#!/usr/bin/env python3
"""nfc_check.py [--fix] - verify (and optionally fix) that every Vietnamese string in the sources is Unicode NFC, UTF-8 without BOM.
Chinese keys and English keys are left alone; only the Vietnamese side is normalised."""
import io, os, sys, unicodedata
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
FIX = "--fix" in sys.argv
# (file, column index of the Vietnamese text)
FILES = [("vi_strings.tsv", 5), ("vi_zh_strings.tsv", 2), ("vi_zh_strings_work3.tsv", 2),
         ("extra_zh.tsv", 1), ("ui.tsv", 1), ("ui_stats.tsv", 1), ("extra.tsv", 1)]
total_bad = 0
for fn, col in FILES:
    p = os.path.join(HERE, fn)
    if not os.path.exists(p): continue
    raw = open(p, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    out, bad, nfd_marks = [], 0, 0
    for line in text.split("\n"):
        if not line or line.startswith("#") or "\t" not in line:
            out.append(line); continue
        cols = line.split("\t")
        if len(cols) > col:
            v = cols[col]
            n = unicodedata.normalize("NFC", v)
            if n != v:
                bad += 1
                nfd_marks += sum(1 for ch in v if 0x300 <= ord(ch) <= 0x36F)
                cols[col] = n
        out.append("\t".join(cols))
    print("%-28s lines=%-6d non-NFC=%-5d combining-marks=%-5d BOM=%s" % (fn, len(out), bad, nfd_marks, bom))
    total_bad += bad + (1 if bom else 0)
    if FIX and (bad or bom):
        with open(p, "w", encoding="utf-8", newline="\n") as f: f.write("\n".join(out))
        print("   -> rewritten as NFC / UTF-8 without BOM")
# the generated Lua
lp = os.path.join(HERE, "..", "payload", "mod", "AI_Vietnamese", "Scripts", "vi_data.lua")
s = open(lp, "rb").read().decode("utf-8")
print("%-28s non-NFC=%s BOM=%s" % ("vi_data.lua", unicodedata.normalize("NFC", s) != s, open(lp, "rb").read(3) == b"\xef\xbb\xbf"))
sys.exit(1 if (total_bad and not FIX) else 0)
