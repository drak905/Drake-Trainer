# WAND investigation handoff

Prepared 2026-09-07. The user requested a wrap-up for another agent because the current agent's quota is depleted. This is a prepared handoff; no successor agent has been launched.

## Objective and agreed scope

Reverse engineer **WAND's application architecture and trainer workflow**, including an assessment of defenses against reverse engineering. The user selected this scope and authorized starting the investigation. Continue from the completed static milestone; do not repeat broad discovery.

The overall investigation is unfinished. The next runtime milestone needs a selected installed game and trainer feature. The user was asked but has not supplied that choice. Continue independent source analysis if useful while awaiting it.

## Where to resume

Repository: `E:\002. Github\036.Trainer_Check\cheatengine-mcp-bridge`

Branch: `main`; HEAD at wrap-up: `6bd7ce90479250a9b4b75e7944df9c105ecb2572`.

Read in this order:

1. Repository `AGENTS.md` for bridge semantics and safety constraints.
2. [README.md](README.md) for milestone status and outstanding work.
3. [architecture.md](architecture.md), [trainer-workflow.md](trainer-workflow.md), and [ipc-contracts.md](ipc-contracts.md).
4. [native-components.md](native-components.md) and [evidence.md](evidence.md).
5. [Original plan](../WAND_Architecture_Trainer_Reverse_Engineering_Plan.md) and [self-defense assessment](../WAND_Self_Defense_Assessment.md).

Original installed application: `C:\Users\thinh\AppData\Local\Wand\app-12.52.0`.

Preserved analysis: `E:\002. Github\036.Trainer_Check\WAND_Analysis\12.52.0`.

The preserved folder contains `app.asar`, `extracted/`, `trainerlib/`, `auxiliary/`, and `manifest.json`. It is outside Git. These local paths must remain accessible to the successor; a fresh checkout on another machine will not contain them.

## Completed and verified

- Actual MCP stdio initialization and calls through the repository's Python server succeeded. The server exposes 175 tools; the CE bridge reports v12.0.0.
- Identified WAND 12.52.0 as an Electron application with Aurelia renderer services and webpack bundles. `package.json` points to `index.js`.
- Preserved a 54,259,971-byte ASAR copy and 21 trainer/auxiliary files. Extracted 499 selected source/config entries from 822 archive entries. No packaged `.map` files were found.
- Rehashed all 499 extracted files against the generated manifest; verified all 21 native/managed copies against their installed originals and manifest. **520 files, zero mismatches.**
- Mapped startup, renderer ownership, backend selection, host placement, native service startup, feature dispatch, readiness, and teardown in the documents above.
- Decoded the small x64 managed host's IL without executing target code; sampled the x86 entry contract.
- Inventoried auxiliary service metadata: assembly version 12.0.0.0, entry point `5::0`, 698 types with obfuscated identifiers. It has not been fully decompiled.
- Verified Authenticode status `Valid`, signer WeMod LLC, for Wand.exe, TrainerHost_x64.exe, TrainerLib_x64.dll, and WandAuxiliaryService.exe.
- Cross-checked the renderer's published Tophat port against an actual Windows listening socket.

ASAR SHA-256: `2925595f4965627082b99789693d0a233429df1027e3e224ad117690e6be0c52`.

## Findings that matter for the next agent

1. **Trainer orchestration lives in the Node-enabled renderer.** Main handles windows/desktop IPC. Main's window options include `nodeIntegration: true` and `contextIsolation: false`; do not assume every native operation passes through main/preload.
2. **There are two backends.** `trainerlib` uses legacy named pipes; `tophat` uses native plugins and reverse-connected bidirectional gRPC sessions to the renderer. Per-title backend resolution uses a remote response, cached response, default Tophat fallback, and a local non-auto override. Actual title selection has not been observed.
3. **TrainerHost is a lifetime shell.** It receives the game PID and 1000 ms polling interval and waits for game exit. JavaScript injects the actual native runtime into that host when `UseExternalHost` is selected; otherwise it uses the game process. Do not confuse the monitored PID with the parent PID.
4. **Legacy auxiliary framing is asymmetric.** Renderer requests use a 4-byte little-endian JSON length; its service-response parser reads a 4-byte big-endian length. Service-side confirmation remains open.
5. **Two superficially similar value layouts differ.** Legacy JavaScript reads 32-bit request/result fields; Tophat's value event parser reads 64-bit fields. See the protocol tables.
6. **The legacy startup-buffer list begins at byte 1548**, although total allocation is `1552 + 32 * variableCount`. Preserve actual offsets rather than guessing from alignment.
7. **UI state is optimistic.** `setValue` updates the local map and publishes before awaiting native acknowledgement. Validate UI update, protocol result, and game effect separately.
8. **Features can use native values or Lua contracts.** Contract-bound controls call a validated unary method instead of the ordinary value channel.
9. **Native protection evidence is strong; active anti-debugging is unproven.** Trainer DLLs have obscured sections and high-entropy `.boot` entry sections. The auxiliary service has renamed managed identifiers. JavaScript hash/envelope checks are confirmed. Debugger imports, Electron integrity strings, and a `Friday` substring matching `frida` do not prove debugger/tool detection.
10. **The app still contains a DevTools-opening path.** No UI activation of it was tested. No defense bypass is necessary to resume the readable source analysis.

## Runtime state at last observation — refresh before use

| Item | Last observed value |
|---|---|
| CE process | PID 4172 |
| WAND main / CE selected target | PID 16248 |
| Main application renderer / support parent | PID 2060 |
| Other renderer | PID 15916 |
| Auxiliary service | PID 21332, parent 2060 |
| Tophat listener | `127.0.0.1:59371`, owner PID 2060 |
| Tophat registry | `%APPDATA%\Wand\service-ports.json` |
| TrainerHost | None observed |
| CE debugger | `debug_is_debugging: false` |

