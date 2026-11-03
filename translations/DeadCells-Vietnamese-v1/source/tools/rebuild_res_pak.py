"""Rebuild the Vietnamese patch pak from a (possibly newer) game's own res.pak.

  python rebuild_res_pak.py <game res.pak> <main.vi.mo> <out.pak>

Reads the Latin fonts from the game's res.pak, completes their Vietnamese letters with
fontcompose.py, adds lang/main.vi.mo and writes a pak stamped like the game's res.pak.
Needs Python 3.8+ with Pillow and NumPy (pip install pillow numpy).
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fontcompose  # noqa: E402
import pak  # noqa: E402

FONTS = ["avril_18", "avril_27", "avril_48", "latin_12", "latin_18", "latin_27", "latin_adys_12",
         "latin_adys_18", "latin_adys_27", "latin_arial_12", "latin_arial_18", "latin_arial_27",
         "latin_medieval_18", "latin_medieval_27", "latin_medieval_48", "latin_medieval_100",
         "monoUbuntu_12", "monoUbuntu_18", "monoUbuntu_27"]


def main(res_pak, mo_path, out):
    tmp = tempfile.mkdtemp()
    src, dst = os.path.join(tmp, "orig"), os.path.join(tmp, "new")
    with open(res_pak, "rb") as fp:
        version, hsize, _, stamp, root = pak.read_header(fp)
        entries = dict(pak.walk(root))
        for name in FONTS:
            for ext in (".fnt", ".png"):
                p = f"fonts/exported/{name}{ext}"
                if p not in entries:
                    continue
                e = entries[p]
                fp.seek(hsize + e.pos)
                d = os.path.join(src, *p.split("/"))
                os.makedirs(os.path.dirname(d), exist_ok=True)
                open(d, "wb").write(fp.read(e.size))
    for name in FONTS:
        rel = f"fonts/exported/{name}.fnt"
        if os.path.exists(os.path.join(src, rel)):
            r = fontcompose.process(src, dst, rel)
            print(r[0], "glyphs added:", r[1])
    files = {}
    for d, _, fs in os.walk(dst):
        for fn in fs:
            p = os.path.join(d, fn)
            files[os.path.relpath(p, dst).replace("\\", "/")] = open(p, "rb").read()
    files["lang/main.vi.mo"] = open(mo_path, "rb").read()
    pak.write_pak(out, files, stamp)
    print(f"{out}: {len(files)} files, stamp {stamp}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
