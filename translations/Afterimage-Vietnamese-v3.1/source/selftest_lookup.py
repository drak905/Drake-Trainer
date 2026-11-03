#!/usr/bin/env python3
"""selftest_lookup.py - run the mod's real lookup() logic (extracted from main.lua) under a Lua runtime against
the generated dictionary, so matching bugs are caught before the game is ever started."""
import io, os, re, sys
from lupa import LuaRuntime
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "payload", "mod", "AI_Vietnamese", "Scripts")
main = open(os.path.join(base, "main.lua"), encoding="utf-8").read()
data = open(os.path.join(base, "vi_data.lua"), encoding="utf-8").read()

# syntax of every shipped Lua file
L = LuaRuntime()
chk = L.eval("function(s) local f,e=load(s) if f then return 'OK' else return e end end")
for n in ("main.lua", "config.lua", "vi_data.lua"):
    r = chk(open(os.path.join(base, n), encoding="utf-8").read())
    print("syntax %-12s %s" % (n, r))
    assert r == "OK", r

# pull out norm() + lookup() verbatim
a = main.index("local function norm")
b = main.index("-- harvest (dev only)")
block = main[a:b]
class _M:  # keep the rest of the script unchanged
    def group(self, _): return block
m = _M()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("EXACT, TMPL = nil, nil")
lua.execute("local d = (function() " + data + " end)(); EXACT, TMPL = d.exact, d.tmpl; ntmpl = #TMPL")
lua.execute(m.group(0).replace("local function norm", "function norm").replace("local function lookup", "function lookup"))
look = lua.eval("lookup")

# 1) hand cases: (source, expected) ; expected None => must NOT match
cases = [
    ("QUIT GAME", "THOÁT GAME"),
    ("Rubiwood Desert", "Sa Mạc Rubiwood"),
    ("Quantity: 3/10", "Số lượng: 3/10"),
    ("COST 500 TO UNLOCK", "TIÊU 500 ĐỂ MỞ KHÓA"),
    ("  \r\nQUIT GAME \r\n", "THOÁT GAME"),
    ("Totally unknown sentence zzz", None),
    ("<Pink>MAX MP+5</>", "<Pink>MP TỐI ĐA +5</>"),
    ("<WhiteG>MAX HP</> <White>+1.4</>", "<WhiteG>HP TỐI ĐA</> <White>+1.4</>"),
    ("<Pink>CRITICAL RATE+1%</>", "<Pink>TỈ LỆ CHÍ MẠNG +1%</>"),
    ("SWORD ATTACK +10", "CÔNG KIẾM +10"),
    ("<Pink>HYDRO RESISTANCE+1%</>", "<Pink>KHÁNG THỦY +1%</>"),
    ("", None),
]
fails = 0
for src, expect in cases:
    got = look(src)
    ok = (got == expect)
    fails += (not ok)
    print(("PASS" if ok else "FAIL"), repr(src)[:48], "->", repr(got)[:70])

# 2) the property that matters: EVERY English string of the game maps to its own Vietnamese
rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "vi_strings.tsv"), encoding="utf-8")]
unesc = lambda s: s.replace("\\r", "\r").replace("\\n", "\n").replace("\\t", "\t")
def n(s): return s.replace("\r\n", "\n").replace("\r", "\n").strip()
want = {}
for r in rows:
    want.setdefault(n(unesc(r[4])), set()).add(n(unesc(r[5])))
miss = []; wrong = []; amb = 0
for en, vis in want.items():
    if not en or "{" in en: continue
    got = look(en)
    if got is None: miss.append(en)
    elif got not in vis and got != n(en): wrong.append((en, got, vis))
    if len(vis) > 1: amb += 1
print("round-trip: %d distinct english strings | no match %d | wrong match %d | same english -> several vi %d" % (len(want), len(miss), len(wrong), amb))
for en in miss[:8]: print("   NO MATCH", repr(en)[:80])
for en, got, vis in wrong[:8]: print("   WRONG", repr(en)[:50], "->", repr(got)[:50])
fails += len(miss) + len(wrong)
print("dictionary: %d exact, %d templates" % (lua.eval("(function() local n=0 for _ in pairs(EXACT) do n=n+1 end return n end)()"), lua.eval("ntmpl")))
sys.exit(1 if fails else 0)



