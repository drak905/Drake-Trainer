"""Inspect Dead Cells HL bytecode.

  hlinspect.py classes <regex>          list obj types matching
  hlinspect.py class <name>             fields + methods of a class
  hlinspect.py funcs <regex>            function names matching
  hlinspect.py dis <name|findex>        disassemble a function
  hlinspect.py xref <name|findex>       functions that call a function
  hlinspect.py fieldref <Class> <field> functions that read/write a field
  hlinspect.py strings <regex>          strings and the functions using them
"""
import os, pickle, re, sys

sys.path.insert(0, os.path.dirname(__file__))
import hlcode
from hlcode import OPNAME, OPIDX

HL = os.environ.get("DC_HL", os.path.join(os.path.dirname(__file__), "..", "..", "artifacts", "dc", "vanilla.hl"))
CACHE = HL + ".pickle"


def load():
    if os.path.exists(CACHE) and os.path.getmtime(CACHE) > os.path.getmtime(HL):
        with open(CACHE, "rb") as fp:
            return pickle.load(fp)
    c = hlcode.Code(open(HL, "rb").read())
    c.data = None
    with open(CACHE, "wb") as fp:
        pickle.dump(c, fp, protocol=4)
    return c


def fn_of(c, key):
    if re.fullmatch(r"\d+", key):
        return c.fidx[int(key)]
    return c.func_by_name(key)


def field_name(c, ti, idx):
    t = c.types[ti]
    if t.kind in (hlcode.HOBJ, hlcode.HSTRUCT):
        fl = c.obj_fields(ti)
        if 0 <= idx < len(fl):
            return c.strings[fl[idx][0]]
    if t.kind == hlcode.HVIRTUAL and 0 <= idx < len(t.fields):
        return c.strings[t.fields[idx][0]]
    return f"#{idx}"


def proto_name(c, ti, idx):
    t = c.types[ti]
    if t.kind == hlcode.HOBJ:
        tbl = c.obj_protos(ti)
        if 0 <= idx < len(tbl) and tbl[idx]:
            return tbl[idx][0] + f"(f{tbl[idx][1]})"
    return f"m#{idx}"


_CONST = None


def const_str(c, g):
    global _CONST
    if _CONST is None:
        _CONST = {}
        for gi, fl in c.constants:
            if c.tname(c.globals[gi]) == "String" and fl:
                _CONST[gi] = c.strings[fl[0]]
    return _CONST.get(g)


def fmt_op(c, f, i, o):
    n = OPNAME[o.op]
    p = o.p
    rt = lambda r: c.tname(f.regs[r])
    s = f"{i:4d} {n:<14}"
    if n in ("Call0", "Call1", "Call2", "Call3", "Call4", "CallN"):
        args = p[2:] if n != "CallN" else p[3:]
        if n == "Call0":
            args = []
        s += f"r{p[0]} = {c.fname.get(p[1], 'f' + str(p[1]))}({', '.join('r%d' % a for a in args)})"
    elif n in ("CallMethod", "CallThis"):
        args = p[3:]
        obj = 0 if n == "CallThis" else args[0]
        s += f"r{p[0]} = r{obj}.{proto_name(c, f.regs[obj], p[1])}({', '.join('r%d' % a for a in args)})"
    elif n == "CallClosure":
        s += f"r{p[0]} = r{p[1]}({', '.join('r%d' % a for a in p[3:])})"
    elif n == "Field":
        s += f"r{p[0]} = r{p[1]}.{field_name(c, f.regs[p[1]], p[2])}"
    elif n == "SetField":
        s += f"r{p[0]}.{field_name(c, f.regs[p[0]], p[1])} = r{p[2]}"
    elif n == "GetThis":
        s += f"r{p[0]} = this.{field_name(c, f.regs[0], p[1])}"
    elif n == "SetThis":
        s += f"this.{field_name(c, f.regs[0], p[0])} = r{p[1]}"
    elif n == "String":
        s += f"r{p[0]} = {c.strings[p[1]]!r}"
    elif n == "Int":
        s += f"r{p[0]} = {c.ints[p[1]]}"
    elif n == "Float":
        s += f"r{p[0]} = {c.floats[p[1]]}"
    elif n in ("GetGlobal",):
        k = const_str(c, p[1])
        s += f"r{p[0]} = G{p[1]}:" + (repr(k) if k is not None else c.tname(c.globals[p[1]]))
    elif n in ("SetGlobal",):
        s += f"G{p[0]}:{c.tname(c.globals[p[0]])} = r{p[1]}"
    elif o.op in hlcode.JUMP_P:
        jp = hlcode.JUMP_P[o.op] - 1
        s += " ".join(f"r{v}" for k, v in enumerate(p) if k != jp) + f" -> {i + 1 + p[jp]}"
    elif n == "StaticClosure":
        s += f"r{p[0]} = &{c.fname.get(p[1], p[1])}"
    elif n == "InstanceClosure":
        s += f"r{p[0]} = &{c.fname.get(p[1], p[1])}[r{p[2]}]"
    elif n == "DynGet":
        s += f"r{p[0]} = r{p[1]}.{c.strings[p[2]]}"
    elif n == "DynSet":
        s += f"r{p[0]}.{c.strings[p[1]]} = r{p[2]}"
    elif n == "Switch":
        cnt = p[1]
        s += f"r{p[0]} [" + ",".join(str(i + 1 + x) for x in p[2:2 + cnt]) + f"] default {i + 1 + p[-1]}"
    else:
        s += " ".join(str(v) for v in p)
    return s


