-- LOMB Companion: Ask LOMB -- a question box that answers from the bundled
-- ForeverDB.net snapshot and what the guild has shared. It works offline: it
-- matches the question against a fixed set of question shapes, looks the names up
-- in the bundle, and builds the answer from the same lookups the other views use.
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

local PREFIXES = { "hey lomb ", "hi lomb ", "lomb ", "hey ", "hi ", "please ", "can you tell me ", "could you tell me ",
  "do you know ", "tell me ", "i want to know ", "i need to know ", "any idea ", "so ", "ok ", "okay " }

local function tidy(q)
  local changed = true
  while changed do
    changed = false
    for _, p in ipairs(PREFIXES) do
      if q:sub(1, #p) == p then q = q:sub(#p + 1); changed = true end
    end
  end
  q = q:gsub(" please$", ""):gsub(" thanks?$", ""):gsub(" thank you$", "")
  return q
end

local function playerLevel()
  local l = UnitLevel and ns.Compat.Call(UnitLevel, "player")
  return type(l) == "number" and l > 0 and l or nil
end

local function playerZone()
  local z = GetRealZoneText and ns.Compat.Call(GetRealZoneText)
  return (type(z) == "string" and z ~= "") and z or nil
end

---------------------------------------------------------------------------
-- Name indexes (built the first time a question needs them)
---------------------------------------------------------------------------
local names = {}

local function build(kind)
  local d = D()
  local list = {}
  local function put(name, id) if name and name ~= "" then list[#list + 1] = { norm(name), id, name } end end
  if not d then return list end
  if kind == "quest" then for id, q in pairs(d.quests or {}) do put(q.n, id) end
  elseif kind == "item" then for id, e in pairs(d.items or {}) do put(e[1], id) end
  elseif kind == "vendor" then for id, v in pairs(d.vendors or {}) do put(v.n, id) end
  elseif kind == "dungeon" then for id, dg in pairs(d.dungeons or {}) do put(dg.n, id) end
  elseif kind == "zone" then for id, z in pairs(d.zones or {}) do put(z.n, id) end
  elseif kind == "set" then for id, s in pairs(d.itemsets or {}) do put(s.n, id) end
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
  end
  return list
end

local function index(kind)
  if not names[kind] then names[kind] = build(kind) end
  return names[kind]
end

function Ask.ResetIndex() names = {} end
function Ask.IndexBuilt(kind) return names[kind] ~= nil end

local function strip(t)
  t = t:gsub("^the quest ", ""):gsub("^quest ", ""):gsub(" quest$", ""):gsub(" item$", "")
  return t
end

-- Find things of one kind by name: exact first, then "starts with", then "contains"
-- (and the name inside the question). Returns a list of { id, name, score }, best first.
-- `prefer(id)` returns a number; higher wins between equal matches.
local function find(kind, text, prefer, limit)
  text = strip(norm(text))
  if text == "" then return {} end
  local alt = text:gsub("^the ", ""):gsub("^an? ", "")
  local out = {}
  for _, e in ipairs(index(kind)) do
    local n, score = e[1], nil
    if n == text or n == alt then score = 4
    elseif n:gsub("^the ", "") == alt then score = 4
    elseif #alt >= 3 and n:sub(1, #alt) == alt then score = 3
    elseif #alt >= 3 and n:find(alt, 1, true) then score = 2
    elseif #n >= 5 and (" " .. text .. " "):find(" " .. n .. " ", 1, true) then score = 1 end
    if score then out[#out + 1] = { id = e[2], name = e[3], score = score, len = #n, pref = prefer and prefer(e[2]) or 0 } end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.pref ~= b.pref then return a.pref > b.pref end
    if a.score == 1 and a.len ~= b.len then return a.len > b.len end   -- longest name found inside the question
    if a.len ~= b.len then return a.len < b.len end
    if type(a.id) == "number" and type(b.id) == "number" then return a.id < b.id end
    return a.name < b.name
  end)
  if limit and #out > limit then for k = #out, limit + 1, -1 do out[k] = nil end end
  return out
end
Ask.Find = find

local function best(kind, text, prefer)
  local r = find(kind, text, prefer, 1)[1]
  return r and r.id, r
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
  return p
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

-- Other close matches with a different name, when the best one wasn't exact.
local function others(a, list, kindWord)
  local top = list[1]
  if not top or top.score >= 4 then return end
  local more, seen = {}, { [top.name] = true }
  for k = 2, #list do
    local r = list[k]
    if #more < 3 and r.score >= 2 and not seen[r.name] then seen[r.name] = true; more[#more + 1] = r.name end
  end
  if #more > 0 then a:muted(("Or did you mean the %s %s?"):format(kindWord, table.concat(more, " / "))) end
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
-- Resolving "X" in a question to something the bundle knows
---------------------------------------------------------------------------
local function itemFrom(raw, text, pred)
  local id = linkedID(raw, "item")
  if id then return id end
  local list = find("item", text, itemPref, 12)
  if pred then
    for _, r in ipairs(list) do if r.score >= 2 and pred(r.id) then return r.id, list end end
  end
  return list[1] and list[1].id, list
end

local function questFrom(raw, text)
  local id = linkedID(raw, "quest")
  if id and FDB().Quest(id) then return id end
  local list = find("quest", text, questPref, 6)
  return list[1] and list[1].id, list
end

local function sold(id) return #FDB().ItemFacts(id).soldBy > 0 end
local function made(id) return #FDB().ItemFacts(id).madeBy > 0 end

local keywords
local function notFound(a, what, text)
  a:say(("I couldn't find %s called \"%s\"."):format(what, text))
  -- names sharing the most words (4+ letters) with what was asked
  local words = {}
  for w in keywords(strip(norm(text))):gmatch("%S+") do if #w >= 4 then words[#words + 1] = w end end
  local near = {}
  if #words > 0 then
    local kind = what == "a quest" and "quest" or "item"
    local scored, seen = {}, {}
    for _, e in ipairs(index(kind)) do
      local hits = 0
      for _, w in ipairs(words) do if e[1]:find(w, 1, true) then hits = hits + 1 end end
      if hits > 0 and not seen[e[3]] then
        seen[e[3]] = true
        scored[#scored + 1] = { id = e[2], name = e[3], hits = hits, pref = kind == "item" and itemPref(e[2]) or questPref(e[2]) }
      end
    end
    table.sort(scored, function(x, y)
      if x.hits ~= y.hits then return x.hits > y.hits end
      if x.pref ~= y.pref then return x.pref > y.pref end
      return x.name < y.name
    end)
    for k = 1, math.min(3, #scored) do near[k] = scored[k] end
  end
  if #near > 0 then
    a:fdb()
    a:muted("Closest names in the bundle:")
    for _, r in ipairs(near) do
      if what == "a quest" then a:link("  " .. r.name, "quests", r.id) else a:link("  " .. FDB().ItemText(r.id), "items", r.id) end
    end
  else
    a:muted("The bundle covers WoW: Forever's quests, vendors and recipes, and gear up to level 30.")
  end
  return true
end

-- Best guess at what a bare name is: { kind, id, ... } or nil
local function anything(raw, text)
  local qid = linkedID(raw, "quest")
  if qid and FDB().Quest(qid) then return "quest", qid end
  local iid = linkedID(raw, "item")
  if iid then return "item", iid end
  local cands = {}
  local function try(kind, prefer, rank)
    local r = find(kind, text, prefer, 1)[1]
    if r and r.score >= 2 then cands[#cands + 1] = { kind = kind, id = r.id, name = r.name, score = r.score, rank = rank } end
  end
  try("dungeon", nil, 9); try("zone", nil, 8); try("set", nil, 7); try("quest", questPref, 6)
  try("vendor", nil, 5); try("npc", nil, 4); try("item", itemPref, 3)
  local slug, i, n = G().FindNode(text)
  if slug and norm(n.n) == strip(norm(text)) then cands[#cands + 1] = { kind = "node", id = { slug, i, n }, score = 4, rank = 10 } end
  table.sort(cands, function(x, y) if x.score ~= y.score then return x.score > y.score end return x.rank > y.rank end)
  local c = cands[1]
  if c then return c.kind, c.id, c end
end

local function describe(a, kind, id)
  if kind == "quest" then return questAnswer(a, id)
  elseif kind == "item" then return itemAnswer(a, id)
  elseif kind == "dungeon" then return dungeonAnswer(a, id)
  elseif kind == "zone" then
    if G().Zone(id) and G().Zone(id).bg then
      local e = G().BattlegroundList(G().Zone(id).n)[1]
      if e then return bgAnswer(a, e.id) end
    end
    return zoneAnswer(a, id)
  elseif kind == "set" then return setAnswer(a, id)
  elseif kind == "vendor" then return vendorAnswer(a, id)
  elseif kind == "npc" then return npcAnswer(a, id)
  elseif kind == "node" then return nodeAnswer(a, id[1], id[2], id[3]) end
  return false
end

---------------------------------------------------------------------------
-- Question shapes, tried in order. Each pattern runs on the tidied question;
-- the first capture (if any) is the thing being asked about.
---------------------------------------------------------------------------
local GATHER = { herbalism = "herbalism", herb = "herbalism", herbs = "herbalism", mining = "mining", mine = "mining",
  ore = "mining", skinning = "skinning", skin = "skinning", fishing = "fishing", fish = "fishing" }

local RULES = {}
local function rule(patterns, fn) RULES[#RULES + 1] = { p = patterns, fn = fn } end

rule({ "next guild event", "next event", "next raid", "upcoming event", "guild events?$", "any events" },
  function(a) return eventAnswer(a) end)

rule({ "^what should i train", "^what can i train", "^what do i train", "^what to train", "^train$", "^training$",
  "^what does my trainer have", "^what s new at my trainer", "^anything to train", "^do i need to train", "^what spells", "^what abilities" },
  function(a) return trainAnswer(a) end)

rule({ "^what can i make$", "^what can i craft$", "^what can i cook$", "^what recipes", "^recipes$" },
  function(a)
    a:say("I answer about one thing at a time: try \"How do I make Heavy Linen Bandage?\" or \"Who can craft Copper Chain Belt?\".")
    a:tab("Open Crafters (what the guild can make)", "crafters")
    a:link("Open the recipe lists in Quests & Items", "recipes", nil)
    return true
  end)

rule({ "^where should i level (%a+)$", "^where to level (%a+)$", "^where can i level (%a+)$", "^where do i level (%a+)$",
  "^best zones? for (%a+)$", "^best place to level (%a+)$", "^level (%a+)$", "^how do i level (%a+)$" },
  function(a, x)
    local slug = GATHER[x]
    if not slug then return false end
    return levelGatherAnswer(a, slug)
  end)

rule({ "^quests? near my level", "^quests? for my level", "^quests? at my level", "^quests? around my level",
  "^what quests? should i do", "^what quests? can i do", "^what should i quest", "^quests? for me$", "^any quests? for me" },
  function(a)
    local lv = playerLevel()
    if not lv then a:say("I can't tell your level right now."); return true end
    return questListAnswer(a, { minLevel = math.max(1, lv - 2), maxLevel = lv + 2, side = FDB().PlayerSide() },
      ("Near level %d"):format(lv))
  end)

rule({ "^quests? for level (%d+)", "^level (%d+) quests?$", "^quests? at level (%d+)" },
  function(a, x)
    local lv = tonumber(x)
    return questListAnswer(a, { minLevel = math.max(1, lv - 1), maxLevel = lv + 1, side = FDB().PlayerSide() }, ("Around level %d"):format(lv))
  end)

rule({ "^quests? in my zone", "^quests? here$", "^quests? around here", "^what quests? are here", "^quests? in this zone",
  "^what quests? are in my zone", "^what quests? are in this zone" },
  function(a)
    local z = playerZone()
    if not z then a:say("I can't tell which zone you're in."); return true end
    if not FDB().Index().zones[z] then a:say(("The bundle has no quests in %s."):format(z)); return true end
    return questListAnswer(a, { zone = z, side = FDB().PlayerSide() }, "In " .. z)
  end)

rule({ "^quests? in (.+)$", "^what quests? are in (.+)$", "^(.+) quests$" },
  function(a, x)
    local id, r = best("zone", x)
    if not id or r.score < 2 then return false end
    return questListAnswer(a, { zone = r.name, side = FDB().PlayerSide() }, "In " .. r.name)
  end)

rule({ "^what comes after (.+)$", "^what comes next after (.+)$", "^whats next after (.+)$", "^what is next after (.+)$",
  "^what s next after (.+)$", "^whats after (.+)$", "^next quest after (.+)$", "^what follows (.+)$", "^after (.+) what next$",
  "^what comes next in (.+)$", "^next in chain (.+)$", "^next part of (.+)$", "^whats the next part of (.+)$", "^where does (.+) lead$" },
  function(a, x, raw)
    x = x:gsub("^the chain ", ""):gsub(" chain$", "")
    local id, list = questFrom(raw, x)
    if not id then return notFound(a, "a quest", x) end
    nextAnswer(a, id)
    others(a, list or {}, "quest")
    return true
  end)

rule({ "^where do i turn in (.+)$", "^where to turn in (.+)$", "^where can i turn in (.+)$", "^who do i turn in (.+) to$",
  "^where do i hand in (.+)$", "^turn in (.+)$", "^who takes (.+)$", "^where does (.+) end$", "^who do i give (.+) to$" },
  function(a, x, raw)
    local id, list = questFrom(raw, x)
    if not id then return notFound(a, "a quest", x) end
    questAnswer(a, id, "end")
    others(a, list or {}, "quest")
    return true
  end)

rule({ "^who sells (.+)$", "^where can i buy (.+)$", "^where do i buy (.+)$", "^where to buy (.+)$", "^buy (.+)$",
  "^which vendor sells (.+)$", "^what vendor sells (.+)$", "^vendor for (.+)$", "^who has (.+) for sale$" },
  function(a, x, raw)
    local id = itemFrom(raw, x, sold)
    if not id then return notFound(a, "an item", x) end
    return sellsAnswer(a, id)
  end)

rule({ "^who can craft (.+)$", "^who can make (.+)$", "^who in the guild can make (.+)$", "^who in the guild can craft (.+)$",
  "^anyone can make (.+)$", "^can anyone make (.+)$", "^can anyone craft (.+)$", "^who crafts (.+)$", "^who makes (.+)$" },
  function(a, x, raw)
    local id = itemFrom(raw, x, made)
    if not id then
      -- enchants and other recipes with no item: the guild's shared recipe names
      local want = strip(norm(x))
      for _, h in ipairs(ns.Crafting and ns.Crafting.Search and ns.Crafting.Search({ search = x }) or {}) do
        if h.name and norm(h.name):find(want, 1, true) and h.crafters and #h.crafters > 0 then
          local short = {}
          for k = 1, math.min(#h.crafters, 8) do short[#short + 1] = ns.Compat.ShortName(h.crafters[k]) or h.crafters[k] end
          a:say(("Guild crafters for %s: %s"):format(h.name, table.concat(short, ", ")))
          a:tab("Open Crafters", "crafters")
          return true
        end
      end
      return craftersAnswer(a, nil, x)
    end
    return craftersAnswer(a, id)
  end)

rule({ "^how do i make (.+)$", "^how to make (.+)$", "^how can i make (.+)$", "^how do i craft (.+)$", "^how to craft (.+)$",
  "^how do i cook (.+)$", "^how to cook (.+)$", "^how do i brew (.+)$", "^how do i smelt (.+)$", "^recipe for (.+)$",
  "^what do i need to make (.+)$", "^what do i need for (.+)$", "^whats in (.+)$", "^how is (.+) made$", "^make (.+)$", "^craft (.+)$" },
  function(a, x, raw)
    local id = itemFrom(raw, x, made)
    if id and made(id) then return makeAnswer(a, id) end
    -- maybe it's a recipe/spell name (enchants have no item)
    local hits = FDB().RecipeList({ search = x })
    for _, h in ipairs(hits) do
      if norm(h.r.n) == strip(norm(x)) then return makeAnswer(a, nil, { prof = h.prof, i = h.i }) end
    end
    if hits[1] then return makeAnswer(a, nil, { prof = hits[1].prof, i = hits[1].i }) end
    if id then a:link(FDB().ItemText(id), "items", id); a:say("It isn't crafted, as far as ForeverDB.net knows."); return true end
    return notFound(a, "a recipe", x)
  end)

rule({ "^what does (.+) disenchant into$", "^what does (.+) disenchant to$", "^what do (.+) disenchant into$",
  "^what will (.+) disenchant into$", "^disenchant (.+)$", "^what can i disenchant (.+) into$", "^can i disenchant (.+)$",
  "^what does (.+) de into$", "^(.+) disenchants? into$", "^what gives (.+) when disenchanted$", "^where do i get (.+) from disenchanting$" },
  function(a, x, raw)
    local id = itemFrom(raw, x)
    if not id then return notFound(a, "an item", x) end
    return deAnswer(a, id)
  end)

rule({ "^what drops in (.+)$", "^what drops at (.+)$", "^what drops from (.+)$", "^what does (.+) drop$", "^what do (.+) drop$",
  "^loot in (.+)$", "^loot from (.+)$", "^(.+) loot$", "^(.+) loot table$", "^what loot is in (.+)$", "^what loot does (.+) have$",
  "^what can i get in (.+)$", "^what can i get from (.+)$", "^what drops off (.+)$" },
  function(a, x)
    x = x:gsub("^the dungeon ", ""):gsub(" dungeon$", ""):gsub(" raid$", "")
    local did, dr = best("dungeon", x)
    if did and dr.score >= 2 then return lootAnswer(a, did, "all") end
    if not ns.Loot then return false end
    local bdid, bi = ns.Loot.FindBoss(x)
    if bdid then return lootAnswer(a, bdid, bi) end
    return false
  end)

rule({ "^what drops (.+)$", "^who drops (.+)$", "^where does (.+) drop$", "^where do (.+) drop$", "^what mob drops (.+)$",
  "^which mob drops (.+)$", "^what monster drops (.+)$", "^drops for (.+)$", "^what drops a (.+)$" },
  function(a, x, raw)
    local id = itemFrom(raw, x)
    if not id then return notFound(a, "an item", x) end
    return dropsAnswer(a, id)
  end)

rule({ "^which set is (.+) in$", "^what set is (.+) in$", "^what set is (.+) part of$", "^which set is (.+) part of$",
  "^is (.+) part of a set$", "^is (.+) in a set$", "^what set does (.+) belong to$", "^set for (.+)$", "^(.+) set$", "^set (.+)$" },
  function(a, x, raw)
    local sid, sr = best("set", x)
    if sid and sr.score >= 3 then return setAnswer(a, sid) end
    local id = itemFrom(raw, x, function(i) return G().SetForItem(i) ~= nil end)
    if not id then return notFound(a, "an item", x) end
    local setId = G().SetForItem(id)
    if not setId then a:link(FDB().ItemText(id), "items", id); a:say("It isn't part of any set up to level 30."); return true end
    return setAnswer(a, setId, id)
  end)

rule({ "^where can i find (.+)$", "^where do i find (.+)$", "^where to find (.+)$", "^where can i pick (.+)$", "^where can i mine (.+)$",
  "^where does (.+) grow$", "^where do i get (.+)$", "^where can i get (.+)$", "^where to get (.+)$", "^where can i farm (.+)$",
  "^where to farm (.+)$", "^where do i farm (.+)$", "^where can i gather (.+)$", "^where is (.+)$", "^where are (.+)$", "^find (.+)$" },
  function(a, x, raw)
    x = x:gsub(" ore$", " ore"):gsub("^some ", "")
    local slug, i, n = G().FindNode(x)
    if slug and (norm(n.n) == strip(norm(x)) or (n.it and norm(FDB().ItemName(n.it)) == strip(norm(x)))) then
      return nodeAnswer(a, slug, i, n)
    end
    local kind, id, c = anything(raw, x)
    if kind == "quest" then return questAnswer(a, id, "start") end
    if kind == "item" then
      local s2, i2, n2 = G().NodeForItem(id)
      if s2 then return nodeAnswer(a, s2, i2, n2) end
      if sold(id) then return sellsAnswer(a, id) end
      return dropsAnswer(a, id)
    end
    if kind then return describe(a, kind, id, c) end
    if slug then return nodeAnswer(a, slug, i, n) end
    return false
  end)

rule({ "^who gives (.+)$", "^where does (.+) start$", "^how do i start (.+)$", "^how do i get the quest (.+)$", "^where do i pick up (.+)$",
  "^where do i get the quest (.+)$", "^who starts (.+)$" },
  function(a, x, raw)
    local id, list = questFrom(raw, x)
    if not id then return notFound(a, "a quest", x) end
    questAnswer(a, id, "start")
    others(a, list or {}, "quest")
    return true
  end)

rule({ "^what level is (.+)$", "^what level for (.+)$", "^(.+) level and bosses$", "^(.+) bosses and level$", "^(.+) levels?$",
  "^(.+) bosses$", "^bosses in (.+)$", "^who are the bosses in (.+)$", "^what bosses are in (.+)$", "^how many bosses in (.+)$",
  "^what level do i need for (.+)$", "^when can i do (.+)$", "^tell me about (.+)$", "^what about (.+)$", "^info on (.+)$", "^what is (.+)$", "^whats (.+)$" },
  function(a, x, raw)
    x = x:gsub("^the dungeon ", ""):gsub(" dungeon$", "")
    local did, dr = best("dungeon", x)
    if did and dr.score >= 2 then return dungeonAnswer(a, did) end
    local bdid = FDB().DungeonForBoss(x)
    if bdid then a:say(("%s is a boss in:"):format(x)); return dungeonAnswer(a, bdid) end
    local kind, id, c = anything(raw, x)
    if kind then return describe(a, kind, id, c) end
    return false
  end)

---------------------------------------------------------------------------
-- Fallback: search everything, or say so
---------------------------------------------------------------------------
local STOP = {}
for w in ("what where who how is the a an i do does can of to in me my for get find about tell it which and are there"):gmatch("%S+") do
  STOP[w] = true
end

function keywords(q)
  local out = {}
  for w in q:gmatch("%S+") do if not STOP[w] then out[#out + 1] = w end end
  return table.concat(out, " ")
end

local function fallback(a, q, raw)
  local kind, id, c = anything(raw, q)
  if kind then return describe(a, kind, id, c) end
  local k = keywords(q)
  if #k >= 3 then
    local kind2, id2, c2 = anything(raw, k)
    if kind2 then return describe(a, kind2, id2, c2) end
    local hits = {}
    local function push(text, mode, key) if #hits < 6 then hits[#hits + 1] = { text, mode, key } end end
    for _, r in ipairs(find("quest", k, questPref, 3)) do push("Quest: " .. r.name, "quests", r.id) end
    for _, r in ipairs(find("item", k, itemPref, 3)) do push("Item: " .. FDB().ItemText(r.id), "items", r.id) end
    for _, r in ipairs(find("dungeon", k, nil, 1)) do push("Dungeon: " .. r.name, "dungeons", r.id) end
    for _, r in ipairs(find("zone", k, nil, 1)) do push("Zone: " .. r.name, "zones", r.id) end
    for _, r in ipairs(find("vendor", k, nil, 2)) do push("Vendor: " .. r.name, "vendors", r.id) end
    if #hits > 0 then
      a:fdb()
      a:say("Not sure what you mean, but these match:")
      for _, h in ipairs(hits) do a:link("  " .. h[1], h[2], h[3]) end
      return true
    end
  end
  a:say("I don't know that one.")
  a:muted("I answer from the bundled ForeverDB.net data and what the guild shares. Try one of these:")
  local n = #Ask.EXAMPLES
  local start = (#q % n) + 1
  for j = 0, 2 do local e = Ask.EXAMPLES[(start + j * 4 - 1) % n + 1]; a:ask("  " .. e, e) end
  a.unknown = true
  return true
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function Ask.Answer(raw)
  raw = tostring(raw or "")
  local q = tidy(norm(raw))
  local a = newAnswer(raw)
  if q == "" then
    a:say("Ask me about quests, items, recipes, gathering, sets, dungeons, training or guild events.")
    for k = 1, 4 do a:ask("  " .. Ask.EXAMPLES[k], Ask.EXAMPLES[k]) end
    return a
  end
  if not (FDB() and FDB().Available()) then
    a:say("The ForeverDB.net data didn't load, so I can't look things up.")
    if q:find("event") then eventAnswer(a) end
    return a
  end
  for _, r in ipairs(RULES) do
    for _, p in ipairs(r.p) do
      local x = q:match(p)
      if x then
        local before = #a.lines
        local ok, done = pcall(r.fn, a, type(x) == "string" and x or nil, raw)
        if not ok then ns.Debug("Ask: %s", tostring(done)) end
        if ok and done then return a end
        for k = #a.lines, before + 1, -1 do a.lines[k] = nil end
        break
      end
    end
  end
  fallback(a, q, raw)
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

Ask.history = {}   -- { answer, ... }, oldest first
Ask.MAX_HISTORY = 40

---------------------------------------------------------------------------
-- Saved history (per character, LOMBCompanionCharDB.askHistory). Only the
-- question and the answer's lines are kept: text, style and what a line opens.
-- Nothing else from the answer object, no timestamps, nothing about the player.
---------------------------------------------------------------------------
local MAX_TEXT = 400

local function cleanText(t)
  if type(t) ~= "string" then return nil end
  return t:sub(1, MAX_TEXT)
end

local function cleanKey(k)
  local tk = type(k)
  if tk == "number" or tk == "string" then return tk == "string" and k:sub(1, 120) or k end
  if tk == "table" then
    local out = {}
    for i = 1, 2 do
      local v = k[i]
      if type(v) == "number" or type(v) == "string" then out[i] = v end
    end
    return out
  end
  return nil
end

local function cleanLine(l)
  if type(l) ~= "table" then return nil end
  local text = cleanText(l.text)
  if not text then return nil end
  local out = { text = text }
  if l.style == "muted" or l.style == "warn" then out.style = l.style end
  if type(l.link) == "table" and type(l.link[1]) == "string" then out.link = { l.link[1], cleanKey(l.link[2]) } end
  if type(l.tab) == "string" then out.tab = l.tab end
  if type(l.ask) == "string" then out.ask = cleanText(l.ask) end
  return out
end

-- A plain copy of an answer that's safe to save (and to load back).
function Ask.Pack(ans)
  if type(ans) ~= "table" then return nil end
  local q = cleanText(ans.q)
  if not q then return nil end
  local out = { q = q:sub(1, 200), lines = {} }
  if ans.data then out.data = true end
  if type(ans.lines) == "table" then
    for _, l in ipairs(ans.lines) do
      local c = cleanLine(l)
      if c then out.lines[#out.lines + 1] = c end
    end
  end
  return out
end

function Ask.Save()
  if type(ns.char) ~= "table" then return end
  local saved = {}
  local from = math.max(1, #Ask.history - Ask.MAX_HISTORY + 1)
  for i = from, #Ask.history do
    local p = Ask.Pack(Ask.history[i])
    if p then saved[#saved + 1] = p end
  end
  ns.char.askHistory = #saved > 0 and saved or nil
end

function Ask.Load()
  Ask.history = {}
  local saved = type(ns.char) == "table" and ns.char.askHistory
  if type(saved) ~= "table" then return 0 end
  local from = math.max(1, #saved - Ask.MAX_HISTORY + 1)
  for i = from, #saved do
    local p = Ask.Pack(saved[i])
    if p then
      p.restored = true
      Ask.history[#Ask.history + 1] = setmetatable(p, A)
    end
  end
  return #Ask.history
end

function Ask.Submit(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  local ans = Ask.Answer(text)
  Ask.history[#Ask.history + 1] = ans
  while #Ask.history > Ask.MAX_HISTORY do table.remove(Ask.history, 1) end
  Ask.Save()
  if ns.AskTab and ns.AskTab.Refresh then ns.AskTab.Refresh(true) end
  return ans
end

-- Clear wipes the saved copy too.
function Ask.Clear()
  Ask.history = {}
  if type(ns.char) == "table" then ns.char.askHistory = nil end
  if ns.AskTab and ns.AskTab.Refresh then ns.AskTab.Refresh(true) end
end

ns:Listen("LOGIN", function() ns.SafeCall(Ask.Load) end)

function Ask.Slash(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then
    ns.UI.Open("ask")
    return
  end
  local ans = Ask.Submit(text)
  ns.Print("|cffb873ffAsk LOMB:|r " .. text)
  for _, line in ipairs(Ask.ChatLines(ans)) do ns.Print("  " .. line) end
end
