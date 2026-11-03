---
title: '4-1-per-session-unsafe-gates-and-armed-banner'
type: 'feature'
created: '2026-10-02'
status: 'done'
route: 'oneshot'
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No UNSAFE gating exists — Freeze ON / Patch writer are always clickable, so one misclick writes game memory with no acknowledgement; the story AC requires split per-session Freeze/Patch gates and a sticky armed banner with exact copy.

**Approach:** Add split acknowledgement checkboxes (Freeze/Patch) to the Setup modal with per-launch persistence only, an explicit Disarm in Extras, and a sticky armed banner + mirrored armed chips; gate the write controls on their respective gates.

## Implementation Notes

- Constants: UNSAFE_BANNER_COPY (exact AC copy), FREEZE_ACK_COPY/PATCH_ACK_COPY (risk + per-session re-arm wording).
- SetupDialog: UNAFE gates LabelFrame with split checkboxes, seeded from App acks; open_settings commits acks then logs `UNSAFE armed — Freeze/Patch enabled for this session.` when armed via Save.
- App: _writes_ok (refuse gate) initialized in __init__ fail-safe; _refresh_controls combines writes_ok × acks; banner packed sticky under header only while armed (sole amber use, text+icon); armed chips 🔶 appended to Freeze ON + Patch writer; Disarm UNSAFE stops active freezes with restore logging and clears both gates.
- Defense-in-depth: freeze_on/patch_writer re-check their acks programmatically.
- Tests: gates disabled by default, arm enables + banner/chips, disarm clears + disables + banner hidden, per-launch defaults, banner copy exact.
- Offline gate: 213 passed, 4 deselected.
- Review pass: blind-hunter N=3. Patched: disarm stops live freezes, in-method gate checks, ack commit only on Save, arming log, fail-closed _writes_ok, stable header reference, re-arm wording. Deferred: banner glyph unification with chips, docs/runbook copy updates, SetupDialog ack round-trip test, one-ack-only matrix test.

