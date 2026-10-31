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

-- Drop-down: a label, then a button showing the current choice; clicking opens a small list.
-- choices = { { value = ..., text = ... }, ... }; get() -> value, set(value)
function W.Dropdown(parent, label, choices, get, set, tip, w)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(400, 22)
  f.text = W.Text(f, "body", 12, "text")
  f.text:SetPoint("LEFT", 0, 0)
  f.text:SetText(label)
  local function textOf(v)
    for _, c in ipairs(choices) do if c.value == v then return c.text end end
    return tostring(v)
  end
  local b = W.Button(f, "", w or 170, 20)
  b:SetPoint("LEFT", f.text, "RIGHT", 10, 0)
  b.label:ClearAllPoints()
  b.label:SetPoint("LEFT", 8, 0)
  b.label:SetJustifyH("LEFT")
  b.arrow = b:CreateTexture(nil, "ARTWORK")
  b.arrow:SetSize(10, 10)
  b.arrow:SetPoint("RIGHT", -6, 0)
  b.arrow:SetTexture(T.ARROW_DOWN)
  b.arrow:SetVertexColor(rgba("accent"))
  b.tip = tip
  f.button = b
  local menu = W.Panel(b, "panel2", "accent")
  menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
  menu:SetSize(w or 170, #choices * 20 + 4)
  menu:SetFrameStrata("DIALOG")
  menu:Hide()
  f.menu, f.items = menu, {}
  for i, c in ipairs(choices) do
    local it = W.Button(menu, c.text, (w or 170) - 4, 20, function()
      menu:Hide()
      local old = get()
      set(c.value)
      f:Refresh()
      if f.onChange and old ~= c.value then f.onChange(c.value) end
    end)
    it:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)
    it.label:ClearAllPoints()
    it.label:SetPoint("LEFT", 6, 0)
    it.label:SetJustifyH("LEFT")
    it.tip = c.tip or tip
    it.value = c.value
    f.items[i] = it
  end
  b:SetScript("OnClick", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end
    menu:SetShown(not menu:IsShown())
  end)
  f:SetScript("OnHide", function() menu:Hide() end)
  function f:Refresh()
    local v = get()
    b.label:SetText(textOf(v))
    for _, it in ipairs(f.items) do it:SetActive(it.value == v) end
  end
  f:Refresh()
  return f
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

