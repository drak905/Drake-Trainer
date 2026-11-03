"""Inspect Font assets: names, fallback chain, Vietnamese coverage (fontTools)."""
import os, io, sys, UnityPy
from fontTools.ttLib import TTFont
GAME = r"E:\GOGGalaxy\Ghost Song\GhostSong_Data"
VI = "ăâđêôơưĂÂĐÊÔƠƯáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ"
env = UnityPy.load(os.path.join(GAME, "sharedassets0.assets"))
for o in env.objects:
    if o.type.name != "Font":
        continue
    d = o.read()
    t = o.read_typetree()
    data = bytes(d.m_FontData or b"")
    cov = "n/a"
    if data:
        try:
            f = TTFont(io.BytesIO(data), fontNumber=0)
            cm = f.getBestCmap()
            miss = [c for c in VI if ord(c) not in cm]
            cov = "VI-missing=%d/%d %s" % (len(miss), len(VI), "".join(miss[:20]))
        except Exception as e:
            cov = "err %s" % e
    print(o.path_id, d.m_Name, len(data), cov)
    print("    fallbacks:", t.get("m_FallbackFonts"), "names:", t.get("m_FontNames"), "size:", t.get("m_FontSize"), "render:", t.get("m_DefaultMaterial"))
