-- LOMB Companion: "Who can craft X?"
-- Reads the recipes you know whenever a profession window is open, shares them
-- as the "rc" dataset (item IDs / spell IDs only, grouped by profession code) and
-- builds a guild-wide index for the Crafters tab and item tooltips.
--
-- Recipes are only ever added while the profession is still known (the game's
-- recipe list can be filtered or collapsed, so an absent row doesn't mean you
-- forgot it); dropping a profession removes its recipes.
local _, ns = ...
local C = ns.Compat
local Crafting = ns:NewModule("Crafting")

Crafting.MAX_PER_PROF = 600
Crafting.byItem = {}     -- [itemID]  = { owner, ... }
Crafting.bySpell = {}    -- [spellID] = { owner, ... }
Crafting.entries = {}    -- flat list for search: { kind="i"|"s", id, prof, crafters = { owner... } }

local function codeOf(profName) return ns.Me.CODES[profName] or profName end
local function nameOf(code) return ns.Me.FROM_CODE[code] or code end
Crafting.CodeOf, Crafting.NameOf = codeOf, nameOf

---------------------------------------------------------------------------
-- Reading recipes from the open profession window
---------------------------------------------------------------------------
local function profEntry(profName)
  ns.char.recipes = ns.char.recipes or {}
  local e = ns.char.recipes[profName]
  if not e then
    e = { i = {}, s = {} }
    ns.char.recipes[profName] = e
  end
  return e
end

-- modern C_TradeSkillUI (returns nil if the API isn't there)
local function scanModern()
  local T = _G.C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs) then return nil end
  local info = C.Call(T.GetBaseProfessionInfo) or C.Call(T.GetTradeSkillLine)
  local profName = type(info) == "table" and (info.professionName or info.parentProfessionName) or info
  if type(profName) ~= "string" or not ns.Me.PROFESSIONS[profName] then return nil end
  local ids = C.Call(T.GetAllRecipeIDs)
  if type(ids) ~= "table" then return nil end
  local items, spells = {}, {}
  for _, recipeID in ipairs(ids) do
    local r = C.Call(T.GetRecipeInfo, recipeID)
    if type(r) == "table" and r.learned ~= false then
      local out = r.outputItemID
      if not out and T.GetRecipeSchematic then
        local sch = C.Call(T.GetRecipeSchematic, recipeID, false)
        out = type(sch) == "table" and sch.outputItemID or nil
      end
      if out then items[out] = r.name or true else spells[recipeID] = r.name or true end
    end
  end
  return profName, items, spells
end

-- classic trade skill window
local function scanTradeSkill()
  if not _G.GetNumTradeSkills or not _G.GetTradeSkillLine then return nil end
  local profName = C.Call(_G.GetTradeSkillLine)
  if type(profName) ~= "string" or not ns.Me.PROFESSIONS[profName] then return nil end
  local items, spells = {}, {}
  local n = C.Call(_G.GetNumTradeSkills) or 0
  for i = 1, math.min(n, 1000) do
    local name, kind = C.Call(_G.GetTradeSkillInfo, i)
    if name and kind ~= "header" and kind ~= "subheader" then
      local id = C.ItemIdFromLink(C.Call(_G.GetTradeSkillItemLink, i))
      if id then
        items[id] = name
      else
        local rl = C.Call(_G.GetTradeSkillRecipeLink, i)
        local sid = type(rl) == "string" and tonumber(rl:match("enchant:(%d+)") or rl:match("spell:(%d+)"))
        if sid then spells[sid] = name end
      end
    end
  end
  return profName, items, spells
end

-- classic craft window (Enchanting)
local function scanCraft()
  if not _G.GetNumCrafts then return nil end
  local profName = C.Call(_G.GetCraftDisplaySkillLine) or C.Call(_G.GetCraftSkillLine, 1)
  if type(profName) ~= "string" or not ns.Me.PROFESSIONS[profName] then return nil end
  local items, spells = {}, {}
  local n = C.Call(_G.GetNumCrafts) or 0
  for i = 1, math.min(n, 1000) do
    local name, _, kind = C.Call(_G.GetCraftInfo, i)
    if name and kind ~= "header" then
      local link = C.Call(_G.GetCraftItemLink, i)
      local id = C.ItemIdFromLink(link)
      local sid = type(link) == "string" and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
      if id then items[id] = name elseif sid then spells[sid] = name end
    end
  end
  return profName, items, spells
end

