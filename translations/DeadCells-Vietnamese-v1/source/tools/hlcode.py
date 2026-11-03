"""Minimal HashLink bytecode (HLB v2-v6) reader / writer.

Unmodified sections and functions are written back from their original raw bytes, so a
read -> write round trip is byte-identical. Functions whose `dirty` flag is set are
re-encoded from their parsed ops / regs / debug info.
"""
import struct

# ---- opcode table (hashlink src/opcodes.h) --------------------------------------------
X, R, RNW, C, G, AR, J, VAR = 0, 1, 2, 3, 4, 5, 6, -1
OPS = [
    ("Mov", R, R, X), ("Int", R, G, X), ("Float", R, G, X), ("Bool", R, C, X), ("Bytes", R, G, X),
    ("String", R, G, X), ("Null", R, X, X),
    ("Add", R, R, R), ("Sub", R, R, R), ("Mul", R, R, R), ("SDiv", R, R, R), ("UDiv", R, R, R),
    ("SMod", R, R, R), ("UMod", R, R, R), ("Shl", R, R, R), ("SShr", R, R, R), ("UShr", R, R, R),
    ("And", R, R, R), ("Or", R, R, R), ("Xor", R, R, R),
    ("Neg", R, R, X), ("Not", R, R, X), ("Incr", R, X, X), ("Decr", R, X, X),
    ("Call0", R, C, X), ("Call1", R, C, R), ("Call2", R, AR, 4), ("Call3", R, AR, 5), ("Call4", R, AR, 6),
    ("CallN", R, AR, VAR), ("CallMethod", R, AR, VAR), ("CallThis", R, AR, VAR), ("CallClosure", R, AR, VAR),
    ("StaticClosure", R, G, X), ("InstanceClosure", R, C, R), ("VirtualClosure", R, R, G),
    ("GetGlobal", R, G, X), ("SetGlobal", G, R, X), ("Field", R, R, G), ("SetField", RNW, G, R),
    ("GetThis", R, G, X), ("SetThis", G, R, X), ("DynGet", R, R, C), ("DynSet", RNW, C, R),
    ("JTrue", RNW, J, X), ("JFalse", RNW, J, X), ("JNull", RNW, J, X), ("JNotNull", RNW, J, X),
    ("JSLt", RNW, R, J), ("JSGte", RNW, R, J), ("JSGt", RNW, R, J), ("JSLte", RNW, R, J),
    ("JULt", RNW, R, J), ("JUGte", RNW, R, J), ("JNotLt", RNW, R, J), ("JNotGte", RNW, R, J),
    ("JEq", RNW, R, J), ("JNotEq", RNW, R, J), ("JAlways", J, X, X),
    ("ToDyn", R, R, X), ("ToSFloat", R, R, X), ("ToUFloat", R, R, X), ("ToInt", R, R, X),
    ("SafeCast", R, R, X), ("UnsafeCast", R, R, X), ("ToVirtual", R, R, X),
    ("Label", X, X, X), ("Ret", RNW, X, X), ("Throw", RNW, X, X), ("Rethrow", RNW, X, X),
    ("Switch", RNW, AR, VAR), ("NullCheck", RNW, X, X), ("Trap", RNW, J, X), ("EndTrap", R, X, X),
    ("GetI8", R, R, R), ("GetI16", R, R, R), ("GetMem", R, R, R), ("GetArray", R, R, R),
    ("SetI8", R, R, R), ("SetI16", R, R, R), ("SetMem", R, R, R), ("SetArray", R, R, R),
    ("New", R, X, X), ("ArraySize", R, R, X), ("Type", R, G, X), ("GetType", R, R, X), ("GetTID", R, R, X),
    ("Ref", R, R, X), ("Unref", R, R, X), ("Setref", RNW, R, X),
    ("MakeEnum", R, AR, VAR), ("EnumAlloc", R, R, X), ("EnumIndex", R, R, X), ("EnumField", R, AR, 4),
    ("SetEnumField", RNW, R, C),
    ("Assert", X, X, X), ("RefData", R, R, X), ("RefOffset", R, R, C), ("Nop", X, X, X),
    ("Prefetch", RNW, C, C), ("Asm", C, C, C), ("Catch", J, X, X),
]
OPNAME = [o[0] for o in OPS]
OPIDX = {n: i for i, n in enumerate(OPNAME)}


