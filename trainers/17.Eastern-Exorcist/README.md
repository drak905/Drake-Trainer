# Eastern Exorcist — trainer script

**Architecture: Unity + Mono.** Everything is found by reading the game's **class
metadata** — real class and field names. No value scanning was needed at all.

---

## Quick start

1. Launch Eastern Exorcist and get into a level.
2. Open Cheat Engine, attach to `EasternExorcist.exe`.
3. `File → Execute Script` → **`ee_resolve.lua`**.

One run resolves every address, applies the loadout, and rebuilds the cheat table
with freezes. Re-run after any restart or if values read wrong.

`EasternExorcist.CT` can be loaded for the entries, but the **`.lua` is the
durable part** — the `.CT` holds live Mono heap addresses that go stale between
sessions.

---

## Files

| File | Purpose |
|---|---|
| `ee_resolve.lua` | **Main tool.** Resolves state, applies loadout, freezes values |
| `EasternExorcist.CT` | Cheat table (~46 entries; addresses valid for one session) |

---

## Config

Top of `ee_resolve.lua`:

```lua
local TAKE_DAMAGE_FACTOR = 0      -- 0 = immune to all damage
local ATTACK_FACTOR      = 10     -- damage output multiplier
local SOUL_REWARD_FACTOR = 10     -- currency gain multiplier
local MOVE_SPEED_FACTOR  = nil    -- nil = leave stock
local LIFE_STEAL_RATE    = nil    -- heal on hit
local FREE_LEVEL_UPS     = true   -- zero the level-up cost formula
local FREE_SKILL_NODES   = true   -- zero skill-node material requirements
local FREE_SKILL_SOUL    = false  -- also zero PriseInSoul / SkillPointCost
local ENEMY_HP_FACTOR    = nil    -- e.g. 0.1 makes all enemies frail
local FREEZE             = true
```

Console helpers:

```lua
EESoul(99999)           -- set currency on every runtime copy
EESkillNodes(true,false) -- zero skill material costs (materials, soul)
EEResolve()             -- re-resolve; returns the info table
EE.props                -- table of AdjustableProp addresses by name
```

Symbols registered: `eeHp`, `eeMaxHp`, `eeEp`, `eeMaxEp`, `eeAttack`,
`eeToughness`, `eeLevel`, `eeSoul`, plus object handles `eeHpObj`, `eeEpObj`,
`eeCharProps`, `eeRuntime`, `eeGameConfig`.

---

## Terminology

This game's naming is why an obvious search finds nothing — **no class contains
the word "Health"**:

| Game term | Meaning |
|---|---|
| **Protagonist** | the player |
| **Unit** | any entity |
| **EP** | stamina bar |
| **Soul** | currency, shown in-game as **"spiritual energy"** |
| **CapacityProp** | generic container for any HP/EP-style stat |

---

## Class map

`CapacityProp` — one instance per stat, self-identifying via its type tag:

| Field | Offset | Type |
|---|---|---|
| `PropValueType` | `0x40` | `ECharPropType`: **1 = HP, 2 = EP** |
| `_propValue` | `0x44` | float — current value |
| `_propFollow` | `0x48` | float — the visual trailing bar |
| `_propCapBase` | `0x54` | float — maximum |

`CharProperties` (live subclass is **`PlayerProperties`**):

| Field | Offset | Type |
|---|---|---|
| `Hp` | `0x10` | `CapacityProp` — used to validate the right instance |
| `_adjustableProps` | `0x18` | `Dictionary<int, AdjustableProp>` |
| `Shield` | `0x28` | `ShieldProperty` |
| `AttackBase` | `0x40` | float |
| `ToughnessBase` | `0x44` | float |

`ProtagRuntimeData` — the game keeps **several copies**:

| Field | Offset | Notes |
|---|---|---|
| `RemainHP` | `0x144` | float |
| `_level` | `0x148` | int32 |
| `_soul` | `0x14C` | int32 — **spiritual energy** |
| `_difficulty` | `0x10C` | int32 |
| `PlayedTime`, `ExSupplies`, `HealedTimes`, `ChapterIndex`, `PageId` | `0x124`–`0x138` | misc |

`ProtagSaveData` mirrors it: `Level@0x164`, `Soul@0x168`.

