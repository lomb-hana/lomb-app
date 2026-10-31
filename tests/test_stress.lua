local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

-- Stress tests: big guild, big bestiary, sync floods, combat. Times are CPU (os.clock) on the
-- offline harness, which is slower than the game client, so budgets are generous; the numbers
-- are printed so changes can be compared run to run.
print("Stress (200-member guild, big bestiary, sync flood, combat)")

local CLASSES = { "Warrior", "Mage", "Priest", "Rogue", "Druid", "Hunter", "Warlock", "Paladin", "Shaman" }
local ZONES = { "Elwynn Forest", "Durotar", "Darkshore", "The Barrens", "Westfall", "Stranglethorn Vale" }
local results = {}
local function ms(fn, n)
  n = n or 1
  local t = os.clock()
  for _ = 1, n do fn() end
  return (os.clock() - t) * 1000 / n
end
local function report(label, v, budget)
  results[#results + 1] = ("%-46s %8.2f ms  (budget %g)"):format(label, v, budget)
  H.ok(v < budget, ("%s took %.1f ms (budget %g)"):format(label, v, budget))
end

local function bigGuild(n)
  local r = {}
  for i = 1, n do
    r[i] = { name = ("Member%03d-Forever"):format(i), rank = i == 1 and "Guild Master" or "Member",
      rankIndex = i == 1 and 0 or 3, level = 1 + (i * 7) % 60, className = CLASSES[i % 9 + 1],
      class = CLASSES[i % 9 + 1]:upper(), zone = ZONES[i % 6 + 1], online = i % 3 == 0, days = i % 40,
      note = i % 5 == 0 and ("Member%03d alt"):format(i - 1) or nil }
  end
  return r
end

H.test("200-member guild: roster scan, roster tab, board, peers", function()
  local ns = H.boot()
  H.roster = bigGuild(200)
  report("roster scan, 200 members", ms(function() ns.Roster.Scan() end, 20), 25)
  for i = 3, 200, 3 do H.deliver(ns, H.roster[i].name, { t = "H", p = ns.PROTOCOL, v = ns.version }) end
  H.fire("GUILD_ROSTER_UPDATE")
  ns.UI.Open("roster"); H.advance(1)
  report("roster tab refresh, 200 rows", ms(function() ns.UI.Refresh("roster") end, 20), 25)
  for _, id in ipairs({ "board", "crafters", "events", "news" }) do
    ns.UI.Open(id); H.advance(0.1)
    report(id .. " tab refresh with 200 members", ms(function() ns.UI.Refresh(id) end, 10), 25)
  end
  H.noErrors("big guild")
end)

local function bigBestiary(ns, n, players)
  local B = ns.Bestiary
  local t0 = time()
  for id = 1, n do
    local m = B.Ensure(id)
    m.nm = "Creature " .. id; m.lv = 1 + id % 60; m.lx = m.lv + 1; m.ct = "Beast"
    m.z[ZONES[id % 6 + 1]] = true
    for p = 1, players do
      if (id + p) % 4 == 0 then
        m.rec[("Member%03d-Forever"):format(p)] = { k = id % 20, c = id % 10, t = t0 - id, i = { [id % 300 + 1000] = 1 } }
      end
    end
    m.rec[ns.playerKey] = { k = 1, c = 1, t = t0 - id * 3, i = { [2000 + id % 50] = 1 } }
  end
end

H.test("5000-mob bestiary: list, search, tab, catch-up, size", function()
  local ns = H.boot()
  local B = ns.Bestiary
  bigBestiary(ns, 5000, 20)
  report("Bestiary.List all 5000", ms(function() B.List("") end, 5), 400)
  report("Bestiary.List search 'creature 12'", ms(function() B.List("creature 12") end, 5), 400)
  ns.UI.Open("bestiary"); H.advance(0.1)
  report("bestiary tab refresh", ms(function() ns.UI.Refresh("bestiary") end, 5), 400)
  report("ChangedSince (catch-up scan)", ms(function() B.ChangedSince(time() - 3600, "me") end, 5), 150)
  report("ApproxSize (full walk)", ms(function() ns.DB.ApproxSize(ns.db) end, 3), 600)
  ns.UI.Open("settings"); H.advance(0.1)
  report("settings tab refresh (size is cached)", ms(function() ns.UI.Refresh("settings") end, 10), 40)
  H.noErrors("big bestiary")
end)

H.test("sync flood: 2000 mob records from 20 guildmates with the bestiary open", function()
  local ns = H.boot()
  local B = ns.Bestiary
  bigBestiary(ns, 3000, 0)
  local msgs = {}
  for i = 1, 2000 do
    local p = B.BuildSyncPayload(i)
    p.v = ns.version
    msgs[i] = { sender = ("Member%03d-Forever"):format(i % 20 + 1), parts = ns.Chunker.Split(ns.Serializer.Pack(p)) }
  end
  ns.UI.Open("bestiary"); H.advance(0.1)
  local t = os.clock()
  for _, m in ipairs(msgs) do
    for _, part in ipairs(m.parts) do H.fire("CHAT_MSG_ADDON", "LOMBC", part, "GUILD", m.sender) end
  end
  local total = (os.clock() - t) * 1000
  report("2000 records received (total)", total, 4000)
  report("  per record", total / 2000, 2)
  local t2 = os.clock(); H.advance(5, 0.5); report("UI catch-up after the flood", (os.clock() - t2) * 1000, 800)
  local n = 0
  for _, m in pairs(ns.db.bestiary) do if m.rec["Member001-Forever"] then n = n + 1 end end
  H.ok(n > 0, "records landed")
  -- junk flood: garbage must be cheap and harmless
  local t3 = os.clock()
  for i = 1, 5000 do H.fire("CHAT_MSG_ADDON", "LOMBC", "garbage" .. i, "GUILD", "Spammer-Forever") end
  report("5000 junk messages", (os.clock() - t3) * 1000, 300)
  H.noErrors("flood")
end)

H.test("combat: 10k target/health/cast events stay cheap", function()
  local ns = H.boot()
  bigBestiary(ns, 2000, 5)
  ns.UI.Open("bestiary"); H.advance(0.1)
  H.inCombat = true
  H.fire("PLAYER_REGEN_DISABLED")
  local t = os.clock()
  for i = 1, 2500 do
    local id = i % 2000 + 1
    H.units.target = { name = "Creature " .. id, level = 10, guid = H.guid(id, ("%08X"):format(i)),
      creatureType = "Beast", health = 100 - i % 100, healthMax = 100 }
    H.fire("PLAYER_TARGET_CHANGED")
    H.fire("UNIT_HEALTH", "target")
    H.fire("UNIT_SPELLCAST_START", "target", "cast-" .. i, 100 + i % 7)
    H.fire("UNIT_HEALTH", "target")
  end
  local total = (os.clock() - t) * 1000
  H.inCombat = false
  H.fire("PLAYER_REGEN_ENABLED")
  report("10k combat events (total)", total, 3000)
  report("  per event", total / 10000, 0.3)
  H.noErrors("combat")
end)

H.test("print timings", function()
  for _, l in ipairs(results) do print("    " .. l) end
end)

H.done()
