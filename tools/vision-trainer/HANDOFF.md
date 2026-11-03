# HANDOFF — Astral Ascent trainer (for the next agent)

Date: 2026-10-04 (evening). Session ended on depleted quota. Supersedes the
2026-10-02 HANDOFF content below where they conflict. Nothing committed;
everything is uncommitted in the working tree (see `git status`).

## Live environment (verify on start — PIDs/handles change on restart)

- Game: `Astral Ascent.exe` PID **17316** (same process all session; HP write persists).
- CE: `cheatengine-x86_64-SSE4-AVX2` PID **27000** (restarted mid-session).
  MUST re-verify: `ping` + `get_opened_process_id` (expect 17316, else re-attach).
- Pipe `\\.\pipe\CE_MCP_Bridge_v99`, bridge v12.0.0, autorun loads
  `MCP_Server/ce_mcp_bridge.lua`.
- Game window handle was `0x50c02` — re-resolve with
  `screenshot.find_window_handle("Astral Ascent")`, never hardcode.
- LLM endpoint `http://localhost:20128/v1`, vision `ag/gemini-3.8-flash-high`,
  saved config at `%APPDATA%/VisionTrainer/config.json`.
- Agent shell is now **Admin** (`IsUserAnAdmin()=1`, High integrity) — user
  relaunched the terminal as Admin. Still could NOT steal focus (see below).

## DONE: Health 90 -> 9999 (verified in-game via screenshot)

- HP is a **double** (dword/float ladders correctly died at 0).
- Scan: double 136 -> 17379 hits -> 104 -> 6 -> 90 -> 6 mirrors tracking together.
- Wrote 9999 (double) to `0x7FF699C1FCB8` (first static candidate, user-approved,
  first try). Readback + HUD `9999/150` both confirm.
- Anchor: `Astral Ascent.exe+A2EFCB8` (static, restart-proof) + AOB
  `00 40 00 00 00 00 80 87 C3 40 00 00 00` (offset 2).
- Saved: `%APPDATA%/VisionTrainer/profiles/Astral_Ascent.exe.json` and
  `runbooks/Astral_Ascent.exe.md`. 5 mirror addresses left unwritten (harmless).
- Clean state otherwise: no freezes, no breakpoints, no patches active.

## IN PROGRESS: unlimited jump (not started on memory — blocked on input)

Goal: infinite jump, tested working. Nothing scanned yet for jump.

### What was built this session (uncommitted, tests green)

- `vision_trainer/screenshot.py`: `find_window_handle`, `client_rect`,
  `grab_printwindow` (ctypes `PrintWindow`, occlusion-proof, blank-detect with
  mss fallback), `encode_image_base64_png`, `capture_window_handle`
  (client crop + `top_fraction` HUD strip), **`read_visible_stats`** =
  find -> capture -> extract in one call. Live-proved: `level=1, health=9999,
  max_health=150`, conf 0.95+.
- `vision_trainer/llm_client.py`: **`extract_values_auto`** (accepts flat
  `{stat: number}` replies; the model does this in the wild) + `_VALUE_TYPE_ALIASES`
  (`integer`->dword etc.; also seen live). Strict `extract_values` untouched.
- Tests: +13 cases (`test_screenshot.py`, `test_llm_vision.py`).
  Gate: `python -m pytest vision_trainer/tests/ -q -m "not live" -c
  vision_trainer/pytest.ini` -> **235 passed**.
- `vision_trainer/README.md`: one-paragraph doc of the new capture path.

### Input-path findings (all tested live, read carefully)

1. Bridge `do_key_press`/`key_down`/`key_up`/`is_key_pressed` take **`{"vk": int}`
   ONLY** (`mcp_cheatengine.py:1482-1504`). The Command Reference docs showing
   `key` names / `duration_ms` are aspirational — wrong. Also: never call CE
   `find_window`/`get_window_rect` (hangs);
   use native `find_window_handle`. `get_window_rect` is stubbed to
   `CE_API_UNAVAILABLE` in the Lua for this reason.)
2. Posted `WM_KEYDOWN/UP` Space via `send_window_message` to the game window:
   delivered (`success:true`) but **ignored** (no jump) — game doesn't pump messages.
3. CE `do_key_press` (global SendInput) and local ctypes SendInput both need
   game **keyboard focus** at send time.
4. **Focus war (unresolved)**: Admin `Lua Engine` window (0x40d24) holds
   foreground and re-asserts constantly. As medium AND as Admin shell, ALL of
   these failed: `SetForegroundWindow`, `SwitchToThisWindow`, Alt-key trick,
   `AttachThreadInput`+`SetFocus` (access denied pre-elevation; error 0 after).
   Minimizing CE windows doesn't stick (Lua Engine self-restores, apparently on
   new bridge log output). `WM_CLOSE` to Lua Engine ignored. Closing it was NOT
   attempted further — bridge survived (ping OK after the attempt).
5. **One user click on the game window DOES grant focus that held ~30 min**
   through heavy CE traffic. So autonomy is one click away, repeatedly proven.

### Next-agent playbook (in order)

1. `ping` + `get_opened_process_id` (expect 17316). Re-attach if CE restarted.
2. Ask user to **click the game window once** (or run this in THEIR interactive
   Admin terminal, which can foreground — agent shells can't):
   `powershell -c "$s=Add-Type -MemberDefinition '[DllImport(\"user32.dll\")]public static extern bool SetForegroundWindow(IntPtr h);' -Name W -Namespace U -PassThru; $s::SetForegroundWindow(0x50c02)"`
   (re-resolve handle first — it changes on game restart).
3. Immediately (same script, zero CE calls inside the window): verify
   `GetForegroundWindow()==game`, ctypes scancode Space tap (`0x39`), screenshot
   +300ms, confirm character left ground. This proves the input path.
4. Build `vision_trainer/input.py` on the proven path: `key_tap(vk, scan,
   hold)`, `jump_then_read(air_ms)`; rule learned the hard way: **never
   interleave bridge calls between focus-acquire and send** (CE log output
   restores the Lua Engine, which steals focus back).
5. Grounded-flag hunt (no pause key exists — Esc does nothing in-game):
   `scan_all` unknown dword while standing -> scripted Space tap -> `next_scan
   changed` (airborne, ~300ms) -> wait 1.5s (landed) -> `next_scan unchanged`,
   repeat to convergence. Fell back to this because mid-air pausing is impossible.
6. Freeze survivors to grounded value (`freeze.WorkerRegistry.start_freeze`),
   functional test: scripted double-Space + screenshot height comparison.
   Side effects (can't fall?) -> escalate to `codepatch.escalate_stubborn_value`
   (data BP -> classify -> NOP writer -> unique-sig fingerprint -> restore).
7. Anchor + profile + runbook (follow the Health pattern), restore-test, report.

## Dirty-tree warning

`vision_trainer/*.py` untracked files + `MCP_Server/*` + doc-count bumps are
prior sessions' work (bridge UNIT-25 `get_window_rect`, counts). Do not revert
blindly. Bridge counts must stay in sync across `AGENTS.md`, `CLAUDE.md`,
`README.md`, `AI_Context/MCP_Bridge_Command_Reference.md` when touching tools
(current: 176 tools / 176 cmd_ / 183 dispatcher incl. 7 aliases).
