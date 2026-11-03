---
title: '2-1-attach-to-the-game-process'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Attach mostly works, but the story 2.1 acceptance is violated in two ways: the failure dialog uses `Attach failed` without the field-associated `Process — Attach failed: {reason}` copy or focus return, and the attach path introduced in story 1.3 calls non-passive `get_process_info` for the post-attach name recheck, which the AC explicitly forbids (side-effect-free `get_opened_process_id` only).

**Approach:** Move the PID→name resolution to a passive `get_process_list` lookup pre-attach (catching the PID-bypass there), delete the `get_process_info` call, and apply the field-associated error copy + focus return on attach failure.

## Implementation Notes

- flow.attach_process: numeric selection resolves name via passive get_process_list (`_resolve_pid_name`, per-row guards); get_process_info deleted from attach path; isdecimal + single parse; resolved name kept as process_name for PID attaches; locked-PID guard uses numeric flag.
- main.App.attach: ATTACH_FAILED_TEMPLATE `Process — Attach failed: {reason}` constant + exact-copy test; focus + select-all on proc_entry for both failure branches.
- Tests: test_attach_contract.py (passive-only, PID send raw, malformed rows, failure state, exact copy) + updated test_main_flow/test_offline_gate sequences.
- Offline gate: 172 passed, 4 deselected (live).
- Review pass: blind-hunter N=4. Patched: per-row list guards, resolved-name persistence, isdecimal, copy constant+test, focus/select on failure, positive PID test. Deferred: ce_client consolidation, fail-open bypass decision, TOCTOU second lookup, vestigial modules param (see deferred-work.md).

