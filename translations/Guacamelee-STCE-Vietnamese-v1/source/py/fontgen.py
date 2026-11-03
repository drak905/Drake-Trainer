"""Add Vietnamese precomposed glyphs to the pre-baked GFONT (.fn) bitmap fonts of Guacamelee! STCE.

The fonts only carry Latin-1.  For every missing Vietnamese letter we compose a bitmap from the font's own glyphs:
base letter + tone/shape marks that are lifted from the existing accented Latin-1 glyphs (acute, grave, tilde,
circumflex), plus a few synthesized marks (hook above, dot below, breve, horn, stroke of đ).
"""
import struct
import unicodedata

import numpy as np
from PIL import Image, ImageDraw

import gfont

THR = 10


def f2u(x):
    return struct.unpack('<I', struct.pack('<f', x))[0]


def u2f(u):
    return struct.unpack('<f', struct.pack('<I', u))[0]


class Gl:
    """Glyph raster: arr[h][w] alpha, x/y = line coordinates of arr[0][0] (y down), adv = advance."""

    def __init__(self, arr, x, y, adv):
        self.arr = arr
        self.x = int(x)
        self.y = int(y)
        self.adv = adv

    @property
    def w(self):
        return self.arr.shape[1]

    @property
    def h(self):
        return self.arr.shape[0]

    def ink(self, thr=THR):
        ys, xs = np.nonzero(self.arr > thr)
        if len(xs) == 0:
            return None
        return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1  # local

    def top(self):
        b = self.ink()
        return self.y + b[1]

    def bottom(self):
        b = self.ink()
        return self.y + b[3]

    def left(self):
        b = self.ink()
        return self.x + b[0]

    def right(self):
        b = self.ink()
        return self.x + b[2]

    def cx(self):
        return (self.left() + self.right()) / 2.0

    def trimmed(self, thr=1):
        b = self.ink(thr)
        if b is None:
            return Gl(np.zeros((1, 1), np.uint8), self.x, self.y, self.adv)
        return Gl(self.arr[b[1]:b[3], b[0]:b[2]].copy(), self.x + b[0], self.y + b[1], self.adv)

    def moved(self, dx, dy):
        return Gl(self.arr, self.x + dx, self.y + dy, self.adv)


def compose(layers, adv=None):
    layers = [l for l in layers if l is not None]
    x0 = min(l.x for l in layers)
    y0 = min(l.y for l in layers)
    x1 = max(l.x + l.w for l in layers)
    y1 = max(l.y + l.h for l in layers)
    out = np.zeros((y1 - y0, x1 - x0), np.uint8)
    for l in layers:
        sub = out[l.y - y0:l.y - y0 + l.h, l.x - x0:l.x - x0 + l.w]
        np.maximum(sub, l.arr, out=sub)
    return Gl(out, x0, y0, layers[0].adv if adv is None else adv)


def diff(acc, base):
    x0 = min(acc.x, base.x)
    y0 = min(acc.y, base.y)
    x1 = max(acc.x + acc.w, base.x + base.w)
    y1 = max(acc.y + acc.h, base.y + base.h)
    A = np.zeros((y1 - y0, x1 - x0), np.int16)
    B = np.zeros_like(A)
    A[acc.y - y0:acc.y - y0 + acc.h, acc.x - x0:acc.x - x0 + acc.w] = acc.arr
    B[base.y - y0:base.y - y0 + base.h, base.x - x0:base.x - x0 + base.w] = base.arr
    d = np.clip(A - B, 0, 255).astype(np.uint8)
    d[d < 40] = 0
    return Gl(d, x0, y0, acc.adv).trimmed(1)


