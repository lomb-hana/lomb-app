local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Sync (end-to-end through serializer, chunker, queue)")

local CORE = { "Core/Init.lua", "Core/Compat.lua", "Core/DB.lua", "Comm/Serializer.lua", "Comm/Chunker.lua",
  "Comm/Queue.lua", "Data/Providers.lua", "Modules/Me.lua", "Modules/Roster.lua", "Modules/Bestiary.lua", "Comm/Sync.lua" }

local function boot(opts)
  H.frames, H.onUpdateFrames, H.timers = {}, {}, {}
  _G.LOMBCompanionDB, _G.LOMBCompanionCharDB = nil, nil
  H.installAPI(opts)
  local ns = H.load(CORE)
  H.fire("ADDON_LOADED", "LOMBCompanion")
  H.fire("PLAYER_LOGIN")
  return ns
end

-- decode everything we sent
local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    H.eq(s.channel, "GUILD")
    H.eq(s.prefix, "LOMBC")
    H.ok(#s.msg <= 255)
    local payload = a:Feed("me", s.msg)
    if payload then
      local ok, d = ns.Serializer.Unpack(payload)
      H.ok(ok, "own message must decode")
      out[#out + 1] = d
    end
  end
  return out
end

-- deliver a table as if a guildmate sent it
local function deliver(ns, sender, tbl)
  local parts = ns.Chunker.Split(ns.Serializer.Pack(tbl))
  for _, p in ipairs(parts) do H.fire("CHAT_MSG_ADDON", "LOMBC", p, "GUILD", sender) end
end

H.test("login sends hello + profile on the guild channel", function()
  local ns = boot()
  H.advance(15)
  local msgs = decodeSent(ns)
  H.eq(msgs[1].t, "H")
  H.eq(msgs[1].p, ns.PROTOCOL)
  H.eq(msgs[2].t, "P")
  H.eq(msgs[2].lv, 12)
  H.eq(msgs[2].cl, "HUNTER")
  H.eq(msgs[2].pr.Sk[1], 75)
  H.eq(msgs[2].pr.Lw[1], 60)
  H.eq(msgs[2].pr.Co[1], 40)
  H.eq(msgs[2].pr.Swords, nil, "weapon skills are not professions")
  H.eq(msgs[2].il, 24)
  H.eq(msgs[2].g, nil, "gold is never shared")
end)

H.test("profile sharing off sends only {off=true}", function()
  local ns = boot()
  ns.db.settings.shareProfile = false
  H.advance(15)
  local msgs = decodeSent(ns)
  H.eq(msgs[2].t, "P")
  H.eq(msgs[2].off, true)
  H.eq(msgs[2].lv, nil)
end)

H.test("nothing is sent during a boss encounter, PvP, or on a trial account", function()
  for _, setup in ipairs({
    function() H.state.encounter = true end,
    function() H.state.instanceType = "pvp" end,
    function() H.state.instanceType = "arena" end,
    function() H.state.trial = true end,
    function() H.state.lockdown = true end,
  }) do
    local ns = boot()
    setup()
    H.advance(30)
    H.eq(#H.sent, 0)
    H.ok(ns.Sync.queue:Size() > 0, "messages wait in the queue")
  end
  -- and they go out once it's over
  local ns = boot()
  H.state.encounter = true
  H.advance(20)
  H.state.encounter = false
  H.advance(3)
  H.eq(#decodeSent(ns), 2)
end)

H.test("guildmate hello -> roster badge + reply after jitter", function()
  local ns = boot()
  H.roster = { { name = "Brambleberry-Forever", rank = "Officer", level = 20, className = "Druid", class = "DRUID", zone = "Darkshore", online = true } }
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(15)
  H.sent = {}
  deliver(ns, "Brambleberry-Forever", { t = "H", v = "0.1.0", p = 1 })
  deliver(ns, "Brambleberry-Forever", { t = "P", v = "0.1.0", lv = 20, cl = "DRUID", il = 30, pt = 41, pr = { He = { 150, 150 } } })
  H.advance(1)
  local row = ns.Roster.byName["Brambleberry-Forever"]
  H.ok(row and row.peer, "peer badge")
  H.eq(row.peer.profile.lv, 20)
  H.eq(row.peer.profile.pr.He[1], 150)
  H.eq(ns.Roster.PeerCount(), 1)
  H.advance(70)   -- profile replies are batched (30s cooldown, 60s ticker)
  local types = {}
  for _, d in ipairs(decodeSent(ns)) do types[#types + 1] = d.t end
  H.ok(table.concat(types, ","):find("P"), "replied with profile")
end)

H.test("bestiary records sync: idempotent, per-recorder, summed", function()
  local ns = boot()
  local B = ns.Bestiary
  local msg = { t = "B", n = 1234, nm = "Riverpaw Gnoll", lv = 10, lx = 11, cl = "normal", ct = "Humanoid", hp = 180,
    z = { "Westfall" }, sp = { 3391 }, r = { k = 10, c = 8, m = 400, i = { [2589] = 4, [1001] = 1 }, q = { [2589] = 7 }, fk = 1793750000, t = 1793750100 } }
  deliver(ns, "Brambleberry-Forever", msg)
  deliver(ns, "Brambleberry-Forever", msg)   -- duplicate
  local m = B.Get(1234)
  H.eq(m.nm, "Riverpaw Gnoll")
  H.eq(B.Aggregate(m).kills, 10, "duplicate not double counted")
  -- an older copy never overwrites a newer one
  local old = { t = "B", n = 1234, r = { k = 2, c = 1, i = {}, t = 1793740000 } }
  deliver(ns, "Brambleberry-Forever", old)
  H.eq(B.Aggregate(m).kills, 10)
  -- a second recorder adds to the total
  deliver(ns, "Thistlewhit-Forever", { t = "B", n = 1234, r = { k = 5, c = 4, i = { [2589] = 2 }, fk = 1793749000, t = 1793750200 } })
  local agg = B.Aggregate(m)
  H.eq(agg.kills, 15)
  H.eq(agg.corpses, 12)
  H.eq(agg.firstKiller, "Thistlewhit-Forever")
  local rate
  for _, l in ipairs(agg.loot) do if l.itemID == 2589 then rate = l.rate end end
  H.near(rate, 6 / 12)
  -- guild provider shows it with source tags
  local merged = B.Merged(1234)
  H.eq(merged.fields.kills.src, "guild")
  H.eq(merged.fields.zones.v[1], "Westfall")
end)

H.test("hostile / malformed messages are ignored safely", function()
  local ns = boot()
  H.fire("CHAT_MSG_ADDON", "LOMBC", "Sgarbage", "GUILD", "Evil-Forever")
  H.fire("CHAT_MSG_ADDON", "LOMBC", "S{s1:ti5;}", "GUILD", "Evil-Forever")
  deliver(ns, "Evil-Forever", { t = "B", n = -5 })
  deliver(ns, "Evil-Forever", { t = "B", n = 55, nm = string.rep("x", 500), r = { k = "lots", t = 1793750000 } })
  deliver(ns, "Evil-Forever", { t = "Z" })
  -- wrong channel / prefix
  H.fire("CHAT_MSG_ADDON", "LOMBC", "S" .. ns.Serializer.Pack({ t = "H" }), "WHISPER", "Evil-Forever")
  H.fire("CHAT_MSG_ADDON", "OTHER", "S" .. ns.Serializer.Pack({ t = "H" }), "GUILD", "Evil-Forever")
  H.eq(ns.Bestiary.Get(-5), nil)
  local m = ns.Bestiary.Get(55)
  H.ok(not m or not m.nm or #m.nm < 80)
  H.ok(not m or not m.rec["Evil-Forever"] or m.rec["Evil-Forever"].k == 0)
  H.ok(ns.Sync.stats.bad >= 2)
  H.eq(#H.errors, 0, "no Lua errors")
end)

H.test("dirty mobs flush out of combat; new peer gets a small backfill", function()
  local ns = boot()
  H.advance(15)
  for i = 1, 45 do
    local g = H.guid(2000 + i)
    H.loot = { { link = "|Hitem:5|h", quantity = 1, sources = { g, 1 } } }
    H.fire("LOOT_OPENED")
  end
  H.sent = {}
  H.state.combat = true
  H.advance(ns.Sync.FLUSH_INTERVAL + 1)
  H.eq(#H.sent, 0, "no flush in combat")
  H.state.combat = false
  H.advance(ns.Sync.FLUSH_INTERVAL + 60)
  local n = 0
  for _, d in ipairs(decodeSent(ns)) do if d.t == "B" then n = n + 1 end end
  H.eq(n, ns.Sync.FLUSH_MAX, "first flush capped")
  H.sent = {}
  deliver(ns, "Newbie-Forever", { t = "H", v = "0.1.0", p = 1 })
  H.advance(60)
  n = 0
  for _, d in ipairs(decodeSent(ns)) do if d.t == "B" then n = n + 1 end end
  H.ok(n >= ns.Sync.BACKFILL_MAX, "backfill sent: " .. n)
end)

H.test("newer version notice shows once", function()
  local ns = boot()
  deliver(ns, "Future-Forever", { t = "H", v = "0.2.0", p = 1 })
  deliver(ns, "Future2-Forever", { t = "H", v = "0.3.0", p = 1 })
  local count = 0
  for _, l in ipairs(DEFAULT_CHAT_FRAME.lines) do if l:find("newer") then count = count + 1 end end
  H.eq(count, 1)
  H.ok(ns.Sync.IsNewerVersion("0.1.10", "0.1.9"))
  H.ok(not ns.Sync.IsNewerVersion("0.1.0", "0.1.0"))
end)

H.done()
