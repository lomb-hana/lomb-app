-- LOMB Companion: guild events (read from the in-game calendar) and attendance.
--
-- Events come from the guild calendar everybody already sees (C_Calendar); we
-- only read it, never create or change events.
-- Attendance: while a guild event is running (from 15 minutes before its start
-- to its end), if you are grouped with the organizer, or you are the organizer,
-- the addon notes who is in the group every 5 minutes. Snapshots wait until
-- you are out of combat. Each recorder shares what they noted ("at" dataset);
-- copies are merged (union, best count wins).
-- Officers (the top ranks, see E.TrustedRank) can add or remove names; those
-- fixes are a separate dataset ("ac") that is only accepted from those ranks.
local _, ns = ...
local C = ns.Compat
local E = ns:NewModule("Events")

E.SNAP_EVERY = 300          -- seconds between group snapshots during an event
E.EARLY = 900               -- start watching this long before the start
E.DEFAULT_LEN = 3 * 3600    -- events without an end time count as 3 hours
E.KEEP_DAYS = 90            -- forget events (and their attendance) after this
E.SHARE_MAX = 8             -- newest recorded events per attendance dataset
E.FIX_MAX = 20              -- newest corrected events per officer dataset
E.NAMES_MAX = 40            -- a raid
E.SUMMARY_DAYS = 30

-- Enum.CalendarStatus
E.STATUS = {
  [0] = "Invited", [1] = "Accepted", [2] = "Declined", [3] = "Confirmed", [4] = "Out",
  [5] = "Standby", [6] = "Signed up", [7] = "Not signed up", [8] = "Tentative",
}
E.TYPES = { GUILD_EVENT = "Guild event", GUILD_ANNOUNCEMENT = "Guild announcement" }

local function guild()
  local g = ns.DB.Guild()
  if not g then return nil end
  g.events = g.events or {}
  g.att = g.att or {}
  g.fixes = g.fixes or {}
  return g
end
E.Guild = guild

local function S() return ns.db.settings end
local function me() return C.ShortName(ns.playerKey or "") end

---------------------------------------------------------------------------
-- calendar
---------------------------------------------------------------------------
local function epochOf(ct)
  if type(ct) ~= "table" or not ct.year or not ct.month then return nil end
  return time({ year = ct.year, month = ct.month, day = ct.monthDay or ct.day or 1,
    hour = ct.hour or 0, min = ct.minute or 0, sec = 0 })
end
E.EpochOf = epochOf

-- Calendar times are realm (server) times; convert them with the realm's offset
-- from our clock (rounded to 15 minutes) so everybody ends up with the same epoch,
-- and every time we show is the player's own local time. Returns offset, ok.
-- ok is false when the client didn't give us what we need (no calendar clock, or
-- an offset no real time zone has): then times are left as the calendar shows
-- them and labelled as realm time. Not checked against the live client before Nov 4.
E.MAX_OFFSET = 15 * 3600
function E.RealmOffset(nowCT)
  local calNow = epochOf(nowCT)
  local srv = C.Call(GetServerTime)
  if type(srv) ~= "number" then srv = time() end
  if not calNow then return 0, false end
  local off = math.floor((srv - calNow) / 900 + 0.5) * 900
  if math.abs(off) > E.MAX_OFFSET then return 0, false end
  return off, true
end

-- "8:00 PM" in the player's local time (no leading zero).
function E.Clock(epoch)
  return (date("%I:%M %p", epoch):gsub("^0", ""))
end

-- How a record's times should be labelled.
function E.TimeLabel(rec, short)
  if rec and rec.tzok == false then
    return short and "(realm time?)" or "(realm time, not converted; unverified until Nov 4)"
  end
  return "(your time)"
end

function E.Key(start, by)
  return ("%d@%s"):format(start, C.ShortName(by or "") ~= "" and C.ShortName(by) or "?")
end

