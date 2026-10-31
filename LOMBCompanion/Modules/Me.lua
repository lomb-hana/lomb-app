-- LOMB Companion: "Me" -- your own character's stats and the profile you share.
local _, ns = ...
local C = ns.Compat
local Me = ns:NewModule("Me")

-- Profession skill lines (Classic-era names; Forever uses the classic skill system).
local PROFESSIONS = {
  ["Alchemy"] = true, ["Blacksmithing"] = true, ["Enchanting"] = true, ["Engineering"] = true,
  ["Herbalism"] = true, ["Leatherworking"] = true, ["Mining"] = true, ["Skinning"] = true,
  ["Tailoring"] = true, ["Cooking"] = true, ["First Aid"] = true, ["Fishing"] = true,
  ["Jewelcrafting"] = true, ["Inscription"] = true,
}
Me.PROFESSIONS = PROFESSIONS
-- Short codes used on the wire (keeps profile messages to one packet).
local CODES = {
  Alchemy = "Al", Blacksmithing = "Bs", Enchanting = "En", Engineering = "Eg", Herbalism = "He",
  Leatherworking = "Lw", Mining = "Mi", Skinning = "Sk", Tailoring = "Ta", Cooking = "Co",
  ["First Aid"] = "FA", Fishing = "Fi", Jewelcrafting = "Jc", Inscription = "In",
}
local FROM_CODE = {}
for k, v in pairs(CODES) do FROM_CODE[v] = k end
Me.CODES, Me.FROM_CODE = CODES, FROM_CODE

Me.stats = {}

local function skillLine(i)
  -- Forever added C_SkillInfo; it may return a table or multiple values.
  if C_SkillInfo and C_SkillInfo.GetSkillLineInfo then
    local info = C.Call(C_SkillInfo.GetSkillLineInfo, i)
    if type(info) == "table" then
      return info.skillName or info.name, info.isHeader,
        info.skillRank or info.rank, info.skillMaxRank or info.maxRank
    end
  end
  local name, isHeader, _, rank, _, _, maxRank = C.Call(_G.GetSkillLineInfo, i)
  return name, isHeader, rank, maxRank
end

function Me.ReadProfessions()
  local count = (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C.Call(C_SkillInfo.GetNumSkillLines))
    or C.Call(_G.GetNumSkillLines) or 0
  local profs = {}
  for i = 1, math.min(count, 100) do
    local name, isHeader, rank, maxRank = skillLine(i)
    if name and not isHeader and PROFESSIONS[name] and rank then
      profs[name] = { rank = rank, max = maxRank or rank }
    end
  end
  return profs
end

-- Rank of one skill line by name (e.g. "Riding"), or nil if not learned.
function Me.SkillRank(want)
  local count = (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C.Call(C_SkillInfo.GetNumSkillLines))
    or C.Call(_G.GetNumSkillLines) or 0
  for i = 1, math.min(count, 100) do
    local name, isHeader, rank = skillLine(i)
    if name == want and not isHeader then return rank end
  end
end

function Me.ReadItemLevel()
  local avg, equipped = C.Call(_G.GetAverageItemLevel)
  local il = equipped or avg
  if il and il > 0 then return math.floor(il + 0.5) end
  -- Fallback: average the equipped slots ourselves.
  local total, n = 0, 0
  for slot = 1, 18 do
    if slot ~= 4 then -- shirt
      local link = C.Call(GetInventoryItemLink, "player", slot)
      if link then
        local lvl = C_Item and C_Item.GetDetailedItemLevelInfo and C.Call(C_Item.GetDetailedItemLevelInfo, link)
        if lvl then total, n = total + lvl, n + 1 end
      end
    end
  end
  if n > 0 then return math.floor(total / n + 0.5) end
  return nil
end

function Me.Refresh()
  local s = Me.stats
  s.name = ns.playerName
  s.level = C.Call(UnitLevel, "player")
  local className, classFile = C.Call(UnitClass, "player")
  s.className, s.class = className, classFile
  s.race = C.Call(UnitRace, "player")
  s.money = C.Call(GetMoney)
  s.ilvl = Me.ReadItemLevel()
  s.professions = Me.ReadProfessions()
  s.deaths = ns.char.deaths
  s.kills = ns.char.kills
  s.played = ns.char.played
  s.xp, s.xpMax = C.Call(UnitXP, "player"), C.Call(UnitXPMax, "player")
  ns:Fire("ME_UPDATED", s)
  return s
end
Me.RefreshSoon = ns.Debounce(1, Me.Refresh)

-- Current /played (seconds), extrapolated from the last TIME_PLAYED_MSG.
function Me.PlayedNow()
  local p = ns.char.played
  if not p then return nil end
  return p.total + math.max(0, time() - p.at), p.level + math.max(0, time() - p.at)
end

---------------------------------------------------------------------------
-- /played without spamming chat: the client prints the result to chat when
-- TIME_PLAYED_MSG fires; we hide that one print for requests we made.
---------------------------------------------------------------------------
local silentRequest = false
function Me.RequestPlayed()
  if not RequestTimePlayed then return end
  silentRequest = true
  C.Call(RequestTimePlayed)
end

local function installPlayedFilter()
  if not ChatFrame_DisplayTimePlayed or Me.filterInstalled then return end
  Me.filterInstalled = true
  local orig = ChatFrame_DisplayTimePlayed
  ChatFrame_DisplayTimePlayed = function(...) -- luacheck: ignore 121
    if silentRequest then silentRequest = false; return end
    return orig(...)
  end
end

-- The profile we share with the guild (one small message). Only level, class,
-- professions, item level and whole hours played -- no gold, no location history.
function Me.Profile()
  local s = Me.stats
  local pr = {}
  for name, p in pairs(s.professions or {}) do
    pr[CODES[name] or name] = { p.rank, p.max }
  end
  local total = Me.PlayedNow()
  return {
    lv = s.level, cl = s.class, pr = pr, il = s.ilvl,
    pt = total and math.floor(total / 3600) or nil,       -- whole hours only
  }
end

function Me:Init()
  installPlayedFilter()
end

function Me:Login()
  Me.Refresh()
  ns.After(4, Me.RequestPlayed)
  -- keep /played fresh without being chatty
  ns.Every(15 * 60, Me.RequestPlayed)
end

ns:On("TIME_PLAYED_MSG", function(_, total, thisLevel)
  total, thisLevel = C.Safe(total), C.Safe(thisLevel)
  if not total then return end
  ns.char.played = { total = total, level = thisLevel or 0, at = time() }
  Me.Refresh()
  ns:Fire("PROFILE_CHANGED")
end)

ns:On("PLAYER_LEVEL_UP", function(_, level)
  level = C.Safe(level)
  if level then
    local total = Me.PlayedNow()
    ns.char.levelTimes[level] = total or true
  end
  Me.RefreshSoon()
  ns.After(2, Me.RequestPlayed)
  ns:Fire("PROFILE_CHANGED")
end)

ns:On("PLAYER_DEAD", function()
  ns.char.deaths = (ns.char.deaths or 0) + 1
  Me.RefreshSoon()
end)

ns:On("PLAYER_MONEY", function() Me.RefreshSoon() end)
ns:On("SKILL_LINES_CHANGED", function() Me.RefreshSoon(); ns:Fire("PROFILE_CHANGED") end)
ns:On("PLAYER_EQUIPMENT_CHANGED", function() Me.RefreshSoon(); ns:Fire("PROFILE_CHANGED") end)
ns:On("PLAYER_XP_UPDATE", function() Me.RefreshSoon() end)
