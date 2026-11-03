---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation']
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-Trainer_Application-2026-10-02/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-Trainer_Application-2026-10-02/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/ux-designs/ux-Trainer_Application-2026-10-02/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-Trainer_Application-2026-10-02/EXPERIENCE.md
---

# Trainer_Application - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Trainer_Application, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

FR-1: Configure endpoint and models from live list — User can set the LLM endpoint (default `http://localhost:20128/v1`) and pick vision + adjust models from the live `GET /models` dropdown; persists to `%APPDATA%\VisionTrainer\config.json`; models never hardcoded; invalid endpoint/model fails with validation message. Realizes UJ-1.
FR-2: Attach to game process with validation — User can attach by process name or PID with explicit success/failure feedback; unresolvable process or failed attach blocks the loop; attached identity feeds Profile/RUNBOOK naming. Realizes UJ-1.
FR-3: Capture game window and extract editable values — User can capture the named game window (crop game window, fallback fullscreen when rect unavailable, downscale to ≤1280px JPEG Base64) and receive editable extracted stat values; nothing written at this stage. Realizes UJ-1.
FR-4: Generate drafts from wishlist, promote after in-game verify — User can enter a wishlist (e.g. `health,stamina,money`), get Draft cheats in `<Game>.draft.json` (replaced wholesale) each carrying a `lookFor` hint, and promote individually verified ones to the live Profile; 6 manual-only trap categories refuse auto-generation with a reason. Realizes UJ-1.
FR-5: Propose parameterized write with offline fallback — User gets a write plan of extracted value × user-set multiplier (user-editable per write, prefilled 100), computed locally when the adjust model is unreachable; plan shown before any write. Realizes UJ-1.
FR-6: Expanded scan narrows to a single address — System runs the L0→L4 ladder (L0 exact → L1 type → L2 protection → L3 narrow → picker) and writes only when narrowed to exactly one address; zero or ambiguous (>1) results stop with picker/refine, never unprompted multi-write; success returns `module_offset` + `signature`. Realizes UJ-1.
FR-7: Vision verdict plus user yes/no gates persistence — System re-screenshots and presents a vision-model verdict alongside a user yes/no dialog (never blocks CE thread); only yes persists Profile + RUNBOOK; No returns to refine with nothing written. Realizes UJ-1.
FR-8: UNSAFE-gated freeze/display with restore on exit — User can enable freeze (repeated-write hold) or display (read-only live readout) only after explicit UNSAFE acknowledgement; normal quit stops workers and restores original values/behavior. Realizes UJ-3.
FR-9: Unique-signature-only code patch with restore — User can patch the writer instruction (nop/replace/skip classification via data-breakpoint) only when its signature is unique; non-unique refuses with reason; skip-classified never patched; exit restores. Realizes UJ-3.
FR-10: Atomic profile saves with anchor ladder re-location — System saves cheats atomically to `<Game>.json` (schema v1) with module+offset/signature/pointer-chain anchors; restart with same game build re-locates via module_offset → signature → pointer_chain without rescan; ambiguous signature raises, never silently picks. Realizes UJ-2.
FR-11: Offline profile validation — User can run `validate-profile` with no game attached to check schema/anchor integrity; corrupt or anchor-broken profiles report per-cheat failures without modifying files. Realizes UJ-2.
FR-12: Append-only RUNBOOK plus .CT export — System appends per-game RUNBOOK entries (`%APPDATA%\VisionTrainer\runbooks\<Game>.md`, viewable in-app) on yes only, and exports `.CT` mapping each cheat to plain entry, AA script, or skipped-with-reason. Realizes UJ-1.
FR-13: Refuse multiplayer / anti-cheat targets — System refuses to operate on multiplayer or anti-cheat titles with explanatory message; indicators block attach/scan before any write; every freeze/patch path requires UNSAFE acknowledgement. Best-effort heuristics + attestation per PRD assumption.

MVP scope note (user direction 2026-10-02): build MVP first (FR-1 through FR-13 per §6.1), then enhancements. Deferred to v2: P1 extras (per-game remembered toggles, Steam discovery, anchor-resolver cache, hotkeys/overlay), P2 items (bounded pointer-chain auto-search on save, TOML profiles, community library), signed packaging/store distribution.

