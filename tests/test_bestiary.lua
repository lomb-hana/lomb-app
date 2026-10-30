local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Bestiary (loot recording, kills, secrets)")

local CORE = { "Core/Init.lua", "Core/Compat.lua", "Core/DB.lua", "Comm/Serializer.lua", "Comm/Chunker.lua",
  "Comm/Queue.lua", "Data/Providers.lua", "Modules/Me.lua", "Modules/Roster.lua", "Modules/Bestiary.lua", "Comm/Sync.lua" }

local function boot()
  H.frames, H.onUpdateFrames, H.timers = {}, {}, {}
  _G.LOMBCompanionDB, _G.LOMBCompanionCharDB = nil, nil
  H.installAPI()
  local ns = H.load(CORE)
  H.fire("ADDON_LOADED", "LOMBCompanion")
  H.fire("PLAYER_LOGIN")
  return ns
end

local function link(id) return ("|cffffffff|Hitem:%d::::::::12:::::|h[Item %d]|h|r"):format(id, id) end

H.test("GUID parsing handles Forever's obfuscated parts", function()
  local ns = boot()
  local C = ns.Compat
  H.eq(C.NpcIdFromGUID("Creature-0-x7Fa-0-12-1234-00ABCDEF01"), 1234)
  H.eq(C.NpcIdFromGUID("Creature-0-4372-0-1-299-0000123456"), 299)
  H.eq(C.NpcIdFromGUID("Vehicle-0-aB9z-1-2-777-ZZZ"), 777)
  H.eq(C.NpcIdFromGUID("Player-4372-0ABCDEF1"), nil)
  H.eq(C.NpcIdFromGUID("GameObject-0-1-2-3-4567-89"), nil)
  H.eq(C.NpcIdFromGUID(H.secret("Creature-0-1-2-3-55-6")), nil, "secret GUID is never parsed")
  H.eq(C.NpcIdFromGUID(nil), nil)
end)

H.test("ParseLoot groups items by corpse and skips non-creatures", function()
  local ns = boot()
  local g1, g2 = H.guid(500, "A1"), H.guid(500, "A2")
  local corpses, un = ns.Bestiary.ParseLoot({
    { link = link(2589), slotType = "item", quantity = 3, sources = { g1, 2, g2, 1 } },
    { link = link(5000), slotType = "item", quantity = 1, sources = { g2, 1 } },
    { slotType = "money", quantity = 0, sources = { g1, 57, g2, 12 } },
    { link = link(7777), slotType = "item", quantity = 1, sources = { "GameObject-0-1-2-3-4567-89", 1 } },
    { link = link(8888), slotType = "item", quantity = 1, sources = {} },
  })
  H.eq(corpses[g1].npcId, 500)
  H.eq(corpses[g1].items[2589], 2)
  H.eq(corpses[g2].items[2589], 1)
  H.eq(corpses[g2].items[5000], 1)
  H.eq(corpses[g1].money, 57)
  H.eq(corpses[g2].money, 12)
  H.eq(corpses["GameObject-0-1-2-3-4567-89"], nil)
  H.eq(un, 1)
end)

