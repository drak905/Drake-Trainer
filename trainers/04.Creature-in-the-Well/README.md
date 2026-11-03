# Creature in the Well - Trainer (portable patch v1)

An in-game trainer for the **offline, single-player** game. It adds God mode, money, unlimited dash, speed x2 and more, each on its own F-key.

It does **not** change `CITW-Win64-Shipping.exe`, the `.pak` or your save files. It is one DLL (`xinput1_3.dll`) that hooks the game in memory while it runs. Removing the DLL removes the trainer. It does not touch anti-cheat or online features.

## Requirements

- Windows 10/11, 64-bit
- Creature in the Well, **Epic Games build 1.0.0-137001-1** (`CITW-Win64-Shipping.exe` SHA-256 starts with `C6A31630...EAA54`)
- PowerShell 5.1+ (already included in Windows)

Other builds: the installer warns you. The trainer looks up each hook by its code signature and skips any it cannot find, so a different build may have some or all features disabled.

## Install

1. **Close the game completely** (check Task Manager for `CITW-Win64-Shipping.exe`).
2. Unzip `CITW-Trainer-v1.zip` anywhere.
3. Double-click **`Install.bat`**.
   - It finds the Epic install folder automatically. If it cannot, it asks you for the folder that contains `CITW.exe`.
   - It checks the game version, backs up any existing `xinput1_3.dll`, and copies the DLL and `citw_trainer.ini` to `<game>\CITW\Binaries\Win64\`.
   - Manual alternative: `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\CreatureintheWell"`
4. Start the game (Epic launcher or `CITW.exe`) and **load your save**.

## Use

The game window must be in focus. A small overlay appears at the top-left, listing each feature as ON (green) or OFF (red).

| Key | Feature | What it does |
|---|---|---|
| **F1** | God mode | Health can never go down |
| **F2** | Infinite money | Temple Power (the currency) is never spent |
| **F3** | Add money | +1000 Temple Power per press |
| **F4** | Unlimited dash | No dash cooldown, dashes can be chained (the game has no jump button, so this is its "jump") |
| **F5** | Speed | Move speed and acceleration x2 |
| **F6** | One-hit kill | Hero attack power 99999 |
| **F7** | Full heal | Health back to 100 |
| **F9** | Cycle speed | x2 / x3 / x4 / x1.5 |
| **F12** | Overlay | Show or hide the overlay |

Toggle keys beep: a high tone for ON and a low tone for OFF. F3 and F7 are one-shot actions and are applied on the next frame.

Add money and Full heal need a loaded save slot. They do nothing on the title screen.

## Settings

Edit `<game>\CITW\Binaries\Win64\citw_trainer.ini` while the game is closed:

```ini
[keys]            ; virtual-key codes, decimal (F1=112 ... F12=123)
key_god=112
key_infinite_power=113
key_add_power=114
key_unlimited_dash=115
key_speed=116
key_one_hit_kill=117
key_full_heal=118
key_cycle_speed=120
key_overlay=123

[trainer]
money_amount=1000 ; how much F3 adds
speed_mult=2.0    ; speed multiplier for F5
overlay=1         ; 0 = start with the overlay hidden

[start]           ; 1 = feature already ON when the game starts
god=0
infinite_power=0
unlimited_dash=0
speed=0
one_hit_kill=0
```

## Check that it loaded

Open `<game>\CITW\Binaries\Win64\citw_trainer.log`. A good start ends with:

```
hooks installed: 8/8
```

If a line says `AOB not found`, that feature is skipped and the others keep working.

Optional self-test: create an empty file named `trainer_selftest.flag` next to the exe, start the game, and read `trainer_selftest_report.json`. It lists PASS or FAIL for each feature.

## Uninstall

Close the game and double-click **`Uninstall.bat`**. It removes the trainer DLL, restores any `xinput1_3.dll` it backed up, and deletes the ini, log and self-test files. Game files and saves are never modified.

## Troubleshooting

| Problem | Fix |
|---|---|
| Installer says the game is running | Close the game, and check Task Manager for a lingering `CITW-Win64-Shipping.exe` |
| No overlay and no log file | The DLL is not in `...\CITW\Binaries\Win64\` (next to `CITW-Win64-Shipping.exe`). Re-run `Install.bat` |
| Overlay invisible | Use windowed or borderless fullscreen (the game default). It cannot draw over exclusive fullscreen |
| Keys do nothing | Click the game window first. Check for key conflicts and remap in the ini |
| Add money or Heal do nothing | Load a save slot first (they do not work on the title screen) |
| Game crashes with "GameThread timed out waiting for RenderThread" | Seen once when relaunching within a few seconds of force-closing the game. Wait about 10 seconds and start it again |
| Different game build | See Requirements. Check the log to see which hooks were skipped |

## Known limits

- **Unlimited dash:** the hook installs and the self-test confirms it, but I have not exercised it with a real dash input.
- **One-hit kill:** I verified the hero's attack power value changes, not that enemies die in a fight.
- A game update that changes the exe may disable some hooks.

## What is in this package

| File | Purpose |
|---|---|
| `xinput1_3.dll` | The trainer. It forwards all controller calls to the real Windows `xinput1_3.dll` |
| `citw_trainer.ini` | Default settings (copied to the game folder on install) |
| `Install.bat` / `install.ps1` | Installer |
| `Uninstall.bat` / `uninstall.ps1` | Uninstaller |
| `SHA256SUMS.txt` | Checksums of the package files |
| `source/` | C source, `hooks_gen.h` and the PDB tools. Rebuild with `source\build.ps1` (needs Python and `pip install ziglang==0.13.0.post1`) |
