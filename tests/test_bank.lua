local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")

print("Bank ledger & wishlist (scan, change log, sharing, tooltips, tab)")

local ROSTER = {
  { name = "Testy-Forever", rank = "Officer", rankIndex = 1, level = 12, className = "Hunter", class = "HUNTER", online = true },
  { name = "Oakenhollow-Forever", rank = "Member", rankIndex = 3, level = 19, className = "Druid", class = "DRUID", online = true },
  { name = "Lombbank-Forever", rank = "Bank", rankIndex = 2, level = 1, className = "Mage", class = "MAGE", online = false },
  { name = "Brindlewick-Forever", rank = "Member", rankIndex = 3, level = 9, className = "Mage", class = "MAGE", online = false },
}
local LINEN, WOOL, COPPER, POTION = 2589, 2592, 2770, 118
local function setup(opts)
  opts = opts or {}
  H.installAPI(opts)
end
local function boot(opts)
  opts = opts or {}
  local ns = H.boot(opts)
  if opts.player then H.state.player = opts.player end
  H.itemNames = { [LINEN] = "Linen Cloth", [WOOL] = "Wool Cloth", [COPPER] = "Copper Ore", [POTION] = "Minor Healing Potion" }
  H.roster = {}
  for i, r in ipairs(ROSTER) do local c = {} for k, v in pairs(r) do c[k] = v end H.roster[i] = c end
  if opts.note then H.roster[1].note = opts.note end
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.sent = {}
  return ns
