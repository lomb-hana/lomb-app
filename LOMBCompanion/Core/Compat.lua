-- LOMB Companion: guarded wrappers around the game API.
-- Forever runs the modern (Midnight-family) client, so:
--   * some unit values are "secret" in combat and must not be compared or stored
--   * the combat log is unavailable
--   * addon messages are blocked during boss encounters / PvP, and for trial accounts
-- Every call here is existence-checked and pcall-wrapped because Forever's API
-- may still differ from what we expect on launch day.
local _, ns = ...
local C = {}
ns.Compat = C

local unpack = unpack or table.unpack -- luacheck: ignore 143

---------------------------------------------------------------------------
-- Secret values
---------------------------------------------------------------------------
function C.IsSecret(v)
  local check = _G.issecretvalue
  if not check then return false end
  local ok, res = pcall(check, v)
  return ok and res == true
end

-- Returns v, or nil if v is a secret value (never store/compare secrets).
function C.Safe(v)
  if v == nil or C.IsSecret(v) then return nil end
  return v
end

-- pcall a function that may not exist; returns its results, secrets stripped.
function C.Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  local n = table.maxn(r)
  for i = 2, n do
    if C.IsSecret(r[i]) then r[i] = nil end
  end
  return unpack(r, 2, n)
end

-- pcall that keeps secret values (for passing straight into widgets only).
function C.CallRaw(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2, table.maxn(r))
end

---------------------------------------------------------------------------
-- Player identity
---------------------------------------------------------------------------
function C.RefreshPlayerKey()
  local name, realm = C.Call(UnitFullName, "player")
  if not name or name == "Unknown" then name = C.Call(UnitName, "player") end
  if not realm or realm == "" then realm = C.Call(GetNormalizedRealmName) or C.Call(GetRealmName) or "" end
  realm = (realm or ""):gsub("%s", "")
  ns.playerName = name or "?"
  ns.playerKey = realm ~= "" and (ns.playerName .. "-" .. realm) or ns.playerName
  return ns.playerKey
end

-- Normalise "Name" / "Name-Realm" to "Name-Realm".
function C.FullName(name)
  if not name then return nil end
  if name:find("-", 1, true) then return name end
  local realm = C.Call(GetNormalizedRealmName) or ""
  return realm ~= "" and (name .. "-" .. realm) or name
end

function C.ShortName(name)
  if not name then return nil end
  if Ambiguate then
    local ok, short = pcall(Ambiguate, name, "short")
    if ok and short then return short end
  end
  return (name:gsub("%-.*$", ""))
end

---------------------------------------------------------------------------
-- Combat / restriction state
---------------------------------------------------------------------------
function C.InCombat()
  if C.Call(InCombatLockdown) then return true end
  return C.Call(UnitAffectingCombat, "player") and true or false
end

function C.InEncounter()
  return C.Call(_G.IsEncounterInProgress) and true or false
end

function C.InPvPMatch()
  local _, instanceType = C.Call(IsInInstance)
  if instanceType == "pvp" or instanceType == "arena" then return true end
  if C_PvP and C.Call(C_PvP.IsActiveBattlefield) then return true end
  return false
end

function C.MessagingLockdown()
  if C_ChatInfo and C.Call(C_ChatInfo.InChatMessagingLockdown) then return true end
  return C.InEncounter() or C.InPvPMatch()
end

-- Trial / veteran accounts can receive addon messages but not send them.
function C.IsRestrictedAccount()
  if C.Call(_G.IsTrialAccount) then return true end
  if C.Call(_G.IsVeteranTrialAccount) then return true end
  if C.Call(_G.GameLimitedMode_IsActive) then return true end
  return false
end

---------------------------------------------------------------------------
-- Addon messages
---------------------------------------------------------------------------
-- Enum.SendAddonMessageResult (modern client); numbers are the fallback.
local RESULT = {
  Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8,
  NotInGuild = 10, AddOnMessageLockdown = 11,
}
if Enum and Enum.SendAddonMessageResult then
  for k in pairs(RESULT) do
    if Enum.SendAddonMessageResult[k] ~= nil then RESULT[k] = Enum.SendAddonMessageResult[k] end
  end
end
C.SEND_RESULT = RESULT

function C.RegisterPrefix(prefix)
  local fn = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or _G.RegisterAddonMessagePrefix
  return C.Call(fn, prefix)
end

