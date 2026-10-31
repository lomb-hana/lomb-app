-- LOMB Companion: guild news feed and fun leaderboards.
--
-- Where news comes from:
--   * the guild roster, which every client can read: joins, leaves and level-ups
--     of every member (addon or not). Kept locally; each client sees the same
--     roster, so the same events get the same ids.
--   * each member's own addon (shared dataset "nw"): exact level-up times, rare
--     kills and newly learned recipes.
--   * achievements (shared dataset "ah", see Achievements.lua): "X reached 300
--     Tailoring". Personal ones, earned at your own pace: there are no races.
-- Leaderboards use shared dataset "st": level, kills, rares, whole hours played
-- and this week's kills/rares, plus the achievement count from "ah".
-- These are self-reported and just for fun. No gold, no deaths, no locations.
local _, ns = ...
local C = ns.Compat
local News = ns:NewModule("News")
local V = ns.Shared.V

News.LEVEL_MARKS = { 10, 20, 30, 40, 50, 60 }   -- own level times, kept to date achievements
News.MAX_OWN = 30            -- own events shared
News.MAX_LOCAL = 300         -- roster events kept
News.KEEP_DAYS = 60
News.GROUP_WINDOW = 15 * 60  -- same rare killed by several of us = one news line
News.items = {}              -- the merged feed, newest first
News.TYPES = { lv = true, rare = true, rc = true, join = true, left = true, ach = true }
News.FILTERS = {
  { key = nil,    label = "All news" },
  { key = "lv",   label = "Level-ups" },
  { key = "rare", label = "Rare kills" },
  { key = "ach",  label = "Achievements" },
  { key = "rc",   label = "New recipes" },
  { key = "gl",   label = "Joins & leaves" },
}

-- US weekly reset: Tuesday 15:00 UTC. Week numbers count from Tue 6 Jan 1970.
local WEEK_ANCHOR, WEEK = 5 * 86400 + 15 * 3600, 7 * 86400
function News.WeekId(t) return math.floor(((t or time()) - WEEK_ANCHOR) / WEEK) end
function News.WeekStart(t) return WEEK_ANCHOR + News.WeekId(t) * WEEK end

local function day(t) return math.floor((t or time()) / 86400) end

-- Same event, same id, whoever saw it.
function News.Id(ty, who, a, t)
  if ty == "join" or ty == "left" then return ("%s:%s:%d"):format(ty, who, day(t)) end
  if ty == "rare" then return ("rare:%s:%s:%d"):format(who, tostring(a), day(t)) end
  return ("%s:%s:%s"):format(ty, who, tostring(a or ""))
end

---------------------------------------------------------------------------
-- Our own activity (per character)
---------------------------------------------------------------------------
local function act()
  local a = ns.char.act
  if type(a) ~= "table" then
    a = {}
    ns.char.act = a
  end
  a.lt = a.lt or {}       -- [level 10/20/../60] = epoch reached (dates achievements; never shared)
  a.r = a.r or 0          -- rares killed
  a.ev = a.ev or {}       -- own events, newest first: { ty, a, b, t }
  a.wk = a.wk or { w = News.WeekId(), k = 0, r = 0 }
  if a.wk.w ~= News.WeekId() then a.wk = { w = News.WeekId(), k = 0, r = 0 } end
  return a
end
News.Act = act

local function sharing() return ns.db.settings.shareActivity ~= false end

function News.AddOwn(ty, a, b, t)
  local s = act()
  t = t or time()
  table.insert(s.ev, 1, { ty, a, b, t })
  while #s.ev > News.MAX_OWN do table.remove(s.ev) end
  ns.Shared.MarkDirty("nw")
  News.RebuildSoon()
end

function News.OnLevel(level)
  level = C.Safe(level)
  if type(level) ~= "number" then return end
  local s = act()
  for _, L in ipairs(News.LEVEL_MARKS) do
    if level >= L and not s.lt[L] then s.lt[L] = time() end
  end
  News.AddOwn("lv", level)
  ns.Shared.MarkDirty("st")
end

function News.OnKill(npcId)
  local s = act()
  s.wk.k = s.wk.k + 1
  local m = ns.db.bestiary[npcId]
  local cl = m and m.cl
  if cl == "rare" or cl == "rareelite" then
    s.r = s.r + 1
    s.wk.r = s.wk.r + 1
    News.AddOwn("rare", npcId, m.nm)
  end
  ns.Shared.MarkDirty("st")
