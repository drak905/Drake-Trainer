# 9 Years of Shadows - Offline Trainer v1.2.2

In-game trainer for **9 Years of Shadows** (Halberd Studios, GOG build v1.0.41, Unity 2022.3.28 Mono, Windows x64).
Single-player / offline use only. It touches no online service and contains no anti-cheat or DRM bypass.

It is a BepInEx 5 plugin: Harmony hooks into the game's own C# methods at runtime.
**No game file is modified** - `Assembly-CSharp.dll` and your saves stay untouched - and everything is removable with one script.

## Hotkeys (in game)

| Key | Feature | Type | What it does |
|-----|---------|------|--------------|
| F1 | God Mode | toggle | No damage, no knock-back, cannot die from hits (enemies, projectiles, hazards) |
| F2 | Add Coins | one-shot | +1000 coins (capped by the game at 9999) |
| F3 | Infinite Money | toggle | Coins are never spent (shops, upgrades, fast travel); refilled to the cap when switched on |
| F4 | Unlimited Jump | toggle | Jump again in mid-air as many times as you press jump (works even before you unlock Double Jump) |
| F5 | Speed x2 | toggle | Walk/run speed multiplier (x2 by default) |
| F6 | One-Hit Kill | toggle | Every hit you land on a **regular enemy** deals 99999 damage (resisted/shielded hits stay resisted). **Bosses, mid-bosses and their parts are NOT affected** (see below) |
| F7 | Infinite Magic | toggle | Magic / shield bar and Apino shots never run out |
| F8 | Full Heal | one-shot | Restores health and magic |
| F9 | Show/hide overlay | toggle | Status panel in the top-left corner |
| **F10** | **Reveal Map** | toggle | Every known room shows on the pause map; each area is also revealed automatically when you enter it |
| **F11** | **Items on Map** | toggle | Marks every **uncollected** item of **every area** on the pause map (see colours below) |
| **F12** | **Unlimited Items** | toggle | No currency/material is ever spent (coins, blue/red notes, armor pieces, light pieces); notes and pieces are topped up to 99 when switched on |
| **Home** | **Walk Through Gates** | toggle | Walk straight through closed gates (switch gates, enemy/arena gates, passages). The gates stay closed and your save is not changed |
| **End** | **Walk Through Walls** | toggle | Walk through destructible crystal walls and fake walls without breaking them |
| **Delete** | **Unstick** | one-shot | Emergency: gives control back if a cutscene or boss outro left the character unable to act (input state, frozen time, locked controls, dialogue). Does nothing while the pause menu is open |
| **Insert** | **Save diagnostics** | one-shot | Writes `NysTrainer_diag.txt` into the game folder: what is touching the character, nearby gates / door ramps / blockers and whether the trainer is ignoring them. Use it if a gate still stops you |

All toggles start **OFF** on every launch; the overlay shows the current state of each one.

### Walking through gates (Home / End)

Switch on **Home** and simply walk into a closed gate: the player's body ignores the gate's barrier, so you pass through it, while the gate itself keeps its state (closed stays closed, puzzle progress and save data are untouched). Switch it off again and gates block you normally - if you are standing inside a gate at that moment, step out of it first or you will be pushed out.
**End** does the same for crystal walls / fake walls (they are not destroyed, so they still count as intact).
Some door-type gates (slope doors) also block in code: a no-move zone in front of them and a rail system that is switched off while closed. Home neutralises those too (walking is always allowed and the door rail stays active for you). It does not open gates for enemies, trigger the switches that open them, or skip scripted cutscene doors, and it cannot take you out of the level boundaries.
If a gate still stops you with Home on: stand in front of it, press **Insert**, and send/keep `NysTrainer_diag.txt` - it names the exact object that blocks.

### Map markers (F11)

Open the pause map after switching F11 on. A diamond is drawn for each item you have **not** collected yet:

| Colour | Item |
|--------|------|
| blue | Blue note |
| red | Red note |
| orange | Armor piece |
| green | Map piece |
| yellow, larger | Ability / upgrade pickup |
| cyan, larger | Armor altar (element armor you have not taken yet) |

