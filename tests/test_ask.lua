local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Ask LOMB: the offline question box")

local function boot()
  local ns = H.boot()
  -- the real client returns nothing for uncached items; the bundle names them
  C_Item.GetItemInfo = function() return nil end
  H.state.level, H.state.class, H.state.zone, H.state.faction = 18, "ROGUE", "Westfall", "Alliance"
  ns.Ask.ResetIndex()
  ns.Ask.Clear()
  return ns
end

local function plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function text(ans)
  local out = {}
  for _, l in ipairs(ans.lines) do out[#out + 1] = plain(l.text) end
  return table.concat(out, "\n")
end
local function has(ans, needle, what)
  H.ok(text(ans):find(needle, 1, true), (what or needle) .. " not in:\n" .. text(ans))
end
local function credited(ns, ans)
  H.ok(ans.data, "uses ForeverDB data")
  local cl = table.concat(ns.Ask.ChatLines(ans), "\n")
  H.ok(cl:find("Data from ForeverDB.net", 1, true) and cl:find("https://foreverdb.net", 1, true), "credit line")
end
local function linkTo(ans, mode)
  for _, l in ipairs(ans.lines) do if l.link and l.link[1] == mode then return l.link[2] end end
end
local noErrors = H.noErrors

H.test("indexes are built on the first question, not at load", function()
  local ns = boot()
  H.ok(not ns.Ask.IndexBuilt("quest") and not ns.Ask.IndexBuilt("item"), "nothing built at load")
  ns.Ask.Answer("Where do I turn in The Defias Brotherhood?")
  H.ok(ns.Ask.IndexBuilt("quest"), "quest names indexed on demand")
  H.ok(not ns.Ask.IndexBuilt("set"), "set names not needed yet")
end)

H.test("quest turn-in, start and next in the chain", function()
  local ns = boot()
  local a = ns.Ask.Answer("Where do I turn in The Defias Brotherhood?")
  has(a, "Turn in: Wiley the Black, Redridge Mountains")
  H.ok(linkTo(a, "quests"), "links the quest page")
  credited(ns, a)
  a = ns.Ask.Answer("where does hogger start")
  has(a, "Starts: Wanted Poster (an object), Elwynn Forest")
  has(a, "(Classic data, may differ)")
  a = ns.Ask.Answer("What comes after Red Leather Bandanas?")
  has(a, "Nothing follows it")
  a = ns.Ask.Answer("what comes after the defias brotherhood")
  has(a, "Next up:")
  has(a, "Storyline: Part 2 of 8")
end)

H.test("who sells, how to make, who can craft", function()
  local ns = boot()
  local a = ns.Ask.Answer("Who sells Fine Thread?")
  has(a, "Fine Thread  sold by 33 vendors")
  has(a, "Gina MacGregor <Trade Supplies>, Westfall (58, 54)", "your zone's vendor first")
  H.eq(linkTo(a, "vendors") ~= nil, true, "vendor links")
  credited(ns, a)
  a = ns.Ask.Answer("who sells linen cloth")
  has(a, "No vendor in WoW: Forever has been seen selling it.")
  a = ns.Ask.Answer("How do I make Heavy Linen Bandage?")
  has(a, "Heavy Linen Bandage  (First Aid, skill 40)")
  has(a, "You need: 2x Linen Cloth")
  H.ok(linkTo(a, "recipes"), "recipe link")
  a = ns.Ask.Answer("Who can craft Copper Chain Belt?")
  has(a, "Nobody in the guild has shared a recipe for Copper Chain Belt yet.")
end)

H.test("disenchant, drops, sets", function()
  local ns = boot()
  local a = ns.Ask.Answer("What does Battleforge Boots disenchant into?")
  has(a, "Disenchants into: 1-2x Soul Dust (75%)")
  has(a, "(Classic data, may differ)")
  a = ns.Ask.Answer("What drops Linen Cloth?")
  has(a, "The guild hasn't recorded it dropping yet.")
  has(a, "drop tables aren't bundled")
  a = ns.Ask.Answer("Which set is Blackened Defias Armor in?")
  has(a, "Defias Leather  (0/5 pieces, from level 14)")
  has(a, "2 pieces: +5 Arcane Resistance.")
  has(a, "unconfirmed in WoW Forever")
  H.ok(linkTo(a, "sets"), "set link")
end)

H.test("training, gathering, dungeons, zones, battlegrounds", function()
  local ns = boot()
  local a = ns.Ask.Answer("What should I train?")
  has(a, "to train now: ")
  has(a, "Next at level 20")
  H.eq(linkTo(a, "training"), "now")
  a = ns.Ask.Answer("Where can I find Briarthorn?")
  has(a, "Briarthorn  (Herbalism, skill 70)")
  has(a, "Most spawns: The Barrens (70)")
  local key = linkTo(a, "gathering")
  H.ok(type(key) == "table" and key[1] == "herbalism", "gathering link carries the profession")
  a = ns.Ask.Answer("where do I level mining")
  has(a, "Skill 1-66: Westfall, Loch Modan, Durotar")
  a = ns.Ask.Answer("Deadmines level and bosses")
  has(a, "Deadmines  (level 17-26, 5 players)")
  has(a, "Edwin VanCleef")
  a = ns.Ask.Answer("what is Elwynn Forest")
  has(a, "Elwynn Forest  (level 2-10, Alliance)")
  a = ns.Ask.Answer("tell me about warsong gulch")
  has(a, "Warsong Gulch  (PvP, levels 10-60)")
  a = ns.Ask.Answer("where is Barkeep Daniels")
  has(a, "Barkeep Daniels is in Redridge Mountains (22, 44).")
end)

H.test("quests near my level and in my zone", function()
  local ns = boot()
  local a = ns.Ask.Answer("Quests near my level")
  has(a, "Near level 18:")
  local names, westfallFirst = {}, nil
  for _, l in ipairs(a.lines) do
    if l.link then
      local t = plain(l.text)
      H.ok(not names[t], "each quest once: " .. t)
      names[t] = true
      if westfallFirst == nil then westfallFirst = t:find("Westfall", 1, true) ~= nil end
    end
  end
  H.ok(westfallFirst, "your zone first")
  a = ns.Ask.Answer("quests in my zone")
  has(a, "In Westfall: 33 quests.")
  a = ns.Ask.Answer("quests in duskwood")
  has(a, "In Duskwood:")
  a = ns.Ask.Answer("quests for level 12")
  has(a, "Around level 12:")
end)

H.test("next guild event", function()
  local ns = boot()
  local a = ns.Ask.Answer("When is the next guild event?")
  has(a, "No upcoming guild events")
  H.calendar = { { at = H.epoch + 86400 + 2 * 3600, title = "Deadmines run", by = "Oakenhollow-Forever", len = 7200 } }
  ns.Events.ReadCalendar()
  a = ns.Ask.Answer("next event?")
  has(a, "Next guild event: Deadmines run")
  has(a, "in 26h 0m")
  has(a, "Posted by Oakenhollow.")
  H.calendar = {}
end)

H.test("fallback: close matches, then I don't know", function()
  local ns = boot()
  local a = ns.Ask.Answer("copper ore")
  has(a, "Copper Ore")
  a = ns.Ask.Answer("asdf qwerty")
  H.ok(a.unknown, "flagged unknown")
  has(a, "I don't know that one.")
  local asks = 0
  for _, l in ipairs(a.lines) do if l.ask then asks = asks + 1 end end
  H.eq(asks, 3, "three example questions to click")
  a = ns.Ask.Answer("")
  has(a, "Ask me about quests")
  a = ns.Ask.Answer("where do i turn in defias brotherhod")
  has(a, "I couldn't find a quest called")
  has(a, "The Defias Brotherhood", "closest names offered for a typo")
  H.ok(linkTo(a, "quests"), "and they're clickable")
  a = ns.Ask.Answer("who sells zzzzzz flurble")
  H.ok(a.unknown or text(a):find("couldn't find", 1, true), "unknown item:\n" .. text(a))
end)

H.test("an item link in the question is used as-is", function()
  local ns = boot()
  local a = ns.Ask.Answer("who sells |cffffffff|Hitem:2321::::::::18:::::|h[Fine Thread]|h|r")
  has(a, "sold by 33 vendors")
end)

H.test("every example gets a real answer", function()
  local ns = boot()
  for _, e in ipairs(ns.Ask.EXAMPLES) do
    local a = ns.Ask.Answer(e)
    H.ok(not a.unknown, "example understood: " .. e)
    H.ok(#a.lines >= 1, "example answered: " .. e)
  end
  noErrors("examples")
end)

H.test("/lomb ask prints to you only and never to chat", function()
  local ns = boot()
  DEFAULT_CHAT_FRAME.lines = {}
  ns.HandleSlash("ask Who sells Fine Thread?")
  H.eq(#H.said, 0, "nothing said in chat")
  H.eq(#H.sent, 0, "nothing sent to the guild")
  local out = table.concat(DEFAULT_CHAT_FRAME.lines, "\n")
  H.ok(out:find("Ask LOMB:", 1, true) and out:find("Who sells Fine Thread?", 1, true), "question echoed with its case")
  H.ok(out:find("Gina MacGregor", 1, true), "answer printed")
  H.ok(out:find("Data from ForeverDB.net", 1, true) and out:find("https://foreverdb.net", 1, true), "credit printed")
  H.eq(#ns.Ask.history, 1, "kept in the session history")
  -- no question: opens the tab
  ns.HandleSlash("ask")
  H.eq(ns.UI.current, "ask")
  noErrors("slash")
end)

H.test("Ask LOMB tab: history, clickable lines, examples, clear", function()
  local ns = boot()
  ns.UI.Open("ask")
  local tab
  for _, t in ipairs(ns.UI.tabs) do if t.id == "ask" then tab = t end end
  H.ok(tab and tab.panel, "tab built")
  H.eq(tab.label, "Ask LOMB")
  local p = tab.panel
  p.list.h = 17 * 20
  p.list:Layout()
  -- welcome screen with clickable examples
  local rows = ns.AskTab.Rows()
  H.ok(plain(rows[1].text):find("Ask me about", 1, true), "welcome")
  local ex
  for _, r in ipairs(rows) do if r.click and r.line.ask then ex = r; break end end
  H.ok(ex, "example rows are clickable")
  -- typing a question + Enter
  p.input:SetText("Where can I find Briarthorn?")
  p.input.scripts.OnEnterPressed(p.input)
  H.eq(p.input:GetText(), "", "input cleared")
  H.eq(#ns.Ask.history, 1)
  rows = p.list.items
  H.eq(rows[1].kind, "you")
  H.eq(rows[2].tag, "LOMB")
  local credit = false
  for _, r in ipairs(rows) do if r.kind == "credit" then credit = plain(r.text) end end
  H.eq(credit, "Data from ForeverDB.net · https://foreverdb.net")
  H.eq(plain(p.credit:GetText()), "Data from ForeverDB.net · https://foreverdb.net", "header credit")
  -- clicking the gathering link opens Quests & Items on the node
  local link
  for _, r in ipairs(rows) do if r.click and r.line.link and r.line.link[1] == "gathering" then link = r; break end end
  H.ok(link, "gathering link row")
  ns.AskTab.Open(link.line)
  H.eq(ns.UI.current, "quests", "opened Quests & Items")
  -- example chip asks straight away
  ns.UI.Open("ask")
  p.chips[1]:Click()
  H.eq(#ns.Ask.history, 2)
  H.eq(ns.Ask.history[2].q, ns.AskTab.CHIPS[1])
  -- up arrow recalls the last question
  p.input.scripts.OnArrowPressed(p.input, "UP")
  H.eq(p.input:GetText(), ns.AskTab.CHIPS[1])
  -- long lines wrap and keep their colour
  local parts = ns.AskTab.Wrap("|cff9a92a8" .. string.rep("word ", 40) .. "|r", 50)
  H.ok(#parts >= 4, "wrapped")
  for _, s in ipairs(parts) do H.ok(#plain(s) <= 52, "fits") end
  H.ok(parts[2]:find("^%s*|cff9a92a8"), "colour carried to the next line")
  p.clear:Click()
  H.eq(#ns.Ask.history, 0, "cleared")
  H.eq(#H.said, 0, "nothing said in chat")
  noErrors("tab")
end)

H.test("history is saved per character, survives a reload, and Clear wipes it", function()
  local ns = boot()
  ns.Ask.Submit("Who sells Fine Thread?")
  ns.Ask.Submit("Where can I find Briarthorn?")
  local saved = _G.LOMBCompanionCharDB.askHistory
  H.eq(#saved, 2, "saved in the per-character SavedVariables")
  H.eq(_G.LOMBCompanionDB.askHistory, nil, "not in the account-wide one")
  -- only the question and the answer lines, nothing else
  local allowed = { q = true, lines = true, data = true }
  local lineKeys = { text = true, style = true, link = true, tab = true, ask = true }
  for _, e in ipairs(saved) do
    for k in pairs(e) do H.ok(allowed[k], "unexpected saved field " .. tostring(k)) end
    for _, l in ipairs(e.lines) do
      for k in pairs(l) do H.ok(lineKeys[k], "unexpected saved line field " .. tostring(k)) end
      for _, v in pairs(l) do H.ok(type(v) ~= "function" and type(v) ~= "userdata", "plain values only") end
    end
    H.ok(getmetatable(e) == nil, "saved as a plain table")
  end
  H.eq(saved[1].q, "Who sells Fine Thread?")
  H.ok(saved[1].data, "credit flag kept")

  -- reload: the history comes back
  local db, cdb = _G.LOMBCompanionDB, _G.LOMBCompanionCharDB
  local ns2 = H.boot({ db = db, charDB = cdb })
  H.eq(#ns2.Ask.history, 2, "history restored after reload")
  H.eq(ns2.Ask.history[2].q, "Where can I find Briarthorn?")
  H.ok(ns2.Ask.history[1].restored, "marked as from earlier")
  ns2.UI.Open("ask")
  local tab = ns2.AskTab
  local rows = tab.Rows()
  H.ok(plain(rows[1].text):find("Saved from earlier", 1, true), "earlier answers are marked")
  local credits = 0
  for _, r in ipairs(rows) do if r.kind == "credit" then credits = credits + 1 end end
  H.eq(credits, 2, "credit lines come back too")
  -- restored links still work
  local link
  for _, r in ipairs(rows) do if r.click and r.line.link then link = r.line; break end end
  H.ok(link, "a clickable line survived")
  tab.Open(link)
  H.eq(ns2.UI.current, "quests", "and opens its page")
  ns2.UI.Open("ask")
  ns2.Ask.Submit("Deadmines level and bosses")
  rows = tab.Rows()
  local now
  for _, r in ipairs(rows) do if r.kind == "note" and plain(r.text) == "Now:" then now = true end end
  H.ok(now, "new answers start under Now:")
  H.eq(#_G.LOMBCompanionCharDB.askHistory, 3)

  -- capped at 40 questions
  for i = 1, 45 do ns2.Ask.Submit("Quests for level " .. (i % 30 + 1)) end
  H.eq(#ns2.Ask.history, 40)
  H.eq(#_G.LOMBCompanionCharDB.askHistory, 40, "saved copy capped at 40")
  -- a tampered/oversized saved file is cleaned on load
  local big = {}
  for i = 1, 60 do big[i] = { q = ("x"):rep(500), lines = { { text = "hi", fn = print, extra = "no" } }, who = "someone" } end
  big[61] = "junk"
  cdb = _G.LOMBCompanionCharDB
  cdb.askHistory = big
  local ns3 = H.boot({ db = _G.LOMBCompanionDB, charDB = cdb })
  H.eq(#ns3.Ask.history, 39, "capped (the junk entry is dropped)")
  H.eq(#ns3.Ask.history[1].q, 200, "long questions trimmed")
  H.eq(ns3.Ask.history[1].who, nil, "unknown fields dropped")
  H.eq(ns3.Ask.history[1].lines[1].fn, nil)
  H.eq(ns3.Ask.history[1].lines[1].extra, nil)

  -- Clear wipes the saved copy as well
  ns3.UI.Open("ask")
  ns3.AskTab.panel.clear:Click()
  H.eq(#ns3.Ask.history, 0)
  H.eq(_G.LOMBCompanionCharDB.askHistory, nil, "saved copy wiped")
  local ns4 = H.boot({ db = _G.LOMBCompanionDB, charDB = _G.LOMBCompanionCharDB })
  H.eq(#ns4.Ask.history, 0, "still empty after another reload")
  noErrors("history")
end)

H.test("minimap: right-click opens Ask LOMB, ctrl-click the card, left-click as before", function()
  local ns = boot()
  local b = ns.Minimap.button
  H.ok(not (ns.UI.frame and ns.UI.frame.shown), "closed to start")
  b.scripts.OnClick(b, "RightButton")
  H.ok(ns.UI.frame.shown, "window opened")
  H.eq(ns.UI.current, "ask", "on the Ask LOMB tab")
  ns.UI.Open("roster")
  b.scripts.OnClick(b, "RightButton")
  H.eq(ns.UI.current, "ask", "switches to Ask LOMB when already open")
  b.scripts.OnClick(b, "LeftButton")
  H.ok(not ns.UI.frame.shown, "left-click still toggles the window")
  b.scripts.OnClick(b, "LeftButton")
  H.ok(ns.UI.frame.shown)
  local toggled = 0
  local real = ns.BestiaryCard.Toggle
  ns.BestiaryCard.Toggle = function() toggled = toggled + 1 end
  _G.IsControlKeyDown = function() return true end
  b.scripts.OnClick(b, "RightButton")
  _G.IsControlKeyDown = function() return false end
  ns.BestiaryCard.Toggle = real
  H.eq(toggled, 1, "ctrl-click: bestiary card")
  -- tooltip text
  local lines = {}
  local add = GameTooltip.AddLine
  GameTooltip.AddLine = function(_, t) lines[#lines + 1] = plain(t or "") end
  b.scripts.OnEnter(b)
  GameTooltip.AddLine = add
  local tt = table.concat(lines, "\n")
  H.ok(tt:find("Right-click  Ask LOMB", 1, true), "tooltip names Ask LOMB:\n" .. tt)
  H.ok(tt:find("Ctrl-click  bestiary card", 1, true), "tooltip names the card")
  H.ok(tt:find("Left-click  open / close", 1, true))
  -- without the ForeverDB snapshot the Ask tab is hidden: right-click just opens the window
  ns.UI.Toggle()
  local avail = ns.FDB.Available
  ns.FDB.Available = function() return false end
  ns.UI.current = "roster"
  b.scripts.OnClick(b, "RightButton")
  H.ok(ns.UI.frame.shown, "window opens")
  H.ok(ns.UI.current ~= "ask", "not onto a hidden tab")
  ns.FDB.Available = avail
  noErrors("minimap")
end)

H.test("event answer uses the player's local time, labelled", function()
  local ns = boot()
  H.state.realmShift = 3600   -- realm clock an hour ahead of ours
  H.calendar = { { at = H.epoch + 3600 + 86400 + 2 * 3600, title = "Deadmines run", by = "Oakenhollow", len = 7200 } }
  ns.Events.ReadCalendar()
  local start = H.epoch + 86400 + 2 * 3600
  local a = ns.Ask.Answer("When is the next guild event?")
  has(a, "at " .. ns.Events.Clock(start) .. " (your time)", "local time with the label")
  has(a, "in 26h 0m", "converted from realm time")
  H.ok(ns.Events.Clock(start):match("^%d+:%d%d [AP]M$"), "12-hour clock: " .. ns.Events.Clock(start))
  -- the client gives an impossible offset: left in realm time and said so
  local gst = GetServerTime
  _G.GetServerTime = function() return math.floor(H.epoch) + 40 * 3600 end
  ns.db.guilds = {}
  ns.Events.ReadCalendar()
  _G.GetServerTime = gst
  a = ns.Ask.Answer("When is the next guild event?")
  has(a, "realm time, not converted; unverified until Nov 4")
  H.state.realmShift = nil
  H.calendar = {}
end)

H.done()
