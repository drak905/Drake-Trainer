# SpeedBrawl In-Game Trainer - Portable Patch v1.0.0

An in-game trainer for the PC (Epic Games) version of **SpeedBrawl**. It adds a small
overlay menu inside the game with per-feature toggles and F-keys. The patch is portable:
copy this folder to another PC, run the installer, and start the game normally.

The trainer is built on **BepInEx 5.4.23.6 (x64) + HarmonyX**. It does not replace or
modify `SpeedBrawl.exe` or any game asset. It only adds `BepInEx` loader files and a
single plugin DLL, and the uninstaller can restore the original state.

---

## Features and default keys

Press **Insert** to show or hide the trainer menu. The menu can also be operated with
the mouse. F-keys work while the menu is hidden.

| Key | Feature | Type | Notes |
| --- | --- | --- | --- |
| `Insert` | Show / hide trainer menu | Toggle | The menu starts visible |
| `F1` | God Mode | Toggle | Player heroes ignore non-helpful damage |
| `F2` | Unlimited Jumps | Toggle | Air jumps are never consumed for player heroes |
| `F3` | Character Move Speed x2 | Toggle | Doubles the player's target run speed |
| `F4` | Infinite Stamina / Special | Toggle | Uses the game's built-in InfiniteEnergy flag and refills hero meters |
| `F5` | Infinite Coins | Toggle | Keeps the coin balance topped up at 9,999,999 |
| `F6` | Add 100,000 Coins | One-shot | Adds to the current balance, clamps at 999,999,999, saves |
| `F7` | Infinite Items (no item loss) | Toggle | Prevents item stack amounts from decreasing for the team inventory; coins are excluded |
| `F8` | Unlock All Gear Items | One-shot | Adds every gear item in the item database and saves |
| `F9` | Show All Items (ESP) | Toggle | Draws on-screen markers for world items, crates, barrels, targets and props |
| `F10` | One-Hit Kill (enemies) | Toggle | Sets incoming damage on enemies to a lethal value |
| `F11` | Unlock All Championships | One-shot | Uses the game's built-in AllChampionshipsUnlocked flag |
| `Home` | Force Save | One-shot | Calls the game's SaveSystem through its built-in cheat helper |

Feature notes:

- **God Mode** is applied only to objects that have a `Hero_Server` component. Enemies,
  crates and destructible props keep normal damage behaviour.
- **Infinite Items** is scoped to the player's `TeamInventory` stacker. It prevents
  decreases of existing item amounts; it does not change coin amounts.
- **Show All Items (ESP)** scans for `DS.Game.Items.Item`, `Crate_Server`,
  `Barrel_Server`, `Target_Server`, `MovingProp_Server`, `StaticProp_Server`,
  `NetworkCrate`, `NetworkBarrel`, `NetworkTarget`, and `NetworkMovingProp`.
- **Unlock All Gear Items** adds gear data from `ItemManager.GearItemDatas`. If the
  item database has not loaded yet (for example, very early in the main menu), the
  status line reports `Unlocked gear: 0`; press it again after loading a save.
- **One-Hit Kill** is intended for offline play and should normally be combined with
  God Mode, because the game shares damage handling between heroes and enemies.

## Requirements

- Windows 64-bit.
- The same SpeedBrawl build that was tested:
  - `SpeedBrawl.exe` file version `2019.4.16.14703470`
  - Unity `2019.4.16`
  - `SpeedBrawl_Data\Managed\DS.Game.Luna.dll` SHA-256:
    `76DD93E1EFFB3BD063F47F5EDCF664F2847001457F55B6D84E048B7E72D5BA29`
- The game must be the Epic Games version (or a build with the same managed assemblies).
- No other trainer or BepInEx installation is required. The installer can coexist with
  an existing BepInEx installation.

## Quick install

1. Copy the whole `SpeedBrawlTrainer_Portable_v1.0.0` folder to the other PC.
   Do not copy only `Install-Trainer.bat`.
