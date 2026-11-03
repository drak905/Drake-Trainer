"""Complete the Vietnamese letters of Dead Cells' Latin bitmap fonts (BFNT + PNG atlas).

Some of the game's exported Latin fonts list every Vietnamese letter, but in several of them
(Berylium "medieval" titles, Fette UNZ Fraktur "avril", ADYS) many of those glyphs are empty
images, and every Latin font lacks Ậ ậ Ợ ợ. For each Vietnamese letter that is missing or blank
this tool builds a glyph from pieces of the same font, so the result keeps the font's own style,
outline and shadow:

  * Ậ ậ Ợ ợ: if both "Â" and "Ạ" style glyphs exist, they are merged (per-channel maximum).
  * otherwise: base letter (or the existing precomposed letter with its circumflex / breve /
    horn) + diacritics. Acute, grave, tilde, circumflex and breve marks are cut out of existing
    accented letters (á - a, Â - A, ...). The dot below is the font's ".", the hook above is the
    top of "?", the horn is "’" (or "'"), the bar of Đ đ is "-".

The glyph is packed into free atlas space (the texture height doubles if the atlas is full) and
inherits the kerning of its base letter.

  python fontcompose.py <in_dir> <out_dir> <font.fnt> [...]   (font paths relative to in_dir)
"""
import os
import sys
import unicodedata

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bfnt  # noqa: E402
from vichars import VI  # noqa: E402

PAD = 2
CIRC, BREVE, HORN = "\u0302", "\u0306", "\u031b"
ACUTE, GRAVE, HOOK, TILDE, DOT = "\u0301", "\u0300", "\u0309", "\u0303", "\u0323"
TOP_TONES = (ACUTE, GRAVE, HOOK, TILDE)
MARK_SOURCES = {
    ACUTE: ("áéóúí", "ÁÉÓÚ"),
    GRAVE: ("àèòùì", "ÀÈÒÙ"),
    TILDE: ("ãõñ", "ÃÕÑ"),
    CIRC: ("âêô", "ÂÊÔ"),
    BREVE: ("ăğŭčšž", "ĂĞŬČŠŽ"),
}


class G:
    """Glyph bitmap in glyph space: arr[h, w, C], top-left at (x, y) relative to the pen."""

    def __init__(self, arr, x, y):
        self.arr, self.x, self.y = arr, x, y

    @property
    def w(self):
        return self.arr.shape[1]

    @property
    def h(self):
        return self.arr.shape[0]

    def ink(self):
        """Bounding box (x0, y0, x1, y1) of the bright, opaque pixels (the letter, not its shadow)."""
        a = self.arr[..., -1].astype(int)
        lum = self.arr[..., 0].astype(int)
        m = (a > 100) & (lum > 100)
        if not m.any():
            m = a > 100
        if not m.any():
            return None
        ys, xs = np.nonzero(m)
        return self.x + xs.min(), self.y + ys.min(), self.x + xs.max() + 1, self.y + ys.max() + 1

    def moved(self, dx, dy):
        return G(self.arr, self.x + dx, self.y + dy)

    def rows_above(self, ylimit):
        keep = ylimit - self.y
        if keep <= 0:
            return None
        g = G(self.arr[:keep], self.x, self.y)
        return g.trimmed()

    def rows_below(self, ystart):
        cut = max(0, ystart - self.y)
        if cut >= self.h:
            return None
        return G(self.arr[cut:], self.x, self.y + cut).trimmed()

    def trimmed(self):
        a = self.arr[..., -1]
        if not a.any():
            return None
        ys, xs = np.nonzero(a)
        return G(self.arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1], self.x + xs.min(), self.y + ys.min())

    def scaled(self, f):
        if abs(f - 1) < 0.02:
            return self
        h, w = self.arr.shape[:2]
        nw, nh = max(1, round(w * f)), max(1, round(h * f))
        chans = [np.asarray(Image.fromarray(self.arr[..., c]).resize((nw, nh), Image.LANCZOS))
                 for c in range(self.arr.shape[2])]
        return G(np.stack(chans, -1), self.x, self.y)


def union(parts):
    parts = [p for p in parts if p is not None]
    x0, y0 = min(p.x for p in parts), min(p.y for p in parts)
    x1, y1 = max(p.x + p.w for p in parts), max(p.y + p.h for p in parts)
    out = np.zeros((y1 - y0, x1 - x0, parts[0].arr.shape[2]), np.uint8)
    for p in parts:
        sl = out[p.y - y0:p.y - y0 + p.h, p.x - x0:p.x - x0 + p.w]
        np.maximum(sl, p.arr, out=sl)
    return G(out, x0, y0)


