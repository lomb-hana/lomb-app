-- LOMB Companion: Wishlist tab -- what guildmates need and what they can give away.
local _, ns = ...
local C = ns.Compat
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local Tab = {}
ns.WishTab = Tab

Tab.view = { filter = "all", addKind = "n", wishSearch = "" }
local view = Tab.view

local function WL() return ns.Wishlist end
local function ago(t) return t and ns.News.Ago(t) or "never" end

local function classText(owner)
  local row = ns.Roster and ns.Roster.byName[owner]
  local short = C.ShortName(owner)
  if row and row.class then return T.classColorText(row.class, short) end
  return short
end
Tab.ClassText = classText

local function itemIcon(id)
  local _, _, _, icon = C.ItemInfo(id)
  return icon or 134400
end

---------------------------------------------------------------------------
-- wishlist
---------------------------------------------------------------------------
local HINT = "Click a guildmate's row to start a whisper (you press Enter)  ·  shift-click an item into the box"
local FILTERS = { { "all", "All" }, { "need", "Needs" }, { "give", "Offers" }, { "mine", "Mine" } }

function Tab.Click(row)
  if not row then return false end
  -- shift-click: link in chat, ctrl-click: preview (the same as every item row)
  if row.id and ns.ItemClick.Modified(row.id) then return true end
  -- your own entries: click opens the item's page
  if row.mine then return row.id and ns.ItemClick.Open(row.id) or false end
  if ChatFrame_OpenChat then ChatFrame_OpenChat(WL().WhisperText(row)) end
  return true
end

function Tab.RemoveRow(row)
  if row and row.mine then WL().Remove(row.entry) end
  UI.Refresh("wishlist")
end

function Tab.Add()
  local p = Tab.panel
  local e, err = WL().Add(view.addKind, p.itemBox:GetText(), p.qtyBox:GetText(), p.noteBox:GetText())
  if e then
    p.itemBox:SetText(""); p.qtyBox:SetText(""); p.noteBox:SetText("")
    p.msg:SetText(HINT)
  else
    p.msg:SetText("|cffe65959" .. (err or "Couldn't add that.") .. "|r")
  end
  UI.Refresh("wishlist")
  return e
end

local function createWishRow(list, i)
  local row = CreateFrame("Button", nil, list)
  row.bg = W.Fill(row, i % 2 == 0 and "row" or { 0, 0, 0, 0 }, "BACKGROUND")
  row.bg:SetAllPoints()
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.kind = W.Text(row, "narrow", 10, "accent", "CENTER")
  row.kind:SetPoint("LEFT", 4, 0)
  row.kind:SetWidth(36)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", 44, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = W.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", 66, 0)
  row.name:SetWidth(190)
  row.who = W.Text(row, "body", 12, "text")
  row.who:SetPoint("LEFT", 262, 0)
  row.who:SetWidth(100)
  row.note = W.Text(row, "narrow", 11, "muted")
  row.note:SetPoint("LEFT", 366, 0)
  row.note:SetPoint("RIGHT", -86, 0)
  row.when = W.Text(row, "narrow", 10, "muted", "RIGHT")
  row.when:SetPoint("RIGHT", -28, 0)
  row.when:SetWidth(56)
  row.del = W.IconButton(row, "x", "Remove from my list", function(self) Tab.RemoveRow(self:GetParent().item) end, 16)
  row.del:SetPoint("RIGHT", -6, 0)
  row:SetScript("OnClick", function(self) Tab.Click(self.item) end)
  W.Tooltip(row, function(tt, self)
    local r = self.item
    if not r then return end
    if r.id and tt.SetItemByID then tt:SetItemByID(r.id) else tt:SetText(r.label, 1, 1, 1) end
    tt:AddLine(" ")
    tt:AddLine(("%s %s %d"):format(C.ShortName(r.owner), r.kind == "n" and "needs" or "can give away", r.q), 1, 1, 1)
    if r.note then tt:AddLine(r.note, 0.8, 0.78, 0.85, true) end
    if not r.mine then
      tt:AddLine("Click: whisper them (you press Enter)   " .. (r.id and "Shift-click: link in chat" or ""), 0.72, 0.45, 1.0)
    elseif r.id then
      ns.ItemClick.AddHint(tt, true)
    end
  end)
  return row
end

local function updateWishRow(row, r)
  row.kind:SetText(r.kind == "n" and "|cffb873ffNEED|r" or "|cff7fe07fGIVE|r")
  if r.id then row.icon:SetTexture(itemIcon(r.id)); row.icon:Show() else row.icon:Hide() end
  local label = r.id and C.ItemInfo(r.id) and W.ItemText(r.id) or r.label
  row.name:SetText(label .. (r.q > 1 and ("  |cff9991a8x%d|r"):format(r.q) or ""))
  local who = classText(r.owner)
  if r.mine then who = "|cff9991a8you|r" elseif not r.online then who = who .. " |cff9991a8(off)|r" end
  row.who:SetText(who)
  row.note:SetText(r.note or "")
  row.when:SetText(ago(r.t))
  row.del:SetShown(r.mine)
