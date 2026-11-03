# Figment 2: Creed Valley — trainer script

**Architecture: Unity + Mono.** Values are found by reading **class metadata**
(real class and field names). The developers left unusually clean naming, so most
features are single named flags.

---

## Quick start

1. Launch Figment 2 and get into a level.
2. Open Cheat Engine, attach to **`Figment 2.exe`** (note the space in the name).
3. `File → Execute Script` → **`f2_resolve.lua`**.

One run resolves everything, applies the loadout and rebuilds the cheat table.
Re-run after a restart **or a scene change** — see the gotcha about object moves.

---

## Files

| File | Purpose |
|---|---|
| `f2_resolve.lua` | resolver + keeper. Edit the config block at the top, then run it. |
| `f2_stop.lua` | **emergency stop** — kills the keeper and unfreezes everything. |
| `Figment2.CT` | cheat table for manual tuning. |

## After restarting Cheat Engine

1. Attach to **`Figment 2.exe`** (note the space in the name).
2. `File -> Execute Script` -> `f2_resolve.lua`.
3. Load `Figment2.CT` only if you want the manual entries; the script does not
   need it.

Addresses are **never** hardcoded — everything is resolved from Mono metadata at
run time, so a new PID or a new scene is fine.

---

## The one thing that will trip you up

**There is no `Assembly-CSharp`.** This project uses Unity assembly definitions,
so the game code lives in an assembly named **`Figment`** (2,337 classes), plus
`BedtimeCore` (352) and ~50 `com.bedtime.*` packages. There are 174 assemblies in
total. Searching for `Assembly-CSharp` returns nothing, which looks like complete
failure if you assume the usual layout.

---

## Config

```lua
local INVULNERABLE = true    -- freeze isInvulnerable = 1
local MAX_HEALTH   = nil     -- e.g. 20 for more hearts (nil = leave stock)
local ANIM_SPEED   = 3.0     -- movement + animation rate (2.0 is barely visible)
local SHARDS       = nil     -- "max" to collect all, a number, or nil to report
local CAMERA_ZOOM  = 5.0     -- orthographic scenes: orthographicSizeAddition
local CAMERA_FOV_MULT = 1.6  -- perspective scenes: Cinemachine FOV multiplier
local KEEP_APPLIED = true    -- re-apply loop (cheap: static-pointer path only)
local FREEZE       = true
```

Console helpers:

```lua
F2AnimSpeed(3)     -- movement speed (2.0 is barely noticeable; 3.0 is clear)
F2CameraZoom(8)    -- orthographic scenes: larger = wider
F2FOV(1.6)         -- perspective scenes: Cinemachine FOV multiplier
F2Shards("max")    -- collect all shards in the current scene
F2Heal()           -- health to max
F2StartKeeper()    -- re-apply loop; F2StopKeeper() to stop
F2Resolve()        -- re-resolve; returns the info table
```

If Cheat Engine ever goes sluggish, run **`f2_stop.lua`**.

Symbols: `f2PlayerHealth`, `f2Health`, `f2MaxHealth`, `f2Invuln`, `f2XP`.

---

## Class map

`PlayerHealth` — **77 named fields**. Two instances: the one with
`maxHealth > 0` is live, the other is the prefab template.

| Field | Offset | Type | Stock |
|---|---|---|---|
| **`isInvulnerable`** | `0x175` | **byte** | 0 — set 1 for god mode |
| `health` | `0x190` | float | 6.0 |
| `maxHealth` | `0x140` | int32 | 6 |
| `baseMaxHealth` | `0x13C` | int32 | 6 |
| `xp` | `0x188` | int32 | 0 |
| `XPNeededNext` | `0x144` | int32 | 5 |
| `regenInCombat` | `0x174` | byte | 0 (off) |
| `regenHealthFactor` | `0x160` | float | 0.167 |
| `delayBeforeRegenerating` | `0x164` | float | 8.0 |
| `respawnHealthFactor` | `0x16C` | float | 1.0 |
| `minimumRespawnHealth` | `0x170` | int32 | 3 |
| `damageReductionPerHit` | `0x150` | float | 0.5 |
| `lastCheckPointHP` | `0x1BC` | float | 6.0 |

`isInvulnerable` is a **1-byte bool**. Reading it as a dword gives nonsense
(2583691264) because the read spills into neighbouring fields.

`PlayerManager` (1 instance) — `animator@0x30` is the player's `Animator`.
This is how you get the right Animator without guessing among the many in scene.

Other useful classes: `CompanionHealth` (Piper), `CollectibleManager`,
`BaubleType` (currency — `PlayerHealth` raises `baublesChanged`), `HealthOrb`,
`HealthSpawner`, `PlayerMovement`.

---

## Movement speed — three approaches, only one works

