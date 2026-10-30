-- LOMB Companion: guild wishlist -- what members need and what they can give away.
-- Each character keeps its own short list; it's shared with the guild as item IDs
-- (or a few words of text for things that aren't one item), quantities and a note.
local _, ns = ...
local C = ns.Compat
local WL = ns:NewModule("Wishlist")
ns.Wishlist = WL

WL.MAX = 20            -- entries per character
WL.TEXT_MAX = 40
WL.QTY_MAX = 999
WL.EXPIRE_DAYS = 60    -- own entries older than this are dropped at login

local function mine()
  ns.char.wish = ns.char.wish or {}
  return ns.char.wish
end
WL.Mine = mine

local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Text from the add box -> itemID (from a link, or a cached item name) + display text.
function WL.Resolve(text)
  text = trim(text)
  if text == "" then return nil, nil end
  local id = C.ItemIdFromLink(text)
  if id then
    local name = C.ItemInfo(id)
    return id, name or text:match("%[(.-)%]") or ("item:" .. id)
  end
  text = text:gsub("[%c|]", "")
  local name, link = C.ItemInfo(text)
  id = link and C.ItemIdFromLink(link)
  if id then return id, name end
  return nil, text:sub(1, WL.TEXT_MAX)
end

local function same(e, kind, id, text)
  if e.k ~= kind then return false end
  if id then return e.i == id end
  return not e.i and (e.x or ""):lower() == (text or ""):lower()
end

-- kind: "n" (need) or "g" (can give away). Returns the entry, or nil + reason.
function WL.Add(kind, text, qty, note)
  if kind ~= "n" and kind ~= "g" then return nil, "kind" end
  local id, label = WL.Resolve(text)
  if not label then return nil, "Type an item name, or shift-click an item into the box." end
  qty = math.floor(tonumber(qty) or 1)
  if qty < 1 then qty = 1 elseif qty > WL.QTY_MAX then qty = WL.QTY_MAX end
  note = trim(note):gsub("[%c|]", ""):sub(1, WL.TEXT_MAX)
  local list = mine()
  for _, e in ipairs(list) do
    if same(e, kind, id, label) then
      e.q, e.t = qty, time()
      if note ~= "" then e.n = note end
      WL.Changed()
      return e
    end
  end
  if #list >= WL.MAX then return nil, ("Your list is full (%d). Remove something first."):format(WL.MAX) end
  local e = { k = kind, i = id, x = (not id) and label or nil, q = qty, n = note ~= "" and note or nil, t = time() }
  list[#list + 1] = e
  WL.Changed()
  return e
end

function WL.Remove(entry)
  local list = mine()
  for i, e in ipairs(list) do
    if e == entry or (entry.k == e.k and entry.t == e.t and entry.i == e.i and entry.x == e.x) then
      table.remove(list, i)
      WL.Changed()
      return true
    end
  end
  return false
end

function WL.Changed()
  ns.Shared.MarkDirty("wl")
  ns:Fire("WISHLIST_UPDATED")
end

function WL.Prune()
  local list, cutoff, n = mine(), time() - WL.EXPIRE_DAYS * 86400, 0
  for i = #list, 1, -1 do
    if (list[i].t or 0) < cutoff then table.remove(list, i); n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------
-- sharing ("wl")
---------------------------------------------------------------------------
function WL.Build()
  local list = mine()
  if #list == 0 then return nil end
  local out = {}
  for i = 1, math.min(#list, WL.MAX) do
    local e = list[i]
    out[i] = { k = e.k, i = e.i, x = e.x, q = e.q, n = e.n, t = e.t }
  end
  return { e = out }
end

function WL.Validate(d)
  local V = ns.Shared.V
  if type(d) ~= "table" or type(d.e) ~= "table" then return nil end
  local out = {}
  for _, e in ipairs(d.e) do
    if #out >= WL.MAX then break end
    if type(e) == "table" and (e.k == "n" or e.k == "g") then
      local c = { k = e.k, i = e.i ~= nil and V.int(e.i, 1, 1e7) or nil,
                  q = V.int(e.q, 1, WL.QTY_MAX), t = V.time(e.t),
                  n = e.n ~= nil and V.str(e.n, WL.TEXT_MAX) or nil }
      if not c.i then c.x = V.str(e.x, WL.TEXT_MAX) end
      if c.q and c.t and (c.i or c.x) then out[#out + 1] = c end
    end
  end
  return { e = out }
end

---------------------------------------------------------------------------
-- reading
---------------------------------------------------------------------------
local function online(owner)
  if owner == ns.playerKey then return true end
  local row = ns.Roster and ns.Roster.byName[owner]
  return row and row.online or false
end
WL.IsOnline = online

function WL.Label(e)
  if e.i then
    local name = C.ItemInfo(e.i)
    return name or ("item:" .. e.i), name ~= nil
  end
  return e.x or "?", true
end

-- filter: "all" | "need" | "give" | "mine"; search matches item, note or name
function WL.All(filter, search)
  filter = filter or "all"
  search = trim(search):lower()
  local rows = {}
  local function add(owner, e, isMine)
    if filter == "need" and e.k ~= "n" then return end
    if filter == "give" and e.k ~= "g" then return end
    if filter == "mine" and not isMine then return end
    local label = WL.Label(e)
    if search ~= "" then
      local hay = (label .. " " .. (e.n or "") .. " " .. C.ShortName(owner)):lower()
      if not hay:find(search, 1, true) then return end
    end
    rows[#rows + 1] = { owner = owner, entry = e, kind = e.k, id = e.i, label = label, q = e.q, note = e.n,
                        t = e.t, mine = isMine, online = online(owner) }
  end
  for _, e in ipairs(mine()) do add(ns.playerKey or "", e, true) end
  for owner, d in ns.Shared.Each("wl") do
    if owner ~= ns.playerKey then
      for _, e in ipairs(d.e or {}) do add(owner, e, false) end
    end
  end
  table.sort(rows, function(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return a.owner < b.owner
  end)
  return rows
end

-- who needs / offers one item: { {owner, q} }, { {owner, q} }
function WL.ForItem(itemID)
  local needs, gives = {}, {}
  local function scan(owner, list)
    for _, e in ipairs(list or {}) do
      if e.i == itemID then
        local into = e.k == "n" and needs or gives
        into[#into + 1] = { owner = owner, q = e.q }
      end
    end
  end
  scan(ns.playerKey or "", mine())
  for owner, d in ns.Shared.Each("wl") do
    if owner ~= ns.playerKey then scan(owner, d.e) end
  end
  local function byName(a, b) return a.owner < b.owner end
  table.sort(needs, byName); table.sort(gives, byName)
  return needs, gives
end

local function who(list)
  local parts = {}
  for i = 1, math.min(#list, 3) do
    local o = list[i]
    local n = C.ShortName(o.owner)
    if online(o.owner) then n = "|cff7fe07f" .. n .. "|r" else n = "|cffffffff" .. n .. "|r" end
    parts[i] = o.q > 1 and (n .. (" (%d)"):format(o.q)) or n
  end
  local text = table.concat(parts, ", ")
  if #list > 3 then text = text .. (" +%d"):format(#list - 3) end
  return text
end
function WL.NeedLine(itemID)
  local needs = WL.ForItem(itemID)
  if #needs > 0 then return "Wanted in LOMB: " .. who(needs) end
end
function WL.GiveLine(itemID)
  local _, gives = WL.ForItem(itemID)
  if #gives > 0 then return "Offered in LOMB: " .. who(gives) end
end

-- Pre-filled whisper (you still press Enter yourself).
function WL.WhisperText(row)
  local link
  if row.id then link = select(2, C.ItemInfo(row.id)) end
  local what = link or row.label
  if row.kind == "n" then
    return ("/w %s Hi! I saw on the LOMB wishlist you need %s. "):format(C.ShortName(row.owner), what)
  end
  return ("/w %s Hi! Is %s from the LOMB wishlist still up for grabs? "):format(C.ShortName(row.owner), what)
end

function WL:Init()
  ns.Shared.Define({
    kind = "wl", label = "wishlist", debounce = 10,
    build = WL.Build, validate = WL.Validate,
    onChange = function() ns:Fire("WISHLIST_UPDATED") end,
  })
end

function WL:Login()
  if WL.Prune() > 0 then WL.Changed() end
  if ns.Tooltip then
    ns.Tooltip.AddLine(WL.NeedLine)
    ns.Tooltip.AddLine(WL.GiveLine)
  end
end