def _nargs(a, b, c):
    if b == AR:
        return c
    if c == X:
        if b == X:
            return 0 if a == X else 1
        return 2
    return 3


NARGS = [_nargs(*o[1:]) for o in OPS]
VAR_OPS = {OPIDX[n] for n in ("CallN", "CallClosure", "CallMethod", "CallThis", "MakeEnum")}
SWITCH = OPIDX["Switch"]
# jump-target operand position per op (relative to the next op)
JUMP_P = {}
for i, (n, a, b, c) in enumerate(OPS):
    if n == "Catch" or n == "JAlways":
        JUMP_P[i] = 1
    elif b == J:
        JUMP_P[i] = 2
    elif c == J:
        JUMP_P[i] = 3

HVOID, HUI8, HUI16, HI32, HI64, HF32, HF64, HBOOL, HBYTES, HDYN, HFUN, HOBJ, HARRAY, HTYPE, HREF, \
    HVIRTUAL, HDYNOBJ, HABSTRACT, HENUM, HNULL, HMETHOD, HSTRUCT, HPACKED, HGUID = range(24)
KIND = ["void", "u8", "u16", "i32", "i64", "f32", "f64", "bool", "bytes", "dyn", "fun", "obj", "array",
        "type", "ref", "virtual", "dynobj", "abstract", "enum", "null", "method", "struct", "packed", "guid"]


# ---- primitive encoding -----------------------------------------------------------------
class Reader:
    def __init__(self, b, pos=0):
        self.b, self.pos = b, pos

    def byte(self):
        v = self.b[self.pos]
        self.pos += 1
        return v

    def i32(self):
        v = struct.unpack_from("<i", self.b, self.pos)[0]
        self.pos += 4
        return v

    def index(self):
        b = self.byte()
        if not b & 0x80:
            return b & 0x7F
        if not b & 0x40:
            v = self.byte() | ((b & 31) << 8)
            return -v if b & 0x20 else v
        c, d, e = self.byte(), self.byte(), self.byte()
        v = ((b & 31) << 24) | (c << 16) | (d << 8) | e
        return -v if b & 0x20 else v

    def raw(self, n):
        v = self.b[self.pos:self.pos + n]
        self.pos += n
        return v


def enc_index(v):
    neg = v < 0
    a = -v if neg else v
    if not neg and a < 0x80:
        return bytes([a])
    if a < 0x2000:
        return bytes([0x80 | (0x20 if neg else 0) | (a >> 8), a & 0xFF])
    if a >= 0x20000000:
        raise ValueError("index too large")
    return bytes([0xC0 | (0x20 if neg else 0) | (a >> 24), (a >> 16) & 0xFF, (a >> 8) & 0xFF, a & 0xFF])


# ---- structures -------------------------------------------------------------------------
class Type:
    __slots__ = ("kind", "raw", "args", "ret", "name", "super", "glob", "fields", "protos", "bindings",
                 "tparam", "constructs")

    def __init__(self):
        self.kind = 0
        self.raw = b""
        self.name = None
        self.super = -1
        self.fields = []      # (name_str_idx, type_idx)
        self.protos = []      # (name_str_idx, findex, pindex)
        self.bindings = []    # (field_idx, findex)
        self.constructs = []  # (name, [types])
        self.args, self.ret, self.tparam, self.glob = [], None, None, None


class Function:
    __slots__ = ("type", "findex", "regs", "ops", "debug", "assigns", "raw", "dirty")

    def __init__(self):
        self.dirty = False


