# Evidence and reproduction index

Inspection date: 2026-09-07. Installed build: `C:\Users\thinh\AppData\Local\Wand\app-12.52.0`.

## Preserved data

Analysis root: [WAND_Analysis/12.52.0](../../../WAND_Analysis/12.52.0).

- `app.asar`: original archive copy, **54,259,971 bytes**.
- `extracted/`: **499** JavaScript/JSON/HTML or other selected source entries extracted from an **822-entry** archive inventory. No `.map` files were present in that inventory.
- `trainerlib/` and `auxiliary/`: **21** copied files, including both trainer hosts, runtime DLLs, stub DLLs, auxiliary service, and its packaged managed dependencies.
- [manifest.json](../../../WAND_Analysis/12.52.0/manifest.json): inventory, extracted-file hashes and archive byte offsets, and copied-binary hashes.

Archive SHA-256: `2925595f4965627082b99789693d0a233429df1027e3e224ad117690e6be0c52`, matching the earlier self-defense assessment.

Verification rehashed all 499 extracted files against the manifest and all 21 copied binaries against both the manifest and their installed originals: **520 files checked, zero mismatches**. Documentation links and the snapshot script's Node syntax check also passed. The managed IL helper successfully decoded the x64 host's wait method and the x86 entry-point sample.

The analysis tooling reads source and metadata. It does not import or evaluate WAND's JavaScript modules or invoke the managed application methods.

## Source labels

All JavaScript filenames below are original ASAR entry names, retained in `extracted/`. Numeric IDs refer to webpack module definitions in the named bundle, not to a runtime process or an address. Character offsets are zero-based positions in the decoded JavaScript string; use the named function/module as the primary anchor.

| Label | Source | Anchors |
|---|---|---|
| S1 | `index.js` | Window preferences ~3629; window IPC registration ~4632; app startup ~52600; main `run()` ~53490; app channel registration ~56998 |
| S2 | `app-84781932.cdc790a001001fb1a767.bundle.js` | Aurelia feature configuration ~37200–39200; native support/trainer storage configuration ~38400 |
| S3 | `app-bba7c3ce.78268bcc3501f013f211.bundle.js` | Modules `15600` (teardown events), `51612` (support startup), `71010` (native wrapper), and `native/support/index` (task framing/status) |
| S4 | `app-7a140d57.5e8a00dd888d8770e3e9.bundle.js` | Modules `22939` (game process service), `76974` (injection wrapper), `cheats/trainer/index` (executor registration) |
| S5 | `app-b3fcf22e.3dcefe8f20c2227b4349.bundle.js` | Module `76517` (backend resolver) ~14012; module `12603` (hotkey dispatch) |
| S6 | `app-696eada4.8ab3ed671521c38230ed.bundle.js` | Modules `7798` (trainer service), `15817` (Tophat DLL paths), `20899` (legacy channel), `55639` (host launch), `59455` (legacy argument buffer), `64060` (Lua artifacts), `75773` (legacy injection) |
| S7 | `app-366d4320.191373ab540e77dfeb72.bundle.js` | Modules `20128` (artifact loader), `51694` (host server), `62089` (contract-runtime metadata), `64968` (host selection/readiness), `70704` (Tophat executor/channel) |
| S8 | `app-bbe2e206.eef4dee4cdfab9769b90.bundle.js` | Module `51343` (legacy executor) ~17204 |
| S9 | `app-bbe2e206.eef4dee4cdfab9769b90.bundle.js` | Module `13392` (trainer factory, lifecycle, values, disposal); `setValue` ~8800; launch implementation ~14100 |
| S10 | `vendor..pnpm-b2ef25c0.b88380762017023a0e88.bundle.js` | Module `48386` (DLL/start-export/registry manifest), `84262` (gRPC host); raw serializers ~10746 |
| S11 | `app-a695d93c.a3b900ae4969b0adb5bc.bundle.js` | Named module `cheats/resources/elements/trainer-play-button`; service launch call ~53801 |
| S12 | `vendor..pnpm-c74b8095.210ce191ae5c7f3932cf.bundle.js` | Modules `1489` (value event decoding), `5828` (results), `12621` (Tophat trainer client), `54186` (Lua executor client) |
| S13 | `app-561cdd0d.b911e168300d942c9bbf.bundle.js` | Modules `11131` (download/cache validation), `63190` (WLC1 envelope/cache) |
| S14 | `app-bde6a4e6.08a62e3cf1bb5694b05c.bundle.js` | `handleButtonClick`, `handleToggleChange`, and other control handlers ~10500–12000 |
| S15 | `app-4e8d88bd.c446efbd9938d2b27f17.bundle.js` | `resolveTrainerBackend` ~3996: `POST /v3/trainer/backend` with `{titleId}` |

## Managed evidence

**N1:** copied `trainerlib/TrainerHost_x64.exe`, SHA-256 `7e7ee2b98de286047f06e785813906a50b238079aa55d633c89bc29259c484c3`. Reflection-only inspection of all declared host methods established the argument and wait behavior. The x86 host's `Main` was also sampled for the argument contract; full x86 IL equivalence was not tested.

**N2:** copied `auxiliary/WandAuxiliaryService.exe`, SHA-256 `5cd798d78137e3057adb2702ef6162790dca88909b4fd40f8e3bedb5707569ae`. Reflection-only metadata identifies assembly version `12.0.0.0`, entry `5::0`, and 698 types. Method names and imported APIs were inventoried, but the service was not fully decompiled.

## Passive runtime evidence

The existing process inventory identified WAND main PID 16248, renderers 2060 and 15916, and auxiliary service 21332 parented by renderer 2060. No `TrainerHost` process appeared in the check at the start of this milestone.

Reading `%APPDATA%\Wand\service-ports.json` returned a record for PID 2060, port 59371, service/target `wand_desktop`, and start timestamp 1788792549. `Get-NetTCPConnection -State Listen` independently confirmed PID 2060 listening on `127.0.0.1:59371`.

At 22:19 local time, a fresh MCP stdio session again verified bridge version 12.0.0 and selected PID 16248, with `debug_is_debugging: false`. This milestone did not attach a debugger or change CE's selected target. No inference about successful native debugging follows from these observations.

## Reproduction tools

[tools/snapshot.cjs](tools/snapshot.cjs) accepts an analysis directory already containing `app.asar`, `trainerlib`, and `auxiliary` copies. It validates archive entry paths and byte ranges, extracts selected source types without execution, and creates `manifest.json`. Output uses exclusive file creation; run it in a fresh destination to preserve prior work.

```powershell
node AI_Context/WAND/tools/snapshot.cjs 'E:\path\to\fresh-analysis-copy'
```

[tools/read-managed-il.ps1](tools/read-managed-il.ps1) uses Windows PowerShell reflection-only loading to list methods or decode IL. It resolves method/field/string tokens where available and does not execute application code. It is a small inspection helper, not a full C# decompiler. Missing dependency metadata can leave unresolved tokens.

```powershell
& AI_Context/WAND/tools/read-managed-il.ps1 `
  -AssemblyPath 'E:\002. Github\036.Trainer_Check\WAND_Analysis\12.52.0\trainerlib\TrainerHost_x64.exe' `
  -MethodPattern '::WaitForExit$'
```

## Limits

This is a code-established architecture and an idle runtime cross-check. It does not establish the remote backend's internal implementation, the current title's actual backend, native packed-code behavior, a feature's effect in a game, native signature enforcement, or active anti-debugging. Those require the targeted follow-up work described in [README.md](README.md).
