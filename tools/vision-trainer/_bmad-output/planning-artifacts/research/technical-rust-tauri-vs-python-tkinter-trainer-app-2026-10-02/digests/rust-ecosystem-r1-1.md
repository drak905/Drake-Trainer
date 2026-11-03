# Digest: rust-ecosystem-r1-1 (Rust std + crates for trainer needs)

## Verdict (dimension only)
Viable but expensive: every need covered by a maintained crate, but Win32-heavy slices force unsafe + windows-crate churn — a bad trade for a solo dev on a working Python app.

## Claims
1. {claim: "xcap actively maintained (0.9.8 released 2026-08-01; monthly releases through 2026), supports Windows screen + window capture + region crop, returns image-crate buffers; Windows impl depends on windows ^0.62", source: "https://docs.rs/crate/xcap/latest", publisher: "docs.rs / nashaofu", pub_date: "2026-08-01", accessed: "2026-10-02", confidence: "high", class: "version/ecosystem"}
2. {claim: "JPEG encode + downscale + Base64 stack is mature std-adjacent crates (image + base64), not OS-specific; image provides JpegEncoder::new_with_quality, DynamicImage, imageops", source: "https://docs.rs/image/latest/image/", publisher: "docs.rs / image-rs", pub_date: "n.d.", accessed: "2026-10-02", confidence: "high", class: "ecosystem"}
3. {claim: "Tokio ships first-party Windows named-pipe client (ClientOptions/NamedPipeClient) plus server; Windows + net feature", source: "https://docs.rs/tokio/latest/tokio/net/windows/named_pipe/", publisher: "docs.rs / Tokio team", pub_date: "n.d.", accessed: "2026-10-02", confidence: "high", class: "version"}
4. {claim: "reqwest is the batteries-included HTTP client (async + blocking, JSON, proxies, rustls default), current line 0.13", source: "https://github.com/seanmonstar/reqwest", publisher: "seanmonstar (GitHub)", pub_date: "n.d. (11.9k stars)", accessed: "2026-10-02", confidence: "high", class: "ecosystem"}
5. {claim: "Official Windows bindings are Microsoft windows-rs (12.8k stars); Microsoft steers library authors to focused crates + windows-bindgen over windows/windows-sys umbrellas due to dependency weight and version churn", source: "https://github.com/microsoft/windows-rs", publisher: "Microsoft (GitHub)", pub_date: "n.d.", accessed: "2026-10-02", confidence: "high", class: "ecosystem/pattern"}
6. {claim: "Process attach/RPM/WPM has no blessed safe wrapper found; pattern is raw ReadProcessMemory/WriteProcessMemory/OpenProcess/EnumProcesses via windows/windows-sys inside unsafe blocks", source: "https://microsoft.github.io/windows-docs-rs/doc/windows/Win32/System/Diagnostics/Debug/fn.ReadProcessMemory.html", publisher: "Microsoft docs-rs mirror / community demo", pub_date: "n.d.", accessed: "2026-10-02", confidence: "medium", class: "pattern"}
7. {claim: "Window-rect path is GetWindowRect/DwmGetWindowAttribute + crop; xcap wraps Window::{x,y,width,height,is_minimized,capture_image}", source: "https://docs.rs/crate/xcap/latest", publisher: "docs.rs / nashaofu", pub_date: "2026-08-01", accessed: "2026-10-02", confidence: "medium", class: "pattern"}
8. {claim: "Solo-dev Win32-heavy Rust learning/debugging burden: no qualifying retrospective found — 'Rust slows solo Win32 work 2-3x' is unverified belief", source: "n/a", publisher: "n/a", pub_date: "n/a", accessed: "2026-10-02", confidence: "low", class: "scale"}

## Not found (thin)
- Window-crop occlusion behavior; JPEG tuning numbers; pipe large-message framing limits; reqwest SSE primary docs; process-memory wrapper maturity; credible 6-12-month Win32-Rust retrospective.

## Leads
- Tokio ClientOptions message-vs-byte-mode docs; reqwest bytes_stream + eventsource-stream; windows crate 0.58->0.62 changelog (churn frequency); crates.io for read-process-memory, sysinfo, base64, scap/screenshots vs xcap downloads.
