# Changelog

Release tags follow the roadmap (v0.1 … v1.0). The addon's own version, shown in game and in the TOC, is separate: **release v0.6.0 is in-game version 0.8.2, v0.6.1 is 0.8.3 and v0.6.2 is 0.8.4**, because v0.7 and v0.8 were built before ForeverDB.net approved API access for v0.6.

Nothing here has been tested in the real game yet. WoW: Forever launches on November 4, 2026.

## v0.6.2 (in-game 0.8.4): storyline drop-downs and quest progress, 2026-10-30

Small pre-release patch, untested in game.

- **Storylines are drop-downs.** Each connected storyline (the whole linked set, branches included, 255 in the bundled data) is one header row in the quest list. The header shows the storyline's name (its first quest), the level range, and either progress ("12-18 · 4/9 done") or the number of quests when the addon can't tell what you've done. There's a violet arrow on the left. Headers start closed. Click to open or close them; the addon remembers this until you log out or reload.
- **Opened storylines** list their quests in story order with the "Part X of Y" tags from v0.6.1. A branch sits right under the quest it splits off, one step further in.
- **Filters still apply.** A header only shows if at least one of its quests passes the filters, and its level range and counts only cover those quests. The tooltip says when only some of its quests match. The count above the list still counts quests, including the ones inside closed headers. Opening a quest from a link opens its storyline. Quests outside chains are unchanged.
- **Quest progress (new, defensive):** quests are tagged "done", "in log" or "turn in" in the list, and the quest page has a "You" line (Done / In your quest log / Ready to turn in / Not started / Can't tell yet).
  - It reads the game's quest log and completed-quest history through the C_QuestLog functions listed for the 1.60.1 client. Every call is guarded, and the old Classic functions are kept as a fallback.
  - It also saves every turn-in it sees (`QUEST_TURNED_IN`) on this character. If that event never fires, a quest that leaves the log while it's ready to hand in also counts. That way progress still counts up if the game won't share its history, but then it only covers turn-ins made while 0.8.4 was running.
  - Nothing is guessed: earlier parts of a chain aren't marked done because a later part is.
  - `/lomb questcheck` prints what the game is telling the addon (quest log, history, per-quest checks, turn-ins seen). It's for checking on launch day.
- No ForeverDB.net requests and no new data. The arrows are two tiny textures that ship with the addon (`tools/make_arrows.py`).

## v0.6.1 (in-game 0.8.3): quest chains, 2026-10-30

Small pre-release patch, untested in game.

- **Chained quests are tagged** "Part 2 of 4" in the quest list, in a soft violet with a thin bar down the left of the row. The quest page shows the same, plus where a branch splits off.
- **Chains are grouped:** a chain's quests are listed together in chain order, at the spot where its first listed quest would be. Quests that aren't in a chain keep their place, and quests with the same name stay separate lines.
- Works out chains from the links already in the bundled ForeverDB.net data. There are no new requests and no new data.
- **Branches and merges:** chains that branch (class letters, side quests) are cut into straight lines, longest first. A branch carries on the numbering of the quest it branches off, so "Part 5 of 5" counts along one real path. Each line is its own group in the list.
- **Edge cases:** "of 4+" means the chain carries on past level 30. A chain that started above level 30 would show "Part ? of ?" (none in this snapshot). If links ever loop, those quests are ordered by level and name and marked as unclear (none in this snapshot). With a level or zone filter, the visible parts of a chain stay grouped and keep their real part numbers.

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
