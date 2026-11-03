# Guacamelee! Super Turbo Championship Edition — Vietnamese language patch v1.0

Adds **Tiếng Việt** as a 7th language to Guacamelee! STCE (menus, dialogue, tutorials, achievements, loading screen,
Move List …). The patch was produced by reverse engineering the game: its archive format (`misc.dat`), its
pre-rendered bitmap fonts (which only contain Latin-1 and therefore cannot show Vietnamese letters) and the language
list code in `Game.exe`.

* **Languages are kept** — English, Français, Italiano, Deutsch, Español and Português still work; Vietnamese is added to
  *Options → Language*.
* **No game assets are redistributed** — the package only contains binary *difference* files (xdelta) that turn *your
  own* `Game.exe` / `misc.dat` into the patched ones. They only apply to the exact build listed below.
* Works together with the *Guacamelee! STCE Trainer v1* (`dinput8.dll`) — that one is not touched.
* Single-player / local co-op only. No anti-cheat exists in this game and nothing here touches online features.

---------------------------------------------------------------------------------------------------

## 1. What you need

| Item | Value |
|------|-------|
| Game | Guacamelee! Super Turbo Championship Edition, **Epic Games Store build `GuacSTCE_29-06-2023_16-43-23+66`** (32-bit) |
| `Game.exe` | 5,607,424 bytes — SHA-256 `DE6CEC52F06B8E0FC835356B31AB80891BC4BA6431823B0EEF6FC02C480209F2` |
| `misc.dat` | 10,091,546 bytes — SHA-256 `B52125AB0FBFF97F7FA7E05C41E2B09F8ECDBA26F33C94D39ED11C29F9FD658C` |
| OS | Windows 10 / 11 with the built-in PowerShell 5 (nothing to install) |

If your files have a different hash (a Steam/GOG build, a newer update, a previously modified file) the installer
stops **before changing anything** and tells you which file does not match. Use Epic's *Verify* to get the original
files back, then run the installer again.

---------------------------------------------------------------------------------------------------

## 2. Install (on any PC)

1. Install the game normally (Epic Games Launcher) and start it once so that it is complete. Close it.
2. Unzip this folder anywhere (extract **everything**, the installer needs the `payload` and `tools` folders).
3. Double-click **`Install.bat`**.
   * It finds the game by itself (Epic launcher manifests, Steam libraries, common folders on every drive).
   * If it cannot find it, it asks for the folder that contains `Game.exe`. You can also run
     `Install.bat -GameDir "D:\Games\GuacameleeSTCE"`.
   * It copies the two original files to `<game folder>\VietnamesePatch_backup`, builds the new ones in temporary
     files, verifies their SHA-256 and only then replaces the game files. Re-running it is harmless.
4. Start the game.

**Manual install** (no PowerShell): `tools\xdelta3.exe -d -s <original Game.exe> payload\Game.exe.xdelta <new Game.exe>`
and the same for `misc.dat`, then copy the two results into the game folder (keep the originals!).

---------------------------------------------------------------------------------------------------

## 3. Using it

1. In the game choose **Options → Language** and press **→** (right) until it shows **Tiếng Việt**
   (it is the last entry, after *Português*).
2. Leave the Options screen (**Esc** or the *OK* button) and answer **Yes / Có** to keep the change.
3. The menus, the pause menu, the Move List, dialogue boxes, tutorials, achievements and the loading screen
   ("ĐANG TẢI…") now appear in Vietnamese. The setting is stored by the game like any other language.

Notes

* The game maps the Windows display language to a game language when no language has been chosen yet; Vietnamese
  Windows is mapped to Tiếng Việt (not tested on a Vietnamese Windows).
* Console command (`SetLanguage Vietnamese`) and the language files use the name **Vietnamese**.
* Switching languages works while playing: *Pause → Options → Language*.

---------------------------------------------------------------------------------------------------

## 4. What was translated / what was not

Translated (about 2,200 unique strings, ~25,000 words): every menu and option, controller/keyboard screens, pause menu,
Move List, shop / upgrades, all NPC dialogue and cutscenes, side quests, tutorials and hints, achievements
(Thành tựu) and trophies, level names, system messages, credits text, the Pollo / costume texts and the loading bar.

Not translated (these are baked into pictures, not text):

* The game logo and the *Super Turbo Championship Edition* banner, the "Press …" artwork on the title screen,
  some textures in the levels (shop signs, posters) and the intro splash screens.
* Characters' and places' names such as Juan, Tostada, Calaca, Xtabay, Santa Luchita, Pueblucho, Uay Chivo, El Presidente,
  El Trio de la Muerte, and the words *luchador*, *esqueleto*, *Intenso*, *Pollo* are intentionally kept (see
  `source\data\TRANSLATION_GUIDE.md`).

