-- LOMB Companion: Leaderboard tab -- just for fun.
local _, ns = ...
local W, UI, T = ns.Widgets, ns.UI, ns.Theme
local News = ns.News
local Tab = { board = "level", weekly = true }
ns.BoardTab = Tab

local MEDALS = { { 0.95, 0.78, 0.36 }, { 0.78, 0.80, 0.86 }, { 0.80, 0.52, 0.30 } }

local function fmt(key, v)
  if key == "played" then return ("%d h"):format(v) end
  if key == "level" then return tostring(v) end
  return W.Thousands(v)
end

local function createRow(list, i)
  local row = CreateFrame("Frame", nil, list)
  row.bg = W.Fill(row, i % 2 == 0 and "row" or { 0, 0, 0, 0 }, "BACKGROUND")
  row.bg:SetAllPoints()
  row.rank = W.Text(row, "title", 15, "muted", "CENTER")
  row.rank:SetPoint("LEFT", 0, 0)
  row.rank:SetWidth(36)
  row.name = W.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", 44, 0)
  row.name:SetWidth(170)
  row.bar = W.Bar(row, 300, 10, "accent")
  row.bar:SetPoint("LEFT", 220, 0)
  row.bar.text:Hide()
  row.value = W.Text(row, "narrow", 13, "text", "RIGHT")
  row.value:SetPoint("RIGHT", -8, 0)
  row.value:SetWidth(90)
  row.detail = W.Text(row, "narrow", 11, "muted")
  row.detail:SetPoint("LEFT", 220, 0)
  row.detail:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
  return row
end

local function updateRow(row, r)
  local medal = MEDALS[r.rank]
  row.rank:SetText(r.rankText or tostring(r.rank))
  if medal then row.rank:SetTextColor(medal[1], medal[2], medal[3]) else row.rank:SetTextColor(0.6, 0.57, 0.66) end
  row.name:SetText(r.class and T.classColorText(r.class, ns.Compat.ShortName(r.name)) or ns.Compat.ShortName(r.name))
  if r.detail then
    row.bar:Hide()
    row.detail:SetText(r.detail)
    row.detail:Show()
  else
    row.detail:Hide()
    row.bar:Show()
    row.bar:SetValue(r.frac or 0)
    if medal then row.bar:SetStatusBarColor(medal[1], medal[2], medal[3]) else row.bar:SetStatusBarColor(0.72, 0.45, 1) end
  end
  row.value:SetText(r.valueText or "")
end

-- "Firsts": one row per milestone level, guild first + class firsts
function Tab.FirstsRows()
  local rows = {}
  local ms = News.Milestones()
  for i = #News.MILESTONES, 1, -1 do
    local L = News.MILESTONES[i]
    local m = ms[L]
    if m and m.first then
      local cls = {}
      for cl, e in pairs(m.classes) do
        if e.name ~= m.first.name then cls[#cls + 1] = { cl = cl, e = e } end
      end
      table.sort(cls, function(a, b) return a.e.t < b.e.t end)
      local parts = {}
      for _, c in ipairs(cls) do parts[#parts + 1] = T.classColorText(c.cl, ns.Compat.ShortName(c.e.name)) end
      rows[#rows + 1] = {
        rank = 99, rankText = tostring(L), name = m.first.name, class = News.ClassOf(m.first.name),
        detail = #parts > 0 and ("class firsts: " .. table.concat(parts, ", ")) or "first of any class",
        valueText = (m.first.approx and "~" or "") .. date("%b %d", m.first.t),
      }
    end
  end
  return rows
end

function Tab.Rows()
  if Tab.board == "firsts" then return Tab.FirstsRows() end
  local def
  for _, b in ipairs(News.BOARDS) do if b.key == Tab.board then def = b end end
  local rows = News.Board(Tab.board, def and def.weekly and Tab.weekly)
  local top = rows[1] and rows[1].value or 1
  for _, r in ipairs(rows) do
    r.frac = top > 0 and r.value / top or 0
    r.valueText = fmt(Tab.board, r.value)
  end
  return rows
end

UI.RegisterTab({
  id = "board", label = "Leaderboard", order = 50,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.buttons = {}
    local prev
    for _, b in ipairs(News.BOARDS) do
      local btn = W.Button(p, b.label, 80, 22, function() Tab.board = b.key; UI.Refresh("board") end)
      if prev then btn:SetPoint("LEFT", prev, "RIGHT", 6, 0) else btn:SetPoint("TOPLEFT", 0, 0) end
      p.buttons[b.key], prev = btn, btn
    end
    p.week = W.Button(p, "This week", 84, 22, function() Tab.weekly = true; UI.Refresh("board") end)
    p.all = W.Button(p, "All time", 84, 22, function() Tab.weekly = false; UI.Refresh("board") end)
    p.all:SetPoint("TOPRIGHT", 0, 0)
    p.week:SetPoint("RIGHT", p.all, "LEFT", -6, 0)
    p.week.tip = "Since the weekly reset (Tuesday)."
    local div = W.Divider(p)
    div:SetPoint("TOPLEFT", 0, -30)
    div:SetPoint("TOPRIGHT", 0, -30)

    p.list = W.List(p, 26, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 0, -34)
    p.list:SetPoint("BOTTOMRIGHT", 0, 24)

    p.empty = W.Text(p, "body", 12, "muted", "CENTER")
    p.empty:SetPoint("CENTER", p.list, "CENTER", 0, 10)
    p.empty:SetWidth(440)
    p.empty:SetWordWrap(true)

    p.foot = W.Text(p, "narrow", 11, "muted")
    p.foot:SetPoint("BOTTOMLEFT", 0, 6)
    p.foot:SetText("Just for fun: stats are self-reported by guildmates with the addon. Levels come from the roster.")

    ns:Listen("BOARD_UPDATED", ns.Debounce(0.5, function() UI.Refresh("board") end))
    return p
  end,
  refresh = function(p)
    local def
    for _, b in ipairs(News.BOARDS) do
      p.buttons[b.key]:SetActive(b.key == Tab.board)
      if b.key == Tab.board then def = b end
    end
    local weekly = def and def.weekly
    p.week:SetShown(weekly); p.all:SetShown(weekly)
    p.week:SetActive(Tab.weekly); p.all:SetActive(not Tab.weekly)
    local rows = Tab.Rows()
    p.list:SetItems(rows)
    if #rows == 0 then
      p.empty:SetText(Tab.board == "firsts" and "Nobody has reached level 10 yet. Get out there!" or
        "Nothing here yet. Stats appear as guildmates with the addon play.")
      p.empty:Show()
    else
      p.empty:Hide()
    end
  end,
})
