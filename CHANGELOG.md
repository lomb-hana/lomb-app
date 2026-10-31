# Changelog

Release tags follow the roadmap (v0.1 … v1.0). The addon's own version, shown in game and in the TOC, is separate: **release v0.6.0 is in-game version 0.8.2, v0.6.1 is 0.8.3, v0.6.2 is 0.8.4, v0.6.3 is 0.8.5, v0.6.4 is 0.8.6, v0.6.5 is 0.8.7, v0.6.6 is 0.8.8 and v0.6.7 is 0.8.9**, because v0.7 and v0.8 were built before ForeverDB.net approved API access for v0.6.

Nothing here has been tested in the real game yet. WoW: Forever launches on November 4, 2026.

## v0.6.7 (in-game 0.8.9): loot browser, 2026-10-30

Pre-release, untested in game.

- **Loot browser** in Quests & Items. The Dungeons view is now called **Loot** (no new tab). Pick a dungeon or raid in the list, then **Whole dungeon**, one of its bosses or **Trash** (they open under the selected dungeon), and the page shows an icon grid with quality-coloured borders.
  - **Notable loot:** ForeverDB.net's picks for the dungeon, labelled as such: "not the full loot table, no drop rates, and not tied to a boss". ForeverDB.net doesn't say which boss drops what, so boss and Trash pages say so and link back to the whole dungeon.
  - **What LOMB saw drop:** items guildmates have looted from that dungeon's mobs (or that boss, or its trash), from the shared bestiary, with a count on each icon and "LOMB saw it drop: N" and the mob in the tooltip. Items ForeverDB.net doesn't list still show, as guild-only finds. When nobody has recorded anything yet, the page says so.
  - Filters: Dungeons & raids / Dungeons / Raids, and Any / Uncommon+ / Rare+ / Epic+. Search matches dungeons, bosses and notable item names.
  - Icons follow the item-row rules from v0.6.6: hover for the tooltip, click opens the item page, shift-click links it in chat, Ctrl-click previews. A **heart** on each icon adds the item to your Wishlist needs, or removes it again.
  - "Data from ForeverDB.net" with https://foreverdb.net and the dungeon's ForeverDB.net page on every loot page.
- **Raids:** Onyxia's Lair is in the bundled data now (ForeverDB.net lists it with no notable loot yet). Raid pages say raids open in WoW: Forever on December 9. The loot code has hooks for the v0.9 raid tools and soft reserves (extra loot sources and badges), but soft reserves aren't built.
- **Item pages:** "Notable dungeon loot" is now **Where it drops**, listing dungeons that have it as notable loot and dungeons where the guild saw it drop (with the boss and count), each opening the loot grid.
- **Bestiary:** a boss's page links to its loot grid.
- **Ask LOMB** answers loot questions: "What drops in Deadmines?", "What does Van Cleef drop?", "Deadmines loot" and similar ones open the grid and list notable loot and the guild's most seen drops. "Where does <item> drop?" now names the dungeon and boss too. Dungeon answers get a "What drops there?" button.
- Lookups are built on first use, not at login or in combat.
- Screenshots: new loot shots (45-48) and a new 31; the Credits shots (07 and 32) were redone from the Credits tab's current text, with the ForeverDB.net credit and support link.
- No ForeverDB.net requests at runtime and no Classic loot data. Building the raid entry took no new requests either (it came from the local cache).

## v0.6.6 (in-game 0.8.8): item rows work the same everywhere, 2026-10-30

Small pre-release patch, untested in game.

- **Click an item to see its page.** Items on the bestiary page (guild loot, notable loot, skinning), the bestiary card's loot lines, Quests & Items (item and recipe lists, vendor, reward, reagent and "made by" lines, guides, herb and ore lists), Ask LOMB answers, the Bank tab (ledger rows and change log), profile gear, the Me tab's loot history and your own Wishlist rows now open the item's page in Quests & Items.
  - If the bundled ForeverDB.net data doesn't have the item, a small "No details for this item" page says so; hovering still shows the game's tooltip and shift-click still links it. If the data didn't load at all, a plain click does nothing and the tooltip only offers shift-click.
  - Where a row already had a main action, it keeps it: Crafters rows still open a whisper to an online crafter, and other members' Wishlist rows still prefill a whisper to them (nothing is sent).
