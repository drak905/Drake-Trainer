"""Search the Ghost Song string literal dump.  usage: strlit.py REGEX [maxlen]"""
import json, re, sys
d = json.load(open(r"E:\002.Github\043.ReverseEngine\artifacts\gs\dump\stringliteral.json", encoding="utf-8"))
items = d if isinstance(d, list) else d.get("stringLiteral", d)
rx = re.compile(sys.argv[1], re.I)
mx = int(sys.argv[2]) if len(sys.argv) > 2 else 100
n = 0
for it in items:
    v = it["value"] if isinstance(it, dict) else it
    if rx.search(v) and len(v) <= mx:
        print(it if not isinstance(it, dict) else (it.get("address"), repr(v)))
        n += 1
        if n > 150:
            break
