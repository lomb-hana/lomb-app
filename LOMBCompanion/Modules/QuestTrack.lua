-- LOMB Companion: which quests this character has done, or has in the quest log.
--
-- Everything here is defensive. The Forever client (1.60.1) lists the modern
-- C_QuestLog API (GetInfo, IsOnQuest, ReadyForTurnIn, GetAllCompletedQuestIDs,
-- IsQuestFlaggedCompleted) and the QUEST_TURNED_IN / QUEST_ACCEPTED /
-- QUEST_REMOVED events, but none of it has been tried on a live server yet.
-- So each call is guarded, the old Classic globals are a fallback, and every
-- turn-in the addon sees is also saved per character (ns.char.questsDone), so
-- progress still counts up if the game won't tell us its quest history.
--
-- Status(id): "log" (in the quest log), "ready" (in the log, ready to turn in),
-- "done", "none" (the game says it isn't done), or nil (can't tell).
-- Nothing is inferred: earlier parts of a chain are not marked done just because
-- a later part is.
local _, ns = ...
local C = ns.Compat
local Track = ns:NewModule("QuestTrack")

-- what the client answered this session
Track.api = { log = false, completed = false, flagged = false, turnins = false }

local inLog, ready = {}, {}       -- [questID] = true
local doneSet = nil               -- [questID] = true, from the game's history
local flagged = {}                -- [questID] = true/false, per-quest answers (cached)

local function QL() local q = _G.C_QuestLog; return type(q) == "table" and q or nil end
local function num(v) v = C.Safe(v); return type(v) == "number" and v > 0 and v or nil end
local function saved() return ns.char and ns.char.questsDone end

local function record(id)
  local s = saved()
  if s and id and not s[id] then s[id] = C.Now() end
end

---------------------------------------------------------------------------
-- Quest log
---------------------------------------------------------------------------
function Track.ScanLog()
  local L = QL()
  local set, rdy, ok = {}, {}, false
  if L and type(L.GetNumQuestLogEntries) == "function" and type(L.GetInfo) == "function" then
    local n = C.Call(L.GetNumQuestLogEntries)
    if type(n) == "number" then
      ok = true
      for i = 1, n do
        local info = C.Call(L.GetInfo, i)
        if type(info) == "table" and not C.Safe(info.isHeader) then
          local id = num(info.questID)
          if not id and type(L.GetQuestIDForLogIndex) == "function" then id = num(C.Call(L.GetQuestIDForLogIndex, i)) end
          if id then set[id] = true end
        end
      end
      for id in pairs(set) do
        local r = C.Call(L.ReadyForTurnIn, id)
        if r == nil then r = C.Call(L.IsComplete, id) end
        if r == true then rdy[id] = true end
      end
    end
  elseif type(_G.GetNumQuestLogEntries) == "function" and type(_G.GetQuestLogTitle) == "function" then
    -- Classic-era globals (not in the 1.60.1 listing; kept in case they come back)
    local n = C.Call(_G.GetNumQuestLogEntries)
    if type(n) == "number" then
      ok = true
      for i = 1, n do
        local _, _, _, isHeader, _, complete, _, qid = C.Call(_G.GetQuestLogTitle, i)
        local id = num(qid)
        if not isHeader and id then
          set[id] = true
          if complete == 1 or complete == true then rdy[id] = true end
        end
      end
    end
  end
  Track.api.log = ok
  if ok then
    -- a quest that left the log while ready to hand in was most likely turned in
    -- (covers clients where QUEST_TURNED_IN never fires)
    for id in pairs(ready) do if not set[id] then record(id) end end
    inLog, ready = set, rdy
  end
  return ok
end

---------------------------------------------------------------------------
-- The game's completed-quest history
---------------------------------------------------------------------------
function Track.ScanDone()
  local L = QL()
  local set
  if L and type(L.GetAllCompletedQuestIDs) == "function" then
    local t = C.Call(L.GetAllCompletedQuestIDs)
    if type(t) == "table" then
      set = {}
      for _, id in ipairs(t) do id = num(id); if id then set[id] = true end end
    end
  end
  if not set and type(_G.GetQuestsCompleted) == "function" then
    local t = C.Call(_G.GetQuestsCompleted)
    if type(t) == "table" then
      set = {}
      for id, v in pairs(t) do id = num(id); if id and v then set[id] = true end end
    end
  end
  doneSet = set
  flagged = {}
  Track.api.completed = set ~= nil
  Track.api.flagged = (L and type(L.IsQuestFlaggedCompleted) == "function")
    or type(_G.IsQuestFlaggedCompleted) == "function" or false
  return set ~= nil
