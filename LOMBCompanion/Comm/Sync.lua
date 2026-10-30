-- LOMB Companion: guild sync.
-- Messages (serialized tables, chunked, throttled, GUILD channel only):
--   H  hello      { t="H", v=addonVersion, p=protocol }
--   P  profile    { t="P", v, lv, cl, pr, il, pt }  or { t="P", off=true } when sharing is off
--   B  bestiary   { t="B", n=npcId, ... }  (see Bestiary.BuildSyncPayload)
--   D / W         shared per-member datasets (see Comm/Shared.lua)
-- Other modules add message types with Sync.RegisterHandler(type, fn).
-- Nothing is sent during boss encounters, PvP matches or chat lockdown, and
-- trial accounts are receive-only.
local _, ns = ...
local C = ns.Compat
local Sync = ns:NewModule("Sync")

Sync.FLUSH_INTERVAL = 120     -- seconds between bestiary flushes
Sync.FLUSH_MAX = 30           -- npcs per flush
Sync.BACKFILL_MAX = 20        -- npcs sent when a new guildmate shows up
Sync.BACKFILL_COOLDOWN = 300
Sync.PROFILE_COOLDOWN = 30

Sync.stats = { received = 0, bad = 0, sessionPeers = 0 }
Sync.sessionPeers = {}
Sync.lastProfileSent = -1e9
Sync.lastBackfill = -1e9
Sync.newerVersionSeen = nil

local Serializer, Chunker, Queue = ns.Serializer, ns.Chunker, ns.Queue

function Sync.CanSend()
  if not C.Call(IsInGuild) then return false, "not in a guild" end
  if C.IsRestrictedAccount() then return false, "receive-only (trial account)" end
  if C.InEncounter() then return false, "paused (boss encounter)" end
  if C.InPvPMatch() then return false, "paused (PvP)" end
  if C.MessagingLockdown() then return false, "paused (lockdown)" end
  return true
end

function Sync:Init()
  Sync.assembler = Chunker.NewAssembler(GetTime)
  Sync.queue = Queue.New({
    send = function(msg) return C.SendAddonMessage(ns.PREFIX, msg, "GUILD") end,
    canSend = function() return (Sync.CanSend()) end,
    clock = GetTime,
  })
  C.RegisterPrefix(ns.PREFIX)
end

function Sync.Send(tbl, priority)
  if not Sync.queue then return false end
  tbl.v = tbl.v or ns.version
  local ok, payload = pcall(Serializer.Pack, tbl)
  if not ok then ns.Debug("serialize failed: %s", tostring(payload)); return false end
  local parts, err = Chunker.Split(payload)
  if not parts then ns.Debug("not sent: %s", err); return false end
  return Sync.queue:Push(parts, priority)
end

function Sync.SendHello()
  local msg = { t = "H", p = ns.PROTOCOL }
  -- revisions of the datasets we publish, so guildmates can ask for what they lack
  if ns.Shared then msg.ds = ns.Shared.Digest() end
  Sync.Send(msg, Queue.ALERT)
end

function Sync.SendProfile(force)
  local nowT = GetTime()
  if not force and nowT - Sync.lastProfileSent < Sync.PROFILE_COOLDOWN then
    Sync.profileDirty = true
    return
  end
  Sync.lastProfileSent = nowT
  Sync.profileDirty = false
  if not ns.db.settings.shareProfile then
    Sync.Send({ t = "P", off = true }, Queue.NORMAL)
    return
  end
  local msg = ns.Me.Profile()
  msg.t = "P"
  Sync.Send(msg, Queue.NORMAL)
  -- keep our own row in the roster up to date too
  ns.Roster.UpdatePeer(ns.playerKey, msg)
end

function Sync.SendMob(npcId, priority)
  local payload = ns.Bestiary.BuildSyncPayload(npcId)
  if payload then return Sync.Send(payload, priority or Queue.BULK) end
end

function Sync.FlushBestiary()
  if not ns.db.settings.shareBestiary then return 0 end
  if C.InCombat() or not Sync.CanSend() then return 0 end
  local sent = 0
  for npcId in pairs(ns.Bestiary.dirty) do
    if sent >= Sync.FLUSH_MAX then break end
    ns.Bestiary.dirty[npcId] = nil
    Sync.SendMob(npcId)
    sent = sent + 1
  end
  return sent
end

