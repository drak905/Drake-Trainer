# Reconcile — technical-rust-tauri-vs-python-tkinter research vs UX spines

Input: `research/technical-rust-tauri-vs-python-tkinter-trainer-app-2026-10-02/research.md` (verdict: stay on Python + Tkinter, harden).
Spines: `ux-Trainer_Application-2026-10-02/DESIGN.md` + `EXPERIENCE.md`. Spines unchanged by this file.

## UI-relevant claims → spine coverage

- **CustomTkinter 6.0.0 (Jun 2026, MIT, ~570KB, drop-in, modern widgets) [6] → honored.** Both spines pin 6.0.0 drop-in; DESIGN §Brand + Components inherit 80% from CustomTkinter, deltas only.
- **Correct Windows HiDPI via CustomTkinter [6] → honored as assertion.** DESIGN §Layout: "HiDPI correct via CustomTkinter; no custom DPI handling." EXPERIENCE Foundation repeats it.
- **PyInstaller one-dir retained; one-file only slows startup [15] → honored.** Both spines state one-dir kept; EXPERIENCE bans installer/step-nav additions.
- **Dark mode via CustomTkinter [6] → honored as system-follow.** DESIGN Colors/Do's: inherit Windows light/dark via appearance mode; EXPERIENCE Cold load: theme follows Windows.
- **Tauri/WebView rejected (offline +127–180MB, installer-centric) [2][3] → honored.** DESIGN explicitly rejects Tauri; EXPERIENCE bans web-UI surfaces.

## Gaps (4)

1. **SmartScreen first-launch UX undefined** — research [5]: warnings + reputation-building invariant, signing deferred; spines ban signed-installer work and define no copy/behavior for the expected one-dir SmartScreen warning.
2. **No DPI acceptance check** — spines assert correctness, but research cites two separate mechanisms ([6] CustomTkinter HiDPI vs [14] hidpi-tk workarounds); no Win10/11 or 125%/150%/200% verification defined.
3. **Widget-parity spike missing** — research next step (a): spike 6.0.0 on one wizard screen; spines list ttk widgets (Combobox, Listbox h6/h8/h5, dialogs) reused as-is with no parity/pin check for 6.0.0 equivalents.
4. **Theme-follow edge behavior undefined** — research claims dark-mode support only, not auto-follow; spines assume appearance-mode follow with no manual override or runtime OS-theme-switch behavior.

## Dropped nuances (intentionally not in spines)

- Tauri 2.12.0 / v3-alpha vitality [1][4]; WebView2 modes/bootstrapper sizes [2][3]; MSI/WiX/NSIS + cross-build friction [2]; updater signing-keypair overhead [11].
- Signing price tiers (OV/EV), EV-bypass removal 2024, Store-MSIX exception [5] — beyond deferred-signing decision.
- Rust slices: Tokio pipes [8], reqwest [9], xcap/JPEG [10], unsafe RPM/WPM + windows-crate churn [12][13]; CE framing/scan ergonomics unverified.
- Rewrite 2–4x model is stale-2018, uncontradicted [7]; sidecar hedge doubles packaging [16][17]; Tkinter ceiling (video/canvas/cross-platform) watch-item; open Qs (IPC benchmarks, occluded capture, SSE, RPM wrappers).
