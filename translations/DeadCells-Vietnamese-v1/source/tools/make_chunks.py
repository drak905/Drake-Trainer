"""Split the English Dead Cells texts (lang/main.en.mo) into translation chunks.

Writes work/strings_en.json  [{id, key, en}]  (id = index in main.en.mo)
       work/chunks/chunk_NN.in.json  [{id, en, ctx?}]  (unique English strings, game order)
"""
import json, os, re, sys

sys.path.insert(0, os.path.dirname(__file__))
import mo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "work")
CH = os.path.join(WORK, "chunks")
LIMIT_CHARS, LIMIT_N = 4500, 140


def main(en_mo):
    ents = mo.read(open(en_mo, "rb").read())
    strings = []
    for i, (k, v) in enumerate(ents):
        strings.append({"id": i, "key": k.decode("utf-8"), "en": v.decode("utf-8")})
    json.dump(strings, open(os.path.join(WORK, "strings_en.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    seen, uniq = {}, []
    for s in strings:
        if not s["en"].strip() or s["en"] in seen:
            continue
        seen[s["en"]] = s["id"]
        item = {"id": s["id"], "en": s["en"]}
        k = s["key"]
        if re.fullmatch(r"[A-Z0-9_]+", k):
            item["ctx"] = k
        elif "||" in k:
            item["ctx"] = k.split("||", 1)[1].strip()
        uniq.append(item)
    os.makedirs(CH, exist_ok=True)

    def is_name(s):
        return (len(s) <= 40 and len(s.split()) <= 5 and "::" not in s and "{" not in s and "\n" not in s
                and not re.search(r"[.!?…:;,\"“]$", s.strip()))

    groups = {"n": [it for it in uniq if is_name(it["en"])], "t": [it for it in uniq if not is_name(it["en"])]}
    total = 0
    for g, items in groups.items():
        lim_n = 200 if g == "n" else LIMIT_N
        chunks, cur, size = [], [], 0
        for it in items:
            if cur and (size + len(it["en"]) > LIMIT_CHARS or len(cur) >= lim_n):
                chunks.append(cur)
                cur, size = [], 0
            cur.append(it)
            size += len(it["en"])
        if cur:
            chunks.append(cur)
        for n, c in enumerate(chunks):
            json.dump(c, open(os.path.join(CH, "chunk_%s%02d.in.json" % (g, n)), "w", encoding="utf-8"),
                      ensure_ascii=False, indent=0)
        print(f"group {g}: {len(items)} strings, {len(chunks)} chunks")
        total += len(chunks)
    print(f"{len(strings)} strings, {len(uniq)} unique, {total} chunks")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(WORK, "orig", "lang", "main.en.mo"))
