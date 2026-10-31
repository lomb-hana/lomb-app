-- LOMB Companion: dungeon and raid loot, for the Loot browser in Quests & Items.
-- Two sources, always labelled apart:
--   * ForeverDB.net's notable loot for each instance (a few picks per dungeon, not a drop
--     table, and not tied to a boss), from the bundled snapshot;
--   * what the guild's bestiary saw drop: mobs whose zone is the instance, and the boss
--     whose name matches. Counts are corpses that had the item, from guildmates with the
--     addon on. No drop rates are made up and no Classic loot tables are bundled.
-- Nothing here runs at login: the only index (instance names) is built on first use, and the
-- guild part is read from the bestiary when a page or answer asks for it.
--
-- Keys: an instance ID (number) is the whole instance; "id:b:N" is boss N; "id:trash" is the
-- recorded mobs that aren't bosses.
--
-- Extension points (raids from 2026-12-09, soft reserves in v0.9):
--   Loot.AddSource(fn)  fn(did, part) -> { { itemID=, note= } ... } more items for a grid
--   Loot.AddBadge(fn)   fn(itemID, did) -> short text or nil (e.g. "SR 2"), shown on the item
local _, ns = ...
local Loot = ns:NewModule("Loot")

Loot.KIND_LABEL = { dungeon = "Dungeon", raid = "Raid" }
Loot.sources, Loot.badges = {}, {}

