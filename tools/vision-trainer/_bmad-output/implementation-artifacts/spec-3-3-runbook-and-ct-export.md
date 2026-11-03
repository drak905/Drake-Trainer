---
title: '3-3-runbook-and-ct-export'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The .CT export emitted a NON-functional AA script for signature-anchored cheats (a `// TODO: insert patched bytes` placeholder — a silent no-op in Cheat Engine), and the runbook hard-coded ×100 into entry headings while the multiplier/fallback audit fields collected in flow were dropped on the floor by the formatter.

**Approach:** Rewrite the signature-anchored export as a functional [ENABLE]/[DISABLE] value-write AA script (per-type directives, sanitized symbol), skip-with-reason cheats whose target/type make the script impossible, and render multiplier + fallback_used in the runbook entry format.

## Implementation Notes

- profiles._aa_script_for_signature: returns None for missing target or unknown value_type (export adds skip-with-reason, no silent drops, no value wipes); directives db/dw/dd/dq + (float)/(double); sanitized symbol names.
- runbook.format_entry: heading shows recorded multiplier (omitted when absent rather than fabricating ×100); fallback_used line added.
- Export dialogs copy preserved: `No profile cheats yet.` / `Exported {n} entries to {dest}.` / per-skip lines (existing main.export_ct behavior).
- Tests: signature export functional ([ENABLE]/[DISABLE], dd directive, no TODO), no-exports-when-invalid, runbook multiplier + fallback rendering.
- Offline gate: 206 passed, 4 deselected.
- Review pass: blind-hunter N=5. Patched: double handling, no-value skip, unknown-type skip, sanitized symbols, DISABLE note, multiplier fabrication removed, fallback disclosure line. Deferred: [DISABLE] auto-restore via recorded original value, _aa_script_for_patch modernization, re-enable overwrite semantics note in script comments, profile-side multiplier persistence.
