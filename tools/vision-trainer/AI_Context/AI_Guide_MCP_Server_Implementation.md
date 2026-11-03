# AI Agent Guide: Building a Full MCP Server for CheatEngine

---

## ⚠️ CRITICAL CONFIGURATION

### 1. BSOD PREVENTION
**You MUST disable:** Cheat Engine → Settings → Extra → **"Query memory region routines"**.
- **Enabled:** Causes `CLOCK_WATCHDOG_TIMEOUT` BSODs due to conflicts with DBVM/Anti-Cheat when scanning protected pages.
- **Disabled:** Scanning works perfectly and safely (v11 verified).

### 2. ANTI-CHEAT SAFETY
- **DO NOT** use software breakpoints (0xCC/Int3). Use **Hardware Debug Registers (DR0-DR3)** breakpoints.
- **DO NOT** write to memory.
- **USE** DBVM tools (`start_dbvm_watch`) for invisible tracing at Ring -1.

### 3. LOADING AND CLIENT CONFIGURATION
- Load the Lua bridge from Cheat Engine with `File -> Execute Script -> MCP_Server/ce_mcp_bridge.lua -> Execute` when available.
- If that menu is unavailable, use `Table -> Show Cheat Table Lua Script` and execute only `dofile([[C:\path\to\cheatengine-mcp-bridge\MCP_Server\ce_mcp_bridge.lua]])`; do not paste the full bridge into the table script.
- For Codex, configure `~/.codex/config.toml` with `[mcp_servers.cheatengine]`, `command = "python"`, and `args = ['C:\path\to\MCP_Server\mcp_cheatengine.py']`. TOML single-quoted strings keep Windows backslashes literal.
- Restart the MCP client after config changes and verify the connection with `ping`. `process_id: 0` means the bridge is connected but CE has not attached to a target process yet.

---

## 1. OBJECTIVE

A **production-grade Model Context Protocol (MCP) server** acts as the "Universal Key" to the game engine, allowing AI agents to:
1.  **Read & Analyze** any part of memory (static or dynamic).
2.  **Trace Execution** invisible to anti-cheat (Hypervisor/Hardware BPs).
3.  **Reverse Engineer** complex structures and functions on the fly.

### Performance Targets
- **Architecture:** Multi-Threaded Named Pipe (Async I/O).
- **Latency:** <2ms per command.
- **Reliability:** 100% Robust against freezes via `thread.synchronize`.

---

## 2. SYSTEM ARCHITECTURE (v12.0.0)

### The "v12/v99" Bridge
The system uses a highly optimized Named Pipe architecture with a dedicated worker thread in Lua to handle blocking I/O, ensuring the main Cheat Engine GUI/Thread never freezes.

An optional TCP relay (`MCP_Server/ce_tcp_relay.py`) lets the Python MCP server run outside the Windows host — from WSL, a container, or another machine. Set `CE_MCP_TRANSPORT=tcp` plus `CE_MCP_HOST` / `CE_MCP_PORT` on the server and run the relay on Windows next to Cheat Engine. The Lua bridge is identical either way. Keep the relay bound to loopback unless you intend to expose bridge control to the network.

### Universal 32/64-bit Architecture Support
The bridge automatically adapts to the target process architecture:
- **`getArchInfo()`** - Dynamically detects 32-bit vs 64-bit target
- **`captureRegisters()`** - Captures RAX/RBX (x64) or EAX/EBX (x86) correctly
- **`captureStack()`** - Reads stack with correct pointer size (8/4 bytes)
- **`readPointer()`** - Used throughout for automatic pointer size handling
- **Function Analysis** - Detects both x86 (`55 8B EC`) and x64 (`55 48 89 E5`, `48 83 EC xx`) prologues

