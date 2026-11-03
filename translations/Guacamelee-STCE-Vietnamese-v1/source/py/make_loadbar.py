"""Create the Vietnamese loading bar texture ("ĐANG TẢI...") from the French one.

usage: python make_loadbar.py <vanilla misc.dat> <out dds>
"""
import struct
import sys

import numpy as np
from PIL import Image, ImageFilter

import arc
import fontgen
import gfont

TEXT = 'ĐANG TẢI...'


# ---- DXT1 ------------------------------------------------------------------------------------
def c565(c):
    c = c.astype(np.int32)
    return ((c[..., 0] >> 3) << 11) | ((c[..., 1] >> 2) << 5) | (c[..., 2] >> 3)


def from565(v):
    r = ((v >> 11) & 31) * 255 // 31
    g = ((v >> 5) & 63) * 255 // 63
    b = (v & 31) * 255 // 31
    return np.stack([r, g, b], -1).astype(np.int32)


def dxt1_encode(rgb):
    h, w, _ = rgb.shape
    bx, by = w // 4 if w >= 4 else 1, h // 4 if h >= 4 else 1
    if w < 4 or h < 4:
        pad = np.zeros((max(4, h), max(4, w), 3), np.uint8)
        pad[:h, :w] = rgb
        for y in range(pad.shape[0]):
            for x in range(pad.shape[1]):
                if y >= h or x >= w:
                    pad[y, x] = rgb[min(y, h - 1), min(x, w - 1)]
        rgb = pad
        h, w = rgb.shape[:2]
        bx, by = w // 4, h // 4
    blocks = rgb.reshape(by, 4, bx, 4, 3).transpose(0, 2, 1, 3, 4).reshape(by * bx, 16, 3).astype(np.int32)
    out = bytearray()
    for blk in blocks:
        lo = blk.min(axis=0)
        hi = blk.max(axis=0)
        # inset the bounding box a little (range fit)
        d = (hi - lo) // 16
        lo2, hi2 = np.minimum(lo + d, 255), np.maximum(hi - d, 0)
        c0 = int(c565(hi2))
        c1 = int(c565(lo2))
        if c0 < c1:
            c0, c1 = c1, c0
        if c0 == c1:
            out += struct.pack('<HHI', c0, c1, 0)
            continue
        p0, p1 = from565(np.array(c0)), from565(np.array(c1))
        pal = np.stack([p0, p1, (2 * p0 + p1) // 3, (p0 + 2 * p1) // 3])
        dist = ((blk[:, None, :] - pal[None]) ** 2).sum(-1)
        idx = dist.argmin(axis=1)
        bits = 0
        for i, v in enumerate(idx):
            bits |= int(v) << (2 * i)
        out += struct.pack('<HHI', c0, c1, bits)
    return bytes(out)


def build_dds(header, img):
    mips = struct.unpack_from('<I', header, 28)[0]
    out = bytearray(header)
    im = img.convert('RGB')
    for m in range(max(1, mips)):
        w, h = max(1, im.width >> m), max(1, im.height >> m)
        lvl = im if m == 0 else im.resize((w, h), Image.BOX)
        out += dxt1_encode(np.asarray(lvl).copy())
    return bytes(out)


# ---- picture ---------------------------------------------------------------------------------
def render_text(base):
    new, _ = fontgen.extend_font(base)
    kit = fontgen.FontKit(new)
    layers = []
    x = 0
    for ch in TEXT:
        gl = kit.gl[ord(ch)]
        layers.append(fontgen.Gl(gl.arr, gl.x + int(round(x)), gl.y, gl.adv))
        x += gl.adv
    comp = fontgen.compose(layers).trimmed(1)
    # place on canvas in absolute coords: comp.x, comp.y are line coordinates
    return comp


def main():
    src, dst = sys.argv[1:3]
    a = arc.Arc(src)
    data = a.data(a.fullnames.index('.\\meshes\\textures\\Load_bar_french.dds'))
    fido60 = a.data(a.fullnames.index('Fonts\\Fido.ttf.60.latin.fnt'))
    header = data[:128]
    h, w = struct.unpack_from('<II', header, 12)
    # decode DXT1 of the French texture through Pillow
    import io
    img = Image.open(io.BytesIO(data)).convert('RGB')
    arr = np.asarray(img).astype(np.float32)
    # locate the yellow text
    yel = (arr[..., 0] > 200) & (arr[..., 1] > 150) & (arr[..., 2] < 110)
    yel[:, :215] = False
    yel[:, 830:] = False
    ys, xs = np.nonzero(yel)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    print('french text bbox', x0, y0, x1, y1)
    # erase it: vertical interpolation between rows above and below (with margin for the glow)
    m = 16
    ya, yb = y0 - m, y1 + m
    xa, xb = x0 - m, x1 + m
    top = arr[ya - 2:ya, xa:xb].mean(axis=0)
    bot = arr[yb:yb + 2, xa:xb].mean(axis=0)
    t = np.linspace(0, 1, yb - ya)[:, None, None]
    fill = top[None] * (1 - t) + bot[None] * t
    # a little texture so the band does not look flat
    rng = np.random.RandomState(7)
    noise = rng.normal(0, 2.0, fill.shape[:2])[..., None]
    arr[ya:yb, xa:xb] = np.clip(fill + noise, 0, 255)
    bg = Image.fromarray(arr.astype(np.uint8))
    # text mask from Fido 60 glyphs
    comp = render_text(fido60)
    scale = (y1 - y0 + 1) / 62.0 * 0.98          # cap height of "A" at size 60 is ~62
    mask = Image.fromarray(comp.arr).resize((int(comp.w * scale), int(comp.h * scale)), Image.LANCZOS)
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    mx, my = int(cx - mask.width / 2.0), int(cy - mask.height / 2.0)
    full = Image.new('L', (w, h), 0)
    full.paste(mask, (mx, my))
    # layers: glow, outline, fill gradient
    glow = full.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(9))
    outline = full.filter(ImageFilter.MaxFilter(7))
    canvas = bg.convert('RGB')
    a = np.asarray(canvas).astype(np.float32)
    ga = np.asarray(glow).astype(np.float32)[..., None] / 255.0 * 0.55
    a = a * (1 - ga) + np.array([255, 150, 20], np.float32) * ga
    oa = np.asarray(outline).astype(np.float32)[..., None] / 255.0
    a = a * (1 - oa) + np.array([92, 52, 8], np.float32) * oa
    fa = np.asarray(full).astype(np.float32)[..., None] / 255.0
    yy = np.linspace(0, 1, h)[:, None, None]
    ty = (my - y0) / float(max(1, y1 - y0))
    tt = np.clip((np.arange(h)[:, None, None] - my) / float(max(1, mask.height)), 0, 1)
    grad = np.array([255, 224, 64], np.float32) * (1 - tt) + np.array([255, 170, 28], np.float32) * tt
    a = a * (1 - fa) + grad * fa
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    out.save(dst + '.png')
    open(dst, 'wb').write(build_dds(header, out))
    print('wrote', dst)


if __name__ == '__main__':
    main()