---

## Skill tree materials

Skill upgrades are gated by **items**, not currency. `SkillNodeData` (274
instances) holds four separate requirements, with transliterated Chinese suffixes:

| Field | Offset | Chinese | Meaning |
|---|---|---|---|
| `UnlockItemAmount` | `0x30` | — | generic item |
| `UnlockItemAmount_CanPian` | `0x34` | 残片 | fragment |
| **`UnlockItemAmount_JieKuai`** | `0x38` | **结块** | **nugget** — "nugget of spirituality" |
| `UnlockItemAmount_JieJing` | `0x3C` | 结晶 | crystal |
| `SkillId` | `0x40` | — | skill id |
| `SkillPointCost` | `0x44` | — | skill points |
| `PriseInSoul` | `0x48` | — | soul cost |

`EESkillNodes(true, false)` zeroes all four material requirements (136 of 274
nodes actually had them) and leaves soul/skill-point costs intact.

**Why zero the requirement instead of granting the items:** the inventory is a
live `Dictionary<int, StoryItem>` (`ProtagRuntimeData.StoryItems@0x40`, with
`StoryItem._count@0x18`). Inserting a new entry means allocating a `StoryItem`
and fixing up hash buckets and chains — fragile and easy to corrupt. Item IDs
seen in play: 4000, 3003, 3004; `GameGlobalConfig.EssenceItemId` is 3000, which
the player did not hold at all.

---

## GameGlobalConfig — singleton
| Field | Offset | Stock |
|---|---|---|
| `PlayerExpBase` | `0x2BC` | 1200 — level-up cost |
| `PlayerExpLinear` | `0x2C0` | 263 |
| `PlayerExpPower` | `0x2C4` | 1.12 |
| `EasyEnemyHpFactor` | `0x1E0` | 0.7 |
| `NormalEnemyHpFactor` | `0x1EC` | 0.85 |
| `HardEnemyHpFactor` | `0x1F8` | 1.0 |
| `NearDeathPercent` | `0x204` | 0.25 |
| `OverSupplyCostBase` | `0x2B0` | 300 |

---

## The modifier system — the best levers in the game

`CharProperties._adjustableProps` maps an `EAdjustPropType` key to an
`AdjustableProp` (`_baseValue@0x20`, `CurrValue@0x30`, `MultiplyMode@0x2C`):

| Key | Name | Key | Name |
|---|---|---|---|
| 0 | HpCapFactor | 11 | **SoulRewardFactor** |
| 1 | HpCapAdd | 12 | MoveSpeedFactor |
| 2 | HpRecoveryAdd | 13 | FatalAttackFactor |
| 3 | EpCapFactor | 14 | DodgeAttackFactor |
| 4 | EpCapAdd | 15 | BlockAttackFactor |
| 5 | EpRecoveryAdd | 16 | AirAttackFactor |
| 6 | StrengthAdd | 17 | FallAttackFactor |
| 7 | ToughnessAdd | 18 | TakeHealFactor |
| 8 | **AttackFactor** | 19 | PotionFactor |
| 9 | **TakeDamageFactor** | 20 | SlaughtAttackFactor |
| 10 | LifeStealRate | | |

`TakeDamageFactor = 0` is true invulnerability — damage is multiplied to nothing
rather than HP being repaired afterwards. Verified in play.

Reading the dictionary: `_entries@0x18`, `_count@0x40`; Mono array data starts at
`+0x20`; each entry is **24 bytes** — `{int hash, int next, int key@+8, ptr
value@+16}`.

---

## Gotchas

**Set `_baseValue`, freeze `_baseValue`, not `CurrValue`.** The game recomputes
`CurrValue` from base plus active buffs — `DodgeAttackFactor` was observed at
`CurrValue` 4.2 against a base of 1.0. Freezing `CurrValue` would cap the stat and
block legitimate buffs. (`TakeDamageFactor` is the exception: both are frozen at 0,
since no buff should ever reintroduce damage.)

**The currency HUD is cached.** It does not re-read `_soul` until something
changes it, so a write appears to do nothing — the display sat at 5248 while
memory held 10000, then jumped to 11352 on the next pickup. **The write was
always working.** Don't chase this as a bug.

