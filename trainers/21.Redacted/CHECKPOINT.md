# REDACTED trainer checkpoint

Last updated: 2026-09-06 15:39:49 +07:00

Read this file before continuing work on REDACTED. Update it after every
completed game modification. Runtime addresses and PIDs below are diagnostic
evidence only and must not be reused after restarting the game.

## Project wrap-up (2026-09-06 15:39 +07:00)

- The user considers work on REDACTED complete and is moving to another game.
  Preserve this file as the handoff if development resumes.
- The trainer was stopped cleanly in PID `24524`. All five owned patches were
  restored to their original instruction bytes: health, collected-item award,
  currency getter, currency gain/update, and currency spend. `RDT` is nil, all
  checked trainer symbols are absent, all dynamic `REDACTED:` address-list
  records were removed, and active breakpoint count is zero.
- The game and Cheat Engine were left running and attached; only the REDACTED
  trainer was deactivated.
- Final development artifact remains `1.3.0-dev1`; `1.2.1` remains the last
  fully gameplay-verified release. The experimental One-Hit Kill feature stays
  disabled by default and should be treated as unsafe: it can prevent room
  progression. The source-filter, XMM8 delta, and minimum-health findings in
  the latest session update remain unresolved.
- Final direct live-memory adjustments were validated at write time: Souvenirs,
  Electronics, and current-run Credits each read `120000`. Persistence of the
  two persistent currencies was not tested; Credits is run-scoped and resets
  when the run ends. These values are game state rather than trainer-owned
  memory, so stopping the trainer did not revert them.

## Latest session update (2026-09-06 14:36 +07:00)

- User reached a locked room after defeating a Rival and receiving one
  Souvenir in a new run within the same game process, PID `24524`.
- Live inspection found No Damage `1`, One-Hit Kill `1`, and `68` forced
  health updates since the current trainer activation (not a per-room count).
  The last intercepted update was `125 -> 105`, forced to zero. Its captured
  component was already freed/reused, so the blocking actor is not identified.
- Live setter disassembly revealed an additional confirmed hook inconsistency:
  native code copies proposed health from XMM6 to XMM8 immediately before the
  hook; the hook changes XMM6 only. The later callback therefore receives the
  original health delta (e.g. `-20`) alongside forced health zero. The hook also
  runs after conditional minimum-health handling whose minimum constant is
  `1.0`. These are candidate causes of encounter failure, not proof of the
  particular door's cause. A player-source filter alone does not fix them.
- Corrected diagnostic RVAs from the live module base `0x7FF75EFB0000`:
  setter entry `0x1F14670`, fifth-argument load `0x1F1475E`, health write
  `0x1F1476A`. The older `0x1F13670` / `0x1F1375E` / `0x1F1376A` entries
  below are off by `0x1000`; use signatures and current disassembly.
- At the user's request, re-enumerated the current wallet and changed its sole
  validated initialized Souvenirs record from `1` to `120000`. Runtime owner
  `0x1DFCA5C3F10`, array `0x1E05F374D80`, count/capacity `16/24`, quantity
  address `0x1E05F375D80`. Revalidated FName `0x2DC0B`, number zero, asset
  `0x1DF59944600`, and asset vtable `module+0x5A937B8` immediately before
  writing. Direct readback and the refreshed trainer mirror both show `120000`.
  No raw records were inserted. All addresses are temporary.
- HUD/spending and save/restart persistence of edited Souvenirs remain pending.
  No trainer code or controls changed; breakpoint count is zero. This checkpoint
  is the only file changed. The user plans to restart the run and pause before
  combat for diagnostic tracing; no trace has been armed yet. Capture target
  identities, protection state, and callback behavior before any proposed fix.
- The user naturally received `20` Electronics, creating the previously absent
  wallet record. At the user's request, re-enumerated the current wallet and
  changed the sole validated Electronics record from `20` to `120000`. Runtime
  owner `0x1DFD4ACA180`, array `0x1DFDC9A3400`, count/capacity `16/24`,
  quantity address `0x1DFDC9A4400`. Revalidated FName `0x2DBFA`, number zero,
  asset `0x1DF59944C00`, and asset vtable `module+0x5A937B8` immediately before
  writing. Direct readback and the refreshed trainer mirror both show `120000`.
  No raw record was inserted; breakpoint count remains zero. These addresses
  are temporary. HUD/spending and save/restart persistence remain pending.
- At the user's request at `15:16 +07:00`, re-enumerated the current run wallet
  and changed its sole validated Credits record from `782` to `120000`. Runtime
  owner `0x1E005515AA0`, array `0x1DFCA4FCD00`, count/capacity `18/24`, and
  quantity address `0x1DFCA4FDE10`. Revalidated FName `0x2DBDE`, number zero,
  the currency asset, and asset vtable `module+0x5A937B8` immediately before
  writing. Direct readback and the refreshed trainer mirror both show `120000`;
  breakpoint count remains zero. These addresses are temporary. Credits remains
  run-scoped and is expected to reset when the run ends; HUD and spending
  confirmation are pending.

## Current release

- Version: `1.3.0-dev1` development table; `1.2.1` remains the last fully
  gameplay-verified release
- Features: No Damage; 100x Collected Item/progression awards; experimental
  One-Hit Kill disabled by default; read-only seven-currency resolver and
  balance display
- Status: development table built and lifecycle-tested. HUD/spending, a full
  game plus Cheat Engine restart, and signature-based hook activation are
  verified. Live tests and published gameplay
  descriptions confirm Credits is run-scoped and resets when a run ends, while
  the other currencies fund persistent upgrades and survive future runs. The
  persistent wallet is now automatically captured by the validated spend hook
  in the current session; restart/scene-transition coverage and a non-spend
  capture path still need verification. A one-bullet player-damage trace has
  now identified a strong fifth-argument player-source discriminator, but the
  safer One-Hit Kill filter is not yet implemented or gameplay-verified
- Target: `Redacted-Win64-Shipping.exe` (64-bit Unreal Engine)
- Incorrect launcher target: `Redacted.exe`

## Immediate handoff state (2026-09-06 13:29 +07:00)

- Game and Cheat Engine/MCP were both freshly restarted. CE is attached to
  `Redacted-Win64-Shipping.exe`, PID `24524`.
- `Redacted.CT` v1.3.0-dev1 is loaded and active with 21 records. The current
  live controls read No Damage `1`, One-Hit Kill `0`, and collected-item
  multiplier `100`. One-Hit Kill had been re-enabled during the failed-room
  test but was already back at `0` when the player-gun trace was prepared; the
  packaged default remains `0`.
- The user clarified that One-Hit Kill worked for several rooms, then a later
  room remained locked after gunfire killed every visible enemy. Read-only
  inspection first found `17` forced events and later `56`; the latest normal
  `100 -> 72` proposed health update was forced to zero. Its captured component
  had already been freed/reused, with the `+0x20` outer field first becoming
  `0x30` and later `0x7FFFFFFF7FFFFFFF`. The hook still classifies targets only
  as "not the player," so the delayed failure is consistent with the first room
  that contains a scripted, shield, temporary, or multi-stage encounter actor.
  No live toggle or code was changed during this diagnostic, and breakpoint
  count is zero.
- The user-reported HUD balances are Contraband `120`, Keycodes `25`,
  Electronics `0`, Security IDs `20`, Samples `4`, Souvenirs `0`, Credits `0`.
  The bounded resolver independently matches every initialized record:
  Contraband `120`, Keycodes `25`, Security IDs `20`, Samples `4`. The other
  three types are absent records, which the CE table labels unavailable rather
  than assuming an initialized zero.
