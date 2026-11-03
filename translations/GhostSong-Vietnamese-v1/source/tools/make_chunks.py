"""Split the translation sources into chunk files for parallel translation sub-agents."""
import os, sys
W = r"E:\002.Github\043.ReverseEngine\artifacts\gsvi\work"
C = os.path.join(W, "chunks")
os.makedirs(C, exist_ok=True)
for f in os.listdir(C):
    if f.endswith(".tsv"):
        os.remove(os.path.join(C, f))

def split(src, prefix, target_chars, header):
    rows = [l.rstrip("\n") for l in open(os.path.join(W, src), encoding="utf-8")]
    chunks, cur, n = [], [], 0
    for r in rows:
        cur.append(r); n += len(r)
        if n >= target_chars:
            chunks.append(cur); cur, n = [], 0
    if cur:
        chunks.append(cur)
    for i, ch in enumerate(chunks, 1):
        p = os.path.join(C, "%s_%02d.src.tsv" % (prefix, i))
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(ch) + "\n")
        print(p, len(ch), "records", sum(len(x) for x in ch), "chars")
    return len(chunks)

split("dlg_src.tsv", "dlg", 17500, "")
split("ui_src.tsv", "ui", 7000, "")
