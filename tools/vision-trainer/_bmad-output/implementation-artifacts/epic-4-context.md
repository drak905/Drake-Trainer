# Epic 4 Context: Stubborn Values — Freeze, Display & Patch

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give the player control over stubborn values the game keeps decaying or resetting: they can arm Freeze to hold a value where they put it (or use Display as a read-only live readout), and for values the game actively rewrites, patch the writing instruction itself so it stops overwriting. All of these are explicitly dangerous — they can corrupt saves or crash the game — so every path is double-gated: a per-session UNSAFE acknowledgement plus a just-in-time confirm, with the app restoring original values/bytes/behavior on clean quit so nothing lingers after the session ends.

## Stories

- Story 4.1: Per-session UNSAFE gates and armed banner
- Story 4.2: Freeze and display with restore on quit
- Story 4.3: Patch-writer with unique-signature rule

## Requirements & Constraints

- Freeze and Display are enabled only after an explicit per-session UNSAFE acknowledgement; the gate must be re-armed each launch; without it the Freeze/Display controls stay disabled.
- Freeze holds a value via repeated writes bound to the snapshotted address + label captured at Freeze ON; changing list selection while frozen must never retarget the freeze. Display is the same lifecycle but strictly read-only — no writes ever.
- Normal quit must stop all freeze workers and restore original values; the quit-time restore checklist reports per-item restored/failed. Force-kill/crash residue has no automatic owner: re-attach must re-resolve via the anchor ladder and explicitly re-freeze — never assume the old address or value; this is a documented limitation surfaced in the banner and a next-launch stale-state recovery banner.
- Patch-writer locates the instruction writing the value via a data-breakpoint, classifies it as nop / replace / skip, fingerprints it with a signature, and applies the patch ONLY when the signature is unique. Non-unique signatures refuse with a reason; writers classified as skip are never patched; failures surface as a patch-failed error.
- Applied patches restore the original bytes on clean quit via the same checklist.
- Freezing/patching with no value selected is a no-op with a field-named guidance message; patching is preceded by a just-in-time risk-confirm dialog that must offer explicit Continue/Cancel.

## Technical Decisions

- Mutation ownership: `FreezeWorker` (`freeze.py`) and `codepatch.py` own all writes to their target and capture original value/bytes exactly once before the first write; restore runs through `FlowState.shutdown` plus `atexit` (worker stop, value/byte restore, breakpoint clear — best-effort). The UI never mutates target memory directly; it drives the bridge headlessly through `FlowState` via `CEBridge`.
- Main-thread CE execution: every bridge command touching Cheat Engine runs on the main thread; freeze/display are background workers that only issue bridge calls, never spawn CE-touching threads on their own.
- Resource cleanup: every long-lived resource created here (hardware breakpoints, DBVM watches, code patches) must register in the bridge's zombie-cleanup registry so a bridge restart or re-executed Lua never leaks them.
- Breakpoint posture: hardware DR0–DR3 breakpoints and DBVM watches are preferred over `0xCC` software breakpoints for locating the writer instruction.
- Handlers branch on 32/64-bit target and use pointer-sized reads for pointer-width data; responses carry the architecture where shape depends on it.
- Wire/result convention: bridge calls return `{success:true,...}` or `{success:false,error,error_code}` from a closed vocabulary; addresses passed as hex strings or ints.
- New Lua capability additions follow the pairing rule: a global `cmd_<method>` handler + dispatcher entry + MCP tool with the identical method name, never `local`; all long-lived Lua tables and handlers stay global.

## UX & Interaction Patterns

- Two split acknowledgement checkboxes in the Setup modal (`Freeze acknowledgement` / `Patch acknowledgement`) each show adjacent one-line risk copy; an explicit `Disarm` control lives in Extras; unchecked gates keep their respective controls disabled.
- When either gate is armed, a sticky header banner reads: `UNSAFE ARMED — Freeze/Patch can corrupt saves. Restores on clean quit only; killing the app may leave game memory changed. Offline games only.` It is text + icon (never color-only), never dismissible while armed, with compact armed chips mirrored adjacent to the Freeze ON and Patch writer controls. This banner is the app's ONLY amber-colored element.
- Freeze/Display controls live on the Extras surface as a Mode selector (`one_shot` / `freeze` / `display`) plus Freeze ON/OFF; Freeze ON requires a just-in-time confirm and snapshots address + label; Freeze OFF logs restore status, and turning off with nothing active states that no active freeze exists for that label.
- `Patch writer (stubborn value)` requires the per-session Patch gate plus a just-in-time confirm with this exact risk copy: `Change the value in-game now so the watch can catch the writer of {address}. This attaches a debugger and patches code. It can crash or corrupt saves. Offline saves only. Continue?` Unique-signature-only; otherwise `Patch skipped {reason}`; success logs the patched address + signature with an automatic-restore note. Both Freeze ON and Patch writer are excluded from the Enter-default button and require their explicit confirm.
- Refusal/no-selection states use field-named error messages naming the exact failing context, paired with icon+text — never color-only.
- Clean quit presents a restore checklist with per-item restored/failed status; the next launch after a forced kill shows a stale-state recovery banner documenting the kill-path limitation.
- Expected log vocabulary for this epic (exact copy): `Freeze ON: {label} @ {address} = {value}`, `Freeze OFF (restored): {label}`, `No active freeze for {label}.`, `Patched writer {addr} (sig {sig}). Restored automatically on exit.`, `Patch skipped {reason}`, `Patch failed`, `Adjust a value first.`

## Cross-Story Dependencies

- Story 4.1 must ship before 4.2 and 4.3 functionally: the gates and armed banner are the sole state both Freeze and Patch controls rely on.
- Freeze, Display, and Patch all bind to values produced by Epic 2's capture/extract/scan loop — they require a selected value row with a resolved address (`module_offset` + `signature`) from a completed scan; no selection means all three are no-ops.
- The Patch confirm dialog asks the user to change the value in-game so the watch can catch the writer — this reuses the Epic 2 verify/re-screenshot interaction rather than introducing a new capture flow.
- Epic 1's offline-only refuse gate disables Freeze, Patch, and Adjust for refused targets until the target changes; dismissing the refusal dialog never re-enables writes.
- The clean-quit restore checklist is shared with the app-wide shutdown flow and must coexist with profile/RUNBOOK persistence from Epic 3; re-attach after force-kill re-resolves addresses via the Epic 3 anchor ladder, so any change to that ladder affects this epic's recovery behavior.
