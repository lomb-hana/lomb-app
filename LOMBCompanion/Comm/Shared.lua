-- LOMB Companion: shared per-member datasets (recipes, gear, bank, wishlist, ...).
--
-- Each member publishes a few small datasets about themselves. A dataset has a
-- revision (epoch seconds of its last change); the hello message carries a digest
-- of our revisions so guildmates who hold an older copy (or none) can ask for it.
--   D  data   { t="D", k=kind, r=rev, d=data }    or { t="D", k, r, off=true } (withdrawn)
--   W  want   { t="W", o=owner, k={kind,...} }     "owner, please re-send these"
-- Data is only ever about the sender, so a copy can only be replaced by its owner.
-- Wants are jittered and suppressed when someone else already asked (it's one
-- broadcast channel: the owner's single reply serves everybody).
local _, ns = ...
local Shared = ns:NewModule("Shared")

Shared.kinds = {}
Shared.SEND_COOLDOWN = 20     -- seconds between two sends of the same dataset
Shared.WANT_SUPPRESS = 30     -- seconds a want from anyone covers everybody
Shared.MAX_BYTES = 8000       -- refuse to publish anything bigger
Shared.STALE_DAYS = 30        -- drop copies of members gone from the roster this long

Shared.lastSent = {}          -- [kind] = GetTime()
Shared.pendingSend = {}       -- [kind] = true while a cooled-down send is scheduled
Shared.seenWants = {}         -- [owner .. "/" .. kind] = GetTime()
Shared.stats = { received = 0, rejected = 0, wants = 0 }

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
Shared.DeepEqual = deepEqual

-- small validators shared by the dataset modules
local V = {}
Shared.V = V
function V.int(v, lo, hi)
  if type(v) ~= "number" or v ~= v or v % 1 ~= 0 then return nil end
  if (lo and v < lo) or (hi and v > hi) then return nil end
  return v
end
function V.num(v, lo, hi)
  if type(v) ~= "number" or v ~= v then return nil end
  if (lo and v < lo) or (hi and v > hi) then return nil end
  return v
end
function V.str(v, maxLen)
  if type(v) ~= "string" or v == "" then return nil end
  if #v > (maxLen or 64) then v = v:sub(1, maxLen or 64) end
  return (v:gsub("[%c|]", ""))   -- no control chars, no UI escape sequences
end
function V.idList(v, maxN, maxId)
  if type(v) ~= "table" then return nil end
  local out, n = {}, 0
  for _, id in ipairs(v) do
    id = V.int(id, 1, maxId or 1e7)
    if id then
      n = n + 1
      if n > (maxN or 1000) then break end
      out[n] = id
    end
  end
  return out
end
function V.time(v) return V.num(v, 1.5e9, 4e9) end
function V.name(v)
  v = V.str(v, 48)
  if v and v:find("^[^%s%-][^%s]*$") then return v end
  return nil
end

local function store(kind)
  local g = ns.DB.Guild()
  if not g then return nil end
  g.shared = g.shared or {}
  g.shared[kind] = g.shared[kind] or {}
  return g.shared[kind]
end
Shared.Store = store

---------------------------------------------------------------------------
-- Defining datasets
--   def = { kind = "rc", label = "recipes",
--           build    = function() return data or nil end,   -- our own data
--           enabled  = function() return bool end,          -- sharing switch
--           validate = function(data, owner) return clean or nil end,
--           onChange = function(owner, data) end }          -- optional
---------------------------------------------------------------------------
function Shared.Define(def)
  assert(type(def.kind) == "string" and #def.kind <= 4, "kind")
  assert(type(def.build) == "function" and type(def.validate) == "function", "build + validate")
  assert(not Shared.kinds[def.kind], "dataset kind already defined: " .. def.kind)
  def.enabled = def.enabled or function() return true end
  Shared.kinds[def.kind] = def
  def.publishSoon = ns.Debounce(def.debounce or 5, function() Shared.Publish(def.kind) end)
  return def
end

function Shared.Get(kind, owner)
  local s = store(kind)
  local e = s and s[owner]
  if e and not e.off then return e.d, e end
  return nil, e
end

-- iterate live copies: for owner, data in Shared.Each(kind) do ... end
function Shared.Each(kind)
  local s = store(kind) or {}
  local owner
  return function()
    while true do
      local e
      owner, e = next(s, owner)
      if owner == nil then return nil end
      if not e.off and e.d ~= nil then return owner, e.d, e end
    end
  end
end

-- Our own data may have changed: publish (debounced).
function Shared.MarkDirty(kind)
  local def = Shared.kinds[kind]
  if def then def.publishSoon() end
end

---------------------------------------------------------------------------
-- Publishing our own datasets
---------------------------------------------------------------------------
function Shared.Publish(kind, force)
  local def = Shared.kinds[kind]
  local s = store(kind)
  if not def or not s or not ns.playerKey then return false end
  local data
  if def.enabled() then
    local ok, res = pcall(def.build)
    if ok then data = res else ns.Debug("build %s failed: %s", kind, tostring(res)) end
  end
  if data ~= nil then
    local packed = ns.Serializer.Pack(data)
    if #packed > Shared.MAX_BYTES then
      ns.Debug("%s too large to share (%d bytes)", kind, #packed)
      return false
    end
  end
  local own = s[ns.playerKey]
  local changed
  if data == nil then
    changed = own ~= nil and not own.off
  else
    changed = not own or own.off or not deepEqual(own.d, data)
  end
  if not changed and not force then return false end
  if changed then
    local rev = math.max(time(), (own and own.r or 0) + 1)
    if data == nil then
      s[ns.playerKey] = { r = rev, off = true, at = time() }
    else
      s[ns.playerKey] = { r = rev, d = data, at = time() }
    end
    if def.onChange then ns.SafeCall(def.onChange, ns.playerKey, data) end
    ns:Fire("SHARED_UPDATED", kind, ns.playerKey)
  end
  Shared.Send(kind)
  return true
end

-- Send our current copy (respecting the per-dataset cooldown).
function Shared.Send(kind)
  local s = store(kind)
  local own = s and s[ns.playerKey]
  if not own or not ns.Sync then return end
  local nowT = GetTime()
  local wait = Shared.SEND_COOLDOWN - (nowT - (Shared.lastSent[kind] or -1e9))
  if wait > 0 then
    if not Shared.pendingSend[kind] then
      Shared.pendingSend[kind] = true
      ns.After(wait, function()
        Shared.pendingSend[kind] = nil
        Shared.Send(kind)
      end)
    end
    return
  end
  Shared.lastSent[kind] = nowT
  local msg = { t = "D", k = kind, r = own.r }
  if own.off then msg.off = true else msg.d = own.d end
  ns.Sync.Send(msg, ns.Queue.BULK)
end

-- { [kind] = rev } (negative rev = withdrawn) for the hello message
function Shared.Digest()
  local out, any = {}, false
  for kind in pairs(Shared.kinds) do
    local s = store(kind)
    local own = s and ns.playerKey and s[ns.playerKey]
    if own then
      out[kind] = own.off and -own.r or own.r
      any = true
    end
  end
  return any and out or nil
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function wantKey(owner, kind) return owner .. "/" .. kind end

function Shared.OnDigest(sender, ds)
  if type(ds) ~= "table" then return end
  local wants = {}
  for kind, rev in pairs(ds) do
    local def = Shared.kinds[kind]
    rev = V.num(rev, -4e9, 4e9)
    if def and rev then
      local s = store(kind)
      local e = s and s[sender]
      if rev > 0 and (not e or e.r < rev) then wants[#wants + 1] = kind
      elseif rev < 0 and e and not e.off and e.r < -rev then wants[#wants + 1] = kind end
    end
  end
  if #wants == 0 then return end
  ns.After(1 + math.random() * 3, function()
    local still = {}
    local nowT = GetTime()
    for _, kind in ipairs(wants) do
      local seen = Shared.seenWants[wantKey(sender, kind)]
      local _, e = Shared.Get(kind, sender)
      local stale = not e or (e.r < math.abs(ds[kind]))
      if stale and not (seen and nowT - seen < Shared.WANT_SUPPRESS) then
        still[#still + 1] = kind
        Shared.seenWants[wantKey(sender, kind)] = nowT
      end
    end
    if #still > 0 then
      Shared.stats.wants = Shared.stats.wants + 1
      ns.Sync.Send({ t = "W", o = sender, k = still }, ns.Queue.NORMAL)
    end
  end)
end

function Shared.OnWant(_, d)
  local owner = V.str(d.o, 64)
  if not owner or type(d.k) ~= "table" then return end
  local nowT = GetTime()
  for i, kind in ipairs(d.k) do
    if i > 16 then break end
    if type(kind) == "string" and Shared.kinds[kind] then
      Shared.seenWants[wantKey(owner, kind)] = nowT
      if owner == ns.playerKey then Shared.Send(kind) end
    end
  end
end

function Shared.OnData(sender, d)
  local def = type(d.k) == "string" and Shared.kinds[d.k]
  local rev = V.time(d.r)
  local s = def and store(d.k)
  if not def or not rev or not s then
    Shared.stats.rejected = Shared.stats.rejected + 1
    return
  end
  local e = s[sender]
  if e and e.r >= rev then return end          -- old or duplicate copy
  if d.off then
    s[sender] = { r = rev, off = true, at = time() }
  else
    local ok, clean = pcall(def.validate, d.d, sender)
    if not ok or clean == nil then
      Shared.stats.rejected = Shared.stats.rejected + 1
      ns.Debug("rejected %s from %s", d.k, sender)
      return
    end
    s[sender] = { r = rev, d = clean, at = time() }
  end
  Shared.stats.received = Shared.stats.received + 1
  if def.onChange then ns.SafeCall(def.onChange, sender, s[sender].d) end
  ns:Fire("SHARED_UPDATED", d.k, sender)
end

-- Forget copies of people who left the guild a while ago.
function Shared.Prune()
  local g = ns.DB.Guild()
  if not g or not g.shared or #ns.Roster.members == 0 then return 0 end
  local cutoff, n = time() - Shared.STALE_DAYS * 86400, 0
  for _, s in pairs(g.shared) do
    for owner, e in pairs(s) do
      if owner ~= ns.playerKey and not ns.Roster.byName[owner] and (e.at or 0) < cutoff then
        s[owner] = nil
        n = n + 1
      end
    end
  end
  return n
end

function Shared:Init()
  ns.Sync.RegisterHandler("D", Shared.OnData)
  ns.Sync.RegisterHandler("W", Shared.OnWant)
end

-- Joined a guild / guild info arrived late: our copies live in the guild bucket.
Shared.RepublishSoon = ns.Debounce(5, function()
  for kind in pairs(Shared.kinds) do ns.SafeCall(Shared.Publish, kind) end
end)
ns:On("PLAYER_GUILD_UPDATE", function() if ns.loggedIn then Shared.RepublishSoon() end end)

function Shared:Login()
  -- refresh our own copies before the hello goes out (no send unless changed)
  for kind in pairs(Shared.kinds) do ns.SafeCall(Shared.Publish, kind) end
  ns.Every(3600, Shared.Prune)
end
