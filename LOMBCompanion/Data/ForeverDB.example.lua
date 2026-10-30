-- EXAMPLE ONLY -- this file is NOT listed in LOMBCompanion.toc and is never loaded.
--
-- If ForeverDB.net gives LOMB permission to bundle their data, a build script will
-- generate Data/ForeverDB.lua in exactly this shape (from data they provide or
-- approve; never scraped, and no API key ever goes in the addon or the repo),
-- and add "Data\ForeverDB.lua" to the TOC after Data\Providers.lua.
--
-- Once loaded, the bestiary card shows the extra sections (boss info, notable
-- loot, skinning, related quests) with a "Data from ForeverDB.net" credit line.
-- All values below are made-up placeholders.
local _, ns = ...

ns.Providers.RegisterStatic({
  id = "foreverdb",
  label = "ForeverDB",
  priority = 50,                  -- below live game data, above guild-recorded data
  credit = "Data from ForeverDB.net",
  url = "https://foreverdb.net",
  dataVersion = "YYYY-MM-DD",     -- shown on the Credits tab
  mobs = {
    [99999] = {
      name = "Example Gnoll Brute",
      level = 12, levelMax = 13,
      classification = "elite",   -- normal | elite | rare | rareelite | worldboss
      creatureType = "Humanoid",
      zones = { "Example Forest" },
      loot = {
        { itemID = 11111, rate = 0.42 },
        { itemID = 22222, rate = 0.015 },
      },
      abilities = { { spellID = 33333, name = "Example Bash" } },
      boss = { notes = "Example: interrupt the heal at 30%." },
      notableLoot = { { itemID = 22222, note = "Example: BiS wand for level 15" } },
      skinning = { skill = 75, items = { 44444 } },
      quests = { { id = 55555, name = "Example Bounty", level = 12 } },
    },
  },
})
