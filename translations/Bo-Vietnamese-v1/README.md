# Bō: Path of the Teal Lotus — Vietnamese Language Pack v1.0.0 (Gói Tiếng Việt)

Adds a complete **Vietnamese (Tiếng Việt)** language to the PC version of *Bō: Path of the Teal Lotus*
(Unity 2022.3 Mono, 64-bit). It appears in the game's own language menu next to English, Spanish, French, …

* ~3,100 UI / item / quest / lore / narrator texts and all **1,857 spoken dialogue lines** (2,484 dialogue nodes) are translated,
  including the haiku, loading tips, controls, Omamori, Daruma and character names.
* Vietnamese needs accented letters that the game's fonts do not contain, so the pack ships **Noto Sans** (SIL Open Font
  License) and builds matching text fonts at run time; the game's outline/colour styles are kept.
* **No game file is modified.** The pack is a plugin for [BepInEx 5](https://github.com/BepInEx/BepInEx)
  (5.4.23.3 is bundled and installed only if the game has no BepInEx yet). Uninstalling restores the game exactly.
* Works together with the *Bo Offline Trainer* — they share the same BepInEx.

> Tóm tắt tiếng Việt: giải nén thư mục này ở bất kỳ đâu → **tắt game** → chạy **`Install.bat`** → vào game:
> **Tùy chọn → Lối chơi → Ngôn ngữ → Tiếng Việt**. Gỡ cài đặt: chạy **`Uninstall.bat`**.

## Install (on any computer)

1. Copy and unzip this folder anywhere (for example the Desktop).
2. **Close the game.**
3. Double-click **`Install.bat`**.
   * It finds the game automatically (GOG registry, Steam libraries, common game folders on every drive).
   * If it cannot, it asks you to paste the folder that contains `Bo.exe`. You can also run
     `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\Bo Path of the Teal Lotus"`.
4. Start the game (GOG Galaxy or `Bo.exe`) and choose **Options → Gameplay → Language → Tiếng Việt**
   (in English: *Options → Gameplay → Language*). The choice is remembered by the game.

Installing is safe to repeat. It copies these files into the game folder and lists them in
`BoVietnamese_install_manifest.txt`:

```
BepInEx\plugins\BoVietnamese\BoVietnamese.dll      (the plugin, contains the translation table)
BepInEx\plugins\BoVietnamese\NotoSans-Regular.ttf  (body font)
BepInEx\plugins\BoVietnamese\NotoSans-Bold.ttf     (title font)
BepInEx\plugins\BoVietnamese\NotoSans-OFL.txt      (font license)
+ if the game had no BepInEx: winhttp.dll, doorstop_config.ini, .doorstop_version, BepInEx\core\*.dll
```

## Uninstall / revert

Close the game and run **`Uninstall.bat`** (or `uninstall.ps1 [-GameDir ...] [-Purge]`). It deletes exactly the files listed
in the manifest. BepInEx is removed only if this pack installed it and the Bo trainer is not installed. If Vietnamese was the
selected language the game simply falls back to its default language. Verifying/repairing the game through GOG Galaxy is also
harmless — it never touched the game's own files.

## Requirements and compatibility

* Windows 10/11 x64, PowerShell 5.1+ (built in).
* The PC build with `Bo.exe`, `Bo_Data\` and `MonoBleedingEdge\`. Built and tested on the GOG build `59597633621004325`.
  The plugin hooks by class/method name, so other builds of the same Unity-Mono version normally work. If a hook is not found
  the plugin logs it in `BepInEx\LogOutput.log` (look for "Bo Vietnamese Language Pack") and the rest keeps working.
* Not touched: online services, DRM, anti-cheat. Single-player only.

## What was verified (self test: 17 / 17 PASS)

Run the built-in self test yourself: create an empty file `vi_selftest.flag` in the game folder (or set `TRAINER_SELFTEST=1`),
start the game, wait ~40 s and read `vi_selftest_report.json` (then delete the flag and the report).

* all 8 hooks installed; language registered and switchable; 3,124 text terms translated, 0 fall back to English;
* markup (`<color>`, `<style=…>`, `[var=…]`) preserved; all 7 Vietnamese font assets contain every Vietnamese letter (á à ả ã ạ ă ắ ằ ẳ ẵ ặ â ấ ầ ẩ ẫ ậ đ ê ế ề ể ễ ệ ơ ớ ờ ở ỡ ợ ư ứ ừ ử ữ ự …);
* 1,857 / 1,857 spoken dialogue lines are served in Vietnamese;
* live in the game (screenshots): photosensitivity warning, saving notice, controller recommendation, main menu, options,
  language dropdown (shows "Tiếng Việt"), save-file screen, intro haiku, in-game HUD, pause menu, map, inventory, quests, Daruma pages.

Not individually checked in game: every one of the ~1,860 dialogue lines and every boss/DLC text on screen (they use the same
verified mechanism). If you see an English line or a clipped line, it is a text that the game builds in code or a box that is
too small for Vietnamese — see "Reporting problems".

## Options

`BepInEx\config\com.research.bovietnamese.cfg` (created on first run):

* `SmallerTextLikeOtherEuropeanLanguages` (default `true`) — Vietnamese is longer than English, so it uses the game's
  "smaller text" rules that Spanish / French / German already use. Set to `false` to keep the English sizes.

## Reporting problems / improving the translation

* Everything is data: `source\translations_en_vi.json` maps each English string to the Vietnamese text; `source\TRANSLATION_GUIDE.md`
  has the glossary and rules (Hồ Hỏa = Fox Fire, Hoa Sen Xanh Ngọc = Teal Lotus, …).
  Edit the JSON, regenerate `vi.tsv` with `tools\merge.py` from the project, rebuild with `build.ps1` — or send the corrected lines.
* A line still in English usually means it is a hard-coded string or a texture/image (the game logo, some sign art).
* Log file: `BepInEx\LogOutput.log`.

## Credits and license

* Translation: LLM-assisted EN→VI localisation with a fixed glossary, then automatically validated (every tag/placeholder identical
  to the English).
* Font: **Noto Sans** © The Noto Project Authors, SIL Open Font License 1.1 (`NotoSans-OFL.txt`).
* BepInEx (LGPL-2.1), HarmonyX / MonoMod (MIT) are bundled unmodified. *Bō: Path of the Teal Lotus* belongs to Squid Shock Studios;
  this is an unofficial fan localisation without any game assets.
