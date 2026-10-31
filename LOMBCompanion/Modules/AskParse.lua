-- LOMB Companion: the reader behind Ask LOMB.
-- Turns a typed question into words with meanings (quest, level, drop...),
-- scores names forgivingly (typos, missing words, plurals) and finds level
-- ranges and "my zone". Pure text work with no game or data calls, so the
-- tests and the web preview can share the same rules. Not an AI: it's a word
-- list, a few scores and an edit-distance check.
local _, ns = ...
local P = {}
ns.AskParse = P

local function set(s)
  local t = {}
  for w in s:gmatch("%S+") do t[w] = true end
  return t
end

-- words that carry no meaning in a question (they are ignored in names too)
P.FILLER = set([[what are the any some for me i can do does did show list give please good a an is
  there to at in around near about of on from with get got should could would will you your it its this
  that these those and or be am have has had so ok okay hey hi hello hiya sup between anywhere somewhere lomb thanks thank just tell know want let
  one ones all which my up into onto off inside out comes come coming goes go going farm gather
  gathered obtain acquire also really much many way ways not tho though yo yes looking look searching seeking trying]])
-- question words: never part of a name
P.QWORDS = set("what where who how when which why whose whom")

-- word -> meaning. Light stemming (s, es, ing, ed) is tried after this.
local SYN = {}
local function syn(concept, words) for w in words:gmatch("%S+") do SYN[w] = concept end end
syn("quest", "quest quests q qs questline questlines mission missions task tasks")
syn("level", "level levels lvl lvls lv lev leveling levelling lvling")
syn("mob", "mob mobs creature creatures monster monsters enemy enemies")
syn("npc", "npc npcs")
syn("drop", "drop drops dropped dropping loot loots looted lootable droprate")
syn("sell", "sell sells sold selling buy buys buying bought purchase vendor vendors merchant merchants shop shops")
syn("cost", "cost costs price prices")
syn("make", "make makes made making craft crafts crafted crafting create creates created cook cooks cooking cooked brew sew smelt")
syn("crafter", "crafter crafters maker makers")
syn("recipe", "recipe recipes pattern patterns schematic schematics formula plans")
syn("need", "reagent reagents mats materials ingredients need needs needed require requires")
syn("where", "where location located locate find finding found spot spots spawn spawns")
syn("dungeon", "dungeon dungeons instance instances dung")
syn("raid", "raid raids")
syn("boss", "boss bosses")
syn("train", "train training trainer trainers spell spells ability abilities learn")
syn("event", "event events calendar meetup meetups")
syn("upcoming", "upcoming soon tonight today tomorrow weekend")
syn("next", "next after follows follow following followup leads lead")
syn("chain", "chain storyline")
syn("start", "start starts starting begin begins started pickup")
syn("give", "gives give giver")
syn("turnin", "turnin handin finish finishes complete completes deliver")
syn("zone", "zone zones area areas region")
syn("here", "here nearby")
syn("mylevel", "mylevel")
syn("set", "set sets")
syn("piece", "piece pieces bonus")
syn("disenchant", "disenchant disenchants disenchanting disenchanted de")
syn("about", "about info information details describe")
syn("item", "item items")
syn("who", "who anyone anybody someone somebody")
syn("how", "how")
syn("when", "when")
syn("what", "what which")
syn("best", "best top fastest")
syn("guild", "guild guildie guildies")
syn("gprof", "herbalism herb herbs herbing mining mine skinning skin fishing fish")
P.SYN = SYN
-- the gathering profession each gathering word means
P.GPROF = { herbalism = "herbalism", herb = "herbalism", herbs = "herbalism", herbing = "herbalism",
  mining = "mining", mine = "mining", skinning = "skinning", skin = "skinning", fishing = "fishing", fish = "fishing" }

local FUZZY = {}
for w in pairs(SYN) do if #w >= 5 then FUZZY[#FUZZY + 1] = w end end
table.sort(FUZZY)

