local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Profiles: gear, XP, alts and mains")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", level = 19, className = "Druid", class = "DRUID", online = false, days = 1 },
  { name = "Brindlewick-Forever", rank = "Member", level = 9, className = "Mage", class = "MAGE", online = true },
  { name = "Twigsnap-Forever", rank = "Alt", level = 5, className = "Rogue", class = "ROGUE", online = false,
    note = "alt of Oakenhollow" },
}
local function copyRoster()
  local out = {}
  for i, r in ipairs(ROSTER) do local c = {} for k, v in pairs(r) do c[k] = v end out[i] = c end
  return out
end
local function boot(opts)
  local ns = H.boot(opts)
  H.roster = copyRoster()
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.sent = {}
  return ns
end
local function link(id, ench, suffix)
  return ("|cff1eff00|Hitem:%d:%s:::::%s:12345:12:::::|h[Item %d]|h|r"):format(id, ench or "", suffix or "", id)
end
local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    local payload = a:Feed("me", s.msg)
    if payload then
      local _, d = ns.Serializer.Unpack(payload)
      out[#out + 1] = d
    end
  end
  return out
end
local function lastOf(ns, kind)
  local found
  for _, m in ipairs(decodeSent(ns)) do if m.t == "D" and m.k == kind then found = m end end
  return found
end
local rev = 0
local function remote(ns, sender, kind, d)
  rev = rev + 1
  for _, p in ipairs(ns.Chunker.Split(ns.Serializer.Pack({ t = "D", k = kind, r = H.epoch + rev, d = d }))) do
    H.fire("CHAT_MSG_ADDON", "LOMBC", p, "GUILD", sender)
  end
  H.advance(2)
end

H.test("compact links keep only item, enchant and suffix", function()
  local ns = boot()
  local P = ns.Profiles
  H.eq(P.CompactLink(link(2575)), "2575")
  H.eq(P.CompactLink(link(15372, 723)), "15372:723")
  H.eq(P.CompactLink(link(6087, "", 1027)), "6087:0:1027")
  H.eq(P.CompactLink("junk"), nil)
  H.eq(P.ItemString("15372:723"), "item:15372:723:::::0")
  local id, e, s = P.ParseCompact("6087:0:1027")
  H.eq(id, 6087); H.eq(e, 0); H.eq(s, 1027)
  H.eq(P.ParseCompact("12:abc"), nil)
end)

H.test("gear + XP are published (5% steps) and withdrawn when sharing is off", function()
  local ns = boot()
  H.gear = { [1] = link(10, 5), [16] = link(2575), [4] = link(45) }
  H.fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
  H.advance(120)
  local m = lastOf(ns, "gr")
  H.ok(m and m.d, "gear dataset sent")
  H.eq(m.d.g[1], "10:5"); H.eq(m.d.g[16], "2575"); H.eq(m.d.g[4], "45")
  H.eq(m.d.xp, 40)            -- 1200 / 3000
  H.eq(m.d.mn, nil, "no main until you pick one")
  for _, s in ipairs(H.sent) do H.ok(#s.msg <= 255) end
  H.sent = {}
  ns.db.settings.shareProfile = false
  ns.Shared.MarkDirty("gr")
  H.advance(120)
  m = lastOf(ns, "gr")
  H.ok(m and m.off, "withdrawn")
end)

H.test("picking a main is shared even with profile sharing off, and covers other characters", function()
  local ns = boot()
  ns.db.settings.shareProfile = false
  local g = ns.DB.Guild()
  g.myChars["Oakenhollow-Forever"] = { lv = 19, cl = "DRUID", at = H.epoch }
  ns.UI.CycleMain(1)          -- not set -> me
  H.eq(ns.Profiles.MyMain(), "Testy-Forever")
  ns.UI.CycleMain(1)          -- -> my other character
  H.eq(ns.Profiles.MyMain(), "Oakenhollow-Forever")
  H.eq(g.accountMain, "Oakenhollow-Forever")
  H.advance(120)
  local m = lastOf(ns, "gr")
  H.ok(m and m.d and m.d.mn == "Oakenhollow-Forever", "main shared")
  H.eq(m.d.g, nil, "no gear when sharing is off")
  H.eq(m.d.xp, nil)
  ns.UI.CycleMain(1)          -- -> not set
  H.eq(ns.Profiles.MyMain(), nil)
  H.eq(ns.char.main, false)
  -- a relog on another character picks the account main
  local db = _G.LOMBCompanionDB
  ns = boot({ db = db })
  ns.DB.Guild().accountMain = "Oakenhollow-Forever"
  H.eq(ns.Profiles.MyMain(), "Oakenhollow-Forever")
end)

H.test("guild notes link alts for members without the addon", function()
  local ns = boot()
  local P = ns.Profiles
  H.eq(P.MainFromNote("alt of Oakenhollow"), "Oakenhollow")
  H.eq(P.MainFromNote("Alt: Bob"), "Bob")
  H.eq(P.MainFromNote("Bob's alt"), "Bob")
  H.eq(P.MainFromNote("bob alt"), "bob")
  H.eq(P.MainFromNote("main"), nil)
  H.eq(P.MainFromNote("Loves fishing"), nil)
  H.advance(2)
  local main, src = P.MainOf("Twigsnap-Forever")
  H.eq(main, "Oakenhollow-Forever"); H.eq(src, "note")
  H.deepEq(P.AltsOf("Oakenhollow-Forever"), { "Twigsnap-Forever" })
  -- a note naming someone not in the guild is ignored
  H.roster[3].note = "alt of Nobodyhere"
  H.fire("GUILD_ROSTER_UPDATE"); H.advance(3)
  H.eq(P.MainOf("Brindlewick-Forever"), nil)
end)

H.test("addon-declared main beats the guild note; hide-alts view", function()
  local ns = boot()
  remote(ns, "Twigsnap-Forever", "gr", { mn = "Brindlewick" })
  H.advance(2)
  local main, src = ns.Profiles.MainOf("Twigsnap-Forever")
  H.eq(main, "Brindlewick-Forever"); H.eq(src, "addon")
  local all = ns.Roster.View({})
  H.eq(#all, 4)
  local hidden = ns.Roster.View({ hideAlts = true })
  H.eq(#hidden, 3)
  for _, r in ipairs(hidden) do H.ok(r.name ~= "Twigsnap-Forever") end
  H.eq(ns.Roster.byName["Brindlewick-Forever"].altCount, 1)
  H.eq(ns.Roster.byName["Twigsnap-Forever"].mainShort, "Brindlewick")
end)

H.test("bad gear data from others is cleaned", function()
  local ns = boot()
  remote(ns, "Brindlewick-Forever", "gr", { g = { [1] = "123:4", [2] = "|cffff0000evil", [40] = "5", [3] = 7 },
    xp = 250, mn = "has space" })
  local d = ns.Shared.Get("gr", "Brindlewick-Forever")
  H.ok(d, "accepted")
  H.eq(d.g[1], "123:4"); H.eq(d.g[2], nil); H.eq(d.g[40], nil); H.eq(d.g[3], nil)
  H.eq(d.xp, nil); H.eq(d.mn, nil)
end)

H.test("inspecting a guildmate fills in their gear locally (never sent)", function()
  local ns = boot()
  H.units.target = { name = "Twigsnap", guid = "Player-1-0001", isPlayer = true }
  H.unitGear.target = { [1] = link(777), [7] = link(888, 12) }
  H.sent = {}
  H.fire("INSPECT_READY", "Player-1-0001")
  local p = ns.Profiles.Get("Twigsnap-Forever")
  H.eq(p.gear[1], "777"); H.eq(p.gear[7], "888:12")
  H.ok(p.gearSeen, "marked as inspected")
  H.eq(ns.Profiles.EmptySlots(p.gear), 14)
  H.advance(120)
  for _, m in ipairs(decodeSent(ns)) do H.ok(not (m.t == "D" and m.k == "gr" and m.d and m.d.g and m.d.g[7]), "not sent") end
  -- strangers are ignored
  H.units.target = { name = "Randomguy", guid = "Player-1-0002", isPlayer = true }
  H.fire("INSPECT_READY", "Player-1-0002")
  H.eq(ns.DB.Guild().inspected["Randomguy-Forever"], nil)
end)

H.test("profile page renders for me, a sharer and a non-addon member", function()
  local ns = boot()
  H.gear = { [1] = link(10, 5), [16] = link(2575) }
  remote(ns, "Brindlewick-Forever", "gr", { g = { [1] = "123:4", [5] = "99" }, xp = 55 })
  remote(ns, "Brindlewick-Forever", "st", { lv = 9, k = 420, r = 2 })
  SlashCmdList.LOMB("roster")
  for _, who in ipairs({ "Testy-Forever", "Brindlewick-Forever", "Twigsnap-Forever" }) do
    ns.RosterTab.OpenProfile(who)
    H.advance(1)
    H.eq(#H.errors, 0, who .. ": " .. tostring(H.errors[1]))
    H.ok(ns.RosterTab.panel.profile:IsShown(), "profile shown")
  end
  local p = ns.Profiles.Get("Brindlewick-Forever")
  H.eq(p.gear[5], "99"); H.eq(p.xp, 55); H.eq(p.stats.k, 420)
  ns.RosterTab.CloseProfile()
  H.ok(not ns.RosterTab.panel.profile:IsShown(), "back to roster")
  H.ok(ns.RosterTab.panel.list:IsShown(), "list back")
  H.eq(#H.errors, 0, tostring(H.errors[1]))
end)

H.done()
