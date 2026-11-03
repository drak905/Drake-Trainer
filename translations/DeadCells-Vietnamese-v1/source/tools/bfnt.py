"""Heaps BFNT (hxd.fmt.bfnt) reader / writer.

  "BFNT" u8 0  u8 version(1)
  u16 len, face name   i16 size
  u16 len, tile path   i16 lineHeight   i16 baseLine   i32 defaultChar
  repeat: i32 id (0 = end)
          u16 x, u16 y, u16 w, u16 h, i16 dx, i16 dy, i16 advance
          repeat: i32 kerningChar (0 = end), i16 amount
"""
import struct, sys


class Glyph:
    __slots__ = ("id", "x", "y", "w", "h", "dx", "dy", "adv", "kern")

    def __init__(self, id, x, y, w, h, dx, dy, adv, kern=None):
        self.id, self.x, self.y, self.w, self.h = id, x, y, w, h
        self.dx, self.dy, self.adv = dx, dy, adv
        self.kern = kern if kern is not None else []

    def __repr__(self):
        return f"<{chr(self.id)!r} {self.x},{self.y} {self.w}x{self.h} d{self.dx},{self.dy} a{self.adv}>"


class Font:
    def __init__(self):
        self.name, self.size, self.tile = "", 0, ""
        self.line_height = self.base_line = 0
        self.default_char = 0
        self.glyphs = {}  # id -> Glyph (insertion order kept)

    @staticmethod
    def parse(b):
        if b[:4] != b"BFNT" or b[4] != 0:
            raise ValueError("not BFNT")
        if b[5] != 1:
            raise ValueError("BFNT version %d" % b[5])
        p = 6
        f = Font()

        def s():
            nonlocal p
            n = struct.unpack_from("<H", b, p)[0]
            v = b[p + 2:p + 2 + n].decode("utf-8")
            p += 2 + n
            return v

        f.name = s()
        f.size = struct.unpack_from("<h", b, p)[0]; p += 2
        f.tile = s()
        f.line_height, f.base_line, f.default_char = struct.unpack_from("<hhi", b, p); p += 8
        while True:
            gid = struct.unpack_from("<i", b, p)[0]; p += 4
            if gid == 0:
                break
            x, y, w, h, dx, dy, adv = struct.unpack_from("<HHHHhhh", b, p); p += 14
            g = Glyph(gid, x, y, w, h, dx, dy, adv)
            while True:
                k = struct.unpack_from("<i", b, p)[0]; p += 4
                if k == 0:
                    break
                g.kern.append((k, struct.unpack_from("<h", b, p)[0])); p += 2
            f.glyphs[gid] = g
        if p != len(b):
            raise ValueError(f"trailing {len(b) - p} bytes")
        return f

    def serialize(self):
        out = bytearray(b"BFNT\x00\x01")

        def s(v):
            e = v.encode("utf-8")
            out.extend(struct.pack("<H", len(e)) + e)

        s(self.name)
        out += struct.pack("<h", self.size)
        s(self.tile)
        out += struct.pack("<hhi", self.line_height, self.base_line, self.default_char)
        for g in self.glyphs.values():
            out += struct.pack("<iHHHHhhh", g.id, g.x, g.y, g.w, g.h, g.dx, g.dy, g.adv)
            for k, a in g.kern:
                out += struct.pack("<ih", k, a)
            out += struct.pack("<i", 0)
        out += struct.pack("<i", 0)
        return bytes(out)


if __name__ == "__main__":
    for fn in sys.argv[1:]:
        f = Font.parse(open(fn, "rb").read())
        ids = sorted(f.glyphs)
        print(f"{fn}: face={f.name!r} size={f.size} tile={f.tile} lh={f.line_height} base={f.base_line} "
              f"glyphs={len(ids)} max=U+{ids[-1]:04X} kern={sum(len(g.kern) for g in f.glyphs.values())}")
