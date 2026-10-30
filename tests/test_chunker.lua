local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
local K = H.loadPure("Comm/Chunker.lua")

print("Chunker")
local clock = 0
local function now() return clock end

H.test("small payload is a single message", function()
  local parts = K.Split("hello")
  H.eq(#parts, 1)
  H.eq(parts[1], "Shello")
  H.eq(K.NewAssembler(now):Feed("A", parts[1]), "hello")
end)

H.test("254 bytes fits in one message, 255 does not", function()
  H.eq(#K.Split(string.rep("x", 254)), 1)
  H.eq(#K.Split(string.rep("x", 254))[1], 255)
  H.eq(#K.Split(string.rep("x", 255)), 2)
end)

H.test("every wire message is <= 255 bytes and reassembles", function()
  for _, size in ipairs({ 255, 251 * 2, 251 * 2 + 1, 1000, 5000, 251 * 64 }) do
    local payload = {}
    for i = 1, size do payload[i] = string.char(65 + (i * 7) % 26) end
    payload = table.concat(payload)
    local parts = assert(K.Split(payload))
    local a = K.NewAssembler(now)
    local result
    for i, p in ipairs(parts) do
      H.ok(#p <= 255, "part too long: " .. #p)
      local r = a:Feed("Bob-Forever", p)
      if i < #parts then H.eq(r, nil) else result = r end
    end
    H.eq(result, payload, "size " .. size)
  end
end)

H.test("too large payload refused", function()
  local parts, err = K.Split(string.rep("x", 251 * 64 + 1))
  H.eq(parts, nil)
  H.ok(err)
end)

H.test("interleaved senders and messages", function()
  local p1 = K.Split(string.rep("a", 600))
  local p2 = K.Split(string.rep("b", 600))
  local a = K.NewAssembler(now)
  local got = {}
  for i = 1, 3 do
    got[#got + 1] = a:Feed("A", p1[i])
    got[#got + 1] = a:Feed("B", p2[i])
    got[#got + 1] = a:Feed("A", (K.Split("solo")[1]))
  end
  local results = {}
  for _, g in pairs(got) do results[#results + 1] = g end
  table.sort(results)
  H.eq(#results, 5)
  H.eq(results[5], "solo") -- 3x solo, 1x a.., 1x b..
  H.eq(results[1], string.rep("a", 600))
  H.eq(results[2], string.rep("b", 600))
end)

H.test("missing first part is dropped, stale parts time out", function()
  local parts = K.Split(string.rep("z", 600))
  local a = K.NewAssembler(now)
  H.eq(a:Feed("A", parts[2]), nil)
  H.eq(a:Feed("A", parts[3]), nil)
  a:Feed("A", parts[1])
  clock = clock + K.TIMEOUT + 1
  H.eq(a:Feed("A", parts[2]), nil)
  H.eq(a:Feed("A", parts[3]), nil, "expired message must not complete")
  a:Purge()
  H.eq(next(a.pending), nil)
end)

H.test("ids are unique across many splits", function()
  local seen = {}
  for _ = 1, 1000 do
    local id = K.Split(string.rep("q", 300))[1]:sub(2, 4)
    H.ok(not seen[id], "duplicate id " .. id)
    seen[id] = true
  end
end)

H.done()
