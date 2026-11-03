# Death's Gambit Afterlife — In-Game Trainer v4 (Portable Patch)

One-file patch that unlocks an in-game trainer for the **Epic Games build** of
Death's Gambit Afterlife. No tools to install, no account needed: this folder
contains the patch, the patch applier, and install/uninstall scripts.

## What's in this folder

| File | Purpose |
| ---- | ------- |
| `dg_trainer_v4.xdelta` | The patch itself (~1 MB, vanilla → trainer v4) |
| `xdelta3.exe` | Patch applier (official xdelta 3.2.2, https://github.com/jmacd/xdelta) |
| `Apply-Patch.ps1` | Installer: backs up, patches, verifies |
| `Revert-Patch.ps1` | Uninstaller: restores the vanilla backup |
| `trainer_v4.csx` | Human-readable source of the trainer logic (for rebuilds) |
| `README.md` | This file |

## Requirements

- Windows PC with the Epic Games version of Death's Gambit Afterlife installed.
- The same game version this patch was built from. The installer checks your
  `data.win` automatically and will refuse to patch a different build.
- About 1 GB free disk space during install (488 MB vanilla backup + temp file).
- The game must be **closed** while patching.

## Install (on the other computer)

1. Copy this whole folder to the other computer (USB stick, network share, etc.).
2. Make sure the game is closed.
3. Double-click `Apply-Patch.ps1` — if Windows shows only an editor, instead
   right-click it → **Run with PowerShell**. If Windows blocks the script, either:
   - right-click the file → Properties → check **Unblock** → OK, or
   - open PowerShell in this folder and run:
     `powershell -ExecutionPolicy Bypass -File .\Apply-Patch.ps1`
4. If your game folder isn't found automatically, paste its full path when asked
   (the folder containing `data.win`, e.g. `E:\EpicGames\DeathsGambitAfterlifMUr7y`).
5. Wait for "Done. Trainer v4 installed." Your original file is kept untouched as
   `data.win.VANILLA` inside the game folder.
6. Launch the game and use the keys below.

## Controls (in-game, no menu needed)

| Key | Effect | Default |
| --- | ------ | ------- |
| F1 | God Mode + infinite healing feathers | ON |
| F2 | Infinite Endurance + Soul Energy + ammo | ON |
| F3 | Essence pickup bonus (+999 per pickup) | ON |
| F4 | Unlimited jump | ON |
| F5 | One-hit kill | **OFF** — press to enable |
| G  | +99999 ultra essence + save (always available) | — |

Notes:
- Toggle messages ("Trainer: God 0/1" …) appear in the game's debug log.
- F5 defaults to OFF on purpose: merchants and quest NPCs share the enemy
  data, so only switch it on for fights.
- Healing values stay within the game's own caps, so the built-in
  anti-tamper check is never tripped.

## Uninstall

Run `Revert-Patch.ps1` (restores your `data.win.VANILLA` backup), or use
Epic Games → Library → Death's Gambit → ⋯ → **Verify**. Your saves are in
`%LocalAppData%\deathsgambit397` and are never touched by either script.

## Troubleshooting

| Problem | Fix |
| ------- | --- |
| "Game is running" | Close the game completely (check Task Manager), re-run the script. |
| "does not match the expected vanilla build" | Your game is a different version/update. Don't force it — ask for a fresh patch built from your version. |
| "Patched file verification FAILED" | Nothing was modified. Re-run; if it persists, Verify via Epic and retry. |
| Windows SmartScreen / antivirus flag on `xdelta3.exe` | It is the unmodified official binary. Allow it, or build from source at the link above. |
| Script won't run ("execution of scripts is disabled") | Use the `-ExecutionPolicy Bypass` command from step 3. |
| Trainer gone after a game update | Updates overwrite `data.win`. Just re-run `Apply-Patch.ps1` (it reuses the backup). |

## FAQ

- **Will I lose my saves?** No. Saves live outside `data.win` and neither script touches them.
- **Can I get banned?** This is an offline single-player game with no anti-cheat
  service; the patch only affects your local files.
- **Can I share this folder?** Yes — but never include anyone's `data.win`,
  save files, or game assets. This folder contains only the diff, the open-source
  patch tool, and scripts.
- **How was this made?** Game logic was decompiled with UndertaleModTool,
  trainer hooks were added to the per-tick globals handler, and the result is
  distributed as an xdelta diff. See `trainer_v4.csx` for the exact changes.

## Version info

- Trainer v4, built from vanilla `data.win` SHA256
  `C924BC2A7B98B65CF1C376750C39256974E969508194AFF32D85CA4243DC661C`
- Patched `data.win` SHA256
  `EBC3582E4C28868AA73E181BCDC313E65A3485A835D94672018DF3494F5C1530`
- The installer verifies both hashes automatically.
