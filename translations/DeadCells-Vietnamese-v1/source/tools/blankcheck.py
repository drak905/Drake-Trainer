"""List Vietnamese letters that are missing OR present-but-blank in BFNT fonts.
usage: blankcheck.py <font.fnt>..."""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bfnt
from vichars import VI


def blank_set(fn):
    f = bfnt.Font.parse(open(fn, "rb").read())
    img = Image.open(os.path.join(os.path.dirname(fn), f.tile))
    a = np.asarray(img.getchannel(img.getbands()[-1]))
    out = []
    for c in VI:
        g = f.glyphs.get(ord(c))
        if g is None or g.w == 0 or g.h == 0 or a[g.y:g.y + g.h, g.x:g.x + g.w].max() < 64:
            out.append(c)
    return f, out


if __name__ == "__main__":
    for fn in sys.argv[1:]:
        f, b = blank_set(fn)
        print(f"{os.path.basename(fn)} ({f.name}): {len(b)} {''.join(b)}")
