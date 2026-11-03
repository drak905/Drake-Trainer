"""Story 3.1: atomic profile saves + anchor ladder + gated re-apply.
Also covers Story 3.2 validate-profile and Story 3.4 drafts/promote."""
import json
import os
import sys
import tempfile
import unittest.mock

from unittest.mock import MagicMock

from vision_trainer import anchor as anchor_mod
from vision_trainer import flow as flow_mod
from vision_trainer import profiles as profiles_mod


class FakeBridge:
    def __init__(self, script):
        self.script = list(script)
        self.calls = []

    def send_command(self, method, params=None):
        self.calls.append((method, params or {}))
        expected, response = self.script.pop(0)
        assert method == expected, f"expected {expected}, got {method}"
        return response() if callable(response) else response


def cheat(**kw):
    base = {"label": "gold", "value_type": "dword",
            "anchor": None, "last_address": "0x9999",
            "module_offset": "", "signature": None,
            "target_value": 5000}
    base.update(kw)
    return base


def test_save_is_atomic_on_failure():
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "game.json")
        original = {"schema": 1, "exe": "game.exe", "cheats": [
            {"label": "gold", "target_value": 1}]}
        profiles_mod.save(path, dict(original))
        before = open(path, encoding="utf-8").read()
        assert "gold" in before

        import os as _os
        real_replace = _os.replace

        def broken_replace(tmp, dst):
            raise OSError("disk full")
        _os.replace = broken_replace
        try:
            try:
                profiles_mod.save(path, {"schema": 1, "exe": "x",
                                          "cheats": []})
                saved = False
            except OSError:
                saved = False
        finally:
            _os.replace = real_replace
        after = open(path, encoding="utf-8").read()
        assert before == after
        assert "gold" in after


def test_ambiguous_signature_falls_through_to_chain():
    bridge = FakeBridge([
        ("aob_scan_module_unique",
         {"success": False, "error": "matched 3 times", "count": 3}),
        ("read_pointer_chain",
         {"success": True, "final_address": "0x5000"}),
        ("validate_pointer_chains",
         {"success": True, "matches": [{"final": "0x5000"}]}),
        ("read_integer", {"success": True, "value": 42}),
    ])
    out = anchor_mod.resolve_anchor(
        bridge,
        cheat(anchor={"signature": "AA", "module": "game.exe", "offset": 0,
                      "pointer_chain": {"base": "b", "offsets": []}}),
        expected_value=42)
    assert out["level"] == "pointer_chain"


def test_ambiguous_signature_without_ladder_raises():
    bridge = FakeBridge([
        ("aob_scan_module_unique",
         {"success": False, "error": "matched 3 times", "count": 3}),
    ])
    try:
        anchor_mod.resolve_anchor(
            bridge, cheat(anchor={"signature": "AA", "module": "a"})
        )
        raised = ""
    except anchor_mod.AmbiguousSignature as exc:
        raised = str(exc)
    assert "refusing to guess" in raised


def _flow_state(bridge, temp_dir):
    return flow_mod.FlowState(bridge=bridge, config={
        "endpoint": "http://localhost:20128/v1",
        "vision_model": "v", "adjust_model": "a"},
        runbook_dir=temp_dir, profiles_dir=temp_dir)


def test_reapply_writes_only_on_confirm():
    with tempfile.TemporaryDirectory() as d:
        path = profiles_mod.resolve_path("game.exe", base_dir=d)
        profiles_mod.save(path, {"schema": 1, "exe": "game.exe", "cheats": [
            cheat(anchor={"module_offset": "game.exe+1234"})]})
        bridge = FakeBridge([
            ("get_symbol_address",
             {"success": True, "address": "0x2000"}),
            ("read_integer", {"success": True, "value": 5000}),
            ("read_integer", {"success": True, "value": 5}),
            ("write_integer", {"success": True}),
        ])
        state = _flow_state(bridge, d)
        state.process_name = "game.exe"
        state.process_id = 1
        seen = {}

        def writer(details):
            seen.update(details)
            return True
        results = state.reapply_profile(writer=writer)
        assert results == [{"label": "gold", "address": "0x2000",
                             "level": "module_offset",
                             "status": "written"}]
        assert seen["old_value"] == 5
        assert seen["new_value"] == 5000
        assert any(m == "write_integer" for m, _ in bridge.calls)


