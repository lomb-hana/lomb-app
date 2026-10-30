-- Offline stub of the WoW API, just enough to load LOMB Companion in plain Lua 5.1
-- and drive it with fake events. Not a game emulator: it checks our logic, not Blizzard's.
local H = {}

H.root = (arg and arg[0] and arg[0]:match("^(.*)/tests/")) or "."
H.addonDir = H.root .. "/LOMBCompanion/"

---------------------------------------------------------------------------
-- tiny test framework
---------------------------------------------------------------------------
H.passed, H.failed = 0, 0
local current = "?" -- luacheck: ignore 231
function H.test(name, fn)
  current = name
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    H.passed = H.passed + 1
    io.write("  ok   ", name, "\n")
  else
    H.failed = H.failed + 1
    io.write("  FAIL ", name, "\n       ", tostring(err):gsub("\n", "\n       "), "\n")
  end
end
function H.eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
function H.ok(v, msg) if not v then error(msg or "expected truthy", 2) end end
function H.near(a, b, eps, msg)
  if math.abs(a - b) > (eps or 1e-9) then error((msg or "not near") .. ": " .. a .. " vs " .. b, 2) end
end
function H.deepEq(a, b, path)
  path = path or "value"
  if type(a) ~= type(b) then error(path .. ": type " .. type(a) .. " vs " .. type(b), 2) end
  if type(a) ~= "table" then
    if a ~= b then error(path .. ": " .. tostring(a) .. " vs " .. tostring(b), 2) end
    return
  end
  for k, v in pairs(a) do H.deepEq(v, b[k], path .. "." .. tostring(k)) end
  for k in pairs(b) do if a[k] == nil then error(path .. "." .. tostring(k) .. " missing", 2) end end
end
function H.done()
  io.write(("\n%d passed, %d failed\n"):format(H.passed, H.failed))
  os.exit(H.failed == 0 and 0 or 1)
end

---------------------------------------------------------------------------
-- clock + timers
---------------------------------------------------------------------------
H.now = 1000            -- GetTime()
H.epoch = 1793750400    -- time() (2026-11-04)
H.timers = {}

