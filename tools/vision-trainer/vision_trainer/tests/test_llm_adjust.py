"""Failing tests first (RED): adjust half of llm_client."""
import json
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from vision_trainer import llm_client


class FakeResp:
    def __init__(self, payload, status=200):
        self._payload = payload
        self.status_code = status

    def json(self):
        return self._payload

    def raise_for_status(self):
        if self.status_code >= 400:
            raise Exception(f"HTTP {self.status_code}")


def chat_payload(content):
    return {"choices": [{"message": {"role": "assistant", "content": content}}]}


class TestComputeWritePlan(unittest.TestCase):
    @patch("vision_trainer.llm_client.requests.post")
    def test_dword_100x(self, mock_post):
        body = json.dumps({"target_value": 500000, "value_type": "dword",
                           "scan_option": "exact"})
        mock_post.return_value = FakeResp(chat_payload(body))
        plan = llm_client.compute_write_plan(
            "http://localhost:20128/v1",
            "cmc/meta/muse-spark-1.3-contributor",
            "gold", 5000, "dword")
        self.assertEqual(plan["target_value"], 500000)
        self.assertEqual(plan["value_type"], "dword")

    @patch("vision_trainer.llm_client.requests.post")
    def test_uses_adjust_model_and_no_images(self, mock_post):
        body = json.dumps({"target_value": 1, "value_type": "dword"})
        mock_post.return_value = FakeResp(chat_payload(body))
        llm_client.compute_write_plan(
            "http://localhost:20128/v1",
            "cmc/meta/muse-spark-1.3-contributor",
            "gold", 5000, "dword")
        sent = mock_post.call_args[1]["json"]
        self.assertEqual(sent["model"], "cmc/meta/muse-spark-1.3-contributor")
        for msg in sent["messages"]:
            content = msg.get("content")
            if isinstance(content, list):
                for part in content:
                    self.assertNotEqual(part.get("type"), "image_url")

    @patch("vision_trainer.llm_client.requests.post")
    def test_float_between_tolerance(self, mock_post):
        body = json.dumps({"target_value": 99.5, "value_type": "float",
                           "scan_option": "between",
                           "tolerance": 0.01})
        mock_post.return_value = FakeResp(chat_payload(body))
        plan = llm_client.compute_write_plan(
            "http://localhost:20128/v1",
            "cmc/meta/muse-spark-1.3-contributor",
            "mana", 0.995, "float")
        self.assertEqual(plan["scan_option"], "between")
        self.assertIn("tolerance", plan)

    @patch("vision_trainer.llm_client.requests.post")
    def test_retries_on_garbage(self, mock_post):
        good = json.dumps({"target_value": 10, "value_type": "dword"})
        mock_post.side_effect = [
            FakeResp(chat_payload("junk")),
            FakeResp(chat_payload(good)),
        ]
        plan = llm_client.compute_write_plan(
            "http://localhost:20128/v1", "m", "gold", 5000, "dword")
        self.assertEqual(plan["target_value"], 10)

    @patch("vision_trainer.llm_client.requests.post")
    def test_raises_after_retries(self, mock_post):
        mock_post.return_value = FakeResp(chat_payload("junk {{{"))
        with self.assertRaises(ValueError):
            llm_client.compute_write_plan(
                "http://localhost:20128/v1", "m", "gold", 5000, "dword")


class TestLocalFallbackPlan(unittest.TestCase):
    def test_fallback_dword_multiplies(self):
        plan = llm_client.fallback_write_plan("gold", 5000, "dword")
        self.assertEqual(plan["target_value"], 500000)

    def test_fallback_float(self):
        plan = llm_client.fallback_write_plan("mana", 1.5, "float")
        self.assertAlmostEqual(plan["target_value"], 150.0)

    def test_fallback_overflow_clamps(self):
        plan = llm_client.fallback_write_plan("gold", 2**40, "dword")
        self.assertLessEqual(plan["target_value"], 2**32 - 1)
        self.assertTrue(plan.get("clamped"))

    def test_fallback_rejects_bad_type(self):
        with self.assertRaises(ValueError):
            llm_client.fallback_write_plan("x", 1, "string")


if __name__ == "__main__":
    unittest.main()
