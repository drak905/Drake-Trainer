import os, sys, collections
import UnityPy
UnityPy.config.FALLBACK_UNITY_VERSION = "2022.3.28f1"
D = r"E:\GOGGalaxy\9 Years of Shadows\9 Years of Shadows_Data"
AA = D + r"\StreamingAssets\aa\StandaloneWindows64"
env = UnityPy.load(*[os.path.join(AA, f) for f in os.listdir(AA) if f.endswith(".bundle")])
CAB = sys.argv[1] if len(sys.argv) > 1 else "CAB-cb3620ce547b3567eb1551f68c36716c"
sf = [v for b in env.files.values() for k, v in b.files.items() if k == CAB][0]
objs = sf.objects
cache = {}
def tt(pid):
    if pid not in cache:
        cache[pid] = objs[pid].read_typetree()
    return cache[pid]
def cls(o):
    try:
        return o.read(check_read=False).m_Script.read().m_ClassName
    except Exception:
        return None
def comps(go_pid):
    g = tt(go_pid); out = []
    for c in g["m_Component"]:
        co = objs.get(c["component"]["m_PathID"])
        if co is None: continue
        n = co.type.name
        if n == "MonoBehaviour": n = "MB:" + str(cls(co))
        out.append(n)
    return g, out
def tpid_of(g):
    for c in g["m_Component"]:
        co = objs.get(c["component"]["m_PathID"])
        if co is not None and co.type.name in ("Transform", "RectTransform"):
            return c["component"]["m_PathID"]
def tree(go_pid, depth=0, maxd=5):
    g, cs = comps(go_pid)
    colinfo = []
    for c in g["m_Component"]:
        co = objs.get(c["component"]["m_PathID"])
        if co is not None and "Collider" in co.type.name:
            d = co.read_typetree()
            colinfo.append("%s(trig=%s,en=%s)" % (co.type.name, d.get("m_IsTrigger"), d.get("m_Enabled")))
    print("  " * depth + "- %s [L%d %s] %s %s" % (g["m_Name"], g["m_Layer"], "on" if g["m_IsActive"] else "off", ",".join(c for c in cs if c not in ("Transform",)), " ".join(colinfo)))
    if depth >= maxd: return
    t = tt(tpid_of(g))
    for ch in t["m_Children"]:
        tree(tt(ch["m_PathID"])["m_GameObject"]["m_PathID"], depth + 1, maxd)
shown = 0
for pid, o in objs.items():
    if o.type.name != "MonoBehaviour": continue
    if cls(o) != "Ramp_LDTK": continue
    d = o.read_typetree()
    print("RAMP isDoor=%s isRight=%s type=%r" % (d.get("_isDoor"), d.get("_isRight"), d.get("_slopeType")))
    if d.get("_isDoor") and shown < 2:
        shown += 1
        tree(d["m_GameObject"]["m_PathID"], 0, 6)
        print()
cnt = collections.Counter()
for pid, o in objs.items():
    if o.type.name == "MonoBehaviour" and cls(o) == "Ramp_LDTK":
        cnt[o.read_typetree().get("_isDoor")] += 1
print("ramps by isDoor:", dict(cnt))
