---
title: '2-2-capture-the-game-window'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Capture works when CE returns a window rect, but there is no fullscreen fallback when `get_window_rect` fails (CE_API_UNAVAILABLE / rect API missing), which the story AC and PRD open Q1 require; capture failures also leak raw exception strings without the field-associated copy.

**Approach:** Add a fullscreen fallback path (primary-monitor grab) in screenshot.py, wire it into App.capture with a log line recording the de-facto path, and keep the existing failure contract (no values cleared, nothing written).

## Implementation Notes

- screenshot.fullscreen_rect(): mss monitors[0] (all displays) with empty-monitors RuntimeError; docstring documents multi-monitor coverage.
- main.App._grab_game_rect(handle): shared window-rect → fullscreen fallback, log includes triggering exception; used by capture() and verify() so both snapshots share geometry.
- Failure copy `Capture — failed: {exc}`.
- De-facto path (PRD Q1): window rect is primary via CE GetWindowRect executeCode fallbacks; fullscreen-virtual-screen is the implemented fallback. Live proof against a real game window still pending — requires CE bridge + attached game (live pytest gate), deferred to first live-harness session.
- Offline gate: 177 passed, 4 deselected (live).
- Review pass: blind-hunter N=3. Patched: verify() shares the fallback, log wording "falling back" + reason included, monitors[0] multi-monitor, no-monitors guard, dimension assertions, fallback-failure test. Deferred: scoped exception types on the rect fallback; capture copy migration of legacy dialogs.