**Connection Details:**
- **Pipe Name:** `\\.\pipe\CE_MCP_Bridge_v99`
- **Protocol:** Length-Prefixed JSON-RPC
- **Flow:** Python `FastMCP` Server <-> Named Pipe <-> Lua Worker Thread <-> Main Thread (`synchronize`)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  AI Agent (Claude/Cursor/Copilot)                                      │
│       │                                                                 │
│       ▼ MCP Protocol (JSON-RPC over stdio)                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  mcp_cheatengine.py (Python MCP Server)                         │   │
│  │  - Translates MCP tools to JSON-RPC                             │   │
│  │  - Connects to \\.\pipe\CE_MCP_Bridge_v99                       │   │
│  └───────────────────────────┬─────────────────────────────────────┘   │
│                              │ Named Pipe (Async)                      │
│                              ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  CheatEngine (Running, attached to .exe)                        │   │
│  │  ┌─────────────────────────────────────────────────────────┐    │   │
│  │  │  ce_mcp_bridge.lua                                      │    │   │
│  │  │  ┌─────────────────┐      ┌─────────────────────┐       │    │   │
│  │  │  │ Worker Thread   │◄────►│ Main Thread (GUI)   │       │    │   │
│  │  │  │ (Blocking I/O)  │ Sync │ (Safe API Execution)│       │    │   │
│  │  │  └─────────────────┘      └─────────────────────┘       │    │   │
│  │  └─────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. COMPREHENSIVE TOOLSET (175 Commands)

The v12.0.0 implementation provides a complete arsenal for reverse engineering with full 32/64-bit compatibility. The tables below are a curated highlight reel; `MCP_Bridge_Command_Reference.md` documents all 175 tools.

### 🔍 Memory Reading & Scanning
| Tool | Description |
|------|-------------|
| `read_memory(addr, size)` | Read raw bytes. |
| `read_integer(addr, type)` | Read Byte, Word, Dword, Qword, Float, Double. |
| `read_string(addr, len)` | Read ASCII/UTF-16 strings. |
| `read_pointer_chain(base, offsets)` | **CRITICAL**: Follow dynamic pointer paths `[base+10]+20`. |
| `scan_all(val, type, prot)` | Full memory scanner (like CE GUI). **Safe Mode Enabled.** |
| `aob_scan(pattern)` | Find array of bytes `48 8B 05 ??`. |
| `generate_signature(addr)` | Create unique AOB signature for an address. |

### 🧬 Structure & Code Analysis
| Tool | Description |
|------|-------------|
| `dissect_structure(addr)` | **AI-Powered**: Auto-guess fields, types, and values at address. |
| `get_rtti_classname(addr)` | Identify C++ object types (e.g., `NpcUser`, `CItem`). |
| `analyze_function(addr)` | Find all `CALL`s made by a function. |
| `find_references(addr)` | Find what code uses this data (Cross-References). |
| `find_call_references(func)` | Find who calls this function (Call Graph). |
| `find_function_boundaries(addr)` | Locate function start/end/prologue. |

### 🐞 Debugging (Anti-Cheat Safe)
| Tool | Description |
|------|-------------|
| `set_breakpoint(addr)` | **Hardware BP**: Triggers on execution. Logs registers. |
| `set_data_breakpoint(addr)` | **Watchpoint**: Triggers on Write/Read access. |
| `get_breakpoint_hits()` | Retrieve hit logs (Registers, Stack, Timestamp). |

### 🚀 DBVM Hypervisor (Ring -1)
| Tool | Description |
|------|-------------|
| `start_dbvm_watch(addr)` | **Invisible Trace**: use physical memory hooks. Undetectable. |
| `get_physical_address(addr)` | Resolve Virtual -> Physical address. |

### 🧭 Pointer Walk-back (Unit 24)
| Tool | Description |
|------|-------------|
| `analyze_pointer_access(instruction, registers)` | Pure logic: parse `mov [rcx+04],eax` + a register snapshot into `struct_base` / `displacement` / `next_scan_value`, so you know what to scan for one level up. |
| `validate_pointer_chains(chains, target)` | Batch-resolve candidate chains and report only the ones that currently land on `target`. Re-run after a restart; the survivors are the stable paths. |

See `Pointer_Tools_Design.md` §5 for the full orchestration recipe (watch → analyze → scan → recurse → validate).

Full commands list at `MCP_Bridge_Command_Reference.md`

---

## 4. CURRENT STATUS

