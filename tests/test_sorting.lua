local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Sortable lists")

local function names(rows, k)
  local out = {}
  for _, r in ipairs(rows) do out[#out + 1] = tostring(r[k or "name"]) end
  return table.concat(out, ",")
end

H.test("SortRows: either direction, missing values last, case-insensitive, stable ties", function()
  local ns = H.boot()
  local W = ns.Widgets
  local rows = { { name = "b", n = 2 }, { name = "A", n = nil }, { name = "c", n = 2 }, { name = "d", n = 9 } }
  H.eq(names(W.SortRows(rows, "name")), "A,b,c,d")
  H.eq(names(W.SortRows(rows, "name", true)), "d,c,b,A")
  H.eq(names(W.SortRows(rows, "n", true, "name")), "d,b,c,A", "nil last, ties by name")
  H.eq(names(W.SortRows(rows, "n", false, "name")), "b,c,d,A", "nil last ascending too")
  H.eq(names(W.SortRows(rows, function(r) return #r.name end)), "b,c,d,A", "function keys, stable")
end)

H.test("SortHeader: click sorts, click again flips, arrow on the active column, tooltips", function()
  local ns = H.boot()
  local W = ns.Widgets
  local view, calls = { sort = "a", desc = false }, 0
  local head = W.SortHeader(UIParent, { { key = "a", label = "A", x = 0, w = 50 },
    { key = "b", label = "B", x = 60, w = 50, desc = true }, { key = "c", label = "C", right = 4, w = 40, justify = "RIGHT" } },
    view, function() calls = calls + 1 end)
  local a, b = head.buttons[1], head.buttons[2]
  H.ok(a.arrow:IsShown() and not b.arrow:IsShown())
  b:Click()
  H.eq(view.sort, "b"); H.eq(view.desc, true, "b starts high-to-low")
  H.ok(b.arrow:IsShown() and not a.arrow:IsShown())
  b:Click()
  H.eq(view.desc, false, "flipped")
  a:Click(); H.eq(view.sort, "a"); H.eq(view.desc, false)
  H.eq(calls, 3)
  for _, btn in ipairs(head.buttons) do H.ok(btn:GetScript("OnEnter"), "tooltip on " .. btn.col.label) end
end)

H.test("crafters sort by profession and by online crafters", function()
  local ns = H.boot()
  local Tab = ns.CraftersTab
  ns.Crafting.IsOnline = function(n) return n == "On1" or n == "On2" end
  local items = {
    { name = "Axe", prof = "Bs", crafters = { "Off1" } },
    { name = "Boots", prof = "Lw", crafters = { "On1", "Off1", "Off2" } },
    { name = "Cloak", prof = "Ta", crafters = { "On1", "On2" } },
  }
  local v = { sort = "crafters", desc = true }
  H.eq(names(Tab.SortItems(items, v)), "Cloak,Boots,Axe", "most online first")
  v.desc = false
  H.eq(names(Tab.SortItems(items, v)), "Axe,Boots,Cloak")
  v.sort, v.desc = "prof", false
  local byProf = names(Tab.SortItems(items, v))
  H.eq(byProf, "Axe,Boots,Cloak", "Blacksmithing, Leatherworking, Tailoring")
  v.sort, v.desc = "name", true
  H.eq(names(Tab.SortItems(items, v)), "Cloak,Boots,Axe")
end)

H.test("bank items sort by name, count and wanted", function()
  local ns = H.boot()
  H.itemNames[1], H.itemNames[2], H.itemNames[3] = "Linen Cloth", "Copper Ore", "Wool Cloth"
  local L = { items = { { id = 1, count = 40 }, { id = 2, count = 5 }, { id = 3, count = 120 } } }
  local B = ns.BankTab
  H.eq(names(B.BankItems(L, ""), "label"), "Copper Ore,Linen Cloth,Wool Cloth")
  H.eq(names(B.BankItems(L, "", "count", true), "label"), "Wool Cloth,Linen Cloth,Copper Ore")
  H.eq(names(B.BankItems(L, "", "label", true), "label"), "Wool Cloth,Linen Cloth,Copper Ore")
  H.eq(names(B.BankItems(L, "cloth", "count", false), "label"), "Linen Cloth,Wool Cloth", "search still applies")
end)

H.test("wishlist sorts by item, who, type and age", function()
  local ns = H.boot()
  local Tab = ns.WishTab
  local function rows()
    return { { label = "Zed", owner = "Bob-Forever", kind = "g", t = 3 }, { label = "apple", owner = "amy-Forever", kind = "n", t = 2 },
      { label = "Mid", owner = "Cat-Forever", kind = "n", t = 1 } }
  end
  H.eq(names(Tab.Sort(rows(), "t", true), "label"), "Zed,apple,Mid", "newest first, as given")
  H.eq(names(Tab.Sort(rows(), "t", false), "label"), "Mid,apple,Zed")
  H.eq(names(Tab.Sort(rows(), "label", false), "label"), "apple,Mid,Zed")
  H.eq(names(Tab.Sort(rows(), "who", false), "label"), "apple,Zed,Mid")
  H.eq(names(Tab.Sort(rows(), "kind", false), "label"), "apple,Mid,Zed", "needs first")
  H.eq(names(Tab.Sort(rows(), "kind", true), "label"), "Zed,apple,Mid")
end)

H.test("attendance sorts by name or presence; absent last; original order untouched", function()
  local ns = H.boot()
  local Tab = ns.EventsTab
  local rows = { { name = "Cat-Forever", present = true, pct = 50 }, { name = "amy-Forever", present = false, pct = 0 },
    { name = "Bob-Forever", present = true, pct = 100 } }
  H.eq(names(Tab.SortAtt(rows)), "Cat-Forever,amy-Forever,Bob-Forever", "no sort chosen: as recorded")
  Tab.attView.sort, Tab.attView.desc = "pct", true
  H.eq(names(Tab.SortAtt(rows)), "Bob-Forever,Cat-Forever,amy-Forever")
  Tab.attView.sort, Tab.attView.desc = "name", false
  H.eq(names(Tab.SortAtt(rows)), "amy-Forever,Bob-Forever,Cat-Forever")
  H.eq(rows[1].name, "Cat-Forever", "source list not reordered")
  Tab.attView.sort = nil
end)

H.test("every tab with a sort header still renders", function()
  local ns = H.boot()
  for _, id in ipairs({ "roster", "crafters", "wishlist", "events", "settings" }) do
    ns.UI.Open(id); H.advance(1)
  end
  H.noErrors("tabs")
end)

H.done()
