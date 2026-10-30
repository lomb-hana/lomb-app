-- LOMB Companion: more Quests & Items modes over the bundled ForeverDB.net data --
-- Zones (and battlegrounds), Training (and rogue poisons), Gathering and Sets --
-- plus the disenchant / set / gathering sections on item pages. Lookups live in
-- Modules/Guides.lua; every page ends with the ForeverDB.net credit and link.
local _, ns = ...
local Tab = ns.QuestsTab
local G = ns.Guides
local H = Tab.H
local add, section, credit, link, itemIcon = H.add, H.section, H.credit, H.link, H.itemIcon
local MUTED, WARN, GOOD, LINK = H.MUTED, H.WARN, H.GOOD, H.LINK

local function FDB() return ns.FDB end
local function classic() return "  " .. WARN .. FDB().CLASSIC_NOTE .. "|r" end

-- open a creature: the bestiary if the guild has a record, else the standalone page
local function openMob(npcId)
  return function()
    if ns.db and ns.db.bestiary and ns.db.bestiary[npcId] and ns.BestiaryTab then
      ns.UI.Open("bestiary"); ns.BestiaryTab.Select(npcId)
    elseif ns.MobPage and ns.MobPage.OpenStandalone then
      ns.MobPage.OpenStandalone(npcId)
    end
  end
end
Tab.H.openMob = openMob

local function zoneLink(name)
  local id = name and G.ZoneByName(name)
  return id and link("zones", id) or nil
end

local function plural(n, word) return ("%d %s%s"):format(n, word, n == 1 and "" or "s") end

---------------------------------------------------------------------------
-- Training
---------------------------------------------------------------------------
G.BANDS = {
  { label = "All levels" },
  { label = "Levels 1-10", min = 1, max = 10 },
  { label = "Levels 11-20", min = 11, max = 20 },
  { label = "Levels 21-30", min = 21, max = 30 },
}

