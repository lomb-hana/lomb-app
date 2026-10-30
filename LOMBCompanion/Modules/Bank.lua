-- LOMB Companion: bank-character ledger.
--
-- WoW: Forever has no guild bank (as far as we know), so guilds park items on a
-- "bank character". When someone plays that character, the addon counts its bags
-- (always) and its bank vault (whenever the bank window is open), keeps a short
-- log of what came in and went out, and shares the list with the guild.
-- Gold: only the bank character's gold is ever shared, shown as "guild bank funds",
-- and only if "Share guild bank funds" is on. Nobody else's gold is ever read for
-- sharing. Nothing happens at all unless someone ticks "This is a guild bank
-- character" in Settings on that character; the Bank tab stays hidden until then.
local _, ns = ...
local C = ns.Compat
local B = ns:NewModule("Bank")
ns.Bank = B

B.MAX_ITEMS = 300      -- distinct items shared
B.LOG_MAX = 60         -- changes kept locally
B.LOG_SHARE = 30       -- changes shared
B.SCAN_DELAY = 2

local function S() return ns.db.settings end

local function me()
  ns.char.bank = ns.char.bank or {}
  local b = ns.char.bank
  b.bags = b.bags or {}
  b.log = b.log or {}
  return b
end
B.Me = me

-- Is this character a guild bank character? Only if someone ticked it in Settings on
-- this character. Nothing is guessed from names or notes (the guild has no bank alt).
function B.IsBankChar()
  return me().isBank == true
end

function B.SetBankChar(v)
  me().isBank = v and true or false
  if v then B.ScanBags() end
  ns.Shared.MarkDirty("bk")
  ns:Fire("BANK_UPDATED")
end

---------------------------------------------------------------------------
-- scanning
---------------------------------------------------------------------------
local function slotInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C.Call(C_Container.GetContainerItemInfo, bag, slot)
    if type(info) == "table" then return C.Safe(info.itemID), C.Safe(info.stackCount) end
    return nil
  end
  if _G.GetContainerItemInfo then
    local _, count, _, _, _, _, link, _, _, id = C.Call(_G.GetContainerItemInfo, bag, slot)
    return id or C.ItemIdFromLink(link), count
  end
end
local function numSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C.Call(C_Container.GetContainerNumSlots, bag) or 0 end
  if _G.GetContainerNumSlots then return C.Call(_G.GetContainerNumSlots, bag) or 0 end
  return 0
end

-- { [itemID] = count } across a set of bags; nil if any slot couldn't be read
function B.Count(bags)
  local out = {}
  for _, bag in ipairs(bags) do
    for slot = 1, numSlots(bag) do
      local id, count = slotInfo(bag, slot)
      if type(id) == "number" then
        if type(count) ~= "number" then return nil end
        out[id] = (out[id] or 0) + count
      end
    end
  end
  return out
end

