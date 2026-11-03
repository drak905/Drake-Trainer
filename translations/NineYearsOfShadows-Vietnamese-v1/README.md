# 9 Years of Shadows — Vietnamese Language Pack v1.0.0 (Gói Tiếng Việt)

Adds a complete **Vietnamese (Tiếng Việt)** language to the PC version of *9 Years of Shadows* (Halberd Studios, GOG build v1.0.41,
Unity 2022.3 Mono, Windows x64). It appears in the game's own language selector next to English, Spanish, French, …

* **839 UI texts** (menus, settings, credits, tutorials, quests, bestiary, map, geode lore, prologue/epilogue, thought bubbles, control
  remapping) and **all 1,488 spoken dialogue lines** (27 conversations: bosses, mid-bosses, NPCs, story scenes) are translated.
* The game's Jost font has no Vietnamese letters (ơ, ư, ạ, ế, ợ …). While Vietnamese is selected the pack switches the game's text fonts
  to **Noto Sans** (SIL Open Font License) with the game's own outline/colour styles, and switches back for every other language.
* **No game file is modified.** It is a plugin for [BepInEx 5](https://github.com/BepInEx/BepInEx) (5.4.23.3 is bundled and installed
  only if the game has no BepInEx yet). Uninstalling removes exactly what was installed.
* Works together with the *9 Years of Shadows Offline Trainer* — they share the same BepInEx.

> Tóm tắt tiếng Việt: giải nén thư mục này ở bất kỳ đâu → **tắt game** → chạy **`Install.bat`** → vào game:
> **OPTIONS → GAME → LANGUAGE → Tiếng Việt** (bấm mũi tên trái/phải rồi di chuyển xuống dòng khác để xác nhận).
> Gỡ cài đặt: chuyển ngôn ngữ về English trước, rồi chạy **`Uninstall.bat`**.

## Install (on any computer that has the game)

1. Copy and unzip this folder anywhere (for example the Desktop).
2. **Close the game.**
3. Double-click **`Install.bat`**.
   * It finds the game automatically (GOG registry, Steam libraries, common game folders on every drive).
   * If it cannot, it asks you to paste the folder that contains `9 Years of Shadows.exe`. You can also run
     `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\9 Years of Shadows"`.
4. Start the game (GOG Galaxy or `9 Years of Shadows.exe`).
5. In the title menu choose **OPTIONS → GAME → LANGUAGE**, press the **left/right arrow** until **Tiếng Việt** is shown (it is the last
   entry, after the other languages), then move to another row (↓) to confirm. The whole game switches immediately, and the choice is
   remembered by the game. Once Vietnamese is selected the menus are in Vietnamese: **TÙY CHỌN → TRÒ CHƠI → NGÔN NGỮ**.

Installing is safe to repeat. It copies these files into the game folder and lists them in `NysVietnamese_install_manifest.txt`:

```
BepInEx\plugins\NysVietnamese\NysVietnamese.dll     (the plugin; contains the translation tables)
BepInEx\plugins\NysVietnamese\NotoSans-Regular.ttf  (body font)
BepInEx\plugins\NysVietnamese\NotoSans-Bold.ttf     (title / bold font)
BepInEx\plugins\NysVietnamese\NotoSans-OFL.txt      (font license)
+ only if the game had no BepInEx: winhttp.dll, doorstop_config.ini, .doorstop_version, BepInEx\core\*.dll
```

## Uninstall / revert

1. Start the game and set **Language** back to **English** (or any original language). *Important:* if the game stays set to Vietnamese
   while the plugin is gone, the game has no Vietnamese dialogue to load. Fix: reinstall the pack, switch to English, uninstall again.
2. Close the game and run **`Uninstall.bat`** (or `uninstall.ps1 [-GameDir ...] [-Purge]`). It deletes exactly the files listed in the
   manifest. BepInEx is removed only if this pack installed it and the trainer is not installed. Verifying/repairing the game through
   GOG Galaxy is also harmless — the pack never touched the game's own files.

## Requirements and compatibility

