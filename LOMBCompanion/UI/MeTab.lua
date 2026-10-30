-- LOMB Companion: Me tab -- your character at a glance.
local _, ns = ...
local T, W, UI = ns.Theme, ns.Widgets, ns.UI
local Me = ns.Me

local TILE_W, TILE_H = 150, 58

local function tile(parent, label)
  local t = W.Panel(parent, "panel", "border")
  t:SetSize(TILE_W, TILE_H)
  t.label = W.Text(t, "narrow", 10, "muted")
  t.label:SetPoint("TOPLEFT", 10, -8)
  t.label:SetText(label:upper())
  t.value = W.Text(t, "title", 20, "text")
  t.value:SetPoint("TOPLEFT", 10, -22)
  t.sub = W.Text(t, "narrow", 10, "muted")
  t.sub:SetPoint("BOTTOMLEFT", 10, 7)
  return t
end

UI.RegisterTab({
  id = "me", label = "Me", order = 20,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.header = W.Text(p, "title", 18, "text")
    p.header:SetPoint("TOPLEFT", 0, -2)
    p.subheader = W.Text(p, "narrow", 11, "muted")
    p.subheader:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -2)

    p.tiles = {}
    local defs = { { "level", "Level" }, { "played", "Played" }, { "ilvl", "Item level" },
      { "gold", "Gold" }, { "kills", "Kills recorded" }, { "deaths", "Deaths" } }
    for i, d in ipairs(defs) do
      local t = tile(p, d[2])
      local col, rowN = (i - 1) % 3, math.floor((i - 1) / 3)
      t:SetPoint("TOPLEFT", col * (TILE_W + 8), -44 - rowN * (TILE_H + 8))
      p.tiles[d[1]] = t
    end
    p.xp = W.Bar(p.tiles.level, TILE_W - 20, 3, "accent", "panel2")
    p.xp:SetPoint("BOTTOMLEFT", 10, 4)
    p.xp.text:Hide()

    -- professions (right column)
    local right = W.Panel(p, "panel", "border")
    right:SetPoint("TOPLEFT", 3 * (TILE_W + 8) + 4, -44)
    right:SetPoint("TOPRIGHT", 0, -44)
    right:SetHeight(TILE_H * 2 + 8)
    local rt = W.SectionTitle(right, "Professions")
    rt:SetPoint("TOPLEFT", 10, -8)
    p.profBars = {}
    for i = 1, 4 do
      local label = W.Text(right, "narrow", 11, "text")
      label:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 22)
      local bar = W.Bar(right, 80, 10, "gold", "panel2")
      bar:SetPoint("TOPRIGHT", -10, -32 - (i - 1) * 22)
      p.profBars[i] = { label = label, bar = bar }
    end
    p.noProf = W.Text(right, "narrow", 11, "muted")
    p.noProf:SetPoint("TOPLEFT", 10, -32)
    p.noProf:SetText("None learned yet.")

    -- recent loot
    local loot = W.Panel(p, "panel", "border")
    loot:SetPoint("TOPLEFT", 0, -44 - 2 * (TILE_H + 8))
    loot:SetPoint("BOTTOMRIGHT", 0, 0)
    local lt = W.SectionTitle(loot, "Recent loot")
    lt:SetPoint("TOPLEFT", 10, -8)
    p.sharing = W.Text(loot, "narrow", 10, "muted", "RIGHT")
    p.sharing:SetPoint("TOPRIGHT", -10, -10)
    p.lootLines = {}
    for i = 1, 6 do
      local l = W.Text(loot, "narrow", 11, "text")
      l:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 17)
      l:SetWidth(380)
      local r = W.Text(loot, "narrow", 10, "muted", "RIGHT")
      r:SetPoint("TOPRIGHT", -10, -30 - (i - 1) * 17)
      p.lootLines[i] = { l = l, r = r }
    end
    ns:Listen("ME_UPDATED", function(s) if p:IsVisible() then ns.SafeCall(p.Render, p, s) end end)
    ns:Listen("KILL_RECORDED", function() if p:IsVisible() then ns.SafeCall(p.Render, p, Me.stats) end end)
    p.Render = UI.RenderMe
    return p
  end,
  -- Me.Refresh fires ME_UPDATED, which renders (no direct render here = no loop)
  refresh = function() Me.Refresh() end,
})

function UI.RenderMe(p, s)
    p.header:SetText(T.classColorText(s.class, s.name or "?"))
    local guild = ns.Compat.Call(GetGuildInfo, "player")
    p.subheader:SetText(("Level %s %s %s%s"):format(tostring(s.level or "?"), s.race or "", s.className or "",
      guild and ("  ·  <" .. guild .. ">") or ""))

    p.tiles.level.value:SetText(s.level or "?")
    if s.xp and s.xpMax and s.xpMax > 0 then
      p.xp:SetMinMaxValues(0, s.xpMax); p.xp:SetValue(s.xp)
      p.tiles.level.sub:SetText(("%d%% to %d"):format(math.floor(s.xp / s.xpMax * 100), (s.level or 0) + 1))
    end
    local total, lvl = Me.PlayedNow()
    p.tiles.played.value:SetText(W.FormatDuration(total))
    p.tiles.played.sub:SetText(lvl and ("this level " .. W.FormatDuration(lvl)) or "waiting for /played")
    p.tiles.ilvl.value:SetText(s.ilvl or "-")
    p.tiles.ilvl.sub:SetText("equipped average")
    p.tiles.gold.value:SetText(s.money and W.Thousands(math.floor(s.money / 10000)) or "-")
    p.tiles.gold.sub:SetText(s.money and W.FormatMoney(s.money) or "")
    p.tiles.kills.value:SetText(W.Thousands(ns.char.kills or 0))
    p.tiles.kills.sub:SetText("since installing LOMB")
    p.tiles.deaths.value:SetText(ns.char.deaths or 0)
    p.tiles.deaths.sub:SetText("since installing LOMB")

    local profs = {}
    for name, v in pairs(s.professions or {}) do profs[#profs + 1] = { name = name, rank = v.rank, max = v.max } end
    table.sort(profs, function(a, b) return a.rank > b.rank end)
    for i, pb in ipairs(p.profBars) do
      local pr = profs[i]
      pb.label:SetShown(pr ~= nil); pb.bar:SetShown(pr ~= nil)
      if pr then
        pb.label:SetText(("%s  |cff999999%d/%d|r"):format(pr.name, pr.rank, pr.max))
        pb.bar:SetMinMaxValues(0, math.max(1, pr.max)); pb.bar:SetValue(pr.rank)
      end
    end
    p.noProf:SetShown(#profs == 0)

    local log = ns.char.lootLog
    for i, line in ipairs(p.lootLines) do
      local e = log[i]
      if e then
        local mob = ns.db.bestiary[e.n]
        line.l:SetText(("%s%s  |cff999999from %s|r"):format(W.ItemText(e.i), (e.q or 1) > 1 and (" x" .. e.q) or "",
          mob and mob.nm or ("NPC " .. e.n)))
        line.r:SetText(date("%b %d %H:%M", e.t))
      else
        line.l:SetText(i == 1 and "|cff999999Nothing yet. Loot something and it shows up here.|r" or "")
        line.r:SetText("")
      end
    end
    p.sharing:SetText(ns.db.settings.shareProfile and "Sharing level, class, professions, item level, hours played"
      or "Profile sharing is off")
end
