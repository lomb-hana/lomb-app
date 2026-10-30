-- LOMB Companion: guild lines on item tooltips ("Crafters in LOMB: ...").
-- Modules register a provider: fn(itemID) -> text or nil (one line each).
local _, ns = ...
local C = ns.Compat
local Tooltip = {}
ns.Tooltip = Tooltip

Tooltip.providers = {}

function Tooltip.AddLine(fn)
  for _, f in ipairs(Tooltip.providers) do if f == fn then return end end
  Tooltip.providers[#Tooltip.providers + 1] = fn
end

-- Lines for one item, in provider order.
function Tooltip.LinesFor(itemID)
  local out = {}
  if not itemID or not ns.db or not ns.db.settings.tooltips then return out end
  for _, fn in ipairs(Tooltip.providers) do
    local ok, text = pcall(fn, itemID)
    if ok and type(text) == "string" and text ~= "" then out[#out + 1] = text end
  end
  return out
end

local function decorate(tt, itemID)
  if not tt or (tt.IsForbidden and tt:IsForbidden()) then return end
  itemID = C.Safe(itemID)
  if type(itemID) ~= "number" then return end
  -- the same tooltip can be filled twice for one hover; add our lines once
  if tt.lombItem == itemID and tt.lombAt == GetTime() then return end
  tt.lombItem, tt.lombAt = itemID, GetTime()
  local lines = Tooltip.LinesFor(itemID)
  if #lines == 0 then return end
  for _, text in ipairs(lines) do tt:AddLine(text, 0.72, 0.45, 1.0, true) end
  tt:Show()   -- resize to fit
end
Tooltip.Decorate = decorate

function Tooltip.Hook()
  if Tooltip.hooked then return end
  Tooltip.hooked = true
  local TDP = _G.TooltipDataProcessor
  if TDP and TDP.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TDP.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      if type(data) == "table" then decorate(tt, data.id) end
    end)
    Tooltip.mode = "dataprocessor"
    return
  end
  local function onSetItem(tt)
    local _, link = C.Call(tt.GetItem, tt)
    decorate(tt, C.ItemIdFromLink(link))
  end
  for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
    local tt = _G[name]
    if tt and tt.HookScript and (not tt.HasScript or tt:HasScript("OnTooltipSetItem")) then
      tt:HookScript("OnTooltipSetItem", onSetItem)
    end
  end
  Tooltip.mode = "script"
end

ns:On("PLAYER_LOGIN", function() ns.SafeCall(Tooltip.Hook) end)
