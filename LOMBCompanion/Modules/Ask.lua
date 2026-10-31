-- LOMB Companion: Ask LOMB -- a question box that answers from the bundled
-- ForeverDB.net snapshot and what the guild has shared. It works offline and is
-- not an AI: AskParse reads the words (synonyms, typos, "my level", "here"),
-- each kind of answer gets a score from its keywords plus how well a name in
-- the bundle fits, and the winner is built from the same lookups the other
-- views use. Close-but-not-exact names get "Did you mean" chips.
-- Nothing is ever sent anywhere; /lomb ask only prints to your own chat frame.
--
-- An answer is { q = question, lines = { line... }, data = bool (uses ForeverDB data) }.
-- A line is { text = "...", style = nil|"muted"|"warn"|"head", link = { mode, key }
-- (opens Quests & Items), tab = "events" (opens a tab), ask = "question" (asks it) }.
local _, ns = ...
local Ask = ns:NewModule("Ask")

local MUTED, WARN, GOOD = "|cff9a92a8", "|cffe0b060", "|cff7fd18b"

Ask.EXAMPLES = {
  "Where do I turn in The Defias Brotherhood?",
  "Who sells Fine Thread?",
  "How do I make Heavy Linen Bandage?",
  "What does Battleforge Boots disenchant into?",
  "What drops Linen Cloth?",
  "Who can craft Copper Chain Belt?",
  "What should I train?",
  "Where can I find Briarthorn?",
  "Which set is Blackened Defias Armor in?",
  "Deadmines level and bosses",
  "What drops in Deadmines?",
  "Quests near my level",
  "Quests in my zone",
  "What comes after Red Leather Bandanas?",
  "When is the next guild event?",
}

local function FDB() return ns.FDB end
local function G() return ns.Guides end
local function D() return ns.FDBData end

---------------------------------------------------------------------------
-- Text helpers
---------------------------------------------------------------------------
-- lower case, no apostrophes, other punctuation as spaces, single spaces
local function norm(s)
  s = tostring(s or ""):lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("['\226\128\153`]", ""):gsub("[^%w]+", " ")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
Ask.Norm = norm

local playerLevel = ns.Compat.PlayerLevel
local playerZone = ns.Compat.PlayerZone
local P = ns.AskParse

---------------------------------------------------------------------------
-- Name indexes (built the first time a question needs them)
---------------------------------------------------------------------------
local names = {}

-- short names people use for dungeons
Ask.DUNGEON_ALIAS = {
  dm = "Deadmines", vc = "Deadmines", rfc = "Ragefire Chasm", wc = "Wailing Caverns", sfk = "Shadowfang Keep",
  stocks = "Stormwind Stockade", stockade = "Stormwind Stockade", stockades = "Stormwind Stockade",
  ony = "Onyxia's Lair", onyxia = "Onyxia's Lair", bfd = "Blackfathom Deeps", gnomer = "Gnomeregan",
  rfk = "Razorfen Kraul", sm = "Scarlet Monastery", mistmantle = "Manor Mistmantle",
}

Ask.ZONE_ALIAS = {
  wsg = "Warsong Gulch", ab = "Arathi Basin", av = "Alterac Valley", stv = "Stranglethorn Vale",
  sw = "Stormwind City", ironforge = "Ironforge", org = "Orgrimmar", tb = "Thunder Bluff", uc = "Undercity",
  hinterlands = "The Hinterlands", barrens = "The Barrens", redridge = "Redridge Mountains",
}

