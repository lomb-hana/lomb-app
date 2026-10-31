-- LOMB Companion: the Loot browser, the "Loot" view in Quests & Items.
-- Pick a dungeon or raid, then the whole instance, a boss or the trash, and see the items
-- as an icon grid. Data: Modules/Loot.lua (ForeverDB.net notable loot + what the guild saw drop).
local _, ns = ...
local Tab, MobPage, Loot = ns.QuestsTab, ns.MobPage, ns.Loot
local H = Tab.H
local add, section, credit, link = H.add, H.section, H.credit, H.link
local MUTED, WARN, GOOD, LINK = H.MUTED, H.WARN, H.GOOD, H.LINK

local KINDS = {
  { label = "Dungeons & raids" },
  { label = "Dungeons", kind = "dungeon" },
  { label = "Raids", kind = "raid" },
}
local QUALITIES = {
  { label = "Any quality" },
  { label = "Uncommon+", min = 2 },
  { label = "Rare+", min = 3 },
  { label = "Epic+", min = 4 },
}
Tab.LOOT_KINDS, Tab.LOOT_QUALITIES = KINDS, QUALITIES

local function has(s, needle) return needle == "" or tostring(s or ""):lower():find(needle, 1, true) ~= nil end

local function lootHit(dg, needle)
  for _, l in ipairs(dg.lo or {}) do
    local name = ns.Compat.ItemInfo(l[1])
    if not name then local e = ns.FDBData.items and ns.FDBData.items[l[1]]; name = e and e[1] end
    if has(name, needle) then return true end
  end
end