function E.FromCalendar(ev, offset, tzok)
  if type(ev) ~= "table" or not E.TYPES[ev.calendarType] then return nil end
  local start = epochOf(ev.startTime)
  if not start then return nil end
  start = start + (offset or 0)
  local stop = epochOf(ev.endTime)
  stop = stop and stop + (offset or 0)
  if not stop or stop <= start or ev.dontDisplayEnd then stop = start + E.DEFAULT_LEN end
  local title = type(ev.title) == "string" and ev.title ~= "" and ev.title or "Guild event"
  local by = type(ev.invitedBy) == "string" and ev.invitedBy ~= "" and C.ShortName(ev.invitedBy) or nil
  local rec = {
    k = E.Key(start, by), title = title:sub(1, 60), start = start, stop = stop, by = by,
    ct = ev.calendarType, status = type(ev.inviteStatus) == "number" and ev.inviteStatus or nil,
  }
  if tzok == false then rec.tzok = false end   -- times left in realm time
  return rec
end

function E.CalendarOpen()
  local f = _G.CalendarFrame
  return f and f.IsShown and f:IsShown() or false
end

-- Read last month, this month and next month. Returns the number of events read,
-- or nil when the calendar isn't available (or the player has it open: changing
-- the month under them would be rude).
function E.ReadCalendar()
  local g = guild()
  if not g or type(C_Calendar) ~= "table" or not C_Calendar.GetNumDayEvents then return nil end
  if E.CalendarOpen() then return nil end
  local nowCT = C.Call(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)
  if type(nowCT) ~= "table" or not nowCT.month then return nil end
  local offset, tzok = E.RealmOffset(nowCT)
  E.tzok = tzok
  C.Call(C_Calendar.SetAbsMonth, nowCT.month, nowCT.year)
  local found, n = {}, 0
  for mo = -1, 1 do
    local info = C.Call(C_Calendar.GetMonthInfo, mo)
    local days = type(info) == "table" and tonumber(info.numDays) or 31
    for day = 1, days do
      local count = C.Call(C_Calendar.GetNumDayEvents, mo, day) or 0
      for i = 1, count do
        local rec = E.FromCalendar(C.Call(C_Calendar.GetDayEvent, mo, day, i), offset, tzok)
        if rec and not found[rec.k] then found[rec.k] = rec; n = n + 1 end
      end
    end
  end
  local now = time()
  for k, rec in pairs(found) do
    local old = g.events[k]
    rec.seen = now
    if old then rec.firstSeen = old.firstSeen end
    rec.firstSeen = rec.firstSeen or now
    g.events[k] = rec
  end
  -- an event we knew about that's gone from a calendar that did load: removed
  if n > 0 then
    local lo = now - 20 * 86400
    for k, rec in pairs(g.events) do
      if not found[k] and rec.ct and rec.start >= lo then rec.missing = true end
    end
  end
  E.lastRead = now
  ns:Fire("EVENTS_UPDATED")
  return n
end

function E.RequestCalendar()
  if type(C_Calendar) == "table" and C_Calendar.OpenCalendar and not E.CalendarOpen() then
    C.Call(C_Calendar.OpenCalendar)
  end
end

