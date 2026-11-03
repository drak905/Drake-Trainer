---
title: 'technical research: Rust + Tauri vs Python + Tkinter for Trainer_Application'
type: 'technical'
topic: 'Rust + Tauri vs Python + Tkinter for Trainer_Application'
decision: 'Should Trainer_Application be rebuilt on Rust std + Tauri UI, or stay on Python + Tkinter?'
source: 'native run'
status: complete
preset: 'standard'
validation: 'normal'
created: '2026-10-02'
updated: '2026-10-02'
verified: 5
unverified: 1
---

# technical research: Rust + Tauri vs Python + Tkinter for Trainer_Application

**Decision this research serves:** Should Trainer_Application be rebuilt on Rust std + Tauri UI, or stay on Python + Tkinter?

## Executive summary

**Stay on Python + Tkinter; do not rebuild on Rust + Tauri.** The evidence converges from all three dimensions: Tauri v2 is healthy (core 2.12.0, Sep 2026 [1]) but its offline distribution story directly regresses your requirements — true-offline WebView2 bundling adds ~127–180MB [2][3] and distribution is installer-centric, not one-dir portable. Every Rust-side need (screenshots, named pipes, HTTP, Win32) is covered by maintained crates [8][9][10], but the Win32-heavy slices force `unsafe` + `windows`-crate churn with no blessed safe wrappers found. Switching to Tauri buys nothing on distribution trust — signing costs and SmartScreen reputation-building apply identically [5]. The cheapest UI upgrade that keeps everything working is CustomTkinter 6.0.0 (released Jun 2026 [6]) — modern widgets, high-DPI, drop-in on existing Tkinter code.

**Biggest caveat:** no solo-dev rewrite post-mortem or Rust-on-Windows iteration-cost data was found within budget — the "rewrite costs 2–4x" argument rests on a durable but stale (2018) industry model [7], applied by analogy. If you want certainty, the cheapest test is a one-week timeboxed spike, not more research.

## 1. Tauri v2 maturity + Windows reality

Tauri v2 is alive and releasing fast: core, CLI, and JS API all at 2.12.0 dated Sep 26, 2026, with steady patch cadence through the year (bundler 2.10.0, wry 0.57.0, updater 2.12.0, single-instance 2.4.5, dialog 2.7.3) [1]. A v3 alpha line exists (3.0.0-alpha.4, ~Oct 2026) [4] — a watching brief, not a reason to wait.

The Windows story is where it breaks for this app. Tauri assumes WebView2 present (Win10 2018+/Win11 ship it) [2]; machines without it hit the install-time network dependency. Your offline requirement forces one of the heavy options: embed the bootstrapper (~+1.8MB, still needs internet), the offline installer (~+127MB), or a fixed runtime (~+180MB, confirmed "around 180MB" in the `WebviewInstallMode::FixedRuntime` docs [3]). Distribution is MSI (WiX, Windows-build-only) or NSIS; cross-building NSIS from other OSes is documented as last-resort [2]. The standalone-portable-`.exe` path is a known community friction point [2]. First-party single-instance [11] and signed-updater plugins exist, but the updater mandates a signing keypair with verification that cannot be disabled — overhead for a hobby app.

Named-pipe IPC from Rust to the CE bridge is feasible: Tokio ships first-party Windows named-pipe client/server primitives (`ClientOptions`/`NamedPipeClient`) [8]. But no Cheat-Engine-specific framing, reconnection, or message-boundary pattern was found — that integration would be designed from scratch. Wizard-dialog primitives (dialog 2.7.3, window-state, tray plugins) exist by name; their multi-window wizard ergonomics were not verified this run.

## 2. Rust std + crate ecosystem for trainer needs

Coverage is complete on paper, expensive in practice:

- **Screenshots/window capture:** `xcap` 0.9.8 (Aug 2026, monthly cadence) supports Windows screen + window + region capture returning `image`-crate buffers [10]. JPEG/downscale is mature std-adjacent crates (`image` with `JpegEncoder::new_with_quality`) [10] — no Win32 code needed for this slice.
- **Named pipes:** Tokio first-party async client/server [8]; framing/large-message behavior undocumented on the fetched page — you own length-prefixing and chunking either way.
- **HTTP LLM client:** `reqwest` 0.13 (11.9k stars) covers `GET /models` + `POST /chat/completions` trivially [9]; SSE/streaming not verified on a primary page.
- **Win32 process/memory:** no blessed safe wrapper found; the pattern is raw `ReadProcessMemory`/`WriteProcessMemory`/`OpenProcess` via the `windows` crate inside `unsafe` blocks [12]. `xcap` itself pulls `windows 0.62` umbrella — and Microsoft now steers authors away from the umbrella crates toward focused crates + `windows-bindgen` for "dependency weight and version churn" [13]. You inherit that churn.
- **Window rect:** `GetWindowRect`/`DwmGetWindowAttribute` + crop; `xcap` wraps position/size/minimized flags [10]. Occluded-window fidelity unverified.

