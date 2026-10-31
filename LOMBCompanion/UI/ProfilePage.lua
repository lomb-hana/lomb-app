-- LOMB Companion: one guildmate's profile (opened from the Roster tab).
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local C = ns.Compat
local Page = {}
ns.ProfilePage = Page

local GEAR_W, SLOT_H = 330, 17

local function itemLine(parent)
  local l = CreateFrame("Frame", nil, parent)
  l:SetSize(GEAR_W - 16, SLOT_H)
  l:EnableMouse(true)
  l.icon = l:CreateTexture(nil, "ARTWORK")
  l.icon:SetSize(14, 14)
  l.icon:SetPoint("LEFT", 0, 0)
  l.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  l.slot = W.Text(l, "narrow", 10, "muted", "RIGHT")
  l.slot:SetPoint("RIGHT", 0, 0)
  l.slot:SetWidth(62)
  l.name = W.Text(l, "body", 11, "text")
  l.name:SetPoint("LEFT", 20, 0)
  l.name:SetPoint("RIGHT", l.slot, "LEFT", -4, 0)
  -- gear: the exact item (enchant, "of the ..." suffix) for the tooltip and the chat link;
  -- click opens the base item's page
  ns.ItemClick.Bind(l, function(self) return self.itemString end)
  return l
end

-- label on the left, value on the right; w = nil spans the whole panel
local function statLine(parent, x, y, w)
  local label = W.Text(parent, "narrow", 11, "muted")
  label:SetPoint("TOPLEFT", x, y)
  local value = W.Text(parent, "body", 12, "text", "RIGHT")
  if w then
    value:SetPoint("TOPLEFT", x + 40, y)
    value:SetWidth(w - 40)
  else
    value:SetPoint("TOPRIGHT", -10, y)
    value:SetWidth(220)
  end
  return { label = label, value = value }
end

local BADGES, BADGE, BADGE_ROW = 22, 22, 11

local function badge(parent)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(BADGE, BADGE)
  b:EnableMouse(true)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.more = W.Text(b, "narrow", 10, "gold", "CENTER", "OVERLAY")
  b.more:SetPoint("CENTER")
  W.Tooltip(b, function(tt, self)
    if self.extra then
      tt:SetText(("%d more achievements"):format(self.extra), 1, 1, 1)
      tt:AddLine("Click \"See all\" to list them.", 0.6, 0.57, 0.66)
      return
    end
    local e = self.entry
    if not e then return end
    tt:SetText(e.def.name, 0.95, 0.78, 0.36)
    tt:AddLine(e.def.desc, 0.9, 0.88, 0.94, true)
    tt:AddLine("Earned " .. ns.Achievements.DateText(e.t, e.x), 0.6, 0.57, 0.66)
    if e.x then tt:AddLine("~ before LOMB could see it: the exact date isn't known.", 0.6, 0.57, 0.66, true) end
  end)
  return b
end

