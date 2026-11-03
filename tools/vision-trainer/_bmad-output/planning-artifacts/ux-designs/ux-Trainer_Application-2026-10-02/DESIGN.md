---
name: Trainer_Application
description: Solo Windows offline vision-to-Cheat Engine trainer — system-native CustomTkinter single-window.
status: final
updated: '2026-10-02'
colors:
  # Surfaces inherit Windows light/dark via CustomTkinter appearance mode; only deltas listed.
  brand-accent: '#0078D4' # [ASSUMPTION: restrained Windows blue chosen as minimal brand accent; not in source]
  brand-accent-dark: '#4CC2FF' # [ASSUMPTION: lightened accent for dark mode legibility; not in source]
  warning-amber: '#B45309' # [ASSUMPTION: dark-amber for AA on light surfaces; not in source]
  warning-amber-dark: '#FBBF24' # [ASSUMPTION: light-amber for AA on dark surfaces; not in source]
  destructive: '#D13438' # [ASSUMPTION: Windows error red; not in source]
  destructive-dark: '#F1707B' # [ASSUMPTION: lightened red for dark mode; not in source]
typography:
  # All roles Segoe UI via CustomTkinter; sizes are deltas for the desktop surface.
  title:
    fontFamily: 'Segoe UI'
    fontSize: 16px # [ASSUMPTION: size inferred; source says Segoe UI only]
    fontWeight: '600'
  heading:
    fontFamily: 'Segoe UI'
    fontSize: 13px # [ASSUMPTION: size inferred; source says Segoe UI only]
    fontWeight: '600'
  body:
    fontFamily: 'Segoe UI'
    fontSize: 12px # [ASSUMPTION: size inferred; source says Segoe UI only]
    fontWeight: '400'
  label:
    fontFamily: 'Segoe UI'
    fontSize: 11px # [ASSUMPTION: size inferred; source says Segoe UI only]
    fontWeight: '400'
  caption:
    fontFamily: 'Segoe UI'
    fontSize: 10px # [ASSUMPTION: size inferred; source says Segoe UI only]
    fontWeight: '400'
rounded:
  sm: 4px # [ASSUMPTION: radii scale inferred; source has no radii]
  md: 6px # [ASSUMPTION: radii scale inferred; source has no radii]
  lg: 8px # [ASSUMPTION: radii scale inferred; source has no radii]
  full: 9999px # [ASSUMPTION: pill reserved for badges; not in source]
spacing:
  # CustomTkinter defaults inherited; named gaps only.
  gutter: 12px # [ASSUMPTION: gap scale inferred; source has body grid only]
  section-gap: 16px # [ASSUMPTION: gap scale inferred; source has body grid only]
  window-min-width: 900px
  window-min-height: 700px
components:
  unsafe-gate-checkbox:
    font: '{typography.body}'
    behavior-ref: 'EXPERIENCE.md Component Patterns unsafe-gate-checkbox'
  unsafe-armed-banner:
    background: '{colors.warning-amber}'
    foreground: '{note: Windows/CustomTkinter near-black text on amber — AAA pair recorded at build (light) and dark-theme pair recorded at build (dark)}'
    radius: '{rounded.md}'
    icon: 'text+icon, never color-only'
    banner-copy: 'UNSAFE ARMED — Freeze/Patch can corrupt saves. Restores on clean quit only; killing the app may leave game memory changed. Offline games only.'
    placement: 'sticky header row above body grid, always visible; compact armed chip mirrored adjacent to Freeze ON and Patch writer'
  button-primary:
    background: '{colors.brand-accent}'
    foreground: '{note: Windows/CustomTkinter text on accent — AA pair recorded at build per theme}'
    radius: '{rounded.md}'
  value-row:
    font: '{typography.body}'
    radius: '{rounded.sm}'
    layout: 'label: value [type] conf=0.XX'
---

## Brand & Style

Vision Trainer is a solo Windows desktop utility for offline games only: screenshot, extract, scan, write once, verify, persist to Profile + RUNBOOK. The aesthetic posture is system-native — follow Windows light/dark via CustomTkinter 6.0.0 drop-in (per research + user decision), minimal brand color, correct Windows HiDPI, PyInstaller one-dir retained. Tauri rejected per research.

This DESIGN.md specifies only the brand-layer deltas on top of CustomTkinter. The 80% that ships from CustomTkinter (buttons, entries, comboboxes, listboxes, dialogs, modal) inherits CustomTkinter/Windows visuals as-is. Customizing beyond the deltas is explicitly against the discipline — the platform owns the rendered values.

## Colors

System-native surfaces inherit Windows theme via CustomTkinter appearance mode. No custom surface tokens. Brand layer is two colors plus destructive:

