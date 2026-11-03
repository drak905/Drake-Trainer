# Native and managed component findings

Build: WAND 12.52.0. See [evidence.md](evidence.md) for identities and source references.

## TrainerHost: a managed lifetime shell

The copied x64 host identifies as `TrainerHost, Version=1.0.0.0`, with type `Wand.App.TrainerHost.Program`. Metadata and IL were read through .NET reflection-only loading; the executable was not run (**N1**).

The entry point accepts two arguments: a process ID and positive polling interval. Invalid arguments print `Usage: pwait <pid> <pollMs>` and return 2. Normal completion returns 0; a caught failure reports an error and returns 1.

`WaitForExit` calls `OpenProcess` with access value `0x100000`, wraps a successful handle in `SafeWaitHandle`, and waits on it. If opening returns error 87, the function returns. Error 5 selects a polling fallback, which retries until it can wait on the handle or the process is gone. Other failures become `Win32Exception`. The x86 entry point also begins with the same argument contract.

JavaScript launches the host with the selected game PID and polling interval `1000`. It then injects the native runtime into the resulting PID. The monitored PID is therefore the game PID, not necessarily the host's parent PID. This distinction corrects the initial working assumption that the executable itself contained the trainer engine.

Selected IL anchors in the x64 host:

| Method | IL offset | Evidence |
|---|---|---|
| `Main` | `IL_0017` | Usage string |
| `Main` | `IL_0056` | Calls `WaitForExit(UInt32, Int32)` |
| `WaitForExit` | `IL_0000` | Pushes access value 1048576 |
| `WaitForExit` | `IL_0007` | Calls imported `OpenProcess` |
| `WaitForExit` | `IL_0028` | Calls `WaitHandle.WaitOne()` |
| `WaitForExit` | `IL_004D` | Calls `PollUntilGone` on fallback path |
| `PollUntilGone` | `IL_0053` | Calls `Thread.Sleep(Int32)` |

## Auxiliary service

`WandAuxiliaryService` reports assembly version **12.0.0.0**, entry point **`5::0`**, and **698 types** after reflection-only dependency loading (**N2**). Its names include `0`, `3`, `5`, `a`, and short numeric methods. This is direct evidence of managed identifier obfuscation, although it does not establish a particular obfuscator.

Recognizable imported API names remain, including process/memory/pipe APIs. The JavaScript wrapper and pipe connector provide better initial semantic anchors than these renamed types. Full command-dispatch and service-side packet validation remain to be mapped. No obfuscated method was invoked to decode strings or execute initialization.

## Runtime DLL families

| Component | Role established by client code | Still unverified |
|---|---|---|
| `TrainerLib_<arch>.dll` | Legacy executor injects it and starts export `Run` | Internal loader, feature handlers, and interaction with CELib |
| `CELib_<arch>.dll` | Legacy dependency inventory and permission preparation | Exact runtime callers and functionality |
| `tophat_service_<arch>.dll` | Injected service started through `StartTophatServiceThread` | Packed initialization and native command dispatch |
| `TrainerLibPlugin_<arch>.dll` | Loaded as `trainerlib` before `trainer_run_mod_json` | Native bridge from command to selected trainer DLL |
| `InputCapturePlugin_<arch>.dll` | Loaded after trainer start; `capture_start` requested | Native capture implementation |
| `LuaExecutorPlugin_x64.dll` / `ContractRuntimePlugin_x64.dll` | Required-plugin availability checks and Lua contract load path | Native artifact cryptography and execution semantics |
| `stub/TrainerLib_<arch>.dll` | Legacy module-masking branch references decoy files | Exact native masking behavior and activation by title |

Protected trainer DLL layouts are documented in [WAND_Self_Defense_Assessment.md](../WAND_Self_Defense_Assessment.md). Static source now supplies concrete entry points, commands, and host selection to guide future native tracing. No protected DLL was executed or unpacked by the analysis.

## Signature observations

Windows `Get-AuthenticodeSignature` reported **Valid** with signer **WeMod LLC** for these four inspected files:

- Installed `Wand.exe`.
- Copied `TrainerHost_x64.exe`.
- Copied `TrainerLib_x64.dll`.
- Copied `WandAuxiliaryService.exe`.

This records signature validation on this machine at inspection time. It does not establish runtime self-verification or debugger resistance.

## Next native investigation

First observe which host and backend a selected trainer actually uses. Resolve the relevant DLL base and export from that runtime instance, then follow its initialization/feature path as needed. Keep the auxiliary support protocol, legacy TrainerLib protocol, and Tophat session protocol separate. Their transports and request IDs differ.
