# Epic 1 Context: Setup & Safe Foundation

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Drak can configure the app once and be protected from wrong targets before anything else runs. This epic lays the rails every later epic inherits: the native-feeling single window, the Setup modal with live model list, and the offline-only refuse gate. It also proves the never-launched wizard actually renders on real Windows — the riskiest packaging unknown — before anything builds on it.

## Stories

- Story 1.1: Launch the app shell on real Windows
- Story 1.2: First-run setup with live model list
- Story 1.3: Offline-only refuse gate

## Requirements & Constraints

- Endpoint defaults to `http://localhost:20128/v1`; vision + adjust models come from the live `GET /models` list, never hardcoded; config persists to `%APPDATA%\VisionTrainer\config.json`; invalid endpoint/model fails with a validation message, never silently.
- Multiplayer/anti-cheat targets are refused before any scan: offline attestation + blocklist/heuristic check at the Process surface; on hit, detach, lock the PID, disable Adjust/Freeze/Patch until the target changes; dismissing never re-enables writes. Best-effort heuristics, acceptable for hobby scope.
- Windows 10/11 only; unsigned one-dir PyInstaller bundle (SmartScreen expected); no macOS/Linux, no signed installer in v1.
- Exact UX strings are load-bearing for a non-technical user: refuse copy, status vocabulary (`OK — {n} models`, `Endpoint unreachable: {exc}`), field-associated errors that name the field, mirror inline, and move focus on dismiss.

## Technical Decisions

- Brownfield: build on the existing `vision_trainer/` codebase, don't rewrite the working LLM-CLI-plus-MCP loop underneath it.
- UI (`main.py`) drives the bridge exclusively through headless `FlowState` via `CEBridge`, never the CE API directly.
- Safety gates: offline-only scope; shell-gated commands require `CE_MCP_ALLOW_SHELL=1` (default unset); TCP relay binds loopback only; CE `Query memory region routines` stays disabled.
- Python >= 3.10 (bump to >= 3.11 by 2026-10-31); Tkinter stdlib, moving to CustomTkinter 6.0.0 drop-in for theme/HiDPI.
- Python `debug_log()` to stderr only, never stdout (stdio guard for the MCP server path).

## UX & Interaction Patterns

- Single window, min 900x700, resizable with scrollable body grid: header row + disabled log + body grid, no step nav. CustomTkinter follows Windows light/dark; correct HiDPI at 125/150/200%.
- Setup is a modal with Tab trap + focus return; Settings re-opens it; Esc closes.
- Accessibility floor inherited by all later epics: named widgets, status line + live status text as polite live region (disabled log is visual-only), Tab order = reading order, explicit focus-ring outline, Narrator + NVDA verified, targets >= 24x24.

## Cross-Story Dependencies

- Story 1.1 (shell renders) enables 1.2 (Setup modal) and 1.3 (refuse gate UX); 1.2 and 1.3 are independent of each other.
- Epic 2 builds on this epic's shell, conventions, and error patterns; Epic 4's UNSAFE gates extend the Setup modal built in 1.2.