end

function News.OnRecipes(_, fresh)
  for _, f in ipairs(fresh or {}) do
    News.AddOwn("rc", f[2], f[1])
  end
end

---------------------------------------------------------------------------
-- Shared datasets
---------------------------------------------------------------------------
function News.BuildStats()
  if not sharing() then return nil end
  local s = act()
  local total = ns.Me.PlayedNow()
  return {
    lv = C.Call(UnitLevel, "player"), k = ns.char.kills or 0, r = s.r,
    pt = (total and ns.db.settings.shareProfile ~= false) and math.floor(total / 3600) or nil,
    wk = { w = s.wk.w, k = s.wk.k, r = s.wk.r },
  }
end

function News.ValidateStats(d)
  if type(d) ~= "table" then return nil end
  local out = {
    lv = V.int(d.lv, 1, 100), k = V.int(d.k, 0, 1e8) or 0, r = V.int(d.r, 0, 1e6) or 0,
    pt = V.int(d.pt, 0, 1e6),
  }
  -- d.lt (milestone times from 0.9.1 and older) is ignored: there are no races any more
  if type(d.wk) == "table" and V.int(d.wk.w, 0, 1e5) then
    out.wk = { w = d.wk.w, k = V.int(d.wk.k, 0, 1e7) or 0, r = V.int(d.wk.r, 0, 1e6) or 0 }
  end
  return out
end

