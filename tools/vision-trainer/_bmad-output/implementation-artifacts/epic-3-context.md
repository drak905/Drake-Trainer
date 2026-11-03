# Epic 3 Context: Cheats That Survive Restart

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

After a cheat is proven in-game and confirmed, its memory location must stop being a throwaway secret. This epic makes confirmed cheats durable: they save atomically into a per-game profile carrying engine-independent anchors (module+offset, signature, pointer chain), re-locate after a game restart with no rescan, and can be sanity-checked offline without a game attached. Alongside, verified successes accumulate into an append-only per-game RUNBOOK and can be exported as a Cheat Engine table, and wishlist words become unverified draft cheats that each carry a verification hint — so guessing can start somewhere without ever polluting the proven profile. Together this delivers the restart-resilience journey (UJ-2) and validates success metric "a saved cheat re-locates via anchor without rescan on the same game build."

## Stories

- Story 3.1: Atomic profiles with anchor re-location
- Story 3.2: Offline profile validation
- Story 3.3: RUNBOOK and .CT export
- Story 3.4: Draft wishlist and promote

## Requirements & Constraints

- Confirmed cheats upsert a per-game `<Game>.json` (schema v1) storing module+offset, signature, and pointer-chain anchors; raw `last_address` may be stored as informational only, never trusted for re-location under ASLR. Saves are atomic — a partial or failed save must never corrupt the existing profile file.
- Re-location on the same game build resolves module_offset → signature → pointer_chain → rescan fallback, with no full rescan. An ambiguous (non-unique) signature raises for user resolution at its rung and falls through to the next rung; it is never silently picked.
- Every re-applied write is preceded by a per-cheat plan-plus-confirm showing address, label, and old→new. Merely opening a profile must never auto-write.
- Offline validation (`Validate profile` button) runs with no game attached, checks schema and anchor integrity, and lists per-cheat pass/fail with the failure reason; validation must never modify files.
- RUNBOOK is append-only per-game Markdown under the app data directory, appended only on the user's Yes, never on a No answer; it is viewable in-app with a friendly "no runbook yet" state.
- `.CT` export opens a save dialog (default filename `cheats.CT`) and maps every profile cheat to a plain entry, an auto-assembler script, or skipped-with-reason; no silent drops — every skip is reported.
- Draft cheats write to a separate `<Game>.draft.json` that is replaced wholesale per run; each draft carries a `lookFor` hint for in-game verification. Unpromoted drafts must never touch the live profile, and promotion happens only per individually verified draft with explicit confirmation.
- Six manual-only trap categories (runspeed, speed, nosearch, hunger, cash, curfew) must never be auto-drafted; drafting them is refused with a labeled reason.
- A multiplayer/anti-cheat refusal gate (best-effort heuristics + user attestation — an accepted assumption, not a perfect detector) still applies to everything this epic touches; no write path may bypass it. Freeze/patch paths unrelated to this epic also still require their UNSAFE acknowledgement.

## Technical Decisions

- Persistence (`profiles`, `runbook`, draft/factory logic) is a bridge-free leaf layer: no dependency on the CE bridge, transport, or MCP server. UI drives it through the headless flow state and `CEBridge` only — never direct CE API calls, and persistence never reaches the wire itself.
- Anchor ladder order and semantics are fixed system-wide (`module_offset → signature → pointer_chain → rescan callback`); profile saving, scan flow, and any export consume this ladder — do not invent a second ordering. All bridge/flow consumers share one mutation-ownership convention with restore-on-exit, so drafts replace wholesale and promote only on explicit user confirmation. Force-kill residue has no automatic owner: re-attach must re-resolve via the ladder and explicitly re-apply, never assume an old address or value.
- Bridge responses carry a closed `error_code` vocabulary (e.g. `NOT_FOUND`, `INVALID_PARAMS`, `PERMISSION_DENIED`, `INTERNAL_ERROR`); unknown codes are treated as `INTERNAL_ERROR`, and clients must never crash on them. Addresses serialize as hex strings and parse as string-or-int.
- Every long-lived bridge resource (hardware breakpoints, DBVM watches, scans) is registered in a cleanup registry torn down when the bridge stops before it restarts, so re-executing the Lua bridge is always safe.
- Known open engine question: whether Cheat Engine resolves `game.exe+0x1234`-style module+offset symbol strings directly, or whether a parsing fallback is needed in the anchor module's exact-match rung — verify against real CE behavior and record the de-facto path.
- Stack: Python >= 3.10 (floor exposed at 3.10's 2026-10-31 end-of-life — plan the bump to >= 3.11), Cheat Engine 7.6 baseline (7.7 compatibility check owed), Tkinter stdlib UI, pywin32 for pipe transport; pytest runs offline by default (`-m "not live"`), with live CE/LLM tests a separate opt-in marker (`-m live`).

## UX & Interaction Patterns

- Drafts surface (Extras row): wishlist entry prefilled `health,stamina,money` + a "Draft cheats" button + a "Promote selected draft" button beside a drafts listbox. Each draft row prefixes `Unverified:` or `Verified:` as icon+text — conveying verified state by styling/color/brackets/case alone is never acceptable. Drafting logs `Drafts written (replaced): {path}. Verify each in-game before promoting.`; promoting with no drafts shows `Draft cheats first.`; a successful promotion logs `Promoted {label} to live profile.`
- Profiles surface (header): `Validate profile`, `View Runbook`, `Open Profiles Folder`, and Export `.CT`. `View Runbook` with an empty runbook shows `No runbook yet.` (showinfo, never an error dialog); runbook open failure shows a field-named showerror. Export empty shows `No profile cheats yet.`; success shows `Exported {n} entries to {dest}.` with per-skip `Skipped {label}: {reason}` lines preserved.
- Restart/anchor failure must never silently pick a stale or guessed address; request user resolution and let the user refine manually — no hidden exact-write path exists.
- All showerror dialogs field-name the failing surface (the established pattern: `{Surface} — {Action} failed: {reason}`), mirror the message inline next to the relevant entry, move focus there on dismiss, and rely on icon+text rather than color alone.
- Accessibility floor (WCAG 2.2 AA intent): named widgets, polite live-region status text (the disabled log stays visual-only), Tab order matching reading order, explicit focus ring, ≥24×24 targets, drafts signal by word not styling; verified with Narrator + NVDA in both themes and at 125/150/200% scaling with no loss or overlap.

## Cross-Story Dependencies

- Story 3.1 feeds 3.2 and 3.3: offline validation and both RUNBOOK and `.CT` export operate on exactly what 3.1 saves. Story 3.1's atomic save path is also what Epic 2's verify-yes persistence (Story 2.5) and 3.3's `RUNBOOK updated:` append hang off; the anchor data (module_offset + signature) comes out of Epic 2's expanded scan.
- Story 3.4's promotion uses Story 3.1's atomic save path to upsert into the live profile; drafts are generated by the factory, and the manual-trap category list is a shared constant defined in the category module — not re-implemented per story.
- The per-game file naming (profile, draft, runbook) derives from the attached game identity resolved in Epic 2's attach story; all paths live under the app data folder (`%APPDATA%\VisionTrainer`), whose exact ownership is a flagged open operational gap, not yet decided.
- The anchor ladder in Story 3.1 is also what Epic 4's force-kill-recovery re-resolution goes through; do not fork the ladder. Epic 4's UNSAFE gates gate freeze/patch only — nothing in this epic requires them.
