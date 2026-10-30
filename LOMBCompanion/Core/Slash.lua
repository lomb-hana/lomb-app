-- LOMB Companion: /lomb slash command + key binding globals.
local _, ns = ...

local HELP = {
  "|cffb873ff/lomb|r  open / close the window",
  "|cffb873ff/lomb roster|r | |cffb873ffme|r | |cffb873ffbestiary|r | |cffb873ffsettings|r | |cffb873ffcredits|r  open a tab",
  "|cffb873ff/lomb card|r  show / hide the bestiary card",
  "|cffb873ff/lomb sync|r  say hello to the guild now",
  "|cffb873ff/lomb status|r  sync status",
  "|cffb873ff/lomb debug|r  toggle debug messages",
}

local TABS = { roster = true, me = true, bestiary = true, settings = true, credits = true }

function ns.HandleSlash(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)") or ""
  if cmd == "" then ns.UI.Toggle()
  elseif TABS[cmd] then ns.UI.Open(cmd)
  elseif cmd == "card" then ns.BestiaryCard.Toggle()
  elseif cmd == "sync" then
    local ok, why = ns.Sync.CanSend()
    if ok then ns.Sync.SendHello(); ns.Sync.SendProfile(true); ns.Print("Said hello to the guild.")
    else ns.Print("Can't sync right now: %s.", why) end
  elseif cmd == "status" then ns.Print(ns.Sync.Status())
  elseif cmd == "debug" then
    ns.db.settings.debug = not ns.db.settings.debug
    ns.Print("Debug %s.", ns.db.settings.debug and "on" or "off")
  else
    for _, line in ipairs(HELP) do ns.Print(line) end
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
