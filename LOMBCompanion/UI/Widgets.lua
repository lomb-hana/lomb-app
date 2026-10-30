-- LOMB Companion: small custom widget kit (no libraries, no Blizzard templates
-- except BackdropTemplate for the 1px borders).
local _, ns = ...
local T = ns.Theme
local W = {}
ns.Widgets = W

local function rgba(key) local c = T.colors[key] or key; return c[1], c[2], c[3], c[4] or 1 end
W.rgba = rgba

local BACKDROP = { bgFile = T.WHITE, edgeFile = T.WHITE, edgeSize = 1 }

function W.Skin(frame, bg, border)
  if not frame.SetBackdrop and _G.Mixin and _G.BackdropTemplateMixin then
    _G.Mixin(frame, _G.BackdropTemplateMixin)
  end
  if frame.SetBackdrop then
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(rgba(bg or "panel"))
    frame:SetBackdropBorderColor(rgba(border or "border"))
  end
  return frame
end

function W.Panel(parent, bg, border, name)
  local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
  return W.Skin(f, bg, border)
end

function W.Text(parent, font, size, color, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFont(T.fonts[font or "body"], size or 12, "")
  fs:SetTextColor(rgba(color or "text"))
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

function W.Fill(parent, color, layer)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetColorTexture(rgba(color))
  return t
end

-- Tooltip helper (uses GameTooltip so it works with other addons' tooltip skins)
function W.Tooltip(frame, fn)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    fn(GameTooltip, self)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Flat button with hover highlight.
function W.Button(parent, text, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w or 100, h or 24)
  W.Skin(b, "panel2", "border")
  b.label = W.Text(b, "body", 11, "text", "CENTER")
  b.label:SetPoint("CENTER")
  b.label:SetText(text)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(rgba("accent"))
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    if not self.active then self:SetBackdropBorderColor(rgba("border")) end
    GameTooltip:Hide()
  end)
  b:SetScript("OnClick", function(self, button)
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
    if onClick then onClick(self, button) end
  end)
  function b:SetActive(on)
    self.active = on
    self:SetBackdropColor(rgba(on and "accentDim" or "panel2"))
    self:SetBackdropBorderColor(rgba(on and "accent" or "border"))
    self.label:SetTextColor(rgba(on and "text" or "muted"))
  end
  return b
end

-- Small square glyph button (pin, expand, close).
function W.IconButton(parent, glyph, tip, onClick, size)
  local b = W.Button(parent, glyph, size or 18, size or 18, onClick)
  b.label:SetFont(T.fonts.body, 11, "")
  b.tip = tip
  return b
end

-- Custom checkbox: square + label. get() -> bool, set(bool)
function W.Check(parent, label, get, set, tip)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(260, 20)
  b.box = W.Panel(b, "panel2", "border")
  b.box:SetSize(14, 14)
  b.box:SetPoint("LEFT", 0, 0)
  b.mark = W.Fill(b.box, "accent", "ARTWORK")
  b.mark:SetPoint("TOPLEFT", 3, -3)
  b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
  b.text = W.Text(b, "body", 12, "text")
  b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
  b.text:SetText(label)
  function b:Refresh() self.mark:SetShown(get() and true or false) end
  b:SetScript("OnClick", function(self)
    set(not get())
    self:Refresh()
  end)
  if tip then
    W.Tooltip(b, function(tt) tt:SetText(label, 1, 1, 1); tt:AddLine(tip, 0.8, 0.78, 0.85, true) end)
  end
  b:Refresh()
  return b
end

function W.SearchBox(parent, w, placeholder, onChange)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  W.Skin(box, "panel2", "border")
  box:SetSize(w, 22)
  box:SetAutoFocus(false)
  box:SetFont(T.fonts.body, 11, "")
  box:SetTextColor(rgba("text"))
  box:SetTextInsets(8, 8, 0, 0)
  box.hint = W.Text(box, "body", 11, "muted")
  box.hint:SetPoint("LEFT", 8, 0)
  box.hint:SetText(placeholder or "Search...")
  box:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    self.hint:SetShown(text == "")
    if onChange then onChange(text) end
  end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(rgba("accent")) end)
  box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(rgba("border")) end)
  return box
end

