local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Code verification fixes (guildmate input, prune timing, /played)")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", level = 19, className = "Druid", class = "DRUID", online = true },
}
local function boot(opts)
  local ns = H.boot(opts)
  H.roster = {}
  for i, r in ipairs(ROSTER) do local c = {} for k, v in pairs(r) do c[k] = v end H.roster[i] = c end
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.sent = {}
  return ns
end
local function deliver(ns, sender, tbl) tbl.v = tbl.v or ns.version; H.deliver(ns, sender, tbl) end
local function noEscapes(s, what) H.ok(type(s) == "string" and not s:find("[%c|]"), what .. ": " .. tostring(s)) end

H.test("a guildmate's rare alert can't put escape codes in chat or the bestiary", function()
  local ns = boot()
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = 61, nm = "Thuros|TInterface\\Icons\\X:999|t", cl = "rare",
    z = "Elwynn|Hitem:1|h[x]|h\nForest" })
  local e = ns.Rares.recent[1]
  noEscapes(e.nm, "name"); noEscapes(e.z, "zone")
  noEscapes(ns.Bestiary.Get(61).nm, "bestiary name")
  for _, l in ipairs(DEFAULT_CHAT_FRAME.lines) do
    if l:find("spotted", 1, true) then H.ok(not l:find("|T", 1, true) and not l:find("|H", 1, true), l) end
  end
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = 62, nm = "||||", cl = "rare" })
  H.eq(ns.Rares.recent[1].nm, nil, "nothing left after cleaning = no name")
  H.noErrors("rares")
end)

H.test("bestiary records from guildmates: clean strings, whole ids only", function()
  local ns = boot()
  local B = ns.Bestiary
  H.eq(B.ApplyRemote("Oakenhollow-Forever", { n = 12.5, nm = "Half" }), false, "fractional npc id refused")
  H.eq(B.Get(12.5), nil)
  B.ApplyRemote("Oakenhollow-Forever", { n = 70, nm = "Bad|cffff0000Wolf", cl = "rare|r", ct = "Beast\n",
    z = { "Elwynn|TX|t" }, sp = { 0, 1.5, 133 },
    r = { t = H.epoch, k = 2, c = 2, i = { [0] = 1, [2.5] = 1, [2589] = 1 } } })
  local m = B.Get(70)
  noEscapes(m.nm, "name"); noEscapes(m.cl, "class"); noEscapes(m.ct, "type")
  for z in pairs(m.z) do noEscapes(z, "zone") end
  H.eq(m.sp[0], nil); H.eq(m.sp[1.5], nil); H.ok(m.sp[133], "real spell kept")
  local r = m.rec["Oakenhollow-Forever"]
  H.eq(r.i[0], nil); H.eq(r.i[2.5], nil); H.eq(r.i[2589], 1)
  H.noErrors("bestiary")
end)

H.test("a guildmate's profile is cleaned before it is saved or shown", function()
  local ns = boot()
  local big = {}
  for i = 1, 40 do big["P" .. i] = { i, 300 } end
  big["Bad|T1:1|t"] = 5
  big.Junk = { "x" }
  deliver(ns, "Oakenhollow-Forever", { t = "P", v = "9.9|cffff0000!", lv = 19, cl = "DRUID|r",
    il = "high", pt = -4, pr = big })
  local peer = ns.DB.Guild().peers["Oakenhollow-Forever"]
  noEscapes(peer.v, "version"); noEscapes(peer.profile.cl, "class")
  H.eq(peer.profile.lv, 19); H.eq(peer.profile.il, nil); H.eq(peer.profile.pt, nil)
  local n = 0
  for code, v in pairs(peer.profile.pr) do
    n = n + 1; noEscapes(code, "profession code"); H.ok(code ~= "Junk", "no rank = dropped")
    H.ok(type(v) == "number" or type(v[1]) == "number", "numeric rank")
  end
  H.ok(n <= 16, "at most 16 professions kept, got " .. n)
  -- my own profile still round-trips
  ns.Sync.SendProfile()
  local mine = ns.DB.Guild().peers[ns.playerKey]
  H.ok(mine and mine.profile, "own profile kept")
  H.noErrors("profile")
end)

H.test("the newer-version notice prints a cleaned version", function()
  local ns = boot()
  deliver(ns, "Oakenhollow-Forever", { t = "H", p = 1, v = "99.0|Hurl:x|h[click]|h" })
  noEscapes(ns.Sync.newerVersionSeen, "version")
  for _, l in ipairs(DEFAULT_CHAT_FRAME.lines) do
    if l:find("newer LOMB", 1, true) then H.ok(not l:find("|H", 1, true), l) end
  end
end)

H.test("inspected gear isn't wiped when the roster hasn't loaded yet", function()
  local ns = boot()
  local g = ns.DB.Guild()
  g.inspected = { ["Oakenhollow-Forever"] = { t = H.epoch }, ["Gone-Forever"] = { t = H.epoch } }
  local members, byName = ns.Roster.members, ns.Roster.byName
  ns.Roster.members, ns.Roster.byName = {}, {}
  ns.Profiles.PruneInspected()
  H.ok(g.inspected["Oakenhollow-Forever"] and g.inspected["Gone-Forever"], "kept while the roster is empty")
  ns.Roster.members, ns.Roster.byName = members, byName
  ns.Profiles.PruneInspected()
  H.ok(g.inspected["Oakenhollow-Forever"], "still in the guild: kept")
  H.eq(g.inspected["Gone-Forever"], nil, "left the guild: pruned")
end)

H.test("a lost /played reply doesn't swallow the player's own /played later", function()
  local ns = boot()
  H.state.playedPrinted = 0
  ns.Me.RequestPlayed()
  H.advance(11)
  ChatFrame_DisplayTimePlayed()
  H.eq(H.state.playedPrinted, 1, "the player's /played printed")
  ns.Me.RequestPlayed()
  ChatFrame_DisplayTimePlayed()
  H.eq(H.state.playedPrinted, 1, "our own request still stays quiet")
end)

H.done()
