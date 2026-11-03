"""Vision Trainer configuration: LLM endpoint + vision/adjust models."""

import json
import os

import requests

DEFAULT_ENDPOINT = "http://localhost:20128/v1"

CONFIG_FILENAME = "config.json"
APP_DIR_NAME = "VisionTrainer"


def default_config():
    return {
        "endpoint": DEFAULT_ENDPOINT,
        "vision_model": "",
        "adjust_model": "",
    }


def normalize_endpoint(endpoint):
    return (endpoint or "").strip().rstrip("/")


def models_url(endpoint):
    return normalize_endpoint(endpoint) + "/models"


def chat_url(endpoint):
    return normalize_endpoint(endpoint) + "/chat/completions"


def validate_config(cfg):
    if not isinstance(cfg, dict):
        return False, "config must be an object"
    if not (cfg.get("endpoint") or "").strip():
        return False, "endpoint is required"
    if not (cfg.get("vision_model") or "").strip():
        return False, "vision model is required"
    if not (cfg.get("adjust_model") or "").strip():
        return False, "adjust model is required"
    return True, ""


def default_config_path():
    base = os.environ.get("APPDATA") or os.path.expanduser("~")
    directory = os.path.join(base, APP_DIR_NAME)
    return os.path.join(directory, CONFIG_FILENAME)


def load_config(path=None):
    path = path or default_config_path()
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    ok, _ = validate_config(data)
    if not ok:
        return None
    data["endpoint"] = normalize_endpoint(data["endpoint"])
    return data


def save_config(cfg, path=None):
    ok, err = validate_config(cfg)
    if not ok:
        raise ValueError(err)
    path = path or default_config_path()
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    payload = {
        "endpoint": normalize_endpoint(cfg["endpoint"]),
        "vision_model": cfg["vision_model"],
        "adjust_model": cfg["adjust_model"],
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    return path


def list_models(endpoint):
    url = models_url(endpoint)
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        payload = resp.json()
    except Exception as exc:
        raise ConnectionError(
            f"Could not reach LLM endpoint {url}: {exc}"
        ) from exc
    if isinstance(payload, dict) and isinstance(payload.get("data"), list):
        return [m.get("id", "") for m in payload["data"] if m.get("id")]
    if isinstance(payload, dict) and isinstance(payload.get("models"), list):
        names = []
        for m in payload["models"]:
            name = m.get("name") or m.get("model") or m.get("id")
            if name:
                names.append(name)
        return names
    if isinstance(payload, list):
        return [m for m in payload if isinstance(m, str)]
    raise ValueError(f"Unrecognized model list shape from {url}")