function B.BagList()
  local out = {}
  for bag = 0, (_G.NUM_BAG_SLOTS or 4) do out[#out + 1] = bag end
  return out
end
function B.VaultList()
  local out = { _G.BANK_CONTAINER or -1 }
  local first = (_G.NUM_BAG_SLOTS or 4) + 1
  for bag = first, first + (_G.NUM_BANKBAGSLOTS or 6) - 1 do out[#out + 1] = bag end
  return out
end

-- bags + last known vault
function B.Totals()
  local b = me()
  local out = {}
  for id, n in pairs(b.bags or {}) do out[id] = (out[id] or 0) + n end
  for id, n in pairs(b.vault or {}) do out[id] = (out[id] or 0) + n end
  return out
end

-- Note what came in or went out since the last look (bag <-> vault moves cancel out).
function B.Diff(before, after)
  local out = {}
  for id, n in pairs(after) do
    local d = n - (before[id] or 0)
    if d ~= 0 then out[#out + 1] = { id = id, d = d } end
  end
  for id, n in pairs(before) do
    if after[id] == nil then out[#out + 1] = { id = id, d = -n } end
  end
  table.sort(out, function(a, c) return a.id < c.id end)
  return out
end

local function record(before, baseline)
  local b = me()
  if not b.seeded or baseline then b.seeded = true; return end   -- first look: no log, just the baseline
  local now = time()
  for _, ch in ipairs(B.Diff(before, B.Totals())) do
    table.insert(b.log, 1, { t = now, id = ch.id, d = ch.d })
  end
  while #b.log > B.LOG_MAX do table.remove(b.log) end
end

function B.ScanBags()
  if not B.IsBankChar() then return false end
  local counts = B.Count(B.BagList())
  if not counts then return false end
  local b = me()
  local before = B.Totals()
  b.bags, b.bagsAt = counts, time()
  record(before)
  B.ReadMoney()
  ns.Shared.MarkDirty("bk")
  ns:Fire("BANK_UPDATED")
  return true
end

function B.ScanVault()
  if not B.IsBankChar() or not B.vaultOpen then return false end
  local counts = B.Count(B.VaultList())
  local bags = B.Count(B.BagList())
  if not counts or not bags then return false end
  local b = me()
  local before, first = B.Totals(), b.vault == nil
  b.vault, b.vaultAt = counts, time()
  b.bags, b.bagsAt = bags, time()
  record(before, first)   -- the first look at the vault sets a baseline, it isn't "new" items
  B.ReadMoney()
  ns.Shared.MarkDirty("bk")
  ns:Fire("BANK_UPDATED")
  return true
end

function B.ReadMoney()
  if not B.IsBankChar() then return end
  local m = C.Call(GetMoney)
  if type(m) == "number" then me().money = m end
end

B.ScanSoon = ns.Debounce(B.SCAN_DELAY, function()
  if B.vaultOpen then B.ScanVault() else B.ScanBags() end
end)

---------------------------------------------------------------------------
-- the shared ledger ("bk")
---------------------------------------------------------------------------
function B.Build()
  if not B.IsBankChar() then return nil end
  local b = me()
  if not b.bagsAt then return nil end
  local ids = {}
  for id in pairs(B.Totals()) do ids[#ids + 1] = id end
  table.sort(ids)
  local totals = B.Totals()
  local flat = {}
  for i = 1, math.min(#ids, B.MAX_ITEMS) do
    flat[#flat + 1] = ids[i]
    flat[#flat + 1] = totals[ids[i]]
  end
  local hist = {}
  for i = 1, math.min(#b.log, B.LOG_SHARE) do
    local e = b.log[i]
    hist[#hist + 1] = e.t; hist[#hist + 1] = e.id; hist[#hist + 1] = e.d
  end
  return { i = flat, b = b.bagsAt, v = b.vaultAt, h = hist,
           m = S().shareBankFunds and b.money or nil }
end

function B.Validate(d)
  local V = ns.Shared.V
  if type(d) ~= "table" or type(d.i) ~= "table" then return nil end
  local out = { i = {}, h = {}, b = V.time(d.b), v = d.v ~= nil and V.time(d.v) or nil }
  if not out.b then return nil end
  if #d.i % 2 ~= 0 or #d.i > B.MAX_ITEMS * 2 then return nil end
  for k = 1, #d.i, 2 do
    local id, n = V.int(d.i[k], 1, 1e7), V.int(d.i[k + 1], 1, 1e6)
    if not id or not n then return nil end
    out.i[#out.i + 1] = id; out.i[#out.i + 1] = n
  end
  if type(d.h) == "table" and #d.h % 3 == 0 and #d.h <= B.LOG_SHARE * 3 then
    for k = 1, #d.h, 3 do
      local t, id, n = V.time(d.h[k]), V.int(d.h[k + 1], 1, 1e7), V.int(d.h[k + 2], -1e6, 1e6)
      if t and id and n and n ~= 0 then
        out.h[#out.h + 1] = t; out.h[#out.h + 1] = id; out.h[#out.h + 1] = n
      end
    end
  end
  if d.m ~= nil then out.m = V.int(d.m, 0, 1e11) end
  return out
end

-- Every bank character the guild knows about (ours from live data, others' from sync).
-- { { owner, items = { {id, count} }, bagsAt, vaultAt, money, log = { {t, id, d} }, mine } }, newest first
-- our own ledger comes straight from the live data (no wait for the share debounce)
local function each()
  local list = {}
  local own = B.IsBankChar() and B.Build() or nil
  if own then list[#list + 1] = { ns.playerKey, own } end
  for owner, d in ns.Shared.Each("bk") do
    if owner ~= ns.playerKey then list[#list + 1] = { owner, d } end
  end
  local i = 0
  return function()
    i = i + 1
    if list[i] then return list[i][1], list[i][2] end
  end
end
B.Each = each

-- Does the guild have any bank character (ours, or one a guildmate shares)?
-- The Bank tab and the "Guild bank has" tooltip line only exist when it does.
function B.Exists()
  if B.IsBankChar() then return true end
  return each()() ~= nil
end

function B.Ledgers()
  local out = {}
  for owner, d in each() do
    local L = { owner = owner, items = {}, log = {}, bagsAt = d.b, vaultAt = d.v, money = d.m,
                mine = owner == ns.playerKey }
    for k = 1, #d.i, 2 do L.items[#L.items + 1] = { id = d.i[k], count = d.i[k + 1] } end
    for k = 1, #(d.h or {}), 3 do L.log[#L.log + 1] = { t = d.h[k], id = d.h[k + 1], d = d.h[k + 2] } end
    out[#out + 1] = L
  end
  table.sort(out, function(a, c)
    if a.bagsAt ~= c.bagsAt then return (a.bagsAt or 0) > (c.bagsAt or 0) end
    return a.owner < c.owner
  end)
  return out
end

-- total of one item across all bank characters
function B.HasItem(itemID)
  local n = 0
  for _, d in each() do
    for k = 1, #d.i, 2 do if d.i[k] == itemID then n = n + d.i[k + 1] end end
  end
  return n
end

function B.TooltipLine(itemID)
  if not B.Exists() then return nil end
  local n = B.HasItem(itemID)
  if n > 0 then return ("Guild bank has: |cffffffff%d|r"):format(n) end
end

function B:Init()
  ns.Shared.Define({
    kind = "bk", label = "bank ledger", debounce = 15,
    enabled = function() return B.IsBankChar() end,
    build = B.Build, validate = B.Validate,
    onChange = function() ns:Fire("BANK_UPDATED") end,
  })
end

function B:Login()
  if ns.Tooltip then ns.Tooltip.AddLine(B.TooltipLine) end
  ns.After(8, function() B.ScanBags() end)
end

ns:Listen("ROSTER_UPDATED", function()
  if B.IsBankChar() and not me().bagsAt then B.ScanSoon() end
end)
ns:On("BAG_UPDATE_DELAYED", function() if B.IsBankChar() then B.ScanSoon() end end)
ns:On("PLAYERBANKSLOTS_CHANGED", function() if B.vaultOpen then B.ScanSoon() end end)
ns:On("BANKFRAME_OPENED", function()
  B.vaultOpen = true
  if B.IsBankChar() then ns.After(0.5, B.ScanVault) end
end)
ns:On("BANKFRAME_CLOSED", function() B.vaultOpen = false end)
ns:On("PLAYER_MONEY", function()
  if B.IsBankChar() then B.ReadMoney(); ns.Shared.MarkDirty("bk") end
end)