No credible 6–12-month solo/team Win32-Rust retrospective was found — "Rust slows solo Win32 work" stays an unverified belief, not a cited claim.

## 3. Rewrite cost + solo-dev operational burden

The economics argue harden-over-rewrite. The classic rewrite-cost model (catch-up maintenance + undiscovered scope + adoption enhancements → 2–4x estimate multipliers) is stale (2018) but directionally durable [7]; for a 20-module/156-test working app, the undiscovered-scope term is the live risk, and no counter-evidence (a cheap successful solo rewrite post-mortem) surfaced. Tkinter on Windows needs DPI workarounds (hidpi-tk exists for exactly this [14]), but there is no 2026 evidence it is unmaintained — and the in-Python upgrade path is cheap: CustomTkinter 6.0.0 shipped Jun 24, 2026, MIT, ~570KB, drop-in on Tkinter with modern widgets, dark mode, and correct Windows high-DPI [6].

Distribution trust is the decisive equalizer: Microsoft's current signing terms (OV $150–300/yr, EV $400+/yr, EV instant SmartScreen bypass removed in 2024, reputation built over time for all, only Store MSIX free of warnings — updated Aug 2026 [5]) apply identically to a Tauri bundle. Tauri's NSIS/MSI still needs the same reputation-building; PyInstaller's one-dir default remains the right hobby shape (one-file only slows startup) [15]. Switching toolkits does not buy trust.

