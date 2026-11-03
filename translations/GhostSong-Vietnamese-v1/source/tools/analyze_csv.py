"""Compare the code sets of the per-language translation CSVs shipped in resources.assets."""
import csv, io, os, collections
D = r"E:\002.Github\043.ReverseEngine\artifacts\gsvi\translations"
# container: path -> pathid (from res_container.py): the exact-name entries are what Resources.Load returns
LANG_PID = {"chinese": 138, "english": 145, "french": 133, "german": 149, "japanese": 137, "korean": 151,
            "portuguese": 142, "russian": 140, "spanish": 156}
def load(pid):
    fn = [f for f in os.listdir(D) if f.startswith("%d_" % pid)][0]
    raw = open(os.path.join(D, fn), "rb").read().decode("utf-8-sig", errors="replace")
    rows = list(csv.reader(io.StringIO(raw)))
    hdr = rows[0]
    ci = hdr.index("CONTENT")
    out = collections.OrderedDict()
    dup = 0
    for r in rows[1:]:
        if not r or not r[0]:
            continue
        if r[0] in out:
            dup += 1
            continue
        out[r[0]] = r[ci] if len(r) > ci else ""
    return out, hdr, dup
data = {}
for lang, pid in LANG_PID.items():
    d, hdr, dup = load(pid)
    data[lang] = d
    print("%-10s pid=%d hdr=%s codes=%d dup=%d nonempty=%d" % (lang, pid, hdr, len(d), dup, sum(1 for v in d.values() if v.strip())))
en = set(data["english"])
for lang, d in data.items():
    s = set(d)
    print("%-10s only-in-it vs english: %d   missing-vs-english: %d" % (lang, len(s - en), len(en - s)))
allc = set()
for d in data.values():
    allc |= set(d)
print("union codes:", len(allc), " english:", len(en))
