local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Events & attendance (calendar, recording, sharing, officer fixes)")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", rankIndex = 1, level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", rankIndex = 3, level = 19, className = "Druid", class = "DRUID", online = true },
  { name = "Brindlewick-Forever", rank = "Member", rankIndex = 3, level = 9, className = "Mage", class = "MAGE", online = true },
  { name = "Abbeyrose-Forever", rank = "Member", rankIndex = 3, level = 9, className = "Priest", class = "PRIEST", online = false },
  { name = "Marrowfen-Forever", rank = "Guild Master", rankIndex = 0, level = 20, className = "Warrior", class = "WARRIOR", online = true },
}
local function boot(opts)
  local ns = H.boot(opts)
  H.roster = {}
  for i, r in ipairs(ROSTER) do local c = {} for k, v in pairs(r) do c[k] = v end H.roster[i] = c end
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.epoch = math.ceil(H.epoch / 60) * 60   -- the calendar has minute precision
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
local function deliver(ns, sender, tbl)
  tbl.v = tbl.v or ns.version
  for _, p in ipairs(ns.Chunker.Split(ns.Serializer.Pack(tbl))) do
    H.fire("CHAT_MSG_ADDON", "LOMBC", p, "GUILD", sender)
  end
end
local function group(names)
  for i = 1, 4 do H.units["party" .. i] = nil end
  for i, n in ipairs(names) do H.units["party" .. i] = { name = n } end
  H.state.groupSize = #names > 0 and #names + 1 or 0
  H.state.raid = false