MCP was rechecked at **22:19 Asia/Bangkok, 2026-09-07**. The temporary MCP probe session closed after verification. No persistent new client configuration was installed. No CE debugger attachment, breakpoints, scans, injection, target writes, game launch, trainer activation, or installed-package edits were performed by this investigation. The listed processes/listener belong to the already running application and were left in place.

## MCP access when tools are not exposed directly

This session did not expose Cheat Engine as named agent tools. Python already has `mcp` and `win32file`, so we used a real MCP client against `MCP_Server/mcp_cheatengine.py`, with pipe transport. Use direct CE MCP tools if the successor has them; otherwise this passive probe works from the repository in PowerShell:

```powershell
@'
import asyncio, os, sys
from datetime import timedelta
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    params = StdioServerParameters(
        command=sys.executable,
        args=['MCP_Server/mcp_cheatengine.py'],
        env=dict(os.environ, CE_MCP_TRANSPORT='pipe', CE_MCP_TIMEOUT='8'))
    async with stdio_client(params) as (reader, writer):
        async with ClientSession(reader, writer,
                read_timeout_seconds=timedelta(seconds=25)) as session:
            await session.initialize()
            for name in ['ping', 'get_opened_process_id', 'debug_is_debugging']:
                result = await session.call_tool(name, {})
                print(name, [c.text for c in result.content if c.type == 'text'])
asyncio.run(main())
'@ | python -
```

Use `get_opened_process_id` for a passive attachment check. `get_process_info` reinitializes symbols. `enum_modules` may fall back to AOB scanning. **Before scans, verify CE Settings → Extra → Query memory region routines is disabled**, as required by the repository. No verification of this setting was made because no scans were used. Preserve existing debugger resources and never clear unrelated breakpoints. Do not run the full integration test suite as a connectivity probe: it is an end-to-end tool exercise.

## Available tooling and limitations

- [snapshot.cjs](tools/snapshot.cjs): validated ASAR extraction and hash-manifest generation. Already run successfully. Uses exclusive output creation; do not rerun into the populated snapshot directory.
- [read-managed-il.ps1](tools/read-managed-il.ps1): Windows PowerShell reflection-only IL reader. Validated on TrainerHost. Use `-MethodPattern` for bounded output; `-ListOnly` on the auxiliary service produces thousands of lines.
- Node, Python, Windows PowerShell, MCP SDK, and pywin32 are available.
- `dotnet.exe` is present, but **no .NET SDK** was found. `ilspycmd`/`ildasm` were not found on PATH. No dependencies were installed for this work.
- The metadata helper preloads referenced assemblies for reflection-only inspection. A raw `GetTypes()` without this preload failed on the auxiliary service; the helper's preload allowed the 698-type inventory.
- No internet research was performed or needed for the first milestone. Consult official technical sources for specific unresolved questions, following available skills when browsing is actually needed.

## Suggested continuation

1. Read this package, confirm the application build and refresh passive process/CE state. Keep using the preserved source snapshot if its hash still matches the build being studied.
2. Obtain the user's game/feature choice for a representative runtime trace. Do not guess a game or activate arbitrary features. The last unanswered question was: “Which installed game and trainer feature should we trace first?”
3. While waiting, map the obfuscated auxiliary command dispatch, Tophat registration/payload schemas, or artifact/native validation boundaries from the existing copies. Static protocol documents identify concrete entry points; avoid another broad scan.
4. For the selected session, record backend, game PID, host PID, artifact identity, loaded modules, launch/ready events, one on/off cycle, and normal cleanup. Establish real game effect separately from optimistic UI state.
5. Use targeted CE reads/tracing only for unresolved native questions, after prerequisites and target identity are established. The packed native implementation and active anti-debug behavior remain open work.
6. Update the existing documents and evidence index with confirmed observations and explicit limits.

## Git ownership and portability

Nothing from this investigation has been committed or pushed. All WAND documents/tools are currently untracked. **A new Git worktree will not automatically receive them.** Give the successor access to this checkout or copy the explicitly scoped investigation files along with access to the external analysis directory.

Files created by this investigation:

- `AI_Context/WAND_Architecture_Trainer_Reverse_Engineering_Plan.md`
- `AI_Context/WAND_Self_Defense_Assessment.md`
- `AI_Context/WAND/` (documents, this handoff, and two tools)

Pre-existing changes to preserve:

- Modified: `AGENTS.md`, `AI_Context/AI_Guide_MCP_Server_Implementation.md`, `AI_Context/MCP_Bridge_Command_Reference.md`, `CLAUDE.md`, `README.md`.
- Untracked: `.commandcode/`, `AI_Context/Cheat_Engine_Agent_Research_and_Method_Catalog.md`.

Do not stage, revert, or overwrite these unrelated changes. No commits, cleanup of user processes, or bulk filesystem cleanup are needed for this handoff.

## Ready-to-paste successor prompt

> Continue the WAND architecture and trainer-workflow investigation. Start by reading `E:\002. Github\036.Trainer_Check\cheatengine-mcp-bridge\AI_Context\WAND\HANDOFF.md`, then follow its evidence/doc links. The first static milestone is complete; do not redo discovery. Work is uncommitted in that checkout, with preserved application copies in `E:\002. Github\036.Trainer_Check\WAND_Analysis\12.52.0`. Preserve unrelated dirty files. Refresh passive CE/process state. The user has not yet selected a game and feature for runtime tracing; ask for that choice while continuing useful local source analysis. Native packed-code behavior, auxiliary dispatch, and active anti-debugging remain unverified. Do not infer that bridge connectivity proves debugger compatibility.