One genuinely cheap reversibility hedge exists: Tauri officially supports a Python-core sidecar (`bundle.externalBin` + per-triple naming + capability-gated `sidecar()` spawn) [16], with community precedent (Tauri v2 + Next.js + PyInstaller'd FastAPI sidecar) [17]. But the pilot doubles packaging (sidecar + Tauri bundle + WebView2) and adds JS/TS + Rust debug surface for one person — a spike, not a plan.

## Cross-dimension insights

The combination that matters: **Tauri's two taxes (WebView2 offline weight + installer-centric distribution) hit exactly the two properties your app already gets for free (offline-capable, one-dir portable)** — while the one thing a rewrite is often assumed to fix (SmartScreen trust) is invariant across toolkits per Microsoft's 2026 terms. Meanwhile the Rust ecosystem's strongest slices (screenshot→JPEG, HTTP, async pipes) are the parts Python already does well, and its weakest slice (unsafe Win32 process/memory + binding churn) is the part your app touches most. The technically modern option loses on fit, not on quality.

## Recommendations

| Criterion (weight) | Python + Tkinter, hardened (pick) | Rust + Tauri rebuild | Notes |
|---|---|---|---|
| Offline + one-dir distribution (hard gate) | Pass — native, no runtime tax | **Fail** — +127–180MB or install-time net [2][3] | Gate alone decides barring reweight |
| CE named-pipe IPC (hard gate) | Pass — working today | Pass with new code [8] | Rust side owns framing either way |
| Solo effort to value (high) | Days–weeks (CustomTkinter, DPI, polish) [6][14] | Weeks–months + unsafe Win32 surface [12][13] | Rewrite model [7] is stale but uncontradicted |
| Distribution trust (medium) | SmartScreen warning, unchanged | Identical costs/reputation [5] | No advantage to switching |
| UI modernity (medium) | CustomTkinter 6.0.0, drop-in [6] | WebView ecosystem (unverified wizard ergonomics) | Cheapest win stays in Python |
| Long-term maintenance by one (medium) | Known codebase + 156 tests | windows-crate churn + 2 toolchains [13][17] | Favors incumbent |

**The pick: stay on Python + Tkinter and harden.** Concrete next steps: (a) spike CustomTkinter 6.0.0 on one wizard screen (theming + DPI) [6]; (b) fix hidpi handling on Win 10/11 [14]; (c) keep PyInstaller one-dir [15]; (d) defer signing until distribution demands it — when it does, budget OV/Store path per [5], not a toolkit switch.

**Runner-up wins if:** offline/portable stops mattering (always-connected users accept an installer + bundled WebView2), or a web-UI feature (rich overlay, remote control surface) becomes load-bearing enough to justify the ~180MB and second toolchain — prototype the pipe framing + screenshot-display IPC first.

**Strongest argument against the pick:** Tkinter's ceiling is real — if the wizard outgrows desktop idioms (embedded video, complex canvas, cross-platform later), no amount of theming fixes it, and the sidecar pilot [16][17] becomes the honest path. Nothing in this run proves that ceiling is near; watch for it.

## Open questions

1. Tauri high-frequency IPC (invoke vs events vs channels) for polling/display workloads — no benchmark retrieved; route: Tokio docs + Tauri IPC guide if the runner-up ever activates.
2. `xcap` occluded/minimized-window capture fidelity vs current `mss`+Win32 path — needs a Windows benchmark, not more search.
3. `reqwest` SSE/streaming for chat completions if streaming UX is wanted — unverified on primary docs.
4. Safe Rust wrappers for RPM/WPM (`read-process-memory` et al.) maturity — surfaced by name only; crates.io comparison outstanding.
5. Tkinter maintenance statement for 2026 (CPython 3.13/3.14 Tk commits) — not needed for the verdict but would strengthen the file.

## Source appendix

| [n] | Finding it supports | Publisher | Pub date | Accessed | Confidence |
|---|---|---|---|---|---|
| [1] | Tauri 2.12.0 core/CLI/API Sep 26 2026; plugin vitality | [Tauri Contributors](https://v2.tauri.app/release/) | 2026-08-31–2026-09-26 | 2026-10-02 | high |
| [2] | WebView2 install modes (+127MB offline), MSI/NSIS constraints | [Tauri Contributors](https://v2.tauri.app/distribute/windows-installer/) | n.d. (current v2 docs) | 2026-10-02 | high |
| [3] | FixedRuntime +~180MB | [docs.rs / tauri-utils](https://docs.rs/tauri-utils/latest/tauri_utils/config/enum.WebviewInstallMode.html) | n.d. | 2026-10-02 | high |
| [4] | v3.0.0-alpha.4; ~112k stars | [tauri-apps (GitHub)](https://github.com/tauri-apps/tauri/releases) | ~2026-10-01 | 2026-10-02 | medium |
| [5] | Signing costs; EV bypass removed 2024; Store MSIX free | [Microsoft Learn](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options) | updated 2026-08-29 | 2026-10-02 | high |
| [6] | CustomTkinter 6.0.0 Jun 24 2026, MIT, drop-in, HiDPI | [PyPI](https://pypi.org/project/customtkinter/) | 2026-06-24 | 2026-10-02 | high |
| [7] | Rewrite 2–4x multiplier model | [8th Light](https://8thlight.com/insights/the-true-cost-of-rewrites) | 2018-11-27 | 2026-10-02 | medium (stale) |
| [8] | Tokio Windows named-pipe client/server | [tokio-rs / docs.rs](https://docs.rs/tokio/latest/tokio/net/windows/named_pipe/) | n.d. | 2026-10-02 | high (existence) |
| [9] | reqwest 0.13 HTTP client | [seanmonstar (GitHub)](https://github.com/seanmonstar/reqwest) | n.d. | 2026-10-02 | high |
| [10] | xcap 0.9.8 window capture; image JPEG stack | [docs.rs](https://docs.rs/crate/xcap/latest) | 2026-08-01 | 2026-10-02 | high |
| [11] | Single-instance plugin 2.4.5 | [Tauri Contributors](https://v2.tauri.app/plugin/single-instance/) | 2026-09-20 | 2026-10-02 | high |
| [12] | Raw unsafe RPM/WPM pattern, no blessed wrapper | [Microsoft docs-rs mirror](https://microsoft.github.io/windows-docs-rs/doc/windows/Win32/System/Diagnostics/Debug/fn.ReadProcessMemory.html) | n.d. | 2026-10-02 | medium |
| [13] | windows-rs umbrella churn warning | [Microsoft (GitHub)](https://github.com/microsoft/windows-rs) | n.d. | 2026-10-02 | high |
| [14] | hidpi-tk DPI workarounds | [PyPI](https://pypi.org/project/hidpi-tk/) | unknown | 2026-10-02 | medium |
| [15] | PyInstaller one-dir vs one-file; Qt size table | [Python GUIs](https://www.pythonguis.com/faq/packaged-installer-file-sizes/) | updated 2026-04-08 | 2026-10-02 | high |
| [16] | Tauri Python sidecar mechanism | [Tauri Contributors](https://v2.tauri.app/develop/sidecar/) | n.d. | 2026-10-02 | high |
| [17] | Tauri + PyInstaller sidecar precedent | [GitHub dieharders](https://github.com/dieharders/example-tauri-v2-python-server-sidecar) | unknown | 2026-10-02 | medium |

Digests: `digests/tauri-windows-r1-1.md`, `digests/rust-ecosystem-r1-1.md`, `digests/rewrite-cost-r1-1.md`.

## Staleness map

Fastest-aging claims (re-check first): [1] Tauri versions (≤1 mo — re-check on any build decision; v3 alpha could stabilize); [5] Microsoft signing terms (≤3 mo); [6] CustomTkinter releases (≤6 mo); [7] rewrite model (already stale — refresh only if used to justify budget). Landscape claims ([8]–[13] ecosystem) ≤6–12 mo. Earliest re-check: Tauri 2.x version line before any architecture commitment.
