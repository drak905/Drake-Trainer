---
name: Trainer_Application
status: final
sources:
  - _bmad-output/planning-artifacts/prds/prd-Trainer_Application-2026-10-02/prd.md
  - _bmad-output/planning-artifacts/research/technical-rust-tauri-vs-python-tkinter-trainer-app-2026-10-02/research.md
updated: 2026-10-02
---

# Trainer_Application — Experience Spine

> Solo Windows offline vision-to-CE trainer. Single-window Tkinter → CustomTkinter 6.0.0. Paired with `DESIGN.md`. Visual specs live in `DESIGN.md`; this spine owns behavior. Spine wins on conflict.

## Foundation

Windows desktop single-window Tkinter app (as-built `main.py`), styled via CustomTkinter 6.0.0 drop-in per research + user decision: follow Windows light/dark, minimal brand color, correct Windows HiDPI, PyInstaller one-dir kept. Window title `Vision Trainer (offline games only)`, minimum 900x700, header row + disabled log + body grid, no step nav [ASSUMPTION: 900x700 minimum and layout retention inferred from as-built + memlog assumption]. Offline-only (FR-1 endpoint default `http://localhost:20128/v1`, `config.json`); refuse multiplayer/anti-cheat (FR-13). Flow backbone per PRD: setup → attach → capture → extract → adjust/multiplier → CE expanded scan → one-shot write → verify → Profile + RUNBOOK. Visual identity reference: `DESIGN.md` (`{colors.brand-accent}`, `{colors.warning-amber}`, `{typography.body}`, `{spacing.gutter}`, `{components.button-primary}`, `{components.unsafe-armed-state}`).

## Information Architecture

All surfaces live in one window; no step navigation in as-built.

| Surface | Reached from | Purpose |
|---|---|---|
| Setup (modal) | App first-run / header Settings | Endpoint entry (default `http://localhost:20128/v1`), vision/adjust comboboxes, Test/Save/Refresh, UNSAFE gate checkboxes + `Disarm` state; re-opens via Settings (FR-1) |
| Process | Body grid | Entry + Attach + Refresh list + PID-name listbox; attach by name/PID validated (FR-2) |
| Capture | Body grid | Title entry + Capture; named-window capture ≤1280px JPEG Base64, no writes (FR-3) |
| Extract | Body grid | Extract values + values listbox (`label: value [type] conf=0.XX`); editable via field + `Apply` / discard with dirty marker (FR-3) |
| Adjust | Body grid | Multiplier entry (prefilled `100`) + blocking write-preview dialog (`Write` / `Cancel`) showing extracted × multiplier = target; local fallback via `Use local ×100 fallback` / `Abort` (FR-5) |
| Verify | Body grid | `Verify (re-screenshot)` + `Yes — confirmed` / `No — refine` (defaults `No`); re-screenshot + vision verdict + modal confirm, only Yes persists (FR-7) |
| Freeze / Display | Extras: Mode combobox (`one_shot/freeze/display`) + Freeze ON/OFF | UNSAFE-gated freeze/display, restore on quit (FR-8; UJ-3) |
| Patch | Extras: `Patch writer (stubborn value)` | Unique-signature-only patch, restore on exit (FR-9) |
| Drafts | Extras: wishlist entry (default `health,stamina,money`) + Draft cheats + Promote selected draft + drafts listbox with `Verified:` / `Unverified:` icon+text prefixes | Wishlist→`draft.json` wholesale with `lookFor`, promote individually; manual-only traps (runspeed, speed, nosearch, hunger, cash, curfew) log `Manual: {label}: {reason}` and never auto-draft (FR-4) |
| Profiles / RUNBOOK / Export | Header: View Runbook, Open Profiles Folder, `Validate profile`, Export .CT | Atomic `profile.json` schema v1 + anchor ladder (FR-10); `Validate profile` lists per-cheat pass/fail (FR-11); append RUNBOOK on Yes (FR-12); Export via save dialog (`Cheat Table *.CT`, `cheats.CT`) mapping plain/AA script/skipped-with-reason (FR-12) |
| Settings | Header Settings | Re-opens Setup modal (FR-1); hosts per-session UNSAFE gate checkboxes + `Disarm` state |

## Voice and Tone

Microcopy uses the exact as-built strings. Brand voice lives in `DESIGN.md`.

