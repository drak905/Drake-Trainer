"""Failing tests first (RED): profiles create/upsert/export."""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import profiles


def sample_cheat(label="gold"):
    return {
        "label": label,
        "value_type": "dword",
        "mode": "one_shot",
        "recipe": {"type": "dword", "protection": "+W-C",
                   "scan_option": "exact", "narrow_rounds": 1,
                   "hits": [47, 1]},
        "anchor": {"module_offset": "game.exe+0x1234"},
        "last_address": "0x1A2B3C",
        "module_offset": "game.exe+0x1234",
        "signature": None,
        "target_value": 500000,
        "verified": True,
        "look_for": "Open inventory, check gold displays 500000",
    }


class TestResolvePath(unittest.TestCase):
    def test_profile_path(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = profiles.resolve_path("Game.exe", base_dir=d)
            self.assertTrue(p.endswith("Game.exe.json"))

    def test_draft_path(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = profiles.draft_path("Game.exe", base_dir=d)
            self.assertTrue(p.endswith("Game.exe.draft.json"))

    def test_rejects_traversal(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = profiles.resolve_path("../../evil", base_dir=d)
            self.assertNotIn("..", os.path.basename(p))


class TestSaveLoad(unittest.TestCase):
    def test_create_profile(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.json")
            profiles.upsert_cheat(path, "Game.exe", sample_cheat())
            data = profiles.load(path)
            self.assertEqual(data["exe"], "Game.exe")
            self.assertEqual(data["schema"], 1)
            self.assertEqual(len(data["cheats"]), 1)

    def test_upsert_no_dupe(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.json")
            profiles.upsert_cheat(path, "Game.exe", sample_cheat("gold"))
            cheat2 = sample_cheat("gold")
            cheat2["target_value"] = 999
            profiles.upsert_cheat(path, "Game.exe", cheat2)
            data = profiles.load(path)
            self.assertEqual(len(data["cheats"]), 1)
            self.assertEqual(data["cheats"][0]["target_value"], 999)

    def test_get_and_list(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.json")
            profiles.upsert_cheat(path, "Game.exe", sample_cheat("gold"))
            profiles.upsert_cheat(path, "Game.exe", sample_cheat("hp"))
            self.assertEqual(len(profiles.list_cheats(path)), 2)
            self.assertEqual(profiles.get_cheat(path, "hp")["label"], "hp")
            self.assertIsNone(profiles.get_cheat(path, "mana"))

    def test_corrupt_recovery(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.json")
            with open(path, "w", encoding="utf-8") as f:
                f.write("\x00binary garbage{{")
            profiles.upsert_cheat(path, "Game.exe", sample_cheat())
            data = profiles.load(path)
            self.assertEqual(len(data["cheats"]), 1)

    def test_load_missing_returns_empty(self):
        data = profiles.load("nope-missing-xyz.json")
        self.assertEqual(data["cheats"], [])


class TestCtExport(unittest.TestCase):
    def test_plain_entry_exports_as_address(self):
        entries, skipped = profiles.export_ct_entries([sample_cheat("gold")])
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["kind"], "address")
        self.assertEqual(skipped, [])

    def test_signature_cheat_exports_as_aa_script(self):
        cheat = sample_cheat("gold")
        cheat["anchor"] = {"signature": "48 89 5C 24 ??",
                           "module": "game.exe", "offset": 4}
        entries, skipped = profiles.export_ct_entries([cheat])
        self.assertEqual(entries[0]["kind"], "aa_script")
        self.assertIn("48 89 5C 24", entries[0]["script"])
        self.assertEqual(skipped, [])

    def test_patch_cheat_exports_as_aa_script(self):
        cheat = sample_cheat("gold")
        cheat["patch"] = {"address": "0x5000", "original_bytes": [0x89, 0x1],
                          "patched_bytes": [0x90, 0x90]}
        entries, skipped = profiles.export_ct_entries([cheat])
        self.assertEqual(entries[0]["kind"], "aa_script")
        self.assertEqual(skipped, [])

    def test_pointer_chain_exports_as_address(self):
        cheat = sample_cheat("gold")
        cheat["anchor"] = {"pointer_chain": {"base": "game.exe+0x10",
                                             "offsets": [0x20, 0x8]}}
        entries, skipped = profiles.export_ct_entries([cheat])
        self.assertEqual(entries[0]["kind"], "address")
        self.assertEqual(skipped, [])

    def test_unsupported_skipped_with_reason(self):
        cheat = sample_cheat("ghost")
        cheat["anchor"] = {"capture_mode": "guard", "patch_id": "p1"}
        entries, skipped = profiles.export_ct_entries([cheat])
        self.assertEqual(entries, [])
        self.assertEqual(len(skipped), 1)
        self.assertIn("reason", skipped[0])

    def test_write_ct_file(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "out.CT")
            n = profiles.write_ct_file(path, [sample_cheat("gold")])
            self.assertEqual(n, 1)
            text = open(path, encoding="utf-8").read()
            self.assertIn("CheatTable", text)
            self.assertIn("gold", text)


if __name__ == "__main__":
    unittest.main()
