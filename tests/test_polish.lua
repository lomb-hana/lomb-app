local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("UI polish (tooltips, resizing, scroll positions, empty states)")

local function setup(withData)
  local ns = H.boot()
  if withData then
    H.roster = {}
    for i = 1, 40 do
      H.roster[i] = { name = ("Member%02d-Forever"):format(i), rank = "Member", rankIndex = 3, level = 10 + i % 30,
        className = "Mage", class = "MAGE", zone = "Elwynn Forest", online = i % 2 == 0, days = i }
    end
    H.fire("GUILD_ROSTER_UPDATE"); H.advance(2, 1)
  end
  return ns
end

-- every visible button, checkbox and text box puts something in the tooltip when hovered
local function untipped()
  local gaps, tt = {}, GameTooltip
  for _, f in ipairs(H.frames) do
    local k = f.kind
    if (k == "Button" or k == "CheckButton" or k == "EditBox") and f:IsVisible() and f.scripts.OnEnter then
      local used, old = false, {}
      for _, m in ipairs({ "SetText", "AddLine", "SetHyperlink", "SetItemByID", "AddDoubleLine", "SetUnit" }) do
        old[m] = rawget(tt, m)
        tt[m] = function() used = true end
      end
      pcall(f.scripts.OnEnter, f)
      for m, fn in pairs(old) do tt[m] = fn end
      if not used then gaps[#gaps + 1] = (f.label and f.label.text) or (f.hint and f.hint.text) or k end
    elseif (k == "Button" or k == "CheckButton" or k == "EditBox") and f:IsVisible() and f.label
      and f.label.text ~= "" and not f.scripts.OnEnter then
      gaps[#gaps + 1] = f.label.text
    end
  end
  return gaps
end

for _, withData in ipairs({ false, true }) do
  H.test("every control in every tab has a tooltip (" .. (withData and "with data" or "empty") .. ")", function()
    local ns = setup(withData)
    ns.Bank.SetBankChar(true)
    for _, tab in ipairs(ns.UI.tabs) do
      ns.UI.Open(tab.id); H.advance(0.5, 0.5)
      local gaps = untipped()
      H.eq(#gaps, 0, tab.id .. ": no tooltip on " .. table.concat(gaps, ", "))
      for _, t in ipairs(ns.UI.tabs) do if t.panel then t.panel:Hide() end end
    end
    H.noErrors("tooltip sweep")
  end)
end

H.test("sidebar entries explain their tab", function()
  local ns = setup()
  ns.UI.Open("roster")
  for _, tab in ipairs(ns.UI.tabs) do
    H.ok(ns.UI.tabButtons[tab.id].tip, tab.id .. " has a sidebar tip")
  end
end)

H.test("the window resizes within bounds, remembers it, and resets", function()
  local ns = setup()
  ns.UI.Open("roster")
  local f = ns.UI.frame
  H.eq(f:GetWidth(), 780); H.eq(f:GetHeight(), 480)
  H.ok(ns.UI.grip and ns.UI.grip.scripts.OnMouseDown, "corner grip")
  f:SetSize(1000.4, 600)
  ns.UI.grip.scripts.OnMouseUp(ns.UI.grip, "LeftButton")
  H.deepEq(ns.db.settings.windowSize, { 1000, 600 })
  f:SetSize(5000, 100)                        -- out of bounds: clamped
  ns.UI.SaveSize()
  H.deepEq(ns.db.settings.windowSize, { ns.UI.MAX_W, ns.UI.MIN_H })
  f:SetSize(780, 480); ns.UI.SaveSize()
  H.eq(ns.db.settings.windowSize, nil, "the default size isn't stored")
  f:SetSize(900, 500); ns.UI.SaveSize()
  ns.UI.grip.scripts.OnClick(ns.UI.grip, "RightButton")
  H.eq(f:GetWidth(), 780); H.eq(ns.db.settings.windowSize, nil, "right-click resets")
  H.noErrors("resize")
end)

H.test("a saved size is applied when the window is built, clamped", function()
  local ns = H.boot()
  ns.db.settings.windowSize = { 1100, 9999 }
  ns.UI.Open("roster")
  H.eq(ns.UI.frame:GetWidth(), 1100); H.eq(ns.UI.frame:GetHeight(), ns.UI.MAX_H)
end)

H.test("pages follow the new width; the Quests mode row always fits", function()
  local ns = setup()
  ns.UI.Open("bestiary")
  local page = ns.UI.tabs[1].panel and nil
  for _, t in ipairs(ns.UI.tabs) do if t.id == "bestiary" then page = t.panel.page end end
  local w0 = page.width
  page.scripts.OnSizeChanged(page, 400)       -- the first size is the one it was built for
  H.eq(page.width, w0)
  local redrawn = 0
  local old = page.Rerender
  page.Rerender = function(self) redrawn = redrawn + 1; return old(self) end
  page.scripts.OnSizeChanged(page, 402)       -- tiny moves don't redraw
  H.advance(0.5, 0.1); H.eq(redrawn, 0)
  page.scripts.OnSizeChanged(page, 700)
  H.eq(page.width, w0 + 300)
  H.advance(0.5, 0.1); H.eq(redrawn, 1, "redrawn once after the drag settles")

  ns.UI.Open("quests")
  local qp
  for _, t in ipairs(ns.UI.tabs) do if t.id == "quests" then qp = t.panel end end
  for _, w in ipairs({ 642, 1142 }) do
    qp.scripts.OnSizeChanged(qp, w)
    local n, used = 0, 0
    for _, b in pairs(qp.modes) do n = n + 1; used = used + b:GetWidth() end
    used = used + 4 * (n - 1)
    H.ok(used <= w, ("mode buttons fit: %d of %d"):format(used, w))
    H.ok(used >= w - n, "and fill the row")
  end
  H.noErrors("reflow")
end)

H.test("lists keep their scroll on refresh and go to the top on a new filter", function()
  local ns = setup(true)
  ns.UI.Open("roster")
  local list
  for _, t in ipairs(ns.UI.tabs) do if t.id == "roster" then list = t.panel.list end end
  list.h = 200; list:Layout()
  list.offset = 10; list:Refresh()
  ns.UI.Refresh("roster")
  H.eq(list.offset, 10, "same view: same place")
  ns.RosterTab = ns.RosterTab
  local items = list.items
  list:SetItems(items, "something else")
  H.eq(list.offset, 0, "new view: top")
  list.offset = 5; list:SetItems(items)   -- no key: old behaviour (keep, clamp)
  H.eq(list.offset, 5)
end)

H.test("the bestiary page keeps its place for the same creature", function()
  local ns = setup()
  local page = ns.MobPage.New(UIParent, 400)
  page.scroll:SetVerticalScroll(120)
  page.lastNpc = 100
  ns.MobPage.Render(page, 100)
  H.eq(page.scroll:GetVerticalScroll(), 120)
  ns.MobPage.Render(page, 101)
  H.eq(page.scroll:GetVerticalScroll(), 0)
end)

H.test("the bestiary list says why it is empty", function()
  local ns = H.boot({ db = { settings = { theme = "clean", themeChosen = true } } })   -- the plain lines
  ns.UI.Open("bestiary")
  local p
  for _, t in ipairs(ns.UI.tabs) do if t.id == "bestiary" then p = t.panel end end
  H.ok(p.empty.shown and p.empty.text:find("Nothing here yet"), "fresh install: " .. tostring(p.empty.text))
  p.search:SetText("zzzz"); H.advance(1, 0.5)
  ns.UI.Refresh("bestiary")
  H.ok(p.empty.text:find("zzzz"), "search: " .. tostring(p.empty.text))
  H.noErrors("bestiary empty")
end)

H.test("a long sync status ends before /lomb", function()
  local ns = setup()
  ns.UI.Open("roster")
  local ft, anchored = ns.UI.footerText, false
  for _, pt in ipairs(ft.points) do if pt[1] == "RIGHT" and pt[2] == ns.UI.footerRight then anchored = true end end
  H.ok(anchored, "footer text stops at /lomb")
end)

H.test("faster bestiary counts match the full ones", function()
  local ns = H.boot()
  local B = ns.Bestiary
  for id = 1, 300 do
    local m = B.Ensure(id)
    m.nm = "Creature " .. id; m.lv = id % 60 + 1
    m.z[id % 3 == 0 and "Durotar" or "Elwynn Forest"] = true
    if id % 2 == 0 then m.rec["Other-Forever"] = { k = id % 4, s = id % 7, c = 1 } end
    if id % 5 == 0 then m.rec[ns.playerKey] = { k = 2, c = 2 } end
  end
  for _, it in ipairs(B.List("")) do
    local agg = B.Aggregate(ns.db.bestiary[it.npcId])
    local mine = ns.db.bestiary[it.npcId].rec[ns.playerKey]
    H.eq(it.kills, agg.kills); H.eq(it.seen, agg.seen); H.eq(it.mine, mine and mine.k or 0)
  end
  local zone = B.List("", { filter = "zone", zone = "Durotar" })
  local st = B.ZoneStats("Durotar")
  local killed, mine = 0, 0
  for _, it in ipairs(zone) do
    if it.kills > 0 then killed = killed + 1 end
    if it.mine > 0 then mine = mine + 1 end
  end
  H.eq(st.known, #zone); H.eq(st.killed, killed); H.eq(st.mine, mine)
  H.eq(#B.List("durotar"), #zone, "searching a zone name still works")
end)

H.done()
