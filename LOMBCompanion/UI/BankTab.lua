-- LOMB Companion: Bank tab -- the bank character's ledger and the guild wishlist.
local _, ns = ...
local C = ns.Compat
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local Tab = {}
ns.BankTab = Tab

local SIDE_W = 230
Tab.view = { mode = "bank", bank = 1, search = "", filter = "all", addKind = "n", wishSearch = "" }
local view = Tab.view

local function B() return ns.Bank end
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
-- bank ledger
---------------------------------------------------------------------------
function Tab.Ledger()
  local all = B().Ledgers()
  if #all == 0 then return nil, all end
  if view.bank > #all then view.bank = 1 end
  return all[view.bank], all
end

function Tab.BankItems(L, search)
  local out = {}
  search = (search or ""):lower()
  for _, it in ipairs(L and L.items or {}) do
    local name = C.ItemInfo(it.id)
    local label = name or ("item:" .. it.id)
    if search == "" or label:lower():find(search, 1, true) then
      local needs = WL().ForItem(it.id)
      out[#out + 1] = { id = it.id, count = it.count, label = label, loaded = name ~= nil, wanted = #needs }
    end
  end
  table.sort(out, function(a, b)
    if a.label ~= b.label then return a.label < b.label end
    return a.id < b.id
  end)
  return out
end

function Tab.NextBank()
  local _, all = Tab.Ledger()
  view.bank = (#all > 0) and (view.bank % #all) + 1 or 1
  UI.Refresh("bank")
end

local function createItemRow(list, i)
  local row = CreateFrame("Button", nil, list)
  row.bg = W.Fill(row, i % 2 == 0 and "row" or { 0, 0, 0, 0 }, "BACKGROUND")
  row.bg:SetAllPoints()
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", 4, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.name = W.Text(row, "body", 12, "text")
  row.name:SetPoint("LEFT", 26, 0)
  row.name:SetWidth(220)
  row.count = W.Text(row, "narrow", 12, "text", "RIGHT")
  row.count:SetPoint("LEFT", 246, 0)
  row.count:SetWidth(50)
  row.want = W.Text(row, "narrow", 11, "gold")
  row.want:SetPoint("LEFT", 310, 0)
  row.want:SetPoint("RIGHT", -4, 0)
  row:SetScript("OnClick", function(self)
    if self.item and IsShiftKeyDown() then
      local _, link = C.ItemInfo(self.item.id)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end
  end)
  W.Tooltip(row, function(tt, self)
    if not self.item then return end
    if tt.SetItemByID then tt:SetItemByID(self.item.id) else tt:SetText(self.item.label, 1, 1, 1) end
  end)
  return row
end

local function updateItemRow(row, item)
  row.icon:SetTexture(itemIcon(item.id))
  row.name:SetText(item.loaded and W.ItemText(item.id) or ("|cff9991a8%s (loading)|r"):format(item.label))
  row.count:SetText(W.Thousands(item.count))
  row.want:SetText(item.wanted > 0 and ("wanted by %d"):format(item.wanted) or "")
end

local function createLogRow(list)
  local row = CreateFrame("Frame", nil, list)
  row.what = W.Text(row, "narrow", 11, "text")
  row.what:SetPoint("LEFT", 4, 0)
  row.what:SetPoint("RIGHT", -60, 0)
  row.when = W.Text(row, "narrow", 10, "muted", "RIGHT")
  row.when:SetPoint("RIGHT", -6, 0)
  row.when:SetWidth(56)
  return row
end

local function updateLogRow(row, e)
  local name = C.ItemInfo(e.id) and W.ItemText(e.id) or ("item:" .. e.id)
  local sign = e.d > 0 and ("|cff7fe07f+%d|r"):format(e.d) or ("|cffe65959%d|r"):format(e.d)
  row.what:SetText(sign .. "  " .. name)
  row.when:SetText(ago(e.t))
end

---------------------------------------------------------------------------
-- wishlist
---------------------------------------------------------------------------
local HINT = "Click a guildmate's row to start a whisper (you press Enter)  ·  shift-click an item into the box"
local FILTERS = { { "all", "All" }, { "need", "Needs" }, { "give", "Offers" }, { "mine", "Mine" } }

function Tab.Click(row)
  if not row or row.mine then return false end
  if IsShiftKeyDown() and row.id then
    local _, link = C.ItemInfo(row.id)
    if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    return true
  end
  if ChatFrame_OpenChat then ChatFrame_OpenChat(WL().WhisperText(row)) end
  return true
end

function Tab.RemoveRow(row)
  if row and row.mine then WL().Remove(row.entry) end
  UI.Refresh("bank")
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
  UI.Refresh("bank")
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
      tt:AddLine("Click: whisper them (you press Enter)   Shift-click: link it", 0.72, 0.45, 1.0)
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

function Tab.SetMode(mode)
  view.mode = mode
  UI.Refresh("bank")
end
function Tab.SetFilter(f)
  view.filter = f
  UI.Refresh("bank")
end
function Tab.ToggleKind()
  view.addKind = view.addKind == "n" and "g" or "n"
  UI.Refresh("bank")
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
  id = "bank", label = "Bank", order = 70,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    p.bankBtn = W.Button(p, "Bank", 90, 22, function() Tab.SetMode("bank") end)
    p.bankBtn:SetPoint("TOPLEFT", 0, 0)
    p.wishBtn = W.Button(p, "Wishlist", 90, 22, function() Tab.SetMode("wish") end)
    p.wishBtn:SetPoint("LEFT", p.bankBtn, "RIGHT", 4, 0)

    -- bank view -----------------------------------------------------------
    local bank = CreateFrame("Frame", nil, p)
    bank:SetPoint("TOPLEFT", 0, -30)
    bank:SetPoint("BOTTOMRIGHT", 0, 0)
    p.bank = bank
    local main = W.Panel(bank, "panel", "border")
    main:SetPoint("TOPLEFT", 0, 0)
    main:SetPoint("BOTTOMRIGHT", -(SIDE_W + 8), 0)
    p.title = W.Text(main, "title", 16, "gold")
    p.title:SetPoint("TOPLEFT", 10, -8)
    p.title:SetPoint("RIGHT", -110, 0)
    p.next = W.Button(main, "Next bank alt", 96, 20, Tab.NextBank)
    p.next:SetPoint("TOPRIGHT", -8, -6)
    p.meta = W.Text(main, "narrow", 11, "muted")
    p.meta:SetPoint("TOPLEFT", 10, -30)
    p.meta:SetPoint("RIGHT", -10, 0)
    p.funds = W.Text(main, "body", 12, "text")
    p.funds:SetPoint("TOPLEFT", 10, -46)
    p.funds:SetPoint("RIGHT", -10, 0)
    p.search = W.SearchBox(main, 200, "Search the bank", function(text)
      view.search = text
      UI.Refresh("bank")
    end)
    p.search:SetPoint("TOPLEFT", 8, -66)
    p.count = W.Text(main, "narrow", 11, "muted", "RIGHT")
    p.count:SetPoint("TOPRIGHT", -10, -70)
    p.items = W.List(main, 20, createItemRow, updateItemRow)
    p.items:SetPoint("TOPLEFT", 4, -94)
    p.items:SetPoint("BOTTOMRIGHT", -4, 4)
    p.empty = W.Text(main, "body", 12, "muted", "CENTER")
    p.empty:SetPoint("TOP", 0, -120)
    p.empty:SetWidth(330)
    p.empty:SetWordWrap(true)

    local side = W.Panel(bank, "panel", "border")
    side:SetPoint("TOPRIGHT", 0, 0)
    side:SetPoint("BOTTOMRIGHT", 0, 0)
    side:SetWidth(SIDE_W)
    p.side = side
    local st = W.SectionTitle(side, "Recent changes")
    st:SetPoint("TOPLEFT", 10, -8)
    st:SetPoint("RIGHT", -10, 0)
    p.log = W.List(side, 18, createLogRow, updateLogRow)
    p.log:SetPoint("TOPLEFT", 6, -32)
    p.log:SetPoint("BOTTOMRIGHT", -4, 44)
    p.logEmpty = W.Text(side, "narrow", 11, "muted")
    p.logEmpty:SetPoint("TOPLEFT", 10, -34)
    p.logEmpty:SetPoint("RIGHT", -10, 0)
    p.logEmpty:SetWordWrap(true)
    p.sideFoot = W.Text(side, "narrow", 10, "muted")
    p.sideFoot:SetPoint("BOTTOMLEFT", 10, 8)
    p.sideFoot:SetPoint("BOTTOMRIGHT", -10, 8)
    p.sideFoot:SetWordWrap(true)
    p.sideFoot:SetText("Counts items going in and out of the bank character's bags and bank. Moving things between them doesn't count.")

    -- wishlist view -------------------------------------------------------
    local wish = CreateFrame("Frame", nil, p)
    wish:SetPoint("TOPLEFT", 0, -30)
    wish:SetPoint("BOTTOMRIGHT", 0, 0)
    p.wish = wish
    p.filters = {}
    local prev
    for _, f in ipairs(FILTERS) do
      local b = W.Button(wish, f[2], 70, 20, function() Tab.SetFilter(f[1]) end)
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 0, 0) end
      p.filters[f[1]] = b
      prev = b
    end
    p.wishSearch = W.SearchBox(wish, 200, "Search items, notes, names", function(text)
      view.wishSearch = text
      UI.Refresh("bank")
    end)
    p.wishSearch:SetPoint("TOPRIGHT", 0, 0)
    local wl = W.Panel(wish, "panel", "border")
    wl:SetPoint("TOPLEFT", 0, -26)
    wl:SetPoint("BOTTOMRIGHT", 0, 64)
    p.wishList = W.List(wl, 22, createWishRow, updateWishRow)
    p.wishList:SetPoint("TOPLEFT", 4, -4)
    p.wishList:SetPoint("BOTTOMRIGHT", -4, 4)
    p.wishEmpty = W.Text(wl, "body", 12, "muted", "CENTER")
    p.wishEmpty:SetPoint("TOP", 0, -70)
    p.wishEmpty:SetWidth(420)
    p.wishEmpty:SetWordWrap(true)

    local add = W.Panel(wish, "panel", "border")
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

    local refresh = ns.Debounce(0.5, function() UI.Refresh("bank") end)
    ns:Listen("BANK_UPDATED", refresh)
    ns:Listen("WISHLIST_UPDATED", refresh)
    ns:Listen("ROSTER_UPDATED", refresh)
    ns:On("GET_ITEM_INFO_RECEIVED", refresh)
    return p
  end,
  refresh = function(p)
    local isBank = view.mode == "bank"
    p.bankBtn:SetActive(isBank)
    p.wishBtn:SetActive(not isBank)
    p.bank:SetShown(isBank)
    p.wish:SetShown(not isBank)

    if isBank then
      local L, all = Tab.Ledger()
      p.next:SetShown(#all > 1)
      if not L then
        p.title:SetText("Guild bank")
        p.meta:SetText("")
        p.funds:SetText("")
        p.items:SetItems({})
        p.log:SetItems({})
        p.count:SetText("")
        p.search:Hide()
        p.logEmpty:SetText("Nothing yet.")
        p.logEmpty:Show()
        p.empty:SetText("No bank character yet.\n\nLog into the guild's bank character and tick \"This character is the "
          .. "guild bank\" in Settings. It's ticked for you if the character's name or guild note says \"bank\".")
        p.empty:Show()
        return
      end
      p.search:Show()
      p.title:SetText(("Guild bank  |cff9991a8·|r  %s"):format(classText(L.owner)))
      local meta = ("Bags counted %s  ·  bank %s"):format(ago(L.bagsAt),
        L.vaultAt and ("counted " .. ago(L.vaultAt)) or "not opened yet")
      if #all > 1 then meta = meta .. ("  ·  bank alt %d of %d"):format(view.bank, #all) end
      p.meta:SetText(meta)
      p.funds:SetText(L.money and ("Guild bank funds: %s"):format(W.FormatMoney(L.money)) or "")
      local items = Tab.BankItems(L, view.search)
      p.items:SetItems(items)
      p.count:SetText(("%d items"):format(#L.items))
      if #L.items == 0 then
        p.empty:SetText("The bank character's bags are empty.")
        p.empty:Show()
      elseif #items == 0 then
        p.empty:SetText("Nothing in the bank matches that.")
        p.empty:Show()
      else
        p.empty:Hide()
      end
      p.log:SetItems(L.log)
      p.logEmpty:SetText(L.mine and not L.vaultAt and "Open the bank once so its contents are counted too."
        or "No changes yet.")
      p.logEmpty:SetShown(#L.log == 0)
      return
    end

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
