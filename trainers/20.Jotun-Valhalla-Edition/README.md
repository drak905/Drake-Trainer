# Jotun: Valhalla Edition — trainer script

**Architecture: Unity + Mono.** Values are found by reading the game's **class
metadata** (real class and field names), not by scanning memory.

---

## Quick start

1. Launch Jotun and get in-game.
2. Open Cheat Engine, attach to `Jotun.exe`.
3. `File → Execute Script` → **`jotun_resolve.lua`**.

That single run resolves every address through Mono metadata and applies your
whole setup. Re-run it after any restart, or any time a value reads wrong.

`Jotun.CT` can also be loaded for the table entries, but the **`.lua` is the
durable part** — the `.CT` holds live heap addresses that go stale between
sessions. The script rebuilds them.

---

## Files

| File | Purpose |
|---|---|
| `jotun_resolve.lua` | **Main tool.** Resolves the player, applies loadout, freezes what needs freezing |
| `Jotun.CT` | Cheat table (18 entries; addresses valid for one session) |

---

## What the script does

- Launches CE's Mono data collector and locates `Assembly-CSharp`
- Finds your Pawn via `PlayerHealthBar._pawn` (a stable reference, not a guess)
- Registers symbols usable anywhere CE accepts an address
- Rebuilds the cheat table entries, replacing rather than duplicating
- Applies move speed, attack damage, camera zoom and god power charges
- Freezes invulnerability, move speed and god powers

Config block at the top of the file:

```lua
local GODPOWER_CHARGES = 99     -- charges per god power
local FREEZE_GODPOWERS = true   -- so they never deplete
local SPEED_MULT       = 4.0    -- x stock 4.3; applied to BASE, never compounds
local FREEZE_SPEED     = true
local ATTACK_DAMAGE    = 100    -- normal attack  (stock 10)
local CHARGED_DAMAGE   = 100    -- charged attack (stock 55)
local ROLL_DAMAGE      = nil    -- dodge attack   (stock 10; nil = leave)
local CAM_MAX_ZOOM     = 0.2    -- LOWER = WIDER  (stock 0.8)
local CAM_MIN_ZOOM     = 0.05   -- how far the game may widen dynamically
```

Console helpers (CE Lua console):

```lua
JotunFindPlayerPawn()             -- pawn address + how it was found
JotunGodPowers(nil)               -- report charges
JotunGodPowers(99)                -- set all
JotunMoveSpeed(3)                 -- 3x (1 = stock, nil = report)
JotunAttackDamage(200, 300, 100)  -- normal, charged, roll
JotunCameraZoom(0.3)              -- lower = wider
```

Registered symbols: `jotunPawn`, `jotunHealth`, `jotunMaxHealth`, `jotunDamage`,
`jotunInvuln`, `jotunDmgTakenMul`, `jotunMoveSpeed`, `jotunDmgNormal`,
`jotunDmgCharged`, `jotunDmgRoll`, `jotunCamMaxZoom`, `jotunCamMinZoom`.

---

## Class map

`Pawn` — every character, player and enemy alike:

| Field | Offset | Type |
|---|---|---|
| `_maxHealth` | `0x50` | float |
| `_triggersCanBeDamaged` | `0x54` | bool |
| `_health` | `0x58` | float |
| `_damage` | `0x5C` | float |
| `_isInvulnerable` | `0x60` | **Int32** (1 = on) |
| `_modifiedDamage` | `0x64` | float |
| `_recievedDamageModifier` | `0x68` | float (0 = take no damage) |

Health is on a **0–100 scale** (rising with upgrades), which is why the HUD shows
a bar and no numbers.

| Class | Field | Offset | Notes |
|---|---|---|---|
| `HealthBar` / `PlayerHealthBar` | `_pawn` | `0x38` | **how the player is identified** |
| `BaseGodPower` | `_numberOfCharges` | `0x2C` | int32; 7 instances |
| `MoveBehaviour` / `PlayerMoveBehaviour` | `_speed` | `0xC8` | float, stock **4.3** |
| `MoveBehaviour` | `_speedModifier` | `0xD8` | float — **has no effect** |
| `AttackBehaviour` | `_damage` | `0xD8` | normal 10, charged 55, roll 10 |
| `PlayerAttackBehaviour` | `_releaseTime` | `0xF0` | float — **has no effect** |
| `CameraController` | `_minZoom` / `_maxZoom` | `0x38` / `0x3C` | float, stock 0.05 / 0.8 |
| `GodPowersManager` | `_activePowerIndex` | `0x4C` | singleton |

God powers (7): Lance, Thunder, Sacrifice (SPEED), Decoy, Revive, Healing, Shield.

Camera scale — **lower = wider**: `0.8` stock, `0.6` slight, `0.35` noticeable,
`0.2` wide. Keep `_minZoom` ≤ `_maxZoom` or the range is invalid.

---

## Gotchas

**Attack speed is not adjustable.** The attack cooldown is already 0, and cutting
`_releaseTime` from 0.3s to 0.05s provably changed nothing. Jotun commits to
attack animations by design, so the rate is animation-bound. The only lever is a
global speedhack, which speeds up enemies too. **Raise damage instead.**

**Don't write `tk2dCamera.zoomFactor` to zoom the view.** `CameraController`
overwrites the game camera every frame, so the write is reverted instantly. It
*does* stick on the two UI cameras, which just shrinks your menu and health bar.
Use `CameraController._maxZoom`.

**`_isInvulnerable` is reset by the game** on run restarts and transitions, so a
one-off write does not hold. The script freezes it via a cheat-table entry.

**God power charges: the HUD lags.** `_numberOfCharges` is the live counter, but
the display doesn't refresh until a power-change event fires — cycle powers to
see restored charges. Freezing the field gives effectively unlimited uses.

**Attack damage persists across areas**, so it is deliberately *not* frozen —
freezing would block any legitimate buff the game grants.

**Speed multiplier applies to a recorded base of 4.3**, not the current value, so
re-running the script never compounds the boost.

**CE's freeze runs on the main thread.** Calling `sleep()` from a script stalls
that thread and makes freezing look broken. Test across separate calls.

**`SaveGame.power*` fields are a dead end** — its four instances return garbage
(`2332265984`, `4294967295`). Don't bother.

---

## Reverse-engineering notes (for agents)

Scanning was hopeless here: a health bar gives no number to search for, and an
unknown-value scan went 1.76 billion → only 30 million even after damage plus
repeated unchanged filters.

Mono metadata bypassed all of it:

1. `LaunchMonoDataCollector()`, then `mono_enumAssemblies()` → find
   `Assembly-CSharp`.
2. `mono_image_enumClasses(img)` → 2,120 classes. **Note the key is `classname`,
   not `name`.**
3. `mono_class_enumFields(cls)` → exact offsets *and* types, so no guessing
   whether health is int or float.
4. `mono_class_findInstancesOfClassListOnly(cls)` → all 77 live `Pawn` instances.
   The player was obvious: the only one at 3/100 health.
5. For a stable identifier, don't pick by lowest health — follow
   `PlayerHealthBar._pawn` instead.

`mono_object_getClass()` gives an instance's concrete subclass, which is how the
seven god powers were named individually.