function Page.New(parent, onBack)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f:Hide()
  f.back = W.Button(f, "< Roster", 70, 22, onBack)
  f.back:SetPoint("TOPLEFT", 0, 0)
  f.title = W.Text(f, "title", 18, "text")
  f.title:SetPoint("LEFT", f.back, "RIGHT", 10, 1)
  f.sub = W.Text(f, "narrow", 11, "muted")
  f.sub:SetPoint("TOPLEFT", 0, -28)
  f.sub:SetWidth(520)
  f.whisper = W.Button(f, "Whisper", 70, 22, function()
    if f.name and ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. C.ShortName(f.name) .. " ") end
  end)
  f.whisper:SetPoint("TOPRIGHT", 0, 0)
  f.whisper.tip = "Opens a whisper in your chat box. Nothing is sent until you press Enter."

  -- gear (left)
  local gear = W.Panel(f, "panel", "border")
  gear:SetPoint("TOPLEFT", 0, -48)
  gear:SetPoint("BOTTOMLEFT", 0, 0)
  gear:SetWidth(GEAR_W)
  f.gearTitle = W.SectionTitle(gear, "Equipped")
  f.gearTitle:SetPoint("TOPLEFT", 8, -6)
  f.gearMeta = W.Text(gear, "narrow", 10, "muted", "RIGHT")
  f.gearMeta:SetPoint("TOPRIGHT", -8, -8)
  f.slots = {}
  for i, s in ipairs(ns.Profiles.SLOTS) do
    local l = itemLine(gear)
    l:SetPoint("TOPLEFT", 8, -26 - (i - 1) * SLOT_H)
    l.slotId = s[1]
    l.slot:SetText(s[2])
    f.slots[i] = l
  end
  f.noGear = W.Text(gear, "body", 12, "muted", "CENTER")
  f.noGear:SetPoint("CENTER", 0, 0)
  f.noGear:SetWidth(GEAR_W - 40)
  f.noGear:SetWordWrap(true)

  -- details (right)
  local info = W.Panel(f, "panel", "border")
  info:SetPoint("TOPLEFT", gear, "TOPRIGHT", 8, 0)
  info:SetPoint("BOTTOMRIGHT", 0, 0)
  f.info = info
  -- achievements (top: the part the guild looks at first)
  local at = W.SectionTitle(info, "Achievements")
  at:SetPoint("TOPLEFT", 10, -6)
  f.achAll = W.Button(info, "See all", 56, 18, function()
    if f.name and ns.AchievementsTab then ns.AchievementsTab.ShowFor(f.name) end
  end)
  f.achAll:SetPoint("TOPRIGHT", -6, -5)
  f.achAll.tip = "Every achievement, with dates."
  f.achCount = W.Text(info, "narrow", 11, "gold", "RIGHT")
  f.achCount:SetPoint("RIGHT", f.achAll, "LEFT", -8, 0)
  f.badges = {}
  for i = 1, BADGES do
    local b = badge(info)
    local col, r = (i - 1) % BADGE_ROW, math.floor((i - 1) / BADGE_ROW)
    b:SetPoint("TOPLEFT", 10 + col * (BADGE + 3), -28 - r * (BADGE + 3))
    f.badges[i] = b
  end
  f.achLatest = {}
  for i = 1, 3 do
    local l = W.Text(info, "narrow", 11, "text")
    l:SetPoint("TOPLEFT", 10, -80 - (i - 1) * 16)
    l:SetPoint("RIGHT", -10, 0)
    l:SetWordWrap(false)
    f.achLatest[i] = l
  end
  f.achEmpty = W.Text(info, "narrow", 11, "muted")
  f.achEmpty:SetPoint("TOPLEFT", 10, -30)
  f.achEmpty:SetPoint("RIGHT", -10, 0)
  f.achEmpty:SetWordWrap(true)
  local div = W.Divider(info)
  div:SetPoint("TOPLEFT", 10, -130)
  div:SetPoint("TOPRIGHT", -10, -130)

  local it = W.SectionTitle(info, "Progress")
  it:SetPoint("TOPLEFT", 10, -136)
  f.xpLabel = W.Text(info, "narrow", 11, "muted")
  f.xpLabel:SetPoint("TOPLEFT", 10, -156)
  f.xp = W.Bar(info, 280, 6, "accent", "panel2")
  f.xp:SetPoint("TOPLEFT", 10, -170)
  f.xp:SetPoint("RIGHT", -10, 0)
  f.xp.text:Hide()
  f.stats = {}
  local half = 136
  local defs = { { "ilvl", "Item lvl", 10, -182, half }, { "played", "Played", 158, -182, half },
    { "kills", "Kills", 10, -198, half }, { "rares", "Rares", 158, -198, half },
    { "main", "Main", 10, -214 }, { "alts", "Alts", 10, -230 } }
  for _, d in ipairs(defs) do
    local st = statLine(info, d[3], d[4], d[5])
    st.label:SetText(d[2])
    f.stats[d[1]] = st
  end
  local pt = W.SectionTitle(info, "Professions")
  pt:SetPoint("TOPLEFT", 10, -250)
  f.profs = {}
  for i = 1, 4 do
    local x, y = 10 + ((i - 1) % 2) * 148, -272 - math.floor((i - 1) / 2) * 26
    local label = W.Text(info, "narrow", 11, "text")
    label:SetPoint("TOPLEFT", x, y)
    local bar = W.Bar(info, 136, 6, "gold", "panel2")
    bar:SetPoint("TOPLEFT", x, y - 14)
    bar.text:Hide()
    f.profs[i] = { label = label, bar = bar }
  end
  f.noProf = W.Text(info, "narrow", 11, "muted")
  f.noProf:SetPoint("TOPLEFT", 10, -272)

  function f:Show2(name)
    self.name = name
    self:Show()
    self:Render()
  end
  function f:Render()
    if self.name and self:IsShown() then ns.SafeCall(Page.Render, self, ns.Profiles.Get(self.name)) end
  end
  local soon = ns.Debounce(0.3, function() f:Render() end)
  ns:Listen("PROFILES_UPDATED", soon)
  ns:Listen("PEER_UPDATED", soon)
  ns:Listen("SHARED_UPDATED", function(kind, owner) if owner == f.name and (kind == "gr" or kind == "st" or kind == "ah") then soon() end end)
  ns:On("GET_ITEM_INFO_RECEIVED", soon)
  ns:Listen("ACHIEVEMENTS_UPDATED", soon)
  return f
