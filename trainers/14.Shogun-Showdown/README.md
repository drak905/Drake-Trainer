# Shogun Showdown - Offline Trainer v1

In-game trainer for **Shogun Showdown** (build 1.0.2.3, Unity 2021.3.45 Mono, Windows x64, Epic Games build).
Single-player / offline use only. It does not touch online services and contains no anti-cheat bypass.

It is a BepInEx 5 plugin (Harmony hooks into the game's own C# methods). **No game file is modified**: the original `Assembly-CSharp.dll` stays untouched, and everything is removable with one script.

## Hotkeys (in game)

The overlay (top-left) shows the state of every toggle. Toggles start OFF on every launch.

| Key | Feature | Type |
|-----|---------|------|
| F1 | God Mode: the hero takes no damage (attacks, poison, collisions, HP-priced shop items) | toggle |
| F2 | Add Coins +100 (the game caps coins at 999) | one-shot |
| F3 | Infinite Money: coins locked at 999, every shop price (coins and meta currency) is free | toggle |
| F4 | Unlimited Special Move: the hero's special move (Wanderer swap, dashes, jumps...) never goes on cooldown | toggle |
| F5 | Game Speed x2: animations and enemy turns play twice as fast | toggle |
| F6 | Move Distance x2: the hero moves two cells per move action | toggle |
| F7 | One-Hit Kill: any enemy the hero hits dies (shields are stripped first) | toggle |
| F8 | No Tile Cooldown: a played tile is recharged immediately | toggle |
| F9 | Infinite Consumables: potions are not used up and can be used again | toggle |
| F10 | Reveal Map: removes the fog from every map location | toggle |
| F11 | Full Heal | one-shot |
| Page Up | Add Meta Currency +100 (the unlock currency; it is saved with your profile) | one-shot |
| Page Down | Give the next consumable (cycles through all 8 types, needs a free slot) | one-shot |
| Insert | Show/hide the overlay | toggle |

Notes on how the requested features map to this game:
- Shogun Showdown is a turn-based tile game, so "unlimited jump" is the hero's special move (F4) and "character speed x2" is both faster play (F5) and a double move distance (F6).
- Game controls (for reference): A / D move, W turn around, S wait, Space attack. Use the mouse to pick map nodes.

## Install (on any PC that has the game)

1. Unzip `ShogunShowdown-Trainer-v1.zip` anywhere.
2. Close the game.
3. Double-click **Install.bat**. It finds the game through the Epic Games manifest, then Steam libraries, then common folders. If it cannot, it asks you to paste the game folder (the one containing `ShogunShowdown.exe`).
   - Or: `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\ShogunShowdown611f6"`
4. Start the game normally (Epic launcher / Steam / `ShogunShowdown.exe`). The overlay appears on the title screen.

Installed files (all listed in `ShogunTrainer_install_manifest.txt` in the game folder): `winhttp.dll`, `doorstop_config.ini`, `.doorstop_version`, `BepInEx\core\*`, `BepInEx\plugins\ShogunTrainer.dll`.

## Uninstall

Double-click **Uninstall.bat** (run `uninstall.ps1 -Purge` in a terminal to also delete the BepInEx folder with the config and logs). Original `winhttp.dll` / `doorstop_config.ini`, if any existed, are restored from `.orig` backups.

## Configuration

After the first launch edit `<game>\BepInEx\config\com.research.shogunshowdowntrainer.cfg`:
- Rebind any hotkey (names from the Unity Input System `Key` enum, e.g. `F9`, `Numpad1`).
- `AddCoinsAmount` (default 100), `AddMetaAmount` (default 100), `SpeedMultiplier` (default 2), `ShowHud`.

## Self-test (optional)

Set the environment variable `TRAINER_SELFTEST=1` before launching, start a run and wait about 5 seconds after the hero appears. `<game>\trainer_selftest_report.json` lists each feature as PASS/FAIL (hook present plus a live check). In self-test mode `End` re-runs the checks, which is useful once an enemy is on the board (the One-Hit Kill check needs a live enemy).

Last verified result (2026-11-03, real game, Wanderer hero): 12 of 12 PASS, including One-Hit Kill on a live enemy (HP 2 -> 0 from a 1-damage hit) and an Edamame potion that stayed usable after being used.

## Troubleshooting

- **No overlay**: make sure `winhttp.dll` is next to `ShogunShowdown.exe` and `BepInEx\LogOutput.log` exists after launch. Antivirus sometimes quarantines `winhttp.dll` (it is the BepInEx/Doorstop loader): add an exception.
- **Hotkeys do nothing**: the game window must have focus. Overlay visible but keys ignored usually means another window is in front.
- **After a game update** the plugin hooks methods by name, so it usually keeps working; if a hook fails the log says `Patch ... failed` and that feature is inert. Re-run Install.bat if a launcher "verify" removed the files.
- **Reveal Map**: some map nodes cannot play their fog animation from outside the map screen, so the trainer marks them uncovered directly. If a node still looks hidden, open the map once with the toggle on.
- Save compatibility: coins and meta currency changes are written to your save like normal gameplay. Keep a backup of your save folder before using Infinite Money or Add Meta.

## Rebuild from source

`source\src\ShogunTrainer.cs` + `source\build.ps1` (uses the .NET Framework `csc.exe`, no SDK required; needs the BepInEx `core` DLLs from `payload\BepInEx\core` and the game's `ShogunShowdown_Data\Managed` folder).

## Credits / licenses

BepInEx 5.4.23.3 (LGPL-2.1) and HarmonyX/MonoMod (MIT) are bundled unmodified from https://github.com/BepInEx/BepInEx. Trainer code: this package.
