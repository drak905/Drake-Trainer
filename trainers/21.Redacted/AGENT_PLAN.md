# REDACTED agent implementation plan

Created: 2026-09-06 (Asia/Bangkok)
Scope: editable spendable currencies, reliable combat controls, and restart recovery.
Status: in progress; development v1.3.0-dev1 adds three-source restart-safe
capture and read-only currency enumeration. Credits HUD and store spending are
verified, including a later `1285 -> 102746` edit confirmed by the user. Two
separate death/autosave/restart tests reset Credits to `0`, including naturally
collected Credits, while the other currencies persisted. The getter capture now
uses the generic currency getter identified by a live Keycodes trace, and its
validator accepts persistent wallets that contain no Credits record. After a
full game and CE restart, however, the user's balance-screen visit did not call
that getter. A bounded value/layout search found and validated the fresh
`14/24` persistent owner, and all four initialized persistent balances matched
the HUD. The next test is a real persistent-currency transaction to identify
the capture/write path. Editable controls remain gated on finding and testing
the appropriate game-managed update paths.

## Start here

Read `CHECKPOINT.md`, this plan, `README.md`, and `redacted_live_trainer.lua`
before changing the trainer. Keep all game-specific work in `redacted_game`.
Canonical source is `redacted_live_trainer.lua`; rebuild `Redacted.CT` using
`build_table.ps1`. Update the checkpoint after each completed modification or
handoff, distinguishing memory evidence from HUD, spending, and restart tests.

The packaged release is v1.2.1. No Damage is verified. One-Hit Kill is disabled
because its broad non-player filter blocked room progression. The 100x award
hook changes collection/progression counters; it is not a spendable-wallet
multiplier.

## Latest evidence superseding the older checkpoint

In PID 22080, the record below followed real Credits gains
230 -> 245 -> 255 -> 265. Three other candidates were stale or reused memory.
The containing owner array also held Contraband 30, Keycodes 10, and Security
IDs 5, alongside non-currency items.

| Discovery | Current-session value |
|---|---|
| Module base | `0x7FF75EFB0000` |
| Inventory owner | `0x17837C346F0` |
| Owner + `0x218` | Array pointer `0x17836C5CD00` |
| Owner + `0x220` / + `0x224` | Count 14 / capacity 24 |
| Record stride | `0x110` |
| Record + `0x08` | Eight-byte FName key |
| Record + `0x10` | Signed 32-bit quantity |
| Record + `0x30` | Observed CurrencyVirtualData pointer |
| Credits quantity address | `0x17836C5D9D0` |
| Actual quantity write | `0x7FF760C87F73`: `mov [rcx+10],r8d` |
| Instruction bytes | `44 89 41 10` |

The hardware breakpoint reported the next instruction at `0x7FF760C87F77`.
At the writer, RCX was the record, RBX/RDI the owner, RAX the old quantity,
R8D the new quantity, and R12D/R15D the positive gain in the observed hits.
These register roles are observations, not a proven contract for every path.
All four temporary breakpoints were removed.

At the user's request, Credits was changed from 265 to **103456**, after
validating PID, owner array, Credits key, and asset pointer. Memory readback was
103456. The HUD later showed `103556`, and purchases of `100`, `200`, and `50`
reduced it to `103206` as expected. After death/respawn autosave and a game
restart, the HUD showed `0`. A later naturally collected Credits balance also
reset to `0`, establishing that this is the normal run-scoped lifetime rather
than evidence of a failed save. In a subsequent run, a validated balance was
changed from `1285` to `102746`; the user confirmed the HUD and spent from it.

Every absolute address above is temporary. Never reuse it after a restart or
assume an array remains allocated after an inventory change.

## Phase 1 — Validate Credits and generalize currency access

1. Confirm the latest Credits edit in the HUD. If the HUD is stale, observe a
   natural pickup/refresh and inspect the normal notification path. Verify a
   purchase when the store becomes accessible. Do not call a raw memory write
   successful merely because its readback matches.
2. Build a read-only currency enumerator from the validated owner. Read the
   array pointer/count each time; validate bounds, stride, resource identity,
   and quantity. Ignore non-currency records. Handle multiple matching records
   explicitly: establish whether the UI sums stacks before assigning totals.
3. Resolve all seven identities using names/metadata and validated assets.
   The indices below are discovery aids for this build, not guaranteed stable
   across updates or restarts.

| Currency | Internal resource name | Observed FName index |
|---|---|---|
| Credits | `Credits` | `0x2DBDE` |
| Keycodes | `BEV_Keycodes` | `0x2DBE3` |
| Contraband | `BEV_Contraband` | `0x2DBEA` |
| Electronics | `BEV_Electronics` | `0x2DBFA` |
| Security IDs | `BEV_SecurityID` | `0x2DBF2` |
| Souvenirs | `BEV_RivalToken` | `0x2DC0B` |
| Samples | `BEV_BossToken` | `0x2DC03` |

4. Implement a shared set-currency operation using a verified setter or the
   validated authoritative record and its normal refresh behavior. Accept
   non-negative whole numbers within the game's supported bounds; reject
   overflow and invalid pointers. Record the previous value for recovery.
