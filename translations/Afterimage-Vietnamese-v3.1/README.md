# Afterimage — Vietnamese Language Pack (Gói tiếng Việt) v3.1.0

A Vietnamese translation of **Afterimage** (Steam, Aurogon). It runs as a UE4SS Lua mod that translates the
game's text live, in memory, and draws it with a matching Vietnamese font. **No game file is modified**: the
`.pak`, the `.exe` and your save files are never touched, and the pack is fully reversible.

**New in v3.1.0 — no more English flicker on the map.** Map and minimap area names are re-written to English by the game
about 2–3 times per second, so in v3.0.0 they showed English most of the time (measured: **92 % of the time**) and Vietnamese
only for a moment. v3.1 translates them in the same frame the game writes them (measured: **0 % English**, no reversals, on the map
screen while panning and zooming). The same release fixes a bug in the pack's own widget cache that made it redo its work on every
widget on every pass.

**New in v3.0.0 — font fix.** In v2 the accented letters (`ố ự ệ ồ ụ ộ ầ ư ờ`…) were drawn with a heavier
mismatched font, so words looked like a ransom note of thin and thick letters. v3 draws all Vietnamese text
from one thin serif font. Details are under *The font fix* below.

---

## What is translated

| Area | How it is matched | Entries |
|---|---|---|
| All game string tables (menus, options, prompts, tutorials, map, achievements, dialogue tables…) | English text shown on screen | 3,144 |
| Items, weapons, equipment, spells, monsters, materials, recipes (the game's own data tables) | the Chinese source text the game passes to its text functions | 5,572 |
| Quest log titles and bodies, item/lore descriptions, extra dialogue lines scraped from the game's English text | English text shown on screen | 1,524 |
| Hand-checked UI labels and stat labels such as `<LABEL> +N%` | English text + number patterns | 109 + 54 |

Checked in game on this build: title menu, profile select, Options, pause menu (items, equipment, talents with
the stat panel, quest log, achievements), item and equipment descriptions, long paragraphs, and the
`Home` on/off toggle.

### Known limits (please read)

- **Language must stay English.** The pack translates from the English text. Keep
  **Options → Game → Language = English**. Other languages are not translated.
- **Quest log coverage is partial.** Every quest line that was in the game's memory when the dictionary was
  built is translated, and the two quests of the test save were checked live. A quest whose English text was
  never captured stays in English until it is added (see *Extending*).
- **Story dialogue boxes were not checked in game.** The dialogue lines found are in the dictionary, but the
  dialogue boxes themselves were not viewed during testing, and the font fix was not verified there.
- **Flicker is fixed for the map and minimap labels, which were the case measured.** Other text that the game rewrites on its own
  schedule can still show English for up to 0.2 s before the sweep catches it. Plain `TextBlock` labels were checked and do not flicker.
- **Not a language-menu entry.** Vietnamese does not appear in Options → Game → Language: that list is hard-coded in the game's
  encrypted scripts. Keep the game on English; the pack draws Vietnamese over it.
- **Combat numbers, the title logo and other art fonts are left as they were.** Only text that uses the
  game's main UI font (`AuroMinTWM_Font`) moves to the Vietnamese font.
- **Chinese-only strings** of the unfinished multiplayer lobby (`进入单人模式`, `建房间`, `找房间` …) are not
  translated. Any text that still contains Chinese stays on the original font, because the Vietnamese font has
  no Chinese glyphs.
- **Text baked into images** (the `AFTERIMAGE` logo, some title art) cannot be changed.
- **Machine-assisted translation.** Style and glossary are in `source/TRANSLATION_GUIDE.md`. Some terms are
  inconsistent between files (for example `Tai Lông Xù` / `Tai Cụp Lông Xù`). Corrections are welcome.

---

## The font fix

**Cause.** The game draws its UI with the composite font `AuroMinTWM_Font`: a heavy Chinese face first, plus a
sub-font per language. The English sub-font is *Bellefair* and is limited to code points `U+0000–U+017F`.
Vietnamese needs `U+01A0/U+01A1/U+01AF/U+01B0` (`Ơ ơ Ư ư`) and `U+1EA0–U+1EF9` (every toned vowel), so each of
those letters was taken from the next font in the chain (Noto Serif / the CJK face) with a different stroke
weight. Your Vietnamese strings were already in Unicode NFC (precomposed), so the encoding was not the problem.

**Fix (at font-asset level).** The pack ships **Cormorant Garamond SemiBold** (SIL Open Font License), a thin
Garamond-style serif with all 186 Vietnamese letters. At runtime the mod:

1. loads that TTF into a font object the game never uses (`DMatchHUDFont`),
2. moves every text block that used the main UI font onto it,
3. redirects the game's 60 rich-text style rows (item and equipment descriptions, dialogue, tooltips) to it.

The font file is `…\Mods\AI_Vietnamese\font\CormorantGaramond-SemiBold.ttf`. In the file the digits are
switched to lining figures (the font's default digits are old-style and look uneven in numbers like
`00:38:42` or `1,192`).

**Choices you can change** (`config.lua`): `hook_rich_text = false` turns off the instant map-label translation (the 5-per-second sweep
then does that job, with flicker); `font_fix = false` goes back to the game's own fonts;
`font_file` points to another TTF with Vietnamese glyphs (for example EB Garamond or Noto Serif). To rebuild the
bundled font see `source/fonts/make_static.py`.

---

## Requirements

- Windows, Steam version of Afterimage (tested on Steam build **14404437**, Unreal Engine 4.26). Other builds
  may work, because the pack reads text at runtime and does not patch the executable.
- The pack bundles the **UE4SS** mod loader and installs it only if none is present. If you also use the
  Afterimage Trainer, the pack detects it and installs **alongside** it without disturbing it.

---

## Install

1. **Close the game.**
2. Unzip this package anywhere.
3. Double-click **`Install.bat`**. It finds the Steam install; if it cannot, it asks for the game folder
   (the one containing `Afterimage.exe`).
   - Manual folder: `Install.bat -GameDir "D:\SteamLibrary\steamapps\common\Afterimage"`
4. Start the game from Steam. Keep **Options → Game → Language = English**.
5. Wait about 30 seconds after the game starts. The pack stays idle while UE4SS finishes loading, then the
   menus switch to Vietnamese and the new font.

Upgrading from v1 or v2 is the same procedure. Your `config.lua` is kept; if you upgrade from v2, add the two
lines `font_fix = true` and `font_file = "font/CormorantGaramond-SemiBold.ttf"` (or delete your
`config.lua` before installing to get the new defaults). Without them the font fix still works, because those
are the built-in defaults.

### In-game toggle
Press **`Home`** to turn the Vietnamese overlay on or off (useful for comparing with English). Turning it off
also puts back the original fonts. Change the key in
`…\Win64\ue4ss\Mods\AI_Vietnamese\Scripts\config.lua`.

---

## Uninstall

1. Close the game.
2. Double-click **`Uninstall.bat`**.

It removes the `AI_Vietnamese` mod (including its font) and its entry in the mod list. If this pack
installed the UE4SS loader and nothing else uses it, the loader is removed too and any earlier `dwmapi.dll`
is restored. If the Afterimage Trainer or another mod is still installed, the loader stays. Game files and
saves are not touched either way.

---

## How it works

Afterimage mixes three text paths:

1. **Unreal string tables** with Chinese source text and English from the `en` culture.
2. **A Lua data table** (`Items`, monsters, spells…) served through
   `LuaLocalizationFunctionLibrary:GetTextWithNameSpace(namespace, row, column, chineseLiteral)`.
3. A separate path for **quest log text**.

The pack hooks the four functions that carry data-table and talent text, hooks `RichTextBlock:SetText` so that the map labels are
translated the moment the game writes them, and runs a light sweep (5 times per second, about 7 ms per run on the test PC) over every
`TextBlock` and `RichTextBlock`. English text is looked up in the English-keyed dictionary
(exact match, `{placeholder}` templates, rich-text `<tag>`s, `<LABEL> +N`, then line by line). Chinese text is
looked up in the Chinese-keyed dictionary. Translated widgets are then moved onto the Vietnamese font. The
hooks are post-hooks wrapped in `pcall`. Not hooked: `LuaLocalizationFunctionLibrary:GetText` (it crashed UE4SS
during testing).

The game archive is AES-encrypted and no key was recovered, and a loose `vi` locres was rejected (a pure `vi`
culture cannot be chosen in the language selector and drops non-table text back to Chinese). Hence the overlay.

---

## Extending / fixing the translation

All sources are in `source/` (plain tab-separated text, UTF-8 without BOM, Unicode NFC):

```
source/vi_strings.tsv            id, namespace, key, Chinese, English, Vietnamese   (string tables)
source/vi_zh_strings*.tsv        id, Chinese, Vietnamese                            (data-table text)
source/extra_zh.tsv              Chinese<TAB>Vietnamese                              (hand additions)
source/ui.tsv, ui_stats.tsv      English<TAB>Vietnamese                              (UI labels, stat labels)
source/extra.tsv                 English<TAB>Vietnamese                              (quests, lore, dialogue)
```

1. Add or fix a line. For English-keyed files the **English side must equal the on-screen text**
   (use `<NL>` for a line break; `#` starts a comment).
2. Install Python 3 and run `python source/gen_vi.py` (rewrites `payload/mod/AI_Vietnamese/Scripts/vi_data.lua`).
3. Check: `python source/nfc_check.py` (all Vietnamese must be NFC; add `--fix` to repair) and, with
   `pip install lupa`, `python source/selftest_lookup.py` (must exit 0).
4. Copy the new `vi_data.lua` to `…\Win64\ue4ss\Mods\AI_Vietnamese\Scripts\`, or run `Install.bat` again.

To find untranslated text while you play, set `harvest = true` in `config.lua`. The pack then writes every
visible untranslated line to `AI_Vietnamese\Scripts\vi_harvest.txt` (`WV` rows are on screen at that
moment). `python source/harvest_report.py vi_harvest.txt` summarises it. Set it back to `false` afterwards.

---

## Troubleshooting

- **Menus still in English.** Check **Language = English**, wait ~30 s after launch, and press `Home` once to
  make sure the overlay is on.
- **Map labels still flicker.** Check `UE4SS.log` for `rich-text instant hook installed: true`. If it says `false`, report the line after it.
- **Accented letters look heavy again.** Check `UE4SS.log` for the line `font fix ready: …`. If it says
  `font fix unavailable`, the font file is missing or `font_file` is wrong. Reinstall with `Install.bat`.
- **Letters or numbers look too thin or too thick.** Use another TTF through `font_file`, or rebuild the
  bundled font at another weight with `source/fonts/make_static.py` (change `wght`).
- **Nothing happens at all.** Confirm `…\Win64\dwmapi.dll` and `…\Win64\ue4ss\` exist and that
  `ue4ss\Mods\mods.txt` contains `AI_Vietnamese : 1`. Launch from Steam.
- **The game crashes.** Uninstall, then report it with `…\Win64\ue4ss\UE4SS.log`.
- **Antivirus** may flag the UE4SS `dwmapi.dll` proxy. It is the open-source UE4SS loader; see
  `LICENSE-UE4SS.txt`.

---

## Credits & licenses

- **UE4SS** (RE-UE4SS) — the Unreal scripting loader. See `LICENSE-UE4SS.txt`.
- **Cormorant Garamond** © 2015 the Cormorant Project Authors, SIL Open Font License 1.1
  (`payload/mod/AI_Vietnamese/font/OFL.txt`). The bundled file is a static SemiBold instance of the variable
  font with lining digits; the family name inside the file was changed to say so.
- Afterimage © Aurogon / Modus Games. This is an unofficial fan translation for single-player use.

---

## Tóm tắt tiếng Việt

Gói tiếng Việt cho **Afterimage** (bản Steam), chạy dưới dạng mod UE4SS, dịch chữ ngay trong bộ nhớ và vẽ
bằng font Việt thống nhất. **Không sửa tệp game nào**, không đụng tới file lưu; gỡ ra là sạch hoàn toàn.

- **Sửa lỗi font (v3):** trước đây các chữ có dấu (`ố ự ệ ồ ụ ộ ầ ư ờ`…) bị vẽ bằng font đậm, lệch nét so với
  chữ Latin mỏng. Nguyên nhân: font chính của game (Bellefair) chỉ có `U+0000–U+017F`, nên mọi chữ Việt ở
  `U+1EA0–U+1EF9` và `Ơ/Ư` bị lấy từ font dự phòng. Gói giờ kèm font **Cormorant Garamond** (mỏng, có đủ 186
  chữ Việt) và chuyển toàn bộ chữ UI sang font này.
- **Đã dịch (~10.000 câu):** menu, tùy chọn, vật phẩm, trang bị, thiên phú, chỉ số, phép thuật, quái vật,
  thành tựu, nhật ký nhiệm vụ và phần lớn mô tả/cốt truyện.
- **Hạn chế:** phải để **Ngôn ngữ = English**; nhiệm vụ chưa từng được ghi lại sẽ còn tiếng Anh; hộp thoại
  cốt truyện chưa được kiểm tra trong game; chuỗi tiếng Trung của phòng chơi mạng chưa dịch; chữ nằm trong
  hình ảnh không đổi được.

**Cài đặt:** đóng game → chạy **`Install.bat`** → mở game từ Steam, giữ **Tùy chọn → Trò chơi → Ngôn ngữ =
English**, chờ khoảng 30 giây. Nhấn **`Home`** để bật/tắt tiếng Việt. **Gỡ:** đóng game → **`Uninstall.bat`**.
