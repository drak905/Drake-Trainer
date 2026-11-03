---
title: '3-4-draft-wishlist-and-promote'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Draft rows render as `[UNVERIFIED]`/`[verified]` bracket+caps (banned by UX-DR9 — signaling must be word+icon, never brackets or case), and promote has a dead unverified gate (`if not verified: pass`) that promotes unverified drafts into the live profile.

**Approach:** Signal drafts with `✅ Verified:` / `⚠️ Unverified:` prefix rows, make promote refuse unverified drafts with an explanation, and pin refused+promoted paths with tests.

## Implementation Notes

- main.draft_cheats: rows `✅ Verified: {label} ({category}): {look_for}` / `⚠️ Unverified: ...`; logs Manual traps + wholesale-replace copy unchanged.
- main.promote_draft: unverified → refusal dialog `... is unverified — verify it in-game first. Re-run Draft cheats after the values change to refresh.`; verified → promote + `Promoted {label} to live profile.`
- Tests: row signaling, refusal blocks promote (state + files untouched), verified promote writes cheat + log.
- Offline gate: 209 passed, 4 deselected.
- Review pass: blind-hunter N=2. Patched: promote test paths + cleanup patches. Deferred: shared _stub_app conftest fixture (still duplicated), display-less hard-fail guard for CI runners, ⚠️ variation-selector portability on old Tk, row truncation for long look_for, direct verified-flip UI path.
