"""Fix the hang on quit: make libhl.dll!hl_sys_exit end the process with TerminateProcess.

Why: Dead Cells quits through Boot.exit -> Boot.onExit (saves the game, flushes logs, shuts down Epic)
-> hxd.System.exit -> std@sys_exit = libhl!hl_sys_exit, which is just `exit(code)`. exit() runs DLL
teardown; there the Epic overlay DLL (EOSOVH-Win64-Shipping.dll, injected by the Epic launcher) frees
D3D11 objects and the Intel GPU driver (igd10um64xe.dll) spins forever. This also happens with the
unmodified game. The game's own cleanup is finished at that point, so ending the process directly is safe.

hl_sys_exit (original):  sub rsp,28h / call [exit] / int3 x6
patched:                 sub rsp,28h / mov edx,ecx / or rcx,-1 / call [TerminateProcess]

usage: patch_libhl.py <libhl.dll> [--check]     (Python 3.8+, no extra modules)
"""
import shutil
import struct
import sys


class PE:
    def __init__(self, data):
        self.d = data
        pe = struct.unpack_from("<I", data, 0x3C)[0]
        nsec = struct.unpack_from("<H", data, pe + 6)[0]
        optsz = struct.unpack_from("<H", data, pe + 20)[0]
        opt = pe + 24
        if struct.unpack_from("<H", data, opt)[0] != 0x20B:
            raise SystemExit("not a 64-bit DLL")
        self.base = struct.unpack_from("<Q", data, opt + 24)[0]
        dd = opt + 112
        self.exp_rva = struct.unpack_from("<I", data, dd)[0]
        self.imp_rva = struct.unpack_from("<I", data, dd + 8)[0]
        self.secs = []
        so = opt + optsz
        for i in range(nsec):
            vs, va, rs, ra = struct.unpack_from("<IIII", data, so + 40 * i + 8)
            self.secs.append((va, max(vs, rs), ra))

    def off(self, rva):
        for va, sz, ra in self.secs:
            if va <= rva < va + sz:
                return rva - va + ra
        raise ValueError(hex(rva))

    def cstr(self, rva):
        o = self.off(rva)
        return self.d[o:self.d.index(b"\0", o)]

    def exports(self):
        o = self.off(self.exp_rva)
        n_names, f_rva, n_rva, o_rva = struct.unpack_from("<IIII", self.d, o + 24)
        out = {}
        for i in range(n_names):
            name = self.cstr(struct.unpack_from("<I", self.d, self.off(n_rva) + 4 * i)[0])
            ordi = struct.unpack_from("<H", self.d, self.off(o_rva) + 2 * i)[0]
            out[name] = struct.unpack_from("<I", self.d, self.off(f_rva) + 4 * ordi)[0]
        return out

    def imports(self):
        out = {}
        o = self.off(self.imp_rva)
        while True:
            oft, _, _, name, ft = struct.unpack_from("<IIIII", self.d, o)
            if not name:
                break
            lookup = oft or ft
            k = 0
            while True:
                ent = struct.unpack_from("<Q", self.d, self.off(lookup) + 8 * k)[0]
                if not ent:
                    break
                if not ent >> 63:
                    out[self.cstr((ent & 0x7FFFFFFF) + 2)] = ft + 8 * k  # IAT slot rva
                k += 1
            o += 20
        return out


def plan(path):
    data = open(path, "rb").read()
    pe = PE(data)
    rva = pe.exports()[b"hl_sys_exit"]
    imp = pe.imports()
    off = pe.off(rva)
    cur = data[off:off + 16]
    if cur[4:8] == bytes.fromhex("89 CA 48 83"):
        return off, None, "patched"
    disp = struct.unpack_from("<i", cur, 6)[0]
    if not (cur[:6] == bytes.fromhex("48 83 EC 28 FF 15") and rva + 10 + disp == imp[b"exit"]
            and cur[10:16] == b"\xcc" * 6):
        raise SystemExit(f"unexpected hl_sys_exit bytes: {cur.hex(' ')}")
    rel = imp[b"TerminateProcess"] - (rva + 16)
    new = bytes.fromhex("89 CA 48 83 C9 FF FF 15") + struct.pack("<i", rel)  # 12 bytes at rva+4
    return off + 4, new, "original"


def main():
    path = sys.argv[1]
    off, new, state = plan(path)
    print("hl_sys_exit:", state)
    if state == "patched" or "--check" in sys.argv:
        return
    backup = path + ".trainer-backup"
    try:
        open(backup, "rb").close()
    except FileNotFoundError:
        shutil.copy2(path, backup)
    with open(path, "r+b") as fp:
        fp.seek(off)
        fp.write(new)
    print("patched", path)


if __name__ == "__main__":
    main()
