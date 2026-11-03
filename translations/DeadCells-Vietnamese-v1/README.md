# Dead Cells – Bản Việt hóa v1 (Vietnamese language patch)

Adds **Tiếng Việt** as a new language to Dead Cells. It does not replace English or any other language.
The patch was made on the Epic Games build of the game (version 35, `1.25.2Win-8b5231cd25`, "The End Is Near"),
including all DLC texts.

- 5,594 game texts translated (5,474 different strings): menus, options, items, mutations, enemies, biomes,
  dialogue, lore, tutorials, achievements and all DLC texts.
- Vietnamese letters are added to every Latin font the game uses (normal, title/medieval, Arial, dyslexia-friendly,
  Ubuntu Mono and Fraktur font options), drawn from each font's own letters so they match its style.
- Any text that is missing from the translation (for example new text added by a future game update) is shown
  in English instead of breaking.

## Install (on any PC)

1. Close Dead Cells.
2. Copy this whole folder (or unzip `DeadCells-Vietnamese-v1.zip`) anywhere on the PC.
3. Double-click **`Install.bat`**.
   - It finds the game by itself (Epic Games launcher, Steam libraries, or common folders such as
     `E:\EpicGames\DeadCells`).
   - If it can't find the game, open PowerShell in this folder and run:
     `powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir "D:\Path\To\DeadCells"`
4. Start Dead Cells the usual way (Epic: from the Epic Games launcher).
5. On the **title screen** open **Options → Language → Tiếng Việt**. The game only allows changing the language
   on the title screen. The choice is saved; next time the game starts in Vietnamese.

### What the installer changes

