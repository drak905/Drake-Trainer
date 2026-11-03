# Voidwrought — English → Vietnamese translation guide

Game: 2D dark-fantasy / cosmic-horror metroidvania (Powersnake / Kwalee). You are a nameless, tendril-armed "Unmade"
creature resurrected inside the **Gray City**, a ruined, god-forsaken city of alchemists, artificers and void-priests,
drawn by the **Red Star** and the sacred **Ichor** that wells up beneath. Tone: bleak, ancient, literary, archaic,
body-horror ("flesh", "tendril", "cartilage", "cyst", "ichor"). UI text is short and functional.

## File format
Input  `work/chunks/chunk_NN.in.json`  : `[{"id": 12, "ctx": "term Dialogue/npc_vizier_intro_01", "en": "..."}, ...]`
Output `work/chunks/chunk_NN.out.json` : `[{"id": 12, "vi": "..."}, ...]` — **one entry for every input id**, UTF-8, valid JSON
(escape `"` as `\"`, line breaks as `\n`; keep the same number of line breaks as the English).
`ctx` is only a hint (the I2 term key shows the category and, for dialogue, the speaker: `npc_vizier`, `npc_voidpriest`,
`lore_stone`, …). Do not translate or output `ctx`.
Check your work with: `python E:\002.Github\043.ReverseEngine\vw-vi\tools\validate_chunk.py NN` — it must report 0 errors.

## Hard rules (the game breaks otherwise)
1. Keep ALL markup tokens exactly as in the English, same count, same spelling: `<i>`, `</i>`, `<b>`, `</b>` (no other
   tags exist). Move them to wrap the corresponding Vietnamese words (word order differs) but never change them.
2. Do not add or drop line breaks (`\n`). Keep leading/trailing spaces and non-breaking spaces (U+00A0) as in the English.
   Do not add quotes/brackets/ellipses that are not in the English; keep "…" and "—" where they are.
3. Output ONLY real Vietnamese with full diacritics (Unicode NFC, precomposed characters). No romanised/telex text,
   no English leftovers except names listed below.
4. Never leave a string untranslated unless it is only a proper name / key label with no Vietnamese equivalent.
5. Keyboard key names (`Enter`, `Home`, `Delete`, single letters, …) and URLs stay unchanged.

## Style
- Natural, fluent, literary game-localisation Vietnamese — not word-for-word. UI space is tight: buttons/menu entries
  must be as short as the English allows (Title Case like the English). Achievement/Data names use Title Case.
- System / UI / tutorial text: address the player as **"bạn"**. Tutorial button prompts like "to Dash forward…" are the
  tail of a sentence that follows an icon: keep them as a fragment starting with a lowercase verb (e.g. "để lướt nhanh về phía trước…").
- Lore stones, journal entries, intro/outro, compendium descriptions: grave, archaic, poetic register (Sino-Vietnamese
  words welcome: thánh, huyết, hư không, đọa…). Third person narrator.
- Dialogue register (the term key shows the speaker):
  - Mystical / ancient beings — `npc_voidpriest`, `npc_caretaker`/`caretaker`, `npc_vizier`, `npc_skychild`, `npc_council`,
    `npc_astronomer`, `npc_learned`, `npc_husk`, `npc_corpsestone`, `npc_forge`, `npc_yantir`, `npc_achretis`: **"ta – ngươi"**
    (self = "ta", the player = "ngươi"; the Council speaks as a group "chúng ta").
  - Mortal / human-like NPCs — `npc_archaeologist`, `npc_trader`, `npc_gourmet`, `npc_hermit`, `npc_crewman`/`npc_crew`:
    **"tôi – bạn"** (the trader is wheedling and servile: "tôi – ngài" is fine). Keep each speaker consistent.
  - The player's own choice lines (`choice`, `answer`, `..._choice01-01`): short, first person "tôi".
- Exclamations and idiom: adapt to something equally grim/poetic in Vietnamese rather than translating literally.
- Numbers, "x2", "+1", percentages: keep as is.

## Glossary (use these exact renderings so the whole game is consistent)
| English | Vietnamese |
|---|---|
| Voidwrought | Voidwrought (unchanged) |
| Gray City | Thành Phố Xám |
| Red Star | Sao Đỏ |
| Void | Hư Không ; Void Charge → Điểm Hư Không ; Void Anchor → Mỏ Neo Hư Không ; Void Gate → Cổng Hư Không ; Void Step → Bước Hư Không ; Voidal Energies → Năng Lượng Hư Không |
| Ichor | Ichor (unchanged) ; Spawn of Ichor → Dòng Dõi Ichor |
| Salt / Healing Salt | Muối / Muối Hồi Phục |
| Trace Metal | Kim Loại Vết |
| Relic / Artifact / Simulacrum / Soul | Di Vật / Cổ Vật / Simulacrum / Linh Hồn |
| Health / Damage / Stamina | Máu / Sát thương / Thể lực |
| Compendium / Journal / Inventory / Map | Bách Khoa / Nhật Ký / Hành Trang / Bản đồ |
| Shrine / Shrine Keeper | Thánh Điện / Người Giữ Thánh Điện |
| Devotee(s) | Tín Đồ |
| Unmade / Unformed / Undone | Kẻ Vô Hình (The Unmade) / Chưa Thành Hình (Unformed) / Kẻ Tan Rã (Undone) |
| Tendril, Claws, Spurs | Xúc tu, Vuốt, Cựa |
| Options / Settings / Controls / Audio / Video / Gameplay / Language | Tùy chọn / Cài đặt / Điều khiển / Âm thanh / Hình ảnh / Lối chơi / Ngôn ngữ |
| Play, Continue, New Game, Quit, Back, Yes, No, On, Off | Chơi, Tiếp tục, Trò Chơi Mới, Thoát, Quay lại, Có, Không, Bật, Tắt |
| Apply, Default, Confirm, Cancel | Áp dụng, Mặc định, Xác nhận, Hủy |
| Keyboard, Gamepad / Controller, Rebind | Bàn phím, Tay cầm, Gán lại phím |
| Jump, Double Jump, Dash, Slide, Attack, Charge Attack | Nhảy, Nhảy đôi, Lướt, Trượt, Tấn công, Tấn công tụ lực |
| Achievements | Thành tựu |

Proper names stay unchanged: Namun, Rahtek, Ta-Hun, So-Venat, Qagat, Achretis, Ose, Yantir, Uut, Jazier, Kwalee, Powersnake, …
Titles "The X" are translated ("The Vizier" → "Vị Tể Tướng", "The Cerebrum" → "Đại Não", "The Glutton" → "Kẻ Háu Ăn",
"The Impure" → "Kẻ Ô Uế", "The Weeper" → "Kẻ Khóc Than"). Enemy / relic / area names are translated into evocative Vietnamese
(Title Case) — be consistent with the same word inside one chunk. Credits job titles are translated; company/person names are not.
