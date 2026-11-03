"""Failing tests first (RED): config load/save/list_models + defaults."""
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from vision_trainer import config


class TestConfigDefaults(unittest.TestCase):
    def test_default_endpoint(self):
        self.assertEqual(
            config.DEFAULT_ENDPOINT, "http://localhost:20128/v1"
        )

    def test_default_config_prefills_endpoint(self):
        cfg = config.default_config()
        self.assertEqual(cfg["endpoint"], "http://localhost:20128/v1")
        self.assertIn("vision_model", cfg)
        self.assertIn("adjust_model", cfg)


class TestEndpointNormalization(unittest.TestCase):
    def test_strips_trailing_slash(self):
        self.assertEqual(
            config.normalize_endpoint("http://localhost:20128/v1/"),
            "http://localhost:20128/v1",
        )

    def test_strips_whitespace(self):
        self.assertEqual(
            config.normalize_endpoint("  http://localhost:20128/v1  "),
            "http://localhost:20128/v1",
        )

    def test_models_url_appends_models(self):
        self.assertEqual(
            config.models_url("http://localhost:20128/v1"),
            "http://localhost:20128/v1/models",
        )

    def test_models_url_no_double_v1(self):
        self.assertEqual(
            config.models_url("http://localhost:20128/v1/"),
            "http://localhost:20128/v1/models",
        )

    def test_chat_url_appends_chat_completions(self):
        self.assertEqual(
            config.chat_url("http://localhost:20128/v1"),
            "http://localhost:20128/v1/chat/completions",
        )


class TestConfigValidation(unittest.TestCase):
    def test_valid_config(self):
        ok, err = config.validate_config({
            "endpoint": "http://localhost:20128/v1",
            "vision_model": "ag/gemini-3.8-flash-high",
            "adjust_model": "cmc/meta/muse-spark-1.3-contributor",
        })
        self.assertTrue(ok)
        self.assertEqual(err, "")

    def test_missing_endpoint(self):
        ok, err = config.validate_config({
            "vision_model": "a",
            "adjust_model": "b",
        })
        self.assertFalse(ok)
        self.assertIn("endpoint", err.lower())

    def test_missing_vision_model(self):
        ok, err = config.validate_config({
            "endpoint": "http://x/v1",
            "adjust_model": "b",
        })
        self.assertFalse(ok)
        self.assertIn("vision", err.lower())

    def test_missing_adjust_model(self):
        ok, err = config.validate_config({
            "endpoint": "http://x/v1",
            "vision_model": "a",
        })
        self.assertFalse(ok)
        self.assertIn("adjust", err.lower())

    def test_review_note_models_accepted(self):
        ok, _ = config.validate_config({
            "endpoint": "http://localhost:20128/v1",
            "vision_model": "ag/gemini-3.8-flash-high",
            "adjust_model": "cmc/meta/muse-spark-1.3-contributor",
        })
        self.assertTrue(ok)


class TestConfigPersistence(unittest.TestCase):
    def test_save_and_load_roundtrip(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "config.json")
            cfg = {
                "endpoint": "http://localhost:20128/v1",
                "vision_model": "ag/gemini-3.8-flash-high",
                "adjust_model": "cmc/meta/muse-spark-1.3-contributor",
            }
            config.save_config(cfg, path)
            loaded = config.load_config(path)
            self.assertEqual(loaded, cfg)

    def test_load_missing_returns_none(self):
        self.assertIsNone(config.load_config("nonexistent-xyz.json"))

    def test_load_corrupt_returns_none(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "config.json")
            with open(path, "w") as f:
                f.write("{not valid json")
            self.assertIsNone(config.load_config(path))

    def test_default_path_uses_appdata(self):
        with patch.dict(os.environ, {"APPDATA": "C:\\Fake\\AppData"}):
            p = config.default_config_path()
        self.assertIn("VisionTrainer", p)
        self.assertTrue(p.endswith("config.json"))


class FakeResp:
    def __init__(self, payload, status=200):
        self._payload = payload
        self.status_code = status

    def json(self):
        return self._payload

    def raise_for_status(self):
        if self.status_code >= 400:
            raise Exception(f"HTTP {self.status_code}")


class TestListModels(unittest.TestCase):
    @patch("vision_trainer.config.requests.get")
    def test_lists_openai_compatible_models(self, mock_get):
        mock_get.return_value = FakeResp({
            "data": [
                {"id": "ag/gemini-3.8-flash-high"},
                {"id": "cmc/meta/muse-spark-1.3-contributor"},
            ]
        })
        models = config.list_models("http://localhost:20128/v1")
        self.assertEqual(models, [
            "ag/gemini-3.8-flash-high",
            "cmc/meta/muse-spark-1.3-contributor",
        ])
        called_url = mock_get.call_args[0][0]
        self.assertEqual(called_url, "http://localhost:20128/v1/models")

    @patch("vision_trainer.config.requests.get")
    def test_endpoint_unreachable_raises(self, mock_get):
        import requests as req
        mock_get.side_effect = req.ConnectionError("refused")
        with self.assertRaises(ConnectionError):
            config.list_models("http://localhost:20128/v1")

    @patch("vision_trainer.config.requests.get")
    def test_ollama_tags_shape_supported(self, mock_get):
        mock_get.return_value = FakeResp({
            "models": [{"name": "qwen2-vl:7b"}, {"name": "llava:7b"}]
        })
        models = config.list_models("http://localhost:11434")
        self.assertEqual(models, ["qwen2-vl:7b", "llava:7b"])


if __name__ == "__main__":
    unittest.main()