function Loot.AddSource(fn) Loot.sources[#Loot.sources + 1] = fn end
function Loot.AddBadge(fn) Loot.badges[#Loot.badges + 1] = fn end

local function FDB() return ns.FDB end
local function bestiary() return ns.db and ns.db.bestiary or {} end

-- "The Deadmines" / "Deadmines" / "Edwin VanCleef" / "van cleef" -> comparable keys
local function squash(s)
  s = tostring(s or ""):lower():gsub("^the ", ""):gsub("['\226\128\153`]", "")
  return (s:gsub("[^%w]", ""))
end
Loot.Squash = squash

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------
function Loot.Key(did, part)
  if part == nil or part == "all" then return did end
  if part == "trash" then return did .. ":trash" end
  return did .. ":b:" .. part
end

-- key -> did, part ("all" | "trash" | boss index)
function Loot.ParseKey(key)
  if type(key) == "number" then return key, "all" end
  local did, rest = tostring(key or ""):match("^(%d+):(.+)$")
  if not did then return tonumber(key), "all" end
  if rest == "trash" then return tonumber(did), "trash" end
  return tonumber(did), tonumber(rest:match("^b:(%d+)$")) or "all"
end

function Loot.PartName(did, part)
  if part == "all" then return "Whole " .. ((FDB().Dungeon(did) or {}).k == "raid" and "raid" or "dungeon") end
  if part == "trash" then return "Trash" end
  local dg = FDB().Dungeon(did)
  return dg and dg.b and dg.b[part] or "?"
end

---------------------------------------------------------------------------
-- Instances and bosses
---------------------------------------------------------------------------
local names    -- [squashed instance name] = did (lazy)
local zoneDid  -- [zone text] = did or false (lazy, filled as zones are asked about)

local function instanceNames()
  if names then return names end
  names = {}
  local d = ns.FDBData
  for did, dg in pairs(d and d.dungeons or {}) do names[squash(dg.n)] = did end
  return names
end

function Loot.ResetIndex() names, zoneDid = nil, nil end
function Loot.IndexBuilt() return names ~= nil end

-- The instance a zone name (as the game reports it inside) belongs to.
local function zoneLookup(zone)
  local z = squash(zone)
  if z == "" then return false end
  local map = instanceNames()
  if map[z] then return map[z] end
  if #z < 6 then return false end
  for n, did in pairs(map) do
    if #n >= 6 and (n:find(z, 1, true) or z:find(n, 1, true)) then return did end
  end
  return false
end

function Loot.InstanceForZone(zone)
  if zone == nil then return nil end
  zoneDid = zoneDid or {}
  local did = zoneDid[zone]
  if did == nil then did = zoneLookup(zone); zoneDid[zone] = did end
  return did or nil
end

-- did, boss index for a boss name: exact, then one name inside the other ("van cleef").
function Loot.FindBoss(text)
  local t = squash(text)
  if #t < 3 then return nil end
  local d = ns.FDBData
  local partial
  for did, dg in pairs(d and d.dungeons or {}) do
    for i, b in ipairs(dg.b or {}) do
      local n = squash(b)
      if n == t then return did, i end
      if not partial and #t >= 4 and n:find(t, 1, true) then partial = { did, i } end
    end
  end
  if partial then return partial[1], partial[2] end
end

local function bossIndex(dg, name)
  local n = squash(name)
  for i, b in ipairs(dg.b or {}) do if squash(b) == n then return i end end
end

local function inInstance(m, did)
  for z in pairs(m.z or {}) do if Loot.InstanceForZone(z) == did then return true end end
  return false
end

-- Bestiary mobs for one part of an instance: { { npcId=, m=, boss=index|nil } }
function Loot.Mobs(did, part)
  local dg = FDB().Dungeon(did)
  local out = {}
  if not dg then return out end
  for npcId, m in pairs(bestiary()) do
    local bi = m.nm and bossIndex(dg, m.nm)
    local here = bi ~= nil or inInstance(m, did)
    if here and (part == "all" or (part == "trash" and not bi) or (part == bi)) then
      out[#out + 1] = { npcId = npcId, m = m, boss = bi }
    end
  end
  table.sort(out, function(a, b) return (a.m.nm or "") < (b.m.nm or "") end)
  return out
end

-- The bestiary mob for a boss (the one with the most kills), for "open in Bestiary".
function Loot.BossMob(did, i)
  local best, kills
  for _, e in ipairs(Loot.Mobs(did, i)) do
    local k = 0
    for _, r in pairs(e.m.rec or {}) do k = k + (r.k or 0) end
    if not best or k > kills then best, kills = e.npcId, k end
  end
  return best
end

---------------------------------------------------------------------------
-- The grid
---------------------------------------------------------------------------
local function quality(itemID)
  local _, _, q = ns.Compat.ItemInfo(itemID)
  if q then return q end
  local d = ns.FDBData
  local e = d and d.items and d.items[itemID]
  return e and e[2]
end
Loot.Quality = quality

-- { items = { { itemID, q, why (ForeverDB note) | nil, notable = bool, seen = corpses, from = {names} } },
--   mobs = n, corpses = n, notable = n (ForeverDB picks), guildOnly = n (recorded, not in ForeverDB's list) }
function Loot.For(did, part)
  part = part or "all"
  local dg = FDB().Dungeon(did)
  local res = { items = {}, mobs = 0, corpses = 0, notable = 0, guildOnly = 0 }
  if not dg then return res end
  local by = {}
  local function entry(itemID)
    local e = by[itemID]
    if not e then
      e = { itemID = itemID, seen = 0, from = {} }
      by[itemID] = e
      res.items[#res.items + 1] = e
    end
    return e
  end
  if part == "all" then
    for _, l in ipairs(dg.lo or {}) do
      local e = entry(l[1])
      e.notable, e.why = true, (l[2] ~= "" and l[2]) or nil
      res.notable = res.notable + 1
    end
  end
  for _, mob in ipairs(Loot.Mobs(did, part)) do
    res.mobs = res.mobs + 1
    for _, r in pairs(mob.m.rec or {}) do
      res.corpses = res.corpses + (r.c or 0)
      for itemID, n in pairs(r.i or {}) do
        if n > 0 then
          local e = entry(itemID)
          e.seen = e.seen + n
          local nm = mob.m.nm or ("NPC " .. mob.npcId)
          if e.from[#e.from] ~= nm then e.from[#e.from + 1] = nm end
        end
      end
    end
  end
  for _, fn in ipairs(Loot.sources) do
    local ok, extra = pcall(fn, did, part)
    if ok and type(extra) == "table" then
      for _, x in ipairs(extra) do
        if x.itemID then local e = entry(x.itemID); e.note = e.note or x.note end
      end
    end
  end
  for _, e in ipairs(res.items) do
    e.q = quality(e.itemID)
    if not e.notable then res.guildOnly = res.guildOnly + 1 end
  end
  table.sort(res.items, function(a, b)
    if (a.notable or false) ~= (b.notable or false) then return a.notable == true end
    if (a.q or -1) ~= (b.q or -1) then return (a.q or -1) > (b.q or -1) end
    if a.seen ~= b.seen then return a.seen > b.seen end
    return a.itemID < b.itemID
  end)
  return res
end

-- Short tags other features add to an item (soft reserves later).
function Loot.Badges(itemID, did)
  local out = {}
  for _, fn in ipairs(Loot.badges) do
    local ok, t = pcall(fn, itemID, did)
    if ok and type(t) == "string" and t ~= "" then out[#out + 1] = t end
  end
  return out
end

-- Where an item drops, as far as the bundle and the guild know:
-- { { did=, key=, notable=bool, why=, seen=n, boss=name|nil } }, notable picks first.
function Loot.WhereDrops(itemID)
  local out, by = {}, {}
  local d = ns.FDBData
  for did, dg in pairs(d and d.dungeons or {}) do
    for _, l in ipairs(dg.lo or {}) do
      if l[1] == itemID then
        local e = { did = did, key = did, notable = true, why = (l[2] ~= "" and l[2]) or nil, seen = 0 }
        out[#out + 1] = e; by[did] = e
      end
    end
  end
  for _, m in pairs(bestiary()) do
    local n = 0
    for _, r in pairs(m.rec or {}) do n = n + ((r.i and r.i[itemID]) or 0) end
    if n > 0 then
      local did, bi = nil, nil
      for z in pairs(m.z or {}) do did = did or Loot.InstanceForZone(z) end
      if not did and m.nm then did, bi = Loot.FindBossExact(m.nm) end
      if did then
        local dg = FDB().Dungeon(did)
        bi = bi or (dg and m.nm and bossIndex(dg, m.nm))
        local e = by[did]
        if not e then e = { did = did, key = did, seen = 0 }; out[#out + 1] = e; by[did] = e end
        e.seen = e.seen + n
        if bi then e.boss, e.key = dg.b[bi], Loot.Key(did, bi) end
      end
    end
  end
  table.sort(out, function(a, b)
    if (a.notable or false) ~= (b.notable or false) then return a.notable == true end
    if a.seen ~= b.seen then return a.seen > b.seen end
    return a.did < b.did
  end)
  return out
end

function Loot.FindBossExact(name)
  local t = squash(name)
  local d = ns.FDBData
  for did, dg in pairs(d and d.dungeons or {}) do
    for i, b in ipairs(dg.b or {}) do if squash(b) == t then return did, i end end
  end
end

---------------------------------------------------------------------------
-- Wishlist heart
---------------------------------------------------------------------------
local function wishEntry(itemID)
  local WL = ns.Wishlist
  if not (WL and WL.Mine and ns.char) then return nil end
  for _, e in ipairs(WL.Mine()) do if e.k == "n" and e.i == itemID then return e end end
end
Loot.WishEntry = wishEntry

function Loot.Wanted(itemID) return wishEntry(itemID) ~= nil end

-- Add to (or take off) your need list. Returns true when it's on the list afterwards, or nil + reason.
function Loot.ToggleWant(itemID, note)
  local WL = ns.Wishlist
  if not WL then return nil, "no wishlist" end
  local e = wishEntry(itemID)
  if e then WL.Remove(e); return false end
  local link = ns.ItemClick and ns.ItemClick.BuiltLink(itemID) or ("item:" .. itemID)
  local ok, why = WL.Add("n", link, 1, note)
  if not ok then return nil, why end
  return true
end
