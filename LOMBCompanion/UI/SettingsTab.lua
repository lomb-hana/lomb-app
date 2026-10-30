-- LOMB Companion: Settings tab.
local _, ns = ...
local W, UI = ns.Widgets, ns.UI

local function S() return ns.db.settings end

local OPTIONS = {
  { section = "Sharing with the guild" },
  { key = "shareProfile", label = "Share my level, class, professions, gear, XP and hours played",
    tip = "Gear is item + enchant IDs only; XP in 5% steps. Never gold, location history, chat, or anything else. "
      .. "Off = guildmates just see that you have the addon (and your main, if you picked one).",
    after = function()
      ns:Fire("PROFILE_CHANGED"); ns.Shared.MarkDirty("gr")
      if ns.Sync then ns.Sync.SendProfile(true) end
    end },
  { key = "shareBestiary", label = "Share bestiary records (kills, sightings, loot, abilities)",
    tip = "Off = you neither send nor receive bestiary data. Your own records still work." },
  { key = "shareRecipes", label = "Share the recipes I know (for \"who can craft\")",
    tip = "Item and spell IDs of what you can make, read when you open a profession window. Off = guildmates won't see you as a crafter.",
    after = function() ns.Shared.MarkDirty("rc") end },
  { key = "shareActivity", label = "Share my news and leaderboard stats",
    tip = "Level-ups, rare kills and new recipes for the News tab; kills, rares and milestone times for the " ..
      "Leaderboard. Off = you're left out of both (your roster level still shows).",
    after = function() ns.Shared.MarkDirty("st"); ns.Shared.MarkDirty("nw") end },
  { key = "shareRares", label = "Tell guildmates when I spot a rare",
    tip = "Sends the rare's name and level, the zone, and where you are on the map (e.g. 45, 62) when you see it. "
      .. "At most once per rare every 10 minutes. Nothing else about where you are is sent." },
  { key = "shareAttendance", label = "Share the event attendance I record",
    tip = "Names of guildmates in the organizer's group during guild events, and how many 5-minute snapshots "
      .. "they were in. Nothing about where anyone was.",
    after = function() ns.Shared.MarkDirty("at") end },
  { section = "Tooltips" },
  { key = "tooltips", label = "Add guild info to item tooltips (crafters)" },
  { section = "Rare alerts" },
  { key = "rareAlerts", label = "Show an alert when a rare is spotted (by me or a guildmate)" },
  { key = "rareSound", label = "Play a sound with rare alerts" },
  { section = "Events" },
  { key = "recordAttendance", label = "Record attendance at guild events",
    tip = "During a guild calendar event, if you're grouped with the organizer, note who's in the group "
      .. "every 5 minutes (after combat). Officers (top 2 ranks) can correct it in the Events tab." },
  { section = "Guild bank" },
  { key = "isBankChar", label = "This character is the guild bank",
    tip = "Per character. The bank character counts its bags and bank and shares the item list (and what went "
      .. "in or out) with the guild. Ticked automatically if this character's name or guild note says \"bank\".",
    get = function() return ns.Bank.IsBankChar() end,
    set = function(v) ns.Bank.SetBankChar(v) end },
  { key = "shareBankFunds", label = "Show the bank character's gold as guild bank funds",
    tip = "Only ever the bank character's own gold. Nobody else's gold is read or shared.",
    after = function() ns.Shared.MarkDirty("bk") end },
  { section = "Bestiary card" },
  { key = "showCard", label = "Show the card when I target a creature",
    after = function(v) if not v and ns.BestiaryCard then ns.BestiaryCard.Hide(true) end end },
  { key = "cardInCombat", label = "Keep the card visible in combat" },
  { key = "cardLocked", label = "Lock card position" },
  { section = "Other" },
  { key = "hideMinimap", label = "Hide minimap button",
    get = function() return S().minimap.hide end,
    set = function(v) S().minimap.hide = v; if ns.Minimap then ns.Minimap.Update() end end },
  { key = "debug", label = "Debug messages in chat" },
}

