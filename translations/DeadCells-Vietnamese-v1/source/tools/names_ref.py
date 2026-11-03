"""Build per-chunk name references for the text chunks (t*): for every translated name/UI string
(n* chunks) whose English appears inside a text chunk string, write chunk_tNN.names.json {en: vi}."""
import glob, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = os.path.join(ROOT, "work", "chunks")

names = {}
for f in sorted(glob.glob(os.path.join(CH, "chunk_n*.in.json"))):
    src = json.load(open(f, encoding="utf-8"))
    out = {o["id"]: o["vi"] for o in json.load(open(f.replace(".in.", ".out."), encoding="utf-8"))}
    for x in src:
        en = x["en"].strip()
        if len(en) >= 4 and x["id"] in out:
            names[en] = out[x["id"]]
pats = [(en, re.compile(r"(?<![A-Za-z])" + re.escape(en) + r"(?![a-z])")) for en in names]
for f in sorted(glob.glob(os.path.join(CH, "chunk_t*.in.json"))):
    text = "\n".join(x["en"] for x in json.load(open(f, encoding="utf-8")))
    ref = {en: names[en] for en, p in pats if p.search(text)}
    json.dump(ref, open(f.replace(".in.json", ".names.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(os.path.basename(f), len(ref))
json.dump(names, open(os.path.join(ROOT, "work", "names_vi.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
