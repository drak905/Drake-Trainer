# Bo: Path of the Teal Lotus — English → Vietnamese translation guide

Game: a 2D action-platformer with Japanese-folklore setting (yokai, kami, tanuki, tengu, kitsune). You play **Bo**, a
"tentaihana" (celestial flower spirit) who wields a bamboo staff, drinks tea to heal and summon daruma dolls, and flies/hovers
with lotus-petal wings. Tone: warm, gently humorous, a little poetic. UI text is short and functional.

## File format
Input  `work/chunks/chunk_NN.in.json`  : `[{"id": 12, "ctx": "dialogue \"All Areas/Blessing Tree\" | Tree of Blessings -> Player", "en": "..."}, ...]`
Output `work/chunks/chunk_NN.out.json` : `[{"id": 12, "vi": "..."}, ...]` — **one entry for every input id**, UTF-8, valid JSON
(escape `"` as `\"`, line breaks as `\n`; keep the same number of line breaks as the English).
`ctx` is only a hint (who speaks to whom / which UI term). Do not translate or output `ctx`.
Check your work with: `python E:\002.Github\043.ReverseEngine\bo-vi\tools\validate_chunk.py NN` — it must report 0 errors.

## Hard rules (the game breaks otherwise)
1. Keep ALL markup tokens exactly as in the English, same count, same spelling: `<color=#CF0000>`, `</color>`, `<#36E0D2>`, `<b>`, `</b>`,
   `<u>`, `<align="center">`, `</align>`, `<style=Player/Jump>`, `<sprite="XBox" name="LEFT STICK/DOWN">`, `[var=Tanuki.UCRaceTime]`,
   `[Chiptune Version]`, `{0}`, `\n`, etc. Move them to wrap the corresponding Vietnamese words (word order differs) but never change them.
   Text *inside* `[...]` that is not a `var=` token (e.g. `[Chiptune Version]`) is a visible label: keep the token **unchanged** too.
2. Do not add or drop line breaks. Do not add quotes/brackets that are not in the English. Keep leading/trailing spaces as in the English.
3. Keep key-binding words that are part of tokens untouched; ordinary words around them are translated.
4. Output ONLY real Vietnamese with full diacritics (Unicode NFC, precomposed characters). No romanized/telex, no English leftovers
   except names listed below.
5. Never leave a string untranslated unless it is only a proper name / sound effect with no Vietnamese equivalent.

## Style
- Natural, fluent game-localization Vietnamese — not word-for-word. Keep sentences about as short as the English
  (UI space is tight: buttons/menu entries should be as short as possible; titles use Title Case like the English).
- Narrator / system / UI / tutorial / item text: address the player as **"bạn"**.
- Dialogue register by speaker (the `ctx` shows `speaker -> listener`):
  - Default NPCs ↔ Bo/Player: **"tôi – bạn"** (friendly peers/young: "mình – cậu"). Bo (the "Player" lines) is mostly Yes/No/short replies.
  - Asahi (stern veteran, mentor-like): "tôi – cậu". Ko, Gyoji, Daichi, Okuni (tanuki, cheerful): "tôi – bạn"/"mình – bạn".
  - Mystical / ancient beings (Amaterasu, Daitengu, Hashihime, Vermillion Stranger, Ri, To, kami, Shogun, Tree of Blessings, Stone Inscription): "ta – ngươi" / "ta – con".
  - Keep each speaker consistent within the chunk.
- Exclamations, puns and yokai-flavoured jokes: adapt to something equally playful in Vietnamese rather than translating literally.
- Numbers, "x2", "+1", percentages, time formats: keep as is.

