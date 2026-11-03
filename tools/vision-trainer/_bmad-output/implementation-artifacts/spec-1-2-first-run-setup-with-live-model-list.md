---
title: '1-2-first-run-setup-with-live-model-list'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** First-run setup in vision_trainer/main.py SetupDialog mostly works but has small gaps against story 1.2: no auto-Refresh on open, no focus return to the Settings button, no destroyed-window guard on the after(100) auto-open.

**Approach:** Close the gaps in the existing SetupDialog and open_settings path so the story 1.2 acceptance holds on real Windows.

## Implementation Notes

- Gaps closed in vision_trainer/main.py SetupDialog/open_settings: _auto_open_settings destroyed-window + stage guard; open_settings focus return to invoker with self fallback; refresh status line (Loading, Failed prefix, empty-list guidance).
- Tests in vision_trainer/tests/test_shell_launch.py: prefill default endpoint, save validates before probe, unreachable shows message.
- Offline gate: 161 passed, 4 deselected (live).
- Review pass: blind-hunter N=3. Patched: refresh failure prefix + empty-list copy; stage re-check; focus fallback. Deferred: threaded network calls + re-entrancy guard; transient/centering/initial-focus; cancel-path log/re-prompt; shared Tk fixture + save_config-not-called asserts.

