local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Guides: training, gathering, disenchanting, sets, poisons, zones, battlegrounds")

local function noErrors(what) H.eq(#H.errors, 0, what .. ": " .. tostring(H.errors[1])) end

local function pageText(page)
  local out = {}
  for i = 1, page.used do
    local l = page.lines[i]
    out[#out + 1] = tostring(l.left.text or "") .. " " .. tostring(l.right.text or "")
  end
  return table.concat(out, "\n")
end
local function has(page, needle) return pageText(page):find(needle, 1, true) ~= nil end
local function panel(ns)
  for _, t in ipairs(ns.UI.tabs) do if t.id == "quests" then return t.panel end end
end
local function credited(page, what)
  H.ok(has(page, "Data from ForeverDB.net"), what .. ": credit")
  H.ok(has(page, "https://foreverdb.net"), what .. ": link")
end

H.test("class data: 9 classes, ranks up to 30, rank 0 for unranked abilities", function()
  local ns = H.boot()
  local G = ns.Guides
  H.eq(#G.ClassList(), 9)
  for _, c in ipairs(G.ClassList()) do
    for _, e in ipairs(G.Ranks({ class = c.key })) do
      H.ok(e.level >= 1 and e.level <= 30, c.key .. " level")
      H.ok(type(e.spell) == "number", "spell id")
    end
  end
  H.state.class = "ROGUE"
  H.eq(G.PlayerClass(), "ROGUE")
  local ss = G.Ranks({ class = "ROGUE", search = "sinister" })
  H.ok(#ss >= 4)
  H.eq(G.RankText(ss[1]), "Sinister Strike (Rank 1)")
  for i = 2, #ss do H.ok(ss[i - 1].level <= ss[i].level, "sorted") end
end)

H.test("training plan: 'known' follows the game's answer, nil means can't tell", function()
  local ns = H.boot()
  local G = ns.Guides
  H.state.class, H.state.level = "ROGUE", 10
  -- no spellbook API at all -> can't tell
  local plan = G.TrainingPlan()
  H.ok(#plan.now > 0)
  H.eq(plan.unsure, #plan.now)
  H.eq(plan.next, 12)
  -- the game knows rank 1 Sinister Strike
  _G.IsPlayerSpell = function(id) return id == 1752 end
  plan = G.TrainingPlan()
  H.eq(plan.unsure, 0)
  H.eq(plan.known, 1)
  for _, e in ipairs(plan.now) do H.ok(e.spell ~= 1752) end
  _G.IsPlayerSpell = nil
end)

H.test("trainer window: costs noted, 'used' ranks count as known, reminder on level-up", function()
  local ns = H.boot()
  local G = ns.Guides
  H.state.class, H.state.level = "ROGUE", 6
  local services = {
    { "Sinister Strike", "Rank 2", "available", 100 },
    { "Eviscerate", "Rank 1", "used", 10 },
    { "Herbalism", "Apprentice", "available", 10 },
  }
  _G.GetNumTrainerServices = function() return #services end
  _G.GetTrainerServiceInfo = function(i) return services[i][1], services[i][2], services[i][3] end
  _G.GetTrainerServiceCost = function(i) return services[i][4] end
  H.eq(G.ReadTrainer(), 2)
  H.eq(G.Cost("ROGUE", "Sinister Strike", 2), 100)
  H.eq(G.IsKnown(2098), true, "Eviscerate rank 1 from the trainer's 'used'")
  -- level 8: Eviscerate rank 2 opens up; reminder goes to your own chat frame only
  H.chatOut = {}
  local printed = {}
  local old = ns.Print
  ns.Print = function(fmt, ...) printed[#printed + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
  H.fire("PLAYER_LEVEL_UP", 8)
  H.advance(2)
  ns.Print = old
  H.ok(printed[1] and printed[1]:find("Eviscerate (Rank 2)", 1, true), tostring(printed[1]))
  -- toggle off
  ns.db.settings.trainerReminder = false
  printed = {}
  ns.Print = function(t) printed[#printed + 1] = t end
  H.fire("PLAYER_LEVEL_UP", 8)
  H.advance(2)
  ns.Print = old
  H.eq(#printed, 0, "reminder off")
  H.eq(#H.said, 0, "nothing said in chat")
  _G.GetNumTrainerServices, _G.GetTrainerServiceInfo, _G.GetTrainerServiceCost = nil, nil, nil
  noErrors("trainer")
end)

H.test("gathering: nodes by skill, your own skill, zone lists and the skinning rule", function()
  local ns = H.boot()
  local G = ns.Guides
  H.eq(G.PlayerSkill("skinning"), 75)
  H.eq(G.PlayerSkill("herbalism"), nil)
  H.eq(G.PROFS[G.DefaultProf()], "skinning", "opens on a profession you have")
  local herbs = G.Nodes("herbalism", { maxSkill = 75 })
  H.ok(#herbs > 2)
  for _, e in ipairs(herbs) do H.ok(e.n.sk <= 75) end
  local slug, _, node = G.FindNode("peacebloom")
  H.eq(slug, "herbalism"); H.eq(node.n, "Peacebloom")
  H.eq(G.NodeForItem(node.it), "herbalism")
  H.eq(G.SkinSkill(5), 1); H.eq(G.SkinSkill(15), 50); H.eq(G.SkinSkill(25), 125)
  H.eq(G.CanGather(50, 75), "yes"); H.eq(G.CanGather(100, 75), "no"); H.eq(G.CanGather(100, nil), nil)
  local gz = G.GatherInZone("Elwynn Forest")
  H.ok(gz.herbs and gz.ore and gz.skinning and gz.fishing, "Elwynn has all four")
  local sk = G.SkinningFor(gz.skinning.b[1].id)
  H.ok(sk and sk.skill, "beast -> skinning facts")
end)

H.test("disenchanting: Classic table by quality/kind/level, enchanters, tooltip toggle", function()
  local ns = H.boot()
  local G = ns.Guides
  local r = G.Disenchant(15284)   -- Long Battle Bow, uncommon weapon, item level 29
  H.ok(r and r.k == 1 and r.q == 2, "weapon row")
  H.ok(29 >= r.lo and 29 <= r.hi)
  H.ok(G.DisenchantText(r) ~= "")
  local _, why = G.Disenchant(2447) -- Peacebloom: common
  H.eq(why, "quality")
  H.ok(#G.DisenchantSources(r.r[1][1]) > 0, "material -> sources")
  -- a guild enchanter from a synced profile
  ns.Me.stats.professions = { Enchanting = { rank = 90, max = 150 } }
  local en = G.Enchanters()
  H.eq(#en, 1); H.eq(en[1].rank, 90)
  local line = G.TooltipLine(15284)
  H.ok(line and line:find("Classic data, may differ", 1, true) and line:find("Guild enchanters"), tostring(line))
  ns.db.settings.deTooltips = false
  H.eq(G.TooltipLine(15284), nil, "setting off")
end)

H.test("gear sets: owned from bags, equipped and the bank scan; missing pieces' sources", function()
  local ns = H.boot()
  local G = ns.Guides
  local s = G.Set(161)
  H.eq(s.n, "Defias Leather")
  local p = G.SetProgress(s)
  H.eq(p.have, 0); H.eq(p.total, #s.i)
  H.gear[5] = ("|cff1eff00|Hitem:%d::|h[x]|h|r"):format(s.i[1])
  ns.char.setBank = { i = { [s.i[2]] = true }, t = H.now }
  p = G.SetProgress(s)
  H.eq(p.have, 2); H.eq(p.equipped, 1)
  H.eq(p.pieces[1].where, "equipped"); H.eq(p.pieces[2].where, "bank")
  local id = G.SetForItem(s.i[3])
  H.eq(id, 161)
  local src = G.Sources(s.i[3])
  H.ok(src.soldBy and src.madeBy and src.dungeons and src.drops, "all source lists present")
  -- the guild bestiary saw it drop
  ns.db.bestiary[1725] = { nm = "Defias Watchman", rec = { ["Testy-Forever"] = { c = 4, i = { [s.i[3]] = 1 } } } }
  local d = G.GuildDrops(s.i[3])
  H.eq(d[1].npcId, 1725); H.eq(d[1].rate, 0.25)
  H.gear[5] = nil
end)

H.test("poisons, battlegrounds and zones", function()
  local ns = H.boot()
  local G = ns.Guides
  local P = G.Poisons()
  H.ok(#P.list >= 3)
  for _, x in ipairs(P.list) do H.ok(x.lv <= 30) end
  H.ok(#G.BattlegroundList("") >= 3)
  H.eq(G.Battleground(2).n, "Warsong Gulch")
  local id = G.ZoneByName("Westfall")
  H.eq(id, 1436)
  local st = G.ZoneStats("Westfall")
  H.ok(st.quests > 10 and st.lo and st.hi >= st.lo, "levels from the quests")
  H.eq(st.side, "A")
  for _, e in ipairs(G.ZoneList({ side = "H" })) do H.ok(e.st.side ~= "A", "no Alliance zones for Horde") end
  local near = G.ZoneList({ minLevel = 10, maxLevel = 12 })
  local found = false
  for _, e in ipairs(near) do if e.z.n == "Westfall" then found = true end end
  H.ok(found, "Westfall is a level 10-12 zone")
end)

H.test("UI: Training / Gathering / Zones / Sets render, credit, link to each other", function()
  local ns = H.boot()
  H.state.class, H.state.level = "ROGUE", 22
  SlashCmdList.LOMB("train")
  H.eq(ns.UI.current, "quests")
  local Tab, p = ns.QuestsTab, panel(ns)
  H.eq(Tab.view.mode, "training")
  H.eq(p.page.key, "now")
  H.ok(has(p.page, "Train now")); credited(p.page, "train now")
  H.ok(has(p.page, "haven't been tried on the live servers"), "unverified note")
  -- the Poisons row (rogue)
  local rows = {}
  for _, r in ipairs(p.list.items) do rows[r.key] = r end
  H.ok(rows.poisons, "poisons row for rogues")
  Tab.Select("poisons"); H.advance(1)
  H.ok(has(p.page, "level 20 · skill 125") and has(p.page, "Klaven's Tower"), pageText(p.page)); credited(p.page, "poisons")
  -- class filter cycles to another class; f3 hidden for non-hunters
  p.f1:Click(); H.advance(1)
  H.ok(p.f1.label.text ~= "Rogue", "class changed")
  -- level row
  Tab.Show("training", "lv:10"); H.advance(1)
  H.ok(has(p.page, "Level 10")); credited(p.page, "level row")
  -- gathering: opens on skinning (the character has it)
  Tab.Show("gathering"); H.advance(1)
  H.eq(p.f1.label.text, "Skinning")
  H.ok(has(p.page, "Where to level Skinning")); credited(p.page, "gathering best")
  Tab.ShowGathering("herbalism", "n:1"); H.advance(1)
  H.ok(has(p.page, "Peacebloom")); H.ok(has(p.page, "Classic data")); credited(p.page, "herb")
  Tab.ShowGathering("skinning", "z:Elwynn Forest"); H.advance(1)
  H.ok(has(p.page, "Beasts")); credited(p.page, "skinning zone")
  -- zones + battleground
  Tab.Show("zones", 1436); H.advance(1)
  H.ok(has(p.page, "Westfall") and has(p.page, "Quests") and has(p.page, "Herbs")); credited(p.page, "zone")
  Tab.Show("zones", "bg:2"); H.advance(1)
  H.ok(has(p.page, "Capture the enemy flag")); H.ok(has(p.page, "Classic")); credited(p.page, "bg")
  -- sets
  Tab.Show("sets", 161); H.advance(1)
  H.ok(has(p.page, "Defias Leather") and has(p.page, "Pieces")); credited(p.page, "set")
  H.ok(has(p.page, "Add the 5 missing pieces to my wishlist"))
  -- click the wishlist line
  for i = 1, p.page.used do
    local l = p.page.lines[i]
    if (l.left.text or ""):find("to my wishlist", 1, true) then l.scripts.OnMouseUp(l, "LeftButton") end
  end
  H.ok(#ns.Wishlist.All("all", "") >= 5, "pieces on the wishlist")
  -- item page extras: disenchant + part of set
  Tab.Show("items", 15284); H.advance(1)
  H.ok(has(p.page, "Disenchants into") and has(p.page, "Classic data, may differ")); credited(p.page, "item")
  Tab.Show("items", ns.Guides.Set(161).i[1]); H.advance(1)
  H.ok(has(p.page, "Part of a set") and has(p.page, "Defias Leather"))
  noErrors("ui")
end)

H.test("mode buttons fit the content width", function()
  local ns = H.boot()
  SlashCmdList.LOMB("quests")
  local n = #ns.QuestsTab.MODES
  H.eq(n, 9)
  local bw = (ns.Theme.sizes.content.w - 4 * 4) / n
  H.ok(bw >= 62, "button width " .. bw)
end)

H.done()
