-- LOMB Companion: one click behaviour for every item row in the addon.
--   Click        the item's page in Quests & Items (ForeverDB.net data), when that data is loaded
--   Shift-click  put the item link in the chat box, the same way as from your bags
--   Ctrl-click   preview it in the dressing room (the game's own handler decides if it can)
-- Modified clicks go through the game's own path (IsModifiedClick / HandleModifiedItemClick /
-- ChatEdit_InsertLink / DressUpItemLink) when it exists. If the game hasn't cached the item yet,
-- we ask for it and finish the click when it arrives (or after a second, with a link built
-- from the ID). Nothing is ever sent: the link only goes into the edit box.
local _, ns = ...
local C = ns.Compat
local IC = {}
ns.ItemClick = IC

IC.HINT = "Click: details  Shift-click: link in chat"
IC.HINT_LINK = "Shift-click: link in chat"
IC.HINT_RGB = { 0.72, 0.45, 1.0 }
IC.WAIT = 1   -- seconds to wait for an uncached item before building the link ourselves

-- An item ID from a number, "item:..." string or full link.
function IC.Id(item)
  if type(item) == "number" then return item end
  if type(item) == "string" then return C.ItemIdFromLink(item) end
end

-- The game's own link, if it has the item cached. An item string or link keeps its
-- enchant and suffix (gear on profiles).
function IC.GameLink(item)
  if type(item) == "string" and item:find("|Hitem:", 1, true) then return item end
  if not IC.Id(item) then return nil end
  local _, link = C.ItemInfo(item)
  if type(link) == "string" and link:find("|Hitem:", 1, true) then return link end
end

-- A link built from the ID (and the bundled name and quality), for items the game won't give us.
function IC.BuiltLink(item)
  local id = IC.Id(item)
  if not id then return nil end
  local body = type(item) == "string" and item:match("^item:[%-%d:]+$") or ("item:" .. id)
  local FDB = ns.FDB
  local d = ns.FDBData
  local e = d and d.items and d.items[id]
  local name = (FDB and FDB.ItemName and FDB.ItemName(id)) or (e and e[1]) or ("Item " .. id)
  local q = (e and e[2]) or 1
  local hex = (FDB and FDB.QUALITY_HEX and FDB.QUALITY_HEX[q]) or "ffffff"
  return ("|cff%s|H%s|h[%s]|h|r"):format(hex, body, name)
end

-- Which modified click this is: "chat", "dressup" or nil (a plain click).
function IC.Modifier()
  local imc = _G.IsModifiedClick
  if type(imc) == "function" then
    if C.Call(imc, "CHATLINK") then return "chat" end
    if C.Call(imc, "DRESSUP") then return "dressup" end
    return nil
  end
  if _G.IsShiftKeyDown and C.Call(_G.IsShiftKeyDown) then return "chat" end
  if _G.IsControlKeyDown and C.Call(_G.IsControlKeyDown) then return "dressup" end
end

local function deliver(action, link)
  if action == "chat" then
    local ok = C.Call(_G.ChatEdit_InsertLink, link)
    -- no chat box open: open one with the link in it (you press Enter; nothing is sent)
    if not ok and _G.ChatFrame_OpenChat then C.Call(_G.ChatFrame_OpenChat, link) end
    return true
  elseif action == "dressup" then
    if _G.DressUpItemLink then C.Call(_G.DressUpItemLink, link) end
    return true
  end
  return false
end

-- Finish a click that was waiting for the game to load the item.
function IC.Finish(id)
  local p = IC.pending
  if not p or (id and p.id ~= id) then return end
  IC.pending = nil
  local link = IC.GameLink(p.item)
  IC.last = { action = p.action, built = link == nil }
  deliver(p.action, link or IC.BuiltLink(p.item))
end

-- Shift- or ctrl-click on an item. Returns true when it was one (and handled).
function IC.Modified(item, action)
  action = action or IC.Modifier()
  if not action then return false end
  local id = IC.Id(item)
  if not id then return false end
  local link = IC.GameLink(item)
  if link then
    IC.last = { action = action, built = false }
    if _G.HandleModifiedItemClick and C.Call(_G.HandleModifiedItemClick, link) then return true end
    return deliver(action, link)
  end
  -- not cached yet: ask the game for it and finish when it arrives
  if C_Item and C_Item.RequestLoadItemDataByID then C.Call(C_Item.RequestLoadItemDataByID, id) end
  IC.pending = { item = item, id = id, action = action }
  if C_Timer and C_Timer.After then
    C_Timer.After(IC.WAIT, function() IC.Finish(id) end)
  else
    IC.Finish(id)
  end
  return true
end

ns:On("GET_ITEM_INFO_RECEIVED", function(_, itemID)
  if IC.pending and IC.pending.id == itemID and IC.GameLink(IC.pending.item) then IC.Finish(itemID) end
end)
ns:On("ITEM_DATA_LOAD_RESULT", function(_, itemID)
  if IC.pending and IC.pending.id == itemID and IC.GameLink(IC.pending.item) then IC.Finish(itemID) end
end)

-- Can a plain click open item pages right now?
function IC.CanOpen()
  local FDB = ns.FDB
  return (FDB and FDB.Available and FDB.Available() and ns.QuestsTab) and true or false
end

-- Plain click: the item's page in Quests & Items. False (and nothing happens) when the
-- ForeverDB.net data isn't loaded; the tooltip still works.
function IC.Open(item)
  local id = IC.Id(item)
  if not id or not IC.CanOpen() then return false end
  local inQuests = ns.UI and ns.UI.frame and ns.UI.frame:IsShown() and ns.UI.current == "quests"
  ns.QuestsTab.Show("items", id, inQuests and true or false)
  return true
end

-- The whole click. onPlain replaces the plain-click action (a row's own link, a whisper...).
-- Returns true when the click did something.
function IC.Click(item, button, onPlain)
  if button and button ~= "LeftButton" then return false end
  if IC.Modified(item) then return true end
  if onPlain then onPlain(); return true end
  return IC.Open(item)
end

-- The hint line at the bottom of an item tooltip.
function IC.AddHint(tt, canOpen)
  if not tt or not tt.AddLine then return end
  local c = IC.HINT_RGB
  tt:AddLine((canOpen and IC.CanOpen()) and IC.HINT or IC.HINT_LINK, c[1], c[2], c[3])
end

-- The game's tooltip for an item (ID, item string or link).
function IC.SetTooltip(tt, item)
  if type(item) == "string" and tt.SetHyperlink then
    local s = item:match("|H(item:[^|]+)|h") or item
    C.Call(tt.SetHyperlink, tt, s)
  elseif tt.SetItemByID then
    C.Call(tt.SetItemByID, tt, IC.Id(item))
  elseif tt.SetHyperlink then
    C.Call(tt.SetHyperlink, tt, "item:" .. tostring(IC.Id(item)))
  end
end

-- Make a plain frame (not a Button) an item row: tooltip, hint and the clicks above.
--   getItem(self) -> item or nil; onPlain(self) optional; extra(tt, self) optional
function IC.Bind(frame, getItem, onPlain, extra)
  if frame.EnableMouse then frame:EnableMouse(true) end
  frame:SetScript("OnEnter", function(self)
    local item = getItem(self)
    if not item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    IC.SetTooltip(GameTooltip, item)
    if extra then extra(GameTooltip, self) end
    IC.AddHint(GameTooltip, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame:SetScript("OnMouseUp", function(self, button)
    local item = getItem(self)
    if item then IC.Click(item, button, onPlain and function() onPlain(self) end) end
  end)
end
