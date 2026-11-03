# Ghost Song — Vietnamese Language Pack v1.0.0 (Gói Tiếng Việt)

Adds a complete **Vietnamese (Tiếng Việt)** language to the PC version of *Ghost Song* (Old Moon, build **1.2.12b**, Unity 2020.3.36 IL2CPP,
Windows x64; tested on the GOG build). It shows up in the game's own language selector, after Korean.

* **569 UI texts** (menus, settings, save slots, difficulty, map, journal, tutorials, credits …) and **5,261 dialogue / text entries**
  (all story, NPC, boss and item text) are translated.
* **No game file is modified.** The pack is a `winmm.dll` proxy that loads together with the game, forwards every `winmm` function to the
  real Windows DLL and patches the game in memory only. Uninstalling removes exactly what was installed.
* Works together with the *Ghost Song Offline Trainer* (it uses `version.dll`, this pack uses `winmm.dll`).
* No extra font needed: the game's fallback fonts (Noto Sans / Noto Sans JP) already contain all Vietnamese letters.

> Tóm tắt tiếng Việt: giải nén thư mục này ở bất kỳ đâu → **tắt game** → chạy **`Install.bat`** → vào game:
> **Settings (Cài đặt) → Game → Language**, bấm mũi tên phải cho tới khi hiện **Tiếng Việt** (nằm sau Korean, trước Auto).
> Gỡ cài đặt: chạy **`Uninstall.bat`**.

## Install (on any computer that has the game)

1. Copy and unzip this folder anywhere (for example the Desktop).
2. **Close the game.**
3. Double-click **`Install.bat`**.
   * It finds the game automatically (GOG registry, Steam libraries, common game folders on every drive).
   * If it cannot, it asks for the folder that contains `GhostSong.exe`. You can also run
     `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\Ghost Song"`.
4. Start the game (GOG Galaxy or `GhostSong.exe`).
5. Open **Settings → Game**, select the **Language** row and press the **right arrow** until **Tiếng Việt** appears (the entry after Korean;
   the next press goes back to *Auto*). The whole game switches immediately, and the choice is remembered by the game
   (after that the title menu reads *Chơi Game / Cài đặt / Đội Ngũ Làm Game / Thoát*).

Installing is safe to repeat. These files are copied into the game folder and listed in `GhostSongVietnamese_install_manifest.txt`:

```
winmm.dll                          (proxy + patcher; an existing foreign winmm.dll is saved as winmm.dll.pre-vi)
GhostSongVietnamese\vi_dlg.tsv     (dialogue translation)
GhostSongVietnamese\vi_ui.tsv      (UI translation)
```

## Uninstall / revert

Close the game and run **`Uninstall.bat`** (or `uninstall.ps1 [-GameDir ...]`). It deletes exactly the manifest files and restores a
previous `winmm.dll` if there was one. Optionally set the language back to English/Auto first. Verifying the game through GOG Galaxy / Steam
is harmless — no original file was changed.

## Important notes

* **It takes over the game's unused 9th language slot, which is Portuguese** (the game ships Portuguese data but its settings menu stops at
  Korean, so Portuguese cannot be chosen normally). While the pack is installed, a PC whose system language is Portuguese with the game on
  *Auto* will therefore show Vietnamese. Uninstall the pack to restore the old behaviour.
* Vietnamese is longer than English, so a few boxes may look tight. Text that is an image (logo, some art) stays English.
* The game must be the tested build: `GameAssembly.dll` SHA-256
  `43A0C1218FFD9B30487EC4FA96ADF8F896E8313CE7EC868671CE1085AFD66246`. On another build the installer warns; the pack checks the code
  bytes of every hook/patch and **skips** any that do not match instead of crashing, so the worst case is "no Vietnamese option".
* Antivirus tools sometimes flag any `winmm.dll` proxy ("DLL hijack" heuristics). It is a false positive; the full C source is in
  `source\src`. Add the game folder to the exclusions if needed.
* A `winmm.dll` from another mod cannot be used at the same time (it is backed up and restored on uninstall).
* Single-player only; nothing online, no DRM or anti-cheat is touched.

## Troubleshooting

* Log: `gs_vi.log` in the game folder. A healthy start ends with
  `installed: hooks 2/2, menu patches 2/2` and `Vietnamese UI applied: 569 fields set, 0 missing`.
* No *Tiếng Việt* in the menu → `menu patches 0/2` in the log (different game build).
* Environment variables for diagnosis: `GSVI_DISABLE=1` turns the pack off completely; `GSVI_STAGE=0` installs nothing, `1` hooks only
  (no menu patch), `2` everything (default).
* Self test: create an empty file `vi_selftest.flag` in the game folder, start the game, wait ~30 s and read `vi_selftest_report.json`
  (`PASS_READY_FOR_HUMAN` is expected); delete the flag and the report afterwards.

## How it works (for modders)

* Dialogue lives in `resources.assets` as TextAssets `*_translation` (columns per language). `LocalizationData.GetValueByCode`
  (`GameAssembly+0x1183B10`) is hooked: when `LocalizationData.language == 28` (the dormant Portuguese `SystemLanguage`) and the column is
  `CONTENT`, the text from `vi_dlg.tsv` is returned.
* UI text is set by the big `switch` in `UItexty.processlanguage` (`+0x11F8ED0`, case 8 = Portuguese). The hook runs the original and then
  overwrites the public string fields by name from `vi_ui.tsv`.
* The settings language row is capped at 7 (Korean). Two 1-byte patches (`+0x11ECA77` and `+0x11EC9DC`, `07 → 08`) allow index 8.
* The `source` folder contains the C source (`src`), `build.py` (needs Python + `ziglang` + MinHook), the translation data (`data`), the
  translation guide and the analysis/translation scripts (`tools`). Edit the `.tsv` files (`key<TAB>text`, keep `{0}`-style placeholders and
  tags), validate with `tools\validate_vi.py`, and copy them over the files in `GhostSongVietnamese\`. No rebuild is needed for text changes.

## Credits and license

* Translation: LLM-assisted EN→VI localisation with a fixed glossary and automatic validation (placeholders, tags, speaker names).
* Hooking: [MinHook](https://github.com/TsudaKageyu/minhook) (BSD-2-Clause), statically linked.
* *Ghost Song* belongs to Old Moon. This is an unofficial fan localisation that contains no game assets.
