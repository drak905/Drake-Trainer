# Reconcile — as-built (`vision_trainer/main.py` + `README.md`) vs UX spines

- Input: `vision_trainer/main.py` (485 lines) + `vision_trainer/README.md` (98 lines).
- Spines: `ux-Trainer_Application-2026-10-02/DESIGN.md` + `EXPERIENCE.md`. Spines not rewritten.
- Method: full read of both inputs; every as-built screen/string/state marked covered / partial / missing.

## Screens / surfaces

- Setup modal (`SetupDialog`, `Vision Trainer — Setup`) — covered. Fields/buttons/status all in spines.
- Main window (`Vision Trainer (offline games only)`, 900x700, header + disabled log + body grid) — covered.
- Header: `Settings / Update info`, `View Runbook`, `Open Profiles Folder`, `Export .CT` — covered.
- Disabled log (`tk.Text`, `log_line`) — partial. Behavior covered; most exact log strings missing (see dropped).
- Process section: `Game process (name or PID):` + `Attach` + `Refresh list` + PID-name listbox h6 — covered.
- Capture section: `Window title (for screenshot):` + `Capture` + `Extract values` + values listbox h8 — covered.
- Adjust/Verify row: `Adjust selected ×100`, `Verify (re-screenshot)`, `Yes — confirmed`, `No — refine` — partial. Fixed ×100 covered; spine adds NEW parameterized multiplier + editable-value gap (README promises editable, `main.py` has no widget).
- Mode/Freeze row: `Mode:` + `one_shot/freeze/display` + `Freeze ON` / `Freeze OFF` — covered (UNSAFE gating is spine NEW).
- `Patch writer (stubborn value)` — covered.
- Wishlist/Drafts: `Factory wishlist (comma):` (default `health,stamina,money`) + `Draft cheats` + `Promote selected draft` + drafts listbox h5 — covered.
- Export `.CT` save dialog (`filedialog.asksaveasfilename`, `Cheat Table *.CT`, `cheats.CT`) — missing. Spine allows only `askyesno/showerror/showinfo`, bans second windows.
- Close path (`WM_DELETE_WINDOW → state.shutdown()` + `atexit restore_on_exit`) — partial. Spine says "restore on quit/exit" only.

## Strings (exact as-built → spine status)

- `Local LLM endpoint:` / `Vision model:` / `Adjust model:` / `Refresh models` / `Test` / `Save` — covered.
- Status: `{n} models found` / `OK — {n} models` / `Failed: {exc}` / `Endpoint unreachable: {exc}` / validate `err` — covered (ordering not captured, see gaps).
- `Game process (name or PID):` / `Attach` / `Refresh list` — covered.
- `Window title (for screenshot):` / `Capture` / `Extract values` — covered.
- Value row `{label}: {value} [{type}] conf={conf:.2f}` — covered.
- `Adjust selected ×100` / `Verify (re-screenshot)` / `Yes — confirmed` / `No — refine` — covered.
- `Mode:` / `one_shot,freeze,display` / `Freeze ON` / `Freeze OFF` — covered.
- `Patch writer (stubborn value)` / `Factory wishlist (comma):` / `Draft cheats` / `Promote selected draft` — covered.
- Draft row `[{verified|UNVERIFIED}] {label} ({category}): {look_for}` — covered.
- Dialogs: `Attach failed` / `Capture failed` / `Extract failed` / `Scan failed` / `Verify failed` / `Patch failed` / `Runbook failed` / `Process list` — covered.
- `Select a value first.` / `Adjust a value first.` / `No active freeze for {label}.` / `Draft cheats first.` / `No profile cheats yet.` — covered.
- `Value now shows {observed} (expected {expected}). Correct?` (`Confirm`) — covered.
- `Change the value in-game now so the watch can catch the writer of {address}. Continue?` (`Patch writer`) — covered.
- `Narrow scan: {exc} Change the value in-game, then use Verify to continue narrowing.` — covered.
- `No runbook yet.\n{path}` (`Runbook` showinfo) — partial. Spine keeps `No runbook yet.`, drops `\n{path}` suffix.
- `RUNBOOK updated:\n{path}` (`Done` showinfo) + log `RUNBOOK updated: {path}` — covered.
- `Exported {n} entries to {dest}.` + per-skip `\nSkipped {s[label]}: {s[reason]}` — partial. Spine keeps first line, drops per-skip suffix + filedialog detail.
- `Patch skipped / {reason}` — covered.
- Log `Adjust model unreachable — local ×100 fallback.` — covered.
- Log `Drafts written (replaced): {path}. Verify each in-game before promoting.` — covered.
- Dropped log/line strings (in `main.py`, absent from both spines): `Settings saved.`; `Attached to PID {id}` (+ runbook `suggest_recipe` line); `Captured {w}x{h} ({KB} KB base64)`; `Verify: observed={o} match={m}`; `Back to refine: re-capture or re-narrow the scan.`; `Freeze ON: {label} @ {address} = {value}`; `Freeze OFF (restored): {label}`; `Patched writer {addr} (sig {sig}). Restored automatically on exit.`; `Manual: {label}: {reason}`; `Promoted {label} to live profile.`
- README-only operational strings — missing from spines (expected; product-UX out of scope): `disable "Query memory region routines"`; `File → Execute Script → MCP_Server/ce_mcp_bridge.lua → Execute`; `[MCP v12.0.0] MCP Server Listening on: CE_MCP_Bridge_v99`; `http://localhost:20128/v1`, `ag/gemini-3.8-flash-high`, `cmc/meta/muse-spark-1.3-contributor`; `%APPDATA%\VisionTrainer\config.json|runbooks|profiles`; `pip install -r vision_trainer\requirements-*.txt`, `python -m vision_trainer.main`, `pytest … -m "not live"`, `pyinstaller vision_trainer.spec`, `SHA256SUMS.txt`, SmartScreen warning, PR convention (game+build, proven vs unproven).