| Component | Status | Version | Notes |
|-----------|--------|---------|-------|
| **Lua Bridge** | ✅ **ACTIVE** | v12.0.0 | `ce_mcp_bridge.lua` (load in CE) — 175 handlers + 7 aliases |
| **Python Server** | ✅ **ACTIVE** | v12.0.0 | `mcp_cheatengine.py` (run in agent) — 175 `@mcp.tool()` functions |
| **TCP Relay** | ✅ **OPTIONAL** | v12.0.0 | `ce_tcp_relay.py` — only needed when the MCP server can't open the pipe |
| **Integration Tests** | ✅ **AVAILABLE** | — | `test_mcp.py` — 69 cases, needs CE + attached process |
| **Offline Tests** | ✅ **AVAILABLE** | — | `test_pointer_parse.lua` — UNIT-24 parser, stock Lua, no CE |
| **Documentation** | ✅ **UPDATED** | v12.0.0 | `MCP_Bridge_Command_Reference.md` (32 sections) |

### Notable behavior to account for
- **Zombie cleanup**: `cleanupZombieState()` runs on every `StartMCPBridge` / `StopMCPBridge`, removing orphaned breakpoints, DBVM watches, scan objects, persistent scans, and mapped MDLs. Don't reload the bridge as a connectivity test — use `ping`.
- **`get_process_info` is not passive**: it calls `reinitializeSymbolhandler()` first. Use `get_opened_process_id` for a minimal attachment check. Its module list is capped at 50 and can disagree with `enum_modules`; they are different views, not the same count.
- **Pointer chains use `readPointer()`** throughout, so they are 32/64-bit safe. `resolveChain()` is the shared helper behind both `read_pointer_chain` and `validate_pointer_chains`.
- **Scans share one slot**: `scan_all` / `next_scan` reuse `serverState.scan_foundlist`. Starting a new scan discards the previous results. Use the persistent-scan tools when you need named, concurrent scan state.
- **Function analysis** detects x86 (`55 8B EC`) and x64 (`55 48 89 E5`, `48 83 EC xx`) prologues, and includes indirect `CALL` (`FF /2`). All analysis responses carry an `arch` field.

---

## 5. BEST PRACTICES FOR AGENTS

1.  **Always Check `ping()`**: verify connection before starting heavy tasks.
2.  **Use `read_pointer_chain`**: simpler and faster than multiple `read_pointer` calls.
3.  **Structure Analysis**: Use `dissect_structure` on unknown pointers to understand their layout immediately.
4.  **Safe Scanning**: `scan_all` scans in **User Mode** range only to prevent BSODs (`0x7FFFF...`).
5.  **RTTI is King**: Use `get_rtti_classname` to identify what an object is instantly.
6.  **Check Architecture**: Use `get_process_info()` to check `targetIs64Bit` before architecture-specific operations. Note this call is **not** side-effect free — it reinitializes the symbol handler. For a plain "is the bridge up and what is it attached to" check, use `ping` + `get_opened_process_id`.
7.  **DBVM for Stealth**: Use `start_dbvm_watch` for invisible Ring -1 tracing (if DBVM is active).
8.  **Cleanup Breakpoints**: Always call `remove_breakpoint` or `stop_dbvm_watch` after monitoring.
9.  **Pointer paths**: after a watch captures an access, feed the instruction + registers to `analyze_pointer_access` to get the next address to scan for, and confirm candidate chains with `validate_pointer_chains` — once now, once after a process restart. Only chains that survive both are stable.
10. **Never reload the Lua bridge as a health check**: reloading runs `cleanupZombieState()` and destroys breakpoints, watches, and scan state. Use `ping`.

---

## 6. VERIFICATION

Two test entry points:

```bash
# Integration — needs Windows + CE running + bridge loaded + a process attached.
# 69 cases across Basic & Utility, Scanning, Memory Reading, Disassembly, References,
# Breakpoints, Modules, High-Level, DBVM, and the Unit-24 groups.
# Capabilities that aren't available (DBVM not loaded, no debugger) report as skipped,
# so exact counts are environment-dependent. Exits non-zero only on real failures.
python MCP_Server/test_mcp.py

# Offline — pure UNIT-24 operand parser under a stock Lua interpreter. No CE needed.
lua MCP_Server/test_pointer_parse.lua
```

Running a single integration test means editing the `all_tests` dict in `test_mcp.py:main`; there is no test selector flag.
