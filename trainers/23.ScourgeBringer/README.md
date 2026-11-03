# ScourgeBringer — cheat table

**Architecture: native AOT-compiled binary.** No .NET runtime, no garbage
collector, plain 64-bit pointers — so a conventional Cheat Engine **pointer path
works and survives restarts.** This is the simplest of the three games.

---

## Quick start

1. Launch ScourgeBringer.
2. Open Cheat Engine, attach to `ScourgeBringer.exe`.
3. `File → Load` → **`ScourgeBringer.CT`**.

Every value resolves immediately. **No scanning, no scripts, no setup.** The
addresses are anchored to the module, so they work after any restart.

---

## Files

| File | Purpose |
|---|---|
| `ScourgeBringer.CT` | Cheat table — 9 stats on one pointer path |

---

## Values

Base path: **`[[ScourgeBringer.exe+1F57F98]+8]`** (the player object)

| Offset | Stat | Type | Notes |
|---|---|---|---|
| `+0xBC` | HP | int32 | |
| `+0xC0` | Max HP | int32 | |
| `+0xC8` | *unidentified* | int32 | was 3 |
| `+0xCC` | Blood Shards | int32 | currency |
| `+0xF8` | Reload Speed buff | int32 | stacks, **5% each** |
| `+0xFC` | Sword Damage buff | int32 | stacks, **5% each** |
| `+0x100` | Gun/Ranged Damage buff | int32 | stacks, **5% each** |
| `+0x104` | Critical Rate buff | int32 | stacks, **5% each** |
| `+0x108` | *unnamed* buff | int32 | stacks, **7% each** — label TBD |
| `+0x168` | Skill Points | int32 | persists between runs |
| `+0xD8`, `+0xE4`, `+0xEC`, `+0xF0` | *unidentified* | int32 | 1, 10, 9, 10 |

All values are plain `int32` — no tagging or scaling. Buff stacks have **no
observed cap**: 100 stacks on a 5% buff gives +500%.

Per-stack percentage is a property of the buff *type*. `+0x108` is 7% per stack
while the others are 5%, so 20 stacks gives +140% there but +100% elsewhere.

---

## Gotchas

**The pointer path follows the *current* player object.** When a run ends and a
new one starts, the object address changes but the static anchor still resolves
correctly — you will simply see fresh values (HP 7/7, shards 0, buffs 0). That is
correct behaviour, not a broken table.

**Buffs reset per run**, as expected. Skill points do not — they are
meta-progression and persist.

**`capacite_seuilMax` equivalents are character-specific.** Skill max was 4 on
the knight and 5 on the wizard, so don't assume constants across characters.

---

## Reverse-engineering notes (for agents)

Confirming it is native, not managed: the full 99-module list contains **no
`coreclr.dll`, no `mono*.dll`, no `clr.dll`**, despite `SDL2.dll` suggesting
FNA/MonoGame. A 33 MB single executable with everything statically linked.

How the pointer path was built:

1. Scan for the value. HP is `int32` — the float scan died at zero while the int
   scan went 58,673 → 4 after a single damage event.
2. Set a **hardware data breakpoint** on the confirmed address. Every hit showed
   `RCX = 0x28F1D547460`, giving the player object base with HP at `+0xBC`.
3. Scan for that address as a **qword**. Result: 8 pointers — 7 on the stack
   (useless) and one real heap pointer.
4. Nothing pointed *directly* at that heap pointer, so scan a **range** — qword
   between `target-0x800` and `target` — to find pointers into the containing
   object.
5. That surfaced a table of pointers **inside the module** (`0x7FF75A1A7DC8`–
   `0x7FF75A1A7F98`, module spans `0x7FF758250000`–`0x7FF75A34C000`). The entry at
   `+0x1F57F98` sat exactly 8 bytes below the target, giving the `+8` hop.

Verified across a restart: different PID, entirely different heap addresses, and
the static anchor still resolved to the correct values.

**Values that start at 0 cannot be scanned for.** Both damage buffs began at 0,
so they were found by **struct diffing** — snapshot 448 bytes of the player
object, trigger the buff, re-read and compare. The only skill required is
recognising the position floats at `+0x134`–`+0x13C` as noise, since they change
whenever you move.