| Do (exact string) | Don't |
|---|---|
| Confirm: `Value now shows {observed} (expected {expected}). Correct?` (`askyesno`, defaults `No`) | Reword the verdict question or block on it |
| Patch confirm: `Change the value in-game now so the watch can catch the writer of {address}. This attaches a debugger and patches code. It can crash or corrupt saves. Offline saves only. Continue?` | Auto-start the writer watch without asking, or omit the risk suffix |
| `No runbook yet.` (`showinfo` Runbook) | Show an empty runbook surface as an error |
| `Select a value first.` (Adjust with no selection) | Write with no selection |
| `Adjust a value first.` (Freeze/Patch with no selection) | Same — never freeze/patch unselected |
| `No active freeze for {label}.` | Silently no-op on freeze-off |
| `Patch skipped {reason}` | Write a non-unique signature anyway |
| `Draft cheats first.` (Promote with no drafts) | Promote from empty drafts |
| `No profile cheats yet.` / `Exported {n} entries to {dest}.` | Export silently |
| Status: `{n} models found` / `OK — {n} models` / `Failed: {exc}` / `Endpoint unreachable: {exc}` | Invent status vocabulary |
| Log: `Adjust model unreachable — local ×100 fallback.` | Hide the fallback |
| Log: `Drafts written (replaced): {path}. Verify each in-game before promoting.` | Draft without the verify reminder |
| Scan narrow: `{exc} Change the value in-game, then use Verify to continue narrowing.` | Auto-rescan without the user changing the value |
| Done: `RUNBOOK updated:` (verdict logged) | Persist on No / non-Yes |
| 6 manual traps (`categories.py MANUAL_ONLY`: runspeed, speed, nosearch, hunger, cash, curfew) refuse with `Manual: {label}: {reason}` — never auto-drafted | Write through a manual-trap hit |

## Component Patterns

Behavioral. Visual specs live in `DESIGN.md` (or CustomTkinter defaults when inherited).

