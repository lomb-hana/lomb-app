-- LOMB Companion: main window (title bar, sidebar navigation, content, sync footer).
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local UI = {}
ns.UI = UI

UI.tabs = {}        -- registered tab definitions, in order
UI.tabButtons = {}

-- tab = { id=, label=, order=, build(content) -> panel, refresh(panel), gap=bool (space above),
--         shown=function() -> bool (optional: the tab is only listed while this is true) }
function UI.RegisterTab(tab)
  UI.tabs[#UI.tabs + 1] = tab
  table.sort(UI.tabs, function(a, b) return a.order < b.order end)
end

-- What each tab is for, shown when you hover its sidebar entry (a tab can set .tip itself).
UI.TAB_TIPS = {
  roster = "Everyone in the guild: level, class, zone, notes. Click a name for their profile.",
  me = "Your character as guildmates see it, and what you share.",
  crafters = "Who in the guild can craft what. Search a recipe or item.",
  news = "What happened in the guild lately: level-ups, dungeons, epic loot, rares.",
  board = "Leaderboards for levels, kills, rares and time played.",
  bestiary = "Creatures the guild has met: where, level, abilities, loot.",
  quests = "Quests, items, vendors, recipes, loot and guides from the bundled ForeverDB.net data.",
  ask = "Ask a question in plain words. Answers come from the addon's own data.",
  events = "Guild events from the calendar, and who came.",
  wishlist = "What guildmates need or can give away.",
  bank = "What the guild bank character has.",
  settings = "What you share, tooltips, alerts, the card, and your data.",
  credits = "Who made LOMB Companion and where its data comes from.",
}

-- One sidebar entry: label, hover tint, accent bar + tint when active, optional badge.
function UI.NavButton(parent, tab)
  local S = T.sizes
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(S.nav.h)
  b.bg = W.Fill(b, "accentDim", "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:Hide()
  b.hover = W.Fill(b, "rowHover", "BACKGROUND")
  b.hover:SetAllPoints()
  b.hover:Hide()
  b.bar = W.Fill(b, "accent", "ARTWORK")
  b.bar:SetWidth(3)
  b.bar:SetPoint("TOPLEFT", 0, 0)
  b.bar:SetPoint("BOTTOMLEFT", 0, 0)
  b.bar:Hide()
  b.label = W.Text(b, "body", 11, "muted", "LEFT")
  b.label:SetPoint("LEFT", 14, 0)
  if T.IsStorybook() and T.TAB_ICON_IDS[tab.id] then   -- storybook look: a little drawn icon before the label
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(T.TabIcon(tab.id))
    b.icon:SetSize(14, 14)
    b.icon:SetPoint("LEFT", 10, 0)
    b.icon:SetVertexColor(W.rgba("muted"))
    b.label:SetPoint("LEFT", 29, 0)
  end
  b.label:SetText(tab.label)
  b.badge = W.Text(b, "narrow", 10, "accent", "RIGHT")
  b.badge:SetPoint("RIGHT", -8, 0)
  b.tip = tab.tip or UI.TAB_TIPS[tab.id]
  b:SetScript("OnEnter", function(self)
    if not self.active then self.hover:Show() end
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tab.label, 1, 1, 1)
      GameTooltip:AddLine(self.tip, 0.8, 0.78, 0.85, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
  b:SetScript("OnClick", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
    UI.Select(tab.id)
  end)
  function b:SetActive(on)
    self.active = on
    self.bg:SetShown(on)
    self.bar:SetShown(on)
    if on then self.hover:Hide() end
    self.label:SetTextColor(W.rgba(on and "text" or "muted"))
    if self.icon then self.icon:SetVertexColor(W.rgba(on and "accent" or "muted")) end
  end
  function b:SetBadge(text) self.badge:SetText(text or "") end
  return b
end

function UI.TabVisible(tab)
  if not tab.shown then return true end
  local ok, on = pcall(tab.shown)
  return ok and on and true or false
end

-- Place the sidebar entries, skipping tabs that are hidden right now.
function UI.LayoutNav()
  if not UI.nav then return end
  local S = T.sizes
  local y = -8
  for _, tab in ipairs(UI.tabs) do
    local b = UI.tabButtons[tab.id]
    if UI.TabVisible(tab) then
      if tab.gap then y = y - 8 end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 1, y)
      b:SetPoint("TOPRIGHT", -1, y)
      b:Show()
      y = y - S.nav.h - 2
    else
      b:Hide()
    end
  end
  -- the open tab just disappeared: fall back to the first one
  if UI.frame and UI.frame:IsShown() and UI.current then
    for _, tab in ipairs(UI.tabs) do
      if tab.id == UI.current and not UI.TabVisible(tab) then UI.Select(UI.tabs[1].id) end
    end
  end
end

-- Small count next to a sidebar entry ("3" new news items, etc.).
function UI.SetBadge(id, text)
  local b = UI.tabButtons[id]
  if b then b:SetBadge(text) end
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
  UI.MakeResizable(f)

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

  -- sidebar navigation
  local nav = W.Panel(f, "panel", "border")
  nav:SetPoint("TOPLEFT", 0, -(S.titleBar - 1))
  nav:SetPoint("BOTTOMLEFT", 0, S.footer - 1)
  nav:SetWidth(S.nav.w)
  UI.nav = nav
  for i, tab in ipairs(UI.tabs) do
    UI.tabButtons[tab.id] = UI.NavButton(nav, tab)
    tab.index = i
  end
  UI.LayoutNav()

  -- content
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", S.nav.w + S.pad, -(S.titleBar + S.pad))
  content:SetPoint("BOTTOMRIGHT", -S.pad, S.footer + 6)
  UI.content = content

  -- footer
  local footer = W.Panel(f, "panel", "border")
  footer:SetPoint("BOTTOMLEFT", 0, 0)
  footer:SetPoint("BOTTOMRIGHT", 0, 0)
  footer:SetHeight(S.footer)
  UI.footerText = W.Text(footer, "narrow", 11, "muted")
  UI.footerText:SetPoint("LEFT", 10, 0)
  UI.grip = UI.ResizeGrip(footer, f)
  UI.grip:SetPoint("BOTTOMRIGHT", -1, 1)
  UI.footerRight = W.Text(footer, "narrow", 11, "muted", "RIGHT")
  UI.footerRight:SetPoint("RIGHT", UI.grip, "LEFT", -6, 0)
  UI.footerRight:SetText("/lomb")
  -- a long sync status stops at "/lomb" with an ellipsis instead of running under it
  UI.footerText:SetPoint("RIGHT", UI.footerRight, "LEFT", -12, 0)
  UI.footerText:SetJustifyH("LEFT")
  UI.footerText:SetWordWrap(false)

  if T.IsStorybook() then UI.Storybook(f, bar, title, sub, nav) end

  f:SetScript("OnShow", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPEN) end
    ns.Roster.Request()
    UI.Select(UI.current or ns.db.settings.lastTab or "roster")
    UI.UpdateFooter()
    if ns.Tour then ns.After(0, function() ns.SafeCall(ns.Tour.MaybeStart) end) end
  end)
  f:SetScript("OnHide", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE) end
    if ns.Tour and ns.Tour.IsShown() then ns.Tour.Stop() end   -- ESC mid-tour counts as seen
  end)
  UI.frame = f
  ns.Every(2, function() if f:IsShown() then UI.UpdateFooter() end end)
  return f
