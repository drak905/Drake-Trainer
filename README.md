# Drake Trainer

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg?logo=windows)](https://microsoft.com/windows)
[![Games Supported](https://img.shields.io/badge/Games%20Supported-25%20Titles-brightgreen.svg)](#game-catalog--feature-matrix)
[![Standalone](https://img.shields.io/badge/Injection-Zero%20External%20Tools-orange.svg)](#key-highlights)

A curated preservation suite of custom **game trainers, in-game HUD overlay menus, native DLL proxy injectors, BepInEx Harmony plugins, and bytecode patches** created by Drake.

Every trainer in this repository is built to be **100% portable, non-destructive, and self-contained**. They require no Cheat Engine, no paid trainer subscriptions, and no complex injection tools.

---

## Key Highlights

- **Dual 1-Click Launchers**: Every trainer provides `Install.bat` (double-click to install) and `install.ps1` (with automatic game path detection for Steam, Epic Games, and GOG Galaxy).
- **Clean Uninstallation**: Original vanilla files are automatically backed up as `.VANILLA`. Double-clicking `Uninstall.bat` instantly restores the game to its pristine vanilla state.
- **In-Game Menus & Overlays**: Featuring Dear ImGui DirectX 11 overlays, UE4SS interactive HUDs, and native retro pixel radar / ESP maps.
- **Complete Rebuildable Source Code**: Full C/C++, C#, Java, Python, and Lua source code and build scripts are included for every trainer.
- **Coexistence Ready**: Built to coexist seamlessly with custom localization packs and community mods.

---

## Game Catalog & Feature Matrix

| # | Game | Engine | Injection Route | Key Features | Folder |
| :-: | :--- | :--- | :--- | :--- | :-: |
| **01** | **[Afterimage](trainers/01.Afterimage)** | Unreal Engine 4 | UE4SS Lua Mod (`dwmapi.dll`) | In-Game HUD Menu (`Home`), God Mode (survives trap/spike/kill volumes), Add +100 to all inventory bag items (`F2`), Unlimited Air Jumps (`F3`), Unlimited Weapon Skills/MP (`F4`), 2x Move Speed (`F5`), Interactive Minimap Item Markers (`PgUp`) | [View](trainers/01.Afterimage) |
| **02** | **[Astral Ascent](trainers/02.Astral-Ascent)** | Chowdren (C++) | Native Proxy DLL (`winmm.dll`) | In-Game Cheat/Debug Menu (`F1` / `[` `]`), God Mode (Infinite HP & Mana), Unlimited Air Jumps, One-Hit Kill, Currency Modifiers (Quartz, Sun, Stars) | [View](trainers/02.Astral-Ascent) |
| **03** | **[Bō: Path of the Teal Lotus](trainers/03.Bo-Path-of-the-Teal-Lotus)** | Unity Mono | BepInEx 5 + Harmony (`winhttp.dll`) | God Mode (immune to damage/spikes/freezes/falls), Unlimited Jump / Infinite Daruma, One-Hit Kill (Tengu Duo support), Infinite Tea / Kettle Heal, Add Fox Fire, In-Game Kodama & Collectible Map (`F2`) | [View](trainers/03.Bo-Path-of-the-Teal-Lotus) |
| **04** | **[Creature in the Well](trainers/04.Creature-in-the-Well)** | Unreal Engine 4 | Native Proxy DLL (`xinput1_3.dll`) | God Mode / Invincibility, Unlimited Energy, Instant Charge, One-Hit Destroy / Max Core Power, Add Energy/Orbs, INI Hotkey Config | [View](trainers/04.Creature-in-the-Well) |
| **05** | **[Dead Cells](trainers/05.Dead-Cells)** | HashLink / Heaps | Bytecode Patcher | God Mode, Infinite Cells & Gold, Unlimited Jumps, One-Hit Kill, Instant Cooldowns | [View](trainers/05.Dead-Cells) |
| **06** | **[Death's Gambit: Afterlife](trainers/06.Deaths-Gambit-Afterlife)** | GameMaker Studio 2 | UTMT Hook + `xdelta3` Patch | God Mode + Infinite Healing Feathers (`F1`), Infinite Endurance + Soul Energy + Ammo (`F2`), Essence Pickup Bonus +999 (`F3`), Unlimited Jump (`F4`), One-Hit Kill (`F5`), +99,999 Ultra Essence (`G`) | [View](trainers/06.Deaths-Gambit-Afterlife) |
| **07** | **[Ghost Song](trainers/07.Ghost-Song)** | Unity IL2CPP (DX11) | Native Proxy (`version.dll`) + ImGui | In-Game Dear ImGui Menu (`Insert`/`F10`), God Mode, Infinite Nanites & Consumables, Unlimited Air Jumps, 2x Move Speed, One-Hit Kill, Infinite Stamina & Spirit, Full Map Reveal with Icons | [View](trainers/07.Ghost-Song) |
| **08** | **[Guacamelee! STCE](trainers/08.Guacamelee-STCE)** | Custom C++ Engine | Native Proxy DLL (`dinput8.dll`) | God Mode, Infinite Stamina, Unlimited Special Moves, Unlimited Jumps, Add Coins / Silver, One-Hit Kill | [View](trainers/08.Guacamelee-STCE) |
| **09** | **[Gunslugs](trainers/09.Gunslugs)** | Java 8 / LWJGL 2 | Classpath Prepend (`config.json`) | Pixel HUD & Toasts, God Mode (`F1`), Add Money (`F2`), Unlimited Money & Items (`F3`), Unlimited Jump (`F4`), 2x Speed (`F5`), Full Level Radar / ESP (`F6`), One-Hit Kill (`F7`), Weapon Cycle (`F8`) | [View](trainers/09.Gunslugs) |
| **10** | **[Gunslugs 2](trainers/10.Gunslugs-2)** | Java 8 / LWJGL 2 | Classpath Prepend (`config.json`) | In-Game HUD, God Mode (`F1`), Add Coins (`F2`), Unlimited Money & Ammo (`F3`), Unlimited Jump (`F4`), 2x Speed (`F5`), Map Radar / Objective ESP (`F6`), One-Hit Kill (`F7`), Weapon Cycle (`F8`) | [View](trainers/10.Gunslugs-2) |
| **11** | **[Gunslugs 3: Rogue Tactics](trainers/11.Gunslugs-3-Rogue-Tactics)** | Java 8 / LWJGL | Classpath Prepend (`config.json`) | Retro In-Game Menu & HUD, God Mode (`F1`), Add Money (`F2`), Unlimited Money & Items (`F3`), Unlimited Jump (`F4`), 2x Speed (`F5`), Full Level Map ESP (`F6`), One-Hit Kill (`F7`), Weapon Cycle (`F8`) | [View](trainers/11.Gunslugs-3-Rogue-Tactics) |
| **12** | **[9 Years of Shadows](trainers/12.Nine-Years-of-Shadows)** | Unity Mono | BepInEx 5 + Harmony (`winhttp.dll`) | God Mode (invincible, survives darkness/traps), Infinite Armor / Shadow gauge, Unlimited Jumps, Infinite Magic energy, Add Light Crystals (+10k), One-Hit Kill | [View](trainers/12.Nine-Years-of-Shadows) |
| **13** | **[Ogu and the Secret Forest](trainers/13.Ogu-and-the-Secret-Forest)** | Unity Mono | BepInEx 5 + Harmony (`winhttp.dll`) | God Mode (Infinite Hearts), Infinite Stamina / Roll, Unlimited Jump / Sprint, Add Bugs / Coins, One-Hit Kill | [View](trainers/13.Ogu-and-the-Secret-Forest) |
| **14** | **[Shogun Showdown](trainers/14.Shogun-Showdown)** | Unity 2021 Mono | BepInEx 5.4.23 + HarmonyX | God Mode (`F1`), Infinite Money / Coins & Meta (`F2`), Unlimited Special Move (`F3`), 2x Character Move Distance (`F4`), 2x Game Speed (`F5`), Infinite Potions (`F6`), No Tile Cooldown (`F7`), One-Hit Kill (`F8`), Reveal Sector Map (`F9`) | [View](trainers/14.Shogun-Showdown) |
| **15** | **[Voidwrought](trainers/15.Voidwrought)** | Unity Mono | BepInEx 5 + Harmony (`winhttp.dll`) | God Mode, Infinite Void Souls / Currency, Unlimited Jumps / Air Dash, Infinite Healing / Ichor, One-Hit Kill | [View](trainers/15.Voidwrought) |
| **16** | **[Wizard of Legend](trainers/16.Wizard-of-Legend)** | Unity Mono | Mono.Cecil IL Injector | Unlocks Native Developer Debug Menu (`Backspace`), God Mode (`2`), Max Difficulty (`1`), Slow-mo (`3`), Fullscreen Minimap (`4`), +9999 Gold / +999 Chaos Gems, Wrath of Developer (Kill All) | [View](trainers/16.Wizard-of-Legend) |
| **17** | **[Eastern Exorcist](trainers/17.Eastern-Exorcist)** | Unity Mono | Mono Metadata Reflection | Damage Immunity (`TakeDamageFactor = 0`), Attack 10x, Soul 10x, 2x Move Speed, Free Level-Ups, Free Skill Nodes | [View](trainers/17.Eastern-Exorcist) |
| **18** | **[Figment](trainers/18.Figment)** | Unity Mono | Singleton Root Keeper | No Damage (`isInvulnerable = 1`), Character Speed 2.0x, Camera Zoom Expansion (`2.66x`), Scene-Transition Auto-Keeper | [View](trainers/18.Figment) |
| **19** | **[Figment 2: Creed Valley](trainers/19.Figment-2-Creed-Valley)** | Unity Mono | Root-Motion Animator Hook | God Mode (`isInvulnerable = 1`), Animation & Run Speed 3.0x, Max Health, Shard Collector, Camera Zoom 5.0x | [View](trainers/19.Figment-2-Creed-Valley) |
| **20** | **[Jotun: Valhalla Edition](trainers/20.Jotun-Valhalla-Edition)** | Unity Mono | Pawn Metadata Reflection | God Power Charges 99 (never deplete), Move Speed 4.0x, Normal Attack 100 dmg, Charged Attack 100 dmg | [View](trainers/20.Jotun-Valhalla-Edition) |
| **21** | **[[REDACTED]](trainers/21.Redacted)** | Unreal Engine 4 | Guarded VTable Hook | No Damage (Player VTable Guarded), 100x Collected Items Multiplier, Live Currency Wallet Resolver | [View](trainers/21.Redacted) |
| **22** | **[River City Girls](trainers/22.River-City-Girls)** | Unity Mono | Persistent Mono Root Keeper | No Damage (Invincibility), One-Hit Kill (100,000x dmg), Money & XP Gain 10x, Speed 2.0x, Max All Character Stats | [View](trainers/22.River-City-Girls) |
| **23** | **[ScourgeBringer](trainers/23.ScourgeBringer)** | Native AOT (64-bit) | Static Module Pointer Path | Infinite HP / Max HP, Blood Shards, Skill Points, Unlimited Buff Stacks (Reload +500%, Sword +500%, Gun +500%) | [View](trainers/23.ScourgeBringer) |
| **24** | **[Sol Cesto](trainers/24.Sol-Cesto)** | Construct 3 / WebView2 | Chrome DevTools Protocol (CDP) | Dual Launcher (`PlaySolCesto.bat`), God Mode (Infinite Lives & Shields), Infinite Gold & Keys, Instant Room Clear, Unlock All Stars | [View](trainers/24.Sol-Cesto) |
| **25** | **[SpeedBrawl](trainers/25.SpeedBrawl)** | Unity 2019 Mono | BepInEx 5.4.23 + HarmonyX (`winhttp.dll`) | In-Game Menu (`Insert`), God Mode (`F1`), Unlimited Air Jumps (`F2`), 2x Move Speed (`F3`), Infinite Stamina/Special (`F4`), Infinite Coins (`F5`), Add +100k Coins (`F6`), Infinite Items (`F7`), Unlock All Gear (`F8`), Show All Items/ESP (`F9`), One-Hit Kill (`F10`), Unlock All Championships (`F11`), Force Save (`Home`) | [View](trainers/25.SpeedBrawl) |

---

## Preserved Vietnamese Localization Packs

In addition to trainers, this repository preserves 7 complete Vietnamese language packs developed alongside the reverse-engineering toolchain:

| Game | Version | Method | Directory |
| :--- | :---: | :--- | :--- |
| **Afterimage** | v3.1.0 | UE4SS RichTextBlock Hook & Runtime Dict | [translations/Afterimage-Vietnamese-v3.1](translations/Afterimage-Vietnamese-v3.1) |
| **Bō: Path of the Teal Lotus** | v1.0.0 | BepInEx Text Mesh Pro (TMP) Font Injection | [translations/Bo-Vietnamese-v1](translations/Bo-Vietnamese-v1) |
| **Dead Cells** | v1.0.0 | PAK Asset Injection & HashLink String Hook | [translations/DeadCells-Vietnamese-v1](translations/DeadCells-Vietnamese-v1) |
| **Ghost Song** | v1.0.0 | Unity TextMeshPro Sub-Mesh Font Fallback | [translations/GhostSong-Vietnamese-v1](translations/GhostSong-Vietnamese-v1) |
| **Guacamelee! STCE** | v1.0.0 | Bitmap Font Atlas Replacement & String Dict | [translations/Guacamelee-STCE-Vietnamese-v1](translations/Guacamelee-STCE-Vietnamese-v1) |
| **9 Years of Shadows** | v1.0.0 | BepInEx Font Injector & UI String Table | [translations/NineYearsOfShadows-Vietnamese-v1](translations/NineYearsOfShadows-Vietnamese-v1) |
| **Voidwrought** | v1.0.0 | BepInEx Unity Localization Interceptor | [translations/Voidwrought-Vietnamese-v1](translations/Voidwrought-Vietnamese-v1) |

---

## Quickstart & Installation

### Option 1: Using Pre-Built Standalone Packages (Recommended)
1. Download the pre-built `.zip` for your game from the **[packages/](packages/)** folder or from [GitHub Releases](https://github.com/drak905/Drake-Trainer/releases).
2. Extract the archive anywhere on your PC.
3. Double-click `Install.bat` (or right-click `install.ps1` → **Run with PowerShell**).
4. Launch your game and enjoy!

### Option 2: Clone the Repository
```bash
git clone https://github.com/drak905/Drake-Trainer.git
cd Drake-Trainer/trainers/14.Shogun-Showdown
./Install.bat
```

### To Uninstall
Double-click `Uninstall.bat` in the trainer folder. The script automatically removes the injection loader and restores the original vanilla backup (`.VANILLA`).

---

## Repository Structure

```text
Drake-Trainer/
├── README.md                          # Master documentation and game matrix (this file)
├── .gitignore                         # Build and OS artifact exclusions
├── docs/
│   └── REVERSE_ENGINEERING_NOTES.md   # Detailed technical reversing write-ups per engine
├── packages/                          # Ready-to-use standalone ZIP archives (32 packages)
├── trainers/                          # Organized trainer projects (25 games)
│   ├── 01.Afterimage/
│   ├── 02.Astral-Ascent/
│   ├── 03.Bo-Path-of-the-Teal-Lotus/
│   ├── 04.Creature-in-the-Well/
│   ├── 05.Dead-Cells/
│   ├── 06.Deaths-Gambit-Afterlife/
│   ├── 07.Ghost-Song/
│   ├── 08.Guacamelee-STCE/
│   ├── 09.Gunslugs/
│   ├── 10.Gunslugs-2/
│   ├── 11.Gunslugs-3-Rogue-Tactics/
│   ├── 12.Nine-Years-of-Shadows/
│   ├── 13.Ogu-and-the-Secret-Forest/
│   ├── 14.Shogun-Showdown/
│   ├── 15.Voidwrought/
│   ├── 16.Wizard-of-Legend/
│   ├── 17.Eastern-Exorcist/
│   ├── 18.Figment/
│   ├── 19.Figment-2-Creed-Valley/
│   ├── 20.Jotun-Valhalla-Edition/
│   ├── 21.Redacted/
│   ├── 22.River-City-Girls/
│   ├── 23.ScourgeBringer/
│   ├── 24.Sol-Cesto/
│   └── 25.SpeedBrawl/
├── tools/                             # Reversing bridges and automation
│   └── vision-trainer/                # Vision-based trainer and Cheat Engine MCP bridge
└── translations/                      # Preserved Vietnamese localization packs (7 games)
    ├── Afterimage-Vietnamese-v3.1/
    ├── Bo-Vietnamese-v1/
    ├── DeadCells-Vietnamese-v1/
    ├── GhostSong-Vietnamese-v1/
    ├── Guacamelee-STCE-Vietnamese-v1/
    ├── NineYearsOfShadows-Vietnamese-v1/
    └── Voidwrought-Vietnamese-v1/
```

---

## Technical Documentation

For in-depth explanations of how each engine was analyzed, decompiled, and patched:
👉 Read **[docs/REVERSE_ENGINEERING_NOTES.md](docs/REVERSE_ENGINEERING_NOTES.md)**.

---

## License & Disclaimer

- The reverse-engineering frameworks, custom proxy DLLs, Harmony plugins, and loader scripts in this repository are published under the **MIT License**.
- These trainers are developed strictly for **offline, single-player gaming, modding accessibility, and reverse-engineering research**.
- All game trademarks, copyrights, and assets belong to their respective developers and publishers.
