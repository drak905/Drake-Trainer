"""Cheat categories: hints, types, plausible ranges, default modes.

Trap shapes (decaying stats, rate multipliers, NPC-decided flags) are
MANUAL_ONLY: reported with a reason, never auto-drafted.
"""

CATEGORIES = {
    "health": {
        "name_hints": [r"health", r"\bhp\b", r"hit.?points", r"vitality"],
        "types": ["dword", "float"],
        "plausible": (1, 100000),
        "mode": "freeze",
        "look_for": "Take damage, toggle, confirm the bar stays full",
    },
    "stamina": {
        "name_hints": [r"stamina", r"\bst\b", r"endurance", r"energy"],
        "types": ["dword", "float"],
        "plausible": (1, 100000),
        "mode": "freeze",
        "look_for": "Sprint, toggle, confirm stamina never drains",
    },
    "mana": {
        "name_hints": [r"mana", r"\bmp\b", r"magic", r"focus"],
        "types": ["dword", "float"],
        "plausible": (1, 100000),
        "mode": "freeze",
        "look_for": "Cast a spell, toggle, confirm mana stays full",
    },
    "money": {
        "name_hints": [r"money", r"gold", r"cash", r"coins?", r"gil",
                       r"credits?", r"caps"],
        "types": ["dword", "qword"],
        "plausible": (0, 10**12),
        "mode": "one_shot",
        "look_for": "Open inventory/shop, confirm the amount changed",
    },
    "bank": {
        "name_hints": [r"bank", r"storage", r"stash"],
        "types": ["dword", "qword"],
        "plausible": (0, 10**12),
        "mode": "one_shot",
        "look_for": "Open bank/storage, confirm the amount changed",
    },
    "ammo": {
        "name_hints": [r"ammo", r"bullets?", r"arrows?", r"rounds?"],
        "types": ["dword", "word"],
        "plausible": (0, 99999),
        "mode": "freeze",
        "look_for": "Fire weapon, toggle, confirm ammo never drops",
    },
    "score": {
        "name_hints": [r"score", r"points?", r"xp", r"experience"],
        "types": ["dword", "qword"],
        "plausible": (0, 10**12),
        "mode": "one_shot",
        "look_for": "Earn points, confirm the new total shows",
    },
    "water": {
        "name_hints": [r"water", r"thirst", r"hydration"],
        "types": ["dword", "float"],
        "plausible": (1, 100000),
        "mode": "freeze",
        "look_for": "Wait in-game, toggle, confirm water never drains",
    },
    "godmode": {
        "name_hints": [r"god", r"invincib", r"no.?damage"],
        "types": ["dword", "byte"],
        "plausible": (0, 1),
        "mode": "freeze",
        "look_for": "Take a hit, toggle, confirm no damage registers",
    },
    "freezetime": {
        "name_hints": [r"time", r"timer", r"clock", r"countdown"],
        "types": ["dword", "float"],
        "plausible": (0, 10**7),
        "mode": "freeze",
        "look_for": "Let time tick, toggle, confirm it stops",
    },
}

MANUAL_ONLY = {
    "runspeed": "rate multiplier: freezing it breaks movement/animation "
                "systems; adjust by hand if you must.",
    "speed": "rate multiplier: zeroing or freezing breaks other systems.",
    "nosearch": "police decision is per-officer, not a player flag.",
    "hunger": "decaying stat loses a freeze race; prefer one-shot top-ups.",
    "cash": "item-held object: reach it from the holding inventory with an "
            "anchor derefOffset, not a plain field write.",
    "curfew": "state flag: verify the exact semantics in-game first.",
}
