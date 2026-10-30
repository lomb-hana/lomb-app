-- LOMB Companion: Quests & Items tab -- quests, item lookup, vendors, profession
-- recipes and dungeons from the bundled ForeverDB.net snapshot (Data/ForeverDB/).
-- Every view says where the data comes from and shows https://foreverdb.net.
local _, ns = ...
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local MobPage = ns.MobPage
local Tab = {}
ns.QuestsTab = Tab

local LIST_W = 250
local MUTED, WARN, GOOD, LINK = "|cff9a92a8", "|cffe0b060", "|cff7fd18b", "|cffb873ff"
local CHAIN = "|cffa98bd6"   -- soft LOMB violet for "Part 1 of 3" tags

Tab.MODES = {
  { key = "quests", label = "Quests", search = "Search quests, NPCs, zones" },
  { key = "items", label = "Items", search = "Search items" },
  { key = "vendors", label = "Vendors", search = "Search vendors or what they sell" },
  { key = "recipes", label = "Recipes", search = "Search recipes or reagents" },
  { key = "dungeons", label = "Dungeons", search = "Search dungeons or bosses" },
}
Tab.LEVELS = {
  { key = "near", label = "Near my level" },
  { key = "all", label = "All levels" },
  { key = "1-10", label = "Levels 1-10", min = 1, max = 10 },
  { key = "11-20", label = "Levels 11-20", min = 11, max = 20 },
  { key = "21-30", label = "Levels 21-30", min = 21, max = 30 },
}
Tab.SKILLS = {
  { label = "Any skill" },
  { label = "Skill 1-75", max = 75 },
  { label = "Skill up to 150", max = 150 },
  { label = "Skill up to 225", max = 225 },
}

local view = { mode = "quests", search = {}, zone = false, level = 1, mine = true, prof = 0, skill = 1 }
Tab.view = view
Tab.selected = {}
Tab.history = {}

local function modeInfo(key)
  for i, m in ipairs(Tab.MODES) do if m.key == key then return m, i end end
end

local function playerZone()
  local z = GetRealZoneText and ns.Compat.Call(GetRealZoneText)
  return (type(z) == "string" and z ~= "") and z or nil
end

local function playerLevel()
  local l = UnitLevel and ns.Compat.Call(UnitLevel, "player")
  return type(l) == "number" and l > 0 and l or nil
end

local function profAt(i)
  local list = ns.FDB.Professions()
  local e = list[i]
  return e and e.slug, e and e.p, #list
end

---------------------------------------------------------------------------
-- List rows
---------------------------------------------------------------------------
local function createRow(list)
  local row = CreateFrame("Button", nil, list)
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.sel = W.Fill(row, "accentDim", "BACKGROUND")
  row.sel:SetAllPoints()
  row.chain = W.Fill(row, "accent", "ARTWORK")   -- thin bar down the left of chained quests
  row.chain:SetPoint("TOPLEFT", 1, -3)
  row.chain:SetPoint("BOTTOMLEFT", 1, 3)
  row.chain:SetWidth(2)
  row.chain:SetAlpha(0.55)
  row.meta = W.Text(row, "narrow", 10, "muted", "RIGHT")
  row.meta:SetPoint("RIGHT", -4, 0)
  row.name = W.Text(row, "body", 11, "text")
  row.name:SetPoint("LEFT", 6, 0)
  row.name:SetPoint("RIGHT", row.meta, "LEFT", -6, 0)
  row.name:SetWordWrap(false)
  row:SetScript("OnClick", function(self) Tab.Select(self.item.key) end)
  return row
end

local function updateRow(row, item)
  row.name:SetText(item.text)
  row.meta:SetText(item.meta or "")
  row.chain:SetShown(item.chain == true)
  row.sel:SetShown(Tab.selected[view.mode] == item.key)
end