def dis(c, f):
    print(f"== f{f.findex} {c.fname.get(f.findex, '?')} : {c.tname(f.type)}")
    if f.debug:
        fi, ln = f.debug[0]
        print(f"   file {c.debugfiles[fi] if fi >= 0 else '?'}:{ln}")
    print("   regs: " + "  ".join(f"r{i}:{c.tname(t)[:40]}" for i, t in enumerate(f.regs)))
    for i, o in enumerate(f.ops):
        line = f.debug[i][1] if f.debug else ""
        print(f"{fmt_op(c, f, i, o):<90} ;{line}")


def calls_of(o):
    n = OPNAME[o.op]
    if n.startswith("Call") and n not in ("CallMethod", "CallThis", "CallClosure"):
        return [o.p[1]]
    if n in ("StaticClosure", "InstanceClosure"):
        return [o.p[1]]
    return []


def main():
    c = load()
    cmd = sys.argv[1]
    a = sys.argv[2:]
    if cmd == "classes":
        rx = re.compile(a[0])
        for ti, t in enumerate(c.types):
            if t.kind == hlcode.HOBJ and rx.search(c.strings[t.name]):
                sup = c.strings[c.types[t.super].name] if t.super >= 0 else ""
                print(ti, c.strings[t.name], "extends", sup)
    elif cmd == "class":
        ti = c.type_by_name[a[0]]
        t = c.types[ti]
        allf = c.obj_fields(ti)
        own0 = len(allf) - len(t.fields)
        print("type", ti, "super", c.tname(t.super) if t.super >= 0 else None)
        for k, (nm, ft) in enumerate(allf):
            print(f"  field {k}{'' if k >= own0 else ' (inh)'} {c.strings[nm]} : {c.tname(ft)}")
        for pn, fi, pi in t.protos:
            print(f"  method {c.strings[pn]} f{fi} pidx {pi} : {c.tname(c.fidx[fi].type) if fi in c.fidx else ''}")
        st = c.type_by_name.get("$" + a[0])
        if st is not None:
            sf = c.obj_fields(st)
            for fid, fi in c.types[st].bindings:
                print(f"  static {c.strings[sf[fid][0]]} f{fi}")
            for k, (nm, ft) in enumerate(sf):
                print(f"  sfield {k} {c.strings[nm]} : {c.tname(ft)}")
    elif cmd == "funcs":
        rx = re.compile(a[0])
        for fi, n in sorted(c.fname.items()):
            if rx.search(n):
                print(fi, n)
    elif cmd == "dis":
        for k in a:
            dis(c, fn_of(c, k))
    elif cmd == "xref":
        tgt = fn_of(c, a[0]).findex
        for f in c.functions:
            if any(tgt in calls_of(o) for o in f.ops):
                print(f.findex, c.fname.get(f.findex, "?"))
    elif cmd == "vxref":  # calls through method index on a class
        ti = c.type_by_name[a[0]]
        tbl = c.obj_protos(ti)
        pidx = [k for k, e in enumerate(tbl) if e and e[0] == a[1]][0]
        for f in c.functions:
            for o in f.ops:
                n = OPNAME[o.op]
                if n in ("CallMethod", "CallThis"):
                    obj = 0 if n == "CallThis" else o.p[3]
                    if o.p[1] == pidx and a[0] in c.tname(f.regs[obj]):
                        print(f.findex, c.fname.get(f.findex, "?")); break
    elif cmd == "fieldref":
        ti = c.type_by_name[a[0]]
        allf = c.obj_fields(ti)
        idx = [k for k, (nm, _) in enumerate(allf) if c.strings[nm] == a[1]][0]
        sub = set()
        for k, t in enumerate(c.types):  # the class and all subclasses
            x = k
            while x >= 0 and c.types[x].kind == hlcode.HOBJ:
                if x == ti:
                    sub.add(k); break
                x = c.types[x].super
        for f in c.functions:
            hits = []
            for i, o in enumerate(f.ops):
                n = OPNAME[o.op]
                if n == "Field" and o.p[2] == idx and f.regs[o.p[1]] in sub:
                    hits.append(f"R@{i}")
                elif n == "SetField" and o.p[1] == idx and f.regs[o.p[0]] in sub:
                    hits.append(f"W@{i}")
                elif n == "GetThis" and o.p[1] == idx and f.regs and f.regs[0] in sub:
                    hits.append(f"R@{i}")
                elif n == "SetThis" and o.p[0] == idx and f.regs and f.regs[0] in sub:
                    hits.append(f"W@{i}")
            if hits:
                print(f.findex, c.fname.get(f.findex, "?"), " ".join(hits[:12]))
    elif cmd == "strings":
        rx = re.compile(a[0])
        ids = {i for i, s in enumerate(c.strings) if rx.search(s)}
        for i in sorted(ids)[:60]:
            users = [f.findex for f in c.functions if any(OPNAME[o.op] == "String" and o.p[1] == i for o in f.ops)]
            print(i, repr(c.strings[i][:80]), [c.fname.get(u, u) for u in users[:6]])


if __name__ == "__main__":
    main()
