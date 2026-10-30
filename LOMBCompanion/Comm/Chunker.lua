-- LOMB Companion: split payloads to fit the 255-byte addon message limit and
-- reassemble them on the other side.
--   single message : "S" .. payload                (payload <= 254 bytes)
--   multi-part     : "F"|"M"|"L" .. id(3) .. part   (part <= 251 bytes)
local _, ns = ...
local K = {}
if ns then ns.Chunker = K end

K.MAX_MSG = 255
K.SINGLE_MAX = K.MAX_MSG - 1
K.PART_MAX = K.MAX_MSG - 4
K.TIMEOUT = 30       -- seconds to wait for the rest of a message
K.MAX_PARTS = 64     -- refuse anything bigger (~16 KB)
K.MAX_PENDING = 32   -- per sender

local ID_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local counter = 0

local function nextId()
  counter = (counter + 1) % (62 * 62 * 62)
  local n, id = counter, ""
  for _ = 1, 3 do
    local d = n % 62
    id = ID_CHARS:sub(d + 1, d + 1) .. id
    n = (n - d) / 62
  end
  return id
end

-- Returns a list of wire messages, or nil + error if the payload is too big.
function K.Split(payload)
  if #payload <= K.SINGLE_MAX then return { "S" .. payload } end
  local parts = math.ceil(#payload / K.PART_MAX)
  if parts > K.MAX_PARTS then return nil, "payload too large" end
  local id, out = nextId(), {}
  for i = 1, parts do
    local piece = payload:sub((i - 1) * K.PART_MAX + 1, i * K.PART_MAX)
    local tag = (i == 1) and "F" or (i == parts and "L" or "M")
    out[i] = tag .. id .. piece
  end
  return out
end

---------------------------------------------------------------------------
-- Reassembly
---------------------------------------------------------------------------
local Assembler = {}
Assembler.__index = Assembler

function K.NewAssembler(clock)
  return setmetatable({ pending = {}, clock = clock or time }, Assembler)
end

-- Feed one wire message. Returns the complete payload when one finishes, else nil.
function Assembler:Feed(sender, msg)
  if type(msg) ~= "string" or #msg < 1 then return nil end
  local tag = msg:sub(1, 1)
  if tag == "S" then return msg:sub(2) end
  if #msg < 4 then return nil end
  local id, part = msg:sub(2, 4), msg:sub(5)
  local now = self.clock()
  local bySender = self.pending[sender]
  if not bySender then
    bySender = { n = 0 }
    self.pending[sender] = bySender
  end
  if tag == "F" then
    if not bySender[id] then
      if bySender.n >= K.MAX_PENDING then return nil end
      bySender.n = bySender.n + 1
    end
    bySender[id] = { parts = { part }, t = now }
    return nil
  end
  local entry = bySender[id]
  if not entry then return nil end      -- missed the first part; drop
  if tag ~= "M" and tag ~= "L" then return nil end
  if now - entry.t > K.TIMEOUT or #entry.parts >= K.MAX_PARTS then
    bySender[id] = nil
    bySender.n = bySender.n - 1
    return nil
  end
  entry.parts[#entry.parts + 1] = part
  entry.t = now
  if tag == "L" then
    bySender[id] = nil
    bySender.n = bySender.n - 1
    return table.concat(entry.parts)
  end
  return nil
end

function Assembler:Purge()
  local now = self.clock()
  for sender, bySender in pairs(self.pending) do
    for id, entry in pairs(bySender) do
      if id ~= "n" and now - entry.t > K.TIMEOUT then
        bySender[id] = nil
        bySender.n = bySender.n - 1
      end
    end
    if bySender.n <= 0 then self.pending[sender] = nil end
  end
end

return K
