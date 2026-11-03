"""Failing tests first (RED): runbook create/update/suggest."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import runbook


def sample_entry(label="gold"):
    return {
        "process": "Game.exe",
        "window_title": "Game",
        "label": label,
        "observed_value": 5000,
        "target_value": 500000,
        "value_type": "dword",
        "scan_recipe": {
            "type": "dword",
            "protection": "+W-C",
            "scan_option": "exact",
            "narrow_rounds": 1,
            "hits": [47, 1],
        },
        "address": "0x1A2B3C",
        "module_offset": "game.exe+0x1234",
        "vision_model": "ag/gemini-3.8-flash-high",
        "adjust_model": "cmc/meta/muse-spark-1.3-contributor",
        "endpoint": "http://localhost:20128/v1",
        "verified": True,
        "notes": "first success",
    }


class TestResolvePath(unittest.TestCase):
    def test_sanitizes_name(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = runbook.resolve_path("Game.exe", base_dir=d)
            self.assertTrue(p.endswith("Game.exe.md"))

    def test_rejects_path_traversal(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = runbook.resolve_path("../../evil", base_dir=d)
            self.assertTrue(os.path.dirname(p).startswith(d))
            self.assertNotIn("..", os.path.basename(p))


class TestSaveAndLoad(unittest.TestCase):
    def test_create_from_template(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.md")
            runbook.save_entry(path, sample_entry())
            text = runbook.load(path)
            self.assertIn("Game.exe", text)
            self.assertIn("gold", text)
            self.assertIn("500000", text)

    def test_append_does_not_clobber(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.md")
            runbook.save_entry(path, sample_entry("gold"))
            first = runbook.load(path)
            runbook.save_entry(path, sample_entry("health"))
            second = runbook.load(path)
            self.assertIn("gold", second)
            self.assertIn("health", second)
            self.assertGreater(len(second), len(first))

    def test_recipe_upsert(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.md")
            runbook.save_entry(path, sample_entry("gold"))
            entry2 = sample_entry("gold")
            entry2["scan_recipe"]["narrow_rounds"] = 3
            runbook.save_entry(path, entry2)
            text = runbook.load(path)
            self.assertEqual(text.count("| gold |"), 1)

    def test_address_marked_informational(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.md")
            runbook.save_entry(path, sample_entry())
            text = runbook.load(path)
            self.assertIn("ASLR", text)

    def test_corrupt_file_recovery(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.md")
            with open(path, "w", encoding="utf-8") as f:
                f.write("\x00\x00binary garbage")
            runbook.save_entry(path, sample_entry())
            text = runbook.load(path)
            self.assertIn("gold", text)


class TestSuggest(unittest.TestCase):
    def test_suggest_most_recent(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.md")
            runbook.save_entry(path, sample_entry("gold"))
            runbook.save_entry(path, sample_entry("health"))
            suggestion = runbook.suggest_recipe(path, "gold")
            self.assertIsNotNone(suggestion)
            self.assertIn("dword", suggestion)

    def test_suggest_unknown_label_none(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "Game.exe.md")
            runbook.save_entry(path, sample_entry("gold"))
            self.assertIsNone(runbook.suggest_recipe(path, "mana"))

    def test_suggest_missing_file_none(self):
        self.assertIsNone(runbook.suggest_recipe("nope-missing.md", "gold"))


if __name__ == "__main__":
    unittest.main()
