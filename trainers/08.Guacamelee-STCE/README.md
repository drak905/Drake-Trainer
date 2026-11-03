# Guacamelee! Super Turbo Championship Edition - Trainer v1.0.0

An in-game trainer for the **offline / single-player** game, with a toggle key for every cheat.
It works as a small `dinput8.dll` that the game loads on start-up (a "proxy DLL"):

* **No game file is modified** (`Game.exe`, `*.dat`, your saves are never touched).
* Everything is found at start-up from byte signatures and the engine's own variable names,
  so it also adapts to slightly different builds (Epic / Steam / GOG). A cheat it cannot find is
  greyed out (`N/A`) instead of crashing the game.
* Tested on: Epic Games Store build `GuacSTCE_29-06-2023_16-43-23+66`
  (`Game.exe`, 5,607,424 bytes, SHA-256 `DE6CEC52F06B8E0FC835356B31AB80891BC4BA6431823B0EEF6FC02C480209F2`), Windows 11, 32-bit game.

> Use it only in the single-player / local co-op game. It does nothing to online features and contains no
> anti-cheat bypass (the game has none). Cheats that give money or reveal the map change the values the game
> later writes to your save - keep a backup of your save if you care about it (see *Saves* below).

---------------------------------------------------------------------------------------------------

## 1. Install (another PC)

1. Install the game normally (Epic / Steam / GOG) and start it once so it is complete.
2. Unzip this folder anywhere.
3. Close the game and double-click **`Install.bat`**.
   * It finds the game by itself (Epic launcher manifests, Steam libraries, common folders).
   * If it cannot, it asks you to paste the folder that contains `Game.exe`; or run
     `Install.bat -GameDir "D:\Games\GuacameleeSTCE"`.
4. Start the game as usual. A key list appears in the top-left corner ("Guacamelee! Trainer v1.0.0").

**Manual install:** copy `payload\dinput8.dll` and `payload\GuacTrainer.ini` next to `Game.exe`.

**Uninstall:** close the game and double-click **`Uninstall.bat`** (or just delete `dinput8.dll`,
`GuacTrainer.ini`, `GuacTrainer.log` and `GuacTrainer_install_manifest.txt` from the game folder).
If another `dinput8.dll` existed before, the installer kept it as `dinput8.dll.orig` and the uninstaller restores it.

Requirements: Windows 10/11 (the DLL uses the Windows 10 C runtime), the 32-bit game build, PowerShell 5 (built in).

---------------------------------------------------------------------------------------------------

## 2. Hotkeys (game window must be focused)