### NonFunctional Requirements

NFR-1: Windows 10/11 only; local LLM server + Cheat Engine required; no macOS/Linux support in v1.
NFR-2: Zero unprompted multi-writes (SM-C1 counter); never optimize scan speed at the cost of write safety.
NFR-3: Atomic persistence — partial/failed saves never corrupt the existing Profile.
NFR-4: Clean-quit restore — freeze/patch leave no residual target mutation on normal quit; force-kill residue is a documented known limitation requiring re-resolve via anchor ladder.
NFR-5: Unsigned one-dir PyInstaller bundle; SmartScreen warning expected; no signed installer or auto-update in v1.
NFR-6: Full-loop success measurable (SM-1: attach → extract → parameterized write → verify yes → Profile + RUNBOOK on disk for at least one owned offline game) and restart resilience (SM-2: anchor re-location without rescan on same build).

### Additional Requirements

- AD-1 Tool pairing: every bridge capability (176 tools) exists as global `cmd_<method>` in `ce_mcp_bridge.lua` + `commandHandlers[method]` entry + `@mcp.tool()` in `mcp_cheatengine.py` with identical method string; aliases dispatcher-only, unique, never collide with canonical names.
- AD-2 Transport seam: wire is 4-byte LE length + UTF-8 JSON-RPC, per-side max frame 32 MB; pipe name `CE_MCP_Bridge_v99` identical in all three clients; `CE_MCP_TRANSPORT=pipe|tcp` (default pipe), `CE_MCP_HOST` default `127.0.0.1`, `CE_MCP_PORT` default `9876`; per-RPC deadline `CE_MCP_TIMEOUT` 30.0 on TCP; only connection-loss auto-reconnect retries reads, never blind re-sends of mutating writes.
- AD-3 Main-thread CE execution: pipe worker owns blocking pipe I/O only; every `executeCommand` runs on main thread via `thread.synchronize`; no handler spawns a CE-touching thread.
- AD-4 Response envelope: Lua returns JSON-RPC `result`|`error`; Python unwraps to `{success:true,...}` / `{success:false,error,error_code}`; addresses as hex via `toHex`, parse string-or-int; lists paginate `{total,offset,limit,returned}` limit capped 10000; closed `error_code` vocab (NO_PROCESS, CE_API_UNAVAILABLE, INVALID_PARAMS, NOT_FOUND, DBK_NOT_LOADED, PERMISSION_DENIED, INTERNAL_ERROR); unknown codes treated as INTERNAL_ERROR.
- AD-5 Lua local limit: all `cmd_*` handlers and shared tables global, never `local`; new code carries mergeable `UNIT-NN` marker; helpers stay `local` only when not per-command.
- AD-6 Cleanup ownership: every long-lived resource (HW breakpoint, DBVM watch, scan object, MDL map) registers in `cleanupZombieState`, torn down by `StopMCPBridge` before `StartMCPBridge`; re-executing Lua is safe.
- AD-7 Anchor ladder order: re-location resolves `module_offset` → `signature` → `pointer_chain` → `rescan` callback; ambiguous signatures refuse that rung and fall through; validated chain means non-empty `matches` from read/validate; raw `last_address` never trusted under ASLR.
- AD-8 Mutation ownership with restore: `FreezeWorker`/codepatch own all writes, capture originals once before first write; `restore_on_exit` via `FlowState.shutdown` + `atexit`; drafts replace wholesale, promote only on explicit confirmation; force-kill residue has no auto owner — re-attach must re-resolve and explicitly re-freeze/re-patch.
- AD-9 Safety gates [ASSUMPTION — needs user ratification]: offline-only scope; `run_command`/`shell_execute` require `CE_MCP_ALLOW_SHELL=1` (default unset); arbitrary Lua execution trusted-code-only by convention; TCP relay binds loopback/trusted interfaces only; CE `Query memory region routines` stays disabled; HW DR0–DR3 + DBVM watches preferred over 0xCC.
- AD-10 64-bit branching: handlers branch on `targetIs64Bit()` and use `readPointer()` for pointer-sized data; responses carry `arch` where shape depends on it.
- AD-11 Dependency direction: agent traffic only via MCP server → pipe/tcp → Lua bridge → CE API → target; UI (`main.py`) drives bridge exclusively through headless `FlowState` via `CEBridge`, never CE API directly; `profiles`/`runbook` have no bridge dependency.
- Stack: Python >= 3.10 (floor expires 2026-10-31 — plan bump to >= 3.11); mcp >= 1.28, < 2; CE 7.6 baseline (7.7 compat check owed); Tkinter stdlib; pywin32 >= 306; pytest offline `-m "not live"` vs live `-m live` per `vision_trainer/pytest.ini`.
- No starter template — brownfield repo; Epic 1 starts from existing `vision_trainer/` codebase, not a scaffold.
- Open operational gaps owed before parallel builds: OS/transport matrix, DBVM on/off posture, `%APPDATA%/VisionTrainer` path ownership, bridge observability (stderr-only debug log).