| Approach | Result |
|---|---|
| `PlayerMovement.movementSpeedMultiplier@0xA8 = 2` | **No effect.** The field exists with a perfect name but the game never applies it |
| `NavMeshAgent.set_speed(7.0)` | **No effect.** The agent is for pathfinding; player speed doesn't come from it |
| **`Animator.set_speed(2.0)`** | **Works.** Movement is root-motion driven |

`PlayerMovement.lockToNavigationMesh = 1` is what suggested the NavMeshAgent, and
`PlayerAnimatorParameter` containing **`LocomotionSpeed`** and
**`LocomotionSpeedMultiplier`** is what pointed to the animator.

Identifying the player's NavMeshAgent (useful technique even though the agent
turned out to be a dead end): invoke `get_speed` on all 7 instances — the player
read **3.5** while every NPC read **0.5**.

**Caveat:** animator speed scales *all* animations, so attacks and dodges speed up
too. A gentler option is the animator float parameter
`LocomotionSpeedMultiplier` via `Animator.SetFloat`, which is the parameter the
game itself drives — untested.

The movement multiplier is deliberately left in the cheat table labelled
`[no effect]` so nobody wastes time rediscovering it.

---

## Shards (the blue collectibles)

**They are called "shards"** — not orbs, baubles, or collectibles. Searching for
those words finds nothing useful, which is the single biggest time sink in this
game.

`ShardSceneManager` — reached via `ShardUI._shardSceneManager@0x70`:

| Field | Offset | Type | Example |
|---|---|---|---|
| `_unlockPoint` | `0x68` | float | 0.5 — reward threshold as a fraction |
| **`Collected`** | `0x6C` | int32 | 48 |
| **`MaxShards`** | `0x70` | int32 | 153 |

The HUD percentage is simply `Collected / MaxShards`. `F2Shards("max")` completes
the set; `F2Shards(nil)` just reports.

**How this was found, after scanning failed completely.** The percentage readings
(17.6%, 21.6%, 31.4%) fit `n/51`, which led to scanning for an integer **16** —
the wrong number entirely. The real counter was **48/153** (the same ratio).
Integer scans returned only *unaligned* addresses, i.e. coincidental byte
patterns, and float scans found only derived display copies.

What worked: **`mono_object_findRealStartOfObject`** on the live display floats,
then `mono_object_getClass` on the result:

```lua
local start = mono_object_findRealStartOfObject(floatAddr)
local cls   = mono_object_getClass(start)
print(mono_class_getName(cls))   --> ShardUI, ShardUI_ShardCounterInterpolatee
```

That named the owning classes and revealed the game's terminology, after which
following `_shardSceneManager` gave the authoritative object in one hop.

**Lesson:** when a value's *name* is unknown, resolve a known address back to its
object and let the class name tell you the vocabulary. Far faster than guessing
search terms.

**Caveat:** `_unlockPoint` is 0.5, so a reward fires at 50%. Jumping straight past
a threshold may skip the trigger, since the game likely checks on pickup. If an
unlock doesn't fire, set `Collected` just below the threshold and collect one
shard naturally. Collected can also exceed `MaxShards` (observed 183/153 = 113%)
if you keep collecting after maxing it — harmless, and `F2Shards("max")` recaps it.

---

## Resolution: static fields, never heap scans

**Do not use `mono_class_findInstancesOfClassListOnly` in this game.** A heap scan
takes seconds to tens of seconds, runs on CE's **main thread**, and trips CE's
*"mono operation is taking longer than expected"* dialog. On a timer it wedges the
GUI and the MCP bridge completely.

Everything is reachable without scanning.

### 1. The player: a static singleton

`PlayerManager` has a **static `instance` field**. The static slot address is fixed
for the life of the process, so reading the live player costs one pointer read:

```lua
local dom  = (mono_enumDomains())[1]
local base = mono_class_getStaticFieldAddress(dom, playerManagerClass)
-- 'instance' is at static offset 0x0
local pm   = readQword(base + 0x0)     -- always the CURRENT PlayerManager
```

Verified: the static read returned `0x1E7CD48E540`, identical to the heap-scanned
result. Every subsystem hangs off it:

| Field | Offset | Type |
|---|---|---|
| **`health`** | `0xA0` | `PlayerHealth` |
| **`animator`** | `0x30` | `Animator` |
| `movement` | `0xC8` | `PlayerMovement` |
| `fight` | `0x90` | `PlayerFight` |
| `inventory` | `0xB0` | `PlayerInventory` |
| `jumping` | `0xB8` | `PlayerJump` |
| `swordController` | `0x108` | `SwordController` |
| `_timeManager` | `0x138` | `TimeManager` |

18 classes expose a static instance, including `GameStateManager`, `SoundManager`,
`InventoryManager` and `TriggerManager`. Check for one **before** ever scanning.

### 2. Scene objects: the StateBehaviour registry

