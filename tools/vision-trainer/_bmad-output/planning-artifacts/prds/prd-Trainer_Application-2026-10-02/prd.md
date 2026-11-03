---
title: Trainer_Application
created: 2026-10-02
updated: 2026-10-02
status: final
---

# PRD: Trainer_Application
*Working title — confirm.*

## 0. Document Purpose
For Drak as builder-user and any downstream agent doing architecture/epics/build on the `vision_trainer/` Tkinter app in this repo. Structured as Glossary-anchored vocabulary with grouped features and globally numbered FRs; inferences are tagged `[ASSUMPTION: ...]` inline and indexed in §9. Builds on `vision_trainer/README.md`, `vision_trainer/CI.md`, and `HANDOFF.md` (2026-10-02) — it does not duplicate their run instructions.

## 1. Vision
Trainer_Application is a solo Windows desktop app that adjusts data in offline games for experimentation and learning: screenshot the game window, let a local vision LLM read the visible stat, run an expanded memory scan through the Cheat Engine bridge, write a parameterized new value, re-screenshot to verify, and save what worked as a durable per-game Profile plus an append-only RUNBOOK. It exists so a single player can skip grind in games they own, learn how game memory works, and re-apply proven cheats after a restart without rescanning from scratch. Offline-only by policy; multiplayer and anti-cheat titles are out of scope and refused.

## 2. Target User

### 2.1 Jobs To Be Done
- As the builder-player, I want to turn a number I see on screen into a bigger number in-game, so I can skip grind in an offline game I own.
- I want cheats that survive a game restart (anchors, not raw addresses), so I don't rescan every session.
- I want freeze/display/patch options for stubborn values, so decaying or resetting stats stay where I put them until I quit.
- I want a per-game RUNBOOK of what actually worked, so I remember which cheats are proven vs guessed.

### 2.2 Non-Users (v1)
Anyone wanting multiplayer advantage, anti-cheat bypass, or a hosted cheat-sharing service — explicitly not served.

### 2.3 Key User Journeys
- **UJ-1. Drak turns 500 gold into parameterized wealth.** Drak, mid-grind in an owned offline RPG, has the app attached to the game process and captures the game window; the vision model extracts "Gold: 500", he picks a multiplier, the app expanded-scans, writes to exactly one address, re-screenshots to verify, he confirms yes, and the Profile + RUNBOOK update.
- **UJ-2. Drak re-applies last week's cheat after restarting the game.** Drak relaunches the same game build; the saved anchor (module+offset → signature → pointer chain) re-locates without a rescan and the write succeeds.
- **UJ-3. Drak freezes a decaying health value, then quits cleanly.** Health keeps resetting, so Drak enables freeze; it holds while playing and restores the original behavior on exit.

## 3. Glossary
- **Trainer** — The Tkinter desktop app (`vision_trainer/`); the product itself.
- **Offline Game** — A single-player game with no multiplayer or anti-cheat enforcement; the only supported target.
- **CE Bridge** — The MCP_Server pipe/TCP bridge to Cheat Engine that performs scans, reads, writes, and breakpoints.
- **Vision Model** — Local OpenAI-compatible LLM that reads stat values from screenshots and issues verify verdicts.
- **Adjust Model** — Local LLM (or local arithmetic fallback) that plans the write from the extracted value and multiplier.
- **Expanded Scan** — Scan ladder L0 exact → L1 type → L2 protection → L3 narrow → picker, ending in one `module_offset` + `signature`.
- **Anchor** — Durable re-location ladder: module+offset → signature → pointer chain; raw addresses are informational only under ASLR.
- **Draft** — A factory-generated plausible cheat (`<Game>.draft.json`, replaced wholesale) not yet verified in-game.
- **Profile** — Promoted per-game cheats (`<Game>.json`, schema v1) with anchors; what the app re-applies.
- **RUNBOOK** — Per-game append-only markdown log of successes, written only on user yes.
- **Verify** — Re-screenshot plus vision-model match verdict plus user yes/no dialog.
- **Freeze** — Repeated-write hold on a value with restore on exit; **Display** is the read-only live readout variant.
- **Patch Writer** — Data-breakpoint locate of the instruction writing a value, classified nop/replace/skip, applied only on a unique signature and restored on exit.

## 4. Features

### 4.1 First-Run Setup & Model Configuration
**Description:** Setup wizard captures exactly three things — endpoint (default `http://localhost:20128/v1`), vision model, adjust model — from the live `/models` list, never hardcoded; saves to `%APPDATA%\VisionTrainer\config.json`. Re-openable via Settings. Realizes UJ-1 (entry).

**Functional Requirements:**

#### FR-1: Configure endpoint and models from live list
User can set the LLM endpoint and pick vision + adjust models from the live `GET /models` dropdown. Realizes UJ-1.

**Consequences (testable):**
- Config persists to `%APPDATA%\VisionTrainer\config.json` and reloads on next launch.
- Models never hardcoded; dropdown reflects the live server list; Refresh re-queries.
- Invalid endpoint/model fails with a validation message, never silently.

