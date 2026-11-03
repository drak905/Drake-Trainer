"""Per-game JSON profiles: machine-readable cheats beside the RUNBOOK log.

Schema v1:
{schema: 1, exe, game_title, updated, cheats: [{label, value_type, mode,
 recipe: {type, protection, scan_option, narrow_rounds, hits},
 anchor: {...}|null, patch: {...}|null, last_address, module_offset,
 signature|null, target_value, verified, look_for}]}
"""

import datetime
import json
import os
import re
import xml.sax.saxutils as saxutils

SCHEMA_VERSION = 1
PROFILES_DIR_NAME = "profiles"

ALLOWED_VALUE_TYPES = ("byte", "word", "dword", "qword",
                       "float", "double")

MODES = ("one_shot", "freeze", "display")


def sanitize_name(name):
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", (name or "").strip())
    cleaned = cleaned.strip("._") or "unknown"
    return cleaned[:64]


def default_profiles_dir():
    base = os.environ.get("APPDATA") or os.path.expanduser("~")
    return os.path.join(base, "VisionTrainer", PROFILES_DIR_NAME)


def resolve_path(process_name, base_dir=None):
    base = base_dir or default_profiles_dir()
    return os.path.join(base, sanitize_name(process_name) + ".json")


def draft_path(process_name, base_dir=None):
    base = base_dir or default_profiles_dir()
    return os.path.join(base, sanitize_name(process_name) + ".draft.json")


def _blank(exe):
    return {"schema": SCHEMA_VERSION, "exe": exe, "game_title": "",
            "updated": "", "cheats": []}