-- Share our most recent records when a new guildmate comes online.
function Sync.Backfill()
  if not ns.db.settings.shareBestiary then return 0 end
  local nowT = GetTime()
  if nowT - Sync.lastBackfill < Sync.BACKFILL_COOLDOWN then return 0 end
  Sync.lastBackfill = nowT
  local mine = {}
  for npcId, m in pairs(ns.db.bestiary) do
    local r = m.rec and m.rec[ns.playerKey]
    if r then mine[#mine + 1] = { id = npcId, t = r.t or 0 } end
  end
  table.sort(mine, function(a, b) return a.t > b.t end)
  local n = math.min(#mine, Sync.BACKFILL_MAX)
  for i = 1, n do Sync.SendMob(mine[i].id) end
  return n
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
-- "0.1.10" > "0.1.9"
function Sync.IsNewerVersion(a, b)
  if type(a) ~= "string" or type(b) ~= "string" then return false end
  local pa, pb = {}, {}
  for n in a:gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in b:gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

local handlers = {}
Sync.handlers = handlers

function Sync.RegisterHandler(msgType, fn)
  assert(type(msgType) == "string" and not handlers[msgType], "handler already registered")
  handlers[msgType] = fn
end

handlers.H = function(sender, d)
  ns.Roster.UpdatePeer(sender, d)
  if not Sync.sessionPeers[sender] then
    Sync.sessionPeers[sender] = true
    Sync.stats.sessionPeers = Sync.stats.sessionPeers + 1
    -- answer a newcomer with our profile + a small backfill, after a random delay
    -- so a guild full of addon users doesn't all reply at the same moment
    ns.After(2 + math.random() * 8, function()
      Sync.SendProfile()
      Sync.Backfill()
    end)
  end
  if ns.Shared then ns.Shared.OnDigest(sender, d.ds) end
  ns:Fire("PEER_HELLO", sender, d)
end

handlers.P = function(sender, d)
  Sync.sessionPeers[sender] = Sync.sessionPeers[sender] or true
  ns.Roster.UpdatePeer(sender, d)
end

handlers.B = function(sender, d)
  if not ns.db.settings.shareBestiary then return end   -- sharing off = no exchange either way
  ns.Bestiary.ApplyRemote(sender, d)
end

function Sync.Handle(sender, d)
  if type(d) ~= "table" or type(d.t) ~= "string" then
    Sync.stats.bad = Sync.stats.bad + 1
    return
  end
  local newer = (type(d.p) == "number" and d.p > ns.PROTOCOL) or Sync.IsNewerVersion(d.v, ns.version)
  if newer then
    if not Sync.newerVersionSeen then
      Sync.newerVersionSeen = tostring(d.v)
      ns.Print("A guildmate has a newer LOMB Companion (%s). Grab it from the LOMB GitHub page.", tostring(d.v))
    end
  end
  local h = handlers[d.t]
  if h then
    Sync.stats.received = Sync.stats.received + 1
    h(sender, d)
  end
end

function Sync.OnAddonMessage(prefix, msg, channel, sender)
  if prefix ~= ns.PREFIX or channel ~= "GUILD" then return end
  sender = C.FullName(sender)
  if not sender or sender == ns.playerKey then return end
  local payload = Sync.assembler:Feed(sender, msg)
  if not payload then return end
  local ok, data = Serializer.Unpack(payload)
  if not ok then
    Sync.stats.bad = Sync.stats.bad + 1
    ns.Debug("bad message from %s: %s", sender, tostring(data))
    return
  end
  Sync.Handle(sender, data)
end

ns:On("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
  Sync.OnAddonMessage(prefix, msg, channel, sender)
end)

---------------------------------------------------------------------------
-- Status line for the UI footer
---------------------------------------------------------------------------
function Sync.Status()
  local can, why = Sync.CanSend()
  local peers = ns.Roster.PeerCount()
  local q = Sync.queue and Sync.queue:Size() or 0
  local state = can and "|cff7fe07fsyncing|r" or ("|cffe0b060" .. why .. "|r")
  if not C.Call(IsInGuild) then state = "|cff888888not in a guild|r" end
  return ("%s  ·  %d guildmate%s with LOMB  ·  queue %d"):format(state, peers, peers == 1 and "" or "s", q)
end

function Sync:Login()
  ns.Every(0.25, function() Sync.queue:Pump() end)
  ns.Every(10, function() Sync.assembler:Purge() end)
  ns.Every(Sync.FLUSH_INTERVAL, Sync.FlushBestiary)
  ns.Every(60, function() if Sync.profileDirty then Sync.SendProfile() end end)
  -- jittered hello so a raid of logins doesn't collide
  ns.After(6 + math.random() * 6, function()
    Sync.SendHello()
    Sync.SendProfile(true)
  end)
end

ns:Listen("PROFILE_CHANGED", function() Sync.profileDirty = true end)
ns:On("PLAYER_GUILD_UPDATE", function()
  if C.Call(IsInGuild) and ns.loggedIn then ns.After(5, Sync.SendHello) end
end)
