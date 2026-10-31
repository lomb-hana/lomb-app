-- LOMB Companion: Events tab -- guild calendar events and who showed up.
local _, ns = ...
local C = ns.Compat
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local Tab = {}
ns.EventsTab = Tab

local LIST_W = 230
Tab.view = { which = "upcoming", mode = "event", selected = nil, add = "" }
local view = Tab.view

local function E() return ns.Events end

-- Event times are shown in the player's local time ("8:00 PM (your time)"); see
-- Events.RealmOffset for the conversion and the fallback when it can't be done.
function Tab.When(rec, long)
  local day = date(long and "%A, %b %d" or "%a %b %d", rec.start):gsub(" 0(%d)", " %1")
  local s = day .. "  ·  " .. E().Clock(rec.start)
  if long and rec.stop then s = s .. " - " .. E().Clock(rec.stop) end
  return s .. " " .. E().TimeLabel(rec, not long)
end

function Tab.Relative(rec, now)
  now = now or time()
  if now >= rec.start and now <= rec.stop then return "|cff7fe07fhappening now|r" end
  local d = rec.start - now
  local function span(sec)
    if sec < 3600 then return ("%d min"):format(math.max(1, math.floor(sec / 60))) end
    if sec < 86400 then return ("%d hour%s"):format(math.floor(sec / 3600), sec < 7200 and "" or "s") end
    local days = math.floor(sec / 86400)
    return ("%d day%s"):format(days, days == 1 and "" or "s")
  end
  if d > 0 then return "in " .. span(d) end
  return span(now - rec.stop) .. " ago"
end

local function classText(short)
  local R = ns.Roster
  local row = R and R.byName and R.byName[C.FullName(short)]
  if row and row.class then return T.classColorText(row.class, short) end
  return short
end
Tab.ClassText = classText

---------------------------------------------------------------------------
-- left: event list
---------------------------------------------------------------------------
local function createEventRow(list)
  local row = CreateFrame("Button", nil, list)
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.sel = W.Fill(row, "accentDim", "BACKGROUND")
  row.sel:SetAllPoints()
  row.when = W.Text(row, "narrow", 10, "muted")
  row.when:SetPoint("TOPLEFT", 6, -3)
  row.when:SetPoint("RIGHT", -4, 0)
  row.title = W.Text(row, "body", 12, "text")
  row.title:SetPoint("TOPLEFT", 6, -17)
  row.title:SetPoint("RIGHT", -4, 0)
  row:SetScript("OnClick", function(self) Tab.Select(self.item.k) end)
  return row
end

local function updateEventRow(row, rec)
  row.when:SetText(Tab.When(rec))
  local a = E().Attendance(rec.k)
  local extra = ""
  if a.present > 0 then extra = ("  |cff9991a8%d|r"):format(a.present) end
  local title = rec.missing and ("|cff9991a8" .. rec.title .. " (removed)|r") or rec.title
  if E().Running(rec) then title = "|cff7fe07fNow:|r " .. title end
  row.title:SetText(title .. extra)
  row.sel:SetShown(view.mode == "event" and view.selected == rec.k)
end

---------------------------------------------------------------------------
-- right: attendance rows
---------------------------------------------------------------------------
local function createAttRow(list, i)
  local row = CreateFrame("Frame", nil, list)
  row.bg = W.Fill(row, i % 2 == 0 and "row" or { 0, 0, 0, 0 }, "BACKGROUND")
  row.bg:SetAllPoints()
  row.name = W.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", 6, 0)
  row.name:SetWidth(140)
  row.pct = W.Text(row, "narrow", 11, "text", "RIGHT")
  row.pct:SetPoint("LEFT", 150, 0)
  row.pct:SetWidth(60)
  row.note = W.Text(row, "narrow", 11, "muted")
  row.note:SetPoint("LEFT", 222, 0)
  row.note:SetPoint("RIGHT", -28, 0)
  row.fix = W.IconButton(row, "x", "Remove", function(self) Tab.ToggleRow(self:GetParent().item) end, 16)
  row.fix:SetPoint("RIGHT", -8, 0)
  return row
end

local function updateAttRow(row, item)
  if view.mode == "summary" then
    row.name:SetText(classText(item.name))
    row.pct:SetText(("%d%%"):format(item.pct))
    row.note:SetText(("%d of %d events"):format(item.attended, item.total))
    row.fix:Hide()
    return
  end
  row.name:SetText(item.present and classText(item.name) or ("|cff9991a8" .. item.name .. "|r"))
  row.pct:SetText(item.present and (item.count > 0 and ("%d%%"):format(item.pct) or "-") or "|cff9991a8absent|r")
  local note = ""
  if item.fix then note = ("|cfff2c75c%s by %s|r"):format(item.fix, item.fixBy) end
  row.note:SetText(note)
  local officer = E().IsOfficer(ns.playerKey or "")
  row.fix:SetShown(officer)
  if officer then
    row.fix.label:SetText(item.fix and "<" or (item.present and "x" or "+"))
    row.fix.tip = item.fix and "Undo the fix" or (item.present and "Mark absent" or "Mark present")
  end
end