`CameraController` and `ShardSceneManager` have no statics, but both derive from
`StateBehaviour`, and the scene registers every `StateBehaviour` in one array:

```
TriggerManager.instance +0x38 -> _sceneStateManager (SceneStateManager)
                        +0x18 -> IdentifierObjects  (StateBehaviour[])
```

Mono array layout on 64-bit: **`+0x18` = length, `+0x20` = first element**.
An object's class is `readQword(readQword(obj))` (vtable → klass).

Walking ~34,000 entries and comparing class pointers takes **~440 ms** — bounded
and predictable. Full resolve including metadata is ~4–7 s, with no CE dialog.

### 3. Validate pointers by CLASS, not by value

```lua
if classOf(cached) == expectedClass then  -- honest liveness check
```

A freed Mono object **keeps its old field bytes**, so value-based sanity checks
pass on dead objects. Observed directly: a dead `PlayerHealth` still reported
`maxHealth = 6` and a dead `CameraController` still reported a plausible
`zoomSize` of 10.5, while every write vanished into unused memory.

---

## Camera — the game uses TWO camera systems

Which one is live **depends on the scene**, and this is the single most confusing
thing about the game. Getting it wrong looks exactly like "my write did nothing".

Check first: `Camera.main.orthographic`. `1` = system 1, `0` = system 2.

### System 1 — orthographic scenes

An active `CameraController` drives an orthographic camera.

| Field | Offset | Stock | Notes |
|---|---|---|---|
| **`orthographicSizeAddition`** | `0xEC` | 0.28125 | additive — **larger = wider** |
| `zoomSize` | `0x188` | ~5.15 | resulting size; read to confirm |
| `isActive` | `0xE8` | 1 | **0 means this scene is system 2** |
| `zoomStartPosition` | `0x190` | ~4.28 | base size |

Scale against a base of ~4.3: `0.28` stock, `2` modest, `5` wide, `10` very wide.
`F2CameraZoom(8)`.

### System 2 — perspective scenes (Cinemachine)

Here `CameraController` still exists but `isActive == 0`, so writing
`orthographicSizeAddition` does nothing. Writing `Camera.main.fieldOfView` is also
futile: **Cinemachine reasserts the lens every frame** (observed: 70.0 reverted to
2.2 within a second).

The source is the virtual camera lens, reachable from a **static** root:

```
CinemachineCore.sInstance                    (STATIC field)
  +0x18  mActiveCameras : List<CinemachineVirtualCameraBase>
           +0x10 _items (array)   +0x18 _size
  each vcam +0x1C0 = m_Lens.FieldOfView
```

`LensSettings.FieldOfView` is reported at `0x10` by metadata; that includes the
**boxed-struct header**, so embedded in the vcam it lands at `+0x1C0`
(`m_Lens@0x1C0`). `OrthographicSize` follows at `+0x1C4`.

Gameplay FOV is **~2.2** — a telephoto rig — so absolute values are meaningless
and a **multiplier** is the portable knob. `F2FOV(1.6)` widens by 60%. Base values
are cached per camera, so repeated calls never compound; `F2FOV(1.0)` restores
stock. 21 virtual cameras were active in one scene, with FOVs of 2.2, 27, 30 and
41.3 — the multiplier scales whichever is live.

Cinemachine rewrites the lens every frame, so the keeper re-applies it each tick
(~20 float reads, negligible).

---

## Movement speed

`Animator.speed` **is the only lever** — verified by sweeping every subsystem
hanging off `PlayerManager` for float fields named speed/velocity/scale. There is
no `walkSpeed` or `runSpeed` anywhere:

- `PlayerMovement` has only turn speeds plus `movementSpeedMultiplier@0xA8`, which
  is **analog-input magnitude** (read as 0.35 while walking), recomputed every
  frame — writes to it are pointless.
- `PlayerSlide.moveSpeed` is 0.0; the rest are dodge/knockback/UI speeds.
- `NavMeshAgent.speed` does nothing (pathfinding only).

**Scale matters more than expected: 2.0 is barely perceptible.** It genuinely
applies — `get_speed` confirms 2.0 and it holds with the keeper off — but on a walk
cycle it does not read as a speed boost. `3.0` is clearly faster; `5.0` is very
fast. If someone reports "speed isn't working", verify with a deliberately extreme
value before assuming the write failed.

Tune live with `F2AnimSpeed(3)`. It writes the global `F2_ANIM_SPEED`, which is
what the keeper enforces — otherwise the keeper would restore the old config value
and silently undo the change within one tick.

An alternative global 2× is `TimeManager` (`PlayerManager+0x138`):
`setCustomDefaultTimeScale@0x1C = 1`, `customDefaultTimeScale@0x20 = 2.0`. That
speeds enemies too.

---

## The keeper — why a freeze is not enough