- **Brand accent (`{colors.brand-accent}` light / `{colors.brand-accent-dark}` dark)** [ASSUMPTION: hex values inferred] — restrained use only: primary action emphasis, Setup save confirmation. Never for warnings or destructive. Minimal brand color per user decision.
- **Warning amber (`{colors.warning-amber}` light / `{colors.warning-amber-dark}` dark)** [ASSUMPTION: hex values inferred] — reserved exclusively for the UNSAFE armed-warning state (Freeze/Patch enabled after first-run acknowledgement). Always text+icon, never color-only per assumption/decision.
- **Destructive (`{colors.destructive}` light / `{colors.destructive-dark}` dark)** [ASSUMPTION: hex values inferred] — error dialogs only (`Attach/Capture/Extract/Scan/Verify/Runbook/Patch failed`). Never decorative.
- **All surfaces, borders, inputs, listbox rows** inherit CustomTkinter/Windows theme. If the brand cannot justify overriding a token, it does not override it.

Avoid: custom dark palette, gradient surfaces, chromatic flourishes, accent for state badges outside UNSAFE.

## Typography

Segoe UI via CustomTkinter for all roles (per assumption). No brand font swap.

- **Title (`{typography.title}`)** — window title only: "Vision Trainer (offline games only)".
- **Heading (`{typography.heading}`)** — section labels in the single-window body grid (Setup, Process, Capture, Extract, Adjust, Verify, Extras).
- **Body (`{typography.body}`)** — entries, comboboxes, listbox rows (`label: value [type] conf=0.XX`), log line.
- **Label (`{typography.label}`)** — field labels, Mode (`one_shot/freeze/display`), drafts `Verified:` / `Unverified:` icon+text prefixes.
- **Caption (`{typography.caption}`)** — status line (`{n} models found`, `OK — {n} models`, `Failed: {exc}`, `Endpoint unreachable: {exc}`), fallback notes.

[ASSUMPTION: all px sizes inferred; source specifies Segoe UI only, no ramp.]

## Layout & Spacing

Single-window all-sections-visible layout kept (no step nav in as-built main.py), minimum 900x700, resizable beyond minimum with a scrollable body grid (125/150/200% Windows scaling verified, no loss or overlap; rows scale with system text size). Header row + log + body grid. Setup is a modal with `Tab` trap + focus return; Settings re-opens it (FR-1). Allowed dialogs: `askyesno`/`showerror`/`showinfo` + Export save dialog — no other second windows.

`{spacing.gutter}` between controls, `{spacing.section-gap}` between sections [ASSUMPTION: gap values inferred]. Listbox heights preserved from as-built: PID-name list h6, values list h8, drafts list h5. Wishlist entry default `health,stamina,money`. HiDPI correct via CustomTkinter; no custom DPI handling.

## Elevation & Depth

Inherited from CustomTkinter/Windows — subtle dialog elevation only. No elevation as hierarchy device. Brand adds nothing; CustomTkinter shadows are correct.

## Shapes

`{rounded.sm}` for entries/inputs/value rows, `{rounded.md}` for buttons/cards including `{components.button-primary}` and `{components.unsafe-armed-banner}`, `{rounded.lg}` for Setup modal [ASSUMPTION: radii scale inferred; source has no radii]. `{rounded.full}` appears only on status badges, if any. No custom corner logic.

## Components

CustomTkinter components used as-is, unchanged: Button, Entry, Combobox, Listbox, Checkbutton, Dialog, Label. Brand-layer deltas:

- **Button (primary)** — `{components.button-primary}`: `{colors.brand-accent}` fill, `{rounded.md}` corner; foreground per platform-convention note (AA pair recorded at build). Other variants inherit CustomTkinter defaults.
- **UNSAFE armed banner** — `{components.unsafe-armed-banner}`: sticky header placement, exact banner copy, mirrored armed chips at Freeze ON and Patch writer; `{colors.warning-amber}` + text+icon, never color-only.
- **Value row** — `{components.value-row}`: `label: value [type] conf=0.XX` in `{typography.body}`; editable variant keeps identical row visual, edit via field with Apply/discard + dirty marker.
- **UNSAFE gate checkbox** — `{components.unsafe-gate-checkbox}`: split Freeze vs Patch gates in Setup; per-session re-arm; explicit Disarm; per-launch persistence only (see EXPERIENCE.md).

## Do's and Don'ts

| Do | Don't |
|---|---|
| Inherit CustomTkinter/Windows surfaces, dark mode, HiDPI as-is | Override surface/border/input tokens beyond accent + amber + red |
| Use `{colors.brand-accent}` sparingly for primary emphasis | Use accent for warnings or errors |
| Use `{colors.warning-amber}` only for UNSAFE armed state, always with text+icon | Use amber decoratively or color-only |
| Keep single window 900x700 min, resizable with scrollable grid, header + log + body grid | Add step nav, overlays, hotkey surfaces, second windows beyond modal + allowed dialogs |
| Keep default ttk→CustomTkinter widget visuals; specify deltas only | Invent a custom theme, fonts, or color system |