-- officer button on a row: mark absent / present, or undo a fix
-- attendance order: as recorded (present first, most present first) until a header is clicked
Tab.attView = { sort = nil, desc = false }
function Tab.SortAtt(rows)
  local v = Tab.attView
  if not v.sort then return rows end
  local copy = {}
  for i, r in ipairs(rows) do copy[i] = r end
  if v.sort == "name" then return W.SortRows(copy, function(r) return C.ShortName(r.name or "") end, v.desc) end
  return W.SortRows(copy, function(r) if r.present == false then return nil end return r.pct end, v.desc, "name")
end

function Tab.ToggleRow(item)
  if not item or not view.selected then return end
  local mode = item.present and "remove" or "add"
  if item.fix then mode = nil end
  local ok, err = E().Fix(view.selected, item.name, mode)
  if not ok and err then ns.Print(err) end
  UI.Refresh("events")
end

---------------------------------------------------------------------------
function Tab.Select(key)
  view.selected, view.mode = key, "event"
  UI.Refresh("events")
end

function Tab.ShowSummary()
  view.mode = "summary"
  UI.Refresh("events")
end

function Tab.SetWhich(which)
  view.which, view.selected = which, nil
  UI.Refresh("events")
end

function Tab.AddName(name)
  name = strtrim and strtrim(name or "") or (name or "")
  if name == "" or not view.selected then return false end
  name = name:sub(1, 1):upper() .. name:sub(2):lower()
  local ok, err = E().Fix(view.selected, name, "add")
  if not ok and err then ns.Print(err) end
  UI.Refresh("events")
  return ok
end

