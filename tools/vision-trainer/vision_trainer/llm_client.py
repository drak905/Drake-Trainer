"""Local LLM client (OpenAI-compatible): vision extract/verify + adjust planning."""

import json
import re

import requests

from . import config as config_mod

MAX_RETRIES = 3
DEFAULT_MIN_CONFIDENCE = 0.0

ALLOWED_VALUE_TYPES = ("byte", "word", "dword", "qword", "float", "double")

# Models drift from the allowed vocabulary ("integer", "int"); map to CE types.
_VALUE_TYPE_ALIASES = {
    "integer": "dword",
    "int": "dword",
    "long": "qword",
    "short": "word",
    "single": "float",
}

TYPE_LIMITS = {
    "byte": (0, 0xFF),
    "word": (0, 0xFFFF),
    "dword": (0, 0xFFFFFFFF),
    "qword": (0, 0xFFFFFFFFFFFFFFFF),
}

EXTRACT_SYSTEM = (
    "You read offline game HUD screenshots. Reply with strict JSON only, "
    "no prose. Shape: {\"values\": [{\"label\": str, \"value\": number, "
    "\"value_type\": one of byte|word|dword|qword|float|double, "
    "\"confidence\": 0.0-1.0}]}. Guess value_type from formatting: "
    "plain integers are dword unless huge (qword) or tiny (byte/word); "
    "decimals/bars are float."
)

VERIFY_SYSTEM = (
    "You compare two game screenshots (before/after a memory edit). "
    "Reply with strict JSON only: {\"observed\": number, \"match\": bool} "
    "where match is true when the after image shows the expected value."
)

ADJUST_SYSTEM = (
    "You plan a Cheat Engine memory write. Reply with strict JSON only: "
    "{\"target_value\": number, \"value_type\": str, "
    "\"scan_option\": exact|between, \"tolerance\": number?, "
    "\"clamped\": bool?}. Multiply the observed value by the given "
    "multiplier. Keep the "
    "given value_type unless overflow forces a wider type. Use scan_option "
    "between with a small tolerance for float/double."
)


def _post_chat(endpoint, model, messages, timeout=120):
    url = config_mod.chat_url(endpoint)
    payload = {"model": model, "messages": messages, "stream": False}
    try:
        payload["response_format"] = {"type": "json_object"}
        resp = requests.post(url, json=payload, timeout=timeout)
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, dict) and "choices" not in data:
            raise ValueError(f"Non-chat response (SSE?): {str(data)[:200]}")
        return data
    except Exception:
        payload = dict(payload)
        payload.pop("response_format", None)
        resp = requests.post(url, json=payload, timeout=timeout)
        resp.raise_for_status()
        return resp.json()


def _assistant_text(response):
    try:
        return response["choices"][0]["message"]["content"] or ""
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError(f"Unexpected chat response shape: {response!r}") from exc


def _extract_json(text):
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip(),
                     flags=re.IGNORECASE)
    try:
        return json.loads(cleaned)
    except ValueError:
        pass
    try:
        return json.loads(text)
    except ValueError:
        pass
    match = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if not match:
        raise ValueError(f"No JSON object in model reply: {text!r}")
    return json.loads(match.group(0))


