# Gunslugs Trainer Patch (v1.0)

An in-game trainer and borderless-fullscreen stability patch for **Gunslugs** (GOG / Packr Windows build by OrangePixel).

---

## Features & In-Game Hotkeys

Press **F1–F8** at any time during gameplay to toggle or trigger cheats, and **F9** (or **F10** / **INSERT**) to show or hide the on-screen trainer menu:

| Hotkey | Feature | Description |
| :--- | :--- | :--- |
| **F1** | **God Mode** | Freezes HP & Armor at max (`200`), blocks damage and `die()`/`initDie()`, prevents continue countdown loss, and grants a protective shield. |
| **F2** | **Add +500 Coins** | Immediately adds `+500` coins to your active player and persistent profile (`PlayerProfile.coins`), plus `+1` Continue (`continuesLeft`). |
| **F3** | **Unlimited Money & Items** | Keeps coins (`>= 9999`), ammo (`maxAmmo`), continues (`>= 9`), and active tactical items (`myItems[]`: Flak Jacket, Jetpack, Skull/Double Damage, Lucky Clover) topped up every frame, and makes shop purchases free. |
| **F4** | **Unlimited Jump (Jetpack)** | Enables infinite mid-air jumps and unlimited continuous Jetpack boost fuel (`jetPackFuel = 16`, `hasJetPack = true`). |
| **F5** | **Move Speed x2** | Doubles horizontal movement acceleration/velocity (`xSpeed` cap `32 -> 64`) while preserving precise platforming control. |
| **F6** | **Show All Items on Map (ESP)** | Draws color-coded bounding boxes and labels (`COIN`, `AMMO`, `MEDKIT`, `ARMOR`, `PICKUP`, `SHOP`, `MISSION`, `LOCKED`, `BEACON`, `EXIT`) over all active pickups, crates, and objectives, plus off-screen directional indicators and a full-level top radar bar showing every item and objective across the entire map. |
| **F7** | **One-Hit Kill (Enemies & Bosses)** | Eliminates any active enemy or boss as soon as it takes a single point of damage (or is touched by your bullets/explosions), including automatic phase progression for the multi-part Final Boss. |
| **F8** | **Cycle Weapon (1–9)** | Cycles through all 9 player weapons (`PISTOL`, `DUAL GUN`, `SHOTGUN`, `FLAMER`, `GRENADE`, `PLASMA`, `ELECTRIC`, `SKULLFM`, `CHICKEN`) and refills ammo. |
| **F9** / **F10** / **INS** | **Toggle Trainer Menu** | Shows or hides the compact top-left trainer overlay (`[F9] GUNSLUGS TRAINER`). Toast notifications and Map ESP remain active even when the menu is collapsed. |

### Included Engine Fix: Windows 10/11 Fullscreen Crash Fix
Vanilla Gunslugs uses LWJGL 2 exclusive fullscreen (`9999x9999`), which crashes on modern Windows 10/11 GPUs with `java.lang.IllegalStateException: Mouse is not created` / `No OpenGL context found in the current thread` when Fullscreen is selected in Options. This patch transparently upgrades Fullscreen mode to borderless fullscreen window mode so it never crashes.

---

## How It Works (Non-Destructive Classpath Injection)

Gunslugs uses the **Packr** native launcher (`gunslugs.exe`), which reads `config.json` on startup and constructs a Java `URLClassLoader` from the `classPath` array in order:

```json
{
   "platform": "windows",
   "jdk": "jre",
   "executable": "gunslugs",
   "appjar": "gunslugs.dat",
   "classpath": [
      "gunslugs-trainer.jar",
      "gunslugs.dat"
   ],
   "mainClass": "com/orangepixel/gunslugs/Main",
   "vmArgs": [
      "-Xmx1G"
   ]
}
```

By placing `gunslugs-trainer.jar` ahead of `gunslugs.dat` in `config.json`:
1. **`gunslugs.exe` and `gunslugs.dat` remain 100% unmodified** (their original SHA-256 hashes are untouched).
2. The JVM loads our patched `com.orangepixel.gunslugs.Player`, `com.orangepixel.utils.ArcadeCanvas`, and new `com.orangepixel.gunslugs.Trainer` classes from `gunslugs-trainer.jar`, while all other classes and game assets load normally from `gunslugs.dat`.

---

## Installation (Any Windows PC)

### Option A: One-Click Batch Installer
1. Extract `Gunslugs-Trainer-v1.zip` anywhere on your PC (or directly inside your `Gunslugs` game folder).
2. Double-click **`Install.bat`**.
   - If the folder is inside `Gunslugs` or your game is installed in `E:\GOGGalaxy\Gunslugs`, `C:\GOG Games\Gunslugs`, `D:\GOG Games\Gunslugs`, or `C:\Program Files (x86)\GOG Galaxy\Games\Gunslugs`, it will auto-detect the game directory.
   - Otherwise, a folder picker dialog will prompt you to select your `Gunslugs` installation folder.

### Option B: PowerShell CLI
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GameDir "D:\Games\Gunslugs"
```

### Option C: Manual Installation (No Scripts Needed)
1. Copy `payload\gunslugs-trainer.jar` into your `Gunslugs` folder (next to `gunslugs.exe` and `gunslugs.dat`).
2. Back up `config.json` to `config.json.orig`.
3. Copy `payload\config.json` into your `Gunslugs` folder (replacing `config.json`).

---

## Uninstallation

Double-click **`Uninstall.bat`** (or run `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -GameDir "D:\Games\Gunslugs"`).

This removes `gunslugs-trainer.jar` and restores `config.json` from `config.json.orig`, returning your game installation to its exact factory state.

---

## Automated Self-Test Mode

To run a non-interactive verification test of all 8 trainer features (creates `trainer_selftest_report.json` and `trainer_selftest_screenshot.png` in the game directory and exits automatically):

```powershell
$env:TRAINER_SELFTEST = "1"
Start-Process -FilePath "E:\GOGGalaxy\Gunslugs\gunslugs.exe" -WorkingDirectory "E:\GOGGalaxy\Gunslugs" -Wait
Remove-Item Env:\TRAINER_SELFTEST
Get-Content "E:\GOGGalaxy\Gunslugs\trainer_selftest_report.json"
```

---

## Rebuilding from Source

Full Java source code for the trainer and patched classes is included in `source/`:
- `source/com/orangepixel/gunslugs/Trainer.java` — Trainer state machine, hotkeys, HUD menu, item/objective ESP overlay, and automated self-test runner.
- `source/com/orangepixel/gunslugs/Player.java` — Hooks in `Player.update()`, `Player.die()`, and `Player.initDie()`.
- `source/com/orangepixel/utils/ArcadeCanvas.java` — Hook in `ArcadeCanvas.render()` (inside the low-res pixel-art `FrameBuffer`) and LWJGL 2 fullscreen stability fix.

To recompile `payload/gunslugs-trainer.jar` using any JDK (Java 8+):
```powershell
powershell -ExecutionPolicy Bypass -File .\source\build.ps1 -GameDir "E:\GOGGalaxy\Gunslugs"
```