2. Close SpeedBrawl.
3. Double-click `Install-Trainer.bat`.
   - The installer auto-detects common Epic install folders.
   - If auto-detection fails, run:
     `Install-Trainer.bat -GamePath "D:\Path\To\SpeedBrawl"`
4. Start SpeedBrawl normally (from Epic Games Launcher, a desktop shortcut, or
   `SpeedBrawl.exe`).
5. Press **Insert** in game. The trainer menu should appear in the top-left.

The installer prints the detected game path, verifies the game build, backs up any
existing loader files, installs the payload, and writes a manifest to
`BepInEx\plugins\SpeedBrawlTrainer.install.json`.

### Why the payload changes Doorstop's `ignore_disable_switch`

The Epic Games Launcher sets the `DOORSTOP_DISABLE` environment variable for some
games. Doorstop (the BepInEx loader) normally honours that variable and refuses to
load. The portable payload therefore ships a `doorstop_config.ini` with:

```ini
ignore_disable_switch = true
```

This is a launcher compatibility setting, not an anti-cheat bypass. It only makes the
mod loader start when the game is launched by Epic. If an older BepInEx installation is
detected, the installer updates this value and backs up the original file.

## Manual install

If you prefer to install by hand:

1. Copy the contents of `payload\` into the SpeedBrawl folder:
   - `winhttp.dll`
   - `doorstop_config.ini`
   - `.doorstop_version`
   - `BepInEx\` (contains `core\` and `plugins\`)
2. Confirm the final layout:

```
SpeedBrawl\
  SpeedBrawl.exe
  winhttp.dll
  doorstop_config.ini
  .doorstop_version
  BepInEx\
    core\
      BepInEx.dll
      ...
    plugins\
      SpeedBrawlTrainer.dll