| Component | Use | Behavioral rules |
|---|---|---|
| Setup modal fields | Setup | Endpoint entry + vision/adjust comboboxes (live `/models` dropdown); Test → status line; Save → `config.json`; Refresh → model list; Escape closes, Enter activates focused button [ASSUMPTION: Enter/Escape mapping inferred from standard modal behavior] |
| UNSAFE gate checkboxes (override: first-run-only replaced) | Setup modal | Split gates: `Freeze acknowledgement` + `Patch acknowledgement` checkboxes; per-session re-arm required each launch (armed state persists per-launch only, never forever); explicit `Disarm` control in Extras; each gate adjacent-copy states freeze can corrupt saves / patch modifies code. Unchecked = respective controls disabled. Supersedes the first-run-only decision — safety review F1. |
| unsafe-armed-banner (sticky) | Header row (sticky, above body grid) | Exact copy: `UNSAFE ARMED — Freeze/Patch can corrupt saves. Restores on clean quit only; killing the app may leave game memory changed. Offline games only.` Text+icon, never color-only; never dismissible while armed; compact armed chip mirrored adjacent to Freeze ON and Patch writer. Uses `{components.unsafe-armed-banner}` / `{colors.warning-amber}`. |
| Process attach | Process | Entry (name or PID) + Attach validates; Refresh list rebuilds PID-name list; failure → `showerror` Attach |
| Capture control | Capture | Title entry + Capture captures named window only; failure → `showerror` Capture; never writes |
| Values listbox | Extract | Rows `label: value [type] conf=0.XX`; selection gates Adjust/Verify/Freeze/Patch; failure → `showerror` Extract |
| Editable value field | Extract | Edit via field + `Apply` / discard; edited-dirty marker on the value row; numeric validation before plan; plan echoes the exact committed operands; stale-vs-edited always distinguishable. Uses `{components.value-row}` visual. |
| Multiplier input | Adjust | Entry prefilled `100`; rejects ≤0 / non-numeric / overflow-huge with `showerror` Adjust: `Multiplier must be a number from 1 to 1000000.` [ASSUMPTION: bounds inferred; PRD assumes e.g. 100]. Committed multiplier renders in the blocking write-preview dialog (see Verify row). |
| Scan picker / refine | Adjust→Scan | L0 exact → L1 type → L2 protection → L3 narrow → picker ladder (FR-6 glossary ladder); write only if exactly 1 address, else picker/refine; narrow treatment: `{exc} Change the value in-game, then use Verify to continue narrowing.` |
| Verify buttons + blocking write-preview | Verify | `Verify (re-screenshot)` re-screenshots; blocking write-preview dialog shows address, label, extracted × multiplier = target, fallback disclosure when the adjust model is unreachable, and CE safety-setting status; explicit `Write` / `Cancel` — display-only is not consent. Model-unreachable offers `Use local ×100 fallback` / `Abort`, never log-only. Confirm dialog `Value now shows {observed} (expected {expected}). Correct?` defaults to `No`; only Yes persists + `RUNBOOK updated:`. Freeze ON / Patch writer / `Write` are excluded from Enter-default and each require this confirm per (address, label, old→new). |
| Mode combobox + Freeze ON/OFF (snapshot-bound) | Freeze/Display | Mode `one_shot/freeze/display` text-only combobox; Freeze ON requires per-session armed gate + just-in-time confirm adjacent to the button; freeze binds to a snapshotted (address + label), never live listbox selection — changing selection while frozen never retargets writes; explicit `Disarm`; clean-quit restore checklist with per-item restored/failed status; on-launch stale-state detector + recovery banner; kill-path documented as known limitation in banner copy. |
| Patch writer button (risk-disclosed) | Patch | `Patch writer (stubborn value)` requires per-session Patch gate + just-in-time confirm adjacent to the button: `Change the value in-game now so the watch can catch the writer of {address}. This attaches a debugger and patches code. It can crash or corrupt saves. Offline saves only. Continue?` Unique-signature-only else `Patch skipped {reason}`; restore on exit with quit-time checklist; excluded from Enter-default. |
| Wishlist + Draft + Promote | Drafts | Wishlist entry + Draft cheats (wholesale to `draft.json` with `lookFor`) + drafts listbox (`Verified:` / `Unverified:` prefix with icon+text, never brackets/case-only or color) + Promote selected draft individually; empty promote → `Draft cheats first.` Manual-only traps log `Manual: {label}: {reason}` per `categories.py MANUAL_ONLY` (runspeed, speed, nosearch, hunger, cash, curfew) and never auto-draft. |
| Profiles / validate-profile entry point | Profiles surface (next to Open Profiles Folder) | `Validate profile` button runs the offline check with no game attached; results list per-cheat pass/fail with the failure reason; failures never modify files. [ASSUMPTION: button placement inferred; source defines behavior only.] |
| RUNBOOK / Export (+ save dialog) | Header | View Runbook (`No runbook yet.` when empty); Open Profiles Folder; Export .CT opens a save dialog (filter `Cheat Table *.CT`, default `cheats.CT`) then maps plain / AA script / skipped-with-reason; empty → `No profile cheats yet.`, success → `Exported {n} entries to {dest}.` with per-skip `\nSkipped {label}: {reason}` lines kept. |
| Log line | Header (disabled) | Single disabled log (visual-only; live status text carries the SR live region) mirrors state transitions including `Settings saved.`, `Attached to PID {id}`, `Captured {w}x{h} ({KB} KB base64)`, `Verify: observed={o} match={m}`, `Back to refine: re-capture or re-narrow the scan.`, `Freeze ON: {label} @ {address} = {value}` / `Freeze OFF (restored): {label}`, `Patched writer {addr} (sig {sig}). Restored automatically on exit.`, `Manual: {label}: {reason}`, `Promoted {label} to live profile.`; no interaction. |

## State Patterns

