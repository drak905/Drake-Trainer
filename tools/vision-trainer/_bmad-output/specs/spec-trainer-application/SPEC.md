---
id: SPEC-trainer-application
companions:
  - architecture-diagrams.md
  - glossary.md
  - brownfield.md
  - ../../../AI_Context/MCP_Bridge_Command_Reference.md
sources:
  - ../../planning-artifacts/architecture/architecture-Trainer_Application-2026-10-02/ARCHITECTURE-SPINE.md
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Trainer Application (cheatengine-mcp-bridge)

## Why

Manual game-memory work means days of hex-dump spelunking to find one pointer or structure, and every game update restarts the hunt. This spec captures the existing whole-system contract — an AI-driven bridge into Cheat Engine plus a guided app that turns a visible stat to 100x — so agents and humans can extend either tier without breaking the wire, the safety gates, or the anchor ladder. Opportunity (newly possible: conversational memory analysis) plus mandate (the finalized architecture spine binds downstream work).

## Capabilities

- **CAP-1**
  - **intent:** AI agent can read, write, scan, analyze, and debug an attached process to achieve reverse-engineering tasks conversationally.
  - **success:** `ping` returns success plus bridge version, and `test_mcp.py` passes with CE running, bridge loaded, and a process attached.
- **CAP-2**
  - **intent:** Operator can run the bridge locally or from a remote host without changing the command contract to support WSL and container setups.
  - **success:** The same command exchange succeeds on both transports under the same per-RPC deadline, and the relay forwards pipe-to-TCP on loopback by default.
- **CAP-3**
  - **intent:** Operator can re-execute the Lua bridge safely to recover from a stale session without leaking breakpoints, watches, scans, or maps.
  - **success:** Re-execution tears down every registered resource and re-listens on the same pipe name.
- **CAP-4**
  - **intent:** Player can auto-adjust an offline game stat to 100x through a guided loop of seeing the value, finding it in memory, writing it, and confirming the change.
  - **success:** The write lands at 100x of the observed value, anchor capture produced at least one ladder rung, and user-yes persists both the per-game RUNBOOK entry and the live profile cheat.
- **CAP-5**
  - **intent:** Player can re-locate a proven cheat after a game restart without rescanning even though addresses shift between runs.
  - **success:** The anchor resolves to a verified address after restart, raw addresses are never trusted under ASLR, and when no rung resolves a rescan recipe is present to rebuild from.
- **CAP-6**
  - **intent:** Player can exit the app knowing freezes, patches, and breakpoints restore the target to its original state.
  - **success:** Shutdown restores original values and bytes, clears breakpoints, and a force-kill recovery re-resolves via the ladder instead of trusting stale addresses.
- **CAP-7**
  - **intent:** Contributor can validate changes without Cheat Engine through the offline pytest suite and the pointer-parser Lua test.
  - **success:** `pytest -m "not live"` passes with no CE running, and the UNIT-24 parser test passes offline.

## Constraints

- Offline educational scope only, never multiplayer or anti-cheat titles; rules out matchmaking bypass and anti-cheat evasion features.
- Shell and arbitrary Lua execution gated: `run_command`/`shell_execute` need `CE_MCP_ALLOW_SHELL=1`, `evaluate_lua` family is trusted-code-only; rules out ungated host execution.
- Single broker contract: paired commands with identical method strings, one framed wire, main-thread execution, closed error codes; rules out parallel incompatible protocols.
- Target-safety hardware rules: `Query memory region routines` stays disabled, hardware breakpoints and hypervisor watches preferred over software breakpoints, 32/64-bit handled by arch branching; rules out BSOD-prone scans and arch-breaking handlers.
- Conservative mutation: single-address prompted writes only, ambiguous signatures refuse the rung, force-kill residue re-resolves via the ladder; rules out multi-address unprompted writes.
- Anchor at persist: no profile write without at least one ladder rung, and anchor-capture failure is a write-blocking error; rules out anchorless cheats that die on restart.
- Verified promotion: drafts promote to the live profile only after in-game verification, or carry explicit `verified:false` and never auto-apply; rules out plausible-but-wrong cheats reaching the live set.
- Stack floor: Python 3.10+, `mcp>=1.28,<2`, CE 7.6 Lua host; rules out the v2 FastMCP API and non-Lua hosts.

## Non-goals

- Cheating in multiplayer games or bypassing anti-cheat systems.
- Cloud-hosted LLM SaaS; the vision/adjust models stay a local OpenAI-compatible server.
- Bridge CI packaging and distribution; no build or linter harness exists for the bridge.
- Shipping per-game cheat recipes as product content; recipes live in user-local profiles and RUNBOOKs.
- Re-deciding per-tool parameter schemas; those live in the adopted command reference companion.

## Success signal

An operator attaches to an owned offline game, adjusts a visible stat to 100x, restarts the game, re-locates the same cheat via its anchor, and exits with the target restored — all with `ping` healthy and the offline test gate green.

## Assumptions

- Assumed spine AD-9 safety gates hold as stated pending user ratification.

## Open Questions

- Is the Python 3.10 floor bump to 3.11+ and the CE 7.7 compat check in scope for this spec?
- Does force-kill recovery need an automatic owner and persistent journal, or is manual re-resolve acceptable?
