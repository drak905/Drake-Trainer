---
title: '2-4-parameterized-plan-and-expanded-scan-to-one-address'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The adjust flow hardcodes ×100 with no user multiplier, no blocking write-preview dialog (the NFR "never write unseen" gate), and the plan does not record a fallback disclosure. Users can't set a multiplier per write and the write happens without a previewed consent dialog.

**Approach:** Add a multiplier entry (prefilled 100, validated 1–1000000), thread the multiplier through llm_client planning (model + fallback), and split scan/write by giving the scan ladder a writer callback that shows the blocking write-preview dialog (address, label, extracted × multiplier = target, fallback disclosure, CE safety status; Write/Cancel, Enter-safe default No).

## Implementation Notes

- Multiplier entry (prefilled 100) validated 1–1000000 with exact copy; threaded through compute_write_plan (payload echo) + fallback_write_plan (target = value × multiplier).
- PreviewDialog: blocking Write/Cancel modal; Enter + Escape both cancel (safe default No); shows address, label, observed × multiplier = target with scan_option/tolerance/clamped, fallback disclosure, CE safety status.
- scanFlow: writer callback REQUIRED (ScanError when missing — unreachable writes banned); WriteCancelled raised on cancel; main logs "Back to refine" once and sets stage=refine.
- write_result carries multiplier/fallback/clamped; runbook entry records multiplier + fallback_used (durable audit).
- module+offset (PRD Q2): get_address_info symbolic_name (e.g. `game.exe+1234`) is stored verbatim as module_offset anchor; signature from generate_signature with module prefix. Pinned by test (get_address_info + generate_signature sequencing). CE-side resolution of the symbol string remains a live-gate check.
- Offline gate: 192 passed, 4 deselected (live). Recurring environment flake: intermittent Tcl init failure creating Tk roots mid-suite; _stub_app retries once.
- Review pass: blind-hunter N=6. Patched: runbook/audit fields, FlowState init, Return→cancel, preview detail lines, exact multiplier display, duplicate log line, writer-required enforcement, tests (validation, cancel path, multiplier echo). Deferred: model-reply clamp/scan_option validation, pre-write read of current memory, ×100 default removal in scan_flow fallback, ADJUST_SYSTEM scan_option defaulting.

