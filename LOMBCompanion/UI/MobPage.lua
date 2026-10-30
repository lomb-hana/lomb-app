-- LOMB Companion: the full bestiary page for one mob. Shared by the Bestiary
-- tab and the card's "expand" view. Every fact line carries a source tag.
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local P = ns.Providers
local MobPage = {}
ns.MobPage = MobPage
MobPage.pages = {}

local function pct(rate)
  if not rate then return "?" end
  if rate >= 0.995 then return "100%" end
  if rate < 0.001 then return "<0.1%" end
  if rate < 0.1 then return ("%.1f%%"):format(rate * 100) end
  return ("%d%%"):format(math.floor(rate * 100 + 0.5))
end
MobPage.pct = pct

function MobPage.LevelText(level, levelMax, skull)
  if skull then return "??" end
  if not level then return "?" end
  if levelMax and levelMax ~= level then return ("%d-%d"):format(level, levelMax) end
  return tostring(level)
end

function MobPage.ClassificationText(cl)
  local c = cl and T.classification[cl]
  if not c then return nil end
  return "|c" .. T.hex(c[2]) .. c[1] .. "|r"
end

function MobPage.TypeText(merged)
  local ct = P.Value(merged, "creatureType")
  local fam = P.Value(merged, "family")
  if ct and fam and fam ~= ct then return ("%s (%s)"):format(ct, fam) end
  return ct
end

local function ago(t)
  if not t then return nil end
  local d = time() - t
  if d < 3600 then return ("%dm ago"):format(math.max(1, math.floor(d / 60))) end
  if d < 86400 then return ("%dh ago"):format(math.floor(d / 3600)) end
  return ("%dd ago"):format(math.floor(d / 86400))
end
MobPage.Ago = ago

---------------------------------------------------------------------------
-- Line pool
---------------------------------------------------------------------------
local function acquire(page)
  page.used = page.used + 1
  local line = page.lines[page.used]
  if not line then
    line = CreateFrame("Frame", nil, page.child)
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(16, 16)
    line.left = W.Text(line, "body", 12, "text")
    line.right = W.Text(line, "narrow", 11, "muted", "RIGHT")
    line.tags = { W.SourceTag(line), W.SourceTag(line), W.SourceTag(line) }
    line:EnableMouse(true)
    page.lines[page.used] = line
  end
  line:Show()
  line:SetScript("OnEnter", nil)
  line:SetScript("OnLeave", nil)
  return line
end

-- opts: text, right, srcs (array), font, size, color, icon, indent, wrap, gap, item, spell
local function addLine(page, opts)
  local line = acquire(page)
  local width = page.width
  local indent = opts.indent or 0
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, -page.y)
  line:SetWidth(width)

  local x = indent
  if opts.icon then
    line.icon:SetTexture(opts.icon)
    line.icon:ClearAllPoints()
    line.icon:SetPoint("TOPLEFT", x, -1)
    line.icon:Show()
    x = x + 20
  else
    line.icon:Hide()
  end

  -- tags on the far right, right text left of them
  local tagX = 0
  for i, tag in ipairs(line.tags) do
    local src = opts.srcs and opts.srcs[i]
    tag:SetSource(src)
    if src then
      tag:ClearAllPoints()
      tag:SetPoint("TOPRIGHT", line, "TOPRIGHT", -tagX, -2)
      tagX = tagX + tag:GetWidth() + 3
    end
  end
  line.right:ClearAllPoints()
  line.right:SetPoint("TOPRIGHT", line, "TOPRIGHT", -(tagX + (tagX > 0 and 4 or 0)), -2)
  line.right:SetText(opts.right or "")

  line.left:SetFont(T.fonts[opts.font or "body"], opts.size or 12, "")
  line.left:SetTextColor(W.rgba(opts.color or "text"))
  line.left:ClearAllPoints()
  line.left:SetPoint("TOPLEFT", x, 0)
  local rightW = (opts.right and opts.right ~= "") and (line.right:GetStringWidth() + 8) or 0
  line.left:SetWidth(math.max(40, width - x - tagX - rightW - 4))
  line.left:SetWordWrap(opts.wrap and true or false)
  line.left:SetText(opts.text or "")
  local h = math.max(opts.icon and 18 or 0, opts.wrap and (line.left:GetStringHeight() or 14) or (opts.size or 12) + 4)
  line:SetHeight(h)

  if opts.item then
    line:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if GameTooltip.SetItemByID then GameTooltip:SetItemByID(opts.item) else GameTooltip:SetHyperlink("item:" .. opts.item) end
      if opts.tip then for _, l in ipairs(opts.tip) do GameTooltip:AddLine(l, 0.8, 0.78, 0.85) end end
      GameTooltip:Show()
    end)
    line:SetScript("OnLeave", function() GameTooltip:Hide() end)
  elseif opts.spell then
    line:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(opts.spell) end
      GameTooltip:Show()
    end)
    line:SetScript("OnLeave", function() GameTooltip:Hide() end)
  elseif opts.tip then
    W.Tooltip(line, function(tt)
      for i, l in ipairs(opts.tip) do if i == 1 then tt:SetText(l, 1, 1, 1) else tt:AddLine(l, 0.8, 0.78, 0.85, true) end end
    end)
  end

  page.y = page.y + h + (opts.gap or 3)
  return line