end

-- The storybook look's extras, drawn over the clean frame: stars in the night sky behind
-- everything, a parchment title bar written in ink, gold flourishes in the corners and a
-- moon divider at the foot of the sidebar. All art is our own (tools/make_storybook.py).
local function tiled(parent, file, layer, sub, alpha)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(file, "REPEAT", "REPEAT")
  if t.SetHorizTile then t:SetHorizTile(true); t:SetVertTile(true) end
  t:SetAlpha(alpha or 1)
  return t
end

function UI.Storybook(f, bar, title, sub, nav)
  local S = T.STORY
  local sky = tiled(f, S.stars, "BACKGROUND", 2, 0.35)
  sky:SetPoint("TOPLEFT", 1, -1)
  sky:SetPoint("BOTTOMRIGHT", -1, 1)
  local navSky = tiled(nav, S.stars, "BACKGROUND", 2, 0.22)
  navSky:SetPoint("TOPLEFT", 1, -1)
  navSky:SetPoint("BOTTOMRIGHT", -1, 1)

  local paper = tiled(bar, S.parchment, "BORDER", 0, 1)
  paper:SetPoint("TOPLEFT", 1, -1)
  paper:SetPoint("BOTTOMRIGHT", -1, 2)
  if paper.SetHorizTile then paper:SetVertTile(false) end
  title:SetTextColor(unpack(T.ink))
  sub:SetTextColor(unpack(T.inkSoft))

  -- flourishes: the two ends of the title bar (ink), the bottom corners of the window (gold)
  local function curl(parent, point, x, y, size, flipX, flipY, color, layer)
    local c = parent:CreateTexture(nil, layer or "OVERLAY")
    c:SetTexture(S.flourish)
    c:SetSize(size, size)
    c:SetPoint(point, x, y)
    local l, r, t, b = 0, 1, 0, 1
    if flipX then l, r = 1, 0 end
    if flipY then t, b = 1, 0 end
    c:SetTexCoord(l, r, t, b)
    c:SetVertexColor(unpack(color))
    return c
  end
  local gold = T.colors.accent
  UI.flourishes = {
    curl(bar, "TOPRIGHT", -34, -3, 26, true, false, T.inkSoft, "ARTWORK"),
    curl(f, "BOTTOMLEFT", 2, T.sizes.footer + 1, 30, false, true, gold),
    curl(f, "BOTTOMRIGHT", -2, T.sizes.footer + 1, 30, true, true, gold),
  }
  local div = nav:CreateTexture(nil, "ARTWORK")
  div:SetTexture(S.divider)
  div:SetSize(100, 8)
  div:SetPoint("BOTTOM", 0, 40)   -- above the gold corner flourish
  div:SetVertexColor(gold[1], gold[2], gold[3], 0.8)
  UI.storyDivider = div
