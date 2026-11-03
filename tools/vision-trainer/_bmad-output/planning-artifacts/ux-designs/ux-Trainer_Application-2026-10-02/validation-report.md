# Validation Report — Trainer_Application

- **DESIGN.md:** `_bmad-output/planning-artifacts/ux-designs/ux-Trainer_Application-2026-10-02/DESIGN.md`
- **EXPERIENCE.md:** `_bmad-output/planning-artifacts/ux-designs/ux-Trainer_Application-2026-10-02/EXPERIENCE.md`
- **Run at:** 2026-10-02

## Overall verdict

The spine pair passed review with teeth: the rubric walker found the contract consumable with no critical breakage, while the safety lens returned FAIL and the accessibility lens NOT YET AA. All 3 safety criticals and all 3 a11y highs were autofixed into the spines (per-session split UNSAFE gates + sticky banner, pre-attach refusal gate, SM-C1 confirm/snapshot rules, blocking write-preview, named widgets + live region, field-associated errors, locked contrast-pair process). Residual risk is verification-on-Windows (contrast ratios, Narrator/NVDA, 125/150/200% scaling, CustomTkinter widget parity), not missing decisions.

## Category verdicts
- Flow coverage — strong
- Token completeness — strong (post-fix: platform-convention foregrounds)
- Component coverage — adequate → fixed (canonical names `unsafe-gate-checkbox` / `unsafe-armed-banner`; multiplier/editable/validate-profile/save-dialog committed)
- State coverage — adequate → fixed (refusal gate, shutdown sequence, Save-gate order, restore checklist committed)
- Visual reference coverage — adequate (imports/ intentionally empty; as-built window is the reference)
- Bloat & overspecification — strong
- Inheritance discipline — adequate → fixed (trap strings inlined from categories.py; UJ titles + ladder wording aligned)
- Shape fit — strong
- Accessibility lens — NOT YET AA → autofixed (3 highs committed; mediums committed)
- Safety lens — FAIL → autofixed (3 criticals + 2 highs committed)

## Findings by severity (all: autofixed into spines)

### Critical (3)
**[Safety]** — First-run-only UNSAFE gate insufficient (§ Component Patterns, DESIGN Components)
Split Freeze vs Patch gates; per-session re-arm; explicit Disarm; per-launch persistence only; just-in-time confirms adjacent to destructive buttons.
Fix: committed as `unsafe-gate-checkbox` + sticky `unsafe-armed-banner`.

**[Safety]** — FR-13 refusal UX unspecified (§ State Patterns Refuse)
Pre-attach gate (blocklist + attestation) that detaches, locks PID, disables writes; exact refusal copy committed.
Fix: committed; heuristic-vs-attestation split deferred to architecture (PRD OQ #4).

**[Safety]** — SM-C1 bypasses: Enter-default, live-selection drift, UJ-2 silent re-apply (§ Interaction Primitives, Key Flows)
Destructive buttons excluded from Enter-default + blocking confirm per (address, label, old→new); freeze snapshot-bound; UJ-2 requires per-cheat plan + confirm.
Fix: committed.

### High (6)
**[Rubric]** — Multiplier input uncommitted → committed: prefilled `100`, bounds 1–1000000 with error copy, renders in blocking write-preview.
**[Rubric]** — Editable extract undefined → committed: field + Apply/discard, dirty marker, validation, plan echoes operands.
**[Rubric]** — Export save-dialog contradiction → committed: save dialog allowlisted with filter/default + per-skip suffix kept.
**[Safety]** — Display-only write preview → committed: blocking Write/Cancel dialog with fallback disclosure + CE-setting status; Use-fallback/Abort choice.
**[Safety]** — Restore-on-exit normal-quit-only → committed: quit-time checklist, on-launch stale-state recovery, kill-path limitation in banner copy, exact 64-word banner copy.
**[A11y ×3]** — Contrast pairs untestable; SR exposure assumed; errors lack field association → committed: platform-convention foregrounds + AA-pair-at-build process; named widgets + polite live region; field-named errors with inline mirror + focus move.

### Medium (10)
Rubric: validate-profile placement; refusal copy; shutdown/Save ordering; component naming; display refresh; trap wording; UJ/L4 wording. A11y: modal contract; scaling reflow; focus-visible/forced-colors; drafts encoding. Safety: patch-copy risk disclosure; editable/multiplier overflow; BSOD-setting gate; refusal-copy inline.
Fix: all committed (see spines); BSOD-setting guard + SmartScreen/DPI-acceptance/widget-parity checks logged as architecture/build verification items.

### Low (9)
Rubric: system-native literal; inherited-only components; empty-imports note; log-string drops; missing-sections note. A11y: pointer targets (24×24 committed). Safety: BSOD gate; copy-by-reference.
Fix: committed or recorded; `imports/` intentionally empty noted here.

## Reviewer files
- `review-rubric.md`
- `review-accessibility.md`
- `review-safety.md`
- `reconcile-prd.md`, `reconcile-asbuilt.md`, `reconcile-research.md`
