"""Pack work/res1/** into a Heaps PAK that the game loads after res.pak.

  python make_res1.py <out.pak> [<game res.pak to copy the stamp from> | --stamp <64 hex>]

The 64-character stamp hash must equal the one in the game's res.pak (the game ignores a pak
whose stamp differs). It is stored at byte offset 12..75 of the file, so an installer can also
rewrite it in place.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pak  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "work", "res1")
PLACEHOLDER = "0" * 64


def collect(src=SRC):
    files = {}
    for d, _, fs in os.walk(src):
        for fn in fs:
            p = os.path.join(d, fn)
            files[os.path.relpath(p, src).replace("\\", "/")] = open(p, "rb").read()
    return files


def main():
    out = sys.argv[1]
    stamp = PLACEHOLDER
    if len(sys.argv) > 2:
        if sys.argv[2] == "--stamp":
            stamp = sys.argv[3]
        else:
            with open(sys.argv[2], "rb") as fp:
                stamp = pak.read_header(fp)[3]
    files = collect()
    pak.write_pak(out, files, stamp)
    with open(out, "rb") as fp:
        v, hs, ds, st, root = pak.read_header(fp)
        n = sum(1 for _ in pak.walk(root))
        for p, e in pak.walk(root):
            fp.seek(hs + e.pos)
            if fp.read(e.size) != files[p]:
                raise SystemExit("verify failed: " + p)
    print(f"{out}: {n} files, {os.path.getsize(out)} bytes, stamp {st}")


if __name__ == "__main__":
    main()
