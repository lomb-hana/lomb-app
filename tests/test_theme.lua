local H = dofile((arg[0]:match("^(.*)/[^/]+$") or ".") .. "/harness.lua")
local ROOT = (arg[0]:match("^(.*)/tests/[^/]+$") or ".") .. "/LOMBCompanion/"

print("Looks: clean and storybook")

local function same(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end

H.test("a fresh install gets the storybook look", function()
  local ns = H.boot()
  H.eq(ns.db.settings.theme, "storybook")
  H.eq(ns.db.settings.themeChosen, false, "nothing chosen yet")
  H.eq(ns.Theme.look, "storybook")
  ns.UI.Open("roster"); H.advance(0.3, 0.3)
  H.ok(ns.UI.tabButtons.roster.icon, "tab icons drawn")
  H.ok(ns.UI.flourishes, "flourishes drawn")
end)

H.test("upgrading: an untouched clean default becomes storybook, a chosen look is kept", function()
  -- 0.9.6 saved theme = "clean" for everyone who never ticked the box
  local ns = H.boot({ db = { schema = 1, settings = { theme = "clean" } } })
  H.eq(ns.db.settings.theme, "storybook", "old unticked default")
  H.eq(ns.Theme.look, "storybook")
  ns = H.boot({ db = { schema = 1, settings = { theme = "storybook" } } })
  H.eq(ns.db.settings.theme, "storybook", "old ticked box")
  ns = H.boot({ db = { schema = 1, settings = { theme = "clean", themeChosen = true } } })
  H.eq(ns.db.settings.theme, "clean", "Clean picked in Settings stays")
  H.eq(ns.Theme.look, "clean")
  ns = H.boot({ db = { settings = { theme = "purple", themeChosen = true } } })
  H.eq(ns.db.settings.theme, "storybook", "a broken saved value becomes the default")
  ns = H.boot({ db = { settings = { theme = "clean", themeChosen = true } } })
  H.eq(ns.db.settings.theme, "clean", "kept across more reloads")
end)

H.test("the clean look, once chosen, draws no storybook extras", function()
  local ns = H.boot({ db = { settings = { theme = "clean", themeChosen = true } } })
  local T = ns.Theme
  H.eq(ns.db.settings.theme, "clean")
  H.eq(T.look, "clean")
  for k, c in pairs(T.palettes.clean) do H.ok(same(T.colors[k], c), k .. " is the clean colour") end
  ns.UI.Open("roster")
  for id, b in pairs(ns.UI.tabButtons) do H.ok(not b.icon, id .. " has no icon") end
  H.ok(not ns.UI.flourishes, "no flourishes")
  H.eq(ns.UI.titleClose.points[1][2], -6, "the X where it always was")
  H.eq(ns.UI.titleClose.w, 22)
  H.eq(ns.UI.titleLogo.points[1][2], 8, "the moon where it always was")
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
  H.eq(#ns.UI.flourishes, 4, "four flourishes")
  -- title bar: mirrored ink flourishes in both top corners, outside the X and the logo
  local fl, fr = ns.UI.flourishes[1], ns.UI.flourishes[2]
  H.eq(fl.points[1][1], "TOPLEFT"); H.eq(fl.points[1][2], 3); H.eq(fl.points[1][3], -3)
  H.eq(fr.points[1][1], "TOPRIGHT"); H.eq(fr.points[1][2], -3); H.eq(fr.points[1][3], -3)
  H.eq(fl.w, fr.w, "same size")
  H.eq(fl.texCoord and fl.texCoord[1], 0, "left one as drawn")
  H.eq(fr.texCoord and fr.texCoord[1], 1, "right one mirrored")
  local close, logo = ns.UI.titleClose, ns.UI.titleLogo
  local cp, lp = close.points[#close.points], logo.points[#logo.points]
  H.ok(cp[1] == "RIGHT" and -cp[4] >= 3 + 26, "the X sits left of the right flourish")
  H.ok(lp[1] == "LEFT" and lp[4] >= 3 + 26, "the moon sits right of the left flourish")
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

H.test("Settings > Look is a drop-down: Storybook (default) or Clean, with a reload", function()
  local ns = H.boot()
  ns.UI.Open("settings"); H.advance(0.3, 0.3)
  local dd = H.tab(ns, "settings").panel.checks.theme
  H.ok(dd and dd.button and dd.menu, "Look drop-down")
  H.eq(dd.button.label.text, "Storybook (default)", "shows the current look")
  H.eq(#dd.items, 2)
  H.eq(dd.items[1].label.text, "Storybook (default)")
  H.eq(dd.items[2].label.text, "Clean")
  H.ok(not dd.menu:IsShown(), "closed until clicked")
  dd.button.scripts.OnClick(dd.button)
  H.ok(dd.menu:IsShown(), "opens on click")
  H.ok(dd.items[1].active and not dd.items[2].active, "current choice marked")
  -- picking the look you already have does nothing
  dd.items[1].scripts.OnClick(dd.items[1])
  H.ok(not dd.menu:IsShown(), "closes after a pick")
  H.ok(not (ns.Widgets.confirm and ns.Widgets.confirm:IsShown()), "same look: no reload")
  dd.button.scripts.OnClick(dd.button)
  dd.items[2].scripts.OnClick(dd.items[2])
  H.eq(ns.db.settings.theme, "clean")
  H.eq(ns.db.settings.themeChosen, true, "remembered as a choice")
  H.eq(dd.button.label.text, "Clean")
  local d = ns.Widgets.confirm
  H.ok(d and d:IsShown(), "asks to reload")
  d.yes.scripts.OnClick(d.yes)
  H.eq(H.reloads, 1, "reloads on yes")
  dd.button.scripts.OnClick(dd.button)
  dd.items[1].scripts.OnClick(dd.items[1])
  H.eq(ns.db.settings.theme, "storybook", "back to storybook")
  H.ok(not d:IsShown(), "already storybook: no reload needed")
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
