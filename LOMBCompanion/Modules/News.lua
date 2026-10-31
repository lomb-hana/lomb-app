-- LOMB Companion: guild news feed and fun leaderboards.
--
-- Where news comes from:
--   * the guild roster, which every client can read: joins, leaves and level-ups
--     of every member (addon or not). Kept locally; each client sees the same
--     roster, so the same events get the same ids.
--   * each member's own addon (shared dataset "nw"): exact level-up times, rare
--     kills and newly learned recipes.
--   * dungeon and raid clears: the last boss of an instance died in front of
--     someone with the addon (Bestiary kill recording); guildmates who were in
--     the same group are named with them, and reports from the same group merge.
--   * guild events that have been held, with how many attended (Events.lua).
-- Leaderboards use shared dataset "st": level, kills, rares, whole hours played
-- and this week's kills/rares.
-- These are self-reported and just for fun. No gold, no deaths, no locations.
local _, ns = ...
local C = ns.Compat
local News = ns:NewModule("News")
local V = ns.Shared.V

News.MAX_OWN = 30            -- own events shared
News.MAX_LOCAL = 300         -- roster events kept
News.KEEP_DAYS = 60
News.GROUP_WINDOW = 15 * 60  -- same rare (or dungeon) by several of us = one news line
News.MAX_NAMES = 5           -- names shown in one dungeon line before "and N more"
News.items = {}              -- the merged feed, newest first
News.TYPES = { lv = true, rare = true, dg = true, rc = true, ev = true, join = true, left = true,
  ep = true, mt = true, wb = true }
News.FILTERS = {
  { key = nil,    label = "All news" },
  { key = "lv",   label = "Level-ups" },
  { key = "rare", label = "Rare kills" },
  { key = "dg",   label = "Dungeons" },
  { key = "rc",   label = "New recipes" },
  { key = "ep",   label = "Epic loot" },
  { key = "mt",   label = "First mounts" },
  { key = "wb",   label = "Welcome backs" },
  { key = "ev",   label = "Guild events" },
  { key = "gl",   label = "Joins & leaves" },
}

-- US weekly reset: Tuesday 15:00 UTC. Week numbers count from Tue 6 Jan 1970.
local WEEK_ANCHOR, WEEK = 5 * 86400 + 15 * 3600, 7 * 86400
function News.WeekId(t) return math.floor(((t or time()) - WEEK_ANCHOR) / WEEK) end

local function day(t) return math.floor((t or time()) / 86400) end

-- Same event, same id, whoever saw it.
function News.Id(ty, who, a, t)
  if ty == "join" or ty == "left" then return ("%s:%s:%d"):format(ty, who, day(t)) end
  if ty == "rare" then return ("rare:%s:%s:%d"):format(who, tostring(a), day(t)) end
  if ty == "ep" then return ("ep:%s:%s:%d"):format(who, tostring(a), day(t)) end
  if ty == "wb" then return ("wb:%s:%d"):format(who, day(t)) end
  if ty == "mt" then return "mt:" .. who end
  if ty == "dg" then return ("dg:%s:%s:%d"):format(who, tostring(a), t or 0) end
  if ty == "ev" then return "ev:" .. tostring(a) end
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
  a.r = a.r or 0          -- rares killed
  a.ev = a.ev or {}       -- own events, newest first: { ty, a, b, t }
  a.wk = a.wk or { w = News.WeekId(), k = 0, r = 0 }
  if a.wk.w ~= News.WeekId() then a.wk = { w = News.WeekId(), k = 0, r = 0 } end
  return a
end
News.Act = act

local function sharing() return ns.db.settings.shareActivity ~= false end