local function rows(search, view)
  local FDB = ns.FDB
  local needle = (search or ""):lower()
  local kind = KINDS[view.lootKind or 1].kind
  local selDid = Loot.ParseKey(Tab.selected.dungeons)
  local out = {}
  for id, dg in pairs(ns.FDBData.dungeons or {}) do
    if (not kind or dg.k == kind) then
      local bossHit = {}
      local ok = has(dg.n, needle)
      for i, b in ipairs(dg.b or {}) do if needle ~= "" and has(b, needle) then bossHit[i] = true; ok = true end end
      if not ok and needle ~= "" and lootHit(dg, needle) then ok = true end
      if ok then out[#out + 1] = { id = id, d = dg, bossHit = bossHit } end
    end
  end
  table.sort(out, function(a, b)
    local la, lb = a.d.lr and a.d.lr[1] or a.d.lv or 99, b.d.lr and b.d.lr[1] or b.d.lv or 99
    if la ~= lb then return la < lb end
    return a.d.n < b.d.n
  end)
  local items = {}
  for _, e in ipairs(out) do
    local dg = e.d
    items[#items + 1] = { key = e.id, text = dg.n,
      meta = (dg.k == "raid" and ("Raid " .. (dg.p or "")) or FDB.DungeonLevelText(dg)),
      tip = { dg.n, (Loot.KIND_LABEL[dg.k] or "Instance") .. ", levels " .. FDB.DungeonLevelText(dg) .. ".",
        "Click for the whole " .. (dg.k == "raid" and "raid" or "dungeon") .. "; its bosses open below it." } }
    if e.id == selDid or next(e.bossHit) then
      for i, b in ipairs(dg.b or {}) do
        if e.id == selDid or e.bossHit[i] then
          items[#items + 1] = { key = Loot.Key(e.id, i), text = b, indent = 1 }
        end
      end
      if e.id == selDid then
        items[#items + 1] = { key = Loot.Key(e.id, "trash"), text = MUTED .. "Trash|r", indent = 1,
          tip = { "Trash", "Recorded loot from the mobs here that aren't bosses." } }
      end
    end
  end
  return items
end

local function tipFor(e, dg)
  local t = {}
  if e.notable then t[#t + 1] = "|cfff2c75cForeverDB.net notable loot|r" .. (e.why and (": " .. e.why) or "") end
  if e.seen > 0 then
    t[#t + 1] = "|cffb873ffLOMB saw it drop: " .. e.seen .. "|r"
    if #e.from > 0 then
      local from = {}
      for i = 1, math.min(3, #e.from) do from[i] = e.from[i] end
      t[#t + 1] = "From " .. table.concat(from, ", ") .. (#e.from > 3 and (" and " .. (#e.from - 3) .. " more") or "")
    end
  else
    t[#t + 1] = "LOMB hasn't seen it drop yet."
  end
  if e.note then t[#t + 1] = e.note end
  for _, b in ipairs(Loot.Badges(e.itemID, dg)) do t[#t + 1] = b end
  return t
end

local function cells(list, did, minQ)
  local out = {}
  for _, e in ipairs(list) do
    if not minQ or (e.q or 0) >= minQ then
      local _, _, _, icon = ns.Compat.ItemInfo(e.itemID)
      local badges = Loot.Badges(e.itemID, did)
      out[#out + 1] = {
        item = e.itemID, icon = icon, q = e.q,
        count = e.seen > 0 and tostring(e.seen) or nil,
        badge = badges[1], wanted = Loot.Wanted(e.itemID), tip = tipFor(e, did),
        onWant = function(d)
          local now, why = Loot.ToggleWant(d.item, Tab.LootNote(did))
          if now == nil and why then ns:Print(why) end
          Tab.Refresh()
        end,
      }
    end
  end
  return out
end

-- note saved with a wishlist entry made from the browser ("Deadmines")
function Tab.LootNote(did)
  local dg = ns.FDB.Dungeon(did)
  return dg and dg.n or nil
end

local function render(page, key)
  local FDB = ns.FDB
  local did, part = Loot.ParseKey(key)
  local dg = did and FDB.Dungeon(did)
  if not dg then return false end
  local minQ = QUALITIES[Tab.view.lootQ or 1].min
  local raid = dg.k == "raid"
  add(page, { text = dg.n, font = "title", size = 20, gap = 2 })
  local bits = { Loot.KIND_LABEL[dg.k] or "Instance" }
  if dg.p then bits[#bits + 1] = dg.p .. " players" end
  bits[#bits + 1] = "Levels " .. FDB.DungeonLevelText(dg)
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  if dg.new then
    add(page, { text = GOOD .. "New in WoW Forever.|r", size = 11 })
  elseif dg.st == "classic" then
    add(page, { text = WARN .. "Level range and bosses from Classic data, may differ in WoW Forever.|r", size = 11, wrap = true })
  end

  local res = Loot.For(did, part)
  local notable, guild = {}, {}
  for _, e in ipairs(res.items) do
    if e.notable then notable[#notable + 1] = e elseif e.seen > 0 or e.note then guild[#guild + 1] = e end
  end

  if part == "all" then
    section(page, "Notable loot")
    if #notable > 0 then
      MobPage.AddGrid(page, cells(notable, did, minQ))
      add(page, { text = "ForeverDB.net's picks for this " .. (raid and "raid" or "dungeon") ..
        ": not the full loot table, no drop rates, and not tied to a boss.", size = 10, color = "muted", wrap = true,
        srcs = { "foreverdb" } })
    else
      add(page, { text = "ForeverDB.net lists no notable loot here yet.", size = 11, color = "muted", wrap = true })
    end
  else
    local name = Loot.PartName(did, part)
    section(page, part == "trash" and "Trash" or name)
    if part ~= "trash" then
      add(page, { text = "ForeverDB.net doesn't say which boss drops what. Its notable loot is on " .. LINK ..
        Loot.PartName(did, "all") .. "|r.", size = 10, color = "muted", wrap = true, onClick = link("dungeons", did) })
      local npc = Loot.BossMob(did, part)
      if npc then
        add(page, { text = LINK .. "Open " .. name .. " in the Bestiary|r", size = 11,
          onClick = function() ns.UI.Open("bestiary"); ns.BestiaryTab.Select(npc) end })
      end
    end
  end

  section(page, part == "all" and "Seen dropping by LOMB" or "What LOMB saw drop")
  local g = cells(guild, did, minQ)
  if #g > 0 then
    MobPage.AddGrid(page, g)
    add(page, { text = ("%d item%s from %d mob%s, %d corpse%s looted by guildmates with LOMB on. Not in ForeverDB's list.")
      :format(#guild, #guild == 1 and "" or "s", res.mobs, res.mobs == 1 and "" or "s", res.corpses, res.corpses == 1 and "" or "s"),
      size = 10, color = "muted", wrap = true, srcs = { "guild" } })
  elseif #guild > 0 then
    add(page, { text = "Nothing at this quality. Change the quality filter to see the rest.", size = 11, color = "muted", wrap = true })
  else
    add(page, { text = "Nobody in the guild has recorded loot here yet. Loot with LOMB on and it shows up here.",
      size = 11, color = "muted", wrap = true })
  end
  add(page, { text = "Hover for details · click opens the item · shift-click links it · ctrl-click previews · heart adds it to your wishlist.",
    size = 10, color = "muted", wrap = true })
  if raid then
    add(page, { text = "Raids open in WoW Forever on December 9.", size = 10, color = "muted", wrap = true })
  end
  credit(page, "More on this " .. (raid and "raid" or "dungeon") .. ": " .. FDB.URL .. "/dungeon/" .. did)
  return true
end

local m = Tab.ModeInfo("dungeons")
m.items, m.render = rows, render
m.empty = "Pick a dungeon or raid on the left."
m.count = function(items)
  local n = 0
  for _, it in ipairs(items) do if not it.indent then n = n + 1 end end
  return ("%d instance%s · notable loot + guild drops"):format(n, n == 1 and "" or "s")
end
m.filters = function(p, view)
  p.f1.label:SetText(KINDS[view.lootKind or 1].label); p.f1:SetActive((view.lootKind or 1) > 1)
  p.f1.tip = "Dungeons, raids or both. Right-click goes back."
  p.f2.label:SetText(QUALITIES[view.lootQ or 1].label); p.f2:SetActive((view.lootQ or 1) > 1)
  p.f2.tip = "Hide items below this quality. Right-click goes back."
  p.f3:Hide()
end
m.filter = function(which, button, view)
  if which == 1 then view.lootKind = H.cycle(view.lootKind or 1, #KINDS, button); Tab.selected.dungeons = nil
  elseif which == 2 then view.lootQ = H.cycle(view.lootQ or 1, #QUALITIES, button) end
end
m.onShow = function(_, view) view.lootKind = 1 end

-- the wishlist changing anywhere repaints the hearts
ns:Listen("WISHLIST_UPDATED", function()
  if Tab.panel and Tab.panel:IsVisible() and Tab.view.mode == "dungeons" then Tab.Refresh() end
end)