- Current validated persistent owner: `0x1DF0166C4F0`; array
  `0x1DFCDF6E680`; count/capacity `14/24`. This runtime address was initially
  seeded in `redWalletGetterCandidate`; after the confirmed Contraband store
  purchase, the real spend hook captured the same owner and the resolver moved
  to source `3` (`spend`). Never reuse these addresses after a process restart
  or owner replacement.
- At the user's request, the single validated initialized Contraband quantity
  at runtime address `0x1DFCDF6F130` was changed from `120` to `120000`.
  Immediate source-record readback and the trainer mirror both reported
  `120000`; the owner, array, `14/24` metadata, FName `0x2DBEA`, and currency
  asset vtable were revalidated directly before the write. The user confirmed
  the HUD value and successfully bought store items; after the later Samples
  purchase, the current resolver balance is `114105`. Persistence across a
  save/restart remains unconfirmed.
  This was a direct live-memory write, not a proven game-managed setter.
- At the user's request, the single validated initialized Samples quantity at
  runtime address `0x1DFCDF6F460` was changed from `4` to `120000`. Direct
  readback and the trainer mirror both reported `120000`. The user confirmed
  the HUD value and successfully bought store items; the current post-purchase
  resolver balance is `119970`. Persistence confirmation is pending.
- At the user's request, the single validated initialized Keycodes quantity at
  runtime address `0x1DFCDF6F240` was changed from `25` to `120000`. Direct
  readback and the trainer mirror both reported `120000`. The user confirmed
  the HUD value and successfully bought store items; the current post-purchase
  resolver balance is `119535`. Persistence confirmation is pending.
- After that transaction the wallet entries were reordered/reused even though
  the owner and array pointers remained unchanged. The single validated
  Security IDs record moved to runtime quantity address `0x1DFCDF6F130`; it
  was reidentified by FName `0x2DBF2` and the currency-asset vtable, then
  changed from `20` to `120000`. Direct readback and the trainer mirror both
  reported `120000`. The user confirmed the HUD value and successfully bought
  store items; the current post-purchase resolver balance is `119860`.
  Persistence confirmation is pending.
- Researched natural initialization routes for the two absent records.
  Electronics are selectable room rewards and are awarded in quantity by
  boxing-glove Elite encounters; community reports and a gameplay guide agree
  that Elite rooms reward both Electronics and Keycodes. Computer Rooms instead
  unredact Rival information and grant anti-Rival buffs, so they are only an
  indirect aid. Souvenirs are awarded for defeating Rivals, either in direct
  combat or through remote attacks; a community-confirmed alternative is the
  Currency Exchange, which offers Souvenirs for `50` Keycodes.
- Automatic capture through a persistent-currency spend is now proven in this
  session. The generic getter hook at `0x7FF760C9B860` still had no useful calls
  during the earlier balance-screen visit. The gain/spend hooks remain armed
  and accept all seven validated currency IDs.
- The requested one-bullet trace completed. The shared setter produced `22`
  hits, confirming that it is too noisy to use as a blanket non-player kill
  point. The actual shot is isolated by the final two writes to component
  `0x1E0608B19D0`: health changed `100 -> 72 -> 58`, and immediate live
  readback confirmed current health `58` and maximum `100`. Its owner at
  component `+0x20` is `0x1DFC30C4ED0`, with non-player vtable
  `0x7FF764606280`.
- On both shot writes, `RDI` was `0x1DFD58C9570`, exactly equal to the current
  player health component's owner. That object has the known player vtable
  `0x7FF764676B98`. Disassembly of the setter at module RVA `0x1F13670`
  proves `RDI` is explicitly loaded from the fifth function argument at
  RVA `0x1F1375E`, immediately before the hooked health write at
  RVA `0x1F1376A`. Therefore `RDI == live player owner` / `[RDI] == known
  player vtable` is a strong player-caused-damage filter, not an incidental
  register value. The candidate safer One-Hit Kill rule is: target owner is
  non-player, health is decreasing, and the fifth-argument source has the
  player vtable. It still needs implementation and tests across several enemy
  classes and room transitions before enabling by default.
- The temporary breakpoint `redacted_player_gun_trace` was removed immediately
  after collection. Breakpoint count is zero; no DBVM watches are active. One-
  Hit Kill remains `0`, No Damage remains `1`, and no game memory was modified
  during this diagnostic beyond the game's normal bullet damage. No temporary
  `_ce*.py` scripts remain. A broad wildcard owner scan exceeded the pipe
  timeout earlier; CE and the game recovered cleanly. Do not repeat that scan.

### Exact next action

Implement an opt-in development revision of One-Hit Kill that retains the
existing non-player target and decreasing-health checks and additionally
requires the setter's fifth argument in `RDI` to be a valid object whose vtable
matches `redPlayerVtable`. Preserve `RDI` and flags. Keep the packaged default
disabled. Lifecycle-test the generated table, then test normal gun kills across
multiple enemy types and several room transitions while watching forced-event
counts. If any scripted target is still affected, add an enemy-owner whitelist
or a narrower upstream damage-site filter rather than returning to the blanket
non-player rule.

Have the user naturally earn at least one Electronics and one Souvenir so the
game creates their currently absent wallet records. For Electronics, choose a
chip-reward door or clear a boxing-glove Elite room. For Souvenirs, eliminate a
Rival directly/remotely or use the `50`-Keycode Currency Exchange offer. After
each gain, confirm the HUD amount and let the resolver capture/re-enumerate the
wallet before any requested adjustment. Never insert an absent raw TArray
record. Then test whether direct persistent-currency changes survive the
relevant autosave/death/respawn path and a clean game restart.

## Spendable-currency investigation (2026-09-05/06)

Status: the seven resource identities and the game's currency record/getter
layout are known. The spendable-wallet owner was captured in PID `22080`, and
its Credits record followed real gains and three purchases. The development
table resolves owners through filtered gain, spend, and getter hooks. Credits
is intentionally limited to the current run; persistent currencies use the
same record layout but survive run transitions. Do not claim that the existing
100x pickup hook changes spendable currency: live HUD evidence disproved that
assumption.

### Latest wallet-owner evidence

After the earlier investigation below, the authoritative-looking record in
PID `22080` followed real Credits gains `230 -> 245 -> 255 -> 265`. Three other
candidates were stale or reused memory. The containing owner array also held
Contraband `30`, Keycodes `10`, and Security IDs `5`, alongside non-currency
records.

| Discovery | Current-session value |
|---|---|
| Module base | `0x7FF75EFB0000` |
| Inventory owner | `0x17837C346F0` |
| Owner + `0x218` | Array pointer `0x17836C5CD00` |
| Owner + `0x220` / `+0x224` | Count 14 / capacity 24 |
| Record stride | `0x110` |
| Record + `0x08` | Eight-byte FName key |
| Record + `0x10` | Signed 32-bit quantity |
| Record + `0x30` | Observed `CurrencyVirtualData*` |
| Credits quantity address | `0x17836C5D9D0` |
| Actual quantity write | `0x7FF760C87F73`: `mov [rcx+10],r8d` |
| Instruction bytes | `44 89 41 10` |

The hardware breakpoint reported the next instruction at `0x7FF760C87F77`.
At the writer, RCX was the record, RBX/RDI the owner, RAX the old quantity,
R8D the new quantity, and R12D/R15D the positive gain in the observed hits.
These register roles are observations rather than a proven contract for every
update path. All four temporary breakpoints were removed.