-- class picked in the filter (0 = this character's class)
local function viewClass(view)
  local list = G.ClassList()
  if (view.cls or 0) > 0 and list[view.cls] then return list[view.cls].key, list[view.cls].n end
  local mine = G.PlayerClass()
  local c = G.Class(mine)
  if c then return mine, c.n end
  return list[1] and list[1].key, list[1] and list[1].n
end
local function isMine(classFile) return classFile == G.PlayerClass() end

local function statusText(e, classFile)
  if not isMine(classFile) then return "" end
  local k = G.IsKnown(e.spell)
  if k == true then return GOOD .. "known|r" end
  local pl = G.PlayerLevel() or 0
  if e.level <= pl then return k == false and "|cffffd36btrain now|r" or (MUTED .. "can't tell|r") end
  return ""
end

local function trainingItems(search, view)
  local out = {}
  local classFile, className = viewClass(view)
  if not classFile then return out end
  local band = G.BANDS[view.band or 1]
  local side = FDB().PlayerSide()
  local needle = search or ""
  if needle ~= "" or view.pet then
    local seen = {}
    for _, e in ipairs(G.Ranks({ class = classFile, search = needle, side = side, pet = view.pet,
        minLevel = band.min, maxLevel = band.max })) do
      if not seen[e.name] then
        seen[e.name] = true
        out[#out + 1] = { key = "ab:" .. e.name, text = e.name, meta = (e.ab.ln or "") .. "  " .. e.level }
      end
    end
    return out
  end
  if isMine(classFile) then
    local plan = G.TrainingPlan(classFile)
    out[#out + 1] = { key = "now", text = "Train now", meta = #plan.now > 0 and ("|cffffd36b" .. #plan.now .. "|r") or (GOOD .. "all done|r"),
      tip = { "Train now", "What your class trainer has for you at your level." } }
  end
  if classFile == "ROGUE" and G.Poisons() then
    out[#out + 1] = { key = "poisons", text = "Poisons", meta = "level " .. tostring(G.Poisons().skill and G.Poisons().skill.lv or 20) }
  end
  if classFile == "HUNTER" then
    out[#out + 1] = { key = "pet", text = "Pet skills", meta = "Beast Training" }
  end
  local byLevel = {}
  for _, e in ipairs(G.Ranks({ class = classFile, side = side, minLevel = band.min, maxLevel = band.max })) do
    byLevel[e.level] = (byLevel[e.level] or 0) + 1
  end
  local pl = G.PlayerLevel() or 0
  for lv = 1, 30 do
    if byLevel[lv] then
      local mine = isMine(classFile) and lv <= pl
      out[#out + 1] = { key = "lv:" .. lv, text = (mine and MUTED or "") .. "Level " .. lv .. (mine and "|r" or ""),
        meta = plural(byLevel[lv], "rank"), tip = { className .. ", level " .. lv } }
    end
  end
  return out
end

local function rankLine(page, e, classFile)
  local cost = G.Cost(classFile, e.name, e.rank)
  local right = cost and FDB().Money(cost) or (e.quest and "quest" or "")
  local st = statusText(e, classFile)
  add(page, { text = G.RankText(e) .. (st ~= "" and ("  " .. st) or "") .. (e.ab.new and ("  " .. GOOD .. "new in Forever|r") or ""),
    right = right, size = 12, onClick = link("training", "ab:" .. e.name),
    tip = { G.RankText(e), "Level " .. e.level .. (e.ab.ln and (" · " .. e.ab.ln) or ""), "Spell " .. e.spell,
      cost and "Cost noted at your class trainer." or "Cost: open your class trainer once and the addon notes it." } })
end

local function trainingFooter(page, classFile)
  local costs = ns.db.trainerCosts and ns.db.trainerCosts[classFile]
  local any = costs and next(costs) ~= nil
  add(page, { text = (any and "Costs are what your class trainer showed when you last opened it. " or
    "ForeverDB has no trainer costs; open your class trainer once and they show here. ")
    .. "\"Known\" comes from the game's spellbook checks, which haven't been tried on the live servers yet (Nov 4).",
    size = 10, color = "muted", wrap = true, gap = 4 })
end

local function renderTraining(page, key)
  local view = Tab.view
  local classFile, className = viewClass(view)
  local c = G.Class(classFile)
  if not c then return false end
  local side = FDB().PlayerSide()
  if key == "now" then
    local plan = G.TrainingPlan(classFile)
    add(page, { text = "Train now", font = "title", size = 20, gap = 2 })
    add(page, { text = ("%s · level %d"):format(className, G.PlayerLevel() or 1), size = 12, color = "muted", gap = 4 })
    section(page, plural(#plan.now, "rank") .. " to learn")
    if #plan.now == 0 then add(page, { text = GOOD .. "Nothing waiting at your trainer.|r", size = 12 }) end
    for _, e in ipairs(plan.now) do rankLine(page, e, classFile) end
    if plan.unsure > 0 then
      add(page, { text = plural(plan.unsure, "rank") .. " the game didn't say whether you know. Open your trainer to check.",
        size = 10, color = "muted", wrap = true })
    end
    if plan.next then
      section(page, "Next, at level " .. plan.next)
      for _, e in ipairs(plan.nextList) do rankLine(page, e, classFile) end
    end
    trainingFooter(page, classFile)
    credit(page, "Class abilities: " .. FDB().URL .. "/class/" .. c.n)
    return true
  elseif key == "poisons" then
    return Tab.RenderPoisons(page)
  elseif key == "pet" then
    add(page, { text = "Pet skills", font = "title", size = 20, gap = 2 })
    add(page, { text = "Hunter · Beast Training (taught to your pet)", size = 12, color = "muted", gap = 4 })
    local last
    for _, e in ipairs(G.Ranks({ class = classFile, pet = true, side = side })) do
      if e.name ~= last then section(page, e.name); last = e.name end
      add(page, { text = G.RankText(e), right = "level " .. e.level, size = 12, indent = 8 })
    end
    credit(page)
    return true
  end
  local lv = tonumber(tostring(key):match("^lv:(%d+)$"))
  if lv then
    add(page, { text = "Level " .. lv, font = "title", size = 20, gap = 2 })
    add(page, { text = className .. " · new at your class trainer", size = 12, color = "muted", gap = 4 })
    section(page, "New ranks")
    for _, e in ipairs(G.Ranks({ class = classFile, minLevel = lv, maxLevel = lv, side = side })) do rankLine(page, e, classFile) end
    local pets = G.Ranks({ class = classFile, minLevel = lv, maxLevel = lv, pet = true, side = side })
    if #pets > 0 then
      section(page, "Pet skills")
      for _, e in ipairs(pets) do add(page, { text = G.RankText(e), size = 12 }) end
    end
    trainingFooter(page, classFile)
    credit(page)
    return true
  end
  local name = tostring(key):match("^ab:(.+)$")
  if not name then return false end
  local ranks = G.Ranks({ class = classFile, search = name:lower(), side = side, pet = nil })
  local pets = G.Ranks({ class = classFile, search = name:lower(), side = side, pet = true })
  local list = {}
  for _, e in ipairs(#ranks > 0 and ranks or pets) do if e.name == name then list[#list + 1] = e end end
  if #list == 0 then return false end
  local ab = list[1].ab
  add(page, { text = name, font = "title", size = 20, gap = 2 })
  local bits = { className }
  if ab.ln then bits[#bits + 1] = ab.ln end
  if ab.q == 1 then bits[#bits + 1] = "learned from a quest" end
  if ab.pet == 1 then bits[#bits + 1] = "pet skill" end
  if ab.new then bits[#bits + 1] = GOOD .. "new in WoW Forever|r" end
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  section(page, "Ranks")
  for _, e in ipairs(list) do
    local cost = G.Cost(classFile, e.name, e.rank)
    local st = statusText(e, classFile)
    add(page, { text = ("Level %d   %s"):format(e.level, e.rank > 0 and ("Rank " .. e.rank) or "")
      .. (st ~= "" and ("  " .. st) or ""), right = cost and FDB().Money(cost) or "", size = 12,
      tip = { G.RankText(e), "Spell " .. e.spell } })
  end
  trainingFooter(page, classFile)
  credit(page, "More: " .. FDB().URL .. "/spell/" .. list[1].spell)
  return true
end

function Tab.RenderPoisons(page)
  local P = G.Poisons()
  if not P then return false end
  add(page, { text = "Rogue poisons", font = "title", size = 20, gap = 2 })
  local sk = P.skill or {}
  add(page, { text = ("Poisons is learned at level %s, from a class quest."):format(tostring(sk.lv or "?")), size = 12, color = "muted", gap = 4 })
  if sk.q then
    section(page, "The Poisons quest")
    local side = FDB().PlayerSide()
    for _, q in ipairs(sk.q) do
      local own = not side or q[3] == "B" or q[3] == side
      local text = (own and q[2] or (MUTED .. q[2] .. "|r")) .. "  " .. MUTED .. FDB().SideText(q[3]) .. "|r"
      add(page, { text = text, size = 12, onClick = FDB().Quest(q[1]) and link("quests", q[1]) or nil })
    end
  end
  section(page, "Poisons up to level 30")
  for _, x in ipairs(P.list or {}) do
    add(page, { text = (x.mk and FDB().ItemText(x.mk) or x.n), icon = x.mk and itemIcon(x.mk) or nil, item = x.mk,
      right = "level " .. tostring(x.lv) .. (x.sk and (" · skill " .. x.sk) or ""), onClick = x.mk and link("items", x.mk) or nil })
    local bits = {}
    if x.rg then
      local rg = {}
      for k = 1, #x.rg, 2 do rg[#rg + 1] = x.rg[k + 1] .. "x " .. FDB().ItemName(x.rg[k]) end
      bits[#bits + 1] = table.concat(rg, ", ")
    end
    if x.tc then bits[#bits + 1] = "trainer " .. FDB().Money(x.tc) end
    if x.ws then bits[#bits + 1] = "comes with the skill" end
    add(page, { text = table.concat(bits, "  ·  "), size = 11, color = "muted", indent = 20, wrap = true })
  end
  if (P.more or 0) > 0 then
    add(page, { text = ("%d more above level 30 on ForeverDB."):format(P.more), size = 10, color = "muted" })
  end
  if P.suppliers and #P.suppliers > 0 then
    section(page, "Poison suppliers seen in WoW Forever")
    for _, s in ipairs(P.suppliers) do
      add(page, { text = s.n .. "  " .. MUTED .. FDB().SideText(s.s) .. "|r", right = FDB().LocText(s.z, s.x, s.y), size = 12,
        onClick = FDB().Vendor(s.id) and link("vendors", s.id) or nil })
    end
  end
  if P.trainers and #P.trainers > 0 then
    section(page, "Rogue trainers seen in WoW Forever")
    for _, t in ipairs(P.trainers) do
      add(page, { text = t.n .. "  " .. MUTED .. FDB().SideText(t.s) .. "|r", right = FDB().LocText(t.z, t.x, t.y), size = 12 })
    end
  end
  credit(page, "More: " .. (P.url or FDB().URL))
  return true
end

Tab.AddMode({
  key = "training", label = "Training", search = "Search abilities", noun = "row", empty = "Pick a row on the left.",
  items = trainingItems, render = renderTraining,
  count = function(items, view)
    local _, n = viewClass(view)
    return (n or "?") .. ": " .. ((Tab.view.search.training or "") ~= "" and plural(#items, "ability") or "what's new by level")
  end,
  filters = function(p, view)
    local _, n = viewClass(view)
    p.f1.label:SetText(n or "Class"); p.f1:SetActive((view.cls or 0) > 0)
    p.f1.tip = "Class (yours first). Right-click goes back."
    p.f2.label:SetText(G.BANDS[view.band or 1].label); p.f2:SetActive((view.band or 1) > 1)
    p.f2.tip = "Level band. Right-click goes back."
    local cf = viewClass(view)
    if cf == "HUNTER" then
      p.f3.label:SetText(view.pet and "Pet skills" or "Your skills"); p.f3:SetActive(view.pet == true)
      p.f3.tip = "Your abilities, or your pet's (Beast Training)."
    else
      p.f3:Hide()
    end
  end,
  filter = function(which, button, view)
    if which == 1 then
      view.cls = H.cycle((view.cls or 0) + 1, #G.ClassList() + 1, button) - 1
      view.pet = nil
    elseif which == 2 then
      view.band = H.cycle(view.band or 1, #G.BANDS, button)
    else
      view.pet = not view.pet or nil
    end
    Tab.selected.training = nil
  end,
  onShow = function(_, view) view.search.training = view.search.training or "" end,
})

---------------------------------------------------------------------------
-- Gathering
---------------------------------------------------------------------------
G.GSKILLS = {
  { label = "Any skill" },
  { label = "My skill", mine = true },
  { label = "Skill 1-75", min = 0, max = 75 },
  { label = "Skill 76-150", min = 76, max = 150 },
  { label = "Skill 151-225", min = 151, max = 225 },
}

local function viewProf(view)
  view.gprof = view.gprof or G.DefaultProf()
  return G.PROFS[view.gprof]
end

local function skillRange(view, slug)
  local b = G.GSKILLS[view.gskill or 1]
  if b.mine then
    local mine = G.PlayerSkill(slug)
    return nil, mine or 0
  end
  return b.min, b.max
end

local function canText(need, slug)
  local mine = G.PlayerSkill(slug)
  local ok = G.CanGather(need, mine)
  if ok == "yes" then return GOOD .. "you can|r" elseif ok == "no" then return WARN .. "need " .. need .. "|r" end
  return ""
end

local function gatherItems(search, view)
  local slug = viewProf(view)
  local lo, hi = skillRange(view, slug)
  local out = {}
  local g = G.Gathering(slug)
  if not g then return out end
  if (search or "") == "" and g.best then
    out[#out + 1] = { key = "best", text = "Where to level " .. G.PROF_NAME[slug], meta = "best zones" }
  end
  if slug == "herbalism" or slug == "mining" then
    for _, e in ipairs(G.Nodes(slug, { search = search, minSkill = lo, maxSkill = hi })) do
      out[#out + 1] = { key = "n:" .. e.i, text = e.n.it and FDB().ItemText(e.n.it) or e.n.n,
        meta = tostring(e.n.sk) .. (e.n.new and (" " .. GOOD .. "new|r") or ""), itemID = e.n.it }
      if e.n.it and e.n.n ~= FDB().ItemName(e.n.it) then out[#out].text = e.n.n end
    end
  else
    for _, e in ipairs(G.GatherZones(slug, { search = search, minSkill = lo, maxSkill = hi })) do
      local meta = slug == "skinning" and (e.z.lv and ("lv " .. e.z.lv[1] .. "-" .. e.z.lv[2]) or "") or ("skill " .. e.skill)
      out[#out + 1] = { key = "z:" .. e.name, text = e.name, meta = meta }
    end
  end
  return out
end

local function noteLine(page, g)
  if g and g.note then add(page, { text = g.note, size = 10, color = "muted", wrap = true, gap = 4 }) end
end

local function mySkillLine(page, slug)
  local rank, max = G.PlayerSkill(slug)
  add(page, { text = MUTED .. "Your " .. G.PROF_NAME[slug] .. "|r   " .. (rank and (rank .. " / " .. (max or rank))
    or "not learned on this character"), size = 12 })
end

local function renderGather(page, key)
  local view = Tab.view
  local slug = viewProf(view)
  local g = G.Gathering(slug)
  if not g then return false end
  if key == "best" then
    add(page, { text = "Where to level " .. G.PROF_NAME[slug], font = "title", size = 20, gap = 2 })
    mySkillLine(page, slug)
    local mine = G.PlayerSkill(slug)
    section(page, "Best zones by skill")
    for _, b in ipairs(g.best or {}) do
      local here = mine and mine >= b[1] and mine < b[2]
      add(page, { text = (here and GOOD or "") .. ("Skill %d-%d"):format(b[1], b[2]) .. (here and "  (you)|r" or ""), size = 12, gap = 0 })
      for _, z in ipairs(b[3] or {}) do
        add(page, { text = z, size = 12, indent = 16, onClick = zoneLink(z) })
      end
    end
    if slug == "skinning" then
      add(page, { text = "Skinning skill needed = 1 up to creature level 10, (level - 10) x 10 up to 20, then level x 5." .. classic(),
        size = 11, color = "muted", wrap = true, gap = 4 })
    end
    noteLine(page, g)
    credit(page, "More: " .. FDB().URL .. "/gathering/" .. slug)
    return true
  end
  local i = tonumber(tostring(key):match("^n:(%d+)$"))
  if i then
    local n = G.Node(slug, i)
    if not n then return false end
    add(page, { text = n.n, font = "title", size = 20, gap = 2 })
    add(page, { text = G.PROF_NAME[slug] .. " · skill " .. n.sk .. (n.new and ("  ·  " .. GOOD .. "new in WoW Forever|r") or ""),
      size = 12, color = "muted", gap = 4 })
    mySkillLine(page, slug)
    local can = canText(n.sk, slug)
    if can ~= "" then add(page, { text = MUTED .. "Can you gather it|r   " .. can, size = 12 }) end
    if n.it or n.also then
      section(page, "Gives")
      for _, iid in ipairs({ n.it, unpack(n.also or {}) }) do
        add(page, { text = FDB().ItemText(iid), icon = itemIcon(iid), item = iid, onClick = link("items", iid) })
      end
    end
    if n.tz then
      section(page, "Where it grows" .. (slug == "mining" and " (veins)" or ""))
      local tz = {}
      for k, z in ipairs(n.tz) do tz[k] = z end
      table.sort(tz, function(x, y) return (x[2] or 0) > (y[2] or 0) end)
      for _, z in ipairs(tz) do
        add(page, { text = z[1], right = plural(z[2] or 0, "spot"), size = 12, onClick = zoneLink(z[1]) })
      end
      add(page, { text = "Spawn spots are Classic data (CMaNGOS)" .. (n.fv and ("; " .. n.fv .. " seen in Forever so far") or "")
        .. ".", size = 10, color = "muted", wrap = true })
    end
    noteLine(page, g)
    credit(page, "More: " .. FDB().URL .. "/gathering/" .. slug)
    return true
  end
  local zname = tostring(key):match("^z:(.+)$")
  local z = zname and g.zones and g.zones[zname]
  if not z then return false end
  add(page, { text = zname, font = "title", size = 20, gap = 2 })
  if slug == "skinning" then
    add(page, { text = ("Skinning · creatures level %d-%d · skill %d-%d"):format(z.lv[1], z.lv[2], z.sk[1], z.sk[2]) .. classic(),
      size = 12, color = "muted", gap = 4, wrap = true })
    mySkillLine(page, slug)
    section(page, "Beasts")
    local mine = G.PlayerSkill(slug)
    local shown = 0
    for _, b in ipairs(z.b or {}) do
      shown = shown + 1
      if shown > 40 then add(page, { text = ("and %d more"):format(#z.b - 40), size = 11, color = "muted" }); break end
      local lv = b.lo == b.hi and tostring(b.lo) or (b.lo .. "-" .. b.hi)
      local ok = mine and b.sk and (mine >= b.sk and GOOD or WARN) or ""
      add(page, { text = b.n .. (b.el and ("  " .. WARN .. "elite|r") or "") .. (b.fv and ("  " .. MUTED .. "seen in Forever|r") or ""),
        right = "lv " .. lv .. "  " .. ok .. "skill " .. tostring(b.sk or "?") .. (ok ~= "" and "|r" or ""), size = 12,
        onClick = openMob(b.id), tip = { b.n, "Click for its bestiary page.", b.g and ("Skins into " .. table.concat((function()
          local t = {}; for _, iid in ipairs(b.g) do t[#t + 1] = FDB().ItemName(iid) end; return t end)(), ", ")) or "" } })
    end
  else
    add(page, { text = ("Fishing · skill %d%s"):format(z.sk or 0, z.ne and (" · no escapes at " .. z.ne) or "") .. classic(),
      size = 12, color = "muted", gap = 4, wrap = true })
    mySkillLine(page, slug)
    if z.l then
      section(page, "Catches")
      for _, l in ipairs(z.l) do
        add(page, { text = FDB().ItemText(l[1]), icon = itemIcon(l[1]), item = l[1], right = tostring(l[2]) .. "%", onClick = link("items", l[1]) })
      end
    end
    if z.po then
      section(page, "Pools")
      add(page, { text = table.concat(z.po, ", "), size = 12, wrap = true })
    end
    if z.cf then add(page, { text = plural(z.cf, "catch") .. " recorded in Forever so far.", size = 10, color = "muted" }) end
  end
  local zid = G.ZoneByName(zname)
  if zid then add(page, { text = LINK .. "Open the zone page|r", size = 12, onClick = link("zones", zid), gap = 4 }) end
  noteLine(page, g)
  credit(page, "More: " .. FDB().URL .. "/gathering/" .. slug)
  return true
end

Tab.AddMode({
  key = "gathering", label = "Gathering", search = "Search herbs, ore, zones, beasts", noun = "row",
  items = gatherItems, render = renderGather,
  count = function(items, view)
    local slug = viewProf(view)
    local rank = G.PlayerSkill(slug)
    return ("%s%s · %s"):format(G.PROF_NAME[slug], rank and (" " .. rank) or "", plural(#items, "row"))
  end,
  filters = function(p, view)
    local slug = viewProf(view)
    p.f1.label:SetText(G.PROF_NAME[slug]); p.f1:SetActive(G.PlayerSkill(slug) ~= nil)
    p.f1.tip = "Herbalism, Mining, Skinning or Fishing. Lit up when you have it. Right-click goes back."
    p.f2.label:SetText(G.GSKILLS[view.gskill or 1].label); p.f2:SetActive((view.gskill or 1) > 1)
    p.f2.tip = "Skill range. \"My skill\" shows what you can gather now. Right-click goes back."
    p.f3:Hide()
  end,
  filter = function(which, button, view)
    if which == 1 then view.gprof = H.cycle(view.gprof or 1, #G.PROFS, button)
    elseif which == 2 then view.gskill = H.cycle(view.gskill or 1, #G.GSKILLS, button) end
    Tab.selected.gathering = nil
  end,
  onShow = function(key, view)
    if type(key) == "string" and key:match("^prof:") then
      local slug = key:match("^prof:(%a+)")
      for i, s in ipairs(G.PROFS) do if s == slug then view.gprof = i end end
    end
    view.gskill = 1
  end,
})

-- open a gathering page by profession + key (from other pages / Ask LOMB)
function Tab.ShowGathering(slug, key)
  for i, s in ipairs(G.PROFS) do if s == slug then Tab.view.gprof = i end end
  Tab.view.gskill = 1
  Tab.view.search.gathering = ""
  Tab.Show("gathering", key, ns.UI.IsShown and ns.UI.IsShown("quests") or false)
end

---------------------------------------------------------------------------
-- Zones (and battlegrounds)
---------------------------------------------------------------------------
local function zoneItems(search, view)
  local out = {}
  local lv = Tab.LEVELS[view.zlevel or 2]
  local minL, maxL = lv.min, lv.max
  if lv.key == "near" then
    local pl = H.playerLevel()
    if pl then minL, maxL = math.max(1, pl - 3), pl + 3 end
  end
  local side = view.zmine ~= false and FDB().PlayerSide() or nil
  local here = H.playerZone()
  for _, e in ipairs(G.ZoneList({ search = search, side = side, minLevel = minL, maxLevel = maxL })) do
    local tag = e.st.side == "A" and "|cff6fa8ffA|r " or (e.st.side == "H" and "|cffff6f6fH|r " or "")
    out[#out + 1] = { key = e.id, text = (e.z.n == here and LINK .. e.z.n .. "|r" or e.z.n) .. (e.z.new and ("  " .. GOOD .. "new|r") or ""),
      meta = tag .. (G.ZoneLevelText(e.st) or "-") }
  end
  if lv.key == "all" or lv.key == "near" or (maxL or 0) >= 10 then
    for _, e in ipairs(G.BattlegroundList(search)) do
      if not (minL and maxL) or ((e.b.lo or 0) <= maxL and (e.b.hi or 99) >= minL) then
        out[#out + 1] = { key = "bg:" .. e.id, text = e.b.n, meta = "|cffe0b060PvP|r " .. G.BattlegroundLevels(e.b) }
      end
    end
  end
  return out
end

local function renderZone(page, key)
  local bg = tonumber(tostring(key):match("^bg:(%d+)$"))
  if bg then return Tab.RenderBattleground(page, bg) end
  local z = G.Zone(key)
  if not z then return false end
  local st = G.ZoneStats(z.n)
  add(page, { text = z.n, font = "title", size = 20, gap = 2 })
  local bits = {}
  if z.c then bits[#bits + 1] = z.c end
  bits[#bits + 1] = st.side == "B" and "Contested / both" or FDB().SideText(st.side)
  if G.ZoneLevelText(st) then bits[#bits + 1] = "quests level " .. G.ZoneLevelText(st) end
  if z.new then bits[#bits + 1] = GOOD .. "new in WoW Forever|r" end
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4, wrap = true })
  add(page, { text = "ForeverDB lists no level range or faction for zones; these come from the quests here.",
    size = 10, color = "muted", wrap = true })
  section(page, "Quests")
  if st.quests > 0 then
    add(page, { text = plural(st.quests, "quest") .. " up to level 30  " .. LINK .. "(list them)|r", size = 12,
      onClick = function() Tab.ShowQuestsInZone(z.n) end })
    for k, s in ipairs(st.storylines) do
      if k > 8 then add(page, { text = ("and %d more storylines"):format(#st.storylines - 8), size = 11, color = "muted" }); break end
      add(page, { text = H.CHAIN .. s.name .. "|r", right = plural(s.n, "part"), size = 12, indent = 8, onClick = link("quests", s.first) })
    end
  else
    add(page, { text = "No quests up to level 30 in the bundle.", size = 11, color = "muted" })
  end
  if #st.vendors > 0 then
    section(page, ("Vendors (%d)"):format(#st.vendors))
    for k, vid in ipairs(st.vendors) do
      if k > 12 then add(page, { text = ("and %d more"):format(#st.vendors - 12), size = 11, color = "muted" }); break end
      local v = FDB().Vendor(vid)
      add(page, { text = v.n .. (v.t and ("  " .. MUTED .. "<" .. v.t .. ">|r") or ""), right = v.x and ("%.0f, %.0f"):format(v.x, v.y) or "",
        size = 12, onClick = link("vendors", vid) })
    end
  end
  local gz = G.GatherInZone(z.n)
  if gz.herbs or gz.ore or gz.skinning or gz.fishing then
    section(page, "Gathering")
    local function nodes(label, list, slug)
      if not list then return end
      local t = {}
      for _, n in ipairs(list) do t[#t + 1] = n[1] .. " " .. MUTED .. n[2] .. "|r" end
      add(page, { text = MUTED .. label .. "|r   " .. table.concat(t, ", "), size = 12, wrap = true,
        onClick = function() Tab.ShowGathering(slug, "best") end })
    end
    nodes("Herbs", gz.herbs, "herbalism")
    nodes("Ore", gz.ore, "mining")
    if gz.skinning then
      add(page, { text = MUTED .. "Skinning|r   " .. ("beasts level %d-%d, skill %d-%d"):format(gz.skinning.lv[1], gz.skinning.lv[2],
        gz.skinning.sk[1], gz.skinning.sk[2]) .. "  " .. LINK .. "(beasts)|r", size = 12,
        onClick = function() Tab.ShowGathering("skinning", "z:" .. z.n) end })
    end
    if gz.fishing then
      add(page, { text = MUTED .. "Fishing|r   skill " .. gz.fishing.sk .. "  " .. LINK .. "(catches)|r", size = 12,
        onClick = function() Tab.ShowGathering("fishing", "z:" .. z.n) end })
    end
    add(page, { text = "Where nodes and beasts spawn is Classic data (CMaNGOS), may differ.", size = 10, color = "muted" })
  end
  section(page, "Dungeons")
  add(page, { text = "ForeverDB's dungeon list doesn't say which zone each one is in.", size = 11, color = "muted", wrap = true,
    onClick = function() Tab.Show("dungeons", nil, true) end })
  credit(page, "More: " .. FDB().URL .. "/zone/" .. key)
  return true
end

function Tab.ShowQuestsInZone(zone)
  local v = Tab.view
  Tab.Show("quests", nil, true)
  v.search.quests = zone
  v.zone, v.level = false, 2
  Tab.Refresh()
end

function Tab.RenderBattleground(page, id)
  local b = G.Battleground(id)
  if not b then return false end
  add(page, { text = b.n, font = "title", size = 20, gap = 2 })
  local bits = { b.k or "Battleground", "levels " .. G.BattlegroundLevels(b) }
  if b.ts then bits[#bits + 1] = b.ts .. " vs " .. b.ts end
  if b.new then bits[#bits + 1] = GOOD .. "new in WoW Forever|r" end
  add(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", gap = 4 })
  if b.rn or b.rs == "classic" then
    add(page, { text = WARN .. (b.rn or "Rules are Classic's.") .. "|r", size = 11, wrap = true })
  end
  if b.win then add(page, { text = MUTED .. "Win|r   " .. b.win, size = 12, wrap = true }) end
  if b.cs then add(page, { text = MUTED .. "Capture time|r   " .. b.cs .. " seconds", size = 12 }) end
  if b.how then
    section(page, "How to play")
    for _, h in ipairs(b.how) do add(page, { text = "- " .. h, size = 12, wrap = true }) end
  end
  if b.ob then
    section(page, "Objectives")
    add(page, { text = table.concat(b.ob, ", "), size = 12, wrap = true })
  end
  if b.d then
    section(page, "About")
    add(page, { text = b.d, size = 11, color = "muted", wrap = true })
  end
  credit(page, "More: " .. FDB().URL .. "/battleground/" .. (b.slug or id))
  return true
end

Tab.AddMode({
  key = "zones", label = "Zones", search = "Search zones or battlegrounds", noun = "zone",
  items = zoneItems, render = renderZone,
  count = function(items)
    local z, b = 0, 0
    for _, it in ipairs(items) do if tostring(it.key):match("^bg:") then b = b + 1 else z = z + 1 end end
    return plural(z, "zone") .. (b > 0 and (", " .. plural(b, "battleground")) or "")
  end,
  filters = function(p, view)
    local lv = Tab.LEVELS[view.zlevel or 2]
    p.f1.label:SetText(lv.label); p.f1:SetActive(lv.key ~= "all")
    p.f1.tip = "Zones with quests near your level (3 either side), all, or a band. Right-click goes back."
    p.f2.label:SetText(view.zmine ~= false and "My faction" or "Both factions"); p.f2:SetActive(view.zmine ~= false)
    p.f2.tip = "Hide the other faction's zones (judged from the quests there)."
    p.f3:Hide()
  end,
  filter = function(which, button, view)
    if which == 1 then view.zlevel = H.cycle(view.zlevel or 2, #Tab.LEVELS, button)
    elseif which == 2 then view.zmine = view.zmine == false end
  end,
  onShow = function(_, view) view.zlevel, view.zmine = 2, false end,
})

---------------------------------------------------------------------------
-- Gear sets
---------------------------------------------------------------------------
local WHERE = { equipped = GOOD .. "equipped|r", bags = GOOD .. "in bags|r", bank = GOOD .. "in bank|r" }

local function setItems(search)
  local out = {}
  for _, e in ipairs(G.SetList(search)) do
    local pr = G.SetProgress(e.s)
    out[#out + 1] = { key = e.id, text = e.s.n, meta = (pr.have == pr.total and GOOD or (pr.have > 0 and "|cffffd36b" or MUTED))
      .. pr.have .. "/" .. pr.total .. "|r" }
  end
  return out
end

local function sourcesLines(page, iid)
  local src = G.Sources(iid)
  local any = false
  for _, s in ipairs(src.soldBy) do
    local v = FDB().Vendor(s.vendor)
    if v then
      any = true
      add(page, { text = MUTED .. "Sold by|r " .. v.n, right = FDB().Money(s.price), size = 11, indent = 20, onClick = link("vendors", s.vendor) })
    end
  end
  for _, ref in ipairs(src.madeBy) do
    local r, p = FDB().Recipe(ref)
    if r then
      any = true
      local crafters = ns.Crafting and ns.Crafting.CraftersOfItem and ns.Crafting.CraftersOfItem(iid) or {}
      add(page, { text = MUTED .. "Made with|r " .. p.n .. " " .. tostring(r.sk[1] or "?")
        .. (#crafters > 0 and ("  " .. GOOD .. plural(#crafters, "guild crafter") .. "|r") or ""), size = 11, indent = 20,
        onClick = link("recipes", ref) })
    end
  end
  for _, d in ipairs(src.dungeons) do
    local dg = FDB().Dungeon(d.dungeon)
    if dg then any = true; add(page, { text = MUTED .. "Notable loot in|r " .. dg.n, size = 11, indent = 20, onClick = link("dungeons", d.dungeon) }) end
  end
  for k, d in ipairs(src.drops) do
    if k > 3 then break end
    any = true
    add(page, { text = MUTED .. "Guild saw it drop from|r " .. d.name .. (d.rate and ("  " .. MUTED .. math.floor(d.rate * 1000 + 0.5) / 10 .. "%|r") or ""),
      size = 11, indent = 20, srcs = { "guild" }, onClick = openMob(d.npcId) })
  end
  if not any then
    add(page, { text = "Where it comes from isn't in the data, and the guild hasn't seen it drop yet.", size = 11, color = "muted", indent = 20 })
  end
end

local function renderSet(page, id)
  local s = G.Set(id)
  if not s then return false end
  local pr = G.SetProgress(s)
  add(page, { text = s.n, font = "title", size = 20, gap = 2 })
  local lv = G.SetLevel(s)
  add(page, { text = ("%d pieces%s  ·  you have %d (%d equipped)"):format(pr.total, lv > 0 and (" · from level " .. lv) or "", pr.have, pr.equipped),
    size = 12, color = "muted", gap = 4 })
  if s.nc then
    add(page, { text = WARN .. "ForeverDB says these pieces are from an earlier build and the current client hides them: unconfirmed in WoW Forever.|r",
      size = 11, wrap = true })
  end
  if s.b then
    section(page, "Set bonuses")
    for _, b in ipairs(s.b) do
      local on = pr.equipped >= b[1]
      add(page, { text = (on and GOOD or MUTED) .. "(" .. b[1] .. ") |r" .. (on and "" or MUTED) .. b[2] .. (on and "" or "|r"), size = 12, wrap = true })
    end
  end
  section(page, "Pieces")
  local missing = {}
  for _, piece in ipairs(pr.pieces) do
    local where = piece.where and WHERE[piece.where] or (MUTED .. "missing|r")
    add(page, { text = FDB().ItemText(piece.id), icon = itemIcon(piece.id), item = piece.id, right = where, onClick = link("items", piece.id) })
    if not piece.where then missing[#missing + 1] = piece.id; sourcesLines(page, piece.id) end
  end
  local seen = ns.char and ns.char.setBank
  add(page, { text = seen and ("Bank last checked " .. date("%b %d", seen.t) .. ".") or "Open your bank once and pieces there count too.",
    size = 10, color = "muted" })
  if #missing > 0 and ns.Wishlist then
    add(page, { text = LINK .. "Add the " .. plural(#missing, "missing piece") .. " to my wishlist|r", size = 12, gap = 4,
      onClick = function()
        local n = 0
        for _, iid in ipairs(missing) do
          if ns.Wishlist.Add("n", ("|Hitem:%d|h[%s]|h"):format(iid, FDB().ItemName(iid)), 1, s.n) then n = n + 1 end
        end
        ns.Print("Added %d piece%s of %s to your wishlist.", n, n == 1 and "" or "s", s.n)
      end,
      tip = { "Wishlist", "Guildmates see what you need in the Wishlist tab and on item tooltips." } })
  end
  credit(page, "More: " .. FDB().URL .. "/itemset/" .. id)
  return true
end

Tab.AddMode({
  key = "sets", label = "Sets", search = "Search sets or pieces", noun = "set",
  items = setItems, render = renderSet,
  filters = function(p) p.f1:Hide(); p.f2:Hide(); p.f3:Hide() end,
})

---------------------------------------------------------------------------
-- Extra sections on item pages
---------------------------------------------------------------------------
Tab.ItemExtras[#Tab.ItemExtras + 1] = function(page, id)
  -- disenchant
  local r, why = G.Disenchant(id)
  if r then
    section(page, "Disenchants into")
    for _, x in ipairs(r.r or {}) do
      local amount = (x[3] and x[4] and x[3] ~= x[4]) and (x[3] .. "-" .. x[4] .. "x  ") or ((x[3] or 1) > 1 and (x[3] .. "x  ") or "")
      add(page, { text = amount .. FDB().ItemText(x[1]), icon = itemIcon(x[1]), item = x[1], right = tostring(x[2]) .. "%",
        onClick = link("items", x[1]) })
    end
    add(page, { text = WARN .. FDB().CLASSIC_NOTE .. "|r  " .. MUTED .. "Enchanting skill needed: not in the data.|r", size = 10 })
    local en = G.Enchanters()
    if #en > 0 then
      add(page, { text = MUTED .. "Guild enchanters|r   " .. G.EnchantersText(en, 6), size = 12, wrap = true, srcs = { "guild" } })
    else
      add(page, { text = "No guild enchanters known yet.", size = 11, color = "muted" })
    end
  elseif why == "level" then
    section(page, "Disenchants into")
    add(page, { text = "Not in the disenchant table.", size = 11, color = "muted" })
  end
  -- disenchant sources (for enchanting materials)
  local srcs = G.DisenchantSources(id)
  if #srcs > 0 then
    section(page, "Disenchanted from")
    local Q = { [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }
    for k, s in ipairs(srcs) do
      if k > 8 then add(page, { text = ("and %d more"):format(#srcs - 8), size = 11, color = "muted" }); break end
      add(page, { text = ("%s %s, item level %d-%d"):format(Q[s.q] or "?", s.k == 1 and "weapons" or "armor", s.lo, s.hi),
        right = tostring(s.chance) .. "%", size = 12 })
    end
    add(page, { text = WARN .. FDB().CLASSIC_NOTE .. "|r", size = 10 })
  end
  -- set
  local sid, s = G.SetForItem(id)
  if s then
    section(page, "Part of a set")
    local pr = G.SetProgress(s)
    add(page, { text = s.n, right = pr.have .. "/" .. pr.total .. " owned", size = 12, onClick = link("sets", sid) })
  end
  -- gathering
  local slug, ni, node = G.NodeForItem(id)
  if node then
    section(page, "Gathered from")
    add(page, { text = node.n, right = G.PROF_NAME[slug] .. " " .. node.sk, size = 12,
      onClick = function() Tab.ShowGathering(slug, "n:" .. ni) end })
  end
  -- guild-recorded drops
  local drops = G.GuildDrops(id)
  if #drops > 0 then
    section(page, "Drops (guild-recorded)")
    for k, d in ipairs(drops) do
      if k > 6 then add(page, { text = ("and %d more"):format(#drops - 6), size = 11, color = "muted" }); break end
      add(page, { text = d.name, right = d.rate and (math.floor(d.rate * 1000 + 0.5) / 10 .. "%") or "", size = 12,
        srcs = { "guild" }, onClick = openMob(d.npcId) })
    end
  end
  -- wishlist
  local need = ns.Wishlist and ns.Wishlist.NeedLine and ns.Wishlist.NeedLine(id)
  if need then add(page, { text = need, size = 11, color = "muted", wrap = true, gap = 4 }) end
end

-- /lomb train
function Tab.ShowTraining()
  Tab.view.cls, Tab.view.band, Tab.view.pet = 0, 1, nil
  Tab.Show("training", G.Class(G.PlayerClass()) and "now" or nil)
end

return Tab