-- Returns "ok" | "throttle" | "lockdown" | "fail"
function C.SendAddonMessage(prefix, msg, channel, target)
  local fn = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or _G.SendAddonMessage
  if type(fn) ~= "function" then return "fail" end
  local ok, res = pcall(fn, prefix, msg, channel, target)
  if not ok then return "fail" end
  if res == nil or res == true or res == RESULT.Success then return "ok" end
  if res == false then return "fail" end
  if res == RESULT.AddonMessageThrottle or res == RESULT.ChannelThrottle then return "throttle" end
  if res == RESULT.AddOnMessageLockdown then return "lockdown" end
  return "fail"
end

---------------------------------------------------------------------------
-- Units / GUIDs
---------------------------------------------------------------------------
-- "Creature-0-<server>-<instance>-<zone>-<npcId>-<spawn>"; server/spawn parts are
-- obfuscated on Forever but the npc ID is still readable.
function C.ParseGUID(guid)
  if type(guid) ~= "string" or C.IsSecret(guid) then return nil end
  local kind, npcId = guid:match("^(%a+)%-%d+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-")
  if kind == "Creature" or kind == "Vehicle" then
    return kind, tonumber(npcId)
  end
  return kind or guid:match("^(%a+)"), nil
end


function C.ItemIdFromLink(link)
  if type(link) ~= "string" or C.IsSecret(link) then return nil end
  return tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
end

function C.PlayerMapID()
  if C_Map and C_Map.GetBestMapForUnit then
    return C.Call(C_Map.GetBestMapForUnit, "player")
  end
end

-- Player position on the current map as whole percents (0-100), or nil when
-- the game doesn't give one (instances, restricted areas).
function C.PlayerMapPos()
  local mapID = C.PlayerMapID()
  if not mapID or not (C_Map and C_Map.GetPlayerMapPosition) then return nil end
  local pos = C.Call(C_Map.GetPlayerMapPosition, mapID, "player")
  if type(pos) ~= "table" and type(pos) ~= "userdata" then return nil end
  local ok, x, y = pcall(function() return pos:GetXY() end)
  x, y = ok and C.Safe(x), ok and C.Safe(y)
  if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return nil end
  return math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)
end

function C.MapName(mapID)
  if not mapID then return nil end
  if C_Map and C_Map.GetMapInfo then
    local info = C.Call(C_Map.GetMapInfo, mapID)
    if type(info) == "table" then return info.name end
  end
  return nil
end

function C.ItemInfo(itemID)
  if not itemID then return nil end
  local name, link, quality, _, _, _, _, _, _, icon
  if C_Item and C_Item.GetItemInfo then
    name, link, quality, _, _, _, _, _, _, icon = C.Call(C_Item.GetItemInfo, itemID)
  elseif _G.GetItemInfo then
    name, link, quality, _, _, _, _, _, _, icon = C.Call(_G.GetItemInfo, itemID)
  end
  if not icon and C_Item and C_Item.GetItemIconByID then
    icon = C.Call(C_Item.GetItemIconByID, itemID)
  end
  return name, link, quality, icon
end

-- Item icon, or the question-mark icon while the item isn't cached yet.
C.QUESTION_ICON = 134400
function C.ItemIcon(itemID)
  local _, _, _, icon = C.ItemInfo(itemID)
  return icon or C.QUESTION_ICON
end

-- The player's level and zone, or nil when the client doesn't know yet.
function C.PlayerLevel()
  local l = UnitLevel and C.Call(UnitLevel, "player")
  return type(l) == "number" and l > 0 and l or nil
end

function C.PlayerZone()
  local z = GetRealZoneText and C.Call(GetRealZoneText)
  return (type(z) == "string" and z ~= "") and z or nil
end

function C.SpellName(spellID)
  if not spellID then return nil end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C.Call(C_Spell.GetSpellInfo, spellID)
    if type(info) == "table" then return info.name, info.iconID end
  end
  if _G.GetSpellInfo then
    local name, _, icon = C.Call(_G.GetSpellInfo, spellID)
    return name, icon
  end
end

function C.ClassColor(classFile)
  local colors = (C_ClassColor and C_ClassColor.GetClassColor and C.Call(C_ClassColor.GetClassColor, classFile))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile or ""])
  if colors then return colors.r, colors.g, colors.b end
  return 0.85, 0.85, 0.85
end

function C.Now() return time() end