At the user's request, Credits was changed from `265` to `103456` after
validating the PID, owner array, Credits key, and asset pointer. It later
advanced through a game update to `103556`, which the user confirmed in the
HUD. The user then bought an item costing `100`; the HUD correctly changed to
`103456`. This verifies display and spending behavior for the edited balance.
After two more purchases, the HUD and validated record both showed `103206`.
The character then died and respawned to trigger autosave. The save advanced to
`2026-09-06 02:37 +07:00`, size `25,908`, SHA-256
`94973AED9A0AB5527EF02DE5657B7363EECAEE8C38523BDC7A8BC1671CA00CF4`.
After restarting the game, the user confirmed that the HUD showed `0`.
A later naturally collected balance also reset to `0` after a clean
death/autosave/restart, confirming that Credits normally expires with the run.
The restart result therefore does not indicate an autosave failure.

The purchase also proved the recorded owner could not be retained: the watched
quantity at `0x17836C5D9D0` stayed `103556` and received no write, while the HUD
changed. The old owner was subsequently found freed/reused. A read-only exact
scan located the new validated Credits record at `0x17836C5A6D0`, within array
`0x17836C59A00` owned by `0x17754B73F10`. It contained Credits `103456`,
Contraband `30`, Keycodes `10`, and Security IDs `5`. The scan was destroyed,
the misplaced watch was removed, and breakpoint count returned to zero.

Every absolute address above is temporary. Never reuse it after a restart or
assume the array remains allocated after an inventory change.

### Restart-safe resolver development (`1.3.0-dev1`)

The original Credits getter at `0x7FF760C9CDE0` receives the wallet owner in
`RCX` and sums every matching Credits record. A live Keycodes access trace later
identified the stronger generic currency getter at `0x7FF760C9B860`; it also
receives the wallet owner in `RCX`, then receives the requested resource through
`RDX`. Its module signature is unique in the current build:

`4C 63 81 20 02 00 00 33 C0 4D 85 C0 7E ?? 48 8B 89 18 02 00 00 48 8B 52 08 48 83 C1 10`

The development table now replaces the generic getter's complete first instruction
(`4C 63 81 20 02 00 00`) with a seven-byte owned jump. The hook captures
`RCX`, executes the displaced `movsxd r8,[rcx+220]`, and returns to the getter.
Because the store did not call that getter, a second capture hook uses the
positive wallet-update entry at module RVA `0x1CD7D00`:

`40 55 57 41 55 41 57 48 8D AC 24 78 FF FF FF 48 81 EC 88 01 00 00 48 8B 05 ?? ?? ?? ??`

That hook captures the update routine's owner from `RCX`, preserves flags,
executes the displaced `push rbp; push rdi; push r13`, and resumes normally.
The first store purchase showed that this routine handles gains rather than
spending, so the table also hooks the unique spend entry at module RVA
`0x1CFB5B0`:

`44 89 44 24 18 89 54 24 10 48 89 4C 24 08 53 56 57 41 55 48 83 EC 58 48 63 C2 41 8B F0 4C 69 E8 10 01 00 00`

The spend function receives `RCX = owner`, `EDX = record index`, and
`R8D = amount`; it subtracts at `0x7FF760CAB5E9` with
`sub [rax+10],r8d`. The capture hook executes the displaced
`mov [rsp+18],r8d` before saving the owner, preserving the original stack
semantics. The timer prefers a populated, validated spend candidate, then a
gain candidate, and finally a getter candidate. It performs only bounded
pointer and record validation. It checks count/capacity, uses the `0x110`
stride, requires FName number zero, and requires the record asset to use the
validated `CurrencyVirtualData` vtable at module RVA `0x5A937B8`. Matching
duplicate records are summed, consistent with the getter's native behavior. A
captured owner with zero validated currency records is retained as state `3`
and shown as `resolver waiting`; it is no longer reported as ready. A
populated lower-priority candidate wins over an empty higher-priority candidate.

Both validated owners were placed into trainer-owned candidate slots solely to
test the enumerator before and after the store transaction. The post-purchase
owner produced Credits `103456`, Keycodes `10`, Contraband `30`, and Security
IDs `5`; Electronics, Souvenirs, and Samples were shown as unavailable. These
matched direct memory inspection. The generated table was then reloaded with
both diagnostic candidates cleared. A subsequent `50`-Credit purchase provided
the real test: the spend hook captured owner `0x17754B73F10`, capture count
became `1`, source became `spend`, and the bounded enumerator populated Credits
`103206`, Keycodes `10`, Contraband `30`, and Security IDs `5` without a seed.
The HUD and direct record both showed `103206`.

An exact pointer scan found 23 heap locations containing the current owner but
no module-static reference. The named scan was destroyed immediately. No
stable pointer chain is claimed from that evidence.

Lifecycle validation passed: disabling restored the health, item-award,
currency-getter, positive-update, and spend-entry bytes; removed all dynamic
records and registered symbols; and left zero breakpoints. Re-enabling the
generated `Redacted.CT` recreated 21 records. The table is Cheat Engine format
52 and its embedded source exactly matches `redacted_live_trainer.lua`.

The game-only restart test used fresh PID `28412` and resolved all code hooks
from signatures with no reused heap address. A filtered Credits update event
captured owner `0x1F93B803F10`, whose array metadata was pointer `0`, count `0`,
capacity `0`. Before the state fix this was incorrectly labeled ready because
Lua treats numeric zero as truthy. The corrected table reports state `3`, all
currency mirrors `-1`, and `resolver waiting`. A read-only inspection found
validated Credits-shaped records containing `2` and `800`, but none containing
the previous `103206`; they are not claimed as the HUD wallet. All diagnostic
scans were destroyed and the breakpoint count is zero.

### Seven currency identities

BrowserOS Neo research at `http://127.0.0.1:9010/mcp` and installed asset-name
inspection agree on these mappings:

| HUD icon | Display name | Internal resource name | FName index |
|---|---|---|---:|
| Skull | Samples | `BEV_BossToken` | `0x2DC03` |
| Key | Keycodes | `BEV_Keycodes` | `0x2DBE3` |
| Suitcase | Contraband | `BEV_Contraband` | `0x2DBEA` |
| Computer chip | Electronics | `BEV_Electronics` | `0x2DBFA` |
| Fingerprint | Security IDs | `BEV_SecurityID` | `0x2DBF2` |
| Crossed guns | Souvenirs | `BEV_RivalToken` | `0x2DC0B` |
| C symbol | Credits | `Credits` | `0x2DBDE` |

The corresponding loaded `CurrencyVirtualData` assets in PID `22080` were:

- Credits `0x1770DEEF400` (`VID_BEV_Credits`)
- Samples `0x17711117C00` (`VID_BEV_BossToken2`)
- Security IDs `0x17711117F00` (`VID_BEV_SecurityIDs2`)
- Souvenirs `0x17711118200` (`VID_BEV_RivalToken2`)
- Contraband `0x17711118800` (`VID_BEV_Contraband`)
- Electronics `0x17711118B00` (`VID_BEV_Electronics2`)
- Keycodes `0x17711118E00` (`VID_BEV_Keycodes2`)

All addresses in this section are restart-only diagnostics. Rediscover them
after a process restart.

### Critical correction: pickup totals are not wallet balances

- The player-like object at `0x1771051D560` had a map at `+0x2178`. It grew
  from two entries (Credits and Contraband) to three when Keycodes was first
  collected. The map held raw values such as Credits `1140`, Contraband
  `6000`, and Keycodes `10`.
- Spending 30 displayed Contraband changed the HUD from 60 to 30 but left the
  map's Contraband value at `6000`. It is therefore cumulative
  collection/progression data, not the spendable wallet.
