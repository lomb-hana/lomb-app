-- LOMB Companion: rare alerts.
-- When you see a rare (target, mouseover or nameplate) it pops a toast for you
-- and, if "Tell guildmates when I spot a rare" is on, tells the guild:
--   RA  { t="RA", n=npcId, nm=name, lv=level, cl=classification, z=zone, x=, y= }
-- x/y are whole map percents of where YOU are when you spot it (so others can
-- find it). Nothing else about your position is ever sent. Each rare is
-- announced at most once per 10 minutes per person, and several guildmates
-- spotting the same rare shows as one alert.
local _, ns = ...
local C = ns.Compat
local R = ns:NewModule("Rares")

R.SPOT_COOLDOWN = 600     -- seconds before we announce the same rare again
R.ALERT_DEDUPE = 300      -- seconds: the same rare from several guildmates = one alert
R.RECENT_MAX = 10

R.sentAt = {}             -- [npcId] = GetTime() we last announced it
R.alertedAt = {}          -- [npcId] = GetTime() we last showed an alert for it
R.recent = {}             -- newest first: { n, nm, lv, cl, z, x, y, by, t }

local function S() return ns.db.settings end

-- What we can safely read about a unit if it's a living rare creature.
function R.ReadUnit(unit)
  if not C.Call(UnitExists, unit) or C.Call(UnitIsPlayer, unit) then return nil end
  local cl = C.Call(UnitClassification, unit)
  if not ns.Bestiary.IsRare(cl) then return nil end
  if C.Call(UnitIsDead, unit) then return nil end
  local kind, npcId = C.ParseGUID(C.Call(UnitGUID, unit))
  if kind ~= "Creature" or not npcId then return nil end
  local lv = C.Call(UnitLevel, unit)
  if type(lv) ~= "number" or lv < 1 then lv = nil end
  return { n = npcId, nm = C.Call(UnitName, unit), lv = lv, cl = cl }
end

local function remember(e)
  for i = #R.recent, 1, -1 do
    if R.recent[i].n == e.n then table.remove(R.recent, i) end
  end
  table.insert(R.recent, 1, e)
  while #R.recent > R.RECENT_MAX do table.remove(R.recent) end
  local m = ns.Bestiary.Ensure(e.n)
  if e.nm and not m.nm then m.nm = e.nm end
  if e.cl and not m.cl then m.cl = e.cl end
  if e.lv and (not m.lv or e.lv < m.lv) then m.lv = e.lv end
  if e.z and not m.z[e.z] then
    local n = 0
    for _ in pairs(m.z) do n = n + 1 end
    if n < ns.Bestiary.MAX_ZONES then m.z[e.z] = true end
  end
  m.rs = { t = e.t, by = e.by, z = e.z, x = e.x, y = e.y }   -- local only, never synced
  ns:Fire("BESTIARY_UPDATED", e.n)
  ns:Fire("RARE_SPOTTED", e)
end

function R.Describe(e)
  local where = e.z or "an unknown place"
  if e.x and e.y then where = ("%s (%d, %d)"):format(where, e.x, e.y) end
  local lv = e.lv and (" (level " .. e.lv .. ")") or ""
  return ("|cffb873ff%s|r%s in %s"):format(e.nm or ("rare #" .. e.n), lv, where)
end

-- Show an alert (toast + sound, and a chat line for guildmates' spots).
function R.Alert(e)
  if not S().rareAlerts then return false end
  local nowT = GetTime()
  if R.alertedAt[e.n] and nowT - R.alertedAt[e.n] < R.ALERT_DEDUPE then return false end
  R.alertedAt[e.n] = nowT
  if e.by ~= ns.playerKey then
    ns.Print("%s spotted the rare %s.", C.ShortName(e.by) or "A guildmate", R.Describe(e))
  end
  if C.InEncounter() or C.InPvPMatch() then return true end   -- chat only while busy
  if S().rareSound and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
    C.Call(PlaySound, SOUNDKIT.RAID_WARNING)
  end
  if ns.RareToast then ns.RareToast.Show(e) end
  return true
end

-- We see a unit: is it a rare we should tell people about?
function R.Check(unit)
  local info = R.ReadUnit(unit)
  if not info then return false end
  local nowT = GetTime()
  if R.sentAt[info.n] and nowT - R.sentAt[info.n] < R.SPOT_COOLDOWN then return false end
  R.sentAt[info.n] = nowT
  ns.SafeCall(ns.Bestiary.RecordSighting, ns.Bestiary.Snapshot(unit))
  info.z = ns.Bestiary.ZoneName()
  info.x, info.y = C.PlayerMapPos()
  info.by, info.t = ns.playerKey, time()
  remember(info)
  R.Alert(info)
  if S().shareRares and ns.Sync and ns.Sync.CanSend() then
    ns.Sync.Send({ t = "RA", n = info.n, nm = info.nm, lv = info.lv, cl = info.cl, z = info.z,
      x = info.x, y = info.y }, ns.Queue.ALERT)
  end
  return true
end

local function int(v, lo, hi) return type(v) == "number" and v >= lo and v <= hi and math.floor(v) == v and v or nil end

-- A guildmate spotted a rare.
-- a guildmate's strings get printed and toasted: drop control chars and |escapes
local function clean(v, maxLen)
  if type(v) ~= "string" or #v >= maxLen then return nil end
  v = v:gsub("[%c|]", "")
  return v ~= "" and v or nil
end

function R.OnRemote(sender, d)
  local n = int(d.n, 1, 10000000)
  if not n or sender == ns.playerKey then return false end
  if d.cl ~= "rare" and d.cl ~= "rareelite" then return false end
  local e = {
    n = n, cl = d.cl, by = sender, t = time(),
    nm = clean(d.nm, 80),
    lv = int(d.lv, 1, 100),
    z = clean(d.z, 64),
    x = int(d.x, 0, 100), y = int(d.y, 0, 100),
  }
  if not (e.x and e.y) then e.x, e.y = nil, nil end
  remember(e)
  return R.Alert(e)
end

function R:Init()
  if ns.Sync then ns.Sync.RegisterHandler("RA", R.OnRemote) end
end

ns:On("PLAYER_TARGET_CHANGED", function() R.Check("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() R.Check("mouseover") end)
ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit) if type(unit) == "string" then R.Check(unit) end end)
