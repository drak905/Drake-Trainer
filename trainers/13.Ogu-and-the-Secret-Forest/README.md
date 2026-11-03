# Ogu and the Secret Forest - Offline Trainer v1

In-game trainer for **Ogu and the Secret Forest** (v1.2.2, Unity 2022.3.19 Mono, Windows x64, Epic Games build).
Single-player / offline use only. It does not touch online services and contains no anti-cheat bypass.

It works as a BepInEx 5 plugin (Harmony hooks into the game's own C# methods). **No game file is modified** - the original `Assembly-CSharp.dll` stays untouched, and everything is removable with one script.

## Hotkeys (in game)

| Key | Feature | Type |
|-----|---------|------|
| F1 | God Mode - Ogu takes no damage | toggle |
| F2 | Add Money (+10,000 gold, capped by the game at 999,999) | one-shot |
| F3 | Infinite Money - gold locked at max, purchases cost nothing | toggle |
| F4 | Speed x2 (walk/run/roll) | toggle |
| F5 | No Cooldowns - unlimited roll/dodge, hat skills, consumable cooldowns | toggle |
| F6 | One-Hit Kill - enemies hit by Ogu die instantly | toggle |
| F7 | Full Heal | one-shot |
| F8 | Show/hide the status overlay (top-left) | toggle |

Note on "unlimited jump": this game is top-down and has no jump button. F5 (unlimited roll/dodge) is the equivalent evasive move.

Toggles start OFF every launch. The overlay shows the current state of each toggle.

## Install (on any PC that has the game)

1. Unzip `Ogu-Trainer-v1.zip` anywhere.
2. Close the game.
3. Double-click **Install.bat**. It finds the game via the Epic Games manifest; if it can't, it asks you to paste the game folder (the one containing `OguForest.exe`).
   - Or: `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\OguandtheSecretFores6K1u7"`
4. Start the game normally (Epic launcher or `OguForest.exe`). The overlay appears top-left once you are in the game.

Installed files (all listed in `OguTrainer_install_manifest.txt` in the game folder): `winhttp.dll`, `doorstop_config.ini`, `.doorstop_version`, `BepInEx\core\*`, `BepInEx\plugins\OguTrainer.dll`.

## Uninstall

Double-click **Uninstall.bat** (add `-Purge` in a terminal to also delete the BepInEx folder with the config and logs). Original `winhttp.dll`/`doorstop_config.ini`, if any existed, are restored from `.orig` backups.

## Configuration

After the first launch edit `<game>\BepInEx\config\com.research.ogutrainer.cfg`:
- Rebind any hotkey (names from the Unity Input System `Key` enum, e.g. `F9`, `Numpad1`).
- `AddMoneyAmount` (default 10000), `SpeedMultiplier` (default 2), `ShowHud`.

## Self-test (optional)

Set the environment variable `TRAINER_SELFTEST=1` before launching, load a save, wait ~5 s. `<game>\trainer_selftest_report.json` lists each feature as PASS/FAIL (hook present + live invariant/delta checks). Last verified result: all 6 features PASS.

## Troubleshooting

- **No overlay**: make sure `winhttp.dll` is next to `OguForest.exe` and `BepInEx\LogOutput.log` exists after launch. Antivirus sometimes quarantines `winhttp.dll` (it is the BepInEx/Doorstop loader) - add an exception.
- **Epic sign-in window appears when launching `OguForest.exe` directly**: close it with the X, or launch via the Epic Games Launcher.
- **After a game update** the plugin hooks methods by name, so it usually keeps working; if a hook fails the log says `Patch ... failed` and that feature is inert. Epic "Verify" does not remove added files, but re-run Install.bat if it does.
- Save compatibility: gold changes are written to the save like normal gameplay. Keep a backup of your save before using Infinite Money.

## Rebuild from source

`source\OguTrainer.cs` + `source\build.ps1` (uses the .NET Framework `csc.exe`, no SDK required; needs BepInEx `core` DLLs and the game's `Managed` folder).

## Credits / licenses

BepInEx 5.4.23.3 (LGPL-2.1) and HarmonyX/MonoMod (MIT) are bundled unmodified from https://github.com/BepInEx/BepInEx. Trainer code: this package.
