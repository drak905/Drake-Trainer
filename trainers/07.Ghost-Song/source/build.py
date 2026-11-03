"""Build the Ghost Song trainer proxy DLL (version.dll) with zig cc/c++ + MinHook + Dear ImGui.

    python build.py            -> gs-trainer/out/version.dll

Needs:  pip install ziglang==0.13.0.post1
        MinHook  (tools/minhook/minhook-master)      - BSD-2-Clause
        Dear ImGui v1.91.9 (tools/imgui)             - MIT
Paths can be overridden with GS_ROOT / GS_MINHOOK / GS_IMGUI.
"""
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("GS_ROOT", os.path.dirname(HERE))
SRC = os.path.join(HERE, "src")
OUT = os.path.join(HERE, "out")
# portable package layout: source/third_party/{minhook,imgui}; repo layout: tools/{minhook/minhook-master,imgui}
_tp = os.path.join(HERE, "third_party")
MH_ROOT = os.environ.get("GS_MINHOOK") or (
    os.path.join(_tp, "minhook") if os.path.isdir(os.path.join(_tp, "minhook"))
    else os.path.join(ROOT, "tools", "minhook", "minhook-master"))
IMGUI = os.environ.get("GS_IMGUI") or (
    os.path.join(_tp, "imgui") if os.path.isdir(os.path.join(_tp, "imgui"))
    else os.path.join(ROOT, "tools", "imgui"))
MH_SRC = os.path.join(MH_ROOT, "src")

ZIG = [sys.executable, "-m", "ziglang"]
TARGET = ["-target", "x86_64-windows-gnu"]
COMMON = ["-O2", "-Wall", "-Wextra", "-DNDEBUG", "-fno-strict-aliasing"]
CXX_DEFS = [
    "-std=c++17", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics",
    "-DIMGUI_DISABLE_DEMO_WINDOWS", "-DIMGUI_DISABLE_DEBUG_TOOLS",
    "-DIMGUI_IMPL_WIN32_DISABLE_GAMEPAD", "-DIMGUI_DISABLE_WIN32_DEFAULT_IME_FUNCTIONS",
]


def is_cpp(path):
    txt = open(path, encoding="utf-8", errors="replace").read()
    return bool(re.search(r"^\s*namespace\s+MH\b", txt, re.M))


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def main():
    os.makedirs(OUT, exist_ok=True)
    work = os.path.join(OUT, "_build")
    if os.path.isdir(work):
        def _force(func, path, _exc):          # read-only copies of third-party files
            os.chmod(path, 0o700)
            func(path)
        shutil.rmtree(work, onexc=_force) if sys.version_info >= (3, 12) else shutil.rmtree(work, onerror=_force)
    os.makedirs(os.path.join(work, "mh", "src"))
    os.makedirs(os.path.join(work, "mh", "include"))

    # MinHook keeps the src/ + include/ layout the upstream files expect
    mh_units = []
    for name in ("buffer", "hook", "trampoline"):
        src = os.path.join(MH_SRC, name + ".c")
        cpp = is_cpp(src)
        dst = os.path.join(work, "mh", "src", name + (".cpp" if cpp else ".c"))
        shutil.copy(src, dst)
        mh_units.append((dst, cpp))
    for name in ("buffer.h", "trampoline.h"):
        p = os.path.join(MH_SRC, name)
        if os.path.exists(p):
            shutil.copy(p, os.path.join(work, "mh", "src", name))
    shutil.copy(os.path.join(MH_ROOT, "include", "MinHook.h"), os.path.join(work, "mh", "include", "MinHook.h"))
    shutil.copytree(os.path.join(MH_SRC, "hde"), os.path.join(work, "mh", "src", "hde"))
    mh_units.append((os.path.join(work, "mh", "src", "hde", "hde64.c"), False))

    incs = ["-I", os.path.join(work, "mh", "include"), "-I", os.path.join(work, "mh", "src"),
            "-I", SRC, "-I", IMGUI, "-I", os.path.join(IMGUI, "backends")]

    units = [
        (os.path.join(SRC, "gs_trainer.c"), False),
        (os.path.join(SRC, "gs_il2cpp.c"), False),
        (os.path.join(SRC, "gs_overlay.cpp"), True),
    ]
    for n in ("imgui.cpp", "imgui_draw.cpp", "imgui_tables.cpp", "imgui_widgets.cpp"):
        units.append((os.path.join(IMGUI, n), True))
    for n in ("imgui_impl_win32.cpp", "imgui_impl_dx11.cpp"):
        units.append((os.path.join(IMGUI, "backends", n), True))
    units += mh_units

    objs = []
    jobs = []
    for i, (path, cpp) in enumerate(units):
        obj = os.path.join(work, "%02d_%s.o" % (i, os.path.splitext(os.path.basename(path))[0]))
        objs.append(obj)
        cmd = ZIG + (["c++"] if cpp else ["cc"]) + TARGET + ["-c"] + COMMON + (CXX_DEFS if cpp else []) + incs + ["-o", obj, path]
        jobs.append((path, cmd))

    failed = False
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as ex:
        for (path, cmd), (rc, out) in zip(jobs, ex.map(lambda j: run(j[1]), jobs)):
            name = os.path.basename(path)
            if out.strip():
                # third-party warnings are noise; show ours in full
                if name.startswith("gs_"):
                    sys.stdout.write("== %s\n%s\n" % (name, out))
            if rc != 0:
                failed = True
                sys.stdout.write("COMPILE FAILED: %s\n%s\n" % (path, out))
    if failed:
        print("BUILD FAILED")
        return 1

    shutil.copy(os.path.join(SRC, "version.def"), os.path.join(work, "version.def"))
    dll = os.path.join(OUT, "version.dll")
    link = ZIG + ["cc"] + TARGET + ["-shared", "-O2", "-s", "-o", dll] + objs + [
        os.path.join(work, "version.def"),
        "-luser32", "-lkernel32", "-lgdi32", "-limm32", "-lole32", "-ldwmapi",
    ]
    rc, out = run(link)
    sys.stdout.write(out)
    if rc != 0:
        print("LINK FAILED (%d)" % rc)
        return rc
    print("built", dll, os.path.getsize(dll), "bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
