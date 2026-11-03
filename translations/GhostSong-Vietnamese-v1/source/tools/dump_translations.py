"""Dump the 'translation*' TextAssets of resources.assets to artifacts/gsvi/translations/ and print heads."""
import os, UnityPy, hashlib
GAME = r"E:\GOGGalaxy\Ghost Song\GhostSong_Data"
OUT = r"E:\002.Github\043.ReverseEngine\artifacts\gsvi\translations"
os.makedirs(OUT, exist_ok=True)
env = UnityPy.load(os.path.join(GAME, "resources.assets"))
for o in env.objects:
    if o.type.name != "TextAsset":
        continue
    d = o.read()
    raw = d.m_Script if isinstance(d.m_Script, (bytes, bytearray)) else d.m_Script.encode("utf-8", "surrogateescape")
    fn = f"{o.path_id}_{d.m_Name.replace(' ', '_')}.txt"
    with open(os.path.join(OUT, fn), "wb") as f:
        f.write(raw)
    head = raw[:160].decode("utf-8", "replace").replace("\n", "\\n").replace("\r", "")
    print(f"{o.path_id} {d.m_Name!r:28} {len(raw):8d} {hashlib.md5(raw).hexdigest()[:8]} {head}")
