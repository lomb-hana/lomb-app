-- LOMB Companion: Roster tab.
local _, ns = ...
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local Roster = ns.Roster

local view = { search = "", onlineOnly = false, addonOnly = false, hideAlts = false, sort = "online" }
local Tab = {}
ns.RosterTab = Tab

local function professionsText(pr)
  if type(pr) ~= "table" then return nil end
  local parts = {}
  for code, v in pairs(pr) do
    local name = ns.Me.FROM_CODE[code] or code
    local rank = type(v) == "table" and v[1] or v
    parts[#parts + 1] = ("%s %s"):format(name, tostring(rank))
  end
  table.sort(parts)
  return table.concat(parts, ", ")
end
ns.UI.ProfessionsText = professionsText

local function createRow(list, i)
  local row = CreateFrame("Button", nil, list)
  row.bg = W.Fill(row, i % 2 == 0 and "row" or { 0, 0, 0, 0 }, "BACKGROUND")
  row.bg:SetAllPoints()
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.cells = {}
  local x = 4
  for _, col in ipairs(T.rosterColumns) do
    if col.key == "badge" then
      row.badge = row:CreateTexture(nil, "ARTWORK")
      row.badge:SetTexture(T.LOGO)
      row.badge:SetSize(12, 12)
      row.badge:SetPoint("LEFT", x + 1, 0)
    else
      local fs = W.Text(row, col.key == "short" and "body" or "narrow", col.key == "short" and 12 or 12,
        "text", col.justify or "LEFT")
      fs:SetPoint("LEFT", x, 0)
      fs:SetWidth(col.w - 6)
      row.cells[col.key] = fs
    end
    x = x + col.w
  end
  row:SetScript("OnClick", function(self) if self.item then Tab.OpenProfile(self.item.name) end end)
  W.Tooltip(row, function(tt, self)
    local r = self.item
    if not r then return end
    tt:SetText(T.classColorText(r.class, r.short), 1, 1, 1)
    local main = ns.Profiles.MainOf(r.name)
    local alts = ns.Profiles.AltsOf(r.name)
    if main then tt:AddLine("Alt of " .. ns.Compat.ShortName(main), 0.95, 0.78, 0.36) end
    if #alts > 0 then
      local names = {}
      for _, a in ipairs(alts) do names[#names + 1] = ns.Compat.ShortName(a) end
      tt:AddLine("Alts: " .. table.concat(names, ", "), 0.95, 0.78, 0.36, true)
    end
    tt:AddLine(("Level %s %s  ·  %s"):format(tostring(r.level or "?"), r.className or "", r.rank or ""), 0.8, 0.78, 0.85)
    if r.zone then tt:AddLine(r.zone, 0.6, 0.57, 0.66) end
    local peer = r.peer
    if peer then
      tt:AddLine(" ")
      tt:AddLine("LOMB Companion " .. tostring(peer.v or "?"), T.colors.accent[1], T.colors.accent[2], T.colors.accent[3])
      local p = peer.profile
      if p then
        local prof = professionsText(p.pr)
        if prof and prof ~= "" then tt:AddDoubleLine("Professions", prof, 0.6, 0.57, 0.66, 1, 1, 1) end
        if p.il then tt:AddDoubleLine("Item level", tostring(p.il), 0.6, 0.57, 0.66, 1, 1, 1) end
        if p.pt then tt:AddDoubleLine("Played", p.pt .. "h", 0.6, 0.57, 0.66, 1, 1, 1) end
      elseif peer.sharing == false then
        tt:AddLine("Not sharing gear / professions.", 0.6, 0.57, 0.66)
      end
    else
      tt:AddLine(" ")
      tt:AddLine("Doesn't have LOMB Companion yet.", 0.6, 0.57, 0.66)
    end
    tt:AddLine("Click to open their profile.", 0.6, 0.57, 0.66)
  end)
  return row
end

local function updateRow(row, r)
  local dim = not r.online
  row.badge:SetShown(r.peer ~= nil)
  local tag = ""
  if r.mainShort then tag = "  |cff777080(" .. r.mainShort .. ")|r"
  elseif (r.altCount or 0) > 0 then tag = "  |cff777080+" .. r.altCount .. "|r" end
  row.cells.short:SetText(T.classColorText(r.class, r.short or "?") .. tag)
  row.cells.short:SetAlpha(dim and 0.6 or 1)
  row.cells.level:SetText(r.level or "")
  row.cells.class:SetText(r.className or "")
  row.cells.rankIndex:SetText(r.rank or "")
  row.cells.zone:SetText(r.zone or "")
  row.cells.online:SetText(Roster.FormatLastOnline(r))
  for key, fs in pairs(row.cells) do
    if key ~= "short" and key ~= "online" then fs:SetTextColor(W.rgba(dim and "muted" or "text")) end
  end
end

UI.RegisterTab({
  id = "roster", label = "Roster", order = 10,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    local search = W.SearchBox(p, 180, "Search name, zone, class", function(text)
      view.search = text
      UI.Refresh("roster")
    end)
    search:SetPoint("TOPLEFT", 0, 0)
    local online = W.Check(p, "Online only", function() return view.onlineOnly end,
      function(v) view.onlineOnly = v; UI.Refresh("roster") end)
    online:SetWidth(100)
    online:SetPoint("LEFT", search, "RIGHT", 14, 0)
    local addon = W.Check(p, "Has LOMB", function() return view.addonOnly end,
      function(v) view.addonOnly = v; UI.Refresh("roster") end)
    addon:SetWidth(100)
    addon:SetPoint("LEFT", online, "RIGHT", 4, 0)
    local alts = W.Check(p, "Hide alts", function() return view.hideAlts end,
      function(v) view.hideAlts = v; UI.Refresh("roster") end,
      "Hide characters linked to a main (by the addon or by a guild note like \"alt of Bob\").")
    alts:SetWidth(90)
    alts:SetPoint("LEFT", addon, "RIGHT", 4, 0)
    p.counts = W.Text(p, "narrow", 11, "muted", "RIGHT")
    p.counts:SetPoint("TOPRIGHT", 0, -5)

    -- header (click to sort)
    local header = W.Panel(p, "panel", "border")
    header:SetPoint("TOPLEFT", 0, -30)
    header:SetPoint("TOPRIGHT", 0, -30)
    header:SetHeight(20)
    local cols, x = {}, 4
    local TIPS = { short = "Sort by name.", level = "Sort by level (highest first, click again to flip).",
      className = "Sort by class.", rankIndex = "Sort by guild rank (Guild Master first).",
      zone = "Sort by zone. Offline members go last." }
    for _, col in ipairs(T.rosterColumns) do
      if col.label ~= "" then
        local key = col.key == "short" and "short" or col.key == "class" and "className" or col.key
        cols[#cols + 1] = { key = key, label = col.label:upper(), x = x, w = col.w - 4, justify = col.justify,
          desc = key == "level", tip = TIPS[key] or ("Sort by " .. col.label:lower() .. ".") }
      end
      x = x + col.w
    end
    p.sortHead = W.SortHeader(header, cols, view, function() UI.Refresh("roster") end)
    p.sortHead:SetPoint("TOPLEFT", 0, -1)
    p.sortHead:SetPoint("TOPRIGHT", 0, -1)

    p.profile = ns.ProfilePage.New(p, function() Tab.CloseProfile() end)
    p.list = W.List(p, T.sizes.row, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 0, -52)
    p.list:SetPoint("BOTTOMRIGHT", 0, 0)

    p.empty = W.Text(p, "body", 12, "muted", "CENTER")
    p.empty:SetPoint("CENTER", p.list, "CENTER", 0, 20)
    p.empty:SetWordWrap(true)
    p.empty:SetWidth(360)

    ns:Listen("ROSTER_UPDATED", function() UI.Refresh("roster") end)
    ns:Listen("PEER_UPDATED", function() UI.Refresh("roster") end)
    ns:Listen("PROFILES_UPDATED", function() UI.Refresh("roster") end)
    p.browse = { search, online, addon, alts, p.counts, header, p.list, p.empty }
    Tab.panel = p
    return p
  end,
  refresh = function(p)
    if Tab.profileName then return end
    local items = Roster.View(view)
    p.list:SetItems(items)
    local inGuild = ns.Compat.Call(IsInGuild)
    p.empty:SetShown(#items == 0)
    p.empty:SetText(inGuild and "No one matches." or "You're not in a guild yet.\nJoin Land of Make Believe and your guildmates show up here.")
    p.counts:SetText(("%d online  ·  %d members  ·  %d with LOMB"):format(
      Roster.online or 0, #Roster.members, inGuild and Roster.PeerCount() + 1 or 0))
  end,
})

function Tab.OpenProfile(name)
  local p = Tab.panel
  if not p then
    UI.Open("roster")
    p = Tab.panel
    if not p then return end
  end
  Tab.profileName = name
  for _, f in ipairs(p.browse) do f:Hide() end
  p.profile:Show2(name)
end

function Tab.CloseProfile()
  local p = Tab.panel
  Tab.profileName = nil
  if not p then return end
  p.profile:Hide()
  for _, f in ipairs(p.browse) do f:Show() end
  UI.Refresh("roster")
end
