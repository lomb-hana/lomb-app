# LOMB Companion

**The guild addon for Land of Make Believe in WoW: Forever.**

LOMB Companion is a free in-game addon made just for the **Land of Make Believe (LOMB)** guild. It keeps the guild's roster, stats, crafters, news and events in one place. It also has a bestiary that fills up as the guild plays. **v0.1: Core is built** and gets its first in-game test when **WoW: Forever launches on November 4, 2026**.

It has its own LOMB look instead of the standard Blizzard-style frames, and it lives in one window you can open from the minimap.

> **Status:** v0.1: Core is built and passes its offline tests. It's awaiting its in-game test when WoW: Forever launches on Nov 4, 2026, and a quick v0.1.1 may follow that first test.

---

## Contents

- [Screenshots](#screenshots)
- [What it does](#what-it-does)
- [Roadmap](#roadmap)
- [How it works](#how-it-works)
- [Design decisions](#design-decisions)
- [Status](#status)
- [Install](#install)
- [Data & credits](#data--credits)
- [Privacy](#privacy)
- [License](#license)

---

## Screenshots

> **Previews only.** These are mock-ups with sample data that mirror the addon's real layout and look. WoW: Forever isn't out yet, so they're not in-game captures.

| Bestiary card + full page | Roster |
|---|---|
| ![Bestiary card and full page](docs/screenshots/04-bestiary-expanded.png) | ![Roster tab](docs/screenshots/01-roster.png) |
| **Me** | **Bestiary tab** |
| ![Me tab](docs/screenshots/02-me.png) | ![Bestiary tab](docs/screenshots/05-bestiary-tab.png) |
| **Settings** | **Credits** |
| ![Settings tab](docs/screenshots/06-settings.png) | ![Credits tab](docs/screenshots/07-credits.png) |
| **Bestiary card (small)** | **Minimap button** |
| ![Bestiary card](docs/screenshots/03-card-small.png) | ![Minimap button](docs/screenshots/08-minimap-button.png) |
| **Crafters (v0.2)** | **Crafters: search + whisper (v0.2)** |
| ![Crafters tab](docs/screenshots/09-crafters.png) | ![Crafters search and whisper](docs/screenshots/10-crafters-search-whisper.png) |
| **News (v0.3)** | **News: milestones only (v0.3)** |
| ![News tab](docs/screenshots/12-news.png) | ![News filtered to milestones](docs/screenshots/13-news-milestones.png) |
| **Leaderboard: levels (v0.3)** | **Leaderboard: kills this week (v0.3)** |
| ![Leaderboard levels](docs/screenshots/14-leaderboard-levels.png) | ![Leaderboard weekly kills](docs/screenshots/15-leaderboard-kills-week.png) |
| **Leaderboard: firsts (v0.3)** | |
| ![Leaderboard firsts](docs/screenshots/16-leaderboard-firsts.png) | |

Item tooltips list guildmates who can craft the item (v0.2):

![Crafters on item tooltips](docs/screenshots/11-item-tooltip-crafters.png)

How the bestiary would look *if* ForeverDB.net approves using their data (not shipped):

![Bestiary with ForeverDB sections](docs/screenshots/05-bestiary-tab-with-foreverdb.png)

---

## What it does

At a glance:

| Area | What you get |
|---|---|
| **Guild** | The full roster with level, class, rank, zone and last seen. Works even for members who don't have the addon. |
| **Me** | Your own stats, including time per level, deaths, loot history and bestiary progress. |
| **Bestiary** | Target a mob to see its level, type, health and what the guild has seen it drop. |
| **Crafters** | "Who can craft X?" search, and crafter info right on item tooltips. |
| **News** | A guild feed of level-ups, joins, milestones and first kills, plus fun leaderboards. |
| **Profiles** | Each member's gear, item level, progress, and alts and mains. |
| **Quests & Items** | Quest, item and vendor info inside the game. |
| **Events** | Guild calendar events and attendance. |
| **Bank & Wishlist** | A ledger for the guild's bank character, and a list of what members need or can give away. |
| **Raid tools** | Raid helpers and map pins for spawns and rares. |

Everything opens from one movable window with tabs, a minimap button, or the `/lomb` command.

---

## Roadmap

### v0.1: Core (built, awaiting in-game test when WoW: Forever launches Nov 4)
- **Main window** with Roster, Me, Bestiary, Settings and Credits tabs, in the custom LOMB style.
- **Minimap button** and the `/lomb` slash command.
- **Guild roster:** level, class, rank, zone, online status and last seen for the whole guild. It reads the game's own guild roster, so it covers members who don't have the addon too.
- **Me tab:** your personal stats, recorded on your own computer: level-up times, deaths and a loot log.
- **Bestiary card:** target a mob to see its level, type, family and health (when the game lets addons read them), plus how many times the guild has killed it and what it has dropped for guild members. Pin it to keep it on one mob, or expand it to a full bestiary page.
- **Basic sync:** members with the addon recognize each other and automatically share level, class, professions, gear and playtime. There's an **off switch** in Settings if you'd rather not share.

### v0.2: Who Can Craft (built, awaiting in-game test)
- Members share their professions and known recipes.
- Search "who can craft X?" and whisper the crafter straight from the result.
- Item tooltips get a line showing which guildmates can craft that item.

### v0.3: News & Milestones (built, awaiting in-game test)
- **Guild news feed:** level-ups, joins and leaves, rare kills, new recipes and milestones, with a filter and an unread count on the News tab.
  - Level-ups, joins and leaves come from the guild roster, so they include members without the addon. Ones that happened while you were offline are marked with "~".
  - Rare kills and new recipes come from guildmates with the addon. When several of you kill the same rare together it's one line.
- **Milestones:** first to level 10, 20, and so on up to 60, for the whole guild and per class.
- **Fun leaderboards:** levels, kills, rares, hours played and "firsts". Kills and rares can be shown for this week (since the Tuesday reset) or all time. These are just for fun, since shared stats can't be fully verified.
- **Off switch** in Settings: "Share my news and leaderboard stats". Hours played are only shared if profile sharing is on too.

### v0.4: Profiles & Gear
- **Member profiles:** equipped gear, average item level, empty slots, level progress and professions.
- **Alts and mains:** link alts to their main so the roster groups them.
- When you're standing next to someone, their gear can also be filled in by inspecting them.

### v0.5: Bestiary+
- **Full bestiary page for every mob:** level, type and family, elite or rare, where it's been seen, abilities seen, loot, seen and killed counts, and completion % per zone.
- **Guild loot recording:** each member's addon records what drops after a fight and shares it, so the bestiary's loot tables grow as the guild plays.
- **Rare alerts** when a rare mob is spotted.
- Leaderboards for kills and rares.

### v0.6: Quests & Items
- Quest info (who gives it and which mobs you need), item details and vendor info.
- Item tooltips show things like "the guild has seen this drop X times" and "this is on a guildmate's wishlist".
- Uses **ForeverDB.net** data **if they approve** (see [Data & credits](#data--credits)).

### v0.7: Events & Attendance
- Reads guild events from the in-game calendar.
- Tracks attendance by who was grouped with the organizer during the event.
- Officers can correct attendance.

### v0.8: Bank & Wishlist
- WoW: Forever doesn't have a guild bank, at least as far as anyone knows. Instead, a **bank-character ledger** shows what the guild's bank character is holding. It's updated whenever someone logs into that character.
- **Wishlist:** what members need (for example, "need 4 Linen for bags") and what they can give away.
- If a real guild bank shows up later, the addon will read that instead.

### v0.9: Raid-ready (raids open Dec 9)
- Raid helpers, plus optional loot tracking and soft reserves or points if guild leadership wants them.
- **Map pins** for mob spawns and rares.

### v1.0: Polish
- A fuller Settings tab, a performance pass, a routine for updating data with each game patch, and translations if wanted.

---

## How it works

In plain English:

- **Addons can't go online.** WoW addons have no internet access, so everything the addon knows either comes **bundled inside the addon's files** or is **recorded in game** while you play.
- **Members share with each other.** Each member's copy of the addon reads that character's own info, such as level, gear and professions. It then quietly passes that info to guildmates' copies over the game's hidden guild addon channel. You never see these messages in chat.
- **Only members with the addon share data.** The basic roster works for everyone. Detailed info like gear and professions only appears for members who have the addon installed.
- **It plays by the game's rules.** WoW: Forever runs on the modern game client, which limits what addons can do:
  - Addons **can't read the combat log**, so things are recorded before or after fights instead of during them.
  - Some info is hidden from addons during combat. The addon shows "?" instead of guessing.
  - **Syncing pauses during dungeon and raid boss fights and PvP matches,** then catches up after.
  - The game limits how fast addons can send messages, so big lists like recipes and loot sync a little at a time.
  - Trial accounts can receive guild data but can't send it.
- **Your data stays local.** Everything is saved in the game's normal addon save files on your own computer, and nothing gets uploaded anywhere.

---

## Design decisions

- **Guild-only.** It's built for Land of Make Believe. It only talks over the in-game guild addon channel, so it only ever exchanges data with members of your own guild.
- **GitHub only.** Releases go here. There won't be CurseForge or Wago listings.
- **No Classic loot data.** Bestiary loot tables come **only from what the guild records** in WoW: Forever, so every drop shown is something a LOMB member actually saw.
- **Not Hardcore.** The guild isn't playing the Hardcore ruleset, so there's no death log or memorial wall.
- **Sharing is on by default.** Gear, professions and playtime are shared automatically with guildmates, and you can turn it off anytime in Settings.
- **Custom LOMB look.** The addon has its own style instead of default Blizzard frames.
- **Free, with no ads or combat advantage,** following Blizzard's addon rules.

---

## Status

- **v0.1.0 is built** (Roster, Me, Bestiary, Settings and Credits tabs, the bestiary card and full bestiary page, minimap button, `/lomb`, and guild sync).
- **v0.3.0 is built:** the News tab (level-ups, joins and leaves, rare kills, new recipes, guild and class milestones) and the Leaderboard tab (levels, kills, rares, hours played, firsts; weekly or all time).
- **v0.2.0 is built:** the Crafters tab ("who can craft X?", filter by profession, online only, click to whisper, shift-click to link), crafter names on item tooltips, and a sidebar menu so more tabs fit. Recipes are read when you open a profession window and shared as recipe IDs only.
- It has an offline test suite (a fake WoW API runs the whole addon, including the windows) plus a linter. Both pass.
- **It can't be tested in the real game until WoW: Forever launches on November 4, 2026.** Expect a quick follow-up fix (v0.1.1) after launch, because the game's addon rules can change between beta and the live release.
- Real testing needs at least two guild members running the addon.

---

## Install

1. Download `LOMBCompanion-v0.1.0.zip` from this repo's **Releases** page.
2. Unzip it into your WoW: Forever AddOns folder:
   ```
   World of Warcraft/<Forever game folder>/Interface/AddOns/
   ```
   You should end up with `Interface/AddOns/LOMBCompanion/LOMBCompanion.toc`.
3. Restart the game, or type `/reload` if you're already logged in.
4. Make sure **LOMB Companion** is ticked in the AddOns list on the character select screen.
5. Click the minimap button or type `/lomb` to open it. `/lomb help` lists every command.

The exact game folder name will be confirmed when WoW: Forever goes live.

**Commands:** `/lomb` (open/close), `/lomb roster | me | bestiary | settings | credits`, `/lomb card` (show/hide the bestiary card), `/lomb status`, `/lomb sync`. You can also set key bindings under *Key Bindings > AddOns > LOMB Companion*.

### For developers

- `bash tests/run.sh` runs the offline tests (needs Lua 5.1).
- `luacheck .` lints the code.
- `tools/build.sh` builds `dist/LOMBCompanion-v<version>.zip`.

---

## Data & credits

- **Game data:** World of Warcraft and WoW: Forever game data belong to **Blizzard Entertainment**. LOMB Companion is a fan-made guild addon and is **not affiliated with or endorsed by Blizzard Entertainment**.
- **ForeverDB.net (pending):** we've asked [ForeverDB.net](https://foreverdb.net) whether we can include their quest, item, vendor and profession data in the addon. **We won't use any of their data unless they approve.** If they do, every place it appears will say **"Data from ForeverDB.net"**, with a link to [https://foreverdb.net](https://foreverdb.net).
- **Guild-recorded data:** bestiary sightings, kills and loot come from Land of Make Believe members playing the game. These are tagged **GUILD**. Facts read live from your game client are tagged **GAME**.
- **Wowhead:** linked to only. Its data isn't copied or collected.

---

## Privacy

- No personal info about anyone goes in this repo.
- Member data like levels, gear and professions stays inside the game and the guild. It's saved on members' own computers and shared only over the in-game guild addon channel.
- Nothing is uploaded to any website or server.

---

## License

The addon's code is MIT licensed. See [LICENSE](LICENSE).

The MIT license covers **only our code**. It doesn't cover Blizzard's game data or any third-party data. If ForeverDB.net data is ever added, it will live in its own clearly marked file that stays ForeverDB.net's: it may not be reused, resold or presented as anyone else's, and it keeps their credit and rules.