-- Rows for the current mode: { key, text, meta }
function Tab.Items()
  local FDB = ns.FDB
  local mode, search = view.mode, view.search[view.mode] or ""
  local out = {}
  if mode == "quests" then
    local lv = Tab.LEVELS[view.level]
    local minL, maxL = lv.min, lv.max
    if lv.key == "near" then
      local pl = playerLevel()
      if pl then minL, maxL = math.max(1, pl - 3), pl + 3 end
    end
    local list = FDB.QuestList({ search = search, zone = view.zone and playerZone() or nil,
      minLevel = minL, maxLevel = maxL, side = view.mine and FDB.PlayerSide() or nil })
    for _, e in ipairs(FDB.GroupChains(list)) do
      local part = FDB.ChainText(e.id)
      out[#out + 1] = { key = e.id, text = e.q.n, chain = part ~= nil,
        meta = (part and CHAIN .. part .. "|r  " or "") .. (e.q.c and WARN .. "c|r " or "")
          .. (e.q.l > 0 and e.q.l or "-") }
    end
  elseif mode == "items" then
    for _, id in ipairs(FDB.ItemSearch(search)) do
      out[#out + 1] = { key = id, text = FDB.ItemText(id) }
    end
  elseif mode == "vendors" then
    local list = FDB.VendorList({ search = search, zone = view.zone and playerZone() or nil,
      side = view.mine and FDB.PlayerSide() or nil })
    for _, e in ipairs(list) do
      out[#out + 1] = { key = e.id, text = e.v.n, meta = e.v.z }
    end
  elseif mode == "recipes" then
    local slug = view.prof > 0 and profAt(view.prof) or nil
    local list = FDB.RecipeList({ prof = slug, search = search, maxSkill = Tab.SKILLS[view.skill].max })
    for _, e in ipairs(list) do
      local p = FDB.Profession(e.prof)
      out[#out + 1] = { key = e.prof .. ":" .. e.i, text = (e.r.mk and FDB.ItemText(e.r.mk) or e.r.n),
        meta = (slug and "" or (p.n:sub(1, 5) .. " ")) .. tostring(e.r.sk[1] or "?") }
    end
  elseif mode == "dungeons" then
    for _, e in ipairs(FDB.DungeonList(search)) do
      out[#out + 1] = { key = e.id, text = e.d.n, meta = FDB.DungeonLevelText(e.d) }
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------
local function recipeRef(key)
  local prof, i = tostring(key):match("^(.-):(%d+)$")
  return prof and { prof = prof, i = tonumber(i) }
end

-- Open the tab on one entry. Links inside the tab push the current entry so
-- the back button can return to it.
function Tab.Show(mode, key, fromLink)
  if not modeInfo(mode) then return end
  if fromLink and Tab.selected[view.mode] then
    Tab.history[#Tab.history + 1] = { view.mode, Tab.selected[view.mode] }
    if #Tab.history > 30 then table.remove(Tab.history, 1) end
  end
  if type(key) == "table" then key = key.prof .. ":" .. key.i end
  view.mode = mode
  if key ~= nil then
    Tab.selected[mode] = key
    -- make sure the row is in the list even if a filter would hide it
    view.search[mode] = ""
    if mode == "quests" or mode == "vendors" then view.zone = false end
    if mode == "quests" then view.level = 2 end
    if mode == "recipes" then view.prof, view.skill = 0, 1 end
  end
  if not fromLink then ns.UI.Open("quests") end
  Tab.Refresh()
end

function Tab.Back()
  local h = table.remove(Tab.history)
  if h then
    view.mode = h[1]
    Tab.selected[h[1]] = h[2]
    Tab.Refresh()
  end
end

function Tab.Select(key)
  Tab.selected[view.mode] = key
  Tab.Refresh()
end

function Tab.Refresh()
  if Tab.panel then UI.Refresh("quests") end
end

local function link(mode, key)
  return function() Tab.Show(mode, key, true) end
end

---------------------------------------------------------------------------
-- Detail pages
---------------------------------------------------------------------------
local add, section = MobPage.AddLine, MobPage.Section

local function itemIcon(itemID)
  local _, _, _, icon = ns.Compat.ItemInfo(itemID)
  return icon or 134400
end

local function credit(page, extra)
  local FDB = ns.FDB
  page.y = page.y + 10
  add(page, { text = FDB.CREDIT .. "  " .. MUTED .. FDB.URL .. "|r", size = 11, color = "gold",
    tip = { FDB.CREDIT, FDB.URL, "Snapshot " .. tostring(FDB.Snapshot() or "?") .. ". The link is in the box at the bottom to copy." } })
  if extra then add(page, { text = extra, size = 10, color = "muted", wrap = true }) end
end

local function endpoint(page, e, label)
  local FDB = ns.FDB
  if not e then
    add(page, { text = MUTED .. label .. "|r   not known yet", size = 12 })
    return
  end
  local kind, id, name = e[1], e[2], e[3]
  local loc = FDB.LocText(e[4], e[5], e[6])
  local classic = e[7] == 1 and ("  " .. WARN .. FDB.CLASSIC_NOTE .. "|r") or ""
  if kind == "i" and id and id > 0 then
    add(page, { text = MUTED .. label .. "|r   " .. FDB.ItemText(id) .. classic, icon = itemIcon(id), item = id,
      onClick = link("items", id), tip = { "Click for more on this item." } })
    return
  end
  local text = name or "?"
  local open, tip
  if kind == "o" then text = text .. "  " .. MUTED .. "(object)|r" end
  if kind == "n" and id and id > 0 then
    if FDB.Vendor(id) then
      open, tip = link("vendors", id), { name or "NPC", "Also a vendor. Click to see what they sell." }
    elseif ns.db and ns.db.bestiary and ns.db.bestiary[id] and ns.BestiaryTab then
      open = function() ns.UI.Open("bestiary"); ns.BestiaryTab.Select(id) end
      tip = { name or "NPC", "Click to open them in the Bestiary." }
    end
  end
  if open then text = text .. "  " .. LINK .. "(open)|r" end
  add(page, { text = MUTED .. label .. "|r   " .. text .. classic, right = loc, onClick = open, tip = tip })
end

local function questLine(page, qid, indent)
  local FDB = ns.FDB
  local q = FDB.Quest(qid)
  if not q then return end
  add(page, { text = q.n .. "  " .. MUTED .. "(" .. q.l .. ")|r", indent = indent, right = q.z,
    onClick = link("quests", qid), tip = { q.n, "Click to open this quest." } })
end

local function renderQuest(page, id)
  local FDB = ns.FDB
  local q = FDB.Quest(id)
  if not q then return false end
  add(page, { text = q.n, font = "title", size = 20, gap = 2 })
  local bits = { "Level " .. FDB.LevelText(q), FDB.SideText(q.s) }
  if q.z then bits[#bits + 1] = q.z end
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  if q.ql then add(page, { text = MUTED .. "Quest line|r   " .. q.ql, size = 12 }) end
  if q.c then
    add(page, { text = WARN .. "This quest's details come from Classic data (CMaNGOS) and may differ in WoW Forever.|r",
      size = 11, wrap = true })
  end
  section(page, "Start and turn in")
  endpoint(page, q.st, "Starts")
  endpoint(page, q.en, "Turn in")
  section(page, "Rewards")
  local rw = q.rw
  if rw then
    if rw.xp then add(page, { text = MUTED .. "XP|r   " .. W.Thousands(rw.xp), size = 12 }) end
    if rw.m then add(page, { text = MUTED .. "Money|r   " .. FDB.Money(rw.m), size = 12 }) end
    for _, iid in ipairs(rw.i or {}) do
      add(page, { text = FDB.ItemText(iid), icon = itemIcon(iid), item = iid, onClick = link("items", iid) })
    end
    add(page, { text = "Seen in game by players' ForeverDB addons.", size = 10, color = "muted" })
  else
    add(page, { text = "Not in ForeverDB's data yet. The quest window in game shows them.", size = 11,
      color = "muted", wrap = true })
  end
  local nx = FDB.NextQuests(id)
  if q.pv or #nx > 0 then
    section(page, "Quest chain")
    local c = FDB.Chain(id)
    if c then
      add(page, { text = CHAIN .. FDB.ChainText(id) .. "|r", size = 12 })
      local notes = {}
      local from, into = c.line.from and FDB.Quest(c.line.from), c.line.into and FDB.Quest(c.line.into)
      if from then notes[#notes + 1] = "Branches off " .. from.n .. "." end
      if into then notes[#notes + 1] = "Leads into " .. into.n .. "." end
      if c.more then notes[#notes + 1] = "Carries on past level 30." end
      if c.earlier then notes[#notes + 1] = "Starts with quests above level 30, so the part can't be counted." end
      if c.line.unclear then notes[#notes + 1] = "The order in this chain is unclear, so it's by level." end
      if c.line.branch and not from and not into then
        notes[#notes + 1] = "Other quests branch off this chain; parts count along the longest path."
      end
      if #notes > 0 then add(page, { text = table.concat(notes, " "), size = 11, color = "muted", wrap = true }) end
    end
    if q.pv then
      add(page, { text = "Comes after", size = 11, color = "muted" })
      for _, p in ipairs(q.pv) do questLine(page, p, 8) end
    end
    if #nx > 0 then
      add(page, { text = "Leads to", size = 11, color = "muted" })
      for _, n in ipairs(nx) do questLine(page, n, 8) end
    end
  end
  credit(page, "More on this quest: " .. ns.FDB.URL .. "/quest/" .. id)
  return true
end

local function renderItem(page, id)
  local FDB = ns.FDB
  add(page, { text = FDB.ItemText(id), font = "title", size = 20, icon = itemIcon(id), item = id, gap = 2 })
  local e = ns.FDBData.items[id]
  local bits = {}
  if e and e[4] then bits[#bits + 1] = e[4] end
  if e and e[3] and e[3] > 0 then bits[#bits + 1] = "Requires level " .. e[3] end
  bits[#bits + 1] = "Item " .. id
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  local f = FDB.ItemFacts(id)
  if #f.soldBy > 0 then
    section(page, "Sold by")
    for _, s in ipairs(f.soldBy) do
      local v = FDB.Vendor(s.vendor)
      if v then
        local price = FDB.Money(s.price) .. ((s.stack or 1) > 1 and (" for " .. s.stack) or "")
        add(page, { text = v.n .. (v.t and ("  " .. MUTED .. "<" .. v.t .. ">|r") or "") .. (s.limited and ("  " .. WARN .. "limited|r") or ""),
          right = price, onClick = link("vendors", s.vendor),
          tip = { v.n, FDB.LocText(v.z, v.x, v.y) or "", FDB.SideText(v.s) } })
      end
    end
  end
  local function recipes(title, refs)
    if #refs == 0 then return end
    section(page, title)
    for k, ref in ipairs(refs) do
      if k > 30 then add(page, { text = ("and %d more"):format(#refs - 30), size = 11, color = "muted" }); break end
      local r, p = FDB.Recipe(ref)
      if r then
        add(page, { text = (r.mk and FDB.ItemText(r.mk) or r.n), right = p.n .. " " .. tostring(r.sk[1] or "?"),
          onClick = link("recipes", ref), tip = { r.n, "Click to open the recipe." } })
      end
    end
  end
  recipes("Made by", f.madeBy)
  recipes("Teaches", f.teaches)
  recipes("Reagent in", f.reagentFor)
  if #f.startsQuest > 0 then
    section(page, "Starts a quest")
    for _, qid in ipairs(f.startsQuest) do questLine(page, qid) end
  end
  if #f.dungeons > 0 then
    section(page, "Notable dungeon loot")
    for _, l in ipairs(f.dungeons) do
      local dg = FDB.Dungeon(l.dungeon)
      if dg then
        add(page, { text = dg.n .. ((l.why and l.why ~= "") and ("  " .. MUTED .. l.why .. "|r") or ""), wrap = true,
          onClick = link("dungeons", l.dungeon) })
      end
    end
  end
  local crafters = ns.Crafting and ns.Crafting.CraftersOfItem and ns.Crafting.CraftersOfItem(id)
  if crafters and #crafters > 0 then
    section(page, "Guild crafters")
    local names = {}
    for _, c in ipairs(crafters) do names[#names + 1] = ns.Compat.ShortName(c) or tostring(c) end
    add(page, { text = table.concat(names, ", "), wrap = true, size = 12, srcs = { "guild" } })
  end
  if page.used <= 2 then
    add(page, { text = "The bundle has nothing more on this item: no Forever vendor, recipe, quest or dungeon pick.",
      size = 11, color = "muted", wrap = true })
  end
  credit(page)
  return true
end

local function renderVendor(page, id)
  local FDB = ns.FDB
  local v = FDB.Vendor(id)
  if not v then return false end
  add(page, { text = v.n, font = "title", size = 20, gap = 2 })
  local bits = {}
  if v.t then bits[#bits + 1] = "<" .. v.t .. ">" end
  bits[#bits + 1] = FDB.LocText(v.z, v.x, v.y) or "Location unknown"
  bits[#bits + 1] = FDB.SideText(v.s)
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  if v.rf then
    add(page, { text = MUTED .. "Reputation discount|r   " .. v.rf .. " (5% at Friendly up to 20% at Exalted)", size = 11, wrap = true })
  end
  local starts, ends = FDB.QuestsForNpc(id)
  if starts or ends then
    section(page, "Quests")
    for _, qid in ipairs(starts or {}) do questLine(page, qid) end
    for _, qid in ipairs(ends or {}) do questLine(page, qid) end
  end
  local i = v.i or {}
  section(page, ("Sells (%d)"):format(#i / 4))
  if #i == 0 then add(page, { text = "No list recorded yet.", size = 11, color = "muted" }) end
  for k = 1, #i, 4 do
    local iid, price, stack, limited = i[k], i[k + 1], i[k + 2], i[k + 3] == 1
    add(page, { text = FDB.ItemText(iid) .. (limited and ("  " .. WARN .. "limited|r") or ""), icon = itemIcon(iid), item = iid,
      right = FDB.Money(price) .. ((stack or 1) > 1 and (" for " .. stack) or ""), onClick = link("items", iid) })
  end
  credit(page, "Prices in copper as players' ForeverDB addons saw them; reputation discounts not applied.")
  return true
end

local function npcName(prof, npcId)
  local FDB = ns.FDB
  for _, t in ipairs(prof.tr or {}) do if t.id == npcId then return t.n, FDB.LocText(t.z, t.x, t.y), t end end
  local v = FDB.Vendor(npcId)
  if v then return v.n, FDB.LocText(v.z, v.x, v.y), v end
  return "NPC " .. npcId
end

-- Trainers/vendors for a recipe: the player's own faction first, the other faction muted.
local function npcsBySide(prof, ids)
  local side, out = ns.FDB.PlayerSide(), {}
  for _, id in ipairs(ids or {}) do
    local n, loc, rec = npcName(prof, id)
    local npcSide = ns.FDB.NpcSide(rec)
    local own = not side or npcSide == "B" or npcSide == side
    out[#out + 1] = { id = id, n = n, loc = loc, own = own }
  end
  table.sort(out, function(a, b)
    if a.own ~= b.own then return a.own end
    if (a.loc or "") ~= (b.loc or "") then return (a.loc or "") < (b.loc or "") end
    return a.n < b.n
  end)
  return out
end

local function renderRecipe(page, key)
  local FDB = ns.FDB
  local ref = recipeRef(key)
  local r, p = FDB.Recipe(ref)
  if not r then return false end
  add(page, { text = r.mk and FDB.ItemText(r.mk) or r.n, font = "title", size = 20,
    icon = r.mk and itemIcon(r.mk) or nil, item = r.mk, gap = 2 })
  local bits = { p.n }
  if r.cat then bits[#bits + 1] = r.cat end
  if r.mc and r.mc > 1 then bits[#bits + 1] = "makes " .. r.mc end
  if r.new then bits[#bits + 1] = GOOD .. "new in WoW Forever|r" end
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  add(page, { text = MUTED .. "Skill|r   " .. FDB.SkillText(r.sk) .. "   " .. MUTED .. "(orange, yellow, green, grey)|r", size = 12 })
  if r.rl then add(page, { text = MUTED .. "Requires level|r   " .. r.rl, size = 12 }) end
  if r.rg then
    section(page, "Reagents")
    for k = 1, #r.rg, 2 do
      local iid, n = r.rg[k], r.rg[k + 1]
      add(page, { text = n .. "x  " .. FDB.ItemText(iid), icon = itemIcon(iid), item = iid, onClick = link("items", iid) })
    end
  end
  section(page, "How to learn it")
  add(page, { text = MUTED .. "From|r   " .. FDB.WaysText(r), size = 12 })
  if r.tc then add(page, { text = MUTED .. "Trainer cost|r   " .. FDB.Money(r.tc), size = 12 }) end
  if r.ri then
    add(page, { text = MUTED .. "Recipe|r   " .. FDB.ItemText(r.ri), icon = itemIcon(r.ri), item = r.ri, onClick = link("items", r.ri) })
  end
  for _, t in ipairs(npcsBySide(p, r.ts)) do
    local name = t.own and t.n or (MUTED .. t.n .. "  (other faction)|r")
    add(page, { text = MUTED .. "Trainer|r   " .. name, right = t.loc, size = 12 })
  end
  for _, v in ipairs(npcsBySide(p, r.vs)) do
    local name = v.own and v.n or (MUTED .. v.n .. "  (other faction)|r")
    add(page, { text = MUTED .. "Vendor|r   " .. name .. "  " .. LINK .. "(open)|r", right = v.loc, size = 12,
      onClick = link("vendors", v.id) })
  end
  add(page, { text = "Only trainers and vendors seen in WoW Forever are listed.", size = 10, color = "muted" })
  local crafters = r.mk and ns.Crafting and ns.Crafting.CraftersOfItem and ns.Crafting.CraftersOfItem(r.mk)
  if crafters and #crafters > 0 then
    section(page, "Guild crafters")
    local names = {}
    for _, c in ipairs(crafters) do names[#names + 1] = ns.Compat.ShortName(c) or tostring(c) end
    add(page, { text = table.concat(names, ", "), wrap = true, size = 12, srcs = { "guild" } })
  end
  credit(page, "More on this profession: " .. ns.FDB.URL .. "/profession/" .. ref.prof)
  return true
end

local function renderDungeon(page, id)
  local FDB = ns.FDB
  local dg = FDB.Dungeon(id)
  if not dg then return false end
  add(page, { text = dg.n, font = "title", size = 20, gap = 2 })
  local bits = { dg.k == "raid" and "Raid" or "Dungeon" }
  if dg.p then bits[#bits + 1] = dg.p .. " players" end
  bits[#bits + 1] = "Levels " .. FDB.DungeonLevelText(dg)
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  if dg.new then
    add(page, { text = GOOD .. "New in WoW Forever.|r", size = 11 })
  elseif dg.st == "classic" then
    add(page, { text = WARN .. "Level range and bosses from Classic data, may differ in WoW Forever.|r", size = 11, wrap = true })
  end
  if dg.b then
    section(page, "Bosses")
    for _, b in ipairs(dg.b) do add(page, { text = b, size = 12 }) end
  end
  if dg.lo then
    section(page, "Notable loot")
    for _, l in ipairs(dg.lo) do
      add(page, { text = FDB.ItemText(l[1]) .. ((l[2] and l[2] ~= "") and ("  " .. MUTED .. l[2] .. "|r") or ""),
        icon = itemIcon(l[1]), item = l[1], wrap = true, onClick = link("items", l[1]) })
    end
    add(page, { text = "ForeverDB's picks, not a drop table. Drops the guild records show in the Bestiary.",
      size = 10, color = "muted", wrap = true })
  end
  credit(page)
  return true
end

local RENDER = { quests = renderQuest, items = renderItem, vendors = renderVendor, recipes = renderRecipe, dungeons = renderDungeon }

function Tab.Render(page, mode, key)
  page.mode, page.key = mode, key
  page.used, page.y = 0, 0
  local ok = key ~= nil and ns.FDB.Available() and RENDER[mode](page, key)
  if not ok then
    for _, l in ipairs(page.lines) do l:Hide() end
    page.empty:SetText(ns.FDB.Available() and "Pick something on the left."
      or "The ForeverDB data files are missing from this install.")
    page.empty:Show()
    page.child:SetHeight(10)
    return
  end
  page.empty:Hide()
  for i = page.used + 1, #page.lines do page.lines[i]:Hide() end
  page.child:SetHeight(page.y + 6)
  if page.lastKey ~= tostring(mode) .. tostring(key) then page.scroll:SetVerticalScroll(0) end
  page.lastKey = tostring(mode) .. tostring(key)
end

---------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------
local function cycle(cur, n, button)
  return (cur - 1 + (button == "RightButton" and n - 1 or 1)) % n + 1
end

UI.RegisterTab({
  id = "quests", label = "Quests & Items", order = 62,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    -- mode buttons across the top
    p.modes = {}
    local bw = (T.sizes.content.w - 4 * 4) / #Tab.MODES
    for i, m in ipairs(Tab.MODES) do
      local b = W.Button(p, m.label, bw, 22, function()
        view.mode = m.key
        Tab.Refresh()
      end)
      b:SetPoint("TOPLEFT", (i - 1) * (bw + 4), 0)
      p.modes[m.key] = b
    end

    local left = W.Panel(p, "panel", "border")
    left:SetPoint("TOPLEFT", 0, -28)
    left:SetPoint("BOTTOMLEFT", 0, 30)
    left:SetWidth(LIST_W)
    p.search = W.SearchBox(left, LIST_W - 12, Tab.MODES[1].search, function(text)
      view.search[view.mode] = text
      UI.Refresh("quests")
    end)
    p.search:SetPoint("TOPLEFT", 6, -6)
    local third = (LIST_W - 20) / 3
    local function filterButton(w, onClick)
      local b = W.Button(left, "", w, 20, onClick)
      if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
      return b
    end
    p.f1 = filterButton(third, function(_, button)
      if view.mode == "recipes" then
        local _, _, n = profAt(1)
        view.prof = cycle(view.prof + 1, n + 1, button) - 1
      else
        view.zone = not view.zone
      end
      UI.Refresh("quests")
    end)
    p.f1:SetPoint("TOPLEFT", 6, -34)
    p.f2 = filterButton(third, function(_, button)
      if view.mode == "recipes" then view.skill = cycle(view.skill, #Tab.SKILLS, button)
      else view.level = cycle(view.level, #Tab.LEVELS, button) end
      UI.Refresh("quests")
    end)
    p.f2:SetPoint("LEFT", p.f1, "RIGHT", 4, 0)
    p.f3 = filterButton(third, function()
      view.mine = not view.mine
      UI.Refresh("quests")
    end)
    p.f3:SetPoint("LEFT", p.f2, "RIGHT", 4, 0)
    p.count = W.Text(left, "narrow", 10, "muted")
    p.count:SetPoint("TOPLEFT", 8, -60)
    p.count:SetWidth(LIST_W - 16)
    p.list = W.List(left, 20, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 2, -76)
    p.list:SetPoint("BOTTOMRIGHT", -2, 4)

    local right = W.Panel(p, "panel", "border")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 30)
    local width = T.sizes.content.w - LIST_W - 8 - 20
    p.back = W.IconButton(right, "<", "Back", function() Tab.Back() end, 18)
    p.back:SetPoint("TOPRIGHT", -6, -6)
    p.page = MobPage.New(right, width - 20)
    p.page:SetPoint("TOPLEFT", 12, -10)
    p.page:SetPoint("BOTTOMRIGHT", -26, 8)

    -- the credit, always visible under the tab
    p.credit = W.Text(p, "body", 11, "gold")
    p.credit:SetPoint("BOTTOMLEFT", 2, 8)
    p.credit:SetText(ns.FDB.CREDIT)
    p.url = W.CopyBox(p, 170, ns.FDB.URL)
    p.url:SetPoint("LEFT", p.credit, "RIGHT", 8, 0)
    p.snap = W.Text(p, "narrow", 10, "muted")
    p.snap:SetPoint("LEFT", p.url, "RIGHT", 8, 0)
    p.snap:SetPoint("RIGHT", p, "RIGHT", -2, 0)
    p.snap:SetWordWrap(false)

    local rerender = ns.Debounce(0.3, function()
      if p:IsVisible() and p.page.key then Tab.Render(p.page, p.page.mode, p.page.key) end
      if p:IsVisible() and (view.mode == "items" or view.mode == "recipes") then p.list:Refresh() end
    end)
    ns:On("GET_ITEM_INFO_RECEIVED", function() rerender() end)
    ns:On("ZONE_CHANGED_NEW_AREA", function() if view.zone then Tab.Refresh() end end)
    return p
  end,
  refresh = function(p)
    local FDB = ns.FDB
    local m = modeInfo(view.mode)
    for key, b in pairs(p.modes) do b:SetActive(key == view.mode) end
    if p.search.hint then p.search.hint:SetText(m.search) end
    if p.search.SetText and p.search:GetText() ~= (view.search[view.mode] or "") then
      p.search:SetText(view.search[view.mode] or "")
    end
    -- filters for this mode
    p.f1:Show(); p.f2:Show(); p.f3:Show()
    if view.mode == "quests" or view.mode == "vendors" then
      p.f1.label:SetText(view.zone and "This zone" or "All zones")
      p.f1:SetActive(view.zone)
      p.f1.tip = "Only what's in the zone you're in, or everywhere."
      p.f3.label:SetText(view.mine and "My faction" or "Both factions")
      p.f3:SetActive(view.mine)
      p.f3.tip = "Hide what the other faction gets."
      if view.mode == "quests" then
        local lv = Tab.LEVELS[view.level]
        p.f2.label:SetText(lv.label)
        p.f2:SetActive(lv.key ~= "all")
        p.f2.tip = "Levels: near yours (3 either side), all, or a band. Right-click goes back."
      else
        p.f2:Hide()
      end
    elseif view.mode == "recipes" then
      local slug, prof = profAt(view.prof)
      p.f1.label:SetText(view.prof > 0 and prof and prof.n or "All")
      p.f1:SetActive(view.prof > 0 and slug ~= nil)
      p.f1.tip = "Profession. Right-click goes back."
      p.f2.label:SetText(Tab.SKILLS[view.skill].label)
      p.f2:SetActive(view.skill > 1)
      p.f2.tip = "Recipes you can learn up to this skill. Right-click goes back."
      p.f3:Hide()
    else
      p.f1:Hide(); p.f2:Hide(); p.f3:Hide()
    end

    local items = FDB.Available() and Tab.Items() or {}
    p.list:SetItems(items)
    local noun = ({ quests = "quest", items = "item", vendors = "vendor", recipes = "recipe", dungeons = "dungeon" })[view.mode]
    local text = ("%d %s%s"):format(#items, noun, #items == 1 and "" or "s")
    if view.mode == "vendors" then text = text .. ", seen in WoW Forever" end
    if view.mode == "quests" and (view.zone and playerZone()) then text = text .. " in " .. playerZone() end
    p.count:SetText(text)
    local sel = Tab.selected[view.mode]
    if sel == nil and items[1] then
      sel = items[1].key
      Tab.selected[view.mode] = sel
    end
    p.back:SetShown(#Tab.history > 0)
    p.snap:SetText(("Snapshot %s. Not covered by this addon's license."):format(tostring(FDB.Snapshot() or "?")))
    Tab.Render(p.page, view.mode, sel)
  end,
})
