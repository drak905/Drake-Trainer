"""Render text with a BFNT font (for checking glyphs): render_sample.py <font.fnt> <out.png> <text> [scale]"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bfnt


def render(fnt, text, bg=(40, 40, 90, 255)):
    f = bfnt.Font.parse(open(fnt, "rb").read())
    img = Image.open(os.path.join(os.path.dirname(fnt), f.tile)).convert("RGBA")
    lines = text.split("\n")
    W = max(sum((f.glyphs.get(ord(ch)) or f.glyphs[f.default_char]).adv for ch in l) for l in lines) + 20
    H = f.line_height * len(lines) + 20
    out = Image.new("RGBA", (W, H), bg)
    for li, l in enumerate(lines):
        x, y = 10, 10 + li * f.line_height
        for ch in l:
            g = f.glyphs.get(ord(ch)) or f.glyphs[f.default_char]
            if g.w and g.h:
                part = img.crop((g.x, g.y, g.x + g.w, g.y + g.h))
                out.alpha_composite(part, (x + g.dx, y + g.dy))
            x += g.adv
    return out


if __name__ == "__main__":
    s = float(sys.argv[4]) if len(sys.argv) > 4 else 2
    im = render(sys.argv[1], sys.argv[3].replace("\\n", "\n"))
    im.resize((int(im.width * s), int(im.height * s)), Image.NEAREST).save(sys.argv[2])
