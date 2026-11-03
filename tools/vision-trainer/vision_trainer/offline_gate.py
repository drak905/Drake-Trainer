"""Offline-only gate: refuse multiplayer / anti-cheat targets (best effort)."""

import re

REFUSE_MESSAGE = (
    "Offline games only — this target looks like multiplayer or anti-cheat "
    "({reason}). Detaching; change the target to continue."
)

KNOWN_LAUNCHERS = (
    "steam", "epicgameslauncher", "epicgames", "ubisoft", "uplay",
    "origin", "battle.net", "battlenet", "riotclient", "riot client",
    "gog galaxy", "goggalaxy",
)

MULTIPLAYER_HINTS = (
    "multiplayer", "online", "pvp", "coop", "co-op", "matchmaking",
    "lobby", "server browser", "battle royale", "mmo", "mmorpg",
)

ANTICHEAT_MODULES = (
    "easyanticheat", "eac", "battleye", "bedaisy", "vgc", "vanguard",
    "xigncode", "xigncode3", "nprotect", "gameguard", "punkbuster",
    "equ8", "EACLauncher", "BEService",
)

ANTICHEAT_WINDOW_HINTS = (
    "easy anti-cheat", "easyanticheat", "battleye", "vanguard",
    "anti-cheat", "anticheat",
)


def _norm(text):
    return re.sub(r"[^a-z0-9]+", "", str(text or "").lower())


def check_process_name(name):
    lowered = str(name or "").lower()
    normed = _norm(name)
    for launcher in KNOWN_LAUNCHERS:
        if _norm(launcher) in normed:
            return f"launcher process ({name})"
    for hint in MULTIPLAYER_HINTS:
        if _norm(hint) in normed:
            return f"multiplayer hint in process name ({name})"
    for mod in ANTICHEAT_MODULES:
        if _norm(mod) in normed:
            return f"anti-cheat module name ({name})"
    return ""


def check_modules(modules):
    for mod in modules or []:
        name = mod.get("name", "") if isinstance(mod, dict) else str(mod)
        normed = _norm(name)
        for ac in ANTICHEAT_MODULES:
            if _norm(ac) and _norm(ac) in normed:
                return f"anti-cheat module loaded ({name})"
    return ""


def check_window_title(title):
    normed = _norm(title)
    for hint in ANTICHEAT_WINDOW_HINTS:
        if _norm(hint) in normed:
            return f"anti-cheat window ({title})"
    return ""