def resize(gl, sx, sy, anchor='bc'):
    """Scale about an anchor point of the ink box ('bc' bottom-centre, 'tc', 'cc')."""
    t = gl.trimmed()
    nw = max(1, int(round(t.w * sx)))
    nh = max(1, int(round(t.h * sy)))
    im = Image.fromarray(t.arr).resize((nw, nh), Image.LANCZOS)
    arr = np.asarray(im).copy()
    cxo = t.x + t.w / 2.0
    if anchor == 'bc':
        ay_old, ay_new = t.y + t.h, None
        ny = int(round(ay_old - nh))
    elif anchor == 'tc':
        ny = t.y
    else:
        ny = int(round(t.y + t.h / 2.0 - nh / 2.0))
    nx = int(round(cxo - nw / 2.0))
    return Gl(arr, nx, ny, gl.adv)


def flipv(gl):
    return Gl(gl.arr[::-1].copy(), gl.x, gl.y, gl.adv)


def row_groups(gl, thr=THR):
    rows = (gl.arr > thr).any(axis=1)
    groups, start = [], None
    for i, v in enumerate(rows):
        if v and start is None:
            start = i
        if not v and start is not None:
            groups.append((start, i))
            start = None
    if start is not None:
        groups.append((start, len(rows)))
    return groups


def synth_marks(size, stem):
    """Fallback marks drawn from scratch when the font's accented glyphs cannot be diffed."""
    import math
    S = 4
    sw = max(2.0, stem * 0.45)
    mh = max(4, int(round(size * 0.20)))
    mw = max(6, int(round(size * 0.30)))
    pad = 3
    out = {}

    def canvas():
        im = Image.new('L', ((mw + 2 * pad) * S, (mh + 2 * pad) * S), 0)
        return im, ImageDraw.Draw(im)

    def finish(im):
        im = im.resize((mw + 2 * pad, mh + 2 * pad), Image.LANCZOS)
        return Gl(np.asarray(im).copy(), 0, 0, 0).trimmed(8)

    def P(x, y):
        return ((x + pad) * S, (y + pad) * S)

    im, d = canvas()
    d.line([P(mw * 0.15, mh), P(mw * 0.85, 0)], fill=255, width=int(sw * S))
    out['acute'] = finish(im)
    im, d = canvas()
    d.line([P(mw * 0.15, 0), P(mw * 0.85, mh)], fill=255, width=int(sw * S))
    out['grave'] = finish(im)
    im, d = canvas()
    d.line([P(0, mh), P(mw / 2.0, 0), P(mw, mh)], fill=255, width=int(sw * S), joint='curve')
    out['circ'] = finish(im)
    im, d = canvas()
    pts = [P(x, mh / 2.0 - (mh / 2.4) * math.sin(2 * math.pi * x / mw)) for x in np.linspace(0, mw, 24)]
    d.line(pts, fill=255, width=int(sw * S * 0.9), joint='curve')
    out['tilde'] = finish(im)
    # hook above: small question-mark curl
    im, d = canvas()
    r = mw * 0.30
    cx, cy = mw * 0.5, mh * 0.32
    bb = [P(cx - r, cy - r)[0], P(cx - r, cy - r)[1], P(cx + r, cy + r)[0], P(cx + r, cy + r)[1]]
    d.arc(bb, 200, 450, fill=255, width=int(sw * S * 0.9))
    d.line([P(cx, cy + r * 0.9), P(cx, mh)], fill=255, width=int(sw * S * 0.9))
    out['hook'] = finish(im)
    return out


