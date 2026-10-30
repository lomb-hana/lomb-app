-- LOMB Companion: bestiary recording (sightings, kills, loot, abilities) and the
-- "game" + "guild" data providers.
--
-- Saved shape (LOMBCompanionDB.bestiary[npcId]):
--   nm, lv, lx (max level), cl (classification), ct (creature type), fam,
--   hp (max health seen, only when not secret), fs/ls (first/last seen),
--   z  = { [zoneName] = true }, sp = { [spellID] = spellName },
--   rec = { [recorder "Name-Realm"] = {
--     k  = kills, c = corpses looted, m = copper looted,
--     i  = { [itemID] = times dropped }, q = { [itemID] = total quantity },
--     s  = sightings (different spawns seen), fk = first kill (epoch),
--     t  = last change (epoch) } }
--   rs = { t, by, z, x, y } last time a guildmate spotted it as a rare (local only)
-- Each recorder's entry is only ever replaced by that recorder's newer copy, so
-- syncing is idempotent and the guild total is simply the sum over recorders.
local _, ns = ...
local C = ns.Compat
local B = ns:NewModule("Bestiary")

B.MAX_ITEMS_PER_RECORD = 40
B.MAX_SPELLS = 16
B.MAX_ZONES = 8
B.LOOT_LOG_MAX = 50

B.dirty = {}            -- [npcId] = true -> needs syncing
B.countedGUIDs = {}     -- corpses/kills already counted this session
B.lootedGUIDs = {}
B.seenGUIDs = {}        -- spawns already counted as a sighting this session
B.unattributedLoot = 0  -- loot we couldn't tie to a mob (secret GUID in combat)
B.live = nil            -- live snapshot of the current target
B.pendingTargetRefresh = false

local function now() return time() end

function B.Get(npcId) return ns.db.bestiary[npcId] end

function B.Ensure(npcId)
  local m = ns.db.bestiary[npcId]
  if not m then
    m = { z = {}, sp = {}, rec = {}, fs = now() }
    ns.db.bestiary[npcId] = m
  end
  m.z = m.z or {}
  m.sp = m.sp or {}
  m.rec = m.rec or {}
  return m
end

function B.MyRecord(m, create)
  local key = ns.playerKey
  local r = m.rec[key]
  if not r and create then
    r = { k = 0, c = 0, m = 0, i = {}, q = {}, t = now() }
    m.rec[key] = r
  end
  return r
end

function B.MarkDirty(npcId)
  B.dirty[npcId] = true
  ns:Fire("BESTIARY_UPDATED", npcId)
end

local function zoneName()
  local z = C.Call(GetRealZoneText) or C.Call(GetZoneText)
  if z and z ~= "" then return z end
  return C.MapName(C.PlayerMapID())
end

