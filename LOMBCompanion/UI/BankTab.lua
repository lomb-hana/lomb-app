-- LOMB Companion: Bank tab -- the guild bank character's ledger.
-- Only listed once a guild bank character exists (someone ticked it in Settings).
local _, ns = ...
local C = ns.Compat
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local Tab = {}
ns.BankTab = Tab

local SIDE_W = 230
Tab.view = { bank = 1, search = "" }
local view = Tab.view

local function B() return ns.Bank end
local function WL() return ns.Wishlist end
local function ago(t) return t and ns.News.Ago(t) or "never" end

local classText = T.OwnerText
Tab.ClassText = classText

local itemIcon = C.ItemIcon

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
  -- click: item page, shift-click: link in chat, ctrl-click: preview (the same as every item row)
  row:SetScript("OnClick", function(self, button)
    if self.item then ns.ItemClick.Click(self.item.id, button) end
  end)
  W.Tooltip(row, function(tt, self)
    if not self.item then return end
    if tt.SetItemByID then tt:SetItemByID(self.item.id) else tt:SetText(self.item.label, 1, 1, 1) end
    ns.ItemClick.AddHint(tt, true)
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
  ns.ItemClick.Bind(row, function(self) return self.itemID end)
  return row
end

local function updateLogRow(row, e)
  row.itemID = e.id
  local name = C.ItemInfo(e.id) and W.ItemText(e.id) or ("item:" .. e.id)
  local sign = e.d > 0 and ("|cff7fe07f+%d|r"):format(e.d) or ("|cffe65959%d|r"):format(e.d)
  row.what:SetText(sign .. "  " .. name)
  row.when:SetText(ago(e.t))
end

UI.RegisterTab({
  id = "bank", label = "Bank", order = 70,
  -- hidden until someone ticks "This is a guild bank character" (here or on a guildmate's bank alt)
  shown = function() return B().Exists() end,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    local bank = CreateFrame("Frame", nil, p)
    bank:SetPoint("TOPLEFT", 0, 0)
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

    local refresh = ns.Debounce(0.5, function() UI.Refresh("bank") end)
    ns:Listen("BANK_UPDATED", refresh)
    ns:Listen("WISHLIST_UPDATED", refresh)
    ns:Listen("ROSTER_UPDATED", refresh)
    ns:On("GET_ITEM_INFO_RECEIVED", refresh)
    return p
  end,
  refresh = function(p)
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
      p.empty:SetText("No guild bank character.\n\nIf the guild sets one up, log into it and tick \"This is a guild "
        .. "bank character\" in Settings.")
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
  end,
})

-- show or hide the sidebar entry when a bank character appears or goes away
ns:Listen("BANK_UPDATED", function() UI.LayoutNav() end)
