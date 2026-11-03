"""GFONT (.fn) reader / writer for Guacamelee! STCE (DrinkBox engine), version 2."""
import struct


class GFont:
    def __init__(self, data=None):
        if data is not None:
            self.parse(data)

    def parse(self, d):
        p = 0
        assert d[:6] == b'GFONT\x00', d[:6]
        p = 6
        self.endian = d[p]; p += 1
        self.version = struct.unpack_from('<I', d, p)[0]; p += 4
        assert self.version == 2
        n = struct.unpack_from('<I', d, p)[0]; p += 4
        self.name1 = d[p:p + n]; p += n
        n = struct.unpack_from('<I', d, p)[0]; p += 4
        self.name2 = d[p:p + n]; p += n
        nk = struct.unpack_from('<I', d, p)[0]; p += 4
        self.kern = []
        for _ in range(nk):
            a, b, k = struct.unpack_from('<HHf', d, p); p += 8
            self.kern.append((a, b, k))
        self.hdr4 = struct.unpack_from('<4I', d, p); p += 16
        self.tw, self.th = struct.unpack_from('<II', d, p); p += 8
        self.tex = bytearray(d[p:p + self.tw * self.th]); p += self.tw * self.th
        self.mid2 = struct.unpack_from('<2I', d, p); p += 8
        ng = struct.unpack_from('<I', d, p)[0]; p += 4
        self.glyphs = []  # dict(code, f4(4 floats), f2a(2 floats), f2b(2 floats), tail(u32))
        for _ in range(ng):
            code = struct.unpack_from('<I', d, p)[0]
            f4 = struct.unpack_from('<4f', d, p + 4)
            a = struct.unpack_from('<2f', d, p + 20)
            b = struct.unpack_from('<2f', d, p + 28)
            tail = struct.unpack_from('<I', d, p + 36)[0]
            self.glyphs.append(dict(code=code, f4=list(f4), a=list(a), b=list(b), tail=tail))
            p += 40
        self.end3 = struct.unpack_from('<3I', d, p); p += 12
        self.size = len(d)
        self.consumed = p

    def build(self):
        o = bytearray(b'GFONT\x00')
        o += bytes([self.endian])
        o += struct.pack('<I', self.version)
        o += struct.pack('<I', len(self.name1)) + self.name1
        o += struct.pack('<I', len(self.name2)) + self.name2
        o += struct.pack('<I', len(self.kern))
        for a, b, k in self.kern:
            o += struct.pack('<HHf', a, b, k)
        o += struct.pack('<4I', *self.hdr4)
        o += struct.pack('<II', self.tw, self.th)
        assert len(self.tex) == self.tw * self.th
        o += bytes(self.tex)
        o += struct.pack('<2I', *self.mid2)
        o += struct.pack('<I', len(self.glyphs))
        for g in self.glyphs:
            o += struct.pack('<I4f2f2fI', g['code'], *g['f4'], *g['a'], *g['b'], g['tail'])
        o += struct.pack('<3I', *self.end3)
        return bytes(o)
