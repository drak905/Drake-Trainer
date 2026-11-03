# Verification Report - SpeedBrawl In-Game Trainer v1.0.0

## 1. Engine triage

| Item | Result |
| --- | --- |
| Engine | Unity 2019.4.16, Mono backend |
| Architecture | Windows x64 PE |
| Game build | SpeedBrawl.exe file version `2019.4.16.14703470` |
| Primary assembly | `SpeedBrawl_Data\Managed\DS.Game.Luna.dll` |
| `SpeedBrawl.exe` SHA-256 | `7A7D3B56C23B22D506C40ED7DBEB2BE2FF7C1F59067D9BC498349BB193801D52` |
| `DS.Game.Luna.dll` SHA-256 | `76DD93E1EFFB3BD063F47F5EDCF664F2847001457F55B6D84E048B7E72D5BA29` |
| `Assembly-CSharp.dll` SHA-256 | `2E16C7597791ADAE668327569FD6C65FD6A885E786BC78CB935ED7593A045EA3` |
| Selected route | Unity Mono -> BepInEx 5.4.23.6 x64 + HarmonyX plugin |
| Graphics/API need | None; trainer uses Unity IMGUI overlay, no D3D hook required |

The game ships a Mono runtime (`MonoBleedingEdge\EmbedRuntime\mono-2.0-bdwgc.dll`) and
managed game assemblies. IL2CPP, Unreal, and a custom native engine were ruled out.
No AOB scanning or process injection is required.

## 2. Static analysis

The full managed member inventory was extracted from `DS.Game.Luna.dll` (13,935 methods,
2,198 types, 9,279 fields) and a local IL reader was used to inspect the relevant
methods. The game facets used by the trainer are:

| Feature | Game code | Observed behaviour |
| --- | --- | --- |
| Coins | `ItemManager.get_Coins` | Reads `TeamInventory.Stacker[GameConfig.CoinItemID]`; setting the stacker updates HUD and save data |
| Coins UI sync | `InventoryStacker.set_Item(UnityGuid,int)` -> `SetAmountInternal` | Raises `ItemAmountChanged`; the HUD listens to it |
| God Mode | `Health_Server.OnPreDamage` / `Health_Server.Invincible` | Existing check aborts damage when `Invincible` is true; hero health objects are on the same GameObject as `Hero_Server` |
| Damage resolution | `Health_Server.ResolveDamage` | Computes `HealthLost` from `SBDamageResult.Damage` and `Health_Server.Value` |
| Movement speed | `MovementController_Server.GetTargetRunSpeed` | Returns the target run speed used by `Mathf.MoveTowards` in `UpdateHorizontalSpeed` |
| Jumps | `PlatformerController2D_Server.UpdateJump` / `get_AirJumps` | Air jump is allowed when `AirJumps < AirJumpCount`; `AirJumps` is reset by `ResetAirJump` |
| Stamina / Special | `Stamina.HasAmount`, `Stamina.TryConsume`, `Special.HasAmount`, `Special.TryConsume` | Built-in `Cheats.CheatBool.InfiniteEnergy` makes both `HasAmount` and `TryConsume` return true |
| Championship unlock | `ChampionshipItemData.get_IsUnlocked` | Returns true when `Cheats.CheatBool.AllChampionshipsUnlocked` is set |
| Item inventory | `InventoryStacker.SetAmountInternal` | Central path for increasing and decreasing item stacks |
| Save | `Cheats.ForceSave` -> `SaveSystem.SaveAll` | Safe no-op when `SaveSystem.Instance` is null |

The game already contains a cheat subsystem (`DS.Game.Luna.Cheats`) with public static
`SetCheatBool`, `GetCheatBool`, `ForceSave`, and cheat enum values. The trainer uses
those built-in flags for invincibility, infinite energy, and championship unlocks
instead of re-implementing them.

## 3. Gate results

### Gate 1 - Static contract

- All five Harmony target methods were resolved by `AccessTools.Method` at runtime.
- No AOB patterns are used, so there is no AOB uniqueness risk.
- Managed methods are patched by symbol, not RVA, so a rebuild with the same method
  names remains compatible.

### Gate 2 - Build and ABI

- Plugin compiled successfully with .NET Framework `csc.exe` targeting a managed
  library.
- References: `BepInEx.dll`, `0Harmony.dll`, `UnityEngine.dll`,
  `UnityEngine.CoreModule.dll`, `UnityEngine.IMGUIModule.dll`,
  `UnityEngine.InputLegacyModule.dll`, `UnityEngine.Networking.dll`,
  `DS.Game.Luna.dll`, `DS.Game.Util.dll`, `DS.Game.Networking.dll`.
- No unsafe code, no native ABI assumptions, no hard-coded addresses.

### Gate 3 - Runtime smoke

Verified in the actual game launched through the Epic Games Launcher:

