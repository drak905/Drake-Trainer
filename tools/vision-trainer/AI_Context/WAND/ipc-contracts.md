# IPC contracts recovered from local code

These contracts were read from WAND 12.52.0 source. No application commands or protocol messages were sent. Byte offsets below are packet offsets; source labels resolve in [evidence.md](evidence.md).

## Electron main ↔ renderer

Window handlers register through `ipcMain.handle`/`ipcMain.on` and check the sender's webContents ID. The renderer uses Electron IPC for desktop operations. One verified example is `ACTION_OPEN_DEV_TOOLS`, dispatched to `webContents.openDevTools` (**S1**).

Trainer operations are largely driven directly by Node-capable renderer services. They do not all pass through Electron main.

## Renderer ↔ auxiliary service

**S3**, module `51612`, creates two pipe servers:

- `\\.\pipe\Wand\Support_<timestamp>_Out`: the service initially connects here; JavaScript sends a four-byte little-endian byte length plus the UTF-8 bare `_In` pipe name.
- `\\.\pipe\Wand\Support_<timestamp>_In`: the service opens the second connection, after which the renderer receives results/events here.

The task protocol implemented by `native/support/index` is asymmetric:

| Direction | Framing visible in JavaScript | Body |
|---|---|---|
| Renderer → service | `writeUInt32LE(length)` + UTF-8 JSON | `{id, command, data}` |
| Service → renderer | `readInt32BE(length)` + UTF-8 JSON | `{id, status, data}` |

Response status: Success `1`, Error `2`, Event `4`, RequiresElevation `5`. Event payloads contain `{event, data}`. Requests use incrementing numeric IDs matched to pending promises. The service-side implementation of these bytes is still to be verified; the table reflects the shipped JavaScript serializer/parser.

Selected wrapper contracts in module `71010`:

| Command | Request data | Role in trainer workflow |
|---|---|---|
| `GetProcesses` | `{argsFilter}` | Discover target candidates |
| `InjectDll` | `{processId, dllPath, stackSize, timeout}` | Load runtime in host |
| `CreateRemoteThread` | `{processId, module, export, arg, proxy}` | Start a runtime export; `arg` is base64 or null |
| `WaitForInputIdle` | `{processId, timeout}` | Prepare target |
| `WaitForEvent` | `{name, timeoutMs}` | Coordinate native teardown |
| `GrantFilePermission` | `{file, sids, permissions}` | Make runtime artifacts accessible |
| `SuspendProcess` / `ResumeProcess` | `{processId}` | Optional preparation/resumption |

This is a selected inventory, not a reproduction client or an exhaustive command reference.

## Legacy trainer channel

**S6**, module `20899`, creates `\\.\pipe\WeMod\Trainer_<timestamp>_In`, `_Out`, and usually `_Log`. The injected runtime connects to `_Out` and is sent the `_In` path as UTF-16LE. Fixed-layout packets then carry values and lifecycle messages. These packets do not use the auxiliary service's JSON framing.

| Type | Numeric tag | Total bytes | Relevant layout |
|---|---:|---:|---|
| Loading | 0 | 8 | Tag read as UInt32LE at 0 |
| Ready | 1 | 8 | Tag read as UInt32LE at 0 |
| Value | 2 | 56 | ID written/read as UInt32LE at 8 by legacy JS; ASCII name at 16, 32-byte field; DoubleLE value at 48 |
| ValueResponse | 3 | 24 | UInt32LE ID at 8 and result at 16 in legacy JS |
| Buffer | 4 | 48 + payload length | ASCII type at 8, 32-byte field; UInt32LE payload length at 40; payload at 48 |

Outgoing buffers are zero-initialized. Incoming data is accumulated until a whole packet is available; the parser retains partial trailing data. Logging uses a 16-byte header: level at 0, UInt32LE message byte length at 8, UTF-16LE text at 16.

Startup buffer passed to `TrainerLib!Run`, module `59455`:

| Offset | Field |
|---:|---|
| 0 | Log pipe, UTF-16LE, 512-byte field |
| 512 | Message pipe, UTF-16LE, 256-byte field |
| 768 | UInt32LE flags |
| 772 | 252 bytes reserved/zero-filled |
| 1024 | Trainer DLL path, UTF-16LE, 512-byte field |
| 1536 | UInt32LE target PID |
| 1540 | UInt32LE game version |
| 1544 | UInt32LE variable count |
| 1548 | First 32-byte ASCII variable field; subsequent fields follow every 32 bytes |

The allocation is `1552 + 32 * variableCount` bytes. The variable list begins at 1548 according to the actual increments in code, leaving four extra allocated bytes at the end. Preserve that distinction when comparing against a native structure definition; do not silently round the variable offset to 1552.

## Tophat session and trainer commands

**S7**, **S10**, and **S12** establish this direction: native service connects to a loopback gRPC server hosted in WAND's renderer. It supports bidirectional routes:

- `/tophat.TophatService/Session`
- `/tophat.TophatService/TelemetrySession`
- `/tophat.TophatService/EventsSession`

Source includes client/session metadata keys `x-tophat-client-id` and `x-tophat-session-id`, raw Buffer request/response serialization, and library-specific payload schemas. Exact registration validation and the complete binary schema are not yet mapped. Do not assume every payload is conventional generated protobuf.

The native startup export is `StartTophatServiceThread`. Its argument is NUL-terminated UTF-8 JSON: `{wandPort, clientId, dumpBaseDir?}`. The desktop publishes `{pid, service, port, target, started}` in `service-ports.json`.

| Stage | Library operation/command | Important fields or output |
|---|---|---|
| Load trainer plugin | `loadPlugin("trainerlib", pluginDllPath)` | Returns plugin handle |
| Start trainer | `trainer_run_mod_json` | `{processId, gameVersion, trainerDllPath, initialVars}` |
| Observe lifecycle | Stream events | `trainer_initializing`, `trainer_ready`, `trainer_status`, `trainer_log` |
| Set value | `trainer_push_client_req_from_json` | `{requestId, name, value}` |
| Complete value request | `trainer_value_response` | Parsed ID/result resolves tracked request |
| Receive native value | `trainer_value_request` | Parsed name/value published to trainer instance |
| Buffer message | `trainer_push_buffer_message` / `buffer_message` | Named binary payload |
| Stop | `trainer_stop_mod`, then `unloadPlugin(handle)` | Cleanup before disconnect |

Tophat's value event decoders use UInt64LE request IDs at offset 8, and UInt64LE result at 16 for the 24-byte response. The 56-byte value request contains a 32-byte name at 16 and Float64LE at 48. This resembles the legacy layout but its JavaScript decoder reads 64-bit fields, whereas the legacy parser reads 32-bit fields. The protocol distinction must be preserved.

## Lua contracts

Required artifacts carry a contract identifier and either a descriptor set or local source metadata. The client registers the artifact through the contract runtime, checks that descriptor package and declared contract agree, and permits bound feature methods with one supported scalar/enum request field (**S6**, **S9**).

An ordinary contract-bound feature invokes the named unary method with `{[argField]: value}`. Native signature checking and the full contract-runtime wire schema remain open work.
