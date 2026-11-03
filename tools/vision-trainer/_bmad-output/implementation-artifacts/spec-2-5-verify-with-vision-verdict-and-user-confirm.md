---
title: '2-5-verify-with-vision-verdict-and-user-confirm'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Verify re-screenshots and asks, but the dialog lacks the `default="no"` safe default, the No path does not log the refine line through the app flow, and the Yes path required a separate button click instead of persisting directly — the story AC requires Yes to persist Profile + RUNBOOK from the dialog itself.

**Approach:** Gate verify on a completed write, make the confirm dialog default No, wire Yes to confirm_yes() and No to confirm_no(), and pin the exact copy plus both persistence outcomes with tests.

## Implementation Notes

- verify(): guard for missing write/before_b64 (`Adjust a value first.`); Yes on the dialog runs confirm_yes() directly (atomic profile + RUNBOOK); No runs confirm_no() (stage refine + refine log line). askyesno default="no" — Enter means No.
- VERIFY_CONFIRM_TEMPLATE constant, story-pinned exact copy; pinned at the call site too (askyesno received the formatted template).
- Tests: yes persists runbook+profile (stage done, done dialog), no writes nothing + write_result retained for the next refine round, gate without write, exact copy.
- Offline gate: 195 passed, 4 deselected (live).
- Review pass: blind-hunter N=3. Patched: pre-write guard, call-site copy pin, done-dialog assertion, no-path state pin, helper cleanup. Deferred: match=False semantics (currently surfaced in log; user verdict still rules), stage-gating re-verify after done, comma formatting normalization, README/CI doc updates for the safe-default behavior.