def test_reapply_never_auto_writes_and_skips_on_refusal():
    with tempfile.TemporaryDirectory() as d:
        path = profiles_mod.resolve_path("game.exe", base_dir=d)
        profiles_mod.save(path, {"schema": 1, "exe": "game.exe", "cheats": [
            cheat(anchor={"module_offset": "game.exe+1234"})]})
        bridge = FakeBridge([
            ("get_symbol_address",
             {"success": True, "address": "0x2000"}),
            ("read_integer", {"success": True, "value": 5000}),
            ("read_integer", {"success": True, "value": 5}),
        ])
        state = _flow_state(bridge, d)
        state.process_name = "game.exe"
        state.process_id = 1
        results = state.reapply_profile(writer=lambda d_: False)
        assert results[0]["status"] == "skipped_user"
        assert "write_integer" not in [m for m, _ in bridge.calls]

        state2 = _flow_state(bridge, d)
        try:
            state2.reapply_profile()
            errored = False
        except ValueError:
            errored = True
        assert errored


def test_reapply_reports_ambiguous_without_guessing():
    with tempfile.TemporaryDirectory() as d:
        path = profiles_mod.resolve_path("game.exe", base_dir=d)
        profiles_mod.save(path, {"schema": 1, "exe": "game.exe", "cheats": [
            cheat(anchor={"signature": "AA", "module": "a"})]})
        bridge = FakeBridge([
            ("aob_scan_module_unique",
             {"success": False, "error": "matched 3", "count": 3}),
        ])
        state = _flow_state(bridge, d)
        state.process_name = "game.exe"
        state.process_id = 1
        results = state.reapply_profile(writer=lambda d_: True)
        assert results[0]["status"] == "ambiguous"
        assert "write" not in [m for m, _ in bridge.calls]


def test_validate_profile_pass_and_fail_rows():
    with tempfile.TemporaryDirectory() as d:
        path = profiles_mod.resolve_path("game.exe", base_dir=d)
        profiles_mod.save(path, {"schema": 1, "exe": "game.exe", "cheats": [
            {"label": "gold", "value_type": "dword", "mode": "one_shot",
             "anchor": {"module_offset": "game.exe+1234"},
             "target_value": 5000},
            {"label": "hp", "value_type": "weird", "mode": "frobnicate",
             "anchor": {"capture_mode": "x"}, "target_value": 3},
            {"label": "mana", "value_type": "dword", "mode": "one_shot",
             "anchor": None, "target_value": None},
        ]})
        report = profiles_mod.validate_profile(path)
        assert report["schema_ok"] is True
        statuses = {r["label"]: r["status"] for r in report["cheats"]}
        assert statuses["gold"] == "pass"
        assert statuses["hp"] == "fail"
        assert any("bad value_type" in p for p in
                   [row["problems"] for row in report["cheats"]
                    if row["label"] == "hp"][0])
        mana = [row for row in report["cheats"]
                if row["label"] == "mana"][0]
        assert "missing anchor" in mana["problems"]
        assert "missing target_value" in mana["problems"]


def test_validate_profile_missing_file_and_corrupt():
    with tempfile.TemporaryDirectory() as d:
        report = profiles_mod.validate_profile(
            os.path.join(d, "nope.json"))
        assert report["exists"] is False
        assert "No profile file." in report["summary"]
        path = os.path.join(d, "broken.json")
        with open(path, "w") as f:
            f.write("{not json")
        report = profiles_mod.validate_profile(path)
        assert report["schema_ok"] is False
        assert "unreadable" in report["summary"]


def test_validate_profile_edge_shapes():
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "shapes.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"schema": 2, "exe": "x", "cheats": ["gold", 42]}, f)
        report = profiles_mod.validate_profile(path)
        assert report["schema_ok"] is False
        assert "schema not v1" in report["summary"]
        assert len(report["cheats"]) == 2
        assert all(r["status"] == "fail" for r in report["cheats"])
        path2 = os.path.join(d, "nolist.json")
        with open(path2, "w", encoding="utf-8") as f:
            json.dump({"schema": 1}, f)
        report2 = profiles_mod.validate_profile(path2)
        assert report2["cheats"] == []
        assert "no cheats list" in report2["summary"]


def test_validate_profile_never_modifies():
    with tempfile.TemporaryDirectory() as d:
        path = profiles_mod.resolve_path("game.exe", base_dir=d)
        profiles_mod.save(path, {"schema": 1, "exe": "game.exe", "cheats": [
            {"label": "gold", "value_type": "dword", "mode": "one_shot",
             "anchor": {"module_offset": "game.exe+1234"},
             "target_value": 5000}]})
        before = open(path).read()
        profiles_mod.validate_profile(path)
        assert open(path).read() == before


def test_signature_export_is_functional_value_write():
    c = {"label": "gold", "value_type": "dword", "mode": "one_shot",
         "anchor": {"signature": "48 89 5C 24 ??", "module": "game.exe",
                    "offset": 4},
         "target_value": 500000}
    entries, skipped = profiles_mod.export_ct_entries([c])
    assert skipped == []
    script = entries[0]["script"]
    assert "[ENABLE]" in script and "[DISABLE]" in script
    assert "dd 500000" in script
    assert "TODO" not in script
    assert "sig_gold+4" in script


