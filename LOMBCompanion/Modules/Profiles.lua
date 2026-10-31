-- LOMB Companion: member profiles -- equipped gear, XP progress and alt/main links.
-- Gear and XP are part of "profile sharing" (Settings). Alt links are only
-- shared once you pick a main yourself on the Me tab.
local _, ns = ...
local C = ns.Compat
local V = ns.Shared.V
local Profiles = ns:NewModule("Profiles")

-- Equipment slots in paper-doll order (left column, right column, weapons).
Profiles.SLOTS = {
  { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back" }, { 5, "Chest" },
  { 4, "Shirt" }, { 19, "Tabard" }, { 9, "Wrist" },
  { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" }, { 11, "Ring" },
  { 12, "Ring" }, { 13, "Trinket" }, { 14, "Trinket" },
  { 16, "Main hand" }, { 17, "Off hand" }, { 18, "Ranged" },
}
Profiles.SLOT_NAME = {}
for _, s in ipairs(Profiles.SLOTS) do Profiles.SLOT_NAME[s[1]] = s[2] end

---------------------------------------------------------------------------
-- Gear: each slot is sent as "itemId[:enchantId[:suffixId]]" (no gems, no
-- unique ids, nothing that identifies a specific copy of an item).
---------------------------------------------------------------------------
function Profiles.CompactLink(link)
  if type(link) ~= "string" then return nil end
  local body = link:match("item:([%-%d:]+)")
  if not body then return nil end
  local f = {}
  for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
  local id = tonumber(f[1])
  if not id or id <= 0 then return nil end
  local ench, suffix = tonumber(f[2]) or 0, tonumber(f[7]) or 0
  if suffix ~= 0 then return ("%d:%d:%d"):format(id, ench, suffix) end
  if ench ~= 0 then return ("%d:%d"):format(id, ench) end
  return tostring(id)
end

function Profiles.ParseCompact(s)
  if type(s) ~= "string" then return nil end
  local id, ench, suffix = s:match("^(%d+):?(%-?%d*):?(%-?%d*)$")
  id = tonumber(id)
  if not id then return nil end
  return id, tonumber(ench) or 0, tonumber(suffix) or 0
end

-- A plain item link string the game can show in a tooltip.
function Profiles.ItemString(s)
  local id, ench, suffix = Profiles.ParseCompact(s)
  if not id then return nil end
  return ("item:%d:%d:::::%d"):format(id, ench, suffix)
end

function Profiles.ReadGear()
  local g, n = {}, 0
  for _, s in ipairs(Profiles.SLOTS) do
    local c = Profiles.CompactLink(C.Call(GetInventoryItemLink, "player", s[1]))
    if c then g[s[1]] = c; n = n + 1 end
  end
  return g, n
end

-- Empty slots worth filling (shirt, tabard and off hand don't count).
local OPTIONAL = { [4] = true, [19] = true, [17] = true }
function Profiles.EmptySlots(gear)
  local n = 0
  for _, s in ipairs(Profiles.SLOTS) do
    if not OPTIONAL[s[1]] and not (gear and gear[s[1]]) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------
-- Inspect: when YOU inspect a guildmate (we never trigger inspects), keep
-- what you saw so their profile has gear even without the addon. Local only.
---------------------------------------------------------------------------
function Profiles.OnInspect(guid)
  guid = C.Safe(guid)
  local g = ns.DB.Guild()
  if not g or type(guid) ~= "string" then return end
  for _, unit in ipairs({ "target", "mouseover", "focus" }) do
    if C.Safe(C.Call(UnitGUID, unit)) == guid and C.Call(UnitIsPlayer, unit) then
      local name, realm = C.Call(UnitName, unit)
      name = C.Safe(name)
      if type(name) ~= "string" then return end
      realm = C.Safe(realm)
      local full = C.FullName((type(realm) == "string" and realm ~= "") and (name .. "-" .. realm) or name)
      if not ns.Roster.byName[full] or full == ns.playerKey then return end
      local gear, n = {}, 0
      for _, s in ipairs(Profiles.SLOTS) do
        local c = Profiles.CompactLink(C.Call(GetInventoryItemLink, unit, s[1]))
        if c then gear[s[1]] = c; n = n + 1 end
      end
      if n == 0 then return end
      g.inspected = g.inspected or {}
      g.inspected[full] = { g = gear, t = time() }
      ns:Fire("PROFILES_UPDATED")
      return
    end
  end
end

function Profiles.PruneInspected()
  local g = ns.DB.Guild()
  -- an empty roster means it hasn't loaded yet, not that everyone left
  local rosterKnown = #(ns.Roster.members or {}) > 0
  for name, e in pairs(g and g.inspected or {}) do
    if time() - (e.t or 0) > 60 * 86400 or (rosterKnown and not ns.Roster.byName[name]) then g.inspected[name] = nil end
  end
end

---------------------------------------------------------------------------
-- Alts and mains
--   ns.char.main  = this character's own choice (a name, or false = "not set")
--   g.accountMain = the main picked on any character of this account (per guild),
--                   so you only have to pick it once.
--   g.myChars     = this account's characters in the guild (local only)
---------------------------------------------------------------------------
function Profiles.MyMain()
  local own = ns.char.main
  if own == false then return nil end
  if own then return own end
  local g = ns.DB.Guild()
  return g and g.accountMain or nil
end

function Profiles.SetMain(name)
  local g = ns.DB.Guild()
  if name then
    ns.char.main = nil
    if g then g.accountMain = name end
  else
    ns.char.main = false
  end
  ns.Shared.MarkDirty("gr")
  Profiles.Changed()
end

function Profiles.MyChars()
  local g = ns.DB.Guild()
  local out = {}
  for name, c in pairs(g and g.myChars or {}) do
    out[#out + 1] = { name = name, level = c.lv, class = c.cl }
  end
  table.sort(out, function(a, b)
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
    return a.name < b.name
  end)
  return out
end

-- "alt of Bob", "Bob's alt", "alt: Bob", "Bob alt", "(Bob)" style guild notes.
local NOTE_PATTERNS = {
  "^%s*[Aa][Ll][Tt]%s+[Oo][Ff]%s+([%a\128-\255]+)",
  "^%s*[Aa][Ll][Tt]%s*[:%-=]%s*([%a\128-\255]+)",
  "^%s*([%a\128-\255]+)'?s%s+[Aa][Ll][Tt]",
  "^%s*([%a\128-\255]+)%s+[Aa][Ll][Tt]%s*$",
  "^%s*[Aa][Ll][Tt]%s+([%a\128-\255]+)%s*$",
}
function Profiles.MainFromNote(note)
  if type(note) ~= "string" or note == "" then return nil end
  for _, pat in ipairs(NOTE_PATTERNS) do
    local who = note:match(pat)
    if who and #who >= 2 and who:lower() ~= "main" and who:lower() ~= "alt" then return who end
  end
  return nil
end

-- Resolve a short or full name to a roster member's full name.
local function resolve(name)
  if not name then return nil end
  local R = ns.Roster
  if R.byName[name] then return name end
  local short = name:gsub("%-.*$", ""):lower()
  for _, r in ipairs(R.members) do
    if (r.short or ""):lower() == short then return r.name end
  end
  return nil
end
Profiles.Resolve = resolve

Profiles.mainOf = {}   -- [full name] = { main = full name, src = "addon" | "note" }

function Profiles.Rebuild()
  local map = {}
  for owner, d in ns.Shared.Each("gr") do
    local m = resolve(d.mn) or d.mn
    if m and m ~= owner then map[owner] = { main = m, src = "addon" } end
  end
  for _, r in ipairs(ns.Roster.members) do
    if not map[r.name] then
      local m = resolve(Profiles.MainFromNote(r.note))
      if m and m ~= r.name then map[r.name] = { main = m, src = "note" } end
    end
  end
  -- follow one hop (alt of an alt -> that alt's main); ignore cycles
  for _, v in pairs(map) do
    local up = map[v.main]
    if up and up.main ~= v.main and not map[up.main] then v.main = up.main end
  end
  Profiles.mainOf = map
  ns:Fire("PROFILES_UPDATED")
end
Profiles.RebuildSoon = ns.Debounce(1, Profiles.Rebuild)
function Profiles.Changed() Profiles.RebuildSoon() end

function Profiles.MainOf(name)
  local e = Profiles.mainOf[name]
  return e and e.main, e and e.src
end

function Profiles.AltsOf(name)
  local out = {}
  for alt, e in pairs(Profiles.mainOf) do
    if e.main == name then out[#out + 1] = alt end
  end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------
-- Shared dataset "gr": { g = {[slot] = compact}, xp = percent, mn = main }
---------------------------------------------------------------------------
function Profiles.Build()
  local d = {}
  if ns.db.settings.shareProfile then
    local g, n = Profiles.ReadGear()
    if n > 0 then d.g = g end
    local lvl = C.Call(UnitLevel, "player")
    local xp, xpMax = C.Call(UnitXP, "player"), C.Call(UnitXPMax, "player")
    if type(xp) == "number" and type(xpMax) == "number" and xpMax > 0 and (lvl or 0) < Profiles.MAX_LEVEL then
      d.xp = math.floor(xp / xpMax * 20) * 5   -- 5% steps: fewer updates while grinding
    end
  end
  local main = Profiles.MyMain()
  if main then d.mn = main end
  if next(d) == nil then return nil end
  return d
end
Profiles.MAX_LEVEL = 60

function Profiles.Validate(d)
  if type(d) ~= "table" then return nil end
  local out = { xp = V.int(d.xp, 0, 100), mn = V.name(d.mn) }
  if type(d.g) == "table" then
    out.g = {}
    for slot, v in pairs(d.g) do
      if V.int(slot, 1, 19) and type(v) == "string" and #v <= 32 and Profiles.ParseCompact(v) then
        out.g[slot] = v
      end
    end
  end
  return out
end

-- Everything we know about one member, for the profile page.
function Profiles.Get(name)
  local R = ns.Roster
  local row = R.byName[name]
  local gr = ns.Shared.Get("gr", name)
  local st = ns.Shared.Get("st", name)
  local peer = row and row.peer or (ns.DB.Guild() or { peers = {} }).peers[name]
  local p = {
    name = name, short = C.ShortName(name), row = row, peer = peer,
    profile = peer and peer.profile, gear = gr and gr.g, xp = gr and gr.xp,
    stats = st, isMe = name == ns.playerKey,
  }
  if not p.gear then
    local g = ns.DB.Guild()
    local seen = g and g.inspected and g.inspected[name]
    if seen then p.gear, p.gearSeen = seen.g, seen.t end
  end
  if p.isMe then
    local s = ns.Me.stats
    p.gear = (Profiles.ReadGear())
    if s.xp and s.xpMax and s.xpMax > 0 and (s.level or 0) < Profiles.MAX_LEVEL then
      p.xp = math.floor(s.xp / s.xpMax * 100)
    end
    p.profile = ns.Me.Profile()
  end
  p.main, p.mainSrc = Profiles.MainOf(name)
  p.alts = Profiles.AltsOf(p.main or name)
  return p
end

function Profiles:Init()
  ns.Shared.Define({
    kind = "gr", label = "gear", debounce = 60,
    build = Profiles.Build, validate = Profiles.Validate,
    onChange = function() Profiles.Changed() end,
  })
end

function Profiles:Login()
  local g = ns.DB.Guild()
  if g then
    g.myChars = g.myChars or {}
    local _, classFile = C.Call(UnitClass, "player")
    g.myChars[ns.playerKey] = { lv = C.Call(UnitLevel, "player"), cl = classFile, at = time() }
  end
  ns.After(30, Profiles.PruneInspected)
  Profiles.Rebuild()
end

local dirty = function() ns.Shared.MarkDirty("gr") end
ns:On("PLAYER_EQUIPMENT_CHANGED", dirty)
ns:On("INSPECT_READY", function(_, guid) Profiles.OnInspect(guid) end)
ns:On("PLAYER_XP_UPDATE", dirty)
ns:On("PLAYER_LEVEL_UP", function(_, level)
  local g = ns.DB.Guild()
  if g and g.myChars and g.myChars[ns.playerKey] then g.myChars[ns.playerKey].lv = C.Safe(level) end
  dirty()
end)
ns:Listen("ROSTER_UPDATED", function() Profiles.RebuildSoon() end)
