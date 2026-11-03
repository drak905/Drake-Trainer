---
title: '3-2-offline-profile-validation'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No offline profile validation exists — the user cannot tell whether a saved `&lt;Game&gt;.json` still parses, has schema v1, or carries intact anchors without attaching a game, and there is no way from the app to run such a check.

**Approach:** Add a `validate_profile` function (schema/anchor integrity + per-cheat pass/fail, never modifies files) in profiles.py, plus a `Validate profile` header button that lists per-cheat results with reasons.

## Implementation Notes

- profiles.validate_profile: file-parse, schema-v1 (non-v1 suffix derived from SCHEMA_VERSION), per-cheat pass/fail rows (label, value_type, mode, anchor rung incl. capture-mode + patch shapes from export, target_value, duplicate labels, non-object entries), never modifies files.
- main: Validate profile header button; PASS/FAIL list with problems; log line + dialog; problems joined with newlines.
- Tests: pass/fail rows, missing file + corrupt + no-cheats-list + non-dict entries + schema 2, no-modification pin.
- Offline gate: 206 passed, 4 deselected.
- Review pass: blind-hunter N=3. Patched: non-dict entries, capture_mode/patch accepted shapes, duplicate labels, ALLOWED_VALUE_TYPES constant, newline joining, schema-suffix derivation. Deferred: exe-name mismatch warning, log-first display for big profiles, type-consistency of target_value, _profile_path helper dedup, module docstring report contract.

