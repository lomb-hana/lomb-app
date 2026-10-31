-- LOMB Companion: first-run welcome tour. Four short cards over the main window,
-- shown once (the first time the window opens), skippable, and reopenable from
-- Settings or with /lomb tour.
local _, ns = ...
local W = ns.Widgets
local Tour = {}
ns.Tour = Tour

-- target(): the frame to outline (nil = the whole content area); tab: open this tab first
Tour.STEPS = {
  { title = "Welcome to LOMB Companion",
    body = "A guild companion for Land of Make Believe. It shares a few things with guildmates who also run it, "
      .. "over the guild's hidden addon channel. Nothing leaves the guild and nothing is sent to a website.\n\n"
      .. "This takes four quick steps. Skip it any time; you can see it again from Settings.",
    target = function() return ns.UI.content end },
  { title = "The tabs",
    body = "Roster, News, Crafters, Events, the guild bank, wishlists, quests, the bestiary and more live down the left. "
      .. "A number next to a tab means something new happened there.\n\n"
      .. "Hover any button or column for a short explanation.",
    target = function() return ns.UI.nav end },
  { title = "You choose what's shared",
    body = "Settings has a switch for each thing: your profile and professions, news, your bank and wishlist, "
      .. "and more. Turn any of them off and guildmates stop seeing it. Your gold is never shared.",
    tab = "settings", target = function() return ns.UI.content end },
  { title = "If something looks wrong",
    body = "Type |cffb873ff/lomb test|r. It checks the game connection, the guild roster, the addon channel, the "
      .. "calendar and the bundled data, then gives you a report to copy and paste in Discord.\n\n"
      .. "That's it. Have fun!",
    target = function() return nil end },
}

local function seen() return ns.db and ns.db.settings.tourDone end
local function markSeen() if ns.db then ns.db.settings.tourDone = true end end

function Tour.Build()
  if Tour.frame then return Tour.frame end
  local main = ns.UI.Create()
  local f = W.Panel(main, "panel", "accent")
  f:SetSize(360, 196)
  f:SetFrameStrata("DIALOG")
  f:SetPoint("CENTER", main, "CENTER", 40, -10)
  f:EnableMouse(true)
  f:Hide()

  f.step = W.Text(f, "narrow", 11, "muted", "RIGHT")
  f.step:SetPoint("TOPRIGHT", -12, -12)
  f.title = W.Text(f, "title", 18, "gold", "LEFT")
  f.title:SetPoint("TOPLEFT", 14, -12)
  f.title:SetPoint("RIGHT", f.step, "LEFT", -8, 0)
  f.body = W.Text(f, "body", 11, "text", "LEFT")
  f.body:SetPoint("TOPLEFT", 14, -42)
  f.body:SetPoint("RIGHT", -14, 0)
  f.body:SetJustifyV("TOP")
  f.body:SetWordWrap(true)
  if f.body.SetSpacing then f.body:SetSpacing(2) end

  f.skip = W.Button(f, "Skip", 64, 22, function() Tour.Stop() end)
  f.skip:SetPoint("BOTTOMLEFT", 12, 12)
  f.skip.tip = "Close the tour. Reopen it from Settings or with /lomb tour."
  f.next = W.Button(f, "Next", 72, 22, function() Tour.Go(Tour.i + 1) end)
  f.next:SetPoint("BOTTOMRIGHT", -12, 12)
  f.next.tip = "Next step"
  f.back = W.Button(f, "Back", 64, 22, function() Tour.Go(Tour.i - 1) end)
  f.back:SetPoint("RIGHT", f.next, "LEFT", -6, 0)
  f.back.tip = "Previous step"

  -- outline around what the step talks about
  local hl = CreateFrame("Frame", nil, main, "BackdropTemplate")
  W.Skin(hl, "panel", "gold")
  if hl.SetBackdropColor then hl:SetBackdropColor(0, 0, 0, 0) end
  hl:SetFrameStrata("DIALOG")
  hl:EnableMouse(false)
  hl:Hide()
  f.hl = hl

  f:SetScript("OnHide", function() hl:Hide(); markSeen() end)
  Tour.frame = f
  return f
end

function Tour.Go(i)
  local f = Tour.frame
  if not f then return end
  local n = #Tour.STEPS
  if i > n then Tour.Stop(); return end
  i = math.max(1, i)
  Tour.i = i
  local s = Tour.STEPS[i]
  if s.tab then ns.UI.Select(s.tab) end
  f.title:SetText(s.title)
  f.body:SetText(s.body)
  f.step:SetText(("%d / %d"):format(i, n))
  f.back:SetShown(i > 1)
  f.next.label:SetText(i == n and "Done" or "Next")
  f.next.tip = i == n and "Close the tour" or "Next step"
  f.skip:SetShown(i < n)
  local target = s.target and s.target()
  if target then
    f.hl:ClearAllPoints()
    f.hl:SetPoint("TOPLEFT", target, "TOPLEFT", -2, 2)
    f.hl:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2, -2)
    f.hl:Show()
  else
    f.hl:Hide()
  end
end

function Tour.Start()
  ns.UI.Open()
  local f = Tour.Build()
  f:Show()
  Tour.Go(1)
end

function Tour.Stop()
  markSeen()
  if Tour.frame then Tour.frame:Hide() end
end

function Tour.IsShown() return Tour.frame ~= nil and Tour.frame:IsShown() end

-- first time the window opens
function Tour.MaybeStart()
  if seen() or Tour.IsShown() then return end
  Tour.Start()
end
