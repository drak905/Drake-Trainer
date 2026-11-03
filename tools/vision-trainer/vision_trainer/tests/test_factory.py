"""Failing tests first (RED): categories + draft/promote factory."""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import categories, factory


def value(label, val, vtype="dword", conf=0.9):
    return {"label": label, "value": val, "value_type": vtype,
            "confidence": conf}


class TestCategories(unittest.TestCase):
    def test_known_categories_present(self):
        for name in ("health", "stamina", "mana", "money", "bank",
                     "ammo", "score"):
            self.assertIn(name, categories.CATEGORIES)

    def test_each_has_required_fields(self):
        for name, cat in categories.CATEGORIES.items():
            for field in ("name_hints", "types", "plausible",
                          "mode", "look_for"):
                self.assertIn(field, cat, f"{name} missing {field}")

    def test_trap_categories_manual(self):
        self.assertIn("runspeed", categories.MANUAL_ONLY)
        self.assertIn("hunger", categories.MANUAL_ONLY)


class TestMatchCategory(unittest.TestCase):
    def test_health_match(self):
        cat = factory.match_category(value("HP", 100))
        self.assertEqual(cat, "health")

    def test_money_match(self):
        cat = factory.match_category(value("Gold", 5000))
        self.assertEqual(cat, "money")

    def test_unknown_returns_none(self):
        self.assertIsNone(factory.match_category(value("ZzzQq", 5)))

    def test_implausible_rejected(self):
        self.assertIsNone(
            factory.match_category(value("Health", 999999999)))

    def test_trap_returns_manual(self):
        kind, reason = factory.classify_trap(value("RunSpeed", 1.0))
        self.assertEqual(kind, "manual")
        self.assertTrue(reason)


class TestDraft(unittest.TestCase):
    def test_drafts_from_wishlist(self):
        drafts, manual = factory.draft_cheats(
            [value("HP", 100), value("Gold", 5000)],
            ["health", "money"])
        self.assertEqual(len(drafts), 2)
        self.assertEqual(manual, [])
        for d in drafts:
            self.assertTrue(d["look_for"])
            self.assertIn("verified", d)

    def test_unmatched_wishlist_entry_manual(self):
        drafts, manual = factory.draft_cheats([value("HP", 100)], ["mana"])
        self.assertEqual(drafts, [])
        self.assertEqual(len(manual), 1)

    def test_multi_instance_flag(self):
        drafts, _ = factory.draft_cheats(
            [value("HP", 100), value("HP", 100)], ["health"])
        self.assertTrue(any(d.get("multi_instance_risk") for d in drafts))

    def test_draft_file_replaces(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "G.draft.json")
            factory.write_drafts(path, "G.exe",
                                 [{"label": "a"}])
            factory.write_drafts(path, "G.exe",
                                 [{"label": "b"}])
            data = json.load(open(path, encoding="utf-8"))
            self.assertEqual(len(data["drafts"]), 1)
            self.assertEqual(data["drafts"][0]["label"], "b")

    def test_draft_never_overwrites_live(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            live = os.path.join(d, "G.json")
            with open(live, "w", encoding="utf-8") as f:
                json.dump({"cheats": [{"label": "kept"}]}, f)
            draft = os.path.join(d, "G.draft.json")
            factory.write_drafts(draft, "G.exe", [{"label": "new"}])
            live_data = json.load(open(live, encoding="utf-8"))
            self.assertEqual(live_data["cheats"][0]["label"], "kept")


class TestPromote(unittest.TestCase):
    def test_promote_copies_anchor(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            live = os.path.join(d, "G.json")
            draft_entry = {"label": "gold", "verified": True,
                           "anchor": {"module_offset": "g.exe+0x1"},
                           "recipe": {"type": "dword"},
                           "value_type": "dword", "mode": "one_shot",
                           "target_value": 1, "look_for": "check"}
            cheat = factory.promote_draft(live, "G.exe", draft_entry)
            self.assertEqual(cheat["anchor"]["module_offset"], "g.exe+0x1")
            data = json.load(open(live, encoding="utf-8"))
            self.assertEqual(len(data["cheats"]), 1)


if __name__ == "__main__":
    unittest.main()
