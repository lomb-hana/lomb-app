-- LOMB Companion: compact, safe serializer for addon messages.
-- Format (no Lua code is ever executed on decode):
--   nil           -> "N"
--   true / false  -> "T" / "F"
--   integer       -> "i<digits>;"
--   float         -> "f<%.17g>;"
--   string        -> "s<len>:<bytes>"
--   table         -> "{" <key value>* "}"
-- Transport escaping (addon messages can't carry "\0"): "\1" -> "\1\1", "\0" -> "\1\2".
local _, ns = ...
local S = {}
if ns then ns.Serializer = S end

local type, tonumber, pairs = type, tonumber, pairs
local floor, huge = math.floor, math.huge
local concat = table.concat
local sub, find, format = string.sub, string.find, string.format

S.MAX_DEPTH = 16
S.MAX_LEN = 64 * 1024

local function encode(v, out, depth)
  local t = type(v)
  if t == "nil" then
    out[#out + 1] = "N"
  elseif t == "boolean" then
    out[#out + 1] = v and "T" or "F"
  elseif t == "number" then
    if v ~= v or v == huge or v == -huge then
      error("cannot serialize NaN/inf")
    elseif v == floor(v) and v >= -2^53 and v <= 2^53 then
      out[#out + 1] = format("i%.0f;", v)
    else
      out[#out + 1] = format("f%.17g;", v)
    end
  elseif t == "string" then
    out[#out + 1] = "s" .. #v .. ":"
    out[#out + 1] = v
  elseif t == "table" then
    if depth >= S.MAX_DEPTH then error("table nested too deeply") end
    out[#out + 1] = "{"
    for k, val in pairs(v) do
      local kt = type(k)
      if kt == "string" or kt == "number" or kt == "boolean" then
        encode(k, out, depth + 1)
        encode(val, out, depth + 1)
      end
    end
    out[#out + 1] = "}"
  else
    error("cannot serialize " .. t)
  end
end

function S.Encode(v)
  local out = {}
  encode(v, out, 0)
  return concat(out)
end

local function decode(str, pos, depth)
  local c = sub(str, pos, pos)
  if c == "N" then return nil, pos + 1
  elseif c == "T" then return true, pos + 1
  elseif c == "F" then return false, pos + 1
  elseif c == "i" or c == "f" then
    local stop = find(str, ";", pos + 1, true)
    if not stop then error("unterminated number") end
    local n = tonumber(sub(str, pos + 1, stop - 1))
    if not n then error("bad number") end
    return n, stop + 1
  elseif c == "s" then
    local colon = find(str, ":", pos + 1, true)
    if not colon then error("bad string header") end
    local len = tonumber(sub(str, pos + 1, colon - 1))
    if not len or len < 0 or colon + len > #str then error("bad string length") end
    return sub(str, colon + 1, colon + len), colon + len + 1
  elseif c == "{" then
    if depth >= S.MAX_DEPTH then error("table nested too deeply") end
    local t = {}
    pos = pos + 1
    while true do
      if pos > #str then error("unterminated table") end
      if sub(str, pos, pos) == "}" then return t, pos + 1 end
      local k, v
      k, pos = decode(str, pos, depth + 1)
      v, pos = decode(str, pos, depth + 1)
      if k == nil then error("nil key") end
      t[k] = v
    end
  end
  error("unexpected '" .. c .. "' at " .. pos)
end

-- Returns ok, value-or-error. Never throws.
function S.Decode(str)
  if type(str) ~= "string" then return false, "not a string" end
  if #str > S.MAX_LEN then return false, "too large" end
  local ok, v, pos = pcall(decode, str, 1, 0)
  if not ok then return false, v end
  if pos ~= #str + 1 then return false, "trailing data" end
  return true, v
end

function S.Escape(str)
  return (str:gsub("\1", "\1\1"):gsub("%z", "\1\2"))
end

function S.Unescape(str)
  return (str:gsub("\1([\1\2])", function(c) return c == "\1" and "\1" or "\0" end))
end

function S.Pack(v) return S.Escape(S.Encode(v)) end

function S.Unpack(str)
  if type(str) ~= "string" then return false, "not a string" end
  return S.Decode(S.Unescape(str))
end

return S
