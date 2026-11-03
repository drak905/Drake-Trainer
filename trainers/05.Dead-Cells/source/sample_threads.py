"""Sample RIP / stack of every thread of a process (read-only) to see where it is stuck.
usage: sample_threads.py <pid> [samples]"""
import ctypes, sys, time, collections
from ctypes import wintypes as W

pid = int(sys.argv[1]); N = int(sys.argv[2]) if len(sys.argv) > 2 else 20
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
psapi = ctypes.WinDLL("psapi")
TH32CS_SNAPTHREAD, TH32CS_SNAPMODULE = 0x4, 0x8 | 0x10


class THREADENTRY32(ctypes.Structure):
    _fields_ = [("dwSize", W.DWORD), ("cntUsage", W.DWORD), ("th32ThreadID", W.DWORD), ("th32OwnerProcessID", W.DWORD),
                ("tpBasePri", ctypes.c_long), ("tpDeltaPri", ctypes.c_long), ("dwFlags", W.DWORD)]


class MODULEENTRY32W(ctypes.Structure):
    _fields_ = [("dwSize", W.DWORD), ("th32ModuleID", W.DWORD), ("th32ProcessID", W.DWORD), ("GlblcntUsage", W.DWORD),
                ("ProccntUsage", W.DWORD), ("modBaseAddr", ctypes.c_void_p), ("modBaseSize", W.DWORD), ("hModule", W.HMODULE),
                ("szModule", ctypes.c_wchar * 256), ("szExePath", ctypes.c_wchar * 260)]


class CONTEXT(ctypes.Structure):
    _pack_ = 16
    _fields_ = [("P", ctypes.c_uint64 * 6), ("ContextFlags", W.DWORD), ("MxCsr", W.DWORD), ("Seg", ctypes.c_uint16 * 6),
                ("EFlags", W.DWORD), ("Dr", ctypes.c_uint64 * 6), ("Rax", ctypes.c_uint64), ("Rcx", ctypes.c_uint64),
                ("Rdx", ctypes.c_uint64), ("Rbx", ctypes.c_uint64), ("Rsp", ctypes.c_uint64), ("Rbp", ctypes.c_uint64),
                ("Rsi", ctypes.c_uint64), ("Rdi", ctypes.c_uint64), ("R8_15", ctypes.c_uint64 * 8), ("Rip", ctypes.c_uint64),
                ("rest", ctypes.c_byte * 1024)]


k32.CreateToolhelp32Snapshot.restype = W.HANDLE
k32.OpenThread.restype = W.HANDLE
k32.OpenProcess.restype = W.HANDLE


def modules():
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, pid)
    me = MODULEENTRY32W(); me.dwSize = ctypes.sizeof(me)
    out = []
    ok = k32.Module32FirstW(W.HANDLE(snap), ctypes.byref(me))
    while ok:
        out.append((me.modBaseAddr, me.modBaseAddr + me.modBaseSize, me.szModule))
        ok = k32.Module32NextW(W.HANDLE(snap), ctypes.byref(me))
    k32.CloseHandle(W.HANDLE(snap))
    return out


def threads():
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
    te = THREADENTRY32(); te.dwSize = ctypes.sizeof(te)
    out = []
    ok = k32.Thread32First(W.HANDLE(snap), ctypes.byref(te))
    while ok:
        if te.th32OwnerProcessID == pid:
            out.append(te.th32ThreadID)
        ok = k32.Thread32Next(W.HANDLE(snap), ctypes.byref(te))
    k32.CloseHandle(W.HANDLE(snap))
    return out


mods = modules()
hproc = k32.OpenProcess(0x0010 | 0x0400, False, pid)  # VM_READ | QUERY_INFORMATION


def where(a):
    for lo, hi, n in mods:
        if lo <= a < hi:
            return f"{n}+{a - lo:#x}"
    return f"{a:#x}(anon)"


def stack_words(rsp, n=64):
    buf = (ctypes.c_uint64 * n)()
    got = ctypes.c_size_t()
    k32.ReadProcessMemory(W.HANDLE(hproc), ctypes.c_void_p(rsp), buf, ctypes.sizeof(buf), ctypes.byref(got))
    return list(buf)[: got.value // 8]


hits = collections.Counter()
last = {}
for _ in range(N):
    for tid in threads():
        h = k32.OpenThread(0x0002 | 0x0008 | 0x0040, False, tid)  # SUSPEND | GET_CONTEXT | QUERY
        if not h:
            continue
        k32.SuspendThread(W.HANDLE(h))
        ctx = CONTEXT(); ctx.ContextFlags = 0x100003  # CONTEXT_AMD64 | CONTROL | INTEGER
        if k32.GetThreadContext(W.HANDLE(h), ctypes.byref(ctx)):
            hits[(tid, where(ctx.Rip))] += 1
            last[tid] = (ctx.Rip, ctx.Rsp)
        k32.ResumeThread(W.HANDLE(h))
        k32.CloseHandle(W.HANDLE(h))
    time.sleep(0.05)
for (tid, w), n in hits.most_common(30):
    print(f"tid {tid}: {w}  x{n}")
for tid, (rip, rsp) in last.items():
    print(f"-- tid {tid} stack words that point into modules:")
    for v in stack_words(rsp, 4000):
        w = where(v)
        if "(anon)" not in w:
            print("   ", w)

