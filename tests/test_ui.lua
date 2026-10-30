local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("UI smoke (full TOC load, every tab, card, slash, minimap)")

local function link(id) return ("|cffffffff|Hitem:%d::::::::12:::::|h[Item %d]|h|r"):format(id, id) end

local function setup()
  local ns = H.boot()
  H.roster = {
    { name = "Testy-Forever", rank = "Officer", rankIndex = 1, level = 12, className = "Hunter", class = "HUNTER", zone = "Darkshore", online = true },
    { name = "Brindlewick-Forever", rank = "Member", rankIndex = 3, level = 9, className = "Mage", class = "MAGE", zone = "Elwynn Forest", online = true },
    { name = "Oakenhollow-Forever", rank = "Member", rankIndex = 3, level = 20, className = "Druid", class = "DRUID", online = false, days = 2 },
  }
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(1)
  return ns
end

local function noErrors(what)
  H.eq(#H.errors, 0, what .. ": " .. tostring(H.errors[1]))
end

H.test("full TOC loads and registers /lomb", function()
  local ns = setup()
  H.ok(ns.UI and ns.BestiaryCard and ns.MobPage and ns.Minimap, "UI modules present")
  H.ok(SlashCmdList.LOMB, "slash registered")
  H.eq(SLASH_LOMB1, "/lomb")
  H.ok(ns.Minimap.button and ns.Minimap.button.shown, "minimap button shown")
  noErrors("boot")
end)

H.test("every tab opens and renders without errors", function()
  local ns = setup()
  SlashCmdList.LOMB("")
  H.ok(ns.UI.frame.shown, "window shown")
  H.ok(#ns.UI.tabs >= 6, "tabs registered")
  ns.Bank.SetBankChar(true)   -- the Bank tab is hidden until a bank character exists
  for _, t in ipairs(ns.UI.tabs) do
    local id = t.id
    SlashCmdList.LOMB(id)
    H.eq(ns.UI.current, id)
    H.advance(2)
  end
  noErrors("tabs")
  ns.UI.Select("me")
  local me
  for _, t in ipairs(ns.UI.tabs) do if t.id == "me" then me = t end end
  H.eq(me.panel.tiles.level.value.text, 12)
  H.eq(me.panel.tiles.ilvl.value.text, 24)
  -- roster shows the three members
  ns.UI.Select("roster")
  local tab
  for _, t in ipairs(ns.UI.tabs) do if t.id == "roster" then tab = t end end
  H.eq(#tab.panel.list.items, 3)
  SlashCmdList.LOMB("")
  H.ok(not ns.UI.frame.shown, "toggle closes")
end)

H.test("targeting a creature shows the card; loot fills the page", function()
  local ns = setup()
  local g = H.guid(3100, "AA")
  H.units.target = { name = "Mottled Boar", level = 3, guid = g, classification = "normal",
    creatureType = "Beast", family = "Boar", health = 70, healthMax = 100 }
  H.fire("PLAYER_TARGET_CHANGED")
  local card = ns.BestiaryCard.frame
  H.ok(card and card.shown, "card shown")
  H.eq(card.npcId, 3100)
  H.eq(card.name.text, "Mottled Boar")
  H.eq(card.health.value, 70)

  H.units.target.dead = true
  H.units.target.health = 0
  H.fire("UNIT_HEALTH", "target")
  H.loot = { { link = link(769), quantity = 1, sources = { g, 1 } } }
  H.fire("LOOT_OPENED")
  H.advance(1)
  local agg = ns.Bestiary.Aggregate(ns.Bestiary.Get(3100))
  H.eq(agg.kills, 1); H.eq(agg.corpses, 1)

  -- expand to full page
  card.expand:Click()
  local page = ns.MobPage.standalone
  H.ok(page and page.shown, "standalone page open")
  H.eq(page.page.npcId, 3100)
  H.ok(page.page.used > 5, "page has lines")
  -- the only ForeverDB facts for a plain boar are its (Classic) skinning facts, with the credit
  local text = {}
  for i = 1, page.page.used do text[#text + 1] = page.page.lines[i].left.text or "" end
  text = table.concat(text, "\n")
  H.ok(text:find("Skinning") and text:find("Classic data, may differ", 1, true), "skinning facts, labelled Classic")
  H.ok(text:find("Data from ForeverDB.net", 1, true), "credit under ForeverDB facts")
  H.ok(not text:find("Notable loot") and not text:find("Boss of"), "no other ForeverDB sections for a boar")
  noErrors("card")
end)

H.test("pinned card survives target loss; unpinned hides", function()
  local ns = setup()
  H.units.target = { name = "Kobold Vermin", level = 2, guid = H.guid(6, "B1"), health = 50, healthMax = 50 }
  H.fire("PLAYER_TARGET_CHANGED")
  local card = ns.BestiaryCard.frame
  card.pin:Click()
  H.ok(ns.db.settings.cardPinned)
  H.units.target = nil
  H.fire("PLAYER_TARGET_CHANGED")
  H.ok(card.shown, "pinned stays")
  card.pin:Click()
  H.ok(not card.shown, "unpinning with no target hides")
  noErrors("pin")
end)

H.test("secret target in combat: card shows, nothing secret stored", function()
  local ns = setup()
  H.state.combat = true
  H.units.target = { name = H.secret("Defias Thug"), level = H.secret(10), guid = H.secret(H.guid(38, "S1")),
    health = H.secret(40), healthMax = H.secret(80) }
  H.fire("PLAYER_TARGET_CHANGED")
  local card = ns.BestiaryCard.frame
  H.ok(card.shown, "card shown")
  H.eq(card.npcId, nil)
  H.ok(card.note.text:find("after combat"), "explains")
  H.eq(next(ns.db.bestiary), nil, "nothing recorded from secrets")
  -- after combat the real identity is read and recorded
  H.state.combat = false
  H.units.target = { name = "Defias Thug", level = 10, guid = H.guid(38, "S1"), health = 40, healthMax = 80 }
  H.fire("PLAYER_REGEN_ENABLED")
  H.eq(card.npcId, 38)
  H.ok(ns.db.bestiary[38], "recorded after combat")
  noErrors("secrets")
end)

H.test("ForeverDB-style module: sections + credit appear", function()
  local ns = setup()
  ns.Providers.RegisterStatic({
    id = "foreverdb", label = "ForeverDB", priority = 50, credit = "Data from ForeverDB.net", url = "https://foreverdb.net",
    mobs = { [99999] = { name = "Test Dummy", level = 60, classification = "worldboss",
      loot = { { itemID = 19019, rate = 0.04 } }, boss = { notes = "Stand behind it." },
      skinning = { skill = 300, items = { 8170 } }, quests = { { id = 1, name = "Kill the dummy", level = 60 } } } },
  })
  local page = ns.MobPage.OpenStandalone(99999)
  local all = {}
  for i = 1, page.page.used do all[#all + 1] = page.page.lines[i].left.text or "" end
  local text = table.concat(all, "\n")
  H.ok(text:find("Boss"), "boss section")
  H.ok(text:find("Skinning"), "skinning section")
  H.ok(text:find("Quests"), "quests section")
  H.ok(text:find("Data from ForeverDB.net", 1, true), "credit line")
  ns.UI.Open("credits")
  H.ok(true)
  noErrors("foreverdb")
  ns.Providers.Unregister("foreverdb")
end)

H.test("settings toggles: profile off sends off-profile, card off hides", function()
  local ns = setup()
  ns.UI.Open("settings")
  local tab
  for _, t in ipairs(ns.UI.tabs) do if t.id == "settings" then tab = t end end
  H.ok(ns.db.settings.shareProfile)
  tab.panel.checks.shareProfile:Click()
  H.ok(not ns.db.settings.shareProfile)
  H.advance(2)
  local sawOff = false
  for _, s in ipairs(H.sent) do
    local _, d = pcall(function() return s.msg end)
    if d and d:find("off") then sawOff = true end
  end
  H.ok(sawOff, "sent profile-off notice")
  tab.panel.checks.showCard:Click()
  H.ok(not ns.db.settings.showCard)
  H.units.target = { name = "Wolf", level = 5, guid = H.guid(299, "W"), health = 1, healthMax = 1 }
  H.fire("PLAYER_TARGET_CHANGED")
  H.ok(not (ns.BestiaryCard.frame and ns.BestiaryCard.frame.shown), "card stays hidden")
  noErrors("settings")
end)

H.test("slash help + status + debug", function()
  local ns = setup()
  SlashCmdList.LOMB("help")
  SlashCmdList.LOMB("status")
  SlashCmdList.LOMB("debug")
  H.ok(ns.db.settings.debug)
  H.ok(#DEFAULT_CHAT_FRAME.lines >= 7)
  noErrors("slash")
end)

H.done()