function News.BuildEvents()
  if not sharing() then return nil end
  local s, out, cutoff = act(), {}, time() - 30 * 86400
  for _, e in ipairs(s.ev) do
    if e[4] >= cutoff then out[#out + 1] = { e[1], e[2], e[3], e[4] } end
  end
  return { e = out }
end

function News.ValidateEvents(d)
  if type(d) ~= "table" or type(d.e) ~= "table" then return nil end
  local out = {}
  for i, e in ipairs(d.e) do
    if i > News.MAX_OWN then break end
    if type(e) == "table" then
      local ty, t = e[1], V.time(e[4])
      local a = V.int(e[2], 0, 1e7)
      local ok = t and a and (ty == "lv" or ty == "rare" or ty == "rc")
      if ok and ty == "lv" and a > 100 then ok = false end
      if ok then
        local b = e[3]
        if ty == "rc" then b = (b == "i" or b == "s") and b or "i" else b = V.str(b, 48) end
        out[#out + 1] = { ty, a, b, t }
      end
    end
  end
  return { e = out }
end

---------------------------------------------------------------------------
-- Roster events (local)
---------------------------------------------------------------------------
local function guild() return ns.DB.Guild() end

function News.AddLocal(ty, who, a, b, t, away)
  local g = guild()
  if not g then return end
  g.news = g.news or {}
  t = t or time()
  local id = News.Id(ty, who, a, t)
  if g.news[id] then return end
  g.news[id] = { ty = ty, w = who, a = a, b = b, t = t, x = away or nil }
  News.RebuildSoon()
end

function News.PruneLocal()
  local g = guild()
  if not g or not g.news then return end
  local list, cutoff = {}, time() - News.KEEP_DAYS * 86400
  for id, e in pairs(g.news) do
    if (e.t or 0) < cutoff then g.news[id] = nil else list[#list + 1] = { id, e.t } end
  end
  if #list > News.MAX_LOCAL then
    table.sort(list, function(x, y) return x[2] > y[2] end)
    for i = News.MAX_LOCAL + 1, #list do g.news[list[i][1]] = nil end
  end
end

ns:Listen("GUILD_JOIN", function(who) News.AddLocal("join", who) end)
ns:Listen("GUILD_LEAVE", function(who) News.AddLocal("left", who) end)
ns:Listen("GUILD_LEVELUP", function(who, newLevel, _, classFile, away)
  News.AddLocal("lv", who, newLevel, classFile, nil, away)
end)

local function classOf(name)
  local row = ns.Roster.byName[name]
  if row and row.class then return row.class end
  local g = guild()
  local mem = g and g.members[name]
  if mem and mem.class then return mem.class end
  local st = ns.Shared.Get("st", name)
  return st and st.cl
end
News.ClassOf = classOf

---------------------------------------------------------------------------
-- The merged feed
---------------------------------------------------------------------------
function News.Rebuild()
  local byId, items = {}, {}
  local function add(ty, who, a, b, t, away)
    if not News.TYPES[ty] or not who or not t then return end
    local id = News.Id(ty, who, a, t)
    local cur = byId[id]
    if cur then
      -- prefer the member's own exact report over a roster sighting
      if cur.x and not away then cur.t, cur.x = t, nil end
      return
    end
    local e = { id = id, ty = ty, who = who, a = a, b = b, t = t, x = away or nil }
    byId[id] = e
    items[#items + 1] = e
  end
  -- our own straight away (before / without publishing)
  for _, e in ipairs(act().ev) do add(e[1], ns.playerKey, e[2], e[3], e[4]) end
  for owner, d in ns.Shared.Each("nw") do
    for _, e in ipairs(d.e or {}) do add(e[1], owner, e[2], e[3], e[4]) end
  end
  local g = guild()
  if g and g.news then
    for _, e in pairs(g.news) do add(e.ty, e.w, e.a, e.b, e.t, e.x) end
  end
  -- achievements (theirs and ours), recent ones only
  local A, cutoff = ns.Achievements, time() - News.KEEP_DAYS * 86400
  for _, e in ipairs(A and A.NewsItems() or {}) do
    if e.t >= cutoff then add("ach", e.who, e.id, nil, e.t) end
  end
  table.sort(items, function(x, y)
    if x.t ~= y.t then return x.t > y.t end
    return x.id < y.id
  end)
  -- group the same rare killed by several guildmates close together
  local out, lastRare = {}, {}
  for _, e in ipairs(items) do
    local prev = e.ty == "rare" and lastRare[e.a]
    if prev and prev.t - e.t <= News.GROUP_WINDOW then
      prev.with = prev.with or {}
      prev.with[#prev.with + 1] = e.who
    else
      out[#out + 1] = e
      if e.ty == "rare" then lastRare[e.a] = e end
    end
  end
  News.items = out
  News.UpdateBadge()
  ns:Fire("NEWS_UPDATED")
  return out
end
News.RebuildSoon = ns.Debounce(1, function() News.Rebuild() end)

function News.Filter(key)
  if not key then return News.items end
  local out = {}
  for _, e in ipairs(News.items) do
    if e.ty == key or (key == "gl" and (e.ty == "join" or e.ty == "left")) then out[#out + 1] = e end
  end
  return out
end

-- unread = news about someone else since you last opened the News tab
function News.Unread()
  local g = guild()
  local seen = g and g.newsSeen or 0
  local n = 0
  for _, e in ipairs(News.items) do
    if e.t <= seen then break end
    if e.who ~= ns.playerKey then n = n + 1 end
  end
  return n
end

function News.MarkSeen()
  local g = guild()
  if g then g.newsSeen = time() end
  News.UpdateBadge()
end

function News.UpdateBadge()
  if not ns.UI or not ns.UI.SetBadge then return end
  local n = News.Unread()
  ns.UI.SetBadge("news", n > 0 and (n > 99 and "99+" or tostring(n)) or nil)
end

---------------------------------------------------------------------------
-- Leaderboards
---------------------------------------------------------------------------
News.BOARDS = {
  { key = "level",  label = "Levels",   weekly = false },
  { key = "kills",  label = "Kills",    weekly = true },
  { key = "rares",  label = "Rares",    weekly = true },
  { key = "played", label = "Played",   weekly = false },
  { key = "ach",    label = "Achievements", weekly = false },
}

-- rows: { name, class, value, text } best first
function News.Board(key, weekly)
  local rows = {}
  local week = News.WeekId()
  if key == "level" then
    local seen = {}
    for _, r in ipairs(ns.Roster.members) do
      if type(r.level) == "number" then
        seen[r.name] = true
        rows[#rows + 1] = { name = r.name, class = r.class, value = r.level }
      end
    end
    for name, st in ns.Shared.Each("st") do
      if not seen[name] and st.lv then rows[#rows + 1] = { name = name, class = classOf(name), value = st.lv } end
    end
  elseif key == "ach" then
    local A = ns.Achievements
    local seen = {}
    local mine = A and A.CountFor(ns.playerKey)
    if mine and mine > 0 and ns.db.settings.shareActivity ~= false then
      seen[ns.playerKey] = true
      rows[#rows + 1] = { name = ns.playerKey, class = classOf(ns.playerKey), value = mine }
    end
    for name in ns.Shared.Each("ah") do
      local n = not seen[name] and A.CountFor(name)
      if n and n > 0 then rows[#rows + 1] = { name = name, class = classOf(name), value = n } end
    end
  else
    for name, st in ns.Shared.Each("st") do
      local v
      if key == "kills" then v = weekly and (st.wk and st.wk.w == week and st.wk.k or 0) or st.k
      elseif key == "rares" then v = weekly and (st.wk and st.wk.w == week and st.wk.r or 0) or st.r
      elseif key == "played" then v = st.pt end
      if v and v > 0 then rows[#rows + 1] = { name = name, class = classOf(name), value = v, tie = 0 } end
    end
  end
  table.sort(rows, function(x, y)
    if x.value ~= y.value then return x.value > y.value end
    if (x.tie or 0) ~= (y.tie or 0) then return (x.tie or 0) < (y.tie or 0) end
    return x.name < y.name
  end)
  local rank, prev = 0, nil
  for i, row in ipairs(rows) do
    if not prev or row.value ~= prev then rank = i end
    row.rank, prev = rank, row.value
  end
  return rows
end

---------------------------------------------------------------------------
function News:Init()
  ns.Shared.Define({
    kind = "st", label = "stats", debounce = 120,
    enabled = sharing, build = News.BuildStats, validate = News.ValidateStats,
    onChange = function() News.RebuildSoon(); ns:Fire("BOARD_UPDATED") end,
  })
  ns.Shared.Define({
    kind = "nw", label = "news",
    enabled = sharing, build = News.BuildEvents, validate = News.ValidateEvents,
    onChange = function() News.RebuildSoon() end,
  })
end

function News:Login()
  act()
  -- 0.9.1 and older kept roster sightings for the "first to N" races: no longer used
  local g = guild()
  if g then g.reach = nil end
  News.PruneLocal()
  News.Rebuild()
  ns.Every(3600, News.PruneLocal)
  ns.Every(60, function() if act().wk.w ~= News.WeekId() then ns.Shared.MarkDirty("st"); ns:Fire("BOARD_UPDATED") end end)
end

ns:On("PLAYER_LEVEL_UP", function(_, level) News.OnLevel(level) end)
ns:Listen("KILL_RECORDED", function(npcId) News.OnKill(npcId) end)
ns:Listen("RECIPES_LEARNED", News.OnRecipes)
ns:Listen("ROSTER_UPDATED", function() News.RebuildSoon(); ns:Fire("BOARD_UPDATED") end)
ns:Listen("PROFILE_CHANGED", function() ns.Shared.MarkDirty("st") end)

---------------------------------------------------------------------------
-- Text for one feed line (UI + tests)
---------------------------------------------------------------------------
local function who(name)
  local short = C.ShortName(name)
  local cl = classOf(name)
  if cl and ns.Theme and ns.Theme.classColorText then return ns.Theme.classColorText(cl, short) end
  return short
end

local function mobName(npcId, fallback)
  local m = ns.db.bestiary[npcId]
  return (m and m.nm) or fallback or ("rare #" .. tostring(npcId))
end

function News.Text(e)
  local n = who(e.who)
  if e.ty == "lv" then
    return ("%s reached level |cfff2c75c%d|r"):format(n, e.a)
  elseif e.ty == "ach" then
    local A = ns.Achievements
    local t = A and A.NewsText(e.a)
    return t and ("%s %s"):format(n, t) or n
  elseif e.ty == "rare" then
    local names = { n }
    for _, w in ipairs(e.with or {}) do names[#names + 1] = who(w) end
    local list = #names == 1 and names[1]
      or (table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names])
    return ("%s killed the rare |cffb873ff%s|r"):format(list, mobName(e.a, e.b))
  elseif e.ty == "rc" then
    local name
    if e.b == "s" then name = C.SpellName(e.a) else name = C.ItemInfo(e.a) end
    return ("%s learned to make %s"):format(n, name and ("|cffe6e0f0" .. name .. "|r") or ("#" .. tostring(e.a)))
  elseif e.ty == "join" then
    return ("%s joined the guild. Say hi!"):format(n)
  elseif e.ty == "left" then
    return ("%s left the guild"):format(n)
  end
  return n
end

function News.Ago(t, now)
  local d = (now or time()) - t
  if d < 60 then return "just now" end
  if d < 3600 then return ("%dm ago"):format(math.floor(d / 60)) end
  if d < 86400 then return ("%dh ago"):format(math.floor(d / 3600)) end
  if d < 7 * 86400 then return ("%dd ago"):format(math.floor(d / 86400)) end
  return date("%b %d", t)
end
