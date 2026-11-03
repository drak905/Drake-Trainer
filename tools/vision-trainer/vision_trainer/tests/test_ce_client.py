"""Failing tests first (RED): ce_client pipe wrapper + helpers."""
import json
import os
import struct
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import ce_client


class FakeBridge:
    def __init__(self):
        self.calls = []
        self.responses = {}

    def send_command(self, method, params=None):
        self.calls.append((method, params or {}))
        if method in self.responses:
            resp = self.responses[method]
            return resp() if callable(resp) else resp
        return {"success": True}


class TestClientConstruction(unittest.TestCase):
    def test_default_pipe_name(self):
        self.assertIn("CE_MCP_Bridge_v99", ce_client.PIPE_NAME)

    def test_tcp_transport_selected_by_env(self):
        with patch.dict(os.environ, {"CE_MCP_TRANSPORT": "tcp",
                                     "CE_MCP_HOST": "10.0.0.5",
                                     "CE_MCP_PORT": "9999"}):
            c = ce_client.CEBridge()
            self.assertEqual(c.transport, "tcp")
            self.assertEqual(c.host, "10.0.0.5")
            self.assertEqual(c.port, 9999)

    def test_pipe_transport_default(self):
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("CE_MCP_TRANSPORT", None)
            c = ce_client.CEBridge()
            self.assertEqual(c.transport, "pipe")


class TestFraming(unittest.TestCase):
    def test_build_request_frame(self):
        frame = ce_client.build_frame("ping", {}, req_id=7)
        length = struct.unpack("<I", frame[:4])[0]
        body = json.loads(frame[4:].decode("utf-8"))
        self.assertEqual(length, len(frame) - 4)
        self.assertEqual(body["method"], "ping")
        self.assertEqual(body["id"], 7)

    def test_parse_response_result(self):
        result = {"success": True, "version": "12.0.0"}
        envelope = {"jsonrpc": "2.0", "result": result, "id": 1}
        raw = json.dumps(envelope).encode("utf-8")
        frame = struct.pack("<I", len(raw)) + raw
        self.assertEqual(ce_client.parse_frame(frame), result)

    def test_parse_response_error(self):
        envelope = {"jsonrpc": "2.0",
                    "error": {"message": "boom"}, "id": 1}
        raw = json.dumps(envelope).encode("utf-8")
        frame = struct.pack("<I", len(raw)) + raw
        out = ce_client.parse_frame(frame)
        self.assertFalse(out["success"])

    def test_parse_oversize_rejected(self):
        frame = struct.pack("<I", ce_client.MAX_RESPONSE_BYTES + 1) + b"{}"
        with self.assertRaises(ConnectionError):
            ce_client.parse_frame(frame)


class TestHelpers(unittest.TestCase):
    def test_ping(self):
        bridge = FakeBridge()
        bridge.responses["ping"] = {"success": True, "version": "12.0.0"}
        self.assertTrue(ce_client.ping(bridge)["success"])

    def test_find_game_window(self):
        bridge = FakeBridge()
        bridge.responses["find_window"] = {"success": True,
                                           "handle": "0x1234"}
        out = ce_client.find_game_window(bridge, "MyGame")
        self.assertEqual(out["handle"], "0x1234")
        self.assertEqual(bridge.calls[0][0], "find_window")

    def test_find_game_window_not_found(self):
        bridge = FakeBridge()
        bridge.responses["find_window"] = {"success": False,
                                           "error_code": "NOT_FOUND"}
        with self.assertRaises(LookupError):
            ce_client.find_game_window(bridge, "Nope")

    def test_get_window_rect(self):
        bridge = FakeBridge()
        bridge.responses["get_window_rect"] = {
            "success": True, "x": 10, "y": 20, "width": 800, "height": 600}
        out = ce_client.get_window_rect(bridge, "0x1234")
        self.assertEqual(out["width"], 800)

    def test_get_window_rect_error_shape(self):
        bridge = FakeBridge()
        bridge.responses["get_window_rect"] = {"success": False,
                                               "error": "Invalid handle"}
        with self.assertRaises(ValueError):
            ce_client.get_window_rect(bridge, "bad")

    def test_open_process_by_pid(self):
        bridge = FakeBridge()
        bridge.responses["open_process"] = {"success": True,
                                            "process_id": 1234}
        out = ce_client.open_process(bridge, "1234")
        self.assertTrue(out["success"])
        self.assertEqual(bridge.calls[0][1]["process_id_or_name"], "1234")

    def test_scan_helpers_forward_params(self):
        bridge = FakeBridge()
        bridge.responses["scan_all"] = {"success": True, "count": 5}
        ce_client.scan_all(bridge, "5000", value_type="dword")
        method, params = bridge.calls[0]
        self.assertEqual(method, "scan_all")
        self.assertEqual(params["value"], "5000")

    def test_write_integer_forwards(self):
        bridge = FakeBridge()
        bridge.responses["write_integer"] = {"success": True}
        ce_client.write_integer(bridge, "0x1000", 500000, "dword")
        method, params = bridge.calls[0]
        self.assertEqual(method, "write_integer")
        self.assertEqual(params["value"], 500000)

    def test_read_integer_forwards(self):
        bridge = FakeBridge()
        bridge.responses["read_integer"] = {"success": True, "value": 42}
        out = ce_client.read_integer(bridge, "0x1000", "dword")
        self.assertEqual(out["value"], 42)

    def test_get_process_list(self):
        bridge = FakeBridge()
        bridge.responses["get_process_list"] = {
            "success": True, "count": 1,
            "processes": [{"pid": 1, "name": "game.exe"}]}
        out = ce_client.get_process_list(bridge)
        self.assertEqual(out["count"], 1)


class TestProcessValidation(unittest.TestCase):
    def test_validate_attached_ok(self):
        bridge = FakeBridge()
        bridge.responses["get_opened_process_id"] = {"success": True,
                                                     "process_id": 4321}
        self.assertEqual(
            ce_client.validate_attached(bridge, 4321), 4321)

    def test_validate_attached_mismatch(self):
        bridge = FakeBridge()
        bridge.responses["get_opened_process_id"] = {"success": True,
                                                     "process_id": 111}
        with self.assertRaises(RuntimeError):
            ce_client.validate_attached(bridge, 4321)

    def test_validate_attached_no_process(self):
        bridge = FakeBridge()
        bridge.responses["get_opened_process_id"] = {
            "success": False, "error_code": "NO_PROCESS"}
        with self.assertRaises(RuntimeError):
            ce_client.validate_attached(bridge, 4321)

    def test_resolve_process_selection_by_pid(self):
        procs = [{"pid": 10, "name": "a.exe"},
                 {"pid": 20, "name": "game.exe"}]
        self.assertEqual(
            ce_client.resolve_process_selection(procs, "20"), 20)

    def test_resolve_process_selection_by_name(self):
        procs = [{"pid": 10, "name": "a.exe"},
                 {"pid": 20, "name": "game.exe"}]
        self.assertEqual(
            ce_client.resolve_process_selection(procs, "game.exe"), 20)

    def test_resolve_process_selection_unknown(self):
        with self.assertRaises(LookupError):
            ce_client.resolve_process_selection([], "nope.exe")


if __name__ == "__main__":
    unittest.main()