function W.SearchBox(parent, w, placeholder, onChange, tip)
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
  box.tip = tip
  if placeholder ~= "" then
    W.Tooltip(box, function(tt, self)
      tt:SetText(self.hint:GetText() or placeholder or "Search", 1, 1, 1)
      tt:AddLine(self.tip or "Type to filter the list as you go. Esc clears it, Enter keeps it.", 0.8, 0.78, 0.85, true)
    end)
  end
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
-- A short string naming a view's filters (its plain values only), for list:SetItems's key.
function W.ViewKey(view, ...)
  local keys, out = {}, {}
  for k, v in pairs(view or {}) do
    local t = type(v)
    if t == "string" or t == "number" or t == "boolean" then keys[#keys + 1] = tostring(k) end
  end
  table.sort(keys)
  for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. tostring(view[k]) end
  for i = 1, select("#", ...) do out[#out + 1] = tostring((select(i, ...))) end
  return table.concat(out, "|")
end

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

  -- key: what the list is showing (filter, search ...). A new key starts at the top;
  -- the same key keeps the scroll position, so a refresh doesn't jump.
  function list:SetItems(items, key)
    self.items = items or {}
    if key ~= nil and key ~= self.viewKey then self.offset = 0 end
    if key ~= nil then self.viewKey = key end
    self:Refresh()
  end
  function list:ScrollToTop() self.offset = 0; self:Refresh() end

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

---------------------------------------------------------------------------
-- Sortable column headers.
--   W.SortHeader(parent, cols, view, onSort)
--   cols = { { key=, label=, x=, w=, justify=, desc=true (first click sorts high-to-low), tip= } }
--   view.sort / view.desc hold the current choice; clicking a column sorts by it,
--   clicking it again flips the direction.
---------------------------------------------------------------------------
function W.SortHeader(parent, cols, view, onSort)
  local head = CreateFrame("Frame", nil, parent)
  head:SetHeight(18)
  head.buttons = {}
  for _, col in ipairs(cols) do
    local b = CreateFrame("Button", nil, head)
    if col.right then b:SetPoint("RIGHT", -col.right, 0) else b:SetPoint("LEFT", col.x, 0) end
    b:SetSize(col.w, 18)
    b.text = W.Text(b, "narrow", 11, "gold", col.justify or "LEFT")
    b.text:SetPoint("LEFT", 0, 0)
    b.text:SetPoint("RIGHT", -12, 0)
    b.text:SetText(col.label)
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetTexture(ns.Theme.ARROW_DOWN)
    b.arrow:SetSize(8, 8)
    if (col.justify or "LEFT") == "LEFT" then
      b.arrow:SetPoint("LEFT", b.text, "LEFT", math.min((b.text:GetStringWidth() or 0) + 3, col.w - 10), 0)
    else
      b.arrow:SetPoint("RIGHT", b, "RIGHT", -1, 0)
    end
    b.arrow:SetVertexColor(rgba("gold"))
    b.col = col
    b:SetScript("OnClick", function()
      if view.sort == col.key then view.desc = not view.desc else view.sort, view.desc = col.key, col.desc and true or false end
      head:Refresh()
      if onSort then onSort(col.key, view.desc) end
    end)
    W.Tooltip(b, function(tt)
      tt:SetText(col.tipTitle or col.label, 1, 1, 1)
      tt:AddLine(col.tip or ("Click to sort by " .. col.label:lower() .. ", click again to flip the order."), 0.8, 0.78, 0.85, true)
    end)
    head.buttons[#head.buttons + 1] = b
  end
  function head:Refresh()
    for _, b in ipairs(self.buttons) do
      local on = view.sort == b.col.key
      b.arrow:SetShown(on)
      -- arrow-down.tga points down: high-to-low; flipped for low-to-high
      if view.desc then b.arrow:SetTexCoord(0, 1, 0, 1) else b.arrow:SetTexCoord(0, 1, 1, 0) end
      b.text:SetTextColor(rgba(on and "text" or "gold"))
    end
  end
  head:Refresh()
  return head
end

-- Sort rows by row[key] (or key(row) when it's a function). Missing values go
-- last either way; ties keep a stable order by `tie` (a field name).
function W.SortRows(rows, key, desc, tie)
  local get = type(key) == "function" and key or function(r) return r[key] end
  local cache = {}
  for i, r in ipairs(rows) do
    local v = get(r)
    if type(v) == "string" then v = v:lower() end
    cache[r] = { v = v, i = i, t = tie and tostring(r[tie] or ""):lower() or "" }
  end
  table.sort(rows, function(a, b)
    local x, y = cache[a], cache[b]
    if x.v ~= y.v then
      if x.v == nil then return false end
      if y.v == nil then return true end
      if type(x.v) ~= type(y.v) then return type(x.v) == "number" end
      if desc then return x.v > y.v end
      return x.v < y.v
    end
    if x.t ~= y.t then return x.t < y.t end
    return x.i < y.i
  end)
  return rows
end

---------------------------------------------------------------------------
-- Copy window: a small box with read-only text the player can select all of and
-- copy (Ctrl+A is done for them, then Ctrl+C). Used by /lomb test.
---------------------------------------------------------------------------
function W.CopyWindow(title, text, hint)
  local d = W.copyWin
  if not d then
    d = W.Panel(UIParent, "bg", "accent", "LOMBCompanionCopy")
    d:SetSize(520, 360)
    d:SetPoint("CENTER", 0, 40)
    d:SetFrameStrata("DIALOG")
    d:SetToplevel(true)
    d:EnableMouse(true)
    W.Movable(d, function() return nil end, function() end)
    d.title = W.Text(d, "title", 16, "gold")
    d.title:SetPoint("TOPLEFT", 12, -10)
    d.title:SetPoint("RIGHT", -40, 0)
    d.close = W.IconButton(d, "x", "Close (Esc)", function() d:Hide() end, 20)
    d.close:SetPoint("TOPRIGHT", -8, -8)
    d.hint = W.Text(d, "narrow", 11, "muted")
    d.hint:SetPoint("BOTTOMLEFT", 12, 10)
    d.hint:SetPoint("BOTTOMRIGHT", -110, 10)
    d.select = W.Button(d, "Select all", 90, 22, function() d.edit:SetFocus(); d.edit:HighlightText() end)
    d.select:SetPoint("BOTTOMRIGHT", -10, 6)
    d.select.tip = "Selects the whole report. Then press Ctrl+C to copy it."
    local box = W.Panel(d, "panel", "border")
    box:SetPoint("TOPLEFT", 10, -34)
    box:SetPoint("BOTTOMRIGHT", -10, 34)
    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(ns.Theme.fonts.narrow, 12, "")
    edit:SetTextColor(rgba("text"))
    edit:SetWidth(484)
    edit:SetScript("OnEscapePressed", function() d:Hide() end)
    -- read-only: typing puts the report back
    edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(d.text or ""); self:HighlightText() end end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local max = math.max(0, (edit:GetHeight() or 0) - (self:GetHeight() or 0))
      self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 36)))
    end)
    d.edit, d.scroll = edit, scroll
    if UISpecialFrames then table.insert(UISpecialFrames, "LOMBCompanionCopy") end
    W.copyWin = d
  end
  d.text = text or ""
  d.title:SetText(title or "")
  d.hint:SetText(hint or "Click Select all, then Ctrl+C to copy.")
  d.edit:SetText(d.text)
  d.scroll:SetVerticalScroll(0)
  d:Show()
  d.edit:SetFocus()
  d.edit:HighlightText()
  return d
end
