"""Failing tests first (RED): anchor resolution ladder."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import anchor


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


def cheat(**kw):
    base = {"label": "gold", "value_type": "dword",
            "recipe": {"type": "dword", "protection": "+W-C",
                       "scan_option": "exact"},
            "anchor": None, "last_address": "0x9999",
            "module_offset": "", "signature": None}
    base.update(kw)
    return base


class TestModuleOffset(unittest.TestCase):
    def test_l0_hit(self):
        bridge = FakeBridge([
            ("get_symbol_address",
             {"success": True, "address": "0x2000"}),
            ("read_integer", {"success": True, "value": 5000}),
        ])
        out = anchor.resolve_anchor(
            bridge, cheat(anchor={"module_offset": "game.exe+0x1234"}),
            expected_value=5000)
        self.assertEqual(out["address"], "0x2000")
        self.assertEqual(out["level"], "module_offset")

    def test_l0_miss_falls_through(self):
        bridge = FakeBridge([
            ("get_symbol_address",
             {"success": False, "error": "not found"}),
            ("aob_scan_module_unique",
             {"success": True, "address": "0x3000"}),
            ("read_integer", {"success": True, "value": 5000}),
        ])
        out = anchor.resolve_anchor(
            bridge,
            cheat(anchor={"module_offset": "game.exe+0x1",
                          "signature": "AA BB", "module": "game.exe",
                          "offset": 0}),
            expected_value=5000)
        self.assertEqual(out["level"], "signature")

    def test_l0_implausible_value_rejected(self):
        bridge = FakeBridge([
            ("get_symbol_address",
             {"success": True, "address": "0x2000"}),
            ("read_integer", {"success": True, "value": 123456789}),
            ("aob_scan_module_unique",
             {"success": True, "address": "0x3000"}),
            ("read_integer", {"success": True, "value": 5000}),
        ])
        out = anchor.resolve_anchor(
            bridge,
            cheat(anchor={"module_offset": "game.exe+0x1",
                          "signature": "AA BB", "module": "game.exe",
                          "offset": 0}),
            expected_value=5000)
        self.assertEqual(out["level"], "signature")


class TestSignature(unittest.TestCase):
    def test_l1_applies_offset(self):
        bridge = FakeBridge([
            ("aob_scan_module_unique",
             {"success": True, "address": "0x4000"}),
            ("read_integer", {"success": True, "value": 7}),
        ])
        out = anchor.resolve_anchor(
            bridge,
            cheat(anchor={"signature": "AA BB", "module": "game.exe",
                          "offset": 4}),
            expected_value=7)
        self.assertEqual(out["level"], "signature")

    def test_l1_ambiguous_refuses(self):
        bridge = FakeBridge([
            ("aob_scan_module_unique",
             {"success": False, "error": "matched 3 times", "count": 3}),
        ])
        with self.assertRaises(anchor.AmbiguousSignature):
            anchor.resolve_anchor(
                bridge,
                cheat(anchor={"signature": "AA", "module": "game.exe",
                              "offset": 0}),
                rescan=None)


class TestPointerChain(unittest.TestCase):
    def test_l2_validated(self):
        bridge = FakeBridge([
            ("read_pointer_chain",
             {"success": True, "final_address": "0x5000"}),
            ("validate_pointer_chains",
             {"success": True, "matches": [{"final": "0x5000"}]}),
            ("read_integer", {"success": True, "value": 42}),
        ])
        out = anchor.resolve_anchor(
            bridge,
            cheat(anchor={"pointer_chain": {"base": "game.exe+0x10",
                                            "offsets": [0x20]}}),
            expected_value=42)
        self.assertEqual(out["level"], "pointer_chain")
        self.assertEqual(out["address"], "0x5000")

    def test_l2_mismatch_falls_to_rescan(self):
        bridge = FakeBridge([
            ("read_pointer_chain",
             {"success": True, "final_address": "0x5000"}),
            ("validate_pointer_chains",
             {"success": True, "matches": []}),
            ("scan_all", {"success": True, "count": 1}),
            ("get_scan_results",
             {"success": True, "total": 1,
              "results": [{"address": "0x6000", "value": "42"}]}),
        ])
        out = anchor.resolve_anchor(
            bridge,
            cheat(anchor={"pointer_chain": {"base": "b", "offsets": []}},
                 recipe={"type": "dword"}),
            expected_value=42,
            rescan=lambda b, c: {"address": "0x6000"})
        self.assertEqual(out["level"], "rescan")


class TestRescanFallback(unittest.TestCase):
    def test_no_anchor_uses_rescan_and_learns(self):
        seen = {}

        def fake_rescan(bridge, cheat):
            seen["called"] = True
            return {"address": "0x7000", "module_offset": "game.exe+0x77",
                    "signature": "CC DD"}

        bridge = FakeBridge([])
        out = anchor.resolve_anchor(bridge, cheat(anchor=None),
                                    rescan=fake_rescan)
        self.assertTrue(seen["called"])
        self.assertEqual(out["learned"]["module_offset"], "game.exe+0x77")

    def test_no_rescan_available_raises(self):
        bridge = FakeBridge([])
        with self.assertRaises(anchor.NoAnchor):
            anchor.resolve_anchor(bridge, cheat(anchor=None), rescan=None)

    def test_stale_raw_address_never_trusted(self):
        bridge = FakeBridge([])
        with self.assertRaises(anchor.NoAnchor):
            anchor.resolve_anchor(
                bridge, cheat(anchor=None, last_address="0x1234"),
                rescan=None)


if __name__ == "__main__":
    unittest.main()
