local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
local P = H.loadPure("Data/Providers.lua")

print("Data providers (merge + source tags)")

local function reset() for i = #P.list, 1, -1 do P.list[i] = nil end end

H.test("higher priority wins each field, others kept as alternatives", function()
  reset()
  P.Register({ id = "guild", priority = 10, GetMob = function() return { name = "Gnoll", level = 10, kills = 7, zones = { "Westfall" } } end })
  P.Register({ id = "game", priority = 100, GetMob = function(_, ctx) return ctx.live end })
  local m = P.Merge(1, { live = { name = "Riverpaw Gnoll", level = 11, health = 40 } })
  H.eq(P.Value(m, "name"), "Riverpaw Gnoll")
  H.eq(select(2, P.Value(m, "name")), "game")
  H.eq(P.Value(m, "kills"), 7)
  H.eq(select(2, P.Value(m, "kills")), "guild")
  H.eq(m.alt.level[1].v, 10)
  H.eq(m.alt.level[1].src, "guild")
  H.ok(m.credits.game and m.credits.guild)
end)

H.test("loot from several sources is merged per item, sorted by rate", function()
  reset()
  P.Register({ id = "guild", priority = 10, GetMob = function()
    return { loot = { { itemID = 10, rate = 0.5, kills = 20 }, { itemID = 11, rate = 0.05, kills = 20 } } } end })
  P.Register({ id = "foreverdb", priority = 50, credit = "Data from ForeverDB.net", GetMob = function()
    return { loot = { { itemID = 11, rate = 0.04 }, { itemID = 12, rate = 0.9 } } } end })
  local m = P.Merge(1, {})
  H.eq(#m.lootList, 3)
  H.eq(m.lootList[1].itemID, 12)
  H.eq(m.lootList[2].itemID, 10)
  H.eq(m.loot[11].sources.guild.rate, 0.05)
  H.eq(m.loot[11].sources.foreverdb.rate, 0.04)
end)

H.test("ForeverDB-only sections are hidden unless a provider supplies them", function()
  reset()
  P.Register({ id = "guild", priority = 10, GetMob = function() return { name = "Hogger", kills = 3 } end })
  local m = P.Merge(448, {})
  for _, s in ipairs(P.SECTIONS) do H.eq(m.sections[s], nil, s) end
  H.eq(P.Has("foreverdb"), false)
  -- plug in a static module the way a generated Data/ForeverDB.lua would
  P.RegisterStatic({ id = "foreverdb", label = "ForeverDB", priority = 50, credit = "Data from ForeverDB.net",
    url = "https://foreverdb.net", mobs = { [448] = { name = "Hogger", boss = { notes = "x" },
      skinning = { skill = 60 }, quests = { { id = 176, name = "Wanted: \"Hogger\"" } } } } })
  m = P.Merge(448, {})
  H.eq(m.sections.boss.src, "foreverdb")
  H.eq(m.sections.boss.credit, "Data from ForeverDB.net")
  H.eq(m.sections.quests.data[1].id, 176)
  H.eq(m.sections.notableLoot, nil)
  H.eq(P.Value(m, "name"), "Hogger")
  H.eq(select(2, P.Value(m, "name")), "foreverdb", "static data outranks guild data")
  H.ok(P.StaticMobIds()[448])
end)

H.test("a broken provider can't break the card", function()
  reset()
  P.Register({ id = "bad", priority = 99, GetMob = function() error("boom") end })
  P.Register({ id = "guild", priority = 10, GetMob = function() return { name = "Ok" } end })
  local m = P.Merge(1, {})
  H.eq(P.Value(m, "name"), "Ok")
end)

H.test("re-registering replaces, unregister removes", function()
  reset()
  P.Register({ id = "x", priority = 1, GetMob = function() return { name = "a" } end })
  P.Register({ id = "x", priority = 1, GetMob = function() return { name = "b" } end })
  H.eq(#P.list, 1)
  H.eq(P.Value(P.Merge(1), "name"), "b")
  P.Unregister("x")
  H.eq(#P.list, 0)
end)

H.test("the example ForeverDB module loads against the real interface", function()
  reset()
  local ns = { Providers = P }
  assert(loadfile(H.addonDir .. "Data/ForeverDB.example.lua"))("LOMBCompanion", ns)
  H.ok(P.Has("foreverdb"))
  local m = P.Merge(99999, {})
  H.ok(m.sections.boss and m.sections.notableLoot and m.sections.skinning and m.sections.quests)
end)

H.test("example module is NOT in the TOC", function()
  for _, f in ipairs(H.tocFiles()) do H.ok(not f:find("ForeverDB"), "ForeverDB file in TOC: " .. f) end
end)

H.done()