-- Merge one scan into our saved recipes. Returns how many were new.
function Crafting.Absorb(profName, items, spells)
  if not profName then return 0 end
  local e = profEntry(profName)
  e.n = e.n or {}
  local added = 0
  local function add(set, prefix, id, name)
    if not set[id] then
      set[id] = true
      added = added + 1
    end
    if type(name) == "string" then e.n[prefix .. id] = name end
  end
  local count = 0
  for _ in pairs(e.i) do count = count + 1 end
  for _ in pairs(e.s) do count = count + 1 end
  for id, name in pairs(items or {}) do
    if count + added >= Crafting.MAX_PER_PROF then break end
    add(e.i, "i", id, name)
  end
  for id, name in pairs(spells or {}) do
    if count + added >= Crafting.MAX_PER_PROF then break end
    add(e.s, "s", id, name)
  end
  e.at = time()
  if added > 0 then
    ns.Debug("learned %d %s recipe(s)", added, profName)
    ns.Shared.MarkDirty("rc")
  end
  return added
end

function Crafting.ScanOpenWindow(which)
  if C.InCombat() then return 0 end     -- never do list work in combat
  local profName, items, spells
  if which == "craft" then
    profName, items, spells = scanCraft()
  else
    profName, items, spells = scanModern()
    if not profName then profName, items, spells = scanTradeSkill() end
  end
  return Crafting.Absorb(profName, items, spells)
end
Crafting.ScanSoon = ns.Debounce(0.5, function() Crafting.ScanOpenWindow("trade") end)
Crafting.ScanCraftSoon = ns.Debounce(0.5, function() Crafting.ScanOpenWindow("craft") end)

-- Drop recipes for professions this character no longer has.
function Crafting.PruneDropped()
  local profs = ns.Me.stats.professions
  if not profs or not ns.char.recipes or next(profs) == nil then return end
  for profName in pairs(ns.char.recipes) do
    if not profs[profName] then
      ns.char.recipes[profName] = nil
      ns.Shared.MarkDirty("rc")
    end
  end
end

