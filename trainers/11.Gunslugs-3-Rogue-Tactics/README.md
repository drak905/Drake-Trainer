# Gunslugs 3: Rogue Tactics — In-Game Trainer & Portable Patch (v1.0)

A non-destructive, zero-binary-modification in-game trainer and portable patch for **Gunslugs 3: Rogue Tactics** (`v1.0.10b`, LibGDX / Packr desktop build).

- **Original `gunslugs3.exe` and `gunslugs3.dat` are 100% untouched** (`gunslugs3.dat` SHA256: `8E9F0784C8824119AC5572BAA09E9D93E317FFD0A6AD3F1DE1BE4A76E61BEBDF`).
- Uses Packr's native `config.json` `"classPath"` priority (`["gunslugs3-trainer.jar", "gunslugs3.dat"]`) so the JVM loads the patched classes (`Trainer`, `PlayerEntity`, `myCanvas`, `ArcadeCanvas`) ahead of the unmodified archive.

---

## Features & In-Game Hotkeys

| Hotkey | Feature | Type | Description |
| :--- | :--- | :--- | :--- |
| **`F1`** | **God Mode** | Toggle (`ON`/`OFF`) | Infinite lives/HP (`lives >= maxLives`), blocks all incoming damage (`PlayerEntity.hitMe`), blocks death (`PlayerEntity.die`), keeps shield & helmet durability topped up, prevents pit-fall death (`y > 2128`), and clears security alarms. |
| **`F2`** | **Add Money & Resources** | Instant Action | Adds **`+500` Coins** (`World.coins`), **`+1` Skill Point** (`skillPoints` + `mySaveGame.charXPPoints`), **`+200` XP**, restores **Full HP**, and unlocks/revives all **8 playable heroes** (`charUnlocked[0..7] = true`, `charDied[0..7] = false`). |
| **`F3`** | **Unlimited Money & Items** | Toggle (`ON`/`OFF`) | Locks Coins at **`>= 9999`**, Skill Points at **`>= 10`**, keeps all 3 ammo pools (`Bullets`, `Explosives`, `Energy`) full, makes all inventory items non-depleting (`itemUsageCount = 9`), stocks essential mission items (`Keycard`, `Jetpack`, `EMP`, `Wrench`, `Battery`, `Cross`, `Bombs`), and makes all **Shop items & Vending Machines cost `$0`**. |
| **`F4`** | **Unlimited Jump** | Toggle (`ON`/`OFF`) | Grants infinite mid-air jumps (`hasDoubleJump = true`, `DoubleJumpCountDown = 99` every frame in `PlayerEntity.update`). |
| **`F5`** | **Character Move Speed x2** | Toggle (`ON`/`OFF`) | Doubles horizontal movement speed cap (`maxSpeed <<= 1`) and doubles horizontal acceleration step (`4 -> 8`) in `PlayerEntity.update`. |
| **`F6`** | **Show All Items on Map (ESP)** | Toggle (`ON`/`OFF`) | Draws color-coded bounding boxes, labels, off-screen directional indicators (`<` / `>`), and a **full-level top radar bar** showing coins, loot crates, pickups, weapons, shops, vending machines, doors, consoles, hack PCs, C4 spots, hostages, rockets, radar towers, extraction choppers, enemies, and bosses across the entire map. |
| **`F7`** | **One-Hit Kill** | Toggle (`ON`/`OFF`) | Boosts player projectile damage (`BulletEntity.energy = 250`) and clamps all active hostile `MonsterEntity` and `BossEntity` health to `1` so enemies and bosses die in a single hit while preserving full XP, coin drops, and mission completion triggers. |
| **`F8`** | **Cycle Weapon** | Instant Action | Cycles through all **19 weapons** (`0..18` in `Globals.weapons` — Pistol, Doubler, Spreader, Flamethrower, Grenade Launcher, Bazooka, Plasma Gun, Jetpack Gun, Skull Flamethrower, Shotguns, Claw, Chicken Gun, Dual Gun, Energy Gun, Rock Guitar, etc.) and refills all ammo. |
| **`F9` / `F10` / `INSERT`** | **Trainer Menu Overlay** | Toggle (`SHOW`/`HIDE`) | Shows or hides the top-right translucent in-game Trainer HUD panel. |

---

## How to Install on Any Computer (Portable Patch)

### Option A: One-Click Installer (Recommended)
1. Copy the **`Gunslugs3-Trainer-v1`** folder (or extract **`Gunslugs3-Trainer-v1.zip`**) to any location on the target PC.
2. Double-click **`Install.bat`**.
   - If the game is installed in a standard path (or if you extracted the patch inside the game folder), the installer detects it automatically.
   - Otherwise, paste your **Gunslugs 3: Rogue Tactics** folder path when prompted (the folder containing `gunslugs3.exe` and `gunslugs3.dat`).
3. Launch `gunslugs3.exe` normally! The **`GUNSLUGS 3 TRAINER [F9]`** menu will appear in the top-right corner.

### Option B: Command-Line PowerShell Install
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GameDir "E:\GOGGalaxy\Gunslugs3RogueTactics"
```

### Option C: Manual Copy (2 Files)
1. Back up `config.json` in your game directory to `config.json.orig`.
2. Copy `payload\gunslugs3-trainer.jar` and `payload\config.json` into your game directory (next to `gunslugs3.exe` and `gunslugs3.dat`).

---

## How to Uninstall

- Double-click **`Uninstall.bat`** (or run `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -GameDir "<path>"`).
- The uninstaller restores your original `config.json` from `config.json.orig` and removes `gunslugs3-trainer.jar`, returning the game to 100% factory state.

---

## Rebuilding from Source

Full Java source code for the trainer and modified hooks is included under `source/`:
- `source/src/com/orangepixel/gunslugs3/Trainer.java` — Core trainer state machine, F1–F10/INSERT hotkeys, ESP overlay & radar renderer, and self-test harness.
- `source/src/com/orangepixel/gunslugs3/ai/PlayerEntity.java` — Hooks for God Mode (`hitMe`, `die`, `update`), Move Speed x2 (`update`), Unlimited Jump (`update`), and Unlimited Items (`deleteInventoryItem`, `useInventoryItem`).
- `source/src/com/orangepixel/gunslugs3/myCanvas.java` — Hooks for per-frame logic (`LogicLoop`, `GameLoop`) and HUD/ESP overlay rendering (`renderStatusbar`).
- `source/src/com/orangepixel/utils/ArcadeCanvas.java` — Safe `try/catch` guard around `setDisplayMode`.

To recompile `gunslugs3-trainer.jar` (requires JDK 8+):
```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```
