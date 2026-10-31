-- LOMB Companion: /lomb test -- a self-test for launch day.
-- Checks that the game gives the addon what it needs (APIs, guild roster, addon
-- channel, calendar, skill lines), that the bundled data and saved variables are
-- healthy, that every feature's own functions run (one read-only line per
-- feature: Me, Crafters, News, Leaderboard, Bestiary, Quests & items, Loot,
-- Ask LOMB, Events, Wishlist, Guild bank, Settings & look, Tour), and -- when
-- a guildmate with LOMB is online -- that a message makes it there and back. Prints PASS / WARN / FAIL lines in chat and opens a window the
-- report can be copied from. Nothing personal goes in the report: no character,
-- guild or guildmate names.
local _, ns = ...
local C = ns.Compat
local ST = ns:NewModule("SelfTest")

ST.ECHO_TIMEOUT = 12        -- seconds to wait for a guildmate to answer the ping
ST.REPLY_COOLDOWN = 30      -- answer any one guildmate's pings at most this often
ST.MAX_REPLY_DELAY = 3      -- answers are spread over 0..3 s; the first one wins

local MARK = { pass = "|cff7fe07fPASS|r", warn = "|cffe0b060WARN|r", fail = "|cffe65959FAIL|r", info = "|cff9991a8INFO|r" }
local PLAIN = { pass = "PASS", warn = "WARN", fail = "FAIL", info = "INFO" }

local function get(path)
  local v = _G
  for part in path:gmatch("[^%.]+") do
    if type(v) ~= "table" then return nil end
    v = v[part]
  end
  return v
end

-- name, required, alternative, what stays off without it (optional ones)
ST.APIS = {
  { "C_ChatInfo.SendAddonMessage", true, "SendAddonMessage" },
  { "C_ChatInfo.RegisterAddonMessagePrefix", true, "RegisterAddonMessagePrefix" },
  { "GetGuildRosterInfo", true }, { "GetNumGuildMembers", true }, { "GetGuildInfo", true },
  { "C_Timer.After", true }, { "UnitGUID", true },
  { "GetGuildRosterLastOnline", false, nil, "last-online in the roster" },
  { "GetServerTime", false, nil, "realm-time event clocks" },
  { "C_Calendar.OpenCalendar", false, nil, "the Events tab" }, { "C_Calendar.GetDayEvent", false, nil, "the Events tab" },
  { "C_DateAndTime.GetCurrentCalendarTime", false, nil, "event times" },
  { "GetSkillLineInfo", false, "C_SkillInfo.GetSkillLineInfo", "professions on the Me tab" },
  { "GetLootSlotInfo", false, nil, "bestiary loot" }, { "GetLootSourceInfo", false, nil, "bestiary loot" },
  { "GetNumLootItems", false, nil, "bestiary loot" }, { "GetLootSlotLink", false, nil, "bestiary loot" },
  { "C_Map.GetBestMapForUnit", false, nil, "zones and rare spots" },
  { "C_Item.GetItemInfo", false, "GetItemInfo", "item names and icons" },
  { "RequestTimePlayed", false, nil, "time played and the Played board" },
  { "GetTradeSkillLine", false, nil, "recipe scanning for Crafters" },
  { "GetNumGroupMembers", false, nil, "event attendance" }, { "IsInRaid", false, nil, "event attendance" },
  { "GetInventoryItemLink", false, nil, "gear on profiles" },
  { "C_Container.GetContainerItemInfo", false, "GetContainerItemInfo", "the guild bank list" },
}

---------------------------------------------------------------------------
-- the checks (each returns status, label, detail)
---------------------------------------------------------------------------
local checks = {}

