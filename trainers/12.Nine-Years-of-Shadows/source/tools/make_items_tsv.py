"""items_dump.json -> nys-trainer/data/items.tsv (embedded into NysTrainer.dll).

Columns: area_enum  area_name  map_cx  map_cy  kind  track_id  label  world_x  world_y
 map_cx/map_cy = (world + areaOffset) / (6.4, 3.84)   (same maths MapGeneratorUI uses for the player marker)
 kind: BlueNote | RedNote | ArmorPiece | MapPiece | Upgrade | ArmorAltar:<ElementInt>
Area offsets are copied from MapAreaManager.GetAreaInfo() (nys-src/_9YoS.Scripts.UI.Map/MapAreaManager.cs).
"""
import json, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))
dump = json.load(open(os.path.join(HERE, "items_dump.json"), encoding="utf-8"))
OUT = os.path.join(HERE, "..", "..", "nys-trainer", "data", "items.tsv")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

AREAS = {1: "AreaA", 2: "AreaB", 3: "AreaC", 4: "AreaD", 5: "AreaE", 6: "AreaF", 7: "AreaGa", 8: "AreaGb", 9: "AreaGc",
         10: "PaintingB", 11: "PaintingC", 12: "PaintingD", 13: "AreaH", 14: "AreaHTop", 15: "DarkApino", 16: "SecondChase"}
OFF = {1: (-6.4, -19.2), 2: (-51.2, -30.72), 3: (-108.8, 3.84), 4: (6.4, -15.28), 5: (-172.8, -96.0), 6: (-364.8, -69.12),
       7: (-307.2, -3.84), 8: (-307.2, -3.84), 9: (-307.2, -3.84), 10: (-83.2, -145.92), 11: (0.0, -181.76), 12: (19.2, -172.8),
       13: (0.0, 0.0), 14: (0.0, 0.0), 15: (-6.4, 257.28), 16: (0.0, 0.0)}
CTYPE = {1: "BlueNote", 2: "RedNote", 3: "ArmorPiece", 4: "MapPiece"}

rows = []
standalone = []
for cab, sc in dump.items():
    area = sc["area_enum"]
    if area not in AREAS:
        continue
    ox, oy = OFF[area]
    oy += 49.92
    items = sc["items"]
    # collectable type per parent path
    parent_ct = {}
    for it in items:
        if it["kind"] == "Collectable" and "collectableType" in it:
            parent_ct[it["path"].rsplit("/", 1)[0]] = it["collectableType"]
    holders = [i for i in items if i["kind"] == "ItemHolder"]
    seen = set()
    for h in holders:
        parent = h["path"].rsplit("/", 1)[0]
        label = parent.rsplit("/", 1)[-1]
        ct = parent_ct.get(parent, 0)
        kind = CTYPE.get(ct, "Upgrade")
        tid = h.get("track_id") or ""
        if not tid or (tid in seen):
            continue
        seen.add(tid)
        rows.append((area, h["x"], h["y"], kind, tid, label, ox, oy))
    for a in [i for i in items if i["kind"] == "CollectArmor"]:
        el = a.get("myArmor", 0)
        rows.append((area, a["x"], a["y"], "ArmorAltar:%s" % el, "", a["path"].rsplit("/", 1)[-1], ox, oy))
    parents_with_holder = {h["path"].rsplit("/", 1)[0] for h in holders}
    for i in items:
        if i["kind"] == "Collectable" and i["path"].rsplit("/", 1)[0] not in parents_with_holder:
            standalone.append((AREAS[area], i["path"], i.get("collectableType")))

with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("# area_enum\tarea\tmap_cx\tmap_cy\tkind\ttrack_id\tlabel\tworld_x\tworld_y\n")
    for area, x, y, kind, tid, label, ox, oy in sorted(rows, key=lambda r: (r[0], r[3], r[4])):
        cx = (x + ox) / 6.4
        cy = (y + oy) / 3.84
        f.write("%d\t%s\t%.4f\t%.4f\t%s\t%s\t%s\t%.3f\t%.3f\n" % (area, AREAS[area], cx, cy, kind, tid, label.replace("\t", " "), x, y))

c = collections.Counter((AREAS[r[0]], r[3].split(":")[0]) for r in rows)
print("rows:", len(rows), "->", os.path.abspath(OUT))
by = collections.defaultdict(dict)
for (a, k), n in sorted(c.items()):
    by[a][k] = n
for a, d in by.items():
    print(" ", a, d)
print("standalone Collectables (no ItemHolder; skipped):")
for s in standalone:
    print("   ", s)
