local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Achievements (personal, at your own pace)")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", level = 19, className = "Druid", class = "DRUID", online = false, days = 1 },
}
local function boot(opts)
  local ns = H.boot(opts)
  H.state.level = 12
  H.roster = {}
  for i, r in ipairs(ROSTER) do local c = {} for k, v in pairs(r) do c[k] = v end H.roster[i] = c end
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.sent = {}
  return ns
end
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    local payload = a:Feed("me", s.msg)
    if payload then local _, d = ns.Serializer.Unpack(payload); out[#out + 1] = d end
  end
  return out
end
local function lastOf(ns, kind)
  local found
  for _, m in ipairs(decodeSent(ns)) do if m.t == "D" and m.k == kind then found = m end end
  return found
end
local function newsOf(ns, id, who)
  for _, e in ipairs(ns.News.items) do
    if e.ty == "ach" and (not id or e.a == id) and (not who or e.who == who) then return e end
  end
end
local function setSkill(name, rank)
  for _, s in ipairs(H.state.skills) do if s[1] == name then s[3] = rank; s[4] = 300; return end end
  table.insert(H.state.skills, { name, false, rank, 300 })
end
-- past the quiet backfill window so new earns are announced
local function settle(ns) ns.char.achSeedUntil = time() - 1 end

H.test("five categories, 30-60 achievements, no 'first to' wording", function()
  local ns = boot()
  local A = ns.Achievements
  H.ok(A.TOTAL >= 30 and A.TOTAL <= 60, "count " .. A.TOTAL)
  local cats = {}
  for _, d in ipairs(A.list) do
    cats[d.cat] = (cats[d.cat] or 0) + 1
    H.ok(A.byId[d.id] == d, "indexed " .. d.id)
    for _, s in ipairs({ d.name, d.desc, type(d.news) == "string" and d.news or "" }) do
      H.ok(not s:lower():find("first to"), "no race wording: " .. s)
      H.ok(not s:lower():find("guild first"), "no race wording: " .. s)
    end
  end
  for _, c in ipairs(A.CATEGORIES) do H.ok((cats[c.key] or 0) > 0, "category " .. c.label) end
  H.eq(#A.CATEGORIES, 5)
  H.ok(A.byId.pTa and A.byId.cMAGE == nil and A.byId.c60MAGE, "professions + class 60s")
end)

H.test("backfill from existing data is quiet; later earns post news", function()
  local ns = boot()
  local A = ns.Achievements
  setSkill("Tailoring", 300)
  A.Scan()
  H.ok(A.IsEarned("pTa"), "300 Tailoring earned from the skill line")
  H.ok(ns.char.achQ.pTa, "quiet during backfill")
  H.ok(ns.char.ach.lv10, "level 10 backfilled")
  ns.News.Rebuild()
  H.eq(newsOf(ns, "pTa"), nil, "no news for backfilled achievements")
  settle(ns)
  setSkill("Riding", 75)
  H.eq(A.Scan(), 1)
  H.ok(A.IsEarned("ride75"))
  H.eq(A.IsEarned("ride150"), nil)
  ns.News.Rebuild()
  local e = newsOf(ns, "ride75", ns.playerKey)
  H.ok(e, "achievement news line")
  H.eq(strip(ns.News.Text(e)), "Testy got their first mount")
  H.eq(A.Scan(), 0, "never earned twice")
end)

H.test("dungeon clears come from the bestiary; misspelled duplicate bosses count once", function()
  local ns = boot()
  local A = ns.Achievements
  local B = ns.Bestiary
  settle(ns)
  local d = A.byId.d389
  H.ok(d and d.need == 4, "Ragefire Chasm: 4 bosses")
  for i, b in ipairs(d.bosses) do
    local m = B.Ensure(90000 + i)
    m.nm, m.cl = b.name, "elite"
    if i < 4 then B.CountKill(H.guid(90000 + i, "B" .. i), 90000 + i) end
  end
  A.Scan()
  H.eq(A.progress.d389.cur, 3, "3 of 4")
  H.eq(A.IsEarned("d389"), nil)
  H.epoch = H.epoch + 60
  B.CountKill(H.guid(90004, "B4"), 90004)
  A.Scan()
  H.eq(A.IsEarned("d389"), math.floor(H.epoch), "dated by the last boss")
  -- anagram typos in the boss list are one boss
  local bs = A.Bosses({ b = { "Gelihast", "Geilhast", "Lorgus Jett" } })
  H.eq(#bs, 2)
  H.ok(bs[1].keys.gelihast and bs[1].keys.geilhast)
  ns.News.Rebuild()
  H.eq(strip(ns.News.Text(newsOf(ns, "d389"))), "Testy cleared Ragefire Chasm")
end)

H.test("epic loot, quests and rares count", function()
  local ns = boot()
  local A = ns.Achievements
  settle(ns)
  H.itemQuality[19019] = 4
  ns.char.lootLog = { { i = 2589, t = H.epoch - 500 }, { i = 19019, t = H.epoch - 300 } }
  ns.char.act = ns.char.act or {}
  ns.char.act.r = 10
  A.Scan()
  H.eq(A.IsEarned("epic"), math.floor(H.epoch - 300), "dated from the loot log")
  H.ok(A.IsEarned("rare1") and A.IsEarned("rare10"))
  H.eq(A.IsEarned("rare25"), nil)
  H.eq(A.progress.rare25.cur, 10)
  H.eq(A.progress.q50.need, 50)
end)

H.test("shared with guildmates, gated by the sharing toggle", function()
  local ns = boot()
  local A = ns.Achievements
  setSkill("Tailoring", 300)
  A.Scan()
  H.advance(40)
  local m = lastOf(ns, "ah")
  H.ok(m and m.d.a.pTa, "published")
  H.ok(m.d.q.pTa, "quiet flag travels so guildmates don't post it either")
  -- validation
  H.eq(A.Validate("junk"), nil)
  local v = A.Validate({ a = { pTa = H.epoch, bogus = H.epoch, lv10 = 5 } })
  H.ok(v.a.pTa and not v.a.bogus and not v.a.lv10, "unknown ids and bad times dropped")
  -- a guildmate's achievements
  H.deliver(ns, "Oakenhollow-Forever", { t = "D", k = "ah", r = H.epoch + 1, d = { a = { pAl = H.epoch - 50, lv10 = H.epoch - 900 } } })
  H.advance(3)
  H.eq(A.CountFor("Oakenhollow-Forever"), 2)
  H.eq(A.CountFor("Nobody-Forever"), nil, "unknown = nil, shown as '-'")
  ns.News.Rebuild()
  local e = newsOf(ns, "pAl", "Oakenhollow-Forever")
  H.eq(strip(ns.News.Text(e)), "Oakenhollow reached 300 Alchemy")
  H.eq(newsOf(ns, "lv10"), nil, "level achievements don't duplicate level-up news")
  -- board + roster
  local rows = ns.News.Board("ach")
  H.ok(#rows >= 2, "achievements board")
  local view = ns.Roster.View({})
  local oak
  for _, r in ipairs(view) do if r.name == "Oakenhollow-Forever" then oak = r end end
  H.eq(oak.ach, 2, "roster count column")
  -- sharing off
  H.sent = {}
  ns.db.settings.shareActivity = false
  H.eq(A.Build(), nil)
  ns.Shared.MarkDirty("ah")
  H.advance(40)
  m = lastOf(ns, "ah")
  H.ok(not (m and m.d and m.d.a), "nothing shared when off")
  for _, r in ipairs(ns.News.Board("ach")) do H.ok(r.name ~= ns.playerKey, "not on the board when off") end
end)

H.test("views render: tab, profile section, ask", function()
  local ns = boot()
  local A = ns.Achievements
  setSkill("Tailoring", 300)
  A.Scan()
  H.tab(ns, "achievements")
  ns.UI.Open("achievements")
  ns.UI.Refresh("achievements")
  local rows = A.Rows(ns.playerKey)
  local headers = 0
  for _, r in ipairs(rows) do if r.header then headers = headers + 1 end end
  H.eq(headers, 5)
  H.eq(#rows, A.TOTAL + 5)
  H.ok(A.DateText(H.epoch, true):find("^~"), "approximate dates marked")
  local ans = ns.Ask.Answer("my achivements")
  H.ok(ans.lines[1].text:find("of " .. A.TOTAL), ans.lines[1].text)
  H.noErrors("achievement views")
end)

H.done()