UI.RegisterTab({
  id = "settings", label = "Settings", order = 90, gap = true,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.checks = {}
    -- options column scrolls with the mouse wheel once it outgrows the window
    local scroll = CreateFrame("ScrollFrame", nil, p)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -214, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(420, 10)
    scroll:SetScrollChild(body)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local max = math.max(0, body:GetHeight() - self:GetHeight())
      self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 44)))
    end)
    p.scroll, p.body = scroll, body
    local y = 0
    for _, o in ipairs(OPTIONS) do
      if o.section then
        local t = W.SectionTitle(body, o.section)
        t:SetPoint("TOPLEFT", 0, -y)
        y = y + 22
      else
        local get = o.get or function() return S()[o.key] end
        local set = o.set or function(v) S()[o.key] = v end
        local c = W.Check(body, o.label, get, function(v) set(v); if o.after then o.after(v) end end, o.tip)
        c:SetWidth(400)
        c:SetPoint("TOPLEFT", 8, -y)
        c.key = o.key
        p.checks[#p.checks + 1] = c
        p.checks[o.key] = c
        y = y + 22
      end
    end
    body:SetHeight(y + 4)

    -- right column: data + actions
    local box = W.Panel(p, "panel", "border")
    box:SetPoint("TOPRIGHT", 0, 0)
    box:SetSize(200, 250)
    local t = W.SectionTitle(box, "Your data")
    t:SetPoint("TOPLEFT", 10, -8)
    p.stats = W.Text(box, "narrow", 11, "text")
    p.stats:SetPoint("TOPLEFT", 10, -30)
    p.stats:SetWidth(180)
    p.stats:SetWordWrap(true)
    p.stats:SetSpacing(3)

    local b1 = W.Button(box, "Reset positions", 180, 22, function()
      S().cardPoint, S().windowPoint, S().cardPinned, S().toastPoint = nil, nil, false, nil
      if ns.RareToast.frame then
        ns.RareToast.frame:ClearAllPoints()
        ns.RareToast.frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
      end
      if ns.BestiaryCard.frame then
        ns.BestiaryCard.frame:ClearAllPoints()
        ns.BestiaryCard.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 260, -140)
        ns.BestiaryCard.UpdatePin()
      end
      UI.frame:ClearAllPoints(); UI.frame:SetPoint("CENTER")
    end)
    b1:SetPoint("BOTTOMLEFT", 10, 40)
    local b0 = W.Button(box, "Preview a rare alert", 180, 22, function()
      ns.RareToast.Show({ n = 0, nm = "Mother Fang", lv = 10, cl = "rare", z = "Elwynn Forest", x = 62, y = 79,
        by = ns.playerKey, t = time() })
    end)
    b0:SetPoint("BOTTOMLEFT", 10, 68)
    b0.tip = "Shows what an alert looks like (nothing is sent). Drag the alert to move it."
    local b2 = W.Button(box, "Clear bestiary data", 180, 22, function()
      W.Confirm("Clear the bestiary saved on this computer?\nGuildmates' copies are not affected, and some records will sync back.",
        function()
          wipe(ns.db.bestiary)
          ns:Fire("BESTIARY_UPDATED")
          UI.Refresh("settings")
          ns.Print("Bestiary cleared.")
        end)
    end)
    b2:SetPoint("BOTTOMLEFT", 10, 12)
    b2.label:SetTextColor(W.rgba("bad"))
    return p
  end,
  refresh = function(p)
    for _, c in ipairs(p.checks) do c:Refresh() end
    local mobs, recs = 0, 0
    for _, m in pairs(ns.db.bestiary) do
      mobs = mobs + 1
      for _ in pairs(m.rec or {}) do recs = recs + 1 end
    end
    local kb = math.floor(ns.DB.ApproxSize(ns.db) / 1024 + 0.5)
    p.stats:SetText(("Creatures known: |cffffffff%d|r\nGuild records: |cffffffff%d|r\nSaved size: |cffffffff~%d KB|r\nAccount: |cffffffff%s|r"):format(
      mobs, recs, kb, ns.Compat.IsRestrictedAccount() and "trial (receive-only)" or "full"))
  end,
})
