-- LOMB Companion: Crafters tab -- "who in the guild can make this?"
local _, ns = ...
local C = ns.Compat
local W, UI = ns.Widgets, ns.UI
local Crafting = ns.Crafting
local Tab = {}
ns.CraftersTab = Tab

local COL = { name = 270, prof = 110 }
Tab.view = { search = "", prof = nil, onlineOnly = false, sort = "name", desc = false }

local function entryIcon(item)
  if item.kind == "i" then
    return C.ItemIcon(item.id)
  end
  local _, icon = C.SpellName(item.id)
  return icon or 136244
end

local function entryLink(item)
  if item.kind == "i" then
    local _, link = C.ItemInfo(item.id)
    return link
  end
  local link = (C_Spell and C.Call(C_Spell.GetSpellLink, item.id)) or C.Call(_G.GetSpellLink, item.id)
  return link
end
Tab.EntryLink = entryLink

-- The ForeverDB recipe for a crafters entry (item made, or enchant spell), if bundled.
function Tab.RecipeRef(item)
  local FDB = ns.FDB
  if not (FDB and FDB.Available() and item) then return nil end
  local I = FDB.Index()
  if item.kind == "i" then
    local refs = I.madeBy[item.id]
    return refs and refs[1]
  end
  return I.bySpell[item.id]
end

