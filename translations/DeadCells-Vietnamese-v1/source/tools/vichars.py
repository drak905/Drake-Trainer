"""Vietnamese character set + coverage report for BFNT fonts.
usage: vichars.py <font.fnt>..."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import bfnt

BASE = "aăâeêioôơuưy"
TONES = ["", "\u0301", "\u0300", "\u0309", "\u0303", "\u0323"]
import unicodedata


def vi_chars():
    out = set("đĐ")
    for b in BASE:
        for t in TONES:
            for c in (b, b.upper()):
                out.add(unicodedata.normalize("NFC", c + t))
    out |= set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return sorted(out)


VI = vi_chars()

if __name__ == "__main__":
    for fn in sys.argv[1:]:
        f = bfnt.Font.parse(open(fn, "rb").read())
        miss = [c for c in VI if ord(c) not in f.glyphs]
        print(f"{os.path.basename(fn)}: missing {len(miss)}/{len(VI)} {''.join(miss)}")
