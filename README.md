# LOMB Companion

**The guild addon for Land of Make Believe in WoW: Forever.**

LOMB Companion is a free in-game addon made just for the **Land of Make Believe (LOMB)** guild. It keeps the guild's roster, stats, crafters, news and events in one place. It also has a bestiary that fills up as the guild plays. **v0.1 through v0.8 are built**, including v0.6 Quests & Items with data from ForeverDB.net, and get their first in-game test when **WoW: Forever launches on November 4, 2026**.

**New here? Read the [install guide](docs/INSTALL.md).** It takes two minutes, and `/lomb test` tells you if everything works.

It has its own LOMB look instead of the standard Blizzard-style frames, and it lives in one window you can open from the minimap. By default it wears a [storybook look](#storybook-look) made for the Land of Make Believe, and there's a plainer Clean look in Settings if you prefer.

> **Status:** v0.1–v0.8 are built and pass their offline tests, including v0.6 Quests & Items (released as `v0.6.0`, in-game version 0.8.2, with the `v0.6.1` quest chain patch as in-game 0.8.3 and later patches up to the `v0.6.9` forgiving Ask LOMB as in-game 0.9.1, the `v0.6.11` guild activity feed as in-game 0.9.3 the `v0.6.12` launch prep (self-test, welcome tour, more news, sortable lists) as in-game 0.9.4 the `v0.6.13` polish pass (resizable window, tooltips everywhere, faster Bestiary) as in-game 0.9.5 the `v0.6.14` storybook look as in-game 0.9.6 the `v0.6.15` storybook-by-default release as in-game 0.9.7 the `v0.6.16` storybook title bar fix as in-game 0.9.8 and the `v0.6.17` self-test and fixes release as in-game 0.9.9; see the [changelog](CHANGELOG.md)). They are awaiting their first in-game test when WoW: Forever launches on Nov 4, 2026. v0.9 raid tools wait for the live game.

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
>
> The images are sorted into feature folders; see [docs/screenshots](docs/screenshots/README.md) for what's in each.

| Bestiary card + full page | Roster |
|---|---|
| ![Bestiary card and full page](docs/screenshots/bestiary/04-bestiary-expanded.png) | ![Roster tab](docs/screenshots/core/01-roster.png) |
| **Me** | **Bestiary tab** |
| ![Me tab](docs/screenshots/core/02-me.png) | ![Bestiary tab](docs/screenshots/bestiary/05-bestiary-tab.png) |
| **Settings** (Look drop-down open) | **Credits** |
| ![Settings tab](docs/screenshots/core/06-settings.png) | ![Credits tab](docs/screenshots/core/07-credits.png) |
| **Bestiary card (small)** | **Minimap button** |
| ![Bestiary card](docs/screenshots/bestiary/03-card-small.png) | ![Minimap button](docs/screenshots/core/08-minimap-button.png) |
| **Crafters (v0.2)** | **Crafters: search + whisper (v0.2)** |
| ![Crafters tab](docs/screenshots/crafting/09-crafters.png) | ![Crafters search and whisper](docs/screenshots/crafting/10-crafters-search-whisper.png) |
| **News: the guild activity feed (v0.3, v0.6.11)** | **News: dungeon clears only (v0.6.11)** |
| ![News tab](docs/screenshots/news/12-news.png) | ![News filtered to dungeon and raid clears](docs/screenshots/news/51-news-dungeons.png) |
| **News: epic loot only (v0.6.12)** | **Welcome tour (v0.6.12)** |
| ![News filtered to epic loot](docs/screenshots/news/53-news-epic-loot.png) | ![Welcome tour step 2 pointing at the tab list](docs/screenshots/core/54-welcome-tour.png) |
| **Self-test report (v0.6.17)** | **Resizable window with tooltips (v0.6.13)** |
| ![The /lomb test report window with a PASS line for every feature and a Select all button](docs/screenshots/core/55-self-test.png) | ![The window dragged larger, with the News tab tooltip and the resize grip tooltip](docs/screenshots/core/56-resized-tooltips.png) |
| **Bestiary search with no matches (v0.6.13)** | |
| ![Bestiary tab searching for zzz, showing No creatures match](docs/screenshots/bestiary/57-bestiary-empty.png) | |
| **Leaderboard: levels (v0.3)** | **Leaderboard: kills this week (v0.3)** |
| ![Leaderboard levels](docs/screenshots/news/14-leaderboard-levels.png) | ![Leaderboard weekly kills](docs/screenshots/news/15-leaderboard-kills-week.png) |
| **Member profile with recent news (v0.4)** | **Profile from an inspect, no addon (v0.4)** |
| ![Member profile](docs/screenshots/profiles-gear/17-profile.png) | ![Profile filled in by inspecting](docs/screenshots/profiles-gear/18-profile-inspected.png) |
| **Roster with "Hide alts" (v0.4)** | |
| ![Roster hiding alts](docs/screenshots/core/19-roster-hide-alts.png) | |
| **Bestiary filtered to rares, with sightings and last spot (v0.5)** | **Rare alert from a guildmate (v0.5)** |
| ![Bestiary rares filter](docs/screenshots/bestiary/20-bestiary-filters.png) | ![Rare alert toast and chat line](docs/screenshots/bestiary/21-rare-toast.png) |
| **Events: attendance being recorded, officer view (v0.7)** | **Events: a past event, member view (v0.7)** |
| ![Event attendance with officer controls](docs/screenshots/events/22-events-attendance.png) | ![Past event attendance](docs/screenshots/events/23-events-past-member.png) |
| **Attendance summary, last 30 days (v0.7)** | **Optional Bank tab, only if a bank character is ticked (v0.8)** |
| ![Attendance summary](docs/screenshots/events/24-attendance-summary.png) | ![Bank ledger](docs/screenshots/bank-wishlist/25-bank-ledger.png) |
| **Wishlist tab: needs and offers (v0.8.1)** | **Item tooltips: wishlist lines (v0.8.1)** |
| ![Wishlist](docs/screenshots/bank-wishlist/26-wishlist.png) | ![Item tooltips with wishlist lines](docs/screenshots/bank-wishlist/27-item-tooltip-bank-wishlist.png) |
| **Quests & Items: quests in this zone near my level (v0.6)** | **Quests & Items: item lookup (v0.6)** |
| ![Quests & Items, quest page](docs/screenshots/quests-items/28-quests.png) | ![Quests & Items, item page](docs/screenshots/quests-items/29-item-lookup.png) |
| **Quests & Items: a recipe and where to learn it (v0.6)** | **Quests & Items: a dungeon (v0.6)** |
| ![Quests & Items, recipe page](docs/screenshots/quests-items/30-recipe.png) | ![Loot view for Excavation Site: Wetlands with its ForeverDB.net notable loot and no guild drops yet](docs/screenshots/quests-items/31-dungeon.png) |
| **Credits with ForeverDB.net (v0.6)** | **Quest chains tagged and grouped (v0.6.1)** |
| ![Credits tab with the ForeverDB.net credit](docs/screenshots/core/32-credits-foreverdb.png) | ![Quest list with chains grouped and tagged Part 1 of 4 and so on](docs/screenshots/quests-items/33-quest-chains.png) |
| **Storyline drop-downs with quest progress (v0.6.2)** | |
| ![Quest list with closed storyline headers showing level range and progress, and one open storyline with done, turn in and in log tags](docs/screenshots/quests-items/34-quest-storylines.png) | |
| **Training: what's new at your class trainer (v0.6.3)** | **Gathering: a herb node against your skill (v0.6.3)** |
| ![Training view with Train now: four rogue ranks to learn and what comes at level 24](docs/screenshots/guides/35-training.png) | ![Gathering view for Herbalism at skill 85 showing Briarthorn, what it gives and where it grows](docs/screenshots/guides/36-gathering.png) |
| **Item page: what it disenchants into and guild enchanters (v0.6.3)** | **Gear sets: pieces you have and where the rest come from (v0.6.3)** |
| ![Long Battle Bow item page with its disenchant results and guild enchanters](docs/screenshots/guides/37-disenchant.png) | ![Defias Leather set page with set bonuses and pieces equipped, in bags, in bank and missing](docs/screenshots/guides/38-gear-sets.png) |
| **Zones: a zone's quests, vendors and gathering (v0.6.3)** | **Battlegrounds: basic info (v0.6.3)** |
| ![Westfall zone page with its quest storylines and vendors](docs/screenshots/guides/39-zones.png) | ![Warsong Gulch page with levels, team size, how to play and the Classic rules label](docs/screenshots/guides/40-battleground.png) |
| **Rogue poisons (v0.6.3)** | **Ask LOMB: quest turn-ins, chains and quests near your level (v0.6.4)** |
| ![Rogue poisons page with the Poisons quest, the poisons up to level 30, their reagents and suppliers](docs/screenshots/guides/41-rogue-poisons.png) | ![Ask LOMB tab answering where to turn in a quest, what comes next and which quests are near your level](docs/screenshots/ask-lomb/42-ask-lomb-quests.png) |
| **Ask LOMB: who sells it, how to make it, what it disenchants into (v0.6.4)** | **Ask LOMB: dungeons, typos, "I don't know" and the next guild event (v0.6.4)** |
| ![Ask LOMB answering who sells Fine Thread, how to make Heavy Linen Bandage and what Battleforge Boots disenchant into](docs/screenshots/ask-lomb/43-ask-lomb-sells-make.png) | ![Ask LOMB answering a dungeon question, a misspelt quest name, an unknown question and the next guild event](docs/screenshots/ask-lomb/44-ask-lomb-more.png) |
| ![Loot view for the whole Deadmines: ForeverDB.net notable loot and an icon grid of what LOMB saw drop, with counts, quality borders, wishlist hearts and a hover tooltip](docs/screenshots/quests-items/45-loot-dungeon.png) | ![Loot view for Edwin VanCleef: what LOMB saw this boss drop, with a link to the Bestiary](docs/screenshots/quests-items/46-loot-boss.png) |
| ![Ask LOMB answering what drops in Deadmines, what Van Cleef drops and where Cruel Barb drops](docs/screenshots/ask-lomb/47-ask-lomb-loot.png) | ![Loot view filtered to raids, showing Onyxia's Lair before raids open on December 9](docs/screenshots/quests-items/48-loot-raid.png) |

The Quests & Items shots are drawn from the real bundled ForeverDB.net snapshot, rendered through the offline test harness. The quest progress in shot 34 is sample data, and so are the character, skills, known ranks, guild enchanters and owned set pieces in shots 35-41. Shots 42-44 are the real answers the Ask LOMB tab gives for a level 18 rogue in Westfall (the guild event is sample data). In the loot shots 45-47 the notable loot is ForeverDB.net's, but the guild drops, counts and the wishlist heart are sample data, and the item icons are placeholders. Shots 07 and 32 use the Credits tab's real text.

Item tooltips list guildmates who can craft the item (v0.2):

![Crafters on item tooltips](docs/screenshots/crafting/11-item-tooltip-crafters.png)

Mock-up of the bestiary with ForeverDB.net sections (v0.6 shows quest and boss lines from the bundled snapshot):

![Bestiary with ForeverDB sections](docs/screenshots/bestiary/05-bestiary-tab-with-foreverdb.png)

### Storybook look

The storybook look is the default since v0.6.15 (in-game 0.9.7), and every screenshot above shows it: a night-sky violet and gold window with a parchment title bar, a faint starfield, gold flourishes, a moon divider, a small icon on each tab and storybook lines when a page is empty. Lists stay on a dark background, so class and item colours stay easy to read. All the art is made for this addon; no Blizzard art is copied.

Prefer something plainer? Pick **Clean** from the **Settings > Look > Window look** drop-down (the other choice is **Storybook (default)**). The interface reloads to redraw, and your choice is remembered. If you upgrade from 0.9.6 and never changed the look, you get the storybook look; if you pick Clean, it stays Clean.

These are previews with sample data, like the rest of the screenshots.

![The storybook look and the clean look side by side](docs/screenshots/theme/00-storybook-vs-clean.png)

![Storybook empty pages for the Bestiary and News](docs/screenshots/theme/01-storybook-empty-states.png)

---

## What it does

At a glance:

| Area | What you get |
|---|---|
| **Guild** | The full roster with level, class, rank, zone and last seen. Works even for members who don't have the addon. |
| **Me** | Your own stats, including time per level, deaths, loot history and bestiary progress. |
| **Bestiary** | Target a mob to see its level, type, health and what the guild has seen it drop. |
| **Crafters** | "Who can craft X?" search, and crafter info right on item tooltips. |
| **News** | A guild activity feed: level-ups, joins and leaves, rare kills, dungeon and raid clears, new recipes and guild events held, plus fun leaderboards. |
| **Profiles** | Each member's gear, item level, progress, and alts and mains. |
| **Quests & Items** | Quest, item and vendor info inside the game, and a Loot browser for dungeons and raids. |
| **Events** | Guild calendar events and attendance. |
| **Wishlist** | A list of what members need or can give away (plus an optional bank-character ledger, hidden unless a guild uses one). |
| **Raid tools** | Raid helpers and map pins for spawns and rares. |

Everything opens from one movable window with tabs, a minimap button, or the `/lomb` command.

**Item rows work the same everywhere (since v0.6.6, in-game 0.8.8):** wherever the addon lists an item (bestiary page and card, Quests & Items, Ask LOMB, Bank, profile gear, Me, Wishlist), hover for the game's tooltip, **click** to open the item's page in Quests & Items, **shift-click** to put its link in your chat box (nothing is sent) and **Ctrl-click** to try it on in the dressing room. Crafters rows and other members' Wishlist rows keep their whisper on a plain click.

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

### v0.3: News & Leaderboards (built, awaiting in-game test)
- **Guild activity feed:** level-ups, joins and leaves, rare kills, new recipes, and (since v0.6.11) dungeon and raid clears and guild events held, with a filter (All news, Level-ups, Rare kills, Dungeons, New recipes, Guild events, Joins & leaves) and an unread count on the News tab.
  - Level-ups, joins and leaves come from the guild roster, so they include members without the addon. Ones that happened while you were offline are marked with "~".
  - Rare kills and new recipes come from guildmates with the addon. When several of you kill the same rare together it's one line.
  - **Dungeon and raid clears** are posted when a dungeon's last boss dies while you're inside, using the bundled dungeon data and the Bestiary's kill recording. Guildmates in the same group are put on one line, for example "Quillanne, Brindlewick and party cleared Deadmines" ("and party" means people from outside the guild were there too). Scarlet Monastery is counted per wing. Forever's own dungeons don't post clears yet, because their last boss isn't known.
  - **Guild events** that were held show as one line with the attendance count, for example "Guild event Deadmines run was held: 6 attended".
  - It's an activity feed, not a race: there are no "first to" lines.
- **Fun leaderboards:** levels, kills, rares and hours played. Kills and rares can be shown for this week (since the Tuesday reset) or all time. These are just for fun, since shared stats can't be fully verified.
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
Released as `v0.6.0` (in-game version **0.8.2**), with the quest chain patch `v0.6.1` (in-game **0.8.3**), the storyline and quest progress patch `v0.6.2` (in-game **0.8.4**), the guides release `v0.6.3` (in-game **0.8.5**), the Ask LOMB question box `v0.6.4` (in-game **0.8.6**) the local-time, minimap and saved-history patch `v0.6.5` (in-game **0.8.7**) and the item-row patch `v0.6.6` (in-game **0.8.8**) the loot browser `v0.6.7` (in-game **0.8.9**), the clean-up `v0.6.8` (in-game **0.9.0**), the forgiving Ask LOMB patch `v0.6.9` (in-game **0.9.1**), `v0.6.10` (in-game **0.9.2**, superseded), the guild activity feed `v0.6.11` (in-game **0.9.3**), the launch prep release `v0.6.12` (in-game **0.9.4**) the polish pass `v0.6.13` (in-game **0.9.5**) the storybook look `v0.6.14` (in-game **0.9.6**) storybook-by-default `v0.6.15` (in-game **0.9.7**) the storybook title bar fix `v0.6.16` (in-game **0.9.8**) and the self-test and fixes release `v0.6.17` (in-game **0.9.9**). The addon's own version runs ahead of the tags because v0.7 and v0.8 shipped first. Uses **ForeverDB.net** data with their approval (see [Data & credits](#data--credits)). Every place it appears says **"Data from ForeverDB.net"** with https://foreverdb.net as copyable text.
- **Quests & Items tab** with views for Quests, Items, Vendors, Recipes and Loot (called Dungeons before v0.6.7), plus the guide views, each with search and a detail page.
  - **Quests** for levels 1–30: level and minimum level, faction, zone, who starts it and where to turn it in (with map spots), and the quest chain (comes after / leads to; click to follow, "<" to go back). Filters: this zone, near my level (±3) or a level band, and my faction.
  - **Quest chains (v0.6.1):** a chained quest is tagged "Part 2 of 4" in the list (with a thin violet bar), and the quests of a chain are listed together in chain order, where the chain's first listed quest would be. Same-name quests stay separate lines. Chains that branch are cut into straight lines; a branch keeps counting from the quest it branches off. "of 4+" means the chain carries on past level 30.
  - **Storyline drop-downs (v0.6.2):** each linked storyline, branches included, is one header row with its name, level range and progress ("12-18 · 4/9 done"). Headers start closed; click to open. Inside, quests are in story order with their "Part X of Y" tags, and a branch sits under the quest it splits off. Filters apply to the parts, and the header counts only those.
  - **Quest progress (v0.6.2, not tried on live servers yet):** "done", "in log" and "turn in" tags in the list, and a "You" line on the quest page. It reads the game's quest log and completed-quest history where the client allows, and also saves every turn-in it sees on this character, so it still counts up if the game won't share its history. `/lomb questcheck` shows what the game is telling the addon.
  - **Items:** required level and slot, who sells it (vendor, price, limited stock), what makes it or what recipe it teaches, what it's a reagent in, quests it starts, dungeons that list it as notable loot, and guildmates who can craft it.
  - **Vendors:** location, faction and what they sell with prices.
  - **Recipes:** skill colours, reagents, and how to learn it (trainer and cost, vendor, quest, drop or automatic). Your own faction's trainers come first.
  - **Loot (v0.6.7, in-game 0.8.9):** a loot browser in the style of AtlasLoot. Pick a dungeon or raid, then **Whole dungeon**, a boss or **Trash**, and get an icon grid with quality-coloured borders. Filters: dungeons and/or raids, and a minimum quality. Search finds dungeons, bosses and notable item names.
    - **Notable loot** is ForeverDB.net's list of picks for that dungeon. It's labelled as notable loot: it isn't the full loot table, has no drop rates, and isn't tied to a boss (ForeverDB.net doesn't say which boss drops what).
    - **What LOMB saw drop** comes from the guild's bestiary: each icon shows how many times guildmates looted it ("LOMB saw it drop: N" in the tooltip) and which mob dropped it. On a boss or Trash, only guild-recorded drops are shown. Items ForeverDB.net doesn't list are still shown, as guild-only finds.
    - Icons work like every other item row: hover for the tooltip, click opens the item page, shift-click links it in chat, Ctrl-click previews it. The **heart** adds it to your Wishlist needs (click again to remove it).
    - Item pages show **Where it drops** (notable loot and guild drops) and link to the grid, and bestiary boss pages link to their boss's loot.
    - Raids show up when ForeverDB.net lists them (Onyxia's Lair so far). Raids open in WoW: Forever on December 9.
    - Ask LOMB answers "What drops in Deadmines?", "What does Van Cleef drop?" and "Where does Cruel Barb drop?".
    - No ForeverDB.net requests at runtime, and no Classic loot tables.
- **Bestiary links:** a mob's page lists the quests it starts or ends, and a boss shows its dungeon.
- **Crafters links:** recipe info (skill, reagents, where to learn it) on crafter results, linking into the Recipes view.
- **Item tooltips:** one optional line from the snapshot (who sells it, what makes it, what it's a reagent for). There's a switch in Settings.
- **Not included:** quest rewards (ForeverDB.net doesn't have them yet, so the page says to check the quest window in game) and mob loot tables (those stay guild-recorded only).
- **Guides (v0.6.3, in-game 0.8.5):** four more views in the Quests & Items tab, plus extra sections on item and mob pages. Everything links to everything else (a zone opens its quests, a herb opens its zones, a set piece opens its item page, and so on).
  - **Training:** pick a class (yours by default) and see what each level brings, with a **Train now** page for ranks at or below your level. "Known" comes from the game's spellbook check, and the class trainer window marks what you already have. Costs show once you've opened your class trainer, because ForeverDB.net has no trainer costs. Optional chat reminder on level-up, only you see it (Settings > Training). `/lomb train` opens it. Hunters also get pet skills.
  - **Gathering:** Herbalism, Mining, Skinning and Fishing. Each node shows the skill it needs, what it gives and where it grows. The **Where to level** page shows the best zones by skill band, with yours highlighted. Filter by "My skill". Skinning lists beasts by zone and skill; mob pages in the bestiary show the skill a beast needs. Spawn spots, skinning and fishing are Classic data and labelled.
  - **Disenchanting:** item pages show what an uncommon, rare or epic weapon or armour piece disenchants into, and which items disenchant into a material. There's also an optional tooltip line (Settings). Guild enchanters (you, plus guildmates whose profile shows Enchanting) are listed, with online ones in green. The disenchant table is Classic data and labelled.
  - **Gear sets:** the 5 sets up to level 30, with set bonuses, which pieces you have (equipped, in bags, or in your bank the last time you opened it) and where to get the rest (vendor, crafted, dungeon). Missing pieces can be added to the wishlist in one click. ForeverDB.net says these sets are hidden in the current client, so the page says they're unconfirmed.
  - **Zones:** each zone's quest count and level range (worked out from its quests), storylines, vendors and gathering (ForeverDB.net's dungeon list doesn't say which zone a dungeon is in). Battleground pages show levels, team size, how to win and how to play; the rules are Classic's and labelled.
  - **Rogue poisons:** under Training for rogues: the Poisons quest, the poisons up to level 30 with reagents, skill and cost, and suppliers and trainers seen in WoW: Forever.
- **Ask LOMB (v0.6.4, in-game 0.8.6):** a question box in its own tab. Type a question in plain words and press Enter; the answer appears in a scrolling history, and violet lines open the matching page in Quests & Items (or ask a follow-up). It works entirely offline: answers come from the bundled ForeverDB.net snapshot and what the guild shares through the addon. Since v0.6.9 (in-game 0.9.1) it reads questions forgivingly: it ignores case, punctuation and filler words, knows common short forms and synonyms (q/quest, lvl/lv/level, mob/creature/npc, drop/loot, vendor/sell/buy, make/craft/create, where/find/location, dungeon/instance), forgives typos in names ("deadmine", "van cleef", "vancleef"), and weighs every possible reading of a question instead of needing one exact pattern. It's still word matching plus name search, not an AI, and it never says anything in chat. `/lomb ask <question>` prints the answer in your chat window, where only you see it.
  - **It understands:** where a quest starts and is turned in, what comes next in a chain, who sells an item, how to make it, which guildmates can craft it, what it disenchants into, what drops it (guild-recorded only), which set it's in, where a herb or ore grows and where to level a gathering skill, what to train, a dungeon's level and bosses, a zone or battleground, where an NPC stands, quests near your level, for a level or in a zone, and the next guild event. Shift-clicked item links work too.
  - **Examples:** "Where do I turn in The Defias Brotherhood?", "Who sells Fine Thread?", "How do I make Heavy Linen Bandage?", "What does Battleforge Boots disenchant into?", "Where can I find Briarthorn?", "Deadmines level and bosses", "Quests near my level", "What comes after Red Leather Bandanas?", "When is the next guild event?". The tab has buttons for these.
  - **Level phrasings** all work: "quests my level", "quests near/at/for my level", "around my lvl", "lvl 20 quests", "quests for 20", "level 20 quests", "quests 18-22". "My zone" and "here" mean the zone you're in.
  - **When it isn't sure,** it answers with its best guess and adds "Did you mean …?" lines to click for the other likely readings, names the closest matches (so typos still work), and otherwise says "I don't know that one" with example questions to click. Answers that use ForeverDB.net data end with "Data from ForeverDB.net · https://foreverdb.net", and Classic-sourced facts keep their "(Classic data, may differ)" label. Since v0.6.5 (in-game 0.8.7) the history is saved for each character and comes back after a reload or log-in (the last 40 questions, marked "Saved from earlier"); **Clear** deletes the saved copy too.
  - **Minimap:** right-click the minimap button to go straight to Ask LOMB (left-click still opens and closes the window; Ctrl-click now shows the bestiary card).

### v0.7: Events & Attendance (built, awaiting in-game test)
- **Events tab:** guild events and announcements from the in-game calendar, upcoming and past, with the organizer, the time and your sign-up status. Since v0.6.5 (in-game 0.8.7), times are shown in your own local time and labelled, for example "8:00 PM (your time)", here and in Ask LOMB. The calendar gives realm (server) times, so the addon converts them using the game's server clock. If it can't work out the difference, it shows the calendar's time labelled "(realm time, not converted; unverified until Nov 4)". The addon never changes the calendar and doesn't read it while you have the calendar window open.
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
- Raid helpers, raid **attendance** (building on v0.7) and **soft reserves** for loot, picked from the Loot browser's grids. No DKP or points.
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
- **v0.6.8 (in-game 0.9.0):** code clean-up with no behaviour change: unused code removed, shared helpers merged, Ask LOMB's history in its own file, and tidier tests and data tools.
- **v0.6.11 (in-game 0.9.3):** News is a guild activity feed: level-ups, joins and leaves, rare kills and new recipes as before, plus dungeon and raid clears (one line per group, with a Dungeons filter) and guild events held with their attendance. The profile's "Recent news" panel is back.
- **v0.6.12 (in-game 0.9.4):** launch prep. `/lomb test` checks that everything works and makes a report you can copy, a four-step welcome tour (reopen it from Settings or with `/lomb tour`), News lines for epic loot, first mounts and welcome backs (14+ days away) with their own filters, and sortable column headers on the Roster, Crafters, Bank, Wishlist and attendance lists. Plus an [install guide](docs/INSTALL.md) and a [launch-day checklist](docs/LAUNCH-CHECKLIST.md).
- **v0.6.14 (in-game 0.9.6):** an optional storybook look (Settings > Look): a night-sky violet and gold window with a parchment title bar, stars, gold flourishes, tab icons and storybook lines on empty pages.
- **v0.6.15 (in-game 0.9.7):** the storybook look is now the default, and Settings > Look is a drop-down: Storybook (default) or Clean. Every screenshot shows the storybook look.
- **v0.6.17 (in-game 0.9.9):** `/lomb test` now checks every feature (one read-only line each), plus fixes from a code review: guild data from other addons is cleaned before it is shown, gear isn't wiped before the roster loads, a lost /played is no longer swallowed, and the wishlist heart no longer errors when the list is full.
- **v0.6.16 (in-game 0.9.8):** a tidier storybook title bar: matching corner flourishes in both top corners, outside the close button and the moon.
- **v0.6.13 (in-game 0.9.5):** polish pass. A resizable window (drag the corner grip; right-click it for the default size), a tooltip on every control and tab, lists that keep their scroll position, clearer empty states, "…" on long names, and a Bestiary tab that refreshes about 4× faster with a big bestiary.
- **v0.6.10 (in-game 0.9.2):** superseded by v0.6.11 (see the [changelog](CHANGELOG.md)).
- **v0.6.9 (in-game 0.9.1):** Ask LOMB is much more forgiving: synonyms, short forms, typos, many ways to say a level, "my zone"/"here", and "Did you mean …?" suggestions. Still offline and not an AI.
- **v0.6.7 (in-game 0.8.9):** the Loot browser in Quests & Items (dungeon, boss or trash icon grids from ForeverDB.net's notable loot and the guild's recorded drops, with wishlist hearts), "Where it drops" on item pages, loot questions in Ask LOMB, and refreshed Credits screenshots.
- **v0.6.6 (in-game 0.8.8):** item rows behave the same everywhere: click opens the item page, shift-click links it in chat, Ctrl-click previews it, with a hint on every tooltip.
- **v0.6.5 (in-game 0.8.7):** event times in your local time ("8:00 PM (your time)") in the Events tab and Ask LOMB, right-click on the minimap button opens Ask LOMB, and the Ask LOMB history is kept per character across reloads.
- **v0.6.4 (in-game 0.8.6):** the Ask LOMB tab, an offline question box over the bundled ForeverDB.net data and the guild's shared data, and `/lomb ask <question>` (only you see the answer).
- **v0.6.3 (in-game 0.8.5):** Training, Gathering, Zones (with battlegrounds) and Sets views, rogue poisons, disenchant info on item pages and tooltips, a level-up trainer reminder and `/lomb train`.
- **v0.6.2 (in-game 0.8.4):** storylines are drop-down headers with level range and progress, and quests show done / in log / turn in where the game allows (plus turn-ins the addon sees itself).
- **v0.6.1 (in-game 0.8.3):** quest chains are tagged "Part k of n" and grouped in the quest list.
- **v0.6.0 (in-game 0.8.2) is built:** the Quests & Items tab (quests, items, vendors, recipes and dungeons for levels 1–30 from a bundled ForeverDB.net snapshot), quest and boss lines in the bestiary, recipe info in Crafters, an optional ForeverDB.net tooltip line, and the ForeverDB.net credit and support line in Credits.
- **v0.8.1 is built:** the guild Wishlist in its own tab (needs and offers, filters, search, click to whisper) with wishlist lines on item tooltips. The Bank tab (a bank character's items, recent changes and funds) is hidden unless someone ticks "This is a guild bank character". Rare alerts are now silent by default.
- **v0.7.0 is built:** the Events tab (guild calendar events), attendance recorded from the organizer's group and merged across guildmates, officer corrections, and a 30-day attendance summary. 
- **v0.5.0 is built:** Bestiary filters and sorting, zone completion, sighting counts, catch-up of bestiary records made while you were offline, and rare alerts (pop-up, sound and chat line, with the spot on the map).
- **v0.4.0 is built:** member profiles (gear, item level, XP progress, stats, professions, recent news), alt and main linking with a "Hide alts" roster option, and inspect-based gear for guildmates without the addon.
- **v0.3.0 is built:** the News tab (level-ups, joins and leaves, rare kills, new recipes) and the Leaderboard tab (levels, kills, rares, hours played; weekly or all time). Its level races were removed in v0.6.10.
- **v0.2.0 is built:** the Crafters tab ("who can craft X?", filter by profession, online only, click to whisper, shift-click to link), crafter names on item tooltips, and a sidebar menu so more tabs fit. Recipes are read when you open a profession window and shared as recipe IDs only.
- It has an offline test suite (a fake WoW API runs the whole addon, including the windows) plus a linter. Both pass.
- **It can't be tested in the real game until WoW: Forever launches on November 4, 2026.** Expect a quick follow-up fix (v0.1.1) after launch, because the game's addon rules can change between beta and the live release.
- Real testing needs at least two guild members running the addon.

---

## Install

📘 **Step-by-step guide with troubleshooting: [docs/INSTALL.md](docs/INSTALL.md).** For launch day testing, see the [launch checklist](docs/LAUNCH-CHECKLIST.md).

1. Download the newest `LOMBCompanion-v*.zip` from this repo's **Releases** page.
2. Unzip it into your WoW: Forever AddOns folder:
   ```
   World of Warcraft/<Forever game folder>/Interface/AddOns/
   ```
   You should end up with `Interface/AddOns/LOMBCompanion/LOMBCompanion.toc`.
3. Restart the game, or type `/reload` if you're already logged in.
4. Make sure **LOMB Companion** is ticked in the AddOns list on the character select screen.
5. Type `/lomb test` to check that everything works.
6. Click the minimap button or type `/lomb` to open it (right-click the button for Ask LOMB, Ctrl-click for the bestiary card, Shift-click for settings). `/lomb help` lists every command.

The exact game folder name will be confirmed when WoW: Forever goes live.

**Commands:** `/lomb` (open/close), `/lomb <tab>` (for example `/lomb roster`, `/lomb events` or `/lomb wishlist`; `/lomb help` lists them all), `/lomb card` (show/hide the bestiary card), `/lomb test` (self-test with a copyable report), `/lomb tour` (the welcome tour again), `/lomb status`, `/lomb sync`, `/lomb questcheck` (what the game tells the addon about your quests), `/lomb train` (what's new at your class trainer), `/lomb ask <question>` (ask LOMB; only you see the answer). You can also set key bindings under *Key Bindings > AddOns > LOMB Companion*.

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
  - **Bundled snapshot:** addons can't go online, so we fetch the data with the API occasionally (a few times a week at most, and after game patches), well under ForeverDB.net's limits, and ship it in its own clearly marked folder, `LOMBCompanion/Data/ForeverDB/` (about 1.1 MB). Each file starts with the credit and the snapshot date.
  - **What's in it:** quests, vendors, professions/recipes and dungeons for levels 1–30, plus only the items those mention (name, quality, required level and slot). Since v0.6.3 also class abilities by level, gathering nodes and zones, the disenchant table, item sets, rogue poisons, zones and battlegrounds.
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
- Ask LOMB never sends anything anywhere. Its history (your last 40 questions and the answers shown) is saved only in this character's own SavedVariables file on your computer, and Clear deletes it.

---

## License

The addon's code is MIT licensed. See [LICENSE](LICENSE).

The MIT license covers **only our code**. It doesn't cover Blizzard's game data or any third-party data. ForeverDB.net data lives in its own clearly marked file that stays ForeverDB.net's: it may not be reused, resold or presented as anyone else's, and it keeps their credit and rules.