-- short forms people type, expanded before anything else
local EXPAND = {
  whats = "what is", wheres = "where is", whos = "who is", hows = "how is", whens = "when is",
  thats = "that is", theres = "there is", heres = "here is", im = "i am", ive = "i have",
  dont = "do not", doesnt = "does not", didnt = "did not", cant = "can not", wont = "will not",
  isnt = "is not", arent = "are not", wanna = "want to", gimme = "give me", lemme = "let me",
  u = "you", r = "are", ur = "your", pls = "please", plz = "please", plox = "please",
  wat = "what", wut = "what", wht = "what", whr = "where", hw = "how",
  wher = "where", whre = "where", wehre = "where", were = "where", wich = "which", wats = "what is",
  selz = "sells", sels = "sells", sel = "sell", byu = "buy", qests = "quests", qusts = "quests", ty = "thanks", thx = "thanks",
}
-- two-word phrases with one meaning
local PHRASE = {
  ["turn in"] = "turnin", ["turned in"] = "turnin", ["turning in"] = "turnin", ["hand in"] = "turnin",
  ["handed in"] = "turnin", ["turn it"] = "turnin", ["pick up"] = "pickup", ["picked up"] = "pickup",
  ["loot table"] = "loot", ["drop table"] = "loot", ["drop rate"] = "loot",
  ["my zone"] = "here", ["this zone"] = "here", ["current zone"] = "here", ["around here"] = "here",
  ["near here"] = "here", ["near me"] = "here", ["this area"] = "here", ["how much"] = "cost",
  ["my level"] = "mylevel", ["my lvl"] = "mylevel", ["my lv"] = "mylevel", ["my lvls"] = "mylevel",
  ["me level"] = "mylevel", ["me lvl"] = "mylevel", ["my levels"] = "mylevel",
}
local LEVELWORD = set("lvl lv level lev l")

