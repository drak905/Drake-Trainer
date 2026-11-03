"""Failing tests first (RED): scan_flow incl. expanded scan ladder."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import scan_flow


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


class TestAdjustTo100xSimple(unittest.TestCase):
    def test_single_hit_writes(self):
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 1}),
            ("get_scan_results",
             {"success": True, "total": 1,
              "results": [{"address": "0x1000", "value": "5000"}]}),
            ("write_integer", {"success": True}),
        ])
        out = scan_flow.adjust_to_100x(
            bridge, "gold", 5000, "dword", target_value=500000,
            picker=lambda c: c[0],
            writer=lambda d: True)
        self.assertEqual(out["address"], "0x1000")
        self.assertEqual(out["target_value"], 500000)
        methods = [m for m, _ in bridge.calls]
        self.assertIn("write_integer", methods)

    def test_never_writes_multiple_without_pick(self):
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 3}),
            ("get_scan_results",
             {"success": True, "total": 3,
              "results": [{"address": "0x1", "value": "5"},
                          {"address": "0x2", "value": "5"},
                          {"address": "0x3", "value": "5"}]}),
        ])
        with self.assertRaises(scan_flow.AmbiguousResults):
            scan_flow.adjust_to_100x(
                bridge, "gold", 5, "dword", target_value=500,
                picker=None,
            writer=lambda d: True)

    def test_picker_choice_written(self):
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 2}),
            ("get_scan_results",
             {"success": True, "total": 2,
              "results": [{"address": "0x1", "value": "5"},
                          {"address": "0x2", "value": "5"}]}),
            ("read_integer", {"success": True, "value": 5}),
            ("read_integer", {"success": True, "value": 5}),
            ("write_integer", {"success": True}),
        ])
        out = scan_flow.adjust_to_100x(
            bridge, "gold", 5, "dword", target_value=500,
            picker=lambda c: c[1],
            writer=lambda d: True)
        self.assertEqual(out["address"], "0x2")


class TestTypeExpansion(unittest.TestCase):
    def test_zero_hits_expands_types(self):
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 1}),
            ("get_scan_results",
             {"success": True, "total": 1,
              "results": [{"address": "0x2000", "value": "5000"}]}),
            ("write_integer", {"success": True}),
        ])
        out = scan_flow.adjust_to_100x(
            bridge, "gold", 5000, "dword", target_value=500000,
            picker=lambda c: c[0],
            writer=lambda d: True)
        types_tried = [p.get("type")
                       for m, p in bridge.calls if m == "scan_all"]
        self.assertEqual(len(types_tried), 3)
        self.assertIn("float", types_tried)
        self.assertEqual(out["address"], "0x2000")
        self.assertIn("float", out["trace"][2])

    def test_protection_expansion_after_types(self):
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 0}),
            ("scan_all", {"success": True, "count": 1}),
            ("get_scan_results",
             {"success": True, "total": 1,
              "results": [{"address": "0x9", "value": "5"}]}),
            ("write_integer", {"success": True}),
        ])
        out = scan_flow.adjust_to_100x(
            bridge, "gold", 5, "dword", target_value=500,
            picker=lambda c: c[0],
            writer=lambda d: True)
        protections = [p.get("protection")
                       for m, p in bridge.calls if m == "scan_all"]
        self.assertIn("+W", protections)
        self.assertTrue(any("protection" in step for step in out["trace"]))

    def test_all_empty_raises_no_results(self):
        responses = [("scan_all", {"success": True, "count": 0})] * 12
        bridge = FakeBridge(responses)
        with self.assertRaises(scan_flow.NoResults):
            scan_flow.adjust_to_100x(
                bridge, "gold", 5, "dword", target_value=500,
                picker=lambda c: c[0],
            writer=lambda d: True)


class TestNarrowing(unittest.TestCase):
    def test_many_hits_narrows_with_next_scan(self):
        results = [{"address": f"0x{i}", "value": "100"} for i in range(200)]
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 200}),
            ("get_scan_results",
             {"success": True, "total": 200, "results": results}),
            ("next_scan", {"success": True, "count": 1}),
            ("get_scan_results",
             {"success": True, "total": 1,
              "results": [{"address": "0x7", "value": "150"}]}),
            ("write_integer", {"success": True}),
        ])
        out = scan_flow.adjust_to_100x(
            bridge, "gold", 100, "dword", target_value=15000,
            picker=lambda c: c[0],
            narrow_values=["150"],
            writer=lambda d: True)
        methods = [m for m, _ in bridge.calls]
        self.assertIn("next_scan", methods)
        self.assertEqual(out["address"], "0x7")

    def test_narrowing_needs_values(self):
        results = [{"address": f"0x{i}", "value": "100"} for i in range(200)]
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 200}),
            ("get_scan_results",
             {"success": True, "total": 200, "results": results}),
        ])
        with self.assertRaises(scan_flow.NeedNarrowingValue):
            scan_flow.adjust_to_100x(
                bridge, "gold", 100, "dword", target_value=15000,
                picker=lambda c: c[0], narrow_values=[],
            writer=lambda d: True)


class TestTrace(unittest.TestCase):
    def test_trace_records_steps(self):
        bridge = FakeBridge([
            ("scan_all", {"success": True, "count": 1}),
            ("get_scan_results",
             {"success": True, "total": 1,
              "results": [{"address": "0x1", "value": "5"}]}),
            ("write_integer", {"success": True}),
        ])
        out = scan_flow.adjust_to_100x(
            bridge, "gold", 5, "dword", target_value=500,
            picker=lambda c: c[0],
            writer=lambda d: True)
        self.assertTrue(out["trace"])
        self.assertIn("scan_all", out["trace"][0])


if __name__ == "__main__":
    unittest.main()
