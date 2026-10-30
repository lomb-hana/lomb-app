-- LOMB Companion: guild roster + which members run the addon (and their shared profiles).
local _, ns = ...
local C = ns.Compat
local Roster = ns:NewModule("Roster")

Roster.members = {}     -- array of member rows (rebuilt on GUILD_ROSTER_UPDATE)
Roster.byName = {}
Roster.lastRequest = 0
Roster.REQUEST_INTERVAL = 10

function Roster.Request(force)
  local now = GetTime()
  if not force and now - Roster.lastRequest < Roster.REQUEST_INTERVAL then return end
  Roster.lastRequest = now
  local fn = (C_GuildInfo and C_GuildInfo.GuildRoster) or _G.GuildRoster
  C.Call(fn)
end

-- Hours since last online, from GetGuildRosterLastOnline (years, months, days, hours).
local function lastOnlineHours(index)
  local y, m, d, h = C.Call(_G.GetGuildRosterLastOnline, index)
  if not y and not m and not d and not h then return nil end
  return (y or 0) * 8760 + (m or 0) * 730 + (d or 0) * 24 + (h or 0)
end

-- Roster changes since the last scan (also across logouts, via the saved
-- per-member level): GUILD_JOIN(name), GUILD_LEAVE(name),
-- GUILD_LEVELUP(name, newLevel, oldLevel, classFile, away).
-- `away` = true when the change happened while we were logged off (first scan
-- of the session), so its time is only "sometime since your last login".
Roster.scansThisSession = 0

function Roster.Scan()
  local g = ns.DB.Guild()
  local members, byName = {}, {}
  local total = C.Call(GetNumGuildMembers) or 0
  local seeded = g and g.rosterSeeded
  local away = Roster.scansThisSession == 0
  local changes = {}
  for i = 1, total do
    local name, rankName, rankIndex, level, className, zone, _, _, online, status, classFile =
      C.Call(GetGuildRosterInfo, i)
    if name then
      local full = C.FullName(name)
      local row = {
        name = full, short = C.ShortName(full), rank = rankName, rankIndex = rankIndex,
        level = level, className = className, class = classFile, zone = zone,
        online = online and true or false, status = status,
        lastOnlineHours = online and 0 or lastOnlineHours(i),
      }
      if g then
        local peer = g.peers[full]
        row.peer = peer
        local mem = g.members[full]
        if not mem then
          mem = {}
          if seeded then changes[#changes + 1] = { "GUILD_JOIN", full } end
        elseif mem.gone then
          mem.gone = nil
          changes[#changes + 1] = { "GUILD_JOIN", full }
        end
        if seeded and type(level) == "number" and type(mem.level) == "number" and level > mem.level then
          changes[#changes + 1] = { "GUILD_LEVELUP", full, level, mem.level, classFile, away }
        end
        if online then mem.seen = time() end
        mem.level, mem.class = level, classFile
        g.members[full] = mem
        row.lastSeen = mem.seen
      end
      members[#members + 1] = row
      byName[full] = row
    end
  end
  -- leavers: only trust a complete roster (some clients list online members only)
  if g and seeded and total > 0 and #members == total then
    for name, mem in pairs(g.members) do
      if not byName[name] and not mem.gone then
        mem.gone = time()
        changes[#changes + 1] = { "GUILD_LEAVE", name }
      end
    end
  end
  if g and total > 0 and #members == total then g.rosterSeeded = true end
  if total > 0 then Roster.scansThisSession = Roster.scansThisSession + 1 end
  Roster.members, Roster.byName = members, byName
  Roster.online = 0
  for _, r in ipairs(members) do if r.online then Roster.online = Roster.online + 1 end end
  for _, c in ipairs(changes) do ns:Fire(unpack(c, 1, 6)) end
  ns:Fire("ROSTER_UPDATED", members)
end
Roster.ScanSoon = ns.Debounce(0.5, Roster.Scan)

-- Called by Sync when a guildmate's addon says hello / shares a profile.
function Roster.UpdatePeer(sender, data)
  local g = ns.DB.Guild()
  if not g then return end
  local peer = g.peers[sender] or {}
  peer.v = data.v or peer.v
  peer.seen = time()
  if data.t == "P" then
    if data.off then
      peer.profile = nil
      peer.sharing = false
    else
      peer.sharing = true
      peer.profile = {
        lv = tonumber(data.lv), cl = type(data.cl) == "string" and data.cl or nil,
        il = tonumber(data.il), pt = tonumber(data.pt),
        pr = type(data.pr) == "table" and data.pr or nil,
        ts = time(),
      }
    end
  end
  g.peers[sender] = peer
  local row = Roster.byName[sender]
  if row then row.peer = peer end
  ns:Fire("PEER_UPDATED", sender, peer)
end

function Roster.PeerCount()
  local g = ns.DB.Guild()
  if not g then return 0 end
  local n = 0
  for name, peer in pairs(g.peers) do
    if name ~= ns.playerKey and peer.seen and time() - peer.seen < 30 * 86400 then n = n + 1 end
  end
  return n
end

-- Display list: filter + sort.
function Roster.View(opts)
  opts = opts or {}
  local q = opts.search and opts.search:lower() or ""
  local out = {}
  for _, r in ipairs(Roster.members) do
    if (not opts.onlineOnly or r.online) and (not opts.addonOnly or r.peer) then
      if q == "" or (r.short or ""):lower():find(q, 1, true)
        or (r.zone or ""):lower():find(q, 1, true)
        or (r.className or ""):lower():find(q, 1, true) then
        out[#out + 1] = r
      end
    end
  end
  local key, desc = opts.sort or "online", opts.desc
  table.sort(out, function(a, b)
    local av, bv
    if key == "online" then
      if a.online ~= b.online then return a.online end
      av, bv = a.lastOnlineHours or 1e9, b.lastOnlineHours or 1e9
      if av == bv then return (a.short or "") < (b.short or "") end
      return av < bv
    end
    av, bv = a[key], b[key]
    if av == bv then return (a.short or "") < (b.short or "") end
    if av == nil then return false end
    if bv == nil then return true end
    if desc then return av > bv end
    return av < bv
  end)
  return out
end

function Roster.FormatLastOnline(row)
  if row.online then return "|cff7fe07fOnline|r" end
  local h = row.lastOnlineHours
  if not h then return "|cff888888-|r" end
  if h < 1 then return "<1h" end
  if h < 24 then return ("%dh"):format(h) end
  local d = math.floor(h / 24)
  if d < 30 then return ("%dd"):format(d) end
  local mo = math.floor(d / 30)
  if mo < 12 then return ("%dmo"):format(mo) end
  return ("%dy"):format(math.floor(mo / 12))
end

function Roster:Login()
  Roster.Request(true)
  ns.Every(60, function() Roster.Request() end)
end

ns:On("GUILD_ROSTER_UPDATE", function() Roster.ScanSoon() end)
ns:On("PLAYER_GUILD_UPDATE", function() Roster.Request(true) end)
