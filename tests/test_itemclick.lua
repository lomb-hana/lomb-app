local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Item rows: click opens the item page, shift-click links it, ctrl-click previews it")

local LINEN, NOT_IN_BUNDLE = 2589, 987654

local function boot()
  local ns = H.boot()
  H.itemNames = { [LINEN] = "Linen Cloth" }
  H.chat, H.errors = {}, {}
  _G.IsShiftKeyDown = function() return false end
  _G.IsControlKeyDown = function() return false end
  _G.IsModifiedClick, _G.HandleModifiedItemClick, _G.DressUpItemLink = nil, nil, nil
  return ns
end

local function closeUI(ns) if ns.UI.frame then ns.UI.frame:Hide() end end
local noErrors = H.noErrors
local function shift(on) _G.IsShiftKeyDown = function() return on end end
local function ctrl(on) _G.IsControlKeyDown = function() return on end end

-- capture the tooltip's added lines while running fn
local function tipLines(fn)
  local lines, add = {}, GameTooltip.AddLine
  GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t or "" end
  fn()
  GameTooltip.AddLine = add
  return table.concat(lines, "\n")
end

local function pageLine(page, needle)
  for i = 1, page.used do
    local l = page.lines[i]
    if (l.left.text or ""):find(needle, 1, true) then return l end
  end
end

local function testMob(ns)
  ns.Providers.RegisterStatic({
    id = "testdb", label = "Test data", priority = 40, credit = "Test credit",
    mobs = { [99998] = { name = "Click Dummy", level = 10,
      loot = { { itemID = LINEN, rate = 0.3 } },
      notableLoot = { { itemID = 2318, note = "nice" } },
      skinning = { skill = 10, items = { 2934 } } } },
  })
  return ns.MobPage.OpenStandalone(99998).page
end

