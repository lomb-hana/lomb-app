-- LOMB Companion: main window (title bar, tab strip, content, sync footer).
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local UI = {}
ns.UI = UI

UI.tabs = {}        -- registered tab definitions, in order
UI.tabButtons = {}

-- tab = { id=, label=, order=, build(content) -> panel, refresh(panel) }
function UI.RegisterTab(tab)
  UI.tabs[#UI.tabs + 1] = tab
  table.sort(UI.tabs, function(a, b) return a.order < b.order end)
end

function UI.Create()
  if UI.frame then return UI.frame end
  local S = T.sizes
  local f = W.Panel(UIParent, "bg", "border", "LOMBCompanionFrame")
  f:SetSize(S.window.w, S.window.h)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:Hide()
  table.insert(UISpecialFrames, "LOMBCompanionFrame")   -- Esc closes it
  W.Movable(f,
    function() return ns.db.settings.windowPoint end,
    function(p) ns.db.settings.windowPoint = p end)

  -- title bar
  local bar = W.Panel(f, "panel", "border")
  bar:SetPoint("TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", 0, 0)
  bar:SetHeight(S.titleBar)
  bar:EnableMouse(false)
  local accent = W.Fill(bar, "accent", "ARTWORK")
  accent:SetHeight(2)
  accent:SetPoint("BOTTOMLEFT", 1, 0)
  accent:SetPoint("BOTTOMRIGHT", -1, 0)

  local logo = bar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(T.LOGO)
  logo:SetSize(24, 24)
  logo:SetPoint("LEFT", 8, 0)

  local title = W.Text(bar, "title", 18, "accent")
  title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  title:SetText("LOMB Companion")
  local sub = W.Text(bar, "narrow", 11, "muted")
  sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
  sub:SetText("Land of Make Believe  ·  v" .. ns.version)

  local close = W.IconButton(bar, "x", "Close", function() f:Hide() end, 22)
  close.label:SetFont(T.fonts.body, 16, "")
  close:SetPoint("RIGHT", -6, 0)

  -- tabs
  local x = S.pad
  for i, tab in ipairs(UI.tabs) do
    local b = W.Button(f, tab.label, S.tab.w, S.tab.h, function() UI.Select(tab.id) end)
    b:SetPoint("TOPLEFT", x, -(S.titleBar + 6))
    x = x + S.tab.w + 4
    UI.tabButtons[tab.id] = b
    tab.index = i
  end

  -- content
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", S.pad, -(S.titleBar + S.tab.h + 14))
  content:SetPoint("BOTTOMRIGHT", -S.pad, S.footer + 6)
  UI.content = content

  -- footer
  local footer = W.Panel(f, "panel", "border")
  footer:SetPoint("BOTTOMLEFT", 0, 0)
  footer:SetPoint("BOTTOMRIGHT", 0, 0)
  footer:SetHeight(S.footer)
  UI.footerText = W.Text(footer, "narrow", 11, "muted")
  UI.footerText:SetPoint("LEFT", 10, 0)
  UI.footerRight = W.Text(footer, "narrow", 11, "muted", "RIGHT")
  UI.footerRight:SetPoint("RIGHT", -10, 0)
  UI.footerRight:SetText("/lomb")

  f:SetScript("OnShow", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPEN) end
    ns.Roster.Request()
    UI.Select(UI.current or ns.db.settings.lastTab or "roster")
    UI.UpdateFooter()
  end)
  f:SetScript("OnHide", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE) end
  end)
  UI.frame = f
  ns.Every(2, function() if f:IsShown() then UI.UpdateFooter() end end)
  return f
end

function UI.UpdateFooter()
  if UI.footerText and ns.Sync then UI.footerText:SetText(ns.Sync.Status()) end
end

function UI.Select(id)
  UI.Create()
  local found
  for _, tab in ipairs(UI.tabs) do
    if tab.id == id then found = tab end
  end
  found = found or UI.tabs[1]
  for _, tab in ipairs(UI.tabs) do
    local on = tab == found
    UI.tabButtons[tab.id]:SetActive(on)
    if on and not tab.panel then
      tab.panel = tab.build(UI.content)
      tab.panel:SetAllPoints(UI.content)
    end
    if tab.panel then tab.panel:SetShown(on) end
  end
  UI.current = found.id
  ns.db.settings.lastTab = found.id
  if found.refresh then ns.SafeCall(found.refresh, found.panel) end
end

function UI.Refresh(id)
  if not UI.frame or not UI.frame:IsShown() or UI.current ~= id then return end
  for _, tab in ipairs(UI.tabs) do
    if tab.id == id and tab.panel and tab.refresh then ns.SafeCall(tab.refresh, tab.panel) end
  end
end

function UI.Toggle(id)
  local f = UI.Create()
  if f:IsShown() and (not id or id == UI.current) then
    f:Hide()
  else
    if id then UI.current = id end
    f:Show()
    if id then UI.Select(id) end
  end
end

function UI.Open(id)
  local f = UI.Create()
  if id then UI.current = id end
  if not f:IsShown() then f:Show() elseif id then UI.Select(id) end
end
