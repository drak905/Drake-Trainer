# Bō: Path of the Teal Lotus — Offline Trainer v1.1.0

A portable, in-game trainer for the **single-player PC build** of *Bō: Path of the Teal Lotus*
(Unity 2022.3, Mono, 64-bit). It adds toggles on the F-keys plus a small on-screen overlay.
No game file is modified — the trainer is a plugin loaded by [BepInEx 5](https://github.com/BepInEx/BepInEx)
(version 5.4.23.3 is bundled), and removing it restores the game exactly.

> Offline / single-player use only. Nothing here touches online services, DRM or anti-cheat.

## Features and hotkeys

| Key | Feature | What it does |
|-----|---------|--------------|
| **F1** | God Mode | No damage from enemies or projectiles, and traps are harmless: you can stand in spikes, lasers, fire, white ice crystals and instant-kill hazards without dying or being sent back. Pits and kill zones do nothing either: you keep falling freely (to the bottom of the map) with no respawn, death animation or HP loss. |
| **F3** | Add Money | Adds **+10,000** fox flames (Kitsunebi) each press. |
| **F4** | Infinite Money | Keeps your fox flames at 99,999 whenever you spend them. |
| **F5** | Unlimited Jump | Unlimited mid-air jumps. |
| **F6** | Speed ×2 | Doubles run speed (and glide speed). |
| **F7** | One-Hit Kill | Every staff / Daruma / bat hit deals 9,999 damage to enemies and bosses. |
| **F8** | Infinite Tea | Healing and Daruma cost no tea (uses the game's own "infinite mana" flag). |
| **F9** | Full Heal | Restores health and tea once. |
| **F10** | Infinite Items | Keeps the 8 crafting/shop resources (bamboo, teal ore, vermillion crystal, crystal mum petal, spider silk, pungent root, lotus seeds, awakening ink) at 99 whenever you spend them. |
| **F11** | Add Items | Adds +99 of each of those resources per press (max 999). |
| **F2** | Collectibles on map | Toggles **every collectible / quest item** on the map (chests, omamori, bamboo, teal ore, spider silk, pungent root, crystal petals, vermillion crystals, lotus seeds, bunny blossoms - 80 markers). Items you already took stay visible but grey and faint. Works with or without the Intuition omamori. |
| **F12** | Overlay | Show / hide the on-screen key list. |
| **Home** | Return to safe ground | Puts you back on the last solid ground you stood on (use it if you fell out of the world or into a spot you cannot climb out of). Falls back to the last checkpoint if no safe ground is recorded. |

Each toggle is independent; the overlay shows ON/OFF.

## Requirements

* Windows 10/11 x64 with PowerShell 5.1+ (included in Windows).
* The PC build of the game that contains `Bo.exe`, `Bo_Data\` and `MonoBleedingEdge\`
  (tested: GOG build `59597633621004325`; other builds of the same Unity-Mono version should work because hooks are by method name, but only the GOG build was tested).

## Install (on any computer)

1. Copy and unzip this folder anywhere (for example your Desktop).
2. **Close the game.**
3. Double-click **`Install.bat`**.
   * It looks for the game automatically (GOG registry, Steam libraries, common game folders on every drive).
   * If it cannot find it, it asks you to paste the folder that contains `Bo.exe`.
   * You can also run: `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\Bo Path of the Teal Lotus"`
4. Start the game normally (GOG Galaxy or `Bo.exe`). The overlay is shown at the top-left; press the hotkeys while playing.

Installing is safe to repeat. The installer copies 16 files into the game folder (`winhttp.dll`, `doorstop_config.ini`,
`.doorstop_version`, `BepInEx\core\*.dll`, `BepInEx\plugins\BoTrainer.dll`) and writes a list of them to
`BoTrainer_install_manifest.txt`.


## Kodama map and collectible map (new in 1.1.0)

* **Kodama tracker (always on).** Open the map (Tab): all **34 Kodama** are marked, whether or not you wear the Intuition omamori.
  **Bright green, enlarged** = still waiting to be picked. **Grey, small and faint** = already taken. When you pick one, its marker fades
  at once - no menu, no reload. The overlay shows `Kodama on map: 25/34 taken`. (The 12 *Kodama Mimic* enemies are not on the map.)
* **F2 - collectible map.** Adds the other collectibles with the same taken / not-taken look. Colours of the waiting ones:
  gold = chest, pink = omamori, lime = bamboo, blue = teal ore, white = spider silk, orange = pungent root, rose = crystal petal,
  red = vermillion crystal, cyan = lotus seed; bunny blossoms keep their own icon. Press F2 again to return to the game's own map.
* Icons only appear at the closer zoom levels of the map (the full-world view shows area art only). Zoom in with **Z** if you do not see them.
* "Taken" is read from the game's own save data (the cleared-icon list that is stored in your save), so it is exact and survives reloads.
* Positions come from the game's own pre-placed map icons, cross-checked against all 105 scenes: the 34 Kodama in the table below all
  have a matching icon within 5 world units. Settings: `[Map] ShowKodamas` (default true), `CollectibleMapAtStart` (false), `TakenIconOpacity` (0.30)
  and `[Hotkeys] ToggleCollectibleMap` (F2).
* F2 is the game's unused beta "bug report" key; the trainer also blocks that action so it can never open a browser.

### All 34 Kodama
| # | Area | Scene | World position (x, y) | Map icon |
|--:|------|-------|-----------------------|----------|
| 1 | Bamboo Forest | CBF Intro | 975, 69 | `CBFIntro_MapIcon_Kodama` |
| 2 | Bamboo Forest | CBF Bump Intro | 1369, 129 | `CBFBumpIntro_MapIcon_Kodama01` |
| 3 | Bamboo Forest | CBF Bump Intro | 1540, 64 | `CBFBumpIntro_MapIcon_Kodama02` |
| 4 | Bamboo Forest | CBF Bump Intro | 1693, 69 | `CBFBumpIntro_MapIcon_Kodama03` |
| 5 | Bamboo Forest | CBF Cave Entrance | 1748, -144 | `CBFCaveEntrance_MapIcon_Kodama01` |
| 6 | Uzumaki Cave | UC Entrance | 2335, -190 | `UC Entrance_MapIcon_Kodama` |
| 7 | Uzumaki Cave | UC Entrance | 2392, -240 | `UC Entrance_MapIcon_Kodama (1)` |
| 8 | Uzumaki Cave | UC Amaterasu | 2482, -483 | `UC Amateratsu_MapIcon_Kodama` |
| 9 | Uzumaki Cave | UC Arena Puzzle | 2999, -535 | `UC Arena_MapIcon_Kodama01` |
| 10 | Uzumaki Cave | UC Main Chamber | 3284, -747 | `UCMainChamber_MapIcon_Secret_Kodama` |
| 11 | SakuraCity | SACIWalls | 3593, -8 | `SACIWalls_MapIcon_Kodama` |
| 12 | SakuraCity | SACITier1 | 3665, 379 | `SACITIer1_MapIcon_Kodama` |
| 13 | Midori Forest | MF Asahi | 5055, 1319 | `MFAsahi_MapIcon_Kodama` |
| 14 | Midori Forest | MF Treetops | 5072, 1684 | `MFTreetops_MapIcon_Kodama01` |
| 15 | Midori Forest | MF Arena | 5327, 1444 | `MFArena_MapIcon_Kodama01` |
| 16 | Midori Forest | MF Treetops | 5351, 1682 | `MFTreetops_MapIcon_Kodama` |
| 17 | Midori Forest | MF Maze | 5684, 1309 | `MFMaze_MapIcon_Kodama` |
| 18 | Midori Forest | MF Shrine Ceremony | 5984, 1655 | `MFShrine_MapIcon_Secret_Kodama_01` |
| 19 | Kitsune Burrows | KB West | 5418, 707 | `KBWest_MapIcon_Secret_Kodama_01` |
| 20 | Kitsune Burrows | KB West | 5496, 879 | `KBWest_MapIcon_Secret_Kodama_02` |
| 21 | Kitsune Burrows | KB Entrance | 5837, 923 | `KBEntrance_MapIcon_Kodama01` |
| 22 | Kitsune Burrows | KB Entrance | 5889, 874 | `KBEntrance_MapIcon_Kodama` |
| 23 | Kitsune Burrows | KB Entrance | 6168, 971 | `KBEntrance_MapIcon_Kodama_Mean` |
| 24 | Kitsune Burrows | KB South | 6226, 487 | `KBSouth_MapIcon_Kodama` |
| 25 | Kitsune Burrows | KB Mochi Bug Nest | 6598, 775 | `KBMochiBugNest_MapIcon_Kodama` |
| 26 | Ice Caverns | IC West | 1279, 338 | `ICWest_MapIcon_Secret_Kodama_` |
| 27 | Ice Caverns | IC East Redesign | 2133, 909 | `ICEast_MapIcon_Secret_Kodama_01` |
| 28 | Ice Caverns | IC East Redesign | 2271, 1160 | `ICEast_MapIcon_Secret_Kodama_02` |
| 29 | Ice Caverns | IC Volcano | 2849, 899 | `ICVolcano_MapIcon_Secret_Kodama_01` |
| 30 | Megumi Mountain | MM Gunbai | 1622, 1998 | `MMGunbai_MapIcon_Secret_Kodama_01` |
| 31 | Megumi Mountain | MM TK Training Grounds Boss Rush Building Exterior kabuki theater | 2034, 1999 | `MM Training Grounds_Secret_Kodama` |
| 32 | Megumi Mountain | MM Main Ascent | 2362, 1824 | `MMMainAscent_MapIcon_Secret_Kodama_01` |
| 33 | Megumi Mountain | MM Vista | 2970, 1686 | `MMVista_MapIcon_Secret_Kodama_01` |
| 34 | Megumi Mountain | MM Base | 3156, 1410 | `MMBase_MapIcon_Kodama` |

## Uninstall / revert

Close the game and double-click **`Uninstall.bat`**. It deletes exactly the files listed in the manifest.
Add `-Purge` (`powershell -ExecutionPolicy Bypass -File uninstall.ps1 -Purge`) to also delete BepInEx logs and the trainer config.
Because no original game file is changed, "Verify / Repair" in GOG Galaxy or Steam also works as a fallback.

## Settings

After the first launch, edit `<game>\BepInEx\config\com.research.botrainer.cfg` to change keys or values:

* `[Hotkeys]` — any key name from Unity's Input System, e.g. `F3`, `Numpad1`, `K`.
* `[Values]` — `AddMoneyAmount` (10000), `AddItemsAmount` (99), `InfiniteMoneyLevel` (99999), `InfiniteItemsLevel` (99),
  `SpeedMultiplier` (2), `OneHitDamage` (9999).
* `[GodMode]` — `FallBehavior` (`Ignore` = default, free fall; `Rescue` = kill zones put you back on safe ground).
* `[UI]` — `ShowHud`.

## Notes and caveats

* Cheated values are real game data: **if the game saves while Infinite Money / Add Money is on, the save keeps those numbers.**
  Back up `%USERPROFILE%\AppData\LocalLow\Squid Shock Studios\Bo\` first if you want to keep a clean save.
* In God Mode falls are never interrupted. If you drop out of the level (endless void) press **Home**. If you prefer the old behaviour, set `FallBehavior = Rescue` in `[GodMode]` (a kill zone then puts you back on the last solid ground). Scripted scenes (Iwao ascent, Gasha fight, wave / Shogun chases, Boss Rush) keep the game's normal respawn. Some scripted "get hit" moments in boss fights may behave oddly; toggle it off (F1) if a scene gets stuck.
* One-Hit Kill can skip boss phase animations because the boss loses all health at once. Bosses that share one health pool across several stages (Karasa Tengu Duo, Daitengu + lesser tengu, and their Boss Rush versions) would break if emptied by one hit, so each hit there completes exactly one stage: the Duo falls in 2 hits, the Daitengu fight in 3.
* The fox-flame counter in the top-left HUD refreshes within a fraction of a second after Add Money / spending.
* If a game update changes the code, the trainer still finds its targets by name; if a feature stops working, check
  `<game>\BepInEx\LogOutput.log` (lines beginning with `Patched:` list the hooks that were applied).
* The installer warns when `Assembly-CSharp.dll` differs from the tested build — it is only a warning.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Installer says "Close the game first" | Quit `Bo.exe` (check Task Manager), run again. |
| "Game folder not found" | Paste the folder containing `Bo.exe`, or pass `-GameDir`. |
| No overlay in game | Press **F12**; confirm `BepInEx\LogOutput.log` exists and says "Bo Offline Trainer ready". Antivirus can quarantine `winhttp.dll` — add the game folder as an exception. |
| Game has a different layout (no `MonoBleedingEdge`) | This trainer targets the Unity-Mono PC build only. |
| Keys do nothing | Click the game window first; another overlay (Steam/Discord) may capture F-keys. |

## What is inside

```
Install.bat / install.ps1        auto-detect game, copy payload, write manifest
Uninstall.bat / uninstall.ps1    remove exactly what was installed
payload\                         BepInEx 5.4.23.3 (winhttp.dll doorstop + core) and BepInEx\plugins\BoTrainer.dll
source\BoTrainer.cs, MapTracker.cs, build.ps1   full plugin source (C#, Harmony) and build script
SHA256SUMS.txt                   checksums of every shipped file
```

## How it works (short)

Decompiled `Assembly-CSharp.dll` showed that all gameplay state lives in managed objects, so hooks are installed by method name with Harmony:
`NewPlayer.CanDamagePlayer` / `NewHealth.DamagePlayer` (God Mode), `NewPlayer.CalculateMoveSpeed` / `Hover.HoverSpeed` (speed),
`NewPlayer.PerformJumpReset` + `canDoubleJump` (jump), `Attack.OnEnable` / `Enemy.EnemyLoseHealth` (one-hit kill),
the `InventoryContainer` money/resources (economy) and `GameManager.InfiniteMana` (tea).
The map tracker reads `HandleMapIcon` objects under the map system and `GameManager.MapClearedconsDictionary` (taken items). The plugin includes a self-test (set the environment variable `TRAINER_SELFTEST=1` before starting the game; it writes
`trainer_selftest_report.json` next to `Bo.exe` once a save is loaded).

## Rebuilding from source

Needs only the .NET Framework compiler that ships with Windows: run `source\build.ps1 -Game "<game folder>" -Bep "<BepInEx\core folder>"`.

## Using it together with the Vietnamese language pack

The trainer and Bo-Vietnamese-v1 share the same mod loader (BepInEx). Install them in any order; each installer reuses BepInEx if it is already there. Uninstalling one never removes BepInEx while the other is still installed (the last one removed takes BepInEx with it).

