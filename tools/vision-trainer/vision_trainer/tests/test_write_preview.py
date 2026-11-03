"""Story 2.4: multiplier plan + write-preview gating + ladder anchor output."""
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import scan_flow
from vision_trainer import llm_client


class FakeBridge:
    def __init__(self, script):
        self.script = list(script)
        self.calls = []

    def send_command(self, method, params=None):
        self.calls.append((method, params or {}))
        if not self.script:
            raise AssertionError(f"unexpected call {method}")
        expected, response = self.script.pop(0)
        assert method == expected, f"expected {expected}, got {method}"
        return response() if callable(response) else response


def test_multiplier_validation_copy():
    from vision_trainer import main as main_mod

    app = _stub_app(main_mod)
    try:
        for bad in ("abc", "0", "-5", "1000001"):
            app.mult_var.set(bad)
            try:
                app._read_multiplier()
                raised = ""
            except ValueError as exc:
                raised = str(exc)
            assert "Multiplier must be a number from 1 to 1000000." \
                in raised, bad
        for good in ("1", "100", "1000000", "2.5"):
            app.mult_var.set(good)
            assert app._read_multiplier() == float(good)
    finally:
        app.destroy()


def test_adjust_invalid_multiplier_shows_exact_copy(monkeypatch):
    import vision_trainer.main as main_mod
    app = _stub_app(main_mod)
    try:
        errors = []
        infos = []
        monkeypatch.setattr(main_mod.messagebox, "showerror",
                            lambda *a, **k: errors.append(a))
        monkeypatch.setattr(main_mod.messagebox, "showinfo",
                            lambda *a, **k: infos.append(a))
        app.state.values = [
            {"label": "gold", "value": 500, "value_type": "dword",
             "confidence": 0.9}]
        app.values_list.insert("end", "gold: 500 [dword] conf=0.90")
        app.values_list.selection_set(0)
        app.mult_var.set("abc")
        app.adjust()
        assert len(errors) == 1 and len(infos) == 0
        assert errors[0][1] == \
            "Multiplier must be a number from 1 to 1000000."
        assert app.state.write_result is None
    finally:
        app.destroy()


def test_adjust_cancel_confirms_no(monkeypatch):
    import vision_trainer.main as main_mod
    from unittest.mock import MagicMock
    app = _stub_app(main_mod)
    try:
        infos = []
        errors = []
        monkeypatch.setattr(main_mod.messagebox, "showerror",
                            lambda *a, **k: errors.append(a))
        monkeypatch.setattr(main_mod.messagebox, "showinfo",
                            lambda *a, **k: infos.append(a))
        monkeypatch.setattr(main_mod.llm_client, "compute_write_plan",
                            MagicMock(side_effect=RuntimeError("down")))
        monkeypatch.setattr(main_mod.scan_flow, "adjust_to_100x",
                            MagicMock(side_effect=main_mod.scan_flow.
                                      WriteCancelled("cancel")))
        app.state.values = [
            {"label": "gold", "value": 500, "value_type": "dword",
             "confidence": 0.9}]
        app.values_list.insert("end", "gold: 500 [dword] conf=0.90")
        app.values_list.selection_set(0)
        app.mult_var.set("100")
        app.adjust()
        assert app.state.stage == "refine"
        assert "Back to refine: re-capture or re-narrow the scan." \
            in app.log.get("1.0", "end")
    finally:
        app.destroy()


def _stub_app(main_mod):
    from unittest.mock import MagicMock
    import tkinter as tk
    import vision_trainer.main as main_mod_
    main_mod_.ce_client.CEBridge = lambda *a, **k: MagicMock()
    cfg = {"endpoint": "http://localhost:20128/v1",
           "vision_model": "v", "adjust_model": "a"}
    main_mod_.config_mod.load_config = lambda *a, **k: cfg
    try:
        app = main_mod_.App()
    except tk.TclError as first:
        try:
            app = main_mod_.App()
        except tk.TclError:
            raise first
    app.withdraw()
    return app


def test_fallback_plan_uses_multiplier():
    plan = llm_client.fallback_write_plan("gold", 500, "dword",
                                          multiplier=7)
    assert plan["target_value"] == 3500
    assert plan["multiplier"] == 7


def test_model_plan_echoes_multiplier_payload():
    from unittest.mock import patch, MagicMock

    captured = {}

    def fake_post(url, json=None, timeout=60):
        captured["content"] = json["messages"][1]["content"]
        resp = MagicMock()
        resp.raise_for_status = lambda: None
        resp.json = lambda: {"choices": [{"message": {
            "content": '{"target_value": 3500, "value_type": "dword",'
                       ' "scan_option": "exact"}'}}]}
        return resp

    with patch("vision_trainer.config.requests.post", fake_post), \
            patch("vision_trainer.llm_client.requests.post", fake_post):
        plan = llm_client.compute_write_plan(
            "http://localhost:20128/v1", "m", "gold", 500, "dword",
            multiplier=7)
    assert plan["target_value"] == 3500
    assert plan["multiplier"] == 7
    assert '"multiplier": 7' in captured["content"]


def test_writer_cancel_aborts_before_write():
    bridge = FakeBridge([
        ("scan_all", {"success": True, "count": 1}),
        ("get_scan_results",
         {"success": True, "total": 1,
          "results": [{"address": "0x100", "value": "500"}]}),
    ])
    seen = {}
    try:
        scan_flow.adjust_to_100x(
            bridge, "gold", 500, "dword", target_value=5000,
            picker=lambda c: c[0],
            writer=lambda d: seen.update(d) or False)
    except scan_flow.WriteCancelled as exc:
        assert "0x100" in str(exc)
    assert "write_integer" not in [m for m, _ in bridge.calls]
    assert seen["address"] == "0x100"


def test_writer_approval_writes_and_anchors():
    bridge = FakeBridge([
        ("scan_all", {"success": True, "count": 1}),
        ("get_scan_results",
         {"success": True, "total": 1,
          "results": [{"address": "0x100", "value": "500"}]}),
        ("write_integer", {"success": True}),
        ("get_address_info",
         {"success": True, "symbolic_name": "game.exe+1234"}),
        ("generate_signature",
         {"success": True, "signature": "55 8B EC",
          "offset_from_start": 16}),
    ])
    out = scan_flow.adjust_to_100x(
        bridge, "gold", 500, "dword", target_value=5000,
        picker=lambda c: c[0], writer=lambda d: True)
    assert out["address"] == "0x100"
    assert out["module_offset"] == "game.exe+1234"
    assert out["signature"]["pattern"] == "55 8B EC"
    assert out["signature"]["module"] == "game.exe"


def test_preview_dialog_defaults_to_no():
    import tkinter as tk
    from vision_trainer import main as main_mod
    try:
        root = tk.Tk()
        root.withdraw()
    except tk.TclError:
        pytest.skip("no display available")
    try:
        dlg = main_mod.PreviewDialog(root, "Write preview", "line1")
        try:
            assert dlg.result is False
            dlg.approve()
            assert dlg.result is True
        finally:
            dlg.destroy()
        dlg2 = main_mod.PreviewDialog(root, "Write preview", "line1")
        try:
            dlg2.cancel()
            assert dlg2.result is False
        finally:
            dlg2.destroy()
    finally:
        root.destroy()
