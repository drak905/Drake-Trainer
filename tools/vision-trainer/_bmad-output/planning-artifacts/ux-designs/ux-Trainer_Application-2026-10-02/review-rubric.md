# Spine Pair Review — Trainer_Application

- **DESIGN.md:** `_bmad-output/planning-artifacts/ux-designs/ux-Trainer_Application-2026-10-02/DESIGN.md`
- **EXPERIENCE.md:** `_bmad-output/planning-artifacts/ux-designs/ux-Trainer_Application-2026-10-02/EXPERIENCE.md`
- **Reconciles read:** `reconcile-prd.md`, `reconcile-asbuilt.md`, `reconcile-research.md` (spines not rewritten)
- **Run at:** 2026-10-02

## Overall verdict

The spine pair is a consumable downstream contract with no critical breakage: all three UJ flows are present with protagonist, steps, climax, and failure paths; every frontmatter token and every `{path.to.token}` reference resolves; DESIGN section order is canonical and all EXPERIENCE defaults are present. Three high-severity gaps on the write path (parameterized multiplier, editable extract, Export save-dialog contradiction) must be committed before story-dev; the remaining findings are honestly pre-flagged in the reconcile files and the inline `[ASSUMPTION]` tags.

## 1. Flow coverage — strong

Checked PRD §2.3 UJ-1/UJ-2/UJ-3 against EXPERIENCE.md Key Flows (lines 123–148). Each flow has a named protagonist (Drak), numbered steps, a bolded climax beat, and a failure path. No misses.

### Findings

_None._

## 2. Token completeness — strong

Extracted all DESIGN.md frontmatter tokens (6 colors, 5 type roles, 4 radii, 4 spacing, 4 components) and every `{path.to.token}` in both spines. All resolve per `design-md-spec.md` type rules; all six color tokens carry hex values with light/dark pairs; typography uses an allowed subset (no `lineHeight`/`letterSpacing` required); `spacing.window-min-width/height` are defined but referenced literally ("900x700") rather than by ref.

### Findings

- **[low]** `button-primary` / `unsafe-armed-state` use the bare literal `'system-native'` for `foreground` (DESIGN.md lines 48, 52) — not a hex, not a `{ref}`, not a spec-pattern `{ note: ... }`. A strict consumer mirroring tokens into code cannot resolve it. *Fix:* adopt the spec's platform-convention form, e.g. `foreground: { note: 'Windows/CustomTkinter text on accent' }`, and document once.*
- **[low]** No numeric contrast ratios stated for the load-bearing amber/red deltas; both spines rely on the "text+icon, never color-only" rule (DESIGN.md lines 75–76; EXPERIENCE.md lines 115–118). Defensible for a system-native surface, but unverified. *Fix:* record one AA-ratio check per delta pair, or explicitly defer to CustomTkinter/Windows theme.*

## 3. Component coverage — adequate

DESIGN.md names 4 brand deltas + 7 as-is CustomTkinter widgets (the sanctioned "deltas only" inheritance pattern per the shadcn example). EXPERIENCE.md carries 16 behavioral rows, all with real rules. Mapping requires consumer inference (names differ across spines — see §7), and the two NEW-gap components lack committable specs.

### Findings

- **[high]** Multiplier input (FR-5) has a behavioral row (EXPERIENCE.md line 71) but no visual spec, no default/prefill, no bounds, no error copy, and no plan-preview placement — pre-flagged in `reconcile-prd.md` gap 2. It sits on the one-shot write path (Flow 1, step 5). *Fix:* commit default (PRD assumes e.g. 100), validation bounds + error string, and where the extracted×multiplier plan renders before the write.*
- **[high]** Editable extracted values (FR-3) have a behavioral row (EXPERIENCE.md line 70, "edit via field") but the widget is undefined — inline vs field, commit/cancel, validation all open; pre-flagged in `reconcile-prd.md` gap 1 and `reconcile-asbuilt.md` (README promises editable, `main.py` has no widget). UJ-1 step 4 depends on it. *Fix:* commit one edit interaction with commit/cancel and validation behavior, keeping the `{components.value-row}` visual.*
- **[low]** Setup modal fields, Profiles/validate-profile entry, and Log line lean on inherited CustomTkinter defaults with radius-only or implied visuals and no component frontmatter tokens. Sanctioned pattern, noted for completeness. *Fix:* no change required; optionally add `setup-modal` and `log-line` tokens if a consumer needs them.*

