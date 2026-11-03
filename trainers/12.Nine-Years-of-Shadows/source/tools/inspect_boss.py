import os, sys, collections
import UnityPy
UnityPy.config.FALLBACK_UNITY_VERSION = "2022.3.28f1"
D = r"E:\GOGGalaxy\9 Years of Shadows\9 Years of Shadows_Data"
AA = D + r"\StreamingAssets\aa\StandaloneWindows64"
env = UnityPy.load(*[os.path.join(AA, f) for f in os.listdir(AA) if f.endswith(".bundle")])
CAB = sys.argv[1] if len(sys.argv) > 1 else "CAB-cb3620ce547b3567eb1551f68c36716c"
want = set(sys.argv[2].split(",")) if len(sys.argv) > 2 else {"ElementalKnight_MidBossAreaA"}
sf = [v for b in env.files.values() for k, v in b.files.items() if k == CAB][0]
objs = sf.objects
cache = {}
def tt(pid):
    if pid not in cache: cache[pid] = objs[pid].read_typetree()
    return cache[pid]
def cls(o):
    try: return o.read(check_read=False).m_Script.read().m_ClassName
    except Exception: return None
def comps(go_pid):
    g = tt(go_pid); out = []
    for c in g["m_Component"]:
        co = objs.get(c["component"]["m_PathID"])
        if co is None: continue
        n = co.type.name
        if n == "MonoBehaviour": n = cls(co)
        if n not in ("Transform",): out.append(n)
    return g, out
def tpid(g):
    for c in g["m_Component"]:
        co = objs.get(c["component"]["m_PathID"])
        if co is not None and co.type.name in ("Transform", "RectTransform"): return c["component"]["m_PathID"]
def chain(go_pid):
    res = []
    cur = go_pid
    while cur:
        g, cs = comps(cur)
        res.append((g["m_Name"], cs))
        t = tt(tpid(g)); f = t["m_Father"]["m_PathID"]
        cur = tt(f)["m_GameObject"]["m_PathID"] if f else 0
    return res
for pid, o in objs.items():
    if o.type.name != "MonoBehaviour": continue
    c = cls(o)
    if c in want:
        d = o.read_typetree()
        print("=== %s" % c)
        for name, cs in chain(d["m_GameObject"]["m_PathID"])[:5]:
            print("   %-40s %s" % (name, ", ".join(cs)))
        for k, v in d.items():
            if k in ("m_ObjectHideFlags", "m_CorrespondingSourceObject", "m_PrefabInstance", "m_PrefabAsset", "m_GameObject", "m_Enabled", "m_EditorHideFlags", "m_Script", "m_Name", "m_EditorClassIdentifier"): continue
            print("      %s = %s" % (k, str(v)[:140]))