end

local function askFlagged(id)
  local v = flagged[id]
  if v ~= nil then return v end
  local L = QL()
  local r
  if L and type(L.IsQuestFlaggedCompleted) == "function" then r = C.Call(L.IsQuestFlaggedCompleted, id) end
  if r == nil and type(_G.IsQuestFlaggedCompleted) == "function" then r = C.Call(_G.IsQuestFlaggedCompleted, id) end
  if r ~= nil then flagged[id] = (r == true) end
  return r
end

---------------------------------------------------------------------------
-- Answers
---------------------------------------------------------------------------
-- true when there's anything to go on (the game answered, or turn-ins were seen)
function Track.Knows()
  local s = saved()
  return Track.api.completed or Track.api.flagged or (s ~= nil and next(s) ~= nil) or false
end

function Track.Status(id)
  if type(id) ~= "number" then return nil end
  if inLog[id] then return ready[id] and "ready" or "log" end
  if doneSet and doneSet[id] then return "done" end
  local s = saved()
  if s and s[id] then return "done" end
  local f
  if Track.api.flagged then f = askFlagged(id) end
  if f == true then return "done" end
  if doneSet or f == false then return "none" end
  return nil
end

-- where a "done" came from: "game" or "seen" (a turn-in this addon saw)
function Track.Source(id)
  if (doneSet and doneSet[id]) or flagged[id] == true then return "game" end
  local s = saved()
  if s and s[id] then return "seen" end
  return nil
end

-- done, total for a list of quest ids
function Track.Progress(ids)
  local done = 0
  for _, id in ipairs(ids) do if Track.Status(id) == "done" then done = done + 1 end end
  return done, #ids
end

-- How many quests this character has completed: the game's history when it
-- answers, else the turn-ins the addon has seen (whichever is larger).
function Track.DoneCount()
  local d, s = 0, 0
  for _ in pairs(doneSet or {}) do d = d + 1 end
  for _ in pairs(saved() or {}) do s = s + 1 end
  return math.max(d, s)
end

-- one line for /lomb quests (what to check on Nov 4)
function Track.Report()
  local n = 0
  for _ in pairs(inLog) do n = n + 1 end
  local d = 0
  for _ in pairs(doneSet or {}) do d = d + 1 end
  local s = 0
  for _ in pairs(saved() or {}) do s = s + 1 end
  return ("Quest log: %s (%d quests). Game history: %s%s. Per-quest check: %s. Turn-ins seen by the addon: %d%s.")
    :format(Track.api.log and "readable" or "not readable", n,
      Track.api.completed and "readable" or "not readable", Track.api.completed and (" (" .. d .. " done)") or "",
      Track.api.flagged and "yes" or "no", s, Track.api.turnins and " (event works)" or "")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function changed() ns:Fire("QUESTS_CHANGED") end

function Track:Init()
  local s = saved()
  if s then
    -- keep it small and clean: numbers only
    for k, v in pairs(s) do if type(k) ~= "number" or type(v) ~= "number" then s[k] = nil end end
  end
  local rescan = ns.Debounce(0.5, function() Track.ScanLog(); changed() end)
  ns:On("QUEST_TURNED_IN", function(_, questID)
    local id = num(questID)
    if not id then return end
    Track.api.turnins = true
    record(id)
    inLog[id], ready[id] = nil, nil
    changed()
  end)
  ns:On("QUEST_ACCEPTED", function() rescan() end)
  ns:On("QUEST_REMOVED", function() rescan() end)
  ns:On("QUEST_LOG_UPDATE", function() rescan() end)
end

function Track:Login()
  Track.ScanLog()
  Track.ScanDone()
  -- the history can arrive a little after login; ask again once
  ns.After(10, function() if Track.ScanDone() then changed() end end)
  changed()
end