### 4.2 Attach, Capture & Extract
**Description:** User enters game process (name or PID) and window title; app attaches (validated, never silent), crops the game window (≤1280px JPEG → Base64), and the vision model extracts editable stat values before any write. Known games surface the last RUNBOOK suggestion. `[ASSUMPTION: window-title capture is the primary path; fullscreen fallback exists when window rect is unavailable.]`

**Functional Requirements:**

#### FR-2: Attach to game process with validation
User can attach by process name or PID with explicit success/failure feedback. Realizes UJ-1.

**Consequences (testable):**
- Unresolvable process or failed attach blocks the loop with a clear error.
- Attached process identity feeds Profile/RUNBOOK file naming.

#### FR-3: Capture game window and extract editable values
User can capture the named game window and receive editable extracted stat values; nothing is written at this stage. Realizes UJ-1.

**Consequences (testable):**
- Capture crops the game window (falls back to fullscreen when rect unavailable) and downscales to ≤1280px JPEG Base64.
- Extracted values are shown editable and user edits are what downstream steps use.

### 4.3 Draft Cheats From Wishlist
**Description:** Optional factory wishlist (e.g. `health,stamina,money`) generates Draft cheats that are plausible but unverified; each carries a `lookFor` so the user verifies in-game, then promotes survivors to the live Profile. Draft file is replaced wholesale per run. Realizes UJ-1 (variant).

**Functional Requirements:**

#### FR-4: Generate drafts from wishlist, promote after in-game verify
User can enter a wishlist, get Draft cheats, and promote individually verified ones to the Profile. Realizes UJ-1.

**Consequences (testable):**
- Drafts write to `<Game>.draft.json` (replaced wholesale); unpromoted drafts never touch the live Profile.
- Each draft carries a `lookFor` hint; 6 manual-only trap categories refuse auto-generation with a reason.

### 4.4 Expanded Scan & Parameterized Adjustment
**Description:** For the picked stat, the adjust model (or local arithmetic fallback when unreachable) proposes the write as `extracted × multiplier`; the Expanded Scan narrows to exactly one address and performs a one-shot parameterized write — never writes to >1 address unprompted. Multiplier is user-set per write `[ASSUMPTION: sensible default prefilled, e.g. 100, user-editable]`. Realizes UJ-1.

**Functional Requirements:**

#### FR-5: Propose parameterized write with offline fallback
User gets a write plan of extracted value × user-set multiplier, computed locally when the adjust model is unreachable. Realizes UJ-1.

**Consequences (testable):**
- Fallback arithmetic plan equals extracted × multiplier; plan is shown before any write.
- Multiplier is user-editable per write, not fixed at 100x.

#### FR-6: Expanded scan narrows to a single address
System runs the L0→L4 ladder and writes only when narrowed to exactly one address. Realizes UJ-1.

**Consequences (testable):**
- Zero or ambiguous (>1) results stop with picker/refine, never an unprompted multi-write.
- Successful scan returns `module_offset` + `signature` for anchoring.

### 4.5 Verify & Confirm
**Description:** After the write, the app re-screenshots, asks the vision model for a match verdict, then asks the user yes/no in a Tkinter dialog that never blocks the CE thread. Yes persists Profile + RUNBOOK; No returns to refine with nothing written. Realizes UJ-1, UJ-3.

**Functional Requirements:**

#### FR-7: Vision verdict plus user yes/no gates persistence
System re-screenshots and presents a vision-model verdict alongside a user yes/no; only yes persists. Realizes UJ-1.

**Consequences (testable):**
- No answer writes Profile or RUNBOOK entries; No returns to refine with nothing written.
- Verify dialog never blocks the CE thread.

### 4.6 Freeze & Display
**Description:** Freeze repeatedly writes the target value to hold it against decay; Display is a live readout without writes. Both restore original state on exit, framed behind an UNSAFE gate the user must explicitly accept. Realizes UJ-3.

**Functional Requirements:**

#### FR-8: UNSAFE-gated freeze/display with restore on exit
User can enable freeze or display only after explicit UNSAFE acknowledgement; normal quit restores. Realizes UJ-3.

**Consequences (testable):**
- Without acknowledgement, freeze/patch controls stay disabled.
- Normal shutdown stops workers and restores original values/behavior.

### 4.7 Patch Writer
**Description:** For values the game keeps resetting, locate the writing instruction via data-breakpoint, classify nop/replace/skip, fingerprint with a unique signature, and apply — refused unless the signature is unique; restored on exit, also UNSAFE-gated. Realizes UJ-3 (stubborn variant).

**Functional Requirements:**

#### FR-9: Unique-signature-only code patch with restore
User can patch the writer instruction only when its signature is unique; exit restores. Realizes UJ-3.

**Consequences (testable):**
- Non-unique signature refuses with a reason; skip-classified writers are never patched.
- Applied patches restore on exit.