- Later, the pickup hook recorded base `10` and multiplied final `1000`, while
  the Credits HUD changed only `145 -> 155`. This independently proves that
  `0x7FF760EB79E0` and `redPickupMultiplier` do not alter the spendable wallet.
- Keep the packaged feature described as a collected-item/progression
  multiplier. Do not market it as a spendable-currency multiplier without a
  new live proof.

### Failed and safely reverted currency approaches

- Editing `BevSaveV3S0.sav` to insert missing currency entries caused the game
  to report a corrupted save. The untouched original was restored exactly.
  Do not edit this save again.
- Earlier game-managed autosave snapshot:
  `C:\Users\thinh\AppData\Local\Redacted\Saved\SaveGames\BevSaveV3S0.sav`.
  At handoff it is 19,298 bytes, last written `2026-09-06 00:29 +07:00`, with
  SHA-256 `B4D703E13C1CF0AF220589DF7B579466DC690FFDC9F4B98190997C5D777EE47D`.
  Its hash changed normally after the restored save was loaded and the game
  autosaved; do not overwrite it merely because it differs from the backup.
- Autosave after the `103206` balance and death/respawn: 25,908 bytes,
  `2026-09-06 02:37 +07:00`, SHA-256
  `94973AED9A0AB5527EF02DE5657B7363EECAEE8C38523BDC7A8BC1671CA00CF4`.
- Current post-restart save at `2026-09-06 09:00:56 +07:00`: 25,851 bytes,
  SHA-256
  `1A9AA8296C36A32533EC069046CAE8B6E659A5F5E7E23B503D35A0F47A6414CA`.
  These changes are game-managed; do not restore or edit either form.
- Untouched known-good pre-experiment backup:
  `BevSaveV3S0.sav.codex-backup-20260905-2259` (17,320 bytes, SHA-256
  `37955673C01BB1585AD195D31F97B61C3C434CE27FD2700AD25EDDAB46B58F20`).
- Rejected corrupted edit preserved for forensics only:
  `BevSaveV3S0.sav.rejected-20260905-2308` (17,673 bytes, SHA-256
  `1ADADA9C3CDF727F779946167C48CBDB831F84E0D74A740ECC7EA0C31FF35587`).
- Calling the native award routine from a CE-created remote thread crashed the
  earlier game PID `11540`. Do not repeat remote-thread/native-call execution.
- A game-thread one-shot initially passed `CurrencyVirtualData` pointers where
  the routine expected FNames. It fired without crashing but did not add the
  five missing wallet types. It was removed and the standard trainer reloaded.
- A later corrected FName initializer was armed but never validated before it
  was removed. More importantly, the target routine is now known to update
  progression rather than spendable balances, so do not resume that approach
  for the wallet.
- A dense seven-name snapshot near `0x177CA99493C` contained values including
  Contraband `10`. Writing its Contraband value to `110` stayed in memory for
  several seconds but did not change the HUD. It was restored to `10`.
- Persistent exact-value scans for Contraband and Credits produced cached or
  unrelated survivors. All named scan sessions (`wallet_*` and
  `credit_live_*`) were destroyed. There are no scans that need cleanup.

### Verified currency-record and getter layout

Credit transitions used for tracing were `45 -> 145 -> 155`. When Credits was
45, the exact `Credits + 45` structure appeared at three locations. Hardware
write watches proved that one was transient, one stayed stale at 45, and one
updated to 145. All watches were removed immediately.

The transient currency record is `0x110` bytes wide:

- record `+0x08`: eight-byte FName key
- record `+0x10`: signed 32-bit quantity
- record `+0x30`: `CurrencyVirtualData*` in the observed copies

The generic record-copy constructor is at `0x7FF760C7F360`. Its relevant copy
sequence is `mov eax,[rdi-0xE0]` at `0x7FF760C7F3F9`, followed by
`mov [rbx-0x74],eax` at `0x7FF760C7F3FF`. A hardware data breakpoint reports
the following instruction (`0x7FF760C7F402`), so do not mistake that next
instruction for the write itself.

The strongest static discovery is the Credits getter at `0x7FF760C9CDE0`:

- `this + 0x218`: record-array pointer
- `this + 0x220`: record count
- stride: `0x110`
- compares `[record + 0x08]` with the static Credits FName
  (`0x7FF765CE1428` in this run)
- sums `[record + 0x10]` and returns the total in `EAX`

Two store affordability functions use the same owner and array layout:
`0x7FF760C8D9B0` and `0x7FF760C8DAC0`. A five-second passive sample produced
no hits because the store calculation was inactive. Execution watches were
then armed in preparation for the user opening the store, but the user asked
for this handoff before performing that action; all three watches were removed.

A temporary whole-wallet copy was observed at `0x177E5CF71A0` with three
contiguous records: Contraband `10`, Keycodes `10`, Credits `155`. It had no
remaining pointer owner by the time it was inspected and must not be written;
it is evidence of the layout only.

### Clean live state at handoff

- Previous game PID `22080` was cleanly unpatched and closed after autosave.
- Fresh game PID: `28412`; module base: `0x7FF75EFB0000`.
- The user confirmed `103556` in the HUD, then bought items costing `100`,
  `200`, and `50` Credits. The HUD followed `103556 -> 103456 -> 103256 ->
  103206`, and the pre-restart live record read `103206`. HUD and spending were
  verified three times.
- After death/respawn autosave and a game restart, the user confirmed the HUD
  shows `0`. A separate natural-Credits test produced the same result, proving
  that Credits is run-scoped. Do not expose editable Apply controls until a
  game-managed setter/dirty-notification path is proven.
- The fresh process captured an empty owner (`0x1F93B803F10`, count/capacity
  `0/0`). The corrected table labels this `resolver waiting`; it does not
  equate the HUD default `0` with an initialized zero-valued Credits record.
- The user naturally collected Credits and confirmed the HUD reached `30`.
  The gain-writer breakpoint captured two updates: old/new `10 -> 20` and
  `20 -> 30`. The initial record insertion produced the first `10` by a
  separate insertion branch. The resolver independently captured owner
  `0x1F8C5D4F040`, array `0x1F8A5BDB380`, count/capacity `15/24`, and displayed
  Credits `30` via source `update`. The same validated array contained
  Contraband `30`, Keycodes `10`, Security IDs `5`, and Samples `2`.
- The `credits_gain_writer` breakpoint was removed immediately; breakpoint
  count is zero. The pre-death save snapshot is 30,857 bytes, timestamp
  `2026-09-06 09:18:36 +07:00`, SHA-256
  `8A82950A412353BA0AA9933D71E8811286C96BE81033075C833558D443D663B4`.
- No Damage is temporarily `0` for the death/autosave test. One-Hit Kill was
  unexpectedly observed as `1` during the state check and was explicitly reset
  to `0`; both values were read back and there are no breakpoints.
- Death/respawn advanced the save to 30,285 bytes at
  `2026-09-06 09:23:39 +07:00`, SHA-256
  `36AE2A2567D724A15AF0C91F9B1B7DE00FBBFF98DF03F7B9E3DBACD0F57454AC`.
  The post-respawn wallet was a new empty transition owner, correctly reported
  as uninitialized. The table was deactivated and all five original byte
  sequences were verified before PID `28412` closed cleanly.
- The game was relaunched as PID `23220`; CE reattached and activated the table
  from signatures. It has 21 records, No Damage `1`, One-Hit Kill `0`, zero
  breakpoints, and is waiting for the loaded game to produce a wallet event.
  The user must enter/continue the playable game and report whether the HUD
  loads the naturally earned `30` Credits.
