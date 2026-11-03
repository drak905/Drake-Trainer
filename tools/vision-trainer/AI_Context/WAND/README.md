# WAND reverse engineering: first static milestone

Build inspected: **12.52.0**, 2026-09-07. This milestone maps the local application, trainer orchestration, and IPC contracts. A complete game/trainer session has not yet been exercised.

**Continuing agent:** start with [HANDOFF.md](HANDOFF.md) for session state, access commands, file ownership, and the next steps.

The main findings are:

- The Node-enabled Electron renderer owns trainer orchestration and the local Tophat server. Electron main owns windows and desktop IPC.
- Two backends coexist: legacy `trainerlib` over named pipes, and `tophat` using native plugins and reverse-connected gRPC streams.
- The managed `TrainerHost` is a process-lifetime shell. JavaScript arranges injection of the actual runtime into either this host or the game process, depending on trainer flags.
- Desktop controls and hotkeys converge on the same trainer instance. Features can use the native value channel or a Lua contract method.
- A passive observation confirmed the local Tophat listener in renderer PID 2060. The backend for a particular title is still unobserved.

Documents:

- [Architecture](architecture.md): startup, process ownership, and component map.
- [Trainer workflow](trainer-workflow.md): launch, value updates, errors, and shutdown.
- [IPC contracts](ipc-contracts.md): transports, message layouts, and command names.
- [Native components](native-components.md): managed host behavior and native boundaries.
- [Evidence index](evidence.md): source locations, hashes, tooling, and observation limits.

Analysis copies are retained outside the repository at [WAND_Analysis/12.52.0](../../../WAND_Analysis/12.52.0). That directory contains the original ASAR copy, 499 extracted source/config files, 21 trainer/auxiliary files, and the generated hash manifest. Extracted application source is not added to this repository.

## Remaining work

1. Select one installed game and feature for a normal trainer session. Capture idle, launch, ready, toggle, and stop checkpoints without changing backend settings.
2. Match the session to these static paths, confirm which PID hosts the native runtime, and correlate actual responses with UI state.
3. Trace native initialization and the selected feature inside the protected DLLs only where the source/runtime evidence leaves a concrete gap.
4. Inspect the auxiliary service's obfuscated command dispatch and confirm both endpoints of its framing contract.
5. Investigate active debugger detection separately; the existing CE process selection does not constitute debugger attachment.

No game was launched, no trainer was activated, and no target memory or installed application files were changed in this milestone. WAND's local API, support commands, and bundled diagnostic functions were read as source only, not invoked.
