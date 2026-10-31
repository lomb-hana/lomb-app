# Installing LOMB Companion

This takes about two minutes. You only need to do it once. After that, updating means doing steps 1 and 2 again.

## 1. Download

1. Open this repo's **[Releases page](https://github.com/lomb-hana/lomb-app/releases)**.
2. Under the newest release, click **`LOMBCompanion-v….zip`** to download it. (Don't use the green "Code" button. That's the source code, not the addon.)

## 2. Put it in your AddOns folder

1. Unzip the file. You get a folder called **`LOMBCompanion`**.
2. Move that folder into your WoW: Forever AddOns folder:
   ```
   World of Warcraft/<Forever game folder>/Interface/AddOns/
   ```
   If there's no `AddOns` folder yet, make one inside `Interface`.
3. Check that it ends up exactly like this. There should be no extra folder in between:
   ```
   Interface/AddOns/LOMBCompanion/LOMBCompanion.toc
   ```
   If you see `AddOns/LOMBCompanion-v0.9.4/LOMBCompanion/…` or `AddOns/LOMBCompanion/LOMBCompanion/…`, move the inner `LOMBCompanion` folder up one level.

The exact name of the Forever game folder will be confirmed when the game goes live on November 4, 2026.

**Updating:** quit the game, delete the old `LOMBCompanion` folder, and put the new one in its place. Your saved data isn't in that folder, so you won't lose anything.

## 3. Turn it on

1. Start the game, or type `/reload` if you're already in.
2. On the character select screen, click **AddOns** (bottom left) and make sure **LOMB Companion** is ticked.
   If it says "Out of date", tick **Load out of date AddOns** at the top.

## 4. Check it works

1. In game, type **`/lomb test`**. The results print in chat, and a window opens with the same report as **PASS**, **WARN** and **FAIL** lines.
   - All PASS or WARN: you're good. WARN lines explain themselves, for example "no guildmate with LOMB is online".
   - Any FAIL line: click **Select all** in the window, press Ctrl+C, and paste the whole report to the guild (see "Something broke?" below).
2. Click the LOMB button on the minimap, or type **`/lomb`**, to open the window. The first time, a short tour shows you around. You can skip it, and reopen it later from **Settings → Show welcome tour** or with `/lomb tour`.

## Handy commands

| Command | What it does |
|---|---|
| `/lomb` | Open or close the window |
| `/lomb help` | List every command |
| `/lomb test` | Check that everything works (copyable report) |
| `/lomb tour` | Show the welcome tour again |
| `/lomb card` | Show or hide the bestiary card |
| `/lomb ask <question>` | Ask LOMB (only you see the answer) |

On the minimap button: **right-click** for Ask LOMB, **Ctrl-click** for the bestiary card, **Shift-click** for Settings.

## Something broke?

1. Type `/lomb test`, click **Select all** in the report window, then press Ctrl+C.
2. If you saw a red error pop-up, copy that text too.
3. Post both in the guild's addon channel on Discord, with a line about what you were doing at the time.

That's all we need. No screenshots of your whole screen, and nothing from your account.