H.test("loot window -> drop rates, deduped per corpse", function()
  local ns = boot()
  local B = ns.Bestiary
  for i = 1, 4 do
    local g = H.guid(600, "C" .. i)
    H.loot = { { link = link(1001), quantity = 1, sources = { g, 1 } } }
    if i == 1 then table.insert(H.loot, { link = link(1002), quantity = 2, sources = { g, 2 } }) end
    H.fire("LOOT_OPENED")
    H.fire("LOOT_OPENED")   -- re-opening the same corpse must not double count
  end
  local m = B.Get(600)
  local r = m.rec[ns.playerKey]
  H.eq(r.c, 4, "corpses")
  H.eq(r.k, 4, "looting proves the kill")
  H.eq(r.i[1001], 4)
  H.eq(r.i[1002], 1)
  H.eq(r.q[1002], 2)
  local agg = B.Aggregate(m)
  local rates = {}
  for _, l in ipairs(agg.loot) do rates[l.itemID] = l.rate end
  H.near(rates[1001], 1.0)
  H.near(rates[1002], 0.25)
  H.eq(#ns.char.lootLog, 5)
  H.eq(ns.char.kills, 4)
end)

H.test("kill seen on target counted once, tap-denied ignored", function()
  local ns = boot()
  local B = ns.Bestiary
  local g = H.guid(700, "K1")
  H.units.target = { name = "Kobold Vermin", level = 3, guid = g, creatureType = "Humanoid", health = 50, healthMax = 50 }
  H.fire("PLAYER_TARGET_CHANGED")
  H.eq(B.Get(700).nm, "Kobold Vermin")
  H.units.target.dead, H.units.target.health = true, 0
  H.fire("UNIT_HEALTH", "target")
  H.fire("UNIT_HEALTH", "target")
  H.fire("PLAYER_TARGET_CHANGED")
  H.eq(B.Get(700).rec[ns.playerKey].k, 1)
  -- someone else's kill
  H.units.target = { name = "Kobold Vermin", level = 3, guid = H.guid(700, "K2"), dead = true, tapDenied = true }
  H.fire("PLAYER_TARGET_CHANGED")
  H.eq(B.Get(700).rec[ns.playerKey].k, 1)
  -- looting the first corpse later doesn't count the kill twice
  H.loot = { { link = link(1), quantity = 1, sources = { g, 1 } } }
  H.fire("LOOT_OPENED")
  H.eq(B.Get(700).rec[ns.playerKey].k, 1)
  H.eq(B.Get(700).rec[ns.playerKey].c, 1)
end)

H.test("combat secrets: nothing secret reaches SavedVariables; re-read after combat", function()
  local ns = boot()
  local B = ns.Bestiary
  H.state.combat = true
  H.units.target = { name = H.secret("Defias Thug"), level = H.secret(10), guid = H.secret(H.guid(800)),
    health = H.secret(100), healthMax = H.secret(100) }
  H.fire("PLAYER_TARGET_CHANGED")
  H.ok(B.live, "card still gets a snapshot")
  H.ok(B.live.restricted, "flagged as restricted")
  H.eq(B.live.name, nil)
  H.ok(_G.issecretvalue(B.live.raw.name), "raw value kept for display only")
  H.eq(B.Get(800), nil, "nothing stored while secret")
  for _, m in pairs(ns.db.bestiary) do
    for _, v in pairs(m) do H.ok(not _G.issecretvalue(v), "secret leaked into DB") end
  end
  -- secret loot sources are skipped, not crashed on
  H.loot = { { link = link(1), quantity = 1, sources = { H.secret(H.guid(800)), 1 } } }
  H.fire("LOOT_OPENED")
  H.eq(B.Get(800), nil)
  -- combat ends: values readable again
  H.state.combat = false
  H.units.target = { name = "Defias Thug", level = 10, guid = H.guid(800), health = 80, healthMax = 100 }
  H.fire("PLAYER_REGEN_ENABLED")
  H.eq(B.Get(800).nm, "Defias Thug")
end)

H.test("abilities recorded from casts, secret spell IDs ignored", function()
  local ns = boot()
  local B = ns.Bestiary
  H.units.target = { name = "Murloc Oracle", level = 9, guid = H.guid(900), health = 1, healthMax = 1 }
  H.fire("PLAYER_TARGET_CHANGED")
  H.fire("UNIT_SPELLCAST_START", "target", "cast-1", 332)
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "cast-2", H.secret(9999))
  H.units.nameplate3 = { name = "Murloc Oracle", guid = H.guid(900, "B"), level = 9 }
  H.fire("UNIT_SPELLCAST_CHANNEL_START", "nameplate3", "cast-3", 12345)
  H.units.target.friendly = true
  H.fire("UNIT_SPELLCAST_START", "target", "cast-4", 4444)
  local sp = B.Get(900).sp
  H.eq(sp[332], "Spell 332")
  H.eq(sp[12345], "Spell 12345")
  H.eq(sp[9999], nil)
  H.eq(sp[4444], nil, "friendly casts ignored")
end)

H.test("friendly NPCs are not recorded", function()
  local ns = boot()
  H.units.target = { name = "Innkeeper", level = 30, guid = H.guid(1000), friendly = true, health = 1, healthMax = 1 }
  H.fire("PLAYER_TARGET_CHANGED")
  H.eq(ns.Bestiary.Get(1000), nil)
  H.eq(ns.Bestiary.live, nil)
end)

H.done()