### UX Design Requirements

UX-DR1: CustomTkinter 6.0.0 drop-in — follow Windows light/dark, minimal brand color, correct HiDPI, PyInstaller one-dir retained; single-window 900×700 min, resizable with scrollable body grid, header + log + body grid, no step nav; listbox heights PID-name h6 / values h8 / drafts h5.
UX-DR2: Sticky UNSAFE armed banner — exact copy `UNSAFE ARMED — Freeze/Patch can corrupt saves. Restores on clean quit only; killing the app may leave game memory changed. Offline games only.`; text+icon never color-only; sticky header placement, never dismissible while armed; compact armed chip mirrored adjacent to Freeze ON and Patch writer; sole amber use.
UX-DR3: Split per-session UNSAFE gates — `Freeze acknowledgement` + `Patch acknowledgement` checkboxes in Setup; per-launch persistence only (per-session re-arm each launch), explicit `Disarm` in Extras; unchecked = respective controls disabled.
UX-DR4: Blocking write-preview dialog — shows address, label, extracted × multiplier = target, fallback disclosure when adjust unreachable, CE safety-setting status; explicit `Write` / `Cancel`; display-only is not consent; excluded from Enter-default.
UX-DR5: Editable value field — edit via field + `Apply` / discard with dirty marker; numeric validation before plan; plan echoes exact committed operands; stale-vs-edited distinguishable.
UX-DR6: Multiplier input — entry prefilled `100`; rejects ≤0 / non-numeric / overflow-huge with `showerror` Adjust: `Multiplier must be a number from 1 to 1000000.`
UX-DR7: Verify confirm — exact copy `Value now shows {observed} (expected {expected}). Correct?` (`askyesno`, defaults No); only Yes persists + `RUNBOOK updated:`; No returns to refine.
UX-DR8: Patch just-in-time confirm — exact risk copy `Change the value in-game now so the watch can catch the writer of {address}. This attaches a debugger and patches code. It can crash or corrupt saves. Offline saves only. Continue?`; unique-signature-only else `Patch skipped {reason}`; excluded from Enter-default.
UX-DR9: Drafts signaling — `Verified:` / `Unverified:` icon+text prefixes (never brackets/case-only/color); wishlist default `health,stamina,money`; 6 manual traps (runspeed, speed, nosearch, hunger, cash, curfew) log `Manual: {label}: {reason}` and never auto-draft.
UX-DR10: Profiles / RUNBOOK / Export surfaces — `Validate profile` button (offline, per-cheat pass/fail, never modifies files); View Runbook (`No runbook yet.` when empty); Open Profiles Folder; Export .CT via save dialog (`Cheat Table *.CT`, default `cheats.CT`) mapping plain / AA script / skipped-with-reason; `No profile cheats yet.` / `Exported {n} entries to {dest}.`
UX-DR11: Setup modal — endpoint entry (default URL), vision/adjust comboboxes from live `/models`, Test → status line, Save → `config.json`, Refresh → model list; `Tab` trap + focus return; Esc closes, Enter activates focused button; Settings re-opens.
UX-DR12: Pre-attach refuse gate — offline-only attestation + blocklist/heuristic check at Process surface before any scan; on hit `showerror` Refuse exact copy, detach, lock PID, disable Adjust/Freeze/Patch until target changes; dismiss never re-enables writes.
UX-DR13: Shutdown UX — `WM_DELETE_WINDOW → shutdown()` + `atexit restore_on_exit`; clean-quit restore checklist with per-item restored/failed status; next-launch stale-state recovery banner; kill-path documented as known limitation in banner copy.
UX-DR14: Accessibility floor — WCAG 2.2 AA intent; named widgets; status line + live status text as polite live region (disabled log visual-only); Tab order = reading order; explicit focus ring (outline, never color-only), verified light/dark/High-Contrast; Narrator + NVDA verified both themes; 125/150/200% scaling no loss/overlap; targets ≥24×24; drafts signal by word not styling.
UX-DR15: Field-associated errors — every `showerror` names failing field (`Process — Attach failed: {reason}` pattern), mirrors inline next to entry, moves focus on dismiss; icon+text never red-only.
UX-DR16: Exact log-line + status vocabulary — `Settings saved.`, `Attached to PID {id}`, `Captured {w}x{h} ({KB} KB base64)`, `Verify: observed={o} match={m}`, `Back to refine: re-capture or re-narrow the scan.`, `Freeze ON: {label} @ {address} = {value}` / `Freeze OFF (restored): {label}`, `Patched writer {addr} (sig {sig}). Restored automatically on exit.`, `Manual: {label}: {reason}`, `Promoted {label} to live profile.`, `Adjust model unreachable — local ×100 fallback.`, `Drafts written (replaced): {path}. Verify each in-game before promoting.`, status `{n} models found` / `OK — {n} models` / `Failed: {exc}` / `Endpoint unreachable: {exc}`.
UX-DR17: Microcopy + banned patterns — exact strings from EXPERIENCE.md Voice table; banned: unprompted multi-write, blocking CE thread, color-only warnings, second windows beyond modal + allowed dialogs, hotkeys/overlay/Steam discovery/anchor cache/toggles/community library, macOS/Linux flows, multiplayer flows, signed-installer or step-nav additions.