-- Our own recipe counts, for the Crafters tab header.
function Crafting.MyCounts()
  local out = {}
  for profName, e in pairs(ns.char.recipes or {}) do
    local n = 0
    for _ in pairs(e.i) do n = n + 1 end
    for _ in pairs(e.s) do n = n + 1 end
    out[#out + 1] = { prof = profName, n = n }
  end
  table.sort(out, function(a, b) return a.prof < b.prof end)
  return out
end

---------------------------------------------------------------------------
-- Shared dataset "rc":  { [profCode] = { i = {itemIDs}, s = {spellIDs} } }
---------------------------------------------------------------------------
local function sortedKeys(set)
  local out = {}
  for id in pairs(set) do out[#out + 1] = id end
  table.sort(out)
  return out
end

function Crafting.Build()
  local out, any = {}, false
  for profName, e in pairs(ns.char.recipes or {}) do
    local i, s = sortedKeys(e.i), sortedKeys(e.s)
    if #i + #s > 0 then
      out[codeOf(profName)] = { i = #i > 0 and i or nil, s = #s > 0 and s or nil }
      any = true
    end
  end
  return any and out or nil
end

function Crafting.Validate(d)
  if type(d) ~= "table" then return nil end
  local V, out, n = ns.Shared.V, {}, 0
  for code, p in pairs(d) do
    code = V.str(code, 24)
    if code and type(p) == "table" then
      n = n + 1
      if n > 16 then break end
      local i = p.i and V.idList(p.i, Crafting.MAX_PER_PROF, 1e7) or nil
      local s = p.s and V.idList(p.s, Crafting.MAX_PER_PROF, 1e7) or nil
      if (i and #i > 0) or (s and #s > 0) then out[code] = { i = i, s = s } end
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Guild index
---------------------------------------------------------------------------
function Crafting.Rebuild()
  local byItem, bySpell, entries = {}, {}, {}
  local seen = {}
  local function add(map, kind, id, code, owner)
    local list = map[id]
    if not list then
      list = {}
      map[id] = list
    end
    list[#list + 1] = owner
    -- one search entry per (recipe, profession)
    local key = kind .. id .. ":" .. code
    local e = seen[key]
    if not e then
      e = { kind = kind, id = id, prof = code, crafters = {} }
      seen[key] = e
      entries[#entries + 1] = e
    end
    e.crafters[#e.crafters + 1] = owner
  end
  for owner, data in ns.Shared.Each("rc") do
    for code, p in pairs(data) do
      for _, id in ipairs(p.i or {}) do add(byItem, "i", id, code, owner) end
      for _, id in ipairs(p.s or {}) do add(bySpell, "s", id, code, owner) end
    end
  end
  Crafting.byItem, Crafting.bySpell, Crafting.entries = byItem, bySpell, entries
  ns:Fire("CRAFTERS_UPDATED")
end
Crafting.RebuildSoon = ns.Debounce(1, Crafting.Rebuild)

-- Display name of a recipe output; nil while the item isn't cached yet.
function Crafting.EntryName(e)
  local names = ns.db.craftNames
  local key = e.kind .. e.id
  local name
  if e.kind == "i" then
    name = ns.Compat.ItemInfo(e.id)
  else
    name = ns.Compat.SpellName(e.id)
  end
  if name then names[key] = name; return name end
  for _, r in pairs(ns.char.recipes or {}) do
    if r.n and r.n[key] then return r.n[key] end
  end
  return names[key]
end

local function isOnline(owner)
  if owner == ns.playerKey then return true end
  local row = ns.Roster.byName[owner]
  return row and row.online or false
end
Crafting.IsOnline = isOnline

-- Crafters sorted: online first, then by name.
function Crafting.SortCrafters(list)
  local out = {}
  for i, v in ipairs(list or {}) do out[i] = v end
  table.sort(out, function(a, b)
    local oa, ob = isOnline(a), isOnline(b)
    if oa ~= ob then return oa end
    return a < b
  end)
  return out
end

function Crafting.CraftersOfItem(itemID) return Crafting.SortCrafters(Crafting.byItem[itemID]) end

-- opts: { search=, prof=code or nil, onlineOnly=bool, owner=name or nil }
function Crafting.Search(opts)
  opts = opts or {}
  local q = (opts.search or ""):lower()
  local out = {}
  local missing = 0
  for _, e in ipairs(Crafting.entries) do
    if not opts.prof or e.prof == opts.prof then
      local crafters = Crafting.SortCrafters(e.crafters)
      local ok = true
      if opts.onlineOnly then ok = isOnline(crafters[1] or "") end
      if ok and opts.owner then
        ok = false
        for _, c in ipairs(crafters) do if c == opts.owner then ok = true end end
      end
      if ok then
        local name = Crafting.EntryName(e)
        if not name then
          missing = missing + 1
          if e.kind == "i" and C_Item and C_Item.RequestLoadItemDataByID then
            C.Call(C_Item.RequestLoadItemDataByID, e.id)
          end
        end
        local match = q == ""
          or (name and name:lower():find(q, 1, true))
          or nameOf(e.prof):lower():find(q, 1, true)
        if not match then
          for _, c in ipairs(crafters) do
            if C.ShortName(c):lower():find(q, 1, true) then match = true; break end
          end
        end
        if match then
          out[#out + 1] = { kind = e.kind, id = e.id, prof = e.prof, name = name, crafters = crafters }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
    if a.name ~= b.name then return (a.name or "") < (b.name or "") end
    return a.id < b.id
  end)
  return out, missing
end

-- Professions that appear in the guild data (for the filter button).
function Crafting.ProfCodes()
  local set, out = {}, {}
  for _, e in ipairs(Crafting.entries) do set[e.prof] = true end
  for code in pairs(set) do out[#out + 1] = code end
  table.sort(out, function(a, b) return nameOf(a) < nameOf(b) end)
  return out
end

function Crafting.CrafterCount()
  local n = 0
  for _ in ns.Shared.Each("rc") do n = n + 1 end
  return n
end

-- Tooltip line: "Crafters in LOMB: A, B, +3"
function Crafting.TooltipLine(itemID)
  local list = Crafting.byItem[itemID]
  if not list or #list == 0 then return nil end
  local sorted = Crafting.SortCrafters(list)
  local parts = {}
  for i = 1, math.min(4, #sorted) do
    local o = sorted[i]
    local short = C.ShortName(o)
    parts[i] = isOnline(o) and ("|cff7fe07f" .. short .. "|r") or short
  end
  local text = table.concat(parts, ", ")
  if #sorted > 4 then text = text .. (", +%d"):format(#sorted - 4) end
  return "Crafters in LOMB: |cffffffff" .. text .. "|r"
end

---------------------------------------------------------------------------
function Crafting:Init()
  ns.db.craftNames = ns.db.craftNames or {}
  ns.Shared.Define({
    kind = "rc", label = "recipes",
    build = Crafting.Build, validate = Crafting.Validate,
    enabled = function() return ns.db.settings.shareRecipes end,
    onChange = function() Crafting.RebuildSoon() end,
  })
end

function Crafting:Login()
  Crafting.Rebuild()
  if ns.Tooltip then ns.Tooltip.AddLine(Crafting.TooltipLine) end
end

ns:On("TRADE_SKILL_SHOW", function() Crafting.ScanSoon() end)
ns:On("TRADE_SKILL_UPDATE", function() Crafting.ScanSoon() end)
ns:On("TRADE_SKILL_LIST_UPDATE", function() Crafting.ScanSoon() end)
ns:On("NEW_RECIPE_LEARNED", function() Crafting.ScanSoon() end)
ns:On("CRAFT_SHOW", function() Crafting.ScanCraftSoon() end)
ns:On("CRAFT_UPDATE", function() Crafting.ScanCraftSoon() end)
ns:On("GET_ITEM_INFO_RECEIVED", function() ns:Fire("CRAFTERS_NAMES") end)
ns:Listen("ME_UPDATED", function() Crafting.PruneDropped() end)
ns:Listen("ROSTER_UPDATED", function() ns:Fire("CRAFTERS_NAMES") end)
