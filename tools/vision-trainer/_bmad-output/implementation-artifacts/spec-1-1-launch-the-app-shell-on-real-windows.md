---
title: '1-1-launch-the-app-shell-on-real-windows'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Tkinter wizard in vision_trainer/main.py was never launched on real Windows per PRD open Q3, so the app shell may not render or behave as specified.

**Approach:** Prove App launches as the specified single window on real Windows and harden the small gaps blocking story 1.1 acceptance.

## Implementation Notes

- Proved App instantiates on this Windows box (Tk OK): title `Vision Trainer (offline games only)`, minsize 900x700, scrollable body grid, Esc closes Setup, log is non-focusable.
- Changes in vision_trainer/main.py: minsize(900,700); canvas+scrollbar scrollable body grid; SetupDialog Escape binding; log Text takefocus=False.
- New test vision_trainer/tests/test_shell_launch.py asserts title/minsize/scroll.
- Offline gate: 158 passed, 4 deselected (live). CustomTkinter 6.0.0 is NOT installed here (ModuleNotFoundError) — follow-up: add it to requirements-vision-app.txt (pinned customtkinter==6.0.0) and swap ttk imports in a later story; shell stays ttk until then.
- Review pass: blind-hunter N=5. Patched: canvas width sync + MouseWheel + stored window id; test rewritten (single root, no dead helper, asserts scroll wiring + takefocus + Escape). Deferred: threaded SetupDialog network calls; startfile fallbacks; promote_draft dead branch; dialog column weights. Verdicts: 1 false (log Text must stay non-focusable per a11y floor).

