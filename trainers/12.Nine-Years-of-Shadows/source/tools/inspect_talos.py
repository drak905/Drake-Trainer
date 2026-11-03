import os, sys
import UnityPy
UnityPy.config.FALLBACK_UNITY_VERSION = "2022.3.28f1"
D = r"E:\GOGGalaxy\9 Years of Shadows\9 Years of Shadows_Data"
AA = D + r"\StreamingAssets\aa\StandaloneWindows64"
env = UnityPy.load(*[os.path.join(AA, f) for f in os.listdir(AA) if f.endswith(".bundle")])
WANT = {"TalosHeart_StateControl", "DamageReceiverWithHealth"}
KEYS = ("LifeFor", "maxHealth", "CurrentHealth", "min", "min2", "canreachmin", "DoOtherThingIn0", "ignorehealth", "dmgmulti", "blocking", "lightCanDamageOnBlocking", "internPhase", "BossAlive", "actualPhase", "trackingInfo", "staysDefeated")
for bname, bf in env.files.items():
    for cname, sf in bf.files.items():
        objs = getattr(sf, "objects", None)
        if not objs or len(objs) < 2000: continue
        hit = False
        for pid, o in objs.items():
            if o.type.name != "MonoBehaviour": continue
            try: c = o.read(check_read=False).m_Script.read().m_ClassName
            except Exception: continue
            if c == "TalosHeart_StateControl":
                hit = True
                d = o.read_typetree()
                print("== %s in %s" % (c, cname))
                go = objs[d["m_GameObject"]["m_PathID"]].read_typetree()
                print("   object:", go["m_Name"])
                for k, v in d.items():
                    if any(k.startswith(x) or k == x for x in KEYS):
                        print("   %s = %s" % (k, v))
                # sibling DamageReceiverWithHealth on same GO
                for cc in go["m_Component"]:
                    co = objs.get(cc["component"]["m_PathID"])
                    if co is not None and co.type.name == "MonoBehaviour":
                        try: cn = co.read(check_read=False).m_Script.read().m_ClassName
                        except Exception: continue
                        if cn == "DamageReceiverWithHealth":
                            dd = co.read_typetree()
                            print("   [DamageReceiverWithHealth] CurrentHealth=%s min=%s min2=%s canreachmin=%s DoOtherThingIn0=%s" % (dd.get("CurrentHealth"), dd.get("min"), dd.get("min2"), dd.get("canreachmin"), dd.get("DoOtherThingIn0")))
