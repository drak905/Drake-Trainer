"""Failing tests first (RED): freeze workers + restore-on-exit."""
import os
import sys
import threading
import time
import unittest
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import freeze as freeze_mod


class TestFreezeWorker(unittest.TestCase):
    def test_start_writes_repeatedly(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": True}
        worker = freeze_mod.FreezeWorker(bridge, "0x1000", 500, "dword",
                                         interval=0.01)
        worker.start()
        time.sleep(0.05)
        worker.stop()
        writes = [c for c in bridge.send_command.call_args_list
                  if c[0][0] == "write_integer"]
        self.assertGreaterEqual(len(writes), 2)

    def test_start_idempotent(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": True}
        worker = freeze_mod.FreezeWorker(bridge, "0x1", 1, "dword",
                                         interval=0.01)
        worker.start()
        worker.start()
        self.assertEqual(len([t for t in [worker._thread] if t.is_alive()]), 1)
        worker.stop()

    def test_stop_idempotent(self):
        bridge = MagicMock()
        worker = freeze_mod.FreezeWorker(bridge, "0x1", 1, "dword")
        worker.stop()
        worker.stop()
        self.assertFalse(worker.running)

    def test_captures_original_value(self):
        bridge = MagicMock()

        def fake(method, params=None):
            if method == "read_integer":
                return {"success": True, "value": 111}
            return {"success": True}

        bridge.send_command.side_effect = fake
        worker = freeze_mod.FreezeWorker(bridge, "0x1", 999, "dword",
                                         interval=60)
        worker.start()
        worker.stop()
        self.assertEqual(worker.original_value, 111)

    def test_restore_writes_original(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": True}
        worker = freeze_mod.FreezeWorker(bridge, "0x1", 999, "dword",
                                         interval=60)
        worker.original_value = 111
        worker.restore()
        methods = [c[0][0] for c in bridge.send_command.call_args_list]
        self.assertIn("write_integer", methods)
        last_write = [c for c in bridge.send_command.call_args_list
                      if c[0][0] == "write_integer"][-1]
        self.assertEqual(last_write[0][1]["value"], 111)


class TestDisplayPoller(unittest.TestCase):
    def test_polls_into_callback(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": True, "value": 42}
        seen = []
        poller = freeze_mod.DisplayPoller(bridge, "0x1", "dword",
                                          seen.append, interval=0.01)
        poller.start()
        time.sleep(0.05)
        poller.stop()
        self.assertTrue(seen)
        self.assertEqual(seen[0], 42)

    def test_start_stop_idempotent(self):
        bridge = MagicMock()
        poller = freeze_mod.DisplayPoller(bridge, "0x1", "dword",
                                          lambda v: None, interval=60)
        poller.start()
        poller.start()
        poller.stop()
        poller.stop()
        self.assertFalse(poller.running)


class TestRegistryRestore(unittest.TestCase):
    def test_registry_restores_all(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": True}
        reg = freeze_mod.WorkerRegistry(bridge)
        w = reg.start_freeze("gold", "0x1", 500, "dword", interval=60)
        w.original_value = 5
        reg.restore_all()
        methods = [c[0][0] for c in bridge.send_command.call_args_list]
        self.assertIn("write_integer", methods)
        self.assertFalse(w.running)

    def test_exit_hook_clears_breakpoints(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": True}
        freeze_mod.restore_on_exit(bridge, freeze_mod.WorkerRegistry(bridge),
                                   patches=[])
        methods = [c[0][0] for c in bridge.send_command.call_args_list]
        self.assertIn("clear_all_breakpoints", methods)

    def test_exit_hook_restores_patches(self):
        bridge = MagicMock()
        bridge.send_command.return_value = {"success": True}
        patches = [{"address": "0x5000", "original_bytes": [0x89, 0xD8]}]
        freeze_mod.restore_on_exit(bridge, freeze_mod.WorkerRegistry(bridge),
                                   patches=patches)
        methods = [c[0][0] for c in bridge.send_command.call_args_list]
        self.assertIn("write_memory", methods)


if __name__ == "__main__":
    unittest.main()
