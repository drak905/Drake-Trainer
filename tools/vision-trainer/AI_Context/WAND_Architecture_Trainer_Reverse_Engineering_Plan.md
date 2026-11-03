# WAND application architecture and trainer workflow: reverse-engineering plan

Prepared 2026-09-07 (Asia/Bangkok). Scope selected by the user: application architecture and trainer workflow.

## Verified baseline

- An actual MCP client initialized the repository's `MCP_Server/mcp_cheatengine.py` over stdio and enumerated **175 tools**. Its `ping` call reached the named-pipe Lua bridge and returned `success: true`, bridge version **12.0.0**.
- `get_opened_process_id` returned **16248**, matching the running WAND main process. No target switch was necessary. The temporary MCP verification session closed after its checks; no client configuration was changed.
- Installed application: `C:\Users\thinh\AppData\Local\Wand\app-12.52.0\Wand.exe`. Executable metadata identifies version **12.52.0**, product **Wand**, company **WeMod**.
- `resources\app.asar` is 54,259,971 bytes. Reading its archive header and packaged `package.json` confirmed `name: Wand`, `version: 12.52.0`, and entry point **`index.js`**. The archive contains many JavaScript bundles and chunks. Source-map availability has not yet been checked.
- Chromium process flags and the ASAR application path support an Electron architecture. The precise Electron version remains unverified.
- Inspection so far was limited to MCP connectivity, attachment identity, process metadata, package metadata, and installed-file inventory. No memory scans, breakpoints, injection, trainer activation, or target-memory writes were performed.

Observed processes (PIDs are session-specific and must be refreshed):

| Component | PID | Parent PID | Evidence |
|---|---:|---:|---|
| WAND main process | 16248 | 14536 | Main window titled Wand; no child `--type` flag |
| GPU process | 19196 | 16248 | `--type=gpu-process` |
| Network utility | 14752 | 16248 | `--utility-sub-type=network.mojom.NetworkService` |
| Renderer | 2060 | 16248 | `--type=renderer`; parent of auxiliary service |
| Renderer | 15916 | 16248 | `--type=renderer` |
| WandAuxiliaryService.exe | 21332 | 2060 | Executable in `static\unpacked\auxiliary` |

Installed native components under `resources\app.asar.unpacked\static\unpacked`:

- `auxiliary`: `WandAuxiliaryService.exe`, `GameLauncher.exe`.
- `trainerlib`: x86/x64 variants of `TrainerHost.exe`, `TrainerLib.dll`, `TrainerLibPlugin.dll`, `CELib.dll`, `ContractRuntimePlugin.dll`, `InputCapturePlugin.dll`, and `tophat_service.dll`; also `LuaExecutorPlugin_x64.dll` and a `stub` directory.
- `overlay`: `overlay_addon.node`, `overlay_game.dll`, `overlay_game_x64.dll`.
- `capture`: `capture_addon.node` and supporting capture libraries.

No process whose name began with `TrainerHost` was observed. File presence establishes investigation targets, not proof that a particular component participates in every trainer session.

## Objective and completion criteria

Explain one representative trainer session from game selection through launch, feature toggle, feedback, and shutdown. Identify the responsible JavaScript modules, process boundaries, message formats, and native entry points. Each claimed connection must cite a packaged-code location or a repeatable runtime observation.

Completion requires an architecture map, a trainer lifecycle sequence, an IPC contract table, a native component map, and a repeatable walkthrough. Mark unresolved behavior explicitly, including anything supplied by remote services that local evidence cannot establish.

## Follow-up: self-defense assessment

The user additionally requested an assessment of defenses against reverse engineering. See [WAND_Self_Defense_Assessment.md](WAND_Self_Defense_Assessment.md) for the inspected-build evidence and limitations.

The follow-up found strong native packing/obfuscation indicators, confirmed trainer-download and Lua-descriptor hash validation, and a Lua artifact envelope-validation path. Active debugger detection remains unverified. The packaged code retains a DevTools-opening path; no `.map` files were found in the ASAR inventory. PE inspection also identified CLR headers in the trainer hosts and auxiliary executables.

Adjust Phases 2–5 to start with the readable JavaScript and managed hosts, document the artifact-validation boundaries, and trace native initialization at the packed DLL boundary. Treat controlled debugger-attachment testing as a separate runtime experiment; MCP connectivity by itself does not establish debugger compatibility.

## Phase 1 — Preserve and index the installed application

1. Record hashes, file versions, PE architecture, and signatures for the executable, ASAR archive, trainer hosts, and relevant DLLs. Work from copies in a dedicated analysis directory and retain the installed originals.
2. Extract the ASAR copy with path validation; preserve original bundle names. Locate `index.js`, preload scripts, renderer entry points, webpack module/chunk mappings, and any source maps. Keep formatted copies separate from original evidence.
3. Classify native files by PE metadata, imports, exports, and CLR presence. Select managed decompilation or native disassembly from that evidence; filenames alone do not establish the runtime.
4. Inventory application-specific log and cache locations referenced by the code. Collect only records relevant to the selected workflow and redact account tokens from notes.

Deliverable: file manifest and an entry-point index linking component roles to exact files.

## Phase 2 — Reconstruct the application boundaries

