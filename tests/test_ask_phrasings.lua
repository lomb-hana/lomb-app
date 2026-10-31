local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Ask LOMB phrasings (tests/ask_phrasings.txt)")

local dir = (arg[0]:match("^(.*)/[^/]+$") or ".")
local rows = {}
for line in io.lines(dir .. "/ask_phrasings.txt") do
  if line:match("%S") and not line:match("^%s*#") then
    local intent, target, q = line:match("^%s*(%S+)%s*|%s*(.-)%s*|%s*(.-)%s*$")
    assert(intent, "bad row: " .. line)
    rows[#rows + 1] = { intent = intent, target = target, q = q }
  end
end

local function boot()
  local ns = H.boot()
  C_Item.GetItemInfo = function() return nil end
  H.state.level, H.state.class, H.state.zone, H.state.faction = 18, "ROGUE", "Westfall", "Alliance"
  ns.Ask.ResetIndex()
  return ns
end

H.test(("the table has at least 150 phrasings (%d)"):format(#rows), function()
  H.ok(#rows >= 150, "only " .. #rows .. " rows")
end)

H.test("every phrasing is read as the intended question", function()
  local ns = boot()
  local bad = {}
  for _, r in ipairs(rows) do
    if r.intent == "unknown" then
      local a = ns.Ask.Answer(r.q)
      local t = {}
      for _, l in ipairs(a.lines) do t[#t + 1] = l.text end
      if not (a.unknown or table.concat(t, "\n"):find("couldn't find", 1, true)) then
        bad[#bad + 1] = ("%q: expected unknown, got %s"):format(r.q, t[1] or "nothing")
      end
    else
      local p = ns.Ask.Parse(r.q)
      if p.intent ~= r.intent or p.target ~= r.target then
        bad[#bad + 1] = ("%q: expected %s | %s, got %s | %s"):format(r.q, r.intent, r.target, p.intent, tostring(p.target))
      end
    end
  end
  H.ok(#bad == 0, #bad .. " of " .. #rows .. " misread:\n  " .. table.concat(bad, "\n  "))
end)

H.test("typos and close names offer 'Did you mean' chips", function()
  local ns = boot()
  local a = ns.Ask.Answer("who sells linen")
  local chips = 0
  for _, l in ipairs(a.lines) do if l.ask and l.text:find("Did you mean", 1, true) then chips = chips + 1 end end
  H.ok(chips >= 1 and a.suggest, "chips offered for a partial name")
  a = ns.Ask.Answer("Who sells Fine Thread?")
  H.ok(not a.suggest, "no chips for an exact name")
end)

H.test("no reading throws, whatever is typed", function()
  local ns = boot()
  for _, q in ipairs({ "?", "!!!", "1-2-3", "lvl", "quests 99-1", "the the the", "|Hitem:999999|h[x]|h",
      string.rep("a", 300), "where where where", "de", "q", "lvl 0 quests" }) do
    local ok, a = pcall(ns.Ask.Answer, q)
    H.ok(ok and a and #a.lines >= 1, "answered: " .. q)
  end
end)

H.done()
