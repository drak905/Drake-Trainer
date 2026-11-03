---
title: '4-2-freeze-and-display-with-restore-on-quit'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Freeze ON binds to the live listbox selection instead of a snapshot (retarget hazard), lacks the just-in-time confirm before it starts writing, Display mode does nothing (no read-only poller UI), and quit-time restore has no per-item checklist; next-launch stale-state recovery does not exist.

**Approach:** Snapshot-bound freeze with just-in-time confirm using the freeze gate, a display-mode poller (read-only live readout via the existing DisplayWorker), a clean-quit restore checklist dialog with per-item status, and a next-launch stale-state recovery banner after unclean shutdown.

## Implementation Notes

- Freeze binds to the write_result snapshot (label/address/value) — changing selection never retargets; no address → `Adjust a value first.`
- Just-in-time Freeze preview dialog (Enter=No) before start; mark_session_active() on freeze and patch; clean quit clears the stale marker.
- Display mode starts a DisplayPoller (read-only) whose callback posts to a queue drained by the UI thread every 500ms; Freeze OFF stops a display poller first.
- FlowState.shutdown returns per-item restore results (freezes via worker.restore() now checked against bridge success; patches via write_memory success); clear_all_breakpoints preserved; on_close shows the restore checklist (Restored/FAILED per item + counts).
- Stale-state recovery banner at startup when the marker survives (auto-hides after 15s, text restored; stays if UNSAFE armed).
- Tests: snapshot binding + gate, quit checklist per-item + counts, recovery banner.
- Offline gate: 216 passed, 4 deselected.
- Review pass: blind-hunter N=4. Patched: restore success verified, breakpoint clear kept, patch marks session, banner text restore after auto-hide, display OFF, freeze_off snapshot label. Deferred: per-game marker isolation, marker content richness, shutdown exception surface, duplicate restore walk refactor, display poller stale address, drain-loop TclError guard.

