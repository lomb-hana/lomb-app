# LOMB Companion

**The guild addon for Land of Make Believe in WoW: Forever.**

LOMB Companion is a free in-game addon made just for the **Land of Make Believe (LOMB)** guild. It keeps the guild's roster, stats, crafters, news and events in one place. It also has a bestiary that fills up as the guild plays. **v0.1 through v0.8 are built**, including v0.6 Quests & Items with data from ForeverDB.net, and get their first in-game test when **WoW: Forever launches on November 4, 2026**.

It has its own LOMB look instead of the standard Blizzard-style frames, and it lives in one window you can open from the minimap.

> **Status:** v0.1–v0.8 are built and pass their offline tests, including v0.6 Quests & Items (released as `v0.6.0`, in-game version 0.8.2, with the `v0.6.1` quest chain patch as in-game 0.8.3; see the [changelog](CHANGELOG.md)). They are awaiting their first in-game test when WoW: Forever launches on Nov 4, 2026. v0.9 raid tools wait for the live game.

> ☕ Quest, item and vendor data comes from [ForeverDB.net](https://foreverdb.net). Their help keeps this project alive, so if you can, [support ForeverDB.net](https://buymeacoffee.com/foreverdb).

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
| **Leaderboard: firsts (v0.3)** | **Member profile (v0.4)** |
| ![Leaderboard firsts](docs/screenshots/16-leaderboard-firsts.png) | ![Member profile](docs/screenshots/17-profile.png) |
| **Profile from an inspect, no addon (v0.4)** | **Roster with "Hide alts" (v0.4)** |
| ![Profile filled in by inspecting](docs/screenshots/18-profile-inspected.png) | ![Roster hiding alts](docs/screenshots/19-roster-hide-alts.png) |
| **Bestiary filtered to rares, with sightings and last spot (v0.5)** | **Rare alert from a guildmate (v0.5)** |
| ![Bestiary rares filter](docs/screenshots/20-bestiary-filters.png) | ![Rare alert toast and chat line](docs/screenshots/21-rare-toast.png) |
| **Events: attendance being recorded, officer view (v0.7)** | **Events: a past event, member view (v0.7)** |
| ![Event attendance with officer controls](docs/screenshots/22-events-attendance.png) | ![Past event attendance](docs/screenshots/23-events-past-member.png) |
| **Attendance summary, last 30 days (v0.7)** | **Optional Bank tab, only if a bank character is ticked (v0.8)** |
| ![Attendance summary](docs/screenshots/24-attendance-summary.png) | ![Bank ledger](docs/screenshots/25-bank-ledger.png) |
| **Wishlist tab: needs and offers (v0.8.1)** | **Item tooltips: wishlist lines (v0.8.1)** |
| ![Wishlist](docs/screenshots/26-wishlist.png) | ![Item tooltips with wishlist lines](docs/screenshots/27-item-tooltip-bank-wishlist.png) |
| **Quests & Items: quests in this zone near my level (v0.6)** | **Quests & Items: item lookup (v0.6)** |
| ![Quests & Items, quest page](docs/screenshots/28-quests.png) | ![Quests & Items, item page](docs/screenshots/29-item-lookup.png) |
| **Quests & Items: a recipe and where to learn it (v0.6)** | **Quests & Items: a dungeon (v0.6)** |
| ![Quests & Items, recipe page](docs/screenshots/30-recipe.png) | ![Quests & Items, dungeon page](docs/screenshots/31-dungeon.png) |
| **Credits with ForeverDB.net (v0.6)** | **Quest chains tagged and grouped (v0.6.1)** |
| ![Credits tab with the ForeverDB.net credit](docs/screenshots/32-credits-foreverdb.png) | ![Quest list with chains grouped and tagged Part 1 of 4 and so on](docs/screenshots/33-quest-chains.png) |

The Quests & Items shots are drawn from the real bundled ForeverDB.net snapshot, rendered through the offline test harness.

Item tooltips list guildmates who can craft the item (v0.2):

![Crafters on item tooltips](docs/screenshots/11-item-tooltip-crafters.png)

Mock-up of the bestiary with ForeverDB.net sections (v0.6 shows quest and boss lines from the bundled snapshot):

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
| **Wishlist** | A list of what members need or can give away (plus an optional bank-character ledger, hidden unless a guild uses one). |
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

### v0.4: Profiles & Gear (built, awaiting in-game test)
- **Member profiles:** click anyone on the roster to open their page: equipped gear (with item tooltips), item level, empty slots, XP progress, hours played, kills, rares, professions and their recent news. There's a Whisper button too.
  - Gear is shared as item and enchant IDs only. XP is shared in 5% steps. Both stop if you turn off profile sharing.
- **Alts and mains:** on the Me tab, click the "Main" button to say which of your characters is your main (or that this one is). Alts show their main in brackets on the roster, mains show "+N", and a "Hide alts" box hides alts from the list.
  - For guildmates without the addon, public notes like "alt of Name" or "Name's alt" are understood too.
  - Your main is only shared once you pick one.
- **Inspect:** when you inspect a guildmate yourself, their gear is remembered on your computer so their profile can show it even if they don't have the addon. It's never sent to anyone.

### v0.5: Bestiary+ (built, awaiting in-game test)
- **Filters and sorting:** the Bestiary list can show all creatures, rares, elites, this zone, guild-killed, not killed yet, or killed by me, sorted by name, level, kills or most recent. Click to step forward, right-click to step back.
- **Zone completion:** the list shows how many creatures known in your current zone the guild has killed (e.g. "Westfall: 31 of 38 killed (82%)").
- **Sightings:** each different spawn you see is counted once, and the mob page shows guild sightings and your own kills next to guild kills.
- **Catching up:** when you log in, guildmates send you the bestiary records they made since you were last online. One guildmate also passes on records from members who are offline now, so nothing is missed.
- **Rare alerts:** when you or a guildmate spots a rare, a LOMB-styled alert pops up and a line appears in chat. Alerts are silent by default; tick "Play a sound with rare alerts" if you want one. Click the alert to open the rare in the Bestiary; drag it to move it.
  - What's shared: the rare's name and level, the zone, and the spotter's map spot as whole numbers (e.g. 61, 72). Nothing else about where you are.
  - Each rare is announced at most once every 10 minutes per person, several guildmates spotting the same rare show as one alert, and there are no pop-ups during boss fights or PvP matches.
  - Three switches in Settings: tell guildmates, show alerts (both on), play a sound (off). "Preview a rare alert" shows what one looks like.

### v0.6: Quests & Items (built, awaiting in-game test)
Released as `v0.6.0` (in-game version **0.8.2**), with the quest chain patch `v0.6.1` (in-game **0.8.3**). The addon's own version runs ahead of the tags because v0.7 and v0.8 shipped first. Uses **ForeverDB.net** data with their approval (see [Data & credits](#data--credits)). Every place it appears says **"Data from ForeverDB.net"** with https://foreverdb.net as copyable text.
- **Quests & Items tab** with five views: Quests, Items, Vendors, Recipes and Dungeons, each with search and a detail page.
  - **Quests** for levels 1–30: level and minimum level, faction, zone, who starts it and where to turn it in (with map spots), and the quest chain (comes after / leads to; click to follow, "<" to go back). Filters: this zone, near my level (±3) or a level band, and my faction.
  - **Quest chains (v0.6.1):** a chained quest is tagged "Part 2 of 4" in the list (with a thin violet bar), and the quests of a chain are listed together in chain order, where the chain's first listed quest would be. Same-name quests stay separate lines. Chains that branch are cut into straight lines; a branch keeps counting from the quest it branches off. "of 4+" means the chain carries on past level 30.
  - **Items:** required level and slot, who sells it (vendor, price, limited stock), what makes it or what recipe it teaches, what it's a reagent in, quests it starts, dungeons that list it as notable loot, and guildmates who can craft it.
  - **Vendors:** location, faction and what they sell with prices.
  - **Recipes:** skill colours, reagents, and how to learn it (trainer and cost, vendor, quest, drop or automatic). Your own faction's trainers come first.
  - **Dungeons:** level range, bosses and ForeverDB's notable loot picks (labelled as picks, not a drop table).
- **Bestiary links:** a mob's page lists the quests it starts or ends, and a boss shows its dungeon.
- **Crafters links:** recipe info (skill, reagents, where to learn it) on crafter results, linking into the Recipes view.
- **Item tooltips:** one optional line from the snapshot (who sells it, what makes it, what it's a reagent for). There's a switch in Settings.
- **Not included:** quest rewards (ForeverDB.net doesn't have them yet, so the page says to check the quest window in game) and mob loot tables (those stay guild-recorded only).

### v0.7: Events & Attendance (built, awaiting in-game test)
- **Events tab:** guild events and announcements from the in-game calendar, upcoming and past, with the organizer, the time and your sign-up status. The addon never changes the calendar and doesn't read it while you have the calendar window open.
- **Attendance:** from 15 minutes before an event until it ends, anyone grouped with the organizer takes a snapshot of the group every 5 minutes (after combat, never during it). Anyone seen in the group at least once counts as present, and the percentage shows how much of the event they were there for.
- **Shared and merged:** recordings from several guildmates are combined, so it works even if the organizer doesn't have the addon or someone disconnects. Only names and snapshot counts are shared.
- **Officer fixes:** the top two guild ranks (changeable in saved settings) can mark someone present or remove them, and undo it. Everyone sees who made each fix. Fixes from anyone else are ignored.
- **Attendance summary:** each member's attendance over the last 30 days. Attendance is kept for 90 days.
- Two switches in Settings: record attendance, and share what I record.

### v0.8: Wishlist (+ optional Bank) (built, awaiting in-game test)
- **Wishlist tab:** has its own sidebar entry and works whether or not the guild has a bank character.
- **Bank tab (optional, hidden by default):** LOMB doesn't use a bank character, so the Bank tab doesn't appear. It only shows up if someone ticks "This is a guild bank character" in Settings on a character (per character; nothing is guessed from names or notes). If they untick it, the tab goes away again.
- WoW: Forever doesn't have a guild bank, at least as far as anyone knows. If a guild does set up a bank character, its **ledger** shows what that character is holding. It's updated whenever someone plays that character: its bags are counted all the time, and its bank whenever the bank window is open.
- **Recent changes:** what went in and out (for example "+20 Linen Cloth, 12m ago"). Moving things between the bags and the bank doesn't count, and the first look at the bank is just a starting point.
- **Guild bank funds:** the bank character's own gold, and nobody else's. There's a switch to hide it.
- **Wishlist:** what members need (for example, "need 4 Linen for bags") and what they can give away. Up to 20 entries per character; your own entries drop off after 60 days. Shift-click an item into the box, or type a name or a few words.
- Clicking a guildmate's wishlist row starts a whisper in your chat box; you still press Enter yourself.
- **Item tooltips** say who in the guild wants or offers that item. The "Guild bank has" line only appears if a bank character exists.
- If a real guild bank shows up later, the addon will read that instead.

### v0.9: Raid-ready (raids open Dec 9)
- Raid helpers, raid **attendance** (building on v0.7) and **soft reserves** for loot. No DKP or points.
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
- **v0.6.1 (in-game 0.8.3):** quest chains are tagged "Part k of n" and grouped in the quest list.
- **v0.6.0 (in-game 0.8.2) is built:** the Quests & Items tab (quests, items, vendors, recipes and dungeons for levels 1–30 from a bundled ForeverDB.net snapshot), quest and boss lines in the bestiary, recipe info in Crafters, an optional ForeverDB.net tooltip line, and the ForeverDB.net credit and support line in Credits.
- **v0.8.1 is built:** the guild Wishlist in its own tab (needs and offers, filters, search, click to whisper) with wishlist lines on item tooltips. The Bank tab (a bank character's items, recent changes and funds) is hidden unless someone ticks "This is a guild bank character". Rare alerts are now silent by default.
- **v0.7.0 is built:** the Events tab (guild calendar events), attendance recorded from the organizer's group and merged across guildmates, officer corrections, and a 30-day attendance summary. 
- **v0.5.0 is built:** Bestiary filters and sorting, zone completion, sighting counts, catch-up of bestiary records made while you were offline, and rare alerts (pop-up, sound and chat line, with the spot on the map).
- **v0.4.0 is built:** member profiles (gear, item level, XP progress, stats, professions, recent news), alt and main linking with a "Hide alts" roster option, and inspect-based gear for guildmates without the addon.
- **v0.3.0 is built:** the News tab (level-ups, joins and leaves, rare kills, new recipes, guild and class milestones) and the Leaderboard tab (levels, kills, rares, hours played, firsts; weekly or all time).
- **v0.2.0 is built:** the Crafters tab ("who can craft X?", filter by profession, online only, click to whisper, shift-click to link), crafter names on item tooltips, and a sidebar menu so more tabs fit. Recipes are read when you open a profession window and shared as recipe IDs only.
- It has an offline test suite (a fake WoW API runs the whole addon, including the windows) plus a linter. Both pass.
- **It can't be tested in the real game until WoW: Forever launches on November 4, 2026.** Expect a quick follow-up fix (v0.1.1) after launch, because the game's addon rules can change between beta and the live release.
- Real testing needs at least two guild members running the addon.

---

## Install

1. Download the newest `LOMBCompanion-v*.zip` from this repo's **Releases** page.
2. Unzip it into your WoW: Forever AddOns folder:
   ```
   World of Warcraft/<Forever game folder>/Interface/AddOns/
   ```
   You should end up with `Interface/AddOns/LOMBCompanion/LOMBCompanion.toc`.
3. Restart the game, or type `/reload` if you're already logged in.
4. Make sure **LOMB Companion** is ticked in the AddOns list on the character select screen.
5. Click the minimap button or type `/lomb` to open it. `/lomb help` lists every command.

The exact game folder name will be confirmed when WoW: Forever goes live.

**Commands:** `/lomb` (open/close), `/lomb <tab>` (for example `/lomb roster`, `/lomb events` or `/lomb wishlist`; `/lomb help` lists them all), `/lomb card` (show/hide the bestiary card), `/lomb status`, `/lomb sync`. You can also set key bindings under *Key Bindings > AddOns > LOMB Companion*.

### For developers

- `bash tests/run.sh` runs the offline tests (needs Lua 5.1).
- `luacheck .` lints the code.
- `tools/build.sh` builds `dist/LOMBCompanion-v<version>.zip`.
- `tools/build_foreverdb.py` rebuilds `LOMBCompanion/Data/ForeverDB/` from the ForeverDB.net API. The key is read only from the `FOREVERDB_API_KEY` environment variable and is never written anywhere; requests go one at a time, at least 2 seconds apart, with backoff, and every response is cached so nothing is fetched twice.

---

## Data & credits

- **Game data:** World of Warcraft and WoW: Forever game data belong to **Blizzard Entertainment**. LOMB Companion is a fan-made guild addon and is **not affiliated with or endorsed by Blizzard Entertainment**.
- **ForeverDB.net (approved):** quest, item, vendor, profession and dungeon data comes from the [ForeverDB.net](https://foreverdb.net) developer API, used with ForeverDB.net's approval for this guild addon. How we use it:
  - **Credit everywhere:** every tab, card and tooltip that shows their data says **"Data from ForeverDB.net"** with the link [https://foreverdb.net](https://foreverdb.net), and the Credits tab says so too. (Addons can't open web links in game, so clicking the credit copies the link.)
  - **Bundled snapshot:** addons can't go online, so we fetch the data with the API occasionally (a few times a week at most, and after game patches), well under ForeverDB.net's limits, and ship it in its own clearly marked folder, `LOMBCompanion/Data/ForeverDB/` (about 800 KB). Each file starts with the credit and the snapshot date.
  - **What's in it:** quests, vendors, professions/recipes and dungeons for levels 1–30, plus only the items those mention (name, quality, required level and slot).
  - **Classic data:** ForeverDB.net marks what was seen in WoW: Forever and what comes from Classic. Vendors and trainers never seen in Forever are left out. Quests from Classic data are kept but labelled "Classic data, may differ" (a small "c" in lists). Classic dungeon level ranges and bosses are labelled, Classic trainer costs are left out, and Classic drop sources for recipes just say "drop".
  - **The API key never ships:** it's kept off the addon and out of this repo.
  - **Not ours:** the data stays ForeverDB.net's. It isn't covered by this repo's MIT license, isn't resold, and isn't presented as our own. ForeverDB.net's labels (data seen in WoW Forever vs. Classic data) are kept.
  - ForeverDB.net isn't affiliated with Blizzard Entertainment, and neither are we.
  - If ForeverDB.net ever asks us to change or remove anything, we will.
  - **Support ForeverDB.net:** their work is what keeps this project going. If the addon helps you, consider [buying them a coffee](https://buymeacoffee.com/foreverdb).
- **Guild-recorded data:** bestiary sightings, kills and loot come from Land of Make Believe members playing the game. These are tagged **GUILD**. Facts read live from your game client are tagged **GAME**.
- **Wowhead:** linked to only. Its data isn't copied or collected.

---

## Privacy

- No personal info about anyone goes in this repo.
- Member data like levels, gear and professions stays inside the game and the guild. It's saved on members' own computers and shared only over the in-game guild addon channel.
- Nothing is uploaded to any website or server.
- Rare alerts share where the spotter was standing (zone plus whole-number map spot) at that moment only. Turn it off with "Tell guildmates when I spot a rare".
- Event attendance shares only which guildmates were in the organizer's group and how many snapshots they were seen in. No locations or anything else. Turn it off with "Share the event attendance I record".
- The bank ledger is off unless someone ticks "This is a guild bank character". If they do, it's shared only from that character (its items, recent changes and, if the switch is on, its own gold as "guild bank funds"). No one else's bags or gold are read for sharing.
- The wishlist shares only what you add to it yourself (item, quantity, a short note).

---

## License

The addon's code is MIT licensed. See [LICENSE](LICENSE).

The MIT license covers **only our code**. It doesn't cover Blizzard's game data or any third-party data. ForeverDB.net data lives in its own clearly marked file that stays ForeverDB.net's: it may not be reused, resold or presented as anyone else's, and it keeps their credit and rules.
