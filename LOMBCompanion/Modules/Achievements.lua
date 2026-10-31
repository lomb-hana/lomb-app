-- LOMB Companion: personal achievements anyone can earn at their own pace.
--
-- No races and no "first to": every achievement is about your own character
-- (or, for "Level 60 <Class>", your own account), so a guildmate earning one
-- never takes anything away from you.
--
-- Saved shape:
--   ns.char.ach   = { [id] = epoch earned }   this character
--   ns.char.achX  = { [id] = true }           the date is approximate (backfilled)
--   ns.char.achQ  = { [id] = true }           earned before this version: no news line
--   ns.db.achAcct = { [id] = { t = epoch, by = "Name-Realm", x = true|nil } }   "Level 60 <Class>"
-- Shared dataset "ah" (gated by Settings > Share activity, like news and stats):
--   { a = { [id] = epoch }, x = { [id] = 1 }, q = { [id] = 1 } }
-- Everything is worked out from things the addon can read: levels, skill lines,
-- the bestiary (your own kills), the loot log, equipped gear, quest history and
-- event attendance. Nothing is guessed: if it can't be read, it isn't an achievement.
local _, ns = ...
local C = ns.Compat
local A = ns:NewModule("Achievements")
local V = ns.Shared.V

A.MAX_LEVEL = 60
A.SEED_SECONDS = 180     -- after the first login with achievements: earn quietly (no news)
A.ZONE_MIN_KNOWN = 10    -- a zone needs at least this many known creatures to count
A.MAX_SHARED = 120

A.CATEGORIES = {
  { key = "lv", label = "Leveling" },
  { key = "pr", label = "Professions" },
  { key = "dg", label = "Dungeons" },
  { key = "ex", label = "Exploration & Bestiary" },
  { key = "gl", label = "Guild life" },
}

A.ICONS = {
  lv = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
  cls = "Interface\\Icons\\INV_Misc_Trophy_03",
  ride = "Interface\\Icons\\Ability_Mount_RidingHorse",
  pr = "Interface\\Icons\\Trade_BlackSmithing",
  dg = "Interface\\Icons\\INV_Misc_Key_03",
  raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
  epic = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02",
  set = "Interface\\Icons\\INV_Chest_Chain_05",
  rare = "Interface\\Icons\\Ability_Hunter_SniperShot",
  zone = "Interface\\Icons\\INV_Misc_Map_01",
  quest = "Interface\\Icons\\INV_Misc_Note_01",
  event = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
}

A.CLASSES = {
  { "WARRIOR", "Warrior" }, { "PALADIN", "Paladin" }, { "HUNTER", "Hunter" }, { "ROGUE", "Rogue" },
  { "PRIEST", "Priest" }, { "SHAMAN", "Shaman" }, { "MAGE", "Mage" }, { "WARLOCK", "Warlock" },
  { "DRUID", "Druid" },
}
-- Classic professions (Jewelcrafting and Inscription aren't in the game).
A.PROFESSIONS = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Leatherworking",
  "Mining", "Skinning", "Tailoring", "Cooking", "First Aid", "Fishing" }
A.PROF_MAX = 300

