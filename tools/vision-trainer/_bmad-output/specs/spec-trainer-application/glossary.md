# Glossary — Trainer Application

| Term | Meaning |
| --- | --- |
| Broker | The Lua bridge inside Cheat Engine; the only tier that touches the CE API. |
| `CEBridge` | `vision_trainer/ce_client.py` transport; the app's sole path to the wire. |
| Framed wire | 4-byte LE length prefix plus UTF-8 JSON-RPC, max frame just under 32 MB. |
| Pipe name | `CE_MCP_Bridge_v99`; the wire version, independent of bridge version 12.0.0. |
| Anchor ladder | Re-location order: `module_offset` → `signature` → `pointer_chain` → `rescan`. |
| Module offset | Symbolic `module+offset` (e.g. `game.exe+0x1234`); first ladder rung. |
| Signature | Unique AOB pattern plus module and offset; ambiguous patterns refuse the rung. |
| Pointer chain | Base plus offsets validated by a non-empty `matches` set; third rung. |
| RUNBOOK | Append-only per-game Markdown log under `%APPDATA%\VisionTrainer\runbooks\`; written only on user-yes. |
| Profile | Per-game JSON cheats under `%APPDATA%\VisionTrainer\profiles\` (`schema:1`); drafts replace wholesale, promotion is explicit. |
| Freeze | Repeated-write worker that captures the original once and restores on exit. |
| Patch writer | Data-breakpoint locate, classify, fingerprint, NOP/replace; unique signature required, bytes restored on exit. |
| Shell gate | `CE_MCP_ALLOW_SHELL=1` env requirement for `run_command`/`shell_execute`; unset by default. |
| `cleanupZombieState` | Lua teardown of breakpoints, DBVM watches, scans, and MDL maps before bridge restart. |
| Offline gate | `pytest -m "not live"` suite plus the UNIT-24 Lua parser test; needs no CE. |
| Live gate | `pytest -m live` harness suite; needs the harness target plus CE plus an attached offline game. |
