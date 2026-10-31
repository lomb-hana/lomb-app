-- LOMB Companion: Bestiary tab -- searchable list of every creature the guild
-- has recorded (plus static data, if a data module is installed).
local _, ns = ...
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local MobPage = ns.MobPage
local Tab = {}
ns.BestiaryTab = Tab

local LIST_W = 220
local search = ""
local view = { filter = 1, sort = 1 }
Tab.view = view

local function createRow(list)
  local row = CreateFrame("Button", nil, list)
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.sel = W.Fill(row, "accentDim", "BACKGROUND")
  row.sel:SetAllPoints()
  row.meta = W.Text(row, "narrow", 10, "muted", "RIGHT")
  row.meta:SetPoint("RIGHT", -4, 0)
  row.name = W.Text(row, "body", 11, "text")
  row.name:SetPoint("LEFT", 6, 0)
  row.name:SetPoint("RIGHT", row.meta, "LEFT", -6, 0)   -- long names end in "..." before the level
  row:SetScript("OnClick", function(self) Tab.Select(self.item.npcId) end)
  return row
end

local function updateRow(row, item)
  local cls = item.cl and T.classification[item.cl]
  row.name:SetText(cls and ("|c" .. T.hex(cls[2]) .. item.name .. "|r") or item.name)
  local extra = (item.kills or 0) > 0 and ("  |cffb873ff" .. item.kills .. "|r") or ""
  if item.spotted and item.spotted.t and time() - item.spotted.t < 3600 then
    extra = extra .. "  |cfff2c75c" .. MobPage.Ago(item.spotted.t) .. "|r"
  end
  row.meta:SetText(MobPage.LevelText(item.level, item.levelMax) .. extra)
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
  id = "bestiary", label = "Bestiary", order = 60,
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
    local B = ns.Bestiary
    local half = (LIST_W - 16) / 2
    p.filter = W.Button(left, B.FILTERS[1].label, half, 20, function(_, button)
      view.filter = (view.filter - 1 + (button == "RightButton" and #B.FILTERS - 1 or 1)) % #B.FILTERS + 1
      UI.Refresh("bestiary")
    end)
    p.filter:SetPoint("TOPLEFT", 6, -34)
    p.filter.tip = "Show: all, rares, elites, this zone, killed or not, killed by me. Right-click goes back."
    if p.filter.RegisterForClicks then p.filter:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    p.sort = W.Button(left, B.SORTS[1].label, half, 20, function(_, button)
      view.sort = (view.sort - 1 + (button == "RightButton" and #B.SORTS - 1 or 1)) % #B.SORTS + 1
      UI.Refresh("bestiary")
    end)
    p.sort:SetPoint("LEFT", p.filter, "RIGHT", 4, 0)
    p.sort.tip = "Sort by name, level, kills or when last seen. Right-click goes back."
    if p.sort.RegisterForClicks then p.sort:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    p.count = W.Text(left, "narrow", 10, "muted")
    p.count:SetPoint("TOPLEFT", 8, -60)
    p.count:SetWidth(LIST_W - 16)
    p.list = W.List(left, 20, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 2, -76)
    p.list:SetPoint("BOTTOMRIGHT", -2, 4)
    p.empty = W.Text(left, "body", 11, "muted", "CENTER")
    p.empty:SetPoint("TOP", p.list, "TOP", 0, -40)
    p.empty:SetWidth(LIST_W - 28)
    p.empty:SetWordWrap(true)

    local right = W.Panel(p, "panel", "border")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    local width = T.sizes.content.w - LIST_W - 8 - 20
    p.page = MobPage.New(right, width)
    p.page:SetPoint("TOPLEFT", 12, -10)
    p.page:SetPoint("BOTTOMRIGHT", -6, 8)
    ns:Listen("BESTIARY_UPDATED", ns.Debounce(1, function() UI.Refresh("bestiary") end))
    return p
  end,
  refresh = function(p)
    local B = ns.Bestiary
    local f, so = B.FILTERS[view.filter], B.SORTS[view.sort]
    p.filter.label:SetText(f.label)
    p.filter:SetActive(f.key ~= "all")
    p.sort.label:SetText(so.label)
    local items = B.List(search, { filter = f.key, sort = so.key })
    p.list:SetItems(items, W.ViewKey(view, search))
    local text = ("%d creature%s"):format(#items, #items == 1 and "" or "s")
    local zs = B.ZoneStats()
    if zs.zone and zs.known > 0 then
      text = text .. ("  ·  %s: %d of %d killed (%d%%)"):format(zs.zone, zs.killed, zs.known, zs.pct)
    end
    p.count:SetText(text)
    if #items == 0 then
      p.empty:SetText(search ~= "" and ns.Theme.Playful("bestiary.search", "No creatures match \"" .. search .. "\".")
        or f.key ~= "all" and ns.Theme.Playful("bestiary.filter", "Nothing matches this filter yet. Right-click the filter to go back.")
        or ns.Theme.Playful("bestiary.none", "Nothing here yet. Creatures you target, fight or kill show up here, and so do the ones guildmates share."))
      p.empty:Show()
    else
      p.empty:Hide()
    end
    if not Tab.selected then
      local live = ns.Bestiary.live
      Tab.selected = (live and live.npcId) or (items[1] and items[1].npcId)
    end
    p.page:SetMob(Tab.selected)
  end,
})
