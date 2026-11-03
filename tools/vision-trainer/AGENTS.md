<!-- bmad:context -->
<!-- Verified 2026-10-02 against 6bd7ce9. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## cheatengine-mcp-bridge

Three-tier bridge letting AI agents drive Cheat Engine over MCP: Python FastMCP server, Lua bridge in CE, optional TCP relay; plus vision_trainer Tkinter app for offline-game 100x adjustment. Python 3.10+, Lua in CE 7.6, MCP SDK pinned. Planning and per-command docs live in AI_Context/, app docs in vision_trainer/README.md and CI.md.

## Policy

- Offline games only; educational scope, never multiplayer or anti-cheat titles.
- Never enable run_command/shell_execute without CE_MCP_ALLOW_SHELL=1; leave unset by default, direct pipe/relay access bypasses the gate and equals host code execution.
- Keep TCP relay on loopback/trusted interfaces only; anyone reaching it controls the bridge.
- vision_trainer PRs state game + build validated in-game and which cheats are proven vs unproven.

## Where things are

- Bridge entry: MCP_Server/mcp_cheatengine.py (176 tools), MCP_Server/ce_mcp_bridge.lua (176 cmd_, 183 dispatcher = 176 + 7 aliases), MCP_Server/ce_tcp_relay.py relay.
- App entry: vision_trainer/main.py; scan_flow.py, anchor.py, freeze.py, codepatch.py, profiles.py, flow.py; tests in vision_trainer/tests/.
- Read AI_Context/MCP_Bridge_Command_Reference.md before touching a tool; never grep the Lua file first. Deeper safety notes in AI_Context/AI_Guide_MCP_Server_Implementation.md.
- When adding/removing a tool keep counts in sync across AGENTS.md, CLAUDE.md, README.md, Command_Reference.md.

## Running and verifying

- Install bridge deps with pip install -r MCP_Server/requirements.txt on Windows pipe, or requirements-tcp.txt for TCP relay (no pywin32); mcp stays >=1.28,<2, v2 removed mcp.server.fastmcp.
- Load Lua with File -> Execute Script -> MCP_Server/ce_mcp_bridge.lua -> Execute, or dofile() path; expect [MCP v12.0.0] MCP Server Listening on: CE_MCP_Bridge_v99; re-executing is safe (StopMCPBridge/cleanupZombieState first).
- Run python MCP_Server/test_mcp.py only with CE running, bridge loaded, process attached; DBVM-gated skips are expected, failures exit non-zero; run lua MCP_Server/test_pointer_parse.lua for the offline UNIT-24 check needing no CE.
- Run app offline gate with python -m pytest vision_trainer/tests/ -q -m "not live" -c vision_trainer/pytest.ini; live gate needs harness + CE + attached offline game: python -m pytest vision_trainer/tests/test_harness_live.py -m live -q.
- Debug the MCP server with python MCP_Server/mcp_cheatengine.py (blocks on stdio); never print to stdout, use debug_log() to stderr only.
- No build, linter, or unit harness for the bridge; single bridge test means editing all_tests in test_mcp.py:main; no Makefile/pyproject/package.json or CI workflows exist.

## Conventions that differ from defaults

- Add a tool in both files with no codegen: cmd_foo in ce_mcp_bridge.lua under UNIT-NN marker plus dispatcher sub-block entry, matching @mcp.tool() foo in mcp_cheatengine.py, then reference section plus count bump.
- Keep handlers global (never local) and UNIT-NN markers mergeable; CE fails past 200 Lua locals.
- Return {success:true,...} or {success:false,error,error_code}; addresses out as hex via toHex, in as string-or-int; list results use offset/limit forming {total,offset,limit,returned}.
- Branch on targetIs64Bit() and use readPointer() for pointer-sized data.
- Run all CE API on main thread via thread.synchronize; worker thread owns blocking pipe I/O only, never spawn CE-touching threads.
- Register every new long-lived resource (HW BP, DBVM watch, scan object, MDL map) in cleanupZombieState so reload tears it down.
- Keep pipe name \\.\pipe\CE_MCP_Bridge_v99 in sync across mcp_cheatengine.py, ce_tcp_relay.py (--pipe overridable), ce_mcp_bridge.lua (bare name), vision_trainer/ce_client.py; _v99 is wire version independent of 12.0.0; select via CE_MCP_TRANSPORT=pipe/tcp (aliases named_pipe/named-pipe/np, socket) at import.
- Never move the top stdio block in mcp_cheatengine.py; it patches both mcp.server.stdio and mcp.server.fastmcp.server stdio_server plus stdout-to-stderr redirect.
- In vision_trainer/: never trust raw addresses under ASLR, resolve via anchor ladder module_offset to signature to pointer_chain; drafts replace wholesale then promote; RUNBOOK appends only on user yes; freeze/patch always restore_on_exit.
- Client config is TOML for Codex ([mcp_servers.cheatengine]) and JSON for Claude Code (cheatengine entry); restart client and verify with ping tool.

## Known pitfalls

- Disable CE Settings -> Extra -> Query memory region routines; enabled scans on DBVM pages cause CLOCK_WATCHDOG_TIMEOUT BSODs, do not weaken without testing.
- Prefer hardware DR0-DR3 via debug_setBreakpoint and DBVM watches over software 0xCC breakpoints.
- get_process_info calls reinitializeSymbolhandler and is not passive; use get_opened_process_id for side-effect-free attach check; its 50-module list can disagree with enum_modules, treat as different views.
- Naive dispatcher grep returns 184 (= cmd_ includes one call-site at aob_scan_module); true count is 183 entries.

<!-- /bmad:context -->
