-- LOMB Companion: /lomb test -- a self-test for launch day.
-- Checks that the game gives the addon what it needs (APIs, guild roster, addon
-- channel, calendar, skill lines), that the bundled data and saved variables are
-- healthy, and -- when a guildmate with LOMB is online -- that a message makes it
-- there and back. Prints PASS / WARN / FAIL lines in chat and opens a window the
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

-- name, required, alternative
ST.APIS = {
  { "C_ChatInfo.SendAddonMessage", true, "SendAddonMessage" },
  { "C_ChatInfo.RegisterAddonMessagePrefix", true, "RegisterAddonMessagePrefix" },
  { "GetGuildRosterInfo", true }, { "GetNumGuildMembers", true }, { "GetGuildInfo", true },
  { "C_Timer.After", true }, { "UnitGUID", true },
  { "GetGuildRosterLastOnline" }, { "GetServerTime" },
  { "C_Calendar.OpenCalendar" }, { "C_Calendar.GetDayEvent" }, { "C_DateAndTime.GetCurrentCalendarTime" },
  { "GetSkillLineInfo", false, "C_SkillInfo.GetSkillLineInfo" },
  { "GetLootSlotInfo" }, { "GetLootSourceInfo" },
  { "C_Map.GetBestMapForUnit" }, { "C_Item.GetItemInfo", false, "GetItemInfo" },
  { "RequestTimePlayed" }, { "GetTradeSkillLine" },
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
      into[#into + 1] = a[1]
    end
  end
  if #missingReq > 0 then return "fail", "Game APIs", "missing: " .. table.concat(missingReq, ", ") end
  if #missingOpt > 0 then
    return "warn", "Game APIs", ("%d of %d found; missing (features using them stay off): %s"):format(
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
  if kb > 8192 then return "warn", "Saved variables", detail .. "; large files make logging out slow" end
  return "pass", "Saved variables", detail
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
