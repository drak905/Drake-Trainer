# Dead Cells Trainer v1 (F-key cheats, single-player)

A patch for **Dead Cells** (made on the Epic Games build, version 35 `1.25.2Win-8b5231cd25`) that adds
cheats you switch on and off with the F-keys while playing. A **trainer menu** in the top-left corner of the
screen lists every key; a toggle's line turns **green when it's ON** and grey when it's OFF. Press **F12** to
hide or show the menu. Each key press also shows a message such as `[DC Trainer] God mode: ON` in the game's
message log. All cheats start **OFF** and the menu starts **shown** every time the game starts.

## Trainer menu

```
DC TRAINER   (F12 hide / show)        <- yellow title
F1   God mode                          <- green = ON, grey = OFF
F3   Unlimited gold & cells
F4   Unlimited jumps
F5   Speed x2
F6   Reveal map & items
F7   Unlimited flasks / ammo / skills
F2   +100,000 gold  +500 cells         <- white = one-press action
F8   Full heal
```

The menu sits on a dark see-through panel, uses the game's own font and HUD scaling, and is part of the
game's HUD, so it hides together with the HUD during cutscenes. It is shown during runs and in the hub
areas (anywhere the game HUD is up), not on the title screen.

## Hotkeys

| Key | Feature | Type | What it does |
|-----|---------|------|--------------|
| **F1** | God mode | toggle | Enemy attacks, traps and falls don't hit you; instant-kill calls are ignored; your health is refilled if anything still gets through. |
| **F2** | Add money | one press | +100,000 gold and +500 cells. |
| **F3** | Unlimited gold & cells | toggle | Spending gold or cells (shops, the Collector) doesn't lower them; gold is kept at 999,999 or more and cells at 9,999 or more. |
| **F4** | Unlimited jumps | toggle | You can jump again in mid-air as many times as you like. |
| **F5** | Speed x2 | toggle | Running speed +100% (2x the base run speed). |
| **F6** | Reveal map & items | toggle | Reveals the whole map of the current level (rooms, items, chests, scrolls, exits, elites, the same as the game's "Explorer's Instinct"). It runs again on every new level while it's ON. |
| **F7** | Unlimited items | toggle | Health flasks are never used up, bows and other ammo weapons never run out, and skills (grenades, turrets, powers) have no cooldown. |
| **F8** | Full heal | one press | Restores all health. |
| **F12** | Trainer menu | toggle | Hides / shows the menu in the top-left corner. |

## Install (on any PC)

1. Close Dead Cells.
2. Copy this whole folder (or unzip `DeadCells-Trainer-v1.zip`) anywhere on the PC.
3. Double-click **`Install.bat`**.
   - It finds the game by itself (Epic Games launcher, Steam libraries, or common folders such as
     `E:\EpicGames\DeadCells`).
   - If it can't find the game, open PowerShell in this folder and run:
     `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Path\To\DeadCells"`
4. Start Dead Cells the usual way (from the Epic Games launcher), start a run, and press the F-keys.

What the installer does:
- Backs up your saves to `<game>\save-backup-<date-time>` (Epic keeps saves in the game folder).
- Copies the original game exe to `<game>\deadcells.exe.trainer-backup`.
- Checks the SHA-256 of `deadcells.exe`:
  - **Same build as this package** (`FFC17ED5…5A77`): it applies `payload\deadcells.xdelta` and checks
    that the result is exactly `5514FD67…6E39`. If anything doesn't match, nothing is changed.
  - **Already patched**: it says so and stops. An older trainer build is upgraded (it restores the backup first).
  - **Another game version**: it rebuilds the patch from *your* game's own code with
    `source\patch_any_version.py`. This needs Python 3.8 or newer (python.org), no extra modules. It stops
    without changing anything if the game code it looks for was renamed in that version.
- Applies the **quit fix** to `libhl.dll` (original kept as `libhl.dll.trainer-backup`), see below.

## Quit fix (game froze when quitting)

On some PCs Dead Cells freezes forever after "Quit game" (or closing the window), and Task Manager can't
end it. **This also happens with the unmodified game**; the trainer doesn't cause it. What happens:

1. The game saves, shuts down Epic services, then calls the C runtime `exit()` (in `libhl.dll`).
2. `exit()` unloads all DLLs. The Epic launcher's overlay DLL (`EOSOVH-Win64-Shipping.dll`) frees its
   Direct3D 11 objects while unloading, and the Intel GPU driver (`igd10um64xe.dll`) waits for its own
   worker threads, which Windows already stopped. That wait never ends, so one thread spins at 100% CPU.

The installer changes 12 bytes in `libhl.dll`, so the game's final `exit()` becomes `TerminateProcess`:
the process ends right after the game has finished saving and cleaning up, and the broken DLL unloading
is skipped. Measured with the Epic launcher: before, the game was still hung 30 s after the close request;
after, it closes in about 2 s.

If a game is already stuck: `source\finish_exit.py <PID>` (Python) ends it by sending its last thread to
the normal "end process" call. Restarting Windows also clears it.

## Uninstall

Close the game and double-click **`Uninstall.bat`**. It puts `deadcells.exe.trainer-backup` and
`libhl.dll.trainer-backup` back (so the game's own hang-on-quit can return). You can also use
**Epic Games launcher → Dead Cells → ⋯ → Manage → Verify**, which downloads the original files again. Your
`save-backup-*` folders are left in place; delete them yourself when you no longer need them.

## Test status

- Checked: the patched bytecode parses, every patched function was disassembled and reviewed, the game
  loads it and reaches the title screen through the Epic launcher, and `Install.bat` / `Uninstall.bat`
  were tested on a copy of the game files (install → already-installed → uninstall restores the original
  hashes). Quitting from the title screen through the Epic launcher was tested before/after the quit fix.
- Not yet checked in a run: the effect of each F-key during gameplay, and how the menu looks in game
  (position over other HUD elements, text size). If a key misbehaves, press it again to switch it off, or
  run `Uninstall.bat`.

## Good to know

- **Game updates** replace `deadcells.exe` (and maybe `libhl.dll`) and remove the trainer and the quit fix.
  Run `Install.bat` again after an update. The new build will have a different hash, so the installer uses
  the Python rebuild path.
- **Epic "Verify"** also removes the trainer and the quit fix.
- Run the game **through the Epic launcher**. Starting `deadcells.exe` directly makes the game quit with
  "Epic init failed" (that also happens without the trainer).
- Cheats are not saved. Gold, cells and items you get while they are ON are saved like normal progress,
  so back up your save first if you want to keep a clean profile (the installer already makes one copy).
- Single-player only. Don't use it in anything online or competitive.

## How it works (for the curious)

Dead Cells runs on HashLink. Its game code is HashLink bytecode stored inside `deadcells.exe` as the
resource `RCDATA / HLBOOT.DAT`. The patch rewrites that bytecode:

- A new function runs at the start of `pr.Game.update` every frame. It reads the F-keys with
  `hxd.Key.isPressed`, flips the toggles (new global booleans), shows the messages through
  `ui.LogManager.text`, and runs the per-frame parts (health refill, gold/cell floor, map reveal through
  `en.Hero.triggerExplorerInstinct` + `ui.hud.MiniMap.revealAll`).
- The same function builds the menu once per HUD: an `h2d.Flow` (vertical, padding, 60% black
  background from `h2d.Tile.fromColor`) added to the HUD's root layer at 6 × HUD pixel scale from the top-left,
  holding one `ui.Text` per line made with the game's `Assets.makeText`. Each frame it sets the panel's
  visibility (F12) and each toggle line's colour.
- Short "if toggle is on, return early" checks are added at the top of these game functions:
  `en.Hero.canReceiveAttack`, `en.Hero.kill` (F1); `en.Hero.substractMoney`, `en.Hero.substractCells` (F3);
  `tool.mainSkills.AirJump.canUse` resets the air-jump counter (F4);
  `tool.hero.HeroActiveSkillsManager.getRunSpeedMul` returns +1.0 (F5);
  `tool.hero.HeroActiveSkill.startCooldown`, `tool.Weapon.consumeAmmo`,
  `tool.weap.dual.OffHandRanged.consumeAmmo`, `tool.mainSkills.Heal.set_healings` (F7).
- F2 calls the game's own `addMoney` / `addCells` (the same calls as the developers' debug console
  command `gold`), so the HUD and the save stay consistent.

`source\` holds the tools that build the patch: `hlcode.py` (HashLink bytecode reader/writer; a
read→write round trip is byte-identical), `hlasm.py` (small assembler, inserts code and fixes jump
offsets), `build_patch.py` (the trainer itself, finds everything by class/method/field name and aborts if
a signature changed), `exeres.py` (reads/replaces the exe resource with Win32 calls), `hlinspect.py`
(disassembler used for the analysis).

## Files

| File | Purpose |
|------|---------|
| `Install.bat` / `install.ps1` | Install (backs up saves and the exe first) |
| `Uninstall.bat` / `uninstall.ps1` | Restore the original exe |
| `payload\deadcells.xdelta` | Binary diff original exe → trainer exe (about 2.5 KB) |
| `payload\xdelta3.exe` | xdelta 3.2.2 decoder (Apache-2.0, see `payload\xdelta3-README.md`) |
| `source\*.py` | Patch builder for other game versions (Python 3.8+), `patch_libhl.py` (quit fix), `finish_exit.py` / `sample_threads.py` (unstick / inspect a hung game) |
| `SHA256SUMS.txt` | Checksums of every file in this package |
