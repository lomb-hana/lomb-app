-- LOMB Companion: /lomb slash command + key binding globals.
local _, ns = ...

local HELP = {
  "|cffb873ff/lomb|r  open / close the window",
  "|cffb873ff/lomb <tab>|r  open a tab: %s",
  "|cffb873ff/lomb card|r  show / hide the bestiary card",
  "|cffb873ff/lomb train|r  what your class trainer has for you",
  "|cffb873ff/lomb sync|r  say hello to the guild now",
  "|cffb873ff/lomb status|r  sync status",
  "|cffb873ff/lomb debug|r  toggle debug messages",
  "|cffb873ff/lomb questcheck|r  what the game tells the addon about your quests",
}

local function isTab(id)
  for _, tab in ipairs(ns.UI.tabs) do if tab.id == id and ns.UI.TabVisible(tab) then return true end end
  return false
end

local function tabList()
  local out = {}
  for _, tab in ipairs(ns.UI.tabs) do
    if ns.UI.TabVisible(tab) then out[#out + 1] = tab.id end
  end
  return table.concat(out, ", ")
end

function ns.HandleSlash(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)") or ""
  if cmd == "" then ns.UI.Toggle()
  elseif cmd ~= "" and isTab(cmd) then ns.UI.Open(cmd)
  elseif cmd == "card" then ns.BestiaryCard.Toggle()
  elseif cmd == "sync" then
    local ok, why = ns.Sync.CanSend()
    if ok then ns.Sync.SendHello(); ns.Sync.SendProfile(true); ns.Print("Said hello to the guild.")
    else ns.Print("Can't sync right now: %s.", why) end
  elseif cmd == "status" then ns.Print(ns.Sync.Status())
  elseif cmd == "questcheck" then
    ns.QuestTrack.ScanLog(); ns.QuestTrack.ScanDone()
    ns.Print(ns.QuestTrack.Report())
  elseif cmd == "train" then
    ns.UI.Open("quests"); ns.QuestsTab.ShowTraining()
  elseif cmd == "debug" then
    ns.db.settings.debug = not ns.db.settings.debug
    ns.Print("Debug %s.", ns.db.settings.debug and "on" or "off")
  else
    for _, line in ipairs(HELP) do ns.Print(line:find("%%s") and line:format(tabList()) or line) end
  end
end

SLASH_LOMB1 = "/lomb"
SLASH_LOMB2 = "/lombc"
SlashCmdList.LOMB = function(msg) ns.SafeCall(ns.HandleSlash, msg) end

-- Bindings.xml
BINDING_HEADER_LOMBCOMPANION = "LOMB Companion"
BINDING_NAME_LOMBCOMPANION_TOGGLE = "Open / close LOMB Companion"
BINDING_NAME_LOMBCOMPANION_CARD = "Show / hide bestiary card"
function LOMBCompanion_ToggleWindow() ns.UI.Toggle() end
function LOMBCompanion_ToggleCard() ns.BestiaryCard.Toggle() end
