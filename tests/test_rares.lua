local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Bestiary+ (sightings, filters, catch-up, rare alerts)")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", level = 19, className = "Druid", class = "DRUID", online = true },
  { name = "Brindlewick-Forever", rank = "Member", level = 9, className = "Mage", class = "MAGE", online = true },
  { name = "Abbeyrose-Forever", rank = "Member", level = 9, className = "Priest", class = "PRIEST", online = false },
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
local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    H.ok(#s.msg <= 255, "fits in one addon message")
    local payload = a:Feed("me", s.msg)
    if payload then
      local _, d = ns.Serializer.Unpack(payload)
      out[#out + 1] = d
    end
  end
  return out
end
local function ofType(ns, t)
  local out = {}
  for _, m in ipairs(decodeSent(ns)) do if m.t == t then out[#out + 1] = m end end
  return out
end
local function deliver(ns, sender, tbl)
  tbl.v = tbl.v or ns.version
  for _, p in ipairs(ns.Chunker.Split(ns.Serializer.Pack(tbl))) do
    H.fire("CHAT_MSG_ADDON", "LOMBC", p, "GUILD", sender)
  end
end
local function chatHas(s)
  for _, l in ipairs(DEFAULT_CHAT_FRAME.lines) do if l:find(s, 1, true) then return true end end
  return false
end
local function pageText(page)
  local out = {}
  for i = 1, page.used do out[#out + 1] = page.lines[i].left.text or "" end
  return table.concat(out, "\n")
end
local function rare(npcId, spawn, extra)
  local u = { name = "Mother Fang", level = 10, guid = H.guid(npcId, spawn), classification = "rare",
    creatureType = "Beast", family = "Spider", health = 100, healthMax = 100 }
  for k, v in pairs(extra or {}) do u[k] = v end
  return u
end

H.test("sightings count once per spawn and sync as part of my record", function()
  local ns = boot()
  local B = ns.Bestiary
  H.units.target = { name = "Kobold Vermin", level = 2, guid = H.guid(6, "S1"), classification = "normal" }
  H.fire("PLAYER_TARGET_CHANGED")
  H.fire("PLAYER_TARGET_CHANGED")
  H.units.target.guid = H.guid(6, "S2")
  H.fire("PLAYER_TARGET_CHANGED")
  local r = B.Get(6).rec[ns.playerKey]
  H.eq(r.s, 2, "two spawns seen")
  H.eq(B.BuildSyncPayload(6).r.s, 2)
  B.ApplyRemote("Oakenhollow-Forever", { n = 6, nm = "Kobold Vermin", r = { k = 3, s = 5, t = time() } })
  B.ApplyRemote("Brindlewick-Forever", { n = 6, r = { k = 4, t = time() } })
  local agg = B.Aggregate(B.Get(6))
  H.eq(agg.seen, 2 + 5 + 4, "a kill counts as a sighting when nothing else was sent")
  H.eq(B.Merged(6).fields.seen.v, 11)
  B.ApplyRemote("Oakenhollow-Forever", { n = 6, r = { k = 3, s = -4, t = time() + 1 } })
  H.eq(B.Get(6).rec["Oakenhollow-Forever"].s, nil, "bad count dropped")
end)

H.test("list filters, sorts and zone completion", function()
  local ns = boot()
  local B = ns.Bestiary
  local t0 = time()
  local function add(id, nm, lv, cl, zone, k, mine)
    local m = B.Ensure(id)
    m.nm, m.lv, m.cl, m.z[zone] = nm, lv, cl, true
    m.ls = t0 + id
    m.rec[mine and ns.playerKey or "Oakenhollow-Forever"] = { k = k, t = t0 }
  end
  add(1, "Mother Fang", 10, "rare", "Elwynn Forest", 1, true)
  add(2, "Hogger", 11, "elite", "Elwynn Forest", 0)
  add(3, "Kobold Laborer", 4, "normal", "Elwynn Forest", 7)
  add(4, "Murloc Raider", 9, "normal", "Westfall", 2)
  local names = function(list) local o = {} for _, it in ipairs(list) do o[#o + 1] = it.name end return table.concat(o, ",") end
  H.eq(names(B.List("", { filter = "rare" })), "Mother Fang")
  H.eq(names(B.List("", { filter = "elite" })), "Hogger")
  H.eq(names(B.List("", { filter = "zone" })), "Hogger,Kobold Laborer,Mother Fang")
  H.eq(names(B.List("", { filter = "unkilled" })), "Hogger")
  H.eq(names(B.List("", { filter = "mine" })), "Mother Fang")
  H.eq(names(B.List("", { sort = "kills" })), "Kobold Laborer,Murloc Raider,Mother Fang,Hogger")
  H.eq(names(B.List("", { sort = "level" })), "Hogger,Mother Fang,Murloc Raider,Kobold Laborer")
  H.eq(names(B.List("", { sort = "recent" })), "Murloc Raider,Kobold Laborer,Hogger,Mother Fang")
  H.eq(names(B.List("westfall")), "Murloc Raider", "search matches zones")
  local zs = B.ZoneStats()
  H.eq(zs.zone, "Elwynn Forest"); H.eq(zs.known, 3); H.eq(zs.killed, 2); H.eq(zs.mine, 1); H.eq(zs.pct, 67)

  -- the tab's filter button cycles and the count line shows zone completion
  ns.UI.Open("bestiary")
  local p = ns.BestiaryTab.panel
  H.ok(p.count.text:find("Elwynn Forest: 2 of 3 killed (67%)", 1, true), p.count.text)
  p.filter:Click()
  H.eq(p.filter.label.text, "Rares")
  H.ok(p.count.text:find("^1 creature"), p.count.text)
  p.filter:GetScript("OnClick")(p.filter, "RightButton")
  H.eq(p.filter.label.text, "All creatures", "right-click goes back")
  p.sort:Click()
  H.eq(p.sort.label.text, "Sort: level")
end)

H.test("catch-up: my changes since they were last online, plus one relay for offline members", function()
  local ns = boot()
  local B, Sync = ns.Bestiary, ns.Sync
  local t0 = time()
  for id = 1, 3 do
    local m = B.Ensure(id); m.nm = "Mob " .. id
    m.rec[ns.playerKey] = { k = id, t = t0 - id * 1000 }
  end
  B.Ensure(9).rec["Abbeyrose-Forever"] = { k = 2, t = t0 - 500 }      -- offline member
  B.Ensure(9).nm = "Mob 9"
  B.Ensure(8).rec["Brindlewick-Forever"] = { k = 1, t = t0 - 500 }     -- online: speaks for themself
  local since = t0 - 2500
  H.eq(#B.ChangedSince(since, "me"), 2)
  H.eq(B.ChangedSince(since, "me")[1].id, 1, "newest first")

  deliver(ns, "Brindlewick-Forever", { t = "H", p = ns.PROTOCOL })
  H.advance(15)
  H.sent = {}
  deliver(ns, "Oakenhollow-Forever", { t = "H", p = ns.PROTOCOL, bs = since })
  H.advance(30)
  local mobs = ofType(ns, "B")
  H.eq(#mobs, 2, "only my two records changed since then")
  local br = ofType(ns, "BR")
  H.eq(#br, 0, "Brindlewick sorts first, so they relay, not me")

  -- now pretend Brindlewick isn't around: I'm the relay
  Sync.sessionPeers["Brindlewick-Forever"] = nil
  Sync.lastCatchUp = {}
  H.sent = {}
  local sent, relayed = Sync.CatchUp("Oakenhollow-Forever", since)
  H.advance(30)
  H.eq(sent, 2); H.eq(relayed, 2, "Abbeyrose's and (now offline) Brindlewick's records")
  br = ofType(ns, "BR")
  H.eq(#br, 2)
  H.eq(br[1].w ~= nil, true)
  H.eq(select(1, Sync.CatchUp("Oakenhollow-Forever", since)), 0, "cooldown per guildmate")

  -- old/invalid since falls back to a normal backfill
  Sync.lastCatchUp = {}
  H.ok(Sync.CatchUp("Oakenhollow-Forever", "x") ~= nil)
end)

H.test("relayed records are applied under the original recorder, never as mine", function()
  local ns = boot()
  local B = ns.Bestiary
  deliver(ns, "Oakenhollow-Forever", { t = "BR", n = 77, w = "Abbeyrose-Forever", nm = "Gnoll", lv = 8,
    r = { k = 5, s = 6, t = time() } })
  H.eq(B.Get(77).rec["Abbeyrose-Forever"].k, 5)
  H.eq(B.Get(77).rec["Oakenhollow-Forever"], nil)
  deliver(ns, "Oakenhollow-Forever", { t = "BR", n = 78, w = ns.playerKey, r = { k = 99, t = time() } })
  H.eq(B.Get(78), nil, "nobody else speaks for my records")
  deliver(ns, "Oakenhollow-Forever", { t = "BR", n = 79, w = "no spaces allowed", r = { k = 1, t = time() } })
  H.eq(B.Get(79), nil)
end)

H.test("spotting a rare: alert, guild message with map spot, 10 minute throttle", function()
  local ns = boot()
  H.state.pos = { 0.452, 0.618 }
  H.units.nameplate3 = rare(471, "R1")
  H.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
  H.advance(2)
  local ra = ofType(ns, "RA")
  H.eq(#ra, 1)
  H.eq(ra[1].n, 471); H.eq(ra[1].nm, "Mother Fang"); H.eq(ra[1].z, "Elwynn Forest")
  H.eq(ra[1].x, 45); H.eq(ra[1].y, 62)
  H.eq(ra[1].cl, "rare")
  local toast = ns.RareToast.frame
  H.ok(toast and toast:IsShown(), "toast shown")
  H.ok(toast.text.text:find("Mother Fang", 1, true))
  H.ok(toast.text.text:find("(45, 62)", 1, true))
  local m = ns.Bestiary.Get(471)
  H.eq(m.rs.by, ns.playerKey); H.eq(m.rs.x, 45)
  H.eq(m.rec[ns.playerKey].s, 1, "counted as a sighting")
  H.eq(ns.Bestiary.BuildSyncPayload(471).rs, nil, "spot location never goes in bestiary sync")

  -- same rare again (target, another spawn) inside 10 min: nothing more sent
  H.sent = {}
  H.units.target = rare(471, "R1")
  H.fire("PLAYER_TARGET_CHANGED")
  H.advance(60)
  H.eq(#ofType(ns, "RA"), 0)
  H.ok(not toast:IsShown(), "toast hid itself")
  H.advance(600)
  H.units.target = rare(471, "R2")
  H.fire("PLAYER_TARGET_CHANGED")
  H.advance(2)
  H.eq(#ofType(ns, "RA"), 1, "announced again after the cooldown")

  -- normal mobs, dead rares and players never trigger
  H.sent = {}
  H.units.target = { name = "Boar", level = 3, guid = H.guid(113, "X"), classification = "normal" }
  H.fire("PLAYER_TARGET_CHANGED")
  H.units.target = rare(472, "D", { dead = true })
  H.fire("PLAYER_TARGET_CHANGED")
  H.units.target = { name = "Someone", level = 10, guid = "Player-1-0ABC", classification = "rare", isPlayer = true }
  H.fire("PLAYER_TARGET_CHANGED")
  H.advance(2)
  H.eq(#ofType(ns, "RA"), 0)
end)

H.test("toast click opens the creature in the Bestiary", function()
  local ns = boot()
  H.units.target = rare(471, "R1")
  H.fire("PLAYER_TARGET_CHANGED")
  ns.RareToast.frame:Click()
  H.ok(not ns.RareToast.frame:IsShown())
  H.ok(ns.UI.frame:IsShown(), "window open")
  H.eq(ns.BestiaryTab.panel.page.npcId, 471)
  local txt = pageText(ns.BestiaryTab.panel.page)
  H.ok(txt:find("Last spotted", 1, true) and txt:find("by you", 1, true), txt)
  H.ok(txt:find("Guild sightings", 1, true), txt)
end)

H.test("a guildmate's rare: chat line + toast, several spotters = one alert", function()
  local ns = boot()
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = 61, nm = "Thuros Lightfingers", lv = 11, cl = "rare",
    z = "Elwynn Forest", x = 89, y = 79 })
  H.ok(chatHas("Oakenhollow spotted the rare"), "chat line")
  H.ok(chatHas("Elwynn Forest (89, 79)"))
  H.ok(ns.RareToast.frame:IsShown())
  H.ok(ns.RareToast.frame.title.text:find("guildmate"))
  local m = ns.Bestiary.Get(61)
  H.eq(m.nm, "Thuros Lightfingers"); H.eq(m.rs.by, "Oakenhollow-Forever"); H.eq(m.rs.y, 79)
  local lines = #DEFAULT_CHAT_FRAME.lines
  deliver(ns, "Brindlewick-Forever", { t = "RA", n = 61, nm = "Thuros Lightfingers", cl = "rare", z = "Elwynn Forest" })
  H.eq(#DEFAULT_CHAT_FRAME.lines, lines, "deduped")
  H.eq(m.rs.by, "Brindlewick-Forever", "but the latest spot is kept")
  H.eq(m.rs.x, nil)

  -- bad messages are ignored
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = 62, cl = "normal" })
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = "x", cl = "rare" })
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = 63, cl = "rare", x = 500, y = 2 })
  H.eq(ns.Bestiary.Get(62), nil); H.eq(ns.Bestiary.Get(63).rs.x, nil, "out-of-range spot dropped")

  -- in an encounter: chat only, no toast
  ns.RareToast.frame:Hide()
  H.state.encounter = true
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = 64, nm = "Gruff Swiftbite", cl = "rare", z = "Elwynn Forest" })
  H.ok(chatHas("Gruff Swiftbite"))
  H.ok(not ns.RareToast.frame:IsShown(), "no toast mid-encounter")
end)

H.test("settings: alerts off, sharing off", function()
  local ns = boot()
  ns.db.settings.shareRares = false
  H.units.target = rare(471, "R1")
  H.fire("PLAYER_TARGET_CHANGED")
  H.advance(2)
  H.eq(#ofType(ns, "RA"), 0, "nothing sent")
  H.ok(ns.RareToast.frame and ns.RareToast.frame:IsShown(), "still alerts me")
  ns.RareToast.frame:Hide()
  ns.db.settings.rareAlerts = false
  local lines = #DEFAULT_CHAT_FRAME.lines
  deliver(ns, "Oakenhollow-Forever", { t = "RA", n = 61, nm = "Thuros", cl = "rare" })
  H.eq(#DEFAULT_CHAT_FRAME.lines, lines)
  H.ok(not ns.RareToast.frame:IsShown())
  H.eq(ns.Bestiary.Get(61).rs.by, "Oakenhollow-Forever", "still noted in the bestiary")
end)

H.test("secret values in combat never trigger or leak", function()
  local ns = boot()
  H.units.target = rare(471, "R1", { classification = H.secret("rare") })
  H.fire("PLAYER_TARGET_CHANGED")
  H.units.target = rare(472, "R2", { guid = H.secret(H.guid(472, "R2")) })
  H.fire("PLAYER_TARGET_CHANGED")
  H.advance(2)
  H.eq(#ofType(ns, "RA"), 0)
  H.ok(not (ns.RareToast.frame and ns.RareToast.frame:IsShown()))
end)

H.done()
