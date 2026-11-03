"""Failing tests first (RED): vision half of llm_client."""
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


def chat_payload(content, model="ag/gemini-3.8-flash-high"):
    return {
        "id": "chatcmpl-1",
        "choices": [{"message": {"role": "assistant", "content": content}}],
        "model": model,
    }


class TestExtractValues(unittest.TestCase):
    @patch("vision_trainer.llm_client.requests.post")
    def test_parses_strict_json(self, mock_post):
        body = json.dumps({"values": [
            {"label": "gold", "value": 5000,
             "value_type": "dword", "confidence": 0.95}
        ]})
        mock_post.return_value = FakeResp(chat_payload(body))
        out = llm_client.extract_values(
            "http://localhost:20128/v1", "ag/gemini-3.8-flash-high", "AAAABBBB")
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0]["label"], "gold")
        self.assertEqual(out[0]["value"], 5000)
        self.assertEqual(out[0]["value_type"], "dword")

    @patch("vision_trainer.llm_client.requests.post")
    def test_posts_to_chat_completions_with_image(self, mock_post):
        body = json.dumps({"values": []})
        mock_post.return_value = FakeResp(chat_payload(body))
        llm_client.extract_values(
            "http://localhost:20128/v1", "ag/gemini-3.8-flash-high", "AAAABBBB")
        url = mock_post.call_args[0][0]
        self.assertEqual(url, "http://localhost:20128/v1/chat/completions")
        sent = mock_post.call_args[1]["json"]
        self.assertEqual(sent["model"], "ag/gemini-3.8-flash-high")
        content = sent["messages"][0]["content"]
        kinds = [c.get("type") for c in content]
        self.assertIn("image_url", kinds)

    @patch("vision_trainer.llm_client.requests.post")
    def test_retries_on_garbage_then_parses(self, mock_post):
        good = json.dumps({"values": [
            {"label": "hp", "value": 100,
             "value_type": "dword", "confidence": 0.9}
        ]})
        mock_post.side_effect = [
            FakeResp(chat_payload("not json at all {{{")),
            FakeResp(chat_payload(good)),
        ]
        out = llm_client.extract_values(
            "http://localhost:20128/v1", "ag/gemini-3.8-flash-high", "AAA")
        self.assertEqual(out[0]["label"], "hp")

    @patch("vision_trainer.llm_client.requests.post")
    def test_raises_after_three_bad_responses(self, mock_post):
        mock_post.return_value = FakeResp(chat_payload("garbage {{{"))
        with self.assertRaises(ValueError):
            llm_client.extract_values(
                "http://localhost:20128/v1", "ag/gemini-3.8-flash-high", "AAA")
        self.assertEqual(mock_post.call_count, 3)

    @patch("vision_trainer.llm_client.requests.post")
    def test_low_confidence_rejected(self, mock_post):
        body = json.dumps({"values": [
            {"label": "gold", "value": 1,
             "value_type": "dword", "confidence": 0.1}
        ]})
        mock_post.return_value = FakeResp(chat_payload(body))
        with self.assertRaises(ValueError):
            llm_client.extract_values(
                "http://localhost:20128/v1", "ag/gemini-3.8-flash-high",
                "AAA", min_confidence=0.5)


class TestExtractValuesAuto(unittest.TestCase):
    @patch("vision_trainer.llm_client.requests.post")
    def test_accepts_strict_shape(self, mock_post):
        body = json.dumps({"values": [
            {"label": "hp", "value": 150,
             "value_type": "dword", "confidence": 0.9}
        ]})
        mock_post.return_value = FakeResp(chat_payload(body))
        out = llm_client.extract_values_auto(
            "http://localhost:20128/v1", "m", "AAA")
        self.assertTrue(out["strict_shape"])
        self.assertEqual(out["values"][0]["value"], 150)

    @patch("vision_trainer.llm_client.requests.post")
    def test_accepts_flat_shape(self, mock_post):
        body = json.dumps({"current_health": 150,
                           "max_health": 150, "level": 1})
        mock_post.return_value = FakeResp(chat_payload(body))
        out = llm_client.extract_values_auto(
            "http://localhost:20128/v1", "m", "AAA")
        self.assertFalse(out["strict_shape"])
        by_label = {v["label"]: v for v in out["values"]}
        self.assertEqual(by_label["current_health"]["value"], 150)
        self.assertEqual(by_label["current_health"]["value_type"],
                         "dword")

    @patch("vision_trainer.llm_client.requests.post")
    def test_flat_float_and_bool_handling(self, mock_post):
        body = json.dumps({"mana": 12.5, "paused": True})
        mock_post.return_value = FakeResp(chat_payload(body))
        out = llm_client.extract_values_auto(
            "http://localhost:20128/v1", "m", "AAA")
        self.assertEqual(len(out["values"]), 1)
        self.assertEqual(out["values"][0]["value_type"], "float")

    @patch("vision_trainer.llm_client.requests.post")
    def test_list_reply_retried_then_raises(self, mock_post):
        mock_post.return_value = FakeResp(chat_payload("[1, 2, 3]"))
        with self.assertRaises(ValueError):
            llm_client.extract_values_auto(
                "http://localhost:20128/v1", "m", "AAA")
        self.assertEqual(mock_post.call_count, 3)

    @patch("vision_trainer.llm_client.requests.post")
    def test_garbage_raises(self, mock_post):
        mock_post.return_value = FakeResp(chat_payload("garbage {{{"))
        with self.assertRaises(ValueError):
            llm_client.extract_values_auto(
                "http://localhost:20128/v1", "m", "AAA")
        self.assertEqual(mock_post.call_count, 3)

    @patch("vision_trainer.llm_client.requests.post")
    def test_value_type_alias_integer(self, mock_post):
        body = json.dumps({"values": [
            {"label": "hp", "value": 9999,
             "value_type": "integer", "confidence": 0.9}
        ]})
        mock_post.return_value = FakeResp(chat_payload(body))
        out = llm_client.extract_values_auto(
            "http://localhost:20128/v1", "m", "AAA")
        self.assertEqual(out["values"][0]["value_type"], "dword")


class TestVerifyValue(unittest.TestCase):
    @patch("vision_trainer.llm_client.requests.post")
    def test_match_true(self, mock_post):
        body = json.dumps({"observed": 500000, "match": True})
        mock_post.return_value = FakeResp(chat_payload(body))
        out = llm_client.verify_value(
            "http://localhost:20128/v1", "ag/gemini-3.8-flash-high",
            "BEFORE", "AFTER", 500000)
        self.assertTrue(out["match"])
        self.assertEqual(out["observed"], 500000)

    @patch("vision_trainer.llm_client.requests.post")
    def test_match_false(self, mock_post):
        body = json.dumps({"observed": 5000, "match": False})
        mock_post.return_value = FakeResp(chat_payload(body))
        out = llm_client.verify_value(
            "http://localhost:20128/v1", "ag/gemini-3.8-flash-high",
            "BEFORE", "AFTER", 500000)
        self.assertFalse(out["match"])

    @patch("vision_trainer.llm_client.requests.post")
    def test_verify_sends_both_images(self, mock_post):
        body = json.dumps({"observed": 1, "match": True})
        mock_post.return_value = FakeResp(chat_payload(body))
        llm_client.verify_value(
            "http://localhost:20128/v1", "ag/gemini-3.8-flash-high",
            "BEFORE64", "AFTER64", 1)
        sent = mock_post.call_args[1]["json"]
        content = sent["messages"][0]["content"]
        images = [c for c in content if c.get("type") == "image_url"]
        self.assertEqual(len(images), 2)


if __name__ == "__main__":
    unittest.main()
