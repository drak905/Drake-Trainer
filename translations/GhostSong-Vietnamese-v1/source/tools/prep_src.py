"""Build the translation source tables from the game's English data.

  work/dlg_src.tsv : id <TAB> code(escaped) <TAB> speaker <TAB> english(escaped)
  work/ui_src.tsv  : id <TAB> field <TAB> english(escaped)

Escaping: \\ -> \\\\, TAB -> \\t, LF -> \\n, CR -> \\r (reversible, one record per line).
Duplicate CODEs: the game's CSVObject.GetDataByCode returns the FIRST row with that CODE, so only the first is kept.
"""
import csv, io, os, re, collections, sys
sys.path.insert(0, os.path.dirname(__file__))
D = r"E:\002.Github\043.ReverseEngine\artifacts\gsvi\translations"
W = r"E:\002.Github\043.ReverseEngine\artifacts\gsvi\work"
os.makedirs(W, exist_ok=True)

def esc(s):
    return s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n").replace("\r", "\\r")

def unesc(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"t": "\t", "n": "\n", "r": "\r", "\\": "\\"}.get(n, "\\" + n))
            i += 2
        else:
            out.append(c); i += 1
    return "".join(out)

def main():
    raw = open(os.path.join(D, "145_translation.txt"), "rb").read().decode("utf-8-sig")
    rows = list(csv.reader(io.StringIO(raw)))
    hdr = rows[0]; ci = hdr.index("CONTENT"); si = hdr.index("Who is Talking")
    seen = set(); recs = []
    for r in rows[1:]:
        if not r or not r[0]:
            continue
        code = r[0]
        if code in seen:
            continue
        seen.add(code)
        text = r[ci] if len(r) > ci else ""
        spk = r[si] if len(r) > si else ""
        recs.append((code, spk, text))
    with open(os.path.join(W, "dlg_src.tsv"), "w", encoding="utf-8", newline="\n") as f:
        for i, (code, spk, text) in enumerate(recs, 1):
            f.write("%d\t%s\t%s\t%s\n" % (i, esc(code), esc(spk), esc(text)))
    print("dialogue records:", len(recs))
    uniq = collections.OrderedDict()
    for c, s, t in recs:
        uniq.setdefault(t, 0); uniq[t] += 1
    print("unique english texts:", len(uniq), "chars:", sum(len(t) for t in uniq))
    pat = collections.Counter()
    for t in uniq:
        for m in re.findall(r"<[^>]+>|\{[^}]*\}|\[[^\]]*\]|%[sd]|\$\w+", t):
            pat[m] += 1
    print("markup/placeholder patterns:", pat.most_common(40))
    print("max len:", max(len(t) for t in uniq), " >200:", sum(1 for t in uniq if len(t) > 200))

    # ---- UI strings (UItexty English block) ----
    src = open(r"E:\002.Github\043.ReverseEngine\gs-src\UItexty.cs", encoding="utf-8").read().split("\n")
    start = next(i for i, l in enumerate(src) if l.strip() == "case 0:")
    end = next(i for i, l in enumerate(src) if i > start and l.strip() == "case 1:")
    ui = []
    pat_as = re.compile(r'^\s*(\w+) = "((?:[^"\\]|\\.)*)";\s*$')
    bad = 0
    for l in src[start + 1:end]:
        if l.strip() in ("break;", ""):
            continue
        m = pat_as.match(l)
        if not m:
            bad += 1; print("UNPARSED:", l[:120]); continue
        name, lit = m.groups()
        # C# literal -> real string
        val = bytes(lit, "utf-8").decode("unicode_escape").encode("latin-1", "ignore").decode("utf-8", "ignore") if False else None
        val = re.sub(r'\\(["\\nrt])', lambda mm: {'"': '"', '\\': '\\', 'n': '\n', 'r': '\r', 't': '\t'}[mm.group(1)], lit)
        ui.append((name, val))
    with open(os.path.join(W, "ui_src.tsv"), "w", encoding="utf-8", newline="\n") as f:
        for i, (n, v) in enumerate(ui, 1):
            f.write("%d\t%s\t%s\n" % (i, n, esc(v)))
    print("UI records:", len(ui), "unparsed:", bad, "chars:", sum(len(v) for _, v in ui))

if __name__ == "__main__":
    main()