### 4.8 Profiles, Anchors & Persistence
**Description:** Yes-confirmations upsert `<Game>.json` (schema v1) with module+offset/signature/pointer-chain anchors; saves are atomic; an offline `validate-profile` check exists; restart re-locates via the anchor ladder without rescanning; ambiguous signatures raise instead of guessing. Raw addresses stored informational only. Realizes UJ-2.

**Functional Requirements:**

#### FR-10: Atomic profile saves with anchor ladder re-location
System saves cheats atomically and re-locates them after game restart without rescan. Realizes UJ-2.

**Consequences (testable):**
- Partial/failed saves never corrupt the existing Profile (atomic write).
- Restart with the same game build re-locates via module_offset → signature → pointer chain.
- Ambiguous signature raises for user resolution, never silently picks.

#### FR-11: Offline profile validation
User can run `validate-profile` with no game attached to check schema/anchor integrity. Realizes UJ-2.

**Consequences (testable):**
- Corrupt or anchor-broken profiles report failures per cheat without modifying files.

### 4.9 RUNBOOK & .CT Export
**Description:** Yes-confirmations append to `%APPDATA%\VisionTrainer\runbooks\<Game>.md` (viewable in-app); `Export .CT` shares cheats with Cheat Engine users as plain entries vs auto-assembler scripts vs skipped-with-reason. Realizes UJ-1, UJ-2.

**Functional Requirements:**

#### FR-12: Append-only RUNBOOK plus .CT export
System appends per-game RUNBOOK entries on yes and exports `.CT` with entry-type mapping. Realizes UJ-1.

**Consequences (testable):**
- `View Runbook` opens the current game's file; No-answers append nothing.
- Export maps each cheat to plain entry, AA script, or skipped-with-reason — no silent drops.

### 4.10 Safety Guardrails
**Description:** Offline-only enforcement with in-code refusal for multiplayer/anti-cheat targets; CE "Query memory region routines" stays disabled per repo policy (BSOD prevention). `[ASSUMPTION: refusal is best-effort process/title heuristics plus explicit user attestation, not a perfect detector.]`

**Functional Requirements:**

#### FR-13: Refuse multiplayer / anti-cheat targets
System refuses to operate on multiplayer or anti-cheat titles with an explanatory message.

**Consequences (testable):**
- Known multiplayer/anti-cheat indicators block attach/scan before any write.
- Every freeze/patch path requires the UNSAFE acknowledgement (FR-8/FR-9).

## 5. Non-Goals (Explicit)
- No multiplayer cheats, anti-cheat bypass, or hosted/community cheat library in v1.
- No macOS/Linux support; Windows 10/11 + CE + local LLM server only.
- No signed installer or auto-update in v1 (unsigned one-dir bundle, SmartScreen warning expected).
- No global hotkeys/overlay, Steam discovery, or anchor-resolver cache in v1 (P1).

## 6. MVP Scope

### 6.1 In Scope
- First-run setup with live model list + persisted config.
- Attach → capture → extract → parameterized one-shot write → verify → yes/no → RUNBOOK + Profile.
- Draft wishlist → promote flow with manual-only traps.
- Freeze/display + patch-writer, UNSAFE-gated, restore on exit.
- Atomic profiles, anchor re-location, offline validate-profile, .CT export.

### 6.2 Out of Scope for MVP
- P1 extras (per-game remembered toggles, Steam discovery, anchor cache, hotkeys/overlay) — deferred to v2 for scope control.
- P2 items (bounded pointer-chain auto-search on save, TOML profiles, community library) — deferred; community library additionally needs hosting.
- Signed packaging and store distribution — deferred; unsigned bundle + SHA256SUMS is enough for solo use.

## 7. Success Metrics
- **SM-1**: Full loop success — attach → extract → parameterized write → verify yes → Profile + RUNBOOK on disk, for at least one owned offline game. Validates FR-2, FR-3, FR-5, FR-6, FR-7, FR-10, FR-12.
- **SM-2**: Restart resilience — saved cheat re-locates via anchor without rescan on same game build. Validates FR-10.
- **SM-C1 (counter)**: Multi-write / unprompted-write count — must stay zero; never optimize scan speed at the cost of write safety. Counterbalances SM-1.

## 8. Open Questions
1. Window-rect UNIT-25 handler is live-unverified (no CE in dev env) — does `GetWindowRect` fallback chain work against real game windows or is fullscreen fallback the de-facto path?
2. Does CE resolve `game.exe+0x1234` module+offset symbol strings, or is a parsing fallback needed in `anchor.py` L0?
3. Tkinter `main.py` wizard was never launched in the headless env — does the full wizard render and flow on real Windows?
4. What exact heuristics/attestation back the multiplayer/anti-cheat refusal (title list, module signals, user checkbox)?

## 9. Assumptions Index
- §4.2 window-title capture primary with fullscreen fallback — confirm capture path priority.
- §4.4 multiplier prefilled with sensible default (e.g. 100), user-editable — confirm default.
- §4.10 refusal is best-effort heuristics + attestation, not a perfect detector — confirm acceptable for hobby scope.