local function squash(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
-- "Gelihast" and "Geilhast" (both in the dungeon list) are one boss: same letters.
local function letters(s)
  local t = {}
  for ch in squash(s):gmatch(".") do t[#t + 1] = ch end
  table.sort(t)
  return table.concat(t)
end

---------------------------------------------------------------------------
-- Definitions. Each: id, cat, name, desc, icon, news (text after the name;
-- false = no news line), need (target), acct (account-wide), and
-- value(ctx) -> current, date(ctx) -> epoch, approx when it can be dated.
---------------------------------------------------------------------------
A.list, A.byId = {}, {}
local function def(d)
  d.need = d.need or 1
  A.list[#A.list + 1] = d
  A.byId[d.id] = d
  return d
end

local function plural(n, one, many) return n == 1 and one or many end

-- Leveling
for _, L in ipairs({ 10, 20, 30, 40, 50, 60 }) do
  def({ id = "lv" .. L, cat = "lv", name = "Level " .. L, desc = ("Reach level %d."):format(L), icon = A.ICONS.lv,
    need = L, news = false, -- the level-up line in News already says it
    value = function(ctx) return ctx.level end,
    date = function(ctx)
      local t = ctx.levelAt[L]
      if t then return t, t <= (ns.char.firstLogin or 0) end
    end })
end
for _, c in ipairs(A.CLASSES) do
  local file, label = c[1], c[2]
  def({ id = "c60" .. file, cat = "lv", name = "Level 60 " .. label, acct = true, icon = A.ICONS.cls,
    desc = ("Take a %s to level 60. Any of your characters counts."):format(label), need = 1,
    news = "reached level 60 on a " .. label,
    value = function(ctx) return ctx.max60[file] and 1 or 0 end,
    date = function(ctx) local m = ctx.max60[file]; if m then return m.t, m.x end end })
end
def({ id = "ride75", cat = "lv", name = "First mount", desc = "Learn Riding (75 skill).", icon = A.ICONS.ride,
  need = 75, news = "got their first mount", value = function(ctx) return ctx.riding end })
def({ id = "ride150", cat = "lv", name = "Epic mount", desc = "Learn Riding up to 150.", icon = A.ICONS.ride,
  need = 150, news = "can ride an epic mount", value = function(ctx) return ctx.riding end })

-- Professions
for _, p in ipairs(A.PROFESSIONS) do
  def({ id = "p" .. (ns.Me.CODES[p] or p), cat = "pr", name = A.PROF_MAX .. " " .. p, prof = p,
    desc = ("Reach %d in %s."):format(A.PROF_MAX, p), icon = A.ICONS.pr, need = A.PROF_MAX,
    news = ("reached %d %s"):format(A.PROF_MAX, p),
    value = function(ctx) local r = ctx.profs[p]; return r and r.rank or nil end })
end

-- Dungeons: every boss of each instance in the bundled dungeon list
function A.Bosses(dg)
  local out, seen = {}, {}
  for _, b in ipairs(dg and dg.b or {}) do
    local k = letters(b)
    if k ~= "" and not seen[k] then
      seen[k] = #out + 1
      out[#out + 1] = { name = b, keys = { [squash(b)] = true } }
    elseif k ~= "" then
      out[seen[k]].keys[squash(b)] = true
    end
  end
  return out
end

local function dungeonList()
  local d = ns.FDBData
  local list = {}
  for did, dg in pairs(d and d.dungeons or {}) do
    if dg.n and dg.b and #dg.b > 0 then list[#list + 1] = { did = did, dg = dg } end
  end
  table.sort(list, function(x, y)
    if (x.dg.k == "raid") ~= (y.dg.k == "raid") then return x.dg.k ~= "raid" end
    if (x.dg.lv or 0) ~= (y.dg.lv or 0) then return (x.dg.lv or 0) < (y.dg.lv or 0) end
    return x.dg.n < y.dg.n
  end)
  return list
end

for _, e in ipairs(dungeonList()) do
  local did, dg = e.did, e.dg
  local bosses = A.Bosses(dg)
  local n = #bosses
  local raid = dg.k == "raid"
  def({ id = "d" .. did, cat = "dg", name = dg.n, did = did, icon = raid and A.ICONS.raid or A.ICONS.dg,
    desc = n == 1 and ("Defeat %s."):format(bosses[1].name)
      or ("Defeat all %d bosses of %s."):format(n, dg.n),
    need = n, news = (raid and "defeated %s" or "cleared %s"):format(n == 1 and bosses[1].name or dg.n),
    bosses = bosses,
    value = function(ctx)
      local k = 0
      for _, b in ipairs(bosses) do if ctx.killedBoss(b) then k = k + 1 end end
      return k
    end,
    date = function(ctx)
      local last
      for _, b in ipairs(bosses) do
        local t = ctx.killedBoss(b)
        if type(t) ~= "number" then return nil end
        if not last or t > last then last = t end
      end
      return last, false
    end })
end
def({ id = "epic", cat = "dg", name = "Purple!", desc = "Loot or equip your first epic item.", icon = A.ICONS.epic,
  news = "found their first epic item",
  value = function(ctx) return ctx.epic and 1 or 0 end,
  date = function(ctx) if ctx.epic then return ctx.epic.t, ctx.epic.x end end })
def({ id = "set", cat = "dg", name = "Dressed for the part", desc = "Wear every piece of a gear set.",
  icon = A.ICONS.set, news = "is wearing a full gear set",
  value = function(ctx) return ctx.fullSet and 1 or 0 end })

-- Exploration & Bestiary
for _, n in ipairs({ 1, 10, 25 }) do
  def({ id = "rare" .. n, cat = "ex", name = n == 1 and "Rare sighting" or ("Rare hunter " .. n),
    desc = ("Kill %d rare %s."):format(n, plural(n, "creature", "creatures")), icon = A.ICONS.rare, need = n,
    news = n == 1 and "killed their first rare" or ("has killed %d rares"):format(n),
    value = function(ctx) return ctx.rares end })
end
def({ id = "zone75", cat = "ex", name = "Zone naturalist",
  desc = ("Kill 75%% of the creatures the bestiary knows in one zone (%d or more known)."):format(A.ZONE_MIN_KNOWN),
  icon = A.ICONS.zone, need = 75, news = "knows a zone's wildlife by heart",
  value = function(ctx) return ctx.zoneBest end })
def({ id = "zone100", cat = "ex", name = "Zone complete",
  desc = ("Kill every creature the bestiary knows in one zone (%d or more known)."):format(A.ZONE_MIN_KNOWN),
  icon = A.ICONS.zone, need = 100, news = "completed a zone's bestiary",
  value = function(ctx) return ctx.zoneBest end })
for _, n in ipairs({ 50, 250 }) do
  def({ id = "q" .. n, cat = "ex", name = ("%d quests"):format(n), desc = ("Complete %d quests."):format(n),
    icon = A.ICONS.quest, need = n, news = ("has completed %d quests"):format(n),
    value = function(ctx) return ctx.quests end,
    date = function(ctx) local t = ctx.questAt(n); if t then return t, false end end })
end

-- Guild life
for _, n in ipairs({ 1, 5, 20 }) do
  def({ id = "ev" .. n, cat = "gl", name = n == 1 and "Showed up" or ("Regular " .. n),
    desc = ("Attend %d guild %s."):format(n, plural(n, "event", "events")), icon = A.ICONS.event, need = n,
    news = n == 1 and "attended their first guild event" or ("has attended %d guild events"):format(n),
    value = function(ctx) return ctx.events end,
    date = function(ctx) local t = ctx.eventAt[n]; if t then return t, false end end })
end

A.TOTAL = #A.list

---------------------------------------------------------------------------
-- Reading the game (one context per scan)
---------------------------------------------------------------------------
local function store()
  local c = ns.char
  c.ach = type(c.ach) == "table" and c.ach or {}
  c.achX = type(c.achX) == "table" and c.achX or {}
  c.achQ = type(c.achQ) == "table" and c.achQ or {}
  ns.db.achAcct = type(ns.db.achAcct) == "table" and ns.db.achAcct or {}
  return c.ach, c.achX, c.achQ, ns.db.achAcct
end
A.Store = store

local function myKills()
  local key = ns.playerKey
  local byName, rares, mine = {}, 0, {}
  for npcId, m in pairs(ns.db.bestiary or {}) do
    local r = m.rec and m.rec[key]
    if r and (r.k or 0) > 0 then
      mine[npcId] = m
      local n = squash(m.nm)
      if n ~= "" then
        local cur = byName[n]
        local t = r.fk or true
        if cur == nil or cur == true or (type(t) == "number" and t < cur) then byName[n] = t end
      end
      if m.cl == "rare" or m.cl == "rareelite" then rares = rares + r.k end
    end
  end
  return byName, rares, mine
end

-- best zone completion (percent of known creatures you've killed), only zones you've hunted in
local function zoneBest(mine)
  local B = ns.Bestiary
  if not (B and B.ZoneStats) then return 0 end
  local count = {}
  for _, m in pairs(mine) do for z in pairs(m.z or {}) do count[z] = (count[z] or 0) + 1 end end
  local best = 0
  for z, n in pairs(count) do
    if n >= A.ZONE_MIN_KNOWN * 0.75 then
      local st = B.ZoneStats(z)
      if st.known >= A.ZONE_MIN_KNOWN then
        local pct = math.floor(100 * st.mine / st.known)
        if pct > best then best = pct end
      end
    end
  end
  return best
end

local function epicFound()
  local Loot = ns.Loot
  local q = Loot and Loot.Quality or function() return nil end
  local first
  for _, e in ipairs(ns.char.lootLog or {}) do
    if e.i and (q(e.i) or 0) >= 4 and (not first or (e.t or 0) < first.t) then first = { t = e.t or time() } end
  end
  if first then return first end
  for slot = 1, 19 do
    local id = C.ItemIdFromLink(C.Call(GetInventoryItemLink, "player", slot))
    if id and (q(id) or 0) >= 4 then return { t = time(), x = true } end
  end
end

local function fullSet()
  local G, d = ns.Guides, ns.FDBData
  if not (G and G.SetProgress) then return false end
  for _, s in pairs(d and d.itemsets or {}) do
    if s.i and #s.i > 0 and G.SetProgress(s).equipped >= #s.i then return true end
  end
  return false
end

-- past guild events you were present at, oldest first: [n] = start time of the nth
local function attended()
  local E = ns.Events
  local out = {}
  if not (E and E.List and E.Attendance) then return out, 0 end
  local me = C.ShortName(ns.playerKey or "")
  local list = E.List("past")
  for i = #list, 1, -1 do
    local rec = list[i]
    if rec.ct == "GUILD_EVENT" then
      for _, r in ipairs(E.Attendance(rec.k).rows) do
        if r.name == me and r.present then out[#out + 1] = rec.start; break end
      end
    end
  end
  return out, #out
end

local function max60(level, classFile)
  local out = {}
  for id, a in pairs(select(4, store())) do
    local file = id:match("^c60(%u+)$")
    if file then out[file] = { t = a.t, x = a.x } end
  end
  if (level or 0) >= A.MAX_LEVEL and classFile and not out[classFile] then
    local t = ns.char.act and ns.char.act.lt and ns.char.act.lt[60]
    out[classFile] = { t = t or time(), x = (not t) or t <= (ns.char.firstLogin or 0) }
  end
  -- other characters on this account (seen in any guild)
  for _, g in pairs(ns.db.guilds or {}) do
    for _, c in pairs(g.myChars or {}) do
      if (tonumber(c.lv) or 0) >= A.MAX_LEVEL and c.cl and not out[c.cl] then out[c.cl] = { t = c.at or time(), x = true } end
    end
  end
  return out
end

function A.Context()
  local level = C.Safe(C.Call(UnitLevel, "player"))
  local _, classFile = C.Call(UnitClass, "player")
  local byName, rares, mine = myKills()
  local act = ns.char.act or {}
  local ctx = {
    level = type(level) == "number" and level or 0,
    profs = ns.Me.ReadProfessions(),
    riding = ns.Me.SkillRank and ns.Me.SkillRank("Riding") or nil,
    rares = math.max(rares, tonumber(act.r) or 0),
    levelAt = act.lt or {},
    quests = ns.QuestTrack and ns.QuestTrack.DoneCount and ns.QuestTrack.DoneCount() or 0,
  }
  ctx.max60 = max60(ctx.level, C.Safe(classFile))
  function ctx.killedBoss(b)
    for k in pairs(b.keys) do if byName[k] ~= nil then return byName[k] end end
  end
  ctx.zoneBest = zoneBest(mine)
  ctx.epic = epicFound()
  ctx.fullSet = fullSet()
  ctx.eventAt, ctx.events = attended()
  local done = ns.char.questsDone or {}
  function ctx.questAt(n)
    local ts = {}
    for _, t in pairs(done) do if type(t) == "number" then ts[#ts + 1] = t end end
    if #ts < n then return nil end
    table.sort(ts)
    return ts[n]
  end
  return ctx
end

---------------------------------------------------------------------------
-- Scanning + earning
---------------------------------------------------------------------------
A.progress = {}    -- [id] = { cur, need } for this character (not shared)

local function quietNow()
  local c = ns.char
  if not c.achSeedUntil then c.achSeedUntil = time() + A.SEED_SECONDS end
  return time() < c.achSeedUntil
end

function A.IsEarned(id)
  local own, _, _, acct = store()
  if own[id] then return own[id] end
  return acct[id] and acct[id].t or nil
end

function A.Scan()
  if not (ns.char and ns.db) then return 0 end
  local own, X, Q, acct = store()
  local ctx = A.Context()
  local quiet = quietNow()
  local fresh = 0
  for _, d in ipairs(A.list) do
    local cur = d.value(ctx)
    A.progress[d.id] = { cur = cur, need = d.need }
    local have = d.acct and acct[d.id] or own[d.id]
    if not have and type(cur) == "number" and cur >= d.need then
      local t, approx
      if d.date then t, approx = d.date(ctx) end
      if not t then t, approx = time(), quiet end
      t = math.floor(t)
      if d.acct then
        acct[d.id] = { t = t, by = ns.playerKey, x = approx or nil }
        own[d.id] = (C.Safe(select(2, C.Call(UnitClass, "player"))) == d.id:sub(4)) and t or nil
      else
        own[d.id] = t
      end
      if approx then X[d.id] = true end
      if quiet then Q[d.id] = true end
      fresh = fresh + 1
      if not quiet then
        ns:Fire("ACHIEVEMENT_EARNED", d.id)
        if ns.Print then ns.Print("Achievement earned: |cfff2c75c%s|r", d.name) end
      end
    end
  end
  if fresh > 0 then
    ns.Shared.MarkDirty("ah")
    if ns.News and ns.News.RebuildSoon then ns.News.RebuildSoon() end
    ns:Fire("ACHIEVEMENTS_UPDATED")
  end
  return fresh
end
A.ScanSoon = ns.Debounce(3, function() ns.SafeCall(A.Scan) end)

---------------------------------------------------------------------------
-- Shared dataset "ah"
---------------------------------------------------------------------------
local function sharing() return ns.db.settings.shareActivity ~= false end

-- Account-wide ones show on an alt only once you've linked it (picked a main),
-- so achievements never reveal which characters share an account.
local function shareAcct(a)
  if a.by == ns.playerKey then return true end
  local P = ns.Profiles
  return P and P.MyMain and P.MyMain() ~= nil
end

-- { [id] = { t, x, q } } for this character, account-wide ones included
function A.Mine()
  local own, X, Q, acct = store()
  local out = {}
  for id, t in pairs(own) do if A.byId[id] then out[id] = { t = t, x = X[id], q = Q[id] } end end
  for id, a in pairs(acct) do
    if A.byId[id] and not out[id] and shareAcct(a) then out[id] = { t = a.t, x = a.x or X[id], q = Q[id] } end
  end
  return out
end

function A.Build()
  if not sharing() then return nil end
  local out = { a = {}, x = {}, q = {} }
  for id, e in pairs(A.Mine()) do
    out.a[id] = e.t
    if e.x then out.x[id] = 1 end
    if e.q then out.q[id] = 1 end
  end
  return out
end

function A.Validate(d)
  if type(d) ~= "table" or type(d.a) ~= "table" then return nil end
  local out, n = { a = {}, x = {}, q = {} }, 0
  local x = type(d.x) == "table" and d.x or {}
  local q = type(d.q) == "table" and d.q or {}
  for id, t in pairs(d.a) do
    if type(id) == "string" and A.byId[id] and V.time(t) and n < A.MAX_SHARED then
      n = n + 1
      out.a[id] = t
      if x[id] then out.x[id] = 1 end
      if q[id] then out.q[id] = 1 end
    end
  end
  return out
end

-- { [id] = { t, x, q } } for anyone, or nil when we know nothing (no addon / sharing off)
function A.For(name)
  if name == ns.playerKey then return A.Mine() end
  local d = ns.Shared.Get("ah", name)
  if not d then return nil end
  local out = {}
  for id, t in pairs(d.a or {}) do out[id] = { t = t, x = d.x and d.x[id], q = d.q and d.q[id] } end
  return out
end

function A.CountFor(name)
  local e = A.For(name)
  if not e then return nil end
  local n = 0
  for _ in pairs(e) do n = n + 1 end
  return n
end

-- Earned, newest first: { {def, t, x} }
function A.Earned(name)
  local out = {}
  for id, e in pairs(A.For(name) or {}) do out[#out + 1] = { def = A.byId[id], t = e.t, x = e.x } end
  table.sort(out, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.def.id < b.def.id end)
  return out
end

-- Rows for the Achievements view: headers + one row per achievement
function A.Rows(name, cat)
  local earned = A.For(name) or {}
  local isMe = name == ns.playerKey
  local rows = {}
  for _, c in ipairs(A.CATEGORIES) do
    if not cat or cat == c.key then
      local list, got = {}, 0
      for _, d in ipairs(A.list) do
        if d.cat == c.key then
          local e = earned[d.id]
          if e then got = got + 1 end
          local p = isMe and A.progress[d.id] or nil
          list[#list + 1] = { def = d, earned = e ~= nil, t = e and e.t, x = e and e.x,
            cur = p and p.cur, need = d.need }
        end
      end
      rows[#rows + 1] = { header = true, label = c.label, got = got, total = #list }
      for _, r in ipairs(list) do rows[#rows + 1] = r end
    end
  end
  return rows
end

function A.DateText(t, approx)
  if not t then return "" end
  return (approx and "~" or "") .. date("%b %d, %Y", t)
end

-- News line text after the member's name
function A.NewsText(id)
  local d = A.byId[id]
  if not d then return nil end
  if d.news then return d.news end
  return "earned |cfff2c75c" .. d.name .. "|r"
end

-- For News: { {who, id, t} } earned with a date worth announcing
function A.NewsItems()
  local out = {}
  local function add(who, list)
    for id, e in pairs(list or {}) do
      local d = A.byId[id]
      if d and d.news ~= false and not e.q and not e.x then out[#out + 1] = { who = who, id = id, t = e.t } end
    end
  end
  add(ns.playerKey, A.Mine())
  for owner in ns.Shared.Each("ah") do
    if owner ~= ns.playerKey then add(owner, A.For(owner)) end
  end
  return out
end

---------------------------------------------------------------------------
function A:Init()
  ns.Shared.Define({
    kind = "ah", label = "achievements", debounce = 30,
    enabled = sharing, build = A.Build, validate = A.Validate,
    onChange = function()
      if ns.News and ns.News.RebuildSoon then ns.News.RebuildSoon() end
      ns:Fire("ACHIEVEMENTS_UPDATED")
      ns:Fire("BOARD_UPDATED")
    end,
  })
end

function A:Login()
  store()
  ns.After(5, function() ns.SafeCall(A.Scan) end)
  ns.Every(600, A.ScanSoon)
end

ns:On("PLAYER_LEVEL_UP", function() A.ScanSoon() end)
ns:On("SKILL_LINES_CHANGED", function() A.ScanSoon() end)
ns:On("PLAYER_EQUIPMENT_CHANGED", function() A.ScanSoon() end)
ns:On("QUEST_TURNED_IN", function() A.ScanSoon() end)
ns:Listen("KILL_RECORDED", function() A.ScanSoon() end)
ns:On("LOOT_CLOSED", function() A.ScanSoon() end)
ns:Listen("EVENTS_UPDATED", function() A.ScanSoon() end)
