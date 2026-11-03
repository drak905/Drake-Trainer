# WAND self-defense assessment

Checked 2026-09-07 against the installed WAND **12.52.0** application. This is a preliminary static assessment plus passive MCP connectivity/debugger-state checks.

## Finding

**There is strong evidence of protection against static inspection of native trainer components, and confirmed artifact-integrity validation in the JavaScript layer. Active anti-debugging or anti-Cheat-Engine behavior is not established.**

| Mechanism | Assessment | Evidence and limits |
|---|---|---|
| Native packing/obfuscation | Strong evidence | Trainer DLLs have mostly blank section names, `.wemod` and `.boot` sections, and high-entropy data. Three sampled x64 DLLs enter inside `.boot`. The exact packer, transformation, and runtime behavior are unknown. |
| Trainer download integrity | Confirmed in code | Downloaded trainer DLL bytes are SHA-256 hashed; a mismatch against metadata rejects the download and removes its temporary file. This does not establish continuous checking of already cached DLLs. |
| Lua descriptor integrity | Confirmed in code | Decoded contract descriptors are SHA-256 checked against `contractDescriptorHash`; missing or mismatched descriptors produce `LuaArtifactInvalid`. |
| Lua artifact envelope | Confirmed format validation | `WLC1` magic/version and length constraints are checked. A `signedLua` value is passed to the native contract path. Signature enforcement, encryption algorithm, and key handling have not been verified. |
| JavaScript analysis friction | Observed | Bundled/minified JavaScript; no `.map` files in the 822-entry ASAR inventory. The code remains readable enough to follow handlers and validation. This is not proof of deliberate anti-debugging. |
| DevTools blocking | Not established; contrary code evidence | A renderer keyboard handler sends `ACTION_OPEN_DEV_TOOLS` on Ctrl+Shift+D; the main process registers it to call `webContents.openDevTools`. Actual UI activation was not tested. |
| Native debugger detection | Candidate APIs only | `Wand.exe` imports `IsDebuggerPresent` and `CheckRemoteDebuggerPresent`; overlay binaries import `IsDebuggerPresent`. Their call sites and responses have not been traced. |
| ASAR self-integrity enforcement | Unverified | `Wand.exe` contains Electron ASAR integrity-check diagnostics. Presence of support code does not establish that validation is enabled for this application. |
| Process/tool blacklist or forced termination | Not demonstrated | Targeted JavaScript searches found no matching debugger/tool-blacklist patterns. Packed native code remains a blind spot. |

## Native evidence

Files are relative to `C:\Users\thinh\AppData\Local\Wand\app-12.52.0\resources\app.asar.unpacked\static\unpacked\trainerlib`.

| File | Entry RVA | Entry section | `.boot` raw size | `.boot` entropy, bits/byte |
|---|---|---|---:|---:|
| `TrainerLib_x64.dll` | `0x560058` | `.boot` | 2,851,328 | 7.95 |
| `CELib_x64.dll` | `0x3FB058` | `.boot` | 2,203,136 | 7.95 |
| `tophat_service_x64.dll` | `0x1146058` | `.boot` | 2,648,576 | 7.92 |

Large sections earlier in these files also have high entropy, including approximately 7.98 in TrainerLib and 7.99 in tophat_service. Each has a `.wemod` section with zero raw bytes. This combination supports packing or obfuscation more strongly than a section name alone. Entropy cannot distinguish compression from encryption or establish virtualized code.

The same blank-section/`.wemod`/`.boot` layout occurs in the inspected x86/x64 `ContractRuntimePlugin`, `InputCapturePlugin`, and `TrainerLibPlugin`, as well as `LuaExecutorPlugin_x64.dll`. No identification of VMProtect, Themida, or another named protector was established.

PE metadata identifies `TrainerHost_x64.exe`, `TrainerHost_x86.exe`, `WandAuxiliaryService.exe`, and `GameLauncher.exe` as having CLR headers. These are useful managed-code analysis entry points. Their PE machine type alone does not resolve managed AnyCPU/runtime behavior.

`Wand.exe` differs: its entry point is in `.text`, with `.text` entropy approximately 6.54. It also has `LZMADEC` and `prot` section names, but these names alone do not establish an anti-analysis mechanism; the sampled `prot` raw section was all zero bytes.

## JavaScript evidence locations

Locations below refer to original files inside `resources\app.asar`. Offsets are zero-based JavaScript string indices in the decoded file, not PE addresses or archive byte offsets.

