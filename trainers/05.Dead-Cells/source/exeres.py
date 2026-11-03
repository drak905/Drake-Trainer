"""Read / replace the embedded HashLink bytecode (RCDATA "HLBOOT.DAT") in deadcells.exe.

  exeres.py extract <exe> <out.hl>
  exeres.py replace <exe> <in.hl>      (uses Win32 UpdateResourceW, same type/name/lang)
"""
import ctypes, os, sys
from ctypes import wintypes

RT_RCDATA = 10
LANG = 0x400


def extract(exe):
    """Read the RCDATA "HLBOOT.DAT" resource with Win32 (no third-party modules)."""
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.LoadLibraryExW.restype = wintypes.HMODULE
    k32.LoadLibraryExW.argtypes = [wintypes.LPCWSTR, wintypes.HANDLE, wintypes.DWORD]
    k32.FindResourceW.restype = wintypes.HANDLE
    k32.FindResourceW.argtypes = [wintypes.HMODULE, wintypes.LPCWSTR, ctypes.c_void_p]
    k32.SizeofResource.restype = wintypes.DWORD
    k32.SizeofResource.argtypes = [wintypes.HMODULE, wintypes.HANDLE]
    k32.LoadResource.restype = wintypes.HANDLE
    k32.LoadResource.argtypes = [wintypes.HMODULE, wintypes.HANDLE]
    k32.LockResource.restype = ctypes.c_void_p
    k32.LockResource.argtypes = [wintypes.HANDLE]
    k32.FreeLibrary.argtypes = [wintypes.HMODULE]
    LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE = 0x40
    h = k32.LoadLibraryExW(os.path.abspath(exe), None, LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE)
    if not h:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        r = k32.FindResourceW(h, "HLBOOT.DAT", ctypes.c_void_p(RT_RCDATA))
        if not r:
            raise RuntimeError("HLBOOT.DAT resource not found")
        n = k32.SizeofResource(h, r)
        p = k32.LockResource(k32.LoadResource(h, r))
        return ctypes.string_at(p, n)
    finally:
        k32.FreeLibrary(h)


def replace(exe, data):
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.BeginUpdateResourceW.restype = wintypes.HANDLE
    k32.BeginUpdateResourceW.argtypes = [wintypes.LPCWSTR, wintypes.BOOL]
    k32.UpdateResourceW.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.LPCWSTR, wintypes.WORD,
                                    ctypes.c_void_p, wintypes.DWORD]
    k32.EndUpdateResourceW.argtypes = [wintypes.HANDLE, wintypes.BOOL]
    h = k32.BeginUpdateResourceW(exe, False)
    if not h:
        raise ctypes.WinError(ctypes.get_last_error())
    buf = ctypes.create_string_buffer(data, len(data))
    if not k32.UpdateResourceW(h, ctypes.c_void_p(RT_RCDATA), "HLBOOT.DAT", LANG, buf, len(data)):
        err = ctypes.get_last_error()
        k32.EndUpdateResourceW(h, True)
        raise ctypes.WinError(err)
    if not k32.EndUpdateResourceW(h, False):
        raise ctypes.WinError(ctypes.get_last_error())


if __name__ == "__main__":
    cmd, exe, f = sys.argv[1:4]
    if cmd == "extract":
        open(f, "wb").write(extract(exe))
    elif cmd == "replace":
        replace(exe, open(f, "rb").read())
    print("ok")
