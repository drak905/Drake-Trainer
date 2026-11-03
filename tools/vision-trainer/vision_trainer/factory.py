"""Cheat factory: wishlist categories -> drafts -> promote.

Drafts go to <Game>.draft.json (replaced wholesale each run, live profile
never touched). Promote copies a verified draft into the live profile.
Plausible != right field: GUI must stress in-game verification.
"""

import json
import os
import re

from . import categories as categories_mod
from . import profiles as profiles_mod


def classify_trap(value):
    label = str(value.get("label", "")).lower()
    for name, reason in categories_mod.MANUAL_ONLY.items():
        if name in label:
            return "manual", f"{name}: {reason}"
    return None, ""


def match_category(value):
    trap, _reason = classify_trap(value)
    if trap:
        return None
    label = str(value.get("label", ""))
    vtype = str(value.get("value_type", "dword")).lower()
    try:
        numeric = float(value.get("value", 0))
    except (TypeError, ValueError):
        return None
    for name, cat in categories_mod.CATEGORIES.items():
        if vtype not in cat["types"]:
            continue
        if not any(re.search(hint, label, re.IGNORECASE)
                   for hint in cat["name_hints"]):
            continue
        lo, hi = cat["plausible"]
        if not (lo <= numeric <= hi):
            continue
        return name
    return None


def draft_cheats(values, wishlist):
    wanted = [str(w).lower() for w in wishlist]
    drafts = []
    manual = []
    seen_labels = {}
    for value in values:
        trap, reason = classify_trap(value)
        if trap:
            manual.append({"label": value.get("label"),
                           "reason": reason})
            continue
        cat_name = match_category(value)
        if cat_name is None or cat_name not in wanted:
            continue
        cat = categories_mod.CATEGORIES[cat_name]
        label = str(value.get("label"))
        seen_labels[label] = seen_labels.get(label, 0) + 1
        drafts.append({
            "label": label,
            "category": cat_name,
            "value": value.get("value"),
            "value_type": value.get("value_type", "dword"),
            "mode": cat["mode"],
            "verified": bool(value.get("confidence", 0)) >= 0.0
            and _plausible_live(value, cat),
            "live_value": value.get("value"),
            "multi_instance_risk": seen_labels[label] > 1,
            "look_for": cat["look_for"],
            "anchor": None,
            "recipe": None,
        })
    for want in wanted:
        if want in categories_mod.MANUAL_ONLY:
            manual.append({"label": want,
                           "reason": categories_mod.MANUAL_ONLY[want]})
        elif not any(d["category"] == want for d in drafts):
            manual.append({"label": want,
                           "reason": "no extracted value matched; "
                                     "fall back to manual scan."})
    return drafts, manual


def _plausible_live(value, cat):
    try:
        numeric = float(value.get("value", 0))
    except (TypeError, ValueError):
        return False
    lo, hi = cat["plausible"]
    return lo <= numeric <= hi


def write_drafts(path, exe, drafts):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    payload = {"exe": exe, "drafts": list(drafts),
               "note": "Drafts only — verify each in-game, then promote. "
                       "Replaced wholesale on every factory run."}
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    return path


def read_drafts(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return []
    drafts = data.get("drafts", [])
    return drafts if isinstance(drafts, list) else []


def promote_draft(live_path, exe, draft):
    cheat = {
        "label": draft.get("label", "stat"),
        "value_type": draft.get("value_type", "dword"),
        "mode": draft.get("mode", "one_shot"),
        "recipe": draft.get("recipe") or {},
        "anchor": draft.get("anchor"),
        "last_address": draft.get("address", ""),
        "module_offset": draft.get("module_offset", ""),
        "signature": draft.get("signature"),
        "target_value": draft.get("target_value",
                                  draft.get("live_value", "")),
        "verified": bool(draft.get("verified", False)),
        "look_for": draft.get("look_for", ""),
    }
    return profiles_mod.upsert_cheat(live_path, exe, cheat)
