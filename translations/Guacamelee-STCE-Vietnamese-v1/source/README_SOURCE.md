# Rebuilding the Vietnamese patch from the vanilla game files

Requires Python 3.10+ with `pillow` and `numpy` (`pip install pillow numpy pefile`). Everything is deterministic: running
the steps below on the original files gives byte-identical `misc.dat` / `Game.exe` to the ones the installer produces.

```
cd source\py
# 1) Vietnamese misc.dat (text, fonts, loading bar)  --  input: the ORIGINAL misc.dat (keep a copy!)
python make_loadbar.py  "D:\Game\misc.dat"  ..\data\Load_bar_vi.dds
python build_vi.py      "D:\Game\misc.dat"  misc.vi.dat            # uses ..\data\chunks, ..\data\overrides.json
# 2) Game.exe with the 7th language entry
python patch_exe.py     "D:\Game\Game.exe"  Game.vi.exe
```

Other tools

* `extract.py <archive.dat> <out dir>` — unpack any `ARCV` archive (`misc.dat`, `levels.dat`, `resources.dat`).
* `arc.py` — reader / writer for the archive format and its stream compression. `gfont.py` — `.fn` bitmap font reader/writer.
* `fontgen.py` — composes the Vietnamese glyphs. `langio.py` — language-file parser matching the engine's own parser.

Translation data (`..\data`)

* `chunks\_index.json` : id → English string; `chunks\chunk_NN.out.json` : id → Vietnamese.
* `overrides.json` (made by `make_keyeq.py`): UI strings whose key equals the English text, plus a few fixes.
* `translations_en_vi.json`: the final English → Vietnamese table used by the build (after terminology fixes).
* `TRANSLATION_GUIDE.md`: style rules and glossary used by the translators.

To fix a line: edit it in the matching `chunk_NN.out.json` (or `overrides.json`), keep every `{TOKEN}`, `%d` and the `\p` / `\n`
escape sequences, rebuild `misc.dat`, then create a delta with `xdelta3 -e -9 -s original new out.xdelta` if you want to
redistribute it.