| State | Surface | Treatment |
|---|---|---|
| Cold load | Window | 900x700 single window, header + disabled log + body grid; no step nav; CustomTkinter theme follows Windows |
| Setup untested | Setup | Status empty until Test; Save gates on `normalize_endpoint → validate (err→status) → list_models probe (Endpoint unreachable: {exc}) → save + destroy`; Refresh auto-fills first model only-if-empty; Test-vs-Refresh probe equivalence. |
| Attach failure | Process | `showerror` Attach failed; list unchanged |
| Capture failure | Capture | `showerror` Capture failed; no values cleared |
| Extract failure | Extract | `showerror` Extract failed; listbox unchanged |
| No selection | Adjust/Freeze/Patch | `Select a value first.` (Adjust) / `Adjust a value first.` (Freeze, Patch); no-op otherwise |
| Model unreachable (adjust) | Adjust | Log `Adjust model unreachable — local ×100 fallback.`; plan still shown before write |
| Multi-address scan | Adjust→Scan | `showerror` Scan failed variant + narrow line `{exc} Change the value in-game, then use Verify to continue narrowing.`; picker/refine, no write |
| Verify verdict | Verify | `askyesno` `Value now shows {observed} (expected {expected}). Correct?`; Yes → persist + `RUNBOOK updated:`; No → refine, nothing persists; error → `showerror` Verify failed |
| Freeze armed/off | Freeze | Per-session gate unchecked → Freeze ON/OFF disabled; armed → sticky unsafe-armed-banner (`{components.unsafe-armed-banner}`); off with none → `No active freeze for {label}.`; clean quit → restore checklist (per-item restored/failed); kill/crash → known limitation, next-launch stale-state recovery banner. |
| Patch skipped | Patch | `Patch skipped {reason}` (non-unique signature); error → `showerror` Patch failed; restore on exit via quit-time checklist. |
| Drafts written | Drafts | Log `Drafts written (replaced): {path}. Verify each in-game before promoting.`; empty promote → `Draft cheats first.` |
| Profile ambiguous | Profiles | Ambiguous anchor raises (FR-10), no silent pick; UJ-2 re-applies via ladder with no rescan |
| Runbook empty/error | RUNBOOK | `No runbook yet.` (`showinfo`); failure → `showerror` Runbook failed |
| Export empty/done | Export | `No profile cheats yet.` / `Exported {n} entries to {dest}.` |
| Refuse (pre-attach gate) | Process | Before any scan: offline-only attestation + blocklist/heuristic check at the Process surface. On hit: `showerror` Refuse: `Offline games only — this target looks like multiplayer or anti-cheat ({reason}). Detaching; change the target to continue.` Then detach, lock that PID, disable Adjust/Freeze/Patch until the target changes. Dismissing the dialog never re-enables writes. [ASSUMPTION: heuristic-vs-attestation split answers PRD open Q #4 at architecture.] |
| Shutdown | Global | `WM_DELETE_WINDOW → shutdown()` then destroy; `atexit restore_on_exit` ordering; Profiles `makedirs` + `startfile`; Runbook `startfile`-or-`showinfo` branch. |
| First launch (unsigned) | Global | One-dir bundle is unsigned → expect a Windows SmartScreen warning on first run; no in-app copy beyond the Setup prerequisite note; signing deferred per research. |

## Interaction Primitives

Mouse-first single-window wizard (attach → capture → extract → adjust → verify → persist); CE scan runs expanded but never blocks the UI thread [ASSUMPTION: non-blocking CE call inferred from `Verify` non-blocking rule + responsiveness need].

- `Enter` activates the focused button except Freeze ON / Patch writer / `Write`, which are excluded from Enter-default and require their blocking confirm. `Escape` closes Setup modal and dismisses `askyesno` as `No` / `showerror`/`showinfo` as close [ASSUMPTION: key mapping inferred; source has button labels only]. Verify confirm defaults to `No`.
- Field-associated errors: every `showerror` names the failing field (`Process — Attach failed: {reason}` pattern), mirrors the message inline next to the failing entry, and moves focus to that field on dismiss; icon+text, never red-color-only.
- Modal contract: `Tab` traps inside Setup/`askyesno` while open; focus returns to the invoker (e.g. Settings button) on close; Yes/No are Tab+Arrow+Enter operable without a pointer.
- Named widgets + live region: every entry/combobox/button/listbox carries an accessible name; the status line + a live (non-disabled) status text expose changes as a polite live region (the disabled log stays visual-only); row readout order verified with Narrator + NVDA in both themes.
- Resizable + scaling: window resizes beyond the 900×700 minimum with a scrollable body grid; rows scale with system text size (no fixed 10px physical caption); verified at 125/150/200% Windows scaling with no loss or overlap; all interactive targets ≥24×24.
- Explicit focus ring (outline, never color-only change), verified in light/dark/High-Contrast forced-colors.
- Selection-gating everywhere: Adjust/Freeze/Patch/Promote refuse empty selection with the exact strings above.
- Only Yes persists; every write is preceded by plan (FR-5) or confirm dialog (Verify/Patch).

**Banned everywhere:** unprompted multi-write (one-shot write only on exactly-1 address, always through the blocking write-preview); blocking CE thread; color-only warnings (text+icon required); second windows beyond modal + allowed dialogs (`askyesno`/`showerror`/`showinfo` + Export save dialog); hotkeys/overlay/Steam discovery/anchor cache/toggles/community library (non-goals); macOS/Linux flows; multiplayer flows; signed-installer or step-nav additions.

## Accessibility Floor

Behavioral. Contrast lives in `DESIGN.md` (system-native CustomTkinter theme; amber/red deltas verified text+icon, never color-only).

- WCAG 2.2 AA intent across the single-window desktop surface.
- UNSAFE armed state announces as text+icon banner using `{components.unsafe-armed-banner}`; state never conveyed by `{colors.warning-amber}` alone.
- `Tab` order matches reading order; explicit focus ring (outline, never color-only), verified in light/dark/High-Contrast forced-colors; `Esc` always closes the topmost modal/dialog with safe default (`No`).
- Screen reader: named widgets throughout; status line + live status text as a polite live region (disabled log is visual-only); surface context announced (window title, section `{typography.heading}`, row `label: value [type] conf=0.XX`); row order verified with Narrator + NVDA in both themes.
- Contrast: AA pairs recorded at build per theme for `{colors.brand-accent}`, `{colors.warning-amber}`, `{colors.destructive}`; warning/destructive meaning never carried by color alone (text+icon).
- Drafts signal by word, not styling: `Verified:` / `Unverified:` prefix with distinct icon+text; amber/red stay out of drafts and Mode; the unsafe-armed-banner is the sole amber use.
- `askyesno` verdict defaults to `No`, is modal with `Tab` trap + focus return, and is keyboard-answerable (Tab+Arrow+Enter) without a pointer [ASSUMPTION: keyboard-answerable inferred from standard dialog behavior].

## Key Flows

### Flow 1 — UJ-1 Drak turns 500 gold into wealth

1. Drak opens Vision Trainer, completes Setup (endpoint default, Test → `OK — {n} models`, Save).
2. Process: enters game name/PID; pre-attach offline gate passes (blocklist + attestation); Attach validates.
3. Capture: enters window title, Capture (≤1280px JPEG Base64, no writes).
4. Extract: Extract values → rows (`label: value [type] conf=0.XX`); Drak edits the 500-gold row via field + `Apply` (dirty marker shows until committed).
5. Adjust: sets multiplier (prefilled `100`), reviews the blocking write-preview (address, label, extracted × multiplier = target) and confirms `Write`.
6. Scan: L0 exact → L1 type → L2 protection → L3 narrow → picker ladder (FR-6 glossary ladder); exactly 1 address → one-shot write; else picker/refine.
7. **Climax:** Verify re-screenshots, vision verdict dialog `Value now shows {observed} (expected {expected}). Correct?` (defaults `No`) — Drak clicks `Yes — confirmed`; profile persists atomically and `RUNBOOK updated:` appends.
8. Failure: multi-address → `{exc} Change the value in-game, then use Verify to continue narrowing.`; no write, no persist.

### Flow 2 — UJ-2 re-apply after restart via anchor ladder, no rescan

1. Drak restarts the game, reopens the saved profile.
2. Per-cheat plan + confirm (address, label, old→new) precedes every re-applied write — opening a profile never auto-writes.
3. **Climax:** confirmed values land without repeating capture/extract/scan; Drak plays on.
4. Failure: ambiguous anchor raises; no silent pick, user refines manually.

### Flow 3 — UJ-3 freeze decaying health, restore on quit

1. Drak re-arms the per-session Freeze gate in Setup (or Extras `Disarm`/re-arm); sticky unsafe-armed-banner shows the exact copy.
2. Extract health, set Mode `freeze`, confirm just-in-time at Freeze ON (snapshot-bound to the confirmed address + label).
3. **Climax:** decaying health holds frozen in-game while the banner stays visible; on clean quit the restore checklist confirms per-item restored, else the failure copy + next-launch recovery banner fires.
4. Failure: Freeze with no selection → `Adjust a value first.`; Freeze-off with none → `No active freeze for {label}.`