def test_runbook_format_uses_multiplier():
    from vision_trainer import runbook as runbook_mod
    entry = {"label": "gold", "multiplier": 33, "process": "game.exe",
             "scan_recipe": {}, "window_title": "", "observed_value": 500,
             "target_value": 16500, "value_type": "dword",
             "address": "0x100", "module_offset": "", "vision_model": "v",
             "adjust_model": "a", "endpoint": "e", "verified": True}
    text = runbook_mod.format_entry(entry, now="2026-10-02 12:00")
    assert "×33" in text
    assert "×100" not in text


def _stub_app(main_mod):
    import tkinter as tk
    main_mod.ce_client.CEBridge = lambda *a, **k: MagicMock()
    cfg = {"endpoint": "http://localhost:20128/v1",
           "vision_model": "v", "adjust_model": "a"}
    main_mod.config_mod.load_config = lambda *a, **k: cfg
    try:
        app = main_mod.App()
    except tk.TclError:
        try:
            app = main_mod.App()
        except tk.TclError as first:
            raise first
    app.withdraw()
    return app


def test_draft_rows_signal_verified_and_unverified():
    from vision_trainer import factory as factory_mod
    draft_one = {"label": "gold", "category": "money",
                 "value": 500, "value_type": "dword", "mode": "one_shot",
                 "verified": False, "look_for": "Open inventory"}
    draft_two = dict(draft_one, label="hp", category="health",
                     verified=True)
    with tempfile.TemporaryDirectory() as d:
        import vision_trainer.main as main_mod
        with unittest.mock.patch.object(
                main_mod.factory_mod, "draft_cheats",
                return_value=([draft_one, draft_two], [])), \
                unittest.mock.patch.object(
                main_mod.factory_mod, "write_drafts",
                return_value=os.path.join(d, "g.draft.json")):
            app = _stub_app(main_mod)
            try:
                app.state.process_name = "game.exe"
                app.state.values = [
                    {"label": "Gold", "value": 500,
                     "value_type": "dword", "confidence": 0.9},
                    {"label": "HP", "value": 100,
                     "value_type": "dword", "confidence": 0.9}]
                app.draft_cheats()
                rows = [app.drafts_list.get(i) for i in range(2)]
                assert rows[0].startswith("⚠️ Unverified: gold")
                assert rows[1].startswith("✅ Verified: hp")
            finally:
                app.destroy()


def test_promote_refuses_unverified_draft():
    import vision_trainer.main as main_mod
    with tempfile.TemporaryDirectory() as d:
        app = _stub_app(main_mod)
        try:
            infos = []
            main_mod.messagebox.showinfo = \
                lambda *a, **k: infos.append(a)
            app.state.process_name = "game.exe"
            app.state.profiles_dir = d
            app.state.drafts = [{"label": "gold", "verified": False,
                                 "mode": "one_shot"}]
            app.drafts_list.insert("end", "⚠️ Unverified: gold")
            app.drafts_list.selection_set(0)
            drafts_before = list(app.state.drafts)
            with unittest.mock.patch.object(
                    main_mod.factory_mod, "promote_draft",
                    side_effect=AssertionError("must not promote")):
                app.promote_draft()
            assert infos and "unverified" in infos[0][1].lower()
            assert app.state.drafts == drafts_before
            assert not os.path.exists(
                profiles_mod.resolve_path("game.exe", base_dir=d))
        finally:
            app.destroy()


def test_promote_verified_draft_writes_and_logs():
    import vision_trainer.main as main_mod
    with tempfile.TemporaryDirectory() as d:
        app = _stub_app(main_mod)
        try:
            infos = []
            with unittest.mock.patch.object(
                    main_mod.messagebox, "showinfo",
                    lambda *a, **k: infos.append(a)):
                app.state.process_name = "game.exe"
                app.state.profiles_dir = d
                draft = {"label": "gold", "verified": True,
                         "mode": "one_shot", "value_type": "dword",
                         "target_value": 5000, "look_for": "check"}
                app.state.drafts = [draft]
                app.drafts_list.insert("end", "✅ Verified: gold")
                app.drafts_list.selection_set(0)
                app.promote_draft()
            assert "Promoted gold to live profile." in \
                app.log.get("1.0", "end")
            cheat = profiles_mod.get_cheat(
                profiles_mod.resolve_path("game.exe", base_dir=d), "gold")
            assert cheat and cheat["target_value"] == 5000
        finally:
            app.destroy()
