"""Validate translated chunks:  python validate_vi.py [chunkname ...]   (names like dlg_01, ui_02; default = all that exist)

Checks per chunk: same ids/order/count as the source, no stray TAB/newline, escape sequences and placeholders/tags preserved,
leading/trailing whitespace kept, Vietnamese actually produced (not a copy of English), NFC normalised.
Exit code 1 if any chunk fails.  Prints the failing ids so a sub-agent can be re-run for just that chunk.
"""
import os, re, sys, unicodedata
C = r"E:\002.Github\043.ReverseEngine\artifacts\gsvi\work\chunks"
VI_RE = re.compile(r"[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]", re.I)
TOK = re.compile(r"<[^>]+>|\{[^}]*\}|%[sd]|\\n|\\t|\\\\|https?://\S+")

def read(p):
    out = []
    with open(p, encoding="utf-8", newline="") as f:
        data = f.read()
    for line in data.split("\n"):
        if line == "":
            continue
        out.append(line.rstrip("\r"))
    return out

def check(name):
    src_p = os.path.join(C, name + ".src.tsv")
    vi_p = os.path.join(C, name + ".vi.tsv")
    if not os.path.exists(vi_p):
        return None, ["missing output file"]
    src = [l.split("\t") for l in read(src_p)]
    vi = read(vi_p)
    errs = []
    if len(src) != len(vi):
        errs.append("record count %d != %d" % (len(vi), len(src)))
    is_dlg = name.startswith("dlg")
    ok_ids = set()
    for i, s in enumerate(src):
        sid = s[0]
        eng = s[3] if is_dlg else s[2]
        if i >= len(vi):
            errs.append("%s: missing line" % sid); continue
        parts = vi[i].split("\t")
        if len(parts) != 2:
            errs.append("%s: expected 'id<TAB>text' got %d fields" % (sid, len(parts))); continue
        vid, txt = parts
        if vid != sid:
            errs.append("%s: id mismatch (%s)" % (sid, vid)); continue
        if unicodedata.normalize("NFC", txt) != txt:
            errs.append("%s: not NFC" % sid); continue
        if eng.strip() == "":
            if txt.strip() != "":
                errs.append("%s: expected empty" % sid)
            else:
                ok_ids.add(sid)
            continue
        if TOK.findall(eng) != TOK.findall(txt):
            errs.append("%s: tags/escapes differ  EN=%r VI=%r" % (sid, TOK.findall(eng), TOK.findall(txt))); continue
        if (eng != eng.rstrip()) != (txt != txt.rstrip()) or (eng != eng.lstrip()) != (txt != txt.lstrip()):
            errs.append("%s: edge whitespace differs (EN=%r VI=%r)" % (sid, eng[-3:] + "|" + eng[:3], txt[-3:] + "|" + txt[:3])); continue
        if txt.strip() == "":
            errs.append("%s: empty translation" % sid); continue
        if len(txt) > 3 * len(eng) + 40:
            errs.append("%s: far too long (%d vs %d)" % (sid, len(txt), len(eng))); continue
        letters = re.sub(r"<[^>]+>|\{[^}]*\}|\\.|[^A-Za-zÀ-ỹ]", "", eng)
        if len(letters) >= 12 and txt == eng:
            errs.append("%s: identical to English: %r" % (sid, eng[:60])); continue
        ok_ids.add(sid)
    return (len(src), len(ok_ids)), errs

def main():
    names = sys.argv[1:]
    if not names:
        names = sorted(f[:-8] for f in os.listdir(C) if f.endswith(".src.tsv"))
    bad = 0
    tot = ok = 0
    for n in names:
        res, errs = check(n)
        if res is None:
            print("%-8s MISSING" % n); bad += 1; continue
        tot += res[0]; ok += res[1]
        if errs:
            bad += 1
            print("%-8s %d/%d ok, %d problems" % (n, res[1], res[0], len(errs)))
            for e in errs[:25]:
                print("     ", e)
            if len(errs) > 25:
                print("      ... %d more" % (len(errs) - 25))
        else:
            print("%-8s OK (%d records)" % (n, res[0]))
    print("TOTAL %d/%d records valid; failing chunks: %d" % (ok, tot, bad))
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