- The user confirmed that PID `23220` loaded Credits `0` while Keycodes,
  Contraband, and the other persistent currencies remained. Memory inspection
  confirms Credits has no record in the authoritative-looking persistent
  wallet; this is a game currency-class distinction, not an autosave failure.
  Credits is run-scoped and resets on a new game/run load. The validated
  14-record owner `0x1E4A65C6670` contains Contraband `30`, Keycodes `10`,
  Security IDs `5`, and Samples `2`, with no Credits record. Two additional
  transient/copy arrays held the same four values.
- The resolver's empty Credits candidate did not expose that persistent wallet.
  Gain and spend hooks are now filtered against all seven validated FName keys,
  allowing any real currency transaction to supply a candidate without
  reopening the earlier unrelated-resource false capture. Empty candidates now
  say `resolver waiting` instead of implying the persistent wallet is empty.
  A diagnostic candidate verified that the rebuilt enumerator reports Credits
  unavailable plus Keycodes `10`, Contraband `30`, Security IDs `5`, and Samples
  `2`. The seed was cleared through disable/re-enable; the table is active with
  No Damage `1`, One-Hit Kill `0`, and zero breakpoints.
- The temporary Keycodes access breakpoint collected 789 accesses before the
  next inspection. It identified module access sites `0x7FF760C957E5` and
  `0x7FF760C9B888`, with persistent wallet owner `0x1E4A65C6670` in `RDI/R12`.
  The breakpoint was removed and the active breakpoint count is zero.
- In current PID `23220`, the resolver later captured a 15-record run wallet at
  owner `0x1E4D21D4ED0`, array `0x1E4023A9A00`. Its sole validated Credits
  quantity at `0x1E4023AA8F0` matched the user's HUD value `1285`. At the user's
  request it was changed to `102746`; direct memory and resolver readback both
  passed. The user confirmed `102746` in the HUD and successfully spent from it
  in the store. All addresses are runtime-only.
- The earlier PID `23220` owner array also contained Contraband `30`, Keycodes `10`,
  and Security IDs `5`; Electronics, Souvenirs, and Samples were not established
  as initialized wallet records.
- Generated trainer v1.3.0-dev1 is active in PID `24524`: No Damage `0` at the
  user's request so the character can die, One-Hit Kill `0`, multiplier `100`.
  The resolver is ready from a validated diagnostic candidate: Keycodes `25`,
  Contraband `120`, Security IDs `20`, and Samples `4`. Credits, Electronics,
  and Souvenirs have no initialized record and display unavailable in CE; this
  corresponds to the user's HUD value `0` for each.
- Fresh persistent owner: `0x1DF0166C4F0`; array `0x1DFCDF6E680`;
  count/capacity `14/24`. A second validated `14/15` copy existed at
  `0x1DF03ABABF8` / `0x1DFBF3140C0`. All addresses are runtime-only.
- The generic getter received zero calls from the reported balance-screen
  visit. The current resolver source is a trainer-owned diagnostic seed, not a
  proven automatic restart path. Trace the next real persistent-currency
  transaction before packaging another capture change.
- Pickup telemetry in this fresh activation: events `0`, last base `0`, last
  final `0`.
- Active hardware breakpoints: **0**.
- Death/respawn triggered autosave successfully. The save advanced to
  `2026-09-06 02:37 +07:00`, size 25,908 bytes, SHA-256
  `94973AED9A0AB5527EF02DE5657B7363EECAEE8C38523BDC7A8BC1671CA00CF4`.
- Active temporary currency hooks/watchpoints: **0**. One validated
  trainer-owned candidate slot is seeded for read-only display in this process.
- Current restart-only code addresses: health write `0x7FF760EC476A`, item
  progression-award entry `0x7FF760EB79E0`.
- Correct Epic AppName: `98614687b212444c9ff0d42095f56cb3`; launch URI:
  `com.epicgames.launcher://apps/98614687b212444c9ff0d42095f56cb3?action=launch&silent=true`.

## Feature: One-hit kill

Status: the version 1.2.0 broad non-player filter produced one-hit kills but
prevented room progression. Version 1.2.1 disables it by default in the live
session and packaged table. It was manually re-enabled in PID `24524` and
reproduced the progression failure. A player-specific damage trace is required
before this feature can be considered safe.

### Live failure evidence and containment

- One-Hit Kill recorded 10 forced health decreases while the user cleared the
  room, but the game could not advance after everything visible was dead.
- The last captured event changed a normal proposed `125 -> 105` health update
  to zero, confirming that the shared health-setter branch was active.
- The filter used only `owner vtable != player vtable`; it therefore included
  every owned non-player health component, not strictly enemies damaged by the
  player. Scripted actors or multi-stage encounter state can be caught by this
  broad rule.
- `redOneHitKill` was immediately written to `0`. No Damage stayed `1`, the
  collected-item multiplier stayed decimal `100`, and breakpoint count stayed
  zero.
- The v1.2.1 source and generated table now initialize the control to Disabled.
  The hotfix was loaded and activated successfully in the current process.
- In PID `24524`, the user reported the same closed-door failure after all
  visible enemies died. The live control was `1` and the event counter was
  `17`; the latest recorded proposed update was `100 -> 72`, forced to zero.
  The captured component was already freed/reused when inspected. Native code
  after the shared health write conditionally invokes virtual/state callbacks,
  so forcing zero can select or bypass encounter transitions for any object
  caught by the broad filter. The exact blocking actor was not retained, but
  the proven root defect is the lack of an enemy-plus-player-damage classifier.
- The user clarified that ordinary rooms worked for several transitions before
  a gun-cleared room locked. A later read showed the forced-event count had
  risen to `56` and the last component's outer field was overwritten with
  `0x7FFFFFFF7FFFFFFF`. This makes a universal gun/kill-attribution failure less
  likely and an encounter-specific non-enemy or staged-actor capture more
  likely. The exact actor still requires a pre-hit trace with One-Hit Kill off.

### Implementation

- Reuses the verified shared health setter and its unique AOB rather than
  adding another code patch.
- The health component's outer object at `+0x20` is checked against the
  player-owner vtable. The existing player branch continues to block only
  decreases when No Damage is enabled.
- When One-Hit Kill is enabled, a decreasing update for an owned component
  whose outer vtable is not the player's is changed to `0.0` in `XMM6` before
  the original health write executes. Healing and unchanged/increased health
  pass through normally.
- The shared hook still preserves `RAX` and `RFLAGS`; the later native `jna`
  consumes the pre-write flags.
- New symbols: `redOneHitKill`, `redOneHitComponent`, `redOneHitEvents`,
  `redOneHitPreviousHealth`, and `redOneHitProposedHealth`.
- New table controls expose the enabled toggle, event counter, target health
  before the hit, and the post-normal-damage health that was replaced by zero.

### Packaging and lifecycle evidence

- The initial updated Lua assembled successfully in live PID `28456` and
  reported version 1.2.0; the safety hotfix now reports version 1.2.1.
- `build_table.ps1` generated a Cheat Engine table version 52 whose decoded
  assembler content exactly matched the canonical Lua source.
- The v1.2.0 generated table loaded successfully with 11 child controls. After
  the progression failure, v1.2.1 was rebuilt and loaded with No Damage `1`,
  One-Hit Kill `0`, and the item multiplier decimal `100`.
- Disable restored health bytes to `F3 0F 11 B3 90 01 00 00` and pickup bytes
  to `44 89 44 24 18`, removed every dynamic child, and unregistered the tested
  health, One-Hit Kill, and pickup symbols.
