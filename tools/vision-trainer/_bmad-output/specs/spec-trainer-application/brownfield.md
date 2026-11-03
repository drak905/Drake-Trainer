# Brownfield Notes — Trainer Application

As-built HOW contract. The kernel states WHAT; this file states HOW the code does it today. New work ratifies these mechanics rather than inventing parallel ones.

## Bridge tier

- **Tool pairing:** `cmd_<method>` global in `ce_mcp_bridge.lua` under a `UNIT-NN` marker, plus a `commandHandlers[method]` dispatcher entry, plus a matching `@mcp.tool()` in `mcp_cheatengine.py` with the identical method string. 176 tools, 183 dispatcher entries (176 + 7 aliases). Aliases live only in the dispatcher table, unique, never colliding with a canonical name. Counts stay in sync across `AGENTS.md`, `CLAUDE.md`, `README.md`, and the command reference.
- **Wire:** 4-byte LE length prefix + UTF-8 JSON-RPC; largest accepted body just under 32 MB (Lua accepts `len < 32 MB`, all Python readers reject `length > 32 MB`). Pipe name `CE_MCP_Bridge_v99` identical in `mcp_cheatengine.py`, `ce_tcp_relay.py`, `ce_mcp_bridge.lua` (bare name), and `vision_trainer/ce_client.py`. Env: `CE_MCP_TRANSPORT=pipe|tcp` (aliases `named_pipe`/`named-pipe`/`np`, `socket`; default `pipe`), `CE_MCP_HOST` default `127.0.0.1`, `CE_MCP_PORT` default `9876`, `CE_MCP_TIMEOUT` default `30.0`. Only connection-loss auto-reconnect retries reads, never blind re-sends of mutating writes.
- **Threading:** Pipe worker thread owns blocking I/O only; every `executeCommand` runs on the main thread via `thread.synchronize`. No CE-touching threads.
- **Envelope:** Lua returns JSON-RPC `result`|`error`; Python unwraps to `{success:true,...}` or `{success:false,error,error_code}`. Addresses out as hex via `toHex`, in as string-or-int. Lists paginate as `{total,offset,limit,returned}`, limit capped at 10000. Closed `error_code` set: `NO_PROCESS`, `CE_API_UNAVAILABLE`, `INVALID_PARAMS`, `NOT_FOUND`, `DBK_NOT_LOADED`, `PERMISSION_DENIED`, `INTERNAL_ERROR`; unknown codes treated as `INTERNAL_ERROR`.
- **Lua globals:** All `cmd_*` handlers and shared tables global, never `local` (CE fails past 200 Lua locals). Load from disk via `dofile(...)`, never paste into a cheat-table script.
- **Stdio guard:** The top block of `mcp_cheatengine.py` never moves; it patches both stdio servers and redirects stdout to stderr. Python logs via `debug_log()` to stderr only.
- **Attach check:** `ping` plus side-effect-free `get_opened_process_id`. Never `get_process_info` (reinitializes the symbol handler) nor bridge reload (destroys breakpoints/watches/scans) as a health check.
- **Arch:** Handlers branch on `targetIs64Bit()` and use `readPointer()` for pointer-sized data; responses carry `arch` where shape depends on it.
- **Timeout gap (pre-mortem finding):** `CE_MCP_TIMEOUT` is honored on TCP paths only; the pipe path in `ce_client.py` has no RPC deadline. Equal-deadline behavior on both transports is specified (CAP-2) but not yet implemented — a code change or an explicit spec weakening is owed before parallel builds rely on it.
- **Error-code gap (pre-mortem finding):** `ce_client.parse_frame` drops `error_code`, returning only `{"success": False, "error": ...}`. The closed taxonomy is specified but not observable on the app path — surface it in the client or weaken the claim; no new codes until both clients carry the taxonomy.

## vision_trainer tier

- **Layering:** `main.py` (Tkinter wizard) drives the bridge exclusively through headless `flow.py FlowState` (owns attach, confirm/promote, shutdown) and reaches the wire only via `ce_client.py CEBridge`. `profiles.py`/`runbook.py` have no bridge dependency.
- **LLM setup:** First-run wizard takes endpoint (default `http://localhost:20128/v1`), vision model, and adjust model; saved to `%APPDATA%\VisionTrainer\config.json`. Models picked from the live `GET /models` list, never hardcoded; chat uses `POST /chat/completions`. Local arithmetic fallback when the adjust model is unreachable.
- **MCP client config:** TOML server block for Codex, JSON server entry for Claude Code; restart the client after adding and verify with the `ping` tool.
- **Capture pipeline:** Game-window crop → ≤1280px JPEG → Base64 → `extract_values`/`verify_value`; values editable before any write.
- **Modes:** one-shot write, freeze (repeated write + restore on exit), display (live readout), patch-writer (data-breakpoint → NOP/replace; refused unless the signature is unique; bytes restored on exit).
- **Drafts:** Factory wishlist → wholesale-replaced `<Game>.draft.json`; promotion to the live profile only on explicit user action after in-game verification, or marked explicitly unverified and never auto-applied; currently no verification enforcement at promote time (spec now requires it — implementation owed).
- **Anchor capture (pre-mortem finding):** `scan_flow` capture failure currently degrades to `signature=None` and an anchorless persist. Per spec this is now a write-blocking error — capture must produce at least one ladder rung before user-yes writes anything.
- **Rescan rung (pre-mortem finding):** The ladder's 4th rung has no defined owner or inputs. The rescan recipe owner and its inputs (scan recipe from profile/runbook) must be defined before CAP-5's full-game-update path is buildable.
- **Persistence:** User-yes writes both `%APPDATA%\VisionTrainer\runbooks\<Game>.md` (append-only, recipe row upsert plus timestamped history) and `%APPDATA%\VisionTrainer\profiles\<Game>.json` (`schema:1`). `Export .CT` shares cheats (plain entries vs auto-assembler scripts vs skipped-with-reason).
- **Force-kill caveat:** In-memory originals are lost and `atexit` never runs, so recovery re-resolves via the anchor ladder and explicitly re-freezes/re-patches.

## Verification gates

- Offline (no CE): `python -m pytest vision_trainer/tests/ -q -m "not live"` plus `lua MCP_Server/test_pointer_parse.lua`.
- Bridge integration (CE running, bridge loaded, process attached): `python MCP_Server/test_mcp.py`; DBVM-gated skips expected, failures exit non-zero.
- Live app (harness + CE + attached offline game): `python -m pytest vision_trainer/tests/test_harness_live.py -m live -q`.

## Packaging and PR convention

- App ships as a one-dir `pyinstaller vision_trainer.spec` bundle in `dist\VisionTrainer\`; LLM server, models, CE, and RUNBOOK/config/profile dirs stay external. `harness/sha256sums.py` writes `SHA256SUMS.txt`. Smoke-test on a clean VM (CE + LLM present, no Python): full loop including profile + RUNBOOK. Unsigned binary, expect SmartScreen on first run.
- vision_trainer PRs state the game + build validated in-game and which cheats are proven vs unproven.
