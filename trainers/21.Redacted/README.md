# REDACTED — plug-and-play Cheat Engine trainer

This toolkit targets the 64-bit Unreal Engine process
`Redacted-Win64-Shipping.exe`. The current table is development version
1.3.0-dev1; version 1.2.1 remains the last fully gameplay-verified release.
It provides verified No Damage and 100x Collected Items hooks and retains an
experimental One-Hit Kill
control, disabled by default after the broad non-player health filter was found
to prevent room progression. Player-health decreases are blocked while healing
remains normal. The multiplier affects positive collection/progression awards;
live testing shows that it does not multiply the spendable wallet balance.

## Quick start

1. Start **REDACTED** and enter the playable game world.
2. Start Cheat Engine.
3. Attach Cheat Engine to `Redacted-Win64-Shipping.exe`. Do **not** attach to
   the small `Redacted.exe` launcher.
4. Load `Redacted.CT`.
5. Check **REDACTED Trainer - Activate**.
6. Leave **REDACTED: No Damage** set to `Enabled`, leave
   **REDACTED: One-Hit Kill** set to `Disabled`, and leave
   **REDACTED: Collected Item Multiplier** set to `100`.
7. The development currency group may initially say it is waiting. A natural
   currency gain or spend lets the corresponding resolver hook capture the
   current owner. A permanent-upgrade balance screen alone did not trigger the
   generic getter in the first clean-restart test. `Resolver waiting` means no
   validated current owner has been captured yet. Balances remain read-only
   while the persistent update path is investigated.

The MCP bridge and Codex are not required for normal use after the table has
been created.

## Using the trainer after restarting

Repeat the Quick start steps each time the game or Cheat Engine is restarted.
If the game is restarted while Cheat Engine remains open, first uncheck the
activation entry, attach to the newly created
`Redacted-Win64-Shipping.exe` process, and then check the activation entry
again. Process IDs, module bases, and heap addresses are intentionally not
stored in the table.

## Controls

| Entry | Default | Behavior |
|---|---:|---|
| `REDACTED: Currencies` | Waiting | Shows resolver status, then current, unavailable, or resolver-waiting state for all seven currencies. Development/read-only. |
| `REDACTED: Wallet resolver captures` | Read-only | Counts calls that supplied a validated candidate wallet owner during this activation. |
| `REDACTED: No Damage` | Enabled | Prevents player-health decreases; healing still works. |
| `REDACTED: One-Hit Kill` | Disabled | Experimental broad filter; enabling it can prevent room progression. |
| `REDACTED: Collected Item Multiplier` | 100 | Multiplies positive collection/progression awards, not spendable wallet balances. Set to 1 for normal gains; accepted range is 1–1000. |
| `REDACTED: Multiplied Item Awards` | Read-only | Counts positive award calls handled in this activation. |
| `REDACTED: Last Base Item Amount` | Read-only | Shows the most recent quantity before multiplication. |
| `REDACTED: Last Multiplied Item Amount` | Read-only | Shows the quantity sent to the inventory maps. |
| `REDACTED: Blocked Health Decreases` | Read-only | Counts health decreases blocked in the current activation. |
| `REDACTED: One-Hit Kills` | Read-only | Counts non-player health decreases forced to zero in this activation. |
| `REDACTED: Last Enemy Health Before Hit` | Read-only | Shows the target health immediately before the last forced kill. |
| `REDACTED: Last Enemy Health After Normal Damage` | Read-only | Shows the health the last hit would have produced without One-Hit Kill. |
| `REDACTED: Last Player Health` | Read-only | Displays health after the hook has observed the player component. |

## Files

| File | Purpose |
|---|---|
| `Redacted.CT` | Ready-to-use Cheat Engine table. |
| `redacted_live_trainer.lua` | Canonical trainer source embedded in the table. |
| `build_table.ps1` | Rebuilds `Redacted.CT` from the Lua source. |
| `CHECKPOINT.md` | Agent handoff, verification evidence, and current status. |

## Implementation and safety

The table AOB-scans a unique health-write sequence at activation and validates
the original instruction bytes before patching. The health component's outer
object must match the player's module-relative vtable, preventing the shared
health setter from affecting enemies or other actors.

For the player, the hook substitutes the existing health value for a proposed
decrease before executing the original write. The experimental One-Hit Kill
branch changes a proposed decrease on any owned non-player health component to
zero, but this filter is too broad for normal play and is disabled by default
in version 1.2.1. Healing and unchanged/increased health pass through both
branches. The hook also saves and restores `RAX` and `RFLAGS`; the flags are
consumed by a later conditional branch and therefore must remain unchanged.

The collected-item hook intercepts the shared native positive-award function.
Its `R8D` argument is the incoming quantity used by collection/progression
maps. The function exits for zero or negative quantities, and the hook
multiplies only positive values. Telemetry verified that a base award of `10`
became `1000` on this path. The spendable Credits HUD increased by only `10`
during the same event, proving that this hook does not multiply wallet funds.

The development currency resolver captures candidates from the uniquely
identified spend, positive-update, and generic currency-getter routines without
changing their results. The generic getter was identified through a live
Keycodes access trace, and its validator works even when the current wallet has
no Credits record. The first clean-restart balance-screen test did not execute
that getter, so a natural persistent-currency transaction is still required to
establish an automatic capture path. The resolver prefers the highest-priority candidate containing at least
one validated currency record. Once captured, a bounded one-second check
validates the owner array and each recognized currency record before updating
read-only table values. Missing records display as unavailable; an owner with
no validated records displays as resolver waiting. The user confirmed the
edited Credits balance in the HUD and completed `100`-, `200`-, and
`50`-Credit purchases with the expected balance changes. The spend hook
captured the final purchase and displayed `103206` without a diagnostic seed.
After a death/respawn autosave and game restart, the HUD returned to `0` and
the captured wallet contained only persistent currencies. A natural pickup subsequently
initialized the wallet and the resolver matched HUD Credits `30`, but a clean
death/autosave/restart also reset those natural Credits to `0`. The other
currencies remained and were found in a validated wallet without a Credits
record. Credits is therefore run-scoped in this game, while Keycodes,
Contraband, Security IDs, Samples, and similar resources are persistent.
In the later run, a validated Credits record was changed from `1285` to
`102746`; the user confirmed `102746` in the HUD and successfully spent it in
the store. This validates current-run editing without changing the currency's
run-scoped lifetime.
Editable Apply controls are withheld until the correct game-managed paths are
identified and tested according to those separate lifetimes.

Unchecking the activation entry restores the original eight-byte health write,
five-byte item-award entry, seven-byte currency-getter instruction, and five-byte
positive-update and spend prologues. It removes the allocated symbols and controls and
releases all three code caves. No debugging breakpoints are required during
normal use.

## Compatibility note

The health-write, item-award, generic currency-getter, positive-update, and spend
signatures are relocatable across restarts, while the player and currency-asset vtables are stored as
module-relative offsets for this verified game build. A game update may change
them. Activation validates every original instruction and stops with an error
rather than patching an unexpected location.

For educational and single-player use only.