class FontComposer:
    def __init__(self, f, img):
        self.f, self.img = f, img
        self.arr = np.asarray(img)
        if self.arr.ndim == 2:
            self.arr = self.arr[..., None]
        self.cache = {}

    def glyph(self, ch):
        g = self.f.glyphs.get(ord(ch))
        if g is None or g.w == 0 or g.h == 0:
            return None
        a = self.arr[g.y:g.y + g.h, g.x:g.x + g.w]
        if a[..., -1].max() < 64:
            return None
        return G(a.copy(), g.dx, g.dy)

    def adv(self, ch):
        g = self.f.glyphs.get(ord(ch))
        return g.adv if g else 0

    # ---- marks -------------------------------------------------------------------------
    def mark(self, kind, upper):
        key = (kind, upper)
        if key in self.cache:
            return self.cache[key]
        res = None
        if kind in MARK_SOURCES:
            lo, up = MARK_SOURCES[kind]
            for src in (up + lo) if upper else (lo + up):
                a, b = self.glyph(src), self.glyph(unicodedata.normalize("NFD", src)[0])
                if a is None or b is None:
                    continue
                bi = b.ink()
                m = a.rows_above(bi[1])
                if m is None or m.ink() is None:
                    continue
                mi = m.ink()
                res = (m, bi[1] - mi[3], (mi[0] + mi[2]) / 2 - (bi[0] + bi[2]) / 2)
                break
        elif kind == HOOK:
            q = self.glyph("?")
            ac = self.mark(ACUTE, upper)
            if q is not None and q.ink():
                qi = q.ink()
                top = q.rows_above(qi[1] + int((qi[3] - qi[1]) * 0.62))
                if top is not None and ac:
                    target_h = max((ac[0].ink()[3] - ac[0].ink()[1]) * 1.3, self.f.size * 0.26)
                    ti = top.ink()
                    top = top.scaled(target_h / max(1, ti[3] - ti[1]))
                    res = (top, ac[1], 0.0)
        self.cache[key] = res
        return res

    def place_above(self, core, kind, upper, center_x, xshift=0.0):
        m = self.mark(kind, upper)
        if m is None:
            raise KeyError(f"no {unicodedata.name(kind)} mark in {self.f.name}")
        mg, gap, cxoff = m
        ci = core.ink()
        mi = mg.ink()
        gap = max(1, gap)
        mw = mi[2] - mi[0]
        tx = round(center_x + cxoff + xshift * mw - (mi[0] + mi[2]) / 2)
        ty = round(ci[1] - gap - mi[3])
        return union([core, mg.moved(tx, ty)])

    def add_dot_below(self, core, center_x):
        d = self.glyph(".")
        if d is None:
            raise KeyError("no '.'")
        d = d.scaled(0.85).trimmed()
        di, ci = d.ink(), core.ink()
        gap = max(1, round(self.f.size * 0.07))
        bottom = max(ci[3], self.f.base_line) if self.f.base_line else ci[3]
        tx = round(center_x - (di[0] + di[2]) / 2)
        ty = round(bottom + gap - di[1])
        return union([core, d.moved(tx, ty)])

    def add_horn(self, core, upper):
        src = next((s for s in (",", "\u2019", "'") if self.glyph(s) is not None), None)
        if src is None:
            raise KeyError("no horn source")
        h = self.glyph(src).trimmed()
        if src == ",":  # a comma turned by 180 degrees: blob at the bottom left, tail up-right
            h = G(h.arr[::-1, ::-1].copy(), h.x, h.y)
        ci = core.ink()
        hi = h.ink()
        target = (ci[3] - ci[1]) * (0.34 if upper else 0.48)
        h = h.scaled(target / max(1, hi[3] - hi[1])).trimmed()
        hi = h.ink()
        thick = max(1, round((ci[2] - ci[0]) * 0.10))
        tx = round(ci[2] - thick - hi[0])
        ty = round(ci[1] + (ci[3] - ci[1]) * 0.20 - hi[3])
        return union([core, h.moved(tx, ty)])

    def add_bar(self, core, upper):
        d = self.glyph("-")
        if d is None:
            raise KeyError("no '-'")
        d = d.trimmed()
        di, ci = d.ink(), core.ink()
        w = (ci[2] - ci[0]) * (0.55 if upper else 0.6)
        d = G(np.asarray(Image.fromarray(d.arr[..., 0]).resize((max(2, round(w)), d.h)))[..., None], d.x, d.y) \
            if d.arr.shape[2] == 1 else G(np.stack([np.asarray(Image.fromarray(d.arr[..., c]).resize(
                (max(2, round(w)), d.h))) for c in range(d.arr.shape[2])], -1), d.x, d.y)
        di = d.ink()
        if upper:
            tx, cy = ci[0] - round(w * 0.18), ci[1] + (ci[3] - ci[1]) * 0.5
        else:
            tx, cy = ci[2] - round(w * 0.8), ci[1] + (ci[3] - ci[1]) * 0.2
        ty = round(cy - (di[1] + di[3]) / 2)
        return union([core, d.moved(round(tx - di[0]), ty)])

    # ---- composition -------------------------------------------------------------------
    def compose(self, ch):
        upper = ch.isupper()
        if ch in "Đđ":
            base = "D" if upper else "d"
            core = self.glyph(base)
            return self.add_bar(core, upper), self.adv(base), base
        nfd = unicodedata.normalize("NFD", ch)
        base, marks = nfd[0], nfd[1:]
        mods = "".join(m for m in marks if m in (CIRC, BREVE, HORN))
        tones = [m for m in marks if m not in (CIRC, BREVE, HORN)]
        tone = tones[0] if tones else None
        base_g = self.glyph(base)
        if base_g is None:
            raise KeyError(f"no base {base}")
        bi = base_g.ink()
        center = (bi[0] + bi[2]) / 2
        adv = self.adv(base)
        # special case: Ậ ậ Ợ ợ from two existing glyphs
        if tone == DOT and mods:
            a = self.glyph(unicodedata.normalize("NFC", base + mods))
            b = self.glyph(unicodedata.normalize("NFC", base + DOT))
            if a is not None and b is not None:
                return union([a, b]), max(adv, self.adv(unicodedata.normalize("NFC", base + mods))), base
        core = None
        if mods:
            pre = unicodedata.normalize("NFC", base + mods)
            if pre != ch:
                core = self.glyph(pre)
                if core is not None:
                    adv = max(adv, self.adv(pre))
        elif tone in TOP_TONES:
            pre = unicodedata.normalize("NFC", base + tone)
            if pre != ch and len(pre) == 1:
                core = self.glyph(pre)
                if core is not None:
                    return core, max(adv, self.adv(pre)), base
        if core is None:
            core = base_g
            if base == "i" and (tone in TOP_TONES):
                dl = self.glyph("\u0131")
                if dl is not None:
                    core = dl
            for m in mods:
                if m == HORN:
                    core = self.add_horn(core, upper)
                else:
                    core = self.place_above(core, m, upper, center)
        if tone in TOP_TONES:
            shift = 0.0
            if mods and HORN not in mods:
                shift = {ACUTE: 0.45, HOOK: 0.45, GRAVE: -0.45, TILDE: 0.0}[tone]
            core = self.place_above(core, tone, upper, center, shift)
        elif tone == DOT:
            core = self.add_dot_below(core, center)
        ci = core.ink()
        adv = max(adv, ci[2] + 1 - 0) if HORN in mods else adv
        return core, adv, base


