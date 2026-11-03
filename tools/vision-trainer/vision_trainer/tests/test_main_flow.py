"""Failing tests first (RED): process-step validation + wizard state machine."""
import os
import sys
import unittest
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import flow


class TestProcessStep(unittest.TestCase):
    def test_bad_pid_stays_on_step(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": False,
                                            "error": "nope"}
        state = flow.FlowState(bridge=bridge, config={
            "endpoint": "http://localhost:20128/v1",
            "vision_model": "v", "adjust_model": "a"})
        ok = state.attach_process("999999")
        self.assertFalse(ok)
        self.assertIsNone(state.process_id)
        self.assertTrue(state.last_error)

    def test_attach_success_sets_pid(self):
        bridge = MagicMock()
        bridge.send_command.side_effect = [
            {"success": True, "processes": []},
            {"success": True, "process_id": 1234},
            {"success": True, "process_id": 1234},
            {"success": True, "modules": []},
        ]
        state = flow.FlowState(bridge=bridge, config={
            "endpoint": "http://localhost:20128/v1",
            "vision_model": "v", "adjust_model": "a"})
        self.assertTrue(state.attach_process("1234"))
        self.assertEqual(state.process_id, 1234)

    def test_remembers_last_process(self):
        bridge = MagicMock()
        bridge.send_command.side_effect = [
            {"success": True, "process_id": 1},
            {"success": True, "process_id": 1},
            {"success": True, "modules": []},
        ]
        state = flow.FlowState(bridge=bridge, config={})
        state.attach_process("game.exe")
        self.assertEqual(state.last_process, "game.exe")


class TestWizardMachine(unittest.TestCase):
    def _state(self):
        bridge = MagicMock()
        return flow.FlowState(bridge=bridge, config={
            "endpoint": "http://localhost:20128/v1",
            "vision_model": "ag/gemini-3.8-flash-high",
            "adjust_model": "cmc/meta/muse-spark-1.3-contributor"})

    def test_initial_stage_is_setup_when_no_config(self):
        state = flow.FlowState(bridge=MagicMock(), config=None)
        self.assertEqual(state.stage, "setup")

    def test_initial_stage_is_process_with_config(self):
        self.assertEqual(self._state().stage, "process")

    def test_yes_writes_runbook(self):
        import tempfile
        state = self._state()
        state.process_id = 1
        state.process_name = "Game.exe"
        state.values = [{"label": "gold", "value": 5,
                         "value_type": "dword", "confidence": 0.9}]
        state.write_result = {"address": "0x1", "target_value": 500,
                              "trace": ["scan_all dword"]}
        with tempfile.TemporaryDirectory() as d:
            saved = state.confirm_yes(runbook_dir=d, notes="")
            self.assertTrue(saved)
        self.assertEqual(state.stage, "done")

    def test_no_does_not_write_runbook(self):
        import tempfile
        state = self._state()
        state.process_id = 1
        state.stage = "verify"
        with tempfile.TemporaryDirectory() as d:
            state.confirm_no()
            self.assertEqual(len(os.listdir(d)), 0)
        self.assertEqual(state.stage, "refine")

    def test_settings_reentry(self):
        state = self._state()
        state.stage = "extract"
        state.open_settings()
        self.assertEqual(state.stage, "setup")
        self.assertTrue(state.settings_return)


if __name__ == "__main__":
    unittest.main()
