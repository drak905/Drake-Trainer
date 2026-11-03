- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-launch-the-app-shell-on-real-windows.md`
  summary: SetupDialog refresh/test/save run synchronous network calls on the Tk main thread with no re-entrancy guard.
  evidence: Blind review pass on 1.1; UI blocks during endpoint probes on slow/unreachable servers; fix is threading or async probe, larger than a simple correction.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-launch-the-app-shell-on-real-windows.md`
  summary: os.startfile-based View Runbook / Open Profiles Folder have no error handling or non-Windows fallback.
  evidence: Blind review pass on 1.1; Windows-only is the v1 target per PRD, but a missing association will raise TclError-less OSError to the user.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-launch-the-app-shell-on-real-windows.md`
  summary: promote_draft has a dead `if not draft.get("verified"): pass` branch and promotes unverified drafts without confirmation.
  evidence: Blind review pass on 1.1; flows into story 3.4 scope (promote gating) rather than 1.1.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-offline-only-refuse-gate.md`
  summary: Short anticheat tokens (eac, vgc) can false-positive on benign process/module names; no allowlist escape hatch.
  evidence: Blind review pass on 1.3; `_norm("eac") in _norm("peace.exe")` matches; best-effort heuristics accepted by PRD assumption, allowlist design needs a user-facing decision.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-offline-only-refuse-gate.md`
  summary: Gate ignores module entries without a `name` key and window titles hinting multiplayer/launchers.
  evidence: Blind review pass on 1.3; bridge schema variants would silently pass; title coverage is cheap but touches gate copy.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-offline-only-refuse-gate.md`
  summary: locked_pids grows unbounded, has no clear/unlock API, and survives OS PID reuse.
  evidence: Blind review pass on 1.3; acceptable for a single session but a reuse refresh belongs with Epic 3/4 UX work.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-attach-to-the-game-process.md`
  summary: PID-to-name resolution is duplicated between flow._resolve_pid_name and ce_client.resolve_process_selection/get_process_list.
  evidence: Blind review pass on 2.1; consolidation changes miss semantics (silent "" vs LookupError) and should be a deliberate refactor.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-attach-to-the-game-process.md`
  summary: Numeric PID attach cannot verify the name when get_process_list fails or omits the PID (fail-open bypass).
  evidence: Blind review pass on 2.1; fail-closed vs fail-open is a product decision; heuristics are best-effort per PRD assumption.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-attach-to-the-game-process.md`
  summary: TOCTOU between pre-attach process-list lookup and open_process is unverified post-attach (passive second lookup would restore the check).
  evidence: Blind review pass on 2.1; get_opened_process_id returns only a PID, so only a second get_process_list could close the window.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-1-attach-to-the-game-process.md`
  summary: attach_process/check_offline_gate keep a vestigial `modules` parameter; the app never passes it, so the pre-attach module gate is unreachable from the UI.
  evidence: Blind review pass on 2.1; intended semantics for re-attach-over-session need deciding before removal.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-extract-values-and-edit-them.md`
  summary: Hex input (0x...) unsupported in the edit field; CE-centric users habitually type hex for integer values.
  evidence: Blind review pass 2.3; decimal-only is the recorded behavior for now; product decision whether hex parsing belongs in v1.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-extract-values-and-edit-them.md`
  summary: No per-type range bounds on Apply (byte 300, negative values accepted) and CE types beyond byte/word/dword/qword fall through to float parsing.
  evidence: Blind review pass 2.3; later failure surfaces at CE write time; bounds list needs the full CE type table.
- source_spec: `_bmad-output/implementation-artifacts/spec-2-3-extract-values-and-edit-them.md`
  summary: Stale uncommitted marker persists after row switch, and switching rows silently discards in-progress typed text (no warning).
  evidence: Blind review pass 2.3; needs UX decision on whether in-progress edits survive selection changes; deferred pending that call.