## Glossary (use these exact renderings so the whole game is consistent)
| English | Vietnamese |
|---|---|
| Bo / Bō (hero name) | Bo (unchanged) |
| tentaihana | tentaihana (unchanged, lowercase in running text) |
| tea / Tea | trà / Trà ; Tea Kettle, kettle → ấm trà / Ấm Trà ; sip → nhấp ; Boiling State → Trạng Thái Sôi ; boiling → đang sôi |
| Fox Fire / Fox Flame / kitsunebi | Hồ Hỏa |
| Daruma, daruma doll | Daruma (unchanged) ; Daruma Wheel → Vòng Daruma ; one eye / two eyes → một mắt / hai mắt |
| Omamori | Omamori (unchanged) ; Omamori Strap → Dây Omamori |
| Shrine / Saving Shrine | đền thờ / Đền Lưu Tiến Trình ; Fast Travel → Dịch Chuyển Nhanh |
| kami / yokai / spirit | kami / yêu quái / linh hồn (linh thể) |
| kitsune, tanuki, tengu, oni, kodama, tsuchigumo, kappa, shisa … | keep the Japanese word (lowercase unless it is a name/title) |
| staff (Bo's weapon) | gậy ; staff attack → đòn đánh bằng gậy |
| Seal (challenge modifier) | Phong Ấn ; Staff Seal → Phong Ấn Gậy ; Kettle Seal → Phong Ấn Ấm Trà ; Daruma Seal → Phong Ấn Daruma ; Omamori Seal → Phong Ấn Omamori ; Petal Seal → Phong Ấn Cánh Hoa |
| health, max health, petal (health unit) | máu, máu tối đa, cánh hoa |
| lotus / Teal Lotus | sen / Hoa Sen Xanh Ngọc |
| jump, double jump, dash, hover, grapple, wall grab | nhảy, nhảy đôi, lướt, lơ lửng, móc kéo, bám tường ; shine dash → lướt tỏa sáng |
| combo, hits, heat | combo, đòn đánh, nhiệt |
| Audience Favor | Sự Ưu Ái Của Khán Giả ; play / performance (theater trial) → vở diễn |
| Quests / Journal / Inventory / Map | Nhiệm vụ / Nhật ký / Túi đồ / Bản đồ |
| Options / Settings / Controls / Audio / Video / Gameplay | Tùy chọn / Cài đặt / Điều khiển / Âm thanh / Hình ảnh / Lối chơi |
| Play, Continue, New Game, Exit Game, Main Menu | Chơi, Tiếp tục, Trò Chơi Mới, Thoát Game, Menu Chính |
| Apply, Default, Confirm, Cancel, Back, Yes, No, On, Off | Áp dụng, Mặc định, Xác nhận, Hủy, Quay lại, Có, Không, Bật, Tắt |
| Keyboard, Controller, Rebind | Bàn phím, Tay cầm, Gán lại phím |
| Purchase, Cost, Upgrade, Shop | Mua, Giá, Nâng cấp, Cửa hàng |
| Sakura City | Thành Phố Sakura |
| Midori Forest | Rừng Midori |
| Megumi Mountain | Núi Megumi |
| Strange Garden | Khu Vườn Kỳ Lạ |
| (Forest of the) Crimson Bamboo (Forest) / Bamboo Forest | (Rừng) Trúc Đỏ Thẫm / Rừng Trúc |
| Uzumaki Cave | Hang Uzumaki |
| Kitsune Burrows | Hang Kitsune |
| Ice Caverns | Hang Băng |
| Celestial Realm | Thiên Giới |
| Imperial Castle | Hoàng Thành |
| Kabuki Theater | Nhà Hát Kabuki |
| Sencho Bridge | Cầu Sencho |
| Sakura Shogun / Shogunate | Shogun Sakura / Mạc phủ Sakura |
| Tree of Blessings / blessing slip | Cây Phước Lành / thẻ phước |
| Stone Inscription / Lore Tablet | Bia Đá Khắc Chữ / Bia Truyền Thuyết |
| Vermillion Stranger / vermillion | Người Lạ Chu Sa / đỏ son (chu sa) |
| Flying Sumo | Sumo Bay |
| Bamboo, Ore, Silk, Crystal Petal, Pungent Root (resources) | Tre, Quặng, Tơ, Cánh Hoa Pha Lê, Rễ Cay |
| Wall Scroll | Tranh Cuộn |

Character, yokai, daruma and place names that are Japanese (Asahi, Okuni, Kitsura, Hashihime, Armakillo, Chachamaru, Jorogumo, …) stay
unchanged. Descriptive English name parts are translated ("Particularly Unmanageable Armakillo" → "Armakillo Cực Kỳ Khó Bảo").
Item names that are plain English words are translated ("Crystal Ramen" → "Mì Ramen Pha Lê").
