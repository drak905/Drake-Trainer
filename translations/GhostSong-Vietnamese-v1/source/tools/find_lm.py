"""Locate LocalizationManager / LanguageStuff MonoBehaviours in the game data (resolves MonoScripts across files)."""
import os, sys, UnityPy
GAME = r"E:\GOGGalaxy\Ghost Song\GhostSong_Data"
WANT = set(sys.argv[1:]) or {"LocalizationManager", "LanguageStuff", "PressButtonLanguageSelector"}
env = UnityPy.load(GAME)
print("files:", list(env.files.keys())[:30])
n = 0
for o in env.objects:
    if o.type.name != "MonoBehaviour":
        continue
    try:
        d = o.read()
        sc = d.m_Script.read()
        nm = sc.m_ClassName
    except Exception as e:
        n += 1
        continue
    if nm in WANT:
        try:
            t = o.read_typetree()
        except Exception as e:
            t = {"err": str(e)}
        print(o.assets_file.name, o.path_id, nm)
        print("   ", {k: v for k, v in t.items() if k not in ("m_GameObject", "m_Script", "m_ObjectHideFlags", "m_CorrespondingSourceObject", "m_PrefabInstance", "m_PrefabAsset")})
print("unresolved:", n)
