"""Shell launch proof: App opens as the specified single window (offline)."""
import os
import sys
import unittest.mock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

tk = pytest.importorskip("tkinter")


def _make_app(monkeypatch):
    from unittest.mock import MagicMock

    import vision_trainer.main as main_mod
    monkeypatch.setattr(main_mod.ce_client, "CEBridge",
                        lambda *a, **k: MagicMock())
    cfg = {"endpoint": "http://localhost:20128/v1",
           "vision_model": "v", "adjust_model": "a"}
    monkeypatch.setattr(main_mod.config_mod, "load_config",
                        lambda *a, **k: cfg)
    app = main_mod.App()
    app.withdraw()
    return app


def test_app_window_shell(monkeypatch):
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        assert app.title() == "Vision Trainer (offline games only)"
        assert app.minsize()[0] >= 900 and app.minsize()[1] >= 700
        assert hasattr(app, "_scroll") and hasattr(app, "_canvas")
        assert app._canvas.cget("yscrollcommand")
        assert app._scroll.cget("command")
        assert app.log.cget("takefocus") in ("0", 0, "")
    finally:
        app.destroy()


def test_capture_falls_back_to_fullscreen(monkeypatch):
    import vision_trainer.main as main_mod
    from unittest.mock import MagicMock

    calls = {"rect": False}

    def boom(*a, **k):
        calls["rect"] = True
        raise ConnectionError("CE_API_UNAVAILABLE")

    monkeypatch.setattr(main_mod.ce_client, "get_window_rect", boom)
    monkeypatch.setattr(main_mod.screenshot, "fullscreen_rect",
                        lambda: {"x": 0, "y": 0, "width": 800,
                                 "height": 600})
    monkeypatch.setattr(main_mod.screenshot, "capture_game_window",
                        lambda rect, **k: "QUJD")
    try:
        app = _make_app(monkeypatch)
        app.proc_var.set("")
    except tk.TclError:
        pytest.skip("no display available")
    try:
        monkeypatch.setattr(
            main_mod.ce_client, "find_game_window",
            lambda bridge, title=None: {"handle": "0x1"})
        messagebox_calls = []
        monkeypatch.setattr(main_mod.messagebox, "showerror",
                            lambda *a, **k: messagebox_calls.append(a))
        app.capture()
        assert calls["rect"] is True
        assert app.state.before_b64 == "QUJD"
        assert app.state.window_handle == "0x1"
        assert messagebox_calls == []
        log_text = app.log.get("1.0", "end")
        assert "falling back to fullscreen 800x600" in log_text
        assert "Captured 800x600" in log_text
    finally:
        app.destroy()


def test_verify_uses_same_rect_fallback(monkeypatch):
    import vision_trainer.main as main_mod
    from unittest.mock import MagicMock

    monkeypatch.setattr(main_mod.ce_client, "get_window_rect",
                        MagicMock(side_effect=ConnectionError("down")))
    monkeypatch.setattr(main_mod.screenshot, "fullscreen_rect",
                        lambda: {"x": 0, "y": 0, "width": 800,
                                 "height": 600})
    monkeypatch.setattr(main_mod.screenshot, "capture_game_window",
                        lambda rect, **k: "REYB")
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        monkeypatch.setattr(
            main_mod.ce_client, "find_game_window",
            lambda bridge, title=None: {"handle": "0x2"})
        monkeypatch.setattr(main_mod.messagebox, "showerror",
                            lambda *a, **k: None)
        monkeypatch.setattr(main_mod.messagebox, "askyesno",
                            lambda *a, **k: False)
        monkeypatch.setattr(
            main_mod.llm_client, "verify_value",
            lambda *a, **k: {"observed": "500", "match": True})
        app.state.write_result = {"target_value": 500}
        app.state.before_b64 = "QUJD"
        app.verify()
        assert app.state.after_b64 == "REYB"
        assert "falling back to fullscreen 800x600" in app.log.get("1.0", "end")
    finally:
        app.destroy()


def _selected_row0(app):
    app.values_list.selection_clear(0, "end")
    app.values_list.selection_set(0)
    app.values_list.activate(0)


def _seed_values(app, monkeypatch):
    import vision_trainer.main as main_mod
    app.state.values = [
        {"label": "gold", "value": 500, "value_type": "dword",
         "confidence": 0.9}]
    app._pending_edits = set()
    app.values_list.delete(0, "end")
    app.values_list.insert("end", "gold: 500 [dword] conf=0.90")
    _selected_row0(app)
    errors = []
    monkeypatch.setattr(main_mod.messagebox, "showerror",
                        lambda *a, **k: errors.append(a))
    monkeypatch.setattr(main_mod.messagebox, "showinfo",
                        lambda *a, **k: errors.append(("info",) + a))
    return errors