- Re-enable recreated both owned near jumps and all controls. Breakpoint count
  was zero after testing and after applying the v1.2.1 hotfix.
- Current restart-only diagnostics: module base `0x7FF72C050000`, health write
  `0x7FF72DF6476A`, item-award entry `0x7FF72DF579E0`. Do not persist these.
- The game remained outside the playable world during packaging: the player
  component and One-Hit Kill event counter were both zero. Visible combat
  behavior is therefore not yet claimed as live-verified.

## Feature: 100x collected-item/progression awards

Status: live-verified for the positive award/progression path, integrated into
the canonical source, packaged in `Redacted.CT`, and lifecycle-tested as
version 1.1.0. It is not verified for the spendable wallet and live evidence
now shows that it does not modify spendable currency.

### Discovery and trace evidence

- An unknown-initial-value `dword` scan was started before collecting currency.
- A 30-coin pickup was filtered with `increased_by 30`.
- The visible balance then changed from `30` to `40`; filtering by the exact
  `+10` transition reduced the scan to 17 candidates, only two of which held
  the displayed balance.
- The two live balance copies were `0x1CE35989FA8` and `0x1CEFC0F6BE8` in this
  process. Both changed from `40` to `140` on the next 100-coin pickup.
- Hardware write traces showed both balances being updated by the same native
  function and the same incoming quantity:
  - `add [rdx+08],r15d` at `0x7FF7E46B7CEA`
  - `add [rdx+08],r15d` at `0x7FF7E46B7E06`
- At both writes, `R15D` was `100`, matching the pickup amount. Earlier in the
  function, `R15D` is loaded from `[rsp+0xA0]`.
- The actual function entry is `0x7FF7E46B79E0`. Its first instruction stores
  `R8D` at `[rsp+0x18]`; after the prologue that same argument is read from
  `[rsp+0xA0]`. Therefore `R8D` is the generic incoming item quantity.
- The function copies `R8D` to `EAX`, tests it, and exits for values `<= 0`.
  This is a positive-gain path, so spending/removal is not multiplied.
- Both temporary data breakpoints were removed immediately after tracing;
  current breakpoint count is zero.

### Live multiplier hook

- Unique entry AOB in the current build:
  `44 89 44 24 18 41 54 41 56 48 83 EC 78 80 B9 A9 26 00 00 00 41 8B C0 4C 8B F2 4C 8B E1`
- Original entry bytes: `44 89 44 24 18`
  (`mov [rsp+18],r8d`).
- A five-byte jump now redirects the entry to `redPickupHook`.
- For positive quantities and a multiplier greater than one, the hook executes
  `imul r8d,[redPickupMultiplier]`, records the original/final quantity, and
  then executes the displaced stack store.
- Live symbols: `redPickupMultiplier`, `redPickupEvents`,
  `redPickupBaseAmount`, and `redPickupFinalAmount`.
- `redPickupMultiplier` is currently decimal **100** (`64 00 00 00`). Important:
  Cheat Engine Auto Assembler interpreted `dd 100` as hexadecimal `0x100`
  (256), so the packaged source must use `dd 64` or explicitly write decimal
  100 after allocation.
- Earlier telemetry showed two progression-counter copies at **1140**, proving
  that a base 10 award became +1000 in that path. Those copies were initially
  mistaken for spendable coin balances. The later spend and HUD tests in the
  currency-investigation section correct that interpretation.
- The current hook has observed 57 positive award events; its latest event had
  base quantity 10 and final quantity 1000. At the same time the spendable
  Credits HUD rose only by 10, so the multiplier affects the progression/item
  path but not the wallet.
- No Damage remains enabled and unaffected.

### Packaged implementation and validation

- `redacted_live_trainer.lua` now contains both guarded hooks and reports
  version 1.1.0.
- The table exposes an editable `REDACTED: Collected Item Multiplier` defaulting
  to decimal 100, plus read-only award count and last base/final quantities.
- The multiplier control clamps user edits to 1–1000; setting 1 preserves
  normal pickup quantities.
- `RedactedTrainerStop` verifies ownership of each near jump before restoring
  code, restores both original instruction sequences, unregisters all health
  and pickup symbols, and deallocates both caves.
- `build_table.ps1` rebuilt `Redacted.CT`; the result parsed as Cheat Engine
  table version 52 and was loaded into the live CE session successfully.
- On activation, all seven child records appeared, No Damage was 1, the item
  multiplier was exactly decimal 100 (`64 00 00 00`), and both code locations
  contained owned near jumps.
- On disable, health bytes restored to
  `F3 0F 11 B3 90 01 00 00`, pickup bytes restored to
  `44 89 44 24 18`, every dynamic child disappeared, and all tested trainer
  symbols were absent.
- Re-enable succeeded with both hooks and all controls recreated. Version 1.1.0
  is currently loaded and active in Cheat Engine.
- Breakpoint count remained zero throughout packaged lifecycle testing.

## Verification evidence

- Initial health was `50/50`; observed real decreases to `45`, `35`, and `20`.
- Four candidate float addresses were traced with hardware write breakpoints.
- Authoritative health was isolated at `[health component + 0x190]`.
- Three other candidates were downstream copies written through VCRUNTIME and
  were deliberately not hooked.
- After the player-filtered hook was installed, health was restored to `50`.
- Live telemetry then recorded **8 blocked health decreases while health
  remained 50**.
- All four temporary hardware breakpoints were removed; breakpoint count was
  verified as zero before the final hook was installed.

## Stable implementation details

- Unique health-write AOB:
  `F3 0F 11 B3 90 01 00 00 F3 44 0F 5C C7 76 ?? 41 0F 2F F1 77 ?? 48 8B 03`
- Original instruction and bytes:
  `movss [rbx+00000190],xmm6` / `F3 0F 11 B3 90 01 00 00`
- Player health offset: `0x190`
- Component outer/owner offset: `0x20`
- Player-owner vtable RVA: `Redacted-Win64-Shipping.exe+56C6B98`
- Proposed decreases are converted to the existing health in `xmm6`; healing
  passes through.
- The hook preserves `RAX` and `RFLAGS`. The later `jna` relies on flags set
  before the original health write.

## Temporary discovery values — never persist these

- Discovery PID: `2672`
- Discovery module base: `0x7FF7E27B0000`
- Discovery health component: `0x1CEB883B0A0`
- Discovery health address: `0x1CEB883B230`

## Files

- `redacted_live_trainer.lua` — canonical source
- `build_table.ps1` — deterministic CT builder
- `Redacted.CT` — generated table
- `README.md` — user startup, restart, and usage instructions
- `CHECKPOINT.md` — this handoff

## Packaging and lifecycle validation

- `build_table.ps1` generated `Redacted.CT` successfully.
- The generated file parsed as XML with Cheat Engine table version 52 and the
  expected `REDACTED Trainer - Activate` record.
- The experimental injection was removed; all eight original bytes were
  restored and its symbols disappeared.
- The canonical Lua source was activated successfully: the health write became
  a five-byte near jump plus three-byte NOP, all six public symbols resolved,
  and the No Damage control contained `1`.
- The actual generated `Redacted.CT` was loaded into Cheat Engine and its master
  record was enabled. All three child controls appeared correctly.
- Disabling the table restored `F3 0F 11 B3 90 01 00 00`, removed every dynamic
  child and trainer symbol, and left `RDT` clean.
- Re-enabling the same table succeeded and is the implementation currently
  active for the user. Health is `50`; No Damage is enabled.
