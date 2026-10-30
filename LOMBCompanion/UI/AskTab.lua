-- LOMB Companion: Ask LOMB tab -- a question box over the bundled ForeverDB.net
-- data and the guild's shared data (Modules/Ask.lua). Type a question, press
-- Enter; answers stack up in the history. Violet lines open the matching page.
local _, ns = ...
local W, UI = ns.Widgets, ns.UI
local Ask = ns.Ask
local Tab = { wrap = 98, chips = 0, stick = false }
ns.AskTab = Tab

local MUTED, WARN = "|cff9a92a8", "|cffe0b060"
-- clickable lines are tinted with the font colour (not |c codes) so their own colours still nest
local PAGE_RGB, ASK_RGB = { 0.80, 0.71, 1.00 }, { 0.72, 0.45, 1.00 }
local ROW_H = 17

-- Short examples for the buttons under the history (cycled with "More").
Tab.CHIPS = {
  "What should I train?", "Quests near my level", "Who sells Fine Thread?",
  "Where can I find Briarthorn?", "What drops Linen Cloth?", "Deadmines level and bosses",
  "Quests in my zone", "How do I make Heavy Linen Bandage?", "When is the next guild event?",
}

---------------------------------------------------------------------------
-- Wrapping (colour codes don't count, and carry on to the next line)
---------------------------------------------------------------------------
local function visible(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

function Tab.Wrap(text, width)
  width = width or Tab.wrap
  if #visible(text) <= width then return { text } end
  local out, cur, curLen, open = {}, "", 0, nil
  local indent = text:match("^(%s*)") or ""
  for word in text:gmatch("%S+") do
    local wl = #visible(word)
    if curLen > 0 and curLen + 1 + wl > width then
      out[#out + 1] = cur .. (open and "|r" or "")
      cur, curLen = indent .. "  " .. (open or ""), #indent + 2
    end
    if curLen > #indent + 2 or (#out == 0 and curLen > 0) then cur = cur .. " "; curLen = curLen + 1 end
    if #out == 0 and curLen == 0 then cur = indent end
    cur, curLen = cur .. word, curLen + wl
    for code in word:gmatch("|c%x%x%x%x%x%x%x%x") do open = code end
    local lastOpen, lastClose = 0, 0
    for p in word:gmatch("()|c%x%x%x%x%x%x%x%x") do lastOpen = p end
    for p in word:gmatch("()|r") do lastClose = p end
    if lastClose > lastOpen then open = nil end
  end
  if curLen > 0 then out[#out + 1] = cur end
  return out
end

---------------------------------------------------------------------------
-- History -> rows
---------------------------------------------------------------------------
local function lineText(l)
  local t = l.text
  if l.style == "muted" then t = MUTED .. t .. "|r"
  elseif l.style == "warn" then t = WARN .. t .. "|r" end
  return t
end

local function pushLine(rows, l, kind)
  local parts = Tab.Wrap(lineText(l))
  for k, p in ipairs(parts) do
    rows[#rows + 1] = { kind = kind or "line", text = p, line = l, first = k == 1, click = (l.link or l.tab or l.ask) and true or nil }
  end
end

function Tab.Rows()
  local rows = {}
  local FDB = ns.FDB
  if #Ask.history == 0 then
    rows[#rows + 1] = { kind = "lomb", text = "Hi! Ask me about quests, items, recipes, gathering, gear sets, dungeons, training or guild events." }
    rows[#rows + 1] = { kind = "lomb", text = MUTED .. "Everything comes from the data bundled with the addon, so it works anywhere, even offline.|r" }
    rows[#rows + 1] = { kind = "lomb", text = MUTED .. "You can also type |r/lomb ask <question>" .. MUTED .. " in chat; only you see the answer.|r" }
    rows[#rows + 1] = { kind = "gap" }
    rows[#rows + 1] = { kind = "lomb", text = "Try one of these:" }
    for k = 1, 7 do
      local e = Ask.EXAMPLES[k]
      pushLine(rows, { text = "  " .. e, ask = e })
    end
    return rows
  end
  local prevRestored = false
  for i, ans in ipairs(Ask.history) do
    if i == 1 and ans.restored then
      rows[#rows + 1] = { kind = "note", text = MUTED .. "Saved from earlier (answers as they were then):|r" }
    elseif prevRestored and not ans.restored then
      rows[#rows + 1] = { kind = "note", text = MUTED .. "Now:|r" }
    end
    prevRestored = ans.restored and true or false
    rows[#rows + 1] = { kind = "you", text = ans.q }
    for _, l in ipairs(ans.lines) do pushLine(rows, l) end
    if ans.data and FDB then
      rows[#rows + 1] = { kind = "credit", text = MUTED .. FDB.CREDIT .. " · " .. FDB.URL .. "|r" }
    end
    rows[#rows + 1] = { kind = "gap" }
  end
  return rows
end

function Tab.Open(l)
  if not l then return end
  if l.ask then
    Ask.Submit(l.ask)
  elseif l.tab then
    UI.Open(l.tab)
  elseif l.link then
    local mode, key = l.link[1], l.link[2]
    if mode == "gathering" and type(key) == "table" then
      ns.QuestsTab.ShowGathering(key[1], key[2])
    else
      ns.QuestsTab.Show(mode, key)
    end
  end
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function createRow(list)
  local row = CreateFrame("Button", nil, list)
  row.you = W.Fill(row, "accentDim", "BACKGROUND")
  row.you:SetAllPoints()
  row.hl = W.Fill(row, "rowHover", "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.bar = W.Fill(row, "accent", "ARTWORK")
  row.bar:SetPoint("TOPLEFT", 0, 0)
  row.bar:SetPoint("BOTTOMLEFT", 0, 0)
  row.bar:SetWidth(2)
  row.who = W.Text(row, "narrow", 10, "muted", "LEFT")
  row.who:SetPoint("LEFT", 8, 0)
  row.who:SetWidth(30)
  row.text = W.Text(row, "body", 11, "text")
  row.text:SetPoint("LEFT", 40, 0)
  row.text:SetPoint("RIGHT", -4, 0)
  row.text:SetWordWrap(false)
  row:SetScript("OnClick", function(self)
    local it = self.item
    if it and it.click then Tab.Open(it.line) end
  end)
  W.Tooltip(row, function(tt, self)
    local it = self.item
    if not (it and it.click) then return end
    local l = it.line
    tt:SetText(l.ask and "Ask this" or (l.tab and "Open the tab" or "Open the page"), 1, 1, 1)
    if l.ask then tt:AddLine(l.ask, 0.8, 0.78, 0.85, true) end
  end)
  return row
end

local function updateRow(row, it)
  local you = it.kind == "you"
  row.you:SetShown(you)
  row.bar:SetShown(you)
  row.who:SetText(you and "You" or (it.tag or ""))
  row.text:SetText(it.text or "")
  local c = it.click and (it.line.ask and ASK_RGB or PAGE_RGB) or ns.Theme.colors.text
  row.text:SetTextColor(c[1], c[2], c[3])
  row.hl:SetShown(it.click == true)
  row:EnableMouse(it.click == true)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function chipText(i)
  local n = #Tab.CHIPS
  return Tab.CHIPS[((Tab.chips * 3 + i - 1) % n) + 1]
end

function Tab.Refresh(toBottom)
  local p = Tab.panel
  if not p then return end
  local rows = Tab.Rows()
  -- "LOMB" tag on the first line of each answer
  local prevYou = false
  for _, r in ipairs(rows) do
    if prevYou and r.kind ~= "you" then r.tag = "LOMB" end
    prevYou = r.kind == "you"
  end
  p.list:SetItems(rows)
  if toBottom or Tab.stick then
    p.list.offset = math.max(0, #rows - p.list:Visible())
    p.list:Refresh()
  end
  for i = 1, 3 do
    local c = p.chips[i]
    c.label:SetText(chipText(i))
  end
  p.clear:SetShown(#Ask.history > 0)
end

function Tab.Submit(text)
  local ans = Ask.Submit(text)
  if ans then
    Tab.recall = nil
    Tab.Refresh(true)
  end
  return ans
end

UI.RegisterTab({
  id = "ask", label = "Ask LOMB", order = 63,
  shown = function() return ns.FDB and ns.FDB.Available() end,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    Tab.panel = p
    p.title = W.SectionTitle(p, "Ask LOMB")
    p.title:SetPoint("TOPLEFT", 0, 0)
    p.clear = W.Button(p, "Clear", 60, 20, function() Ask.Clear(); Tab.Refresh(true) end)
    p.clear:SetPoint("TOPRIGHT", 0, 0)
    p.clear.tip = "Forget the questions so far (they're only kept until you log out anyway)."
    p.credit = W.Text(p, "narrow", 10, "muted", "RIGHT")
    p.credit:SetPoint("RIGHT", p.clear, "LEFT", -10, 0)
    p.credit:SetText(ns.FDB.CREDIT .. " · " .. ns.FDB.URL)
    local div = W.Divider(p)
    div:SetPoint("TOPLEFT", 0, -26)
    div:SetPoint("TOPRIGHT", 0, -26)

    p.list = W.List(p, ROW_H, createRow, updateRow)
    p.list:SetPoint("TOPLEFT", 0, -30)
    p.list:SetPoint("BOTTOMRIGHT", 0, 58)

    p.chips = {}
    p.try = W.Text(p, "narrow", 10, "muted", "LEFT")
    p.try:SetPoint("BOTTOMLEFT", 0, 36)
    p.try:SetText("Try")
    for i = 1, 3 do
      local c = W.Button(p, "", 178, 18, function(self) Tab.Submit(self.label:GetText()) end)
      c.label:SetFont(ns.Theme.fonts.body, 10, "")
      c:SetPoint("BOTTOMLEFT", 26 + (i - 1) * 184, 32)
      p.chips[i] = c
    end
    p.more = W.Button(p, "More", 52, 18, function() Tab.chips = Tab.chips + 1; Tab.Refresh() end)
    p.more.label:SetFont(ns.Theme.fonts.body, 10, "")
    p.more:SetPoint("BOTTOMRIGHT", 0, 32)
    p.more.tip = "Other examples."

    p.input = W.SearchBox(p, 560, "Ask about a quest, item, recipe, herb, set, dungeon, your training...", nil)
    p.input:SetPoint("BOTTOMLEFT", 0, 2)
    p.input:SetPoint("BOTTOMRIGHT", -66, 2)
    p.input:SetMaxLetters(200)
    p.input:SetScript("OnEnterPressed", function(self)
      local text = self:GetText() or ""
      self:SetText("")
      Tab.Submit(text)
    end)
    p.input:SetScript("OnArrowPressed", function(self, key)
      local h = Ask.history
      if #h == 0 or (key ~= "UP" and key ~= "DOWN") then return end
      Tab.recall = math.max(1, math.min(#h, (Tab.recall or (#h + 1)) + (key == "UP" and -1 or 1)))
      self:SetText(h[Tab.recall].q)
    end)
    p.ask = W.Button(p, "Ask", 60, 22, function()
      local text = p.input:GetText() or ""
      p.input:SetText("")
      Tab.Submit(text)
    end)
    p.ask:SetPoint("BOTTOMRIGHT", 0, 2)
    return p
  end,
  refresh = function() Tab.Refresh(true) end,
})
