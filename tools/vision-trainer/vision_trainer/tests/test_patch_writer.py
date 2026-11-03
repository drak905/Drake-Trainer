"""Story 4.3: patch-writer gating, exact confirm copy, unique signatures."""
import os
import sys
import tempfile
import unittest.mock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

tk = pytest.importorskip("tkinter")

from vision_trainer import codepatch as codepatch_mod


def _patch_app(monkeypatch):
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
    app.state.profiles_dir = tempfile.mkdtemp()
    app.patch_ack = True
    return app


def test_patch_confirm_copy_is_exact():
    import vision_trainer.main as main_mod
    assert main_mod.PATCH_CONFIRM_TEMPLATE.format(address="0xABC") == (
        "Change the value in-game now so the watch can catch the writer "
        "of 0xABC. This attaches a debugger and patches code. It can "
        "crash or corrupt saves. Offline saves only. Continue?")


def test_patch_ambiguous_signature_skips(monkeypatch):
    app = _patch_app(monkeypatch)
    try:
        infos = []
        errors = []
        asks = []
        monkeypatch.setattr("tkinter.messagebox.showinfo",
                            lambda *a, **k: infos.append(a))
        monkeypatch.setattr("tkinter.messagebox.showerror",
                            lambda *a, **k: errors.append(a))

        def fake_askyesno(*a, **k):
            asks.append(k)
            return True
        monkeypatch.setattr("tkinter.messagebox.askyesno", fake_askyesno)
        monkeypatch.setattr(
            codepatch_mod, "escalate_stubborn_value",
            unittest.mock.MagicMock(
                side_effect=codepatch_mod.AmbiguousSignature(
                    "signature matched 3 times (expected 1); refusing to "
                    "patch — re-capture required.")))
        app.state.write_result = {"address": "0xABC",
                                   "value_type": "dword"}
        app.patch_writer()
        assert infos and "Patch skipped" == infos[0][0]
        assert "matched 3 times" in infos[0][1]
        assert errors == []
        assert asks and asks[0].get("default") == "no"
    finally:
        app.destroy()


def test_patch_success_logs_and_marks_session(monkeypatch):
    app = _patch_app(monkeypatch)
    try:
        infos = []
        monkeypatch.setattr("tkinter.messagebox.showinfo",
                            lambda *a, **k: infos.append(a))
        monkeypatch.setattr("tkinter.messagebox.askyesno",
                            lambda *a, **k: True)
        marker = {}

        import vision_trainer.main as main_mod
        with unittest.mock.patch.object(
                codepatch_mod, "escalate_stubborn_value",
                return_value={"patched": True,
                              "hit": {"address": "0x5000"},
                              "fingerprint": {"signature": "55 8B EC"},
                              "patch": {"address": "0x5000",
                                        "original_bytes": [0x55],
                                        "patched_bytes": [0x90]}}), \
                unittest.mock.patch.object(
                app.state, "mark_session_active",
                lambda: marker.setdefault("marked", True)):
            app.state.write_result = {"address": "0xABC",
                                       "value_type": "dword"}
            app.patch_writer()
        assert marker.get("marked")
        assert any("Patched writer 0x5000 (sig 55 8B EC)" in line
                   for line in app.log.get("1.0", "end").splitlines())
    finally:
        app.destroy()


def test_patch_skip_classification_never_patches(monkeypatch):
    from vision_trainer import codepatch as cp
    plan = cp.classify_instruction("mov [rax+8], rdx", size=3)
    assert plan["action"] == "nop"
    plan = cp.classify_instruction("mov [rbx], 0x64", size=6)
    assert plan["action"] == "replace"
    plan = cp.classify_instruction("mov [rip+0x1234], rcx", size=6)
    assert plan["action"] == "skip"
    plan = cp.classify_instruction("lock inc dword [rax]", size=5)
    assert plan["action"] == "skip"