Fonts: the game ships its fonts as pre-rendered bitmaps with Latin-1 only. The patch adds all Vietnamese letters
(Ă Â Đ Ê Ô Ơ Ư and every tone-marked vowel, 100+ glyphs) to the 17 bitmap fonts of the game. The new letters are composed
from the game's own glyphs so they match each font; in the decorative `Aldo the Apache` font (only used for a few big
captions) the marks are simpler.

If you find a mistranslation or a line that does not fit in a box, the text is in `source\data\chunks\*.out.json`
(or `translations_en_vi.json`); rebuild instructions are in `source\README_SOURCE.md`.

---------------------------------------------------------------------------------------------------

## 5. Uninstall

Close the game and double-click **`Uninstall.bat`**. It puts the original `Game.exe` and `misc.dat` back from
`VietnamesePatch_backup` (or, if that folder was deleted, rebuilds them from the patched files with the reverse deltas in
`payload`), verifies them and removes the backup. Your saves are never touched. Epic's *Verify / Repair* does the same.

If you uninstall while the game is still set to Tiếng Việt, the original game simply falls back to its default
language (you may see a warning in its log, nothing else).

---------------------------------------------------------------------------------------------------

## 6. Troubleshooting

| Problem | Fix |
|---------|-----|
| "is not the build this patch was made for" | Your `Game.exe` / `misc.dat` differ from the tested Epic build. Run Epic *Verify*; Steam / GOG builds are not supported by this version. |
| "Close the game first" | Quit the game (check Task Manager for `Game.exe`) and run the installer again. |
| The Language list has no *Tiếng Việt* | The patch is not installed (or Epic repaired the files after an update). Run `Install.bat` again. After a game update the patch may stop matching — wait for a new version of the patch. |
| Epic says the game files are corrupted / re-downloads | That is Epic's integrity check noticing the patched files. Re-run `Install.bat` afterwards. |
| A word shows as `<Bad String>` or `<No Translation>` | Report the line; it means a key is missing in the Vietnamese column. |
| PowerShell says scripts are disabled | Use `Install.bat` (it starts PowerShell with `-ExecutionPolicy Bypass` for this script only). |
| Antivirus flags `tools\xdelta3.exe` | It is the unmodified open-source xdelta3 3.2.2 binary (Apache-2.0); you may use your own copy instead. |

---------------------------------------------------------------------------------------------------

## 7. Hashes (for verification)

| File | SHA-256 |
|------|---------|
| original `Game.exe` | `DE6CEC52F06B8E0FC835356B31AB80891BC4BA6431823B0EEF6FC02C480209F2` |
| patched  `Game.exe` | `70FC09A0CA9BCA527A06246550514E75E818A741EDC4FAAF35A42405E39D9818` |
| original `misc.dat` | `B52125AB0FBFF97F7FA7E05C41E2B09F8ECDBA26F33C94D39ED11C29F9FD658C` |
| patched  `misc.dat` | `5362DB2EA62F26A83D9B59A5B9523D4D0A4A22D859E356A0FE24A064E042F84B` |

`SHA256SUMS.txt` lists the hashes of every file in this package.

---------------------------------------------------------------------------------------------------

## 8. Technical summary (for modders)

* `misc.dat` / `levels.dat` / `resources.dat` are `ARCV` archives: a header stream (CRC32-style checksum with polynomial
  `0x827B12AD`, 3-bit mode + size, 64 KB raw-deflate segments) lists the files; every file is such a stream itself.
* Language files are UTF-16 TSV (`misc\lang*.txt`), the column header names select the language
  (`English … Portuguese, ChineseSimplified, Japanese, Russian`). The engine has 11 language slots but only 6 enabled
  by `misc\platformRegionInfo.ini`; slot 6 (formerly "Japanese", which had no text and no font) became **Vietnamese**.
* Fonts are `GFONT` v2 files (kerning pairs, an 8-bit alpha atlas and one record per code point).
* `Game.exe` gets a new section `.viet` (a table, two strings and a 40-byte code cave) and five small edits: the
  language list builder (`FUN_00753c30`) appends the 7th entry, the two list-index→language tables, the two language-name
  pointer tables (narrow table for commands, wide table for the language-file header) and the Windows-LANGID table.
* Rebuild everything from the vanilla files: see `source\README_SOURCE.md`.

Made with the multi-agent reverse-engineering workflow (static analysis with Ghidra + live verification in the running
game). Not affiliated with DrinkBox Studios. Guacamelee! is © DrinkBox Studios.
