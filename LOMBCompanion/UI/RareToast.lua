-- LOMB Companion: the "rare spotted" toast. Click it to open the creature in
-- the Bestiary; drag to move it. Hides itself after a few seconds.
local _, ns = ...
local T, W, C = ns.Theme, ns.Widgets, ns.Compat
local Toast = {}
ns.RareToast = Toast

Toast.DURATION = 10
local WIDTH, HEIGHT = 330, 58

function Toast.Create()
  if Toast.frame then return Toast.frame end
  local f = CreateFrame("Button", "LOMBCompanionRareToast", UIParent, "BackdropTemplate")
  W.Skin(f, "bg", "accent")
  f:SetSize(WIDTH, HEIGHT)
  f:SetFrameStrata("HIGH")
  f:Hide()
  W.Movable(f,
    function() return ns.db.settings.toastPoint or { "TOP", "TOP", 0, -150 } end,
    function(p) ns.db.settings.toastPoint = p end)
  f.logo = f:CreateTexture(nil, "ARTWORK")
  f.logo:SetTexture(T.LOGO)
  f.logo:SetSize(28, 28)
  f.logo:SetPoint("LEFT", 10, 0)
  f.title = W.Text(f, "title", 14, "gold")
  f.title:SetPoint("TOPLEFT", 46, -8)
  f.ago = W.Text(f, "narrow", 10, "muted", "RIGHT")
  f.ago:SetPoint("TOPRIGHT", -10, -10)
  f.text = W.Text(f, "body", 12, "text")
  f.text:SetPoint("TOPLEFT", 46, -26)
  f.text:SetWidth(WIDTH - 56)
  f.hint = W.Text(f, "narrow", 10, "muted")
  f.hint:SetPoint("BOTTOMLEFT", 46, 6)
  f.hint:SetText("Click to open in the Bestiary")
  f:SetScript("OnClick", function(self)
    self:Hide()
    if self.npcId and ns.UI then
      ns.UI.Open("bestiary")
      ns.UI.Select("bestiary")
      if ns.BestiaryTab then ns.BestiaryTab.Select(self.npcId) end
    end
  end)
  Toast.frame = f
  return f
end

function Toast.Show(e)
  local f = Toast.Create()
  f.npcId = e.n
  local who = (e.by == ns.playerKey) and "You" or (C.ShortName(e.by) or "A guildmate")
  f.title:SetText(e.by == ns.playerKey and "Rare spotted!" or "Rare spotted by a guildmate!")
  f.ago:SetText(who)
  f.text:SetText(ns.Rares.Describe(e))
  f:Show()
  Toast.token = (Toast.token or 0) + 1
  local mine = Toast.token
  local function later()
    if Toast.token ~= mine or not f:IsShown() then return end
    if f.IsMouseOver and f:IsMouseOver() then ns.After(3, later) else f:Hide() end
  end
  ns.After(Toast.DURATION, later)
end