def _image_part(b64):
    return {"type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}


def extract_values(endpoint, model, image_b64, min_confidence=DEFAULT_MIN_CONFIDENCE):
    messages = [{
        "role": "user",
        "content": [
            {"type": "text",
             "text": "List every numeric game stat visible (currency, "
                     "health, mana, ammo, score). Strict JSON only."},
            _image_part(image_b64),
        ],
    }]
    last_error = None
    for _ in range(MAX_RETRIES):
        try:
            data = _extract_json(_assistant_text(
                _post_chat(endpoint, model, messages,
                           timeout=120)))
            values = data.get("values")
            if not isinstance(values, list):
                raise ValueError("reply missing 'values' list")
            return _clean_entries(values, min_confidence)
        except (ValueError, KeyError, TypeError) as exc:
            last_error = exc
    raise ValueError(f"Vision model gave no usable JSON: {last_error}")


def _clean_entries(entries, min_confidence):
    cleaned = []
    for v in entries:
        conf = float(v.get("confidence", 1.0))
        if conf < min_confidence:
            raise ValueError(
                f"confidence {conf} below {min_confidence}")
        vtype = str(v.get("value_type", "dword")).lower()
        vtype = _VALUE_TYPE_ALIASES.get(vtype, vtype)
        if vtype not in ALLOWED_VALUE_TYPES:
            raise ValueError(f"bad value_type {vtype!r}")
        cleaned.append({
            "label": str(v.get("label", "unknown")),
            "value": v.get("value"),
            "value_type": vtype,
            "confidence": conf,
        })
    return cleaned


def normalize_flat_stats(data):
    """Accept strict {"values": [...]} or a flat {name: number} reply.

    Returns (entries, strict_shape). Flat numbers become dword (int) or
    float entries with 0.7 confidence, since the model went off-spec.
    """
    if isinstance(data, dict) and isinstance(data.get("values"), list):
        return list(data["values"]), True
    if isinstance(data, dict):
        pairs = [(key, val) for key, val in data.items()
                 if isinstance(val, (int, float))
                 and not isinstance(val, bool)]
        if not pairs:
            raise ValueError("no numeric stats in flat reply")
        return ([{"label": str(key), "value": val,
                  "value_type": ("float" if isinstance(val, float)
                                 else "dword"),
                  "confidence": 0.7} for key, val in pairs], False)
    raise ValueError(f"unrecognized stats shape: {type(data).__name__}")


def extract_values_auto(endpoint, model, image_b64,
                        min_confidence=DEFAULT_MIN_CONFIDENCE):
    """Lenient extract_values: also accepts flat {stat: number} replies.

    Returns {"values", "strict_shape"}. Retries garbage like extract_values.
    """
    messages = [{
        "role": "user",
        "content": [
            {"type": "text",
             "text": "List every numeric game stat visible (currency, "
                     "health, mana, ammo, score). Strict JSON only: "
                     "{\"values\": [{\"label\", \"value\", "
                     "\"value_type\", \"confidence\"}]}."},
            _image_part(image_b64),
        ],
    }]
    last_error = None
    for _ in range(MAX_RETRIES):
        try:
            data = _extract_json(_assistant_text(
                _post_chat(endpoint, model, messages,
                           timeout=120)))
            entries, strict = normalize_flat_stats(data)
            return {"values": _clean_entries(entries, min_confidence),
                    "strict_shape": strict}
        except (ValueError, KeyError, TypeError) as exc:
            last_error = exc
    raise ValueError(f"Vision model gave no usable stats: {last_error}")


def verify_value(endpoint, model, before_b64, after_b64, expected):
    messages = [{
        "role": "user",
        "content": [
            {"type": "text",
             "text": f"The first image is before, the second is after. "
                     f"Expected value is {expected}. Strict JSON only: "
                     "{\"observed\": number, \"match\": bool}."},
            _image_part(before_b64),
            _image_part(after_b64),
        ],
    }]
    last_error = None
    for _ in range(MAX_RETRIES):
        try:
            data = _extract_json(_assistant_text(
                _post_chat(endpoint, model, messages, timeout=120)))
            return {"observed": data["observed"],
                    "match": bool(data["match"])}
        except (ValueError, KeyError, TypeError) as exc:
            last_error = exc
    raise ValueError(f"Verify model gave no usable JSON: {last_error}")


def compute_write_plan(endpoint, model, label, value, value_type,
                       multiplier=100):
    messages = [
        {"role": "system", "content": ADJUST_SYSTEM},
        {"role": "user",
         "content": json.dumps({"label": label, "value": value,
                                "value_type": value_type,
                                "multiplier": multiplier})},
    ]
    last_error = None
    for _ in range(MAX_RETRIES):
        try:
            data = _extract_json(_assistant_text(
                _post_chat(endpoint, model, messages, timeout=60)))
            target = data["target_value"]
            vtype = str(data.get("value_type", value_type)).lower()
            if vtype not in ALLOWED_VALUE_TYPES:
                raise ValueError(f"bad value_type {vtype!r}")
            return {
                "target_value": target,
                "value_type": vtype,
                "scan_option": data.get("scan_option", "exact"),
                "tolerance": data.get("tolerance", 0),
                "clamped": bool(data.get("clamped", False)),
                "multiplier": multiplier,
            }
        except (ValueError, KeyError, TypeError) as exc:
            last_error = exc
    raise ValueError(f"Adjust model gave no usable JSON: {last_error}")


def fallback_write_plan(label, value, value_type, multiplier=100):
    vtype = (value_type or "dword").lower()
    if vtype not in ALLOWED_VALUE_TYPES:
        raise ValueError(f"unsupported value_type {value_type!r}")
    target = value * multiplier
    clamped = False
    if vtype in TYPE_LIMITS:
        lo, hi = TYPE_LIMITS[vtype]
        if isinstance(target, float):
            target = int(target)
        if target > hi:
            target, clamped = hi, True
        elif target < lo:
            target, clamped = lo, True
    plan = {"target_value": target, "value_type": vtype,
            "scan_option": "exact", "tolerance": 0, "clamped": clamped,
            "multiplier": multiplier}
    if vtype in ("float", "double"):
        plan["scan_option"] = "between"
        plan["tolerance"] = abs(float(value)) * 0.001 or 0.0001
    return plan