- **Download hash verification:** `app-561cdd0d.b911e168300d942c9bbf.bundle.js`, webpack module `11131`. SHA-256 creation appears around offset 711. The close handler compares the computed digest with `e.hash`, removes the temporary file on mismatch, and reports `Downloaded trainer failed hash verification`. Its `fetchBinary` path returns an existing cache file after an existence check; this function does not rehash that cache hit.
- **Lua envelope validation:** the same bundle, webpack module `63190`. The predicate checks minimum size 284, magic `WLC1`, version 1, and a positive length divisible by 16 whose value plus 268 equals the envelope length. This proves structure validation, not cryptographic verification.
- **Descriptor hash:** `app-696eada4.8ab3ed671521c38230ed.bundle.js`, webpack module `64060`, around offset 14107. The decoded base64 descriptor's SHA-256 must match metadata or the loader throws `LuaArtifactInvalid`.
- **Native signed-Lua handoff:** `app-aec23333.f5f9d4a34668734033a8.bundle.js`, around offset 14303. The code hashes `signedLua` and calls `registerLuaContract`; the receiver's verification remains to be analyzed.
- **DevTools keyboard path:** `app-295a36df.f22a794493056351b725.bundle.js`, around offset 1786. Ctrl+Shift+D sends `ACTION_OPEN_DEV_TOOLS`.
- **DevTools handler:** `index.js`, around offset 59253, registers that action; around offset 67610, `openDevTools()` invokes `qe?.webContents.openDevTools({mode:"detach"})`. IPC registration around offset 4632 restricts requests to the corresponding window sender. No developer-mode condition surrounds the quoted action registration or helper; upstream/runtime availability was not exercised.

All 477 top-level JavaScript files were checked with targeted patterns for anti-debug terms, `debugger;`, debugger-detected messages, `devtools-opened`, explicit `devtools: false`/`!1`, disabled DevTools flags, selected debugger-detection API names, and selected analysis-tool names. No matches were found for that specific pattern set. This is a bounded text-search result, not a proof that detection is absent.

## False positives and limits

- The `anti-tamper` message in `app-366d4320.191373ab540e77dfeb72.bundle.js` describes possible interference in a host during DLL injection. It does not establish WAND defending itself.
- The sampled `frida` hits in `Wand.exe` and `overlay_addon.node` are substrings of **Friday** in date strings.
- A sampled `tampered` hit in `Wand.exe` belongs to embedded source-map handling code discussing modified JavaScript prototypes.
- `Integrity check failed for asar archive` appears with an Electron source path in `Wand.exe`; enablement is unverified.
- `NtSetInformationThread` appears near process-mitigation code strings. No `ThreadHideFromDebugger` argument or anti-debug response was established.
- Ordinary import-table and readable-string searches cannot exclude dynamically resolved APIs, inline debugger checks, timing checks, TLS initialization checks, or logic hidden by packing. The native import review was not a full disassembly or delay-import/call-graph analysis.

At 21:57 local time, MCP `ping` succeeded, `get_opened_process_id` returned **16248**, and `debug_is_debugging` returned **false**. This establishes bridge availability and CE's selected process, not successful debugger attachment or unrestricted memory access. No breakpoints, injection, scans, memory writes, package changes, or defense bypasses were performed.

## Effect on the architecture investigation

Follow-up static work found managed identifier obfuscation in `WandAuxiliaryService.exe`: assembly version 12.0.0.0, entry point `5::0`, and many short renamed types/methods. The small `TrainerHost` retains readable names and was inspected through reflection-only IL. See [native-components.md](WAND/native-components.md). These findings strengthen the distinction between component-specific analysis obstacles and unverified active debugger blocking.

1. Start with readable JavaScript and managed hosts to map the trainer lifecycle and locate native boundaries.
2. Record artifact validation and the native protection boundary in the IPC/lifecycle diagrams. Distinguish download checks, cache checks, descriptor checks, and native signature enforcement.
3. Inspect native exports and initialization paths to determine what the `.boot` entry does. Compare observed runtime module layout with disk metadata only when that specific step is needed and the repository's scan prerequisites are satisfied.
4. To answer active anti-debugging conclusively, design a separate controlled debugger-attachment experiment with baseline observations, existing-breakpoint preservation, and exit/crash monitoring. Test the main process and trainer runtime separately; a result for one does not establish behavior for the other.
5. Follow the actual call sites of debugger-related APIs and the native `registerLuaContract` receiver before attributing detection or signature enforcement to them. Do not assume a protection brand or bypass requirement.

## Evidence identities

SHA-256 hashes pin these findings to the inspected build:

| File | SHA-256 |
|---|---|
| `resources/app.asar` | `2925595f4965627082b99789693d0a233429df1027e3e224ad117690e6be0c52` |
| `Wand.exe` | `af9317cee5089f3c6c8177827461698775981238dc123c90cbcfe5f54d063d63` |
| `TrainerLib_x64.dll` | `43c5323f97ce71d797c86f605b8eff26cd713d00ffc33d939fbbc99e15efbb4c` |
| `CELib_x64.dll` | `f457972222720554d7fb6eb928751964c492a6edac739d2b2a106e35e66243c7` |
| `tophat_service_x64.dll` | `ba7d48fea5e5aa3b6d6111bb24b3f739c5279cd3bfa9a0b48ed86da2f6b474df` |
