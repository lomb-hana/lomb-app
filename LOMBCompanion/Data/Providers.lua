-- LOMB Companion: data providers for the bestiary.
--
-- Every fact on the bestiary card comes from a provider and is shown with its
-- source, so players can always tell where a number came from:
--   "game"      what the client tells us right now (live target)
--   "guild"     what LOMB members recorded and synced
--   "foreverdb" ForeverDB.net data, used with permission: a snapshot bundled in
--               Data/ForeverDB/ (not MIT-licensed) and registered by
--               Modules/QuestDB.lua. Nothing is fetched at runtime. Quests a mob
--               gives and dungeon boss notes only -- mob loot stays guild-recorded.
--
-- Provider interface:
--   Providers.Register{
--     id = "foreverdb", label = "ForeverDB", priority = 50,
--     credit = "Data from ForeverDB.net", url = "https://...",
--     GetMob = function(npcId, ctx) return mobTable or nil end,
--   }
-- A mob table may contain any of the FIELDS below plus:
--   loot        = { { itemID=, rate= (0..1), count=, kills= }, ... }
--   abilities   = { { spellID=, name= }, ... }
--   boss        = { notes=, ... }               -- free-form sections
--   notableLoot = { { itemID=, note= }, ... }
--   skinning    = { skill=, items = { itemID, ... } }
--   quests      = { { id=, name=, level= }, ... }
local _, ns = ...
local P = {}
if ns then ns.Providers = P end

P.FIELDS = {
  "name", "level", "levelMax", "classification", "creatureType", "family",
  "health", "healthMax", "zones", "kills", "firstKiller", "firstSeen", "lastSeen",
  "recorders", "seen",
}
-- Sections that only exist when a provider supplies them (hidden otherwise).
P.SECTIONS = { "boss", "notableLoot", "skinning", "quests" }

local providers = {}
P.list = providers

function P.Register(p)
  assert(type(p) == "table" and p.id and p.GetMob, "provider needs id and GetMob")
  for i = #providers, 1, -1 do
    if providers[i].id == p.id then table.remove(providers, i) end
  end
  p.priority = p.priority or 0
  providers[#providers + 1] = p
  table.sort(providers, function(a, b) return a.priority > b.priority end)
  return p
end

function P.Get(id)
  for _, p in ipairs(providers) do if p.id == id then return p end end
end

function P.Unregister(id)
  for i = #providers, 1, -1 do
    if providers[i].id == id then table.remove(providers, i) end
  end
end

function P.Has(id) return P.Get(id) ~= nil end

-- Merge all providers for one mob.
-- Returns {
--   fields   = { [field] = { v = value, src = providerId }, ... },
--   alt      = { [field] = { {v=, src=}, ... } },  -- other sources' values, for tooltips
--   loot     = { [itemID] = { itemID=, sources = { [src] = {rate=, count=, kills=} } } },
--   lootList = sorted array of the above (best-known rate first),
--   abilities= { [key] = { spellID=, name=, sources = { [src]=true } } },
--   sections = { [section] = { data = ..., src = id, credit = ..., url = ... } },
--   credits  = { [providerId] = provider } -- providers that contributed anything
-- }
function P.Merge(npcId, ctx)
  local out = { fields = {}, alt = {}, loot = {}, lootList = {}, abilities = {}, sections = {}, credits = {} }
  for _, p in ipairs(providers) do
    local ok, mob = pcall(p.GetMob, npcId, ctx)
    if ok and type(mob) == "table" then
      local used = false
      for _, f in ipairs(P.FIELDS) do
        local v = mob[f]
        if v ~= nil then
          used = true
          if out.fields[f] == nil then
            out.fields[f] = { v = v, src = p.id }
          else
            out.alt[f] = out.alt[f] or {}
            table.insert(out.alt[f], { v = v, src = p.id })
          end
        end
      end
      if type(mob.loot) == "table" then
        for _, l in ipairs(mob.loot) do
          if l.itemID then
            used = true
            local e = out.loot[l.itemID]
            if not e then
              e = { itemID = l.itemID, sources = {} }
              out.loot[l.itemID] = e
            end
            e.sources[p.id] = { rate = l.rate, count = l.count, kills = l.kills }
          end
        end
      end
      if type(mob.abilities) == "table" then
        for _, a in ipairs(mob.abilities) do
          local key = a.spellID or a.name
          if key then
            used = true
            local e = out.abilities[key] or { spellID = a.spellID, name = a.name, sources = {} }
            e.name = e.name or a.name
            e.sources[p.id] = true
            out.abilities[key] = e
          end
        end
      end
      for _, s in ipairs(P.SECTIONS) do
        if mob[s] ~= nil and out.sections[s] == nil then
          used = true
          out.sections[s] = { data = mob[s], src = p.id, credit = p.credit, url = p.url }
        end
      end
      if used then out.credits[p.id] = p end
    end
  end
  -- sort loot: highest known rate first (any source), then itemID for stability
  for _, e in pairs(out.loot) do
    local best = 0
    for _, s in pairs(e.sources) do
      if s.rate and s.rate > best then best = s.rate end
    end
    e.best = best
    out.lootList[#out.lootList + 1] = e
  end
  table.sort(out.lootList, function(a, b)
    if a.best ~= b.best then return a.best > b.best end
    return a.itemID < b.itemID
  end)
  return out
end

-- Field value helper: returns value, source
function P.Value(merged, field)
  local f = merged and merged.fields[field]
  if f then return f.v, f.src end
end

-- Display labels for sources (used by the UI source tags).
P.SOURCE_LABEL = { game = "game", guild = "guild", foreverdb = "ForeverDB" }

---------------------------------------------------------------------------
-- Optional data module hook.
-- A static data module (see Data/ForeverDB.example.lua) can call
-- LOMBCompanion.Providers.RegisterStatic{ id=..., ..., mobs = { [npcId] = {...} } }.
-- The bundled ForeverDB snapshot uses Providers.Register with GetMob instead.
---------------------------------------------------------------------------
function P.RegisterStatic(def)
  assert(type(def.mobs) == "table", "static provider needs mobs")
  def.GetMob = def.GetMob or function(npcId) return def.mobs[npcId] end
  return P.Register(def)
end

-- Search mob names across static providers (for the Bestiary tab list).
function P.StaticMobIds()
  local ids = {}
  for _, p in ipairs(providers) do
    if type(p.mobs) == "table" then
      for id in pairs(p.mobs) do ids[id] = p.id end
    end
  end
  return ids
end

return P