### FR Coverage Map

FR-1: Epic 1 - Endpoint + model configuration from live list
FR-2: Epic 2 - Attach to game process with validation
FR-3: Epic 2 - Capture window and extract editable values
FR-4: Epic 3 - Draft wishlist cheats, promote after in-game verify
FR-5: Epic 2 - Parameterized write plan with offline fallback
FR-6: Epic 2 - Expanded scan narrows to exactly one address
FR-7: Epic 2 - Vision verdict plus user yes/no gates persistence
FR-8: Epic 4 - UNSAFE-gated freeze/display with restore on exit
FR-9: Epic 4 - Unique-signature-only code patch with restore
FR-10: Epic 3 - Atomic profiles with anchor ladder re-location
FR-11: Epic 3 - Offline profile validation
FR-12: Epic 3 - Append-only RUNBOOK plus .CT export
FR-13: Epic 1 - Refuse multiplayer / anti-cheat targets

## Epic List

### Epic 1: Setup & Safe Foundation
Drak can configure the app once and be protected from wrong targets before anything else runs.
**FRs covered:** FR-1, FR-13

### Epic 2: Core Cheat Loop — See It, Change It, Prove It
Drak can turn a number on screen into a bigger number in-game, with proof, in one sitting (UJ-1).
**FRs covered:** FR-2, FR-3, FR-5, FR-6, FR-7

### Epic 3: Cheats That Survive Restart
Drak's proven cheats re-apply after a game restart with no rescan, and he keeps a record of what worked (UJ-2).
**FRs covered:** FR-4, FR-10, FR-11, FR-12

### Epic 4: Stubborn Values — Freeze, Display & Patch
Drak can hold decaying/resetting values where he put them until he quits, with the app cleaning up after itself (UJ-3).
**FRs covered:** FR-8, FR-9

## Epic 1: Setup & Safe Foundation

Drak can configure the app once and be protected from wrong targets before anything else runs.

### Story 1.1: Launch the app shell on real Windows

