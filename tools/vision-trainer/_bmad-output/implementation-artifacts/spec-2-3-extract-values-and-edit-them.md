---
title: '2-3-extract-values-and-edit-them'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Extract renders rows and gates Adjust on selection, but there is no editable value field — the story AC requires edit via field + Apply/discard with a dirty marker, numeric validation before any plan, and the plan echoing the exact committed operands.

**Approach:** Add an edit entry with Apply/discard next to the values list in main.py, with a per-row uncommitted-edit marker and numeric validation on Apply; committed edits flow into the existing adjust plan path unchanged.

## Implementation Notes

- main.py: Edit value entry (row 4) with Apply/Discard + Return binding; KeyRelease dirty marker via _pending_edits set; rows renumbered below the values list.
- _commit_operand(raw, value_type_hint): integer types (byte/word/dword/qword) demand int; float types reject inf/nan; shared _format_value_row helper.
- apply_edit shows `Edit failed` / `Edit — invalid number|integer: {raw}` with exact-copy coverage; discard restores the committed value; _on_value_select prefills the entry with the committed value; values_list exportselection=False so entry text selection cannot clear the listbox selection.
- Adjust flow unchanged — the committed value is what the plan uses (plan echoes exact committed operands).
- Offline gate: 184 passed, 4 deselected (live). Known flake: Tk root creation can intermittently raise TclError in full-suite runs on this box (skipped test); passes in isolation.
- Review pass: blind-hunter N=4 (two passes). Patched: pending set type, Return binding TypeError, per-type integer parse + error copy, discard restores committed value, selection-sync prefill, exportselection, shared row formatter, dead payload removed, test hygiene. Deferred: hex input support, byte-type range bounds, stale marker after row switch, silent in-progress text loss on row switch, CE types beyond _INTEGER_TYPES.

