local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Crafters (recipe scan, sharing, index, tab, tooltip)")

local function boot()
  local ns = H.boot()
  H.roster = {
    { name = "Testy-Forever", rank = "Officer", level = 12, className = "Hunter", class = "HUNTER", online = true },
    { name = "Oakenhollow-Forever", rank = "Member", level = 20, className = "Druid", class = "DRUID", online = false, days = 1 },
    { name = "Brindlewick-Forever", rank = "Member", level = 9, className = "Mage", class = "MAGE", online = true },
  }
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.sent = {}
  return ns
end

local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    local payload = a:Feed("me", s.msg)
    if payload then
      local _, d = ns.Serializer.Unpack(payload)
      out[#out + 1] = d
    end
  end
  return out
end
local function lastRc(ns)
  local found
  for _, m in ipairs(decodeSent(ns)) do if m.t == "D" and m.k == "rc" then found = m end end
  return found
end
local function deliver(ns, sender, tbl)
  for _, p in ipairs(ns.Chunker.Split(ns.Serializer.Pack(tbl))) do
    H.fire("CHAT_MSG_ADDON", "LOMBC", p, "GUILD", sender)
  end
end

local LW = { line = "Leatherworking", rows = {
  { name = "Leather", kind = "header" },
  { name = "Light Armor Kit", item = 2304 },
  { name = "Handstitched Leather Boots", item = 2302 },
  { name = "Embossed Leather Gloves", item = 4239 },
} }

H.test("opening a profession window reads recipes and shares item IDs", function()
  local ns = boot()
  H.trade = LW
  H.fire("TRADE_SKILL_SHOW")
  H.advance(1)
  local mine = ns.char.recipes.Leatherworking
  H.ok(mine.i[2304] and mine.i[2302] and mine.i[4239], "three recipes read")
  H.eq(mine.n.i2304, "Light Armor Kit", "names remembered for offline display")
  H.advance(30)
  local m = lastRc(ns)
  H.ok(m, "recipes published")
  H.deepEq(m.d.Lw.i, { 2302, 2304, 4239 })
  H.eq(m.d.Lw.n, nil, "names are not sent (IDs only)")
  H.eq(#H.errors, 0)
end)

H.test("a filtered/collapsed window never removes recipes; dropping the profession does", function()
  local ns = boot()
  H.trade = LW
  H.fire("TRADE_SKILL_SHOW"); H.advance(1)
  H.trade = { line = "Leatherworking", rows = { { name = "Light Armor Kit", item = 2304 } } }
  H.fire("TRADE_SKILL_UPDATE"); H.advance(1)
  local n = 0
  for _ in pairs(ns.char.recipes.Leatherworking.i) do n = n + 1 end
  H.eq(n, 3, "still three")
  -- unlearn Leatherworking
  H.state.skills = { { "Professions", true, 0, 0 }, { "Skinning", false, 75, 150 } }
  H.fire("SKILL_LINES_CHANGED")
  H.advance(2)
  H.eq(ns.char.recipes.Leatherworking, nil, "pruned after the profession was dropped")
end)

H.test("not scanned in combat; unknown window ignored", function()
  local ns = boot()
  H.state.combat = true
  H.trade = LW
  H.fire("TRADE_SKILL_SHOW"); H.advance(1)
  H.eq(ns.char.recipes and ns.char.recipes.Leatherworking, nil, "nothing in combat")
  H.state.combat = false
  H.trade = { line = "Swords", rows = { { name = "x", item = 1 } } }
  H.fire("TRADE_SKILL_SHOW"); H.advance(1)
  H.eq(ns.char.recipes and ns.char.recipes.Swords, nil, "only real professions")
end)

H.test("enchanting craft window stores spell IDs", function()
  local ns = boot()
  H.state.skills[#H.state.skills + 1] = { "Enchanting", false, 90, 150 }
  H.fire("SKILL_LINES_CHANGED"); H.advance(2)
  H.craft = { line = "Enchanting", rows = { { name = "Enchant Bracer - Minor Health", spell = 7418 },
    { name = "Runed Copper Rod", item = 6218 } } }
  H.fire("CRAFT_SHOW"); H.advance(1)
  H.ok(ns.char.recipes.Enchanting.s[7418], "enchant spell")
  H.ok(ns.char.recipes.Enchanting.i[6218], "rod item")
end)

H.test("guild index: who can craft, online first, tooltip line", function()
  local ns = boot()
  H.trade = LW
  H.fire("TRADE_SKILL_SHOW"); H.advance(30)
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "rc", r = 1793750500, d = { Lw = { i = { 2304, 5958 } } } })
  deliver(ns, "Brindlewick-Forever", { t = "D", k = "rc", r = 1793750500, d = { Ta = { i = { 2580, 2304 } } } })
  H.advance(2)
  local who = ns.Crafting.CraftersOfItem(2304)
  H.eq(#who, 3)
  H.eq(who[3], "Oakenhollow-Forever", "offline crafter last")
  local line = ns.Crafting.TooltipLine(2304)
  H.ok(line:find("Crafters in LOMB", 1, true))
  H.ok(line:find("Oakenhollow", 1, true))
  H.eq(ns.Crafting.TooltipLine(999999), nil, "no line for items nobody makes")
  -- search
  H.eq(#ns.Crafting.Search({ search = "item 2580" }), 1)
  H.eq(#ns.Crafting.Search({ prof = "Ta" }), 2)
  H.eq(#ns.Crafting.Search({ search = "oaken" }), 2, "search by crafter name")
  local online = ns.Crafting.Search({ onlineOnly = true })
  for _, e in ipairs(online) do H.ok(ns.Crafting.IsOnline(e.crafters[1])) end
  H.eq(#online, 5, "5958 (only offline crafter) filtered out")
end)

H.test("junk recipe data from a guildmate is cleaned", function()
  local ns = boot()
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "rc", r = 1793750500,
    d = { ["Lw|cff"] = { i = { 1, "x", -5, 2.5, 7 } }, Bad = "nope" } })
  H.advance(2)
  local d = ns.Shared.Get("rc", "Oakenhollow-Forever")
  H.ok(d["Lwcff"], "UI escapes stripped from keys")
  H.deepEq(d["Lwcff"].i, { 1, 7 })
  H.eq(d.Bad, nil)
end)

H.test("crafters tab lists, whispers, links", function()
  local ns = boot()
  deliver(ns, "Brindlewick-Forever", { t = "D", k = "rc", r = 1793750500, d = { Ta = { i = { 2580, 2568 } } } })
  H.advance(2)
  ns.UI.Open("crafters")
  local tab
  for _, t in ipairs(ns.UI.tabs) do if t.id == "crafters" then tab = t end end
  local p = tab.panel
  p.list:SetSize(600, 300)
  p.list:Layout()
  H.eq(#p.list.items, 2)
  H.ok(p.count.text:find("2 recipes"), p.count.text)
  H.ok(not p.empty.shown, "no empty state")
  local row = p.list.rows[1]
  H.ok(row.who.text:find("Brindlewick"), "crafter shown")
  H.chat = {}
  row:Click()
  H.ok(H.chat[1] and H.chat[1].open:find("^/w Brindlewick"), "whisper opened")
  _G.IsShiftKeyDown = function() return true end
  row:Click()
  _G.IsShiftKeyDown = function() return false end
  H.ok(H.chat[2] and H.chat[2].link:find("Hitem:"), "item linked")
  -- profession filter cycles
  p.profBtn:Click()
  H.eq(ns.CraftersTab.view.prof, "Ta")
  p.profBtn:Click()
  H.eq(ns.CraftersTab.view.prof, nil, "back to all")
  H.eq(#H.errors, 0)
end)

H.test("empty state explains how to add recipes", function()
  local ns = boot()
  ns.UI.Open("crafters")
  local tab
  for _, t in ipairs(ns.UI.tabs) do if t.id == "crafters" then tab = t end end
  H.ok(tab.panel.empty.text:find("profession window"))
  H.ok(tab.panel.mine.text:find("none read yet"))
end)

H.test("item tooltip gets the crafters line (and respects the setting)", function()
  local ns = boot()
  ns.db.settings.fdbTooltips = false   -- the ForeverDB line has its own test (test_questdb.lua)
  deliver(ns, "Brindlewick-Forever", { t = "D", k = "rc", r = 1793750500, d = { Ta = { i = { 2580 } } } })
  H.advance(2)
  local lines = {}
  GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
  GameTooltip.GetItem = function() return "Item 2580", "|cffffffff|Hitem:2580::|h[Item 2580]|h|r" end
  H.eq(ns.Tooltip.mode, "script")
  GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
  H.eq(#lines, 1)
  H.ok(lines[1]:find("Brindlewick"))
  H.now = H.now + 1
  ns.db.settings.tooltips = false
  lines = {}
  GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
  H.eq(#lines, 0, "setting off")
  -- secret item link: no line, no error
  ns.db.settings.tooltips = true
  H.now = H.now + 1
  GameTooltip.GetItem = function() return H.secret("x"), H.secret("y") end
  GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
  H.eq(#lines, 0)
  H.eq(#H.errors, 0)
end)

H.test("recipe sharing off withdraws; receiving still works", function()
  local ns = boot()
  H.trade = LW
  H.fire("TRADE_SKILL_SHOW"); H.advance(30)
  H.sent = {}
  ns.UI.Open("settings")
  local tab
  for _, t in ipairs(ns.UI.tabs) do if t.id == "settings" then tab = t end end
  tab.panel.checks.shareRecipes:Click()
  H.advance(30)
  local m = lastRc(ns)
  H.ok(m and m.off, "withdrawal sent")
  deliver(ns, "Brindlewick-Forever", { t = "D", k = "rc", r = 1793750500, d = { Ta = { i = { 2580 } } } })
  H.advance(2)
  H.eq(#ns.Crafting.CraftersOfItem(2580), 1)
  H.eq(#ns.Crafting.CraftersOfItem(2304), 0, "own recipes no longer listed")
end)

H.done()
