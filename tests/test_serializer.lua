local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
local S = H.loadPure("Comm/Serializer.lua")

print("Serializer")

H.test("round-trips scalars", function()
  for _, v in ipairs({ 0, 1, -1, 42, 2^40, -2^40, 3.25, -0.001, 1/3, "", "hello", "a:b{c}s3:x" }) do
    local ok, out = S.Decode(S.Encode(v))
    H.ok(ok, "decode failed for " .. tostring(v))
    H.eq(out, v)
  end
  local ok, t = S.Decode(S.Encode(true)); H.ok(ok); H.eq(t, true)
  local ok2, f = S.Decode(S.Encode(false)); H.ok(ok2); H.eq(f, false)
end)

H.test("round-trips nested tables", function()
  local v = { t = "B", n = 1234, nm = "Riverpaw Gnoll", r = { k = 3, c = 2, i = { [2589] = 2, [1234] = 1 }, fk = 1793750400 },
    z = { "Westfall", "Elwynn Forest" }, sp = { 3391 }, flag = true, f = 0.125 }
  local ok, out = S.Decode(S.Encode(v))
  H.ok(ok)
  H.deepEq(out, v)
end)

H.test("strings with any byte survive transport escaping", function()
  local raw = ""
  for b = 0, 255 do raw = raw .. string.char(b) end
  local packed = S.Pack({ s = raw, k = "\0\1\1\2" })
  H.ok(not packed:find("%z"), "no NUL bytes on the wire")
  local ok, out = S.Unpack(packed)
  H.ok(ok)
  H.eq(out.s, raw)
  H.eq(out.k, "\0\1\1\2")
end)

H.test("rejects garbage without throwing", function()
  for _, bad in ipairs({ "", "x", "s5:abc", "{", "{s1:a", "i12", "f;", "{s1:ai1;", "i1;i2;", "s-1:", "{N i1;}" }) do
    local ok = S.Decode(bad)
    H.eq(ok, false, "should reject " .. bad)
  end
  H.eq((S.Unpack(nil)), false)
end)

H.test("depth limit on encode and decode", function()
  local deep = {}
  local cur = deep
  for _ = 1, 40 do cur.x = {}; cur = cur.x end
  H.ok(not pcall(S.Encode, deep))
  local ok = S.Decode(string.rep("{s1:x", 40) .. "N" .. string.rep("}", 40))
  H.eq(ok, false)
end)

H.test("refuses functions / NaN", function()
  H.ok(not pcall(S.Encode, { f = print }))
  H.ok(not pcall(S.Encode, 0/0))
end)

H.test("never executes code", function()
  _G.PWNED = nil
  local ok = S.Decode("s19:PWNED=true return 1")
  H.ok(ok)
  H.eq(_G.PWNED, nil)
end)

H.done()
