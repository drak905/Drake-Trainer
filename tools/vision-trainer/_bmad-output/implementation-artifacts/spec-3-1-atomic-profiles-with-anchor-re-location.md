---
title: '3-1-atomic-profiles-with-anchor-re-location'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Profile saves are non-atomic (plain open-for-write in profiles.save corrupts the file on partial writes), the anchor ladder aborts on an ambiguous signature instead of falling through to the next rung as AD-7 requires, and no re-apply path exists: a saved profile is never resolved and re-written after a restart (UJ-2 is unimplemented).

**Approach:** Make profiles.save atomic (temp file + os.replace), make ambiguous signatures fall through the ladder (raise only when no rung resolves and no rescan), and add FlowState.reapply_profile with a per-cheat plan (address, label, old→new) that never writes without a confirm callback, wired to a Re-apply profile button.

## Implementation Notes

- profiles.save: unique temp file + fsync + os.replace (atomic; readers see old or new).
- anchor: ambiguous signature falls through to pointer_chain/rescan; AmbiguousSignature raises only when no rung resolves and no rescan. Fall-through pinned by test.
- FlowState.reapply_profile: per-cheat resolve (module_offset → signature → pointer_chain; rescan=None so no auto-rescan), then per-cheat plan+confirm writer({cheat, address, old_value, new_value, label}) before any write; write success checked; mode honored (display → readout-only no write; freeze → start_freeze re-establish); learned anchors (relocated module_offset/signature/last_address) persisted back to the profile.
- main: Re-apply profile header button; requires attach; refuse/patch copy per re-apply outcome; summary line; per-cheat dialog via PreviewDialog (Enter = No).
- Offline gate: 200 passed, 2 skipped (environment Tcl flake).
- Review pass: blind-hunter N=5. Patched: write-success check, mode semantics (display/freeze), learned-anchor persistence, unique tmp name, writer-payload docstring, empty-profile + summary UX. Deferred: rescan-rung verification, load-corrupt error surfacing + schema check, writer-exception batch abort, float/double re-apply coverage, signature AA script TODO bytes (story 3.3 scope).

