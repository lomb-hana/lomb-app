local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
local Q = H.loadPure("Comm/Queue.lua")

print("Queue")

local function setup(opts)
  local env = { t = 0, sent = {}, result = "ok", can = true }
  local q = Q.New({
    clock = function() return env.t end,
    canSend = function() return env.can end,
    send = function(m)
      if env.result ~= "ok" then return env.result end
      env.sent[#env.sent + 1] = { m = m, t = env.t }
      return "ok"
    end,
    capacity = opts and opts.capacity, rate = opts and opts.rate, maxItems = opts and opts.maxItems,
  })
  local function run(seconds)
    local stop = env.t + seconds
    while env.t < stop - 1e-9 do
      env.t = env.t + 0.25
      q:Pump()
    end
  end
  return q, env, run
end

H.test("burst then ~1 msg/sec", function()
  local q, env, run = setup()
  for i = 1, 40 do q:Push("m" .. i) end
  q:Pump()
  H.eq(#env.sent, 9, "initial burst")
  run(10)
  H.ok(#env.sent >= 18 and #env.sent <= 20, "after 10s: " .. #env.sent)
  -- never more than capacity + rate*window in any window
  for i = 1, #env.sent do
    local n = 0
    for j = i, #env.sent do
      if env.sent[j].t - env.sent[i].t < 5 then n = n + 1 end
    end
    H.ok(n <= 9 + 5, "window overflow " .. n)
  end
end)

H.test("priority order: alert before normal before bulk", function()
  local q, env = setup({ capacity = 1 })
  q:Push("bulk", Q.BULK)
  q:Push("normal", Q.NORMAL)
  q:Push("alert", Q.ALERT)
  q:Pump(); env.t = 1; q:Pump(); env.t = 2; q:Pump()
  H.eq(env.sent[1].m, "alert")
  H.eq(env.sent[2].m, "normal")
  H.eq(env.sent[3].m, "bulk")
end)

H.test("multi-part groups stay in order", function()
  local q, env, run = setup()
  q:Push({ "F1", "M1", "L1" })
  q:Push({ "F2", "L2" })
  run(5)
  local s = {}
  for _, e in ipairs(env.sent) do s[#s + 1] = e.m end
  H.eq(table.concat(s, ","), "F1,M1,L1,F2,L2")
end)

H.test("throttle result keeps message and backs off", function()
  local q, env = setup()
  q:Push({ "a", "b" })
  env.result = "throttle"
  q:Pump()
  H.eq(q:Size(), 2)
  H.eq(q.stats.throttled, 1)
  env.result = "ok"
  env.t = 1; q:Pump()
  H.eq(#env.sent, 0, "still backing off")
  env.t = 3; q:Pump()
  H.eq(#env.sent, 2, "sent after backoff")
  H.eq(env.sent[1].m, "a"); H.eq(env.sent[2].m, "b")
  -- repeated throttling grows the backoff
  q:Push("c"); env.result = "throttle"; env.t = 4; q:Pump()
  q:Push("d"); env.t = 30; q:Pump()
  H.eq(q.backoff, 4)
end)

H.test("nothing sent while paused (encounter / pvp / trial)", function()
  local q, env, run = setup()
  for i = 1, 5 do q:Push("m" .. i) end
  env.can = false
  run(30)
  H.eq(#env.sent, 0)
  env.can = true
  run(1)
  H.eq(#env.sent, 5)
end)

H.test("queue cap drops bulk first, keeps alerts", function()
  local q = setup({ maxItems = 10 })
  for i = 1, 10 do q:Push("b" .. i, Q.BULK) end
  H.eq(q:Push("more", Q.BULK), false)
  H.ok(q:Push("alert", Q.ALERT))
  H.eq(q:Size(), 10)
  H.ok(q.stats.dropped >= 2)
end)

H.test("hard failure drops the message", function()
  local q, env = setup()
  q:Push("x")
  env.result = "fail"
  q:Pump()
  H.eq(q:Size(), 0)
  H.eq(q.stats.failed, 1)
end)

H.done()