-- x: extra details (dungeon clears: { n = group size, g = { guildmates' short names } })
function News.AddOwn(ty, a, b, t, x)
  local s = act()
  t = t or time()
  table.insert(s.ev, 1, { ty, a, b, t, x })
  while #s.ev > News.MAX_OWN do table.remove(s.ev) end
  ns.Shared.MarkDirty("nw")
  News.RebuildSoon()
end

function News.OnLevel(level)
  level = C.Safe(level)
  if type(level) ~= "number" then return end
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
  News.CheckClear(m and m.nm)
  ns.Shared.MarkDirty("st")
end

---------------------------------------------------------------------------
-- Dungeon and raid clears
---------------------------------------------------------------------------
-- The bundled boss lists aren't in kill order, so each instance's last boss is
-- named here, by dungeon id (Scarlet Monastery: one per wing). A name that isn't
-- in the bundled list is skipped. Forever's own dungeons aren't listed: their
-- last boss isn't known, so they post no clear line.
News.FINAL_BOSSES = {
  [33] = { ["Archmage Arugal"] = true },             -- Shadowfang Keep
  [34] = { ["Bazil Thredd"] = true },                -- Stormwind Stockade
  [36] = { ["Edwin VanCleef"] = true },              -- Deadmines
  [43] = { ["Mutanus the Devourer"] = true },        -- Wailing Caverns
  [47] = { ["Charlga Razorflank"] = true },          -- Razorfen Kraul
  [48] = { ["Aku'mai"] = true },                     -- Blackfathom Deeps
  [90] = { ["Mekgineer Thermaplugg"] = true },       -- Gnomeregan
  [189] = { ["Bloodmage Thalnos"] = "Graveyard", ["Arcanist Doan"] = "Library",
    ["Herod"] = "Armory", ["High Inquisitor Whitemane"] = "Cathedral" },
  [249] = { ["Onyxia"] = true },                     -- Onyxia's Lair
  [389] = { ["Bazzalan"] = true },                   -- Ragefire Chasm
}

local function squash(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end

local finals
-- { [squashed boss name] = { did, wing } }, from the bundled dungeon list
function News.Finals()
  if finals then return finals end
  finals = {}
  local list = ns.FDBData and ns.FDBData.dungeons or {}
  for did, bosses in pairs(News.FINAL_BOSSES) do
    local dg = list[did]
    for _, b in ipairs(dg and dg.b or {}) do
      local wing = bosses[b]
      if wing then finals[squash(b)] = { did = did, wing = wing ~= true and wing or nil } end
    end
  end
  return finals
end

function News.DungeonName(did, wing)
  local dg = ns.FDBData and ns.FDBData.dungeons and ns.FDBData.dungeons[did]
  local n = dg and dg.n or ("dungeon #" .. tostring(did))
  return wing and ("%s (%s)"):format(n, wing) or n
end

-- A boss died that we counted as our (group's) kill: was it the last one?
function News.CheckClear(bossName)
  local f = bossName and News.Finals()[squash(bossName)]
  if not f then return false end
  if C.Call(IsInInstance) == false then return false end   -- same name out in the world
  local mates, size = {}, 1
  if ns.Events and ns.Events.GroupNames then
    local names = ns.Events.GroupNames()
    size = math.max(#names, 1)
    local mine = C.ShortName(ns.playerKey)
    for _, nm in ipairs(names) do
      if nm ~= mine and ns.Events.IsMember(nm) then mates[#mates + 1] = nm end
    end
  end
  News.AddOwn("dg", f.did, f.wing, nil, { n = size, g = mates })
  return true
end

-- Epic loot: "You receive loot: [item]." (the game's own LOOT_ITEM_SELF lines, so
-- won rolls count; crafted and quest-reward items don't). Epic quality or better.
News.EPIC = 4
local function lootPrefix(fmt)
  return type(fmt) == "string" and fmt:match("^(.-)%%s") or nil
end
function News.OnLootMessage(msg)
  if type(msg) ~= "string" or C.IsSecret(msg) then return end
  local mine = false
  for _, fmt in ipairs({ _G.LOOT_ITEM_SELF_MULTIPLE, _G.LOOT_ITEM_SELF }) do
    local pre = lootPrefix(fmt)
    if pre and pre ~= "" and msg:sub(1, #pre) == pre then mine = true; break end
  end
  if not mine then return end
  local link = msg:match("|H(item:[^|]+)|h")
  local id = link and C.ItemIdFromLink(link)
  if not id then return end
  local _, _, quality = C.ItemInfo(id)
  if quality == nil then
    -- not cached yet: the link's own colour says it (epic purple / legendary orange)
    local col = msg:match("|c(%x%x%x%x%x%x%x%x)|Hitem:")
    col = col and col:lower():sub(3)
    quality = (col == "a335ee" and 4) or (col == "ff8000" and 5) or nil
  end
  if type(quality) == "number" and quality >= News.EPIC and quality <= 5 then
    local s, today = act(), day()
    for _, e in ipairs(s.ev) do
      if e[1] == "ep" and e[2] == id and day(e[4]) == today then return end   -- same item again today
    end
    News.AddOwn("ep", id, quality)
  end
end

-- First mount: the riding skill goes from none to learned. The first reading on a
-- character only remembers the skill (no news for riding learned long ago).
function News.CheckRiding(rank)
  if type(rank) ~= "number" then return false end   -- skill lines not readable yet
  local s = act()
  if s.rd == nil then s.rd = rank; return false end
  if s.rd == 0 and rank > 0 then
    s.rd = rank
    News.AddOwn("mt", rank)
    return true
  end
  if rank > s.rd then s.rd = rank end
  return false
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
    if e[4] >= cutoff then out[#out + 1] = { e[1], e[2], e[3], e[4], e[5] } end
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
      local ok = t and a and (ty == "lv" or ty == "rare" or ty == "rc" or ty == "dg" or ty == "ep" or ty == "mt")
      if ok and ty == "lv" and a > 100 then ok = false end
      if ok and ty == "mt" and (a < 1 or a > 375) then ok = false end
      if ok and ty == "ep" and a < 1 then ok = false end
      if ok then
        local b, x = e[3], nil
        if ty == "rc" then b = (b == "i" or b == "s") and b or "i"
        elseif ty == "ep" then b = V.int(b, 4, 5) or 4
        elseif ty == "mt" then b = nil
        else b = V.str(b, 48) end
        if ty == "dg" then
          local wings = News.FINAL_BOSSES[a]
          local known = false
          for _, w in pairs(wings or {}) do if w == b then known = true end end
          b = known and b or nil
          local xd = type(e[5]) == "table" and e[5] or {}
          x = { n = V.int(xd.n, 1, 40) or 1, g = {} }
          for k, nm in ipairs(type(xd.g) == "table" and xd.g or {}) do
            if k > 39 then break end
            nm = V.name(nm)
            if nm then x.g[#x.g + 1] = nm end
          end
        end
        out[#out + 1] = { ty, a, b, t, x }
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
ns:Listen("GUILD_WELCOMEBACK", function(who, days, away)
  News.AddLocal("wb", who, days, nil, nil, away)
end)
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
  local function add(ty, who, a, b, t, away, x)
    if not News.TYPES[ty] or not who or not t then return end
    local id = News.Id(ty, who, a, t)
    local cur = byId[id]
    if cur then
      -- prefer the member's own exact report over a roster sighting
      if cur.x and not away then cur.t, cur.x = t, nil end
      return
    end
    local e = { id = id, ty = ty, who = who, a = a, b = b, t = t, x = away or nil }
    if ty == "dg" then
      e.n, e.mates = type(x) == "table" and x.n or 1, {}
      for _, nm in ipairs(type(x) == "table" and x.g or {}) do e.mates[C.FullName(nm)] = true end
      e.mates[who] = nil
    end
    byId[id] = e
    items[#items + 1] = e
  end
  -- our own straight away (before / without publishing)
  for _, e in ipairs(act().ev) do add(e[1], ns.playerKey, e[2], e[3], e[4], nil, e[5]) end
  for owner, d in ns.Shared.Each("nw") do
    for _, e in ipairs(d.e or {}) do add(e[1], owner, e[2], e[3], e[4], nil, e[5]) end
  end
  local g = guild()
  if g and g.news then
    for _, e in pairs(g.news) do add(e.ty, e.w, e.a, e.b, e.t, e.x) end
  end
  -- guild events that have been held (attendance taken), recent ones only
  local E, now = ns.Events, time()
  if E and E.List and E.Attendance then
    for _, rec in ipairs(E.List("past")) do
      if rec.ct == "GUILD_EVENT" and rec.stop >= now - News.KEEP_DAYS * 86400 then
        local n = E.Attendance(rec.k).present
        if n > 0 then add("ev", rec.by and C.FullName(rec.by) or "?", rec.k, { title = rec.title, n = n }, rec.stop) end
      end
    end
  end
  table.sort(items, function(x, y)
    if x.t ~= y.t then return x.t > y.t end
    return x.id < y.id
  end)
  -- group the same rare killed by several guildmates close together, and
  -- reports of the same clear from people in the same group
  local out, lastRare, lastDg = {}, {}, {}
  local function sameGroup(x, y)
    if x.mates[y.who] or y.mates[x.who] then return true end
    for nm in pairs(y.mates) do if x.mates[nm] then return true end end
    return false
  end
  for _, e in ipairs(items) do
    local prev = e.ty == "rare" and lastRare[e.a]
    local key = e.ty == "dg" and (tostring(e.a) .. ":" .. tostring(e.b or "")) or nil
    local dprev
    for _, d in ipairs(key and lastDg[key] or {}) do
      if d.t - e.t <= News.GROUP_WINDOW and sameGroup(d, e) then dprev = d; break end
    end
    if prev and prev.t - e.t <= News.GROUP_WINDOW then
      prev.with = prev.with or {}
      prev.with[#prev.with + 1] = e.who
    elseif dprev then
      dprev.mates[e.who] = true
      for nm in pairs(e.mates) do dprev.mates[nm] = true end
      dprev.mates[dprev.who] = nil
      dprev.n = math.max(dprev.n, e.n)
    else
      out[#out + 1] = e
      if e.ty == "rare" then lastRare[e.a] = e end
      if key then lastDg[key] = lastDg[key] or {}; table.insert(lastDg[key], e) end
    end
  end
  News.items = out
  News.UpdateBadge()
  ns:Fire("NEWS_UPDATED")
  return out
end
News.RebuildSoon = ns.Debounce(1, function() News.Rebuild() end)

-- Is `name` part of this news line (the one it's about, or in the group)?
function News.Involves(e, name)
  return e.who == name or (e.mates ~= nil and e.mates[name] == true) or false
end

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
  else
    for name, st in ns.Shared.Each("st") do
      local v
      if key == "kills" then v = weekly and (st.wk and st.wk.w == week and st.wk.k or 0) or st.k
      elseif key == "rares" then v = weekly and (st.wk and st.wk.w == week and st.wk.r or 0) or st.r
      elseif key == "played" then v = st.pt end
      if v and v > 0 then rows[#rows + 1] = { name = name, class = classOf(name), value = v } end
    end
  end
  table.sort(rows, function(x, y)
    if x.value ~= y.value then return x.value > y.value end
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
  -- leftovers, never read again: roster sightings and level times for the old
  -- "first to N" races (0.9.1 and older), and the achievements of 0.9.2
  local s, g, c = act(), guild(), ns.char
  s.lt = nil
  c.ach, c.achX, c.achQ, c.achSeedUntil = nil, nil, nil, nil
  ns.db.achAcct = nil
  if g then
    g.reach = nil
    if g.shared then g.shared.ah = nil end
  end
  News.PruneLocal()
  News.Rebuild()
  ns.Every(3600, News.PruneLocal)
  ns.Every(60, function() if act().wk.w ~= News.WeekId() then ns.Shared.MarkDirty("st"); ns:Fire("BOARD_UPDATED") end end)
end

ns:On("PLAYER_LEVEL_UP", function(_, level) News.OnLevel(level) end)
ns:Listen("KILL_RECORDED", function(npcId) News.OnKill(npcId) end)
ns:Listen("RECIPES_LEARNED", News.OnRecipes)
ns:On("CHAT_MSG_LOOT", function(_, msg) News.OnLootMessage(msg) end)
ns:Listen("ME_UPDATED", function(s) if type(s) == "table" then News.CheckRiding(s.riding) end end)
ns:Listen("ATTENDANCE_UPDATED", function() News.RebuildSoon() end)
ns:Listen("EVENTS_UPDATED", function() News.RebuildSoon() end)
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
  elseif e.ty == "dg" then
    local names, others = { n }, {}
    for nm in pairs(e.mates or {}) do others[#others + 1] = nm end
    table.sort(others)
    for _, nm in ipairs(others) do names[#names + 1] = who(nm) end
    local total = #names
    if total > News.MAX_NAMES then
      for k = total, News.MAX_NAMES, -1 do names[k] = nil end
      names[#names + 1] = ("%d more"):format(total - News.MAX_NAMES + 1)
    end
    if (e.n or 1) > total then names[#names + 1] = "party" end
    local list = #names == 1 and names[1]
      or (table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names])
    return ("%s cleared |cfff2c75c%s|r"):format(list, News.DungeonName(e.a, e.b))
  elseif e.ty == "ev" then
    local d = type(e.b) == "table" and e.b or {}
    return ("Guild event |cffe6e0f0%s|r was held: %d attended"):format(d.title or "?", d.n or 0)
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
  elseif e.ty == "ep" then
    local name = C.ItemInfo(e.a)
    local col = e.b == 5 and "ff8000" or "a335ee"
    return ("%s looted the %s |cff%s%s|r"):format(n, e.b == 5 and "legendary" or "epic", col,
      name and ("[" .. name .. "]") or ("item #" .. tostring(e.a)))
  elseif e.ty == "mt" then
    return ("%s learned to ride: first mount!"):format(n)
  elseif e.ty == "wb" then
    return ("%s is back after %d days away. Welcome back!"):format(n, tonumber(e.a) or 14)
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
