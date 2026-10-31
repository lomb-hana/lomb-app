-- LOMB Companion: core namespace, event dispatch, internal callbacks, timers.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.version = "0.9.6"
ns.PROTOCOL = 1          -- bump when the sync message format changes
ns.PREFIX = "LOMBC"      -- addon message prefix (max 16 chars)
ns.modules = {}

_G.LOMBCompanion = ns    -- handy for /dump and for the future data module

ns.errors = { n = 0 }      -- counted for /lomb test
local function report(err)
  ns.errors.n = ns.errors.n + 1
  ns.errors.last = err
  local handler = geterrorhandler and geterrorhandler()
  if handler then handler(err) else print(err) end
end

-- Safe call: never let one module's bug break the rest of the addon.
function ns.SafeCall(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then report(("LOMB Companion: %s"):format(tostring(err))) end
  return ok
end

---------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame
local eventHandlers = {}

function ns:On(event, fn)
  local list = eventHandlers[event]
  if not list then
    list = {}
    eventHandlers[event] = list
    -- some events may not exist on Forever; registering an unknown event errors
    pcall(eventFrame.RegisterEvent, eventFrame, event)
  end
  list[#list + 1] = fn
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = eventHandlers[event]
  if not list then return end
  for i = 1, #list do ns.SafeCall(list[i], event, ...) end
end)

---------------------------------------------------------------------------
-- Internal callbacks (module -> UI)
---------------------------------------------------------------------------
local listeners = {}

function ns:Listen(msg, fn)
  listeners[msg] = listeners[msg] or {}
  table.insert(listeners[msg], fn)
end

function ns:Fire(msg, ...)
  local list = listeners[msg]
  if not list then return end
  for i = 1, #list do ns.SafeCall(list[i], ...) end
end

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------
function ns.After(seconds, fn)
  C_Timer.After(seconds, function() ns.SafeCall(fn) end)
end

function ns.Every(seconds, fn)
  return C_Timer.NewTicker(seconds, function() ns.SafeCall(fn) end)
end

-- Debounce: run fn once, `seconds` after the last request.
function ns.Debounce(seconds, fn)
  local token = 0
  return function()
    token = token + 1
    local mine = token
    C_Timer.After(seconds, function()
      if mine == token then ns.SafeCall(fn) end
    end)
  end
end

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
function ns.Print(fmt, ...)
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  local out = DEFAULT_CHAT_FRAME or { AddMessage = function(_, m) print(m) end }
  out:AddMessage("|cffb873ffLOMB|r " .. text)
end

function ns.Debug(fmt, ...)
  if ns.db and ns.db.settings and ns.db.settings.debug then
    ns.Print("|cff888888[debug]|r " .. fmt, ...)
  end
end

---------------------------------------------------------------------------
-- Lifecycle: modules register Init (after SavedVariables) and Login.
---------------------------------------------------------------------------
function ns:NewModule(name)
  local m = { name = name }
  ns.modules[#ns.modules + 1] = m
  ns[name] = m
  return m
end

ns:On("ADDON_LOADED", function(_, loaded)
  if loaded ~= ADDON_NAME then return end
  ns.DB.Load()
  -- the look is picked before any frame is built (Settings > Look reloads the UI)
  if ns.Theme and ns.Theme.Apply then ns.Theme.Apply(ns.db.settings.theme) end
  for _, m in ipairs(ns.modules) do
    if m.Init then ns.SafeCall(m.Init, m) end
  end
  ns.loaded = true
end)

ns:On("PLAYER_LOGIN", function()
  ns.Compat.RefreshPlayerKey()
  for _, m in ipairs(ns.modules) do
    if m.Login then ns.SafeCall(m.Login, m) end
  end
  ns.loggedIn = true
  ns:Fire("LOGIN")
end)