- Breakpoint count remains zero throughout packaged-table testing.

## Next action

Currency work is the immediate continuation:

1. Naturally initialize and verify Electronics and Souvenirs through the
   researched in-game acquisition routes.
2. Test the modified persistent balances through death/respawn autosave and a
   clean game restart.
3. Implement a shared bounded set-currency operation only after the relevant
   game-managed path is proven. Test persistent currencies through readback,
   HUD, spending, death/respawn autosave, and a fresh load. Treat Credits as
   run-scoped: test it through current-run HUD/spending and document its reset.
4. Restart Cheat Engine, reload the table, attach, and repeat
   activation/capture. Repeat across a scene/run transition.
5. Generalize by validated resource identity to the other six currencies.
   Treat absent records as unavailable and never insert raw TArray entries.
6. Build the seven table controls on top of the resolver, then add explicit,
   opt-in preference restoration. Rebuild and validate `Redacted.CT` after the
   canonical Lua changes.

Separately, keep One-Hit Kill Disabled. When a healthy enemy is available,
trace one normal player hit at the shared health setter so the damage
instigator/source can replace the broad non-player filter.

## Modification history

- 2026-09-04 — Created the organized `redacted_game` toolkit, packaged the
  verified No Damage hook as version 1.0.0, validated the generated table, and
  left it enabled in the current session.
- 2026-09-04 — Traced the shared positive item-award routine, verified 100x
  currency and other item quantities, packaged the editable multiplier as
  version 1.1.0, validated full cleanup/re-enable behavior, and left the table
  active with multiplier 100.
- 2026-09-04 — Added a player-excluding One-Hit Kill branch to the shared
  health hook, packaged version 1.2.0, validated full cleanup/re-enable
  behavior, and left No Damage, One-Hit Kill, and the 100x multiplier active.
  Gameplay hit confirmation remains pending because the restarted session had
  not entered the playable world.
- 2026-09-04 — Live gameplay showed that the broad One-Hit Kill filter killed
  enemies but prevented room progression after 10 events. Disabled the feature
  live, changed its packaged default to Disabled, rebuilt and loaded version
  1.2.1, and left No Damage plus the 100x multiplier active with zero
  breakpoints.
- 2026-09-05/06 — Identified all seven currencies and their FName keys,
  recovered the untouched save after a rejected edit was reported corrupted,
  proved the existing pickup multiplier changes progression rather than the
  spendable wallet, rejected and reverted cached-value writes, derived the
  `0x110` currency-record layout and the Credits getter/affordability routines,
  and left PID `22080` with trainer v1.2.1 active and zero breakpoints. The next
  step is to capture the wallet owner by opening/highlighting a Credit-priced
  store item while execution watches are armed.
- 2026-09-06 — Captured the current-session wallet owner and an authoritative
  Credits record in PID `22080`. The record followed `230 -> 245 -> 255 -> 265`.
  At the user's request, changed it to `103456` and confirmed memory readback;
  HUD, spending, autosave, and reload confirmation remain pending. Updated the
  continuation order to establish restart-safe resolution before table controls.
- 2026-09-06 — Added the `1.3.0-dev1` Credits-getter capture hook, validated
  currency-asset type checks, bounded read-only seven-currency enumerator, and
  explicit unavailable states. Verified enumeration with the known live owner,
  full three-hook cleanup/re-enable, exact CT embedding, 21 generated records,
  and zero breakpoints. Cleared the diagnostic owner seed; a real capture and
  fresh-process test remain pending.
- 2026-09-06 — User confirmed edited Credits in the HUD at `103556` and bought
  a `100`-Credit item, producing the expected HUD value `103456`. The prior
  owner had been freed/reused and its old record stayed stale, proving addresses
  must be re-resolved across store transactions. Located and validated the new
  owner/array read-only, then added a preferred wallet-update capture hook with
  getter fallback. Four-patch cleanup/re-enable and exact CT embedding passed;
  the generated table is active with empty candidate slots and zero breakpoints.
- 2026-09-06 — User bought a second item for `200` Credits; HUD and the live
  record both changed `103456 -> 103256`. A correctly placed hardware watch
  captured `RCX/RDI = owner`, `RAX = Credits record`, and `RSI/R8 = 200` at
  the spend write. Added the unique spend-function entry as the resolver's
  highest-priority capture source. Five-patch cleanup/re-enable, generated-table
  activation, and exact source embedding passed with zero breakpoints.
- 2026-09-06 — User bought a third item for `50` Credits after the spend hook
  was active. HUD and memory changed `103256 -> 103206`; the hook captured the
  correct owner once and the unseeded enumerator populated all four available
  balances with source `spend`. The confirming hardware watch was removed and
  breakpoint count returned to zero. Fresh-process recovery is the next gate.
- 2026-09-06 — Death/respawn advanced the save to a new timestamp/hash. Filtered
  gain and spend capture hooks to Credits records so unrelated resource owners
  cannot displace the wallet candidate. Restored all original code, closed PID
  `22080`, launched PID `28412`, reattached CE, and activated the generated
  table using signatures only. No old heap address was used; No Damage restored
  to `1` and breakpoint count remained zero. Saved HUD/capture verification in
  the playable world remains next.
- 2026-09-06 — The user confirmed the restarted HUD shows `0`, so the edited
  `103206` balance failed persistence despite the prior death/respawn autosave.
  Fresh-process inspection found no validated `103206` currency record. Fixed
  the resolver to require at least one validated currency record before
  reporting ready, prefer populated candidates, and report an empty captured
  owner as state `3` / `resolver waiting`. Rebuilt and activated the table;
  the state-3 live test passed with 21 records and zero breakpoints. Natural
  Credits gain tracing is now the next currency gate. After lifecycle
  validation, armed one hardware execution breakpoint at the known gain writer
  for that test.
- 2026-09-06 — A natural pickup initialized the fresh wallet at Credits `30`.
  The resolver captured the new owner without a seed and matched the HUD. The
  gain breakpoint recorded the `10 -> 20 -> 30` writer sequence and was removed,
  leaving zero breakpoints. Recorded the pre-death save snapshot, disabled No
  Damage, and forced the unexpectedly enabled One-Hit Kill control back to `0`.
  Death/respawn and fresh-load persistence of the natural 30 are next.
- 2026-09-06 — Death/respawn advanced the save hash. Cleanly deactivated the
  table, verified all five original patches, closed PID `28412`, launched PID
  `23220`, reattached CE, and activated the table using signatures. The new
  process is waiting for gameplay/HUD confirmation of the naturally earned 30.
- 2026-09-06 — The fresh HUD showed Credits `0` while persistent currencies
  remained. Validated a live 14-record persistent wallet holding Contraband
  `30`, Keycodes `10`, Security IDs `5`, and Samples `2`, with no Credits
  record. Broadened gain/spend capture filters to all seven currency FNames,
  improved empty-candidate wording, rebuilt the CT, verified diagnostic
  enumeration, restored all five patches, cleared the seed, and reactivated
  cleanly with zero breakpoints.
- 2026-09-06 — Published gameplay sources confirmed the live result: Credits
  buy temporary Fabricator upgrades and are deleted when the run ends, while
  the other resources buy permanent upgrades. Later, the user reported current
  Credits `1285`; the naturally captured 15-record wallet matched exactly. At
  the user's request, changed its sole validated Credits record to `102746`.
  Direct and resolver readback passed. The user confirmed HUD `102746` and
  successfully spent from it. Removed the Keycodes access watch and left No
  Damage `1`, One-Hit Kill `0`, and zero breakpoints.