5. Treat absent currencies separately from zero-valued existing records. Show
   an unavailable/uninitialized state until a legitimate first pickup or a
   proven game-managed insertion path creates the record. Never append bytes
   to a TArray manually or fabricate UObject/assets.
6. Test each currency individually: before value, requested value, readback,
   HUD refresh, spending when available, and natural autosave/reload. Record
   untested currencies honestly rather than marking all seven complete.

Live result for step 1: HUD display and three purchases passed in PID `22080`.
In PID `28412`, the update hook captured an owner whose currency array was
empty. The resolver now reports this as `resolver waiting` and requires at
least one validated currency record before reporting ready. A natural pickup
produced HUD/resolver Credits `30`, and the gain writer showed
`10 -> 20 -> 30`; death/autosave/fresh load reset it to `0` while the
persistent currency records survived. Do not promise Credits persistence
across runs. The later `1285 -> 102746` current-run edit also passed HUD and
spending verification.

Do not edit the save file directly. A previous save edit was rejected as
corrupted and restored. Do not invoke native game functions from CE-created
remote threads; a prior attempt crashed the game. Any future setter invocation
must use a verified game-thread path with valid arguments and lifecycle.

## Phase 2 — Make the cheat table the normal control surface

Provide one activation entry with clear child groups:

- Currencies: seven current balances and editable desired values, with an
  explicit Apply action and status/error feedback. Re-resolve records when
  applying; do not freeze stale heap addresses.
- Combat: No Damage toggle; One-Hit Kill toggle only when repaired and tested.
  Until then keep One-Hit Kill disabled and visibly marked experimental.
- Collection/progression: existing multiplier, accurately labeled with its
  actual effect. Implement a separate wallet gain multiplier only if requested
  and verified at the authoritative wallet update path.
- Status: attached process, build compatibility, owner resolved/pending,
  per-currency availability, and last operation result.

Preserve the verified player No Damage branch. Repair One-Hit Kill by tracing
a normal player attack to identify actual enemy targets and damage source.
Replace the broad 'owner is not player' filter. Validate normal enemies,
multi-stage enemies/bosses, scripted actors, room clear, and progression before
enabling it by default or calling it safe.

For every hook, validate complete original instructions, allocate a reachable
code cave, preserve required registers/flags, and restore owned patches on
disable. Install cleanup transactionally and handle partial setup failure.
Never free a cave while a live patch still points into it. Tie runtime state
to process identity so cleanup cannot write old bytes into a newly attached
process. Remove diagnostic breakpoints promptly after collecting evidence.

## Phase 3 — Resolve addresses and restore preferences after restart

Distinguish two needs: finding the new runtime objects and restoring the user's
chosen settings. Saving heap addresses solves neither.

1. Derive a unique, validated module code signature for the real inventory
   update routine discovered above. Disassemble its surrounding function and
   prove the owner relationship. Also investigate a stable singleton/root or
   module-relative pointer chain that can resolve the owner immediately.
2. Prefer a validated root/pointer resolver. If only a capture hook is reliable,
   capture the owner from normal game execution and expose 'waiting for first
   inventory event' until available. Document the required pickup/menu action.
3. On activation, validate the attached Shipping process and build, resolve
   code once, resolve resource identities, and find or capture the current
   owner. Validate the owner and array anew after scene/run transitions.
   Any timer should do only cheap pointer checks; never full heap scans.
4. Save user preferences in a small versioned settings file beside the toolkit,
   or an equivalent clearly documented CE mechanism. Persist toggles,
   multiplier, and explicitly chosen currency targets; never persist PIDs,
   heap pointers, or unverified object addresses as reusable state.
5. Make restoration behavior explicit: restore combat/multiplier preferences
   after successful activation. Let the user opt into applying saved currency
   targets once the wallet resolves. Default to preserving the game's saved
   balance; do not silently reset purchases on every timer tick or activation.
6. Keep settings parsing bounded and non-executable, validate values/schema,
   and save atomically. A portable table/settings path must be resolved without
   hardcoded developer paths. Document where preferences are stored and how
   to reset them.
7. On a changed or unsupported build, report a useful compatibility error and
   leave affected features unpatched. Avoid expensive rescanning loops.

## Acceptance tests and delivery

- All seven currencies have independent, clearly labeled controls. Each
  tested currency matches HUD and spending; unavailable types report why.
- No Damage works across scene transitions. One-Hit Kill remains disabled
  until enemy death and room progression both pass testing.
- Disabling restores original instructions and removes owned temporary
  resources. Re-enabling recreates working controls without duplicate records.
- Restart the game, restart CE, attach, load the table, and activate it: code
  and inventory addresses resolve without a manual value scan. Repeat in a
  second fresh process and across a scene/run transition.
- Preferences restore according to the documented policy, including currency
  target opt-in; invalid settings fail safely and visibly.
- Rebuild the CT from canonical Lua, validate its contents and actual CE
  activation, then update README restart instructions and CHECKPOINT with
  evidence, limitations, release version, and next unresolved work.

Suggested order: trace a natural persistent-currency transaction and capture
its owner/write path -> implement and test game-managed setters with separate
run-scoped/persistent policies -> seven currency controls -> restart/settings
workflow -> repair and validate One-Hit Kill.
Keep the existing working No Damage feature available throughout.
