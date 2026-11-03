import os, sys, collections, json
import UnityPy
UnityPy.config.FALLBACK_UNITY_VERSION = "2022.3.28f1"
D = r"E:\GOGGalaxy\9 Years of Shadows\9 Years of Shadows_Data"
AA = D + r"\StreamingAssets\aa\StandaloneWindows64"
env = UnityPy.load(*[os.path.join(AA, f) for f in os.listdir(AA) if f.endswith(".bundle")])
TARGET_CAB = sys.argv[1] if len(sys.argv) > 1 else "CAB-cb3620ce547b3567eb1551f68c36716c"   # Map_Area_A
sf = None
for b in env.files.values():
    for k, v in b.files.items():
        if k == TARGET_CAB:
            sf = v
objs = sf.objects
def tt(pid):
    return objs[pid].read_typetree()
def cls(o):
    try:
        return o.read(check_read=False).m_Script.read().m_ClassName
    except Exception:
        return None
def go_of(pid):
    o = objs.get(pid)
    return o
def go_summary(go_pid, depth=0, maxdepth=2):
    o = objs.get(go_pid)
    if o is None:
        return "<none>"
    g = o.read_typetree()
    comps = []
    for c in g["m_Component"]:
        co = objs.get(c["component"]["m_PathID"])
        if co is None:
            continue
        n = co.type.name
        if n == "MonoBehaviour":
            n = "MB:" + str(cls(co))
        comps.append(n)
    return "%s [layer %d, tag %s, active %s] comps=%s" % (g["m_Name"], g["m_Layer"], g.get("m_Tag"), g["m_IsActive"], ",".join(comps))
def children_go(go_pid):
    g = tt(go_pid)
    tpid = None
    for c in g["m_Component"]:
        co = objs.get(c["component"]["m_PathID"])
        if co is not None and co.type.name in ("Transform", "RectTransform"):
            tpid = c["component"]["m_PathID"]
    if tpid is None:
        return []
    t = tt(tpid)
    return [tt(ch["m_PathID"])["m_GameObject"]["m_PathID"] for ch in t["m_Children"]]

count = 0
kinds = collections.Counter()
for pid, o in objs.items():
    if o.type.name != "MonoBehaviour":
        continue
    c = cls(o)
    if c not in ("GateController", "DestructibleBlocker", "FakeWall"):
        continue
    d = o.read_typetree()
    gopid = d["m_GameObject"]["m_PathID"]
    kinds[c] += 1
    if count < 6 and c == "GateController":
        count += 1
        print("=== GateController", go_summary(gopid))
        print("   openByDefault", d.get("openByDefault"), "noAutomation", d.get("noAutomation"), "trackingInfo", d.get("trackingInfo"))
        ib = d.get("instantBarrier", {}).get("m_PathID")
        if ib:
            ibo = objs.get(ib)
            print("   instantBarrier ->", ibo.type.name if ibo else None, "go:", go_summary(tt(ib)["m_GameObject"]["m_PathID"]) if ibo else "")
        for s in d.get("gateSliders", []):
            sp = s["m_PathID"]
            so = objs.get(sp)
            sd = so.read_typetree()
            print("   slider:", go_summary(sd["m_GameObject"]["m_PathID"]))
            bpid = sd["barrierSpriteRenderer"]["m_PathID"]
            bo = objs.get(bpid)
            bgo = bo.read_typetree()["m_GameObject"]["m_PathID"]
            print("      barrier GO:", go_summary(bgo))
            for ch in children_go(bgo):
                print("         child:", go_summary(ch))
    if c in ("DestructibleBlocker", "FakeWall") and kinds[c] <= 2:
        print("===", c, go_summary(gopid))
        pb = d.get("physicalBarrier", {}).get("m_PathID")
        if pb and pb in objs:
            print("   physicalBarrier:", objs[pb].type.name, go_summary(tt(pb)["m_GameObject"]["m_PathID"]))
print(dict(kinds))