- 2026-09-06 — Replaced the narrow Credits-getter capture signature with the
  unique generic currency getter at module RVA `0x1CEB860`, identified by the
  Keycodes access trace. Rebuilt `Redacted.CT`; CE `loadfile` syntax passed.
  A deactivate/reactivate lifecycle restored all five original instruction
  sequences exactly, recreated 21 records with No Damage `1` and One-Hit Kill
  `0`, and left zero breakpoints. The generic getter resolved to
  `0x7FF760C9B860`. No currency call occurred during the four-second checks, so
  automatic persistent-wallet capture is waiting for a natural currency or
  permanent-upgrade menu access.
- 2026-09-06 — Disabled No Damage in live PID `23220` at the user's request so
  the character can die and respawn. Byte-sized readback confirmed No Damage
  `0`, One-Hit Kill `0`, and intact `CC` alignment padding. Currency hooks and
  the trainer activation remain active.
- 2026-09-06 — After the user restarted both the game and Cheat Engine/MCP,
  the bridge found new PID `24524` with no CE attachment. Attached CE to
  `Redacted-Win64-Shipping.exe`, loaded the rebuilt table, and activated it
  entirely from signatures. Restored the user's No Damage preference to `0`;
  One-Hit Kill remains `0`. The generic getter resolved to
  `0x7FF760C9B860`, all 21 controls were recreated, and zero breakpoints remain.
  The currency resolver is waiting with zero captures until the user opens a
  currency/permanent-upgrade screen and reports the displayed balances.
- 2026-09-06 — The user reported the clean-restart HUD balances: Contraband
  `120`, Keycodes `25`, Electronics `0`, Security IDs `20`, Samples `4`,
  Souvenirs `0`, and Credits `0`. The generic getter still had zero captures.
  Exact read-only signatures located two full `0x110` record arrays plus
  compact copies. Pointer validation identified a `14/24` owner at
  `0x1DF0166C4F0`; seeding only the trainer-owned candidate made the bounded
  resolver independently report Keycodes `25`, Contraband `120`, Security IDs
  `20`, and Samples `4`. The other three records were absent, consistent with
  HUD zero. A broad experimental owner scan exceeded the bridge timeout, but
  CE and the game recovered with the table still active. Four short-lived
  access watches collected no hits and were removed; breakpoint count is zero.
- 2026-09-06 — Revalidated PID `24524` and the persistent wallet immediately
  before modifying Contraband. Exactly one initialized Contraband record was
  present at `0x1DFCDF6F130`, with quantity `120`, FName `0x2DBEA`, and the
  expected `CurrencyVirtualData` vtable. Wrote `120000`; direct readback and
  the resolver mirror both returned `120000` after the timer refreshed. The
  owner remained `0x1DF0166C4F0`, metadata remained `14/24`, and breakpoint
  count remained zero. The user confirmed the HUD value and successfully spent
  Contraband in the store. The spend hook captured the same owner automatically
  and the resolver switched to source `3`; after purchases, Contraband reads
  `117355`. Save persistence confirmation remains pending.
- 2026-09-06 — Revalidated the persistent wallet after the store transaction.
  Exactly one initialized Samples record was present at `0x1DFCDF6F460`, with
  quantity `4`, FName `0x2DC03`, and the expected currency-asset vtable. Wrote
  `120000`; the direct record and resolver mirror both remained `120000` after
  refresh. The owner remained `0x1DF0166C4F0`, metadata remained `14/24`, the
  resolver stayed ready via source `3` (`spend`), and breakpoint count remained
  zero. The user confirmed the HUD value and successfully spent Samples in the
  store; the current post-purchase balance is `119970`. Save persistence
  confirmation remains pending.
- 2026-09-06 — Revalidated the wallet again after the Samples purchase.
  Exactly one initialized Keycodes record was present at `0x1DFCDF6F240`, with
  quantity `25`, FName `0x2DBE3`, and the expected currency-asset vtable. Wrote
  `120000`; direct readback and the resolver mirror both remained `120000`
  after refresh. The owner remained `0x1DF0166C4F0`, metadata remained `14/24`,
  the resolver stayed ready via source `3` (`spend`), and breakpoint count
  remained zero. The user confirmed the HUD value and successfully spent
  Keycodes in the store; the current post-purchase balance is `119535`. Save
  persistence confirmation remains pending.
- 2026-09-06 — Revalidated the wallet after the Keycodes purchase and observed
  that records had been reordered/reused despite unchanged owner and array
  pointers. Rediscovered exactly one initialized Security IDs record at
  `0x1DFCDF6F130`, with quantity `20`, FName `0x2DBF2`, and the expected
  currency-asset vtable. Wrote `120000`; direct readback and the resolver mirror
  both remained `120000` after refresh. The owner stayed `0x1DF0166C4F0`,
  metadata stayed `14/24`, the resolver stayed ready via source `3` (`spend`),
  and breakpoint count remained zero. The user confirmed the HUD value and
  successfully spent Security IDs in the store; the current post-purchase
  balance is `119860`. Save persistence confirmation remains pending.
- 2026-09-06 — Researched natural acquisition routes for the absent Electronics
  and Souvenirs wallet records using Epic's guide, Steam discussion evidence,
  Reddit gameplay reports, a level designer's portfolio, and a gameplay-video
  transcript. Electronics come from selectable Electronics reward rooms and
  boxing-glove Elite encounters, which reward Electronics plus Keycodes.
  Computer Rooms instead unredact Rival information and grant buffs against
  them. Souvenirs come from defeating Rivals directly or through remote attacks;
  the Currency Exchange offers another route for `50` Keycodes. No live game
  memory was modified during this research.
- 2026-09-06 — Diagnosed a repeated One-Hit Kill room-progression failure in
  PID `24524`. The feature had been re-enabled and recorded `17` forced health
  decreases; the latest replaced a normal `100 -> 72` update with zero. The
  captured component was already freed/reused, while disassembly confirmed the
  shared setter is followed by conditional virtual/state callbacks. The hook's
  sole target rule remains `outer vtable != player vtable`, which is not an
  enemy or player-damage test and can corrupt scripted encounter transitions.
  The user then clarified that it worked for several rooms before a later room
  cleared by gunfire locked; the event count subsequently reached `56` and the
  captured component had been freed/reused. This supports an encounter-specific
  staged/non-enemy target rather than a gun-specific failure. Per diagnostic-
  only scope, no toggle or code was changed; zero breakpoints remain.
- 2026-09-06 — Prepared the requested player-gun trace in PID `24524` while the
  user stood in front of a healthy enemy. One-Hit Kill was already `0`; No
  Damage remained `1`. Cleared the stale One-Hit capture fields and armed one
  short-lived hardware execution breakpoint at `redHealthHook`, ID
  `redacted_player_gun_trace`, capturing registers plus 32 stack entries. It
  had zero hits when armed and must be removed immediately after one bullet.
- 2026-09-06 — Collected that one-bullet trace and immediately removed its
  hardware breakpoint. The shared setter emitted 22 events, but the real enemy
  hit was identified as two writes to one live `100`-max component,
  `100 -> 72 -> 58`. Both writes carried the exact live player owner in `RDI`;
  the setter disassembly shows that `RDI` is its fifth argument and reloads it
  immediately before the health write. This provides a strong player-source
  filter for the next development version. No trainer code or live toggle was
  changed; One-Hit Kill remains off, No Damage remains on, and breakpoint count
  is zero.

## Checkpoint convention

After every new feature or fix, record the change, stable discovery data,
temporary values, files changed, live-test result, cleanup result, and next
unresolved action.
