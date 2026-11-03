#!/usr/bin/env python3
"""vn_coverage.py font.ttf - does the font have every Vietnamese code point? Also prints the default weight instance."""
import sys, io
from fontTools.ttLib import TTFont
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
VN = ("aáàảãạăắằẳẵặâấầẩẫậbcdđeéèẻẽẹêếềểễệfghiíìỉĩịjklmnoóòỏõọôốồổỗộơớờởỡợpqrstuúùủũụưứừửữựvwxyýỳỷỹỵz"
      "AÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬBCDĐEÉÈẺẼẸÊẾỀỂỄỆFGHIÍÌỈĨỊJKLMNOÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢPQRSTUÚÙỦŨỤƯỨỪỬỮỰVWXYÝỲỶỸỴZ")
for p in sys.argv[1:]:
    f = TTFont(p)
    cmap = f.getBestCmap()
    miss = [c for c in sorted(set(VN)) if ord(c) not in cmap]
    # combining marks (for NFD fallback)
    comb = [c for c in range(0x300, 0x30a) if c not in cmap]
    name = f["name"].getDebugName(4)
    wght = ""
    if "fvar" in f:
        for a in f["fvar"].axes: wght += " %s[%s..%s default %s]" % (a.axisTag, a.minValue, a.maxValue, a.defaultValue)
    print("%-34s %-28s vietnamese chars %d/%d missing=%s  combining-missing=%d%s" % (p.split("\\")[-1], name, len(set(VN)) - len(miss), len(set(VN)), "".join(miss) or "none", len(comb), wght))