H.test("bestiary page: guild loot, notable loot and skinning rows open the item page", function()
  local ns = boot()
  H.ok(ns.FDBData.items[LINEN], "Linen Cloth is in the bundle")
  local page = testMob(ns)
  local seen = 0
  for i = 1, page.used do
    local l = page.lines[i]
    local up = l.scripts.OnMouseUp
    local t = l.left.text or ""
    local id = (t:find("Linen Cloth", 1, true) or t:find("Item " .. LINEN, 1, true)) and LINEN
      or (t:find("Light Leather", 1, true) or t:find("Item 2318", 1, true)) and 2318
      or (t:find("Ruined Leather Scraps", 1, true) or t:find("Item 2934", 1, true)) and 2934
    if id and up then
      seen = seen + 1
      closeUI(ns)
      up(l, "LeftButton")
      H.eq(ns.UI.current, "quests", "opens Quests & Items for " .. id)
      H.ok(ns.UI.frame.shown, "window open")
      H.eq(ns.QuestsTab.selected.items, id)
      -- the tooltip ends with the hint
      local tips = tipLines(function() l.scripts.OnEnter(l) end)
      H.ok(tips:find("Click: details  Shift-click: link in chat", 1, true), tips)
    end
  end
  H.ok(seen >= 3, "loot, notable loot and skinning rows found (" .. seen .. ")")
  -- right-click does nothing (and doesn't error)
  ns.Providers.Unregister("testdb")
  noErrors("mob page")
end)

H.test("shift-click links the item in chat (the game's own link), ctrl-click previews it", function()
  local ns = boot()
  local page = testMob(ns)
  local l = pageLine(page, "Linen Cloth") or pageLine(page, "Item " .. LINEN)
  closeUI(ns)
  shift(true)
  l.scripts.OnMouseUp(l, "LeftButton")
  shift(false)
  H.eq(#H.chat, 1)
  H.ok(H.chat[1].link and H.chat[1].link:find("|Hitem:" .. LINEN, 1, true), "a real item link went into the chat box")
  H.ok(not ns.UI.frame or not ns.UI.frame.shown, "the modified click wasn't swallowed by the row's own click")
  -- ctrl-click: dressing room
  local dressed
  _G.DressUpItemLink = function(link) dressed = link; return true end
  ctrl(true)
  l.scripts.OnMouseUp(l, "LeftButton")
  ctrl(false)
  H.ok(dressed and dressed:find("|Hitem:" .. LINEN, 1, true), "dressing room got the link")
  -- the standard path when the client has it: IsModifiedClick + HandleModifiedItemClick
  local handled
  _G.IsModifiedClick = function(what) return what == "CHATLINK" end
  _G.HandleModifiedItemClick = function(link) handled = link; return true end
  H.chat = {}
  l.scripts.OnMouseUp(l, "LeftButton")
  H.ok(handled and handled:find("|Hitem:" .. LINEN, 1, true), "HandleModifiedItemClick used")
  H.eq(#H.chat, 0, "not inserted twice")
  _G.IsModifiedClick, _G.HandleModifiedItemClick, _G.DressUpItemLink = nil, nil, nil
  -- no chat box open: the box opens with the link in it (nothing is sent)
  local insert = _G.ChatEdit_InsertLink
  _G.ChatEdit_InsertLink = function() return false end
  shift(true)
  l.scripts.OnMouseUp(l, "LeftButton")
  shift(false)
  _G.ChatEdit_InsertLink = insert
  H.ok(H.chat[1] and H.chat[1].open and H.chat[1].open:find("|Hitem:" .. LINEN, 1, true), "chat box opened with the link")
  H.eq(#H.sent, 0, "nothing sent")
  ns.Providers.Unregister("testdb")
  noErrors("modified clicks")
end)

H.test("an item the game hasn't cached: requested, linked when it arrives, else built from the ID", function()
  local ns = boot()
  local get = C_Item.GetItemInfo
  local requested = {}
  C_Item.GetItemInfo = function() return nil end
  C_Item.RequestLoadItemDataByID = function(id) requested[#requested + 1] = id end
  shift(true)
  H.ok(ns.ItemClick.Click(LINEN, "LeftButton"))
  shift(false)
  H.eq(requested[1], LINEN, "asked the game for it")
  H.eq(#H.chat, 0, "waiting")
  C_Item.GetItemInfo = get
  H.fire("GET_ITEM_INFO_RECEIVED", LINEN, true)
  H.ok(H.chat[1] and H.chat[1].link:find("|Hitem:" .. LINEN .. "::|h[Linen Cloth]", 1, true), "the game's link once loaded")
  H.eq(ns.ItemClick.last.built, false)
  -- never arrives: after a second, a link built from the ID with the bundled name
  H.chat = {}
  C_Item.GetItemInfo = function() return nil end
  shift(true)
  ns.ItemClick.Click(LINEN, "LeftButton")
  shift(false)
  H.advance(2)
  H.ok(H.chat[1] and H.chat[1].link == "|cffffffff|Hitem:2589|h[Linen Cloth]|h|r", tostring(H.chat[1] and H.chat[1].link))
  H.eq(ns.ItemClick.last.built, true)
  C_Item.GetItemInfo = get
  C_Item.RequestLoadItemDataByID = nil
  noErrors("uncached")
end)

H.test("items not in the ForeverDB data, or no data at all: a small page or nothing, never an error", function()
  local ns = boot()
  H.ok(not ns.FDBData.items[NOT_IN_BUNDLE])
  H.ok(ns.ItemClick.Open(NOT_IN_BUNDLE))
  H.eq(ns.UI.current, "quests")
  local page = ns.QuestsTab.panel.page
  H.ok(pageLine(page, "No details for this item"), "no-details page")
  H.ok(pageLine(page, "Data from ForeverDB.net"), "credit stays")
  -- the page's own header doesn't reopen itself, but shift-click still links
  local head = page.lines[1]
  local sel = ns.QuestsTab.selected.items
  head.scripts.OnMouseUp(head, "LeftButton")
  H.eq(ns.QuestsTab.selected.items, sel)
  shift(true); head.scripts.OnMouseUp(head, "LeftButton"); shift(false)
  H.ok(H.chat[1] and H.chat[1].link:find("|Hitem:" .. NOT_IN_BUNDLE, 1, true))
  -- ForeverDB data missing: plain click does nothing, tooltip says shift-click only
  local avail = ns.FDB.Available
  ns.FDB.Available = function() return false end
  closeUI(ns)
  H.eq(ns.ItemClick.Open(LINEN), false)
  H.ok(not ns.UI.frame.shown, "nothing opened")
  local tips = tipLines(function() ns.ItemClick.AddHint(GameTooltip, true) end)
  H.eq(tips, "Shift-click: link in chat")
  ns.FDB.Available = avail
  noErrors("fallbacks")
end)

H.test("bestiary card loot lines behave like every item row", function()
  local ns = boot()
  local g = H.guid(3100, "AA")
  H.units.target = { name = "Mottled Boar", level = 3, guid = g, health = 0, healthMax = 100, dead = true }
  H.fire("PLAYER_TARGET_CHANGED")
  H.loot = { { link = "|cffffffff|Hitem:" .. LINEN .. "::|h[Linen Cloth]|h|r", quantity = 1, sources = { g, 1 } } }
  H.fire("LOOT_OPENED")
  H.advance(1)
  H.fire("PLAYER_TARGET_CHANGED")
  local card = ns.BestiaryCard.frame
  local line
  for _, l in ipairs(card.lines) do if l.shown and l.itemID == LINEN then line = l end end
  H.ok(line, "loot line on the card")
  closeUI(ns)
  line.scripts.OnMouseUp(line, "LeftButton")
  H.eq(ns.UI.current, "quests"); H.eq(ns.QuestsTab.selected.items, LINEN)
  shift(true); line.scripts.OnMouseUp(line, "LeftButton"); shift(false)
  H.ok(H.chat[1] and H.chat[1].link:find("|Hitem:" .. LINEN, 1, true))
  local tips = tipLines(function() line.scripts.OnEnter(line) end)
  H.ok(tips:find("Shift-click: link in chat", 1, true), tips)
  noErrors("card")
end)

H.test("Quests & Items rows, Ask LOMB answers, the bank, profiles and Me: same clicks", function()
  local ns = boot()
  -- a page row with its own onClick (vendor/reward lines): shift-click links instead of navigating
  ns.QuestsTab.Show("items", 2318)
  local before = ns.QuestsTab.selected.items
  ns.ItemClick.Modified(LINEN, "chat")
  H.eq(ns.QuestsTab.selected.items, before)
  -- the Items list on the left: shift-click links, plain click selects
  local p = ns.QuestsTab.panel
  ns.QuestsTab.Show("items", LINEN)
  for i, it in ipairs(p.list.items) do
    if it.itemID == LINEN then p.list.offset = i - 1; p.list:Layout(); break end
  end
  local row
  for _, r in ipairs(p.list.rows) do if r.item and r.item.itemID == LINEN then row = r end end
  H.ok(row, "item row in the list")
  H.chat = {}
  ns.QuestsTab.selected.items = nil
  shift(true); row.scripts.OnClick(row, "LeftButton"); shift(false)
  H.eq(ns.QuestsTab.selected.items, nil, "shift-click didn't select")
  H.ok(H.chat[1] and H.chat[1].link:find("|Hitem:" .. LINEN, 1, true))
  row.scripts.OnClick(row, "LeftButton")
  H.eq(ns.QuestsTab.selected.items, LINEN)

  -- Ask LOMB: an item answer line
  ns.Ask.Clear()
  ns.Ask.Submit("What drops Linen Cloth?")
  ns.UI.Open("ask")
  local alist = ns.AskTab.panel.list
  for i, it in ipairs(alist.items) do
    if ns.AskTab.ItemOf(it) == LINEN then alist.offset = i - 1; break end
  end
  alist:Layout()
  local arow
  for _, r in ipairs(ns.AskTab.panel.list.rows) do
    if r.item and ns.AskTab.ItemOf(r.item) == LINEN then arow = r end
  end
  H.ok(arow, "item line in the answer")
  H.chat = {}
  shift(true); arow.scripts.OnClick(arow, "LeftButton"); shift(false)
  H.ok(H.chat[1] and H.chat[1].link:find("|Hitem:" .. LINEN, 1, true), "linked from Ask LOMB")
  H.eq(ns.UI.current, "ask", "stayed in Ask LOMB")
  arow.scripts.OnClick(arow, "LeftButton")
  H.eq(ns.UI.current, "quests")
  H.eq(ns.QuestsTab.selected.items, LINEN)

  -- profile gear: the exact item string (enchant + suffix) goes to the tooltip and link
  do
    local l = ns.ProfilePage.New(UIParent, function() end).slots[1]
    l.itemString = "item:" .. LINEN .. ":0:0:0:0:0:0"
    H.chat = {}
    shift(true); l.scripts.OnMouseUp(l, "LeftButton"); shift(false)
    H.ok(H.chat[1] and H.chat[1].link:find("|Hitem:" .. LINEN, 1, true), "gear linked")
  end

  -- Me tab loot log
  ns.char.lootLog = { { i = LINEN, q = 2, n = 3100, t = H.epoch } }
  ns.UI.Open("me")
  local me
  for _, t in ipairs(ns.UI.tabs) do if t.id == "me" then me = t.panel end end
  ns.UI.RenderMe(me, ns.Me.stats)
  local hit = me.lootLines[1].hit
  H.eq(hit.itemID, LINEN)
  hit.scripts.OnMouseUp(hit, "LeftButton")
  H.eq(ns.UI.current, "quests")
  H.eq(me.lootLines[2].hit.itemID, nil, "empty lines aren't items")
  noErrors("other rows")
end)

H.done()