## States

- Cold load single-window, no step nav — covered.
- Setup untested → Test/Refresh probe; Save gates on `normalize_endpoint` + `validate_config` + `list_models` reachability — partial (strings covered, ordering/normalize dropped).
- First-run auto-open Setup (`stage == setup`); `settings_return` stage restore — partial (auto-open implied; flag mechanics not in spine).
- Attach fail (`showerror`, list unchanged); process list `[:500]`, pick via `split()[0]` — partial (fail covered; 500-cap/pick mechanics missing).
- Runbook suggestion on attach if file exists — partial (suggestion behavior noted; exact trigger/shape missing).
- Capture pipeline (find window → rect → JPEG ≤1280px → Base64 → `before_b64`/`window_handle`) — covered (README ≤1280px JPEG; spine notes no writes).
- Extract fail (listbox unchanged); `compute_write_plan` → `fallback_write_plan` — covered.
- Multi-address (`NeedNarrowingValue` / `ScanError`, no write) — covered.
- Verify (`after_b64` + vision verdict + modal Yes/No; Yes persists, No refines) — covered.
- Freeze registry (`start_freeze`/`stop_freeze(restore=True)`, restore on quit) — covered (exact ON/OFF log lines dropped).
- Patch (`escalate_stubborn_value`, unique-signature-only, `applied_patches`, restore on exit) — covered.
- Drafts wholesale replace + `lookFor` + manual list; promote single (unverified pass-through `pass`) — covered.
- Profiles anchor ladder / ambiguous raises; validate-profile; Export plain vs AA vs skipped — covered (spine-level; `main.py` delegates).
- Refuse (offline-only; multiplayer/anti-cheat + manual traps via `showerror`, flow halts) — covered.
- Shutdown ordering (`shutdown()` then destroy; `atexit` registry+patches restore); Profiles `makedirs` + `startfile`; Runbook `startfile`-or-`showinfo` branch — partial/missing (see gaps).

## Gaps (4)

1. Half the as-built log/confirm prose dropped — `Settings saved.`, `Attached to PID …`, `Captured …`, `Verify: observed=…`, `Back to refine…`, `Freeze ON/OFF…`, `Patched writer…`, `Manual:…`, `Promoted…`, per-entry `Skipped…`. Spine-following build loses traceability copy.
2. Export save dialog uncovered/contradicted — `asksaveasfilename` (`*.CT`, `cheats.CT`) plus per-skip suffix have no spine surface; spine bans second windows and lists only yes/no/error/info dialogs.
3. Shutdown/restore ordering underspecified — `WM_DELETE_WINDOW → shutdown()`, `atexit restore_on_exit(registry, applied_patches)`, Profiles `makedirs+startfile`, Runbook `startfile`-or-info branch reduced to "restore on quit".
4. Setup Save gate ordering dropped — `normalize_endpoint → validate(err→status) → list_models probe (Endpoint unreachable) → save+d e stroy`, Refresh auto-fill first-model-only-if-empty, and Test-vs-Refresh probe equivalence not captured though all status strings are.
