# Gunslugs 2 — In-Game Trainer & Portable Patch (v1.0)

A non-destructive, portable in-game trainer and map ESP overlay for **Gunslugs 2** (GOG / PC LibGDX build by OrangePixel).

---

## 1. Features & Hotkeys

Once in the game, an interactive **GUNSLUGS 2 TRAINER** menu appears in the top-right corner of the screen. Toggle any feature at any time using the function keys:

| Hotkey | Feature | Description |
| :--- | :--- | :--- |
| **F1** | **God Mode** | Infinite HP (`lives = 32`), full Adrenaline (`extraLife = 16`), permanent Heavy Shield (`armorCounter = 96`), player-mounted vehicle fuel lock (`800`), bottomless pit rescue, and blocks all `Player.hit()`, `Player.die()`, `Player.initDie()`, and `Player.initFakeDie()` damage/death routines. |
| **F2** | **+500 Coins** | Immediately adds **+500 coins** to your current run and persists the gain to `PlayerProfile`. |
| **F3** | **Unlimited Money & Items** | Locks coins at **>= 9999**, unlocks **Ammo Extender (`128`)**, refills weapon ammo to maximum every frame, grants **Voodoo Continue Doll (`hasContinue`)** & **Special Drink (`hasSpecialDrink`)**, maintains **Shield (`96`)** & **Adrenaline (`16`)**, and unlocks **all playable Heroes/Avatars and Weapons** in `PlayerProfile`. |
| **F4** | **Unlimited Jump** | Allows infinite mid-air jumps and continuous flight by resetting jump/grounded state while holding Jump (`UP` / `W` / `X` / `L` / gamepad jump). |
| **F5** | **Move Speed x2** | Doubles horizontal movement speed cap (`maxSpeed = 80` vs default `40`) and doubles horizontal acceleration. |
| **F6** | **Show All Items on Map (ESP)** | Draws color-coded bounding boxes and crisp bitmap labels around all items and objectives (**Coins**, **Ammo**, **Medkits**, **Shields**, **Weapons**, **Items**, **Crates**, **Doors**, **Signal Towers**, **Switches**, **Shops**, **Hero Cages**, **Beacons**, **Vehicles**, **Exits**), displays off-screen directional edge indicators (`<` / `>`) for objectives, draws a **top-center full-level radar bar**, and prevents spawned coins/pickups from despawning. |
| **F7** | **One-Hit Kill** | Sets all active hostile enemy, turret, destructible crate, and boss (`mBOSS1..mBOSS7`) health to `1 HP` for instant kills while preserving shop item coin prices and player-mounted vehicle fuel. |
| **F8** | **Cycle Weapon** | Cycles through all primary and special weapons (`Pistol`, `Dual Gun`, `Shotgun`, `Flamethrower`, `Grenade Launcher`, `Plasma Gun`, `Electro Gun`, `Skull Gun`, `Chickens`, `Jetpack`) and refills ammunition. |
| **F9** *(or F10 / INSERT)* | **Hide / Show Menu** | Toggles visibility of the top-right trainer menu overlay. |

---

## 2. How to Install (Any PC)

The portable patch does **not** modify `Gunslugs2.exe` or `Gunslugs2.jar`. Instead, it uses the Packr launcher configuration (`app\Gunslugs2.json`) to prepend `gunslugs2-trainer.jar` to the JVM classpath.

### Option A — One-Click Installer (Recommended)
1. Extract `Gunslugs2-Trainer-v1.zip` anywhere on your computer.
2. Double-click **`Install.bat`**.
   - The installer automatically locates your **Gunslugs 2** installation via the GOG registry (`1679659438`) or common GOG/Steam folders.
   - If your game is in a custom folder, paste the folder path containing `Gunslugs2.exe` and `Gunslugs2.jar` when prompted.

### Option B — PowerShell Command Line
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GameDir "E:\GOGGalaxy\Gunslugs2"
```

To also run the automated 4-gate zero-touch self-test right after installing:
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -GameDir "E:\GOGGalaxy\Gunslugs2" -SelfTest
```

### Option C — Manual Installation
1. Copy `payload\gunslugs2-trainer.jar` into your `Gunslugs2` folder (next to `Gunslugs2.exe` and `Gunslugs2.jar`).
2. Back up `app\Gunslugs2.json` to `app\Gunslugs2.json.orig`.
3. Copy `payload\Gunslugs2.json` to `app\Gunslugs2.json`.

---

## 3. How to Uninstall

- Double-click **`Uninstall.bat`** (or run `.\uninstall.ps1 -GameDir "<path>"`).
- This restores `app\Gunslugs2.json.orig` back to `app\Gunslugs2.json` and removes `gunslugs2-trainer.jar`, returning your game directory to a 100% unmodified state.

---

## 4. Rebuilding from Source

Full Java source code is included in the `source\` folder:
- `source\com\orangepixel\gunslugs2\Trainer.java` — Core trainer state machine, F-key edge detector, world entity scanner, ESP/radar renderer, and automated self-test harness.
- `source\com\orangepixel\gunslugs2\Player.java` — Classpath shadow of `Player` with hooks for `update()`, `hit()`, `die()`, `initDie()`, `initFakeDie()`, and `addCoin()`.
- `source\com\orangepixel\utils\ArcadeCanvas.java` — Classpath shadow of `ArcadeCanvas` dispatching per-frame key polling and rendering hooks.

To recompile `payload\gunslugs2-trainer.jar` (requires JDK 8+):
```powershell
powershell -ExecutionPolicy Bypass -File .\source\build.ps1 -GameDir "E:\GOGGalaxy\Gunslugs2"
```

---

## 5. File Integrity (SHA-256)

| File | SHA-256 |
| :--- | :--- |
| `payload\gunslugs2-trainer.jar` | `6f6fc0aed743f7dacf84bcc8d9ec6f50c99652086fe1ab668958b96908d6e5f2` |
| `Gunslugs2.jar` *(Original unmodified game archive)* | `8f92f9ea2f84b055be744f98b911dbcdc6f8199bd1ec75b54338bff3ffffa913` |
| `Gunslugs2.exe` *(Original unmodified launcher)* | `eeae2de59d6b5c3a4c6f79f643b27aaa163ecd3b11f431a9e39460d872aa0b29` |
