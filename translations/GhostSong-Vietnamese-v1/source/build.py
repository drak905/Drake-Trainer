"""Build the Ghost Song Vietnamese language pack proxy DLL (winmm.dll) with zig cc + MinHook."""
import os, re, shutil, subprocess, sys

ROOT = r"E:\002.Github\043.ReverseEngine"
HERE = os.path.join(ROOT, "gs-vi")
SRC = os.path.join(HERE, "src")
OUT = os.path.join(HERE, "out")
MH_SRC = os.path.join(ROOT, "tools", "minhook", "minhook-master", "src")


def is_cpp(path):
    txt = open(path, encoding="utf-8", errors="replace").read()
    return bool(re.search(r"^\s*namespace\s+MH\b", txt, re.M))


def main():
    subprocess.check_call([sys.executable, os.path.join(HERE, "gen_proxy.py")])
    os.makedirs(OUT, exist_ok=True)
    work = os.path.join(OUT, "_build")
    if os.path.isdir(work):
        shutil.rmtree(work)
    os.makedirs(os.path.join(work, "src"))
    os.makedirs(os.path.join(work, "include"))
    mh = []
    for name in ("buffer", "hook", "trampoline"):
        s = os.path.join(MH_SRC, name + ".c")
        d = os.path.join(work, "src", name + (".cpp" if is_cpp(s) else ".c"))
        shutil.copy(s, d)
        mh.append(d)
    for name in ("buffer.h", "trampoline.h"):
        p = os.path.join(MH_SRC, name)
        if os.path.exists(p):
            shutil.copy(p, os.path.join(work, "src", name))
    shutil.copy(os.path.join(MH_SRC, "..", "include", "MinHook.h"), os.path.join(work, "include", "MinHook.h"))
    shutil.copytree(os.path.join(MH_SRC, "hde"), os.path.join(work, "src", "hde"), dirs_exist_ok=True)
    for f in ("gsvi.c", "gsvi_il2cpp.c", "gsvi_il2cpp.h", "winmm_proxy.inc", "winmm.def"):
        shutil.copy(os.path.join(SRC, f), os.path.join(work, f))

    dll = os.path.join(OUT, "winmm.dll")
    cmd = ["python", "-m", "ziglang", "cc", "-target", "x86_64-windows-gnu", "-shared", "-O2", "-Wall", "-Wextra",
           "-Wno-unused-parameter", "-I", os.path.join(work, "include"), "-I", os.path.join(work, "src"), "-I", work,
           "-o", dll,
           os.path.join(work, "gsvi.c"), os.path.join(work, "gsvi_il2cpp.c")] + mh + [
           os.path.join(work, "src", "hde", "hde64.c"), os.path.join(work, "winmm.def"),
           "-luser32", "-lkernel32"]
    print(" ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
    if r.returncode != 0:
        print("BUILD FAILED (%d)" % r.returncode)
        return r.returncode
    print("built", dll, os.path.getsize(dll), "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
