local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Quests & Items (bundled ForeverDB.net snapshot)")

local noErrors = H.noErrors

local tab = H.tab

-- every text a detail page currently shows, joined
local function pageText(page)
  local out = {}
  for i = 1, page.used do
    local l = page.lines[i]
    out[#out + 1] = tostring(l.left.text or "") .. " " .. tostring(l.right.text or "")
  end
  return table.concat(out, "\n")
end

local function hasLine(page, needle)
  return pageText(page):find(needle, 1, true) ~= nil
end

H.test("data files load with the credit header and a snapshot", function()
  local ns = H.boot()
  local D = ns.FDBData
  H.ok(D and ns.FDB.Available(), "data loaded")
  H.ok(D.snapshot:match("^%d%d%d%d%-%d%d%-%d%d$"), "snapshot date")
  local n = 0
  for _ in pairs(D.quests) do n = n + 1 end
  H.ok(n > 1000, "quests bundled: " .. n)
  for _, f in ipairs({ "Core", "Items", "Quests", "Vendors", "Recipes", "Dungeons" }) do
    local fh = assert(io.open(H.addonDir .. "Data/ForeverDB/" .. f .. ".lua"))
    local first = fh:read("*l"); fh:close()
    H.ok(first:find("Data from ForeverDB.net (https://foreverdb.net), used with permission. "
      .. "Not covered by this project's MIT license.", 1, true), f .. " header")
  end
  for _, q in pairs(D.quests) do H.ok(q.l <= 30, "quest level <= 30") end
  noErrors("load")
end)

H.test("quest lookups: list filters, NPC index, chains", function()
  local ns = H.boot()
  local FDB = ns.FDB
  local q = FDB.Quest(33)
  H.eq(q.n, "Wolves Across the Border")
  H.eq(q.z, "Elwynn Forest")
  local inZone = FDB.QuestList({ zone = "Elwynn Forest", side = "A" })
  H.ok(#inZone > 10)
  for i = 2, #inZone do H.ok(inZone[i - 1].q.l <= inZone[i].q.l, "sorted by level") end
  for _, e in ipairs(inZone) do H.ok(e.q.s ~= "H", "no Horde-only quests for Alliance") end
  local band = FDB.QuestList({ minLevel = 21, maxLevel = 30 })
  for _, e in ipairs(band) do H.ok(e.q.l >= 21 and e.q.l <= 30) end
  local found = FDB.QuestList({ search = "wolves across" })
  H.eq(found[1].id, 33)
  local starts = FDB.QuestsForNpc(q.st[2])
  local has33 = false
  for _, id in ipairs(starts) do if id == 33 then has33 = true end end
  H.ok(has33, "quest giver index")
  H.eq(FDB.PlayerSide(), "A")
  H.state.faction = "Horde"
  H.eq(FDB.PlayerSide(), "H")
end)

H.test("item, vendor, recipe and dungeon lookups agree with each other", function()
  local ns = H.boot()
  local FDB = ns.FDB
  local D = ns.FDBData
  -- a vendor item points back to its vendor
  local vid, v = next(D.vendors)
  while v and not v.i do vid, v = next(D.vendors, vid) end
  H.ok(v, "a vendor with items")
  local facts = FDB.ItemFacts(v.i[1])
  local back = false
  for _, s in ipairs(facts.soldBy) do if s.vendor == vid then back = true end end
  H.ok(back, "soldBy index")
  -- every bundled vendor was seen in Forever (Classic-only vendors are left out)
  H.ok(#FDB.VendorList({}) > 100)
  -- recipes: skill filter and the reagent index
  local list = FDB.RecipeList({ prof = "alchemy", maxSkill = 75 })
  H.ok(#list > 3)
  for _, e in ipairs(list) do H.ok((e.r.sk[1] or 0) <= 75) end
  local r = list[1].r
  if r.rg then H.ok(#FDB.ItemFacts(r.rg[1]).reagentFor > 0) end
  for _, e in ipairs(FDB.RecipeList({})) do H.ok((e.r.sk[1] or 0) <= 225, "skill cap") end
  -- bosses map back to their dungeon
  local n = 0
  for id, dg in pairs(ns.FDBData.dungeons) do
    n = n + 1
    if dg.b and dg.b[1] then H.eq(FDB.DungeonForBoss(dg.b[1]), id, dg.n) end
  end
  H.ok(n >= 5)
end)

H.test("item tooltip line carries the credit and respects the setting", function()
  local ns = H.boot()
  local FDB = ns.FDB
  local vid, v = next(ns.FDBData.vendors)
  while v and not v.i do vid, v = next(ns.FDBData.vendors, vid) end
  local line = FDB.TooltipLine(v.i[1])
  H.ok(line and line:find("Data from ForeverDB.net, https://foreverdb.net", 1, true), tostring(line))
  ns.db.settings.fdbTooltips = false
  H.eq(FDB.TooltipLine(v.i[1]), nil)
  local lines = {}
  GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
  ns.db.settings.fdbTooltips = true
  ns.db.settings.tooltips = true
  GameTooltip.GetItem = function() return "x", ("|cffffffff|Hitem:%d::|h[x]|h|r"):format(v.i[1]) end
  H.now = H.now + 5
  GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
  local seen = false
  for _, l in ipairs(lines) do if tostring(l):find("ForeverDB.net", 1, true) then seen = true end end
  H.ok(seen, "tooltip shows the ForeverDB line")
  noErrors("tooltip")
end)

H.test("Quests & Items tab: every view renders, shows the credit and the link", function()
  local ns = H.boot()
  SlashCmdList.LOMB("quests")
  H.eq(ns.UI.current, "quests")
  local t = tab(ns, "quests")
  local p = t.panel
  H.ok(p, "tab built")
  H.eq(p.credit.text, "Data from ForeverDB.net")
  H.eq(p.url:GetText(), "https://foreverdb.net")
  H.ok(p.snap.text:find(ns.FDBData.snapshot, 1, true))
  for _, m in ipairs(ns.QuestsTab.MODES) do
    ns.QuestsTab.Show(m.key)
    H.advance(1)
    H.ok(#p.list.items > 0, m.key .. " list has rows")
    H.ok(p.page.key ~= nil, m.key .. " auto-selects the first row")
    H.ok(hasLine(p.page, "Data from ForeverDB.net"), m.key .. " detail credit")
    H.ok(hasLine(p.page, "https://foreverdb.net"), m.key .. " detail link")
  end
  noErrors("views")
end)

H.test("quest page: giver, turn-in, chain links and Classic label", function()
  local ns = H.boot()
  ns.QuestsTab.Show("quests", 33)
  local p = tab(ns, "quests").panel
  H.eq(p.page.key, 33)
  H.ok(hasLine(p.page, "Wolves Across the Border"))
  H.ok(hasLine(p.page, "Eagan Peltskinner"))
  H.ok(hasLine(p.page, "Elwynn Forest (49, 40)"))
  H.ok(hasLine(p.page, "foreverdb.net/quest/33"))
  -- follow a chain link, then go back
  local nextId = ns.FDB.NextQuests(33)[1]
  if nextId then
    for i = 1, p.page.used do
      local l = p.page.lines[i]
      if tostring(l.left.text):find(ns.FDB.Quest(nextId).n, 1, true) and l.scripts and l.scripts.OnMouseUp then
        l.scripts.OnMouseUp(l, "LeftButton")
        break
      end
    end
    H.eq(p.page.key, nextId)
    H.ok(p.back.shown, "back button")
    ns.QuestsTab.Back()
    H.eq(p.page.key, 33)
  end
  -- a Classic-sourced quest says so
  for id, q in pairs(ns.FDBData.quests) do
    if q.c then
      ns.QuestsTab.Show("quests", id)
      H.ok(hasLine(p.page, "Classic data"), "classic label")
      break
    end
  end
  -- filters cycle without errors and "near my level" uses the player's level
  ns.QuestsTab.Show("quests")
  ns.QuestsTab.view.level = 1
  ns.UI.Refresh("quests")
  for _, row in ipairs(p.list.items) do
    if not row.header then
      local q = ns.FDB.Quest(row.key)
      H.ok(q.l >= 9 and q.l <= 15, "near level 12")
    end
  end
  p.f1.scripts.OnClick(p.f1, "LeftButton")
  H.ok(ns.QuestsTab.view.zone)
  for _, row in ipairs(p.list.items) do
    if not row.header then H.eq(ns.FDB.Quest(row.key).z, "Elwynn Forest") end
  end
  p.f2.scripts.OnClick(p.f2, "RightButton")
  p.f3.scripts.OnClick(p.f3, "LeftButton")
  noErrors("quest page")
end)

H.test("bestiary links: quest givers show their quests, bosses link their dungeon", function()
  local ns = H.boot()
  local P = ns.Providers
  H.ok(P.Get("foreverdb"), "provider registered")
  local q = ns.FDB.Quest(33)
  ns.db.bestiary[q.st[2]] = { nm = q.st[3] }
  local m = P.Merge(q.st[2], {})
  H.ok(m.sections.quests, "quests section")
  local any = false
  for _, e in ipairs(m.sections.quests.data) do if e.id == 33 then any = true end end
  H.ok(any)
  -- a boss of a bundled dungeon
  for did, dg in pairs(ns.FDBData.dungeons) do
    if dg.b then
      ns.db.bestiary[990001] = { nm = dg.b[1] }
      local mb = P.Merge(990001, {})
      H.ok(mb.sections.boss and mb.sections.boss.data.dungeon == did, "boss -> dungeon")
      break
    end
  end
  noErrors("bestiary")
end)

H.test("credits tab names ForeverDB with the support link", function()
  local ns = H.boot()
  SlashCmdList.LOMB("credits")
  local p = tab(ns, "credits").panel
  H.ok(p.fdb.text:find("Data from ForeverDB.net", 1, true))
  H.ok(p.fdb.text:find("https://buymeacoffee.com/foreverdb", 1, true))
  H.ok(p.fdb.text:find("keeps this project alive", 1, true))
  H.eq(p.fdbUrl:GetText(), "https://foreverdb.net")
  H.eq(p.supportUrl:GetText(), "https://buymeacoffee.com/foreverdb")
  noErrors("credits")
end)

H.test("recipe trainers: own faction first, the other faction marked", function()
  local ns = H.boot()
  local FDB = ns.FDB
  H.eq(FDB.NpcSide({ s = "B", z = "Orgrimmar" }), "H", "capital zone sets side")
  H.eq(FDB.NpcSide({ s = "B", z = "Stranglethorn Vale" }), "B", "contested stays both")
  H.eq(FDB.NpcSide({ s = "A", z = "Orgrimmar" }), "A", "explicit side wins")
  local ref = FDB.Index().madeBy[2568] and FDB.Index().madeBy[2568][1]
  H.ok(ref, "Brown Linen Vest has a recipe")
  ns.QuestsTab.Show("recipes", ref.prof .. ":" .. ref.i)
  local txt = pageText(tab(ns, "quests").panel.page)
  local firstOther = txt:find("(other faction)", 1, true)
  local own = txt:find("Darnassus", 1, true)
  H.ok(own and firstOther and own < firstOther, "Alliance trainer listed before Horde ones")
  noErrors("recipe faction")
end)

H.test("quest chains: parts follow the links, branches carry the numbering", function()
  local ns = H.boot()
  local FDB = ns.FDB
  -- Northshire: A Threat Within -> Kobold Camp Cleanup -> Investigate Echo Ridge -> Skirmish at Echo Ridge
  local first = FDB.Chain(783)
  H.ok(first, "783 is chained")
  H.eq(first.part, 1)
  for k, id in ipairs({ 783, 7, 15, 21 }) do
    H.eq(FDB.Chain(id).line, first.line, id .. " same line")
    H.eq(FDB.Chain(id).part, k, id .. " part")
  end
  H.eq(FDB.ChainText(783), "Part 1 of " .. first.total)
  -- Report to Goldshire branches off Skirmish at Echo Ridge and keeps counting from it
  local rg = FDB.Chain(54)
  H.ok(rg.line ~= first.line, "branch is its own line")
  H.eq(rg.part, 5)
  H.eq(rg.line.from, 21)
  H.ok(rg.line.branch, "marked as a branching chain")
  -- a quest without links has no chain
  H.eq(FDB.Chain(9), nil)
  H.eq(FDB.ChainText(9), nil)
  -- every chained quest: parts are in range, and each line counts up by one along real links
  local lines = {}
  for id in pairs(ns.FDBData.quests) do
    local c = FDB.Chain(id)
    if c then
      H.ok(c.part >= 1 and c.part <= c.total, "part in range " .. id)
      lines[c.line] = true
    end
  end
  for line in pairs(lines) do
    H.ok(not line.unclear, "no loops in the bundled data")
    for k = 2, #line.ids do
      local a, b = line.ids[k - 1], line.ids[k]
      H.eq(FDB.Chain(b).part, FDB.Chain(a).part + 1)
      local linked = false
      for _, n in ipairs(FDB.NextQuests(a)) do if n == b then linked = true end end
      H.ok(linked, a .. " leads to " .. b)
    end
  end
  noErrors("chains")
end)

H.test("quest chains: made-up data covers loops, branches and links past level 30", function()
  local ns = H.boot()
  local FDB = ns.FDB
  local function q(n, l, extra)
    local t = { n = n, l = l, r = 1, s = "A", z = "Testland" }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
  end
  ns.FDBData.quests = {
    -- straight chain whose last part is a lower level than the first
    [1] = q("Alpha", 5, { nx = { 2 } }), [2] = q("Beta", 6, { pv = { 1 }, nx = { 3 } }), [3] = q("Gamma", 4, { pv = { 2 } }),
    -- branch: 10 -> 11 -> 12 and 10 -> 13; 12 leads on past level 30
    [10] = q("Root", 8, { nx = { 11, 13 } }), [11] = q("Long", 9, { pv = { 10 } }),
    [12] = q("Longer", 9, { pv = { 11 }, nx = { 9999 } }), [13] = q("Side", 8, { pv = { 10 } }),
    -- a loop: 20 -> 21 -> 20
    [20] = q("Loop B", 3, { nx = { 21 } }), [21] = q("Loop A", 3, { nx = { 20 } }),
    -- the first known part of a chain that starts above level 30
    [30] = q("Late", 7, { pv = { 8888 }, nx = { 31 } }), [31] = q("Later", 7, { pv = { 30 } }),
    [40] = q("Loner", 2),
  }
  FDB.ResetIndex()
  H.eq(FDB.ChainText(1), "Part 1 of 3")
  H.eq(FDB.ChainText(3), "Part 3 of 3")
  H.eq(FDB.ChainText(10), "Part 1 of 3+")
  H.eq(FDB.ChainText(12), "Part 3 of 3+")
  H.eq(FDB.ChainText(13), "Part 2 of 2")
  H.eq(FDB.Chain(13).line.from, 10)
  H.ok(FDB.Chain(10).line.branch)
  H.ok(FDB.Chain(20).line.unclear, "loop falls back")
  H.eq(FDB.ChainText(21), "Part 1 of 2")   -- same level: by name, "Loop A" first
  H.eq(FDB.ChainText(30), "Part ? of ?")
  H.eq(FDB.ChainText(40), nil)
  FDB.ResetIndex()
  noErrors("made-up chains")
end)

H.test("quest list: chained quests are tagged and grouped, others unchanged", function()
  local ns = H.boot()
  local Tab = ns.QuestsTab
  Tab.Show("quests")
  Tab.view.level, Tab.view.zone, Tab.view.mine = 3, false, false   -- levels 1-10, everywhere, both sides
  Tab.open[ns.FDB.Storyline(783).id] = true
  local rows = Tab.Items()
  local pos = {}
  for i, r in ipairs(rows) do pos[r.key] = i end
  -- Northshire's storyline is together, in order, under its header; branches
  -- sit right after the quest they split from, one step further in
  local head = rows[pos[783] - 1]
  H.ok(head.header and head.open and head.text == "A Threat Within", "header right above part 1")
  H.ok(pos[783] < pos[7] and pos[7] < pos[15] and pos[15] < pos[21], "main line in order")
  H.eq(pos[54], pos[21] + 1)
  H.eq(rows[pos[783]].indent, 1)
  H.eq(rows[pos[7]].indent, 1)
  H.eq(rows[pos[54]].indent, 2)
  H.eq(rows[pos[5261]].indent, 2)
  H.ok(pos[5261] < pos[7], "the branch off part 1 comes before part 2")
  H.ok(rows[pos[783]].meta:find("Part 1 of", 1, true), "tag in the row")
  H.ok(rows[pos[783]].chain, "chain bar")
  -- quests outside chains keep their level order and have no tag
  local plain, last = 0, 0
  for _, r in ipairs(rows) do
    if not r.header and not ns.FDB.Chain(r.key) then
      plain = plain + 1
      H.ok(not r.chain and not r.meta:find("Part", 1, true), "untagged")
      local l = ns.FDB.Quest(r.key).l
      l = l > 0 and l or 99
      H.ok(l >= last, "unchained quests stay in level order")
      last = l
    end
  end
  H.ok(plain > 50, "plenty of standalone quests")
  -- the quest page says which part it is
  Tab.Show("quests", 54)
  local p = tab(ns, "quests").panel
  H.ok(hasLine(p.page, "Part 5 of 5"))
  H.ok(hasLine(p.page, "Branches off Skirmish at Echo Ridge."))
  noErrors("tagged list")
end)

H.done()