- **Shift-click links the item in chat**, the same as from your bags, on every item row. It goes through the game's own modified-click handling (`HandleModifiedItemClick` when the client has it, otherwise `ChatEdit_InsertLink`, opening the chat box with the link in it if none is open). It only fills the edit box; nothing is ever sent. **Ctrl-click** previews the item in the dressing room where the client supports it.
  - If the game hasn't cached the item yet, the addon asks for it (`C_Item.RequestLoadItemDataByID`) and links it as soon as it arrives, or after a second builds a link from the item ID with the bundled name and quality.
  - Profile gear links keep the exact item (enchant and suffix).
- **Tooltips** on item rows end with "Click: details  Shift-click: link in chat" (Crafters and others' Wishlist rows say what their click does instead).
- Row clicks no longer swallow shift- and ctrl-clicks (for example, shift-clicking an item in the Quests & Items list links it instead of selecting it).
- No ForeverDB.net requests and no data changes.

## v0.6.5 (in-game 0.8.7): local event times, minimap shortcut, saved Ask history, 2026-10-30

Small pre-release patch, untested in game.

- **Event times in your local time, everywhere.** The Events tab (list and detail) and Ask LOMB's "next guild event" answer show times like "Wed Nov 4 · 8:00 PM (your time)", on a 12-hour clock, with the end time on the detail view.
  - The in-game calendar gives realm (server) times. The addon compares the calendar's current time (`C_DateAndTime.GetCurrentCalendarTime`) with the server's clock (`GetServerTime`, or your computer's clock if that's missing), rounds the difference to 15 minutes and converts every event to the real moment, so `date()` shows it in your time.
  - If the difference can't be worked out (no calendar clock, or a gap bigger than 15 hours, which no time zone has), the time is left as the calendar shows it and labelled "(realm time, not converted; unverified until Nov 4)", or "(realm time?)" in the list.
  - Not checked on live servers yet: whether WoW: Forever's calendar really uses realm time.
- **Minimap button:** right-click now opens the Ask LOMB tab directly (opening the window if needed; if the ForeverDB.net data didn't load, it just opens the window). Left-click still opens and closes the window, Shift-click still opens Settings, and the bestiary card moved to **Ctrl-click** (`/lomb card` still works). The tooltip says so.
- **Ask LOMB history is saved** per character (`LOMBCompanionCharDB.askHistory`) and comes back after a reload or log-in, under "Saved from earlier (answers as they were then)"; new answers follow under "Now:". Capped at the last 40 questions. **Clear** deletes the saved copy as well.
  - Only the question and the answer's lines are saved (text, muted/warning style, and what a line opens). No timestamps, character data or anything else. Saved entries are cleaned again when loaded (bad entries dropped, long text trimmed).
  - Saved answers aren't recalculated, so "in 26h" in an old event answer is as it was then. Ask again for fresh data.
- No ForeverDB.net requests and no data changes.

## v0.6.4 (in-game 0.8.6): Ask LOMB, 2026-10-30

Pre-release, untested in game. Still on the v0.6 tag line because it answers from the ForeverDB.net snapshot; the in-game version goes on from 0.8.5.

- **Ask LOMB tab** (between Quests & Items and Events): a question box with an input line, a scrolling history, example buttons ("Try", with "More" for others) and a Clear button. Press Enter to ask; the up and down arrows bring back earlier questions. Your question sits on a violet band; violet answer lines open the page they name (a quest, item, vendor, recipe, dungeon, herb or zone in Quests & Items, the Training page, or the Events or Crafters tab), and example questions ask themselves when clicked. The header always shows "Data from ForeverDB.net · https://foreverdb.net", and so does every answer that used it.
- **`/lomb ask <question>`** prints the answer in your own chat window. It never sends anything to guild, party, say or any other channel. `/lomb ask` on its own opens the tab.
- **Questions it answers** (plain words; punctuation, capitals and "please" don't matter, and shift-clicked item or quest links work):
  - where a quest starts and where it's turned in; what comes after it in its chain (with the storyline position);
  - who sells an item (your side and your zone first, top 5, with prices); how to make it (profession, skill, reagents, how to learn it); which guildmates can craft it (from shared recipes, online first);
  - what an item disenchants into, and who in the guild can disenchant (Classic table, labelled);
  - what drops an item: guild-recorded drops only, plus ForeverDB.net's notable dungeon loot picks;
  - which gear set an item is in, with bonuses, your pieces and the "hidden in the current client" warning;
  - where a herb or ore grows and where to level Herbalism, Mining, Skinning or Fishing;
  - what to train now and at the next level;
  - a dungeon's level range, minimum level and bosses; a zone's levels and counts; a battleground's levels; where an NPC stands;
  - quests near your level, for a given level, in your zone or in a named zone (quests you've done are left out, your zone first);
  - the next guild event from the calendar.
- **When it can't tell:** it tries the question as a plain name (quest, item, vendor, NPC, herb, dungeon, zone, set), then offers the closest names in the bundle (so "defias brotherhod" still finds the quest), and otherwise says "I don't know that one." with three example questions to click.
- It's pattern matching and name search over the bundled data, not an AI, and it works offline. Name lookups are built the first time you ask, not at login. The history is kept until you log out or reload (40 questions at most).
- No new ForeverDB.net data and no new requests (still 685 in total for the snapshot).

## v0.6.3 (in-game 0.8.5): guides, 2026-10-30

Pre-release, untested in game. Release tags stay on the v0.6 line because these are all ForeverDB.net features; the in-game version keeps counting from 0.8.4.

- **Training view** (Quests & Items > Training): pick a class (yours by default) and a level band. **Train now** lists the ranks at or below your level that the game doesn't report as known, with "next at level N" underneath. Each level row lists the ranks it brings. Hunters can switch to pet skills. `/lomb train` opens it.
  - **Level-up reminder:** when you level, a chat line only you see names the new ranks (and their cost once known), with a pointer to `/lomb train`. Switch: Settings > Training.
  - **Known ranks** come from the game's spellbook check (`C_SpellBook.IsSpellKnown`, with older functions as guarded fallbacks). If the game won't say, the rank is marked "can't tell". Not tried on live servers yet.
  - **Trainer costs:** ForeverDB.net has none. When you open your class trainer, the addon notes the costs and which ranks you already have, and shows them from then on.
- **Rogue poisons** (under Training for rogues): the Poisons quest for each faction, the poisons up to level 30 with reagents, skill and cost, and suppliers and trainers seen in WoW: Forever.
- **Gathering view:** Herbalism, Mining, Skinning and Fishing, filtered by profession and by your skill.
  - Herb and ore nodes show the skill needed, what they give and the zones they grow in (by spawn count).
  - **Where to level** shows the best zones for each skill band, with your band highlighted.
  - Skinning lists beasts by zone with the skill they need; bestiary mob pages show it too. Fishing shows each zone's skill and catches.
  - Spawn spots, skinning and fishing come from Classic data and are labelled "(Classic data, may differ)".
- **Disenchanting:** item pages for uncommon, rare and epic weapons and armour show what they disenchant into, and material pages show what disenchants into them. Guild enchanters are listed (you, guildmates whose profile shows Enchanting, and shared recipe lists), with online ones in green. There's an optional tooltip line, switched on in Settings. The table is Classic data and labelled.
- **Gear sets view:** the 5 item sets up to level 30, with bonuses, pieces you have (equipped, in bags, or in your bank when you last opened it) and where the rest come from. Missing pieces can be added to your wishlist. ForeverDB.net says all 5 are hidden in the current client, so each page says they're unconfirmed in WoW: Forever.
- **Zones view:** every zone with its level range and faction (worked out from its quests, since ForeverDB.net lists neither), quest count and storylines, vendors and gathering. ForeverDB.net's dungeon list has no zones, so dungeons aren't on zone pages. **Battlegrounds** are in the same view: levels, team size, how to win and how to play. The rules are Classic's and labelled.
- **Links between views:** item pages show "Part of a set", "Gathered from" and the guild-recorded drops. Mob pages show skinning. Zones link to quests, vendors and nodes.
- New data in `LOMBCompanion/Data/ForeverDB/` (about 116 KB more, 1.1 MB in total): classes, gathering, disenchanting, item sets, poisons, zones and battlegrounds. 685 ForeverDB.net requests in total for this snapshot, one at a time and cached.
- Mob loot stays guild-recorded only. Vendors and trainers never seen in WoW: Forever are still left out.

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