class FontKit:
    def __init__(self, data):
        self.g = gfont.GFont(data)
        g = self.g
        self.tex = np.frombuffer(bytes(g.tex), dtype=np.uint8).reshape(g.th, g.tw)
        self.gl = {}
        self.rec = {}
        for r in g.glyphs:
            u0, v0, u1, v1 = r['f4']
            c0, r0, c1, r1 = round(u0 * g.tw), round(v0 * g.th), round(u1 * g.tw), round(v1 * g.th)
            arr = self.tex[r0:r1, c0:c1].copy() if (c1 > c0 and r1 > r0) else np.zeros((1, 1), np.uint8)
            self.gl[r['code']] = Gl(arr, r['a'][0], r['a'][1], u2f(r['tail']))
            self.rec[r['code']] = r
        self.size = g.hdr4[3]
        self.stem = self._stem_width()
        self._marks()

    # ---- measurements --------------------------------------------------------------------
    def G(self, ch):
        return self.gl[ord(ch)]

    def _stem_width(self):
        ws = []
        for ch in 'lI':
            gl = self.G(ch)
            for row in gl.arr[gl.h // 3: 2 * gl.h // 3]:
                ws.append(int((row > 128).sum()))
        ws = [w for w in ws if w > 0]
        return int(np.median(ws)) if ws else max(2, self.size // 8)

    def _marks(self):
        self.m = {}
        for case, base in (('l', 'a'), ('u', 'A')):
            pairs = {'acute': 'áÁ', 'grave': 'àÀ', 'tilde': 'ãÃ', 'circ': 'âÂ'}
            for name, chars in pairs.items():
                acc = self.G(chars[0 if case == 'l' else 1])
                mk = diff(acc, self.G(base))
                self.m[(case, name)] = mk
            # reference base (for relative placement) = the plain letter
            self.m[(case, 'ref')] = self.G(base)
        bad = False
        for case in 'lu':
            for name in ('acute', 'grave', 'tilde', 'circ'):
                mk = self.m[(case, name)]
                if mk.h > 0.40 * self.size or mk.w > 0.60 * self.size or mk.h < 2:
                    bad = True
        self.synthetic = bad
        if bad:
            for case in 'lu':
                syn = synth_marks(self.size, self.stem)
                for name, gl in syn.items():
                    self.m[(case, name)] = gl
                self.m[(case, 'synhook')] = syn['hook']
        for case in 'lu':
            ref = self.m[(case, 'ref')]
            for name in ('acute', 'grave', 'tilde', 'circ'):
                mk = self.m[(case, name)]
                if bad:
                    self.m[(case, name, 'rel')] = (0.0, max(1, self.size // 12))
                else:
                    self.m[(case, name, 'rel')] = (mk.cx() - ref.cx(), ref.top() - mk.bottom())
            self.m[(case, 'breve')] = flipv(self.m[(case, 'circ')])
            self.m[(case, 'breve', 'rel')] = self.m[(case, 'circ', 'rel')]
            acute = self.m[(case, 'acute')]
            # hook above: curl of the question mark
            q = self.G('?').trimmed()
            grp = row_groups(q)
            top = q.arr[:grp[0][1] if len(grp) > 1 else int(q.h * 0.62)]
            hook = Gl(top, q.x, q.y, 0).trimmed()
            hook = resize(hook, max(1.0, acute.w * 1.35) / hook.w, max(1.0, min(acute.h * 1.6, self.size * 0.36)) / hook.h, 'bc')
            self.m[(case, 'hook')] = hook
            if self.synthetic:
                hook = self.m[(case, 'synhook')]
                self.m[(case, 'hook')] = hook
            elif self.size >= 18:
                a2 = hook.arr.copy()
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    sh = np.roll(hook.arr, (dy, dx), axis=(0, 1))
                    a2 = np.maximum(a2, sh)
                hook = Gl(a2, hook.x, hook.y, hook.adv)
                self.m[(case, 'hook')] = hook
            self.m[(case, 'hook', 'rel')] = (0.0, max(0, self.m[(case, 'acute', 'rel')][1] - max(1, self.size // 14)))

    # ---- building blocks ---------------------------------------------------------------
    def body(self, ch):
        """Plain letter glyph; for i/ı the dotless stem."""
        gl = self.G(ch)
        if ch == 'i':
            grp = row_groups(gl)
            if len(grp) >= 2:
                r0 = grp[-1][0]
                return Gl(gl.arr[r0:].copy(), gl.x, gl.y + r0, gl.adv)
        return gl

    def put_mark(self, base, case, name, scale=1.0, dx=0, extra_gap=0, top=None):
        mk = self.m[(case, name)]
        rel = self.m[(case, name, 'rel')]
        if scale != 1.0:
            mk = resize(mk, scale, scale, 'bc')
        btop = base.top() if top is None else top
        bcx = base.cx()
        # mark centre x = base centre + rel_x ; mark bottom = base top - gap
        nx = int(round(bcx + rel[0] * 1.0 + dx - (mk.x * 0 + (mk.w / 2.0))))
        gap = max(0, int(round(rel[1])))
        ny = int(round(btop - gap - extra_gap - mk.h))
        return Gl(mk.arr, nx, ny, base.adv)

    def horn(self, base):
        t = base.trimmed()
        T, R = t.top(), t.right()
        hbody = t.h
        stem = max(2.0, self.stem * 0.62)
        S = 4
        L = max(3.0, 0.22 * min(hbody, self.size))
        # work canvas
        pad = int(L) + 4
        W = (R - base.x) + pad + 2
        H = pad + hbody + 4
        im = Image.new('L', (W * S, H * S), 0)
        d = ImageDraw.Draw(im)
        sx = (R - base.x - stem * 0.55) * S
        sy = (pad + 0.5 * stem) * S
        ex = sx + L * 0.95 * S
        ey = sy - L * 0.80 * S
        d.line([(sx, sy), (ex, ey)], fill=255, width=int(stem * S))
        r = stem * S / 2
        d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=255)
        im = im.resize((W, H), Image.LANCZOS)
        arr = np.asarray(im).copy()
        hg = Gl(arr, base.x, T - pad, base.adv)
        out = compose([base, hg], adv=base.adv + max(1.0, 0.45 * L))
        return out

    def stroke_d(self, upper=False):
        """đ: 'd' with a crossbar through the ascender stem."""
        gl = self.G('d')
        t = gl
        xh_top = self.G('o').top()
        asc_top = t.top()
        # stem columns: ink columns in the ascender zone
        zone = t.arr[: max(1, xh_top - t.y - 1)]
        cols = np.nonzero((zone > 128).any(axis=0))[0]
        c0, c1 = cols.min(), cols.max() + 1
        bar_h = max(2, int(round(self.stem * 0.42)))
        yc = int(round(asc_top + (xh_top - asc_top) * 0.52 + 0.5))
        x0 = t.x + c0 - max(2, int(self.size * 0.12))
        x1 = t.x + c1 + max(1, int(self.size * 0.05))
        arr = np.full((bar_h, x1 - x0), 255, np.uint8)
        bar = Gl(arr, x0, yc - bar_h // 2, gl.adv)
        return compose([gl, bar])

    # ---- compose a target character -----------------------------------------------------
    def make(self, ch):
        if ch == 'Đ':
            return self.G('Ð')
        if ch == 'đ':
            return self.stroke_d()
        dec = unicodedata.normalize('NFD', ch)
        letter, marks = dec[0], set(dec[1:])
        upper = letter.isupper()
        case = 'u' if upper else 'l'
        base = self.body(letter) if (letter == 'i' and marks & {'\u0300', '\u0301', '\u0303', '\u0309'}) else self.G(letter)
        shape = None
        if '\u0302' in marks:
            shape = 'circ'
        elif '\u0306' in marks:
            shape = 'breve'
        elif '\u031b' in marks:
            shape = 'horn'
        tone = None
        for k, v in (('\u0300', 'grave'), ('\u0301', 'acute'), ('\u0309', 'hook'), ('\u0303', 'tilde'), ('\u0323', 'dot')):
            if k in marks:
                tone = v
        layers = [base]
        adv = base.adv
        top_for_tone = None
        stacked = False
        if shape == 'circ':
            pre = {'a': 'â', 'e': 'ê', 'o': 'ô', 'A': 'Â', 'E': 'Ê', 'O': 'Ô'}[letter]
            base = self.G(pre)
            layers = [base]
        elif shape == 'breve':
            mk = self.put_mark(base, case, 'breve')
            layers = [base, mk]
            base = compose(layers)
        elif shape == 'horn':
            base = self.horn(base)
            layers = [base]
            body_top = self.G(letter).top()
            top_for_tone = body_top
        if shape in ('circ', 'breve'):
            stacked = True
        if tone == 'dot':
            dot = self.G('.').trimmed()
            dot = resize(dot, 0.8, 0.8, 'tc')
            ref = self.G(letter)
            by = max(ref.bottom(), self.G('x' if not upper else 'H').bottom())
            bx = int(round(ref.cx() - dot.w / 2.0))
            gap = max(1, int(round(self.size * 0.07)))
            layers = [base, Gl(dot.arr, bx, by + gap, adv)]
        elif tone:
            if stacked:
                top = base.top()
                sc = 0.85
                dx = 0
                if tone == 'acute':
                    dx = int(round(base.w * 0.14))
                elif tone == 'grave':
                    dx = -int(round(base.w * 0.14))
                mk = self.put_mark(base, case, tone, scale=sc, dx=dx, extra_gap=0,
                                   top=top - max(0, int(round(self.m[(case, tone, 'rel')][1])) - 1))
                layers = [base, mk]
            else:
                mk = self.put_mark(base, case, tone, top=top_for_tone)
                layers = [base, mk]
        res = compose(layers, adv=getattr(base, 'adv', adv))
        return res


def _is_vi(c):
    d = unicodedata.normalize('NFD', chr(c))
    if len(d) < 2 or d[0] not in 'AEIOUYaeiouy' or not all(m in '\u0300\u0301\u0302\u0303\u0306\u0309\u031b\u0323' for m in d[1:]):
        return False
    b, ms = d[0].lower(), set(d[1:])
    if '\u0302' in ms and b not in 'aeo':
        return False
    if '\u0306' in ms and b != 'a':
        return False
    if '\u031b' in ms and b not in 'ou':
        return False
    return True


VI_CHARS = ''.join(chr(c) for c in range(0xC0, 0x1EFA) if _is_vi(c))
VI_CHARS += 'Đđ'


def extend_font(data, only=None):
    kit = FontKit(data)
    g = kit.g
    chars = [c for c in VI_CHARS if ord(c) not in kit.rec] if only is None else list(only)
    new = {}
    for c in chars:
        gl = kit.make(c).trimmed(1)
        new[ord(c)] = gl
    # pack new tiles below the existing atlas
    gut = 2
    x, y, rowh = gut, g.th + gut, 0
    placed = {}
    for code in sorted(new):
        gl = new[code]
        if x + gl.w + gut > g.tw:
            x, y = gut, y + rowh + gut
            rowh = 0
        placed[code] = (x, y)
        x += gl.w + gut
        rowh = max(rowh, gl.h)
    new_th = y + rowh + gut
    tex = np.zeros((new_th, g.tw), np.uint8)
    tex[:g.th] = kit.tex
    for code, (px, py) in placed.items():
        gl = new[code]
        tex[py:py + gl.h, px:px + gl.w] = gl.arr
    # rewrite glyph records (v coords w.r.t. new height)
    recs = []
    for r in g.glyphs:
        u0, v0, u1, v1 = r['f4']
        r0, r1 = round(v0 * g.th), round(v1 * g.th)
        c0, c1 = round(u0 * g.tw), round(u1 * g.tw)
        r2 = dict(r)
        r2['f4'] = [c0 / g.tw, r0 / new_th, c1 / g.tw, r1 / new_th]
        recs.append(r2)
    for code, gl in new.items():
        px, py = placed[code]
        recs.append(dict(code=code, f4=[px / g.tw, py / new_th, (px + gl.w) / g.tw, (py + gl.h) / new_th],
                         a=[float(gl.x), float(gl.y)], b=[float(gl.w), float(gl.h)], tail=f2u(float(gl.adv))))
    recs.sort(key=lambda r: r['code'])
    g.glyphs = recs
    g.th = new_th
    g.tex = bytearray(tex.tobytes())
    return g.build(), len(new)


