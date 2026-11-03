"""Add the Vietnamese language entry to any deadcells.exe whose bytecode still has the expected names.

usage: python patch_any_version.py "<path to deadcells.exe>"

Extracts the embedded HashLink bytecode (RCDATA HLBOOT.DAT), runs build_vi_patch.build on it and
writes it back. The caller (install.ps1) makes the backup first. Needs Python 3.8+ on Windows,
no extra modules.
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_vi_patch  # noqa: E402
import exeres  # noqa: E402


def main():
    exe = sys.argv[1]
    if not os.path.isfile(exe):
        raise SystemExit(f"not found: {exe}")
    data = exeres.extract(exe)
    if build_vi_patch.MARK.encode("utf-8") in data:
        print("already patched")
        return
    tmp = tempfile.mkdtemp()
    src, dst = os.path.join(tmp, "in.hl"), os.path.join(tmp, "out.hl")
    open(src, "wb").write(data)
    try:
        build_vi_patch.build(src, dst)
    except build_vi_patch.PatchError as e:
        raise SystemExit("patch failed: " + str(e))
    new = open(dst, "rb").read()
    exeres.replace(exe, new)
    if exeres.extract(exe) != new:
        raise SystemExit("verification failed (restore the backup)")
    print("Vietnamese language added to", exe)


if __name__ == "__main__":
    main()
