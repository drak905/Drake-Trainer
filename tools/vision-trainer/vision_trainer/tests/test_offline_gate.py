"""Offline-only refuse gate: blocklist + heuristics + lock (offline)."""
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from unittest.mock import MagicMock

from vision_trainer import flow as flow_mod
from vision_trainer import offline_gate as gate_mod


def _state(bridge=None):
    return flow_mod.FlowState(bridge=bridge or MagicMock(), config={
        "endpoint": "http://localhost:20128/v1",
        "vision_model": "v", "adjust_model": "a"})


def test_launcher_name_refused_before_attach():
    bridge = MagicMock()
    state = _state(bridge)
    assert state.attach_process("steam") is False
    assert state.refused is True
    assert state.last_error.startswith("Offline games only")
    assert state.process_id is None
    bridge.send_command.assert_not_called()


def test_anticheat_module_refused_and_detaches():
    bridge = MagicMock()
    bridge.send_command.side_effect = [
        {"success": True, "process_id": 777},
        {"success": True, "process_id": 777},
        {"success": True, "modules": [{"name": "EasyAntiCheat.dll"}]},
        {"success": False},
        {"success": True},
    ]
    state = _state(bridge)
    assert state.attach_process("game.exe") is False
    assert state.refused is True
    assert "anti-cheat module loaded" in state.last_error
    assert state.process_id is None
    assert state.stage == "process"


def test_pid_bypass_caught_by_process_list_lookup():
    bridge = MagicMock()
    bridge.send_command.side_effect = [
        {"success": True, "processes": [{"pid": 9999,
                                         "name": "steam.exe"}]},
    ]
    state = _state(bridge)
    assert state.attach_process("9999") is False
    assert state.refused is True
    assert "launcher process" in state.last_error
    assert 9999 in state.locked_pids


def test_locked_pid_refused_without_bridge_call():
    bridge = MagicMock()
    state = _state(bridge)
    state.locked_pids.add(4242)
    assert state.attach_process("4242") is False
    assert "previously refused PID" in state.last_error
    bridge.send_command.assert_not_called()


def test_clean_target_passes_gate():
    bridge = MagicMock()
    bridge.send_command.side_effect = [
        {"success": True, "process_id": 1234},
        {"success": True, "process_id": 1234},
        {"success": True, "modules": [{"name": "game.exe"}]},
        {"success": False},
    ]
    state = _state(bridge)
    assert state.attach_process("solo_rpg.exe") is True
    assert state.refused is False
    assert state.process_id == 1234


def test_refuse_copy_exact():
    reason = "launcher process (steam)"
    assert gate_mod.REFUSE_MESSAGE.format(reason=reason) == (
        "Offline games only — this target looks like multiplayer or "
        f"anti-cheat ({reason}). Detaching; change the target to continue."
    )