```

3. Start the game and press **Insert**.

## Uninstall

1. Close SpeedBrawl.
2. Double-click `Uninstall-Trainer.bat`.
   - If auto-detection fails:
     `Uninstall-Trainer.bat -GamePath "D:\Path\To\SpeedBrawl"`
3. The uninstaller removes the trainer plugin and restores the backup created during
   installation. If BepInEx was installed by the trainer and no other plugins exist,
   the loader files are removed as well.

If other BepInEx plugins are installed, the uninstaller keeps BepInEx and only removes
the SpeedBrawl trainer plugin.

## Troubleshooting

### No trainer menu appears

1. Check that `BepInEx\LogOutput.log` exists in the game folder.
2. Open it and look for:
   - `Loading [SpeedBrawl In-Game Trainer 1.0.0]`
   - `Patched Health_Server.OnPreDamage`
   - `Chainloader startup complete`
3. If the log is missing, BepInEx did not load:
   - Confirm `winhttp.dll`, `doorstop_config.ini` and `.doorstop_version` are in the
     game folder next to `SpeedBrawl.exe`.
   - Confirm `doorstop_config.ini` contains `ignore_disable_switch = true`.
   - Some antivirus products quarantine `winhttp.dll`; add the game folder to the
     allow list and reinstall.
4. If the log exists but the plugin did not load, confirm
   `BepInEx\plugins\SpeedBrawlTrainer.dll` exists and is not zero bytes.
5. Check the game build hash. A different SpeedBrawl build may have different managed
   method names; the installer warns about this. Use `-Force` only if you accept that
   the trainer may fail to patch.

### The menu appears but a feature does nothing

- Most gameplay features only act while a level is loaded and the player hero exists.
  `Coins` and `Heroes` in the status line show whether the game objects are ready.
- `Unlock All Gear Items` depends on the item database being loaded. Try it again
  after loading a save or entering the team screen.
- `God Mode` and `One-Hit Kill` rely on the game's server-side `Health_Server`
  components. They do not affect menu-only scenes.
- If a feature is toggled while an online session is detected, the trainer suppresses
  itself and shows `ONLINE SESSION DETECTED`. Leave the online session and restart the
  level for offline use.

### The game will not start after installation

- Run `Uninstall-Trainer.bat` to restore the backup.
- If the game still fails, verify the game files through Epic Games Launcher.
- The installer never edits `SpeedBrawl.exe`; only loader files are added.

## Compatibility and safety

- **Offline / single-player use only.** Do not enable the trainer in online matches.
  The plugin checks the game's party connector and disables its patches when an online
  party is detected, but this is a best-effort guard, not a guarantee.
- The trainer does not bypass DRM, anti-cheat, or online protections. It uses only
  managed BepInEx/Harmony patches and the game's own cheat flags.
- `God Mode`, `Infinite Coins`, and `Unlimited Items` can change your save data. Back
  up your save files before experimenting:
  `%USERPROFILE%\AppData\LocalLow\Double Stallion\SpeedBrawl\`
- The uninstaller restores loader files from the timestamped
  `_TrainerBackup_<date>_<time>` folder created at install time.

## Technical summary

- Loader: **BepInEx 5.4.23.6 x64** (Doorstop + HarmonyX 2.9).
- Plugin: `SpeedBrawlTrainer.dll`, GUID `com.rea.speedbrawl.trainer`, version `1.0.0`.
- Managed analysis target: `DS.Game.Luna.dll` (Unity 2019.4.16 Mono).
- Harmony patches:
  - `DS.Game.Luna.Health_Server.OnPreDamage` — God Mode (aborts non-helpful damage
    for objects with `Hero_Server`).
  - `DS.Game.Luna.Health_Server.ResolveDamage` — One-Hit Kill (sets lethal damage on
    `Enemy_Server` objects).
  - `DS.Game.Luna.PlatformerController2D_Server.get_AirJumps` — returns `-1` for
    player heroes while Unlimited Jumps is enabled.
  - `DS.Game.Luna.MovementController_Server.GetTargetRunSpeed` — multiplies the
    target run speed by `2` for player heroes.
  - `DS.Game.Items.InventoryStacker.SetAmountInternal` — blocks decreases of existing
    item amounts in the player's `TeamInventory`; coins are excluded.
- Game-provided cheat flags used through `DS.Game.Luna.Cheats`:
  - `Cheats.CheatBool.Invincible` (God Mode flag)
  - `Cheats.CheatBool.InfiniteEnergy` (Infinite Stamina / Special)
  - `Cheats.CheatBool.AllChampionshipsUnlocked` (Unlock All Championships)
  - `Cheats.ForceSave()` (Force Save)
- Coins are written through `ItemManager.Instance.TeamInventory.Stacker[
  GameConfig.Instance.CoinItemID]`, which keeps the HUD and save data in sync.

## What was verified

- BepInEx 5.4.23.6 loads SpeedBrawl through the Epic Games Launcher after the
  `ignore_disable_switch` fix.
- All five Harmony patches apply without errors (`BepInEx\LogOutput.log`).
- The overlay menu renders in game.
- `F6 Add 100,000 Coins` changed the balance from `105` to `100,105`, and the game HUD
  updated immediately.
- `F5 Infinite Coins` raised the balance to `9,999,999`, and the game HUD updated.
- The plugin was rebuilt from the included source and the final DLL was smoke-tested in
  the Epic-launched game.

## File list

```
SpeedBrawlTrainer_Portable_v1.0.0\
  Install-Trainer.bat
  Install-Trainer.ps1
  Uninstall-Trainer.bat
  Uninstall-Trainer.ps1
  README.md
  VERIFICATION.md
  EVIDENCE_LOG.txt
  SHA256SUMS.txt
  payload\
    winhttp.dll
    doorstop_config.ini
    .doorstop_version
    BepInEx\
      core\...
      plugins\SpeedBrawlTrainer.dll
  Source\
    SpeedBrawlTrainer.cs
    build.ps1
```

## Attribution

- BepInEx: https://github.com/BepInEx/BepInEx (LGPL-2.1)
- HarmonyX: https://github.com/BepInEx/HarmonyX (MIT)
- SpeedBrawl is a trademark of its respective owner. This patch is a fan-made
  single-player trainer and is not affiliated with or endorsed by the game's
  developer or publisher.