| Key | Feature | What it does |
|-----|---------|--------------|
| **F1** | God Mode | No player takes damage (uses the game's own "Players Invulnerable" switch). Enemies are unaffected. |
| **F2** | Infinite Stamina | Stamina / magic never runs out (the game's "Infinite Mana" switch). |
| **F3** | +10,000 Pesos | Adds money through the game's own function (the game caps money at 100,000). Press repeatedly. |
| **F4** | Unlimited Money | Fills your money to 100,000 and makes shops/upgrades cost nothing. |
| **F5** | Unlimited Jump | Jump again in mid-air as often as you like - even before you unlocked the double jump. |
| **F6** | Move Speed x2 | Juan runs/walks twice as fast. **F9** cycles the multiplier x2 -> x3 -> x4. |
| **F7** | Show Entire Map + Items | Reveals the whole map of the area (rooms, chests, doors, collectibles). Pressing again restores your real explored map. |
| **F8** | One-Hit Kill | Every hit on an enemy does 1000x damage. Default off - avoid on multi-phase bosses. |
| **F9** | Cycle speed | x2 / x3 / x4 for F6. |
| **F10** | Infinite Intenso | Keeps the Intenso (Devil Trigger) bar full. |
| **F11** | Game debug menu | Unlocks the developers' hidden **Debug Options** entry in the pause menu (jump to any level, inventory editor, destroy nearby enemies, ...). |
| **F12** | Panel | Show / hide the key list (green = on). A short message also appears for every toggle. |

All keys, the speed multiplier, the money amount and the panel can be changed in `GuacTrainer.ini`
(next to `Game.exe`; restart the game after editing). Use `NONE` to disable a key.

Tips
* Switch cheats on **after** the save is loaded if you want to see the effect immediately; they stay on across levels.
* Unlimited Money makes shops free - buy what you like, then press F4 again to turn it off.
* If a key conflicts with a Steam/Epic overlay shortcut (e.g. F12 for screenshots on Steam), change it in the ini.

---------------------------------------------------------------------------------------------------

## 3. Saves

Saves live in `Documents\GuacameleeSTCE_EGS\` (`SAVE.DAT`, `LOCALSETTINGS.DAT`; the folder name differs on other stores).
The trainer never writes them, but the *game* will save the cheated values (money, revealed map) at its next
checkpoint. To be safe, copy that folder before using money/map cheats, or turn the cheat off before saving
(F7 restores the real map, F4 off leaves money at whatever it is - spend or edit as you like).

---------------------------------------------------------------------------------------------------

## 4. Troubleshooting

* **Nothing appears on screen** - the panel is drawn on top of the game in DirectX 9. Check
  `GuacTrainer.log` in the game folder: every feature prints `gate1 ... OK/FAIL`. `hook_d3d9 FAIL` only
  disables the on-screen text; the hotkeys still work.
* **A feature says `N/A`** - the signature was not found in your build of `Game.exe`; send `GuacTrainer.log` along.
* **Hotkeys do nothing** - click the game window first (keys are read only while it is focused). On some
  laptops F-keys need `Fn`.
* **Game crashes at start after a game update** - run `Uninstall.bat`; the signatures are verified for uniqueness,
  but a big engine update can still break a hook. Please report with `GuacTrainer.log`.
* Antivirus may warn about an unsigned `dinput8.dll` (typical for any mod loader). The source is in `source\`.

---------------------------------------------------------------------------------------------------

## 5. What is inside / how it was made

```
Install.bat / install.ps1      auto-detect game folder, copy payload, write manifest
Uninstall.bat / uninstall.ps1  remove everything the installer added (restores a previous dinput8.dll)
payload\dinput8.dll            the trainer (x86, ~230 KB, MinHook linked in)
payload\GuacTrainer.ini        default settings
source\guac_trainer.c          complete source;  source\build.bat rebuilds it (python -m pip install ziglang==0.13.0.post1)
source\minhook\                MinHook (BSD-2) used for the inline hooks
SHA256SUMS.txt                 checksums of every file
```

Reverse-engineering summary (Ghidra + custom scripts, details in `artifacts/gcm/`):
the engine ("Gengine", native C++ x86, D3D9) ships its developer console and debug menu in the retail build.
God mode, infinite stamina and the debug menu are plain engine switches found by name (`g_playersInvincible`,
`g_infiniteMana`, `g_debugMenuEnabled`). Money uses the game's `AddCurrency`/`SpendCurrency`, the map reveal is the
engine's own "Clear Map Fog of War", Intenso uses the engine's `FillDevil` console command. Unlimited jump patches the
air-jump counter test in `Character::Update` (reversible, in memory only); speed scales `m_moveSpeed/m_walkSpeed` of the
player objects inside a hook of that same update; one-hit kill hooks the damage routine and only touches non-player objects.

Verified in the live game: money (+10,000 / 100,000 / free shops), unlimited jump (6 mid-air jumps), speed (13.6 -> 25.1 units/s),
full map reveal, god mode (synthetic hit test), hotkeys and overlay. One-hit kill is logic-tested only (no enemy was reachable in
the test save) - tell us if a boss behaves oddly.

Credits: MinHook by Tsuda Kageyu (BSD-2-Clause). Game (c) DrinkBox Studios. This trainer is an unofficial fan tool.