As a non-technical player,
I want the app to open as a single native-feeling window,
So that I can reach every step without touching a CLI.

**Acceptance Criteria:**

**Given** Windows 10/11 with Python and dependencies installed
**When** Drak launches the app
**Then** a single window titled `Vision Trainer (offline games only)` opens at minimum 900x700, resizable with scrollable body grid, header row plus disabled log plus body grid, and no step navigation
**And** CustomTkinter 6.0.0 follows the OS light/dark theme with correct HiDPI at 125/150/200 percent scaling and no loss or overlap
**And** Tab order matches reading order, focus ring is an outline never color-only, Esc closes the topmost modal with the safe default, and all interactive targets are at least 24x24
**And** every field error names the failing field, mirrors inline next to the entry, moves focus there on dismiss, and uses icon plus text never red-only

### Story 1.2: First-run setup with live model list

As a non-technical player,
I want to point the app at my local LLM server and pick models from a live list,
So that extraction and planning work without editing config files.

**Acceptance Criteria:**

**Given** first run with no config file
**When** the app opens
**Then** the Setup modal opens with endpoint prefilled `http://localhost:20128/v1`, vision and adjust comboboxes populated from live `GET /models`, Test, Save, and Refresh buttons, Tab trap with focus return, and Esc to close
**And** with a reachable endpoint, pressing Test shows status `OK — {n} models`, and Refresh re-queries and auto-fills the first model only-if-empty
**And** with valid endpoint and models, pressing Save persists config to `%APPDATA%\VisionTrainer\config.json`, logs `Settings saved.`, and closes the modal, and header Settings re-opens it
**And** with an unreachable endpoint or invalid model, Test or Save shows `Endpoint unreachable: {exc}` or `Failed: {exc}` with a validation message and never fails silently, and models are never hardcoded

### Story 1.3: Offline-only refuse gate

As a non-technical player,
I want the app to refuse multiplayer and anti-cheat targets with a clear reason,
So that I never accidentally cheat where I should not.

**Acceptance Criteria:**

**Given** a process entered at the Process surface
**When** the pre-attach gate runs offline attestation plus blocklist and heuristic check
**Then** on a hit it shows `Offline games only — this target looks like multiplayer or anti-cheat ({reason}). Detaching; change the target to continue.`, detaches, locks that PID, and disables Adjust, Freeze, and Patch until the target changes, and dismissing the dialog never re-enables writes
**And** with a clean offline target the gate passes and attach proceeds with no extra friction

## Epic 2: Core Cheat Loop — See It, Change It, Prove It

Drak can turn a number on screen into a bigger number in-game, with proof, in one sitting (UJ-1).

### Story 2.1: Attach to the game process

As a non-technical player,
I want to attach by game name or PID with clear feedback,
So that the loop knows which process to scan.

**Acceptance Criteria:**

**Given** a running offline game
**When** Drak enters its name or PID and presses Attach
**Then** success logs `Attached to PID {id}`, the identity feeds Profile and RUNBOOK naming, and the PID-name listbox rebuilds on Refresh
**And** with an unresolvable name or failed attach, it shows `Process — Attach failed: {reason}`, leaves the list unchanged, and blocks the loop with no silent continue
**And** attach health checks use side-effect-free `get_opened_process_id`, never `get_process_info` nor bridge reload as a health check

### Story 2.2: Capture the game window

As a non-technical player,
I want one button to capture the game window,
So that the vision model can read my stats without me taking screenshots manually.

**Acceptance Criteria:**

**Given** an attached game with a named window
**When** Drak presses Capture
**Then** it crops the game window, falls back to fullscreen when the rect is unavailable, downscales to at most 1280px JPEG Base64, logs `Captured {w}x{h} ({KB} KB base64)`, and writes nothing
**And** with a failed capture, it shows `Capture failed`, clears no values, and writes nothing
**And** the live-unverified `GetWindowRect` fallback chain is proven against a real game window and the de-facto path is recorded

### Story 2.3: Extract values and edit them

As a non-technical player,
I want the visible stats as editable rows,
So that what I saw on screen is what the scan uses.

**Acceptance Criteria:**