| File | Change |
|------|--------|
| `<game>\save-backup-<date-time>\` | Copy of your saves, made before anything is changed. |
| `deadcells.exe` | Adds "Tiếng Việt" to the game's language list. The previous exe is kept as `deadcells.exe.vi-backup`. |
| `<game>\res1.pak` (or `res2.pak`, … if `res1.pak` is already used by another mod) | New file with the Vietnamese texts and the extended fonts. `res.pak` is **not** modified. |

How `deadcells.exe` is patched:

- **Original game** (SHA-256 `FFC17ED5…5A77`) or **game + DC Trainer v1** (`5514FD67…6E39`): it applies a
  small binary diff from `payload\` and checks the result hash (`FC4450DC…EA60` or `0425A366…2796`). If anything
  doesn't match, nothing is changed.
- **Already patched**: the exe step is skipped (running the installer again only refreshes the texts/fonts).
- **Another game version**: it rebuilds the patch from your exe's own game code with
  `source\tools\patch_any_version.py`. This needs **Python 3.8+** (python.org), no extra modules. If the game code
  it looks for has changed, it stops and restores your exe.

The pak file must carry the same "stamp" as your game's `res.pak` (otherwise the game silently ignores it); the
installer copies the stamp from your `res.pak`, so the pak also loads on other game versions.

## Uninstall

Close the game and double-click **`Uninstall.bat`**. It puts `deadcells.exe.vi-backup` back and deletes the
Vietnamese pak (any later `resN.pak` from other mods is renumbered so the game still loads it). If the game was set
to Vietnamese it starts in English afterwards. You can also use **Epic Games launcher → Library → Dead Cells → ⋯ →
Manage → Verify** to get the original `deadcells.exe` back; then delete the Vietnamese `res1.pak` yourself.
Your `save-backup-*` folders are left in place.

## Good to know

- **Game updates** and **Epic "Verify"** replace `deadcells.exe` and remove the Vietnamese entry from the language
  list. Run `Install.bat` again afterwards (the new build has a different hash, so the installer uses the Python
  rebuild path). If an update changes the game's fonts, rebuild the pak too (see "Rebuild" below).
- **Pixelated font option**: the game's pixel font ("Pixelated font" in Options → Video) has no Vietnamese letters.
  While the language is Vietnamese, the game uses the classic font instead. All other font options work.
- **Epic cloud saves**: if the Epic launcher shows *"We've detected a cloud sync conflict"* the first time after
  installing, choose the newer file (usually **Upload to cloud**: your local saves are the current ones; the
  installer also made a copy in `save-backup-*`).
- **DC Trainer v1**: both patches work together, in either order. If you install the trainer after this patch,
  the trainer installer uses its Python rebuild path (needs Python), because the exe hash is no longer the original.
- Text inside pictures (logos, the online "news" panel on the title screen) stays as it is.
- Start the game through the Epic launcher (starting `deadcells.exe` directly fails with "Epic init failed", also
  without this patch).

## Test status

- Checked: the patched game code parses and the changed functions were disassembled and reviewed; the game starts
  through the Epic launcher, reaches the title screen and shows Vietnamese menus with correct diacritics, with both
  the original exe and the trainer exe; the language list shows "Tiếng Việt"; Options screens show Vietnamese text
  and descriptions.
- Every translated string passed an automatic check: `::placeholders::`, `{text@COLOR}` tags, icons, `*`, `%` and
  line breaks are identical to the English; no string is missing.
- `Install.bat` / `Uninstall.bat` were tested on copies of the game files: original exe, trainer exe, an unknown
  build (Python path), an existing foreign `res1.pak` (the patch goes to `res2.pak`), and uninstall with a later
  foreign pak (renumbered).
- Not checked by playing a full run: how long translated texts fit in every in-game panel, and the switch from the
  pixel font to the classic font (checked only in the code). If a text is cut off or reads badly, edit it as
  described below.

## How it works (for the curious)

Dead Cells runs on HashLink (Haxe/Heaps). Its game code is HashLink bytecode stored inside `deadcells.exe` as the
resource `RCDATA / HLBOOT.DAT`; its assets are in `res.pak`.

- The language list is `Lang.LANGS`, built in the game's static initialiser. The patch adds one entry
  `{id:"vi", name:"Tiếng Việt", codes:["vi-vn","vi"], chars:"latin", src:"en"}`. Because of `src:"en"`, the game
  loads `lang/main.en.mo` first and then overlays `lang/main.vi.mo` with its own `GetText.readNextMo`, which looks up
  each **English** text in the Vietnamese file. That is why missing strings fall back to English.
- `Lang.isFontCompatible` gets a short check at its start: it returns `false` for the "legacy" pixel font while the
  language is `vi`, so the game switches to the classic font.
- At start-up `Boot.initRes` loads `res.pak`, then `res1.pak`, `res2.pak`, … while they exist, and later files
  override earlier ones (a pak is skipped if its 64-character stamp differs from the game's). The patch pak holds
  `lang/main.vi.mo` and 19 Latin fonts (`fonts/exported/*.fnt` + `.png`, Heaps BFNT format).
- The fonts already listed most Vietnamese letters, but `Ậ ậ Ợ ợ` were missing everywhere and in the title
  (Berylium), ADYS and Fraktur fonts most Vietnamese letters were empty images. `fontcompose.py` builds them from
  the font's own glyphs: base letter or existing `â ê ô ơ ư ă` + marks cut out of `á à ã â ă` (`á` minus `a`), the
  dot below from `.`, the hook above from the top of `?`, the horn from a turned `,`, and packs them into the
  font texture.

## Files

| File | Purpose |
|------|---------|
| `Install.bat` / `install.ps1` | Install (backs up saves and the exe first) |
| `Uninstall.bat` / `uninstall.ps1` | Restore the exe and remove the Vietnamese pak |
| `common.ps1` | Shared helpers (game folder search, file checks) |
| `payload\dc-vietnamese.pak` | Texts (`lang/main.vi.mo`) + extended fonts; installed as `res1.pak` |
| `payload\vanilla_to_vi.xdelta`, `payload\trainer_to_vi.xdelta` | Binary diffs original exe / trainer exe → Vietnamese exe (about 5 KB each) |
| `payload\xdelta3.exe` | xdelta 3.2.2 decoder (Apache-2.0, see `payload\xdelta3-README.md`) |
| `source\tools\` | Python tools: `build_vi_patch.py` (bytecode patch), `patch_any_version.py`, `exeres.py`, `hlcode.py`/`hlasm.py` (HashLink reader/writer), `pak.py` (Heaps PAK), `bfnt.py` + `fontcompose.py` (fonts), `mo.py` + `build_mo.py` (gettext), `rebuild_res_pak.py`, `validate_chunk.py` |
| `source\translation\` | The translation: `chunks\chunk_*.in.json` (English) / `.out.json` (Vietnamese), `vi_strings.json` (all strings: key, English, Vietnamese), `main.vi.mo`, `TRANSLATION_GUIDE.md` (rules + glossary), `names_vi.json` |
| `SHA256SUMS.txt` | Checksums of every file in this package |

## Rebuild / edit the translation

Needs Python 3.8+; the font step also needs `pip install pillow numpy`.

1. Edit the `"vi"` texts in `source\translation\chunks\chunk_*.out.json` (keep `::placeholders::`, `{…@CODE}` tags
   and line breaks).
2. In an empty work folder create `work\chunks\` with the chunk files and `work\strings_en.json`, put the tools in
   `tools\` next to it, then run `python tools\validate_chunk.py all` and `python tools\build_mo.py` (writes
   `work\res1\lang\main.vi.mo`).
3. Build the pak from your own game's `res.pak` (fonts of your version + your stamp):
   `python tools\rebuild_res_pak.py "<game>\res.pak" work\res1\lang\main.vi.mo "<game>\res1.pak"`.