local function crafterText(list, max)
  local parts = {}
  for i = 1, math.min(max or 3, #list) do
    local o = list[i]
    local short = C.ShortName(o)
    parts[i] = Crafting.IsOnline(o) and ("|cff7fe07f" .. short .. "|r") or ("|cff9991a8" .. short .. "|r")
  end
  local text = table.concat(parts, ", ")
  if #list > (max or 3) then text = text .. ("  |cff9991a8+%d|r"):format(#list - (max or 3)) end
  return text
end
Tab.CrafterText = crafterText

function Tab.Whisper(item)
  for _, o in ipairs(item.crafters) do
    if o ~= ns.playerKey and Crafting.IsOnline(o) then
      local name = item.name or "this"
      if ChatFrame_OpenChat then
        ChatFrame_OpenChat(("/w %s Hi! Could you craft %s for me? "):format(C.ShortName(o), entryLink(item) or name))
      end
      return o
    end
  end
  ns.Print("Nobody who can craft that is online right now.")
  return nil
end

local function createRow(list, i)
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
  row.name:SetWidth(COL.name - 30)
  row.prof = W.Text(row, "narrow", 12, "muted")
  row.prof:SetPoint("LEFT", COL.name, 0)
  row.prof:SetWidth(COL.prof - 6)
  row.who = W.Text(row, "narrow", 12, "text")
  row.who:SetPoint("LEFT", COL.name + COL.prof, 0)
  row.who:SetPoint("RIGHT", -4, 0)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetScript("OnClick", function(self)
    local item = self.item
    if not item then return end
    local ref = Tab.RecipeRef(item)
    if IsAltKeyDown and IsAltKeyDown() and ref and ns.QuestsTab then
      ns.QuestsTab.Show("recipes", ref)
    elseif item.kind == "i" and ns.ItemClick.Modified(item.id) then
      -- shift-click: link in chat, ctrl-click: preview (the same as every item row)
      return
    elseif IsShiftKeyDown() then
      local link = entryLink(item)
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    else
      Tab.Whisper(item)
    end
  end)
  W.Tooltip(row, function(tt, self)
    local item = self.item
    if not item then return end
    tt:SetText(item.name or ("#" .. item.id), 1, 1, 1)
    tt:AddLine(Crafting.NameOf(item.prof), 0.6, 0.57, 0.66)
    tt:AddLine(" ")
    for n, o in ipairs(item.crafters) do
      if n > 12 then tt:AddLine(("+%d more"):format(#item.crafters - 12), 0.6, 0.57, 0.66); break end
      local on = Crafting.IsOnline(o)
      tt:AddDoubleLine(C.ShortName(o), on and "online" or "offline",
        1, 1, 1, on and 0.5 or 0.6, on and 0.88 or 0.57, on and 0.5 or 0.66)
    end
    local ref = Tab.RecipeRef(item)
    local r, prof
    if ref then r, prof = ns.FDB.Recipe(ref) end
    if r then
      tt:AddLine(" ")
      tt:AddLine(("%s  skill %s"):format(prof.n, ns.FDB.SkillText(r.sk)), 1, 1, 1)
      if r.rg then tt:AddLine("Reagents: " .. ns.FDB.ReagentsText(r), 0.8, 0.78, 0.85, true) end
      tt:AddLine("Learned from: " .. ns.FDB.WaysText(r), 0.8, 0.78, 0.85, true)
      tt:AddLine(ns.FDB.CREDIT .. ", " .. ns.FDB.URL, 0.95, 0.78, 0.36)
    end
    tt:AddLine(" ")
    tt:AddLine("Click: whisper an online crafter   Shift-click: link in chat", 0.72, 0.45, 1.0)
    if r then tt:AddLine("Alt-click: open the recipe in Quests & Items", 0.72, 0.45, 1.0) end
  end)
  return row
end

local function updateRow(row, item)
  row.icon:SetTexture(entryIcon(item))
  if item.name then
    row.name:SetText(item.kind == "i" and W.ItemText(item.id) or item.name)
  else
    row.name:SetText(("|cff9991a8%s #%d (loading)|r"):format(item.kind == "i" and "item" or "spell", item.id))
  end
  row.prof:SetText(Crafting.NameOf(item.prof))
  row.who:SetText(crafterText(item.crafters, 3))
end

function Tab.CycleProf()
  local codes = Crafting.ProfCodes()
  local cur, nextCode = Tab.view.prof, nil
  if not cur then
    nextCode = codes[1]
  else
    for i, c in ipairs(codes) do if c == cur then nextCode = codes[i + 1] end end
  end
  Tab.view.prof = nextCode
  UI.Refresh("crafters")
end

-- Search() returns items A to Z; other orders are applied here.
function Tab.SortItems(items, view)
  local key, desc = view.sort or "name", view.desc
  if key == "name" and not desc then return items end
  if key == "prof" then
    W.SortRows(items, function(it) return Crafting.NameOf(it.prof) end, desc, "name")
  elseif key == "crafters" then
    W.SortRows(items, function(it)
      local on = 0
      for _, c in ipairs(it.crafters or {}) do if Crafting.IsOnline(c) then on = on + 1 end end
      return on * 1000 + #(it.crafters or {})
    end, desc, "name")
  else
    W.SortRows(items, "name", desc)
  end
  return items
end

UI.RegisterTab({
  id = "crafters", label = "Crafters", order = 30,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    p.search = W.SearchBox(p, 230, "Search items, professions, names", function(text)
      Tab.view.search = text
      UI.Refresh("crafters")
    end)
    p.search:SetPoint("TOPLEFT", 0, 0)
    p.profBtn = W.Button(p, "All professions", 130, 22, function(_, button)
      if button == "RightButton" then Tab.view.prof = nil; UI.Refresh("crafters") else Tab.CycleProf() end
    end)
    p.profBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p.profBtn.tip = "Click to cycle professions, right-click for all."
    p.profBtn:SetPoint("LEFT", p.search, "RIGHT", 8, 0)
    p.online = W.Check(p, "Online only", function() return Tab.view.onlineOnly end,
      function(v) Tab.view.onlineOnly = v; UI.Refresh("crafters") end,
      "Only show crafters who are online right now, so you can whisper them.")
    p.online:SetWidth(110)
    p.online:SetPoint("LEFT", p.profBtn, "RIGHT", 12, 0)
    p.count = W.Text(p, "narrow", 11, "muted", "RIGHT")
    p.count:SetPoint("TOPRIGHT", 0, -5)

    -- column headers (click to sort)
    p.head = W.SortHeader(p, {
      { key = "name", label = "Item", x = 26, w = COL.name - 30, tip = "Sort by item name (A to Z, click again for Z to A)." },
      { key = "prof", label = "Profession", x = COL.name, w = COL.prof - 6, tip = "Sort by profession, then item name." },
      { key = "crafters", label = "Crafters (online first)", x = COL.name + COL.prof, w = 200, desc = true,
        tip = "Sort by how many crafters are online right now, then how many there are in all." },
    }, Tab.view, function() UI.Refresh("crafters") end)
    p.head:SetPoint("TOPLEFT", 0, -30)
    p.head:SetPoint("TOPRIGHT", 0, -30)
    local div = W.Divider(p)
    div:SetPoint("TOPLEFT", 0, -49)
    div:SetPoint("TOPRIGHT", 0, -49)

    p.list = W.List(p, 22, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 0, -52)
    p.list:SetPoint("BOTTOMRIGHT", 0, 26)

    p.empty = W.Text(p, "body", 12, "muted", "CENTER")
    p.empty:SetPoint("CENTER", p.list, "CENTER", 0, 10)
    p.empty:SetWidth(440)
    p.empty:SetWordWrap(true)

    p.mine = W.Text(p, "narrow", 11, "muted")
    p.mine:SetPoint("BOTTOMLEFT", 0, 6)
    p.mine:SetPoint("BOTTOMRIGHT", 0, 6)

    local refresh = ns.Debounce(0.3, function() UI.Refresh("crafters") end)
    ns:Listen("CRAFTERS_UPDATED", refresh)
    ns:Listen("CRAFTERS_NAMES", refresh)
    return p
  end,
  refresh = function(p)
    local items, missing = Crafting.Search(Tab.view)
    Tab.SortItems(items, Tab.view)
    p.list:SetItems(items, W.ViewKey(Tab.view))
    p.profBtn.label:SetText(Tab.view.prof and Crafting.NameOf(Tab.view.prof) or "All professions")
    p.profBtn:SetActive(Tab.view.prof ~= nil)
    p.online:Refresh()
    local crafters = Crafting.CrafterCount()
    p.count:SetText(("%d recipes  ·  %d crafter%s%s"):format(#items, crafters, crafters == 1 and "" or "s",
      missing > 0 and ("  ·  %d loading"):format(missing) or ""))
    if #items == 0 then
      if #Crafting.entries == 0 then
        p.empty:SetText("No recipes shared yet.\n\nOpen each of your profession windows once and LOMB Companion " ..
          "remembers what you can make. Guildmates with the addon do the same, and their recipes show up here.")
      else
        p.empty:SetText(ns.Theme.Playful("crafters.search", "Nothing matches that search."))
      end
      p.empty:Show()
    else
      p.empty:Hide()
    end
    local mine = Crafting.MyCounts()
    if #mine == 0 then
      p.mine:SetText("Your recipes: none read yet. Open a profession window to add yours.")
    else
      local parts = {}
      for _, m in ipairs(mine) do parts[#parts + 1] = ("%s |cffffffff%d|r"):format(m.prof, m.n) end
      p.mine:SetText("Your recipes: " .. table.concat(parts, "  ·  ") ..
        (ns.db.settings.shareRecipes and "" or "  |cffe0b060(not shared: turned off in Settings)|r"))
    end
  end,
})
