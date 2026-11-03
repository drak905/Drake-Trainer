---
title: '1-3-offline-only-refuse-gate'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No offline-only refuse gate exists anywhere in vision_trainer/ — attach_process in flow.py attaches whatever process is named with no multiplayer/anti-cheat check, and main.py App.attach shows no refuse path.

**Approach:** Add a best-effort pre-attach gate (process-name blocklist plus loaded-module heuristics plus explicit user attestation) in flow.py with FlowState tracking locked PIDs, and wire the App.attach surface to show the exact refuse copy, detach, and disable Adjust/Freeze/Patch until the target changes.

## Implementation Notes

- New vision_trainer/offline_gate.py: name blocklist (launchers, multiplayer hints, anticheat tokens), loaded-module check, window-title check, exact REFUSE_MESSAGE copy.
- FlowState in vision_trainer/flow.py: locked_pids + refused flag; pre-attach name check with no bridge call; post-attach module + resolved-name (get_process_info) + title recheck with detach + PID lock; refused reset on entry; mismatch branches detach.
- App.attach in vision_trainer/main.py: passes window title, shows Refuse dialog on gate hit, disables Adjust/Freeze/Patch until target changes.
- Tests vision_trainer/tests/test_offline_gate.py: 6 tests incl. PID-bypass caught post-attach.
- Offline gate: 167 passed, 4 deselected (live).
- Review pass: blind-hunter N=5. Patched: PID-bypass post-attach name check; stale-state detach clearing; refused reset; mismatch-branch detach. Deferred: short-token false positives (eac/vgc) + allowlist; module-schema tolerance; title multiplayer/launcher hints; locked-PID eviction/reuse; cancel-path log; threading.

