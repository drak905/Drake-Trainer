"""Scan Ghost Song asset files for localization-related objects (TextAsset / Font / MonoBehaviour)."""
import sys, os, collections
import UnityPy

GAME = r"E:\GOGGalaxy\Ghost Song\GhostSong_Data"
files = sys.argv[1:] or ["resources.assets", "globalgamemanagers.assets", "sharedassets0.assets", "sharedassets1.assets"]
for fn in files:
    p = os.path.join(GAME, fn)
    print("=====", fn, os.path.getsize(p))
    env = UnityPy.load(p)
    cnt = collections.Counter()
    for o in env.objects:
        cnt[o.type.name] += 1
    print(dict(cnt))
    for o in env.objects:
        if o.type.name in ("TextAsset", "Font"):
            try:
                d = o.read()
                n = getattr(d, "m_Name", "?")
                sz = len(getattr(d, "m_Script", b"") or b"") if o.type.name == "TextAsset" else len(getattr(d, "m_FontData", b"") or b"")
                print(f"  {o.type.name:10s} pid={o.path_id:<8d} size={sz:<9d} {n}")
            except Exception as e:
                print("  ERR", o.type.name, o.path_id, e)
