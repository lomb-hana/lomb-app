-- LOMB Companion: minimap button (no LibDBIcon dependency). Drag to move around
-- the minimap edge. Left-click: window. Right-click: card. Shift-click: settings.
local _, ns = ...
local T, W = ns.Theme, ns.Widgets
local M = {}
ns.Minimap = M

local function settings() return ns.db.settings.minimap end

function M.Position()
  local b = M.button
  if not b or not Minimap then return end
  local angle = math.rad(settings().angle or 215)
  local r = (Minimap:GetWidth() or 140) / 2 + 6
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

function M.Create()
  if M.button or not Minimap then return M.button end
  local b = CreateFrame("Button", "LOMBCompanionMinimapButton", Minimap)
  b:SetSize(T.sizes.minimap, T.sizes.minimap)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")

  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  b.bg:SetVertexColor(0.08, 0.06, 0.12, 1)
  b.bg:SetSize(24, 24)
  b.bg:SetPoint("CENTER")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(T.LOGO)
  b.icon:SetSize(22, 22)
  b.icon:SetPoint("CENTER")
  b.ring = b:CreateTexture(nil, "OVERLAY")
  b.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b.ring:SetSize(54, 54)
  b.ring:SetPoint("TOPLEFT")
  b.ring:SetVertexColor(0.72, 0.45, 1.0)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  b:SetScript("OnClick", function(_, button)
    if IsShiftKeyDown and IsShiftKeyDown() then ns.UI.Open("settings")
    elseif button == "RightButton" then ns.BestiaryCard.Toggle()
    else ns.UI.Toggle() end
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      cx, cy = cx / scale, cy / scale
      settings().angle = math.floor(math.deg(math.atan2(cy - my, cx - mx)) + 0.5) % 360
      M.Position()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  W.Tooltip(b, function(tt)
    tt:SetText("|cffb873ffLOMB|r Companion", 1, 1, 1)
    tt:AddLine(ns.Sync and ns.Sync.Status() or "", 0.8, 0.78, 0.85)
    tt:AddLine(" ")
    tt:AddLine("|cffffffffLeft-click|r  open / close", 0.6, 0.57, 0.66)
    tt:AddLine("|cffffffffRight-click|r  bestiary card", 0.6, 0.57, 0.66)
    tt:AddLine("|cffffffffShift-click|r  settings", 0.6, 0.57, 0.66)
    tt:AddLine("|cffffffffDrag|r  move", 0.6, 0.57, 0.66)
  end)
  M.button = b
  return b
end

function M.Update()
  local b = M.Create()
  if not b then return end
  if settings().hide then b:Hide() else M.Position(); b:Show() end
end

ns:Listen("LOGIN", function() ns.SafeCall(M.Update) end)
