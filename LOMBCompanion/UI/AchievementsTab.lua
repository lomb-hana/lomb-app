-- LOMB Companion: Achievements tab -- yours (with progress) or a guildmate's (earned, with dates).
local _, ns = ...
local W, UI, T = ns.Widgets, ns.UI, ns.Theme
local A = ns.Achievements
local Tab = { cat = nil, who = nil }
ns.AchievementsTab = Tab

local function subject() return Tab.who or ns.playerKey end

local function createRow(list, i)
  local row = CreateFrame("Frame", nil, list)
  row.bg = W.Fill(row, i % 2 == 0 and "row" or { 0, 0, 0, 0 }, "BACKGROUND")
  row.bg:SetAllPoints()
  row:EnableMouse(true)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 6, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.head = W.Text(row, "title", 13, "gold")
  row.head:SetPoint("LEFT", 4, -2)
  row.headCount = W.Text(row, "narrow", 11, "muted", "RIGHT")
  row.headCount:SetPoint("RIGHT", -8, -2)
  row.right = W.Text(row, "narrow", 11, "good", "RIGHT")
  row.right:SetPoint("RIGHT", -8, 0)
  row.right:SetWidth(120)
  row.bar = W.Bar(row, 120, 12, "accent", "panel2")
  row.bar:SetPoint("RIGHT", -8, 0)
  row.name = W.Text(row, "body", 12, "text")
  row.name:SetPoint("TOPLEFT", 36, -3)
  row.name:SetPoint("RIGHT", -140, 0)
  row.desc = W.Text(row, "narrow", 10, "muted")
  row.desc:SetPoint("TOPLEFT", 36, -17)
  row.desc:SetPoint("RIGHT", -140, 0)
  row.desc:SetWordWrap(false)
  W.Tooltip(row, function(tt, self)
    local r = self.item
    if not r or r.header then return end
    tt:SetText(r.def.name, 0.95, 0.78, 0.36)
    tt:AddLine(r.def.desc, 0.9, 0.88, 0.94, true)
    if r.earned then
      tt:AddLine("Earned " .. A.DateText(r.t, r.x), 0.45, 0.85, 0.5)
      if r.x then tt:AddLine("~ before LOMB could see it: the exact date isn't known.", 0.6, 0.57, 0.66, true) end
    elseif r.cur ~= nil then
      tt:AddLine(("%s of %d"):format(tostring(r.cur), r.need), 0.6, 0.57, 0.66)
    end
    if r.def.acct then tt:AddLine("Counts for any character on your account.", 0.6, 0.57, 0.66, true) end
  end)
  return row
end

local function updateRow(row, r)
  local isHead = r.header and true or false
  row.head:SetShown(isHead); row.headCount:SetShown(isHead)
  row.icon:SetShown(not isHead); row.name:SetShown(not isHead); row.desc:SetShown(not isHead)
  if isHead then
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.head:SetText(r.label)
    row.headCount:SetText(("%d of %d"):format(r.got, r.total))
    row.right:Hide(); row.bar:Hide()
    return
  end
  row.bg:SetColorTexture(W.rgba(row.index % 2 == 0 and "row" or { 0, 0, 0, 0 }))
  row.icon:SetTexture(r.def.icon)
  row.icon:SetDesaturated(not r.earned)
  row.icon:SetAlpha(r.earned and 1 or 0.45)
  row.name:SetText(r.earned and ("|cfff2c75c" .. r.def.name .. "|r") or r.def.name)
  row.desc:SetText(r.def.desc)
  if r.earned then
    row.bar:Hide()
    row.right:SetText(A.DateText(r.t, r.x))
    row.right:SetTextColor(W.rgba("good"))
    row.right:Show()
  elseif type(r.cur) == "number" then
    row.right:Hide()
    row.bar:SetMinMaxValues(0, r.need)
    row.bar:SetValue(math.min(r.cur, r.need))
    row.bar.text:SetText(r.need == 1 and "not yet" or ("%s / %s"):format(W.Thousands(r.cur), W.Thousands(r.need)))
    row.bar:Show()
  else
    row.bar:Hide()
    row.right:SetText(subject() == ns.playerKey and (r.def.prof and "not learned" or "-") or "")
    row.right:SetTextColor(W.rgba("muted"))
    row.right:Show()
  end
end

function Tab.ShowFor(name)
  Tab.who = (name ~= ns.playerKey) and name or nil
  UI.Open("achievements")
  UI.Select("achievements")
end

UI.RegisterTab({
  id = "achievements", label = "Achievements", order = 22,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.title = W.SectionTitle(p, "Achievements")
    p.title:SetPoint("TOPLEFT", 0, -2)
    p.count = W.Text(p, "narrow", 11, "gold")
    p.count:SetPoint("LEFT", p.title, "RIGHT", 10, 0)
    p.mine = W.Button(p, "Back to mine", 100, 22, function() Tab.who = nil; UI.Refresh("achievements") end)
    p.mine:SetPoint("TOPRIGHT", 0, 0)
    p.cats = {}
    local prev
    local cats = { { key = nil, label = "All" } }
    for _, c in ipairs(A.CATEGORIES) do cats[#cats + 1] = { key = c.key, label = c.key == "ex" and "Exploration" or c.label } end
    for _, c in ipairs(cats) do
      local b = W.Button(p, c.label, c.key == "ex" and 92 or 84, 20, function() Tab.cat = c.key; UI.Refresh("achievements") end)
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 0, -28) end
      p.cats[#p.cats + 1] = { key = c.key, btn = b }
      prev = b
    end
    local div = W.Divider(p)
    div:SetPoint("TOPLEFT", 0, -54)
    div:SetPoint("TOPRIGHT", 0, -54)

    p.list = W.List(p, 32, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 0, -58)
    p.list:SetPoint("BOTTOMRIGHT", 0, 24)

    p.empty = W.Text(p, "body", 12, "muted", "CENTER")
    p.empty:SetPoint("CENTER", p.list, "CENTER", 0, 10)
    p.empty:SetWidth(440)
    p.empty:SetWordWrap(true)

    p.foot = W.Text(p, "narrow", 11, "muted")
    p.foot:SetPoint("BOTTOMLEFT", 0, 6)
    p.foot:SetText("Personal goals, no races. Guildmates see yours (and the News line) unless Share activity is off.")

    ns:Listen("ACHIEVEMENTS_UPDATED", ns.Debounce(0.5, function() UI.Refresh("achievements") end))
    return p
  end,
  refresh = function(p)
    local who = subject()
    local isMe = who == ns.playerKey
    if isMe then A.Scan() end
    local earned = A.For(who)
    local n = 0
    for _ in pairs(earned or {}) do n = n + 1 end
    local r = ns.Roster.byName[who]
    p.title:SetText(isMe and "My achievements" or (T.classColorText(r and r.class, ns.Compat.ShortName(who)) .. "'s achievements"))
    p.count:SetText(earned and ("%d of %d earned"):format(n, A.TOTAL) or "")
    p.mine:SetShown(not isMe)
    for _, c in ipairs(p.cats) do c.btn:SetActive(c.key == Tab.cat) end
    if not earned then
      p.list:SetItems({})
      p.empty:SetText("Nothing shared: they don't have LOMB Companion, or have activity sharing turned off.")
      p.empty:Show()
      return
    end
    p.empty:Hide()
    p.list:SetItems(A.Rows(who, Tab.cat))
  end,
})
