-- LOMB Companion: SavedVariables (account-wide + per character), defaults, migration.
local _, ns = ...
local DB = {}
ns.DB = DB

DB.SCHEMA = 1

local DEFAULTS = {
  schema = DB.SCHEMA,
  settings = {
    shareProfile = true,     -- gear, professions, playtime (shared automatically; off switch in Settings)
    shareBestiary = true,    -- kills / loot / sightings you record
    shareRecipes = true,     -- which items/enchants you can craft (item and spell IDs only)
    shareActivity = true,    -- news (level-ups, rare kills, new recipes) + leaderboard stats
    rareAlerts = true,       -- toast + chat line when you or a guildmate spots a rare
    rareSound = false,       -- rare alerts are silent unless this is ticked
    shareRares = true,       -- tell guildmates when you spot a rare (its name, zone and map spot)
    toastPoint = nil,
    recordAttendance = true, -- note who's grouped with the organizer during guild calendar events
    shareAttendance = true,  -- share what we noted (names + snapshot counts per event)
    shareBankFunds = true,   -- the bank character shares its gold as "guild bank funds" (nobody else's)
    officerRanks = 2,        -- the top N guild ranks can fix attendance (GM = rank 1)
    tooltips = true,         -- add LOMB lines to item tooltips ("Crafters in LOMB: ...")
    fdbTooltips = true,      -- add a ForeverDB.net line (sold by / made by / reagent) to item tooltips
    deTooltips = true,       -- add "Disenchants into ..." (+ guild enchanters) to disenchantable gear tooltips
    trainerReminder = true,  -- on level-up, print (to you only) what's new at your class trainer
    showCard = true,         -- bestiary card on target
    cardInCombat = true,     -- keep card up in combat (shows only what the game allows)
    cardLocked = false,
    cardPoint = nil,         -- { point, relPoint, x, y }
    cardPinned = false,
    windowPoint = nil,
    lastTab = "roster",
    tourDone = false,        -- the welcome tour was shown (or skipped) once
    minimap = { hide = false, angle = 215 },
    debug = false,
  },
  guilds = {},     -- [guildKey] = { members = {}, peers = {} }
  bestiary = {},   -- [npcId] = mob record (see Modules/Bestiary.lua)
  trainerCosts = {}, -- [classFile]["Name|rank"] = copper, noted at your class trainer (ForeverDB has no costs)
  seq = 0,
}

local CHAR_DEFAULTS = {
  schema = DB.SCHEMA,
  deaths = 0,
  kills = 0,
  levelTimes = {},   -- [level] = total /played seconds when reached
  played = nil,      -- { total = s, level = s, at = epoch }
  lootLog = {},      -- newest first, capped
  firstLogin = nil,
  trained = {},      -- [spellID] = true, ranks a class trainer listed as already learned
  setBank = nil,     -- { i = {[itemID]=true}, t = epoch }: set pieces seen in this character's bank
  questsDone = {},   -- [questID] = epoch, turn-ins this addon saw (fallback for quest tracking)
}

local function fill(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      fill(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end
DB.Fill = fill

function DB.Migrate(db)
  db.schema = db.schema or 0
  -- schema 0 -> 1: nothing to convert yet (first release)
  db.schema = DB.SCHEMA
end

function DB.Load()
  if type(LOMBCompanionDB) ~= "table" then LOMBCompanionDB = {} end
  if type(LOMBCompanionCharDB) ~= "table" then LOMBCompanionCharDB = {} end
  ns.db = fill(LOMBCompanionDB, DEFAULTS)
  ns.char = fill(LOMBCompanionCharDB, CHAR_DEFAULTS)
  DB.Migrate(ns.db)
  ns.char.firstLogin = ns.char.firstLogin or time()
end

-- Per-guild bucket, keyed by guild name + realm so alts in other guilds don't mix.
function DB.Guild()
  local guildName = ns.Compat.Call(GetGuildInfo, "player")
  if not guildName then return nil end
  local realm = ns.Compat.Call(GetNormalizedRealmName) or ""
  local key = guildName .. "@" .. realm
  local g = ns.db.guilds[key]
  if not g then
    g = { name = guildName, members = {}, peers = {} }
    ns.db.guilds[key] = g
  end
  return g, key
end

-- Rough size of a table once saved, for the Settings tab.
function DB.ApproxSize(t, seen)
  seen = seen or {}
  if type(t) ~= "table" then return #tostring(t) + 2 end
  if seen[t] then return 0 end
  seen[t] = true
  local n = 2
  for k, v in pairs(t) do n = n + DB.ApproxSize(k, seen) + DB.ApproxSize(v, seen) + 4 end
  return n
end
