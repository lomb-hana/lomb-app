# Changelog

Release tags follow the roadmap (v0.1 … v1.0). The addon's own version, shown in game and in the TOC, is separate: **release v0.6.0 is in-game version 0.8.2**, because v0.7 and v0.8 were built before ForeverDB.net approved API access for v0.6.

Nothing here has been tested in the real game yet. WoW: Forever launches on November 4, 2026.

## v0.6.0 (in-game 0.8.2): Quests & Items, 2026-10-30

Pre-release, untested in game.

- **New Quests & Items tab** with Quests, Items, Vendors, Recipes and Dungeons views, using a bundled snapshot of [ForeverDB.net](https://foreverdb.net) data (levels 1–30), used with permission.
  - Quests: level, faction, zone, start and turn-in NPCs with map spots, and the quest chain with click-through and a back button. Filters for this zone, near my level or a level band, and my faction.
  - Items: required level and slot, vendors and prices, recipes, reagent uses, quests started, notable dungeon loot, guild crafters.
  - Vendors: location, faction and stock with prices.
  - Recipes: skill colours, reagents, how to learn it. Your own faction's trainers are listed first and the other faction's are marked.
  - Dungeons: level range, bosses and ForeverDB.net's notable loot picks (not a drop table).
- **Bestiary:** mob pages list the quests the NPC starts or ends; bosses link to their dungeon.
- **Crafters:** recipe info on results, with a link to the Recipes view.
- **Item tooltips:** an optional ForeverDB.net line (sold by, made by, reagent for), with a switch in Settings.
- **Credits:** the ForeverDB.net credit, snapshot date and a support line (https://buymeacoffee.com/foreverdb), with both links as copyable text.
- Every place that shows this data says "Data from ForeverDB.net" and shows https://foreverdb.net as copyable text.
- **Classic data:** vendors and trainers never seen in WoW: Forever are left out; quests from Classic data are kept and labelled; Classic dungeon details are labelled; Classic trainer costs are left out.
- **Not included:** quest rewards (not in ForeverDB.net's data yet) and mob loot (still guild-recorded only).
- Data lives in `LOMBCompanion/Data/ForeverDB/` (about 800 KB), each file headed with the credit and snapshot date. It isn't covered by this project's MIT license.
- `tools/build_foreverdb.py` rebuilds the snapshot. The API key comes only from the environment and is never stored; requests are sequential, spaced out, cached and backed off.

## v0.8.1: Wishlist tab, optional Bank, quiet rare alerts

- Wishlist in its own tab; the Bank tab only shows when a bank character is ticked; rare alerts are silent by default.

## v0.8.0: Bank & Wishlist

- Guild bank ledger from a bank character and the first wishlist.

## v0.7.0: Events & Attendance

- Events tab from the guild calendar, attendance snapshots merged across guildmates, officer fixes and a 30-day summary.

## v0.5.0: Bestiary+

- Bestiary filters and sorting, zone completion, sightings, offline catch-up and rare alerts.

## v0.4.0: Profiles & Gear

- Member profiles, alt and main linking, inspect-based gear.

## v0.3.0: News & Milestones

- Guild news feed, milestones and leaderboards.

## v0.2.0: Who Can Craft

- Crafters tab, crafter lines on item tooltips, sidebar menu.

## v0.1.0: Core

- Main window, roster, Me tab, bestiary card and page, minimap button, `/lomb`, guild sync.
