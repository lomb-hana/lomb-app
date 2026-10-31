local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Shared datasets (revisions, digest/want, tombstones, validation)")

local function boot()
  local ns = H.boot()
  H.roster = {
    { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
    { name = "Oakenhollow-Forever", rank = "Member", level = 20, className = "Druid", class = "DRUID", online = true },
  }
  H.fire("GUILD_ROSTER_UPDATE")
  -- a tiny test dataset
  ns.testData = { n = 1 }
  ns.testOn = true
  ns.Shared.Define({ kind = "tt", debounce = 1,
    build = function() return ns.testData end,
    enabled = function() return ns.testOn end,
    validate = function(d) if type(d) == "table" and type(d.n) == "number" then return { n = d.n } end end })
  H.advance(20)
  H.sent = {}
  return ns
end

local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    local payload = a:Feed("me", s.msg)
    if payload then
      local ok, d = ns.Serializer.Unpack(payload)
      H.ok(ok, "own message must decode")
      out[#out + 1] = d
    end
  end
  return out
end
local function ofType(msgs, t, k)
  local out = {}
  for _, m in ipairs(msgs) do if m.t == t and (not k or m.k == k) then out[#out + 1] = m end end
  return out
end

local deliver = H.deliver

H.test("publish sends once per change, with a rising revision", function()
  local ns = boot()
  ns.Shared.MarkDirty("tt")
  H.advance(5)
  local d = ofType(decodeSent(ns), "D", "tt")
  H.eq(#d, 1, "first publish sends")
  H.eq(d[1].d.n, 1)
  local r1 = d[1].r
  H.sent = {}
  ns.Shared.MarkDirty("tt")
  H.advance(5)
  H.eq(#ofType(decodeSent(ns), "D", "tt"), 0, "unchanged data is not resent")
  ns.testData = { n = 2 }
  ns.Shared.MarkDirty("tt")
  H.advance(30)
  d = ofType(decodeSent(ns), "D", "tt")
  H.eq(#d, 1)
  H.ok(d[1].r > r1, "revision rises even within the same second")
  H.eq(#H.errors, 0)
end)

H.test("hello carries a digest; a guildmate with an old copy asks, we answer", function()
  local ns = boot()
  ns.Shared.Publish("tt")
  H.advance(25)
  local own = select(2, ns.Shared.Get("tt", ns.playerKey))
  ns.Sync.SendHello()
  H.advance(2)
  local hello = ofType(decodeSent(ns), "H")[1]
  H.eq(hello.ds.tt, own.r, "digest has our revision")
  H.sent = {}
  deliver(ns, "Oakenhollow-Forever", { t = "W", o = ns.playerKey, k = { "tt" } })
  H.advance(25)
  local d = ofType(decodeSent(ns), "D", "tt")
  H.eq(#d, 1, "want answered")
end)

H.test("receiving: store newer copies, ignore old/duplicate, reject junk", function()
  local ns = boot()
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "tt", r = 1793750500, d = { n = 7 } })
  H.eq(ns.Shared.Get("tt", "Oakenhollow-Forever").n, 7)
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "tt", r = 1793750400, d = { n = 3 } })
  H.eq(ns.Shared.Get("tt", "Oakenhollow-Forever").n, 7, "older revision ignored")
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "tt", r = 1793750600, d = { n = "x" } })
  H.eq(ns.Shared.Get("tt", "Oakenhollow-Forever").n, 7, "invalid data rejected")
  H.ok(ns.Shared.stats.rejected >= 1)
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "zz", r = 1793750600, d = {} })
  H.eq(#H.errors, 0, "unknown kinds are ignored quietly")
  -- withdrawn
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "tt", r = 1793750700, off = true })
  H.eq(ns.Shared.Get("tt", "Oakenhollow-Forever"), nil, "withdrawn copy gone")
end)

H.test("digest from a guildmate: want sent after jitter, suppressed if someone else asked", function()
  local ns = boot()
  deliver(ns, "Oakenhollow-Forever", { t = "H", v = "0.2.0", p = 1, ds = { tt = 1793750500 } })
  H.advance(6)
  local w = ofType(decodeSent(ns), "W")
  H.eq(#w, 1, "asked for the newer copy")
  H.eq(w[1].o, "Oakenhollow-Forever")
  H.eq(w[1].k[1], "tt")
  -- second hello: someone else already asked within the window
  H.sent = {}
  deliver(ns, "Oakenhollow-Forever", { t = "H", v = "0.2.0", p = 1, ds = { tt = 1793750500 } })
  H.advance(6)
  H.eq(#ofType(decodeSent(ns), "W"), 0, "suppressed")
  -- up to date: no want
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "tt", r = 1793750500, d = { n = 1 } })
  H.advance(40)
  H.sent = {}
  deliver(ns, "Oakenhollow-Forever", { t = "H", v = "0.2.0", p = 1, ds = { tt = 1793750500 } })
  H.advance(6)
  H.eq(#ofType(decodeSent(ns), "W"), 0, "no want when current")
end)

H.test("switching sharing off sends a withdrawal", function()
  local ns = boot()
  ns.Shared.Publish("tt")
  H.advance(25)
  H.sent = {}
  ns.testOn = false
  ns.Shared.Publish("tt")
  H.advance(2)
  local d = ofType(decodeSent(ns), "D", "tt")
  H.eq(#d, 1)
  H.ok(d[1].off, "tombstone")
  H.eq(d[1].d, nil, "no data in a withdrawal")
  H.ok(ns.Shared.Digest().tt < 0, "digest marks it withdrawn")
end)

H.test("prune drops copies of long-gone members only", function()
  local ns = boot()
  deliver(ns, "Gone-Forever", { t = "D", k = "tt", r = 1793750500, d = { n = 1 } })
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "tt", r = 1793750500, d = { n = 1 } })
  H.epoch = H.epoch + 31 * 86400
  local n = ns.Shared.Prune()
  H.epoch = 1793750400
  H.eq(n, 1)
  H.eq(ns.Shared.Get("tt", "Gone-Forever"), nil)
  H.ok(ns.Shared.Get("tt", "Oakenhollow-Forever"), "roster member kept")
end)

H.test("messages stay within the traffic rules (255 bytes, guild channel)", function()
  local ns = boot()
  local big = {}
  for i = 1, 400 do big[i] = 100000 + i end
  ns.testData = { n = 1, big = big }
  ns.Shared.kinds.tt.validate = function(d) return d end
  ns.Shared.Publish("tt")
  H.advance(120)
  H.ok(#H.sent > 5, "split into many parts")
  for _, s in ipairs(H.sent) do
    H.ok(#s.msg <= 255)
    H.eq(s.channel, "GUILD")
  end
  local d = ofType(decodeSent(ns), "D", "tt")
  H.eq(#d[1].d.big, 400)
end)

H.done()