**Given** a fresh capture
**When** Drak presses Extract
**Then** rows render as `label: value [type] conf=0.XX` in the values listbox, and failure shows `Extract failed` and leaves the listbox unchanged
**And** editing a row via field plus Apply shows a dirty marker until committed, runs numeric validation before any plan, echoes the exact committed operands in the plan, and discard drops the edit
**And** with no selection, pressing Adjust shows `Select a value first.` and writes nothing

### Story 2.4: Parameterized plan and expanded scan to one address

As a non-technical player,
I want a previewed multiply-plan and a scan that narrows to exactly one address,
So that one button press changes exactly one value.

**Acceptance Criteria:**

**Given** a committed value
**When** Drak sets the multiplier prefilled `100`, validated 1 to 1000000 else `Multiplier must be a number from 1 to 1000000.`, and confirms
**Then** the blocking write-preview shows address, label, extracted times multiplier equals target, fallback disclosure when the adjust model is unreachable, and CE safety-setting status, with explicit `Write` and `Cancel`, and display-only is not consent, and an unreachable model offers `Use local ×100 fallback` or `Abort` and logs `Adjust model unreachable — local ×100 fallback.`
**And** with Write confirmed, the L0 to L3 ladder runs exact to type to protection to narrow, writes only on exactly 1 address, and returns `module_offset` plus `signature`, while zero or multi-address stops with picker or refine plus `{exc} Change the value in-game, then use Verify to continue narrowing.`, never an unprompted multi-write
**And** module plus offset strings like `game.exe+0x1234` are proven against CE resolution behavior and the parse-or-fallback path is recorded

### Story 2.5: Verify with vision verdict and user confirm

As a non-technical player,
I want proof the value actually changed before anything is saved,
So that guesses never become cheats.

**Acceptance Criteria:**

**Given** a completed write
**When** Drak presses `Verify (re-screenshot)`
**Then** the app re-screenshots, gets the vision verdict logging `Verify: observed={o} match={m}` without blocking the CE thread, and asks `Value now shows {observed} (expected {expected}). Correct?` defaulting to No
**And** with Yes the profile persists atomically and the RUNBOOK appends with `RUNBOOK updated:`, while with No nothing persists and the loop returns to refine with `Back to refine: re-capture or re-narrow the scan.`

## Epic 3: Cheats That Survive Restart

Drak's proven cheats re-apply after a game restart with no rescan, and he keeps a record of what worked (UJ-2).

### Story 3.1: Atomic profiles with anchor re-location

As a non-technical player,
I want confirmed cheats saved with durable anchors,
So that they re-apply after a restart with no rescan.

**Acceptance Criteria:**

**Given** a Yes confirmation
**When** the cheat persists
**Then** it upserts `<Game>.json` schema v1 atomically with module plus offset, signature, and pointer-chain anchors, and partial or failed saves never corrupt the existing Profile
**And** with the same game build relaunched, each cheat re-locates via module_offset to signature to pointer_chain with no rescan, after a per-cheat plan plus confirm of address, label, old to new, where opening a profile never auto-writes, and raw `last_address` is never trusted under ASLR
**And** with an ambiguous signature, re-location raises for user resolution and falls through to the next ladder rung, never silently picking

### Story 3.2: Offline profile validation

As a non-technical player,
I want to check a saved profile with no game running,
So that I know which cheats are still good.

**Acceptance Criteria:**

**Given** no game attached
**When** Drak presses `Validate profile`
**Then** it checks schema and anchor integrity and lists per-cheat pass and fail with the failure reason, and failures never modify files

### Story 3.3: RUNBOOK and .CT export

As a non-technical player,
I want a readable log of what worked plus a way to share it with Cheat Engine,
So that I remember proven cheats and can hand them off.

**Acceptance Criteria:**

**Given** a Yes confirmation
**When** persistence runs
**Then** it appends to `%APPDATA%\VisionTrainer\runbooks\<Game>.md`, `View Runbook` opens the current game's file, `No runbook yet.` shows when empty, and No-answers append nothing
**And** with profile cheats saved, Export .CT opens a save dialog filtered `Cheat Table *.CT` defaulting to `cheats.CT` and maps each cheat to plain entry, AA script, or skipped-with-reason with per-skip newline `Skipped {label}: {reason}` lines and no silent drops, while empty exports show `No profile cheats yet.` and success shows `Exported {n} entries to {dest}.`