## 4. State coverage — adequate

Walked all 11 IA surfaces against the 16 State Patterns rows (EXPERIENCE.md lines 81–100). Every surface has at least its failure/empty/no-selection treatment. Gaps cluster where the reconciles already point.

### Findings

- **[high]** Export `.CT` save-dialog contradiction: as-built uses `filedialog.asksaveasfilename` (`*.CT`, `cheats.CT`) plus a per-skip `\nSkipped {s[label]}: {s[reason]}` suffix, but the spine allows only `askyesno`/`showerror`/`showinfo`, bans second windows, and keeps only the first export line (`reconcile-asbuilt.md` gap 2). The Export flow cannot be source-extracted as specified. *Fix:* add the save dialog to the IA + dialog allowlist with its filter/default-filename, and commit whether the per-skip suffix stays.*
- **[medium]** Offline validate-profile (FR-11) cites behavior only: entry affordance, run scope, and per-cheat pass/fail results surface are unspecified; placement is assumption-tagged (EXPERIENCE.md line 77; `reconcile-prd.md` gap 3). *Fix:* commit the trigger location and the results presentation.*
- **[medium]** Safety refusal UX (FR-13) states the global refuse but commits no block point (attach vs scan), no refusal dialog copy, and no heuristic-vs-attestation presentation; PRD open Q #4 is unanswered in the spine (`reconcile-prd.md` gap 4). *Fix:* commit where the refuse fires and the exact `showerror` strings.*
- **[medium]** Shutdown/restore ordering and Setup Save-gate ordering are reduced to "restore on quit" and Test/Save/Refresh labels: `WM_DELETE_WINDOW → shutdown()` + `atexit restore_on_exit` ordering, Profiles `makedirs`/`startfile`, Runbook `startfile`-or-`showinfo` branch, and the `normalize_endpoint → validate → list_models probe → save` sequence are dropped though all status strings survive (`reconcile-asbuilt.md` gaps 3–4). Restore ordering is load-bearing safety behavior for freeze/patch. *Fix:* commit the shutdown/restore sequence and the Save-gate order as state rows.*
- **[low]** Display readout refresh behavior is thin (FR-8 covered as enhanced gate; refresh cadence undefined — `reconcile-prd.md` §4.6 note); the 6 manual-trap refuse strings live in PRD/FR-4 only and are assumption-referenced in the Voice table (EXPERIENCE.md line 56). *Fix:* one line on display refresh; quote or pinpoint the trap strings.*

## 5. Visual reference coverage — adequate

`imports/` and `.working/` are empty; there are no `mockups/` or `wireframes/` directories, hence zero orphans and zero unspecific references. "Spine wins on conflict" is stated once (EXPERIENCE.md line 12). The as-built `main.py` window functions as the implicit composition reference but is never declared as such.

### Findings

