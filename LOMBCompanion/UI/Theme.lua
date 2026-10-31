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
  nav      = { w = 118, h = 24 },          -- left sidebar (15 entries must fit)
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
  { key = "zone",   label = "Zone",        w = 120 },
  { key = "ach",    label = "Ach",         w = 36, justify = "CENTER" },
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
