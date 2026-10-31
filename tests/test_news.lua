local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("News, dungeon clears and leaderboards")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", level = 19, className = "Druid", class = "DRUID", online = false, days = 1 },
  { name = "Brindlewick-Forever", rank = "Member", level = 9, className = "Mage", class = "MAGE", online = true },
}
local function copyRoster()
  local out = {}
  for i, r in ipairs(ROSTER) do local c = {} for k, v in pairs(r) do c[k] = v end out[i] = c end
  return out
end

local function boot(opts)
  local ns = H.boot(opts)
  H.state.level = 12
  H.roster = copyRoster()
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.sent = {}
  return ns
end

local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    local payload = a:Feed("me", s.msg)
    if payload then
      local _, d = ns.Serializer.Unpack(payload)
      out[#out + 1] = d
    end
  end
  return out
end
local function lastOf(ns, kind)
  local found
  for _, m in ipairs(decodeSent(ns)) do if m.t == "D" and m.k == kind then found = m end end
  return found
end
local deliver = H.deliver
-- a guildmate's addon publishing a dataset
local rev = 0
local function remote(ns, sender, kind, d)
  rev = rev + 1
  deliver(ns, sender, { t = "D", k = kind, r = H.epoch + rev, d = d })
  H.advance(2)
end
local function rescan(mut)
  if mut then mut(H.roster) end
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(3)
end
local function find(ns, ty, who)
  for _, e in ipairs(ns.News.items) do
    if e.ty == ty and (not who or e.who == who) then return e end
  end
end
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

H.test("week ids roll over at the Tuesday reset", function()
  local ns = boot()
  local W = ns.News.WeekId
  -- 2026-11-03 is a Tuesday; reset at 15:00 UTC
  local tue = 1793718000
  H.eq(W(tue - 1) + 1, W(tue), "new week starts at reset")
  H.eq(W(tue), W(tue + 6 * 86400 + 23 * 3600), "same week until next Tuesday")
end)

H.test("roster level-ups, joins and leaves become news", function()
  local ns = boot()
  rescan(function(r) r[2].level = 20 end)
  local e = find(ns, "lv", "Oakenhollow-Forever")
  H.ok(e, "level-up seen from the roster")
  H.eq(e.a, 20)
  H.eq(strip(ns.News.Text(e)), "Oakenhollow reached level 20")
  rescan(function(r) r[#r + 1] = { name = "Newbie-Forever", rank = "Initiate", level = 3, className = "Rogue", class = "ROGUE", online = true } end)
  H.ok(find(ns, "join", "Newbie-Forever"), "join seen")
  rescan(function(r) table.remove(r, 3) end)
  H.ok(find(ns, "left", "Brindlewick-Forever"), "leave seen")
  H.ok(ns.DB.Guild().members["Brindlewick-Forever"].gone, "marked gone")
  -- no duplicates when the same roster is read again
  local n = #ns.News.items
  rescan()
  H.eq(#ns.News.items, n, "rescan adds nothing")
end)

H.test("first ever roster read is not news; partial rosters never cause leaves", function()
  local ns = boot()
  H.eq(find(ns, "join"), nil, "nobody 'joined' on the first read")
  local real = _G.GetNumGuildMembers
  -- a client that only lists online members: 2 rows of a 3-member guild
  H.roster = { H.roster[1], H.roster[3] }
  _G.GetNumGuildMembers = function() return 3, 2 end
  rescan()
  H.eq(find(ns, "left"), nil, "no leaves from an incomplete list")
  _G.GetNumGuildMembers = real
end)

H.test("old milestone data is harmless: no races, no firsts, level-up lines unchanged", function()
  local ns = boot()
  -- an older client still sends exact level times ("lt"); they are ignored
  remote(ns, "Oakenhollow-Forever", "st", { lv = 21, k = 400, r = 2, pt = 30, lt = { [10] = H.epoch - 9000, [20] = H.epoch - 600 } })
  remote(ns, "Brindlewick-Forever", "st", { lv = 20, k = 380, r = 0, pt = 28, lt = { [10] = H.epoch - 8000, [20] = H.epoch - 300 } })
  rescan(function(r) r[2].level = 21; r[3].level = 20 end)
  for _, it in ipairs(ns.News.items) do H.ok(it.ty ~= "ms", "no milestone race lines") end
  H.eq(ns.News.Milestones, nil, "Firsts are gone")
  H.eq(ns.News.ReachTime, nil)
  for _, b in ipairs(ns.News.BOARDS) do H.ok(b.key ~= "firsts", "no Firsts board") end
  for _, f in ipairs(ns.News.FILTERS) do H.ok(f.label ~= "Milestones", "no Milestones filter") end
  local e = find(ns, "lv", "Brindlewick-Forever")
  H.eq(strip(ns.News.Text(e)), "Brindlewick reached level 20", "level-up line exactly as before")
  for _, line in ipairs({ "first in the guild", "first to" }) do
    for _, it in ipairs(ns.News.items) do H.ok(not strip(ns.News.Text(it)):find(line), line) end
  end
end)

H.test("my rare kills and level-ups are shared; normal kills only count", function()
  local ns = boot()
  local B = ns.Bestiary
  local m = B.Ensure(61)
  m.nm, m.cl = "Thuros Lightfingers", "rare"
  local w = B.Ensure(299)
  w.nm, w.cl = "Diseased Young Wolf", "normal"
  B.CountKill(H.guid(299, "A1"), 299)
  B.CountKill(H.guid(61, "A2"), 61)
  H.state.level = 13
  H.fire("PLAYER_LEVEL_UP", 13)
  H.advance(130)
  local st = lastOf(ns, "st")
  H.ok(st, "stats published")
  H.eq(st.d.k, 2); H.eq(st.d.r, 1); H.eq(st.d.wk.r, 1)
  H.eq(st.d.lt, nil, "no level race times shared any more")
  local nw = lastOf(ns, "nw")
  H.ok(nw, "own news published")
  local kinds = {}
  for _, e in ipairs(nw.d.e) do kinds[e[1]] = e end
  H.eq(kinds.rare[2], 61); H.eq(kinds.lv[2], 13)
  H.ok(not next(nw.d.e[3] or {}), "no news for the normal wolf")
  local e = find(ns, "rare")
  H.eq(strip(ns.News.Text(e)), "Testy killed the rare Thuros Lightfingers")
end)

H.test("same rare killed by several guildmates is one line", function()
  local ns = boot()
  local m = ns.Bestiary.Ensure(462)
  m.nm, m.cl = "Vultros", "rare"
  remote(ns, "Oakenhollow-Forever", "nw", { e = { { "rare", 462, "Vultros", H.epoch - 60 } } })
  remote(ns, "Brindlewick-Forever", "nw", { e = { { "rare", 462, "Vultros", H.epoch - 50 } } })
  H.advance(2)
  local n, line = 0, nil
  for _, e in ipairs(ns.News.items) do if e.ty == "rare" then n = n + 1; line = e end end
  H.eq(n, 1, "grouped")
  H.eq(strip(ns.News.Text(line)), "Brindlewick and Oakenhollow killed the rare Vultros")
end)

H.test("an exact report replaces a roster sighting of the same level-up", function()
  local ns = boot()
  rescan(function(r) r[2].level = 20 end)
  local e = find(ns, "lv", "Oakenhollow-Forever")
  remote(ns, "Oakenhollow-Forever", "nw", { e = { { "lv", 20, nil, H.epoch - 400 } } })
  H.advance(2)
  local n = 0
  for _, it in ipairs(ns.News.items) do if it.ty == "lv" and it.who == "Oakenhollow-Forever" then n = n + 1; e = it end end
  H.eq(n, 1, "one line")
  H.ok(e.t <= H.epoch - 400, "exact time used")
end)

H.test("bad remote news is dropped", function()
  local ns = boot()
  remote(ns, "Oakenhollow-Forever", "nw", { e = {
    { "lv", 500, nil, H.epoch }, { "hack", 1, nil, H.epoch }, { "rare", "x", nil, H.epoch },
    { "rc", 2304, "z", H.epoch - 5 }, "junk",
  } })
  H.advance(2)
  local d = ns.Shared.Get("nw", "Oakenhollow-Forever")
  H.eq(#d.e, 1, "only the recipe survives")
  H.eq(d.e[1][3], "i", "bad kind defaults to item")
end)

H.test("leaderboards rank, tie and split weekly", function()
  local ns = boot()
  local wk = ns.News.WeekId()
  remote(ns, "Oakenhollow-Forever", "st", { lv = 19, k = 400, r = 2, pt = 30, wk = { w = wk, k = 50, r = 1 } })
  remote(ns, "Brindlewick-Forever", "st", { lv = 9, k = 400, r = 5, pt = 28, wk = { w = wk - 1, k = 300, r = 5 } })
  local all = ns.News.Board("kills", false)
  H.eq(all[1].rank, 1); H.eq(all[2].rank, 1, "tied")
  local week = ns.News.Board("kills", true)
  H.eq(week[1].name, "Oakenhollow-Forever", "last week's kills don't count")
  H.eq(#week, 1)
  local lv = ns.News.Board("level")
  H.eq(lv[1].name, "Oakenhollow-Forever"); H.eq(lv[1].value, 19)
  H.eq(#lv, 3, "levels include members without the addon")
  local played = ns.News.Board("played")
  H.eq(played[1].value, 30)
end)

H.test("turning sharing off stops both datasets; hours need profile sharing", function()
  local ns = boot()
  ns.db.settings.shareProfile = false
  H.eq(ns.News.BuildStats().pt, nil, "hours withheld")
  ns.db.settings.shareActivity = false
  H.eq(ns.News.BuildStats(), nil)
  H.eq(ns.News.BuildEvents(), nil)
end)

H.test("new recipes become news, the first scan doesn't", function()
  local ns = boot()
  H.trade = { line = "Leatherworking", rows = { { name = "Light Armor Kit", item = 2304 } } }
  H.fire("TRADE_SKILL_SHOW")
  H.advance(2)
  H.eq(find(ns, "rc"), nil, "first read is not news")
  H.trade = { line = "Leatherworking", rows = { { name = "Light Armor Kit", item = 2304 }, { name = "Fine Leather Belt", item = 4246 } } }
  H.fire("TRADE_SKILL_UPDATE")
  H.fire("TRADE_SKILL_SHOW")
  H.advance(2)
  local e = find(ns, "rc")
  H.ok(e, "new recipe news")
  H.eq(e.a, 4246)
end)

H.test("unread badge counts others' news and clears on open", function()
  local ns = boot()
  rescan(function(r) r[2].level = 20 end)
  H.ok(ns.News.Unread() >= 1, "unread")
  ns.UI.Open("news")
  H.eq(ns.News.Unread(), 0, "cleared")
  -- every board and filter renders without errors
  ns.UI.Select("board")
  for _, b in ipairs(ns.News.BOARDS) do
    ns.BoardTab.board = b.key
    ns.UI.Refresh("board")
  end
  ns.UI.Select("news")
  for _ = 1, #ns.News.FILTERS do ns.NewsTab.Cycle() end
  H.eq(ns.NewsTab.filter, 1, "filter cycle wraps")
end)

local function group(names, raid)
  for i = 1, 40 do H.units["party" .. i] = nil; H.units["raid" .. i] = nil end
  for i, n in ipairs(names) do H.units[(raid and "raid" or "party") .. i] = { name = n } end
  H.state.groupSize = #names > 0 and (raid and #names or #names + 1) or 0
  H.state.raid = raid or false
end
local function boss(ns, npcId, name)
  local m = ns.Bestiary.Ensure(npcId)
  m.nm, m.cl = name, "elite"
  return m
end
local function count(ns, ty)
  local n = 0
  for _, e in ipairs(ns.News.items) do if e.ty == ty then n = n + 1 end end
  return n
end

H.test("dungeon clear: the last boss dies, guildmates in the group are named", function()
  local ns = boot()
  H.state.instanceType = "party"
  group({ "Oakenhollow", "Brindlewick", "Strangerx", "Wanderby" })
  boss(ns, 644, "Rhahk'Zor"); boss(ns, 639, "Edwin VanCleef")
  ns.Bestiary.CountKill(H.guid(644, "B1"), 644)
  H.advance(2)
  H.eq(count(ns, "dg"), 0, "not the last boss: no line")
  ns.Bestiary.CountKill(H.guid(639, "B2"), 639)
  H.advance(130)
  local e = find(ns, "dg")
  H.ok(e, "clear in the feed")
  H.eq(strip(ns.News.Text(e)), "Testy, Brindlewick, Oakenhollow and party cleared Deadmines")
  H.ok(ns.News.Involves(e, "Oakenhollow-Forever"), "the group is part of the line")
  H.ok(not ns.News.Involves(e, "Strangerx-Forever"))
  local nw = lastOf(ns, "nw")
  local sent
  for _, it in ipairs(nw.d.e) do if it[1] == "dg" then sent = it end end
  H.ok(sent, "clear shared")
  H.eq(sent[2], 36); H.eq(sent[5].n, 5); H.eq(#sent[5].g, 2, "guildmates only, not the pugs")
  local only = ns.News.Filter("dg")
  H.eq(#only, 1, "Dungeons filter")
  H.eq(only[1].ty, "dg")
  local hasFilter
  for _, f in ipairs(ns.News.FILTERS) do if f.key == "dg" then hasFilter = f.label end end
  H.eq(hasFilter, "Dungeons")
  H.state.instanceType = "none"
  group({})
end)

H.test("a whole-guild group reads without 'party'; same name out in the world is not a clear", function()
  local ns = boot()
  H.state.instanceType = "party"
  group({ "Oakenhollow" })
  boss(ns, 4275, "Archmage Arugal")
  ns.Bestiary.CountKill(H.guid(4275, "C1"), 4275)
  H.advance(2)
  H.eq(strip(ns.News.Text(find(ns, "dg"))), "Testy and Oakenhollow cleared Shadowfang Keep")
  H.state.instanceType = "none"
  boss(ns, 6487, "Arcanist Doan")
  ns.Bestiary.CountKill(H.guid(6487, "C2"), 6487)
  H.advance(2)
  H.eq(count(ns, "dg"), 1, "outside an instance: nothing")
  group({})
end)

H.test("Scarlet Monastery wings and Blackfathom's real last boss", function()
  local ns = boot()
  H.state.instanceType = "party"
  boss(ns, 3975, "Herod"); boss(ns, 4829, "Aku'mai"); boss(ns, 6243, "Gelihast")
  ns.Bestiary.CountKill(H.guid(6243, "D0"), 6243)
  ns.Bestiary.CountKill(H.guid(3975, "D1"), 3975)
  ns.Bestiary.CountKill(H.guid(4829, "D2"), 4829)
  H.advance(2)
  local lines = {}
  for _, e in ipairs(ns.News.items) do if e.ty == "dg" then lines[#lines + 1] = strip(ns.News.Text(e)) end end
  table.sort(lines)
  H.eq(#lines, 2, "Gelihast is not the last boss")
  H.eq(lines[1], "Testy cleared Blackfathom Deeps")
  H.eq(lines[2], "Testy cleared Scarlet Monastery (Armory)")
  H.state.instanceType = "none"
end)

H.test("reports from the same group merge into one line; another group stays separate", function()
  local ns = boot()
  H.roster[#H.roster + 1] = { name = "Kettlefoot-Forever", rank = "Member", level = 20, className = "Mage", class = "MAGE", online = true }
  H.roster[#H.roster + 1] = { name = "Sorrelvane-Forever", rank = "Member", level = 21, className = "Rogue", class = "ROGUE", online = true }
  rescan()
  remote(ns, "Oakenhollow-Forever", "nw", { e = { { "dg", 36, nil, H.epoch - 120, { n = 3, g = { "Brindlewick" } } } } })
  remote(ns, "Brindlewick-Forever", "nw", { e = { { "dg", 36, nil, H.epoch - 110, { n = 3, g = { "Oakenhollow" } } } } })
  remote(ns, "Kettlefoot-Forever", "nw", { e = { { "dg", 36, nil, H.epoch - 100, { n = 2, g = { "Sorrelvane" } } } } })
  H.advance(2)
  local lines = {}
  for _, e in ipairs(ns.News.items) do if e.ty == "dg" then lines[#lines + 1] = strip(ns.News.Text(e)) end end
  table.sort(lines)
  H.eq(#lines, 2)
  H.eq(lines[1], "Brindlewick, Oakenhollow and party cleared Deadmines")
  H.eq(lines[2], "Kettlefoot and Sorrelvane cleared Deadmines")
end)

H.test("raid clears list a few names, then a count", function()
  local ns = boot()
  local g = {}
  for i = 1, 7 do
    local nm = "Raider" .. string.char(96 + i)
    H.roster[#H.roster + 1] = { name = nm .. "-Forever", rank = "Member", level = 60, className = "Mage", class = "MAGE", online = true }
    g[#g + 1] = nm
  end
  rescan()
  remote(ns, "Oakenhollow-Forever", "nw", { e = { { "dg", 249, nil, H.epoch - 60, { n = 20, g = g } } } })
  H.advance(2)
  H.eq(strip(ns.News.Text(find(ns, "dg"))),
    "Oakenhollow, Raidera, Raiderb, Raiderc, 4 more and party cleared Onyxia's Lair")
end)

H.test("bad dungeon reports are cleaned up", function()
  local ns = boot()
  remote(ns, "Oakenhollow-Forever", "nw", { e = {
    { "dg", 36, string.rep("x", 40), H.epoch - 30, { n = 900, g = { "Bad Name", 7, "Brindlewick" } } },
    { "dg", "x", nil, H.epoch - 20 },
  } })
  H.advance(2)
  local d = ns.Shared.Get("nw", "Oakenhollow-Forever")
  H.eq(#d.e, 1)
  H.eq(d.e[1][3], nil, "unknown wing dropped")
  H.eq(d.e[1][5].n, 1, "silly group size reset")
  H.eq(#d.e[1][5].g, 1); H.eq(d.e[1][5].g[1], "Brindlewick")
end)

H.test("guild events that were held show with their attendance", function()
  local ns = boot()
  local E = ns.Events
  H.calendar = { { at = H.epoch - 2 * 86400, title = "Stockades", by = "Oakenhollow", len = 3600 } }
  E.ReadCalendar()
  local rec = E.List("past")[1]
  E.Guild().att[rec.k] = { n = 3, who = { Oakenhollow = 3, Testy = 2, Brindlewick = 1 }, start = rec.start }
  ns.News.Rebuild()
  local e = find(ns, "ev")
  H.ok(e, "held event in the feed")
  H.eq(strip(ns.News.Text(e)), "Guild event Stockades was held: 3 attended")
  H.eq(#ns.News.Filter("ev"), 1)
  -- one not yet held, or with nobody recorded: no line
  H.calendar = { { at = H.epoch + 86400, title = "Later", by = "Testy", len = 3600 },
    { at = H.epoch - 3 * 86400, title = "Nobody came", by = "Testy", len = 3600 } }
  E.ReadCalendar()
  ns.News.Rebuild()
  H.eq(count(ns, "ev"), 1)
end)

H.test("0.9.2 achievement data is ignored and cleared; no achievement news or boards", function()
  local ns = boot()
  local db, cdb = _G.LOMBCompanionDB, _G.LOMBCompanionCharDB
  local g = ns.DB.Guild()
  g.shared.ah = { ["Oakenhollow-Forever"] = { r = 1, at = H.epoch, d = { e = { lv20 = H.epoch } } } }
  ns.char.ach, ns.char.achX, ns.char.achQ, ns.char.achSeedUntil = { lv10 = H.epoch }, {}, {}, H.epoch
  ns.char.act.lt = { [10] = H.epoch }
  ns.db.achAcct = { c60MAGE = { t = H.epoch } }
  local ns2 = H.boot({ db = db, charDB = cdb })
  H.state.level = 12
  H.roster = copyRoster()
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(5)
  H.eq(ns2.Achievements, nil, "no achievements module")
  H.eq(ns2.Shared.kinds.ah, nil, "no achievements dataset")
  H.eq(ns2.DB.Guild().shared.ah, nil, "stored copies dropped")
  H.eq(ns2.char.ach, nil); H.eq(ns2.char.achSeedUntil, nil); H.eq(ns2.db.achAcct, nil)
  H.eq(ns2.char.act.lt, nil, "old level times dropped")
  for _, b in ipairs(ns2.News.BOARDS) do H.ok(b.key ~= "ach" and b.key ~= "firsts", b.key) end
  for _, f in ipairs(ns2.News.FILTERS) do H.ok(f.key ~= "ach" and f.key ~= "ms", f.label) end
  -- an old client still sending "ah" is ignored
  remote(ns2, "Brindlewick-Forever", "ah", { e = { lv10 = H.epoch } })
  H.eq(ns2.DB.Guild().shared.ah, nil)
  for _, e in ipairs(ns2.News.items) do H.ok(e.ty ~= "ach", "no achievement lines") end
end)

H.test("news survives a relog; offline level-ups are marked approximate", function()
  local ns = boot()
  local db, cdb = _G.LOMBCompanionDB, _G.LOMBCompanionCharDB
  rescan(function(r) r[2].level = 20 end)
  H.advance(3)
  local ns2 = H.boot({ db = db, charDB = cdb })
  H.state.level = 12
  H.roster = copyRoster()
  H.roster[2].level = 22
  H.roster[3].level = 10
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(5)
  H.ok(find(ns2, "lv", "Oakenhollow-Forever"), "kept")
  local b = find(ns2, "lv", "Brindlewick-Forever")
  H.ok(b and b.x, "offline level-up flagged")
  H.eq(ns ~= ns2, true)
end)

H.test("epic loot: epics only, mine only, once a day, uncached links by colour", function()
  local ns = boot()
  H.itemNames[12345], H.itemQuality[12345] = "Hand of Testing", 4
  H.itemNames[222], H.itemQuality[222] = "Blue Bracers", 3
  local function loot(id, q, fmt)
    local col = q == 4 and "ffa335ee" or "ff0070dd"
    H.fire("CHAT_MSG_LOOT", (fmt or "You receive loot: %s."):format("|c" .. col .. "|Hitem:" .. id .. "::|h[x]|h|r"))
    H.advance(2)
  end
  loot(222, 3)
  H.eq(find(ns, "ep"), nil, "blue items aren't news")
  loot(12345, 4, "Brindlewick receives loot: %s.")
  H.eq(find(ns, "ep"), nil, "someone else's loot line isn't ours to post")
  loot(12345, 4, "You receive item: %s.")
  H.eq(find(ns, "ep"), nil, "crafted / quest items don't count")
  loot(12345, 4)
  local e = find(ns, "ep", ns.playerKey)
  H.ok(e, "epic looted")
  H.eq(strip(ns.News.Text(e)), "Testy looted the epic [Hand of Testing]")
  loot(12345, 4, "You receive loot: %sx2.")
  local n = 0
  for _, x in ipairs(ns.News.items) do if x.ty == "ep" then n = n + 1 end end
  H.eq(n, 1, "the same epic twice in a day is one line")
  H.itemUncached[777] = true
  loot(777, 4)
  local u = 0
  for _, x in ipairs(ns.News.Filter("ep")) do if x.a == 777 then u = u + 1 end end
  H.eq(u, 1, "uncached item counted from its purple link")
  -- shared with the guild and validated on the way in
  H.advance(130)
  local nw = lastOf(ns, "nw")
  H.ok(nw, "news dataset published")
  remote(ns, "Brindlewick-Forever", "nw", { e = { { "ep", 12345, 9, H.epoch }, { "ep", -3, 4, H.epoch },
    { "mt", 0, nil, H.epoch }, { "mt", 75, "junk", H.epoch } } })
  local b = find(ns, "ep", "Brindlewick-Forever")
  H.ok(b and b.b == 4, "bad quality cleaned to epic")
  local m = find(ns, "mt", "Brindlewick-Forever")
  H.ok(m and m.a == 75 and m.b == nil, "mount line kept, junk dropped")
  local mine = 0
  for _, x in ipairs(ns.News.items) do if x.who == "Brindlewick-Forever" then mine = mine + 1 end end
  H.eq(mine, 2, "bad entries dropped")
end)

H.test("first mount: riding learned is news once; riding learned long ago isn't", function()
  local ns = boot()
  ns.char.act.rd = nil
  H.state.skills = {}
  ns.Me.Refresh()
  H.eq(ns.char.act.rd, nil, "skill lines not readable yet: nothing remembered")
  H.state.skills = { { "Defense", false, 60, 60 } }
  ns.Me.Refresh()
  H.eq(ns.char.act.rd, 0, "no riding yet")
  H.eq(find(ns, "mt"), nil)
  H.state.skills = { { "Defense", false, 60, 60 }, { "Riding", false, 75, 75 } }
  H.fire("SKILL_LINES_CHANGED")
  H.advance(3)
  local e = find(ns, "mt", ns.playerKey)
  H.ok(e, "first mount line")
  H.eq(strip(ns.News.Text(e)), "Testy learned to ride: first mount!")
  H.state.skills = { { "Riding", false, 150, 150 } }
  ns.Me.Refresh()
  H.advance(2)
  local n = 0
  for _, x in ipairs(ns.News.Filter("mt")) do if x.who == ns.playerKey then n = n + 1 end end
  H.eq(n, 1, "training up later isn't another first")
  -- a character that already rides when it first runs this version
  local ns2 = H.boot({ skills = { { "Undead Horsemanship", false, 75, 75 } } })
  ns2.Me.Refresh()
  H.advance(2)
  H.eq(find(ns2, "mt"), nil, "already riding: no news")
  H.eq(ns2.char.act.rd, 75)
  H.ok(ns2.Me.IsRidingSkill("Mechanostrider Piloting"))
  H.ok(not ns2.Me.IsRidingSkill("Mining"))
end)

H.test("welcome back: 14+ days offline, then online", function()
  local ns = boot()
  rescan(function(r) r[2].days = 20 end)                       -- Oakenhollow: 20 days offline
  rescan(function(r) r[3].online = false; r[3].days = 3 end)  -- Brindlewick: 3 days
  rescan(function(r) r[2].online = true; r[3].online = true end)
  local e = find(ns, "wb", "Oakenhollow-Forever")
  H.ok(e, "back after 20 days")
  H.eq(strip(ns.News.Text(e)), "Oakenhollow is back after 20 days away. Welcome back!")
  H.eq(e.x, nil, "seen live: exact time")
  H.eq(find(ns, "wb", "Brindlewick-Forever"), nil, "3 days isn't long enough")
  H.eq(#ns.News.Filter("wb"), 1)
  rescan()
  H.eq(#ns.News.Filter("wb"), 1, "no repeat while they stay online")
  -- an old offline sighting (more than a week before) isn't trusted
  rescan(function(r) r[2].online = false; r[2].days = 30 end)
  H.advance(8 * 86400, 600)
  rescan(function(r) r[2].online = true end)
  local n = 0
  for _, x in ipairs(ns.News.Filter("wb")) do if x.who == "Oakenhollow-Forever" then n = n + 1 end end
  H.eq(n, 1, "stale sighting: no second line")
end)

H.test("welcome back across a relog is marked approximate", function()
  boot()
  local db, cdb = _G.LOMBCompanionDB, _G.LOMBCompanionCharDB
  rescan(function(r) r[2].days = 16 end)
  H.advance(86400, 600)
  local ns2 = H.boot({ db = db, charDB = cdb })
  H.roster = copyRoster()
  H.roster[2].online = true
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(5)
  local e = find(ns2, "wb", "Oakenhollow-Forever")
  H.ok(e and e.x, "came back while we were offline: approximate")
  H.eq(e and e.a, 16, "days counted to our last sighting")
end)

H.done()
