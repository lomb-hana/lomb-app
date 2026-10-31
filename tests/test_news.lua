local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("News, milestones and leaderboards")

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
  H.eq(ns.News.WeekStart(tue + 1000), tue)
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

H.test("milestones: guild first and class firsts", function()
  local ns = boot()
  -- remote stats with exact milestone times
  remote(ns, "Oakenhollow-Forever", "st", { lv = 21, k = 400, r = 2, pt = 30, lt = { [10] = H.epoch - 9000, [20] = H.epoch - 600 } })
  remote(ns, "Brindlewick-Forever", "st", { lv = 20, k = 380, r = 0, pt = 28, lt = { [10] = H.epoch - 8000, [20] = H.epoch - 300 } })
  remote(ns, "Kettlefoot-Forever", "st", { lv = 20, k = 10, r = 0, pt = 20, cl = "MAGE", lt = { [10] = H.epoch - 7000, [20] = H.epoch - 100 } })
  H.roster[#H.roster + 1] = { name = "Kettlefoot-Forever", rank = "Member", level = 20, className = "Mage", class = "MAGE", online = true }
  rescan()
  local ms = ns.News.Milestones()
  H.eq(ms[20].first.name, "Oakenhollow-Forever", "guild first to 20")
  H.eq(ms[20].classes.MAGE.name, "Brindlewick-Forever", "first mage to 20 (earlier than Kettlefoot)")
  H.eq(ms[30].first, nil, "nobody at 30")
  local e = find(ns, "ms", "Oakenhollow-Forever")
  H.ok(e, "milestone in the feed")
  H.ok(strip(ns.News.Text(e)):find("first in the guild to reach 20"), ns.News.Text(e))
  local c
  for _, it in ipairs(ns.News.items) do if it.ty == "ms" and it.who == "Brindlewick-Forever" and tostring(it.a) == "20:MAGE" then c = it end end
  H.ok(c and strip(ns.News.Text(c)):find("first Mage"), "class first line")
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
  H.eq(st.d.lt[10] ~= nil, true, "already-passed milestone recorded")
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
  H.ok(ns2.News.ReachTime("Brindlewick-Forever", 10), "reach time noted")
  H.eq(ns ~= ns2, true)
end)

H.done()
