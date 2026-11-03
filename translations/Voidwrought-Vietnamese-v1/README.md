# Voidwrought — Vietnamese Language Pack (Tiếng Việt) v1.0.0

Adds **Vietnamese** as a 12th language to **Voidwrought** (Powersnake / Kwalee; PC build, Unity 2021.3 **Mono**, Windows x64).
All 1,802 distinct game texts are translated: menus, settings, HUD, tutorials, dialogue, lore stones, journal entries, compendium,
achievements, relics/items, credits and the EULA screen.

It is a BepInEx 5 plugin (Harmony). **No game file is modified** — `Assembly-CSharp.dll`, the Addressables bundles and your saves stay
untouched, so Epic's "Verify" will not undo it, and one script removes it again.

## What is inside

| Part | What it does |
|---|---|
| `VwVietnamese.dll` | Adds the language "Vietnamese" (code `vi`) to the game's I2 Localization source at start-up and fills every text term. The translation table is embedded in the DLL and keyed by the English text, so it survives key renames in game updates (new/changed texts simply stay in English). |
| Noto Sans TTFs (Regular, Bold, Italic, BoldItalic) | The game's own fonts lack the stacked Vietnamese vowels (ả ạ ằ ắ ẳ … ỵ). While Vietnamese is selected the plugin builds dynamic TextMeshPro fallback fonts from these files (SIL OFL licence, see `NotoSans-OFL.txt`). Other languages are unaffected. |
| BepInEx 5.4.23.3 | Mod loader. Installed only if the game does not have it yet (e.g. from the Voidwrought trainer). |

## Install (any PC that has the game)

1. Unzip `Voidwrought-Vietnamese-v1.zip` anywhere and **close the game**.
2. Double-click **`Install.bat`**. It finds the game automatically (Epic Games Launcher manifest, Steam libraries, common folders on every drive); if it cannot, it asks you to paste the folder that contains `Voidwrought.exe`. Manual: `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Games\VoidwroughtFq9Qv"`.
3. Start the game (through the Epic Games Launcher as usual).
4. **Settings → Game → Language** — press Right until **Tiếng Việt** (it is the last entry, after Hungarian). The change is instant; leave the menu to save it. The game remembers the choice.

Re-running `Install.bat` is safe (idempotent). It also works together with the Voidwrought trainer pack in either order.

## Uninstall

Close the game and double-click **`Uninstall.bat`**. It removes exactly the files listed in `VwVietnamese_install_manifest.txt` in the game folder, switches
the saved language back to English (`%USERPROFILE%\AppData\LocalLow\Powersnake\Voidwrought\Settings.json`, otherwise a missing 12th language would make the game fail at start-up),
and keeps BepInEx if the trainer still needs it. `-Purge` also deletes the whole `BepInEx` folder when this pack installed it.

## Requirements / compatibility

* Windows, the **Unity-Mono PC build** (folder `MonoBleedingEdge` present). Tested on Epic build *Win.1.1.33* (`Assembly-CSharp.dll` SHA-256 `1B093F6D…CA62`); other builds only get a warning.
* No admin rights, no internet. The game must be closed while installing.
* Saves are never touched. Selecting the language only changes `Settings.json`.

## Troubleshooting

* **Language list has no "Tiếng Việt"** — check that `BepInEx\plugins\VwVietnamese\VwVietnamese.dll` exists and open `BepInEx\LogOutput.log`; it must contain `Injected 'Vietnamese' into source`. If BepInEx never loads, make sure `winhttp.dll` and `doorstop_config.ini` sit next to `Voidwrought.exe`.
* **Square boxes / missing letters** — the four `NotoSans-*.ttf` files must stay in the same folder as the DLL.
* **Game does not start after removing files by hand** — set `"Language": 0` in `Settings.json` (see above) or use `Uninstall.bat`.
* **Text overflows a button** — Vietnamese is longer than English; a few very tight UI labels may look crowded. Please report them.
* Self-test (developer): create an empty file `vi_selftest.flag` in the game folder and start the game; `vi_selftest_report.json` appears after ~25 s (every line should say `PASS`). Delete the flag afterwards.

## Translation notes

Translated against `source/TRANSLATION_GUIDE.md` (glossary: Hư Không = Void, Muối Hồi Phục = Healing Salt, Di Vật = Relic, Cổ Vật = Artifact,
Thành Phố Xám = Gray City, Sao Đỏ = Red Star, …; archaic "ta – ngươi" for the ancient beings, "tôi – bạn" for mortal NPCs). `source/translations/` holds the
English→Vietnamese table and the per-chunk files, so you can improve wording: edit a chunk `*.out.json`, run `python source/tools/validate_chunk.py NN` and `python source/tools/merge.py`,
then rebuild with `source/build.ps1` (needs the .NET Framework `csc.exe` that ships with Windows and the game's `Managed` folder).

## Files in this package

```
Install.bat / install.ps1      installer          Uninstall.bat / uninstall.ps1   uninstaller
payload/plugin/...             VwVietnamese.dll + fonts   payload/bepinex/...   BepInEx 5.4.23.3 (only if missing)
source/                        plugin source, build script, translations, tools     SHA256SUMS.txt   integrity hashes
```

Fan-made, unofficial; not affiliated with Powersnake or Kwalee. Offline/single-player use only; no anti-cheat or DRM is touched.
