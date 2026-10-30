-- LOMB Companion: Credits tab.
local _, ns = ...
local T, W, UI = ns.Theme, ns.Widgets, ns.UI

UI.RegisterTab({
  id = "credits", label = "Credits", order = 100,
  build = function(parent)
    local p = CreateFrame("Frame", nil, parent)
    local logo = p:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(T.LOGO)
    logo:SetSize(72, 72)
    logo:SetPoint("TOP", 0, -6)
    local title = W.Text(p, "title", 24, "accent", "CENTER")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -6)
    title:SetText("LOMB Companion")
    local ver = W.Text(p, "narrow", 11, "muted", "CENTER")
    ver:SetPoint("TOP", title, "BOTTOM", 0, -2)
    ver:SetText("v" .. ns.version .. "  ·  made for the Land of Make Believe guild  ·  MIT license")

    p.body = W.Text(p, "body", 12, "text", "CENTER")
    p.body:SetPoint("TOP", ver, "BOTTOM", 0, -18)
    p.body:SetWidth(520)
    p.body:SetWordWrap(true)
    p.body:SetSpacing(4)
    p.data = W.Text(p, "body", 12, "gold", "CENTER")
    p.data:SetPoint("TOP", p.body, "BOTTOM", 0, -14)
    p.data:SetWidth(520)
    p.data:SetWordWrap(true)
    p.data:SetSpacing(3)
    -- ForeverDB.net: credit, copyable link and a support line
    p.fdb = W.Text(p, "body", 11, "text", "CENTER")
    p.fdb:SetPoint("TOP", p.data, "BOTTOM", 0, -10)
    p.fdb:SetWidth(540)
    p.fdb:SetWordWrap(true)
    p.fdb:SetSpacing(3)
    p.fdbUrl = W.CopyBox(p, 190, "https://foreverdb.net")
    p.fdbUrl:SetPoint("TOPRIGHT", p.fdb, "BOTTOM", -4, -8)
    p.supportUrl = W.CopyBox(p, 250, "https://buymeacoffee.com/foreverdb")
    p.supportUrl:SetPoint("TOPLEFT", p.fdb, "BOTTOM", 4, -8)
    local foot = W.Text(p, "narrow", 10, "muted", "CENTER")
    foot:SetPoint("BOTTOM", 0, 4)
    foot:SetText("github.com/lomb-hana/lomb-app  ·  Not affiliated with Blizzard Entertainment.")
    return p
  end,
  refresh = function(p)
    p.body:SetText(table.concat({
      "Built by and for LOMB. Every number in the bestiary was recorded by guildmates",
      "playing -- kills, loot and abilities -- and shared over the guild addon channel.",
      "",
      "|cff9a92a8Sources are tagged on every fact:|r  " .. T.color("game", "GAME") .. " live from your client,  "
        .. T.color("guild", "GUILD") .. " recorded by LOMB members"
        .. ((ns.FDB and ns.FDB.Available()) and (",  " .. T.color("foreverdb", "FOREVERDB") .. " from ForeverDB.net.") or "."),
    }, "\n"))
    local lines = {}
    local fdbOn = ns.FDB and ns.FDB.Available()
    for _, prov in ipairs(ns.Providers.list) do
      -- the ForeverDB credit gets its own paragraph below
      if prov.credit and not (fdbOn and prov.url == ns.FDB.URL) then
        lines[#lines + 1] = prov.credit .. (prov.url and ("  |cff9a92a8" .. prov.url .. "|r") or "")
      end
    end
    p.data:SetText(table.concat(lines, "\n"))
    local FDB = ns.FDB
    local on = FDB and FDB.Available()
    p.fdb:SetShown(on); p.fdbUrl:SetShown(on); p.supportUrl:SetShown(on)
    if on then
      p.fdb:SetText(table.concat({
        "Quests & Items, and the quest and boss lines in the bestiary: |cfff2c75cData from ForeverDB.net|r "
          .. "(https://foreverdb.net), used with permission. Snapshot " .. tostring(FDB.Snapshot() or "?")
          .. "; that data isn't covered by this addon's MIT license.",
        "ForeverDB's help keeps this project alive. Support them at https://buymeacoffee.com/foreverdb",
      }, "\n"))
    end
  end,
})
