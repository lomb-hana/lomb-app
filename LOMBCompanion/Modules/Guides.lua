-- LOMB Companion: guides over the bundled ForeverDB.net data (Data/ForeverDB/*.lua):
-- what to train, gathering, disenchanting, gear sets, rogue poisons, zones and
-- battlegrounds. Lookups only -- nothing is fetched at runtime.
--
-- What isn't in the data (and so isn't guessed here):
--   * class trainer costs (ForeverDB has none): the addon notes them when you
--     open your class trainer, per class, and shows them after that;
--   * where set pieces drop: only vendor / recipe / dungeon-pick
--     facts from the bundle (quest rewards aren't in it), plus drops the guild's own bestiary recorded;
--   * the enchanting skill a disenchant needs, and zone level ranges / factions
--     (zone levels below come from the quests in that zone).
-- Classic data (CMaNGOS) is labelled "(Classic data, may differ)" wherever it shows.
local _, ns = ...
local C = ns.Compat
local G = ns:NewModule("Guides")

G.PROFS = { "herbalism", "mining", "skinning", "fishing" }
G.PROF_NAME = { herbalism = "Herbalism", mining = "Mining", skinning = "Skinning", fishing = "Fishing" }
G.SET_SLOTS = 19   -- equipped slots 1..19

local function D() return ns.FDBData end
local function lower(s) return type(s) == "string" and s:lower() or "" end
local function has(text, needle) return needle == "" or lower(text):find(needle, 1, true) ~= nil end
local function S() return ns.db and ns.db.settings or {} end

function G.Available()
  local d = D()
  return d ~= nil and d.classes ~= nil and next(d.classes) ~= nil
end

---------------------------------------------------------------------------
-- Classes: what to train
---------------------------------------------------------------------------
function G.PlayerClass()
  local _, classFile = C.Call(UnitClass, "player")
  return type(classFile) == "string" and classFile or nil
end

function G.PlayerLevel()
  local l = C.Call(UnitLevel, "player")
  return type(l) == "number" and l > 0 and l or nil
end

function G.Class(classFile) local d = D(); return d and d.classes and d.classes[classFile or ""] end

function G.ClassList()
  local d, out = D(), {}
  for cf, c in pairs(d and d.classes or {}) do out[#out + 1] = { key = cf, n = c.n } end
  table.sort(out, function(a, b) return a.n < b.n end)
  return out
end

-- Does this character know the spell? true / false, or nil when the game won't say.
-- Unverified on the live client until launch (Nov 4): several APIs are tried.
function G.IsKnown(spellID)
  if not spellID then return nil end
  local answered = false
  local SB = _G.C_SpellBook
  local tries = { SB and SB.IsSpellKnown or false, _G.IsPlayerSpell or false, _G.IsSpellKnown or false }
  for k = 1, #tries do
    local fn = tries[k]
    if type(fn) == "function" then
      local v = C.Call(fn, spellID)
      if v == true then return true end
      if v == false then answered = true end
    end
  end
  local seen = ns.char and ns.char.trained
  if seen and seen[spellID] then return true end
  if answered then return false end
  return nil
end

local function rankKey(name, rank) return name .. "|" .. (rank and rank > 0 and rank or 0) end
G.RankKey = rankKey

-- Trainer cost the addon noted at a class trainer (copper), or nil.
function G.Cost(classFile, name, rank)
  local t = ns.db and ns.db.trainerCosts and ns.db.trainerCosts[classFile or ""]
  return t and t[rankKey(name, rank)]
end

local function sideOK(ab, side)
  return not ab.s or not side or ab.s == side
end

-- Flat list of ranks: { ab, name, rank, spell, level, quest, pet }
-- opts: class, minLevel, maxLevel, pet (true = pet skills only, false/nil = none), search, side
function G.Ranks(opts)
  opts = opts or {}
  local c = G.Class(opts.class or G.PlayerClass())
  local out = {}
  if not c then return out end
  local needle = lower(opts.search)
  local side = opts.side
  for _, ab in ipairs(c.a) do
    if (ab.pet == 1) == (opts.pet == true) and sideOK(ab, side) and has(ab.n, needle) then
      for _, r in ipairs(ab.r) do
        local lv = r[3]
        if (not opts.minLevel or lv >= opts.minLevel) and (not opts.maxLevel or lv <= opts.maxLevel) then
          out[#out + 1] = { ab = ab, name = ab.n, rank = r[2], spell = r[1], level = lv, quest = ab.q == 1, pet = ab.pet == 1 }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if a.name ~= b.name then return a.name < b.name end
    return a.rank < b.rank
  end)
  return out
end

function G.RankText(e)
  return e.name .. (e.rank and e.rank > 0 and (" (Rank " .. e.rank .. ")") or "")
end

-- What this character can train now: ranks at or below its level that it doesn't
-- know (when the game says), plus the next level that has something new.
-- Returns { now = {...}, unsure = n, next = level, nextList = {...} }
function G.TrainingPlan(classFile, level, side)
  classFile = classFile or G.PlayerClass()
  level = level or G.PlayerLevel() or 1
  side = side or ns.FDB.PlayerSide()
  local plan = { now = {}, known = 0, unsure = 0, nextList = {} }
  for _, e in ipairs(G.Ranks({ class = classFile, maxLevel = level, side = side })) do
    local k = G.IsKnown(e.spell)
    e.known = k
    if k == true then plan.known = plan.known + 1
    else
      if k == nil then plan.unsure = plan.unsure + 1 end
      plan.now[#plan.now + 1] = e
    end
  end
  for _, e in ipairs(G.Ranks({ class = classFile, minLevel = level + 1, side = side })) do
    if not plan.next then plan.next = e.level end
    if e.level ~= plan.next then break end
    plan.nextList[#plan.nextList + 1] = e
  end
  return plan
end

-- New ranks that open up at exactly this level.
function G.NewAt(level, classFile)
  return G.Ranks({ class = classFile, minLevel = level, maxLevel = level, side = ns.FDB.PlayerSide() })
end

-- Chat text for the level-up reminder, or nil when nothing new opens up.
function G.ReminderText(level, classFile)
  local list = G.NewAt(level, classFile)
  if #list == 0 then return nil end
  local names, cost, costs = {}, 0, 0
  for _, e in ipairs(list) do
    names[#names + 1] = G.RankText(e) .. (e.quest and " (quest)" or "")
    local c = G.Cost(classFile or G.PlayerClass(), e.name, e.rank)
    if c then cost, costs = cost + c, costs + 1 end
  end
  local text = ("Level %d: new at your class trainer: %s."):format(level, table.concat(names, ", "))
  if costs > 0 then
    text = text .. (" About %s%s."):format(ns.FDB.Money(cost), costs < #list and " for the ones with a known cost" or "")
  end
  return text .. " |cff9a92a8/lomb train for the list.|r"
end

-- Class trainer window: note costs, and which ranks this character already has.
-- (GetTrainerService* are the Classic trainer API; all guarded.)
function G.ReadTrainer()
  if type(_G.GetNumTrainerServices) ~= "function" then return 0 end
  if type(_G.IsTradeskillTrainer) == "function" and C.Call(_G.IsTradeskillTrainer) then return 0 end
  local classFile = G.PlayerClass()
  local c = G.Class(classFile)
  if not c then return 0 end
  local names = {}
  for _, ab in ipairs(c.a) do names[ab.n] = ab end
  ns.db.trainerCosts = ns.db.trainerCosts or {}
  local costs = ns.db.trainerCosts[classFile] or {}
  ns.db.trainerCosts[classFile] = costs
  ns.char.trained = ns.char.trained or {}
  local n = C.Call(_G.GetNumTrainerServices) or 0
  local noted = 0
  for i = 1, math.min(n, 300) do
    local name, sub, category = C.Call(_G.GetTrainerServiceInfo, i)
    local ab = type(name) == "string" and names[name]
    if ab then
      local rank = tonumber(type(sub) == "string" and sub:match("(%d+)") or "") or 0
      local cost = C.Call(_G.GetTrainerServiceCost, i)
      if type(cost) == "number" and cost >= 0 then costs[rankKey(name, rank)] = cost; noted = noted + 1 end
      if category == "used" then
        for _, r in ipairs(ab.r) do if r[2] == rank then ns.char.trained[r[1]] = true end end
      end
    end
  end
  ns:Fire("TRAINER_READ", noted)
  return noted
end

---------------------------------------------------------------------------
-- Gathering
---------------------------------------------------------------------------
function G.Gathering(slug) local d = D(); return d and d.gathering and d.gathering[slug] end

-- The player's skill in a gathering profession: rank, max (nil if they don't have it).
function G.PlayerSkill(slug)
  local name = G.PROF_NAME[slug] or slug
  local profs = (ns.Me and ns.Me.stats and ns.Me.stats.professions)
  if not profs and ns.Me and ns.Me.ReadProfessions then profs = ns.Me.ReadProfessions() end
  local p = profs and profs[name]
  if p then return p.rank, p.max end
end

-- Which gathering profession to open on: the first one this character has.
function G.DefaultProf()
  for i, slug in ipairs(G.PROFS) do if G.PlayerSkill(slug) then return i end end
  return 1
end

-- Can you gather it? "yes" / "no", or nil when the skill isn't known.
function G.CanGather(need, mine)
  if not need or not mine then return nil end
  return mine >= need and "yes" or "no"
end

-- Nodes (herbs, ore) up to a skill, lowest first. opts: search, maxSkill, minSkill
function G.Nodes(slug, opts)
  opts = opts or {}
  local g, out = G.Gathering(slug), {}
  if not g or not g.nodes then return out end
  local needle = lower(opts.search)
  for i, n in ipairs(g.nodes) do
    local ok = (not opts.maxSkill or n.sk <= opts.maxSkill) and (not opts.minSkill or n.sk >= opts.minSkill)
    if ok and needle ~= "" then
      ok = has(n.n, needle) or (n.it and has(ns.FDB.ItemName(n.it), needle))
      if not ok then for _, z in ipairs(n.tz or {}) do if has(z[1], needle) then ok = true; break end end end
    end
    if ok then out[#out + 1] = { i = i, n = n } end
  end
  return out
end

function G.Node(slug, i) local g = G.Gathering(slug); return g and g.nodes and g.nodes[i] end

-- Zones for skinning or fishing, by skill. opts: search, maxSkill, minSkill
function G.GatherZones(slug, opts)
  opts = opts or {}
  local g, out = G.Gathering(slug), {}
  if not g or not g.zones then return out end
  local needle = lower(opts.search)
  for name, z in pairs(g.zones) do
    local lo = slug == "skinning" and (z.sk and z.sk[1]) or z.sk or 0
    local ok = (not opts.maxSkill or (lo or 0) <= opts.maxSkill) and (not opts.minSkill or (lo or 0) >= opts.minSkill)
    if ok and needle ~= "" then
      ok = has(name, needle)
      if not ok and slug == "skinning" then
        for _, b in ipairs(z.b or {}) do if has(b.n, needle) then ok = true; break end end
      elseif not ok then
        for _, l in ipairs(z.l or {}) do if has(ns.FDB.ItemName(l[1]), needle) then ok = true; break end end
      end
    end
    if ok then out[#out + 1] = { name = name, z = z, skill = lo or 0 } end
  end
  table.sort(out, function(a, b)
    if a.skill ~= b.skill then return a.skill < b.skill end
    return a.name < b.name
  end)
  return out
end

-- Best places to level a gathering skill at the given skill (or all bands).
function G.BestZones(slug, skill)
  local g = G.Gathering(slug)
  local out = {}
  for _, b in ipairs(g and g.best or {}) do
    if not skill or (skill >= (b[1] or 0) and skill < (b[2] or 999)) then out[#out + 1] = b end
  end
  return out
end

local gidx
local function gatherIndex()
  if gidx then return gidx end
  gidx = { beast = {}, zone = {}, item = {} }
  local d = D()
  for zname, z in pairs(d and d.gathering and d.gathering.skinning and d.gathering.skinning.zones or {}) do
    for _, b in ipairs(z.b or {}) do
      if b.id and not gidx.beast[b.id] then gidx.beast[b.id] = { b = b, zone = zname } end
    end
  end
  for _, slug in ipairs({ "herbalism", "mining" }) do
    for i, n in ipairs(G.Gathering(slug) and G.Gathering(slug).nodes or {}) do
      if n.it then gidx.item[n.it] = gidx.item[n.it] or { slug = slug, i = i } end
      for _, a in ipairs(n.also or {}) do gidx.item[a] = gidx.item[a] or { slug = slug, i = i } end
    end
  end
  return gidx
end
G.ResetIndex = function() gidx = nil end

-- Skinning facts for a creature (bestiary): { skill, items, zone, seen }
function G.SkinningFor(npcId)
  local e = npcId and gatherIndex().beast[npcId]
  if not e then return nil end
  return { skill = e.b.sk, items = e.b.g, zone = e.zone, seen = e.b.fv == 1, skinned = e.b.sf, beast = e.b }
end

-- The herb/ore node an item comes from: slug, node index, node
function G.NodeForItem(itemID)
  local e = itemID and gatherIndex().item[itemID]
  if e then return e.slug, e.i, G.Node(e.slug, e.i) end
end

-- Everything gatherable in a zone: { herbs = {{name, skill, spawns}}, ore = {...}, skinning = zone, fishing = zone }
function G.GatherInZone(zone)
  local out = {}
  local h, m = G.Gathering("herbalism"), G.Gathering("mining")
  out.herbs = h and h.zones and h.zones[zone] and h.zones[zone].nd or nil
  out.ore = m and m.zones and m.zones[zone] and m.zones[zone].nd or nil
  local s, f = G.Gathering("skinning"), G.Gathering("fishing")
  out.skinning = s and s.zones and s.zones[zone] or nil
  out.fishing = f and f.zones and f.zones[zone] or nil
  return out
end

---------------------------------------------------------------------------
-- Disenchanting (all Classic data)
---------------------------------------------------------------------------
-- Item level, quality and kind (1 weapon, 2 armour): bundle first, then the game.
function G.ItemMeta(itemID)
  local d = D()
  local e = d and d.items and d.items[itemID]
  if e and e[5] then return e[5], e[2], e[6] end
  local ilvl, quality, kind
  local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
  if getInfo then
    local _, _, q, lvl, _, _, _, _, equip, _, _, classID = C.Call(getInfo, itemID)
    quality, ilvl = q, lvl
    if classID == 2 then kind = 1 elseif classID == 4 then kind = 2 end
    if kind == 2 and (equip == "INVTYPE_BODY" or equip == "INVTYPE_TABARD") then kind = nil end
    if kind and (equip == nil or equip == "") then kind = nil end
  end
  quality = quality or (e and e[2])
  return ilvl, quality, kind
end

-- The disenchant row for an item, or nil + reason ("quality", "kind", "level", "unknown").
function G.Disenchant(itemID)
  local d = D()
  if not (d and d.disenchant) then return nil, "unknown" end
  local ilvl, quality, kind = G.ItemMeta(itemID)
  if not quality or not ilvl then return nil, "unknown" end
  if quality < 2 or quality > 4 then return nil, "quality" end
  if not kind then return nil, "kind" end
  for _, r in ipairs(d.disenchant) do
    if r.q == quality and r.k == kind and ilvl >= (r.lo or 0) and ilvl <= (r.hi or 999) then return r, ilvl end
  end
  return nil, "level"
end

function G.DisenchantText(r)
  local out = {}
  for _, x in ipairs(r.r or {}) do
    local amount = (x[3] and x[4] and x[3] ~= x[4]) and (x[3] .. "-" .. x[4] .. "x ") or ((x[3] or 1) > 1 and (x[3] .. "x ") or "")
    out[#out + 1] = ("%s%s (%s%%)"):format(amount, ns.FDB.ItemName(x[1]), tostring(x[2] or "?"))
  end
  return table.concat(out, ", ")
end

-- Which gear disenchants into a material: { {q, k, lo, hi, chance} }
function G.DisenchantSources(materialID)
  local d, out = D(), {}
  for _, r in ipairs(d and d.disenchant or {}) do
    for _, x in ipairs(r.r or {}) do
      if x[1] == materialID then out[#out + 1] = { q = r.q, k = r.k, lo = r.lo, hi = r.hi, chance = x[2] } end
    end
  end
  return out
end

-- Guild enchanters: { name, rank (or nil), online, me }. Online first, then highest skill.
function G.Enchanters()
  local by = {}
  local function add(name, rank)
    if not name then return end
    local e = by[name] or { name = name }
    if rank and (not e.rank or rank > e.rank) then e.rank = rank end
    by[name] = e
  end
  local me = ns.playerKey
  local mine = ns.Me and ns.Me.stats and ns.Me.stats.professions and ns.Me.stats.professions.Enchanting
  if mine and me then add(me, mine.rank) end
  local g = ns.DB and ns.DB.Guild and ns.DB.Guild()
  for name, peer in pairs(g and g.peers or {}) do
    local pr = peer.profile and peer.profile.pr
    local en = type(pr) == "table" and pr.En
    if en then add(name, type(en) == "table" and tonumber(en[1]) or tonumber(en)) end
  end
  if ns.Shared and ns.Shared.Each then
    for owner, data in ns.Shared.Each("rc") do
      if type(data) == "table" and data.En then add(owner, nil) end
    end
  end
  local out = {}
  local online = ns.Crafting and ns.Crafting.IsOnline
  for name, e in pairs(by) do
    e.me = name == me
    e.online = online and online(name) or e.me
    out[#out + 1] = e
  end
  table.sort(out, function(a, b)
    if a.online ~= b.online then return a.online end
    if (a.rank or -1) ~= (b.rank or -1) then return (a.rank or -1) > (b.rank or -1) end
    return a.name < b.name
  end)
  return out
end

function G.EnchantersText(list, max)
  list = list or G.Enchanters()
  local names = {}
  for i, e in ipairs(list) do
    if i > (max or 4) then names[#names + 1] = ("+%d more"):format(#list - (max or 4)); break end
    local n = C.ShortName(e.name) or e.name
    if e.online then n = "|cff7fd18b" .. n .. "|r" end
    if e.rank then n = n .. " " .. e.rank end
    names[#names + 1] = n
  end
  return table.concat(names, ", ")
end

-- Tooltip line (off with the "Disenchant info on item tooltips" setting).
function G.TooltipLine(itemID)
  if S().deTooltips == false or not itemID then return nil end
  local r = G.Disenchant(itemID)
  if not r then return nil end
  local line = "Disenchants into " .. G.DisenchantText(r) .. "  |cff9a92a8" .. ns.FDB.CLASSIC_NOTE .. "|r"
  local en = G.Enchanters()
  if #en > 0 then line = line .. "\nGuild enchanters: " .. G.EnchantersText(en, 3) end
  return line
end

---------------------------------------------------------------------------
-- Gear sets
---------------------------------------------------------------------------
function G.Set(id) local d = D(); return d and d.itemsets and d.itemsets[id] end

function G.SetList(search)
  local d, out = D(), {}
  local needle = lower(search)
  for id, s in pairs(d and d.itemsets or {}) do
    local ok = has(s.n, needle)
    if not ok then for _, iid in ipairs(s.i) do if has(ns.FDB.ItemName(iid), needle) then ok = true; break end end end
    if ok then out[#out + 1] = { id = id, s = s } end
  end
  table.sort(out, function(a, b)
    local la, lb = G.SetLevel(a.s), G.SetLevel(b.s)
    if la ~= lb then return la < lb end
    return a.s.n < b.s.n
  end)
  return out
end

-- Lowest required level among a set's pieces.
function G.SetLevel(s)
  local d, lo = D(), nil
  for _, iid in ipairs(s.i) do
    local e = d.items[iid]
    local r = e and e[3]
    if r and r > 0 and (not lo or r < lo) then lo = r end
  end
  return lo or 0
end

function G.SetForItem(itemID)
  local d = D()
  for id, s in pairs(d and d.itemsets or {}) do
    for _, iid in ipairs(s.i) do if iid == itemID then return id, s end end
  end
end

local function equippedSet()
  local out = {}
  for slot = 1, G.SET_SLOTS do
    local id = C.ItemIdFromLink(C.Call(GetInventoryItemLink, "player", slot))
    if id then out[id] = true end
  end
  return out
end

-- Where this character has a piece: "equipped", "bags", "bank", or nil.
-- Bank only counts once the bank window was opened on this character.
function G.Owned(itemID, cache)
  cache = cache or {}
  cache.eq = cache.eq or equippedSet()
  if cache.eq[itemID] then return "equipped" end
  if not cache.bags and ns.Bank and ns.Bank.Count and ns.Bank.BagList then
    cache.bags = ns.Bank.Count(ns.Bank.BagList()) or {}
  end
  if cache.bags and (cache.bags[itemID] or 0) > 0 then return "bags" end
  local seen = ns.char and ns.char.setBank
  if seen and seen.i and seen.i[itemID] then return "bank", seen.t end
  return nil
end

-- { have = n, equipped = n, total = n, pieces = { {id, where, at} } }
function G.SetProgress(s)
  local cache, out = {}, { have = 0, equipped = 0, total = #s.i, pieces = {} }
  for _, iid in ipairs(s.i) do
    local where, at = G.Owned(iid, cache)
    if where then out.have = out.have + 1 end
    if where == "equipped" then out.equipped = out.equipped + 1 end
    out.pieces[#out.pieces + 1] = { id = iid, where = where, at = at }
  end
  return out
end

-- Set pieces in the bank, noted whenever this character opens its bank.
function G.ScanBank()
  if not (ns.Bank and ns.Bank.Count and ns.Bank.VaultList) then return end
  local counts = ns.Bank.Count(ns.Bank.VaultList()) or {}
  local d = D()
  local i = {}
  for _, s in pairs(d and d.itemsets or {}) do
    for _, iid in ipairs(s.i) do if (counts[iid] or 0) > 0 then i[iid] = true end end
  end
  ns.char.setBank = { i = i, t = time() }
end

-- Creatures the guild's bestiary saw drop an item: { {npcId, name, rate} }
function G.GuildDrops(itemID)
  local out = {}
  for npcId, m in pairs(ns.db and ns.db.bestiary or {}) do
    local drops, corpses = 0, 0
    for _, r in pairs(m.rec or {}) do
      corpses = corpses + (r.c or 0)
      drops = drops + ((r.i and r.i[itemID]) or 0)
    end
    if drops > 0 then
      out[#out + 1] = { npcId = npcId, name = m.nm or ("NPC " .. npcId), rate = corpses > 0 and math.min(1, drops / corpses) or nil }
    end
  end
  table.sort(out, function(a, b) return (a.rate or 0) > (b.rate or 0) end)
  return out
end

-- Where a piece comes from, as far as the bundle and the guild know.
-- { soldBy, madeBy, dungeons, drops } (any can be empty). Quest rewards aren't in the bundle.
function G.Sources(itemID)
  local f = ns.FDB.ItemFacts(itemID)
  return { soldBy = f.soldBy, madeBy = f.madeBy, dungeons = f.dungeons, drops = G.GuildDrops(itemID) }
end

---------------------------------------------------------------------------
-- Rogue poisons, battlegrounds, zones
---------------------------------------------------------------------------
function G.Poisons() local d = D(); return d and d.poisons end

function G.Battleground(id) local d = D(); return d and d.battlegrounds and d.battlegrounds[id] end

function G.BattlegroundList(search)
  local d, out = D(), {}
  local needle = lower(search)
  for id, b in pairs(d and d.battlegrounds or {}) do
    if has(b.n, needle) or has(b.k, needle) then out[#out + 1] = { id = id, b = b } end
  end
  table.sort(out, function(a, b)
    if (a.b.lo or 99) ~= (b.b.lo or 99) then return (a.b.lo or 99) < (b.b.lo or 99) end
    return a.b.n < b.b.n
  end)
  return out
end

function G.BattlegroundLevels(b)
  if b.lo and b.hi then return b.lo .. "-" .. b.hi end
  if b.lo then return b.lo .. "+" end
  return "?"
end

function G.Zone(id) local d = D(); return d and d.zones and d.zones[id] end

function G.ZoneByName(name)
  local needle = lower(name)
  for id, z in pairs(D() and D().zones or {}) do if lower(z.n) == needle then return id, z end end
end

local zstats = {}
-- Derived facts about a zone, from the quests, vendors and gathering data (cached).
-- { quests, lo, hi, mid, side, storylines = {{id, name, n}}, vendors = {ids} }
function G.ZoneStats(name)
  if zstats[name] then return zstats[name] end
  local d = D()
  local st = { quests = 0, levels = {}, sides = { A = 0, H = 0, B = 0 }, vendors = {}, storylines = {} }
  local stories = {}
  for qid, q in pairs(d and d.quests or {}) do
    if q.z == name then
      st.quests = st.quests + 1
      if q.l and q.l > 0 then st.levels[#st.levels + 1] = q.l end
      st.sides[q.s or "B"] = (st.sides[q.s or "B"] or 0) + 1
      local s = ns.FDB.Storyline and ns.FDB.Storyline(qid)
      if s and s.size and s.size > 1 then
        local e = stories[s.id] or { id = s.id, name = s.name, n = 0, first = qid }
        e.n = e.n + 1
        stories[s.id] = e
      end
    end
  end
  table.sort(st.levels)
  local n = #st.levels
  if n > 0 then
    -- the middle 80% of quest levels, so a stray low/high quest doesn't stretch the range
    st.lo = st.levels[math.max(1, math.floor(n * 0.1) + 1)]
    st.hi = st.levels[math.max(1, math.ceil(n * 0.9))]
    st.mid = st.levels[math.floor((n + 1) / 2)]
  end
  local a, h = st.sides.A, st.sides.H
  if ns.FDB.ZONE_SIDE[name] then st.side = ns.FDB.ZONE_SIDE[name]
  elseif a > 2 * h and a >= 3 then st.side = "A"
  elseif h > 2 * a and h >= 3 then st.side = "H"
  else st.side = "B" end
  for vid, v in pairs(d and d.vendors or {}) do
    if v.z == name then st.vendors[#st.vendors + 1] = vid end
  end
  table.sort(st.vendors, function(x, y) return d.vendors[x].n < d.vendors[y].n end)
  for _, e in pairs(stories) do st.storylines[#st.storylines + 1] = e end
  table.sort(st.storylines, function(x, y) if x.n ~= y.n then return x.n > y.n end return x.name < y.name end)
  st.levels = nil
  zstats[name] = st
  return st
end

function G.ZoneLevelText(st)
  if not st or not st.lo then return nil end
  return st.lo == st.hi and tostring(st.lo) or (st.lo .. "-" .. st.hi)
end

-- Zones (not battlegrounds), sorted by name. opts: search, side ("A"/"H"), minLevel, maxLevel
function G.ZoneList(opts)
  opts = opts or {}
  local d, out = D(), {}
  local needle = lower(opts.search)
  for id, z in pairs(d and d.zones or {}) do
    if not z.bg and has(z.n, needle) then
      local st = G.ZoneStats(z.n)
      local ok = not opts.side or st.side == "B" or st.side == opts.side
      if ok and (opts.minLevel or opts.maxLevel) then
        ok = st.lo ~= nil and (not opts.maxLevel or st.lo <= opts.maxLevel) and (not opts.minLevel or st.hi >= opts.minLevel)
      end
      if ok then out[#out + 1] = { id = id, z = z, st = st } end
    end
  end
  table.sort(out, function(a, b)
    local la, lb = a.st.lo or 99, b.st.lo or 99
    if la ~= lb then return la < lb end
    return a.z.n < b.z.n
  end)
  return out
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns:On("PLAYER_LEVEL_UP", function(_, level)
  if S().trainerReminder == false then return end
  level = tonumber(level)
  if not level or not G.Available() then return end
  ns.After(1.5, function()
    local text = G.ReminderText(level)
    if text then ns.Print(text) end   -- your own chat frame only
  end)
end)

local readSoon = ns.Debounce(0.3, function() ns.SafeCall(G.ReadTrainer) end)
ns:On("TRAINER_SHOW", function() readSoon() end)
ns:On("TRAINER_UPDATE", function() readSoon() end)
ns:On("BANKFRAME_OPENED", function() ns.After(0.5, function() ns.SafeCall(G.ScanBank) end) end)

function G:Login()
  if ns.Tooltip and G.Available() then ns.Tooltip.AddLine(G.TooltipLine) end
end

return G
