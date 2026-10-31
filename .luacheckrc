std = "lua51"
max_line_length = 160
codes = true
ignore = { "212/self", "211/_", "212/_.*", "213/_.*", "542" }
exclude_files = { "dist/", "tests/out/" }

globals = {
  "LOMBCompanion", "LOMBCompanionDB", "LOMBCompanionCharDB",
  "SlashCmdList", "SLASH_LOMB1", "SLASH_LOMB2",
  "BINDING_HEADER_LOMBCOMPANION", "BINDING_NAME_LOMBCOMPANION_TOGGLE", "BINDING_NAME_LOMBCOMPANION_CARD",
  "LOMBCompanion_ToggleWindow", "LOMBCompanion_ToggleCard",
  "ChatFrame_DisplayTimePlayed",
}

read_globals = {
  "ReloadUI",
  -- Lua extras provided by WoW
  "wipe", "Ambiguate", "geterrorhandler", "date", "time", "strsplit", "strtrim", "tinsert", "tremove", "unpack", "bit",
  -- namespaces
  "C_Timer", "C_ChatInfo", "C_GuildInfo", "C_Map", "C_Item", "C_Spell", "C_SkillInfo", "C_PvP",
  "C_ClassColor", "C_PlayerInfo", "C_Club", "Enum",
  -- frames / UI
  "CreateFrame", "UIParent", "GameTooltip", "Minimap", "UISpecialFrames", "DEFAULT_CHAT_FRAME",
  "Mixin", "BackdropTemplateMixin", "PlaySound", "SOUNDKIT", "ITEM_QUALITY_COLORS", "RAID_CLASS_COLORS",
  "GetCursorPosition", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
  "ChatFrame_OpenChat", "ChatEdit_InsertLink", "hooksecurefunc", "C_Calendar", "C_Container", "C_DateAndTime",
  "GetInventoryItemLink", "GetInventoryItemID", "GetContainerNumSlots", "GetContainerItemInfo", "GetContainerItemLink",
  -- secrets (12.x / Forever)
  "issecretvalue", "canaccessvalue",
  -- units
  "GetServerTime", "GetBuildInfo", "GetNumGroupMembers", "IsInRaid", "IsInGroup", "C_Calendar", "C_DateAndTime", "CalendarFrame",
  "UnitExists", "UnitIsPlayer", "UnitGUID", "UnitName", "UnitLevel", "UnitClassification", "UnitCreatureType",
  "UnitCreatureFamily", "UnitFactionGroup", "UnitHealth", "UnitHealthMax", "UnitIsDead", "UnitIsTapDenied", "UnitCanAttack",
  "UnitReaction", "UnitClass", "UnitRace", "UnitXP", "UnitXPMax", "UnitAffectingCombat", "UnitFullName",
  -- player / account
  "GetMoney", "GetRealmName", "GetNormalizedRealmName", "GetTime", "InCombatLockdown", "IsInGuild", "GetGuildInfo",
  "IsInInstance", "IsEncounterInProgress", "IsTrialAccount", "IsVeteranTrialAccount", "GameLimitedMode_IsActive",
  "RequestTimePlayed", "GetAverageItemLevel", "GetInventoryItemLink", "GetNumSkillLines", "GetSkillLineInfo",
  "GetRealZoneText", "GetZoneText", "GetItemInfo", "GetSpellInfo",
  -- guild
  "GetNumGuildMembers", "GetGuildRosterInfo", "GetGuildRosterLastOnline", "GuildRoster",
  -- loot
  "GetNumLootItems", "GetLootSlotType", "GetLootSlotInfo", "GetLootSourceInfo", "GetLootSlotLink",
  -- comms
  "SendAddonMessage", "RegisterAddonMessagePrefix",
}

files["tests/"] = { std = "+busted", globals = { "_ENV" }, ignore = { "111", "112", "113", "122", "142", "143" } }
files["tools/"] = { ignore = { "113" } }

-- generated ForeverDB.net data (one record per line; long lines are expected)
files["LOMBCompanion/Data/ForeverDB/"] = { max_line_length = false }