end

local function professionList(pr)
  local out = {}
  for code, v in pairs(type(pr) == "table" and pr or {}) do
    local rank = type(v) == "table" and v[1] or v
    local max = type(v) == "table" and v[2] or rank
    out[#out + 1] = { name = ns.Me.FROM_CODE[code] or code, rank = tonumber(rank) or 0, max = tonumber(max) or 0 }
  end
  table.sort(out, function(a, b) return a.rank > b.rank end)
  return out
end

local function shortNames(list)
  local out = {}
  for _, n in ipairs(list) do
    local r = ns.Roster.byName[n]
    out[#out + 1] = T.classColorText(r and r.class, C.ShortName(n))
  end
  return table.concat(out, ", ")
end

function Page.Render(f, p)
  local row = p.row
  local cls = row and row.class or (p.profile and p.profile.cl)
  f.title:SetText(T.classColorText(cls, p.short))
  local bits = {}
  local lv = row and row.level or (p.profile and p.profile.lv)
  bits[#bits + 1] = ("Level %s %s"):format(tostring(lv or "?"), row and row.className or "")
  if row and row.rank then bits[#bits + 1] = row.rank end
  if row and row.zone and row.zone ~= "" then bits[#bits + 1] = row.zone end
  if row then bits[#bits + 1] = ns.Roster.FormatLastOnline(row) end
  if p.peer and p.peer.v then bits[#bits + 1] = "|cffb873ffLOMB " .. tostring(p.peer.v) .. "|r" end
  local A = ns.Achievements
  local earned = A and A.For(p.name) and A.Earned(p.name) or nil
  if earned then
    bits[#bits + 1] = ("|cfff2c75c★ %d achievement%s|r"):format(#earned, #earned == 1 and "" or "s")
  end
  f.sub:SetText(table.concat(bits, "  ·  "))
  f.whisper:SetShown(not p.isMe)

  -- gear
  local any = false
  for _, l in ipairs(f.slots) do
    local s = p.gear and p.gear[l.slotId]
    local id = ns.Profiles.ParseCompact(s)
    l.itemString = id and ns.Profiles.ItemString(s) or nil
    if id then
      any = true
      local _, _, _, icon = C.ItemInfo(id)
      l.icon:SetTexture(icon or 134400)
      l.icon:Show()
      l.name:SetText(W.ItemText(id))
    else
      l.icon:Hide()
      l.name:SetText("|cff555060-|r")
    end
  end
  for _, l in ipairs(f.slots) do l:SetShown(any) end
  f.noGear:SetShown(not any)
  if p.peer == nil and not p.isMe then
    f.noGear:SetText("Doesn't have LOMB Companion yet, so their gear isn't shared.\n" ..
      "Inspect them in game and what you saw shows up here.")
  elseif p.peer and p.peer.sharing == false then
    f.noGear:SetText("Has profile sharing turned off.")
  else
    f.noGear:SetText("No gear shared yet. It shows up a minute or so after they log in.")
  end
  local il = p.profile and p.profile.il
  local meta = {}
  if any then
    local empty = ns.Profiles.EmptySlots(p.gear)
    if empty > 0 then meta[#meta + 1] = ("|cffe0a060%d empty|r"):format(empty) end
  end
  if il then meta[#meta + 1] = "item level " .. il end
  if p.gearSeen then meta[#meta + 1] = "inspected " .. ns.News.Ago(p.gearSeen) end
  f.gearMeta:SetText(table.concat(meta, "  ·  "))

  -- progress
  local maxed = (tonumber(lv) or 0) >= ns.Profiles.MAX_LEVEL
  f.xp:SetShown(p.xp ~= nil and not maxed)
  if maxed then
    f.xpLabel:SetText("Max level")
  elseif p.xp then
    f.xpLabel:SetText(("%d%% of the way to level %d"):format(p.xp, (tonumber(lv) or 0) + 1))
    f.xp:SetMinMaxValues(0, 100); f.xp:SetValue(p.xp)
  else
    f.xpLabel:SetText("XP progress not shared")
  end
  local st = p.stats or {}
  local function set(key, v) f.stats[key].value:SetText(v or "|cff777080-|r") end
  set("ilvl", il and tostring(il))
  set("played", p.profile and p.profile.pt and (W.Thousands(p.profile.pt) .. " hours"))
  set("kills", st.k and W.Thousands(st.k))
  set("rares", st.r and tostring(st.r))
  if p.main then
    set("main", shortNames({ p.main }) .. (p.mainSrc == "note" and "  |cff777080(guild note)|r" or ""))
  else
    set("main", #p.alts > 0 and "This is their main" or nil)
  end
  local alts = {}
  for _, a in ipairs(p.alts) do if a ~= p.name then alts[#alts + 1] = a end end
  set("alts", #alts > 0 and shortNames(alts) or nil)

  local profs = professionList(p.profile and p.profile.pr)
  for i, pb in ipairs(f.profs) do
    local pr = profs[i]
    pb.label:SetShown(pr ~= nil); pb.bar:SetShown(pr ~= nil)
    if pr then
      pb.label:SetText(("%s  |cff999999%d/%d|r"):format(pr.name, pr.rank, pr.max))
      pb.bar:SetMinMaxValues(0, math.max(1, pr.max)); pb.bar:SetValue(pr.rank)
    end
  end
  f.noProf:SetShown(#profs == 0)
  f.noProf:SetText("None shared.")

  Page.RenderAchievements(f, p, earned)
end

function Page.RenderAchievements(f, p, earned)
  local A = ns.Achievements
  local list = earned or {}
  local private = p.isMe and ns.db.settings.shareActivity == false
  f.achCount:SetText(earned and (("%d of %d"):format(#list, A.TOTAL) .. (private and "  |cff777080(only you)|r" or "")) or "")
  f.achAll:SetShown(earned ~= nil)
  local shown = math.min(#list, BADGES)
  local extra = #list > BADGES and (#list - BADGES + 1) or nil
  for i, b in ipairs(f.badges) do
    local e = list[i]
    b.entry, b.extra = nil, nil
    if extra and i == BADGES then
      b.extra = extra
      b.icon:SetColorTexture(0.16, 0.13, 0.2, 1)
      b.more:SetText("+" .. extra)
      b:Show()
    elseif e and i <= shown then
      b.entry = e
      b.icon:SetTexture(e.def.icon)
      b.more:SetText("")
      b:Show()
    else
      b:Hide()
    end
  end
  for i, l in ipairs(f.achLatest) do
    local e = list[i]
    l:SetText(e and ("|cfff2c75c%s|r  |cff777080%s|r"):format(e.def.name, A.DateText(e.t, e.x)) or "")
    l:SetShown(e ~= nil)
  end
  local msg
  if not earned then
    if p.peer == nil then msg = "Doesn't have LOMB Companion yet, so achievements aren't shared."
    else msg = "Has activity sharing turned off, or hasn't sent achievements yet." end
  elseif #list == 0 then
    msg = p.isMe and "None yet. Open the Achievements tab to see what's close." or "None earned yet."
  end
  f.achEmpty:SetText(msg or "")
  f.achEmpty:SetShown(msg ~= nil)
end