Markers are shown for all areas, including areas you have not visited and rooms that are not revealed - combine with F10 to see the rooms too.
Collected items disappear automatically (the plugin reads your save's own "already collected" state). Boss rewards and story-only pickups are not listed.

## Install (on any PC that has the game)

1. Unzip `NineYearsOfShadows-Trainer-v1.zip` anywhere.
2. Close the game.
3. Double-click **Install.bat**.
   - It finds the game by itself (GOG registry, Steam libraries, common folders). If it can't, it asks you to paste the folder that contains `9 Years of Shadows.exe`.
   - Or run it yourself: `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\9 Years of Shadows"`
4. Start the game normally (GOG Galaxy or `9 Years of Shadows.exe`). The overlay appears top-left once the game has loaded; the hotkeys work during gameplay.

Files added to the game folder (all listed in `NysTrainer_install_manifest.txt`):
`winhttp.dll`, `doorstop_config.ini`, `.doorstop_version`, `BepInEx\core\*`, `BepInEx\plugins\NysTrainer.dll`.
Re-running the installer is safe (it also updates an older trainer version).

**Other BepInEx mods (e.g. a language pack) are supported**: if the game already has a BepInEx 5 loader, the installer keeps it untouched and only adds BepInEx\plugins\NysTrainer.dll. The uninstaller likewise removes only the trainer when other plugins are present, so those mods keep working.

## Uninstall

Double-click **Uninstall.bat**. If no other BepInEx plugin is installed it removes everything (add `-Purge` in a terminal to also delete the `BepInEx` folder with config and logs); if other plugins exist it removes only the trainer and keeps the shared loader.
A pre-existing `winhttp.dll` / `doorstop_config.ini`, if any, is restored from its `.orig` backup.

## Configuration

After the first launch edit `<game>\BepInEx\config\com.research.nystrainer.cfg`:
- Rebind any hotkey (names from the Unity Input System `Key` enum, e.g. `F10`, `Numpad1`, `Backquote`, `Home`).
- `AddMoneyAmount` (default 1000), `SpeedMultiplier` (default 2), `ItemFillAmount` (default 99), `ShowHud`.
If you upgrade from v1.0 delete that file once so the new hotkeys are written.

## Notes and limits - please read

- **Changes can end up in your save.** Coins, notes and pieces you add (F2/F3/F12) live in the game's wallet and are written to the save the next time the game saves (save point / area change). Revealed map cells (F10) are stored in the save the same way. If you want to be able to go back, copy `%USERPROFILE%\AppData\LocalLow\Halberd Studios\9 Years of Shadows\SaveData` first. Quitting without saving discards everything.
- **Unlimited Items** is about the five currencies/materials; this game has no other consumable items.
- **Reveal Map** reveals every room the game knows about. Rooms of an area that has never been loaded only become known when you first enter that area (they are revealed immediately at that moment). Secret rooms of the current area stay hidden.
- **Items on Map** uses an item list extracted from the game's level data (60 items), so it works for all areas at once. Position accuracy is within the map cell.
- God Mode blocks hits, not scripted deaths (e.g. a chase sequence that is designed to reset you can still reset you).
- **One-Hit Kill and bosses**: boss fights are scripted in phases (health thresholds, intro/outro coroutines). A 99999 hit jumps from full health to dead in one step and skips that chain. Concrete example found in the game code - the Mask of Andros (Monkey, Area C): the game keeps its health at 10 or more and plays the real ending (death slash, `DieAction`, opening the arena gates, victory, save) from its *damaged* handler; a one-shot kill makes the engine take the generic *defeated* path instead, so none of that runs: the boss is dead, the arena stays locked and the character has nothing to do next. Its hand crystals are boss objects too and break the same way. Since v1.2.2 One-Hit Kill ignores bosses, mid-bosses, boss projectiles/crystals and clones, and you fight them normally. If you really want it, set `OneHitKillAffectsBosses = true` in the config - at your own risk.
- **If you get stuck after a boss**: press **Delete** (Unstick). If that is not enough, press **Insert** and look at `NysTrainer_diag.txt` (it lists the bosses loaded and the input/time state), then reload your last save.
- Pressing the hotkeys while a menu is open still toggles the features (harmless).
- **Walk Through Gates / Walls** only changes collisions with barriers that exist when the toggle is on (re-checked 4 times per second and the moment a gate closes). If you toggle it off while inside a barrier, the game pushes you out.

## Troubleshooting

- **No overlay**: check that `winhttp.dll` sits next to `9 Years of Shadows.exe` and that `BepInEx\LogOutput.log` exists after launching. Some antivirus tools quarantine `winhttp.dll` (it is the BepInEx/Doorstop loader) - add an exception and re-run the installer.
- **Game updated**: the plugin hooks methods by name, so it usually keeps working. If a feature does nothing, `BepInEx\LogOutput.log` shows which `Patched: ...` line is missing; only that feature is affected. The item list on the map is tied to the tested level data; after a big update some markers may be off or missing. Re-run `Install.bat` if the update removed the added files.
- **A feature does nothing right after loading a save**: wait until you are in control of the character (the player object must exist).
- **Installer says "Close the game first"**: exit the game completely (check Task Manager for `9 Years of Shadows.exe`).
- **No item markers**: switch F11 on *before* opening the map (the map is built when it opens); close and reopen it after toggling.

## Self-test (optional)

Set the environment variable `TRAINER_SELFTEST=1`, start the game, load a save and wait ~5 s.
`<game>\trainer_selftest_report.json` lists every feature as PASS/FAIL (hook present + live invariant/delta checks).
Last verified on GOG v1.0.41: 12/12 PASS (God Mode, One-Hit Kill, Add Money, Infinite Money, Speed, Unlimited Jump, Infinite Magic, Unlimited Items, Reveal Map, Items on Map, Walk Through Gates, Walk Through Blockers).
Live checks done in a real session: coins 6 -> 1006 after F2; max walk velocity 2.14 -> 4.26 with F5; 8 rapid jump presses kept the character airborne ~2.4 s (a normal jump is ~0.45 s) with F4; notes/pieces 2/7/1/1 -> 99 each with F12; hidden rooms shown on the pause map with F10; item diamonds placed on the map with F11 (positions checked against the game's own player marker, collected counts match the wallet); Home: a real gate was closed in memory and the player dropped into its barrier - with the toggle OFF the physics engine pushed the player out, with it ON the player stayed inside (then everything was restored).

## Rebuild from source

`source\NysTrainer.cs` + `source\build.ps1` + `source\data\items.tsv` (uses the .NET Framework `csc.exe` from Windows, no SDK required;
needs the BepInEx `core` DLLs - see `payload\BepInEx\core` - and the game's `Managed` folder:
`.\build.ps1 -Game "<game folder>" -Bep "<path to payload\BepInEx\core>"`).
`source\tools\` holds the Python scripts (UnityPy) that regenerate `items.tsv` from the game's level bundles - only needed if the game's levels change.

## Credits / licenses

BepInEx 5.4.23.3 (LGPL-2.1) and HarmonyX / MonoMod (MIT) are bundled unmodified from https://github.com/BepInEx/BepInEx.
Trainer code: this package.





