"""Per-game RUNBOOK: append-only markdown experience log."""

import datetime
import os
import re

RUNBOOK_DIR_NAME = "runbooks"
ASSETS_DIR_NAME = "assets"


def sanitize_name(name):
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", (name or "").strip())
    cleaned = cleaned.strip("._") or "unknown"
    return cleaned[:64]


def default_runbook_dir():
    base = os.environ.get("APPDATA") or os.path.expanduser("~")
    return os.path.join(base, "VisionTrainer", RUNBOOK_DIR_NAME)


def resolve_path(process_name, base_dir=None):
    base = base_dir or default_runbook_dir()
    return os.path.join(base, sanitize_name(process_name) + ".md")


def _load_text(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except (OSError, ValueError, UnicodeDecodeError):
        return ""


def load(path):
    return _load_text(path)


def _recipe_row(entry):
    recipe = entry.get("scan_recipe", {})
    return (f"| {entry.get('label','')} | {recipe.get('type','')} | "
            f"{recipe.get('protection','')} | {recipe.get('scan_option','')} | "
            f"{recipe.get('narrow_rounds',0)} | "
            f"{entry.get('observed_value','')} → {entry.get('target_value','')} |")


def _template(process, now):
    return (
        f"# RUNBOOK — {process}\n\n"
        f"Created: {now}\n\n"
        "Raw memory addresses below are informational only (ASLR changes them "
        "every launch). The scan **recipe** is the reusable truth — re-scan "
        "with it rather than reusing an address.\n\n"
        "## Known-good recipes\n\n"
        "| stat | type | protection | scan_option | narrow_rounds | observed → target |\n"
        "|------|------|------------|-------------|-----------------|------------------|\n"
        "\n## History\n"
    )


def format_entry(entry, now=None):
    now = now or datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    recipe = entry.get("scan_recipe", {})
    multiplier = entry.get("multiplier")
    lines = [
        f"## {now} — {entry.get('label','')}"
        + (f" ×{multiplier}" if multiplier else ""),
        "",
        f"- process: `{entry.get('process','')}` ({entry.get('window_title','')})",
        f"- observed → target: {entry.get('observed_value','')} → "
        f"{entry.get('target_value','')} ({entry.get('value_type','')})",
        "- fallback used: "
        f"{bool(entry.get('fallback_used', False))}",
        f"- recipe: type={recipe.get('type','')} "
        f"protection={recipe.get('protection','')} "
        f"scan_option={recipe.get('scan_option','')} "
        f"narrow_rounds={recipe.get('narrow_rounds',0)} "
        f"hits={recipe.get('hits',[])}",
        f"- address: `{entry.get('address','')}` "
        f"(module+offset: `{entry.get('module_offset','')}`) — informational, see ASLR note",
        f"- models: vision={entry.get('vision_model','')} "
        f"adjust={entry.get('adjust_model','')} endpoint={entry.get('endpoint','')}",
        f"- verified: {entry.get('verified', False)}",
    ]
    if entry.get("notes"):
        lines.append(f"- notes: {entry['notes']}")
    lines.append("")
    return "\n".join(lines)


def save_entry(path, entry):
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    existing = _load_text(path)
    if "Known-good recipes" not in existing:
        existing = _template(entry.get("process", "game"), now)
    label = str(entry.get("label", ""))
    lines = existing.splitlines()
    lines = [ln for ln in lines
             if not ln.startswith(f"| {label} |")]
    marker = "## History"
    row = _recipe_row(entry)
    if marker in lines:
        idx = lines.index(marker)
        lines.insert(idx, row)
    else:
        lines.append(row)
    updated = "\n".join(lines).rstrip() + "\n\n" + format_entry(entry, now)
    if not updated.endswith("\n"):
        updated += "\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(updated)
    return path


def suggest_recipe(path, label):
    text = _load_text(path)
    if not text or label not in text:
        return None
    for line in text.splitlines():
        if line.startswith(f"| {label} |"):
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) >= 5:
                return (f"Last time `{label}` worked as `{parts[1]}` "
                        f"{parts[3]} + {parts[4]} narrowings "
                        f"(protection {parts[2]})")
            return f"Last time `{label}` worked: {line}"
    histories = [ln for ln in text.splitlines()
                 if label in ln and ln.startswith("## ")]
    return histories[-1] if histories else None
