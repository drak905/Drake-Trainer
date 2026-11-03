# Digest: tauri-windows-r1-1 (Tauri v2 maturity + Windows reality)

## Verdict (dimension only)
Tauri v2 is alive and Windows-capable, but a poor fit for offline + one-dir distribution.

## Claims
1. {claim: "Current stable core is tauri crate 2.12.0, CLI 2.12.0, @tauri-apps/api 2.12.0, all dated Sep 26, 2026", source: "https://v2.tauri.app/release/", publisher: "Tauri Contributors (official docs)", pub_date: "2026-09-26", accessed: "2026-10-02", confidence: "high", class: "version"}
2. {claim: "Release vitality high through Sep 2026: bundler 2.10.0, runtime/wry 2.12.0 (Sep 26); wry 0.57.0 (Sep 8); updater 2.12.0 + single-instance 2.4.5 (Sep 20); store 2.4.5 (Sep 16); dialog 2.7.3, http 2.7.0, log 2.9.2 (Aug 31-Sep 20)", source: "https://v2.tauri.app/release/", publisher: "Tauri Contributors", pub_date: "2026-08-31 to 2026-09-26", accessed: "2026-10-02", confidence: "high", class: "ecosystem"}
3. {claim: "2.x shows continuous patch cadence into mid-2026 (runtime 2.10 Feb 02 ... 2.11.3 Jun 17, 2026)", source: "https://v2.tauri.app/release/tauri-runtime/", publisher: "Tauri Contributors", pub_date: "2026-02-02 to 2026-06-17", accessed: "2026-10-02", confidence: "medium", class: "ecosystem"}
4. {claim: "Next major in alpha: tauri v3.0.0-alpha.4 latest GitHub release (~Oct 01); repo ~112k stars / 4k forks", source: "https://github.com/tauri-apps/tauri/releases", publisher: "tauri-apps (GitHub)", pub_date: "2026-10-01 (observed)", accessed: "2026-10-02", confidence: "medium", class: "ecosystem"}
5. {claim: "Default Windows install downloads WebView2 bootstrapper at install time (needs internet); embedBootstrapper ~+1.8MB still needs internet; offlineInstaller ~+127MB no internet; fixedVersion ~+180MB; skip not recommended", source: "https://v2.tauri.app/distribute/windows-installer/", publisher: "Tauri Contributors (official docs)", pub_date: "n.d. (current v2 docs)", accessed: "2026-10-02", confidence: "high", class: "version"}
6. {claim: "WebView2 treated as OS-distributed on Win10 (Apr 2018+) and Win11 (preinstalled)", source: "https://v2.tauri.app/reference/webview-versions/", publisher: "Tauri Contributors", pub_date: "n.d.", accessed: "2026-10-02", confidence: "medium", class: "version"}
7. {claim: "MSI (WiX v3) only builds on Windows; NSIS cross-build from Linux/macOS is last-resort, less tested", source: "https://v2.tauri.app/distribute/windows-installer/", publisher: "Tauri Contributors", pub_date: "n.d.", accessed: "2026-10-02", confidence: "high", class: "pattern"}
8. {claim: "First-party single-instance plugin exists (2.4.5, Sep 20 2026), MSRV Rust 1.77.2", source: "https://v2.tauri.app/plugin/single-instance/", publisher: "Tauri Contributors", pub_date: "2026-09-20", accessed: "2026-10-02", confidence: "high", class: "version"}
9. {claim: "First-party updater exists (2.12.0) but requires signing keypair; verification cannot be disabled", source: "https://v2.tauri.app/plugin/updater/", publisher: "Tauri Contributors", pub_date: "2026-09-20", accessed: "2026-10-02", confidence: "medium", class: "version"}
10. {claim: "Single standalone .exe bundling WebView2 for machines without it is a known friction point", source: "https://github.com/orgs/tauri-apps/discussions/4774", publisher: "tauri-apps (GitHub Discussion)", pub_date: "n.d.", accessed: "2026-10-02", confidence: "low", class: "pattern"}
11. {claim: "Rust-side Windows named-pipe IPC feasible via tokio::net::windows::named_pipe (NamedPipeServer/ClientOptions/ServerOptions), Windows-gated + net feature", source: "https://docs.rs/tokio/latest/tokio/net/windows/named_pipe/", publisher: "tokio-rs / docs.rs", pub_date: "n.d.", accessed: "2026-10-02", confidence: "high existence / low CE-suitability", class: "pattern"}
12. {claim: "Dialog/notification/shell/window-state plugins maintained (e.g. dialog 2.7.3 Aug 31 2026) — wizard primitives exist, behavior not verified", source: "https://v2.tauri.app/release/", publisher: "Tauri Contributors", pub_date: "2026-08-31", accessed: "2026-10-02", confidence: "low", class: "ecosystem"}

## Not found (thin, do not decide on)
- IPC high-frequency performance benchmarks; tray/multi-window/dialog behavior; offline-updater suitability; maintainer/funding status; v2.0->2.12 fix history; CE-bridge-specific pipe framing gotchas.

## Leads
- webview-versions + updater + tray/dialog/window docs; 18-month Tauri retrospective (johal.in); erikhorton Tauri retrospective; devache pain-point list; tauri-apps discussion #13925; Tokio ClientOptions/message-vs-byte-mode docs.