def load(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return _blank("")
    if not isinstance(data, dict) or not isinstance(
            data.get("cheats"), list):
        return _blank(data.get("exe", "") if isinstance(data, dict) else "")
    data.setdefault("schema", SCHEMA_VERSION)
    data.setdefault("exe", "")
    return data


def save(path, data):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    data["updated"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    payload = json.dumps(data, indent=2)
    import uuid
    tmp = f"{path}.tmp{os.getpid()}.{uuid.uuid4().hex[:8]}"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)  # atomic: readers see old or new, never partial
    return path


def upsert_cheat(path, exe, cheat):
    data = load(path)
    if not data.get("exe"):
        data["exe"] = exe
    label = str(cheat.get("label", "stat"))
    cheat = dict(cheat)
    cheat["label"] = label
    if cheat.get("mode") not in MODES:
        cheat["mode"] = "one_shot"
    data["cheats"] = [c for c in data["cheats"]
                      if str(c.get("label")) != label]
    data["cheats"].append(cheat)
    save(path, data)
    return cheat


def validate_profile(path):
    """Offline check: file loads, schema v1, every cheat intact.
    Returns one row per cheat (pass/fail + reason); never modifies files."""
    results = []
    if not os.path.exists(path):
        return {"exists": False, "schema_ok": False, "cheats": [],
                "summary": "No profile file."}
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as exc:
        return {"exists": True, "schema_ok": False, "cheats": [],
                "summary": f"Profile unreadable: {exc}"}
    if not isinstance(data, dict) or not isinstance(
            data.get("cheats"), list):
        return {"exists": True, "schema_ok": False, "cheats": [],
                "summary": "Profile JSON has no cheats list."}
    schema_ok = data.get("schema") == SCHEMA_VERSION
    for cheat in data["cheats"]:
        if not isinstance(cheat, dict):
            results.append({"label": str(cheat)[:40],
                            "status": "fail",
                            "problems": ["entry is not an object"]})
            continue
        label = str(cheat.get("label", "?"))
        problems = []
        if not str(cheat.get("label") or "").strip():
            problems.append("missing label")
        if cheat.get("value_type") not in ALLOWED_VALUE_TYPES:
            problems.append(f"bad value_type {cheat.get('value_type')!r}")
        if cheat.get("mode") not in MODES:
            problems.append(f"bad mode {cheat.get('mode')!r}")
        anchor = cheat.get("anchor")
        patch = cheat.get("patch")
        if isinstance(anchor, dict) and anchor.get("capture_mode"):
            pass  # live-object anchored: legitimate shape, exports skipped
        elif patch:
            pass  # patch-anchored: legitimate shape
        elif not isinstance(anchor, dict) or not anchor:
            problems.append("missing anchor")
        else:
            has_rung = (anchor.get("module_offset")
                        or anchor.get("signature")
                        or anchor.get("pointer_chain"))
            if not has_rung:
                problems.append("anchor has no relocation rung")
        if cheat.get("target_value") in (None, ""):
            problems.append("missing target_value")
        results.append({"label": label,
                        "status": "fail" if problems else "pass",
                        "problems": problems})
    labels = [r.get("label") for r in data["cheats"]
              if isinstance(r, dict)]
    duplicates = {l for l in labels if labels.count(l) > 1}
    if duplicates:
        results.append({"label": ", ".join(sorted(duplicates)),
                        "status": "fail",
                        "problems": ["duplicate labels"]})
    summary = (f"{sum(1 for r in results if r['status'] == 'pass')} pass / "
               f"{sum(1 for r in results if r['status'] == 'fail')} fail"
               + ("" if schema_ok else f" — schema not v{SCHEMA_VERSION}"))
    return {"exists": True, "schema_ok": schema_ok, "cheats": results,
            "summary": summary}


def get_cheat(path, label):
    for cheat in load(path).get("cheats", []):
        if str(cheat.get("label")) == str(label):
            return cheat
    return None


def list_cheats(path):
    return load(path).get("cheats", [])


_AA_DIRECTIVES = {"byte": "db", "word": "dw", "dword": "dd",
                  "qword": "dq"}


def _aa_script_for_signature(label, anchor, value_type="dword",
                             target_value=None):
    if target_value in (None, ""):
        return None  # caller must skip-with-reason, not emit a value wipe
    vtype = str(value_type or "dword").lower()
    if vtype not in ALLOWED_VALUE_TYPES:
        return None
    sig = anchor.get("signature", "")
    module = anchor.get("module", "")
    offset = anchor.get("offset", 0)
    safe_label = sanitize_name(label).replace("-", "_")

    if vtype in ("float", "double"):
        directive = (f"(double){float(target_value)}"
                     if vtype == "double"
                     else f"(float){float(target_value)}")
    else:
        directive = f'{_AA_DIRECTIVES[vtype]} {int(target_value)}'
    return (f'// {safe_label}: signature-anchored value write '
            f'(module {module})\n'
            f'[ENABLE]\n'
            f'aobscanmodule(sig_{safe_label},{module},{sig})\n'
            f'sig_{safe_label}+{offset}:\n'
            f'  {directive}\n'
            f'[DISABLE]\n'
            f'// restore the original value of {safe_label} here '
            '(re-scan to find it)\n')


def _aa_script_for_patch(label, patch):
    addr = patch.get("address", "0x0")
    orig = " ".join(f"{b:02X}" for b in patch.get("original_bytes", []))
    new = " ".join(f"{b:02X}" for b in patch.get("patched_bytes", []))
    return (f"// {label}: code patch at {addr}\n"
            f"// original: {orig}\n"
            f"{addr}:\n"
            f"  db {new}  // patched: was {orig}\n")


def export_ct_entries(cheats):
    entries = []
    skipped = []
    for cheat in cheats:
        label = str(cheat.get("label", "stat"))
        vtype = str(cheat.get("value_type", "dword"))
        anchor = cheat.get("anchor") or {}
        patch = cheat.get("patch")
        if patch:
            entries.append({"kind": "aa_script", "label": label,
                            "script": _aa_script_for_patch(label, patch)})
        elif anchor.get("signature"):
            script = _aa_script_for_signature(
                label, anchor, vtype, cheat.get("target_value"))
            if script is None:
                skipped.append({"label": label,
                                "reason": "bad/missing target or "
                                          "value_type for signature "
                                          "value write"})
            else:
                entries.append({"kind": "aa_script", "label": label,
                                "script": script})
        elif anchor.get("capture_mode"):
            skipped.append({"label": label,
                            "reason": f"capture/{anchor['capture_mode']} "
                                      "patches have no Cheat Engine "
                                      "equivalent (live-object anchored)"})
        elif anchor.get("pointer_chain"):
            chain = anchor["pointer_chain"]
            entries.append({"kind": "address", "label": label,
                            "address": str(chain.get("base", "")),
                            "offsets": list(chain.get("offsets", [])),
                            "type": vtype})
        elif anchor.get("module_offset") or cheat.get("module_offset"):
            entries.append({"kind": "address", "label": label,
                            "address": str(anchor.get("module_offset")
                                           or cheat.get("module_offset")),
                            "offsets": [], "type": vtype})
        elif cheat.get("last_address"):
            entries.append({"kind": "address", "label": label,
                            "address": str(cheat.get("last_address")),
                            "offsets": [], "type": vtype,
                            "stale_warning": True})
        else:
            skipped.append({"label": label,
                            "reason": "no anchor, address, or patch known"})
    return entries, skipped


def write_ct_file(path, cheats):
    entries, _skipped = export_ct_entries(cheats)
    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             '<CheatTable CheatEngineTableVersion="42">',
             '  <CheatEntries>']
    for i, entry in enumerate(entries):
        label = saxutils.escape(entry["label"])
        if entry["kind"] == "aa_script":
            script = saxutils.escape(entry["script"])
            lines.append(
                f'    <CheatEntry><ID>{i}</ID>'
                f'<Description>{label} (auto-assemble)</Description>'
                f'<VariableType>Auto Assembler Script</VariableType>'
                f'<AssemblerScript>{script}</AssemblerScript>'
                f'</CheatEntry>')
        else:
            addr = saxutils.escape(entry["address"])
            lines.append(
                f'    <CheatEntry><ID>{i}</ID>'
                f'<Description>{label}</Description>'
                f'<VariableType>{entry["type"]}</VariableType>'
                f'<Address>{addr}</Address>'
                f'</CheatEntry>')
    lines.append('  </CheatEntries>')
    lines.append('</CheatTable>')
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return len(entries)
