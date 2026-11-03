"""GNU gettext .mo reader / writer (little endian, no hash table).

Entries are (msgid_raw, msgstr_raw) byte strings exactly as stored (msgctxt joined with \\x04,
plural forms joined with \\x00).
usage: mo.py stats <file.mo> | mo.py dump <file.mo> <out.json>
"""
import json, struct, sys


def read(b):
    magic = struct.unpack_from("<I", b, 0)[0]
    if magic != 0x950412DE:
        raise ValueError("bad mo magic %x" % magic)
    rev, n, oo, ot, hs, ho = struct.unpack_from("<6I", b, 4)
    out = []
    for i in range(n):
        ln, off = struct.unpack_from("<II", b, oo + 8 * i)
        lt, oft = struct.unpack_from("<II", b, ot + 8 * i)
        out.append((bytes(b[off:off + ln]), bytes(b[oft:oft + lt])))
    return out


def write(entries):
    """entries: list of (msgid bytes, msgstr bytes). Sorted by msgid as gettext requires."""
    entries = sorted(entries, key=lambda e: e[0])
    n = len(entries)
    oo = 28
    ot = oo + 8 * n
    data_start = ot + 8 * n
    ids = bytearray()
    strs = bytearray()
    id_tab, str_tab = [], []
    for k, v in entries:
        id_tab.append((len(k), len(ids)))
        ids += k + b"\0"
    for k, v in entries:
        str_tab.append((len(v), len(strs)))
        strs += v + b"\0"
    out = bytearray(struct.pack("<7I", 0x950412DE, 0, n, oo, ot, 0, data_start))
    for ln, off in id_tab:
        out += struct.pack("<II", ln, data_start + off)
    sbase = data_start + len(ids)
    for ln, off in str_tab:
        out += struct.pack("<II", ln, sbase + off)
    out += ids + strs
    return bytes(out)


if __name__ == "__main__":
    cmd, fn = sys.argv[1], sys.argv[2]
    e = read(open(fn, "rb").read())
    if cmd == "stats":
        ctx = sum(1 for k, _ in e if b"\x04" in k)
        plural = sum(1 for k, _ in e if b"\x00" in k)
        chars = sum(len(v.decode("utf-8")) for _, v in e)
        print(f"{fn}: entries={len(e)} ctx={ctx} plural={plural} msgstr_chars={chars}")
        print("header:", e[0][1][:400] if e and e[0][0] == b"" else None)
    elif cmd == "dump":
        json.dump([[k.decode("utf-8"), v.decode("utf-8")] for k, v in e], open(sys.argv[3], "w", encoding="utf-8"),
                  ensure_ascii=False, indent=0)
