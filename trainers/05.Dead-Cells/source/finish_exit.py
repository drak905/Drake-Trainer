"""Finish a process that hangs inside ExitProcess (DLL detach deadlock) and can't be killed.
Redirects its last thread to ntdll!NtTerminateProcess(-1, 0), the final step of a normal exit.
usage: finish_exit.py <pid>"""
import ctypes, sys
from ctypes import wintypes as W
sys.path.insert(0, __import__("os").path.dirname(__file__))
from sample_threads import CONTEXT, threads, k32  # noqa: E402  (also prints a short sample)

pid = int(sys.argv[1])
k32.GetModuleHandleW.restype = W.HMODULE
k32.GetProcAddress.restype = ctypes.c_void_p
k32.GetProcAddress.argtypes = [W.HMODULE, ctypes.c_char_p]
nt_term = k32.GetProcAddress(k32.GetModuleHandleW("ntdll.dll"), b"NtTerminateProcess")
for tid in threads():
    h = k32.OpenThread(0x0002 | 0x0008 | 0x0010 | 0x0040, False, tid)
    k32.SuspendThread(W.HANDLE(h))
    ctx = CONTEXT(); ctx.ContextFlags = 0x100003
    k32.GetThreadContext(W.HANDLE(h), ctypes.byref(ctx))
    ctx.Rcx = 0xFFFFFFFFFFFFFFFF      # NtCurrentProcess()
    ctx.Rdx = 0                       # exit status
    ctx.Rsp = (ctx.Rsp & ~0xF) - 8 - 0x100
    ctx.Rip = nt_term
    print("tid", tid, "->", hex(nt_term), "ok" if k32.SetThreadContext(W.HANDLE(h), ctypes.byref(ctx)) else "FAILED")
    k32.ResumeThread(W.HANDLE(h))
    k32.CloseHandle(W.HANDLE(h))
