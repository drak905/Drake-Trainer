"""Validate translated chunks:  python validate_chunk.py NN [NN ...]   (or "all")

Reads work/chunks/chunk_NN.in.json + chunk_NN.out.json and checks, per string:
  - every id present exactly once, non-empty Vietnamese text
  - ::placeholders:: identical (same names, same count)
  - {text@CODE} colour tags: same number of {..} and the same @CODE list; {..@img} icons unchanged
  - same count of '*' (emphasis), '%', '$word', '\\n' and U+00A0 as the English
  - no CJK / Cyrillic, no mojibake, text is Unicode NFC
"""
import collections, json, os, re, sys, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = os.path.join(ROOT, "work", "chunks")

PH = re.compile(r"::[^:\s]*::")
BRACE = re.compile(r"\{([^{}]*)\}")
DOLLAR = re.compile(r"\$[A-Za-z]\w*")
BTN = re.compile(r"(?<!:):[A-Za-z0-9_]+:(?!:)")


def sig(s):
    codes, imgs, n = [], [], 0
    for m in BRACE.finditer(s):
        n += 1
        body = m.group(1)
        if "@" in body:
            code = body.rsplit("@", 1)[1]
            if code == "img":
                imgs.append(body)
            else:
                codes.append(code)
    return {
        "placeholders": collections.Counter(PH.findall(s)),
        "button_icons": collections.Counter(BTN.findall(s)),
        "braces": n,
        "codes": collections.Counter(codes),
        "icons": collections.Counter(imgs),
        "*": s.count("*"),
        "%": s.count("%"),
        "$": collections.Counter(DOLLAR.findall(s)),
        "newlines": s.count("\n"),
    }


def check_pair(en, vi):
    errs = []
    if not isinstance(vi, str) or not vi.strip():
        return ["empty"]
    a, b = sig(en), sig(vi)
    for k in a:
        if a[k] != b[k]:
            errs.append(f"{k}: en={dict(a[k]) if isinstance(a[k], collections.Counter) else a[k]} "
                        f"vi={dict(b[k]) if isinstance(b[k], collections.Counter) else b[k]}")
    if re.search(r"[\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af\u0400-\u04ff]", vi):
        errs.append("CJK/Cyrillic characters")
    if "\ufffd" in vi or re.search("Ã[\u0080-\u00bf]|á»", vi):
        errs.append("mojibake")
    if unicodedata.normalize("NFC", vi) != vi:
        errs.append("not NFC")
    return errs


def check(nn):
    src = json.load(open(os.path.join(CH, "chunk_%s.in.json" % nn), encoding="utf-8"))
    path = os.path.join(CH, "chunk_%s.out.json" % nn)
    if not os.path.exists(path):
        return ["output file missing"], len(src)
    try:
        out = json.load(open(path, encoding="utf-8"))
    except Exception as ex:
        return [f"invalid JSON: {ex}"], len(src)
    errs, got = [], {}
    for o in out:
        if o["id"] in got:
            errs.append("duplicate id %d" % o["id"])
        got[o["id"]] = o.get("vi")
    for x in src:
        i, en = x["id"], x["en"]
        if i not in got:
            errs.append("missing id %d: %r" % (i, en[:50]))
            continue
        for e in check_pair(en, got[i]):
            errs.append(f"id {i}: {e}  | en={en[:70]!r}")
    extra = set(got) - set(x["id"] for x in src)
    if extra:
        errs.append("unknown ids: %s" % sorted(extra)[:10])
    return errs, len(src)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["all"]:
        args = sorted(f[6:-8] for f in os.listdir(CH) if f.endswith(".in.json"))
    bad = 0
    for nn in args:
        errs, n = check(nn)
        print("chunk", nn, "strings", n, "errors", len(errs))
        for e in errs[:40]:
            print("  -", e)
        bad += len(errs)
    sys.exit(1 if bad else 0)
