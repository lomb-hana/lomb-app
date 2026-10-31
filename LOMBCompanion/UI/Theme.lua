-- LOMB Companion: look & feel. One place for every colour, font and size, so the
-- screenshots (tools/mock) and the game use exactly the same values.
local _, ns = ...
local T = {}
ns.Theme = T

T.colors = {
  bg       = { 0.055, 0.047, 0.078, 0.96 },
  panel    = { 0.090, 0.080, 0.120, 1 },
  panel2   = { 0.120, 0.105, 0.160, 1 },
  border   = { 0.240, 0.200, 0.320, 1 },
  accent   = { 0.720, 0.450, 1.000, 1 },   -- LOMB violet  #B873FF
  accentDim= { 0.720, 0.450, 1.000, 0.18 },
  gold     = { 0.950, 0.780, 0.360, 1 },
  text     = { 0.920, 0.900, 0.950, 1 },
  muted    = { 0.600, 0.570, 0.660, 1 },
  good     = { 0.500, 0.880, 0.500, 1 },
  warn     = { 0.880, 0.700, 0.380, 1 },
  bad      = { 0.900, 0.350, 0.350, 1 },
  row      = { 1, 1, 1, 0.025 },
  rowHover = { 0.720, 0.450, 1.000, 0.12 },
  health   = { 0.300, 0.780, 0.360, 1 },
  healthBg = { 0.080, 0.150, 0.080, 1 },
}

-- source tag colours: where a fact came from
T.sourceColors = {
  game      = { 0.45, 0.80, 0.95, 1 },
  guild     = { 0.72, 0.45, 1.00, 1 },
  foreverdb = { 0.95, 0.78, 0.36, 1 },
}

T.fonts = {
  title  = "Fonts\\MORPHEUS.TTF",
  body   = "Fonts\\FRIZQT__.TTF",
  narrow = "Fonts\\ARIALN.TTF",
}

T.sizes = {
  window   = { w = 780, h = 480 },
  titleBar = 34,
  nav      = { w = 118, h = 26 },          -- left sidebar
  content  = { w = 642 },                  -- window.w - nav.w - 2 * pad
  tab      = { w = 100, h = 26 },
  footer   = 22,
  pad      = 10,
  row      = 20,
  card     = { w = 250 },
  page     = { w = 420, h = 520 },
  minimap  = 32,
}

-- Roster columns (widths in px); the mock screenshots read these too.
T.rosterColumns = {
  { key = "badge",  label = "",            w = 18 },
  { key = "short",  label = "Name",        w = 150 },
  { key = "level",  label = "Lvl",         w = 36, justify = "CENTER" },
  { key = "class",  label = "Class",       w = 80 },
  { key = "rankIndex", label = "Rank",     w = 96 },
  { key = "zone",   label = "Zone",        w = 128 },
  { key = "online", label = "Last online", w = 90, justify = "RIGHT" },
}

T.classification = {
  normal    = nil,
  trivial   = nil,
  minus     = nil,
  elite     = { "Elite",      T.colors.gold },
  rare      = { "Rare",       { 0.78, 0.82, 0.90, 1 } },
  rareelite = { "Rare Elite", { 0.95, 0.60, 0.95, 1 } },
  worldboss = { "Boss",       T.colors.bad },
}

T.LOGO = "Interface\\AddOns\\LOMBCompanion\\Media\\logo"
T.WHITE = "Interface\\Buttons\\WHITE8X8"
T.ARROW_RIGHT = "Interface\\AddOns\\LOMBCompanion\\Media\\arrow-right"   -- our own, see tools/make_arrows.py
T.ARROW_DOWN = "Interface\\AddOns\\LOMBCompanion\\Media\\arrow-down"