* Windows 10/11 x64, PowerShell 5.1+ (built in). No admin rights, no .NET SDK needed.
* The PC build with `9 Years of Shadows.exe`, `9 Years of Shadows_Data\` and `MonoBleedingEdge\`. Built and tested on the GOG build
  v1.0.41 (`goggame-2099051765`). The plugin hooks by class/method name, so other builds of the same Unity-Mono version normally work.
  If a hook is not found it is logged in `BepInEx\LogOutput.log` (search for "Vietnamese Language Pack").
* Single-player only. Nothing online, no DRM or anti-cheat is touched.

## What was verified (self test: 17 / 17 PASS)

Run the built-in self test yourself: create an empty file `nys_vi_selftest.flag` in the game folder (or set the environment variable
`TRAINER_SELFTEST=1`), start the game, wait ~40 s and read `nys_vi_selftest_report.json` (then delete the flag and the report).

* all 6 hooks installed (string library, dialogue library, language setter, 3 on the language selector);
* 839 / 839 UI tags served in Vietnamese, `{{0}}`-style placeholders and `<b>` tags preserved;
* 27 / 27 dialogue programs rebuilt in Vietnamese, 0 untranslated lines, no line contains a second `:` (the game cuts such lines);
* all 10 Jost font assets can draw every Vietnamese letter (á à ả ã ạ ă ắ ằ ẳ ẵ ặ â ấ ầ ẩ ẫ ậ đ ê ế ề ể ễ ệ ơ ớ ờ ở ỡ ợ ư ứ ừ ử ữ ự …)
  with Noto Sans, and switching back to another language restores the original Jost fonts (10 / 10);
* live in the game (screenshots): title menu, data-select screen, pause menu, map + quest list, game settings, language selector
  (shows "Tiếng Việt"), prologue text, and an in-game dialogue box (speaker name, portrait, text) with correct accents.

Not individually checked in game: every one of the 1,488 dialogue lines and every tutorial/bestiary card on screen (they use the same
verified mechanism). Vietnamese is longer than English, so a few boxes may look tight; a text that is a picture (title logo, some
art) cannot be translated by a plugin and stays English.

## Reporting problems / improving the translation

Everything is data, in the `source` folder:

* `work\ui_src.tsv` / `work\ui_vi_*.tsv` — UI texts (id, tag, English) and their Vietnamese;
* `work\dlg_src.tsv` / `work\dlg_vi_*.tsv` — dialogue lines (`Speaker:Text`; the game shows only the text before the **second** colon, so
  never use `:` inside a Vietnamese line);
* edit the `*_vi_*.tsv` files, run `python validate.py ui` and `python validate.py dlg` (checks placeholders / tags / speakers),
  then `python build_data.py` (writes `data\ui.tsv`, `data\dlg.tsv`) and rebuild the DLL with `build.ps1`
  (`.\build.ps1 -Src src\NysVietnamese.cs -Name NysVietnamese -Resource "data\ui.tsv,ui.tsv;data\dlg.tsv,dlg.tsv"`; needs only the
  .NET Framework `csc.exe` that ships with Windows and the game's `Managed` folder). Copy the new `NysVietnamese.dll` into
  `BepInEx\plugins\NysVietnamese\`.
* Names kept in the original form: Europa, Apino, Talos, Belial, Draythus, Auriel, Hibino, Michiru, Kahori … Glossary used: *Ân Huệ* =
  Grace, *Giáp* = Armor, *thanh ánh sáng* = light bar, *Đòn Lốc Xoáy* = Whirlwind Strike, *Mảnh Vỡ Cổ Đại* = Ancient Fragment,
  *thánh vật* = relic, *Sổ Quái Vật* = Bestiary.
* Log file for bug reports: `BepInEx\LogOutput.log`.

## How it works (for modders)

The game keeps each UI text in a ScriptableObject `LocalizedStringLibrary` (tag → one text per `ConstantsManager.Localization.Language`
value, 1 = English … 8 = German) and each conversation in per-language Yarn programs (`DialogueFileLibrary`). The plugin defines the
new language value **9**:

| Hook (Harmony) | Purpose |
|---|---|
| `LocalizedStringLibrary.GetLocalizedStringFromTag(tag, 9)` (postfix) | returns the embedded Vietnamese text for the tag |
| `DialogueFileLibrary.GetLocalizedDialogueFileFromTag(tag, 9)` (postfix) | clones the English `YarnProgram`, replaces its string table with the Vietnamese lines (matched by a hash of the English line) |
| `SpinnerBase.Awake/UpdateSetting/Move` (language spinner) | appends the "Tiếng Việt" entry (saving value 9) |
| `SettingsObject.CurrentLanguage` setter (prefix) | switches the Jost font assets to Noto Sans (or back) before the game refreshes its texts |

The language value is stored by the game like any other, so it is remembered between sessions.

## Credits and license

* Translation: LLM-assisted EN→VI localisation with a fixed glossary, then automatically validated (every tag/placeholder identical to
  the English, speaker names preserved, no stray colons).
* Font: **Noto Sans** © The Noto Project Authors, SIL Open Font License 1.1 (`NotoSans-OFL.txt`).
* BepInEx (LGPL-2.1), HarmonyX / MonoMod (MIT) are bundled unmodified. *9 Years of Shadows* belongs to Halberd Studios; this is an
  unofficial fan localisation that contains no game assets.
