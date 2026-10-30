local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Quests & Items (bundled ForeverDB.net snapshot)")

local function noErrors(what) H.eq(#H.errors, 0, what .. ": " .. tostring(H.errors[1])) end

local function tab(ns, id)
  for _, t in ipairs(ns.UI.tabs) do if t.id == id then return t end end
end

-- every text a detail page currently shows, joined
local function pageText(page)
  local out = {}
  for i = 1, page.used do
    local l = page.lines[i]
    out[#out + 1] = tostring(l.left.text or "") .. " " .. tostring(l.right.text or "")
  end
  return table.concat(out, "\n")
end

local function hasLine(page, needle)
  return pageText(page):find(needle, 1, true) ~= nil
end

H.test("data files load with the credit header and a snapshot", function()
  local ns = H.boot()
  local D = ns.FDBData
  H.ok(D and ns.FDB.Available(), "data loaded")
  H.ok(D.snapshot:match("^%d%d%d%d%-%d%d%-%d%d$"), "snapshot date")
  local n = 0
  for _ in pairs(D.quests) do n = n + 1 end
  H.ok(n > 1000, "quests bundled: " .. n)
  for _, f in ipairs({ "Core", "Items", "Quests", "Vendors", "Recipes", "Dungeons" }) do
    local fh = assert(io.open(H.addonDir .. "Data/ForeverDB/" .. f .. ".lua"))
    local first = fh:read("*l"); fh:close()
    H.ok(first:find("Data from ForeverDB.net (https://foreverdb.net), used with permission. "
      .. "Not covered by this project's MIT license.", 1, true), f .. " header")
  end
  for _, q in pairs(D.quests) do H.ok(q.l <= 30, "quest level <= 30") end
  noErrors("load")
end)

H.test("quest lookups: list filters, NPC index, chains", function()
  local ns = H.boot()
  local FDB = ns.FDB
  local q = FDB.Quest(33)
  H.eq(q.n, "Wolves Across the Border")
  H.eq(q.z, "Elwynn Forest")
  local inZone = FDB.QuestList({ zone = "Elwynn Forest", side = "A" })
  H.ok(#inZone > 10)
  for i = 2, #inZone do H.ok(inZone[i - 1].q.l <= inZone[i].q.l, "sorted by level") end
  for _, e in ipairs(inZone) do H.ok(e.q.s ~= "H", "no Horde-only quests for Alliance") end
  local band = FDB.QuestList({ minLevel = 21, maxLevel = 30 })
  for _, e in ipairs(band) do H.ok(e.q.l >= 21 and e.q.l <= 30) end
  local found = FDB.QuestList({ search = "wolves across" })
  H.eq(found[1].id, 33)
  local starts = FDB.QuestsForNpc(q.st[2])
  local has33 = false
  for _, id in ipairs(starts) do if id == 33 then has33 = true end end
  H.ok(has33, "quest giver index")
  H.eq(FDB.PlayerSide(), "A")
  H.state.faction = "Horde"
  H.eq(FDB.PlayerSide(), "H")
end)

H.test("item, vendor, recipe and dungeon lookups agree with each other", function()
  local ns = H.boot()
  local FDB = ns.FDB
  local D = ns.FDBData
  -- a vendor item points back to its vendor
  local vid, v = next(D.vendors)
  while v and not v.i do vid, v = next(D.vendors, vid) end
  H.ok(v, "a vendor with items")
  local facts = FDB.ItemFacts(v.i[1])
  local back = false
  for _, s in ipairs(facts.soldBy) do if s.vendor == vid then back = true end end
  H.ok(back, "soldBy index")
  -- every bundled vendor was seen in Forever (Classic-only vendors are left out)
  H.ok(#FDB.VendorList({}) > 100)
  -- recipes: a made item finds its recipe; reagents index
  local list = FDB.RecipeList({ prof = "alchemy", maxSkill = 75 })
  H.ok(#list > 3)
  for _, e in ipairs(list) do H.ok((e.r.sk[1] or 0) <= 75) end
  local r = list[1].r
  if r.mk then H.eq(FDB.RecipeForItem(r.mk).n, FDB.RecipeForItem(r.mk).n) end
  if r.rg then H.ok(#FDB.ItemFacts(r.rg[1]).reagentFor > 0) end
  for _, e in ipairs(FDB.RecipeList({})) do H.ok((e.r.sk[1] or 0) <= 225, "skill cap") end
  -- dungeons sorted by level, bosses map back
  local dl = FDB.DungeonList("")
  H.ok(#dl >= 5)
  local first = dl[1].d
  if first.b then H.ok(FDB.DungeonForBoss(first.b[1]) == dl[1].id) end
end)

H.test("item tooltip line carries the credit and respects the setting", function()
  local ns = H.boot()
  local FDB = ns.FDB
  local vid, v = next(ns.FDBData.vendors)
  while v and not v.i do vid, v = next(ns.FDBData.vendors, vid) end
  local line = FDB.TooltipLine(v.i[1])
  H.ok(line and line:find("Data from ForeverDB.net, https://foreverdb.net", 1, true), tostring(line))
  ns.db.settings.fdbTooltips = false
  H.eq(FDB.TooltipLine(v.i[1]), nil)
  local lines = {}
  GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
  ns.db.settings.fdbTooltips = true
  ns.db.settings.tooltips = true
  GameTooltip.GetItem = function() return "x", ("|cffffffff|Hitem:%d::|h[x]|h|r"):format(v.i[1]) end
  H.now = H.now + 5
  GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
  local seen = false
  for _, l in ipairs(lines) do if tostring(l):find("ForeverDB.net", 1, true) then seen = true end end
  H.ok(seen, "tooltip shows the ForeverDB line")
  noErrors("tooltip")
end)

H.test("Quests & Items tab: every view renders, shows the credit and the link", function()
  local ns = H.boot()
  SlashCmdList.LOMB("quests")
  H.eq(ns.UI.current, "quests")
  local t = tab(ns, "quests")
  local p = t.panel
  H.ok(p, "tab built")
  H.eq(p.credit.text, "Data from ForeverDB.net")
  H.eq(p.url:GetText(), "https://foreverdb.net")
  H.ok(p.snap.text:find(ns.FDBData.snapshot, 1, true))
  for _, m in ipairs(ns.QuestsTab.MODES) do
    ns.QuestsTab.Show(m.key)
    H.advance(1)
    H.ok(#p.list.items > 0, m.key .. " list has rows")
    H.ok(p.page.key ~= nil, m.key .. " auto-selects the first row")
    H.ok(hasLine(p.page, "Data from ForeverDB.net"), m.key .. " detail credit")
    H.ok(hasLine(p.page, "https://foreverdb.net"), m.key .. " detail link")
  end
  noErrors("views")
end)

H.test("quest page: giver, turn-in, chain links and Classic label", function()
  local ns = H.boot()
  ns.QuestsTab.Show("quests", 33)
  local p = tab(ns, "quests").panel
  H.eq(p.page.key, 33)
  H.ok(hasLine(p.page, "Wolves Across the Border"))
  H.ok(hasLine(p.page, "Eagan Peltskinner"))
  H.ok(hasLine(p.page, "Elwynn Forest (49, 40)"))
  H.ok(hasLine(p.page, "foreverdb.net/quest/33"))
  -- follow a chain link, then go back
  local nextId = ns.FDB.NextQuests(33)[1]
  if nextId then
    for i = 1, p.page.used do
      local l = p.page.lines[i]
      if tostring(l.left.text):find(ns.FDB.Quest(nextId).n, 1, true) and l.scripts and l.scripts.OnMouseUp then
        l.scripts.OnMouseUp(l, "LeftButton")
        break
      end
    end
    H.eq(p.page.key, nextId)
    H.ok(p.back.shown, "back button")
    ns.QuestsTab.Back()
    H.eq(p.page.key, 33)
  end
  -- a Classic-sourced quest says so
  for id, q in pairs(ns.FDBData.quests) do
    if q.c then
      ns.QuestsTab.Show("quests", id)
      H.ok(hasLine(p.page, "Classic data"), "classic label")
      break
    end
  end
  -- filters cycle without errors and "near my level" uses the player's level
  ns.QuestsTab.Show("quests")
  ns.QuestsTab.view.level = 1
  ns.UI.Refresh("quests")
  for _, row in ipairs(p.list.items) do
    local q = ns.FDB.Quest(row.key)
    H.ok(q.l >= 9 and q.l <= 15, "near level 12")
  end
  p.f1.scripts.OnClick(p.f1, "LeftButton")
  H.ok(ns.QuestsTab.view.zone)
  for _, row in ipairs(p.list.items) do H.eq(ns.FDB.Quest(row.key).z, "Elwynn Forest") end
  p.f2.scripts.OnClick(p.f2, "RightButton")
  p.f3.scripts.OnClick(p.f3, "LeftButton")
  noErrors("quest page")
end)

H.test("bestiary links: quest givers show their quests, bosses link their dungeon", function()
  local ns = H.boot()
  local P = ns.Providers
  H.ok(P.Has("foreverdb"), "provider registered")
  local q = ns.FDB.Quest(33)
  ns.db.bestiary[q.st[2]] = { nm = q.st[3] }
  local m = P.Merge(q.st[2], {})
  H.ok(m.sections.quests, "quests section")
  local any = false
  for _, e in ipairs(m.sections.quests.data) do if e.id == 33 then any = true end end
  H.ok(any)
  -- a boss of a bundled dungeon
  for did, dg in pairs(ns.FDBData.dungeons) do
    if dg.b then
      ns.db.bestiary[990001] = { nm = dg.b[1] }
      local mb = P.Merge(990001, {})
      H.ok(mb.sections.boss and mb.sections.boss.data.dungeon == did, "boss -> dungeon")
      break
    end
  end
  noErrors("bestiary")
end)

H.test("credits tab names ForeverDB with the support link", function()
  local ns = H.boot()
  SlashCmdList.LOMB("credits")
  local p = tab(ns, "credits").panel
  H.ok(p.fdb.text:find("Data from ForeverDB.net", 1, true))
  H.ok(p.fdb.text:find("https://buymeacoffee.com/foreverdb", 1, true))
  H.ok(p.fdb.text:find("keeps this project alive", 1, true))
  H.eq(p.fdbUrl:GetText(), "https://foreverdb.net")
  H.eq(p.supportUrl:GetText(), "https://buymeacoffee.com/foreverdb")
  noErrors("credits")
end)

H.test("recipe trainers: own faction first, the other faction marked", function()
  local ns = H.boot()
  local FDB = ns.FDB
  H.eq(FDB.NpcSide({ s = "B", z = "Orgrimmar" }), "H", "capital zone sets side")
  H.eq(FDB.NpcSide({ s = "B", z = "Stranglethorn Vale" }), "B", "contested stays both")
  H.eq(FDB.NpcSide({ s = "A", z = "Orgrimmar" }), "A", "explicit side wins")
  local ref = FDB.Index().madeBy[2568] and FDB.Index().madeBy[2568][1]
  H.ok(ref, "Brown Linen Vest has a recipe")
  ns.QuestsTab.Show("recipes", ref.prof .. ":" .. ref.i)
  local txt = pageText(tab(ns, "quests").panel.page)
  local firstOther = txt:find("(other faction)", 1, true)
  local own = txt:find("Darnassus", 1, true)
  H.ok(own and firstOther and own < firstOther, "Alliance trainer listed before Horde ones")
  noErrors("recipe faction")
end)

H.done()
