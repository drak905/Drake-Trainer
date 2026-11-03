"""pdbq.py - query CITW PDB via dbghelp (ctypes). usage: pdbq.py <mask> [limit]  | pdbq.py -n <exactname>"""
import ctypes, ctypes.wintypes as wt, sys, json
EXE = r"E:\EpicGames\CreatureintheWell\CITW\Binaries\Win64\CITW-Win64-Shipping.exe"
BASE = 0x140000000
dh = ctypes.WinDLL("dbghelp.dll")
class SYMBOL_INFO(ctypes.Structure):
    _fields_ = [("SizeOfStruct", wt.ULONG), ("TypeIndex", wt.ULONG), ("Reserved", ctypes.c_uint64*2),
                ("Index", wt.ULONG), ("Size", wt.ULONG), ("ModBase", ctypes.c_uint64), ("Flags", wt.ULONG),
                ("Value", ctypes.c_uint64), ("Address", ctypes.c_uint64), ("Register", wt.ULONG), ("Scope", wt.ULONG),
                ("Tag", wt.ULONG), ("NameLen", wt.ULONG), ("MaxNameLen", wt.ULONG), ("Name", ctypes.c_char*2)]
MAXN = 2048
buf = ctypes.create_string_buffer(ctypes.sizeof(SYMBOL_INFO) + MAXN)
def init():
    dh.SymSetOptions(0x2 | 0x4 | 0x10000000 | 0x80000)  # UNDNAME | DEFERRED | NO_PROMPTS ; SYMOPT_FAIL_CRITICAL.. harmless
    dh.SymInitialize(ctypes.c_void_p(-1), r"E:\EpicGames\CreatureintheWell\CITW\Binaries\Win64", False)
    dh.SymLoadModuleExW.restype = ctypes.c_uint64
    b = dh.SymLoadModuleExW(ctypes.c_void_p(-1), None, EXE, None, ctypes.c_uint64(BASE), 0, None, 0)
    if not b: raise SystemExit("load fail %d" % ctypes.GetLastError())
    return b
CB = ctypes.WINFUNCTYPE(wt.BOOL, ctypes.POINTER(SYMBOL_INFO), wt.ULONG, ctypes.c_void_p)
def enum(mask, limit=200):
    out = []
    def cb(si, sz, ctx):
        s = si.contents
        name = ctypes.string_at(ctypes.addressof(s) + SYMBOL_INFO.Name.offset, s.NameLen).decode("latin1")
        out.append((s.Address - BASE, s.Size, name))
        return len(out) < limit
    f = CB(cb)
    dh.SymEnumSymbols(ctypes.c_void_p(-1), ctypes.c_uint64(BASE), mask.encode(), f, None)
    return out
if __name__ == "__main__":
    init()
    mask = sys.argv[1]; lim = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    for rva, sz, n in enum(mask, lim): print(hex(rva), sz, n)
