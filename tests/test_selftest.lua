local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("/lomb test self-test")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", level = 19, className = "Druid", class = "DRUID", online = false, days = 1 },
  { name = "Brindlewick-Forever", rank = "Member", level = 9, className = "Mage", class = "MAGE", online = true },
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
    local payload = a:Feed("me", s.msg)
    if payload then local _, d = ns.Serializer.Unpack(payload); out[#out + 1] = d end
  end
  return out
end
local function sentOf(ns, t)
  local out = {}
  for _, m in ipairs(decodeSent(ns)) do if m.t == t then out[#out + 1] = m end end
  return out
end
local function peerOnline(ns)
  H.deliver(ns, "Brindlewick-Forever", { t = "H", p = ns.PROTOCOL, v = "0.9.4" })
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(3)
  H.sent = {}
end
local function lineOf(text, label)
  for l in text:gmatch("[^\n]+") do if l:find("%] " .. label .. ":") then return l end end
end

H.test("is wired to /lomb test and listed in the help", function()
  local ns = boot()
  local printed = {}
  local orig = ns.Print
  ns.Print = function(fmt, ...) printed[#printed + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
  ns.HandleSlash("help")
  local found
  for _, l in ipairs(printed) do if l:find("/lomb test", 1, true) then found = true end end
  H.ok(found, "help lists /lomb test")
  printed = {}
  ns.HandleSlash("test")
  H.ok(ns.SelfTest.run, "slash starts a run")
  H.ok(ns.SelfTest.run.done, "no peers: finishes at once")
  ns.Print = orig
  H.noErrors("slash test")
end)

H.test("no guildmates with LOMB online: every check runs, the echo is skipped with a warning", function()
  local ns = boot()
  local got
  ns.SelfTest.Run({ quiet = true, onDone = function(text, counts) got = { text = text, counts = counts } end })
  H.ok(got, "finished without waiting")
  local text = got.text
  for _, label in ipairs({ "Addon errors", "Game APIs", "Guild roster", "Addon channel", "Sync echo", "Calendar",
    "Skill lines", "Bundled data", "Saved variables", "Situation" }) do
    H.ok(lineOf(text, label), "line for " .. label)
  end
  H.ok(lineOf(text, "Sync echo"):find("^%[WARN%]"), "echo skipped is a warning")
  H.ok(lineOf(text, "Guild roster"):find("^%[PASS%]"), "roster read")
  H.ok(lineOf(text, "Skill lines"):find("^%[PASS%]"), "skills read")
  H.ok(lineOf(text, "Bundled data"):find("^%[PASS%]"), lineOf(text, "Bundled data"))
  H.eq(got.counts.fail, 0, text)
  H.eq(#sentOf(ns, "TP"), 0, "no ping without peers")
  -- no personal info in the copyable text
  H.ok(not text:find("Testy"), "no character name")
  H.ok(not text:find("Brindlewick") and not text:find("Oakenhollow"), "no guildmate names")
  H.ok(not text:find("Land of Make Believe"), "no guild name")
  H.ok(text:find("^LOMB Companion " .. ns.version:gsub("%.", "%%.")), "header has the version")
end)

H.test("echo: a guildmate's addon answers the ping", function()
  local ns = boot()
  peerOnline(ns)
  local got
  local run = ns.SelfTest.Run({ quiet = true, onDone = function(text) got = text end })
  H.ok(not run.done, "waiting for an answer")
  H.advance(1)
  local pings = sentOf(ns, "TP")
  H.eq(#pings, 1, "one ping")
  H.advance(0.8)
  H.deliver(ns, "Brindlewick-Forever", { t = "TQ", id = pings[1].id, to = ns.playerKey, v = "0.9.4" })
  H.ok(got, "finished on the answer")
  local l = lineOf(got, "Sync echo")
  H.ok(l:find("^%[PASS%]") and l:find("0.9.4", 1, true), l)
  H.ok(not got:find("Brindlewick"), "the answering guildmate isn't named")
  -- an answer meant for someone else is ignored
  H.deliver(ns, "Brindlewick-Forever", { t = "TQ", id = "x", to = "Other-Forever" })
  H.noErrors("echo")
end)

H.test("echo: nobody answers in time", function()
  local ns = boot()
  peerOnline(ns)
  local got
  ns.SelfTest.Run({ quiet = true, onDone = function(text) got = text end })
  H.advance(ns.SelfTest.ECHO_TIMEOUT - 1)
  H.eq(got, nil, "still waiting")
  H.advance(2)
  H.ok(got, "timed out")
  H.ok(lineOf(got, "Sync echo"):find("^%[WARN%].*no answer in 12 s from 1 guildmate online"), lineOf(got, "Sync echo"))
  -- a second run is allowed after the first ends
  local again = ns.SelfTest.Run({ quiet = true })
  H.ok(again ~= nil)
end)

H.test("answering: one reply per ping, cancelled if someone beats us, cooldown per sender", function()
  local ns = boot()
  H.deliver(ns, "Brindlewick-Forever", { t = "TP", id = "1" })
  H.advance(ns.SelfTest.MAX_REPLY_DELAY + 1)
  local r = sentOf(ns, "TQ")
  H.eq(#r, 1, "answered")
  H.eq(r[1].to, "Brindlewick-Forever"); H.eq(r[1].id, "1"); H.eq(r[1].v, ns.version)
  -- again within the cooldown: silent
  H.sent = {}
  H.deliver(ns, "Brindlewick-Forever", { t = "TP", id = "2" })
  H.advance(ns.SelfTest.MAX_REPLY_DELAY + 1)
  H.eq(#sentOf(ns, "TQ"), 0, "cooldown")
  -- another guildmate answers first: we stay quiet
  H.advance(ns.SelfTest.REPLY_COOLDOWN)
  H.sent = {}
  local orig = math.random
  math.random = function(a) if a then return orig(a) end return 0.99 end
  H.deliver(ns, "Brindlewick-Forever", { t = "TP", id = "3" })
  H.deliver(ns, "Oakenhollow-Forever", { t = "TQ", id = "3", to = "Brindlewick-Forever" })
  H.advance(ns.SelfTest.MAX_REPLY_DELAY + 1)
  math.random = orig
  H.eq(#sentOf(ns, "TQ"), 0, "someone beat us")
  -- junk ids are ignored
  H.deliver(ns, "Oakenhollow-Forever", { t = "TP", id = string.rep("x", 40) })
  H.deliver(ns, "Oakenhollow-Forever", { t = "TP", id = 5 })
  H.advance(5)
  H.eq(#sentOf(ns, "TQ"), 0, "junk ignored")
  H.noErrors("answering")
end)

H.test("a broken check is reported as a failure, not a crash; errors are counted", function()
  local ns = boot()
  table.insert(ns.SelfTest.checks, function() error("boom") end)
  ns.errors.n = 2
  local got, counts
  ns.SelfTest.Run({ quiet = true, onDone = function(t, c) got, counts = t, c end })
  table.remove(ns.SelfTest.checks)
  H.ok(lineOf(got, "Check crashed"):find("^%[FAIL%]"), "crash line")
  H.ok(lineOf(got, "Addon errors"):find("^%[WARN%].*2 caught"), lineOf(got, "Addon errors"))
  H.ok(counts.fail >= 1 and counts.warn >= 1)
end)

H.test("not in a guild: roster and channel say so plainly", function()
  local ns = H.boot({ guild = false })
  H.advance(5)
  local got
  ns.SelfTest.Run({ quiet = true, onDone = function(t) got = t end })
  H.ok(got, "finished")
  H.ok(not lineOf(got, "Guild roster"):find("^%[PASS%]"), lineOf(got, "Guild roster"))
  H.ok(lineOf(got, "Sync echo"):find("^%[WARN%]"))
end)

H.test("the copy window opens with the report", function()
  local ns = boot()
  ns.SelfTest.Run()
  local f = _G.LOMBCompanionCopy
  H.ok(f and f:IsShown(), "window shown")
  H.ok(ns.SelfTest.last and #ns.SelfTest.last > 100)
  local found
  for _, n in ipairs(UISpecialFrames) do if n == "LOMBCompanionCopy" then found = true end end
  H.ok(found, "ESC closes it")
  H.noErrors("copy window")
end)

local function report(ns)
  local got
  ns.SelfTest.Run({ quiet = true, onDone = function(text, counts) got = { text = text, counts = counts } end })
  return got.text, got.counts
end
local FEATURE_LINES = { "Me tab", "Crafters", "News", "Leaderboard", "Bestiary", "Quests & items", "Loot browser",
  "Ask LOMB", "Events", "Wishlist", "Guild bank", "Settings & look", "Tour" }

H.test("a line for every feature: all pass on a fresh install, nothing sent, no names", function()
  local ns = boot()
  H.said = {}
  local text, counts = report(ns)
  for _, label in ipairs(FEATURE_LINES) do
    local l = lineOf(text, label)
    H.ok(l, "line for " .. label)
    H.ok(l:find("^%[PASS%]"), l)
  end
  H.ok(lineOf(text, "Game APIs"):find("^%[PASS%]"), lineOf(text, "Game APIs"))
  H.ok(lineOf(text, "Leaderboard"):find("4 boards built", 1, true), lineOf(text, "Leaderboard"))
  H.ok(lineOf(text, "Quests & items"):find("class guides loaded", 1, true), lineOf(text, "Quests & items"))
  H.ok(lineOf(text, "Tour"):find("4 of 4 steps ready", 1, true), lineOf(text, "Tour"))
  H.ok(lineOf(text, "Settings & look"):find("look storybook", 1, true), lineOf(text, "Settings & look"))
  H.eq(counts.fail, 0, text)
  H.eq(#H.said, 0, "no chat messages")
  H.eq(#H.sent, 0, "no addon messages without peers")
  H.eq(#ns.Ask.history, 0, "the sample question isn't added to Ask history")
  H.ok(not text:find("Testy") and not text:find("Brindlewick") and not text:find("Oakenhollow"), "no names")
  H.noErrors("feature lines")
end)

H.test("feature lines read live data", function()
  local ns = boot()
  ns.Wishlist.Add("n", "Linen Cloth", 3)
  ns.Bestiary.ApplyRemote("Oakenhollow-Forever", { n = 99001, nm = "Test Wolf" })
  ns.db.settings.recordAttendance = false
  local text = report(ns)
  H.ok(lineOf(text, "Wishlist"):find("1 of 20 entries on yours", 1, true), lineOf(text, "Wishlist"))
  H.ok(lineOf(text, "Bestiary"):find("1 creature known (1 listed)", 1, true), lineOf(text, "Bestiary"))
  H.ok(lineOf(text, "Events"):find("^%[WARN%].*recording off"), lineOf(text, "Events"))
  H.ok(not text:find("Test Wolf", 1, true), "no creature names either")
end)

H.test("a feature whose functions break shows up as a failed check", function()
  local ns = boot()
  local keep = ns.Crafting.Search
  ns.Crafting.Search = function() error("boom") end
  local text, counts = report(ns)
  ns.Crafting.Search = keep
  H.eq(lineOf(text, "Crafters"), nil, "no pass line")
  H.ok(text:find("Check crashed", 1, true) and text:find("boom", 1, true), text)
  H.ok(counts.fail >= 1)
end)

H.test("missing optional APIs are named with what stays off", function()
  local ns = boot()
  local keep = { _G.GetNumGroupMembers, _G.RequestTimePlayed }
  _G.GetNumGroupMembers, _G.RequestTimePlayed = nil, nil
  local text, counts = report(ns)
  _G.GetNumGroupMembers, _G.RequestTimePlayed = keep[1], keep[2]
  local l = lineOf(text, "Game APIs")
  H.ok(l:find("^%[WARN%]") and l:find("GetNumGroupMembers (event attendance)", 1, true)
    and l:find("RequestTimePlayed (time played and the Played board)", 1, true)
    and l:find("missing (what stays off)", 1, true), l)
  H.eq(counts.fail, 0, "optional APIs only warn")
end)

H.done()