function H.advance(seconds, step)
  step = step or 0.05
  local target = H.now + seconds
  while H.now < target - 1e-9 do
    local dt = math.min(step, target - H.now)
    H.now = H.now + dt
    H.epoch = H.epoch + dt
    local due = {}
    for i = #H.timers, 1, -1 do
      local t = H.timers[i]
      if t.at <= H.now + 1e-9 then
        if t.every and not t.cancelled then
          t.at = t.at + t.every
          due[#due + 1] = t
        else
          table.remove(H.timers, i)
          if not t.cancelled then due[#due + 1] = t end
        end
      end
    end
    for _, t in ipairs(due) do t.fn(t.handle) end
    for _, f in ipairs(H.onUpdateFrames or {}) do
      local s = f.scripts.OnUpdate
      if s and f.shown then s(f, dt) end
    end
  end
end

---------------------------------------------------------------------------
-- mock frames
---------------------------------------------------------------------------
H.frames = {}
H.onUpdateFrames = {}
local Frame = {}
local FrameMT = {}

local function newRegion(kind, parent, name)
  local f = setmetatable({
    kind = kind, parent = parent, name = name, scripts = {}, events = {}, shown = true,
    w = 0, h = 0, text = "", points = {}, children = {}, alpha = 1, value = 0, min = 0, max = 1,
  }, FrameMT)
  if name then _G[name] = f end
  H.frames[#H.frames + 1] = f
  if parent and parent.children then parent.children[#parent.children + 1] = f end
  return f
end
H.newRegion = newRegion

FrameMT.__index = function(_, k)
  local m = Frame[k]
  if m then return m end
  -- any other widget method (CamelCase) is a harmless no-op returning nothing;
  -- plain lowercase fields stay nil, like on real frames
  if type(k) == "string" and k:find("^%u") then return function() end end
  return nil
end

function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsEventRegistered(e) return self.events[e] or false end
function Frame:SetScript(name, fn)
  self.scripts[name] = fn
  if name == "OnUpdate" then
    local found = false
    for _, f in ipairs(H.onUpdateFrames) do if f == self then found = true end end
    if not found then H.onUpdateFrames[#H.onUpdateFrames + 1] = self end
  end
end
function Frame:HookScript(name, fn)
  local old = self.scripts[name]
  self.scripts[name] = function(...) if old then old(...) end; return fn(...) end
end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:HasScript() return true end
function Frame:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide()
  local was = self.shown
  self.shown = false
  if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
  local f = self
  while f do if not f.shown then return false end f = f.parent end
  return true
end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:GetWidth() return self.w end
function Frame:GetHeight() return self.h end
function Frame:GetSize() return self.w, self.h end
function Frame:GetLeft() return 0 end
function Frame:GetRight() return self.w end
function Frame:GetTop() return self.h end
function Frame:GetBottom() return 0 end
function Frame:GetCenter() return self.w / 2, self.h / 2 end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetScale() return 1 end
function Frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Frame:ClearAllPoints() self.points = {} end
function Frame:GetPoint() local p = self.points[1]; if p then return unpack(p) end return "CENTER", nil, "CENTER", 0, 0 end
function Frame:GetNumPoints() return #self.points end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:SetFormattedText(fmt, ...) self.text = fmt:format(...) end
function Frame:GetStringWidth() return #(self.text or "") * 6 end
function Frame:GetStringHeight() return 12 end
function Frame:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Frame:SetFont() return true end
function Frame:CreateTexture(name) return newRegion("Texture", self, name) end
function Frame:CreateFontString(name) return newRegion("FontString", self, name) end
function Frame:CreateMaskTexture(name) return newRegion("MaskTexture", self, name) end
function Frame:CreateLine(name) return newRegion("Line", self, name) end
function Frame:GetParent() return self.parent end
function Frame:SetParent(p) self.parent = p end
function Frame:GetName() return self.name end
function Frame:GetObjectType() return self.kind end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetAlpha() return self.alpha end
function Frame:SetValue(v) self.value = v end
function Frame:GetValue() return self.value end
function Frame:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Frame:GetMinMaxValues() return self.min, self.max end
function Frame:SetChecked(v) self.checked = v and true or false end
function Frame:GetChecked() return self.checked end
function Frame:IsMouseOver() return false end
function Frame:GetFrameLevel() return 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:GetVerticalScroll() return self.vscroll or 0 end
function Frame:SetVerticalScroll(v) self.vscroll = v end
function Frame:GetVerticalScrollRange() return 0 end
function Frame:GetNumChildren() return #self.children end
function Frame:GetChildren() return unpack(self.children) end
function Frame:HasFocus() return false end
function Frame:GetNumLetters() return #(self.text or "") end
function Frame:IsForbidden() return false end
function Frame:IsProtected() return false end
function Frame:Click() if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton", true) end end
function Frame:GetBackdrop() return self.backdrop end
function Frame:SetBackdrop(b) self.backdrop = b end

H.Frame = Frame

---------------------------------------------------------------------------
-- WoW globals
---------------------------------------------------------------------------
function H.installAPI(opts)
  opts = opts or {}
  local env = _G
  env.UIParent = newRegion("Frame", nil, "UIParent")
  env.UIParent.w, env.UIParent.h, env.UIParent.shown = 1920, 1080, true
  env.Minimap = newRegion("Frame", env.UIParent, "Minimap")
  env.Minimap.w, env.Minimap.h, env.Minimap.shown = 140, 140, true
  env.GameTooltip = newRegion("GameTooltip", env.UIParent, "GameTooltip")
  env.DEFAULT_CHAT_FRAME = { lines = {}, AddMessage = function(self, m) self.lines[#self.lines + 1] = m end }
  env.CreateFrame = function(kind, name, parent) return newRegion(kind, parent, name) end
  env.GetTime = function() return H.now end
  env.time = function() return math.floor(H.epoch) end
  env.date = os.date
  env.debugprofilestop = function() return H.now * 1000 end
  env.geterrorhandler = function() return function(e) H.errors[#H.errors + 1] = e; io.write("[error] ", tostring(e), "\n") end end
  H.errors = {}
  env.C_Timer = {
    After = function(s, fn) H.timers[#H.timers + 1] = { at = H.now + s, fn = fn } end,
    NewTicker = function(s, fn)
      local t = { at = H.now + s, every = s }
      t.handle = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled end }
      t.fn = fn
      H.timers[#H.timers + 1] = t
      return t.handle
    end,
    NewTimer = function(s, fn)
      local t = { at = H.now + s, fn = fn }
      t.handle = { Cancel = function() t.cancelled = true end }
      H.timers[#H.timers + 1] = t
      return t.handle
    end,
  }
  env.strsplit = function(sep, s)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
    return unpack(out)
  end
  env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  env.tinsert, env.tremove = table.insert, table.remove
  env.Ambiguate = function(name, mode)
    if mode == "short" or mode == "none" then return (name:gsub("%-.*$", "")) end
    return name
  end
  env.hooksecurefunc = function(a, b, c)
    if type(a) == "table" then
      local old = a[b]; a[b] = function(...) local r = { old(...) }; c(...); return unpack(r) end
    else
      local old = env[a]; env[a] = function(...) local r = { old(...) }; b(...); return unpack(r) end
    end
  end
  env.InCombatLockdown = function() return H.state.combat end
  env.UnitAffectingCombat = function() return H.state.combat end
  env.IsEncounterInProgress = function() return H.state.encounter end
  env.IsInInstance = function() return H.state.instanceType ~= "none", H.state.instanceType end
  env.IsTrialAccount = function() return H.state.trial end
  env.IsInGuild = function() return H.state.guild ~= nil end
  env.GetGuildInfo = function() if H.state.guild then return H.state.guild, "Member", 3 end end
  env.UnitFullName = function(u) if u == "player" then return H.state.player, H.state.realm end end
  env.UnitName = function(u)
    if u == "player" then return H.state.player end
    local d = H.units[u]; return d and d.name
  end
  env.GetNormalizedRealmName = function() return H.state.realm end
  env.GetRealmName = function() return H.state.realm end
  env.GetRealZoneText = function() return H.state.zone end
  env.GetZoneText = function() return H.state.zone end
  env.GetMoney = function() return H.state.money end
  env.UnitLevel = function(u) if u == "player" then return H.state.level end local d = H.units[u]; return d and d.level end
  env.UnitClass = function(u) if u == "player" then return "Hunter", "HUNTER", 3 end end
  env.UnitRace = function() return "Night Elf" end
  env.UnitXP = function() return 1200 end
  env.UnitXPMax = function() return 3000 end
  env.GetAverageItemLevel = function() return 24.4, 23.6 end
  env.GetNumSkillLines = function() return #H.state.skills end
  env.GetSkillLineInfo = function(i)
    local s = H.state.skills[i]
    if s then return s[1], s[2], nil, s[3], 0, 0, s[4] end
  end
  env.RequestTimePlayed = function() H.state.playedRequests = (H.state.playedRequests or 0) + 1 end
  env.ChatFrame_DisplayTimePlayed = function() H.state.playedPrinted = (H.state.playedPrinted or 0) + 1 end

  -- units
  H.units = {}
  local function U(u) return H.units[u] end
  env.UnitExists = function(u) return u == "player" or U(u) ~= nil end
  env.UnitIsPlayer = function(u) if u == "player" then return true end local d = U(u); return d and d.isPlayer end
  env.UnitGUID = function(u) local d = U(u); return d and d.guid end
  env.UnitClassification = function(u) local d = U(u); return d and d.classification or "normal" end
  env.UnitCreatureType = function(u) local d = U(u); return d and d.creatureType end
  env.UnitCreatureFamily = function(u) local d = U(u); return d and d.family end
  env.UnitHealth = function(u) local d = U(u); return d and d.health end
  env.UnitHealthMax = function(u) local d = U(u); return d and d.healthMax end
  env.UnitIsDead = function(u) local d = U(u); return d and d.dead end
  env.UnitIsTapDenied = function(u) local d = U(u); return d and d.tapDenied end
  env.UnitCanAttack = function(_, u) local d = U(u); return d and not d.friendly end
  env.UnitReaction = function(u) local d = U(u); return d and (d.friendly and 5 or 2) end
  env.UnitIsUnit = function(a, b) return a == b end

  -- secrets: values wrapped by H.secret() are "secret"
  local secretMT = { __tostring = function() return "<secret>" end }
  H.secret = function(v) return setmetatable({ v = v }, secretMT) end
  env.issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == secretMT end

  -- guild roster
  H.roster = {}
  env.GetNumGuildMembers = function() return #H.roster, #H.roster end
  env.GetGuildRosterInfo = function(i)
    local r = H.roster[i]
    if r then
      return r.name, r.rank, r.rankIndex or 1, r.level, r.className, r.zone, "", "", r.online, 0, r.class
    end
  end
  env.GetGuildRosterLastOnline = function(i)
    local r = H.roster[i]
    if r and not r.online then return 0, 0, r.days or 0, r.hours or 0 end
  end
  env.C_GuildInfo = { GuildRoster = function() H.state.rosterRequests = (H.state.rosterRequests or 0) + 1 end }

  -- addon messages
  H.sent = {}
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) H.state.prefix = p; return true end,
    SendAddonMessage = function(prefix, msg, channel)
      if #msg > 255 then error("message too long: " .. #msg) end
      if H.state.sendResult then return H.state.sendResult end
      H.sent[#H.sent + 1] = { prefix = prefix, msg = msg, channel = channel, at = H.now }
      return 0
    end,
    InChatMessagingLockdown = function() return H.state.lockdown end,
  }
  env.Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8,
    NotInGuild = 10, AddOnMessageLockdown = 11 }, LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 } }

  -- loot window
  H.loot = {}
  env.GetNumLootItems = function() return #H.loot end
  env.GetLootSlotLink = function(i) local s = H.loot[i]; return s and s.link end
  env.GetLootSlotType = function(i) local s = H.loot[i]; return s and s.slotType or 1 end
  env.GetLootSlotInfo = function(i) local s = H.loot[i]; if s then return 134400, "x", s.quantity or 1 end end
  env.GetLootSourceInfo = function(i) local s = H.loot[i]; if s then return unpack(s.sources) end end

  env.C_Item = {
    GetItemInfo = function(id) return "Item " .. id, "|cffffffff|Hitem:" .. id .. "::|h[Item " .. id .. "]|h|r", 1, 1, 1, "", "", 1, "", 134400 end,
    GetItemIconByID = function() return 134400 end,
    GetDetailedItemLevelInfo = function() return 20 end,
  }
  env.C_Spell = { GetSpellInfo = function(id) return { name = "Spell " .. id, iconID = 136243 } end }
  env.C_Map = { GetBestMapForUnit = function() return 1429 end, GetMapInfo = function() return { name = H.state.zone } end }
  env.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 0.7, g = 0.7, b = 0.7 } end })
  env.SlashCmdList = {}
  env.UISpecialFrames = {}
  env.BINDING_HEADER_LOMBCOMPANION = nil
  env.PlaySound = function() end
  env.SOUNDKIT = { IG_MAINMENU_OPEN = 1, IG_MAINMENU_CLOSE = 2, U_CHAT_SCROLL_BUTTON = 3, IG_CHARACTER_INFO_TAB = 4 }
  env.GetCursorPosition = function() return 0, 0 end
  env.IsShiftKeyDown = function() return false end
  env.IsControlKeyDown = function() return false end
  env.StaticPopup_Show = function() end
  env.GetCoinTextureString = function(c) return tostring(c) .. "c" end
  env.SecondsToTime = function(s) return tostring(s) .. "s" end
  env.FONT_COLOR_CODE_CLOSE = "|r"
  env.ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, hex = "|cffffffff" } end })
  env.C_AddOns = { GetAddOnMetadata = function(_, k) if k == "Version" then return H.tocVersion() end end }

  -- profession windows (classic trade skill + craft APIs)
  --   H.trade = { line = "Leatherworking", rows = { { name=, kind="optimal"|"header", item=id | spell=id } } }
  H.trade, H.craft = nil, nil
  env.GetTradeSkillLine = function() if H.trade then return H.trade.line, 75, 150 end return "UNKNOWN" end
  env.GetNumTradeSkills = function() return H.trade and #H.trade.rows or 0 end
  env.GetTradeSkillInfo = function(i)
    local r = H.trade and H.trade.rows[i]
    if r then return r.name, r.kind or "optimal", 0, false end
  end
  env.GetTradeSkillItemLink = function(i)
    local r = H.trade and H.trade.rows[i]
    if r and r.item then return "|cffffffff|Hitem:" .. r.item .. "::|h[" .. r.name .. "]|h|r" end
  end
  env.GetTradeSkillRecipeLink = function(i)
    local r = H.trade and H.trade.rows[i]
    if r and r.spell then return "|cffffd000|Henchant:" .. r.spell .. "|h[" .. r.name .. "]|h|r" end
  end
  env.GetCraftDisplaySkillLine = function() if H.craft then return H.craft.line, 75, 150 end end
  env.GetNumCrafts = function() return H.craft and #H.craft.rows or 0 end
  env.GetCraftInfo = function(i)
    local r = H.craft and H.craft.rows[i]
    if r then return r.name, "", r.kind or "optimal", 0 end
  end
  env.GetCraftItemLink = function(i)
    local r = H.craft and H.craft.rows[i]
    if r and r.item then return "|cffffffff|Hitem:" .. r.item .. "::|h[" .. r.name .. "]|h|r" end
    if r and r.spell then return "|cffffd000|Henchant:" .. r.spell .. "|h[" .. r.name .. "]|h|r" end
  end
  -- chat helpers
  H.chat = {}
  env.ChatFrame_OpenChat = function(text) H.chat[#H.chat + 1] = { open = text } end
  env.ChatEdit_InsertLink = function(link) H.chat[#H.chat + 1] = { link = link }; return true end

  H.state = {
    player = "Testy", realm = "Forever", guild = opts.guild == false and nil or (opts.guild or "Land of Make Believe"),
    level = 12, money = 123456, zone = "Elwynn Forest", combat = false, encounter = false,
    instanceType = "none", trial = false, lockdown = false,
    skills = { { "Professions", true, 0, 0 }, { "Skinning", false, 75, 150 }, { "Leatherworking", false, 60, 150 },
      { "Secondary Skills", true, 0, 0 }, { "Cooking", false, 40, 75 }, { "Swords", false, 60, 60 } },
  }
end

---------------------------------------------------------------------------
-- load the addon (in TOC order) into a fresh namespace
---------------------------------------------------------------------------
function H.tocVersion()
  for line in io.lines(H.addonDir .. "LOMBCompanion.toc") do
    local v = line:match("^## Version:%s*(%S+)")
    if v then return v end
  end
end

function H.tocFiles()
  local files = {}
  for line in io.lines(H.addonDir .. "LOMBCompanion.toc") do
    if not line:match("^%s*#") and line:match("%.lua%s*$") then
      files[#files + 1] = (line:gsub("\\", "/"):gsub("%s+$", ""))
    end
  end
  return files
end

function H.load(files)
  local ns = {}
  for _, f in ipairs(files or H.tocFiles()) do
    local chunk, err = loadfile(H.addonDir .. f)
    if not chunk then error(err) end
    chunk("LOMBCompanion", ns)
  end
  return ns
end

-- load only the standalone pieces (no WoW API needed)
function H.loadPure(rel)
  local ns = {}
  local chunk = assert(loadfile(H.addonDir .. rel))
  return chunk("LOMBCompanion", ns), ns
end

function H.fire(event, ...)
  for _, f in ipairs(H.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

-- boot the full addon: load files, ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD
function H.boot(opts)
  H.frames, H.onUpdateFrames, H.timers = {}, {}, {}
  _G.LOMBCompanionDB, _G.LOMBCompanionCharDB = opts and opts.db or nil, opts and opts.charDB or nil
  H.installAPI(opts)
  local ns = H.load()
  H.fire("ADDON_LOADED", "LOMBCompanion")
  H.fire("PLAYER_LOGIN")
  H.fire("PLAYER_ENTERING_WORLD", true, false)
  return ns
end

-- Creature GUID with Forever-style obfuscated server/spawn parts.
function H.guid(npcId, spawn)
  return ("Creature-0-x7Fa-0-12-%d-%s"):format(npcId, spawn or "00ABCDEF01")
end

return H
