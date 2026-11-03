"""Heaps PAK (Dead Cells res.pak) reader / writer.

Layout (version >= 1), from hxd.fmt.pak.Reader.readHeader in the game bytecode:
  "PAK" u8 version  i32 headerSize  i32 dataSize  char[64] stampHash
  file tree                                   (headerSize - 16 - 64 bytes, incl. "DATA")
  "DATA"
  data                                        (dataPosition is relative to headerSize)
File entry: u8 nameLen, name, u8 flags (bit0 = directory)
  directory: i32 count, entries...
  file:      i32 dataPosition, i32 dataSize, i32 checksum (adler32 of the data)

usage:
  pak.py list <pak> [regex]
  pak.py extract <pak> <outdir> [regex]
  pak.py stamp <pak>
"""
import os, re, struct, sys, zlib


class Entry:
    __slots__ = ("name", "is_dir", "content", "pos", "size", "checksum")

    def __init__(self, name, is_dir):
        self.name, self.is_dir = name, is_dir
        self.content, self.pos, self.size, self.checksum = [], 0, 0, 0


def read_header(fp):
    if fp.read(3) != b"PAK":
        raise ValueError("not a PAK file")
    version = fp.read(1)[0]
    header_size, data_size = struct.unpack("<ii", fp.read(8))
    left = header_size - 16
    stamp = b""
    if version >= 1:
        stamp = fp.read(64)
        left -= 64
    tree = fp.read(left)
    if fp.read(4) != b"DATA":
        raise ValueError("corrupted PAK header")
    pos = [0]

    def rd():
        n = tree[pos[0]]
        name = tree[pos[0] + 1:pos[0] + 1 + n].decode("utf-8")
        pos[0] += 1 + n
        flags = tree[pos[0]]
        pos[0] += 1
        e = Entry(name, bool(flags & 1))
        if e.is_dir:
            cnt = struct.unpack_from("<i", tree, pos[0])[0]
            pos[0] += 4
            e.content = [rd() for _ in range(cnt)]
        else:
            e.pos, e.size, e.checksum = struct.unpack_from("<iii", tree, pos[0])
            pos[0] += 12
        return e

    root = rd()
    return version, header_size, data_size, stamp.decode("ascii"), root


def walk(e, path=""):
    for c in e.content:
        p = (path + "/" + c.name) if path else c.name
        if c.is_dir:
            yield from walk(c, p)
        else:
            yield p, c


def adler32(b):
    return zlib.adler32(b) & 0xFFFFFFFF


def write_pak(path, files, stamp, version=1):
    """files: dict 'dir/sub/name' -> bytes. Writes a PAK whose root is an unnamed directory."""
    root = Entry("", True)
    for p in sorted(files):
        parts = p.split("/")
        d = root
        for part in parts[:-1]:
            nxt = next((c for c in d.content if c.is_dir and c.name == part), None)
            if nxt is None:
                nxt = Entry(part, True)
                d.content.append(nxt)
            d = nxt
        f = Entry(parts[-1], False)
        f.size = len(files[p])
        d.content.append(f)
    data = bytearray()

    def assign(e, prefix=""):
        for c in e.content:
            p = (prefix + "/" + c.name) if prefix else c.name
            if c.is_dir:
                assign(c, p)
            else:
                b = files[p]
                c.pos = len(data)
                c.size = len(b)
                c.checksum = adler32(b)
                data.extend(b)

    assign(root)

    def enc(e):
        nb = e.name.encode("utf-8")
        out = bytes([len(nb)]) + nb + bytes([1 if e.is_dir else 0])
        if e.is_dir:
            out += struct.pack("<i", len(e.content)) + b"".join(enc(c) for c in e.content)
        else:
            out += struct.pack("<iiI", e.pos, e.size, e.checksum)
        return out

    tree = enc(root)
    st = stamp.encode("ascii")
    if len(st) != 64:
        raise ValueError("stamp hash must be 64 chars")
    header_size = 16 + 64 + len(tree)
    with open(path, "wb") as fp:
        fp.write(b"PAK" + bytes([version]) + struct.pack("<ii", header_size, len(data)))
        fp.write(st + tree + b"DATA")
        fp.write(data)


def main():
    cmd, pak = sys.argv[1], sys.argv[2]
    with open(pak, "rb") as fp:
        version, hsize, dsize, stamp, root = read_header(fp)
        if cmd == "stamp":
            print(stamp)
            return
        if cmd == "list":
            rx = re.compile(sys.argv[3]) if len(sys.argv) > 3 else None
            for p, e in walk(root):
                if not rx or rx.search(p):
                    print(f"{e.size:>10} {p}")
            return
        if cmd == "extract":
            out = sys.argv[3]
            rx = re.compile(sys.argv[4]) if len(sys.argv) > 4 else None
            n = 0
            for p, e in walk(root):
                if rx and not rx.search(p):
                    continue
                fp.seek(hsize + e.pos)
                b = fp.read(e.size)
                dst = os.path.join(out, *p.split("/"))
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                with open(dst, "wb") as o:
                    o.write(b)
                n += 1
            print("extracted", n)


if __name__ == "__main__":
    main()