def free_spot(occ, w, h):
    H, W = occ.shape
    for y in range(0, H - h + 1, 2):
        colfree = ~occ[y:y + h].any(axis=0)
        run = 0
        for x in range(W):
            run = run + 1 if colfree[x] else 0
            if run >= w:
                return x - w + 1, y
    return None


def blank_or_missing(fc, ch):
    return fc.glyph(ch) is None


def process(in_dir, out_dir, rel):
    f = bfnt.Font.parse(open(os.path.join(in_dir, rel), "rb").read())
    png_rel = os.path.join(os.path.dirname(rel), f.tile)
    img = Image.open(os.path.join(in_dir, png_rel))
    img.load()
    mode = img.mode
    fc = FontComposer(f, img)
    targets = [ch for ch in VI if ord(ch) > 127 and blank_or_missing(fc, ch)]
    built = []
    for ch in targets:
        g, adv, base = fc.compose(ch)
        built.append((ch, g, adv, base))
    arr = fc.arr.copy()
    H, W = arr.shape[:2]
    occ = arr[..., -1] > 0
    for g in f.glyphs.values():
        if g.w and g.h:
            occ[max(0, g.y - PAD):g.y + g.h + PAD, max(0, g.x - PAD):g.x + g.w + PAD] = True
    for ch, g, adv, base in built:
        spot = free_spot(occ, g.w + 2 * PAD, g.h + 2 * PAD)
        while spot is None:
            arr = np.concatenate([arr, np.zeros_like(arr)], 0)
            occ = np.concatenate([occ, np.zeros_like(occ)], 0)
            H *= 2
            spot = free_spot(occ, g.w + 2 * PAD, g.h + 2 * PAD)
        x, y = spot[0] + PAD, spot[1] + PAD
        arr[y:y + g.h, x:x + g.w] = g.arr
        occ[y - PAD:y + g.h + PAD, x - PAD:x + g.w + PAD] = True
        cp = ord(ch)
        bg = f.glyphs.get(ord(base))
        kern = list(bg.kern) if bg else []
        f.glyphs[cp] = bfnt.Glyph(cp, x, y, g.w, g.h, g.x, g.y, adv, kern)
        if bg:
            for og in list(f.glyphs.values()):
                if og.id != cp and any(k == cp for k, _ in og.kern) is False:
                    for k, amt in list(og.kern):
                        if k == ord(base):
                            og.kern.append((cp, amt))
    out_img = Image.fromarray(arr[..., 0] if arr.shape[2] == 1 else arr)
    assert out_img.mode == mode, (out_img.mode, mode)
    os.makedirs(os.path.dirname(os.path.join(out_dir, rel)), exist_ok=True)
    open(os.path.join(out_dir, rel), "wb").write(f.serialize())
    out_img.save(os.path.join(out_dir, png_rel), optimize=True)
    return rel, len(built), img.size, out_img.size, "".join(t for t, *_ in built)


if __name__ == "__main__":
    in_dir, out_dir = sys.argv[1], sys.argv[2]
    for rel in sys.argv[3:]:
        r = process(in_dir, out_dir, rel)
        print(r[0], "built", r[1], r[2], "->", r[3], r[4])
