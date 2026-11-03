# Vision Trainer

Standalone Windows app that auto-adjusts **offline** game data (currency, HP,
mana, …) to 100x: screenshot → Base64 → local LLM reads the value → expanded
memory scan → write → re-screenshot verify → user yes/no → per-game RUNBOOK.

Educational / offline-games-only. Not for multiplayer or anti-cheat titles.

## Prerequisites

1. Windows 10/11, Cheat Engine installed.
2. CE → Settings → Extra → **disable "Query memory region routines"**
   (BSOD prevention — hard requirement of this repo).
3. In CE: `File → Execute Script → MCP_Server/ce_mcp_bridge.lua → Execute`
   (look for `[MCP v12.0.0] MCP Server Listening on: CE_MCP_Bridge_v99`).
4. A local OpenAI-compatible LLM server, default
   `http://localhost:20128/v1` (pre-filled; editable). It must expose
   `GET /models` and `POST /chat/completions`. Example tagged models:
   vision `ag/gemini-3.8-flash-high`, adjust
   `cmc/meta/muse-spark-1.3-contributor` — picked from the live model list,
   never hardcoded.

## Install & run (dev)

```bat
pip install -r vision_trainer\requirements-vision-app.txt
pip install -r vision_trainer\requirements-dev.txt
python -m vision_trainer.main
```

Tests (TDD, no CE needed — all IO mocked/stubbed):

```bat
python -m pytest vision_trainer/tests/ -q -m "not live"
```

Opt-in live tests (needs `vision_trainer/harness/target.py` + CE bridge):

```bat
python -m pytest vision_trainer/tests/test_harness_live.py -m live -q
```

## First-run setup

On first launch the Setup wizard asks for exactly 3 things and saves them to
`%APPDATA%\VisionTrainer\config.json`:

1. **Endpoint** (default `http://localhost:20128/v1`) — Refresh lists models
   via `GET {endpoint}/models`.
2. **Vision model** — reads screenshots (`extract_values`, `verify_value`).
3. **Adjust model** — plans the ×100 write (may be the same or a cheaper
   text model). Falls back to a local arithmetic plan when unreachable.

`Settings / Update info` re-opens this form anytime.

## Loop

1. Enter the game process (name or PID) → Attach (validated, never silent).
   Known games show the RUNBOOK suggestion from the last success.
2. Enter the game window title → Capture (native PrintWindow client-area
   crop → HUD strip → PNG → Base64, no focus steal; mss fullscreen fallback;
   `screenshot.read_visible_stats` does find → capture → `extract_values_auto`
   in one call and tolerates flat `{stat: number}` replies and `integer`
   type aliases) → Extract values (editable before any write).
   Optional: enter a factory wishlist (`health,stamina,money`) → Draft cheats
   (plausible ≠ right field — verify each in-game via its `lookFor`, then
   Promote to the live profile).
3. Pick a stat → adjust model proposes the write → expanded scan
   (exact → type → protection → narrow → picker; never writes to >1 address
   unprompted) → 100x write. Modes: one-shot, freeze (repeated write +
   restore on exit), display (live readout). Stubborn value the game keeps
   resetting? Use "Patch writer" (data-breakpoint → NOP/replace the writer;
   refused unless the signature is unique; restored on exit).
4. Verify re-screenshots and asks the vision model for a match verdict, then
   asks **you** yes/no (Tkinter dialog — never blocks the CE thread).
5. **Yes** → creates/updates `%APPDATA%\VisionTrainer\runbooks\<Game>.md`
   **and** `%APPDATA%\VisionTrainer\profiles\<Game>.json` (durable cheats
   with module+offset / signature / pointer-chain anchors — raw addresses
   marked informational due to ASLR). Restart the game and the anchor
   re-locates without a rescan. `Export .CT` shares cheats with Cheat Engine
   users (plain entries vs auto-assembler scripts vs skipped-with-reason).
   **No** → back to refine; no RUNBOOK/profile write.

`View Runbook` opens the current game's file.

## Packaging

```bat
pip install pyinstaller
pyinstaller vision_trainer.spec
```

One-dir bundle in `dist\VisionTrainer\`. The LLM server, models, CE, and the
RUNBOOK/config/profile dirs stay external. `python
vision_trainer/harness/sha256sums.py dist/VisionTrainer` writes
`SHA256SUMS.txt`. Smoke-test on a clean VM (CE + LLM present, no Python):
full loop incl. profile + RUNBOOK. No admin required. The binary is
unsigned, so expect a Windows SmartScreen warning on first run.

PR convention: state which game + build you validated in-game, and which
cheats are proven vs unproven (see `CI.md`).