end

function Tab.SetFilter(f)
  view.filter = f
  UI.Refresh("wishlist")
end
function Tab.ToggleKind()
  view.addKind = view.addKind == "n" and "g" or "n"
  UI.Refresh("wishlist")
end

-- shift-clicking an item while the item box has focus puts the link in it
function Tab.HookLinks()
  if Tab.hooked or not hooksecurefunc or not _G.ChatEdit_InsertLink then return end
  Tab.hooked = true
  hooksecurefunc("ChatEdit_InsertLink", function(link)
    local p = Tab.panel
    if p and p.itemBox and p.itemBox:HasFocus() and type(link) == "string" and C.ItemIdFromLink(link) then
      p.itemBox:SetText(link)
    end
  end)
end

UI.RegisterTab({
  id = "wishlist", label = "Wishlist", order = 68,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    p.filters = {}
    local prev
    for _, f in ipairs(FILTERS) do
      local b = W.Button(p, f[2], 70, 20, function() Tab.SetFilter(f[1]) end)
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 0, 0) end
      p.filters[f[1]] = b
      prev = b
    end
    p.wishSearch = W.SearchBox(p, 200, "Search items, notes, names", function(text)
      view.wishSearch = text
      UI.Refresh("wishlist")
    end)
    p.wishSearch:SetPoint("TOPRIGHT", 0, 0)
    local wl = W.Panel(p, "panel", "border")
    wl:SetPoint("TOPLEFT", 0, -26)
    wl:SetPoint("BOTTOMRIGHT", 0, 64)
    p.wishList = W.List(wl, 22, createWishRow, updateWishRow)
    p.wishList:SetPoint("TOPLEFT", 4, -4)
    p.wishList:SetPoint("BOTTOMRIGHT", -4, 4)
    p.wishEmpty = W.Text(wl, "body", 12, "muted", "CENTER")
    p.wishEmpty:SetPoint("TOP", 0, -70)
    p.wishEmpty:SetWidth(420)
    p.wishEmpty:SetWordWrap(true)

    local add = W.Panel(p, "panel", "border")
    add:SetPoint("BOTTOMLEFT", 0, 0)
    add:SetPoint("BOTTOMRIGHT", 0, 0)
    add:SetHeight(56)
    p.kindBtn = W.Button(add, "I need", 84, 22, Tab.ToggleKind)
    p.kindBtn:SetPoint("TOPLEFT", 8, -8)
    p.kindBtn.tip = "Click to switch between \"I need\" and \"I can give\"."
    p.itemBox = W.SearchBox(add, 190, "Item (type or shift-click)")
    p.itemBox:SetPoint("LEFT", p.kindBtn, "RIGHT", 6, 0)
    p.qtyBox = W.SearchBox(add, 44, "Qty")
    p.qtyBox:SetPoint("LEFT", p.itemBox, "RIGHT", 6, 0)
    if p.qtyBox.SetNumeric then p.qtyBox:SetNumeric(true) end
    if p.qtyBox.SetMaxLetters then p.qtyBox:SetMaxLetters(3) end
    p.noteBox = W.SearchBox(add, 160, "Note (optional)")
    p.noteBox:SetPoint("LEFT", p.qtyBox, "RIGHT", 6, 0)
    if p.noteBox.SetMaxLetters then p.noteBox:SetMaxLetters(WL().TEXT_MAX) end
    p.addBtn = W.Button(add, "Add", 70, 22, Tab.Add)
    p.addBtn:SetPoint("LEFT", p.noteBox, "RIGHT", 6, 0)
    for _, box in ipairs({ p.itemBox, p.qtyBox, p.noteBox }) do
      box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Tab.Add() end)
    end
    p.msg = W.Text(add, "narrow", 11, "muted")
    p.msg:SetPoint("BOTTOMLEFT", 10, 6)
    p.msg:SetPoint("BOTTOMRIGHT", -10, 6)
    p.msg:SetText(HINT)
    Tab.HookLinks()

    local refresh = ns.Debounce(0.5, function() UI.Refresh("wishlist") end)
    ns:Listen("WISHLIST_UPDATED", refresh)
    ns:Listen("ROSTER_UPDATED", refresh)
    ns:On("GET_ITEM_INFO_RECEIVED", refresh)
    return p
  end,
  refresh = function(p)
    for k, b in pairs(p.filters) do b:SetActive(view.filter == k) end
    local rows = WL().All(view.filter, view.wishSearch)
    p.wishList:SetItems(rows)
    if #rows == 0 then
      p.wishEmpty:SetText(view.filter == "mine"
        and "You haven't added anything yet. Use the line below: what you need, or what you can give away."
        or "Nothing on the wishlist yet.\n\nAdd what you need or what you can give away below; guildmates see it "
          .. "here and on item tooltips.")
      p.wishEmpty:Show()
    else
      p.wishEmpty:Hide()
    end
    p.kindBtn.label:SetText(view.addKind == "n" and "I need" or "I can give")
  end,
})
