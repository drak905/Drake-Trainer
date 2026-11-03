"""Patch any Dead Cells build whose bytecode still has the expected names.

usage: python patch_any_version.py "<game folder>"

Steps: backup deadcells.exe -> deadcells.exe.trainer-backup (once), extract the embedded
HLBOOT.DAT bytecode, rebuild it with build_patch.py, write it back into deadcells.exe.
Only needs Python 3.8+ on Windows (no extra modules).
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_patch
import exeres


def main():
    game = sys.argv[1] if len(sys.argv) > 1 else "."
    exe = os.path.join(game, "deadcells.exe")
    if not os.path.isfile(exe):
        raise SystemExit(f"deadcells.exe not found in {game}")
    backup = exe + ".trainer-backup"
    data = exeres.extract(exe)
    if b"[DC Trainer]" in data:
        raise SystemExit("This deadcells.exe is already patched (restore the backup first to re-patch).")
    if not os.path.exists(backup):
        shutil.copy2(exe, backup)
        print("backup:", backup)
    tmp = tempfile.mkdtemp()
    src, dst = os.path.join(tmp, "vanilla.hl"), os.path.join(tmp, "patched.hl")
    open(src, "wb").write(data)
    build_patch.build(src, dst)
    exeres.replace(exe, open(dst, "rb").read())
    if exeres.extract(exe) != open(dst, "rb").read():
        shutil.copy2(backup, exe)
        raise SystemExit("verification failed, original exe restored")
    shutil.rmtree(tmp, ignore_errors=True)
    print("Dead Cells trainer installed into", exe)


if __name__ == "__main__":
    main()
