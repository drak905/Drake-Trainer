"""ARCV archive (DrinkBox / Guacamelee! STCE) reader/writer helpers.

File layout (little endian):
  'ARCV\0'  u8 flag(=1)  u32 hdr_size  hdr_stream[hdr_size]  u32 ?  u32 offsets[count+1]  data...
Streams ("compressed stream"): u32 crc, then bit-packed: 3 bits mode, [32 bits usize], payload.
  mode 4: usize (bits 3..34 of byte 4), then 64K segments: u16 clen per segment, then segment data
          (clen==0 -> stored raw, otherwise raw deflate).
"""
import struct
import zlib


def crc_table(poly):
    t = []
    for i in range(256):
        c = i << 24
        for _ in range(8):
            c = ((c << 1) ^ poly) & 0xFFFFFFFF if c & 0x80000000 else (c << 1) & 0xFFFFFFFF
        t.append(c)
    return t


def crc_calc(data, poly=0x827B12AD, init=0):
    t = crc_table(poly)
    c = init
    for b in data:
        c = ((c << 8) & 0xFFFFFFFF) ^ t[((c >> 24) ^ b) & 0xFF]
    return c


def read_stream(buf):
    """Decode a compressed stream (modes 3/4 only). Returns (mode, bytes)."""
    crc = struct.unpack_from('<I', buf, 0)[0]
    v = int.from_bytes(buf[4:9], 'little')
    mode = v & 7
    usize = (v >> 3) & 0xFFFFFFFF
    if mode == 3:
        # raw bit-packed: data bits start at bit 3 of byte 4 + 32 bits -> byte-misaligned by 3 bits
        raise NotImplementedError('mode 3')
    if mode != 4:
        raise NotImplementedError('mode %d' % mode)
    nseg = (1 if (usize & 0xFFFF) else 0) + (usize >> 16)
    pos = 9
    clen = []
    for i in range(nseg):
        clen.append(struct.unpack_from('<H', buf, pos)[0])
        pos += 2
    out = bytearray()
    remaining = usize
    for i in range(nseg):
        seg = min(0x10000, remaining)
        remaining -= seg
        n = clen[i] or 0x10000
        if clen[i] == 0:
            out += buf[pos:pos + seg]
            pos += 0x10000 if seg == 0x10000 else seg
            # note: engine advances by 0x10000 for zero len, last seg is last anyway
        else:
            d = zlib.decompressobj(-15)
            o = d.decompress(buf[pos:pos + n])
            assert len(o) == seg, (len(o), seg)
            out += o
            pos += n
    return mode, crc, bytes(out)


def write_stream(data, level=9):
    usize = len(data)
    nseg = (1 if (usize & 0xFFFF) else 0) + (usize >> 16)
    segs = []
    for i in range(nseg):
        chunk = data[i * 0x10000:(i + 1) * 0x10000]
        c = zlib.compressobj(level, zlib.DEFLATED, -15)
        z = c.compress(chunk) + c.flush()
        if len(z) >= len(chunk) or len(z) > 0xFFFF:
            segs.append((0, chunk))
        else:
            segs.append((len(z), z))
    body = struct.pack('<I', 0)  # placeholder crc
    v = 4 | (usize << 3)
    body += v.to_bytes(5, 'little')
    for cl, _ in segs:
        body += struct.pack('<H', cl)
    for cl, z in segs:
        body += z
    crc = crc_calc(body[4:])
    return struct.pack('<I', crc) + body[4:]


class Arc:
    def __init__(self, path):
        self.path = path
        f = open(path, 'rb')
        self.f = f
        hdr = f.read(10)
        assert hdr[:5] == b'ARCV\x00', hdr
        self.flag = hdr[5]
        self.hdr_size = struct.unpack_from('<I', hdr, 6)[0]
        self.hdr_raw = f.read(self.hdr_size)
        mode, self.hdr_crc, toc = read_stream(self.hdr_raw)
        self.toc = toc
        self.count = struct.unpack_from('<I', toc, 0)[0]
        self.toc_field1 = struct.unpack_from('<I', toc, 4)[0]
        n = self.count
        lens = toc[8:8 + n]
        p = 8 + n
        self.names = []
        for i in range(n):
            ln = lens[i]
            self.names.append(toc[p:p + ln].decode('latin1'))
            p += ln + 2
        self.toc_tail = toc[p:]
        # full names (stored length byte = strlen-1, then name + NUL)
        self.fullnames = []
        p = 8 + n
        for i in range(n):
            ln = lens[i]
            self.fullnames.append(toc[p:p + ln + 1].decode('latin1'))
            p += ln + 2
        self.unk = struct.unpack('<I', f.read(4))[0]
        self.offs = list(struct.unpack('<%dI' % (n + 1), f.read(4 * (n + 1))))
        self.base = f.tell()

    def raw(self, i):
        a = self.base + self.offs[i]
        b = self.base + self.offs[i + 1]
        self.f.seek(a)
        return self.f.read(b - a)

    def data(self, i):
        r = self.raw(i)
        return read_stream(r)[2]


def build_archive(path, entries, unk, flag=1):
    """entries: list of (fullname:str, raw_stream:bytes). Writes ARCV file."""
    n = len(entries)
    names = b''
    lens = bytearray()
    for nm, _ in entries:
        b = nm.encode('latin1')
        assert 1 <= len(b) <= 256
        lens.append(len(b) - 1)
        names += b + b'\x00'
    toc = struct.pack('<II', n, len(names)) + bytes(lens) + names
    hdr = write_stream(toc)
    offs = [0]
    for _, raw in entries:
        offs.append(offs[-1] + len(raw))
    with open(path, 'wb') as f:
        f.write(b'ARCV\x00' + bytes([flag]) + struct.pack('<I', len(hdr)))
        f.write(hdr)
        f.write(struct.pack('<I', unk))
        f.write(struct.pack('<%dI' % (n + 1), *offs))
        for _, raw in entries:
            f.write(raw)
