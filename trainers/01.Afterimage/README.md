# Afterimage Trainer v1.4.0 (portable patch)

An in-game trainer for **Afterimage** (Steam, single-player). Every feature has its own key. A dark status panel with four
sections shows what is ON or OFF, and you can also click the rows with the mouse.

New in 1.4.0: **F2 now adds +100 to every consumable and material in your inventory bag** (potions, Rest Potions, cooking ingredients, trade materials). Money is on F10.

Added in 1.3.2: **the corner minimap now zooms out while Map Item Markers is ON**, so chests are in view (see the changelog).

Added in 1.3.1: **God Mode now survives traps and other lethal hits** (see the F1 entry and the changelog).

New in 1.3.0: **redesigned panel** (dark backdrop, sections, key badges, coloured ON/OFF pills, collapsible pill, mouse
clicking and dragging). The cheats themselves are unchanged. Also new: the installer now works next to other UE4SS mods
such as the Afterimage Vietnamese pack (older trainer installers deleted the whole `ue4ss` folder when upgrading).

Added in 1.2.0: a corner **minimap**. Added in 1.1.0: **map item markers**, **reveal the whole map**, **talent points**, **infinite air dash**.

* Game: Afterimage, Steam app **1701520**, Unreal Engine 4.26, Windows x64
* Tested on: Steam build **14404437**, `Afterimage-Win64-Shipping.exe` SHA-256
  `48F9EB843E624775E7B6D8C5BE2B3BDB69B8C6E56E4203D28C459249DE67D089`
* **No game file is modified.** The patch adds a proxy `dwmapi.dll` that loads [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS)
  (MIT licence, see `LICENSE-UE4SS.txt`) and one Lua mod, `AI_Trainer`. Uninstalling removes only the files this package added.
* For offline, single-player use only.

## The panel

```
+-------------------------------------------------------+
|  AFTERIMAGE TRAINER 1.4.0                  [F8] Hide  |
+-------------------------------------------------------+
|  COMBAT & SURVIVAL                                    |
|  [F1]   God Mode                                [OFF] |
|  [F5]   Infinite Mana                           [OFF] |
|  [F6]   One-Hit Kill                            [OFF] |
|  [F7]   Full Heal                               [USE] |
|  MOVEMENT & SPEED                                     |
|  [F3]   Unlimited Jump                          [OFF] |
|  [End]  Infinite Dash                           [OFF] |
|  [F4]   Game Speed          [F9] cycle     [OFF x2.0] |
|  RESOURCES & PROGRESSION                              |
|  [F2]   Add Bag Items                          [+100] |
|  [F10]  Add Money (+100,000)                  [+100K] |
|  [PgDn] Add +5 Talent Points                [Free: 9] |
|  MAP & EXPLORATION                                    |
|  [PgUp] Map Item Markers                        [OFF] |
|  [Del]  Reveal Full Map                         [OFF] |
|  [F12]  Minimap Camera                       [FOLLOW] |
|  [Ins] Mouse: OFF   (click rows, drag the title)      |
+-------------------------------------------------------+
```

* Dark semi-transparent panel, so the text is readable over any scene. It sits at the left of the screen, just below the
  game's own HP/mana gauge.
* Hotkeys are amber badges, names are white (grey when the feature is off), **ON** is green (the whole row gets a faint green
  tint), **OFF** is grey, values such as `FOLLOW`, `Free: 9` are blue, one-shot actions (`USE`, `+100K`) are orange.
* The panel is drawn over menus too, and never blocks the game's own mouse input.
* **F8** collapses the panel to a small pill: `AFTERIMAGE TRAINER 1.4.0  [F8 Show] (N Active)`, where N is the number of
  cheats that are ON (the minimap counts when it is on). F8 again, or a click on the pill, brings the panel back.

