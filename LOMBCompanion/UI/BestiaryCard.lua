-- LOMB Companion: the small bestiary card that pops up when you target a creature.
-- Pin it to keep it on screen; expand it to the full page.
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local C, P, MobPage = ns.Compat, ns.Providers, ns.MobPage
local Card = {}
ns.BestiaryCard = Card

local WIDTH = T.sizes.card.w
local INNER = WIDTH - 20
local MAX_LINES = 7

local function settings() return ns.db.settings end

function Card.Create()
  if Card.frame then return Card.frame end
  local f = W.Panel(UIParent, "bg", "border", "LOMBCompanionCard")
  f:SetSize(WIDTH, 120)
  f:SetFrameStrata("MEDIUM")
  f:Hide()
  W.Movable(f,
    function()
      local p = settings().cardPoint
      return p or { "TOPLEFT", "TOPLEFT", 260, -140 }
    end,
    function(p) settings().cardPoint = p end,
    function() return settings().cardLocked end)

  f.accent = W.Fill(f, "accent", "ARTWORK")
  f.accent:SetHeight(2)
  f.accent:SetPoint("TOPLEFT", 1, -1)
  f.accent:SetPoint("TOPRIGHT", -1, -1)

  f.logo = f:CreateTexture(nil, "ARTWORK")
  f.logo:SetTexture(T.LOGO)
  f.logo:SetSize(14, 14)
  f.logo:SetPoint("TOPLEFT", 8, -9)

  f.close = W.IconButton(f, "x", "Hide card", function() Card.Hide(true) end, 16)
  f.close:SetPoint("TOPRIGHT", -6, -6)
  f.expand = W.IconButton(f, "+", "Open the full bestiary page", function()
    if f.npcId then MobPage.OpenStandalone(f.npcId, f) end
  end, 16)
  f.expand:SetPoint("RIGHT", f.close, "LEFT", -3, 0)
  f.pin = W.IconButton(f, "P", "Pin: keep this card on screen", function() Card.SetPinned(not settings().cardPinned) end, 16)
  f.pin:SetPoint("RIGHT", f.expand, "LEFT", -3, 0)

  f.name = W.Text(f, "title", 15, "text")
  f.name:SetPoint("TOPLEFT", f.logo, "TOPRIGHT", 6, 2)
  f.name:SetPoint("RIGHT", f.pin, "LEFT", -4, 0)
  f.sub = W.Text(f, "narrow", 11, "muted")
  f.sub:SetPoint("TOPLEFT", 10, -28)
  f.sub:SetWidth(INNER)
  f.subTag = W.SourceTag(f)
  f.subTag:SetPoint("TOPRIGHT", -10, -28)

  f.health = W.Bar(f, INNER, 12, "health", "healthBg")
  f.health:SetPoint("TOPLEFT", 10, -44)

  f.lines = {}
  for i = 1, MAX_LINES do
    local l = CreateFrame("Frame", nil, f)
    l:SetSize(INNER, 16)
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetSize(14, 14)
    l.icon:SetPoint("LEFT", 0, 0)
    l.left = W.Text(l, "narrow", 11, "text")
    l.right = W.Text(l, "narrow", 11, "muted", "RIGHT")
    l.tag = W.SourceTag(l)
    l.tag:SetPoint("RIGHT", 0, 0)
    l.right:SetPoint("RIGHT", l.tag, "LEFT", -4, 0)
    l:EnableMouse(true)
    f.lines[i] = l
  end
  f.note = W.Text(f, "narrow", 10, "muted")
  f.note:SetWidth(INNER)
  f.note:SetWordWrap(true)

  Card.frame = f
  Card.UpdatePin()
  return f
end

function Card.UpdatePin()
  local f = Card.frame
  if not f then return end
  local on = settings().cardPinned
  f.pin:SetActive(on)
  f.pin.label:SetTextColor(W.rgba(on and "accent" or "muted"))
  f:SetBackdropBorderColor(W.rgba(on and "accent" or "border"))
end

function Card.SetPinned(on)
  settings().cardPinned = on and true or false
  Card.UpdatePin()
  if not on and not ns.Bestiary.live then Card.Hide() end
end

local function setLine(l, y, opts)
  l:ClearAllPoints()
  l:SetPoint("TOPLEFT", Card.frame, "TOPLEFT", 10, -y)
  local x = 0
  if opts.icon then l.icon:SetTexture(opts.icon); l.icon:Show(); x = 18 else l.icon:Hide() end
  l.left:ClearAllPoints()
  l.left:SetPoint("LEFT", x, 0)
  l.left:SetWidth(INNER - x - 70)
  l.left:SetText(opts.text)
  l.right:SetText(opts.right or "")
  l.tag:SetSource(opts.src)
  if opts.item then
    -- same as every item row: click = item page, shift-click = link in chat, ctrl-click = preview
    l.itemID = opts.item
    ns.ItemClick.Bind(l, function(self) return self.itemID end)
  else
    l.itemID = nil
    l:SetScript("OnEnter", nil); l:SetScript("OnLeave", nil); l:SetScript("OnMouseUp", nil)
  end
  l:Show()
end

-- Health bar from RAW values: they may be secret in combat; StatusBar accepts
-- secrets, and we only do arithmetic when they are not.
function Card.UpdateHealth(snap)
  local f = Card.frame
  if not f or not snap or f.npcId ~= snap.npcId then return end
  local raw = snap.raw or {}
  local hp, max = raw.health, raw.healthMax
  if hp == nil or max == nil then f.health:Hide(); return end
  f.health:Show()
  pcall(f.health.SetMinMaxValues, f.health, 0, max)
  pcall(f.health.SetValue, f.health, hp)
  if C.IsSecret(hp) or C.IsSecret(max) then
    pcall(f.health.text.SetText, f.health.text, hp)
  elseif max > 0 then
    f.health.text:SetText(("%s / %s  (%d%%)"):format(W.Thousands(hp), W.Thousands(max), math.floor(hp / max * 100 + 0.5)))
  else
    f.health.text:SetText("")
  end