class Op:
    __slots__ = ("op", "p")  # p: list of operands (p1, p2, p3, extra...)

    def __init__(self, op, p):
        self.op, self.p = op, list(p)

    def __repr__(self):
        return f"{OPNAME[self.op]} {self.p}"


class Code:
    def __init__(self, data):
        self.data = data
        r = Reader(data)
        if data[:3] != b"HLB":
            raise ValueError("not HL bytecode")
        r.pos = 3
        self.version = r.byte()
        self.flags = r.index()
        self.nints = r.index(); self.nfloats = r.index(); self.nstrings = r.index()
        self.nbytes = r.index() if self.version >= 5 else 0
        self.ntypes = r.index(); self.nglobals = r.index(); self.nnatives = r.index()
        self.nfunctions = r.index()
        self.nconstants = r.index() if self.version >= 4 else 0
        self.entrypoint = r.index()
        self.hasdebug = self.flags & 1
        self.ints = [r.i32() for _ in range(self.nints)]
        self.floats = [struct.unpack("<d", r.raw(8))[0] for _ in range(self.nfloats)]
        self.strings = self._read_strings(r, self.nstrings)
        if self.version >= 5:
            size = r.i32()
            self.bytes_blob = r.raw(size)
            self.bytes_pos = [r.index() for _ in range(self.nbytes)]
        self.debugfiles = self._read_strings(r, r.index()) if self.hasdebug else []
        self.types = [self._read_type(r) for _ in range(self.ntypes)]
        self.globals = [r.index() for _ in range(self.nglobals)]
        self.natives = []
        for _ in range(self.nnatives):
            self.natives.append((r.index(), r.index(), r.index(), r.index()))  # lib, name, type, findex
        self.functions = [self._read_function(r) for _ in range(self.nfunctions)]
        self.constants = []
        for _ in range(self.nconstants):
            g = r.index(); n = r.index()
            self.constants.append((g, [r.index() for _ in range(n)]))
        if r.pos != len(data):
            raise ValueError(f"trailing data {r.pos} != {len(data)}")
        self._index()

    # -- reading helpers
    @staticmethod
    def _read_strings(r, n):
        size = r.i32()
        blob = r.raw(size)
        out, p = [], 0
        for _ in range(n):
            sz = r.index()
            out.append(blob[p:p + sz].decode("utf-8", "surrogateescape"))
            p += sz + 1
        return out

    def _read_type(self, r):
        t = Type()
        start = r.pos
        t.kind = k = r.byte()
        if k in (HFUN, HMETHOD):
            n = r.byte()
            t.args = [r.index() for _ in range(n)]
            t.ret = r.index()
        elif k in (HOBJ, HSTRUCT):
            t.name = r.index(); t.super = r.index(); t.glob = r.index()
            nf, np_, nb = r.index(), r.index(), r.index()
            t.fields = [(r.index(), r.index()) for _ in range(nf)]
            t.protos = [(r.index(), r.index(), r.index()) for _ in range(np_)]
            t.bindings = [(r.index(), r.index()) for _ in range(nb)]
        elif k == HVIRTUAL:
            nf = r.index()
            t.fields = [(r.index(), r.index()) for _ in range(nf)]
        elif k == HABSTRACT:
            t.name = r.index()
        elif k == HENUM:
            t.name = r.index(); t.glob = r.index()
            for _ in range(r.index()):
                nm = r.index()
                t.constructs.append((nm, [r.index() for _ in range(r.index())]))
        elif k in (HREF, HNULL, HPACKED):
            t.tparam = r.index()
        t.raw = bytes(r.b[start:r.pos])
        return t

    def _read_op(self, r):
        op = r.byte()
        n = NARGS[op]
        if n >= 0:
            if n <= 3:
                p = [r.index() for _ in range(n)]
            else:
                p = [r.index() for _ in range(n)]  # p1 p2 p3 + extras
        elif op in VAR_OPS:
            p1, p2, cnt = r.index(), r.index(), r.byte()
            p = [p1, p2, cnt] + [r.index() for _ in range(cnt)]
        elif op == SWITCH:
            p1, cnt = r.index(), r.index()
            offs = [r.index() for _ in range(cnt)]
            p = [p1, cnt] + offs + [r.index()]
        else:
            raise ValueError(f"bad op {op}")
        return Op(op, p)

    def _read_function(self, r):
        f = Function()
        start = r.pos
        f.type = r.index(); f.findex = r.index()
        nregs = r.index(); nops = r.index()
        f.regs = [r.index() for _ in range(nregs)]
        f.ops = [self._read_op(r) for _ in range(nops)]
        f.debug, f.assigns = None, None
        if self.hasdebug:
            f.debug = self._read_debug(r, nops)
            if self.version >= 3:
                na = r.index()
                per = 3 if self.version >= 6 else 2
                f.assigns = [tuple(r.index() for _ in range(per)) for _ in range(na)]
        f.raw = bytes(r.b[start:r.pos])
        return f

    @staticmethod
    def _read_debug(r, nops):
        curfile, curline, out = -1, 0, []
        while len(out) < nops:
            c = r.byte()
            if c & 1:
                curfile = ((c >> 1) << 8) | r.byte()
            elif c & 2:
                delta, count = c >> 6, (c >> 2) & 15
                out += [(curfile, curline)] * count
                curline += delta
            elif c & 4:
                curline += c >> 3
                out.append((curfile, curline))
            else:
                b2, b3 = r.byte(), r.byte()
                curline = (c >> 3) | (b2 << 5) | (b3 << 13)
                out.append((curfile, curline))
        return out

    # -- writing
    @staticmethod
    def _write_strings(out, strs):
        blob = b"".join(s.encode("utf-8", "surrogateescape") + b"\0" for s in strs)
        out += struct.pack("<i", len(blob)) + blob
        for s in strs:
            out += enc_index(len(s.encode("utf-8", "surrogateescape")))

    @staticmethod
    def _enc_op(o):
        b = bytearray([o.op])
        n = NARGS[o.op]
        if n >= 0:
            for v in o.p:
                b += enc_index(v)
        elif o.op in VAR_OPS:
            b += enc_index(o.p[0]) + enc_index(o.p[1]) + bytes([o.p[2]])
            for v in o.p[3:]:
                b += enc_index(v)
        else:
            for v in o.p:
                b += enc_index(v)
        return bytes(b)

    def _enc_function(self, f):
        b = bytearray()
        b += enc_index(f.type) + enc_index(f.findex) + enc_index(len(f.regs)) + enc_index(len(f.ops))
        for t in f.regs:
            b += enc_index(t)
        for o in f.ops:
            b += self._enc_op(o)
        if self.hasdebug:
            curfile = -1
            for fi, line in f.debug:
                if fi != curfile:
                    b += bytes([((fi >> 8) << 1) | 1, fi & 0xFF])
                    curfile = fi
                b += bytes([(line & 31) << 3, (line >> 5) & 0xFF, (line >> 13) & 0xFF])
            if self.version >= 3:
                b += enc_index(len(f.assigns))
                for a in f.assigns:
                    for v in a:
                        b += enc_index(v)
        return bytes(b)

    def serialize(self):
        out = bytearray(b"HLB" + bytes([self.version]))
        out += enc_index(self.flags)
        hdr = [len(self.ints), len(self.floats), len(self.strings)]
        if self.version >= 5:
            hdr.append(len(self.bytes_pos))
        hdr += [len(self.types), len(self.globals), len(self.natives), len(self.functions)]
        if self.version >= 4:
            hdr.append(len(self.constants))
        hdr.append(self.entrypoint)
        for v in hdr:
            out += enc_index(v)
        for v in self.ints:
            out += struct.pack("<i", v)
        for v in self.floats:
            out += struct.pack("<d", v)
        self._write_strings(out, self.strings)
        if self.version >= 5:
            out += struct.pack("<i", len(self.bytes_blob)) + self.bytes_blob
            for v in self.bytes_pos:
                out += enc_index(v)
        if self.hasdebug:
            out += enc_index(len(self.debugfiles))
            self._write_strings(out, self.debugfiles)
        for t in self.types:
            out += t.raw
        for g in self.globals:
            out += enc_index(g)
        for n in self.natives:
            for v in n:
                out += enc_index(v)
        for f in self.functions:
            out += self._enc_function(f) if f.dirty else f.raw
        for g, fl in self.constants:
            out += enc_index(g) + enc_index(len(fl))
            for v in fl:
                out += enc_index(v)
        return bytes(out)

    # -- symbol helpers
    def _index(self):
        self.fidx = {}  # findex -> Function
        for f in self.functions:
            self.fidx[f.findex] = f
        self.native_idx = {n[3]: n for n in self.natives}
        self.fname = {}
        self.type_by_name = {}
        for ti, t in enumerate(self.types):
            if t.kind in (HOBJ, HSTRUCT):
                nm = self.strings[t.name]
                self.type_by_name.setdefault(nm, ti)
                for pn, fi, _ in t.protos:
                    self.fname.setdefault(fi, nm + "." + self.strings[pn])
                allf = self.obj_fields(ti)
                for fid, fi in t.bindings:
                    cls = nm[1:] if nm.startswith("$") else nm
                    self.fname.setdefault(fi, cls + "." + self.strings[allf[fid][0]])
        for n in self.natives:
            self.fname[n[3]] = "native:" + self.strings[n[0]] + "@" + self.strings[n[1]]

    def obj_fields(self, ti):
        t = self.types[ti]
        base = self.obj_fields(t.super) if t.super >= 0 else []
        return base + t.fields

    def obj_protos(self, ti):
        """Return virtual table: list indexed by pindex of (name, findex)."""
        t = self.types[ti]
        tbl = list(self.obj_protos(t.super)) if t.super >= 0 else []
        for pn, fi, pi in t.protos:
            if pi < 0:
                continue
            while len(tbl) <= pi:
                tbl.append(None)
            tbl[pi] = (self.strings[pn], fi)
        return tbl

    def tname(self, ti):
        t = self.types[ti]
        if t.kind in (HOBJ, HSTRUCT, HABSTRACT, HENUM):
            return self.strings[t.name]
        if t.kind == HNULL:
            return "Null<" + self.tname(t.tparam) + ">"
        if t.kind == HREF:
            return "Ref<" + self.tname(t.tparam) + ">"
        if t.kind in (HFUN, HMETHOD):
            return "(" + ",".join(self.tname(a) for a in t.args) + ")->" + self.tname(t.ret)
        if t.kind == HVIRTUAL:
            return "virtual{" + ",".join(self.strings[n] for n, _ in t.fields[:6]) + "}"
        return KIND[t.kind]

    def find_type(self, kind):
        for i, t in enumerate(self.types):
            if t.kind == kind:
                return i
        raise KeyError(kind)

    def add_string(self, s):
        try:
            return self.strings.index(s)
        except ValueError:
            self.strings.append(s)
            return len(self.strings) - 1

    def add_int(self, v):
        try:
            return self.ints.index(v)
        except ValueError:
            self.ints.append(v)
            return len(self.ints) - 1

    def add_float(self, v):
        for i, f in enumerate(self.floats):
            if f == v:
                return i
        self.floats.append(v)
        return len(self.floats) - 1

    def add_global(self, ti):
        self.globals.append(ti)
        return len(self.globals) - 1

    def func_by_name(self, name):
        hits = [fi for fi, n in self.fname.items() if n == name and fi in self.fidx]
        if len(hits) != 1:
            raise KeyError(f"{name}: {len(hits)} matches")
        return self.fidx[hits[0]]