-- ---------------------------------------------------------------- looks
-- Two looks: "storybook", the default since 0.9.7 (Land of Make Believe: a night sky in
-- violet and gold, a parchment title bar, corner flourishes, tab icons and playful empty
-- states), and "clean" (the colours above, picked in Settings > Look). The art is drawn in code by tools/make_storybook.py; the fonts
-- are the game's own. A look is picked once when the addon loads (Settings changes it
-- and reloads the UI), because frames read these colours when they are built.
local function copy(c) return { c[1], c[2], c[3], c[4] } end
T.palettes = { clean = {}, storybook = {
  bg       = { 0.063, 0.051, 0.137, 0.97 },  -- night sky
  panel    = { 0.098, 0.078, 0.196, 1 },
  panel2   = { 0.137, 0.110, 0.251, 1 },
  border   = { 0.520, 0.420, 0.230, 1 },     -- old gold
  accent   = { 0.960, 0.790, 0.400, 1 },     -- gold
  accentDim= { 0.960, 0.790, 0.400, 0.16 },
  gold     = { 1.000, 0.860, 0.520, 1 },
  text     = { 0.960, 0.925, 0.835, 1 },     -- parchment cream
  muted    = { 0.700, 0.650, 0.820, 1 },     -- lavender
  row      = { 1, 1, 1, 0.03 },
  rowHover = { 0.960, 0.790, 0.400, 0.10 },
} }
for k, c in pairs(T.colors) do T.palettes.clean[k] = copy(c) end
T.ink = { 0.290, 0.180, 0.100, 1 }           -- writing on parchment
T.inkSoft = { 0.420, 0.300, 0.190, 1 }
T.look = "clean"

local MEDIA = "Interface\\AddOns\\LOMBCompanion\\Media\\Storybook\\"
T.STORY = {
  parchment = MEDIA .. "parchment", stars = MEDIA .. "stars",
  flourish = MEDIA .. "flourish", divider = MEDIA .. "divider",
}
function T.TabIcon(id) return MEDIA .. "icon-" .. tostring(id) end
T.TAB_ICON_IDS = { roster = true, me = true, crafters = true, news = true, board = true, bestiary = true, quests = true,
  ask = true, events = true, wishlist = true, bank = true, settings = true, credits = true }

-- Switch every colour in place (other tables, like T.classification, point at these).
function T.Apply(name)
  if not T.palettes[name] then name = "clean" end
  for k, c in pairs(T.palettes.clean) do
    local src = T.palettes[name][k] or c
    local dst = T.colors[k]
    dst[1], dst[2], dst[3], dst[4] = src[1], src[2], src[3], src[4]
  end
  T.look = name
  return name
end
function T.IsStorybook() return T.look == "storybook" end

-- Empty-state lines: the storybook look tells them as a little story, the clean look
-- keeps them plain. Unknown keys fall back to the plain text.
T.PLAYFUL = {
  ["bestiary.none"]   = "The bestiary's pages are still blank.\n\nTarget, fight or defeat a creature and it gets written in, "
    .. "and so do the ones guildmates meet.",
  ["bestiary.search"] = "No creature by that name in our book yet. Perhaps it's still hiding in the tall grass.",
  ["bestiary.filter"] = "Not one of those in the book so far. Right-click the filter to see every page.",
  ["mob.pick"]        = "Choose a page on the left, or target a creature out in the world.",
  ["news.none"]       = "Once upon a time... nothing has happened yet.\n\nLevel-ups, rare kills, dungeon clears, new recipes, "
    .. "epic loot, first mounts and guild events will write the story here.",
  ["news.filter"]     = "No tales of that kind yet.",
  ["board.none"]      = "The leaderboard is still an empty page. It fills in as guildmates with the addon play.",
  ["crafters.search"] = "No crafter in the guild knows that one yet.",
  ["roster.search"]   = "Nobody by that name in the guild.",
  ["bank.none"]       = "The treasure chest is empty.",
  ["bank.search"]     = "Nothing like that in the treasure chest.",
  ["events.none"]     = "No adventures on the calendar yet.\n\nEvents come from the in-game calendar: officers add them there.",
  ["events.past"]     = "No adventures told yet.",
  ["wishlist.none"]   = "Nobody has made a wish yet.\n\nAdd what you need or what you can give away below. Guildmates see it here and on item tooltips.",
}
function T.Playful(key, plain)
  if T.look == "storybook" and T.PLAYFUL[key] then return T.PLAYFUL[key] end
  return plain
end

function T.hex(c)
  return ("ff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

function T.color(key, text)
  local c = T.colors[key] or T.sourceColors[key] or T.colors.text
  return "|c" .. T.hex(c) .. tostring(text) .. "|r"
end

function T.classColorText(classFile, text)
  local r, g, b = ns.Compat.ClassColor(classFile)
  return "|c" .. T.hex({ r, g, b }) .. tostring(text) .. "|r"
end

-- A character's short name, class-coloured when the roster knows them.
function T.OwnerText(owner)
  local row = ns.Roster and ns.Roster.byName[owner]
  local short = ns.Compat.ShortName(owner)
  if row and row.class then return T.classColorText(row.class, short) end
  return short
end
