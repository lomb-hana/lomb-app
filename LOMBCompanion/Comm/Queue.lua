-- LOMB Companion: throttled outgoing queue.
-- The server allows a small burst of addon messages then roughly one per second
-- per prefix; we stay under that with a token bucket, keep three priorities,
-- back off when the game reports throttling, and hold everything while sending is
-- locked down (boss encounters, PvP) or impossible (trial accounts).
local _, ns = ...
local Q = {}
if ns then ns.Queue = Q end

Q.ALERT, Q.NORMAL, Q.BULK = 1, 2, 3

local Queue = {}
Queue.__index = Queue

-- opts: send(msg) -> "ok"|"throttle"|"lockdown"|"fail", canSend() -> bool, clock() -> seconds
function Q.New(opts)
  local q = setmetatable({}, Queue)
  q.send = assert(opts.send, "send required")
  q.canSend = opts.canSend or function() return true end
  q.clock = opts.clock or GetTime
  q.capacity = opts.capacity or 9
  q.rate = opts.rate or 1            -- tokens per second
  q.maxItems = opts.maxItems or 400
  q.tokens = q.capacity
  q.last = q.clock()
  q:Clear()
  q.blockedUntil = 0
  q.backoff = 0
  q.stats = { sent = 0, throttled = 0, dropped = 0, failed = 0 }
  return q
end

-- Each lane is a FIFO with explicit first/last indices (no holes, no # on sparse tables).
local function laneSize(lane) return lane.last - lane.first + 1 end

function Queue:Size()
  local n = 0
  for p = 1, 3 do n = n + laneSize(self.lanes[p]) end
  return n
end

-- Enqueue a group of wire messages that must stay together and in order.
function Queue:Push(messages, priority)
  priority = priority or Q.NORMAL
  if type(messages) == "string" then messages = { messages } end
  if self:Size() + #messages > self.maxItems then
    -- drop the newest bulk traffic first; alerts always get in
    if priority == Q.BULK then
      self.stats.dropped = self.stats.dropped + #messages
      return false
    end
    self:DropBulk(#messages)
  end
  local lane = self.lanes[priority]
  for i = 1, #messages do
    lane.last = lane.last + 1
    lane[lane.last] = messages[i]
  end
  return true
end

function Queue:DropBulk(n)
  local lane = self.lanes[Q.BULK]
  while n > 0 and laneSize(lane) > 0 do
    lane[lane.last] = nil
    lane.last = lane.last - 1
    n = n - 1
    self.stats.dropped = self.stats.dropped + 1
  end
end

function Queue:Refill()
  local now = self.clock()
  local dt = now - self.last
  if dt > 0 then
    self.tokens = math.min(self.capacity, self.tokens + dt * self.rate)
    self.last = now
  end
  return now
end

local function peek(self)
  for p = 1, 3 do
    local lane = self.lanes[p]
    if lane.first <= lane.last then return p, lane[lane.first] end
  end
end

local function pop(self, p)
  local lane = self.lanes[p]
  lane[lane.first] = nil
  lane.first = lane.first + 1
  if lane.first > lane.last then
    lane.first, lane.last = 1, 0   -- drained: reset indices
  end
end

-- Send as much as the bucket allows. Call from an OnUpdate/ticker.
function Queue:Pump()
  local now = self:Refill()
  if now < self.blockedUntil then return 0 end
  if not self.canSend() then return 0 end
  local sent = 0
  while self.tokens >= 1 do
    local p, msg = peek(self)
    if not p then break end
    local res = self.send(msg)
    if res == "ok" then
      pop(self, p)
      self.tokens = self.tokens - 1
      self.backoff = 0
      sent = sent + 1
      self.stats.sent = self.stats.sent + 1
    elseif res == "throttle" or res == "lockdown" then
      -- keep the message, wait, retry with growing backoff (max 30s)
      self.stats.throttled = self.stats.throttled + 1
      self.backoff = math.min(30, self.backoff > 0 and self.backoff * 2 or 2)
      self.blockedUntil = now + self.backoff
      self.tokens = 0
      break
    else
      pop(self, p)
      self.stats.failed = self.stats.failed + 1
    end
  end
  return sent
end

function Queue:Clear()
  self.lanes = { { first = 1, last = 0 }, { first = 1, last = 0 }, { first = 1, last = 0 } }
end

return Q
