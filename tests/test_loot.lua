local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Loot browser (ForeverDB.net notable loot + guild-recorded drops)")

local DM = 36            -- Deadmines in the bundled snapshot
local VANCLEEF = 990036  -- a made-up npc id for the test bestiary

local function noErrors(what) H.eq(#H.errors, 0, what .. ": " .. tostring(H.errors[1])) end
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function tab(ns, id)
  for _, t in ipairs(ns.UI.tabs) do if t.id == id then return t end end
end
local function pageText(page)
  local out = {}
  for i = 1, page.used do out[#out + 1] = plain(page.lines[i].left.text) end
  return table.concat(out, "\n")
end
local function shownCells(page)
  local out = {}
  for _, c in ipairs(page.cells or {}) do if c.shown and c.data then out[#out + 1] = c end end
  return out
end
local function bossIndex(ns, name)
  for i, b in ipairs(ns.FDBData.dungeons[DM].b) do if b == name then return i end end
end

-- a guild bestiary with Van Cleef, a Deadmines trash mob and a mob outside
local function boot()
  local ns = H.boot()
  C_Item.GetItemInfo = function() return nil end
  ns.Loot.ResetIndex()
  ns.db.bestiary[VANCLEEF] = { nm = "Edwin VanCleef", z = { ["The Deadmines"] = true },
    rec = { ["Testy-Forever"] = { k = 3, c = 3, i = { [5193] = 1, [2874] = 2 } } } }
  ns.db.bestiary[990037] = { nm = "Defias Pirate", z = { ["The Deadmines"] = true },
    rec = { ["Testy-Forever"] = { k = 9, c = 8, i = { [2589] = 5 } }, ["Other-Forever"] = { c = 2, i = { [2589] = 1 } } } }
  ns.db.bestiary[990038] = { nm = "Defias Bandit", z = { ["Westfall"] = true },
    rec = { ["Testy-Forever"] = { c = 4, i = { [2589] = 3 } } } }
  return ns
end

H.test("nothing is indexed at load; keys round-trip", function()
  local ns = H.boot()
  H.ok(not ns.Loot.IndexBuilt(), "no instance index at login")
  local L = ns.Loot
  H.eq(L.Key(DM), DM); H.eq(L.Key(DM, "all"), DM)
  H.eq(L.Key(DM, "trash"), DM .. ":trash"); H.eq(L.Key(DM, 8), DM .. ":b:8")
  local d, p = L.ParseKey(DM .. ":b:8"); H.eq(d, DM); H.eq(p, 8)
  d, p = L.ParseKey(DM .. ":trash"); H.eq(d, DM); H.eq(p, "trash")
  d, p = L.ParseKey(DM); H.eq(d, DM); H.eq(p, "all")
  H.eq(L.InstanceForZone("The Deadmines"), DM)
  H.eq(L.InstanceForZone("Deadmines"), DM)
  H.eq(L.InstanceForZone("Westfall"), nil)
  H.ok(L.IndexBuilt(), "built on first use")
  local bd, bi = L.FindBoss("van cleef")
  H.eq(bd, DM); H.eq(ns.FDBData.dungeons[DM].b[bi], "Edwin VanCleef")
  noErrors("keys")
end)

H.test("whole dungeon: ForeverDB picks first, guild drops kept apart, counts summed", function()
  local ns = boot()
  local r = ns.Loot.For(DM, "all")
  H.eq(r.notable, #ns.FDBData.dungeons[DM].lo, "every notable pick")
  for i = 1, r.notable do H.ok(r.items[i].notable, "notable first") end
  local by = {}
  for _, e in ipairs(r.items) do by[e.itemID] = e end
  H.eq(by[5193].seen, 1, "notable item the guild also saw")
  H.ok(by[5193].notable)
  H.eq(by[2589].seen, 6, "trash drop, both recorders, not the Westfall mob")
  H.ok(not by[2589].notable)
  H.eq(r.mobs, 2); H.eq(r.corpses, 13)
  H.eq(r.guildOnly, 2, "2874 + 2589 are guild-only")
  noErrors("all")
end)

H.test("boss and trash views; extension hooks", function()
  local ns = boot()
  local L = ns.Loot
  local vc = bossIndex(ns, "Edwin VanCleef")
  local b = L.For(DM, vc)
  H.eq(b.notable, 0, "ForeverDB picks aren't tied to a boss")
  H.eq(#b.items, 2); H.eq(b.mobs, 1)
  H.eq(L.BossMob(DM, vc), VANCLEEF)
  local t = L.For(DM, "trash")
  H.eq(#t.items, 1); H.eq(t.items[1].itemID, 2589)
  L.AddBadge(function(itemID) if itemID == 2589 then return "SR 2" end end)
  L.AddSource(function(did, part) if did == DM and part == "trash" then return { { itemID = 9999, note = "test" } } end end)
  H.eq(L.Badges(2589, DM)[1], "SR 2")
  H.eq(#L.For(DM, "trash").items, 2, "source adds an item")
  L.badges, L.sources = {}, {}
  noErrors("parts")
end)

H.test("where an item drops: notable + guild-recorded boss", function()
  local ns = boot()
  local w = ns.Loot.WhereDrops(5193)
  H.eq(#w, 1); H.eq(w[1].did, DM); H.ok(w[1].notable); H.eq(w[1].seen, 1)
  H.eq(w[1].boss, "Edwin VanCleef")
  H.eq(w[1].key, ns.Loot.Key(DM, bossIndex(ns, "Edwin VanCleef")))
  local g = ns.Loot.WhereDrops(2589)
  H.eq(#g, 1); H.ok(not g[1].notable); H.eq(g[1].seen, 6)
  H.eq(#ns.Loot.WhereDrops(123456789), 0)
  noErrors("where")
end)

H.test("the Loot view: tree, icon grid, counts, credit, heart", function()
  local ns = boot()
  local Tab = ns.QuestsTab
  Tab.Show("dungeons", DM)
  local p = tab(ns, "quests").panel
  local rows = Tab.Items()
  local kids = 0
  for _, r in ipairs(rows) do if r.indent then kids = kids + 1 end end
  H.eq(kids, #ns.FDBData.dungeons[DM].b + 1, "bosses + trash under the open dungeon")
  local txt = pageText(p.page)
  H.ok(txt:find("Notable loot", 1, true) and txt:find("not the full loot table", 1, true), "labelled notable loot")
  H.ok(txt:find("Seen dropping by LOMB", 1, true))
  H.ok(txt:find("Data from ForeverDB.net", 1, true) and txt:find("https://foreverdb.net", 1, true), "credit")
  local cells = shownCells(p.page)
  H.eq(#cells, 5, "3 notable + 2 guild-only")
  local seen
  for _, c in ipairs(cells) do if c.data.item == 2589 then seen = c end end
  H.eq(seen.data.count, "6")
  H.ok(table.concat(seen.data.tip, "\n"):find("LOMB saw it drop: 6", 1, true))
  -- heart: onto the need list and off again
  H.ok(not ns.Loot.Wanted(2589))
  seen.data.onWant(seen.data)
  H.ok(ns.Loot.Wanted(2589), "on the wishlist")
  local e = ns.Loot.WishEntry(2589)
  H.eq(e.k, "n"); H.eq(e.n, "Deadmines")
  for _, c in ipairs(shownCells(p.page)) do if c.data.item == 2589 then H.ok(c.data.wanted, "heart lit") end end
  ns.Loot.ToggleWant(2589)
  H.ok(not ns.Loot.Wanted(2589), "off again")
  -- a boss page, then a page with no grid hides the old cells
  Tab.Show("dungeons", ns.Loot.Key(DM, bossIndex(ns, "Edwin VanCleef")))
  H.eq(#shownCells(p.page), 2)
  H.ok(pageText(p.page):find("Open Edwin VanCleef in the Bestiary", 1, true))
  Tab.Show("quests", 33)
  H.eq(#shownCells(p.page), 0, "grid cleared on other pages")
  -- quality filter
  Tab.view.lootQ = 4
  Tab.Show("dungeons", ns.Loot.Key(DM, "trash"))
  H.ok(pageText(p.page):find("Nothing at this quality", 1, true))
  Tab.view.lootQ = 1
  noErrors("view")
end)

H.test("old dungeon links, item pages and the Bestiary boss link open the browser", function()
  local ns = boot()
  local p
  ns.QuestsTab.Show("items", 5193)
  p = tab(ns, "quests").panel
  local txt = pageText(p.page)
  H.ok(txt:find("Where it drops", 1, true) and txt:find("LOMB saw it drop: 1", 1, true), "item page")
  local m = ns.Providers.Merge(VANCLEEF, {})
  H.eq(m.sections.boss.data.loot, ns.Loot.Key(DM, bossIndex(ns, "Edwin VanCleef")), "bestiary boss -> loot grid")
  -- Onyxia's Lair is bundled for the December 9 raids
  local ony
  for id, dg in pairs(ns.FDBData.dungeons) do if dg.n == "Onyxia's Lair" then ony = id; H.eq(dg.k, "raid") end end
  H.ok(ony, "raid bundled")
  ns.QuestsTab.Show("dungeons", ony)
  H.ok(pageText(p.page):find("no notable loot", 1, true))
  noErrors("links")
end)

H.test("Ask LOMB: what drops in X, what does a boss drop, where does an item drop", function()
  local ns = boot()
  ns.Ask.ResetIndex()
  local function txt(a) local o = {} for _, l in ipairs(a.lines) do o[#o + 1] = plain(l.text) end return table.concat(o, "\n") end
  local function linkTo(a) for _, l in ipairs(a.lines) do if l.link and l.link[1] == "dungeons" then return l.link[2] end end end
  local a = ns.Ask.Answer("what drops in deadmines")
  H.ok(txt(a):find("Loot in Deadmines", 1, true), txt(a))
  H.ok(txt(a):find("Notable loot", 1, true) and txt(a):find("LOMB saw drop", 1, true), txt(a))
  H.eq(linkTo(a), DM)
  a = ns.Ask.Answer("what does van cleef drop")
  H.ok(txt(a):find("Edwin VanCleef (Deadmines)", 1, true), txt(a))
  H.eq(linkTo(a), ns.Loot.Key(DM, bossIndex(ns, "Edwin VanCleef")))
  local name = ns.FDB.ItemName(5193)
  a = ns.Ask.Answer("where does " .. name .. " drop")
  H.ok(txt(a):find("Notable loot in Deadmines", 1, true), txt(a))
  H.ok(linkTo(a), "links into the browser")
  noErrors("ask")
end)

H.done()
