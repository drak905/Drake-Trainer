"""List ResourceManager container (Resources paths) from globalgamemanagers."""
import os, UnityPy
GAME = r"E:\GOGGalaxy\Ghost Song\GhostSong_Data"
env = UnityPy.load(os.path.join(GAME, "globalgamemanagers"), os.path.join(GAME, "resources.assets"))
for o in env.objects:
    if o.type.name == "ResourceManager":
        t = o.read_typetree()
        for name, ptr in t["m_Container"]:
            print(name, ptr["m_FileID"], ptr["m_PathID"])
