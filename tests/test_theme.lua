local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
local ROOT = (arg[0]:match("^(.*)/tests/[^/]+$") or ".") .. "/LOMBCompanion/"

print("Looks: clean and storybook")

local function same(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end

H.test("the clean look is the default and draws no storybook extras", function()
  local ns = H.boot()
  local T = ns.Theme
  H.eq(ns.db.settings.theme, "clean")
  H.eq(T.look, "clean")
  for k, c in pairs(T.palettes.clean) do H.ok(same(T.colors[k], c), k .. " is the clean colour") end
  ns.UI.Open("roster")
  for id, b in pairs(ns.UI.tabButtons) do H.ok(not b.icon, id .. " has no icon") end
  H.ok(not ns.UI.flourishes, "no flourishes")
  H.eq(T.Playful("bestiary.none", "plain"), "plain")
end)

H.test("a saved storybook look is applied before any window is built", function()
  local ns = H.boot({ db = { settings = { theme = "storybook" } } })
  local T = ns.Theme
  H.eq(T.look, "storybook")
  H.ok(same(T.colors.accent, T.palettes.storybook.accent), "gold accent")
  H.ok(same(T.colors.good, T.palettes.clean.good), "colours the storybook leaves alone stay")
  H.ok(T.classification.elite[2] == T.colors.gold, "shared colour tables still point at the live palette")
  ns.UI.Open("roster"); H.advance(0.5, 0.5)
  for _, tab in ipairs(ns.UI.tabs) do
    local b = ns.UI.tabButtons[tab.id]
    H.ok(b.icon and b.icon.texturePath == T.TabIcon(tab.id), tab.id .. " has its icon")
  end
  local roster = ns.UI.tabButtons.roster
  H.ok(same(roster.icon.vertex, T.colors.accent), "the open tab's icon is gold")
  H.ok(same(ns.UI.tabButtons.news.icon.vertex, T.colors.muted), "other icons are muted")
  H.eq(#ns.UI.flourishes, 3, "three flourishes")
  H.ok(ns.UI.storyDivider, "moon divider in the sidebar")
  for _, tab in ipairs(ns.UI.tabs) do ns.UI.Open(tab.id); H.advance(0.3, 0.3) end
  H.noErrors("every tab in the storybook look")
end)

H.test("storybook empty states are storybook lines, clean ones stay plain", function()
  local ns = H.boot({ db = { settings = { theme = "storybook" } } })
  ns.UI.Open("bestiary"); H.advance(0.5, 0.5)
  local p = H.tab(ns, "bestiary").panel
  H.eq(p.empty.text, ns.Theme.PLAYFUL["bestiary.none"])
  ns.UI.Open("news"); H.advance(0.5, 0.5)
  H.eq(H.tab(ns, "news").panel.empty.text, ns.Theme.PLAYFUL["news.none"])
end)

H.test("switching looks round-trips every colour exactly", function()
  local ns = H.boot()
  local T = ns.Theme
  T.Apply("storybook"); T.Apply("nonsense")
  H.eq(T.look, "clean", "an unknown look falls back to clean")
  for k, c in pairs(T.palettes.clean) do H.ok(same(T.colors[k], c), k .. " restored") end
end)

H.test("Settings > Look switches and offers a reload", function()
  local ns = H.boot()
  ns.UI.Open("settings"); H.advance(0.3, 0.3)
  local c = H.tab(ns, "settings").panel.checks.storybook
  H.ok(c, "Look checkbox")
  c.scripts.OnClick(c)
  H.eq(ns.db.settings.theme, "storybook")
  local d = ns.Widgets.confirm
  H.ok(d and d:IsShown(), "asks to reload")
  d.yes.scripts.OnClick(d.yes)
  H.eq(H.reloads, 1, "reloads on yes")
  c.scripts.OnClick(c)
  H.eq(ns.db.settings.theme, "clean", "unticking goes back")
  H.ok(not d:IsShown(), "already clean: no reload needed")
end)

local function read(path) local f = io.open(path, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end

H.test("every storybook line is used, and every Playful key has a line", function()
  local ns = H.boot()
  local src = ""
  for _, f in ipairs({ "BestiaryTab", "BoardTab", "CraftersTab", "BankTab", "NewsTab", "EventsTab", "RosterTab", "WishlistTab", "MobPage" }) do
    src = src .. (read(ROOT .. "UI/" .. f .. ".lua") or "")
  end
  for key in pairs(ns.Theme.PLAYFUL) do H.ok(src:find('Playful("' .. key .. '"', 1, true), key .. " is used") end
  for key in src:gmatch('Playful%("([%w%.]+)"') do H.ok(ns.Theme.PLAYFUL[key], key .. " has a storybook line") end
end)

H.test("storybook art is shipped as power-of-two 32-bit TGAs", function()
  local ns = H.boot()
  local files = {}
  for _, p in pairs(ns.Theme.STORY) do files[#files + 1] = p end
  for id in pairs(ns.Theme.TAB_ICON_IDS) do files[#files + 1] = ns.Theme.TabIcon(id) end
  for _, p in ipairs(files) do
    local rel = p:gsub("^Interface\\AddOns\\LOMBCompanion\\", ""):gsub("\\", "/") .. ".tga"
    local s = read(ROOT .. rel)
    H.ok(s, rel .. " exists")
    if s then
      local w, h = s:byte(13) + s:byte(14) * 256, s:byte(15) + s:byte(16) * 256
      local pow2 = function(n) return n > 0 and math.floor(math.log(n) / math.log(2) + 0.5) == math.log(n) / math.log(2) end
      H.ok(s:byte(3) == 2 and s:byte(17) == 32, rel .. " is uncompressed 32-bit")
      H.ok(pow2(w) and pow2(h), rel .. " is " .. w .. "x" .. h)
    end
  end
end)

H.done()