1. Follow startup from `index.js`: window creation, preload configuration, renderer loading, service startup, and shutdown handlers.
2. Locate Electron IPC registration and invocation sites, native-addon loads, child-process launches, and local socket/pipe setup. Search for the observed native filenames to locate their actual callers.
3. Separate UI state, catalog/game discovery, trainer coordination, native services, overlay, and capture responsibilities. Treat the network utility as a transport component until code establishes its application-level role.
4. Build an IPC table with sender, receiver, channel/operation name, request fields, response/event fields, error behavior, and evidence location. The auxiliary service's command line contains a `Wand\Support_..._Out` argument; investigate its meaning without assuming it is the trainer protocol.

Deliverable: verified process/component diagram and IPC contract table. Keep hypotheses separate from observed edges.

## Phase 3 — Trace trainer orchestration in packaged code

Follow these candidate stages, adjusting the sequence to match the implementation:

1. Game selection and installed-game discovery.
2. Game executable/build identification and compatible trainer selection.
3. Trainer metadata/artifact lookup, local caching, and any validation performed by the client.
4. Game launch or discovery of an existing process.
5. Architecture selection and creation of a trainer host or equivalent runtime.
6. Runtime initialization, connection establishment, and ready/error notification.
7. UI toggle or hotkey to trainer operation, value update, and UI acknowledgement.
8. Stop, game exit, crash handling, and cleanup.

For each stage, record its controlling function/module, inputs, outputs, side effects, and failure transitions. Determine the roles of `TrainerLib`, `CELib`, and the plugin family through callers and exports. Their names are leads, not established semantics.

Deliverable: a lifecycle sequence and state-transition table with code references, including the selected toggle's complete caller chain.

## Phase 4 — Validate one representative session at runtime

Prerequisite: select an installed supported game and one observable feature. This game/feature choice is still open. Use a reproducible local session with a known starting state.

1. Capture idle, game-selected, launch-requested, trainer-ready, feature-on, feature-off, and stopped checkpoints. Record timestamps, PIDs/parent PIDs, module changes, relevant log events, and visible state.
2. Correlate new trainer-host processes and loaded libraries with Phase 3's launch code. Establish where trainer logic executes: a host, WAND, the game, or a combination.
3. Check each proposed IPC edge against both endpoints and normal workflow observations. Start with existing logs and code; use narrowly targeted instrumentation only where those leave a specific question unresolved.
4. Repeat the toggle and stop sequence to distinguish causal behavior from unrelated background events.

Cheat Engine MCP strategy:

- Start each connection with `ping` and `get_opened_process_id`. Revalidate identity before using addresses or switching targets with `open_process`.
- Preserve a record of existing debugger/breakpoint state using `debug_is_debugging` and `list_breakpoints` before any tracing. Opening a process and attaching a debugger are distinct actions.
- Use `enum_modules` with pagination for module evidence once scan prerequisites are satisfied: its fallback can perform AOB scans. Avoid `get_process_info` for passive checks because it reinitializes symbols.
- Resolve a concrete code target from static analysis before using `disassemble`, `find_references`, or `find_call_references`. Use small, bounded reads for relevant structures.
- Where necessary, trace selected native boundaries with hardware `set_breakpoint`/`set_data_breakpoint` and collect bounded `get_breakpoint_hits`. Account for existing DR0–DR3 usage; remove only breakpoints created for this investigation.
- Use `analyze_pointer_access` and `validate_pointer_chains` only if a persistent native structure is necessary to explain the workflow. JavaScript object addresses require separate care because the runtime can move objects.
- Confirm CE Settings → Extra → **Query memory region routines is disabled before memory scans**, as required by this repository. Kernel/DBVM operations are not needed for the initial architecture investigation.
- Keep addresses as module plus offset alongside the observed absolute address, target architecture, and binary hash. A reloaded process invalidates prior absolute addresses.

Deliverable: timestamped evidence for one complete trainer lifecycle, with discrepancies fed back into the architecture map.

## Phase 5 — Explain the native execution boundary

1. Starting from the confirmed trainer-host launch and IPC handlers, follow native initialization, plugin loading, target-process selection, and feature dispatch.
2. Identify whether a feature reaches memory access, injected execution, script execution, or another mechanism. Establish this separately for each inspected path; do not generalize from bundled DLL names.
3. Record the message-to-function mapping, value types, status/error propagation, and resource ownership. Include how shutdown releases handles, threads, hooks, or other resources actually observed.
4. Validate normal stop and game-exit cleanup. Investigate launch failure or unsupported-build handling using existing code/log evidence before designing additional experiments.

Deliverable: native call-path notes and an annotated IPC-to-runtime map. Any code or memory modifications would be a separate implementation task beyond this planning request.

## Final deliverables and order

Execute Phases 1–3 first, then choose the representative game/feature for Phases 4–5. Prioritize the UI-to-trainer path; inspect overlay/capture only when the selected path depends on them.

- `architecture.md`: process ownership, component responsibilities, and evidence-backed connections.
- `trainer-workflow.md`: launch/toggle/stop sequence, states, errors, and cleanup.
- `ipc-contracts.md`: channels, operation names, field types, acknowledgements, and callers.
- `native-components.md`: binary identities, architectures, relevant exports, and verified roles.
- `evidence/`: manifest, code locations, bounded runtime observations, and reproduction steps.

The first static milestone is now recorded in [WAND/README.md](WAND/README.md), with architecture, lifecycle, IPC, native-component, and evidence documents. It includes an archive/native snapshot, source inspection, managed host IL analysis, and a passive check of the renderer's local Tophat listener. Phases 1–3 have an initial evidence-backed map; the auxiliary service's obfuscated implementation, full artifact/native internals, and the representative runtime trace remain unfinished. The historical baseline above describes the earlier plan-preparation checks.