- BepInEx 5.4.23.6 loaded under Unity 2019.4.16.
- Plugin loaded: `Loading [SpeedBrawl In-Game Trainer 1.0.0]`.
- All five patches applied:
  - `Patched Health_Server.OnPreDamage`
  - `Patched Health_Server.ResolveDamage`
  - `Patched PlatformerController2D_Server.get_AirJumps`
  - `Patched MovementController_Server.GetTargetRunSpeed`
  - `Patched InventoryStacker.SetAmountInternal`
- `Chainloader startup complete` with no exceptions.
- The in-game overlay rendered on the title screen and remained stable.

Epic launcher note: the Epic Games Launcher sets `DOORSTOP_DISABLE`, which prevented
BepInEx from loading with the stock Doorstop configuration. The shipped
`doorstop_config.ini` sets `ignore_disable_switch = true`, after which BepInEx loaded
normally through Epic. This was verified twice.

### Gate 4 - Closed-loop functional delta

The following deltas were observed live in the game:

| Test | Before | Action | After | UI updated |
| --- | --- | --- | --- | --- |
| Add money | 105 coins | `F6` Add 100,000 | 100,105 coins | Yes, HUD showed 100,105 |
| Infinite money | 100,105 coins | `F5` toggle on | 9,999,999 coins | Yes, HUD showed 9,999,999 |
| Menu overlay | Hidden | `Insert` | Visible | Yes |
| Feature toggles | Off | F-keys / mouse | Active summary changed | Yes |

`F6` exercised the full chain: plugin -> `ItemManager.TeamInventory.Stacker` ->
`InventoryStacker.SetAmountInternal` -> `ItemAmountChanged` -> HUD -> `Cheats.ForceSave`.
The HUD update confirms the real inventory value changed, not a display-only copy.

## 4. Feature implementation summary

| Feature | Mechanism |
| --- | --- |
| God Mode | Harmony prefix on `Health_Server.OnPreDamage`; aborts non-helpful damage when the object has `Hero_Server`; also sets `Cheats.CheatBool.Invincible` |
| Unlimited Jumps | Harmony postfix on `PlatformerController2D_Server.get_AirJumps`; returns `-1` for hero objects so the air-jump comparison always passes |
| Move Speed x2 | Harmony postfix on `MovementController_Server.GetTargetRunSpeed`; multiplies result by `2` for hero objects |
| Infinite Stamina | `Cheats.CheatBool.InfiniteEnergy` + periodic refill of `Hero_Server.Stamina` and `Hero_Server.Special` |
| Infinite Coins | Periodic top-up of the coin stacker to 9,999,999 |
| Add Coins | Writes `Coins + 100000` through the stacker, clamps at 999,999,999, calls `Cheats.ForceSave` |
| Infinite Items | Harmony prefix on `InventoryStacker.SetAmountInternal`; blocks decreases only for the player's `TeamInventory`, excluding the coin item ID |
| Unlock All Gear | Iterates `ItemManager.GearItemDatas`, adds missing gear to `TeamInventory`, then `Cheats.ForceSave` |
| Show All Items | IMGUI ESP marker pass over known world item/prop component types using `Camera.main.WorldToScreenPoint` |
| One-Hit Kill | Harmony prefix on `Health_Server.ResolveDamage`; sets `SBDamageResult.Damage` to a lethal value for `Enemy_Server` |
| Unlock All Championships | `Cheats.CheatBool.AllChampionshipsUnlocked` |
| Force Save | `Cheats.ForceSave()` |

## 5. Online guard

`SBNetworkManager.Instance.Connector.IsPartyOnline` is checked before every feature
action and inside every Harmony patch. When an online party is detected, the trainer
suppresses its game cheat flags and refuses to apply its patches. This is a
best-effort guard; the trainer is intended for offline/single-player use only.

## 6. Limitations and residual unknowns

- The live closed-loop tests covered the overlay, coin write path, HUD sync, save, and
  patch application. The God Mode, jump, speed, item-freeze, one-hit-kill, and ESP
  paths were verified statically and by successful patch installation, but were not
  each exercised in a live level during this session.
- `Unlock All Gear` depends on `ItemManager.GearItemDatas` being populated. In the
  title/main-menu state the list can be empty; the trainer reports
  `Gear database not ready - open Equip and retry`.
- The ESP uses `Camera.main`; if a level uses a different active camera, markers may
  not appear until the main camera is active.
- The game build hash check is exact. A different SpeedBrawl build may still work, but
  is not certified by this report.

## 7. Reproducibility

The portable folder contains the exact plugin DLL, the BepInEx loader, installer and
uninstaller scripts, source, and `SHA256SUMS.txt`. The plugin can be rebuilt with
`Source\build.ps1` against the game's managed assemblies and a BepInEx core folder.
