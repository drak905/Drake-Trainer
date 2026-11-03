"""Add a Vietnamese entry to Dead Cells' language table (HashLink bytecode).

  python build_vi_patch.py <in.hl> <out.hl>

Changes (everything is located by class / field / string names, so it also works on top of other
bytecode patches such as the DC trainer, and on other game versions while these names exist):
1. Static init: the array literal assigned to Lang.LANGS grows by one and gets a new entry
     {id:"vi", name:"Tiếng Việt", src:"en", codes:["vi-vn","vi"], chars:"latin", mo:null, isMod:false}
   "src":"en" makes Lang.getTexts load English first and then overlay lang/main.vi.mo
   (readNextMo), so any string missing from the Vietnamese file falls back to English.
   The texts themselves (lang/main.vi.mo) and the font glyphs come from res1.pak, which the game
   loads after res.pak (Boot.initRes: res.pak, res1.pak, res2.pak, ...).
2. Lang.isFontCompatible: returns false for ("legacy" pixel font) while the language is "vi",
   because that bitmap font has no Vietnamese letters; the game then uses the classic font.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hlcode  # noqa: E402
import hlasm  # noqa: E402
from hlcode import OPIDX, Op  # noqa: E402

VI_ID, VI_NAME, VI_SRC, VI_CODES, VI_CHARS = "vi", "Tiếng Việt", "en", ["vi-vn", "vi"], "latin"
MARK = "Tiếng Việt"


class PatchError(Exception):
    pass


def const_string(c, s):
    """Global holding a String object constant (HL "String" opcode only yields raw bytes)."""
    tstr = c.type_by_name["String"]
    for g, fl in c.constants:
        if c.globals[g] == tstr and fl and c.strings[fl[0]] == s:
            return g
    g = c.add_global(tstr)
    c.constants.append((g, [c.add_string(s), c.add_int(len(s.encode("utf-16-le")) // 2)]))
    return g


def global_of_type(c, tname):
    ti = c.type_by_name[tname]
    hits = [g for g, t in enumerate(c.globals) if t == ti]
    if len(hits) != 1:
        raise PatchError(f"global {tname}: {len(hits)} matches")
    return hits[0]


def field_index(c, ti, name):
    t = c.types[ti]
    fl = c.obj_fields(ti) if t.kind in (hlcode.HOBJ, hlcode.HSTRUCT) else t.fields
    for k, (nm, _) in enumerate(fl):
        if c.strings[nm] == name:
            return k
    raise PatchError(f"field {name} not found in {c.tname(ti)}")


def patch_langs(c):
    g_lang = global_of_type(c, "$Lang")
    t_lang = c.type_by_name["$Lang"]
    f_langs = field_index(c, t_lang, "LANGS")
    # find "GetGlobal rX = $Lang ; SetField rX.LANGS = rY"
    site = None
    for f in c.functions:
        for i, o in enumerate(f.ops):
            if o.op == OPIDX["SetField"] and o.p[1] == f_langs and f.regs[o.p[0]] == t_lang:
                if site:
                    raise PatchError("several LANGS writers")
                site = (f, i)
    if not site:
        raise PatchError("LANGS writer not found")
    f, i_set = site
    ops = f.ops
    # ops[i_set-2] = Call1 rArrObj = ArrayObj.alloc(rNative) ; ops[i_set-1] = GetGlobal $Lang
    i_wrap = i_set - 2
    w = ops[i_wrap]
    if w.op != OPIDX["Call1"] or ops[i_set - 1].op != OPIDX["GetGlobal"] or ops[i_set - 1].p[1] != g_lang:
        raise PatchError("unexpected LANGS init shape")
    r_native = w.p[2]
    wrap_fn = w.p[1]
    # walk back to the native alloc of r_native: Call2 r_native = alloc_array(rType, rLen); rLen = Int n
    i_alloc = None
    for k in range(i_wrap - 1, max(0, i_wrap - 4000), -1):
        o = ops[k]
        if o.op == OPIDX["Call2"] and o.p[0] == r_native and c.fname.get(o.p[1], "").endswith("alloc_array"):
            i_alloc = k
            break
    if i_alloc is None:
        raise PatchError("alloc_array of LANGS not found")
    r_len = ops[i_alloc].p[3]
    i_int = i_alloc - 1
    if ops[i_int].op != OPIDX["Int"] or ops[i_int].p[0] != r_len:
        raise PatchError("LANGS length constant not found")
    count = c.ints[ops[i_int].p[1]]
    # first entry block: New rObj ... SetArray r_native rIdx rObj
    i_new = i_alloc + 1
    if ops[i_new].op != OPIDX["New"]:
        raise PatchError("LANGS entry New not found")
    r_obj = ops[i_new].p[0]
    t_entry = f.regs[r_obj]
    fields = {}
    r_str = r_type = r_int = r_codes_native = r_codes_obj = r_bool = None
    i_type_op = None
    k = i_new + 1
    while ops[k].op != OPIDX["SetArray"] or ops[k].p[0] != r_native:
        o = ops[k]
        if o.op == OPIDX["SetField"] and o.p[0] == r_obj:
            fields[c.strings[c.types[t_entry].fields[o.p[1]][0]] if c.types[t_entry].kind == hlcode.HVIRTUAL
                   else c.strings[c.obj_fields(t_entry)[o.p[1]][0]]] = (o.p[1], o.p[2])
        elif o.op == OPIDX["Type"] and i_type_op is None:
            i_type_op = k
            r_type = o.p[0]
        elif o.op == OPIDX["Call2"] and c.fname.get(o.p[1], "").endswith("alloc_array"):
            r_codes_native, r_int = o.p[0], o.p[3]
        elif o.op == OPIDX["Call1"] and o.p[1] == wrap_fn:
            r_codes_obj = o.p[0]
        k += 1
        if k - i_new > 60:
            raise PatchError("LANGS entry block too long")
    need = {"id", "name", "src", "codes", "chars", "mo", "isMod"}
    if not need <= set(fields):
        raise PatchError(f"LANGS entry fields: {sorted(fields)}")
    r_str = fields["id"][1]
    r_bool = fields["isMod"][1]
    if None in (r_type, r_int, r_codes_native, r_codes_obj):
        raise PatchError("LANGS entry registers not found")
    type_op = ops[i_type_op]

    a = hlasm.Asm(f.regs)

    def setf(name, reg):
        a.op("SetField", r_obj, fields[name][0], reg)

    a.op("New", r_obj)
    a.op("GetGlobal", r_str, const_string(c, VI_ID)); setf("id", r_str)
    a.op("GetGlobal", r_str, const_string(c, VI_NAME)); setf("name", r_str)
    a.op("GetGlobal", r_str, const_string(c, VI_SRC)); setf("src", r_str)
    a.op("Type", type_op.p[0], type_op.p[1])
    a.op("Int", r_int, c.add_int(len(VI_CODES)))
    a.op("Call2", r_codes_native, ops[i_alloc].p[1], r_type, r_int)
    for n, code in enumerate(VI_CODES):
        a.op("GetGlobal", r_str, const_string(c, code))
        a.op("Int", r_int, c.add_int(n))
        a.op("SetArray", r_codes_native, r_int, r_str)
    a.op("Call1", r_codes_obj, wrap_fn, r_codes_native); setf("codes", r_codes_obj)
    a.op("GetGlobal", r_str, const_string(c, VI_CHARS)); setf("chars", r_str)
    a.op("Null", r_str); setf("mo", r_str)
    a.op("Bool", r_bool, 0); setf("isMod", r_bool)
    a.op("Int", r_int, c.add_int(count))
    a.op("SetArray", r_native, r_int, r_obj)
    hlasm.insert(c, f, i_wrap, a)
    # grow the array literal (op index i_int is before the insertion point, unchanged)
    f.ops[i_int].p[1] = c.add_int(count + 1)
    return f.findex, count


def patch_font_compat(c):
    f = c.func_by_name("Lang.isFontCompatible")
    tstr = c.type_by_name["String"]
    if f.regs[0] != tstr or f.regs[1] != tstr:
        raise PatchError("Lang.isFontCompatible signature changed")
    g_lang = global_of_type(c, "$Lang")
    t_lang = c.type_by_name["$Lang"]
    a = hlasm.Asm(f.regs)
    r_cls = a.reg(t_lang)
    r_cur = a.reg(tstr)
    r_k = a.reg(tstr)
    r_b = a.reg(c.find_type(hlcode.HBOOL))
    a.op("GetGlobal", r_cls, g_lang)
    a.op("Field", r_cur, r_cls, field_index(c, t_lang, "LANG"))
    a.op("GetGlobal", r_k, const_string(c, VI_ID))
    a.jmp("JNotEq", r_cur, r_k, to="body")
    a.op("GetGlobal", r_k, const_string(c, "legacy"))
    a.jmp("JNotEq", 1, r_k, to="body")
    a.op("Bool", r_b, 0)
    a.op("Ret", r_b)
    hlasm.insert(c, f, 0, a)
    return f.findex


def build(src, dst):
    c = hlcode.Code(open(src, "rb").read())
    if MARK in c.strings:
        raise PatchError("bytecode already contains the Vietnamese patch")
    fi, n = patch_langs(c)
    fc = patch_font_compat(c)
    data = c.serialize()
    hlcode.Code(data)  # must re-parse
    open(dst, "wb").write(data)
    print(f"LANGS in f{fi}: {n} -> {n + 1} entries; Lang.isFontCompatible f{fc} patched; {len(data)} bytes")


if __name__ == "__main__":
    try:
        build(sys.argv[1], sys.argv[2])
    except PatchError as e:
        raise SystemExit("patch failed: " + str(e))