-- Read-only text the player can select and copy (Ctrl+C), e.g. a web link.
-- Addons can't open a browser, so links are shown as copyable text.
function W.CopyBox(parent, w, text)
  local box = W.SearchBox(parent, w, "", nil)
  box.copyText = text or ""
  box.hint:Hide()
  box:SetText(box.copyText)
  box:SetCursorPosition(0)
  box:SetScript("OnTextChanged", function(self, user)
    if user and self:GetText() ~= self.copyText then self:SetText(self.copyText); self:HighlightText() end
  end)
  box:SetScript("OnEditFocusGained", function(self)
    self:SetBackdropBorderColor(rgba("accent"))
    self:HighlightText()
  end)
  box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
  function box:SetCopyText(t) self.copyText = t or ""; self:SetText(self.copyText); self:SetCursorPosition(0) end
  W.Tooltip(box, function(tt)
    tt:SetText(box.copyText, 1, 1, 1)
    tt:AddLine("Click, then Ctrl+C to copy.", 0.8, 0.78, 0.85)
  end)
  return box
end

-- Source tag: tiny coloured pill saying where a fact came from.
function W.SourceTag(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(40, 12)
  f.bg = W.Fill(f, { 1, 1, 1, 0.08 }, "BACKGROUND")
  f.bg:SetAllPoints()
  f.text = W.Text(f, "narrow", 9, "muted", "CENTER")
  f.text:SetPoint("CENTER", 0, 0)
  function f:SetSource(src)
    if not src then self:Hide(); return end
    local c = T.sourceColors[src] or T.colors.muted
    self.text:SetText((ns.Providers.SOURCE_LABEL[src] or src):upper())
    self.text:SetTextColor(c[1], c[2], c[3], 1)
    self.bg:SetColorTexture(c[1], c[2], c[3], 0.16)
    self:SetWidth(math.max(28, (self.text:GetStringWidth() or 30) + 8))
    W.Tooltip(self, function(tt)
      local what = src == "game" and "Read from the game client just now."
        or src == "guild" and "Recorded by LOMB members with this addon."
        or src == "foreverdb" and "Data from ForeverDB.net"
        or src
      tt:SetText("Source: " .. (ns.Providers.SOURCE_LABEL[src] or src), c[1], c[2], c[3])
      tt:AddLine(what, 0.85, 0.83, 0.9, true)
    end)
    self:Show()
  end
  return f
end

function W.Bar(parent, w, h, color, bg)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(w, h)
  bar:SetStatusBarTexture(T.WHITE)
  bar:SetStatusBarColor(rgba(color or "accent"))
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar.bg = W.Fill(bar, bg or "panel2", "BACKGROUND")
  bar.bg:SetAllPoints()
  bar.text = W.Text(bar, "narrow", 10, "text", "CENTER")
  bar.text:SetPoint("CENTER")
  return bar
end

function W.Divider(parent, alpha)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(T.colors.border[1], T.colors.border[2], T.colors.border[3], alpha or 1)
  t:SetHeight(1)
  return t
end

function W.SectionTitle(parent, text)
  local fs = W.Text(parent, "title", 14, "gold")
  fs:SetText(text)
  return fs
end

---------------------------------------------------------------------------
-- Virtual list: fixed row pool, mouse wheel + slim scrollbar.
--   list = W.List(parent, rowHeight, createRow(list, i), updateRow(row, item, index))
--   list:SetItems(items)
---------------------------------------------------------------------------
function W.List(parent, rowHeight, createRow, updateRow)
  local list = CreateFrame("Frame", nil, parent)
  list.rows, list.items, list.offset, list.rowHeight = {}, {}, 0, rowHeight
  list.track = W.Fill(list, { 1, 1, 1, 0.04 }, "BORDER")
  list.track:SetWidth(3)
  list.track:SetPoint("TOPRIGHT", 0, 0)
  list.track:SetPoint("BOTTOMRIGHT", 0, 0)
  list.thumb = W.Fill(list, "accent", "ARTWORK")
  list.thumb:SetWidth(3)

  function list:Visible() return math.max(1, math.floor((self:GetHeight() or 0) / self.rowHeight)) end

  function list:Layout()
    local n = self:Visible()
    for i = #self.rows + 1, n do
      local row = createRow(self, i)
      row:SetHeight(self.rowHeight)
      row:SetPoint("TOPLEFT", 0, -(i - 1) * self.rowHeight)
      row:SetPoint("RIGHT", -6, 0)
      self.rows[i] = row
    end
    self:Refresh()
  end

  function list:Refresh()
    local n = self:Visible()
    local maxOff = math.max(0, #self.items - n)
    if self.offset > maxOff then self.offset = maxOff end
    for i, row in ipairs(self.rows) do
      local idx = self.offset + i
      local item = (i <= n) and self.items[idx] or nil
      if item then
        row.item, row.index = item, idx
        updateRow(row, item, idx)
        row:Show()
      else
        row.item = nil
        row:Hide()
      end
    end
    local h = self:GetHeight() or 0
    if #self.items > n and h > 0 then
      local th = math.max(16, h * n / #self.items)
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", 0, -((h - th) * self.offset / maxOff))
      self.thumb:Show(); self.track:Show()
    else
      self.thumb:Hide(); self.track:Hide()
    end
  end

  function list:SetItems(items)
    self.items = items or {}
    self:Refresh()
  end

  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta)
    self.offset = math.max(0, self.offset - delta * 3)
    self:Refresh()
  end)
  list:SetScript("OnSizeChanged", function(self) self:Layout() end)
  return list
end

---------------------------------------------------------------------------
-- Confirm dialog (custom, not StaticPopup, so it matches the LOMB look)
---------------------------------------------------------------------------
function W.Confirm(text, onYes)
  local d = W.confirm
  if not d then
    d = W.Panel(UIParent, "bg", "accent", "LOMBCompanionConfirm")
    d:SetSize(320, 120)
    d:SetPoint("CENTER", 0, 120)
    d:SetFrameStrata("DIALOG")
    d:EnableMouse(true)
    d.text = W.Text(d, "body", 12, "text", "CENTER")
    d.text:SetPoint("TOPLEFT", 16, -18)
    d.text:SetPoint("TOPRIGHT", -16, -18)
    d.text:SetWordWrap(true)
    d.yes = W.Button(d, "Yes", 100, 24, function() d:Hide(); if d.onYes then d.onYes() end end)
    d.yes:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 14)
    d.no = W.Button(d, "Cancel", 100, 24, function() d:Hide() end)
    d.no:SetPoint("BOTTOMLEFT", d, "BOTTOM", 6, 14)
    if UISpecialFrames then table.insert(UISpecialFrames, "LOMBCompanionConfirm") end
    W.confirm = d
  end
  d.text:SetText(text)
  d.onYes = onYes
  d:Show()