local function countKeys(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

---------------------------------------------------------------------------
-- Live snapshot of a unit. Values may be secret in combat: the snapshot keeps
-- raw values ONLY under .raw (passed straight to widgets) and stores safe copies.
---------------------------------------------------------------------------
function B.Snapshot(unit)
  unit = unit or "target"
  if not C.Call(UnitExists, unit) then return nil end
  if C.Call(UnitIsPlayer, unit) then return nil end
  local guid = C.Call(UnitGUID, unit)
  local kind, npcId = C.ParseGUID(guid)
  local snap = {
    unit = unit, guid = guid, npcId = npcId, kind = kind,
    name = C.Call(UnitName, unit),
    level = C.Call(UnitLevel, unit),
    classification = C.Call(UnitClassification, unit),
    creatureType = C.Call(UnitCreatureType, unit),
    family = C.Call(UnitCreatureFamily, unit),
    health = C.Call(UnitHealth, unit),
    healthMax = C.Call(UnitHealthMax, unit),
    dead = C.Call(UnitIsDead, unit) and true or false,
    tapDenied = C.Call(UnitIsTapDenied, unit) and true or false,
    canAttack = C.Call(UnitCanAttack, "player", unit) and true or false,
    reaction = C.Call(UnitReaction, unit, "player"),
    raw = {
      name = C.CallRaw(UnitName, unit),
      health = C.CallRaw(UnitHealth, unit),
      healthMax = C.CallRaw(UnitHealthMax, unit),
      level = C.CallRaw(UnitLevel, unit),
    },
    restricted = false,
    at = now(),
  }
  -- If identity is hidden right now (combat secrets), say so; we re-read after combat.
  if guid == nil and C.CallRaw(UnitGUID, unit) ~= nil then snap.restricted = true end
  if snap.level == -1 then snap.level = nil; snap.skull = true end
  return snap
end

-- Record a sighting from a snapshot (only safe values reach the DB).
function B.RecordSighting(snap)
  if not snap or not snap.npcId or snap.kind ~= "Creature" then return end
  local m = B.Ensure(snap.npcId)
  local changed = false
  if snap.name and m.nm ~= snap.name then m.nm = snap.name; changed = true end
  if snap.level then
    if not m.lv or snap.level < m.lv then m.lv = snap.level; changed = true end
    if not m.lx or snap.level > m.lx then m.lx = snap.level; changed = true end
  end
  if snap.classification and m.cl ~= snap.classification then m.cl = snap.classification; changed = true end
  if snap.creatureType and m.ct ~= snap.creatureType then m.ct = snap.creatureType; changed = true end
  if snap.family and m.fam ~= snap.family then m.fam = snap.family; changed = true end
  if snap.healthMax and snap.healthMax > 0 and (not m.hp or snap.healthMax > m.hp) then
    m.hp = snap.healthMax; changed = true
  end
  local z = zoneName()
  if z and not m.z[z] and countKeys(m.z) < B.MAX_ZONES then m.z[z] = true; changed = true end
  m.ls = now()
  -- count each spawn once per session ("seen 40 times" across the guild)
  if snap.guid and not B.seenGUIDs[snap.guid] then
    B.seenGUIDs[snap.guid] = true
    local r = B.MyRecord(m, true)
    r.s = (r.s or 0) + 1
    r.t = now()
    changed = true
  end
  if changed then B.MarkDirty(snap.npcId) end
  return m
end

---------------------------------------------------------------------------
-- Kills (no combat log on Forever): a creature we could see die while it was
-- tapped by us / our group, or a corpse we looted. Deduped by GUID per session.
---------------------------------------------------------------------------
function B.CountKill(guid, npcId)
  if not guid or not npcId or B.countedGUIDs[guid] then return false end
  B.countedGUIDs[guid] = true
  local m = B.Ensure(npcId)
  local r = B.MyRecord(m, true)
  r.k = (r.k or 0) + 1
  r.fk = r.fk or now()
  r.t = now()
  ns.char.kills = (ns.char.kills or 0) + 1
  B.MarkDirty(npcId)
  ns:Fire("KILL_RECORDED", npcId)
  return true
end

function B.CheckUnitDeath(unit)
  if not C.Call(UnitIsDead, unit) then return end
  if C.Call(UnitIsPlayer, unit) then return end
  if C.Call(UnitIsTapDenied, unit) then return end         -- someone else's kill
  local guid = C.Call(UnitGUID, unit)
  local kind, npcId = C.ParseGUID(guid)
  if kind ~= "Creature" or not npcId then return end
  local snap = B.Snapshot(unit)
  B.RecordSighting(snap)
  B.CountKill(guid, npcId)
end

---------------------------------------------------------------------------
-- Loot
---------------------------------------------------------------------------
-- Pure function (unit tested): turn loot window contents into per-corpse drops.
-- slots: array of { link=, slotType=, quantity=, sources = { guid, qty, guid, qty, ... } }
-- Returns { [guid] = { npcId=, items = { [itemID] = qty }, money = copper } }, unattributed
function B.ParseLoot(slots)
  local corpses, unattributed = {}, 0
  for _, s in ipairs(slots) do
    local src = s.sources or {}
    if #src == 0 then unattributed = unattributed + 1 end
    for j = 1, #src, 2 do
      local guid, qty = src[j], src[j + 1] or s.quantity or 1
      local kind, npcId = C.ParseGUID(guid)
      if kind == "Creature" and npcId then
        local corpse = corpses[guid]
        if not corpse then
          corpse = { npcId = npcId, items = {}, money = 0 }
          corpses[guid] = corpse
        end
        if s.slotType == "money" then
          corpse.money = corpse.money + (tonumber(qty) or 0)
        else
          local itemID = C.ItemIdFromLink(s.link)
          if itemID then corpse.items[itemID] = (corpse.items[itemID] or 0) + (tonumber(qty) or 1) end
        end
      elseif guid == nil then
        unattributed = unattributed + 1
      end
    end
  end
  return corpses, unattributed
end

-- Apply parsed corpses to the DB (first loot of each corpse only).
function B.ApplyLoot(corpses)
  local applied = 0
  for guid, corpse in pairs(corpses) do
    if not B.lootedGUIDs[guid] then
      B.lootedGUIDs[guid] = true
      applied = applied + 1
      local m = B.Ensure(corpse.npcId)
      local r = B.MyRecord(m, true)
      r.c = (r.c or 0) + 1
      r.m = (r.m or 0) + corpse.money
      for itemID, qty in pairs(corpse.items) do
        if r.i[itemID] or countKeys(r.i) < B.MAX_ITEMS_PER_RECORD then
          r.i[itemID] = (r.i[itemID] or 0) + 1
          r.q[itemID] = (r.q[itemID] or 0) + qty
        end
        B.LogLoot(corpse.npcId, itemID, qty)
      end
      r.t = now()
      -- looting a corpse proves the kill even if we never saw it die
      B.CountKill(guid, corpse.npcId)
      B.MarkDirty(corpse.npcId)
    end
  end
  return applied
end

function B.LogLoot(npcId, itemID, qty)
  local log = ns.char.lootLog
  table.insert(log, 1, { n = npcId, i = itemID, q = qty, t = now() })
  while #log > B.LOOT_LOG_MAX do table.remove(log) end
end

local LOOT_SLOT_MONEY = (Enum and Enum.LootSlotType and Enum.LootSlotType.Money) or 2

function B.ReadLootWindow()
  local n = C.Call(GetNumLootItems) or 0
  local slots = {}
  for slot = 1, n do
    local slotType = C.Call(GetLootSlotType, slot)
    local _, _, quantity = C.Call(GetLootSlotInfo, slot)
    local sources = { C.Call(GetLootSourceInfo, slot) }
    slots[#slots + 1] = {
      link = C.Call(GetLootSlotLink, slot),
      slotType = slotType == LOOT_SLOT_MONEY and "money" or "item",
      quantity = quantity,
      sources = sources,
    }
  end
  return slots
end

function B.OnLootOpened()
  local corpses, unattributed = B.ParseLoot(B.ReadLootWindow())
  B.unattributedLoot = B.unattributedLoot + unattributed
  B.ApplyLoot(corpses)
end

---------------------------------------------------------------------------
-- Abilities seen (UNIT_SPELLCAST_* on hostile target / nameplates, non-secret only)
---------------------------------------------------------------------------
function B.RecordSpell(unit, spellID)
  spellID = C.Safe(spellID)
  if not spellID then return end
  if C.Call(UnitIsPlayer, unit) then return end
  local kind, npcId = C.ParseGUID(C.Call(UnitGUID, unit))
  if kind ~= "Creature" or not npcId then return end
  local m = B.Ensure(npcId)
  if m.sp[spellID] then return end
  if countKeys(m.sp) >= B.MAX_SPELLS then return end
  m.sp[spellID] = C.SpellName(spellID) or true
  B.MarkDirty(npcId)
end

---------------------------------------------------------------------------
-- Aggregates + providers
---------------------------------------------------------------------------
-- Pure function (unit tested): sum all recorders.
function B.Aggregate(m)
  local agg = { kills = 0, corpses = 0, money = 0, items = {}, qty = {}, recorders = 0, seen = 0 }
  local firstKill, firstKiller
  for who, r in pairs(m.rec or {}) do
    agg.recorders = agg.recorders + 1
    agg.kills = agg.kills + (r.k or 0)
    agg.seen = agg.seen + math.max(r.s or 0, r.k or 0)
    agg.corpses = agg.corpses + (r.c or 0)
    agg.money = agg.money + (r.m or 0)
    for itemID, n in pairs(r.i or {}) do agg.items[itemID] = (agg.items[itemID] or 0) + n end
    for itemID, n in pairs(r.q or {}) do agg.qty[itemID] = (agg.qty[itemID] or 0) + n end
    if r.fk and (not firstKill or r.fk < firstKill or (r.fk == firstKill and who < firstKiller)) then
      firstKill, firstKiller = r.fk, who
    end
  end
  agg.firstKill, agg.firstKiller = firstKill, firstKiller
  agg.loot = {}
  if agg.corpses > 0 then
    for itemID, n in pairs(agg.items) do
      agg.loot[#agg.loot + 1] = {
        itemID = itemID, rate = math.min(1, n / agg.corpses),
        count = agg.qty[itemID] or n, kills = agg.corpses,
      }
    end
  end
  return agg
end

local function zonesList(m)
  local z = {}
  for name in pairs(m.z or {}) do z[#z + 1] = name end
  table.sort(z)
  return z
end
B.ZonesList = zonesList

ns.Providers.Register({
  id = "game", label = "Game", priority = 100,
  GetMob = function(npcId, ctx)
    local live = ctx and ctx.live
    if not live or live.npcId ~= npcId then return nil end
    return {
      name = live.name, level = live.level, classification = live.classification,
      creatureType = live.creatureType, family = live.family,
      health = live.health, healthMax = live.healthMax,
    }
  end,
})

ns.Providers.Register({
  id = "guild", label = "LOMB guild", priority = 10,
  GetMob = function(npcId)
    local m = ns.db and ns.db.bestiary[npcId]
    if not m then return nil end
    local agg = B.Aggregate(m)
    local abilities = {}
    for spellID, name in pairs(m.sp or {}) do
      abilities[#abilities + 1] = { spellID = spellID, name = type(name) == "string" and name or nil }
    end
    return {
      name = m.nm, level = m.lv, levelMax = (m.lx and m.lx ~= m.lv) and m.lx or nil,
      classification = m.cl, creatureType = m.ct, family = m.fam, healthMax = m.hp,
      zones = next(m.z or {}) and zonesList(m) or nil,
      kills = agg.kills, firstKiller = agg.firstKiller, firstSeen = m.fs, lastSeen = m.ls,
      recorders = agg.recorders, seen = agg.seen > 0 and agg.seen or nil,
      loot = agg.loot, abilities = abilities,
    }
  end,
})

function B.Merged(npcId)
  return ns.Providers.Merge(npcId, { live = B.live })
end

-- Filters and sort orders for the Bestiary tab.
B.FILTERS = {
  { key = "all",      label = "All creatures" },
  { key = "rare",     label = "Rares" },
  { key = "elite",    label = "Elites" },
  { key = "zone",     label = "This zone" },
  { key = "killed",   label = "Guild killed" },
  { key = "unkilled", label = "Not killed yet" },
  { key = "mine",     label = "Killed by me" },
}
B.SORTS = {
  { key = "name",   label = "Sort: name" },
  { key = "level",  label = "Sort: level" },
  { key = "kills",  label = "Sort: kills" },
  { key = "recent", label = "Sort: recent" },
}

local function isRare(cl) return cl == "rare" or cl == "rareelite" end
local function isElite(cl) return cl == "elite" or cl == "rareelite" or cl == "worldboss" end
B.IsRare = isRare

local function matches(q, ...)
  if q == "" then return true end
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" and v:lower():find(q, 1, true) then return true end
  end
  return false
end

local function passes(filter, it, here)
  if filter == "rare" then return isRare(it.cl) end
  if filter == "elite" then return isElite(it.cl) end
  if filter == "zone" then return here ~= nil and it.zones[here] == true end
  if filter == "killed" then return (it.kills or 0) > 0 end
  if filter == "unkilled" then return (it.kills or 0) == 0 end
  if filter == "mine" then return (it.mine or 0) > 0 end
  return true
end

-- Sorted list of known mobs for the Bestiary tab (guild-recorded + static data).
-- opts: { filter = key, sort = key, zone = name for the "zone" filter } (or just a search string)
function B.List(search, opts)
  opts = opts or {}
  local q = search and search:lower() or ""
  local filter, here = opts.filter or "all", opts.zone or zoneName()
  local out, seen = {}, {}
  for npcId, m in pairs(ns.db.bestiary) do
    seen[npcId] = true
    local zs = ""
    for z in pairs(m.z or {}) do zs = zs .. " " .. z end
    if matches(q, m.nm, zs, m.ct, m.fam) then
      local agg = B.Aggregate(m)
      local mine = m.rec and m.rec[ns.playerKey]
      local it = { npcId = npcId, name = m.nm or ("NPC " .. npcId), level = m.lv, levelMax = m.lx,
        cl = m.cl, kills = agg.kills, seen = agg.seen, mine = mine and mine.k or 0, ls = m.ls, zones = m.z or {},
        spotted = m.rs }
      if passes(filter, it, here) then out[#out + 1] = it end
    end
  end
  for npcId, src in pairs(ns.Providers.StaticMobIds()) do
    if not seen[npcId] then
      local p = ns.Providers.Get(src)
      local m = p and p.mobs[npcId]
      if m and matches(q, m.name, m.creatureType, m.family) then
        local zones = {}
        for _, z in ipairs(type(m.zones) == "table" and m.zones or {}) do zones[z] = true end
        local it = { npcId = npcId, name = m.name or ("NPC " .. npcId), level = m.level,
          levelMax = m.levelMax, cl = m.classification, kills = 0, seen = 0, mine = 0, static = src, zones = zones }
        if passes(filter, it, here) then out[#out + 1] = it end
      end
    end
  end
  local sort = opts.sort or "name"
  table.sort(out, function(a, b)
    if sort == "level" and (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
    if sort == "kills" and (a.kills or 0) ~= (b.kills or 0) then return (a.kills or 0) > (b.kills or 0) end
    if sort == "recent" and (a.ls or 0) ~= (b.ls or 0) then return (a.ls or 0) > (b.ls or 0) end
    if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
    return a.npcId < b.npcId
  end)
  return out
end

-- Completion for a zone: how many of the creatures known there the guild (and you) have killed.
function B.ZoneStats(zone)
  zone = zone or zoneName()
  local st = { zone = zone, known = 0, killed = 0, mine = 0 }
  if not zone then return st end
  local list = B.List("", { filter = "zone", zone = zone })
  for _, it in ipairs(list) do
    st.known = st.known + 1
    if (it.kills or 0) > 0 then st.killed = st.killed + 1 end
    if (it.mine or 0) > 0 then st.mine = st.mine + 1 end
  end
  st.pct = st.known > 0 and math.floor(st.killed / st.known * 100 + 0.5) or 0
  return st
end
B.ZoneName = zoneName

---------------------------------------------------------------------------
-- Sync helpers (used by Comm/Sync.lua)
---------------------------------------------------------------------------
function B.BuildSyncPayload(npcId)
  local m = ns.db.bestiary[npcId]
  if not m then return nil end
  local r = m.rec[ns.playerKey]
  local zones = zonesList(m)
  while #zones > 5 do table.remove(zones) end
  local spells, n = {}, 0
  for spellID in pairs(m.sp or {}) do
    n = n + 1
    if n <= 10 then spells[#spells + 1] = spellID end
  end
  return {
    t = "B", n = npcId, nm = m.nm, lv = m.lv, lx = m.lx, cl = m.cl, ct = m.ct, hp = m.hp,
    z = zones, sp = spells,
    r = r and { k = r.k, c = r.c, m = r.m, s = r.s, i = r.i, q = r.q, fk = r.fk, t = r.t } or nil,
  }
end

-- Pass on someone else's record (catch-up for a guildmate who was offline).
function B.BuildRelayPayload(npcId, who)
  local m = ns.db.bestiary[npcId]
  local r = m and m.rec[who]
  if not r or who == ns.playerKey then return nil end
  return { t = "BR", n = npcId, w = who, nm = m.nm, lv = m.lv, lx = m.lx, cl = m.cl, ct = m.ct,
    r = { k = r.k, c = r.c, m = r.m, s = r.s, i = r.i, q = r.q, fk = r.fk, t = r.t } }
end

-- Records changed after `since`: { { id=, who=, t= }, ... } newest first.
-- who = "me" for our own, "others" for everyone else's.
function B.ChangedSince(since, who)
  local out = {}
  for npcId, m in pairs(ns.db.bestiary) do
    for rec, r in pairs(m.rec or {}) do
      local mine = rec == ns.playerKey
      if (r.t or 0) > since and ((who == "me") == mine) then
        out[#out + 1] = { id = npcId, who = rec, t = r.t or 0 }
      end
    end
  end
  table.sort(out, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.id < b.id end)
  return out
end

local function validCount(v) return type(v) == "number" and v >= 0 and v < 1e9 and v end
local function validTime(v) return type(v) == "number" and v > 1.5e9 and v < 4e9 and v end

-- Apply a guildmate's bestiary message. Returns true if anything changed.
function B.ApplyRemote(sender, d)
  local npcId = tonumber(d.n)
  if not npcId or npcId <= 0 or npcId > 10000000 then return false end
  if sender == ns.playerKey then return false end
  local m = B.Ensure(npcId)
  local changed = false
  if type(d.nm) == "string" and not m.nm and #d.nm < 80 then m.nm = d.nm; changed = true end
  if validCount(d.lv) and (not m.lv or d.lv < m.lv) then m.lv = d.lv; changed = true end
  if validCount(d.lx) and (not m.lx or d.lx > m.lx) then m.lx = d.lx; changed = true end
  if type(d.cl) == "string" and not m.cl then m.cl = d.cl; changed = true end
  if type(d.ct) == "string" and not m.ct then m.ct = d.ct; changed = true end
  if validCount(d.hp) and (not m.hp or d.hp > m.hp) then m.hp = d.hp; changed = true end
  if type(d.z) == "table" then
    for _, z in ipairs(d.z) do
      if type(z) == "string" and #z < 64 and not m.z[z] and countKeys(m.z) < B.MAX_ZONES then
        m.z[z] = true; changed = true
      end
    end
  end
  if type(d.sp) == "table" then
    for _, id in ipairs(d.sp) do
      if validCount(id) and not m.sp[id] and countKeys(m.sp) < B.MAX_SPELLS then
        m.sp[id] = C.SpellName(id) or true; changed = true
      end
    end
  end
  local r = d.r
  if type(r) == "table" and validTime(r.t) then
    local old = m.rec[sender]
    if not old or (old.t or 0) < r.t then
      local clean = { k = validCount(r.k) or 0, c = validCount(r.c) or 0, m = validCount(r.m) or 0,
        s = validCount(r.s) or nil,
        fk = validTime(r.fk) or nil, t = r.t, i = {}, q = {} }
      local items = 0
      for itemID, n in pairs(type(r.i) == "table" and r.i or {}) do
        if validCount(itemID) and validCount(n) and items < B.MAX_ITEMS_PER_RECORD then
          items = items + 1
          clean.i[itemID] = math.min(n, clean.c > 0 and clean.c or n)
          local q = type(r.q) == "table" and validCount(r.q[itemID]) or n
          clean.q[itemID] = q
        end
      end
      m.rec[sender] = clean
      changed = true
    end
  end
  m.ls = math.max(m.ls or 0, now())
  if changed then ns:Fire("BESTIARY_UPDATED", npcId) end
  return changed
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
function B.RefreshTarget()
  local snap = B.Snapshot("target")
  -- only creatures you can fight (or their corpses); vendors and guards stay out
  if snap and not (snap.canAttack or snap.dead or snap.restricted) then snap = nil end
  B.live = snap
  if snap then
    if snap.restricted and C.InCombat() then B.pendingTargetRefresh = true end
    B.RecordSighting(snap)
  end
  ns:Fire("TARGET_CHANGED", snap)
end

ns:On("PLAYER_TARGET_CHANGED", function()
  B.RefreshTarget()
  if B.live then B.CheckUnitDeath("target") end
end)

ns:On("UNIT_HEALTH", function(_, unit)
  if unit ~= "target" then
    if type(unit) == "string" and unit:find("^nameplate") then B.CheckUnitDeath(unit) end
    return
  end
  if B.live then
    B.live.health = C.Call(UnitHealth, "target")
    B.live.raw.health = C.CallRaw(UnitHealth, "target")
    B.live.raw.healthMax = C.CallRaw(UnitHealthMax, "target")
    ns:Fire("TARGET_HEALTH", B.live)
    B.CheckUnitDeath("target")
  end
end)

ns:On("UNIT_CLASSIFICATION_CHANGED", function(_, unit)
  if unit == "target" then B.RefreshTarget() end
end)

ns:On("PLAYER_REGEN_ENABLED", function()
  if B.pendingTargetRefresh then
    B.pendingTargetRefresh = false
    B.RefreshTarget()
  end
end)

ns:On("LOOT_OPENED", function() B.OnLootOpened() end)

local function onCast(_, unit, _, spellID)
  if unit == "target" or (type(unit) == "string" and unit:find("^nameplate")) then
    if C.Call(UnitCanAttack, "player", unit) then B.RecordSpell(unit, spellID) end
  end
end
ns:On("UNIT_SPELLCAST_START", onCast)
ns:On("UNIT_SPELLCAST_CHANNEL_START", onCast)
ns:On("UNIT_SPELLCAST_SUCCEEDED", onCast)