- **[low]** Empty `imports/` directory is not acknowledged and no composition-reference line declares what illustrates each surface (contrast the Drift example's `→ Composition reference:` line). *Fix:* add one line in Foundation noting `imports/` is intentionally empty and the as-built single window is the visual reference, with the spine winning on conflict.*

## 6. Bloat & overspecification — strong

Both spines are lean (124 + 148 lines). No pixel specs beyond tokens; no persona/FR restatement (Drak appears only in flow titles); the Voice table's exact strings are load-bearing (gated by `reconcile-asbuilt.md` string audit); DESIGN prose carries editorial voice while EXPERIENCE prose stays behavioral. The ~15 inline `[ASSUMPTION]` tags are disciplined provisionality markers, not decoration.

### Findings

_None._

## 7. Inheritance discipline — adequate

EXPERIENCE `sources` resolve from the repo root to the final PRD and the Tauri-vs-Tkinter research (root-relative form; DESIGN.md carries no `sources`, matching the design example). All EXPERIENCE token references resolve to DESIGN tokens by name. Glossary terms (UNSAFE, anchor ladder, Draft/Profile, RUNBOOK, one-shot, `lookFor`, validate-profile) are used consistently. Name identity is the weak point.

### Findings

- **[medium]** Component identity requires inference across spines and within EXPERIENCE: DESIGN "Gate checkbox" vs EXPERIENCE "UNSAFE first-run checkbox (NEW)" (line 65) vs "UNSAFE checkbox" (line 94); DESIGN "UNSAFE armed state" vs EXPERIENCE "Armed-warning banner (NEW)" (line 66) vs "armed-warning state" / "armed … banner" (lines 94, 143). A consumer cannot match rows by name. *Fix:* pick one canonical name per component and use it verbatim in both spines (e.g. `unsafe-gate-checkbox`, `unsafe-armed-banner`, with matching frontmatter keys).*
- **[low]** UJ flow titles paraphrase rather than quote the PRD verbatim: "UJ-1 Drak turns 500 gold into wealth" drops PRD's "parameterized"; UJ-2/UJ-3 titles reword "last week's cheat" / "quits cleanly" (EXPERIENCE.md lines 125, 136, 143 vs PRD §2.3 lines 29–31). Scan ladder reads "L0→L4" (line 72) while the PRD glossary defines "L0 exact → L1 type → L2 protection → L3 narrow → picker" with no L4 — the L4↔picker mapping is unstated. *Fix:* use verbatim UJ titles and map L4 to the glossary ladder explicitly.*
- **[low]** ~10 as-built log/confirm strings dropped from the spines (`Settings saved.`, `Attached to PID …`, `Captured …`, `Verify: observed=…`, `Back to refine…`, `Freeze ON/OFF…`, `Patched writer…`, `Manual:…`, `Promoted…`, `No runbook yet.\n{path}` path suffix) per `reconcile-asbuilt.md`. A spine-following build loses traceability copy; behavior is preserved. *Fix:* confirm the drop is intentional or restore the load-bearing lines (especially freeze/patch confirmations) to Voice/State rows.*

## 8. Shape fit — strong

DESIGN.md contains all 8 canonical sections in locked order (Brand & Style → Colors → Typography → Layout & Spacing → Elevation & Depth → Shapes → Components → Do's and Don'ts). EXPERIENCE.md contains all 8 required defaults (Foundation, IA, Voice and Tone, Component Patterns, State Patterns, Interaction Primitives, Accessibility Floor, Key Flows). No invented sections. `status: draft` with `updated: 2026-10-02` and resolvable `sources` are present.

### Findings

- **[low]** Inspiration (& Anti-patterns) and Responsive sections are absent. Both drops are defensible — rejects live in the Banned list (EXPERIENCE.md line 111) and the product is a fixed-minimum (900×700) single window — but neither drop is noted. *Fix:* one line each (or a single note) recording the intentional omission so a future multi-surface addition knows where the sections go.*

## Mechanical notes

- Frontmatter: DESIGN has `name` + `description` + full token sets (no `sources`/`status`, matching the design example shape); EXPERIENCE has `name`, `status: draft` (honest vs final PRD), root-relative `sources` (2 files, both resolve), `updated: 2026-10-02`. No Mermaid in either spine — N/A.
- Cross-refs audited: all 6 color, 5 typography, 4 rounded, 2/4 spacing (`gutter`, `section-gap` used; `window-min-*` literal-only), and 4 component refs resolve; all 8 EXPERIENCE token refs (`brand-accent`, `warning-amber`, `typography.body`, `typography.heading`, `spacing.gutter`, `button-primary`, `unsafe-armed-state`, `value-row`) resolve to DESIGN frontmatter.
- Name inconsistencies: see §7 medium (gate checkbox ×3 variants; armed state/banner ×4 variants); UJ title paraphrases + L0→L4 drift: see §7 low.
- Directories: `imports/` empty (see §5 low); `.working/` empty; no `mockups/`/`wireframes/` — consistent with a fast-path as-built-anchored spine, recorded here for the record.