end

-- Make a frame draggable and remember where it was left.
function W.Movable(frame, getPoint, setPoint, isLocked)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if isLocked and isLocked() then return end
    self:StartMoving()
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    setPoint({ point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) })
  end)
  local p = getPoint()
  if p then
    frame:ClearAllPoints()
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
end

function W.FormatMoney(copper)
  if not copper then return "-" end
  local g = math.floor(copper / 10000)
  local s = math.floor(copper / 100) % 100
  local c = copper % 100
  if g > 0 then return ("%s|cffffd100g|r %d|cffc7c7cfs|r"):format(W.Thousands(g), s) end
  if s > 0 then return ("%d|cffc7c7cfs|r %d|cffeda55fc|r"):format(s, c) end
  return ("%d|cffeda55fc|r"):format(c)
end

function W.Thousands(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

function W.FormatDuration(seconds)
  if not seconds then return "-" end
  local d = math.floor(seconds / 86400)
  local h = math.floor(seconds / 3600) % 24
  local m = math.floor(seconds / 60) % 60
  if d > 0 then return ("%dd %dh"):format(d, h) end
  if h > 0 then return ("%dh %dm"):format(h, m) end
  return ("%dm"):format(m)
end

function W.ItemText(itemID)
  local name, _, quality = ns.Compat.ItemInfo(itemID)
  if not name then return ("item:%d"):format(itemID) end
  local c = _G.ITEM_QUALITY_COLORS and quality and _G.ITEM_QUALITY_COLORS[quality]
  if c and c.hex then return c.hex .. name .. "|r" end
  return name
end
