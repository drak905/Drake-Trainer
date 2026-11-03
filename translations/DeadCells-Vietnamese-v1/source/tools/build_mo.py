"""Merge translated chunks into lang/main.vi.mo.

The game loads English first and then overlays main.vi.mo with GetText.readNextMo, which looks
up each English text (msgstr of main.en.mo) in the Vietnamese file. So main.vi.mo maps
English text -> Vietnamese text.

  python build_mo.py [out.mo]     (default work/res1/lang/main.vi.mo)
Also writes work/vi_strings.json (id, key, en, vi) for review.
"""
import glob, json, os, sys, unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mo  # noqa: E402
from validate_chunk import check_pair  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "work")
# characters some fonts lack -> safe replacements
CHAR_FIX = {"\u2014": "-", "\u2013": "-", "\u2026": "...", "\u201c": "\"", "\u201d": "\"", "\u2018": "'",
            "\u2019": "'", "\u00ab": "\"", "\u00bb": "\""}


def main(out):
    strings = json.load(open(os.path.join(WORK, "strings_en.json"), encoding="utf-8"))
    vi_by_id = {}
    for f in sorted(glob.glob(os.path.join(WORK, "chunks", "chunk_*.out.json"))):
        for o in json.load(open(f, encoding="utf-8")):
            vi_by_id[o["id"]] = o["vi"]
    by_en = {}
    for s in strings:
        if s["id"] in vi_by_id:
            by_en.setdefault(s["en"], vi_by_id[s["id"]])
    entries, review, missing, bad = {}, [], 0, 0
    for s in strings:
        en = s["en"]
        vi = by_en.get(en)
        if vi is None:
            missing += 1
            continue
        vi = unicodedata.normalize("NFC", vi)
        for k, v in CHAR_FIX.items():
            if k not in en:
                vi = vi.replace(k, v)
        if check_pair(en, vi):
            bad += 1
            continue
        entries[en.encode("utf-8")] = vi.encode("utf-8")
        review.append({"id": s["id"], "key": s["key"], "en": en, "vi": vi})
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "wb").write(mo.write(list(entries.items())))
    json.dump(review, open(os.path.join(WORK, "vi_strings.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"{len(entries)} entries -> {out}; strings without translation: {missing}; rejected: {bad}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(WORK, "res1", "lang", "main.vi.mo"))
