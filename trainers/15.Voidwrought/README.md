# Voidwrought - Offline Trainer v1

In-game trainer for **Voidwrought** (Powersnake; Epic Games build Win.1.1.33, Unity 2021.3.39 **Mono**, Windows x64, DirectX 11).
Single-player / offline use only. It does not touch online services and contains no anti-cheat bypass (the game has none).

It is a BepInEx 5 plugin: Harmony hooks the game's own C# methods at runtime. **No game file is modified** - the original `Assembly-CSharp.dll` stays untouched and everything is removable with one script. An overlay in the top-left corner shows every hotkey and its state.

## Hotkeys (in game, after you have loaded a save)

| Key | Feature | Type |
|-----|---------|------|
| **F1** | **God Mode** - no HP loss from any source. (Spikes/pits still put you back on the last safe ground, like vanilla, so you never fall forever.) | toggle |
| **F2** | **Add Money** - +10,000 Ichor and +1,000 Trace Metal (clamped by the game's 99,999 cap) | one-shot |
| **F3** | **Infinite Money + Items** - every purchase, crafting cost, upgrade and cost check is free; Ichor and Trace Metal are kept at the cap | toggle |
| **F4** | **Unlimited Jump** - endless air jumps (works even before you find Double Jump) | toggle |
| **F5** | **Speed x2** run speed (PageUp cycles x2 / x3 / x4 / x1.5) | toggle |
| **F6** | **One-Hit Kill** - every hit on an enemy takes its remaining HP | toggle |
| **F7** | **Full Heal** - HP, heal flasks (Salt) and relic charges | one-shot |
| **F8** | **Infinite Flasks + Charges** - heal flasks and relic energy are never spent | toggle |
| **F9** | **Show Items** - green/yellow/blue markers (with distance, arrows at the screen edge) for uncollected pickups, secrets and lore stones in the current room; the overlay also shows how many pickups/secrets/lore you have in this region | toggle |
| **F10** | **Reveal Whole Map** (the game's own `map_complete`) | one-shot |
| **F11** | **Noclip** free-fly with the direction keys (the game's own debug noclip) | toggle |
| **F12** | Show / hide the overlay | toggle |
| **Home** | Fill all material / currency stacks to their cap (not upgrade levels, not story counters) | one-shot |
| **End** | Unlock every relic and crest (equip them in the menu) | one-shot |

Toggles start OFF at every launch. Hotkeys only work while a save is loaded (the overlay says "load a save to activate" otherwise).

### Things to know

- **What gets saved.** Money, materials, relics and the revealed map change your real inventory/map data, so they are written to the save the next time the game saves (normal save rooms). Toggles themselves (God, speed, ...) are never saved. If you want to try things risk-free, copy `%USERPROFILE%\AppData\LocalLow\Powersnake\Voidwrought\*.sav` somewhere first. (Epic cloud sync will ask which save to keep if it sees a change - choose the one you want.)
- **One-Hit Kill and bosses.** It sets each hit to the enemy's remaining HP, so a boss dies on the first hit. If a boss fight scripts phases from its HP, switch it off for that fight.
- **Unlimited Jump** turns the Double Jump ability on for as long as the toggle is on. Switching it off restores the real ability state.
- **Item markers** list objects the game names `... Pickup ...`, `Secret`, `Lore Stone`, `Chest`. Rooms may hold things that are hidden behind scripts and do not show up; the region counter (X/Y) tells you how many you still miss.
- Home / End are deliberately not on F-keys so you do not press them by accident.

## Install (on any PC that has the game)

1. Unzip `Voidwrought-Trainer-v1.zip` anywhere.
2. Close the game.
3. Double-click **Install.bat**. It finds the game from the Epic Games manifest, Steam libraries or common folders; if it cannot, it asks you to paste the game folder (the one that contains `Voidwrought.exe`).
   - Or in a terminal: `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\VoidwroughtFq9Qv"`
4. Start the game normally (Epic Games Launcher), load a save. The overlay appears top-left.

Installed files (all listed in `VwTrainer_install_manifest.txt` in the game folder): `winhttp.dll`, `doorstop_config.ini`, `.doorstop_version`, `BepInEx\core\*`, `BepInEx\plugins\VwTrainer.dll`. An existing `winhttp.dll` / `doorstop_config.ini` is kept as `.orig` and restored on uninstall.

The installer warns (but continues) if your game build differs from the one the trainer was tested on (`Assembly-CSharp.dll` SHA-256 `1B093F6D297CFE3D...CA62`).

## Uninstall

Double-click **Uninstall.bat** (add `-Purge` in a terminal to also delete the whole `BepInEx` folder with config and logs).

## Configuration

After the first launch edit `<game>\BepInEx\config\com.research.voidwroughttrainer.cfg`:
- Rebind any hotkey (Unity `KeyCode` names, e.g. `F9`, `Keypad1`, `Insert`).
- `AddIchorAmount`, `AddTraceMetalAmount`, `SpeedMultiplier`, `ItemMarkerMaxDistance`, `ShowHud`.

## Self-test (optional)

Create an empty file `trainer_selftest.flag` in the game folder (or set `TRAINER_SELFTEST=1`), start the game, load a save and wait ~15 s. `trainer_selftest_report.json` lists every feature as PASS/FAIL with its hook status (the file `trainer_selftest_full.flag` additionally runs the one-shot actions - map reveal, max materials, all relics - in memory). Last result: 11/11 PASS, 0 patch errors. Delete the flag files afterwards.

## Troubleshooting

- **No overlay**: `winhttp.dll` must sit next to `Voidwrought.exe` and `BepInEx\LogOutput.log` must exist after a launch. Some antivirus tools quarantine `winhttp.dll` (it is the BepInEx/Doorstop loader) - add an exception.
- **An "Epic Games sign-in" window pops up over the game**: that is the Epic overlay, not the trainer. Close it with the X, or launch the game from the Epic Games Launcher while you are signed in.
- **A feature does nothing after a game update**: the plugin hooks methods by name/signature; if one disappears the log says `Patch failed for ...` and only that feature is inert. Re-run Install.bat after an Epic "Verify" if it removed files.
- Keys do nothing while the game window is not focused.

## Rebuild from source

`source\VwTrainer.cs` + `source\build.ps1` (uses the .NET Framework `csc.exe` that ships with Windows - no SDK needed; point `-Bep` to the BepInEx `core` folder and `-Game` to the game folder).

## Credits / licenses

BepInEx 5.4.23.3 (LGPL-2.1) and HarmonyX / MonoMod (MIT) are bundled unmodified from https://github.com/BepInEx/BepInEx. Trainer code: this package.
