# Guacamelee! Super Turbo Championship Edition — English → Vietnamese translation guide

Game: a Metroidvania beat-'em-up set in a Mexican-folklore world (Day of the Dead, lucha libre). You are **Juan Aguacate**,
a humble agave farmer turned **luchador** who wears a magic mask, fights skeletons (calacas) and switches between the
world of the living and the world of the dead. Tone: jokey, meme-y, lots of puns, video-game references, silly NPC chatter,
Spanish words sprinkled in the English text ("amigo", "muy inteligente", "¡Pa'su mecha!"). Menu/UI text is short and functional.

## File format
Input  `work/chunks/chunk_NN.in.json`  : `[{"id": 12, "ctx": "HubTown | ManAboveBar5 | ...", "en": "..."}, ...]`
Output `work/chunks/chunk_NN.out.json` : `[{"id": 12, "vi": "..."}, ...]` — **one entry for every input id**, UTF-8, valid JSON
(escape `"` as `\"` in JSON, and a backslash as `\\` in JSON — see below). `ctx` is only a hint (file | key | note). Never output ctx.
Check your work with: `python E:\002.Github\043.ReverseEngine\tools\gcm\vi_validate.py NN` — it must report 0 errors.

## Hard rules (the game breaks otherwise)
1. The text uses engine escape sequences that are written as **a literal backslash + letter** in the English string:
   `\n` = line break, `\p` = page break (next text box). In the JSON they appear as `\\n` and `\\p`. Keep every `\p` exactly
   (same count, same position in the story flow, including a trailing `\p`). `\n` line breaks: re-wrap the Vietnamese yourself;
   use about the same number of lines (±1), **each line at most ~38 characters** (dialogue boxes are narrow) and never more
   lines per page than the longest page in the English. Short UI strings: no `\n` unless English has one.
2. Keep ALL placeholders unchanged, same count: `{X}`, `{CROSS}`, `{MENUCONFIRM}`, `{LSTICKRIGHT}`, `{R2}`, `{TOGGLEMAP}` …
   (anything in braces), printf codes `%d`, `%u`, `%s`, `%.0f`, and `[circle]`-style bracket tokens. Words around them are translated.
3. No real tab / carriage-return / line feed characters inside a string. Do not add quotes that are not in the English.
   Keep leading/trailing spaces as in the English. Keep the exact same ASCII punctuation style (`...` stays `...`).
4. Output only real Vietnamese in Unicode **NFC** (precomposed characters, e.g. `ế` not `e` + combining marks), full diacritics. No telex/romanised text.
5. If the English is only a name, sound effect or onomatopoeia ("BAWK! BAWK!", "Trolololol", "Ay ay ay"), translate it only if there is a natural
   Vietnamese equivalent; otherwise keep it. Never leave ordinary sentences in English.
6. If the English text is an internal ID or debug text that is not a sentence (e.g. `DIALOG - 03 - Skeleton_2`), return it unchanged.

## Style
- Natural, fluent, funny game-localisation Vietnamese — not word-for-word. Adapt puns/jokes to something equally playful.
- Narrator / UI / tutorial / system text addresses the player as **"bạn"**. Imperatives for buttons: "Nhấn {X} để tấn công."
- Characters: default friendly townsfolk ↔ Juan: "tôi – cậu/bạn" (cheerful: "mình – cậu"); old/wise characters (Uay Chivo the goat spirit,
  Olmec heads, elders): "ta – ngươi/con"; villains (Calaca, Jaguar Javier, Xtabay, Flame Face, skeleton bosses): arrogant "ta – ngươi" / "tao – mày" for thugs.
  Chickens (Pollo) may be silly: "gà ta – mày". Keep a speaker consistent (the ctx file/key shows who).
- Keep length close to the English (UI space is tight). Menu entries, buttons and titles: as short as possible, Title Case like the English.
- Numbers, `x2`, `+1`, `%`, times and money formats stay as they are.

## Glossary (use these exact renderings)
| English | Vietnamese |
|---|---|
| Guacamelee!, Juan Aguacate, Juan, Tostada, El Presidente, Carlos Calaca / Calaca, Xtabay, Flame Face, Jaguar Javier, Uay Chivo, El Trio de la Muerte, Santa Luchita, Pueblucho, Pico de Gallo, Olmec | keep unchanged (Olmec head → đầu Olmec) |
| luchador / luchadora / lucha libre | luchador / luchadora / lucha libre (keep) |
| Skeleton / calaca (generic enemy) / esqueleto | bộ xương / calaca (keep "esqueleto(s)" when the English keeps it) |
| Chicken, Pollo, Pollo form | Gà, dạng Pollo (Pollo = keep) |
| Intenso / EL INTENSO / Devil Trigger | EL INTENSO / Intenso (keep) |
| Dimension swap, Living World, Dead World | Hoán đổi chiều không gian, Thế giới người sống, Thế giới người chết |
| Mask, Luchador mask | mặt nạ, mặt nạ luchador |
| Health, Stamina, Pesos, Silver | Máu, Thể lực, Peso, Bạc |
| Orb / Power Orb | Quả cầu / Quả cầu sức mạnh |
| Combo, Hit(s), Max combo | Combo, đòn, Combo cao nhất |
| Upgrades, Shop, Buy, Purchase, Cost | Nâng cấp, Cửa hàng, Mua, Mua, Giá |
| Chest, Treasure, Collectible | Rương, Kho báu, Vật phẩm sưu tầm |
| Checkpoint / Save Point / Altar | Điểm kiểm tra / Điểm lưu / Bàn thờ |
| Temple, Cave, Forest, Desert, Sierra, Canal, Mansion, Town | Đền, Hang động, Rừng, Sa mạc, Sierra, Kênh đào, Dinh thự, Thị trấn |
| Achievement(s), Trophy/Trophies | Thành tựu, Cúp |
| Options, Settings, Controls, Audio, Video, Language | Tùy chọn, Cài đặt, Điều khiển, Âm thanh, Hình ảnh, Ngôn ngữ |
| Start, Continue, New Game, Load, Save, Quit, Back, Yes, No, Ok, Cancel, On, Off | Bắt đầu, Tiếp tục, Trò chơi mới, Tải, Lưu, Thoát, Quay lại, Có, Không, OK, Hủy, Bật, Tắt |
| Player 1 … 4 / PLAYER ONE … FOUR | Người chơi 1…4 / NGƯỜI CHƠI MỘT … BỐN |
| Paused, Resume, Restart, Difficulty (Easy/Normal/Hard…) | Tạm dừng, Tiếp tục, Chơi lại, Độ khó (Dễ/Thường/Khó…) |
| Spanish phrases in the English ("amigo", "gracias", "señor", "¡Pa'su mecha!", "muy inteligente") | keep as in English (amigo → may become "bạn" only when it is clearly a plain address) |
| The Great Temple, Tule Tree, Pico, … (area names) | keep proper names; translate only common nouns |

Always use the same rendering for the same term in every chunk. When the English contains a pop-culture reference (Zelda, Mario, Metroid…),
keep the reference recognisable.