**Level changes reset the camera zoom and the animator speed**, and neither can be
held by a cheat-table freeze:

- **Animator speed is a native property.** There is no address to freeze; it must
  be re-invoked via `mono_invoke_method`.
- **Objects are recreated per scene.** `CameraController` was observed moving from
  `0x1ADD6DF71C0` to `0x1ADD6DF7C40`, and `PlayerHealth` from `0x1AE204ECA80` to
  `0x1ADDA507540`.

`F2StartKeeper()` runs a CE timer that re-resolves and re-applies. It is started
automatically when `KEEP_APPLIED = true`.

### The bug worth remembering

The first keeper validated **only `PlayerHealth`** and re-resolved when that went
stale. But `PlayerManager.animator` is swapped on scene changes **independently**.
With `PlayerHealth` still valid, no re-resolve happened, so the cached animator
pointer went stale (`0x1ADD8873F20` while the live one was `0x1AF35B72140`) and
every speed write landed on a **dead object**. `get_speed` returned 0 and the
player moved at normal speed.

The tell was the fix counter: **22,456 fixes** in ~3.5 hours, i.e. almost one per
tick. A keeper that "succeeds" every single tick is not succeeding — it is fighting
something it can never win. Check the counter when a keeper appears to work but
the effect is absent.

### Why content-based pointer validation does not work

The next attempt validated each cached pointer by reading its fields and checking
for sane values. **That also failed**, and the reason matters: a freed Mono object
**keeps its old bytes** until the memory is reused. Observed directly —

| Pointer | Cached (dead) | Live |
|---|---|---|
| `PlayerManager` | `0x1AF3D03DA80` | `0x1AF082C5380` |
| `CameraController` | `0x1ADD6DF7700` | `0x1ADD6DF7540` |

The dead `PlayerHealth` still reported `maxHealth = 6`, and the dead
`CameraController` still reported a plausible `zoomSize` of 10.5. Every sanity
check passed while the loadout was written into garbage. **In a GC'd heap, only a
fresh instance lookup proves a pointer is live.**

### And why re-resolving every tick is worse

Re-enumerating instances on every tick fixed correctness and **broke Cheat Engine**
twice — the second time triggering CE's *"mono operation is taking longer than
expected"* dialog mid-session. CE timers run on the **main thread**, the same one
that serves the MCP bridge and the GUI. Heap scans take seconds, so ticks piled up
and starved everything.

**The fix was not a better timer — it was removing the scans.** See
*Resolution: static fields, never heap scans* above. The keeper now reads the live
player through the fixed static slot (a handful of pointer reads, measured at
**0 ms**) and validates the camera by class pointer. `KEEP_APPLIED = true` is safe
again.

If CE ever does go sluggish, run **`f2_stop.lua`**. If it is too unresponsive even
for that, restart CE — timers do not survive a restart and nothing here is
persistent.

Diagnostics:

```lua
print(F2_KEEPER_FIXES, F2_KEEPER_RESOLVES)
print(F2.animator == readQword(F2.playerManager + 0x30))  -- must be true
```

---

## Gotchas

**Objects move between scenes.** `PlayerHealth` was at `0x1AE204ECA80` and later
resolved to `0x1ADD8751A80` within the same session. Frozen cheat-table entries
then point at dead memory. **Re-run the script after a scene change**, not just
after a restart.

**Two instances of most player components.** `PlayerHealth` and `PlayerMovement`
each have 2; one is the prefab template with zeroed values. Filter on
`maxHealth > 0` rather than taking index 1.

**Native properties can't be frozen.** Animator speed and NavMeshAgent speed are
native-backed with no writable managed field, so they have no address for a
cheat-table entry. They must be re-applied by invoking the setter — which is what
`F2AnimSpeed()` does.

---

## Reverse-engineering notes (for agents)

The technique this game required that the other Mono titles didn't:
**`mono_invoke_method` to call managed property setters.** When a value is
native-backed (`Animator.speed`, `NavMeshAgent.speed`) there is no field to poke,
but the managed getter/setter can be invoked directly:

```lua
local dom = (mono_enumDomains())[1]
local set = findMethod(animImg, "Animator", "set_speed")
mono_invoke_method(dom, set, animatorInstance, { 2.0 })
```

Calling the *getter* across all instances of a class is also an excellent way to
identify which instance is the player, without any memory scanning.

Sequence that worked here:
1. `mono_enumAssemblies` → note there is no `Assembly-CSharp`; target `Figment`
2. Search class names for `health` / `player` → `PlayerHealth`
3. Dump all 77 fields with values → `isInvulnerable`, `health`, `maxHealth` are
   immediately obvious from their names
4. For movement, follow `PlayerManager.animator` rather than searching for a
   speed field — there isn't one

**Zero memory scans were needed for this game.**
