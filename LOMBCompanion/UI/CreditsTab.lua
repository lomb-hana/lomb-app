-- LOMB Companion: Credits tab.
local _, ns = ...
local T, W, UI = ns.Theme, ns.Widgets, ns.UI

UI.RegisterTab({
  id = "credits", label = "Credits", order = 5,
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
        .. T.color("guild", "GUILD") .. " recorded by LOMB members.",
    }, "\n"))
    local lines = {}
    for _, prov in ipairs(ns.Providers.list) do
      if prov.credit then lines[#lines + 1] = prov.credit .. (prov.url and ("  |cff9a92a8" .. prov.url .. "|r") or "") end
    end
    p.data:SetText(table.concat(lines, "\n"))
  end,
})