def test_extract_rows_render_format(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        monkeypatch.setattr(
            main_mod.llm_client, "extract_values",
            lambda *a, **k: [{"label": "gold", "value": 500,
                              "value_type": "dword",
                              "confidence": 0.92}])
        app.state.before_b64 = "QUJD"
        app.extract()
        assert app.values_list.get(0) == "gold: 500 [dword] conf=0.92"
    finally:
        app.destroy()


def test_apply_edit_commits_and_plan_echoes(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        errors = _seed_values(app, monkeypatch)
        app.edit_var.set("600")
        app.apply_edit()
        assert errors == []
        assert app.state.values[0]["value"] == 600
        assert 0 not in app._pending_edits
        assert "edited" not in app.values_list.get(0)
        assert "Edit applied: gold = 600" in app.log.get("1.0", "end")
    finally:
        app.destroy()


def test_apply_edit_invalid_number_refused(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        errors = _seed_values(app, monkeypatch)
        app.edit_var.set("abc")
        app.apply_edit()
        assert len(errors) == 1
        assert "Edit — invalid integer: 'abc'" in errors[0][1]
        assert app.state.values[0]["value"] == 500
    finally:
        app.destroy()


def test_discard_edit_reverts_marker(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        _seed_values(app, monkeypatch)
        app.edit_var.set("600")
        app._on_edit_key(None)
        assert "edited (uncommitted)" in app.values_list.get(0)
        app.discard_edit()
        assert app.state.values[0]["value"] == 500
        assert "edited" not in app.values_list.get(0)
    finally:
        app.destroy()


def test_adjust_without_selection_shows_exact_copy(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        infos = []
        monkeypatch.setattr(main_mod.messagebox, "showinfo",
                            lambda *a, **k: infos.append(a))
        app.state.values = []
        app.adjust()
        assert infos and infos[0][1] == "Select a value first."
    finally:
        app.destroy()


def test_extract_resets_pending_after_new_extract(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        _seed_values(app, monkeypatch)
        app.edit_var.set("999")
        app._on_edit_key(None)
        assert 0 in app._pending_edits
        monkeypatch.setattr(
            main_mod.llm_client, "extract_values",
            lambda *a, **k: [{"label": "gold", "value": 500,
                              "value_type": "dword",
                              "confidence": 0.9}])
        app.state.before_b64 = "QUJD"
        app.extract()
        assert isinstance(app._pending_edits, set)
        assert app._pending_edits == set()
        _selected_row0(app)
        app.edit_var.set("600")
        app._on_edit_key(None)
        assert 0 in app._pending_edits
    finally:
        app.destroy()


def test_on_value_select_prefills_edit_entry(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        _seed_values(app, monkeypatch)
        app.state.values.append({"label": "hp", "value": 80,
                                 "value_type": "dword",
                                 "confidence": 0.8})
        app.values_list.insert("end", "hp: 80 [dword] conf=0.80")
        app.edit_var.set("")
        app.values_list.selection_clear(0, "end")
        app.values_list.selection_set(1)
        app._on_value_select(None)
        assert app.edit_var.get() == "80"
    finally:
        app.destroy()


def test_unsafe_gates_disable_then_arm_banner(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        assert str(app.freeze_on_btn.cget("state")) == "disabled"
        assert str(app.patch_btn.cget("state")) == "disabled"
        app.freeze_ack = True
        app.patch_ack = True
        app._refresh_controls()
        assert str(app.freeze_on_btn.cget("state")) == "normal"
        assert str(app.patch_btn.cget("state")) == "normal"
        assert "ARMED" in app.freeze_on_btn.cget("text")
        assert "ARMED" in app.patch_btn.cget("text")
        assert app.unsafe_banner.winfo_manager()
        assert "Freeze/Patch can corrupt saves" in \
            app.unsafe_banner.cget("text")
        app.disarm_unsafe()
        assert app.freeze_ack is False and app.patch_ack is False
        assert str(app.freeze_on_btn.cget("state")) == "disabled"
        assert not app.unsafe_banner.winfo_manager()
    finally:
        app.destroy()


def test_setup_acks_are_per_launch(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        assert app.freeze_ack is False and app.patch_ack is False
    finally:
        app.destroy()


def test_unsafe_banner_copy_is_exact():
    import vision_trainer.main as main_mod
    assert main_mod.UNSAFE_BANNER_COPY == (
        "UNSAFE ARMED — Freeze/Patch can corrupt saves. Restores on "
        "clean quit only; killing the app may leave game memory changed. "
        "Offline games only.")


def test_freeze_snapshot_bound_and_gated(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        infos = []
        monkeypatch.setattr(main_mod.messagebox, "showinfo",
                            lambda *a, **k: infos.append(a))
        # without a completed write, freeze refuses regardless of selection
        app.state.values = [{"label": "hp", "value": 10,
                             "value_type": "dword", "confidence": 0.9}]
        app.values_list.insert("end", "hp: 10 [dword] conf=0.90")
        app.values_list.selection_set(0)
        app.freeze_ack = True
        app.freeze_on()
        assert infos and infos[0][1] == "Adjust a value first."
        # with a completed write, changing selection never retargets
        app.state.write_result = {"address": "0xABC", "label": "gold",
                                   "target_value": 5000,
                                   "value_type": "dword"}
        app.values_list.delete(0, "end")
        app.values_list.insert("end", "gold: 5000 [dword] conf=0.99")
        app.values_list.selection_set(0)
        with unittest.mock.patch.object(
                main_mod, "PreviewDialog") as dlg_cls:
            instance = dlg_cls.return_value
            instance.result = True
            dlg_cls.side_effect = lambda *a, **k: instance
            app.state.mark_session_active = lambda: None
            from unittest.mock import MagicMock
            app.state.registry.start_freeze = MagicMock()
            app.state.registry.freezes = {}
            app.state.registry.pollers = {}
            with unittest.mock.patch.object(app, "wait_window",
                                            lambda *a, **k: None):
                app.freeze_on()
            assert app.state.registry.start_freeze.called
            assert app.state.registry.start_freeze.call_args[0][:2] == \
                ("gold", "0xABC")
    finally:
        app.destroy()


def test_quit_checklist_reports_per_item(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    infos = []
    monkeypatch.setattr(main_mod.messagebox, "showinfo",
                        lambda *a, **k: infos.append(a))
    with unittest.mock.patch.object(
            app.state, "shutdown",
            return_value=[{"label": "gold", "restored": True},
                          {"label": "patch@0x1",
                           "restored": False}]) as shutdown_mock:
        shutdown_mock.side_effect = None
        app.on_close()
        shutdown_mock.assert_called_once()
    assert infos
    text = infos[0][1]
    assert "Restored: gold" in text
    assert "FAILED: patch@0x1" in text
    assert "1 restored, 1 failed" in infos[0][0]


def test_stale_state_recovery_banner(monkeypatch):
    import vision_trainer.main as main_mod
    app = None
    monkeypatch.setattr(
        "vision_trainer.flow.FlowState.session_was_unclean",
        lambda self: True)
    try:
        app = _make_app(monkeypatch)
    except tk.TclError:
        pytest.skip("no display available")
    try:
        app.update()
        assert app.unsafe_banner.winfo_manager()
        assert "ended uncleanly" in app.unsafe_banner.cget("text")
    finally:
        if app:
            app.destroy()


def test_setup_dialog_escape_binding(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        root = tk.Tk()
        root.withdraw()
    except tk.TclError:
        pytest.skip("no display available")
    try:
        dlg = main_mod.SetupDialog(root, {"endpoint": "http://x",
                                           "vision_model": "", "adjust_model": ""})
        try:
            bound = dlg.bind("<Escape>")
            assert bound, "Setup dialog must bind <Escape>"
        finally:
            dlg.destroy()
    finally:
        root.destroy()


def test_setup_dialog_prefills_default_endpoint(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        root = tk.Tk()
        root.withdraw()
    except tk.TclError:
        pytest.skip("no display available")
    try:
        dlg = main_mod.SetupDialog(
            root, main_mod.config_mod.default_config())
        try:
            assert dlg.endpoint_var.get() == \
                "http://localhost:20128/v1"
        finally:
            dlg.destroy()
    finally:
        root.destroy()


def test_setup_save_validates_before_probe(monkeypatch):
    import vision_trainer.main as main_mod
    from unittest.mock import MagicMock
    try:
        root = tk.Tk()
        root.withdraw()
    except tk.TclError:
        pytest.skip("no display available")
    try:
        dlg = main_mod.SetupDialog(
            root, {"endpoint": "", "vision_model": "",
                   "adjust_model": ""})
        try:
            probe = MagicMock()
            monkeypatch.setattr(main_mod.config_mod, "list_models",
                                probe)
            dlg.save()
            assert dlg.result is None
            probe.assert_not_called()
            assert dlg.status.cget("text")
        finally:
            dlg.destroy()
    finally:
        root.destroy()


def test_setup_save_unreachable_shows_message(monkeypatch):
    import vision_trainer.main as main_mod
    try:
        root = tk.Tk()
        root.withdraw()
    except tk.TclError:
        pytest.skip("no display available")
    try:
        dlg = main_mod.SetupDialog(
            root, {"endpoint": "http://localhost:20128/v1",
                   "vision_model": "v", "adjust_model": "a"})
        try:
            def boom(_endpoint):
                raise ConnectionError("refused")
            monkeypatch.setattr(main_mod.config_mod, "list_models",
                                boom)
            dlg.save()
            assert dlg.result is None
            assert "Endpoint unreachable" in dlg.status.cget("text")
        finally:
            dlg.destroy()
    finally:
        root.destroy()
