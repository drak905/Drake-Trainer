"""Offline extractor: world positions + tracking ids of collectible things in every Map_Area_* scene.

Usage: python extract_items.py [--dump]   (writes tools/nys/items_dump.json)
Reads the Addressables scene bundles with UnityPy (read-only; nothing in the game folder is modified).
"""
import os, sys, json, math, collections
import UnityPy

UnityPy.config.FALLBACK_UNITY_VERSION = "2022.3.28f1"
D = r"E:\GOGGalaxy\9 Years of Shadows\9 Years of Shadows_Data"
AA = D + r"\StreamingAssets\aa\StandaloneWindows64"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "items_dump.json")

WANT = {"ItemHolder", "Collectable", "PlayerControllerUpdates", "Cornucopia", "CollectArmor", "LoreObject", "MapMarkerGiver", "UnlockMapArea"}


def load_env():
    paths = [os.path.join(AA, f) for f in os.listdir(AA) if f.endswith(".bundle")]
    return UnityPy.load(*paths)


def quat_mul_vec(q, v):
    x, y, z, w = q
    # v' = q * v * q^-1
    vx, vy, vz = v
    tx = 2 * (y * vz - z * vy)
    ty = 2 * (z * vx - x * vz)
    tz = 2 * (x * vy - y * vx)
    return (vx + w * tx + (y * tz - z * ty), vy + w * ty + (z * tx - x * tz), vz + w * tz + (x * ty - y * tx))


def main():
    env = load_env()
    print("bundles loaded:", len(env.files))
    # scene serialized files = CABs that contain many GameObjects and a LDtkComponentProject
    results = {}
    for bname, bf in env.files.items():
        for cname, sf in bf.files.items():
            objs = getattr(sf, "objects", None)
            if not objs or len(objs) < 2000:
                continue
            # detect scene by presence of MapAreaManager / CastleVaniaRig MonoBehaviours
            classes = collections.Counter()
            mbs = []
            for o in objs.values():
                if o.type.name == "MonoBehaviour":
                    try:
                        mb = o.read(check_read=False)
                        cn = mb.m_Script.read().m_ClassName
                    except Exception:
                        continue
                    classes[cn] += 1
                    mbs.append((o, mb, cn))
            if "CastleVaniaRig" not in classes:
                continue
            area = None
            for o, mb, cn in mbs:
                if cn == "MapAreaManager":
                    try:
                        area = o.read_typetree().get("area")
                    except Exception:
                        pass
            print(cname, "objects", len(objs), "area enum", area, "ItemHolder", classes.get("ItemHolder"), "Collectable", classes.get("Collectable"))
            # transforms
            tcache = {}

            def get_t(pid):
                if pid in tcache:
                    return tcache[pid]
                o = objs.get(pid)
                if o is None:
                    return None
                tt = o.read_typetree()
                tcache[pid] = tt
                return tt

            def world(pid, depth=0):
                tt = get_t(pid)
                if tt is None or depth > 80:
                    return (0.0, 0.0, 0.0), (0, 0, 0, 1), (1.0, 1.0, 1.0)
                lp = tt["m_LocalPosition"]; lr = tt["m_LocalRotation"]; ls = tt["m_LocalScale"]
                father = tt["m_Father"]["m_PathID"]
                p = (lp["x"], lp["y"], lp["z"]); r = (lr["x"], lr["y"], lr["z"], lr["w"]); s = (ls["x"], ls["y"], ls["z"])
                if father == 0:
                    return p, r, s
                pp, pr, ps = world(father, depth + 1)
                sp = (p[0] * ps[0], p[1] * ps[1], p[2] * ps[2])
                rp = quat_mul_vec(pr, sp)
                wp = (pp[0] + rp[0], pp[1] + rp[1], pp[2] + rp[2])
                # compose rotation
                ax, ay, az, aw = pr; bx, by, bz, bw = r
                wr = (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx, aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)
                ws = (ps[0] * s[0], ps[1] * s[1], ps[2] * s[2])
                return wp, wr, ws

            def go_info(go_pid):
                go = objs.get(go_pid)
                if go is None:
                    return None
                g = go.read_typetree()
                t_pid = None
                for c in g["m_Component"]:
                    cp = c["component"]["m_PathID"]
                    co = objs.get(cp)
                    if co is not None and co.type.name in ("Transform", "RectTransform"):
                        t_pid = cp
                        break
                return g, t_pid

            def path_of(t_pid):
                names = []
                cur = t_pid; guard = 0
                while cur and guard < 60:
                    tt = get_t(cur)
                    if tt is None:
                        break
                    gi = go_info(tt["m_GameObject"]["m_PathID"])
                    if gi:
                        names.append(gi[0]["m_Name"])
                    cur = tt["m_Father"]["m_PathID"]
                    guard += 1
                return "/".join(reversed(names))

            items = []
            for o, mb, cn in mbs:
                if cn not in WANT:
                    continue
                try:
                    data = o.read_typetree()
                except Exception as e:
                    print("typetree fail", cn, str(e)[:80]); continue
                gpid = data["m_GameObject"]["m_PathID"]
                gi = go_info(gpid)
                if not gi:
                    continue
                g, tpid = gi
                if tpid is None:
                    continue
                wp, wr, ws = world(tpid)
                rec = {
                    "kind": cn,
                    "name": g["m_Name"],
                    "path": path_of(tpid),
                    "active": bool(g.get("m_IsActive", 1)),
                    "x": round(wp[0], 3), "y": round(wp[1], 3),
                }
                ti = data.get("trackingInfo")
                if ti:
                    rec["track_id"] = ti.get("id"); rec["track_type"] = ti.get("objectType")
                for k in ("collectableType", "collectableAddAmount", "staysDefeated", "maxCoinNbr", "myArmor", "currencyType", "value"):
                    if k in data:
                        rec[k] = data[k]
                items.append(rec)
            results[cname] = {"area_enum": area, "count": len(items), "items": items}
    json.dump(results, open(OUT, "w", encoding="utf-8"), indent=1)
    print("wrote", OUT)
    for cname, r in results.items():
        c = collections.Counter(i["kind"] for i in r["items"])
        print(cname, r["area_enum"], dict(c))


if __name__ == "__main__":
    main()