local function build(kind)
  local d = D()
  local list = {}
  local function put(name, id) if name and name ~= "" then list[#list + 1] = { key = P.Key(name), id = id, name = name } end end
  if not d then return list end
  if kind == "quest" then for id, q in pairs(d.quests or {}) do put(q.n, id) end
  elseif kind == "item" then for id, e in pairs(d.items or {}) do put(e[1], id) end
  elseif kind == "vendor" then for id, v in pairs(d.vendors or {}) do put(v.n, id) end
  elseif kind == "dungeon" then
    for id, dg in pairs(d.dungeons or {}) do
      put(dg.n, id)
      for alias, target in pairs(Ask.DUNGEON_ALIAS) do
        if target == dg.n then list[#list + 1] = { key = P.Key(alias), id = id, name = dg.n } end
      end
    end
  elseif kind == "boss" then
    for did, dg in pairs(d.dungeons or {}) do
      for i, b in ipairs(dg.b or {}) do put(b, { did, i }) end
    end
  elseif kind == "zone" then
    for id, z in pairs(d.zones or {}) do
      put(z.n, id)
      for alias, target in pairs(Ask.ZONE_ALIAS) do
        if target == z.n then list[#list + 1] = { key = P.Key(alias), id = id, name = z.n } end
      end
    end
  elseif kind == "set" then for id, s in pairs(d.itemsets or {}) do put(s.n, id) end
  elseif kind == "node" then
    for _, slug in ipairs({ "herbalism", "mining" }) do
      local g = G().Gathering(slug)
      for i, n in ipairs(g and g.nodes or {}) do
        local id = { slug, i, n }
        put(n.n, id)
        if n.it then put(FDB().ItemName(n.it), id) end
      end
    end
  elseif kind == "npc" then
    local seen = {}
    for _, q in pairs(d.quests or {}) do
      for _, e in ipairs({ q.st, q.en }) do
        if e and e[1] == "n" and e[2] and not seen[e[2]] then
          seen[e[2]] = true
          put(e[3], { id = e[2], name = e[3], zone = e[4], x = e[5], y = e[6], classic = e[7] == 1 })
        end
      end
    end
  elseif kind == "mob" then
    for npcId, m in pairs(ns.db and ns.db.bestiary or {}) do put(m.nm, npcId) end
  end
  return list
end

local function index(kind)
  if kind == "mob" then return build(kind) end   -- guild data changes as you play
  if not names[kind] then names[kind] = build(kind) end
  return names[kind]
end

function Ask.ResetIndex() names = {} end
function Ask.IndexBuilt(kind) return names[kind] ~= nil end

local MIN = 45   -- below this a name doesn't really match

-- Find things of one kind by name, forgivingly (see AskParse.Match). Returns a
-- list of { id, name, score, kind }, best first. `prefer(id)` breaks ties.
local function find(kind, text, prefer, limit)
  local q = P.Key(text)
  if q.c == "" then return {} end
  local out, seen = {}, {}
  for _, e in ipairs(index(kind)) do
    local s = P.Match(e.key, q)
    if s >= MIN then
      local k = e.name .. "\0" .. tostring(type(e.id) == "table" and (e.id.id or e.id[2]) or e.id)
      local old = seen[k]
      if not old or old.score < s then
        local r = { id = e.id, name = e.name, score = s, len = #e.name, kind = kind, pref = prefer and prefer(e.id) or 0 }
        if old then for f, v in pairs(r) do old[f] = v end else seen[k] = r; out[#out + 1] = r end
      end
    end
  end
  -- scores a few points apart count as a tie, so the better-known thing wins
  table.sort(out, function(a, b)
    local ba, bb = math.floor(a.score / 4), math.floor(b.score / 4)
    if ba ~= bb then return ba > bb end
    if a.pref ~= b.pref then return a.pref > b.pref end
    if a.score ~= b.score then return a.score > b.score end
    if a.len ~= b.len then return a.len < b.len end
    if type(a.id) == "number" and type(b.id) == "number" then return a.id < b.id end
    return a.name < b.name
  end)
  if limit and #out > limit then for k = #out, limit + 1, -1 do out[k] = nil end end
  return out
end
Ask.Find = find

-- Names sharing words with the text, for "best guess" when nothing matches well.
local function loose(kind, text, prefer, limit)
  local q = P.Key(text)
  local out = {}
  for _, e in ipairs(index(kind)) do
    local h = P.Overlap(e.key, q)
    if h > 0 then out[#out + 1] = { id = e.id, name = e.name, hits = h, kind = kind, pref = prefer and prefer(e.id) or 0, len = #e.name } end
  end
  table.sort(out, function(a, b)
    if a.hits ~= b.hits then return a.hits > b.hits end
    if a.pref ~= b.pref then return a.pref > b.pref end
    if a.len ~= b.len then return a.len < b.len end
    return a.name < b.name
  end)
  if #out > limit then for k = #out, limit + 1, -1 do out[k] = nil end end
  return out
end

-- quests: your side first, then nearest your level
local function questPref(id)
  local q = FDB().Quest(id)
  if not q then return 0 end
  local side = FDB().PlayerSide()
  local p = FDB().SideOK(q, side) and 100 or 0
  local lv = playerLevel()
  if lv and q.l and q.l > 0 then p = p - math.abs(q.l - lv) end
  return p
end

-- items: the bundle knows something about it (sold, made, dungeon...) and better quality
local function itemPref(id)
  local e = D() and D().items[id]
  local p = (e and e[2] or 1)
  if FDB().Known(id) then p = p + 10 end
  return p + math.min(#FDB().ItemFacts(id).reagentFor, 20)   -- "linen" is the cloth everyone uses
end

local function linkedID(raw, what)
  local id = tostring(raw or ""):match("|H" .. what .. ":(%d+)")
  return id and tonumber(id)
end

---------------------------------------------------------------------------
-- Answer building
---------------------------------------------------------------------------
local A = {}
A.__index = A

Ask.AnswerMeta = A   -- answer methods, shared with saved history (AskHistory.lua)
local function newAnswer(q) return setmetatable({ q = q, lines = {}, data = false }, A) end

function A:say(text, style) self.lines[#self.lines + 1] = { text = text, style = style }; return self end
function A:link(text, mode, key) self.lines[#self.lines + 1] = { text = text, link = { mode, key } }; return self end
function A:tab(text, id) self.lines[#self.lines + 1] = { text = text, tab = id }; return self end
function A:ask(text, q) self.lines[#self.lines + 1] = { text = text, ask = q or text }; return self end
function A:muted(text) return self:say(text, "muted") end
function A:warn(text) return self:say(text, "warn") end
function A:fdb() self.data = true; return self end

local function where(e)
  if not e then return "not known yet" end
  local kind, id, name = e[1], e[2], e[3]
  local loc = FDB().LocText(e[4], e[5], e[6])
  local classic = e[7] == 1 and (" " .. WARN .. FDB().CLASSIC_NOTE .. "|r") or ""
  if kind == "i" and id and id > 0 then return "from the item " .. FDB().ItemText(id) .. classic end
  local text = name or "?"
  if kind == "o" then text = text .. " (an object)" end
  if loc then text = text .. ", " .. loc end
  return text .. classic
end

local function questTitle(_, q)
  local bits = { "level " .. FDB().LevelText(q) }
  if q.z then bits[#bits + 1] = q.z end
  if q.s == "A" or q.s == "H" then bits[#bits + 1] = FDB().SideText(q.s) end
  return ("%s  %s(%s)|r"):format(q.n, MUTED, table.concat(bits, ", "))
end

local function status(id)
  local s = ns.QuestTrack and ns.QuestTrack.Status and ns.QuestTrack.Status(id)
  if s == "done" then return GOOD .. "  done|r" elseif s == "ready" then return "|cffffd36b  turn in|r"
  elseif s == "log" then return "|cff8fc8ff  in log|r" end
  return ""
end

---------------------------------------------------------------------------
-- Answers about one thing
---------------------------------------------------------------------------
local function questAnswer(a, id, focus)
  local q = FDB().Quest(id)
  if not q then return false end
  a:fdb()
  a:link(questTitle(id, q) .. status(id), "quests", id)
  if focus ~= "end" then a:say("Starts: " .. where(q.st)) end
  if focus ~= "start" then a:say("Turn in: " .. where(q.en)) end
  local chain = FDB().ChainText(id)
  if chain then a:muted("Part of a storyline: " .. chain .. ".") end
  return true
end

local function nextAnswer(a, id)
  local q = FDB().Quest(id)
  if not q then return false end
  a:fdb()
  a:link(questTitle(id, q) .. status(id), "quests", id)
  local nx = FDB().NextQuests(id)
  local chain = FDB().ChainText(id)
  if #nx == 0 then
    local c = FDB().Chain(id)
    if c and c.more then a:say("The next part is above level 30, which isn't in the bundled data.")
    elseif chain then a:say("That's the last part of its storyline (" .. chain .. ").")
    else a:say("Nothing follows it in ForeverDB.net's data. It isn't part of a chain.") end
    return true
  end
  a:say(#nx == 1 and "Next up:" or "It leads to:")
  for k = 1, math.min(#nx, 5) do
    local n = FDB().Quest(nx[k])
    if n then a:link("  " .. questTitle(nx[k], n) .. status(nx[k]), "quests", nx[k]) end
  end
  if chain then a:muted("Storyline: " .. chain .. " for " .. q.n .. ".") end
  return true
end

local function vendorSort(list)
  local side, here = FDB().PlayerSide(), playerZone()
  local function score(s)
    local v = FDB().Vendor(s.vendor)
    local p = 0
    if v then
      local vs = FDB().NpcSide(v)
      if side and (vs == side or vs == "B") then p = p + 2 end
      if here and v.z == here then p = p + 1 end
    end
    return p
  end
  table.sort(list, function(x, y)
    local sx, sy = score(x), score(y)
    if sx ~= sy then return sx > sy end
    if (x.price or 0) ~= (y.price or 0) then return (x.price or 0) < (y.price or 0) end
    return x.vendor < y.vendor
  end)
end

local function sellsAnswer(a, id)
  a:fdb()
  local f = FDB().ItemFacts(id)
  local list = {}
  for i, s in ipairs(f.soldBy) do list[i] = s end
  if #list == 0 then
    a:link(FDB().ItemText(id), "items", id)
    a:say("No vendor in WoW: Forever has been seen selling it.")
    if #f.madeBy > 0 then a:ask("How do I make it?", "How do I make " .. FDB().ItemName(id) .. "?") end
    a:ask("What drops it?", "What drops " .. FDB().ItemName(id) .. "?")
    return true
  end
  vendorSort(list)
  a:link(FDB().ItemText(id) .. MUTED .. ("  sold by %d vendor%s|r"):format(#list, #list == 1 and "" or "s"), "items", id)
  for k = 1, math.min(#list, 5) do
    local s = list[k]
    local v = FDB().Vendor(s.vendor)
    if v then
      local price = FDB().Money(s.price) .. ((s.stack or 1) > 1 and (" for " .. s.stack) or "")
      local loc = FDB().LocText(v.z, v.x, v.y) or "?"
      a:link(("  %s%s, %s  %s%s|r%s"):format(v.n, v.t and (" <" .. v.t .. ">") or "", loc, MUTED, price,
        s.limited and (WARN .. "  limited stock|r") or ""), "vendors", s.vendor)
    end
  end
  if #list > 5 then a:muted(("  and %d more on the item page."):format(#list - 5)) end
  return true
end

local function profName(slug)
  local p = FDB().Profession(slug)
  return p and p.n or slug
end

local function makeAnswer(a, id, ref)
  ref = ref or (FDB().ItemFacts(id).madeBy or {})[1]
  if not ref then return false end
  local r = FDB().Recipe(ref)
  if not r then return false end
  a:fdb()
  a:link(("%s  %s(%s, skill %s)|r"):format(r.mk and FDB().ItemText(r.mk) or r.n, MUTED, profName(ref.prof),
    tostring(r.sk and r.sk[1] or "?")), "recipes", ref)
  local rg = FDB().ReagentsText(r)
  a:say("You need: " .. (rg ~= "" and rg or "no reagents listed"))
  a:say("Learned from: " .. FDB().WaysText(r))
  if r.ri then a:link("  Recipe: " .. FDB().ItemText(r.ri), "items", r.ri) end
  local cr = ns.Crafting and ns.Crafting.CraftersOfItem and r.mk and ns.Crafting.CraftersOfItem(r.mk) or {}
  if #cr > 0 then a:ask(("%d in the guild can make it. Who?"):format(#cr), "Who can craft " .. FDB().ItemName(r.mk) .. "?") end
  return true
end

local function craftersAnswer(a, id, label)
  local cr = ns.Crafting and ns.Crafting.CraftersOfItem and id and ns.Crafting.CraftersOfItem(id) or {}
  local name = id and FDB().ItemText(id) or label
  if #cr == 0 then
    a:say(("Nobody in the guild has shared a recipe for %s yet."):format(name))
    a:muted("Crafters show up here once they open their profession window with the addon on.")
    if id and #(FDB().ItemFacts(id).madeBy) > 0 then a:ask("How do I make it myself?", "How do I make " .. FDB().ItemName(id) .. "?") end
    return true
  end
  local list = {}
  for k = 1, math.min(#cr, 8) do
    local c = cr[k]
    local short = ns.Compat.ShortName(c) or tostring(c)
    list[#list + 1] = (ns.Crafting.IsOnline and ns.Crafting.IsOnline(c)) and (GOOD .. short .. "|r") or short
  end
  a:say(("Guild crafters for %s: %s%s"):format(name, table.concat(list, ", "), #cr > 8 and (" and " .. (#cr - 8) .. " more") or ""))
  a:muted("Online ones are green.")
  a:tab("Open Crafters", "crafters")
  return true
end

local function deAnswer(a, id)
  local G_ = G()
  a:fdb()
  local r, why = G_.Disenchant(id)
  a:link(FDB().ItemText(id), "items", id)
  if r then
    a:say("Disenchants into: " .. G_.DisenchantText(r))
    a:warn(FDB().CLASSIC_NOTE)
  else
    local src = G_.DisenchantSources(id)
    if #src > 0 then
      local q = { [2] = "green", [3] = "blue", [4] = "purple" }
      local parts = {}
      for k = 1, math.min(#src, 4) do
        local s = src[k]
        parts[#parts + 1] = ("%s %s, item level %d-%d (%s%%)"):format(q[s.q] or "?", s.k == 1 and "weapons" or "armour",
          s.lo or 0, s.hi or 0, tostring(s.chance or "?"))
      end
      a:say("That's an enchanting material. It comes from disenchanting " .. table.concat(parts, "; ") .. ".")
      a:warn(FDB().CLASSIC_NOTE)
    elseif why == "quality" then a:say("It can't be disenchanted: only green, blue and purple gear can.")
    elseif why == "kind" then a:say("It can't be disenchanted: only weapons and armour can.")
    else a:say("I can't tell: the item's level isn't in the bundle and the game hasn't shown it to you yet.") end
  end
  local en = G_.Enchanters()
  if #en > 0 then a:say("Guild enchanters: " .. G_.EnchantersText(en, 4)) end
  return true
end

local function dropsAnswer(a, id)
  a:link(FDB().ItemText(id), "items", id)
  local drops = G().GuildDrops(id)
  if #drops > 0 then
    a:say("The guild has seen it drop from:")
    for k = 1, math.min(#drops, 5) do
      local e = drops[k]
      a:say(("  %s%s"):format(e.name, e.rate and (MUTED .. ("  %d%% of corpses|r"):format(math.floor(e.rate * 100 + 0.5))) or ""))
    end
    a:muted("Guild-recorded loot only, from what guildmates have looted with the addon on.")
  else
    a:say("The guild hasn't recorded it dropping yet.")
    a:muted("Mob loot here only comes from what guildmates loot with the addon on; ForeverDB.net's drop tables aren't bundled.")
  end
  local f = FDB().ItemFacts(id)
  local spots = ns.Loot and ns.Loot.WhereDrops(id) or {}
  for k = 1, math.min(#spots, 3) do
    local w = spots[k]
    local dg = FDB().Dungeon(w.did)
    if w.notable then a:fdb() end
    a:link(("  %s %s%s|r"):format(w.notable and "Notable loot in" or "Seen in", dg.n,
      MUTED .. (w.boss and (", from " .. w.boss) or "") .. (w.seen > 0 and (", LOMB saw it drop: " .. w.seen) or "")),
      "dungeons", w.key)
  end
  if #f.soldBy > 0 then a:fdb(); a:ask("A vendor sells it too. Who?", "Who sells " .. FDB().ItemName(id) .. "?") end
  local slug, _, n = G().NodeForItem(id)
  if slug then a:fdb(); a:ask(("It's gathered from %s. Where?"):format(n.n), "Where can I find " .. n.n .. "?") end
  return true
end

local function nodeAnswer(a, slug, i, n)
  a:fdb()
  a:link(("%s  %s(%s, skill %d)|r"):format(n.n, MUTED, G().PROF_NAME[slug] or slug, n.sk or 0), "gathering", { slug, "n:" .. i })
  if n.it then a:say("Gives: " .. FDB().ItemText(n.it)) end
  local tz = {}
  for k, z in ipairs(n.tz or {}) do tz[k] = z end
  table.sort(tz, function(x, y) return (x[2] or 0) > (y[2] or 0) end)
  if #tz > 0 then
    local parts = {}
    for k = 1, math.min(#tz, 5) do parts[#parts + 1] = ("%s (%d)"):format(tz[k][1], tz[k][2] or 0) end
    a:say("Most spawns: " .. table.concat(parts, ", "))
    a:warn("Spawn spots are " .. FDB().CLASSIC_NOTE)
  else
    a:say("ForeverDB.net has no spawn zones for it.")
  end
  local mine = G().PlayerSkill(slug)
  if mine then
    a:muted(mine >= (n.sk or 0) and ("Your skill (%d) is enough."):format(mine) or ("You need %d; you have %d."):format(n.sk or 0, mine))
  end
  return true
end

local function levelGatherAnswer(a, slug)
  local G_ = G()
  local mine = G_.PlayerSkill(slug)
  a:fdb()
  a:link("Where to level " .. (G_.PROF_NAME[slug] or slug), "gathering", { slug, "best" })
  local bands = G_.BestZones(slug, mine)
  if #bands == 0 then bands = G_.BestZones(slug) end
  if #bands == 0 then a:say("ForeverDB.net has no suggestions for that one."); return true end
  for k = 1, math.min(#bands, 4) do
    local b = bands[k]
    local zones = type(b[3]) == "table" and table.concat(b[3], ", ") or tostring(b[3] or "?")
    a:say(("  Skill %s-%s: %s"):format(tostring(b[1] or "?"), tostring(b[2] or "?"), zones))
  end
  a:warn(FDB().CLASSIC_NOTE)
  return true
end

local function setAnswer(a, id, piece)
  local G_ = G()
  local s = G_.Set(id)
  if not s then return false end
  a:fdb()
  local prog = G_.SetProgress(s)
  a:link(("%s  %s(%d/%d pieces, from level %d)|r"):format(s.n, MUTED, prog and prog.have or 0, #s.i, G_.SetLevel(s)), "sets", id)
  if piece then a:say(FDB().ItemText(piece) .. " is one of its pieces.") end
  local parts = {}
  for _, iid in ipairs(s.i) do parts[#parts + 1] = FDB().ItemName(iid) end
  a:say("Pieces: " .. table.concat(parts, ", "))
  for k = 1, math.min(#(s.b or {}), 2) do a:muted(("  %d pieces: %s"):format(s.b[k][1], s.b[k][2])) end
  a:warn("ForeverDB.net says the current client hides this set: unconfirmed in WoW Forever.")
  return true
end

local function dungeonAnswer(a, id)
  local dg = FDB().Dungeon(id)
  if not dg then return false end
  a:fdb()
  a:link(("%s  %s(level %s, %s players)|r"):format(dg.n, MUTED, FDB().DungeonLevelText(dg), tostring(dg.p or 5)), "dungeons", id)
  if dg.lv then a:say(("Minimum level to enter: %d"):format(dg.lv)) end
  if dg.b and #dg.b > 0 then a:say("Bosses: " .. table.concat(dg.b, ", ")) end
  a:ask("What drops there?", "What drops in " .. dg.n .. "?")
  return true
end

-- "what drops in Deadmines" / "what does Van Cleef drop": the Loot browser, in words
local function lootAnswer(a, did, part)
  local L, dg = ns.Loot, FDB().Dungeon(did)
  if not (L and dg) then return false end
  part = part or "all"
  local res = L.For(did, part)
  local title = part == "all" and ("Loot in " .. dg.n) or (L.PartName(did, part) .. " (" .. dg.n .. ")")
  a:link(title .. "  " .. MUTED .. "(open the loot grid)|r", "dungeons", L.Key(did, part))
  local notable, seen = {}, {}
  for _, e in ipairs(res.items) do
    if e.notable then notable[#notable + 1] = e end
    if e.seen > 0 then seen[#seen + 1] = e end
  end
  if #notable > 0 then
    a:fdb()
    local t = {}
    for _, e in ipairs(notable) do t[#t + 1] = FDB().ItemText(e.itemID) end
    a:say("Notable loot (ForeverDB.net's picks, not a drop table): " .. table.concat(t, ", "))
  elseif part == "all" then
    a:muted("ForeverDB.net lists no notable loot here yet.")
  else
    a:muted("ForeverDB.net doesn't say which boss drops what.")
    a:link("  Notable loot for all of " .. dg.n, "dungeons", did)
  end
  table.sort(seen, function(x, y) return x.seen > y.seen end)
  if #seen > 0 then
    local t = {}
    for k = 1, math.min(#seen, 5) do t[k] = ("%s (%d)"):format(FDB().ItemText(seen[k].itemID), seen[k].seen) end
    a:say("LOMB saw drop: " .. table.concat(t, ", ") .. (#seen > 5 and (" and " .. (#seen - 5) .. " more") or ""))
    a:muted("Guild-recorded: corpses that had it, from guildmates looting with the addon on.")
  else
    a:muted("Nobody in the guild has recorded loot " .. (part == "all" and "here" or "from it") .. " yet.")
  end
  return true
end

local function zoneAnswer(a, id)
  local z = G().Zone(id)
  if not z then return false end
  a:fdb()
  if z.bg then return false end
  local st = G().ZoneStats(z.n)
  a:link(("%s  %s(level %s, %s)|r"):format(z.n, MUTED, G().ZoneLevelText(st) or "?", FDB().SideText(st.side)), "zones", id)
  a:say(("%d quests, %d vendors, %d storylines in the bundle."):format(st.quests, #st.vendors, #st.storylines))
  a:ask("Quests in " .. z.n, "Quests in " .. z.n)
  return true
end

local function bgAnswer(a, id)
  local b = G().Battleground(id)
  if not b then return false end
  a:fdb()
  a:link(("%s  %s(PvP, levels %s)|r"):format(b.n, MUTED, G().BattlegroundLevels(b)), "zones", "bg:" .. id)
  if b.p then a:say(("Teams of %s."):format(tostring(b.p))) end
  a:warn("Rules are Classic's. " .. FDB().CLASSIC_NOTE)
  return true
end

local function vendorAnswer(a, id)
  local v = FDB().Vendor(id)
  if not v then return false end
  a:fdb()
  a:link(("%s%s"):format(v.n, v.t and (" <" .. v.t .. ">") or ""), "vendors", id)
  a:say("Where: " .. (FDB().LocText(v.z, v.x, v.y) or "?") .. ", " .. FDB().SideText(FDB().NpcSide(v)))
  local n = math.floor(#(v.i or {}) / 4)
  a:muted(("Sells %d item%s. Click for the list."):format(n, n == 1 and "" or "s"))
  return true
end

local function npcAnswer(a, e)
  a:fdb()
  local loc = FDB().LocText(e.zone, e.x, e.y)
  a:say(("%s is in %s.%s"):format(e.name or "?", loc or "an unknown place", e.classic and (" " .. WARN .. FDB().CLASSIC_NOTE .. "|r") or ""))
  local starts, ends = FDB().QuestsForNpc(e.id)
  if starts and #starts > 0 then
    local q = FDB().Quest(starts[1])
    a:link(("  Gives %d quest%s, e.g. %s"):format(#starts, #starts == 1 and "" or "s", q and q.n or "?"), "quests", starts[1])
  end
  if ends and #ends > 0 then a:muted(("  Takes turn-ins for %d quest%s."):format(#ends, #ends == 1 and "" or "s")) end
  return true
end

local function itemAnswer(a, id)
  a:fdb()
  a:link(FDB().ItemText(id), "items", id)
  local f = FDB().ItemFacts(id)
  local bits = {}
  if #f.soldBy > 0 then bits[#bits + 1] = ("sold by %d vendor%s"):format(#f.soldBy, #f.soldBy == 1 and "" or "s") end
  if #f.madeBy > 0 then bits[#bits + 1] = "crafted (" .. profName(f.madeBy[1].prof) .. ")" end
  if #f.reagentFor > 0 then bits[#bits + 1] = ("used in %d recipe%s"):format(#f.reagentFor, #f.reagentFor == 1 and "" or "s") end
  if #f.dungeons > 0 then bits[#bits + 1] = "notable dungeon loot" end
  if #f.startsQuest > 0 then bits[#bits + 1] = "starts a quest" end
  a:say(#bits > 0 and ("It's " .. table.concat(bits, ", ") .. ".") or "The bundle doesn't say where it comes from.")
  local nm = FDB().ItemName(id)
  if #f.soldBy > 0 then a:ask("Who sells it?", "Who sells " .. nm .. "?") end
  if #f.madeBy > 0 then a:ask("How do I make it?", "How do I make " .. nm .. "?") end
  a:ask("What drops it?", "What drops " .. nm .. "?")
  return true
end

---------------------------------------------------------------------------
-- Lists
---------------------------------------------------------------------------
local function questListAnswer(a, opts, title)
  a:fdb()
  local all = FDB().QuestList(opts)
  local list, done = {}, 0
  for _, e in ipairs(all) do
    if (ns.QuestTrack and ns.QuestTrack.Status and ns.QuestTrack.Status(e.id)) == "done" then done = done + 1
    else list[#list + 1] = e end
  end
  local here = playerZone()
  if not opts.zone and here then
    -- quests in your zone first
    table.sort(list, function(x, y)
      local hx, hy = x.q.z == here, y.q.z == here
      if hx ~= hy then return hx end
      if x.q.l ~= y.q.l then return x.q.l < y.q.l end
      return x.q.n < y.q.n
    end)
  end
  a:say(("%s: %d quest%s%s."):format(title, #list, #list == 1 and "" or "s", done > 0 and (" (" .. done .. " done not counted)") or ""))
  -- one line per name (chains like "Captain Sander's Hidden Treasure" reuse it)
  local shown, seen = 0, {}
  for _, e in ipairs(list) do
    if shown >= 8 then break end
    local key = e.q.n .. "|" .. tostring(e.q.z)
    if not seen[key] then
      seen[key] = true
      shown = shown + 1
      a:link(("  %s%s"):format(questTitle(e.id, e.q), status(e.id)), "quests", e.id)
    end
  end
  if #list > shown then a:muted(("  and more in Quests & Items (%d in all)."):format(#list)) end
  return true
end

local function trainAnswer(a)
  local G_ = G()
  local cls = G_.PlayerClass()
  if not G_.Class(cls) then a:say("I don't know your class's trainer yet."); return true end
  a:fdb()
  local plan = G_.TrainingPlan()
  if #plan.now == 0 then
    a:say("Nothing new to train right now.")
  else
    local list = {}
    for k = 1, math.min(#plan.now, 6) do list[#list + 1] = G_.RankText(plan.now[k]) end
    a:say(("%d to train now: %s%s"):format(#plan.now, table.concat(list, ", "), #plan.now > 6 and ", ..." or ""))
    if plan.unsure > 0 then a:muted("The game hasn't said which ranks you already have, so some may be known. Visit your trainer once to sort that out.") end
  end
  if plan.next then
    local list = {}
    for _, e in ipairs(plan.nextList) do list[#list + 1] = G_.RankText(e) end
    a:say(("Next at level %d: %s"):format(plan.next, table.concat(list, ", ")))
  end
  a:link("Open Train now", "training", "now")
  return true
end

local function eventAnswer(a)
  local E = ns.Events
  local list = E and E.List and E.List("upcoming") or {}
  local now = time()
  local ev
  for _, rec in ipairs(list) do if rec.start >= now - 3600 then ev = rec; break end end
  if not ev then
    a:say("No upcoming guild events in the calendar.")
    a:muted("The addon reads the in-game guild calendar; open it once so it can see new events.")
    a:tab("Open Events", "events")
    return true
  end
  local mins = math.floor((ev.start - now) / 60)
  local when
  if mins <= 0 then when = "happening now"
  elseif mins < 60 then when = ("in %d min"):format(mins)
  elseif mins < 48 * 60 then when = ("in %dh %dm"):format(math.floor(mins / 60), mins % 60)
  else when = ("in %d days"):format(math.floor(mins / 1440)) end
  local day = date("%a %b %d", ev.start):gsub(" 0(%d)", " %1")
  a:say(("Next guild event: %s, %s at %s %s, %s."):format(ev.title or "Guild event", day, E.Clock(ev.start), E.TimeLabel(ev), when))
  if ev.by then a:muted("Posted by " .. (ns.Compat.ShortName(ev.by) or ev.by) .. ".") end
  a:tab("Open Events", "events")
  return true
end

---------------------------------------------------------------------------
-- Reading the question: which kind of answer, about what
---------------------------------------------------------------------------
local function sold(id) return #FDB().ItemFacts(id).soldBy > 0 end
local function made(id) return #FDB().ItemFacts(id).madeBy > 0 end
local function inSet(id) return G().SetForItem(id) ~= nil end

local PREFER = { quest = questPref, item = itemPref }

-- What each kind of answer can be about, in order of preference on a tie.
local KINDS = {
  next = { "quest" }, turnin = { "quest" }, start = { "quest" },
  sells = { "item" }, crafters = { "item" }, make = { "item" }, disenchant = { "item" }, drops = { "item" },
  loot = { "dungeon", "boss", "mob" },
  set = { "set", "item" },
  find = { "node", "npc", "vendor", "zone", "dungeon", "quest", "item", "boss", "mob" },
  info = { "dungeon", "boss", "zone", "set", "quest", "vendor", "npc", "node", "item", "mob" },
}
-- the item has to be sold / made / in a set for these, when a close name is
local PRED = { sells = sold, crafters = made, make = made, set = inSet }
-- answers that can do without a name
local OPTIONAL = { make = true, crafters = true }
-- answers that need nothing more than the words
local BARE = { event = true, train = true, gather = true }

-- Everything matching `text` across kinds, best first ({ id, name, score, kind }).
local function resolve(st, kinds, text, raw)
  local ck = table.concat(kinds, ",") .. "\0" .. text
  if st.cache[ck] then return st.cache[ck] end
  local all = {}
  local function has(k) for _, x in ipairs(kinds) do if x == k then return true end end end
  local lq = linkedID(raw, "quest")
  if lq and has("quest") and FDB().Quest(lq) then
    all[#all + 1] = { kind = "quest", id = lq, name = FDB().Quest(lq).n, score = 100, rank = 0, pref = 0, len = 0 }
  end
  local li = linkedID(raw, "item")
  if li and has("item") then all[#all + 1] = { kind = "item", id = li, name = FDB().ItemName(li), score = 100, rank = 0, pref = 0, len = 0 } end
  if #all == 0 and text ~= "" then
    for rank, kind in ipairs(kinds) do
      for _, r in ipairs(find(kind, text, PREFER[kind], 8)) do r.rank = rank; all[#all + 1] = r end
    end
    -- near-equal scores (a few points apart) go by kind first: "redridge" is the zone
    table.sort(all, function(a, b)
      local ba, bb = math.floor(a.score / 4), math.floor(b.score / 4)
      if ba ~= bb then return ba > bb end
      if a.rank ~= b.rank then return a.rank < b.rank end
      if a.pref ~= b.pref then return a.pref > b.pref end
      if a.score ~= b.score then return a.score > b.score end
      return a.len < b.len
    end)
  end
  st.cache[ck] = all
  return all
end

-- Pick the one to answer about: the best, or for items a close one that fits.
local function pick(list, pred)
  local top = list[1]
  if not top or not pred then return top end
  for _, r in ipairs(list) do
    if r.score < top.score - 12 then break end
    if r.kind ~= "item" or pred(r.id) then return r end
  end
  return top
end

-- Score one reading of the question: keyword weight plus how well a name fits.
local function evaluate(st, it)
  local q, name = st.q, it.name
  local plan = { intent = name, kw = it.kw }
  if BARE[name] then
    plan.total = it.kw
    if name == "gather" then
      for _, t in ipairs(q.toks) do if t.c == "gprof" then plan.slug = P.GPROF[t.w] or P.GPROF[t.w:gsub("s$", "")]; break end end
      if not plan.slug then return nil end
    end
    return plan
  end
  local rest = P.Rest(q, P.STRIP[name] or {})
  plan.rest = rest
  if name == "quests" then
    plan.total = it.kw
    if rest ~= "" then
      local z = resolve(st, { "zone" }, rest, st.raw)[1]
      if z then plan.zone = z.name; plan.cand = z; plan.list = { z }; plan.total = it.kw + P.Fit(z.score) + z.score / 200
      else plan.total = it.kw - 3 end
    end
    return plan
  end
  if rest == "" and not linkedID(st.raw, "item") and not linkedID(st.raw, "quest") then
    if OPTIONAL[name] and q.has.make then plan.total = it.kw; plan.empty = true; return plan end
    return nil
  end
  local list = resolve(st, KINDS[name], rest, st.raw)
  plan.list = list
  plan.cand = pick(list, PRED[name])
  -- the closer name breaks ties between readings ("loot deadmines")
  plan.total = it.kw + (plan.cand and (P.Fit(plan.cand.score) + plan.cand.score / 200) or -1)
  return plan
end

-- The best reading of a question. Readings are tried strongest-words first and
-- the search stops once nothing left could win, so unneeded name lists aren't built.
local function decide(raw, st)
  local q = P.Read(raw)
  st.q, st.raw = q, raw
  local best
  for _, it in ipairs(P.Intents(q, true)) do
    if best and it.kw + 4.5 <= best.total then break end
    local plan = evaluate(st, it)
    if plan and (not best or plan.total > best.total) then best = plan end
  end
  return best, q
end

local function levelOpts(q)
  local lv = playerLevel()
  if q.mylevel or not (q.range or q.num) then
    if not lv then return nil end
    return math.max(1, lv - 2), lv + 2, ("Near level %d"):format(lv), "me"
  elseif q.range then
    return q.range[1], q.range[2], ("Levels %d-%d"):format(q.range[1], q.range[2]), q.range[1] .. "-" .. q.range[2]
  end
  return math.max(1, q.num - 1), q.num + 1, ("Around level %d"):format(q.num), tostring(q.num)
end

-- The reading in short, for tests: { intent, target, score }.
function Ask.Parse(raw)
  local plan, q = decide(tostring(raw or ""), { cache = {} })
  if not plan then return { intent = "none", target = "" } end
  local target = plan.cand and plan.cand.name or ""
  if plan.intent == "quests" then
    local lvlPart = ""
    if q.mylevel or q.range or q.num or not (plan.zone or q.here) then lvlPart = select(4, levelOpts(q)) or "me" end
    local zonePart = plan.zone or (q.here and "here")
    target = lvlPart .. (zonePart and ("@" .. zonePart) or "")
  elseif plan.intent == "gather" then target = plan.slug
  elseif plan.empty then target = "" end
  return { intent = plan.intent, target = target, score = plan.cand and plan.cand.score, kind = plan.cand and plan.cand.kind }
end

-- "Did you mean" chips for other close names, when the best one wasn't exact.
local function didYouMean(a, plan, skip)
  local top = plan.cand
  if not top or top.score >= 95 or not plan.list then return end
  local again = P.AGAIN[plan.intent] or P.AGAIN.info
  local seen, n = { [top.name] = true }, 0
  if skip then seen[skip] = true end
  for _, r in ipairs(plan.list) do
    if n >= 3 or r.score < top.score - 25 then break end
    if not seen[r.name] then
      seen[r.name] = true
      n = n + 1
      a:ask("  Did you mean " .. r.name .. "?", again:format(r.name))
    end
  end
  a.suggest = n > 0 or nil
end

local function makeList(a)
  a:say("I answer about one thing at a time: try \"How do I make Heavy Linen Bandage?\" or \"Who can craft Copper Chain Belt?\".")
  a:tab("Open Crafters (what the guild can make)", "crafters")
  a:link("Open the recipe lists in Quests & Items", "recipes", nil)
  return true
end

local function mobAnswer(a, npcId)
  local m = ns.db and ns.db.bestiary[npcId]
  local B = ns.Bestiary
  if not (m and B) then return false end
  local agg = B.Aggregate(m)
  a:say(("%s  %s(guild kills: %d)|r"):format(m.nm or "?", MUTED, agg.kills))
  table.sort(agg.loot, function(x, y) if x.rate ~= y.rate then return x.rate > y.rate end return x.itemID < y.itemID end)
  if #agg.loot == 0 then a:muted("Nobody in the guild has recorded loot from it yet."); return true end
  for k = 1, math.min(#agg.loot, 6) do
    local e = agg.loot[k]
    a:link(("  %s  %s%d%% of %d corpses|r"):format(FDB().ItemText(e.itemID), MUTED, math.floor(e.rate * 100 + 0.5), e.kills), "items", e.itemID)
  end
  a:muted("Guild-recorded: corpses that had it, from guildmates looting with the addon on.")
  return true
end

local function bossLoot(a, id) return lootAnswer(a, id[1], id[2]) end

local function describe(a, kind, id)
  if kind == "quest" then return questAnswer(a, id)
  elseif kind == "item" then return itemAnswer(a, id)
  elseif kind == "dungeon" then return dungeonAnswer(a, id)
  elseif kind == "boss" then
    a:say(("%s is a boss in:"):format(D().dungeons[id[1]].b[id[2]]))
    return dungeonAnswer(a, id[1])
  elseif kind == "zone" then
    if G().Zone(id) and G().Zone(id).bg then
      local e = G().BattlegroundList(G().Zone(id).n)[1]
      if e then return bgAnswer(a, e.id) end
    end
    return zoneAnswer(a, id)
  elseif kind == "set" then return setAnswer(a, id)
  elseif kind == "vendor" then return vendorAnswer(a, id)
  elseif kind == "npc" then return npcAnswer(a, id)
  elseif kind == "node" then return nodeAnswer(a, id[1], id[2], id[3])
  elseif kind == "mob" then return mobAnswer(a, id) end
  return false
end

-- One handler per kind of answer: (a, plan, candidate) -> true when answered.
local DO = {}
DO.event = function(a) return eventAnswer(a) end
DO.train = function(a) return trainAnswer(a) end
DO.gather = function(a, plan) return levelGatherAnswer(a, plan.slug) end
DO.quests = function(a, plan, _, q)
  local zone = plan.zone
  if not zone and q.here then
    zone = playerZone()
    if not zone then a:say("I can't tell which zone you're in."); return true end
    if not FDB().Index().zones[zone] then a:say(("The bundle has no quests in %s."):format(zone)); return true end
  end
  local opts = { zone = zone, side = FDB().PlayerSide() }
  local title
  if q.mylevel or q.range or q.num or not zone then
    local lo, hi, t = levelOpts(q)
    if not lo then a:say("I can't tell your level right now."); return true end
    opts.minLevel, opts.maxLevel, title = lo, hi, t
    if zone then title = title .. " in " .. zone end
  else
    title = "In " .. zone
  end
  return questListAnswer(a, opts, title)
end
DO.next = function(a, _, c) return nextAnswer(a, c.id) end
DO.turnin = function(a, _, c) return questAnswer(a, c.id, "end") end
DO.start = function(a, _, c) return questAnswer(a, c.id, "start") end
DO.sells = function(a, _, c) return sellsAnswer(a, c.id) end
DO.disenchant = function(a, _, c) return deAnswer(a, c.id) end
DO.drops = function(a, _, c) return dropsAnswer(a, c.id) end
DO.crafters = function(a, plan, c)
  if plan.empty then return makeList(a) end
  if c and c.score >= MIN and made(c.id) then return craftersAnswer(a, c.id) end
  -- enchants and other recipes with no item: the guild's shared recipe names
  local want = P.Key(plan.rest)
  for _, h in ipairs(ns.Crafting and ns.Crafting.Search and ns.Crafting.Search({ search = plan.rest }) or {}) do
    if h.name and P.Match(P.Key(h.name), want) >= MIN and h.crafters and #h.crafters > 0 then
      local short = {}
      for k = 1, math.min(#h.crafters, 8) do short[#short + 1] = ns.Compat.ShortName(h.crafters[k]) or h.crafters[k] end
      a:say(("Guild crafters for %s: %s"):format(h.name, table.concat(short, ", ")))
      a:tab("Open Crafters", "crafters")
      return true
    end
  end
  if c and c.score >= MIN then return craftersAnswer(a, c.id) end
  return craftersAnswer(a, nil, plan.rest)
end
DO.make = function(a, plan, c)
  if plan.empty then return makeList(a) end
  if c and c.score >= MIN and made(c.id) then return makeAnswer(a, c.id) end
  -- maybe it's a recipe/spell name (enchants have no item)
  local want, bestHit, bestScore = P.Key(plan.rest), nil, MIN - 1
  for _, h in ipairs(FDB().RecipeList({ search = plan.rest })) do
    local s = P.Match(P.Key(h.r.n), want)
    if s > bestScore then bestHit, bestScore = h, s end
  end
  if bestHit then return makeAnswer(a, nil, { prof = bestHit.prof, i = bestHit.i }) end
  if c and c.score >= MIN then a:link(FDB().ItemText(c.id), "items", c.id); a:say("It isn't crafted, as far as ForeverDB.net knows."); return true end
  return false
end
DO.loot = function(a, _, c)
  if c.kind == "dungeon" then return lootAnswer(a, c.id, "all") end
  if c.kind == "boss" then return bossLoot(a, c.id) end
  return mobAnswer(a, c.id)
end
DO.set = function(a, _, c)
  if c.kind == "set" then return setAnswer(a, c.id) end
  local setId = G().SetForItem(c.id)
  if not setId then a:link(FDB().ItemText(c.id), "items", c.id); a:say("It isn't part of any set up to level 30."); return true end
  return setAnswer(a, setId, c.id)
end
DO.find = function(a, _, c)
  if c.kind == "quest" then return questAnswer(a, c.id, "start") end
  if c.kind == "item" then
    local s2, i2, n2 = G().NodeForItem(c.id)
    if s2 then return nodeAnswer(a, s2, i2, n2) end
    if sold(c.id) then return sellsAnswer(a, c.id) end
    return dropsAnswer(a, c.id)
  end
  return describe(a, c.kind, c.id)
end
DO.info = function(a, _, c) return describe(a, c.kind, c.id) end

local WHAT = { next = "a quest", turnin = "a quest", start = "a quest", sells = "an item", crafters = "an item",
  make = "a recipe", disenchant = "an item", drops = "an item", loot = "a dungeon, boss or creature",
  set = "a set or item", find = "anything", info = "anything" }

-- Nothing matched well: answer the best loose guess, offer the next ones.
local function bestGuess(a, plan, st)
  local kinds = KINDS[plan.intent] or KINDS.info
  local text = plan.rest or ""
  local all = {}
  if text ~= "" then
    for rank, kind in ipairs(kinds) do
      if kind ~= "mob" and kind ~= "node" and kind ~= "boss" then
        for _, r in ipairs(loose(kind, text, PREFER[kind], 4)) do r.rank = rank; all[#all + 1] = r end
      end
    end
  end
  table.sort(all, function(x, y)
    if x.hits ~= y.hits then return x.hits > y.hits end
    if x.rank ~= y.rank then return x.rank < y.rank end
    if x.pref ~= y.pref then return x.pref > y.pref end
    return x.len < y.len
  end)
  local again = P.AGAIN[plan.intent] or P.AGAIN.info
  local g = all[1]
  if g then
    local before = #a.lines
    a:say(("Best guess for \"%s\":"):format(text))
    local ok, done = pcall(DO[plan.intent] or DO.info, a, plan, g, st.q)
    if ok and done then
      local seen, n = { [g.name] = true }, 0
      for _, r in ipairs(all) do
        if n >= 3 then break end
        if not seen[r.name] then seen[r.name] = true; n = n + 1; a:ask("  Did you mean " .. r.name .. "?", again:format(r.name)) end
      end
      a.suggest = n > 0 or nil
      return true
    end
    for k = #a.lines, before + 1, -1 do a.lines[k] = nil end
  end
  if plan.intent ~= "info" and text ~= "" then
    a:say(("I couldn't find %s called \"%s\"."):format(WHAT[plan.intent] or "anything", text))
    a:muted("The bundle covers WoW: Forever's quests, vendors and recipes, and gear up to level 30.")
    return true
  end
  return false
end

local function unknown(a, raw)
  a:say("I don't know that one.")
  a:muted("I answer from the bundled ForeverDB.net data and what the guild shares. Try one of these:")
  local n = #Ask.EXAMPLES
  local start = (#raw % n) + 1
  for j = 0, 2 do local e = Ask.EXAMPLES[(start + j * 4 - 1) % n + 1]; a:ask("  " .. e, e) end
  a.unknown = true
  return true
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function Ask.Answer(raw)
  raw = tostring(raw or "")
  local a = newAnswer(raw)
  if P.Norm(raw) == "" then
    a:say("Ask me about quests, items, recipes, gathering, sets, dungeons, training or guild events.")
    for k = 1, 4 do a:ask("  " .. Ask.EXAMPLES[k], Ask.EXAMPLES[k]) end
    return a
  end
  if not (FDB() and FDB().Available()) then
    a:say("The ForeverDB.net data didn't load, so I can't look things up.")
    if P.Norm(raw):find("event") then eventAnswer(a) end
    return a
  end
  local st = { cache = {} }
  local ok, plan = pcall(decide, raw, st)
  if not ok then ns.Debug("Ask: %s", tostring(plan)); plan = nil end
  if plan then
    local c = plan.cand
    local fn = DO[plan.intent]
    if fn and (BARE[plan.intent] or plan.intent == "quests" or plan.empty or (c and c.score >= MIN)
        or (plan.intent == "crafters" or plan.intent == "make")) then
      local before = #a.lines
      if c and c.score < 60 and plan.rest and plan.rest ~= "" then a:say(("Best guess for \"%s\":"):format(plan.rest)) end
      local ok2, done = pcall(fn, a, plan, c, st.q)
      if not ok2 then ns.Debug("Ask: %s", tostring(done)) end
      if ok2 and done then didYouMean(a, plan); return a end
      for k = #a.lines, before + 1, -1 do a.lines[k] = nil end
    end
    local ok3, done3 = pcall(bestGuess, a, plan, st)
    if not ok3 then ns.Debug("Ask: %s", tostring(done3)) end
    if ok3 and done3 then return a end
  end
  unknown(a, raw)
  return a
end

-- Plain chat lines for /lomb ask (your chat frame only; never sent).
function Ask.ChatLines(ans)
  local out = {}
  for _, l in ipairs(ans.lines) do
    local t = l.text
    if l.style == "muted" then t = MUTED .. t .. "|r" elseif l.style == "warn" then t = WARN .. t .. "|r" end
    if l.ask then t = "|cffb873ff" .. t:gsub("^%s+", "") .. "|r" .. MUTED .. "  (/lomb ask " .. l.ask .. ")|r" end
    out[#out + 1] = t
  end
  if ans.data then out[#out + 1] = MUTED .. FDB().CREDIT .. " · " .. FDB().URL .. "|r" end
  return out
end