### Story 3.4: Draft wishlist and promote

As a non-technical player,
I want wishlist words turned into unverified draft cheats I can promote one by one,
So that guessing starts somewhere without polluting proven cheats.

**Acceptance Criteria:**

**Given** a wishlist entry defaulting to `health,stamina,money`
**When** Drak presses Draft cheats
**Then** drafts write wholesale to `<Game>.draft.json` each carrying a `lookFor` hint, the log shows `Drafts written (replaced): {path}. Verify each in-game before promoting.`, and unpromoted drafts never touch the live Profile
**And** with drafts listed under `Verified:` and `Unverified:` icon plus text prefixes, promoting one individually after in-game verify logs `Promoted {label} to live profile.`, while empty promote shows `Draft cheats first.`
**And** with any of the 6 manual-only traps of runspeed, speed, nosearch, hunger, cash, and curfew, drafting logs `Manual: {label}: {reason}` and never auto-drafts it

## Epic 4: Stubborn Values — Freeze, Display & Patch

Drak can hold decaying/resetting values where he put them until he quits, with the app cleaning up after itself (UJ-3).

### Story 4.1: Per-session UNSAFE gates and armed banner

As a non-technical player,
I want to explicitly arm Freeze and Patch each launch with the risks spelled out,
So that I never enable something dangerous by accident.

**Acceptance Criteria:**

**Given** the Setup modal
**When** Drak views the gates
**Then** split `Freeze acknowledgement` plus `Patch acknowledgement` checkboxes show adjacent risk copy, persist per-launch only with per-session re-arm required, and unchecked keeps respective controls disabled, with an explicit `Disarm` in Extras
**And** with either gate armed, the sticky header banner shows `UNSAFE ARMED — Freeze/Patch can corrupt saves. Restores on clean quit only; killing the app may leave game memory changed. Offline games only.` text plus icon never color-only and never dismissible while armed, with compact armed chips mirrored adjacent to Freeze ON and Patch writer

### Story 4.2: Freeze and display with restore on quit

As a non-technical player,
I want decaying values held where I put them or just watched live,
So that stubborn stats stay put until I quit cleanly.

**Acceptance Criteria:**

**Given** a selected value and armed Freeze gate
**When** Drak sets Mode `one_shot/freeze/display` and presses Freeze ON with the just-in-time confirm
**Then** freeze binds to the snapshotted address plus label where changing selection while frozen never retargets, holds via repeated writes, and logs `Freeze ON: {label} @ {address} = {value}`, while Display is the read-only live readout variant with no writes
**And** with normal quit, workers stop, originals restore, and the quit-time checklist reports per-item restored or failed, where Freeze OFF logs `Freeze OFF (restored): {label}` and off-with-none shows `No active freeze for {label}.`
**And** with no selection, Freeze or Patch shows `Adjust a value first.` and does nothing, and kill-path residue stays a documented limitation covered by the banner copy plus next-launch stale-state recovery banner

### Story 4.3: Patch-writer with unique-signature rule

As a non-technical player,
I want the resetting instruction itself patched only when it is safe to identify,
So that the game stops overwriting my value.

**Acceptance Criteria:**

**Given** a selected value and armed Patch gate
**When** Drak presses `Patch writer (stubborn value)`
**Then** the just-in-time confirm asks `Change the value in-game now so the watch can catch the writer of {address}. This attaches a debugger and patches code. It can crash or corrupt saves. Offline saves only. Continue?`, locates the writer via data-breakpoint, classifies nop, replace, or skip, applies only on a unique signature, and logs `Patched writer {addr} (sig {sig}). Restored automatically on exit.`
**And** with a non-unique signature, patch evaluation refuses with `Patch skipped {reason}`, skip-classified writers are never patched, and errors show `Patch failed`
**And** with an applied patch, normal quit restores bytes via the quit-time checklist, and hardware DR0 to DR3 breakpoints and DBVM watches are preferred over 0xCC software breakpoints throughout
