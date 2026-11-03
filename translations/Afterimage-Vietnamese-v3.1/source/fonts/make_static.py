#!/usr/bin/env python3
"""make_static.py - cut a static SemiBold (wght 600) instance out of Cormorant Garamond's variable font and verify Vietnamese coverage.
Output: CormorantGaramond-SemiBold.ttf  (SIL OFL 1.1; Reserved Font Name 'Cormorant' -> we rename the family inside the file)."""
import sys, io, os
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(HERE, "CormorantGaramond-VF.ttf")
dst = os.path.join(HERE, "CormorantGaramond-SemiBold.ttf")
f = TTFont(src)
inst = instancer.instantiateVariableFont(f, {"wght": 600}, inplace=False)
# keep the Vietnamese-relevant tables only matters little; just save
inst.save(dst)
# the instance keeps the "Light" name of the variable font's default master: rename it honestly (OFL has no Reserved Font Name)
g0 = TTFont(dst)
for rec in g0["name"].names:
    if rec.nameID in (1, 16): rec.string = "Cormorant Garamond SemiBold"
    elif rec.nameID in (2, 17): rec.string = "Regular"
    elif rec.nameID == 4: rec.string = "Cormorant Garamond SemiBold"
    elif rec.nameID == 6: rec.string = "CormorantGaramond-SemiBold"
    elif rec.nameID == 3: rec.string = "CormorantGaramond-SemiBold;static instance wght=600 for AI_Vietnamese"
g0.save(dst)
# Slate cannot switch OpenType features, so make lining figures the default digits (the font's default digits are old-style)
g1 = TTFont(dst)
names = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
have = set(g1.getGlyphOrder())
if all(n + ".lf" in have for n in names):
    for t in g1["cmap"].tables:
        if t.isUnicode():
            for ch, n in zip("0123456789", names):
                if ord(ch) in t.cmap: t.cmap[ord(ch)] = n + ".lf"
    print("digits remapped to lining figures")
g1.save(dst)
VN = ("aáàảãạăắằẳẵặâấầẩẫậbcdđeéèẻẽẹêếềểễệfghiíìỉĩịjklmnoóòỏõọôốồổỗộơớờởỡợpqrstuúùủũụưứừửữựvwxyýỳỷỹỵz"
      "AÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬBCDĐEÉÈẺẼẸÊẾỀỂỄỆFGHIÍÌỈĨỊJKLMNOÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢPQRSTUÚÙỦŨỤƯỨỪỬỮỰVWXYÝỲỶỸỴZ")
g = TTFont(dst)
cmap = g.getBestCmap()
miss = [c for c in sorted(set(VN)) if ord(c) not in cmap]
print("static instance:", g["name"].getDebugName(4), "| fvar present:", "fvar" in g, "| size", os.path.getsize(dst), "bytes")
print("vietnamese letters present: %d/%d  missing=%s" % (len(set(VN)) - len(miss), len(set(VN)), "".join(miss) or "none"))
digits = all(ord(c) in cmap for c in "0123456789+-%/:.,()")
print("digits and punctuation present:", digits)
