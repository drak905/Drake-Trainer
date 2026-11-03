---
title: '4-3-patch-writer-with-unique-signature-rule'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Patch writer's confirm dialog lacked the AC's full risk copy (debugger attach, crash/corrupt-saves warning, offline-saves-only line) and had no Enter-safe default; a non-unique signature surfaced as a generic `Patch failed` error instead of the required `Patch skipped {reason}`.

**Approach:** Use the exact PATCH_CONFIRM_TEMPLATE with `default="no"`, route AmbiguousSignature to the Patch-skipped dialog, keep skip-classified writers unpatched, and pin classification + logging with tests.

## Implementation Notes

- main: PATCH_CONFIRM_TEMPLATE (AC exact copy) + `default="no"`; AmbiguousSignature → `Patch skipped {reason}` showinfo (not a failure); PatchError stays `Patch failed`; success path logs `Patched writer {addr} (sig {sig}). Restored automatically on exit.` and marks the session for stale-state recovery.
- codepatch.classify_instruction: register-store regex extended to x64 r-prefixed registers (rdx/rsi/r15d previously misclassified as skip).
- Tests: exact copy, ambiguous→skipped (errors empty, default no), success logs + session marker, classification matrix incl. skip shapes.
- Offline gate: 220 passed, 4 deselected.
- Deferred: per-RIP-relative relocation check (out of scope, skip is the safe posture), 64-bit size-aware NOP widths, breakpooint-size selection from instruction size.
