-- LOMB Companion: News tab -- what the guild has been up to.
local _, ns = ...
local W, UI = ns.Widgets, ns.UI
local News = ns.News
local Tab = { filter = 1 }
ns.NewsTab = Tab

local ICONS = {
  lv = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
  rare = "Interface\\Icons\\Ability_Hunter_SniperShot",
  dg = "Interface\\Icons\\INV_Misc_Key_03",
  ev = "Interface\\Icons\\INV_Misc_Note_02",
  rc = "Interface\\Icons\\Trade_BlackSmithing",
  join = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
  left = "Interface\\Icons\\Spell_Shadow_Teleport",
}

local function createRow(list, i)
  local row = CreateFrame("Frame", nil, list)
  row.bg = W.Fill(row, i % 2 == 0 and "row" or { 0, 0, 0, 0 }, "BACKGROUND")
  row.bg:SetAllPoints()
  row:EnableMouse(true)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", 6, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  row.when = W.Text(row, "narrow", 11, "muted", "RIGHT")
  row.when:SetPoint("RIGHT", -6, 0)
  row.when:SetWidth(90)
  row.text = W.Text(row, "body", 12, "text")
  row.text:SetPoint("LEFT", 32, 0)
  row.text:SetPoint("RIGHT", row.when, "LEFT", -8, 0)
  W.Tooltip(row, function(tt, self)
    local e = self.item
    if not e then return end
    tt:SetText(News.Text(e), 1, 1, 1, 1, true)
    tt:AddLine(date("%a %b %d, %H:%M", e.t), 0.6, 0.57, 0.66)
    if e.x then
      tt:AddLine("Happened while you were offline: the exact time isn't known.", 0.6, 0.57, 0.66, true)
    end
  end)
  return row
end

local function updateRow(row, e)
  row.icon:SetTexture(ICONS[e.ty] or ICONS.lv)
  row.text:SetText(News.Text(e))
  row.when:SetText(e.x and ("~" .. News.Ago(e.t)) or News.Ago(e.t))
end

function Tab.Cycle(step)
  Tab.filter = (Tab.filter - 1 + (step or 1)) % #News.FILTERS + 1
  UI.Refresh("news")
end

UI.RegisterTab({
  id = "news", label = "News", order = 40,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    p.title = W.SectionTitle(p, "Guild news")
    p.title:SetPoint("TOPLEFT", 0, 0)
    p.filterBtn = W.Button(p, "All news", 150, 22, function(_, button) Tab.Cycle(button == "RightButton" and -1 or 1) end)
    p.filterBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p.filterBtn.tip = "Click to choose what to show (right-click goes back)."
    p.filterBtn:SetPoint("TOPRIGHT", 0, 0)
    p.count = W.Text(p, "narrow", 11, "muted", "RIGHT")
    p.count:SetPoint("RIGHT", p.filterBtn, "LEFT", -10, 0)
    local div = W.Divider(p)
    div:SetPoint("TOPLEFT", 0, -28)
    div:SetPoint("TOPRIGHT", 0, -28)

    p.list = W.List(p, 26, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 0, -32)
    p.list:SetPoint("BOTTOMRIGHT", 0, 24)

    p.empty = W.Text(p, "body", 12, "muted", "CENTER")
    p.empty:SetPoint("CENTER", p.list, "CENTER", 0, 10)
    p.empty:SetWidth(440)
    p.empty:SetWordWrap(true)

    p.foot = W.Text(p, "narrow", 11, "muted")
    p.foot:SetPoint("BOTTOMLEFT", 0, 6)
    p.foot:SetText("Level-ups and joins come from the guild roster; rares, dungeons and recipes from guildmates with the addon.")

    ns:Listen("NEWS_UPDATED", function() UI.Refresh("news") end)
    return p
  end,
  refresh = function(p)
    local f = News.FILTERS[Tab.filter]
    local items = News.Filter(f.key)
    p.list:SetItems(items)
    p.filterBtn.label:SetText(f.label)
    p.filterBtn:SetActive(f.key ~= nil)
    p.count:SetText(("%d item%s"):format(#items, #items == 1 and "" or "s"))
    if #items == 0 then
      p.empty:SetText(f.key and "Nothing of that kind yet." or
        "No news yet.\n\nLevel-ups, rare kills, dungeon clears, new recipes and guild events show up here as they happen.")
      p.empty:Show()
    else
      p.empty:Hide()
    end
    News.MarkSeen()
  end,
})
