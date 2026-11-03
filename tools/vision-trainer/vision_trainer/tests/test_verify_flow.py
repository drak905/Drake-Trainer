"""Story 2.5: verify verdict dialog + persistence gating (offline)."""
import os
import sys
import tempfile

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

tk = pytest.importorskip("tkinter")


def _verify_app(monkeypatch, temp_dir):
    from unittest.mock import MagicMock
    import vision_trainer.main as main_mod
    monkeypatch.setattr(main_mod.ce_client, "CEBridge",
                        lambda *a, **k: MagicMock())
    cfg = {"endpoint": "http://localhost:20128/v1",
           "vision_model": "v", "adjust_model": "a"}
    monkeypatch.setattr(main_mod.config_mod, "load_config",
                        lambda *a, **k: cfg)
    try:
        app = main_mod.App()
    except tk.TclError:
        try:
            app = main_mod.App()
        except tk.TclError as first:
            raise first
    app.withdraw()
    app.state.runbook_dir = temp_dir
    app.state.profiles_dir = temp_dir
    app.state.before_b64 = "QUJD"
    app.state.write_result = {"target_value": 50000, "address": "0x100",
                               "value_type": "dword", "trace": []}
    app.state.process_name = "solo_rpg.exe"
    app.state.selected = {"label": "gold", "value": 500,
                           "value_type": "dword", "confidence": 0.9}
    monkeypatch.setattr(
        main_mod.ce_client, "find_game_window",
        lambda bridge, title=None: {"handle": "0x2"})
    monkeypatch.setattr(
        main_mod.ce_client, "get_window_rect",
        lambda bridge, handle: {"x": 0, "y": 0, "width": 800,
                                 "height": 600})
    monkeypatch.setattr(main_mod.screenshot, "capture_game_window",
                        lambda rect, **k: "REYB")
    monkeypatch.setattr(
        main_mod.llm_client, "verify_value",
        lambda *a, **k: {"observed": "50,000", "match": True})
    return app


def test_verify_yes_persists_runbook_and_profile(monkeypatch):
    with tempfile.TemporaryDirectory() as d:
        import vision_trainer.main as main_mod
        app = _verify_app(monkeypatch, d)
        try:
            infos = []
            errors = []
            asks = []
            monkeypatch.setattr(main_mod.messagebox, "showinfo",
                                lambda *a, **k: infos.append(a))
            monkeypatch.setattr(main_mod.messagebox, "showerror",
                                lambda *a, **k: errors.append(a))

            def fake_askyesno(*a, **k):
                asks.append((a, k))
                return True
            monkeypatch.setattr(main_mod.messagebox, "askyesno",
                                fake_askyesno)
            app.verify()
            assert any("Verify: observed=50,000 match=True" in line
                       for line in app.log.get("1.0", "end")
                       .splitlines())
            assert asks and asks[0][1].get("default") == "no"
            assert "RUNBOOK updated:" in app.log.get("1.0", "end")
            assert asks[0][0][1] == main_mod.VERIFY_CONFIRM_TEMPLATE.format(
                observed="50,000", expected=50000)
            rb = os.path.join(d, "solo_rpg.exe.md")
            assert os.path.exists(rb)
            assert app.state.stage == "done"
            assert infos, "Done dialog expected after persistence"
        finally:
            app.destroy()


def test_verify_no_returns_to_refine(monkeypatch):
    with tempfile.TemporaryDirectory() as d:
        import vision_trainer.main as main_mod
        app = _verify_app(monkeypatch, d)
        try:
            monkeypatch.setattr(main_mod.messagebox, "askyesno",
                                lambda *a, **k: False)
            app.verify()
            assert app.state.stage == "refine"
            assert "Back to refine: re-capture or re-narrow the scan." \
                in app.log.get("1.0", "end")
            assert not os.path.exists(
                os.path.join(d, "solo_rpg.exe.md"))
            assert not os.path.exists(
                os.path.join(d, "solo_rpg.exe.json"))
            assert app.state.write_result is not None
        finally:
            app.destroy()


def test_verify_without_write_gates(monkeypatch):
    with tempfile.TemporaryDirectory() as d:
        import vision_trainer.main as main_mod
        app = _verify_app(monkeypatch, d)
        try:
            infos = []
            monkeypatch.setattr(main_mod.messagebox, "showinfo",
                                lambda *a, **k: infos.append(a))
            app.state.write_result = None
            app.verify()
            assert infos and infos[0][1] == "Adjust a value first."
            assert not os.path.exists(
                os.path.join(d, "solo_rpg.exe.md"))
        finally:
            app.destroy()


def test_verify_confirm_copy_is_exact():
    import vision_trainer.main as main_mod
    assert main_mod.VERIFY_CONFIRM_TEMPLATE.format(
        observed="50,000", expected=50000) == (
        "Value now shows 50,000 (expected 50000). Correct?")
