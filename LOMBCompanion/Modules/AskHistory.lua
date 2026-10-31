-- LOMB Companion: Ask LOMB history -- the questions you've asked, kept per
-- character, plus /lomb ask. The answering itself lives in Ask.lua.
local _, ns = ...
local Ask = ns.Ask

Ask.history = {}   -- { answer, ... }, oldest first
Ask.MAX_HISTORY = 40

---------------------------------------------------------------------------
-- Saved history (per character, LOMBCompanionCharDB.askHistory). Only the
-- question and the answer's lines are kept: text, style and what a line opens.
-- Nothing else from the answer object, no timestamps, nothing about the player.
---------------------------------------------------------------------------
local MAX_TEXT = 400

local function cleanText(t)
  if type(t) ~= "string" then return nil end
  return t:sub(1, MAX_TEXT)
end

local function cleanKey(k)
  local tk = type(k)
  if tk == "number" or tk == "string" then return tk == "string" and k:sub(1, 120) or k end
  if tk == "table" then
    local out = {}
    for i = 1, 2 do
      local v = k[i]
      if type(v) == "number" or type(v) == "string" then out[i] = v end
    end
    return out
  end
  return nil
end

local function cleanLine(l)
  if type(l) ~= "table" then return nil end
  local text = cleanText(l.text)
  if not text then return nil end
  local out = { text = text }
  if l.style == "muted" or l.style == "warn" then out.style = l.style end
  if type(l.link) == "table" and type(l.link[1]) == "string" then out.link = { l.link[1], cleanKey(l.link[2]) } end
  if type(l.tab) == "string" then out.tab = l.tab end
  if type(l.ask) == "string" then out.ask = cleanText(l.ask) end
  return out
end

-- A plain copy of an answer that's safe to save (and to load back).
function Ask.Pack(ans)
  if type(ans) ~= "table" then return nil end
  local q = cleanText(ans.q)
  if not q then return nil end
  local out = { q = q:sub(1, 200), lines = {} }
  if ans.data then out.data = true end
  if type(ans.lines) == "table" then
    for _, l in ipairs(ans.lines) do
      local c = cleanLine(l)
      if c then out.lines[#out.lines + 1] = c end
    end
  end
  return out
end

function Ask.Save()
  if type(ns.char) ~= "table" then return end
  local saved = {}
  local from = math.max(1, #Ask.history - Ask.MAX_HISTORY + 1)
  for i = from, #Ask.history do
    local p = Ask.Pack(Ask.history[i])
    if p then saved[#saved + 1] = p end
  end
  ns.char.askHistory = #saved > 0 and saved or nil
end

function Ask.Load()
  Ask.history = {}
  local saved = type(ns.char) == "table" and ns.char.askHistory
  if type(saved) ~= "table" then return 0 end
  local from = math.max(1, #saved - Ask.MAX_HISTORY + 1)
  for i = from, #saved do
    local p = Ask.Pack(saved[i])
    if p then
      p.restored = true
      Ask.history[#Ask.history + 1] = setmetatable(p, Ask.AnswerMeta)
    end
  end
  return #Ask.history
end

function Ask.Submit(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  local ans = Ask.Answer(text)
  Ask.history[#Ask.history + 1] = ans
  while #Ask.history > Ask.MAX_HISTORY do table.remove(Ask.history, 1) end
  Ask.Save()
  if ns.AskTab and ns.AskTab.Refresh then ns.AskTab.Refresh(true) end
  return ans
end

-- Clear wipes the saved copy too.
function Ask.Clear()
  Ask.history = {}
  if type(ns.char) == "table" then ns.char.askHistory = nil end
  if ns.AskTab and ns.AskTab.Refresh then ns.AskTab.Refresh(true) end
end

ns:Listen("LOGIN", function() ns.SafeCall(Ask.Load) end)

function Ask.Slash(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then
    ns.UI.Open("ask")
    return
  end
  local ans = Ask.Submit(text)
  ns.Print("|cffb873ffAsk LOMB:|r " .. text)
  for _, line in ipairs(Ask.ChatLines(ans)) do ns.Print("  " .. line) end
end