end
local function names(rows, presentOnly)
  local out = {}
  for _, r in ipairs(rows) do if not presentOnly or r.present then out[#out + 1] = r.name end end
  table.sort(out)
  return table.concat(out, ",")
end

H.test("reads guild events from the calendar in realm time", function()
  local ns = boot()
  H.state.realmShift = 3600     -- the realm clock runs an hour ahead of ours
  local realmNow = H.epoch + 3600
  H.calendar = {
    { at = realmNow + 2 * 86400, title = "Deadmines run", by = "Oakenhollow", len = 2 * 3600, status = 6 },
    { at = realmNow + 86400, title = "Guild meeting", by = "Marrowfen-Forever", ct = "GUILD_ANNOUNCEMENT" },
    { at = realmNow + 3 * 86400, title = "My dentist", by = "Testy", ct = "PLAYER" },
    { at = realmNow - 5 * 86400, title = "Ragefire Chasm", by = "Testy" },
  }
  local n = ns.Events.ReadCalendar()
  H.eq(n, 3, "guild events and announcements only")
  local up = ns.Events.List("upcoming")
  H.eq(#up, 2)
  H.eq(up[1].title, "Guild meeting")
  H.eq(up[1].by, "Marrowfen", "organizer name shortened")
  H.eq(up[2].title, "Deadmines run")
  H.eq(up[2].start, H.epoch + 2 * 86400, "realm time converted to our epoch")
  H.eq(up[2].stop - up[2].start, 7200)
  H.eq(up[2].status, 6)
  H.eq(up[1].stop - up[1].start, ns.Events.DEFAULT_LEN, "no end time: 3 hours")
  H.eq(#ns.Events.List("past"), 1)
  -- the event vanishes from the calendar: marked removed, not deleted
  table.remove(H.calendar, 1)
  ns.Events.ReadCalendar()
  local rec = ns.Events.Get(up[2].k)
  H.ok(rec and rec.missing, "removed event is flagged")
  H.eq(#ns.Events.List("upcoming"), 1)
  -- an empty read (calendar not loaded yet) doesn't flag anything
  H.calendar = {}
  ns.Events.ReadCalendar()
  H.ok(not ns.Events.Get(up[1].k).missing)
  -- don't flip the month under a player who has the calendar open
  _G.CalendarFrame = CreateFrame("Frame"); _G.CalendarFrame:Show()
  H.eq(ns.Events.ReadCalendar(), nil)
  _G.CalendarFrame = nil
  H.state.realmShift = nil
end)

H.test("attendance is recorded while grouped with the organizer", function()
  local ns = boot()
  H.calendar = { { at = H.epoch + 600, title = "Stockades", by = "Oakenhollow", len = 3600 } }
  ns.Events.ReadCalendar()
  local key = ns.Events.List("upcoming")[1].k
  local E = ns.Events
  group({ "Brindlewick" })
  E.Tick()
  H.eq(E.Attendance(key).n, 0, "not grouped with the organizer: nothing recorded")
  group({ "Oakenhollow", "Brindlewick", "Stranger" })
  E.Tick()
  local a = E.Attendance(key)
  H.eq(a.n, 1)
  H.eq(names(a.rows), "Brindlewick,Oakenhollow,Testy", "guild members only")
  H.advance(60); E.Tick()
  H.eq(E.Attendance(key).n, 1, "one snapshot every 5 minutes")
  H.advance(300); E.Tick()
  H.eq(E.Attendance(key).n, 2)
  group({ "Oakenhollow" })
  H.state.combat = true
  H.advance(300); E.Tick()
  H.eq(E.Attendance(key).n, 2, "waits for combat to end")
  H.state.combat = false
  H.fire("PLAYER_REGEN_ENABLED")
  H.advance(3)
  a = E.Attendance(key)
  H.eq(a.n, 3)
  local brind
  for _, r in ipairs(a.rows) do if r.name == "Brindlewick" then brind = r end end
  H.eq(brind.count, 2); H.eq(brind.pct, 67)
  H.ok(a.rows[1].count == 3, "most snapshots first")
  -- after the event ends nothing more is noted
  H.advance(3600)
  local atEnd = E.Attendance(key).n
  H.ok(atEnd > 3, "kept recording until the end")
  H.advance(900); E.Tick()
  H.eq(E.Attendance(key).n, atEnd)
  -- the switch
  local t1 = math.ceil(H.epoch / 60) * 60
  H.calendar = { { at = t1, title = "Gnomeregan", by = "Testy", len = 3600 } }
  E.ReadCalendar()
  ns.db.settings.recordAttendance = false
  E.Tick()
  local g = E.Guild()
  H.eq(g.att[E.Key(t1, "Testy")], nil, "recording off")
  ns.db.settings.recordAttendance = true
  group({})
  E.Tick()
  H.eq(g.att[E.Key(t1, "Testy")].n, 1, "the organizer records their own group")
  -- announcements never record
  H.ok(not E.CanRecord({ ct = "GUILD_ANNOUNCEMENT", start = t1, stop = t1 + 600, by = "Testy" }))
end)

H.test("recorded attendance is shared and merged; bad copies rejected", function()
  local ns = boot()
  local E = ns.Events
  local t0 = H.epoch
  H.calendar = { { at = t0, title = "Stockades", by = "Testy", len = 3600 } }
  E.ReadCalendar()
  group({ "Brindlewick" })
  E.Tick()
  H.advance(40)
  local sent
  for _, m in ipairs(decodeSent(ns)) do if m.t == "D" and m.k == "at" then sent = m end end
  H.ok(sent, "attendance published")
  H.eq(sent.d[1].k, E.Key(t0, "Testy"))
  H.eq(sent.d[1].w.Brindlewick, 1)
  H.eq(sent.d[1].n, 1)
  -- a guildmate recorded the same event (more snapshots) and an older one we missed
  local key = E.Key(t0, "Testy")
  local old = E.Key(t0 - 7 * 86400, "Oakenhollow")
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "at", r = H.epoch, d = {
    { k = key, ti = "Stockades", s = t0, n = 3, w = { Brindlewick = 3, Oakenhollow = 2, Testy = 1 } },
    { k = old, ti = "Wailing Caverns", s = t0 - 7 * 86400, n = 2, w = { Oakenhollow = 2, Abbeyrose = 1 } },
  } })
  local a = E.Attendance(key)
  H.eq(a.n, 3)
  H.eq(names(a.rows), "Brindlewick,Oakenhollow,Testy")
  H.eq(table.concat(a.recorders, ","), "Oakenhollow,Testy")
  local past = E.List("past")
  H.eq(past[#past].title, "Wailing Caverns", "event known only from a guildmate shows up")
  H.ok(past[#past].remote)
  -- junk is dropped
  H.eq(E.ValidateAttendance({ { k = "nope", n = 1, w = {} } }), nil)
  local v = E.ValidateAttendance({ { k = key, n = 2, w = { ["Bad Name"] = 1, ["X|cff"] = 1, Ok = 9, Fine = 2 } } })
  H.eq(v[1].w.Fine, 2); H.eq(v[1].w.Ok, nil, "count above snapshots"); H.eq(v[1].w["Bad Name"], nil)
  -- sharing off: withdrawn
  ns.db.settings.shareAttendance = false
  H.sent = {}
  ns.Shared.Publish("at")
  H.advance(25)
  local off
  for _, m in ipairs(decodeSent(ns)) do if m.t == "D" and m.k == "at" then off = m.off end end
  H.ok(off, "withdrawn when sharing is off")
end)

H.test("officers fix attendance; fixes from other ranks are ignored", function()
  local ns = boot()
  local E = ns.Events
  H.calendar = { { at = H.epoch, title = "Stockades", by = "Testy", len = 3600 } }
  E.ReadCalendar()
  local key = E.Key(H.epoch, "Testy")
  group({ "Brindlewick" })
  E.Tick()
  H.ok(E.IsOfficer("Testy"), "rank 2 of the top 2")
  H.ok(not E.IsOfficer("Oakenhollow"))
  H.ok(E.Fix(key, "Abbeyrose", "add"))
  H.ok(E.Fix(key, "Brindlewick", "remove"))
  local ok, err = E.Fix(key, "Nobody", "add")
  H.ok(not ok and err:find("roster"), "only guild members can be added")
  local a = E.Attendance(key)
  H.eq(names(a.rows, true), "Abbeyrose,Testy")
  local ab
  for _, r in ipairs(a.rows) do if r.name == "Abbeyrose" then ab = r end end
  H.eq(ab.fix, "added"); H.eq(ab.fixBy, "Testy")
  H.advance(20)
  local sent
  for _, m in ipairs(decodeSent(ns)) do if m.t == "D" and m.k == "ac" then sent = m end end
  H.ok(sent, "fixes published")
  H.eq(table.concat(sent.d[key].a, ","), "Abbeyrose")
  -- undo
  E.Fix(key, "Brindlewick", nil)
  H.eq(names(E.Attendance(key).rows, true), "Abbeyrose,Brindlewick,Testy")
  -- a member's "fix" is rejected; the guild master's newer one wins
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "ac", r = H.epoch, d = { [key] = { t = math.floor(H.epoch) + 50, r = { "Testy" } } } })
  H.eq(names(E.Attendance(key).rows, true), "Abbeyrose,Brindlewick,Testy")
  deliver(ns, "Marrowfen-Forever", { t = "D", k = "ac", r = H.epoch, d = { [key] = { t = math.floor(H.epoch) + 60, r = { "Abbeyrose" } } } })
  a = E.Attendance(key)
  H.eq(names(a.rows, true), "Brindlewick,Testy")
  for _, r in ipairs(a.rows) do if r.name == "Abbeyrose" then ab = r end end
  H.eq(ab.fixBy, "Marrowfen")
  -- non-officers can't fix
  ns.db.settings.officerRanks = 1
  ok = E.Fix(key, "Abbeyrose", "add")
  H.ok(not ok, "rank 2 isn't trusted when only the GM is")
  ns.db.settings.officerRanks = 2
end)

H.test("summary counts events attended in the last 30 days", function()
  local ns = boot()
  local E = ns.Events
  H.calendar = {
    { at = H.epoch - 3 * 86400, title = "One", by = "Testy", len = 3600 },
    { at = H.epoch - 2 * 86400, title = "Two", by = "Testy", len = 3600 },
    { at = H.epoch - 40 * 86400, title = "Ancient", by = "Testy", len = 3600 },
  }
  E.ReadCalendar()
  local g = E.Guild()
  g.att[E.Key(H.epoch - 3 * 86400, "Testy")] = { n = 2, who = { Testy = 2, Brindlewick = 1 }, start = H.epoch - 3 * 86400 }
  g.att[E.Key(H.epoch - 2 * 86400, "Testy")] = { n = 1, who = { Testy = 1 }, start = H.epoch - 2 * 86400 }
  g.att[E.Key(H.epoch - 40 * 86400, "Testy")] = { n = 1, who = { Abbeyrose = 1 }, start = H.epoch - 40 * 86400 }
  local rows, total = E.Summary()
  H.eq(total, 2)
  H.eq(rows[1].name, "Testy"); H.eq(rows[1].attended, 2); H.eq(rows[1].pct, 100)
  H.eq(rows[2].name, "Brindlewick"); H.eq(rows[2].pct, 50)
  H.eq(#rows, 2, "old events left out")
  -- prune drops events past the keep window
  H.advance(0)
  H.epoch = H.epoch + 60 * 86400
  E.Prune()
  H.eq(g.att[E.Key(H.epoch - 100 * 86400, "Testy")], nil)
  H.epoch = H.epoch - 60 * 86400
end)

H.test("events tab: list, detail, officer add, summary", function()
  local ns = boot()
  local E = ns.Events
  H.calendar = {
    { at = H.epoch + 86400, title = "Deadmines run", by = "Oakenhollow", len = 7200, status = 6 },
    { at = H.epoch - 600, title = "Stockades", by = "Testy", len = 3600 },
  }
  E.ReadCalendar()
  group({ "Brindlewick" })
  E.Tick()
  ns.UI.Open("events")
  local Tab = ns.EventsTab
  local p = Tab.panel
  H.ok(p, "tab built")
  H.eq(#p.list.items, 2, "running + upcoming")
  H.eq(p.list.items[1].title, "Stockades")
  H.ok(p.title.text == "Stockades", "first event selected")
  H.ok(p.status.text:find("Recording"), "recording status shown")
  H.eq(#p.att.items, 2)
  H.ok(p.addBox:IsShown(), "officer can add")
  p.addBox:SetText("abbeyrose")
  p.addBtn:Click()
  H.eq(names(p.att.items, true), "Abbeyrose,Brindlewick,Testy")
  H.eq(p.addBox:GetText(), "")
  -- the row's fix button removes, then undoes
  local function item(name) for _, it in ipairs(p.att.items) do if it.name == name then return it end end end
  Tab.ToggleRow(item("Brindlewick"))
  H.eq(names(p.att.items, true), "Abbeyrose,Testy")
  Tab.ToggleRow(item("Brindlewick"))
  H.eq(names(p.att.items, true), "Abbeyrose,Brindlewick,Testy")
  -- pick the upcoming one
  Tab.Select(p.list.items[2].k)
  H.eq(p.title.text, "Deadmines run")
  H.ok(p.meta.text:find("Signed up"), "my calendar status")
  H.ok(p.when.text:find("in 1 day"), p.when.text)
  H.ok(not p.addBox:IsShown(), "no fixes before the event")
  -- past tab and summary
  p.past:Click()
  H.eq(#p.list.items, 0)
  H.ok(p.empty:IsShown())
  p.summary:Click()
  H.eq(p.title.text, "Attendance summary")
  -- non-officers see a note, not the controls
  ns.db.settings.officerRanks = 1
  p.upcoming:Click()
  Tab.Select(p.list.items[1].k)
  H.ok(not p.addBox:IsShown())
  H.ok(p.foot:IsShown())
  ns.db.settings.officerRanks = 2
end)

H.test("calendar request + settings", function()
  local ns = boot()
  H.advance(20)
  H.ok(H.state.calendarOpened >= 1, "asks the server for the calendar after login")
  H.calendar = { { at = H.epoch + 3600, title = "Later", by = "Testy" } }
  H.fire("CALENDAR_UPDATE_EVENT_LIST")
  H.advance(3)
  H.eq(ns.Events.List("upcoming")[1].title, "Later")
  ns.UI.Open("settings")
  local panel
  for _, t in ipairs(ns.UI.tabs) do if t.id == "settings" then panel = t.panel end end
  H.ok(panel.checks.recordAttendance and panel.checks.shareAttendance, "both switches in Settings")
  panel.checks.recordAttendance:Click()
  H.eq(ns.db.settings.recordAttendance, false)
end)

H.test("Events tab shows times in the player's local time, labelled", function()
  local ns = boot()
  H.state.realmShift = -2 * 3600   -- realm two hours behind us
  local start = H.epoch + 3 * 86400
  H.calendar = { { at = start - 2 * 3600, title = "Stockades", by = "Oakenhollow", len = 5400 } }
  ns.Events.ReadCalendar()
  local rec = ns.Events.List("upcoming")[1]
  H.eq(rec.start, start, "realm time converted to the real moment")
  H.eq(rec.tzok, nil, "converted (nothing extra saved)")
  local short = ns.EventsTab.When(rec)
  local long = ns.EventsTab.When(rec, true)
  local clock = date("%I:%M %p", start):gsub("^0", "")
  H.ok(short:find(clock .. " (your time)", 1, true), short)
  H.ok(long:find(clock .. " - " .. (date("%I:%M %p", start + 5400):gsub("^0", "")) .. " (your time)", 1, true), long)
  -- no usable server clock: fall back to time() (still an epoch), still converted
  local gst = GetServerTime
  _G.GetServerTime = nil
  local off, ok = ns.Events.RealmOffset(C_DateAndTime.GetCurrentCalendarTime())
  H.eq(off, 7200); H.eq(ok, true)   -- realm behind: add two hours
  -- an offset no time zone has: left as the calendar shows it, and labelled
  _G.GetServerTime = function() return math.floor(H.epoch) + 30 * 3600 end
  off, ok = ns.Events.RealmOffset(C_DateAndTime.GetCurrentCalendarTime())
  H.eq(off, 0); H.eq(ok, false)
  off, ok = ns.Events.RealmOffset(nil)
  H.eq(off, 0); H.eq(ok, false)
  ns.Events.ReadCalendar()
  _G.GetServerTime = gst
  local bad
  for _, r in ipairs(ns.Events.List("upcoming")) do if r.tzok == false then bad = r end end
  H.ok(bad, "record flagged as not converted")
  H.ok(ns.EventsTab.When(bad):find("(realm time?)", 1, true), ns.EventsTab.When(bad))
  H.ok(ns.EventsTab.When(bad, true):find("unverified until Nov 4", 1, true))
  -- the tab itself renders the label
  ns.UI.Open("events")
  H.eq(#H.errors, 0, tostring(H.errors[1]))
  H.state.realmShift = nil
  H.calendar = {}
end)

H.done()
