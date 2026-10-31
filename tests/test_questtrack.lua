local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Quest tracking + storyline drop-downs")

local noErrors = H.noErrors

local function clearAPI()
  _G.C_QuestLog, _G.GetQuestsCompleted, _G.GetQuestLogTitle, _G.IsQuestFlaggedCompleted = nil, nil, nil, nil
  _G.GetNumQuestLogEntries = nil
end

-- a modern C_QuestLog like the one listed for the 1.60.1 client
local function modernAPI(log, completed)
  _G.C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, #log end,
    GetInfo = function(i) return log[i] end,
    ReadyForTurnIn = function(id)
      for _, e in ipairs(log) do if e.questID == id then return e.ready == true end end
      return false
    end,
    GetAllCompletedQuestIDs = function() local t = {} for _, id in ipairs(completed) do t[#t + 1] = id end return t end,
    IsQuestFlaggedCompleted = function(id)
      for _, c in ipairs(completed) do if c == id then return true end end
      return false
    end,
  }
end

local tab = H.tab

local function pageText(page)
  local out = {}
  for i = 1, page.used do out[#out + 1] = tostring(page.lines[i].left.text or "") end
  return table.concat(out, "\n")
end

local function find(rows, key)
  for i, r in ipairs(rows) do if r.key == key then return r, i end end
end

H.test("no quest API at all: says it can't tell, then counts turn-ins it sees", function()
  clearAPI()
  local ns = H.boot()
  local T = ns.QuestTrack
  H.eq(T.api.log, false); H.eq(T.api.completed, false); H.eq(T.api.flagged, false)
  H.eq(T.Status(783), nil)
  H.eq(T.Knows(), false)
  local Tab = ns.QuestsTab
  Tab.Show("quests")
  Tab.view.level, Tab.view.zone, Tab.view.mine = 3, false, false
  local head = find(Tab.Items(), "story:783")
  H.ok(head.meta:find("quests$"), "no progress claimed: " .. head.meta)
  H.fire("QUEST_TURNED_IN", 783, 100, 0)
  H.ok(type(ns.char.questsDone[783]) == "number", "saved per character")
  H.eq(T.Status(783), "done")
  H.eq(T.Source(783), "seen")
  H.eq(T.Status(7), nil)
  head = find(Tab.Items(), "story:783")
  H.ok(head.meta:find("1/%d+ done$"), "progress on the header: " .. head.meta)
  -- a secret quest id is ignored, never stored
  H.fire("QUEST_TURNED_IN", H.secret(7), 0, 0)
  H.eq(ns.char.questsDone[7], nil)
  H.ok(T.Report():find("not readable"), "report")
  noErrors("no API")
end)

H.test("turn-ins seen are kept for the character; junk is dropped", function()
  clearAPI()
  local ns = H.boot({ charDB = { questsDone = { [783] = 1790000000, [7] = 1790000100, bad = 1, [15] = "x" } } })
  H.eq(ns.QuestTrack.Status(783), "done")
  H.eq(ns.QuestTrack.Status(7), "done")
  H.eq(ns.char.questsDone.bad, nil)
  H.eq(ns.char.questsDone[15], nil)
  H.ok(ns.QuestTrack.Knows())
  noErrors("saved")
end)

H.test("modern C_QuestLog: in log, ready, done from history, not started", function()
  clearAPI()
  local log = {
    { title = "Northshire", isHeader = true },
    { title = "Kobold Camp Cleanup", questID = 7, ready = true },
    { title = "Investigate Echo Ridge", questID = 15 },
    { title = "secret", questID = H.secret(18) },
  }
  modernAPI(log, { 783, 33 })
  local ns = H.boot()
  local T = ns.QuestTrack
  H.ok(T.api.log and T.api.completed and T.api.flagged, "all answered")
  H.eq(T.Status(783), "done"); H.eq(T.Source(783), "game")
  H.eq(T.Status(7), "ready")
  H.eq(T.Status(15), "log")
  H.eq(T.Status(21), "none")
  H.eq(T.Status(18), "none")     -- the secret id was skipped
  H.ok(T.Knows())
  H.eq(select(1, T.Progress({ 783, 7, 15, 21, 33 })), 2)
  -- 7 leaves the log while ready (no QUEST_TURNED_IN): counted as turned in
  table.remove(log, 2)
  H.fire("QUEST_LOG_UPDATE")
  H.advance(1)
  H.eq(T.Status(7), "done")
  H.eq(T.Source(7), "seen")
  -- 15 dropped while not done: not counted
  table.remove(log, 2)
  H.fire("QUEST_REMOVED", 15)
  H.advance(1)
  H.eq(T.Status(15), "none")
  H.ok(T.Report():find("Quest log: readable", 1, true), "report")
  -- the list and the quest page show it
  local Tab = ns.QuestsTab
  Tab.Show("quests", 783)
  Tab.view.level, Tab.view.zone, Tab.view.mine = 3, false, false
  local rows = Tab.Items()
  local r = find(rows, 783)
  H.ok(r.meta:find("done", 1, true), "done tag")
  H.ok(find(rows, "story:783").meta:find("%d+/%d+ done"), "header progress")
  local p = tab(ns, "quests").panel
  ns.UI.Refresh("quests")
  H.ok(pageText(p.page):find("You", 1, true) and pageText(p.page):find("Done", 1, true), "status on the page")
  Tab.Show("quests", 21)
  H.ok(pageText(p.page):find("Not started", 1, true), "not started")
  clearAPI()
  noErrors("modern")
end)

H.test("a quest API that errors or returns junk doesn't break anything", function()
  clearAPI()
  _G.C_QuestLog = {
    GetNumQuestLogEntries = function() error("nope") end,
    GetInfo = function() error("nope") end,
    GetAllCompletedQuestIDs = function() return "junk" end,
    IsQuestFlaggedCompleted = function() error("nope") end,
  }
  local ns = H.boot()
  local T = ns.QuestTrack
  H.eq(T.api.log, false)
  H.eq(T.api.completed, false)
  H.eq(T.Status(783), nil)
  H.fire("QUEST_LOG_UPDATE")
  H.advance(11)
  ns.QuestsTab.Show("quests", 783)
  ns.HandleSlash("questcheck")
  clearAPI()
  noErrors("junk API")
end)

H.test("Classic-era globals still work as a fallback", function()
  clearAPI()
  _G.GetNumQuestLogEntries = function() return 3 end
  _G.GetQuestLogTitle = function(i)
    if i == 1 then return "Elwynn", nil, nil, true end
    if i == 2 then return "Kobold Camp Cleanup", 2, nil, false, nil, 1, nil, 7 end
    return "Investigate Echo Ridge", 3, nil, false, nil, nil, nil, 15
  end
  _G.GetQuestsCompleted = function() return { [783] = true } end
  local ns = H.boot()
  local T = ns.QuestTrack
  H.eq(T.Status(7), "ready")
  H.eq(T.Status(15), "log")
  H.eq(T.Status(783), "done")
  H.eq(T.Status(21), "none")
  clearAPI()
  noErrors("classic")
end)

H.test("storylines: one closed header each, open on click, filters respected", function()
  clearAPI()
  local ns = H.boot()
  local Tab, FDB = ns.QuestsTab, ns.FDB
  Tab.Show("quests")
  local p = tab(ns, "quests").panel
  Tab.view.level, Tab.view.zone, Tab.view.mine = 3, false, false   -- levels 1-10, everywhere, both sides
  ns.UI.Refresh("quests")
  local rows = p.list.items
  local heads, quests = 0, 0
  for _, r in ipairs(rows) do
    if r.header then
      heads = heads + 1
      H.ok(not r.open, "closed by default")
    else
      quests = quests + 1
      H.eq(FDB.Storyline(r.key), nil, "closed storylines hide their parts")
    end
  end
  H.ok(heads > 10, "headers: " .. heads)
  H.ok(Tab.count > quests, "count includes quests in closed storylines")
  H.ok(p.count.text:find("^" .. Tab.count .. " quests"), "count text: " .. tostring(p.count.text))
  -- nothing auto-selected on a header
  H.ok(type(Tab.selected.quests) == "number", "a quest is selected, not a header")
  -- the header: name, level range and the parts the filters let through
  -- (near level 12 = 9-15 cuts the Defias storyline, 5-20, down)
  Tab.view.level = 1
  ns.UI.Refresh("quests")
  rows = p.list.items
  local story, head, at, vis
  for i, r in ipairs(rows) do
    if r.header then
      local st = FDB.Storyline(r.story)
      local v = {}
      for _, o in ipairs(st.order) do local l = FDB.Quest(o.id).l; if l >= 9 and l <= 15 then v[#v + 1] = o.id end end
      if #v > 1 and #v < st.size then story, head, at, vis = st, r, i, v; break end
    end
  end
  H.ok(story, "a storyline that straddles the level band")
  H.eq(head.text, story.name)
  H.ok(#vis > 0 and #vis < story.size, "some parts filtered out")
  H.eq(head.meta, FDB.LevelRange(vis) .. " · " .. #vis .. " quests")
  H.ok(head.tip[3]:find(#vis .. " of its " .. story.size, 1, true), "tooltip says how many match")
  -- click opens it, parts follow in story order, click again closes
  local row
  for _, r in ipairs(p.list.rows) do if r.item == head then row = r end end
  if row then row.scripts.OnClick(row, "LeftButton") else Tab.Toggle(head.story) end
  rows = p.list.items
  H.ok(rows[at].open, "open")
  local n = 0
  for i = at + 1, #rows do
    if rows[i].header or FDB.Storyline(rows[i].key) ~= story then break end
    H.eq(rows[i].key, vis[n + 1], "story order")
    H.ok(rows[i].indent >= 1, "indented under the header")
    n = n + 1
  end
  H.eq(n, #vis)
  Tab.Toggle(head.story)
  H.ok(not p.list.items[at].open, "closed again")
  Tab.view.level = 3
  story = FDB.Storyline(783)
  -- a storyline with nothing matching has no header
  Tab.view.search.quests = "Camping 101"
  ns.UI.Refresh("quests")
  rows = p.list.items
  head = find(rows, "story:783")
  H.ok(head.text == "A Threat Within", "header named after the storyline's first quest, even filtered out")
  H.eq(head.meta, "6 · 4 quests")
  for _, r in ipairs(rows) do
    if not r.header then H.ok(r.text:find("Camping 101", 1, true), "only matches") end
  end
  Tab.view.search.quests = "zzzz no such quest"
  ns.UI.Refresh("quests")
  H.eq(#p.list.items, 0)
  -- opening a quest from a link opens its storyline
  Tab.Show("quests", 15)
  H.ok(Tab.open[story.id], "opened to show the quest")
  local _, i = find(p.list.items, 15)
  H.ok(i, "row visible")
  noErrors("storylines")
end)

H.test("header progress counts only visible parts and turns green when all done", function()
  clearAPI()
  local ns = H.boot()
  local Tab, FDB = ns.QuestsTab, ns.FDB
  Tab.Show("quests")
  Tab.view.level, Tab.view.zone, Tab.view.mine = 1, false, false
  Tab.view.search.quests = "Camping 101"
  for _, o in ipairs(FDB.Storyline(783).order) do
    if FDB.Quest(o.id).n:find("Camping 101", 1, true) then H.fire("QUEST_TURNED_IN", o.id, 0, 0) end
  end
  Tab.view.level = 2   -- all levels
  local head = find(Tab.Items(), "story:783")
  H.ok(head.meta:find("4/4 done", 1, true), head.meta)
  H.ok(head.meta:find("|cff7fd18b", 1, true), "green when finished")
  Tab.view.search.quests = ""
  head = find(Tab.Items(), "story:783")
  H.ok(head.meta:find("4/" .. FDB.Storyline(783).size .. " done", 1, true), head.meta)
  noErrors("progress")
end)

H.test("every storyline covers each chained quest once", function()
  local ns = H.boot()
  local FDB, seen, count = ns.FDB, {}, 0
  for id in pairs(ns.FDBData.quests) do
    local st = FDB.Storyline(id)
    H.eq(st ~= nil, FDB.Chain(id) ~= nil)
    if st and not seen[st] then
      seen[st] = true
      local ids = {}
      for _, o in ipairs(st.order) do
        H.ok(not ids[o.id], "once"); ids[o.id] = true
        H.eq(FDB.Storyline(o.id), st)
        H.ok(o.depth >= 0 and o.depth <= 3, "depth")
      end
      H.eq(#st.order, st.size)
      H.eq(st.order[1].id, st.id)
      H.eq(st.order[1].depth, 0)
      count = count + 1
    end
  end
  H.ok(count > 100, "storylines: " .. count)
  noErrors("cover")
end)

H.done()