checks[#checks + 1] = function()
  local errs = ns.errors and ns.errors.n or 0
  if errs > 0 then
    return "warn", "Addon errors", ("%d caught this session; last: %s"):format(errs,
      tostring(ns.errors.last or "?"):gsub("|", "/"):sub(1, 140))
  end
  return "pass", "Addon errors", "none this session"
end

checks[#checks + 1] = function()
  local missingReq, missingOpt = {}, {}
  for _, a in ipairs(ST.APIS) do
    local ok = type(get(a[1])) == "function" or (a[3] and type(get(a[3])) == "function")
    if not ok then
      local into = a[2] and missingReq or missingOpt
      into[#into + 1] = a[4] and (a[1] .. " (" .. a[4] .. ")") or a[1]
    end
  end
  if #missingReq > 0 then return "fail", "Game APIs", "missing: " .. table.concat(missingReq, ", ") end
  if #missingOpt > 0 then
    return "warn", "Game APIs", ("%d of %d found; missing (what stays off): %s"):format(
      #ST.APIS - #missingOpt, #ST.APIS, table.concat(missingOpt, ", "))
  end
  return "pass", "Game APIs", ("all %d found"):format(#ST.APIS)
end

checks[#checks + 1] = function()
  if not C.Call(IsInGuild) then return "warn", "Guild roster", "not in a guild (most features need one)" end
  local total = C.Call(GetNumGuildMembers) or 0
  local R = ns.Roster
  local read = R and R.members and #R.members or 0
  if total == 0 and read == 0 then return "warn", "Guild roster", "the game hasn't sent the roster yet; try again in a minute" end
  if read == 0 then return "fail", "Guild roster", ("the game lists %d members but none were read"):format(total) end
  local st = read >= total and "pass" or "warn"
  return st, "Guild roster", ("%d of %d members read, %d online"):format(read, total, R.online or 0)
end

checks[#checks + 1] = function()
  local S = ns.Sync
  local reg = C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered
    and C.Call(C_ChatInfo.IsAddonMessagePrefixRegistered, ns.PREFIX)
  if reg == false then return "fail", "Addon channel", "the message prefix isn't registered" end
  local can, why = S.CanSend()
  local detail = ("%s; %d received this session, %d unreadable, queue %d"):format(
    can and "can send" or ("can't send: " .. tostring(why)), S.stats.received, S.stats.bad,
    S.queue and S.queue:Size() or 0)
  if not can then return "warn", "Addon channel", detail end
  if S.stats.bad > 5 and S.stats.bad > S.stats.received / 10 then return "warn", "Addon channel", detail end
  return "pass", "Addon channel", detail
end

checks[#checks + 1] = function()
  if type(C_Calendar) ~= "table" or not C_Calendar.GetNumDayEvents then
    return "warn", "Calendar", "no calendar API: the Events tab stays empty"
  end
  local nowCT = C.Call(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)
  if type(nowCT) ~= "table" or not nowCT.month then return "warn", "Calendar", "the calendar clock isn't readable" end
  local E = ns.Events
  local off, ok = E.RealmOffset(nowCT)
  local realm = ("%d:%02d"):format(nowCT.hour or 0, nowCT.minute or 0)
  local here = date("%H:%M", time())
  local n = 0
  local g = ns.DB.Guild()
  for _ in pairs(g and g.events or {}) do n = n + 1 end
  local shift = -off / 3600
  if math.abs(shift) < 0.01 then shift = 0 end   -- no "-0h"
  local detail = ("realm clock %s, your clock %s (shift %+.2gh); %d event%s known%s"):format(realm, here, shift,
    n, n == 1 and "" or "s", E.lastRead and "" or ", calendar not read yet")
  if not ok then return "warn", "Calendar", detail .. "; times are shown as realm time" end
  return "pass", "Calendar", detail
end

checks[#checks + 1] = function()
  local count = (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C.Call(C_SkillInfo.GetNumSkillLines))
    or C.Call(_G.GetNumSkillLines) or 0
  if count == 0 then return "warn", "Skill lines", "none readable (professions won't show)" end
  local profs, n = ns.Me.ReadProfessions(), 0
  local names = {}
  for name, p in pairs(profs) do n = n + 1; names[#names + 1] = ("%s %d"):format(name, p.rank) end
  table.sort(names)
  local riding = ns.Me.RidingSkill()
  return "pass", "Skill lines", ("%d lines; professions: %s; riding: %s"):format(count,
    n > 0 and table.concat(names, ", ") or "none", (riding or 0) > 0 and tostring(riding) or "not learned")
end

checks[#checks + 1] = function()
  local D = ns.FDBData
  if type(D) ~= "table" then return "fail", "Bundled data", "the ForeverDB snapshot didn't load" end
  local function count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
  local parts, empty = {}, {}
  for _, k in ipairs({ "items", "quests", "vendors", "professions", "dungeons", "zones" }) do
    local n = count(D[k])
    parts[#parts + 1] = ("%s %d"):format(k, n)
    if n == 0 then empty[#empty + 1] = k end
  end
  local want = 0
  for _, bosses in pairs(ns.News.FINAL_BOSSES) do for _ in pairs(bosses) do want = want + 1 end end
  local found = count(ns.News.Finals())
  local detail = ("snapshot %s; %s; last bosses %d of %d found"):format(tostring(D.snapshot),
    table.concat(parts, ", "), found, want)
  if #empty > 0 then return "fail", "Bundled data", detail .. "; empty: " .. table.concat(empty, ", ") end
  if found < want then return "warn", "Bundled data", detail end
  return "pass", "Bundled data", detail
end

checks[#checks + 1] = function()
  local db = _G.LOMBCompanionDB
  if type(db) ~= "table" or db ~= ns.db then return "fail", "Saved variables", "the account data isn't loaded" end
  if type(ns.char) ~= "table" then return "fail", "Saved variables", "this character's data isn't loaded" end
  local kb = math.floor((ns.DB.ApproxSize and ns.DB.ApproxSize(db) or 0) / 1024 + 0.5)
  local detail = ("schema %s (expected %s), about %d KB"):format(tostring(db.schema), tostring(ns.DB.SCHEMA), kb)
  if db.schema ~= ns.DB.SCHEMA then return "warn", "Saved variables", detail end
  local left = {}
  for _, k in ipairs(ns.DB.OBSOLETE.db) do if db[k] ~= nil then left[#left + 1] = k end end
  for _, k in ipairs(ns.DB.OBSOLETE.char) do if ns.char[k] ~= nil then left[#left + 1] = k end end
  if #left > 0 then return "warn", "Saved variables", detail .. "; old fields not cleared: " .. table.concat(left, ", ") end
  detail = detail .. "; old fields cleared"
  if kb > 8192 then return "warn", "Saved variables", detail .. "; large files make logging out slow" end
  return "pass", "Saved variables", detail
end

---------------------------------------------------------------------------
-- one line per feature: each calls the feature's own functions the way its tab
-- does (read-only: nothing is sent, posted or changed; counts only, no names)
---------------------------------------------------------------------------
local function count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local function plural(n, word, many) return ("%d %s"):format(n, n == 1 and word or many or (word .. "s")) end
local function has(path) return type(get(path)) == "function" end
local function onOff(v) return v and "on" or "off" end

checks[#checks + 1] = function()
  local Me = ns.Me
  local p = Me.Profile()
  if type(p) ~= "table" then return "fail", "Me tab", "your profile couldn't be built" end
  local played = Me.PlayedNow()
  local detail = ("profile ready (level %s, %s); played %s; sharing %s"):format(tostring(p.lv or "?"),
    plural(count(p.pr), "profession"), played and "known" or "not read yet", onOff(ns.db.settings.shareProfile))
  if not p.lv then return "warn", "Me tab", detail end
  return "pass", "Me tab", detail
end

checks[#checks + 1] = function()
  local Cr = ns.Crafting
  local mine = 0
  for _, e in ipairs(Cr.MyCounts()) do mine = mine + e.n end
  local rows = Cr.Search({})
  return "pass", "Crafters", ("%s listed from %s; %d of yours scanned; sharing %s, tooltips %s"):format(
    plural(#rows, "recipe"), plural(Cr.CrafterCount(), "guildmate"), mine,
    onOff(ns.db.settings.shareRecipes), onOff(ns.db.settings.tooltips))
end

checks[#checks + 1] = function()
  local News = ns.News
  return "pass", "News", ("%s in the feed, %d unread; activity sharing %s"):format(plural(#(News.items or {}), "item"),
    News.Unread and News.Unread() or 0, onOff(ns.db.settings.shareActivity))
end

checks[#checks + 1] = function()
  local News, parts = ns.News, {}
  for _, b in ipairs(News.BOARDS) do
    parts[#parts + 1] = ("%s %d"):format(b.label:lower(), #News.Board(b.key, b.weekly))
  end
  if #parts == 0 then return "fail", "Leaderboard", "no boards defined" end
  return "pass", "Leaderboard", plural(#parts, "board") .. " built (" .. table.concat(parts, ", ") .. " rows)"
end

checks[#checks + 1] = function()
  local mobs, mine = 0, 0
  for _, m in pairs(ns.db.bestiary or {}) do
    mobs = mobs + 1
    if m.rec and m.rec[ns.playerKey] then mine = mine + 1 end
  end
  local listed = #ns.Bestiary.List("", { filter = "all" })
  local st = ns.db.settings
  local detail = ("%s known (%d listed), %d recorded by you; sharing %s, rare alerts %s"):format(
    plural(mobs, "creature"), listed, mine, onOff(st.shareBestiary), onOff(st.rareAlerts))
  if not has("UnitGUID") then return "warn", "Bestiary", detail .. "; can't tell creatures apart on this client" end
  return "pass", "Bestiary", detail
end

checks[#checks + 1] = function()
  local FDB, Track, G = ns.FDB, ns.QuestTrack, ns.Guides
  if not FDB.Available() then return "fail", "Quests & items", "the ForeverDB.net data isn't available" end
  local quests = #FDB.QuestList({})
  local items = #FDB.ItemSearch("linen", 5)
  local api = Track.api or {}
  local detail = ("%s searchable, item search works (%d for \"linen\"); quest log %s, done-quest marks %s; class guides %s")
    :format(plural(quests, "quest"), items, api.log and "readable" or "not readable",
      Track.Knows() and "on" or "waiting for data", G.Available() and "loaded" or "missing")
  if quests == 0 or items == 0 or not G.Available() then return "warn", "Quests & items", detail end
  return "pass", "Quests & items", detail
end

checks[#checks + 1] = function()
  local D, Loot = ns.FDBData, ns.Loot
  local did
  for id in pairs(D and D.dungeons or {}) do if not did or id < did then did = id end end
  if not did then return "warn", "Loot browser", "no dungeons in the bundled data: the loot browser stays empty" end
  local res = Loot.For(did)
  return "pass", "Loot browser", ("%s browsable (the first lists %s)")
    :format(plural(count(D.dungeons), "instance"), plural(#res.items, "item"))
end

checks[#checks + 1] = function()
  local Ask = ns.Ask
  local q = Ask.EXAMPLES[2]
  local ans = Ask.Answer(q)                -- answered, not added to your history
  local n = ans and #ans.lines or 0
  if n == 0 then return "fail", "Ask LOMB", "a sample question got no answer" end
  local detail = ("a sample question got a %d-line answer; %s in your history"):format(n, plural(#Ask.history, "question"))
  if ans.unknown then return "warn", "Ask LOMB", detail .. " (it didn't know the sample)" end
  return "pass", "Ask LOMB", detail
end

checks[#checks + 1] = function()
  local E = ns.Events
  local g = E.Guild and E.Guild()
  if not g then return "warn", "Events", "no guild data yet" end
  local st = ns.db.settings
  local detail = ("%d upcoming, %d past; attendance recording %s, sharing %s, noted for %s"):format(
    #E.List("upcoming"), #E.List("past"), onOff(st.recordAttendance), onOff(st.shareAttendance),
    plural(count(g.att), "event"))
  if not st.recordAttendance then return "warn", "Events", detail end
  return "pass", "Events", detail
end

checks[#checks + 1] = function()
  local WL = ns.Wishlist
  local others = 0
  for owner in ns.Shared.Each("wl") do if owner ~= ns.playerKey then others = others + 1 end end
  return "pass", "Wishlist", ("%d of %d entries on yours, %s in the list; %d guildmate%s' lists known"):format(
    #WL.Mine(), WL.MAX, plural(#WL.All("all", ""), "row"), others, others == 1 and "" or "s")
end

checks[#checks + 1] = function()
  local B = ns.Bank
  local n = 0
  for _ in B.Each() do n = n + 1 end
  return "pass", "Guild bank", ("%s; %s shared"):format(B.IsBankChar() and "this is a bank character" or "not a bank character",
    plural(n, "bank ledger"))
end

checks[#checks + 1] = function()
  local T, UI, st = ns.Theme, ns.UI, ns.db.settings
  local look = T and T.look
  if not (T and T.palettes and T.palettes[look]) then return "fail", "Settings & look", "the look didn't apply" end
  local broken = 0
  for _, t in ipairs(UI.tabs) do if type(t.build) ~= "function" then broken = broken + 1 end end
  local detail = ("look %s (saved %s); %s, %d broken"):format(look, tostring(st.theme), plural(#UI.tabs, "tab"), broken)
  if broken > 0 then return "fail", "Settings & look", detail end
  if look ~= st.theme then return "warn", "Settings & look", detail .. "; the saved look isn't the one showing" end
  return "pass", "Settings & look", detail
end

checks[#checks + 1] = function()
  local Tour, ok = ns.Tour, 0
  for _, step in ipairs(Tour.STEPS) do
    if type(step.title) == "string" and type(step.body) == "string" and type(step.target) == "function" then ok = ok + 1 end
  end
  local detail = ("%d of %d steps ready; %s (/lomb tour shows it again)"):format(ok, #Tour.STEPS,
    ns.db.settings.tourDone and "seen" or "not seen yet")
  if ok < #Tour.STEPS or ok == 0 then return "fail", "Tour", detail end
  return "pass", "Tour", detail
end

checks[#checks + 1] = function()
  local bits = {}
  if C.InCombat() then bits[#bits + 1] = "in combat (run it again out of combat for a clean result)" end
  if C.IsRestrictedAccount() then bits[#bits + 1] = "trial account (receive-only)" end
  if #bits > 0 then return "warn", "Situation", table.concat(bits, "; ") end
  return "pass", "Situation", "out of combat"
end
ST.checks = checks

function ST.RunChecks()
  local out = {}
  for _, fn in ipairs(checks) do
    local ok, st, label, detail = pcall(fn)
    if not ok then st, label, detail = "fail", "Check crashed", tostring(st):sub(1, 140) end
    out[#out + 1] = { st = st, label = label, detail = detail }
  end
  return out
end

---------------------------------------------------------------------------
-- sync echo: we send a ping, the first guildmate with LOMB to answer wins
---------------------------------------------------------------------------
ST.replied = {}         -- [sender] = GetTime() of our last answer
ST.pending = {}         -- [ping id] = true while we wait to answer (cancelled if someone beats us)

function ST.OnlinePeers()
  local n = 0
  for _, r in ipairs(ns.Roster.members or {}) do
    if r.online and r.peer and r.name ~= ns.playerKey then n = n + 1 end
  end
  return n
end

local function onPing(sender, d)
  if type(d.id) ~= "string" or #d.id > 24 then return end
  local now = GetTime()
  if ST.replied[sender] and now - ST.replied[sender] < ST.REPLY_COOLDOWN then return end
  ST.replied[sender] = now
  ST.pending[d.id] = true
  ns.After(math.random() * ST.MAX_REPLY_DELAY, function()
    if not ST.pending[d.id] then return end         -- someone else answered first
    ST.pending[d.id] = nil
    ns.Sync.Send({ t = "TQ", id = d.id, to = sender, v = ns.version }, ns.Queue.ALERT)
  end)
end

local function onPong(_, d)
  if type(d.id) ~= "string" then return end
  ST.pending[d.id] = nil                            -- answered: the rest of us stay quiet
  local run = ST.run
  if run and run.id == d.id and d.to == ns.playerKey and not run.echo then
    run.echo = { rtt = GetTime() - run.sentAt, v = tostring(d.v or "?") }
    ST.Finish()
  end
end

function ST.EchoLine(run)
  if run.echoSkip then return { st = "warn", label = "Sync echo", detail = run.echoSkip } end
  if run.echo then
    return { st = "pass", label = "Sync echo",
      detail = ("a guildmate answered in %.1f s (their version %s)"):format(run.echo.rtt, run.echo.v) }
  end
  return { st = "warn", label = "Sync echo", detail = ("no answer in %d s from %d guildmate%s online with LOMB"):format(
    ST.ECHO_TIMEOUT, run.peers, run.peers == 1 and "" or "s") }
end

---------------------------------------------------------------------------
-- report
---------------------------------------------------------------------------
function ST.Report(lines)
  local counts = { pass = 0, warn = 0, fail = 0 }
  for _, l in ipairs(lines) do counts[l.st] = (counts[l.st] or 0) + 1 end
  local build, _, _, toc = C.Call(GetBuildInfo)
  local head = ("LOMB Companion %s self-test, %s. Client %s (interface %s)."):format(ns.version,
    date("%Y-%m-%d %H:%M"), tostring(build or "?"), tostring(toc or "?"))
  local sum = ("Result: %d pass, %d warn, %d fail."):format(counts.pass, counts.warn, counts.fail)
  local plain, colored = { head }, {}
  for _, l in ipairs(lines) do
    plain[#plain + 1] = ("[%s] %s: %s"):format(PLAIN[l.st] or l.st, l.label, l.detail or "")
    colored[#colored + 1] = ("%s  %s: |cffffffff%s|r"):format(MARK[l.st] or l.st, l.label, l.detail or "")
  end
  plain[#plain + 1] = sum
  return table.concat(plain, "\n"), colored, sum, counts
end

function ST.Finish()
  local run = ST.run
  if not run or run.done then return end
  run.done = true
  local lines = run.lines
  table.insert(lines, 5, ST.EchoLine(run))   -- after the addon channel line
  local text, colored, sum, counts = ST.Report(lines)
  ST.last = text
  for _, l in ipairs(colored) do ns.Print(l) end
  ns.Print(sum .. (counts.fail + counts.warn > 0 and " Copy the report from the window and post it in the guild's addon channel on Discord." or ""))
  if ns.Widgets and ns.Widgets.CopyWindow and not run.quiet then
    ns.Widgets.CopyWindow("LOMB self-test: " .. sum, text,
      "Select all, then Ctrl+C. Paste it in Discord if anything says WARN or FAIL.")
  end
  if run.done_cb then run.done_cb(text, counts) end
end

-- opts.quiet: no window (tests); opts.onDone(text, counts)
function ST.Run(opts)
  opts = opts or {}
  if ST.run and not ST.run.done then ns.Print("The self-test is already running."); return end
  local run = { lines = ST.RunChecks(), peers = ST.OnlinePeers(), quiet = opts.quiet, done_cb = opts.onDone }
  ST.run = run
  local can, why = ns.Sync.CanSend()
  if not can then
    run.echoSkip = "skipped: can't send right now (" .. tostring(why) .. ")"
  elseif run.peers == 0 then
    run.echoSkip = "skipped: no guildmate with LOMB is online (do the two-player check from the launch checklist)"
  end
  if run.echoSkip then ST.Finish(); return run end
  run.id = ("%d%04d"):format(time() % 1e6, math.random(0, 9999))
  run.sentAt = GetTime()
  ns.Sync.Send({ t = "TP", id = run.id }, ns.Queue.ALERT)
  ns.Print("Self-test: checking %d things and waiting up to %d s for a guildmate to answer...", #run.lines + 1, ST.ECHO_TIMEOUT)
  ns.After(ST.ECHO_TIMEOUT, function() if ST.run == run then ST.Finish() end end)
  return run
end

function ST:Init()
  ns.Sync.RegisterHandler("TP", onPing)
  ns.Sync.RegisterHandler("TQ", onPong)
end