end

function Card.Render(npcId, snap)
  local f = Card.Create()
  f.npcId = npcId
  f.snap = snap
  for _, l in ipairs(f.lines) do l:Hide() end

  if not npcId then
    -- identity hidden right now (combat secrets): show what we can, fill in after combat
    pcall(f.name.SetText, f.name, snap and snap.raw and snap.raw.name or "Unknown")
    f.sub:SetText("")
    f.subTag:SetSource(nil)
    Card.UpdateHealth(snap)
    f.note:ClearAllPoints()
    f.note:SetPoint("TOPLEFT", 10, -62)
    f.note:SetText("Details appear after combat.")
    f:SetHeight(84)
    return
  end

  local merged = ns.Bestiary.Merged(npcId)
  local V = function(k) return P.Value(merged, k) end
  f.name:SetText(V("name") or ("NPC " .. npcId))
  local level, lsrc = V("level")
  local bits = { "Level " .. MobPage.LevelText(level, V("levelMax"), snap and snap.skull) }
  local cls = MobPage.ClassificationText(V("classification"))
  if cls then bits[#bits + 1] = cls end
  local typ = MobPage.TypeText(merged)
  if typ then bits[#bits + 1] = typ end
  f.sub:SetText(table.concat(bits, "  ·  "))
  f.subTag:SetSource(lsrc)

  local y = 44
  if snap and snap.npcId == npcId then
    Card.UpdateHealth(snap)
    y = y + 18
  else
    f.health:Hide()
  end

  local n = 0
  local function add(opts)
    if n >= MAX_LINES then return end
    n = n + 1
    setLine(f.lines[n], y, opts)
    y = y + 17
  end

  local kills, ksrc = V("kills")
  if kills and kills > 0 then add({ text = "|cff9a92a8Guild kills|r  " .. W.Thousands(kills), src = ksrc }) end
  local fk, fksrc = V("firstKiller")
  if fk then add({ text = "|cff9a92a8First kill|r  " .. C.ShortName(fk), src = fksrc }) end

  -- top drops (best known rate first)
  local shown = 0
  for _, e in ipairs(merged.lootList) do
    if shown >= 3 then break end
    local src = e.sources.foreverdb and "foreverdb" or e.sources.guild and "guild" or next(e.sources)
    local s = e.sources[src]
    local _, _, _, icon = C.ItemInfo(e.itemID)
    add({ text = MobPage.ItemText(e.itemID), right = MobPage.pct(s and s.rate), src = src, icon = icon or 134400, item = e.itemID })
    shown = shown + 1
  end

  -- one ability teaser
  local abil = next(merged.abilities) and select(2, next(merged.abilities))
  if abil then
    local nm = C.SpellName(abil.spellID) or abil.name
    if nm then add({ text = "|cff9a92a8Casts|r  " .. nm, src = abil.sources.foreverdb and "foreverdb" or "guild" }) end
  end

  local note
  if n == 0 then
    note = "New to the LOMB bestiary. Kill and loot it to start the record."
  elseif merged.credits.foreverdb then
    note = merged.credits.foreverdb.credit
  end
  f.note:ClearAllPoints()
  f.note:SetPoint("TOPLEFT", 10, -(y + 2))
  f.note:SetText(note or "")
  if note then y = y + (f.note:GetStringHeight() or 12) + 4 end
  f:SetHeight(y + 10)
end

function Card.Show(snap)
  if not settings().showCard then return end
  if C.InCombat() and not settings().cardInCombat then return end
  local f = Card.Create()
  ns.SafeCall(Card.Render, snap and snap.npcId, snap)
  f:Show()
end

function Card.Hide(force)
  if not Card.frame then return end
  if force then settings().cardPinned = false; Card.UpdatePin() end
  Card.frame:Hide()
end

function Card.Toggle()
  if Card.frame and Card.frame:IsShown() then Card.Hide(true) return end
  local live = ns.Bestiary.live
  if live then Card.Show(live) else
    ns.Print("Target a creature to see its card.")
  end
end

ns:Listen("TARGET_CHANGED", function(snap)
  if snap then
    if settings().cardPinned and Card.frame and Card.frame:IsShown() and Card.frame.npcId
      and Card.frame.npcId ~= snap.npcId then
      return -- pinned to another mob: leave it alone
    end
    Card.Show(snap)
  elseif not settings().cardPinned then
    Card.Hide()
  end
end)

ns:Listen("TARGET_HEALTH", function(snap) Card.UpdateHealth(snap) end)

ns:Listen("BESTIARY_UPDATED", function(npcId)
  local f = Card.frame
  if f and f:IsShown() and f.npcId == npcId then
    local live = ns.Bestiary.live
    ns.SafeCall(Card.Render, npcId, live and live.npcId == npcId and live or nil)
  end
end)

ns:On("PLAYER_REGEN_DISABLED", function()
  if not settings().cardInCombat and Card.frame and not settings().cardPinned then Card.frame:Hide() end
end)
ns:On("PLAYER_REGEN_ENABLED", function()
  if not settings().cardInCombat and ns.Bestiary.live and settings().showCard then Card.Show(ns.Bestiary.live) end
end)