end

local function section(page, title)
  page.y = page.y + 8
  addLine(page, { text = title, font = "title", size = 15, color = "gold", gap = 2 })
  local line = page.lines[page.used]
  line.div = line.div or W.Divider(line, 0.8)
  line.div:ClearAllPoints()
  line.div:SetPoint("BOTTOMLEFT", 0, -1)
  line.div:SetPoint("BOTTOMRIGHT", 0, -1)
  page.y = page.y + 4
end

local function fact(page, label, value, src, alt, tip)
  if value == nil or value == "" then return end
  local srcs = { src }
  if alt then for _, a in ipairs(alt) do if #srcs < 3 and a.src ~= src then srcs[#srcs + 1] = a.src end end end
  addLine(page, { text = "|cff9a92a8" .. label .. "|r   " .. tostring(value), size = 12, srcs = srcs, tip = tip })
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
function MobPage.Render(page, npcId)
  page.npcId = npcId
  page.used, page.y = 0, 0
  if not npcId then
    for _, l in ipairs(page.lines) do l:Hide() end
    page.empty:Show()
    page.child:SetHeight(10)
    return
  end
  page.empty:Hide()
  local merged = ns.Bestiary.Merged(npcId)
  page.merged = merged
  local V = function(f) return P.Value(merged, f) end
  local F = merged.fields

  -- header
  local name = V("name") or ("NPC " .. npcId)
  addLine(page, { text = name, font = "title", size = 22, color = "text", srcs = { F.name and F.name.src }, gap = 2 })
  local level, levelSrc = V("level")
  local live = ns.Bestiary.live
  local skull = live and live.npcId == npcId and live.skull
  local bits = { "Level " .. MobPage.LevelText(level, V("levelMax"), skull) }
  local cls = MobPage.ClassificationText(V("classification"))
  if cls then bits[#bits + 1] = cls end
  local typ = MobPage.TypeText(merged)
  if typ then bits[#bits + 1] = typ end
  addLine(page, { text = table.concat(bits, "  ·  "), size = 12, color = "muted", srcs = { levelSrc }, gap = 6 })

  -- facts
  section(page, "What we know")
  local hpMax, hpSrc = V("healthMax")
  fact(page, "Health", hpMax and W.Thousands(hpMax), hpSrc, merged.alt.healthMax)
  local zones, zSrc = V("zones")
  if type(zones) == "table" and #zones > 0 then fact(page, "Seen in", table.concat(zones, ", "), zSrc) end
  local kills, kSrc = V("kills")
  if kills and kills > 0 then fact(page, "Guild kills", W.Thousands(kills), kSrc, merged.alt.kills) end
  local seen, seenSrc = V("seen")
  if seen and seen > 0 then fact(page, "Guild sightings", W.Thousands(seen), seenSrc) end
  local rec0 = ns.db.bestiary[npcId]
  local mine = rec0 and rec0.rec and rec0.rec[ns.playerKey]
  if mine and (mine.k or 0) > 0 then fact(page, "Your kills", W.Thousands(mine.k), "guild") end
  local rs = rec0 and rec0.rs
  if rs and rs.t then
    local where = rs.z or "?"
    if rs.x and rs.y then where = ("%s (%d, %d)"):format(where, rs.x, rs.y) end
    local by = rs.by == ns.playerKey and "you" or ns.Compat.ShortName(rs.by) or "?"
    fact(page, "Last spotted", ("%s by %s, %s"):format(where, by, ago(rs.t)), "guild")
  end
  local fk, fkSrc = V("firstKiller")
  if fk then fact(page, "First guild kill", ns.Compat.ShortName(fk), fkSrc) end
  local rec, recSrc = V("recorders")
  if rec and rec > 0 then fact(page, "Recorded by", rec == 1 and "1 member" or (rec .. " members"), recSrc) end
  local ls, lsSrc = V("lastSeen")
  if ls then fact(page, "Last seen", ago(ls), lsSrc) end
  if page.used <= 3 then
    addLine(page, { text = "Nothing recorded yet. Kill and loot one and it fills in -- for the whole guild.",
      color = "muted", size = 11, wrap = true })
  end

  -- loot
  if #merged.lootList > 0 then
    section(page, "Loot")
    for i, e in ipairs(merged.lootList) do
      if i > (page.maxLoot or 40) then break end
      local srcs, tip, rateText = {}, {}, nil
      for _, id in ipairs({ "foreverdb", "guild", "game" }) do
        local s = e.sources[id]
        if s then
          srcs[#srcs + 1] = id
          local label = P.SOURCE_LABEL[id] or id
          rateText = rateText or pct(s.rate)
          tip[#tip + 1] = ("%s: %s%s"):format(label, pct(s.rate),
            s.kills and (" of " .. W.Thousands(s.kills) .. " looted") or "")
        end
      end
      local _, _, _, icon = ns.Compat.ItemInfo(e.itemID)
      addLine(page, { text = W.ItemText(e.itemID), right = rateText, srcs = srcs,
        icon = icon or 134400, item = e.itemID, tip = tip })
    end
    if merged.credits.guild then
      local agg = ns.Bestiary.Aggregate(ns.Bestiary.Get(npcId) or {})
      if agg.corpses > 0 then
        addLine(page, { text = ("Guild rates from %d looted corpse%s."):format(agg.corpses, agg.corpses == 1 and "" or "s"),
          size = 10, color = "muted" })
      end
    end
  end

  -- abilities
  local abil = {}
  for _, a in pairs(merged.abilities) do abil[#abil + 1] = a end
  if #abil > 0 then
    table.sort(abil, function(a, b) return (a.name or "") < (b.name or "") end)
    section(page, "Abilities seen")
    for _, a in ipairs(abil) do
      local nm, icon = ns.Compat.SpellName(a.spellID)
      local srcs = {}
      for _, id in ipairs({ "foreverdb", "guild", "game" }) do if a.sources[id] then srcs[#srcs + 1] = id end end
      addLine(page, { text = nm or a.name or ("Spell " .. tostring(a.spellID)), icon = icon or 136243,
        srcs = srcs, spell = a.spellID })
    end
  end

  -- optional data-module sections (hidden unless a provider supplies them)
  local S = merged.sections
  if S.boss then
    local d = S.boss.data
    section(page, "Boss")
    if type(d) == "table" then
      if d.notes then addLine(page, { text = d.notes, wrap = true, size = 11, srcs = { S.boss.src } }) end
      for _, ph in ipairs(d.phases or {}) do
        addLine(page, { text = "- " .. tostring(ph), wrap = true, size = 11, indent = 6 })
      end
    else
      addLine(page, { text = tostring(d), wrap = true, size = 11, srcs = { S.boss.src } })
    end
  end
  if S.notableLoot and type(S.notableLoot.data) == "table" then
    section(page, "Notable loot")
    for _, n in ipairs(S.notableLoot.data) do
      local _, _, _, icon = ns.Compat.ItemInfo(n.itemID)
      addLine(page, { text = W.ItemText(n.itemID) .. (n.note and ("  |cff9a92a8" .. n.note .. "|r") or ""),
        icon = icon or 134400, item = n.itemID, srcs = { S.notableLoot.src } })
    end
  end
  if S.skinning and type(S.skinning.data) == "table" then
    local d = S.skinning.data
    section(page, "Skinning")
    if d.skill then addLine(page, { text = "|cff9a92a8Skill needed|r   " .. d.skill, srcs = { S.skinning.src } }) end
    for _, itemID in ipairs(d.items or {}) do
      local _, _, _, icon = ns.Compat.ItemInfo(itemID)
      addLine(page, { text = W.ItemText(itemID), icon = icon or 134400, item = itemID, srcs = { S.skinning.src } })
    end
  end
  if S.quests and type(S.quests.data) == "table" then
    section(page, "Quests")
    for _, q in ipairs(S.quests.data) do
      addLine(page, { text = ("%s%s"):format(q.name or ("Quest " .. tostring(q.id)),
        q.level and ("  |cff9a92a8(" .. q.level .. ")|r") or ""), srcs = { S.quests.src } })
    end
  end

  -- credits for any data module that contributed
  local credits = {}
  for id, prov in pairs(merged.credits) do
    if prov.credit then credits[#credits + 1] = { id = id, text = prov.credit, url = prov.url } end
  end
  table.sort(credits, function(a, b) return a.id < b.id end)
  if #credits > 0 then
    page.y = page.y + 10
    for _, c in ipairs(credits) do
      addLine(page, { text = c.text, size = 11, color = "gold", srcs = { c.id },
        tip = { c.text, c.url or "" } })
    end
  end

  for i = page.used + 1, #page.lines do page.lines[i]:Hide() end
  page.child:SetHeight(page.y + 6)
  page.scroll:SetVerticalScroll(0)
end

function MobPage.New(parent, width)
  local page = CreateFrame("Frame", nil, parent)
  page.width = width - 10
  page.lines, page.used, page.y = {}, 0, 0
  page.scroll = CreateFrame("ScrollFrame", nil, page)
  page.scroll:SetAllPoints()
  page.child = CreateFrame("Frame", nil, page.scroll)
  page.child:SetSize(page.width, 10)
  page.scroll:SetScrollChild(page.child)
  page.scroll:EnableMouseWheel(true)
  page.scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxS = math.max(0, page.child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(maxS, math.max(0, self:GetVerticalScroll() - delta * 40)))
  end)
  page.empty = W.Text(page, "body", 12, "muted", "CENTER")
  page.empty:SetPoint("CENTER")
  page.empty:SetWidth(width - 40)
  page.empty:SetWordWrap(true)
  page.empty:SetText("Pick a creature on the left, or target one in the world.")
  function page:SetMob(npcId) ns.SafeCall(MobPage.Render, self, npcId) end
  MobPage.pages[#MobPage.pages + 1] = page
  return page
end

-- Re-render visible pages when their mob changes or item names arrive.
local rerender = ns.Debounce(0.3, function()
  for _, page in ipairs(MobPage.pages) do
    if page:IsVisible() and page.npcId then page:SetMob(page.npcId) end
  end
end)
ns:On("GET_ITEM_INFO_RECEIVED", function() rerender() end)
ns:Listen("BESTIARY_UPDATED", function(npcId)
  for _, page in ipairs(MobPage.pages) do
    if page.npcId == npcId then rerender(); return end
  end
end)

---------------------------------------------------------------------------
-- Standalone expanded page (opened from the card's expand button)
---------------------------------------------------------------------------
function MobPage.OpenStandalone(npcId, anchor)
  local f = MobPage.standalone
  if not f then
    local S = T.sizes.page
    f = W.Panel(UIParent, "bg", "border", "LOMBCompanionMobPage")
    f:SetSize(S.w, S.h)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    table.insert(UISpecialFrames, "LOMBCompanionMobPage")
    W.Movable(f, function() return nil end, function() end)
    local bar = W.Fill(f, "accent", "ARTWORK")
    bar:SetHeight(2)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T.LOGO)
    logo:SetSize(16, 16)
    logo:SetPoint("TOPLEFT", 10, -8)
    local t = W.Text(f, "title", 13, "accent")
    t:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    t:SetText("LOMB Bestiary")
    local close = W.IconButton(f, "x", "Close", function() f:Hide() end, 20)
    close:SetPoint("TOPRIGHT", -6, -6)
    local open = W.IconButton(f, ">", "Open in the LOMB window", function()
      f:Hide(); ns.UI.Open("bestiary"); if ns.BestiaryTab then ns.BestiaryTab.Select(f.page.npcId) end
    end, 20)
    open:SetPoint("RIGHT", close, "LEFT", -4, 0)
    f.page = MobPage.New(f, S.w - 20)
    f.page:SetPoint("TOPLEFT", 12, -34)
    f.page:SetPoint("BOTTOMRIGHT", -8, 10)
    MobPage.standalone = f
  end
  f:ClearAllPoints()
  if anchor then
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
  else
    f:SetPoint("CENTER")
  end
  f:Show()
  f.page:SetMob(npcId)
  return f
end
