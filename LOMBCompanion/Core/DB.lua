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
    windowSize = nil,        -- { w, h } when resized with the corner grip
    lastTab = "roster",
    tourDone = false,        -- the welcome tour was shown (or skipped) once
    theme = "storybook",     -- "storybook" (default) or "clean" (Settings > Look; applied on load)
    themeChosen = false,     -- true once the player picks a look in Settings > Look
    minimap = { hide = false, angle = 215 },
    debug = false,
  },
  guilds = {},     -- [guildKey] = { members = {}, peers = {} }
  bestiary = {},   -- [npcId] = mob record (see Modules/Bestiary.lua)
  trainerCosts = {}, -- [classFile]["Name|rank"] = copper, noted at your class trainer (ForeverDB has no costs)
}

local CHAR_DEFAULTS = {
  schema = DB.SCHEMA,
  deaths = 0,
  kills = 0,
  played = nil,      -- { total = s, level = s, at = epoch }
  lootLog = {},      -- newest first, capped
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

-- The look: storybook is the default (0.9.7+). 0.9.6 saved theme = "clean" for everyone who
-- never touched the switch, so only a look picked in Settings (themeChosen) is kept; anything
-- else becomes storybook. A ticked 0.9.6 box ("storybook") stays storybook either way.
function DB.MigrateTheme(s)
  if s.theme ~= "clean" and s.theme ~= "storybook" then s.theme = "storybook" end
  if not s.themeChosen then s.theme = "storybook" end
end

function DB.Migrate(db)
  db.schema = db.schema or 0
  -- schema 0 -> 1: nothing to convert yet (first release)
  db.schema = DB.SCHEMA
  DB.MigrateTheme(db.settings)
end

function DB.Load()
  if type(LOMBCompanionDB) ~= "table" then LOMBCompanionDB = {} end
  if type(LOMBCompanionCharDB) ~= "table" then LOMBCompanionCharDB = {} end
  ns.db = fill(LOMBCompanionDB, DEFAULTS)
  ns.char = fill(LOMBCompanionCharDB, CHAR_DEFAULTS)
  DB.Migrate(ns.db)
  DB.ClearObsolete(ns.db, ns.char)
end

-- Saved fields older versions wrote but nothing reads any more (cleared at log-in):
-- account seq (never used), per character levelTimes and firstLogin (until 0.9.9).
DB.OBSOLETE = { db = { "seq" }, char = { "levelTimes", "firstLogin" } }
function DB.ClearObsolete(db, char)
  for _, k in ipairs(DB.OBSOLETE.db) do if db then db[k] = nil end end
  for _, k in ipairs(DB.OBSOLETE.char) do if char then char[k] = nil end end
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