end

-- Resizing: never smaller than the original 780x480 (every tab is laid out for at least
-- that), up to a size that still fits small screens. The size is saved like the position.
UI.MIN_W, UI.MIN_H, UI.MAX_W, UI.MAX_H = 780, 480, 1280, 860

local function clampSize(w, h)
  w = math.max(UI.MIN_W, math.min(UI.MAX_W, math.floor((tonumber(w) or UI.MIN_W) + 0.5)))
  h = math.max(UI.MIN_H, math.min(UI.MAX_H, math.floor((tonumber(h) or UI.MIN_H) + 0.5)))
  return w, h
end
UI.ClampSize = clampSize

function UI.MakeResizable(f)
  if f.SetResizable then f:SetResizable(true) end
  if f.SetResizeBounds then
    f:SetResizeBounds(UI.MIN_W, UI.MIN_H, UI.MAX_W, UI.MAX_H)
  else
    if f.SetMinResize then f:SetMinResize(UI.MIN_W, UI.MIN_H) end
    if f.SetMaxResize then f:SetMaxResize(UI.MAX_W, UI.MAX_H) end
  end
  local s = ns.db.settings.windowSize
  if type(s) == "table" then f:SetSize(clampSize(s[1], s[2])) end
end

function UI.SaveSize()
  local f = UI.frame
  if not f then return end
  local w, h = clampSize(f:GetWidth(), f:GetHeight())
  f:SetSize(w, h)
  local default = w == T.sizes.window.w and h == T.sizes.window.h
  ns.db.settings.windowSize = (not default) and { w, h } or nil
  local point, _, relPoint, x, y = f:GetPoint()
  if point and tonumber(x) and tonumber(y) then
    ns.db.settings.windowPoint = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
  end
end

function UI.ResetSize()
  ns.db.settings.windowSize = nil
  if UI.frame then UI.frame:SetSize(T.sizes.window.w, T.sizes.window.h) end
end

-- The corner grip: drag to resize, right-click to go back to the default size.
function UI.ResizeGrip(parent, f)
  local g = CreateFrame("Button", nil, parent)
  g:SetSize(16, 16)
  g:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
  g.lines = {}
  for i = 1, 3 do                       -- three short diagonal strokes, drawn, no texture file
    local l = g:CreateTexture(nil, "OVERLAY")
    l:SetColorTexture(W.rgba("muted"))
    l:SetSize(2 + i * 3, 1)
    l:SetPoint("BOTTOMRIGHT", -2, 2 + (i - 1) * 4)
    g.lines[i] = l
  end
  g:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  g:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and f.StartSizing then f:StartSizing("BOTTOMRIGHT") end
  end)
  g:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    UI.SaveSize()
  end)
  g:SetScript("OnClick", function(_, button) if button == "RightButton" then UI.ResetSize() end end)
  g:SetScript("OnEnter", function(self)
    for _, l in ipairs(self.lines) do l:SetColorTexture(W.rgba("accent")) end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Resize", 1, 1, 1)
    GameTooltip:AddLine("Drag to resize the window. Right-click to go back to the default size.", 0.8, 0.78, 0.85, true)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function(self)
    for _, l in ipairs(self.lines) do l:SetColorTexture(W.rgba("muted")) end
    GameTooltip:Hide()
  end)
  return g
end

function UI.UpdateFooter()
  if UI.footerText and ns.Sync then UI.footerText:SetText(ns.Sync.Status()) end
end

function UI.Select(id)
  UI.Create()
  local found
  for _, tab in ipairs(UI.tabs) do
    if tab.id == id and UI.TabVisible(tab) then found = tab end
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
