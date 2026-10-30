-- LOMB Companion: Bestiary tab -- searchable list of every creature the guild
-- has recorded (plus static data, if a data module is installed).
local _, ns = ...
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local MobPage = ns.MobPage
local Tab = {}
ns.BestiaryTab = Tab

local LIST_W = 220
local search = ""

local function createRow(list)
  local row = CreateFrame("Button", nil, list)
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.sel = W.Fill(row, "accentDim", "BACKGROUND")
  row.sel:SetAllPoints()
  row.name = W.Text(row, "body", 11, "text")
  row.name:SetPoint("LEFT", 6, 0)
  row.name:SetWidth(LIST_W - 70)
  row.meta = W.Text(row, "narrow", 10, "muted", "RIGHT")
  row.meta:SetPoint("RIGHT", -4, 0)
  row:SetScript("OnClick", function(self) Tab.Select(self.item.npcId) end)
  return row
end

local function updateRow(row, item)
  local cls = item.cl and T.classification[item.cl]
  row.name:SetText(cls and ("|c" .. T.hex(cls[2]) .. item.name .. "|r") or item.name)
  row.meta:SetText(("%s%s"):format(MobPage.LevelText(item.level, item.levelMax),
    (item.kills or 0) > 0 and ("  |cffb873ff" .. item.kills .. "|r") or ""))
  row.sel:SetShown(Tab.selected == item.npcId)
end

function Tab.Select(npcId)
  Tab.selected = npcId
  if Tab.panel then
    Tab.panel.page:SetMob(npcId)
    Tab.panel.list:Refresh()
  end
end

UI.RegisterTab({
  id = "bestiary", label = "Bestiary", order = 3,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    local left = W.Panel(p, "panel", "border")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(LIST_W)
    p.search = W.SearchBox(left, LIST_W - 12, "Search creatures", function(text)
      search = text
      UI.Refresh("bestiary")
    end)
    p.search:SetPoint("TOPLEFT", 6, -6)
    p.count = W.Text(left, "narrow", 10, "muted")
    p.count:SetPoint("TOPLEFT", 8, -34)
    p.list = W.List(left, 20, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 2, -50)
    p.list:SetPoint("BOTTOMRIGHT", -2, 4)

    local right = W.Panel(p, "panel", "border")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    local width = (T.sizes.window.w - 2 * T.sizes.pad) - LIST_W - 8 - 20
    p.page = MobPage.New(right, width)
    p.page:SetPoint("TOPLEFT", 12, -10)
    p.page:SetPoint("BOTTOMRIGHT", -6, 8)
    ns:Listen("BESTIARY_UPDATED", ns.Debounce(1, function() UI.Refresh("bestiary") end))
    return p
  end,
  refresh = function(p)
    local items = ns.Bestiary.List(search)
    p.list:SetItems(items)
    p.count:SetText(("%d creature%s known"):format(#items, #items == 1 and "" or "s"))
    if not Tab.selected then
      local live = ns.Bestiary.live
      Tab.selected = (live and live.npcId) or (items[1] and items[1].npcId)
    end
    p.page:SetMob(Tab.selected)
  end,
})