end
local function decodeSent(ns)
  local a = ns.Chunker.NewAssembler(function() return H.now end)
  local out = {}
  for _, s in ipairs(H.sent) do
    H.ok(#s.msg <= 255, "fits in one addon message")
    local payload = a:Feed("me", s.msg)
    if payload then
      local _, d = ns.Serializer.Unpack(payload)
      out[#out + 1] = d
    end
  end
  return out
end
local function deliver(ns, sender, tbl)
  tbl.v = tbl.v or ns.version
  for _, p in ipairs(ns.Chunker.Split(ns.Serializer.Pack(tbl))) do
    H.fire("CHAT_MSG_ADDON", "LOMBC", p, "GUILD", sender)
  end
end
local function sentKind(ns, kind)
  for _, d in ipairs(decodeSent(ns)) do if d.t == "D" and d.k == kind then return d end end
end
local function bags(contents) H.bags[0] = contents end
local function vault(contents) H.bags[-1] = contents end
_ = setup

H.test("only a ticked bank character scans; 'bank' in the name or note doesn't tick it", function()
  local ns = boot()
  local B = ns.Bank
  bags({ { LINEN, 20 }, false, { COPPER, 5 } })
  H.ok(not B.IsBankChar(), "an ordinary character isn't the bank")
  H.ok(not B.ScanBags(), "no scan")
  H.eq(B.Me().bagsAt, nil)
  H.eq(B.Build(), nil, "nothing to share")
  -- a guild note saying bank is ignored (no auto-detect)
  H.roster[1].note = "Guild Bank alt"
  H.fire("GUILD_ROSTER_UPDATE")
  H.advance(20)
  H.ok(not B.IsBankChar(), "guild note 'bank' does nothing")
  H.eq(B.Me().bagsAt, nil)
  H.ok(not B.Exists())
  -- only the Settings tick makes it a bank character
  B.SetBankChar(true)
  H.ok(B.IsBankChar())
  H.ok(B.Me().bagsAt, "scanned once ticked")
  H.eq(B.Me().bags[LINEN], 20)
  B.SetBankChar(false)
  H.ok(not B.IsBankChar())
  H.eq(B.Build(), nil)
  B.SetBankChar(true)
  H.ok(B.IsBankChar())
end)

H.test("no bank character: Bank tab hidden, no tooltip line; appears once one is ticked or shared", function()
  local ns = boot()
  local B, UI = ns.Bank, ns.UI
  ns.playerKey = "Lombbank-Forever"
  H.ok(not B.IsBankChar(), "a name with 'bank' isn't auto-ticked")
  ns.playerKey = "Testy-Forever"
  UI.Open("roster")
  H.ok(not UI.tabButtons.bank:IsShown(), "Bank hidden in the sidebar")
  H.ok(UI.tabButtons.wishlist:IsShown(), "Wishlist has its own entry")
  UI.Open("bank")
  H.eq(UI.current, "roster", "can't open a hidden tab")
  ns.HandleSlash("bank")
  H.eq(UI.current, "roster", "/lomb bank does nothing while hidden")
  ns.Wishlist.Add("n", "Wool Cloth", 2)
  local function bankLine(id)
    for _, l in ipairs(ns.Tooltip.LinesFor(id)) do if tostring(l):find("Guild bank has") then return true end end
  end
  H.eq(B.TooltipLine(WOOL), nil, "no 'Guild bank has' line")
  H.ok(not bankLine(WOOL))
  -- a guildmate shares a bank character's ledger
  local now = H.epoch
  deliver(ns, "Vaultkeep-Forever", { t = "D", k = "bk", r = now, d = { i = { WOOL, 40 }, b = now } })
  H.ok(B.Exists())
  H.ok(UI.tabButtons.bank:IsShown(), "Bank appears")
  H.ok(bankLine(WOOL), "tooltip line now")
  UI.Open("bank")
  H.eq(UI.current, "bank")
  -- they untick it: the off marker hides the tab again and we fall back
  deliver(ns, "Vaultkeep-Forever", { t = "D", k = "bk", r = now + 60, off = true })
  H.ok(not B.Exists())
  H.ok(not UI.tabButtons.bank:IsShown(), "hidden again")
  H.eq(UI.current, "roster", "fell back to the first tab")
  -- ticking our own character shows it too
  B.SetBankChar(true)
  H.ok(UI.tabButtons.bank:IsShown())
end)

H.test("rare alerts are silent by default; the sound is an option", function()
  local ns = boot()
  H.eq(ns.db.settings.rareSound, false)
  local played = 0
  _G.PlaySound = function() played = played + 1 end
  _G.SOUNDKIT = _G.SOUNDKIT or { RAID_WARNING = 8959 }
  ns.Rares.Alert({ n = 1, nm = "Mor'Ladim", z = "Duskwood", by = "Oakenhollow-Forever" })
  H.eq(played, 0, "no sound")
  ns.db.settings.rareSound = true
  ns.Rares.Alert({ n = 2, nm = "Mor'Ladim", z = "Duskwood", by = "Oakenhollow-Forever" })
  H.ok(played >= 1, "sound when ticked")
end)

H.test("change log: in/out, bag<->bank moves cancel, first bank look is a baseline", function()
  local ns = boot()
  local B = ns.Bank
  bags({ { LINEN, 20 }, { COPPER, 5 } })
  B.SetBankChar(true)
  H.eq(#B.Me().log, 0, "first scan is the baseline")
  bags({ { LINEN, 30 }, { COPPER, 5 } })
  H.fire("BAG_UPDATE_DELAYED")
  H.advance(3)
  H.eq(#B.Me().log, 1)
  H.eq(B.Me().log[1].id, LINEN)
  H.eq(B.Me().log[1].d, 10)
  -- open the bank: 50 wool already inside -> baseline, not "new"
  vault({ { WOOL, 50 } })
  H.fire("BANKFRAME_OPENED")
  H.advance(1)
  H.ok(B.Me().vaultAt, "bank counted")
  H.eq(#B.Me().log, 1, "first look at the bank isn't logged")
  -- move 30 linen into the bank: no change
  bags({ false, { COPPER, 5 } })
  vault({ { WOOL, 50 }, { LINEN, 30 } })
  H.fire("PLAYERBANKSLOTS_CHANGED")
  H.fire("BAG_UPDATE_DELAYED")
  H.advance(3)
  H.eq(#B.Me().log, 1, "moving between bags and bank isn't a change")
  -- someone takes 10 wool out of the bank (it goes into bags, then mailed away)
  vault({ { WOOL, 40 }, { LINEN, 30 } })
  H.fire("PLAYERBANKSLOTS_CHANGED")
  H.advance(3)
  H.eq(#B.Me().log, 2)
  H.eq(B.Me().log[1].id, WOOL)
  H.eq(B.Me().log[1].d, -10)
  H.fire("BANKFRAME_CLOSED")
  -- bank closed: bag changes still counted, last known bank kept
  bags({ { COPPER, 5 }, { POTION, 4 } })
  H.fire("BAG_UPDATE_DELAYED")
  H.advance(3)
  H.eq(B.Me().log[1].id, POTION)
  H.eq(B.Totals()[WOOL], 40, "bank remembered while closed")
  -- an unreadable count (secret) doesn't wipe anything
  bags({ { COPPER, H.secret(5) } })
  H.ok(not B.ScanBags(), "skips an unreadable scan")
  H.eq(B.Totals()[POTION], 4)
end)

H.test("gold: only the bank character, only as guild bank funds, with an off switch", function()
  local ns = boot()
  local B = ns.Bank
  bags({ { LINEN, 2 } })
  H.state.money = 999999
  H.fire("PLAYER_MONEY")
  H.eq(B.Me().money, nil, "an ordinary character's gold isn't read")
  B.SetBankChar(true)
  H.eq(B.Me().money, 999999)
  local d = B.Build()
  H.eq(d.m, 999999, "shared as guild bank funds")
  ns.db.settings.shareBankFunds = false
  H.eq(B.Build().m, nil, "switch off -> no gold")
  ns.db.settings.shareBankFunds = true
  -- other datasets never carry gold
  for _, kind in ipairs({ "gr", "st", "wl" }) do
    local def = ns.Shared.kinds[kind]
    if def then
      local ok, data = pcall(def.build)
      if ok and data then H.ok(not ns.Serializer.Pack(data):find("999999"), kind .. " has no gold") end
    end
  end
end)

H.test("ledger is shared, validated and shown for guildmates; tooltip says what the bank has", function()
  local ns = boot()
  local B = ns.Bank
  bags({ { LINEN, 20 }, { COPPER, 5 } })
  B.SetBankChar(true)
  bags({ { LINEN, 25 }, { COPPER, 5 } })
  B.ScanBags()
  H.advance(60)
  local msg = sentKind(ns, "bk")
  H.ok(msg, "bank ledger sent")
  H.eq(msg.d.i[1], LINEN)
  H.eq(#msg.d.h, 3, "one change shared")
  -- receive another bank alt's ledger
  local now = H.epoch
  deliver(ns, "Lombbank-Forever", { t = "D", k = "bk", r = now, d = { i = { WOOL, 40, POTION, 3 }, b = now - 60,
    v = now - 3600, h = { now - 100, WOOL, -10 }, m = 5000000 } })
  local L = B.Ledgers()
  H.eq(#L, 2)
  local other
  for _, l in ipairs(L) do if l.owner == "Lombbank-Forever" then other = l end end
  H.ok(other, "guildmate's ledger stored")
  H.eq(other.money, 5000000)
  H.eq(other.log[1].d, -10)
  H.eq(B.HasItem(WOOL), 40)
  H.eq(B.TooltipLine(WOOL), "Guild bank has: |cffffffff40|r")
  H.eq(B.TooltipLine(12345), nil)
  local lines = ns.Tooltip.LinesFor(LINEN)
  local found
  for _, l in ipairs(lines) do if tostring(l):find("Guild bank has") then found = true end end
  H.ok(found, "tooltip provider registered")
  -- junk is rejected
  H.eq(B.Validate({ i = { 1 }, b = now }), nil, "odd list")
  H.eq(B.Validate({ i = { 1, 2 } }), nil, "no time")
  H.eq(B.Validate({ i = { "x", 2 }, b = now }), nil)
  local v = B.Validate({ i = { 1, 2 }, b = now, h = { now, 1, 0, now, 2, 3 }, m = -5 })
  H.eq(#v.h, 3, "zero changes dropped")
  H.eq(v.m, nil, "bad money dropped")
end)

H.test("wishlist: add, update, resolve links and names, full list, remove", function()
  local ns = boot()
  local WL = ns.Wishlist
  local e = WL.Add("n", "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r", "20", "for bandages")
  H.ok(e, "added from a link")
  H.eq(e.i, LINEN)
  H.eq(e.q, 20)
  H.eq(e.n, "for bandages")
  local e2 = WL.Add("n", "linen cloth", 40)
  H.eq(e2, e, "same item updates the entry")
  H.eq(e.q, 40)
  H.eq(e.n, "for bandages", "note kept")
  local g = WL.Add("g", "Wool Cloth", 0)
  H.eq(g.i, WOOL, "cached item name resolves")
  H.eq(g.q, 1, "qty at least 1")
  local t = WL.Add("n", "Someone to run me through |cffDeadmines", "", "")
  H.eq(t.i, nil)
  H.ok(not t.x:find("|", 1, true), "no escape codes in text")
  H.ok(#t.x <= WL.TEXT_MAX)
  local _, err = WL.Add("n", "   ")
  H.ok(err, "empty rejected")
  for i = 1, WL.MAX - 3 do H.ok(WL.Add("g", "thing " .. i)) end
  local full, why = WL.Add("g", "one more")
  H.eq(full, nil)
  H.ok(why:find("full"))
  H.ok(WL.Remove(g))
  H.ok(WL.Add("g", "one more"), "room again")
  -- old entries expire
  WL.Mine()[1].t = H.epoch - 61 * 86400
  H.eq(WL.Prune(), 1)
end)

H.test("wishlist is shared; needs/offers on tooltips; whisper is only prefilled", function()
  local ns = boot()
  local WL = ns.Wishlist
  WL.Add("g", "Linen Cloth", 30, "free")
  H.advance(60)
  local msg = sentKind(ns, "wl")
  H.ok(msg, "wishlist sent")
  H.eq(msg.d.e[1].i, LINEN)
  local now = H.epoch
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "wl", r = now, d = { e = {
    { k = "n", i = LINEN, q = 10, t = now - 5 },
    { k = "n", x = "Help with |Hjunk|h quest", q = 1, t = now - 50, n = "evenings" },
    { k = "z", i = 5, q = 1, t = now },
  } } })
  local all = WL.All("all")
  H.eq(#all, 3, "mine + two valid of theirs")
  H.ok(not all[3].label:find("|", 1, true) or all[3].mine, "text sanitized")
  H.eq(#WL.All("need"), 2)
  H.eq(#WL.All("give"), 1)
  H.eq(#WL.All("mine"), 1)
  H.eq(#WL.All("all", "evenings"), 1, "search notes")
  H.eq(#WL.All("all", "oaken"), 2, "search names")
  H.eq(WL.NeedLine(LINEN), "Wanted in LOMB: |cff7fe07fOakenhollow|r (10)")
  H.eq(WL.GiveLine(LINEN), "Offered in LOMB: |cff7fe07fTesty|r (30)")
  H.eq(WL.NeedLine(WOOL), nil)
  local row = WL.All("need")[1]
  local text = WL.WhisperText(row)
  H.ok(text:find("^/w Oakenhollow "), text)
  H.ok(text:find("Hitem:2589"), "item link in the whisper")
  -- removing everything sends an "off" marker
  WL.Remove(WL.Mine()[1])
  H.advance(60)
  H.eq(ns.Wishlist.Build(), nil)
end)

H.test("Bank tab: ledger view, search, next bank alt, empty states", function()
  local ns = boot()
  bags({ { LINEN, 20 }, { COPPER, 5 }, { WOOL, 3 } })
  ns.Bank.SetBankChar(true)
  ns.UI.Open("bank")
  local Tab = ns.BankTab
  local p = Tab.panel
  H.ok(p, "tab built")
  ns.Wishlist.Add("n", "Copper Ore", 2)
  ns.UI.Refresh("bank")
  H.eq(#p.items.items, 3)
  H.eq(p.items.items[1].label, "Copper Ore", "sorted by name")
  H.eq(p.items.items[1].wanted, 1, "wishlist match shown")
  H.ok(p.funds.text:find("Guild bank funds"), "funds line")
  H.ok(p.logEmpty.text:find("Open the bank"), "asks to open the bank once")
  p.search:SetText("cloth")
  H.eq(#p.items.items, 2)
  p.search:SetText("zzz")
  H.ok(p.empty:IsShown())
  p.search:SetText("")
  H.ok(not p.next:IsShown(), "one bank alt: no next button")
  local now = H.epoch
  deliver(ns, "Lombbank-Forever", { t = "D", k = "bk", r = now, d = { i = { WOOL, 40 }, b = now + 5 } })
  ns.UI.Refresh("bank")
  H.ok(p.next:IsShown())
  H.ok(p.title.text:find("Lombbank"), "newest ledger first")
  p.next:Click()
  H.ok(p.title.text:find("Testy"), p.title.text)
end)

H.test("Wishlist tab: filters, add form, shift-click fills the box, whisper prefill, remove", function()
  local ns = boot()
  ns.UI.Open("wishlist")
  H.eq(ns.UI.current, "wishlist", "own tab, no bank character needed")
  local Tab = ns.WishTab
  local p = Tab.panel
  H.ok(p.wishEmpty:IsShown())
  -- shift-click an item while the item box has focus
  p.itemBox:SetFocus()
  _G.ChatEdit_InsertLink("|cffffffff|Hitem:2592::|h[Wool Cloth]|h|r")
  H.ok(p.itemBox:GetText():find("item:2592"), "link landed in the box")
  p.itemBox:ClearFocus()
  p.qtyBox:SetText("5")
  p.addBtn:Click()
  H.eq(#p.wishList.items, 1)
  H.eq(p.wishList.items[1].id, WOOL)
  H.eq(p.wishList.items[1].q, 5)
  H.eq(p.itemBox:GetText(), "", "form cleared")
  -- empty add shows an error
  p.addBtn:Click()
  H.ok(p.msg.text:find("Type an item"), p.msg.text)
  -- toggle to "can give"
  p.kindBtn:Click()
  H.eq(p.kindBtn.label.text, "I can give")
  p.itemBox:SetText("Linen Cloth")
  p.addBtn:Click()
  H.eq(#p.wishList.items, 2)
  p.filters.need:Click()
  H.eq(#p.wishList.items, 1)
  p.filters.all:Click()
  -- a guildmate's row: click opens a prefilled whisper, nothing is sent
  local now = H.epoch
  deliver(ns, "Oakenhollow-Forever", { t = "D", k = "wl", r = now, d = { e = { { k = "g", i = COPPER, q = 8, t = now + 10 } } } })
  ns.UI.Refresh("wishlist")
  local theirs = p.wishList.items[1]
  H.eq(theirs.owner, "Oakenhollow-Forever")
  H.chat = {}
  H.sent = {}
  H.ok(Tab.Click(theirs))
  H.ok(H.chat[1] and H.chat[1].open:find("^/w Oakenhollow"), "prefilled whisper")
  H.eq(#H.sent, 0, "nothing sent")
  H.ok(not Tab.Click(p.wishList.items[2]), "own rows don't whisper")
  -- remove own row
  Tab.RemoveRow(p.wishList.items[2])
  H.eq(#p.wishList.items, 2)
end)

H.test("settings: bank character + funds switches", function()
  local ns = boot()
  ns.UI.Open("settings")
  local panel
  for _, t in ipairs(ns.UI.tabs) do if t.id == "settings" then panel = t.panel end end
  H.ok(panel.checks.isBankChar and panel.checks.shareBankFunds, "both in Settings")
  bags({ { LINEN, 1 } })
  panel.checks.isBankChar:Click()
  H.ok(ns.Bank.IsBankChar())
  H.ok(ns.Bank.Me().bagsAt, "scanned on tick")
  panel.checks.shareBankFunds:Click()
  H.eq(ns.db.settings.shareBankFunds, false)
end)

H.done()