### Mouse
Press **Ins** to turn on *mouse mode* (the game's cursor is shown while it is on). Then:
* **click a row** to toggle / trigger it, exactly like its hotkey;
* **drag the title bar** to move the panel. The position is remembered in `ue4ss\Mods\AI_Trainer\Scripts\hud_pos.txt`
  (delete that file to go back to the default position);
* **click `[F8] Hide`** to collapse, **click the pill** to expand.

The clicks work whenever the game's cursor is visible (for example in the pause menu), not only in mouse mode. Every hotkey keeps working.
The game binds no mouse button to any action, so showing the cursor does not change gameplay. Press Ins again to hide the cursor.

## Keys

| Key | Feature | What it does |
|-----|---------|--------------|
| **F1**  | God Mode (toggle) | The game's own `Invincible` flag stays on, HP is held at max, and any write that would take your HP below 1 (a trap, a one-hit kill, fall damage) is rewritten to full HP before the game stores it, so the death sequence never starts. |
| **F2**  | +100 of every bag item | Adds 100 to the count of every consumable and material you have (or have had) in the inventory bag: HP / MP potions, Rest Potions (fast travel), balms, talent-reset potions, cooking ingredients and trade materials. A stack stops at 999. The pill shows how many kinds were raised (`+100 x19`). Equipment, story/quest items and progress counters are left alone. It is the real bag count, shown in the Items menu and kept in your save. |
| **F10** | +100,000 money | Adds to your real wallet. It shows in the Items menu and is kept in your save. |
| **F3**  | Unlimited Jump (toggle) | Press jump again in mid-air to jump again. Works with Space, a re-bound jump key, or gamepad A. |
| **F4**  | Game Speed (toggle) | Raises walk/run speed through the game's buff system. Turning it off restores normal speed. |
| **F9**  | Cycle speed multiplier | x2.0, x3.0, x4.0, x1.5 (editable in `config.lua`). The pill shows the selected one even while the speed is OFF. |
| **F5**  | Infinite Mana (toggle) | Mana is refilled constantly. |
| **F6**  | One-Hit Kill (toggle) | Enemies are held at 1 HP, so any hit kills them. Bosses too. Default OFF. |
| **F7**  | Full Heal | Refills HP and mana once. |
| **F8**  | Collapse / expand the panel | |
| **PageUp** | Map Item Markers (toggle) | Open the map (M) to see an icon at every chest, item and money crystal you have **not** collected yet, in every region. Collected ones are left out, and the list refreshes every time you open the map. The pill shows how many markers were placed. |
| **DEL** | Reveal Full Map (toggle) | Removes the fog of war from the map screen. This only changes the display: your exploration % and save data are untouched. |
| **PageDown** | +5 Talent Points | Adds 5 to your talent point total. Spend them in Esc > Talent. They are saved with your game. The pill shows how many free points you have. |
| **END** | Infinite Dash (toggle) | Refills the air dash constantly. |
| **F12** | Minimap Camera (cycles FOLLOW, REGION, OFF) | A minimap in the bottom-right corner, drawn from the game's own map art. **FOLLOW** keeps your icon in the middle and scrolls the map every frame; **REGION** shows the whole current region. With Map Item Markers on, uncollected pickups near you are shown too. It hides itself while a menu or the map screen is open. |
| **INS** | Mouse mode (toggle) | Shows the cursor so rows can be clicked and the title dragged. |

F11 is left free on purpose: the engine uses F11 to switch fullscreen/windowed. F12 is used by the minimap, so move Steam's
screenshot key off F12 (Steam > Settings > In Game), or rebind the minimap in `config.lua`.
PageUp/PageDown also scroll lists inside the game's menus (Items, etc.), so pressing them there does both.

## Install (on any Windows PC that owns the game)

1. Install Afterimage from Steam and start it once so the game folder exists. Close the game.
2. Unzip this package anywhere, for example on your Desktop.
3. Double-click **`Install.bat`**.
   * It finds the game through the Steam registry key and `libraryfolders.vdf`, on any library drive.
   * If it cannot find the game, it asks for the game folder (the folder that contains `Afterimage.exe`). You can also run
     `Install.bat -GameDir "D:\SteamLibrary\steamapps\common\Afterimage"`.
   * It refuses to run while the game is open.
   * If UE4SS is not installed yet it installs it. If another mod loader's `dwmapi.dll` is there, that file is moved to a
     backup folder first. If UE4SS is already there (an older trainer, the Vietnamese pack, other mods), it is left as it is
     and only the trainer is added; `mods.txt` / `mods.json` are merged, not replaced.
   * Then it copies the trainer files and checks every file's hash.
4. Start the game from Steam and load your save. About 30 seconds after the game starts the trainer panel appears at the left
   of the screen, and the keys work.

### Upgrading from 1.0 - 1.2
Run the new `Install.bat`; you do not need to uninstall first. Your old `config.lua` is copied to
`...\Win64\AI_Trainer_config_previous_<date>.lua` and the new `config.lua` (with the new keys) is installed. If you had
changed settings, copy them into the new file. Other mods (for example `AI_Vietnamese`) are not touched.

### Manual install (without running scripts)
If `ue4ss` is not in `...\Afterimage\Binaries\Win64\` yet, copy `payload\loader\dwmapi.dll` and the `payload\loader\ue4ss\` folder there.
Then copy `payload\mod\AI_Trainer` and `payload\mod\Keybinds` into `ue4ss\Mods\` and add the lines `AI_Trainer : 1` and `Keybinds : 1` to `ue4ss\Mods\mods.txt`.

## Uninstall
Close the game and double-click **`Uninstall.bat`**. It removes the trainer and its `mods.txt` entries. The UE4SS loader is
removed too, unless another mod such as the Vietnamese pack still needs it (then it stays, and the Vietnamese uninstaller removes
it later). Your saves and the game files are not touched. If the installer had backed up another mod loader, it is put back.

## Settings (`ue4ss\Mods\AI_Trainer\Scripts\config.lua`)
Open the file in Notepad, change it, save it, and restart the game.
* `keys`: rebind any feature. Use any UE4SS key name (`F1`..`F12`, `INS`, `DEL`, `HOME`, `END`, `PAGE_UP`, `PAGE_DOWN`, `NUM_ONE`, ...).
  A modifier can be added, for example `"SHIFT+F2"`. Do not use `CONTROL+` (Ctrl is the game's dash key) or `ALT+F4`.
  The panel shows whatever keys you set.
* `money_big`: the amount for F10 (the row label follows).
* `bag_item_amount` (default 100) and `bag_item_cap` (default 999, 0 = no limit): what F2 adds and the highest count it will set.
* `bag_item_prefixes`, `bag_item_ids`, `bag_exclude`, `bag_extra_ids`: which items F2 touches. The game cannot list the bag, so item ids are tried from the names of the game's item icons plus `bag_extra_ids`; an id is raised when it starts with one of `bag_item_prefixes` (or is in `bag_item_ids`), does not contain a `bag_exclude` text, and is in your bag, in storage or already listed in the Items menu. Add `"Weapon_"` or `"Quest_"` to `bag_item_prefixes` if you want those raised too (not recommended: quest items and equipment are single items).
* `talent_points`: how many talent points PageDown adds.
* `speed_steps`: list of speed multipliers. The first one is used when you turn speed on.
* `god_hook`: `true` (default) = God Mode also rewrites lethal HP writes (the main protection); `false` = only the per-frame HP guard.
* `defaults`: features that start ON when the game starts, for example `map_items = true`.
* `map_item_types`, `map_icons`: which pickups get a map marker, and with which icon.
* `show_hud`: `true` = full panel at start, `false` = start as the small pill.
* `hud_collapse_to_pill`: `true` (default) = F8 collapses to the pill; `false` = F8 hides the panel completely.
* `hud_x`, `hud_y`: default panel position in UI pixels (1920x1080 reference). A position saved by dragging (`hud_pos.txt`) wins.
* `hud = { width = ... }`: panel width.
* `defaults.minimap`: minimap mode at start (0 off, 1 follow, 2 region). `minimap`: size, margins, zoom, icon size.

## Troubleshooting
* **I still died with God Mode on.** God Mode covers every death that goes through the HP value (enemy hits, traps, falls, one-hit damage). It cannot cover a scripted death or a respawn the game triggers on purpose (a story event, a boss mechanic that moves you, being teleported to the last safe point after a trap, which is normal and costs no HP). If it happens, note where, then look in `ue4ss\UE4SS.log` for `[AI_Trainer] God Mode blocked a lethal HP write`: that line appears every time the trainer saved you, so if it is missing the death did not come through HP.
* **No panel / keys do nothing.** Wait about 30 seconds after the game starts. Check that `dwmapi.dll` and the `ue4ss`
  folder are next to `Afterimage-Win64-Shipping.exe`, and look in `ue4ss\UE4SS.log` for lines starting with `[AI_Trainer]`.
* **The panel covers something.** Drag it (Ins, then drag the title bar), or press F8 to collapse it to the pill.
* **Clicking does nothing.** The cursor must be visible: press Ins. Click inside the panel; the pill and the `[F8] Hide` label are clickable too.
* **I moved the panel somewhere I cannot reach.** Delete `ue4ss\Mods\AI_Trainer\Scripts\hud_pos.txt`.
* **The panel looks like plain yellow text.** The new panel failed to build and the trainer fell back to the old text list; send the `[AI_Trainer]` lines of `ue4ss\UE4SS.log`.
* **Text shows in Vietnamese or looks odd.** The Vietnamese pack leaves the trainer's text alone. Everything on the panel is English by design.
* **No markers on the map.** Markers only appear on the map screen (M). Press PageUp first; the row should say
  `ON (N)` with N above 0. Press DEL to reveal the full layout.
* **A marker stays on an item I already took.** Close and reopen the map; the list is rebuilt from the game's "opened" flags each time.
* **No minimap.** Press F12 until the panel says FOLLOW or REGION. It is hidden while a menu or the map screen is open.
* **The game switched between fullscreen and windowed.** That is the engine's own F11 key, not the trainer.
* **Antivirus complains about `dwmapi.dll`.** It is the standard UE4SS proxy loader. Some antivirus tools flag
  DLL loaders by heuristics. Allow-list the game folder, or build UE4SS yourself from the linked repository.
* **A feature stopped working after a game update.** The property ids are listed in `config.lua` (`sprop = {...}`).
  A large patch may change them. Check for a newer package.
* **Steam "Verify integrity"** neither removes nor breaks the trainer, because it only adds files.
* Back up `%LOCALAPPDATA%\Afterimage\Saved\SaveGames` before heavy cheating. Money and talent points you add are saved with the game.

## Self-test (optional)
Create an empty file `ue4ss\Mods\AI_Trainer\selftest.flag`, start the game and load a save. Once the character has stood on the
ground for about 5 seconds and an enemy is loaded (or after about 95 seconds), `...\Win64\AI_Trainer_selftest_report.json` is
written with one PASS/FAIL line per feature. Every test puts the value back afterwards. Delete the flag file when you are done.
The test must run in a real level; on the title screen the minimap check cannot pass.

Result on the test PC (build 14404437, 2026-10-31): all lines PASS, 14 with an enemy loaded (new line GOD_LETHAL_WRITE: HP forced to 0 with God Mode on, the character must stay alive; ONE_HIT_KILL is SKIPPED when no enemy is loaded at that spot) (TALENT_POINTS, INFINITE_DASH, MAP_ITEMS 868 pickups / 840 markers,
MAP_REVEAL, MINIMAP, INVARIANTS, MONEY, HEAL, SPEED, GOD, MANA, JUMP, ONE_HIT_KILL).

## How it works (short)
* Player stats live in the game's `SPropertySystem` component (`PlayerCharacter.SProp`), addressed by integer ids (see `config.lua`).
* Map markers: the minimap component's own DataTable (`/Game/Assets/Minimap/DropItemInfo`) lists every pickup with its save id and
  position; the trainer reads each one's "opened" flag and calls the game's `MinimapComponent.AddNpcMark` for the others.
* Reveal map: the map material multiplies the map by a fog mask texture; the trainer swaps it for a white texture and restores it.
* Minimap: a clipped UMG panel built from the map screen's own region textures, moved every rendered frame.
* Panel (`hud.lua`): UMG widgets built at runtime (images and text blocks on a canvas). UE4SS cannot set rounded brushes, so rounded
  corners are small stacked rectangles. The widget is hit-test invisible; the mouse is read with
  `WidgetLayoutLibrary.GetMousePositionOnViewport` and `IsInputKeyDown(LeftMouseButton)` while the cursor is visible. The pill texts
  carry an invisible zero-width space so the Vietnamese pack's text sweep does not translate them.
* Everything goes through the game's own functions (no raw memory writes), so menus and saves stay consistent.

## Changelog
* **1.4.0**: F2 changed from "+10,000 money" to "+100 of every bag item" (see the F2 entry and the config notes). The bag is the player property `prop_item_bag` (item id to count); F2 writes the new counts there, so the Items menu shows them at once. Overflow counts kept in storage (the number in brackets) are not changed. Money is still on F10 (+100,000); the +10,000 key is gone.
* **1.3.2**: Map Item Markers looked empty on the corner minimap. Cause: FOLLOW showed only about 317 x 192 map units around you, and the nearest uncollected chest is usually further away (in testing it was 303 units away, just outside the view). The markers were being drawn correctly (REGION mode and the M map screen showed them). Fix: while Map Item Markers is ON, FOLLOW uses a wider view (`minimap.zoom_items = 0.3`, about 633 x 383 units); with it OFF the zoom is unchanged. Set `zoom_items = 0.6` in `config.lua` to keep the old view.
* **1.3.1**: God Mode fix. With God Mode on, the character still died on a trap. Cause: a trap / hit that sets HP to 0 or below starts the game's death sequence on the next game tick (about 4 ms later), while the trainer topped HP up only every 25 ms and only when HP was still above 0. Now (1) pre-hooks on the game's two HP setters (`SPropComponent:SetSPropertyNumberValue` and `SetSPropertyCurrNumberValue`) rewrite a lethal write to full HP before it is stored (checked live: writing HP 0 and HP -50 no longer sets the death flag), (2) a per-frame guard restores HP (current and base value), (3) the 25 ms loop no longer skips HP 0. New config option `god_hook`. The hooks do nothing while God Mode is off. New self-test line GOD_LETHAL_WRITE.
* **1.3.0**: new panel (sections, key badges, status pills, row highlight, collapsible pill with active count, mouse clicks and drag, saved position); new key `mouse` (Ins); `hud.lua` added; the installer is now coexistence-aware (no longer wipes the `ue4ss` folder, merges `mods.txt`/`mods.json`, keeps the loader while another mod uses it); self-test waits until the player is on the ground. No change to the cheats.
* **1.2.0**: corner minimap (F12).
* **1.1.1**: Map Item Markers on PageUp, Talent Points on PageDown; main loop moved to UE4SS's game-thread timer (fixes a rare crash).
* 1.1.0: Map Item Markers, Reveal Map, Talent Points, Infinite Dash; key modifiers (`"SHIFT+F2"`).
* 1.0.1: Unlimited Jump follows the game's jump binding; 30 s start-up delay.
* 1.0.0: first release.

## Package contents
```
Install.bat / Install.ps1       installer (finds the Steam library automatically, upgrades in place, coexists with other mods)
Uninstall.bat / Uninstall.ps1   uninstaller
README.md                       this file
SHA256SUMS.txt                  hashes of every file in this package
LICENSE-UE4SS.txt               UE4SS licence
payload\loader\                 UE4SS proxy loader dwmapi.dll + ue4ss\ (experimental-latest, v3.0.1-1176-g1ba38db4)
payload\mod\AI_Trainer\Scripts  main.lua, hud.lua, minimap.lua, config.lua (the trainer's Lua source, editable)
payload\mod\Keybinds\           UE4SS's stock Keybinds helper mod
```
