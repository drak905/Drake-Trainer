"""Story 2.1: attach contract — passive checks, field-associated failure copy."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from unittest.mock import MagicMock

from vision_trainer import flow as flow_mod

PASSIVE_ONLY_TOOLS = ("get_process_info", "reload_bridge")


def _state(bridge=None):
    return flow_mod.FlowState(bridge=bridge or MagicMock(), config={
        "endpoint": "http://localhost:20128/v1",
        "vision_model": "v", "adjust_model": "a"})


def _calls(bridge):
    return [c.args[0] for c in bridge.send_command.call_args_list]


def test_attach_never_uses_get_process_info():
    bridge = MagicMock()
    bridge.send_command.side_effect = [
        {"success": True, "processes": []},
        {"success": True, "process_id": 5},
        {"success": True, "process_id": 5},
        {"success": True, "modules": []},
    ]
    state = _state(bridge)
    assert state.attach_process("1234") is True
    for tool in PASSIVE_ONLY_TOOLS:
        assert tool not in _calls(bridge)
    assert "get_opened_process_id" in _calls(bridge)


def test_pid_attach_sends_pid_and_keeps_resolved_name():
    bridge = MagicMock()
    bridge.send_command.side_effect = [
        {"success": True, "processes": [
            {"pid": 7777, "name": "solo_rpg.exe"}]},
        {"success": True, "process_id": 7777},
        {"success": True, "process_id": 7777},
        {"success": True, "modules": []},
    ]
    state = _state(bridge)
    assert state.attach_process("7777") is True
    assert state.process_id == 7777
    assert state.process_name == "solo_rpg.exe"
    open_calls = [c for c in bridge.send_command.call_args_list
                  if c.args[0] == "open_process"]
    assert open_calls[0].args[1]["process_id_or_name"] == "7777"


def test_failed_attach_keeps_state_and_blocks():
    bridge = MagicMock()
    bridge.send_command.side_effect = [
        {"success": True, "processes": []},
        {"success": False, "error": "not found"},
    ]
    state = _state(bridge)
    assert state.attach_process("1234") is False
    assert state.last_error
    assert state.refused is False
    assert state.stage == "process"
    assert state.process_id is None
    assert "enum_modules" not in _calls(bridge)


def test_malformed_process_list_rows_are_skipped():
    bridge = MagicMock()
    bridge.send_command.side_effect = [
        {"success": True, "processes": [
            "garbage", {"name": "no-pid.exe"}, {"pid": "x"},
            {"pid": 42, "name": "clean.exe"}]},
        {"success": True, "process_id": 42},
        {"success": True, "process_id": 42},
        {"success": True, "modules": []},
    ]
    state = _state(bridge)
    assert state.attach_process("42") is True
    assert state.process_name == "clean.exe"


def test_attach_failed_copy_is_exact():
    from vision_trainer import main as main_mod
    assert main_mod.ATTACH_FAILED_TEMPLATE.format(reason="boom") == (
        "Process — Attach failed: boom")