---------------------------------------------------------------------------
-- group roster
---------------------------------------------------------------------------
-- short names of everyone in our party/raid (including us)
function E.GroupNames()
  local out, seen = {}, {}
  local function add(name)
    name = name and C.ShortName(name)
    if name and name ~= "" and not seen[name] then seen[name] = true; out[#out + 1] = name end
  end
  add(me())
  local n = C.Call(GetNumGroupMembers) or 0
  if n > 0 then
    local raid = C.Call(IsInRaid)
    for i = 1, raid and n or math.min(n - 1, 4) do
      add(C.Call(UnitName, (raid and "raid" or "party") .. i))
    end
  end
  table.sort(out)
  return out
end

local function isMember(short)
  local R = ns.Roster
  return R and R.byName and R.byName[C.FullName(short)] ~= nil
end
E.IsMember = isMember

function E.Running(rec, now)
  now = now or time()
  return rec.ct == "GUILD_EVENT" and not rec.missing and now >= rec.start - E.EARLY and now <= rec.stop
end

-- Is the attendance for this event ours to take right now?
function E.CanRecord(rec)
  if not S().recordAttendance or not E.Running(rec) then return false end
  if not rec.by then return false end
  if rec.by == me() then return true end
  for _, name in ipairs(E.GroupNames()) do if name == rec.by then return true end end
  return false
end

function E.Snapshot(rec)
  local g = guild()
  if not g then return false end
  local a = g.att[rec.k]
  if not a then
    a = { n = 0, who = {}, title = rec.title, start = rec.start }
    g.att[rec.k] = a
  end
  a.n = a.n + 1
  a.last = time()
  local count = 0
  for _, name in ipairs(E.GroupNames()) do
    if isMember(name) or name == me() then
      a.who[name] = (a.who[name] or 0) + 1
      count = count + 1
    end
  end
  ns.Shared.MarkDirty("at")
  ns:Fire("ATTENDANCE_UPDATED", rec.k)
  return count
end

function E.Tick()
  local g = guild()
  if not g then return end
  local now = time()
  for _, rec in pairs(g.events) do
    if E.CanRecord(rec) then
      local a = g.att[rec.k]
      if not a or not a.last or now - a.last >= E.SNAP_EVERY - 5 then
        if C.InCombat() then
          E.pending = true      -- picked up again when combat ends
        else
          E.Snapshot(rec)
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- officers
---------------------------------------------------------------------------
function E.TrustedRank()
  return math.max(0, (tonumber(S().officerRanks) or 2) - 1)
end

function E.IsOfficer(name)
  local R = ns.Roster
  local row = R and R.byName and R.byName[C.FullName(name)]
  return row ~= nil and type(row.rankIndex) == "number" and row.rankIndex <= E.TrustedRank()
end

-- mode: "add", "remove" or nil (clear our fix)
function E.Fix(key, name, mode)
  local g = guild()
  if not g or not E.IsOfficer(me()) then return false, "Only officers can fix attendance." end
  name = C.ShortName(name or "")
  if name == "" then return false, "No name." end
  if mode == "add" and not isMember(name) then return false, name .. " isn't in the guild roster." end
  local f = g.fixes[key] or { a = {}, r = {} }
  g.fixes[key] = f
  f.a[name], f.r[name] = nil, nil
  if mode == "add" then f.a[name] = true elseif mode == "remove" then f.r[name] = true end
  f.t = time()
  if not next(f.a) and not next(f.r) then g.fixes[key] = nil end
  ns.Shared.MarkDirty("ac")
  ns:Fire("ATTENDANCE_UPDATED", key)
  return true
end

---------------------------------------------------------------------------
-- merged view
---------------------------------------------------------------------------
local function recordings(key)
  local g = guild()
  local out = {}
  local mine = g and g.att[key]
  if mine then out[#out + 1] = { by = me(), n = mine.n, who = mine.who } end
  for owner, data in ns.Shared.Each("at") do
    if owner ~= ns.playerKey then
      for _, e in ipairs(data) do
        if e.k == key then out[#out + 1] = { by = C.ShortName(owner), n = e.n, who = e.w } end
      end
    end
  end
  return out
end

-- fixes, oldest first (so the newest officer decision wins)
local function fixes(key)
  local g = guild()
  local out = {}
  local mine = g and g.fixes[key]
  if mine and E.IsOfficer(me()) then out[#out + 1] = { by = me(), t = mine.t or 0, a = mine.a, r = mine.r } end
  for owner, data in ns.Shared.Each("ac") do
    if owner ~= ns.playerKey and E.IsOfficer(owner) then
      local f = data[key]
      if f then out[#out + 1] = { by = C.ShortName(owner), t = f.t or 0, a = f.a, r = f.r } end
    end
  end
  table.sort(out, function(x, y) if x.t ~= y.t then return x.t < y.t end return x.by < y.by end)
  return out
end

-- { n = snapshots, recorders = {names}, rows = { {name, count, pct, present, fix, fixBy} } }
function E.Attendance(key)
  local recs = recordings(key)
  local n, who, by = 0, {}, {}
  for _, r in ipairs(recs) do
    n = math.max(n, r.n or 0)
    by[#by + 1] = r.by
    for name, c in pairs(r.who or {}) do who[name] = math.max(who[name] or 0, c) end
  end
  local state = {}
  for name, c in pairs(who) do state[name] = { name = name, count = c, present = true } end
  for _, f in ipairs(fixes(key)) do
    for name in pairs(f.a or {}) do
      local s = state[name] or { name = name, count = 0 }
      s.present, s.fix, s.fixBy = true, "added", f.by
      state[name] = s
    end
    for name in pairs(f.r or {}) do
      local s = state[name] or { name = name, count = 0 }
      s.present, s.fix, s.fixBy = false, "removed", f.by
      state[name] = s
    end
  end
  local rows = {}
  for _, s in pairs(state) do
    s.pct = n > 0 and math.floor(100 * math.min(s.count, n) / n + 0.5) or (s.present and 100 or 0)
    rows[#rows + 1] = s
  end
  table.sort(rows, function(x, y)
    if x.present ~= y.present then return x.present end
    if x.count ~= y.count then return x.count > y.count end
    return x.name < y.name
  end)
  table.sort(by)
  local present = 0
  for _, r in ipairs(rows) do if r.present then present = present + 1 end end
  return { n = n, recorders = by, rows = rows, present = present }
end

-- All known events (calendar + ones only known from guildmates' attendance), newest first.
function E.List(which)
  local g = guild()
  local now = time()
  local all = {}
  if g then
    for k, rec in pairs(g.events) do all[k] = rec end
    for owner, data in ns.Shared.Each("at") do
      if owner ~= ns.playerKey then
        for _, e in ipairs(data) do
          if not all[e.k] then
            all[e.k] = { k = e.k, title = e.ti or "Guild event", start = e.s, stop = e.s + E.DEFAULT_LEN,
              by = e.k:match("@(.+)$"), ct = "GUILD_EVENT", remote = true }
          end
        end
      end
    end
  end
  local out = {}
  for _, rec in pairs(all) do
    local upcoming = rec.stop >= now
    if (which == "upcoming" and upcoming and not rec.missing) or (which == "past" and not upcoming) or which == "all" then
      out[#out + 1] = rec
    end
  end
  if which == "upcoming" then
    table.sort(out, function(a, b) if a.start ~= b.start then return a.start < b.start end return a.k < b.k end)
  else
    table.sort(out, function(a, b) if a.start ~= b.start then return a.start > b.start end return a.k < b.k end)
  end
  return out
end

function E.Get(key)
  for _, rec in ipairs(E.List("all")) do if rec.k == key then return rec end end
end

-- Per-member attendance over the last N days: { {name, attended, total, pct} }
function E.Summary(days)
  local since = time() - (days or E.SUMMARY_DAYS) * 86400
  local total, per = 0, {}
  for _, rec in ipairs(E.List("past")) do
    if rec.start >= since and rec.ct == "GUILD_EVENT" then
      local a = E.Attendance(rec.k)
      if a.n > 0 or #a.rows > 0 then
        total = total + 1
        for _, r in ipairs(a.rows) do
          if r.present then per[r.name] = (per[r.name] or 0) + 1 end
        end
      end
    end
  end
  local rows = {}
  for name, c in pairs(per) do
    rows[#rows + 1] = { name = name, attended = c, total = total, pct = math.floor(100 * c / total + 0.5) }
  end
  table.sort(rows, function(a, b) if a.attended ~= b.attended then return a.attended > b.attended end return a.name < b.name end)
  return rows, total
end

---------------------------------------------------------------------------
-- datasets
---------------------------------------------------------------------------
function E.BuildAttendance()
  local g = guild()
  if not g then return nil end
  local list = {}
  for k, a in pairs(g.att) do
    if a.n > 0 then list[#list + 1] = { k = k, a = a } end
  end
  table.sort(list, function(x, y) return (x.a.start or 0) > (y.a.start or 0) end)
  local out = {}
  for i = 1, math.min(#list, E.SHARE_MAX) do
    local k, a = list[i].k, list[i].a
    local w = {}
    for name, c in pairs(a.who) do w[name] = c end
    out[i] = { k = k, ti = a.title, s = a.start, n = a.n, w = w }
  end
  if #out == 0 then return nil end
  return out
end

local V
local function cleanKey(k)
  k = V.str(k, 40)
  if not k then return nil end
  local s, by = k:match("^(%d+)@([^@]+)$")
  if not s then return nil end
  return k, tonumber(s), by
end
local function cleanName(n)
  n = V.str(n, 24)
  return n and not n:find("[%s%-]") and n or nil
end

function E.ValidateAttendance(data)
  V = V or ns.Shared.V
  if type(data) ~= "table" then return nil end
  local out = {}
  for i = 1, math.min(#data, E.SHARE_MAX) do
    local e = data[i]
    local k, s = cleanKey(type(e) == "table" and e.k)
    local n = k and V.int(e.n, 1, 1000)
    if k and n and type(e.w) == "table" then
      local w, count = {}, 0
      for name, c in pairs(e.w) do
        name, c = cleanName(name), V.int(c, 1, n)
        if name and c and count < E.NAMES_MAX then w[name] = c; count = count + 1 end
      end
      out[#out + 1] = { k = k, ti = V.str(e.ti, 60) or "Guild event", s = s, n = n, w = w }
    end
  end
  return #out > 0 and out or nil
end

function E.BuildFixes()
  local g = guild()
  if not g or not E.IsOfficer(me()) then return nil end
  local list = {}
  for k, f in pairs(g.fixes) do list[#list + 1] = { k = k, f = f } end
  table.sort(list, function(x, y) return (x.f.t or 0) > (y.f.t or 0) end)
  local out, n = {}, 0
  for i = 1, math.min(#list, E.FIX_MAX) do
    local f = list[i].f
    local a, r = {}, {}
    for name in pairs(f.a) do a[#a + 1] = name end
    for name in pairs(f.r) do r[#r + 1] = name end
    table.sort(a); table.sort(r)
    out[list[i].k] = { t = f.t, a = a, r = r }
    n = n + 1
  end
  return n > 0 and out or nil
end

-- wire format uses name lists; stored as sets
function E.ValidateFixes(data, owner)
  V = V or ns.Shared.V
  if type(data) ~= "table" or not E.IsOfficer(owner) then return nil end
  local out, n = {}, 0
  for k, f in pairs(data) do
    k = cleanKey(k)
    if k and type(f) == "table" and n < E.FIX_MAX then
      local a, r, any = {}, {}, false
      for _, name in ipairs(type(f.a) == "table" and f.a or {}) do
        name = cleanName(name); if name then a[name] = true; any = true end
      end
      for _, name in ipairs(type(f.r) == "table" and f.r or {}) do
        name = cleanName(name); if name then r[name] = true; any = true end
      end
      if any then out[k] = { t = V.int(f.t, 0, 4e9) or 0, a = a, r = r }; n = n + 1 end
    end
  end
  return n > 0 and out or nil
end

function E.Prune()
  local g = guild()
  if not g then return end
  local cut = time() - E.KEEP_DAYS * 86400
  for k, rec in pairs(g.events) do if rec.stop < cut then g.events[k] = nil end end
  for k, a in pairs(g.att) do if (a.start or 0) < cut then g.att[k] = nil end end
  for k in pairs(g.fixes) do
    local s = tonumber(k:match("^(%d+)@"))
    if s and s < cut then g.fixes[k] = nil end
  end
end

---------------------------------------------------------------------------
function E:Init()
  ns.Shared.Define({
    kind = "at", label = "attendance", debounce = 30,
    enabled = function() return S().shareAttendance end,
    build = E.BuildAttendance, validate = E.ValidateAttendance,
    onChange = function() ns:Fire("ATTENDANCE_UPDATED") end,
  })
  ns.Shared.Define({
    kind = "ac", label = "attendance fixes", debounce = 10,
    build = E.BuildFixes, validate = E.ValidateFixes,
    onChange = function() ns:Fire("ATTENDANCE_UPDATED") end,
  })
end

E.ReadSoon = ns.Debounce(2, function() E.ReadCalendar() end)

function E:Login()
  E.Prune()
  ns.After(10, E.RequestCalendar)
  ns.After(15, E.ReadSoon)
  ns.Every(1800, E.RequestCalendar)
  ns.Every(60, E.Tick)
end

ns:On("CALENDAR_UPDATE_EVENT_LIST", function() E.ReadSoon() end)
ns:On("CALENDAR_UPDATE_GUILD_EVENTS", function() E.ReadSoon() end)
ns:On("PLAYER_REGEN_ENABLED", function()
  if E.pending then E.pending = false; ns.After(2, E.Tick) end
end)
ns:On("GROUP_ROSTER_UPDATE", ns.Debounce(5, function() E.Tick() end))
