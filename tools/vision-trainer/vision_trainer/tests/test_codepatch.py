"""Failing tests first (RED): code-patch escalation path."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import codepatch


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


class TestLocateWriter(unittest.TestCase):
    def test_returns_hit_address(self):
        bridge = FakeBridge([
            ("set_data_breakpoint", {"success": True, "id": "bp1"}),
            ("get_breakpoint_hits",
             {"success": True, "total": 1,
              "hits": [{"address": "0x5000",
                        "instruction": "mov [rax+0x10],ecx",
                        "registers": {"RAX": "0x1000"}}]}),
            ("remove_breakpoint", {"success": True}),
        ])
        hit = codepatch.locate_writer(bridge, "0x1010")
        self.assertEqual(hit["address"], "0x5000")

    def test_no_hits_raises(self):
        bridge = FakeBridge([
            ("set_data_breakpoint", {"success": True, "id": "bp1"}),
            ("get_breakpoint_hits",
             {"success": True, "total": 0, "hits": []}),
            ("remove_breakpoint", {"success": True}),
        ])
        with self.assertRaises(codepatch.NoWriterHit):
            codepatch.locate_writer(bridge, "0x1010")

    def test_breakpoint_cleaned_up_on_no_hit(self):
        bridge = FakeBridge([
            ("set_data_breakpoint", {"success": True, "id": "bp1"}),
            ("get_breakpoint_hits",
             {"success": True, "total": 0, "hits": []}),
            ("remove_breakpoint", {"success": True}),
        ])
        try:
            codepatch.locate_writer(bridge, "0x1010")
        except codepatch.NoWriterHit:
            pass
        methods = [m for m, _ in bridge.calls]
        self.assertIn("remove_breakpoint", methods)


class TestClassify(unittest.TestCase):
    def test_mov_reg_mem_is_nop(self):
        plan = codepatch.classify_instruction("mov [rax+0x10],ecx", size=3)
        self.assertEqual(plan["action"], "nop")
        self.assertEqual(plan["nop_bytes"], 3)

    def test_mov_imm_is_replace(self):
        plan = codepatch.classify_instruction("mov [rax+0x10],0x64",
                                              size=7)
        self.assertEqual(plan["action"], "replace")

    def test_rip_relative_is_skip(self):
        plan = codepatch.classify_instruction(
            "mov [rip+0x1234],eax", size=6)
        self.assertEqual(plan["action"], "skip")
        self.assertIn("RIP", plan["reason"])

    def test_unknown_is_skip(self):
        plan = codepatch.classify_instruction("call 0x1234", size=5)
        self.assertEqual(plan["action"], "skip")


class TestNopBytes(unittest.TestCase):
    def test_nop_fill_length(self):
        self.assertEqual(codepatch.nop_fill(3), [0x90, 0x90, 0x90])
        self.assertEqual(codepatch.nop_fill(1), [0x90])

    def test_nop_fill_rejects_zero(self):
        with self.assertRaises(ValueError):
            codepatch.nop_fill(0)


class TestFingerprint(unittest.TestCase):
    def test_unique_signature_accepted(self):
        bridge = FakeBridge([
            ("generate_signature",
             {"success": True, "signature": "AA BB CC",
              "offset_from_start": 2}),
            ("aob_scan_module_unique",
             {"success": True, "address": "0x5000"}),
        ])
        fp = codepatch.fingerprint_writer(bridge, "0x5000", "game.exe")
        self.assertEqual(fp["signature"], "AA BB CC")
        self.assertEqual(fp["module"], "game.exe")

    def test_ambiguous_signature_refuses(self):
        bridge = FakeBridge([
            ("generate_signature",
             {"success": True, "signature": "AA",
              "offset_from_start": 0}),
            ("aob_scan_module_unique",
             {"success": False, "error": "matched 5", "count": 5}),
        ])
        with self.assertRaises(codepatch.AmbiguousSignature):
            codepatch.fingerprint_writer(bridge, "0x5000", "game.exe")


class TestApplyRestore(unittest.TestCase):
    def test_apply_nop_writes_and_records(self):
        bridge = FakeBridge([
            ("read_memory",
             {"success": True, "bytes": [0x89, 0x48, 0x10]}),
            ("write_memory", {"success": True}),
        ])
        patch = codepatch.apply_patch(bridge, "0x5000", [0x90] * 3)
        self.assertEqual(patch["original_bytes"], [0x89, 0x48, 0x10])
        self.assertEqual(patch["patched_bytes"], [0x90] * 3)

    def test_restore_writes_original(self):
        bridge = FakeBridge([
            ("write_memory", {"success": True}),
        ])
        codepatch.restore_patch(
            bridge, {"address": "0x5000", "original_bytes": [1, 2, 3]})
        method, params = bridge.calls[0]
        self.assertEqual(method, "write_memory")
        self.assertEqual(params["bytes"], [1, 2, 3])


if __name__ == "__main__":
    unittest.main()