function Tab.StatusText(rec, a)
  local Ev = E()
  if rec.ct ~= "GUILD_EVENT" then return "Announcements don't take attendance." end
  if Ev.Running(rec) then
    if Ev.CanRecord(rec) then
      return ("|cff7fe07fRecording:|r you're grouped with %s. %d snapshot%s so far (every 5 min)."):format(
        rec.by == C.ShortName(ns.playerKey or "") and "your own group" or rec.by, a.n, a.n == 1 and "" or "s")
    end
    if not ns.db.settings.recordAttendance then return "Recording is turned off in Settings." end
    return ("Join %s's group to have attendance recorded (anyone grouped with them records it)."):format(rec.by or "the organizer")
  end
  if rec.start > time() then
    return ("Attendance is taken from %s's group during the event, starting 15 minutes early."):format(rec.by or "the organizer")
  end
  if a.n == 0 and #a.rows == 0 then
    return "No attendance was recorded for this event."
  end
  return ("%d present  ·  %d snapshot%s  ·  recorded by %s"):format(a.present, a.n, a.n == 1 and "" or "s",
    #a.recorders > 0 and table.concat(a.recorders, ", ") or "officer fixes only")
end

UI.RegisterTab({
  id = "events", label = "Events", order = 65,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    local left = W.Panel(p, "panel", "border")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(LIST_W)
    local half = (LIST_W - 16) / 2
    p.upcoming = W.Button(left, "Upcoming", half, 20, function() Tab.SetWhich("upcoming") end)
    p.upcoming:SetPoint("TOPLEFT", 6, -6)
    p.past = W.Button(left, "Past", half, 20, function() Tab.SetWhich("past") end)
    p.past:SetPoint("LEFT", p.upcoming, "RIGHT", 4, 0)
    p.upcoming.tip = "Guild events from the in-game calendar that haven't started yet."
    p.past.tip = "Events that were held, with the attendance LOMB recorded."
    p.list = W.List(left, 34, createEventRow, updateEventRow)
    p.list:SetPoint("TOPLEFT", 2, -32)
    p.list:SetPoint("BOTTOMRIGHT", -2, 34)
    p.empty = W.Text(left, "body", 11, "muted", "CENTER")
    p.empty:SetPoint("TOP", 0, -60)
    p.empty:SetWidth(LIST_W - 24)
    p.empty:SetWordWrap(true)
    p.summary = W.Button(left, "Attendance summary", LIST_W - 12, 22, Tab.ShowSummary)
    p.summary:SetPoint("BOTTOMLEFT", 6, 6)
    p.summary.tip = "How often each member was at guild events."

    local right = W.Panel(p, "panel", "border")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    p.right = right
    p.title = W.Text(right, "title", 16, "gold")
    p.title:SetPoint("TOPLEFT", 12, -10)
    p.title:SetPoint("RIGHT", -12, 0)
    p.when = W.Text(right, "body", 12, "text")
    p.when:SetPoint("TOPLEFT", 12, -34)
    p.when:SetPoint("RIGHT", -12, 0)
    p.meta = W.Text(right, "narrow", 11, "muted")
    p.meta:SetPoint("TOPLEFT", 12, -52)
    p.meta:SetPoint("RIGHT", -12, 0)
    p.section = W.SectionTitle(right, "Attendance")
    p.section:SetPoint("TOPLEFT", 12, -74)
    p.section:SetPoint("RIGHT", -12, 0)
    p.status = W.Text(right, "narrow", 11, "muted")
    p.status:SetPoint("TOPLEFT", 12, -96)
    p.status:SetPoint("RIGHT", -12, 0)
    p.status:SetWordWrap(true)
    p.attHead = W.SortHeader(right, {
      { key = "name", label = "Name", x = 6, w = 140, tip = "Sort by name (click again for Z to A)." },
      { key = "pct", label = "Present", x = 150, w = 64, justify = "RIGHT", desc = true,
        tip = "Sort by how much of the event (or of all events, in the summary) they were there for." },
    }, Tab.attView, function() UI.Refresh("events") end)
    p.attHead:SetPoint("TOPLEFT", 8, -126)
    p.attHead:SetPoint("RIGHT", -4, 0)
    p.att = W.List(right, 20, createAttRow, updateAttRow)
    p.att:SetPoint("TOPLEFT", 8, -146)
    p.att:SetPoint("BOTTOMRIGHT", -4, 36)
    p.addBox = W.SearchBox(right, 180, "Add a guildmate", function(text) view.add = text end)
    p.addBox:SetPoint("BOTTOMLEFT", 12, 8)
    p.addBox:SetScript("OnEnterPressed", function(self)
      if Tab.AddName(self:GetText()) then self:SetText("") end
      self:ClearFocus()
    end)
    p.addBtn = W.Button(right, "Mark present", 110, 22, function()
      if Tab.AddName(p.addBox:GetText()) then p.addBox:SetText("") end
    end)
    p.addBtn:SetPoint("LEFT", p.addBox, "RIGHT", 6, 0)
    p.foot = W.Text(right, "narrow", 11, "muted")
    p.foot:SetPoint("BOTTOMLEFT", 12, 12)
    p.foot:SetPoint("BOTTOMRIGHT", -12, 12)

    local refresh = ns.Debounce(0.5, function() UI.Refresh("events") end)
    ns:Listen("EVENTS_UPDATED", refresh)
    ns:Listen("ATTENDANCE_UPDATED", refresh)
    ns:Listen("ROSTER_UPDATED", refresh)
    return p
  end,
  refresh = function(p)
    local Ev = E()
    p.upcoming:SetActive(view.which == "upcoming")
    p.past:SetActive(view.which == "past")
    p.summary:SetActive(view.mode == "summary")
    local items = Ev.List(view.which)
    p.list:SetItems(items, view.which)
    if #items == 0 then
      p.empty:SetText(view.which == "upcoming"
        and ns.Theme.Playful("events.none", "No upcoming guild events.\n\nEvents come from the in-game calendar: officers add them there.")
        or ns.Theme.Playful("events.past", "No past events yet."))
      p.empty:Show()
    else
      p.empty:Hide()
    end
    local officer = Ev.IsOfficer(ns.playerKey or "")

    if view.mode == "summary" then
      local rows, total = Ev.Summary()
      p.title:SetText("Attendance summary")
      p.when:SetText(("Last %d days  ·  %d event%s with attendance"):format(Ev.SUMMARY_DAYS, total, total == 1 and "" or "s"))
      p.meta:SetText("Present = seen in the organizer's group at least once, plus officer fixes.")
      p.section:SetText("Members")
      p.status:SetText(#rows == 0 and "Nothing recorded yet." or "")
      p.att:SetItems(Tab.SortAtt(rows))
      p.attHead:SetShown(#rows > 1)
      p.addBox:Hide(); p.addBtn:Hide(); p.foot:Hide()
      return
    end

    local rec = view.selected and Ev.Get(view.selected)
    if not rec then
      rec = items[1]
      view.selected = rec and rec.k
    end
    if not rec then
      p.title:SetText("Events")
      p.when:SetText("")
      p.meta:SetText("")
      p.section:SetText("Attendance")
      p.status:SetText("Pick an event on the left.")
      p.att:SetItems({})
      p.attHead:Hide()
      p.addBox:Hide(); p.addBtn:Hide(); p.foot:Hide()
      return
    end
    p.title:SetText(rec.title)
    p.when:SetText(Tab.When(rec, true) .. "  ·  " .. Tab.Relative(rec))
    local meta = { "Organizer: " .. (rec.by and classText(rec.by) or "unknown"), Ev.TYPES[rec.ct] or "Guild event" }
    if rec.status and Ev.STATUS[rec.status] then meta[#meta + 1] = "You: " .. Ev.STATUS[rec.status] end
    if rec.remote then meta[#meta + 1] = "from a guildmate's record" end
    p.meta:SetText(table.concat(meta, "  ·  "))
    local a = Ev.Attendance(rec.k)
    p.section:SetText(a.present > 0 and ("Attendance  (%d)"):format(a.present) or "Attendance")
    p.status:SetText(Tab.StatusText(rec, a))
    p.att:SetItems(Tab.SortAtt(a.rows))
    p.attHead:SetShown(#a.rows > 1)
    local past = rec.start - Ev.EARLY <= time()
    p.addBox:SetShown(officer and past and rec.ct == "GUILD_EVENT")
    p.addBtn:SetShown(officer and past and rec.ct == "GUILD_EVENT")
    p.foot:SetShown(not officer and past and rec.ct == "GUILD_EVENT")
    p.foot:SetText("Officers can correct attendance.")
  end,
})
