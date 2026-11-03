# Reconcile — PRD vs UX spines (spines NOT rewritten)

Input: `prd-Trainer_Application-2026-10-02/prd.md` (status: final, 2026-10-02)
Spines: `ux-Trainer_Application-2026-10-02/DESIGN.md` + `EXPERIENCE.md` (spines win on conflict)

## Per-feature coverage

- §4.1 Setup & model config (FR-1) — **covered**: Setup modal, endpoint default `http://localhost:20128/v1`, live `/models` dropdowns, Test/Save/Refresh, Settings re-open, status strings.
- §4.2 Attach (FR-2) — **covered**: Process entry + Attach + Refresh + PID-name listbox (h6), validated, `showerror` on failure.
- §4.2 Capture & Extract (FR-3) — **partial**: named-window capture ≤1280px JPEG Base64 + no-writes + failures covered; editable-values intent flagged as NEW gap (`README promises editable, main.py lacks widget`; "edit via field" vague).
- §4.3 Draft wishlist (FR-4) — **covered**: wishlist default `health,stamina,money`, wholesale `draft.json` + `lookFor`, `[verified]/[UNVERIFIED]`, individual promote, 6 manual-trap refuse (exact trap wording assumed, lives in PRD).
- §4.4 Parameterized write (FR-5) — **partial**: plan-shown-before-write + local fallback logged (`Adjust model unreachable — local ×100 fallback.`); multiplier input flagged as NEW gap replacing as-built fixed `×100` — default/prefill, validation, preview layout unspecified.
- §4.4 Expanded scan (FR-6) — **covered**: L0→L4 ladder, exactly-1-address one-shot write, picker/refine + narrow line, `module_offset` + signature.
- §4.5 Verify & confirm (FR-7) — **covered**: re-screenshot + vision verdict + non-blocking `askyesno` (`Value now shows {observed} (expected {expected}). Correct?`); only-Yes persists + `RUNBOOK updated:`.
- §4.6 Freeze & Display (FR-8) — **covered** (enhanced): first-run UNSAFE checkbox (NEW) + persistent text+icon armed banner; restore-on-quit; selection gates (`Adjust a value first.`, `No active freeze for {label}.`). Display readout refresh behavior thin.
- §4.7 Patch writer (FR-9) — **covered**: `Patch writer (stubborn value)` + confirm string, unique-signature-only else `Patch skipped {reason}`, restore on exit.
- §4.8 Profiles & anchors (FR-10) — **covered**: atomic schema-v1 save, anchor ladder (module_offset → signature → pointer chain), UJ-2 no-rescan re-apply, ambiguous-raises.
- §4.8 Offline validate-profile (FR-11) — **partial**: behavior cited; trigger/results UI unspecified — placement only `[ASSUMPTION: header/Profiles-folder inferred]`, no per-cheat failure display.
- §4.9 RUNBOOK + .CT export (FR-12) — **covered**: append-on-Yes only, `View Runbook` / `No runbook yet.`, Export mapping plain vs AA vs skipped-with-reason (`No profile cheats yet.` / `Exported {n} entries to {dest}.`).
- §4.10 Safety guardrails (FR-13) — **partial**: refuse-multiplayer/anti-cheat stated globally + Banned list; no refusal copy, no heuristic/attestation UI, no defined block point (attach vs scan).
- §5/§6 Non-goals & MVP scope — **covered**: hotkeys/overlay/Steam-discovery/anchor-cache/toggles/community/macOS-Linux/signed-installer all in Banned list; P1/P2 deferrals respected.

## Gaps (4)

1. FR-3 editable extract — no edit widget defined (inline vs field, commit/cancel, validation); "edit via field" is placeholder.
2. FR-5 multiplier input — no default/prefill (PRD assumes e.g. 100), bounds, error copy, or plan-preview placement.
3. FR-11 validate-profile — no entry affordance, run scope, or per-cheat pass/fail results surface.
4. FR-13 refusal UX — no block point, refusal dialog copy, or heuristic-vs-attestation presentation (open Q #4 unanswered in spine).

## Dropped qualitative ideas (lost in FR structure)

- Builder-player curiosity/learning voice ("learn how game memory works") → FRs reduce to scan/write mechanics.
- Grind-skip empowerment feel (UJ-1 "500 gold into wealth" playfulness) → flattened into testable consequences.
- Cautious-craft trust tone (UNSAFE honesty, BSOD-prevention care, zero-unprompted-write safety SM-C1) → kept as gates/bans but loses the reassuring voice.
- Proven-vs-guessed memory pride (RUNBOOK as personal lab notebook) → kept as append-only rule, loses nostalgic/ownership feel.
- Restart-resilience relief (UJ-2 "no rescan" delight) → kept as ladder rule, loses the payoff emotion.
