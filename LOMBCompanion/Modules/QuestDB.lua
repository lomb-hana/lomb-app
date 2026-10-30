-- LOMB Companion: Quests & Items -- lookups over the bundled ForeverDB.net data
-- (Data/ForeverDB/*.lua). Nothing is fetched at runtime; the data is a snapshot.
--
-- Data from ForeverDB.net (https://foreverdb.net), used with permission. The data
-- files are not covered by this project's MIT license. Anywhere the addon shows
-- this data it says so and shows the link.
local _, ns = ...
local FDB = ns:NewModule("FDB")

FDB.CREDIT = "Data from ForeverDB.net"
FDB.URL = "https://foreverdb.net"
FDB.SUPPORT_URL = "https://buymeacoffee.com/foreverdb"
FDB.CLASSIC_NOTE = "(Classic data, may differ)"
FDB.QUALITY_HEX = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }
FDB.WAYS = { auto = "automatic", trainer = "trainer", vendor = "vendor", drop = "drop", quest = "quest" }

local function D() return ns.FDBData end

function FDB.Available()
  local d = D()
  return d ~= nil and next(d.quests) ~= nil
end

function FDB.Snapshot() local d = D(); return d and d.snapshot end

local function lower(s) return type(s) == "string" and s:lower() or "" end
FDB.Lower = lower
local function has(text, needle) return needle == "" or lower(text):find(needle, 1, true) ~= nil end

---------------------------------------------------------------------------
-- Indexes (built once, the first time anything asks)
---------------------------------------------------------------------------
local idx

local function push(t, k, v)
  local l = t[k]
  if not l then l = {}; t[k] = l end
  l[#l + 1] = v
end

function FDB.Index()
  if idx then return idx end
  local d = D()
  idx = {
    npcStarts = {}, npcEnds = {}, itemStarts = {},
    soldBy = {}, madeBy = {}, reagentFor = {}, recipeItemFor = {}, dungeonLoot = {},
    bySpell = {}, questNext = {}, zones = {}, zoneList = {}, vendorZones = {}, bossDungeon = {},
  }
  if not d then return idx end
  local zc = {}
  for qid, q in pairs(d.quests) do
    if q.st then
      if q.st[1] == "n" then push(idx.npcStarts, q.st[2], qid)
      elseif q.st[1] == "i" then push(idx.itemStarts, q.st[2], qid) end
    end
    if q.en and q.en[1] == "n" then push(idx.npcEnds, q.en[2], qid) end
    for _, p in ipairs(q.pv or {}) do push(idx.questNext, p, qid) end
    if q.z then zc[q.z] = (zc[q.z] or 0) + 1 end
  end
  for z, n in pairs(zc) do idx.zoneList[#idx.zoneList + 1] = { name = z, count = n } end
  table.sort(idx.zoneList, function(a, b) return a.name < b.name end)
  idx.zones = zc
  for vid, v in pairs(d.vendors) do
    local i = v.i or {}
    for k = 1, #i, 4 do
      push(idx.soldBy, i[k], { vendor = vid, price = i[k + 1], stack = i[k + 2], limited = i[k + 3] == 1 })
    end
    if v.z then idx.vendorZones[v.z] = true end
  end
  for slug, p in pairs(d.professions) do
    for ri, r in ipairs(p.r) do
      local ref = { prof = slug, i = ri }
      if r.mk then push(idx.madeBy, r.mk, ref) end
      if r.ri then push(idx.recipeItemFor, r.ri, ref) end
      if r.sp then idx.bySpell[r.sp] = ref end
      local rg = r.rg or {}
      for k = 1, #rg, 2 do push(idx.reagentFor, rg[k], ref) end
    end
  end
  for did, dg in pairs(d.dungeons) do
    for _, l in ipairs(dg.lo or {}) do push(idx.dungeonLoot, l[1], { dungeon = did, why = l[2] }) end
    for _, b in ipairs(dg.b or {}) do idx.bossDungeon[lower(b)] = did end
  end
  return idx
end

function FDB.ResetIndex() idx = nil; FDB.ResetChains() end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
function FDB.PlayerSide()
  local f = UnitFactionGroup and ns.Compat.Call(UnitFactionGroup, "player")
  return (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
end

-- Quests/vendors for "A" or "H" plus anything for both sides; nil side = everything.
function FDB.SideOK(rec, side)
  return not side or rec.s == "B" or rec.s == side
end

-- Faction home zones, for NPCs ForeverDB lists as "both" (trainers mostly).
FDB.ZONE_SIDE = {
  ["Stormwind City"] = "A", ["Ironforge"] = "A", ["Darnassus"] = "A", ["Elwynn Forest"] = "A", ["Dun Morogh"] = "A",
  ["Teldrassil"] = "A", ["Westfall"] = "A", ["Loch Modan"] = "A", ["Darkshore"] = "A", ["Redridge Mountains"] = "A",
  ["Duskwood"] = "A",
  ["Orgrimmar"] = "H", ["Thunder Bluff"] = "H", ["Undercity"] = "H", ["Durotar"] = "H", ["Mulgore"] = "H",
  ["Tirisfal Glades"] = "H", ["Silverpine Forest"] = "H", ["The Barrens"] = "H",
}

-- A, H or B for an NPC record, using its zone when ForeverDB says "both".
function FDB.NpcSide(rec)
  if not rec then return "B" end
  if rec.s and rec.s ~= "B" then return rec.s end
  return FDB.ZONE_SIDE[rec.z or ""] or "B"
end

function FDB.SideText(s)
  return (s == "A" and "Alliance") or (s == "H" and "Horde") or "Both factions"
end

function FDB.ItemName(itemID)
  local name = ns.Compat.ItemInfo(itemID)
  if name then return name end
  local d = D()
  local e = d and d.items[itemID]
  return e and e[1] or ("Item " .. tostring(itemID))
end

-- Coloured item name: the game's own (if cached), else the bundled name.
function FDB.ItemText(itemID)
  local name, _, quality = ns.Compat.ItemInfo(itemID)
  if not name then
    local d = D()
    local e = d and d.items[itemID]
    name, quality = e and e[1] or ("Item " .. tostring(itemID)), e and e[2]
  end
  return "|cff" .. (FDB.QUALITY_HEX[quality or 1] or "ffffff") .. name .. "|r"
end

function FDB.LocText(zone, x, y)
  if not zone then return nil end
  if x and y then return ("%s (%s, %s)"):format(zone, tostring(math.floor(x + 0.5)), tostring(math.floor(y + 0.5))) end
  return zone
end

function FDB.Money(copper)
  if not copper or copper <= 0 then return "free" end
  if ns.Widgets and ns.Widgets.FormatMoney then return ns.Widgets.FormatMoney(copper) end
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  local out = {}
  if g > 0 then out[#out + 1] = g .. "g" end
  if s > 0 then out[#out + 1] = s .. "s" end
  if c > 0 then out[#out + 1] = c .. "c" end
  return table.concat(out, " ")
end

function FDB.LevelText(q)
  if q.r and q.r > 0 and q.r ~= q.l then return ("%d (min %d)"):format(q.l, q.r) end
  return tostring(q.l)
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
function FDB.Quest(id) local d = D(); return d and d.quests[id] end

function FDB.Zones() return FDB.Index().zoneList end

-- opts: search, zone, minLevel, maxLevel, side, sort ("level" | "name")
function FDB.QuestList(opts)
  opts = opts or {}
  local d, out = D(), {}
  if not d then return out end
  local needle = lower(opts.search):gsub("^%s+", ""):gsub("%s+$", "")
  for id, q in pairs(d.quests) do
    if (not opts.zone or q.z == opts.zone)
      and (not opts.minLevel or q.l >= opts.minLevel)
      and (not opts.maxLevel or q.l <= opts.maxLevel)
      and FDB.SideOK(q, opts.side)
      and (needle == "" or has(q.n, needle) or has(q.z, needle)
        or (q.st and has(q.st[3], needle)) or (q.en and has(q.en[3], needle))) then
      out[#out + 1] = { id = id, q = q }
    end
  end
  if opts.sort == "name" then
    table.sort(out, function(a, b) if a.q.n ~= b.q.n then return a.q.n < b.q.n end return a.id < b.id end)
  else
    table.sort(out, function(a, b)
      local la, lb = a.q.l > 0 and a.q.l or 99, b.q.l > 0 and b.q.l or 99   -- no level (books etc.) last
      if la ~= lb then return la < lb end
      if a.q.n ~= b.q.n then return a.q.n < b.q.n end
      return a.id < b.id
    end)
  end
  return out
end

---------------------------------------------------------------------------
-- Quest chains, worked out from the pv/nx links in the bundled data.
--
-- The links form small graphs, and some branch (class letters, side quests) or
-- merge. To get a clear "Part k of n" each chain is cut into straight lines:
-- the longest path first, then the longest path through what's left, and so on.
-- A line that branches off (or leads into) another one carries on that line's
-- numbering, so "Part 3 of 4" always counts along one real path through the
-- quest. Links to quests outside the bundle (above level 30) set `more`.
-- If the links ever loop, the remaining quests are ordered by level, name and
-- id and marked `unclear`.
---------------------------------------------------------------------------
local chains

local function questKey(Q, id)
  local q = Q[id]
  local l = (q.l and q.l > 0) and q.l or 99
  return l, q.n or "", id
end

local function before(Q, a, b)
  local la, na, ia = questKey(Q, a)
  local lb, nb, ib = questKey(Q, b)
  if la ~= lb then return la < lb end
  if na ~= nb then return na < nb end
  return ia < ib
end

-- Longest path through the unassigned quests `left` (a set). nil if they loop.
local function longestPath(Q, nodes, left, succ, pred)
  local indeg, ready, order = {}, {}, {}
  for _, v in ipairs(nodes) do
    if left[v] then
      local n = 0
      for p in pairs(pred[v] or {}) do if left[p] then n = n + 1 end end
      indeg[v] = n
      if n == 0 then ready[#ready + 1] = v end
    end
  end
  while #ready > 0 do
    table.sort(ready, function(a, b) return before(Q, b, a) end)   -- pop the "smallest"
    local v = table.remove(ready)
    order[#order + 1] = v
    for s in pairs(succ[v] or {}) do
      if left[s] then
        indeg[s] = indeg[s] - 1
        if indeg[s] == 0 then ready[#ready + 1] = s end
      end
    end
  end
  local count = 0
  for _ in pairs(indeg) do count = count + 1 end
  if #order < count then return nil end
  local dist, from, best = {}, {}, nil
  for _, v in ipairs(order) do
    dist[v] = 1
    local preds = {}
    for p in pairs(pred[v] or {}) do if left[p] then preds[#preds + 1] = p end end
    table.sort(preds, function(a, b) return before(Q, a, b) end)
    for _, p in ipairs(preds) do
      if dist[p] + 1 > dist[v] then dist[v] = dist[p] + 1; from[v] = p end
    end
    if not best or dist[v] > dist[best] or (dist[v] == dist[best] and before(Q, v, best)) then best = v end
  end
  local path, v = {}, best
  while v do table.insert(path, 1, v); v = from[v] end
  return path
end

local function buildChains()
  local d = D()
  chains = { of = {}, lines = {} }
  if not d then return chains end
  local Q = d.quests
  local succ, pred, adj, ext = {}, {}, {}, {}
  local function link(a, b)
    if a == b then return end
    succ[a] = succ[a] or {}; succ[a][b] = true
    pred[b] = pred[b] or {}; pred[b][a] = true
    adj[a] = adj[a] or {}; adj[a][b] = true
    adj[b] = adj[b] or {}; adj[b][a] = true
  end
  for id, q in pairs(Q) do
    for _, p in ipairs(q.pv or {}) do if Q[p] then link(p, id) else ext[id] = "before" end end
    for _, n in ipairs(q.nx or {}) do
      if Q[n] then link(id, n) elseif ext[id] ~= "before" then ext[id] = "after" end
    end
  end
  local starts = {}
  for id in pairs(adj) do starts[#starts + 1] = id end
  table.sort(starts)
  local seen = {}
  for _, root in ipairs(starts) do
    if not seen[root] then
      local comp, stack = {}, { root }
      seen[root] = true
      while #stack > 0 do
        local v = table.remove(stack)
        comp[#comp + 1] = v
        for w in pairs(adj[v]) do if not seen[w] then seen[w] = true; stack[#stack + 1] = w end end
      end
      table.sort(comp, function(a, b) return before(Q, a, b) end)
      local branches = false
      for _, v in ipairs(comp) do
        local ns_, np = 0, 0
        for _ in pairs(succ[v] or {}) do ns_ = ns_ + 1 end
        for _ in pairs(pred[v] or {}) do np = np + 1 end
        if ns_ > 1 or np > 1 then branches = true end
      end
      local left, remaining = {}, #comp
      for _, v in ipairs(comp) do left[v] = true end
      while remaining > 0 do
        local path = longestPath(Q, comp, left, succ, pred)
        local unclear = false
        if not path then        -- the links loop: fall back to level / name / id order
          path, unclear = {}, true
          for _, v in ipairs(comp) do if left[v] then path[#path + 1] = v end end
        end
        for _, v in ipairs(path) do left[v] = nil end
        remaining = remaining - #path
        -- carry on the numbering of a line this one branches off or leads into
        local offset, tail, from, into = 0, 0, nil, nil
        for p in pairs(pred[path[1]] or {}) do
          local c = chains.of[p]
          if c and c.part > offset then offset, from = c.part, p end
        end
        for s in pairs(succ[path[#path]] or {}) do
          local c = chains.of[s]
          if c and c.total - c.part + 1 > tail then tail, into = c.total - c.part + 1, s end
        end
        local line = { ids = path, branch = branches or nil, unclear = unclear or nil, from = from, into = into }
        chains.lines[#chains.lines + 1] = line
        local total = offset + #path + tail
        local more = ext[path[#path]] == "after" or nil
        for k, v in ipairs(path) do
          chains.of[v] = { line = line, part = offset + k, total = total, more = more,
            earlier = (k == 1 and offset == 0 and ext[v] == "before") or nil }
        end
      end
    end
  end
  return chains
end

-- { part, total, more, line = { ids, branch, unclear, from, into } } or nil
function FDB.Chain(id)
  if not chains then buildChains() end
  return chains.of[id]
end

function FDB.ResetChains() chains = nil end

-- "Part 2 of 3" ("of 3+" when the chain goes on past level 30; "Part ?" when it
-- starts above level 30, which the bundle can't count).
function FDB.ChainText(id)
  local c = FDB.Chain(id)
  if not c then return nil end
  if c.earlier then return "Part ? of ?" end
  return ("Part %d of %d%s"):format(c.part, c.total, c.more and "+" or "")
end

-- Takes a sorted quest list ({ id, q } entries) and pulls each chain line together
-- in chain order, where the line's first listed quest sits. Other quests stay put.
function FDB.GroupChains(list)
  local byLine, out, done = {}, {}, {}
  for _, e in ipairs(list) do
    local c = FDB.Chain(e.id)
    if c then
      byLine[c.line] = byLine[c.line] or {}
      table.insert(byLine[c.line], e)
    end
  end
  for _, e in ipairs(list) do
    local c = FDB.Chain(e.id)
    if not c then
      out[#out + 1] = e
    elseif not done[c.line] then
      done[c.line] = true
      local group = byLine[c.line]
      table.sort(group, function(a, b) return FDB.Chain(a.id).part < FDB.Chain(b.id).part end)
      for _, g in ipairs(group) do out[#out + 1] = g end
    end
  end
  return out
end

function FDB.QuestsForNpc(npcId)
  local i = FDB.Index()
  return i.npcStarts[npcId], i.npcEnds[npcId]
end

function FDB.NextQuests(id)
  local q = FDB.Quest(id)
  local out, seen = {}, {}
  for _, n in ipairs((q and q.nx) or {}) do if not seen[n] then seen[n] = true; out[#out + 1] = n end end
  for _, n in ipairs(FDB.Index().questNext[id] or {}) do if not seen[n] then seen[n] = true; out[#out + 1] = n end end
  return out
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
function FDB.ItemSearch(text, limit)
  local d, out = D(), {}
  if not d then return out end
  local needle = lower(text)
  for id, e in pairs(d.items) do
    if needle == "" or has(e[1], needle) then out[#out + 1] = id end
  end
  table.sort(out, function(a, b)
    local na, nb = d.items[a][1] or "", d.items[b][1] or ""
    if na ~= nb then return na < nb end
    return a < b
  end)
  if limit and #out > limit then for k = #out, limit + 1, -1 do out[k] = nil end end
  return out
end

-- Everything the bundle knows about one item.
function FDB.ItemFacts(itemID)
  local i = FDB.Index()
  return {
    soldBy = i.soldBy[itemID] or {},
    madeBy = i.madeBy[itemID] or {},
    reagentFor = i.reagentFor[itemID] or {},
    teaches = i.recipeItemFor[itemID] or {},
    startsQuest = i.itemStarts[itemID] or {},
    dungeons = i.dungeonLoot[itemID] or {},
  }
end

function FDB.Known(itemID)
  local f = FDB.ItemFacts(itemID)
  return #f.soldBy + #f.madeBy + #f.reagentFor + #f.teaches + #f.startsQuest + #f.dungeons > 0
end

---------------------------------------------------------------------------
-- Vendors
---------------------------------------------------------------------------
function FDB.Vendor(id) local d = D(); return d and d.vendors[id] end

function FDB.VendorList(opts)
  opts = opts or {}
  local d, out = D(), {}
  if not d then return out end
  local needle = lower(opts.search)
  for id, v in pairs(d.vendors) do
    local ok = FDB.SideOK(v, opts.side) and (not opts.zone or v.z == opts.zone)
    if ok and needle ~= "" then
      ok = has(v.n, needle) or has(v.t, needle) or has(v.z, needle)
      if not ok then
        local i = v.i or {}
        for k = 1, #i, 4 do
          if has(FDB.ItemName(i[k]), needle) then ok = true; break end
        end
      end
    end
    if ok then out[#out + 1] = { id = id, v = v } end
  end
  table.sort(out, function(a, b)
    if (a.v.z or "") ~= (b.v.z or "") then return (a.v.z or "") < (b.v.z or "") end
    if a.v.n ~= b.v.n then return a.v.n < b.v.n end
    return a.id < b.id
  end)
  return out
end

---------------------------------------------------------------------------
-- Professions / recipes
---------------------------------------------------------------------------
function FDB.Professions()
  local d, out = D(), {}
  if not d then return out end
  for slug, p in pairs(d.professions) do out[#out + 1] = { slug = slug, p = p } end
  table.sort(out, function(a, b)
    if a.p.k ~= b.p.k then return (a.p.k or "") > (b.p.k or "") end   -- primary before secondary
    return a.p.n < b.p.n
  end)
  return out
end

function FDB.Profession(slug) local d = D(); return d and d.professions[slug] end

function FDB.Recipe(ref)
  local p = ref and FDB.Profession(ref.prof)
  return p and p.r[ref.i], p
end

function FDB.RecipeForSpell(spellID)
  local ref = spellID and FDB.Index().bySpell[spellID]
  if ref then return FDB.Recipe(ref) end
end

function FDB.RecipeForItem(itemID)
  local refs = itemID and FDB.Index().madeBy[itemID]
  if refs and refs[1] then return FDB.Recipe(refs[1]) end
end

-- opts: prof (slug or nil for all), search, maxSkill
function FDB.RecipeList(opts)
  opts = opts or {}
  local d, out = D(), {}
  if not d then return out end
  local needle = lower(opts.search)
  for slug, p in pairs(d.professions) do
    if not opts.prof or opts.prof == slug then
      for ri, r in ipairs(p.r) do
        local ok = not opts.maxSkill or (r.sk[1] or 0) <= opts.maxSkill
        if ok and needle ~= "" then
          ok = has(r.n, needle) or has(r.cat, needle) or (r.mk and has(FDB.ItemName(r.mk), needle))
          if not ok and r.rg then
            for k = 1, #r.rg, 2 do if has(FDB.ItemName(r.rg[k]), needle) then ok = true; break end end
          end
        end
        if ok then out[#out + 1] = { prof = slug, i = ri, r = r } end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.prof ~= b.prof then return a.prof < b.prof end
    local sa, sb = a.r.sk[1] or 999, b.r.sk[1] or 999   -- unknown skill sorts last
    if sa ~= sb then return sa < sb end
    return a.r.n < b.r.n
  end)
  return out
end

function FDB.SkillText(sk)
  if not sk then return "" end
  return ("|cffff8040%s|r |cffffff00%s|r |cff40c040%s|r |cff808080%s|r"):format(
    tostring(sk[1] or "?"), tostring(sk[2] or "?"), tostring(sk[3] or "?"), tostring(sk[4] or "?"))
end

function FDB.WaysText(r)
  if not r.w then return "unknown" end
  local out = {}
  for w in r.w:gmatch("[^,]+") do out[#out + 1] = FDB.WAYS[w] or w end
  return table.concat(out, ", ")
end

function FDB.ReagentsText(r)
  local out = {}
  local rg = r.rg or {}
  for k = 1, #rg, 2 do out[#out + 1] = ("%dx %s"):format(rg[k + 1], FDB.ItemName(rg[k])) end
  return table.concat(out, ", ")
end

---------------------------------------------------------------------------
-- Dungeons
---------------------------------------------------------------------------
function FDB.Dungeon(id) local d = D(); return d and d.dungeons[id] end

function FDB.DungeonList(search)
  local d, out = D(), {}
  if not d then return out end
  local needle = lower(search)
  for id, dg in pairs(d.dungeons) do
    local ok = needle == "" or has(dg.n, needle)
    if not ok then for _, b in ipairs(dg.b or {}) do if has(b, needle) then ok = true; break end end end
    if ok then out[#out + 1] = { id = id, d = dg } end
  end
  table.sort(out, function(a, b)
    local la, lb = a.d.lr and a.d.lr[1] or a.d.lv or 99, b.d.lr and b.d.lr[1] or b.d.lv or 99
    if la ~= lb then return la < lb end
    return a.d.n < b.d.n
  end)
  return out
end

function FDB.DungeonLevelText(dg)
  if dg.lr then
    if dg.lr[1] == dg.lr[2] then return tostring(dg.lr[1]) end
    return ("%d-%d"):format(dg.lr[1], dg.lr[2])
  end
  return dg.lv and tostring(dg.lv) or "?"
end

function FDB.DungeonForBoss(name)
  local did = name and FDB.Index().bossDungeon[lower(name)]
  return did, did and FDB.Dungeon(did)
end

---------------------------------------------------------------------------
-- One-line item tooltip summary (with the credit on the line itself)
---------------------------------------------------------------------------
function FDB.TooltipText(itemID)
  if not FDB.Available() or not itemID then return nil end
  local f = FDB.ItemFacts(itemID)
  local bits = {}
  if #f.soldBy > 0 then
    local best
    for _, s in ipairs(f.soldBy) do
      local per = (s.price or 0) / math.max(1, s.stack or 1)
      if not best or per < best.per then best = { per = per, s = s } end
    end
    local v = FDB.Vendor(best.s.vendor)
    local text = ("Sold by %s"):format(v and v.n or "a vendor")
    if v and v.z then text = text .. " (" .. v.z .. ")" end
    text = text .. " for " .. FDB.Money(best.s.price) .. (best.s.stack and best.s.stack > 1 and (" per " .. best.s.stack) or "")
    if #f.soldBy > 1 then text = text .. (" +%d more"):format(#f.soldBy - 1) end
    bits[#bits + 1] = text
  end
  if #f.madeBy > 0 then
    local r, p = FDB.Recipe(f.madeBy[1])
    if r then bits[#bits + 1] = ("Made with %s %d"):format(p.n, r.sk[1] or 0) end
  end
  if #f.reagentFor > 0 then
    bits[#bits + 1] = ("Reagent in %d recipe%s"):format(#f.reagentFor, #f.reagentFor == 1 and "" or "s")
  end
  if #f.teaches > 0 then
    local r, p = FDB.Recipe(f.teaches[1])
    if r then bits[#bits + 1] = ("Teaches %s (%s %d)"):format(r.n, p.n, r.sk[1] or 0) end
  end
  if #f.startsQuest > 0 then
    local q = FDB.Quest(f.startsQuest[1])
    if q then bits[#bits + 1] = "Starts quest: " .. q.n end
  end
  if #f.dungeons > 0 then
    local dg = FDB.Dungeon(f.dungeons[1].dungeon)
    if dg then bits[#bits + 1] = "Notable loot in " .. dg.n end
  end
  if #bits == 0 then return nil end
  return table.concat(bits, "  ·  ") .. "  |cff9a92a8(" .. FDB.CREDIT .. ", " .. FDB.URL .. ")|r"
end

---------------------------------------------------------------------------
-- Bestiary hook: quests a creature gives/takes, and dungeon boss info.
---------------------------------------------------------------------------
local function mobName(npcId, ctx)
  local live = ctx and ctx.live
  if live and live.npcId == npcId and type(live.name) == "string" then return live.name end
  local m = ns.db and ns.db.bestiary and ns.db.bestiary[npcId]
  return m and m.nm
end

function FDB.MobInfo(npcId, ctx)
  if not FDB.Available() or not npcId then return nil end
  local out, any = {}, false
  local starts, ends = FDB.QuestsForNpc(npcId)
  if starts or ends then
    local list, seen = {}, {}
    for _, set in ipairs({ starts or {}, ends or {} }) do
      for _, qid in ipairs(set) do
        if not seen[qid] then
          seen[qid] = true
          local q = FDB.Quest(qid)
          list[#list + 1] = { id = qid, name = q.n, level = q.l }
        end
      end
    end
    table.sort(list, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.name < b.name end)
    out.quests, any = list, true
  end
  local did, dg = FDB.DungeonForBoss(mobName(npcId, ctx))
  if dg then
    local classic = dg.st == "classic" and ("  " .. FDB.CLASSIC_NOTE) or ""
    out.boss = { notes = ("Boss in %s (levels %s, %d players).%s"):format(dg.n, FDB.DungeonLevelText(dg), dg.p or 5, classic),
      dungeon = did }
    if dg.lo then
      local nl = {}
      for _, l in ipairs(dg.lo) do nl[#nl + 1] = { itemID = l[1], note = l[2] } end
      out.notableLoot = nl
    end
    any = true
  end
  return any and out or nil
end

function FDB.RegisterProvider()
  if not (ns.Providers and FDB.Available()) then return end
  ns.Providers.Register({
    id = "foreverdb", label = "ForeverDB", priority = 50,
    credit = FDB.CREDIT, url = FDB.URL, dataVersion = FDB.Snapshot(),
    GetMob = function(npcId, ctx) return FDB.MobInfo(npcId, ctx) end,
  })
end
FDB.RegisterProvider()

-- Item tooltip line (off with the "ForeverDB.net info on item tooltips" setting).
function FDB.TooltipLine(itemID)
  if ns.db and ns.db.settings and ns.db.settings.fdbTooltips == false then return nil end
  return FDB.TooltipText(itemID)
end

function FDB:Login()
  if ns.Tooltip and FDB.Available() then ns.Tooltip.AddLine(FDB.TooltipLine) end
end

return FDB