**Multiple data copies exist.** `ProtagRuntimeData` and `ProtagSaveData` each have
several live instances. `EESoul()` writes every plausible copy. Most instances are
garbage — pointing into `UnityPlayer.dll`, or holding values like `4294901761` —
so the script filters to instances with a sane level and soul before writing.
Writing unfiltered risks corrupting unrelated memory.

**`findInstancesOfClass` misses the live `CharProperties`** because the real object
is the subclass `PlayerProperties`. Enumerate the subclass, then validate by
checking its `Hp` pointer equals the HP `CapacityProp`.

**Max HP is not fixed.** Level-ups raise it (500 → 999.6 observed), so don't
hardcode it.

**`PlayerExpPower` must stay non-zero.** Zeroing base and linear is enough for
free upgrades; setting the exponent to 0 would make `level^0 = 1` and could yield
a constant cost instead of zero.

---

## Known limits / unresolved

**Unlimited jumps: not achievable by a field write.** The double-jump limit is
enforced by the **animation state machine**, not a counter. Evidence: enumerating
every jump-related method in all 1,835 classes yields only
`BaseAgent.JumpOffCurrentFloor`, `BaseAgent.OnAnimJump` and
`ProtagnistAgent.OnAnimJump` — there is no `CanJump`, `TryJump`, or jump-count
getter. `OnAnimJump` is a *callback from* the animation system.

Ruled out, so don't repeat these:
- field-name search for jump / air / double / extra / remain / fly → only impulse
  strengths (`AnimJumpEvent.GroundBurst`, `AirBurst` = 7.8) and input flags
- freezing `BaseAgent.IsGrounded@0x16C` = 1 → no change
- struct diff of the agent, grounded vs airborne → surfaced `+0x100` / `+0x104`
  (one went 2→0, looking exactly like a counter) but the game rewrites that region
  constantly; `+0x104` read 514 moments after being set to 5
- `ProtagonistConfigure` (23 fields) → no jump count

**Workable substitute:** air mobility *is* writable — `BaseAgent.GravityFactor@0x130`
(0.77 stock), `GameGlobalConfig.AirAcc@0x3D8` (36.0), `AirDamp@0x36C` (0.20).
Dropping gravity to ~0.2–0.3 gives long floaty jumps.

**HP pinned at exactly 50% — unresolved.** After reaching level 30 (max HP grew
500 → 999.647), HP became stuck at `499.823` = `999.647 × 0.5`, with
`CapacityProp._prevPercent` reading `0.5`. Writes to `_propValue`, `_propFollow`
and `ProtagRuntimeData.RemainHP` are all reverted to that figure within a fraction
of a second, and a CE freeze loses the race.

Confirmed *not* the cause:
- `TakeDamageFactor` is still 0.0 (base and curr) — damage blocking never broke
- `PropCapFactor` = 1.0 and `PropCapAdd` = 0 — the cap is not being scaled
- `HpCapFactor` is **absent** from `_adjustableProps` (still only the same 15 keys)
- HP is *stable*, not draining — repeated samples read an identical value

Most likely a curse/debuff imposing a 50% HP ceiling. Next step would be
inspecting the `Buff` class (75 instances, `RemainTime@0x54`) for an active effect
on the player, or tracing the damage/clamp path that writes `_propValue`.

---

## Reverse-engineering notes (for agents)

1. `LaunchMonoDataCollector()`, then `mono_enumAssemblies()` → `Assembly-CSharp`
   (109 assemblies, 1,835 classes).
2. Searching class names for "Health" finds **nothing**. Search **field** names
   instead — that surfaced `ProtagRuntimeData.RemainHP` and `ProtagonistConfigure.Hp`,
   which revealed the "Protagonist" convention.
3. `mono_class_getEnumValues` on `ECharPropType` and `EAdjustPropType` is what
   made the whole stat system legible — the enum names *are* the documentation.
4. The only memory scan in the entire session was for a **pointer** (qword) to the
   HP object, to identify which `CharProperties` was live among three candidates.
   Checking `AttackBase == 95` against the HUD confirmed it.
5. Cross-validation matters: `RemainHP` agreed across `CapacityProp` and two
   independent `ProtagRuntimeData` instances, which is what made the identification
   trustworthy before writing anything.
