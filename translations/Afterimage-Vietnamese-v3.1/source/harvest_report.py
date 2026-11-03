#!/usr/bin/env python3
"""harvest_report.py - classify what the mod logged as 'could not translate' during a play session."""
import io, sys, re, collections
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
p = sys.argv[1]
rows = [l.rstrip("\n").split("\t") for l in open(p, encoding="utf-8", errors="replace") if l.strip()]
kinds = collections.Counter(r[0] for r in rows)
print("lines:", len(rows), dict(kinds))
DEV = re.compile(r"^(Add \d+ Point|Add \d+ Point|Display Name|Skill Name|skill type|hidden|NULL|Text|Text Block|Waiting\.\.\.|SetSkin:|SetMaterial:|SetOffset:|SetTalentPoint\(0\)|order:|Boss|LEMON|PgUp|PgDn|Space|Esc|Enter|Z|X|C|Q|E|A|D|S|W|Num \d|Left Ctrl|Left Shift|Controller\w+|Gamepad[\w \-]+)$")
real_en, real_zh, noise = [], [], []
for r in rows:
    kind = r[0]
    if kind == "W":
        s = r[1]
        if DEV.match(s) or s.startswith("[") or "TRAINER" in s or re.match(r"^Lv\d+", s): noise.append(s)
        elif re.search(r"[\u3400-\u9fff]", s): real_zh.append(s)
        else: real_en.append(s)
    else:  # data-table row (older logger wrote the chinese literal as field 0)
        real_zh.append(" | ".join(x[:60] for x in r[:4]))
print("noise (dev placeholders, keys, trainer):", len(noise))
print("REAL untranslated english widget text :", len(real_en))
for s in real_en[:40]: print("   EN  ", s[:100])
print("REAL untranslated chinese / data-table:", len(real_zh))
for s in real_zh[:40]: print("   ZH  ", s[:120])
