# Launch-day checklist (WoW: Forever, November 4, 2026)

This is the first time LOMB Companion runs in the real game. Everything so far has passed offline tests against a fake WoW API, so this list covers the things only the live game can show. It takes about 30 minutes with **two guildmates online** (call them A and B). Tick each box, and write down anything odd next to it.

Times below are in your own time zone. The addon shows event times in local time.

## 1. Install (both players)
- [ ] Install it following [INSTALL.md](INSTALL.md). The folder sits at `Interface/AddOns/LOMBCompanion/LOMBCompanion.toc`.
- [ ] LOMB Companion is ticked in the AddOns list. Note whether it said "Out of date": ______
- [ ] Log in with no red error pop-up. The LOMB button shows on the minimap.

## 2. Self-test (both players)
- [ ] `/lomb test` opens the report window.
- [ ] Write down every **FAIL** line: ______
- [ ] Write down every **WARN** line: ______
- [ ] Copying works: click **Select all**, then Ctrl+C. The text pastes into Discord.

## 3. Two-player sync check
- [ ] With A and B both online, A runs `/lomb test`. The "Sync echo" line is PASS: "a guildmate answered in N s (their version …)".
- [ ] A opens the Roster. B shows the addon mark, and B's level, zone and professions fill in.
- [ ] B targets a creature A has never seen. Within a few minutes it shows in A's Bestiary with B's record.
- [ ] B adds a wishlist need. It shows in A's Wishlist tab within a minute.
- [ ] B logs out and back in. A gets no duplicate news lines.

## 4. Every tab (one player is enough)
Open each tab, look for anything cut off, overlapping or empty that shouldn't be, and hover a few controls to check the tooltips.
- [ ] Roster: sorting by each header, the Online / Addon / Hide alts toggles, clicking a name opens the profile
- [ ] Me
- [ ] Board (Leaderboard)
- [ ] News: the filters, plus a level-up line after you ding
- [ ] Crafters: open a profession window first, then check your recipes show
- [ ] Events
- [ ] Wishlist
- [ ] Bank (only appears once someone ticks "This is a guild bank character")
- [ ] Bestiary, plus the bestiary card (`/lomb card`)
- [ ] Quests & Items: quests, items, vendors, the Loot browser, and quest progress for your log
- [ ] Ask LOMB: try "what drops in deadmines", "quests in my zone" and "next event"
- [ ] Settings: every checkbox toggles, and "Show welcome tour" and "Run self-test" work
- [ ] Credits
- [ ] The welcome tour showed once on first open and didn't show again after a `/reload`

## 5. Combat check
- [ ] Fight a few mobs with the window **open**, then again with it **closed**. There's no stutter and no error pop-up.
- [ ] In combat, target an enemy. The bestiary card updates and there's no "action blocked" message.
- [ ] After combat, the kills appear in the Bestiary (Kills column) and on the Board.
- [ ] Loot a corpse. The loot shows on the creature's page.

## 6. Calendar time check
- [ ] An officer makes a test guild event in the game calendar for a known time, for example 9:00 PM.
- [ ] The Events tab shows the same time with "(your time)". A player in another time zone, if one is around, sees it shifted correctly.
- [ ] Ask LOMB "next event" gives the same time.

## 7. Dungeon clears (News)
The addon posts "<group> cleared <dungeon>" when the last boss dies. These are the bosses it treats as last. Confirm each one the first time the guild clears it:
- [ ] **Ragefire Chasm: Bazzalan.** ⚠️ This one is uncertain. On Forever, check whether the run really ends at Bazzalan or at Taragaman the Hungerer. Write down which boss was last: ______
- [ ] Deadmines: Edwin VanCleef
- [ ] Wailing Caverns: Mutanus the Devourer
- [ ] Shadowfang Keep: Archmage Arugal
- [ ] Blackfathom Deeps: Aku'mai
- [ ] Stormwind Stockade: Bazil Thredd
- [ ] Razorfen Kraul: Charlga Razorflank
- [ ] Gnomeregan: Mekgineer Thermaplugg
- [ ] Scarlet Monastery: Thalnos (Graveyard), Doan (Library), Herod (Armory), Whitemane (Cathedral)

**Forever's own dungeons** post no clear line yet, because their last boss isn't known. Whoever clears one first, please write down the boss that ended the run:
- [ ] City of Dalaran: ______
- [ ] Excavation Site: Wetlands: ______
- [ ] Ruins of Lordaeron: ______
- [ ] The Hall of Thanes: ______
- [ ] Manor Mistmantle: ______ (ForeverDB.net lists no bosses yet)

## 8. If something breaks, send this
Post it in the guild's addon channel on Discord:
1. The `/lomb test` report (click **Select all**, then Ctrl+C).
2. The text of any red error pop-up. Type `/console scriptErrors 1` first if no pop-ups show.
3. What you were doing, and roughly when.
4. Your addon version. It's the first line of the self-test report.

Please don't include account names, Battle.net tags or screenshots showing chat with other people.