-- Lowercased plain words: links and colour codes become their names, curly
-- quotes and dashes are straightened, punctuation goes, and "18-22" reads as
-- "18 to 22".
function P.Norm(raw)
  local s = tostring(raw or "")
  s = s:gsub("|H.-|h%[(.-)%]|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:lower():gsub("\226\128[\152\153]", "'"):gsub("\226\128[\147\148]", "-")
  s = s:gsub("(%d)%s*%-%s*(%d)", "%1 to %2")
  s = s:gsub("'", ""):gsub("[^%w%s]", " ")
  return (s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function words(s)
  local out = {}
  for w in s:gmatch("%S+") do out[#out + 1] = w end
  return out
end

-- Restricted edit distance (with swapped letters), giving up past max.
-- Fast path for "at most one typo" (no tables made): 0, 1, or 2 meaning "more".
local function within1(a, b)
  if a == b then return 0 end
  local la, lb = #a, #b
  if la > lb then a, b, la, lb = b, a, lb, la end
  if lb - la > 1 then return 2 end
  local byte = string.byte
  local i = 1
  while i <= la and byte(a, i) == byte(b, i) do i = i + 1 end
  if la == lb then
    -- one substitution, or two neighbours swapped
    if a:sub(i + 1) == b:sub(i + 1) then return 1 end
    if i < la and byte(a, i) == byte(b, i + 1) and byte(a, i + 1) == byte(b, i) and a:sub(i + 2) == b:sub(i + 2) then return 1 end
    return 2
  end
  -- one letter extra in b
  return a:sub(i) == b:sub(i + 1) and 1 or 2
end

local function osa(a, b, max)
  local la, lb = #a, #b
  if math.abs(la - lb) > max then return max + 1 end
  if max <= 1 then
    local d = within1(a, b)
    return d > max and max + 1 or d
  end
  if la == 0 or lb == 0 then return math.max(la, lb) end
  local prev2, prev = {}, {}
  for j = 0, lb do prev[j] = j end
  for i = 1, la do
    local cur, low, ca = { [0] = i }, i, a:byte(i)
    for j = 1, lb do
      local cb = b:byte(j)
      local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca == cb and 0 or 1))
      if i > 1 and j > 1 and ca == b:byte(j - 1) and a:byte(i - 1) == cb then v = math.min(v, prev2[j - 2] + 1) end
      cur[j] = v
      if v < low then low = v end
    end
    if low > max then return max + 1 end
    prev2, prev = prev, cur
  end
  return prev[lb]
end
P.Distance = osa

-- The meaning of one word, if it has one: exact, then stemmed, then one typo.
function P.Concept(w)
  if SYN[w] then return SYN[w] end
  local n = #w
  if n >= 4 then
    if w:sub(-1) == "s" and SYN[w:sub(1, -2)] then return SYN[w:sub(1, -2)] end
    if w:sub(-2) == "es" and SYN[w:sub(1, -3)] then return SYN[w:sub(1, -3)] end
  end
  if n >= 6 and w:sub(-3) == "ing" then
    local b = w:sub(1, -4)
    if SYN[b] or SYN[b .. "e"] then return SYN[b] or SYN[b .. "e"] end
  end
  if n >= 5 and w:sub(-2) == "ed" then
    local b = w:sub(1, -3)
    if SYN[b] or SYN[b .. "e"] then return SYN[b] or SYN[b .. "e"] end
  end
  if n >= 5 then
    for _, k in ipairs(FUZZY) do
      if k:byte(1) == w:byte(1) and osa(w, k, 1) <= 1 then return SYN[k] end
    end
  end
end

-- Read a question: words, their meanings, level asks and "here".
function P.Read(raw)
  local list = {}
  for _, w in ipairs(words(P.Norm(raw))) do
    local e = EXPAND[w]
    if e then
      for _, x in ipairs(words(e)) do list[#list + 1] = x end
    else
      local a, d = w:match("^(%a+)(%d+)$")
      if a and LEVELWORD[a] then list[#list + 1] = "lvl"; list[#list + 1] = d else list[#list + 1] = w end
    end
  end
  local toks, i = {}, 1
  while i <= #list do
    local two = list[i + 1] and PHRASE[list[i] .. " " .. list[i + 1]]
    -- "near me level": the second pair wins when it says "my level"
    if two and list[i + 2] and PHRASE[list[i + 1] .. " " .. list[i + 2]] == "mylevel" then two = nil end
    if two then
      toks[#toks + 1] = { w = two }
      i = i + 2
    else
      toks[#toks + 1] = { w = list[i] }
      i = i + 1
    end
  end
  local q = { toks = toks, has = {} }
  for k, t in ipairs(toks) do
    t.i = k
    t.num = t.w:match("^%d+$") and tonumber(t.w) or nil
    t.c = not t.num and P.Concept(t.w) or nil
    t.filler = P.FILLER[t.w] or false
    if t.w == "what" or t.w == "which" then t.c = "what" end
    if t.c then q.has[t.c] = (q.has[t.c] or 0) + 1 end
  end
  -- levels: "my level", "18 to 22", "18 22", "lvl 20", "quests for 20"
  for k, t in ipairs(toks) do
    if t.num and t.num >= 1 and t.num <= 80 and not t.used then
      local a, b = toks[k + 1], toks[k + 2]
      if a and b and b.num and (a.w == "to" or a.w == "through" or a.w == "thru" or a.w == "and" or a.w == "till" or a.w == "until") then
        q.range = { math.min(t.num, b.num), math.max(t.num, b.num) }
        t.used, a.used, b.used = true, true, true
      elseif a and a.num and a.num <= 80 then
        q.range = { math.min(t.num, a.num), math.max(t.num, a.num) }
        t.used, a.used = true, true
      elseif not q.num then
        q.num = t.num
        t.used = true
      end
    end
  end
  q.mylevel = q.has.mylevel ~= nil
  q.here = q.has.here ~= nil
  return q
end

-- The words of a question left once the given meanings are taken out.
-- Kind hints ("quest", "item") go too, unless nothing else is left.
local KINDWORD = { quest = true, item = true, npc = true, mob = true, dungeon = true, raid = true, zone = true, boss = true, set = true }
function P.Rest(q, strip)
  local out, hints = {}, {}
  for _, t in ipairs(q.toks) do
    local skip = t.filler or t.used or P.QWORDS[t.w] or t.c == "what" or (t.c and strip[t.c])
      or t.c == "here" or t.c == "mylevel"
    if not skip then
      if t.c and KINDWORD[t.c] then hints[#hints + 1] = t.w else out[#out + 1] = t.w end
    end
  end
  if #out == 0 and #hints > 0 and strip.keepHints then out = hints end
  return table.concat(out, " ")
end

-- A comparable form of a name: its words (fillers dropped) and those words run together.
function P.Key(text)
  local all, kept = words(P.Norm(text)), {}
  for _, w in ipairs(all) do if not P.FILLER[w] then kept[#kept + 1] = w end end
  if #kept == 0 then kept = all end
  return { t = kept, c = table.concat(kept), s = " " .. table.concat(kept, " ") .. " " }
end

local byte = string.byte

-- same word, or one is the other plus "s"/"es" (no new strings: this runs a lot)
local function plural(a, b)
  if a == b then return true end
  local la, lb = #a, #b
  if la > lb then a, b, la, lb = b, a, lb, la end
  local d = lb - la
  if d < 1 or d > 2 or la == 0 or byte(b, lb) ~= 115 or byte(a, 1) ~= byte(b, 1) then return false end
  if d == 2 and byte(b, lb - 1) ~= 101 then return false end
  return b:sub(1, la) == a
end

-- does s start with p (p at least 1 long)?
local function starts(s, p)
  local n = #p
  return n <= #s and byte(s, 1) == byte(p, 1) and (n == 1 or byte(s, n) == byte(p, n)) and s:sub(1, n) == p
end

local function tokenScore(qw, nt)
  local best = 0
  for _, nw in ipairs(nt) do
    local s = 0
    if plural(qw, nw) then s = 1
    elseif #qw >= 3 and starts(nw, qw) then s = 0.85
    elseif #nw >= 4 and starts(qw, nw) then s = 0.8
    elseif #qw >= 4 then
      local m = #qw >= 8 and 2 or 1
      if osa(qw, nw, m) <= m then s = 0.7 end
    end
    if s > best then best = s; if s == 1 then return 1 end end
  end
  return best
end

-- How well a name (its Key) answers what was typed (its Key), 0 to 100.
-- 100 same, 96 plural, 84+ start of the name, 80+ every word in the name,
-- 72+ inside the name, 60-68 a typo or two, 50-67 the whole name inside the
-- question, 40-70 most words close. Below 45 is no match.
function P.Match(n, q)
  local nc, qc = n.c, q.c
  local nn, nq = #nc, #qc
  if nn == 0 or nq == 0 then return 0 end
  if nc == qc then return 100 end
  if plural(nc, qc) then return 96 end
  local cov = math.min(nq / nn, 1) * 3
  if nq >= 3 and starts(nc, qc) then return 84 + cov end
  local all = true
  for _, w in ipairs(q.t) do
    local hit = false
    for _, nw in ipairs(n.t) do if plural(w, nw) then hit = true; break end end
    if not hit then all = false; break end
  end
  if all then return 80 + cov end
  if nq >= 5 and nc:find(qc, 1, true) then return 72 + cov end
  local s = 0
  local m = nq >= 8 and 2 or (nq >= 5 and 1 or 0)
  if m > 0 then
    local d = osa(nc, qc, m)
    if d <= m then s = 76 - 8 * d
    elseif nn > nq and nc:byte(1) == qc:byte(1) then
      d = osa(nc:sub(1, nq), qc, m)
      if d <= m then s = 64 - 8 * d end
    end
  end
  if nn >= 5 and q.s:find(n.s, 1, true) then s = math.max(s, 52 + math.min(nn, 30) * 0.5) end
  if s == 0 and #q.t > 0 then
    local sum, hit = 0, 0
    for _, w in ipairs(q.t) do
      local v = tokenScore(w, n.t)
      if v == 0 and #w >= 3 then return 0 end
      sum = sum + v
      if v > 0 then hit = hit + 1 end
    end
    if hit == 0 then return 0 end
    s = 40 + 20 * (sum / #q.t) + 10 * math.min(hit / #n.t, 1)
  end
  return s
end

-- What a match score is worth when choosing between readings of a question.
function P.Fit(score)
  if not score then return 0 end
  if score >= 95 then return 4 elseif score >= 80 then return 3 elseif score >= 60 then return 2 elseif score >= 45 then return 1 end
  return -1
end

-- Loose word overlap, for "best guess" suggestions when nothing really matches.
function P.Overlap(n, q)
  local hit = 0
  for _, w in ipairs(q.t) do
    if #w >= 4 then
      for _, nw in ipairs(n.t) do
        if starts(nw, w) or (#nw >= 4 and starts(w, nw)) or (#w >= 5 and osa(w, nw, 1) <= 1) then hit = hit + 1; break end
      end
    end
  end
  return hit
end

-- How strongly each kind of answer is suggested by the words alone.
-- Returns a list of { name, kw } for the intents that can apply, best first.
function P.Intents(q, gather)
  local h, out = q.has, {}
  local function n(c) return h[c] or 0 end
  local function add(name, kw) out[#out + 1] = { name = name, kw = kw } end
  local lvl = q.mylevel or q.range or q.num
  if n("event") > 0 or (n("raid") > 0 and (n("next") + n("upcoming") + n("when")) > 0) or (n("upcoming") > 0 and n("guild") > 0) then
    add("event", 4 * math.min(n("event"), 1) + 2 * math.min(n("upcoming"), 1) + math.min(n("next"), 1)
      + math.min(n("guild"), 1) + math.min(n("when"), 1) + (n("raid") > 0 and n("event") == 0 and 3 or 0))
  end
  if n("train") > 0 then add("train", 4 + (n("what") > 0 and 0.5 or 0)) end
  if gather and n("gprof") > 0 then
    add("gather", 4 + (n("level") > 0 and 3 or 0) + (n("where") > 0 and 1.5 or 0) + (n("best") > 0 and 1 or 0)
      + (q.mylevel and 3 or 0))
  end
  if n("quest") > 0 or q.mylevel or (n("level") > 0 and lvl) then
    add("quests", 3 * math.min(n("quest"), 1) + (q.mylevel and 2 or 0) + ((q.range or q.num) and 2 or 0)
      + math.min(n("level"), 1) + (q.here and 2 or 0))
  end
  if n("next") > 0 or n("chain") > 0 then add("next", 4 * math.min(n("next"), 1) + n("chain") * 1 + 0.5 * math.min(n("what"), 1)) end
  if n("turnin") > 0 then add("turnin", 5) end
  if n("start") > 0 or n("give") > 0 then
    add("start", 4 * math.min(n("start"), 1) + 2 * math.min(n("give"), 1) + ((n("who") > 0 and n("give") > 0) and 1 or 0))
  end
  if n("sell") > 0 or n("cost") > 0 then add("sells", 4 * math.min(n("sell"), 1) + 2 * math.min(n("cost"), 1)) end
  if (n("who") > 0 and n("make") > 0) or n("crafter") > 0 then add("crafters", n("crafter") > 0 and 4 or 5) end
  if n("make") > 0 or n("recipe") > 0 or n("need") > 0 then
    add("make", 3 * math.min(n("make"), 1) + 3 * math.min(n("recipe"), 1) + 2 * math.min(n("need"), 1) + math.min(n("how"), 1))
  end
  if n("disenchant") > 0 then add("disenchant", 5) end
  if n("drop") > 0 then
    -- "what drops in X", "X loot" is about a place or creature; "what drops X" about an item
    local first
    for _, t in ipairs(q.toks) do if t.c == "drop" then first = t.i; break end end
    local after = q.toks[first + 1]
    local before = false
    for k = 1, first - 1 do
      local t = q.toks[k]
      if not t.filler and not t.c and not t.num then before = true end
    end
    local place = after and (after.w == "in" or after.w == "at" or after.w == "inside" or after.w == "off")
    local lootKw = 3 + (place and 1.5 or (before and 1 or 0))
    local dropKw = 3 + ((not place and not before) and 1 or 0) + ((n("who") + n("mob") + n("where")) > 0 and 1 or 0)
    if after and after.w == "from" then lootKw = lootKw + 1.5 end
    add("loot", lootKw)
    add("drops", dropKw)
  end
  if n("set") > 0 then add("set", 4 + math.min(n("piece"), 1)) end
  if n("where") > 0 then add("find", 3) end
  add("info", 0.5 + 2 * math.min(n("level"), 1) + 2 * math.min(n("boss"), 1) + math.min(n("about"), 1)
    + 0.5 * math.min(n("what"), 1))
  -- stable: best first, ties in the order added
  for k, e in ipairs(out) do e.order = k end
  table.sort(out, function(a, b) if a.kw ~= b.kw then return a.kw > b.kw end return a.order < b.order end)
  return out
end

-- Meanings each intent takes out of the name being asked about.
P.STRIP = {
  quests = { quest = true, level = true, zone = true, here = true, best = true, need = true, give = true,
    about = true, where = true, start = true },
  next = { next = true, chain = true, quest = true },
  turnin = { turnin = true, where = true, who = true, quest = true, how = true },
  start = { start = true, give = true, who = true, where = true, how = true, quest = true },
  sells = { sell = true, cost = true, where = true, who = true, how = true },
  crafters = { who = true, make = true, crafter = true, guild = true },
  make = { make = true, recipe = true, need = true, how = true, who = true },
  disenchant = { disenchant = true, how = true },
  loot = { drop = true, who = true, dungeon = true, boss = true, mob = true, raid = true },
  drops = { drop = true, who = true, where = true, mob = true, how = true },
  set = { set = true, piece = true },
  find = { where = true, how = true, mob = true, npc = true, gprof = true },
  -- words that only say what kind of answer is wanted are no name on their own
  info = { about = true, level = true, boss = true, how = true, make = true, recipe = true, crafter = true,
    sell = true, drop = true, train = true, event = true, where = true, need = true, keepHints = true },
}
-- How to ask again about a suggested name, per intent.
P.AGAIN = {
  sells = "Who sells %s?", make = "How do I make %s?", crafters = "Who can craft %s?",
  disenchant = "What does %s disenchant into?", loot = "What drops in %s?", drops = "Where does %s drop?",
  set = "Which set is %s in?", next = "What comes after %s?", turnin = "Where do I turn in %s?",
  start = "Where does %s start?", find = "Where is %s?", info = "Tell me about %s", quests = "Quests in %s",
}

return P
