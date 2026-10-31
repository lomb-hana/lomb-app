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

local function statLine(parent, y)
  local label = W.Text(parent, "narrow", 11, "muted")
  label:SetPoint("TOPLEFT", 10, y)
  local value = W.Text(parent, "body", 12, "text", "RIGHT")
  value:SetPoint("TOPRIGHT", -10, y)
  value:SetWidth(200)
  return { label = label, value = value }
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
  local it = W.SectionTitle(info, "Progress")
  it:SetPoint("TOPLEFT", 10, -6)
  f.xpLabel = W.Text(info, "narrow", 11, "muted")
  f.xpLabel:SetPoint("TOPLEFT", 10, -28)
  f.xp = W.Bar(info, 280, 8, "accent", "panel2")
  f.xp:SetPoint("TOPLEFT", 10, -44)
  f.xp:SetPoint("RIGHT", -10, 0)
  f.xp.text:Hide()
  f.stats = {}
  local defs = { { "ilvl", "Item level" }, { "played", "Played" }, { "kills", "Kills" }, { "rares", "Rares" },
    { "main", "Main" }, { "alts", "Alts" } }
  for i, d in ipairs(defs) do
    local s = statLine(info, -58 - (i - 1) * 18)
    s.label:SetText(d[2])
    f.stats[d[1]] = s
  end
  local pt = W.SectionTitle(info, "Professions")
  pt:SetPoint("TOPLEFT", 10, -172)
  f.profs = {}
  for i = 1, 4 do
    local label = W.Text(info, "narrow", 11, "text")
    label:SetPoint("TOPLEFT", 10, -194 - (i - 1) * 18)
    local bar = W.Bar(info, 80, 8, "gold", "panel2")
    bar:SetPoint("TOPRIGHT", -10, -197 - (i - 1) * 18)
    f.profs[i] = { label = label, bar = bar }
  end
  f.noProf = W.Text(info, "narrow", 11, "muted")
  f.noProf:SetPoint("TOPLEFT", 10, -194)
  local nt = W.SectionTitle(info, "Recent news")
  nt:SetPoint("TOPLEFT", 10, -270)
  f.news = {}
  for i = 1, 4 do
    local l = W.Text(info, "narrow", 11, "text")
    l:SetPoint("TOPLEFT", 10, -290 - (i - 1) * 16)
    l:SetPoint("RIGHT", -10, 0)
    l:SetWordWrap(false)
    f.news[i] = l
  end

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
  ns:Listen("SHARED_UPDATED", function(kind, owner) if owner == f.name and (kind == "gr" or kind == "st") then soon() end end)
  ns:On("GET_ITEM_INFO_RECEIVED", soon)
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

  local n = 0
  for _, e in ipairs(ns.News and ns.News.items or {}) do
    if n >= #f.news then break end
    if ns.News.Involves(e, p.name) then
      n = n + 1
      f.news[n]:SetText(ns.News.Text(e) .. "  |cff777080" .. ns.News.Ago(e.t) .. "|r")
    end
  end
  for i = n + 1, #f.news do f.news[i]:SetText(i == 1 and "|cff777080Nothing yet.|r" or "") end
end
