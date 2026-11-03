# Trainer lifecycle and feature dispatch

This is a source-derived walkthrough, not a completed game-session trace. Source labels resolve in [evidence.md](evidence.md).

## Launch

1. **UI entry.** `TrainerPlayButton.launch` checks notes/dialog conditions, uses the selected trainer and installation, warns for an unconfirmed supported-version match when applicable, and calls `trainerService.launch(new ...(...))` with trainer metadata, installation, version, and trigger (**S11**).
2. **Single active trainer.** The trainer service rejects a concurrent launch, creates cancellation state, and asks the trainer factory to construct the instance. The factory resolves the backend through the remote/cache/settings decision described in [architecture.md](architecture.md) (**S5**, **S6**, **S9**).
3. **Acquire artifacts.** Loader types include `trainerlib`, `trainerlib-local`, and `artifacts`. The artifact path obtains the trainer DLL and, for Tophat, required Lua artifacts; availability metadata can disable Lua artifacts. Download hash and descriptor checks apply as documented in the [self-defense assessment](../WAND_Self_Defense_Assessment.md) (**S7**, **S13**).
4. **Read binary architecture and check dependencies.** The state machine loads the trainer DLL's PE metadata and distinguishes AMD64 from the `ia32` branch. It checks the internal trainer DLL inventory before finding a game process (**S9**).
5. **Find or launch the game.** The process service resolves the installation path, builds an image/path matcher, applies process selection rules, and searches existing processes. It can use an existing match, require an internal launch, or require an already running game. Defaults in this path include an 8-second process minimum age and 45-second launch timeout. Actual per-title configuration can override these (**S4**).
6. **Validate architecture and choose host.** A trainer/game architecture mismatch rejects the launch. `UseExternalHost` creates the managed host; otherwise the game is the runtime host (**S6**, **S9**, **N1**).
7. **Execute the selected backend.** Follow the legacy or Tophat branch below.
8. **Wait for readiness.** The service supplies a 45-second connection timeout and 90-second load timeout. Readiness, failure events, cancellation, and disconnection race one another. If process suspension was requested, configured resumption follows readiness. The before-activation hook then loads required Lua contracts for Tophat and validates their bindings (**S6**, **S9**).
9. **Publish Active.** The instance marks launch success and publishes `activated`, enabling subscribed control, hotkey, and other consumers. Merely obtaining a transport connection is earlier than this state.

The state enum in module `13392` is:

`AwaitingLaunch → AcquiringBinary → EnsuringBinaryAccess → CheckingInternalBinaries → FindingProcess → ValidatingProcess → [CreatingTrainerHost] → Injecting → InitializingIpc → Executing → [Connecting] → Activating → Active → [Detaching] → Ended`

Square brackets indicate backend-dependent or optional states. This is enum order; callbacks and individual executors determine the transitions actually taken. The transition setter rejects non-increasing state numbers.

## Legacy trainerlib branch

The executor prepares the target process, injects the architecture-specific `TrainerLib` into the chosen host, creates trainer message/log pipes, and requests a remote call to the DLL's `Run` export. The startup argument buffer contains the trainer DLL path, target PID, game version, variable names, flags, and pipe names (**S6**, **S8**).

Flags include separate paths for external hosting, process suspension/resumption, module masking, and thread handling. Their presence describes WAND's interaction with its target/host; it does not demonstrate that WAND detects analysis of itself. No flag path was exercised.

The legacy channel handles loading/ready notifications, named numeric values, acknowledgements, buffer messages, and log records. See [ipc-contracts.md](ipc-contracts.md) for layouts.

## Tophat branch

The executor selects architecture-specific service/plugin paths, resolves the runtime host, and checks for completion of an earlier teardown. It then prepares the process and requests injection of `tophat_service_<arch>.dll` through the auxiliary service (**S7**).

It calls `StartTophatServiceThread` with a NUL-terminated UTF-8 JSON argument containing `wandPort`, `clientId`, and optionally `dumpBaseDir`. The native service connects back to the renderer's loopback server. The renderer waits for the generated client ID, watching for game/host exit and timeout.

Once connected, the trainer client:

1. Loads the `trainerlib` plugin from `TrainerLibPlugin_<arch>.dll`.
2. Sends `trainer_run_mod_json` containing `processId`, `gameVersion`, `trainerDllPath`, and `initialVars`.
3. Processes `trainer_initializing` and `trainer_ready` events.
4. Separately attempts to load the input-capture plugin and start capture; that promise chain logs failures rather than defining the trainer-ready event.

The x64 Lua/contract plugin availability is checked separately. After trainer readiness, required contracts are registered and their method/request-field bindings validated before the overall trainer becomes Active (**S6**, **S7**, **S12**).

## Toggle and feedback path

Desktop `handleToggleChange` calls the active instance's `setValue(target, value, source, cheatUuid)`; numeric, selection, and button handlers converge on the same method. The hotkey controller also calls it with the Hotkey source (**S5**, **S14**).

The instance converts booleans to 0/1, rejects unknown variable names, updates its local value map, and publishes a value event before awaiting the backend. The UI therefore performs an optimistic state update; the first visual change is not proof of a native acknowledgement (**S9**).

There are two dispatch routes:

- Without a contract binding: legacy sends a binary Value request; Tophat sends `trainer_push_client_req_from_json` with a request ID, name, and value, then waits for `trainer_value_response` (**S6**, **S12**).
- With a contract binding: the instance finds the registered Lua contract and invokes its named unary method with `{[argField]: value}`. Missing contracts and invalid bindings have explicit failure paths (**S6**, **S9**).

Result values are `OK=0`, `Changed=1`, and `Error=2`. Backend-originated value events can update the UI independently. Failed value sets publish `value-error`; the trainer service exposes these to higher-level consumers. A controlled trace should correlate the request, response/event, UI update, and game effect separately.

## Stop and cleanup

`endTrainer()` cancels a pending launch or disposes the active instance and waits for `ended` (**S6**).

For Tophat, the disposal path unloads registered Lua contracts, stops the trainer, unloads the trainerlib plugin, requests session shutdown, and closes the connection. The data-channel shutdown stages each have a 5-second bound. The trainer instance then waits up to 30 seconds for `Local\TophatService_TeardownComplete_<hostPID>` and checks the stalled event (**S3**, **S7**, **S9**, **S12**).

The source contains a conditional diagnostic capture path when teardown fails while the host remains alive. The collection policy is separate; the existence of that path does not mean a capture was made. External-host disposal is scheduled after the final state, with different delay values based on target liveness. The managed host also independently exits when the monitored game exits.

## What the first runtime trace must establish

Record the selected title, installation/build, feature, artifact identity, backend resolution, game PID, host PID, loaded modules, and actual transport. Trace one on/off cycle through the relevant dispatch route and a normal stop. Avoid assuming a global backend or a universal native implementation from this static map.
