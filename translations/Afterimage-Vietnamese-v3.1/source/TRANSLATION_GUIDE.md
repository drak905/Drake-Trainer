# Afterimage — Vietnamese translation guide (English → Vietnamese)

Game: **Afterimage** (Aurogon), a 2D action-adventure Metroidvania. Dark-fantasy, melancholic, poetic tone.
The player (**Renee**, a young "Resonant" / songstress-soldier) travels with the spirit companion **Ifree** through
a world recovering from the **Great Explosion** ("Big Bang" in the lore), where dead souls return to the **Stream**.

## Hard rules (a violation breaks the game — the validator rejects the file)
1. Output **exactly one Vietnamese line per input line**, same order, same count. Format is `ID<TAB>Vietnamese`.
   Never merge, split, skip or reorder lines. Never output anything except those lines.
2. Keep the literal two-character sequences `\n` and `\r` and `\t` exactly where they are (they are line breaks
   inside one string). Do not turn them into real line breaks. `\r\n` pairs stay `\r\n`.
3. Keep every `{placeholder}` token byte-for-byte (`{cost}`, `{CurrCount}`, `{MaxCount}`, `{currenttext}`,
   `{emptyline}`, `{playerlevel}`) and every tag byte-for-byte (`<Grey>`, `</>`, `<img id="..."/>`, `<RedS>` …).
   Translate only the human text between tags.
4. Numbers, punctuation style like `…`, `—`, `!`, `?` are kept. Keep ALL-CAPS strings in ALL CAPS
   (UI buttons/labels are upper case: `QUIT GAME` → `THOÁT GAME`).
5. Use full, correct Vietnamese diacritics (UTF-8). Never leave English words except the proper nouns below.
6. Keep length close to the English where you can — UI labels have little room. Prefer short natural phrasing for
   buttons/labels; dialogue may be as long as needed.
7. If a line is only `???`, a number, or a proper noun, return it unchanged.

## Voice
- Dialogue: natural spoken Vietnamese, matched to the speaker. Ifree = cheeky, proud, a bit bossy spirit ("ta"/"ngươi"
  is too archaic — use "tôi/cậu" or "ta/nhóc" only where the English is clearly haughty). Renee = quiet, gentle ("tôi"/"mình").
  Elders / Madame = measured and warm. Hostile bosses = formal and cold.
- Pick one pronoun pair per speaker and keep it. Do not use heavy Sino-Vietnamese archaisms unless the line is a
  ritual/scripture/lore text (research notes, glyph texts), where a slightly literary register is right.
- UI text: short imperative/noun forms (`Xác nhận`, `Hủy`, `Quay lại`), not full sentences.

## Character voice decisions (established in the pilot — every translator must match these)
- **Renee** (player, quiet, gentle): self = "tôi". Calls Ifree "Ifree"; calls Aros "Cô Giáo" / "Cô".
- **Ifree** (cheeky spirit companion): self = "Ifree" or "Ifree đại nhân" (when boasting); calls Renee "Ree"/"cậu".
- **Aros / Madame** (Renee's teacher): self = "cô"; calls Renee "em".
- **Levine** (librarian): self = "tôi"; calls Renee "cô". Between old friends (Levine/Ripe) they say "ông".
- **Owl** (the character named Owl / "Cú"): keep the name as **Cú**.
- Anonymous system/narration text ("You…"): "bạn".
- Chinese-wuxia register ("ngươi/ta") only for ancient beings, bosses, scripture and lore books.

## Fixed terms (use EXACTLY these; do not invent variants)
### Keep as-is (proper names)
Ifree, Renee, Ree, Aros, Aqil, Agus, Atmous, Avisia, Brenda, Karin, Karsa, Levine, Stanley, Emily, Doro, Ethan,
Eseus, Alice, Nicole, Rosalia, Ripe, Roxie, Ian, Mia, Martin, Madeline, Tark, Roke, Loss, Patt, Auss, Alvess, Se,
Snailing, Samsare, Brandr, Izotz, Arteefex, Engardin, Luca, 42, Afterimage, Owl→**Cú** only when it is a common noun.

### World terms
| English | Vietnamese |
|---|---|
| Stream | Dòng Chảy |
| Sea of Souls | Biển Linh Hồn |
| Soulfield | Cánh Đồng Linh Hồn |
| Soul Link | Liên Kết Linh Hồn |
| Ode to LUCA / Member of the Ode to LUCA | Ca Đoàn Tụng Ca LUCA / Thành viên Ca Đoàn |
| Ode | Tụng Ca |
| Goliath(s) | Cự Thần |
| Goliath of Pyro / Hydro / Anemo / Geo | Cự Thần Hỏa / Thủy / Phong / Địa |
| Cion(s) | Tử Duệ |
| Pyro Cion / Geo Cion | Tử Duệ Hỏa / Tử Duệ Địa |
| Holy Grounds | Thánh Địa |
| Hallows | Thánh Khí |
| Primeval Glyphs | Cổ Văn Nguyên Thủy |
| Shenlong Glyphs | Cổ Văn Thần Long |
| Glyphs | Cổ Văn |
| Confluence | Hợp Lưu |
| Resonant(s) | Người Cộng Hưởng |
| Wanderer(s) | Kẻ Lang Thang |
| Madame | Cô Giáo (when Renee addresses her teacher) / Madame |
| Well / Well of Being / Well of Hydro | Giếng / Giếng Hiện Hữu / Giếng Thủy |
| Cloudworm | Sâu Mây |
| Dews | Giọt Sương |
| Memory Shards / Shards | Mảnh Ký Ức / Mảnh Vỡ |
| Great Explosion / Big Bang | Đại Bùng Nổ |
| Prism Bone / prismatic bones | Cốt Lăng Kính / xương lăng kính |
| Resting Town | Thị Trấn An Nghỉ |
| Rubiwood Desert / Village | Sa Mạc Rubiwood / Làng Rubiwood |
| Rainbow Plains | Bình Nguyên Cầu Vồng |
| Misty Waters | Vùng Nước Sương Mù |
| Sky Palace | Thiên Cung |
| Solar Birthplace | Nơi Sinh Của Mặt Trời |
| Albedo Tower | Tháp Albedo |
| Grand Archives | Đại Thư Viện |
| Sanctum | Thánh Điện |
| Gift | Ân Huệ |
| Reagent | Dược Liệu |
| Afterimage (the mechanic) | Afterimage |
| Talent | Thiên Phú |
| Echo | Dư Âm |
| Savepoint | Điểm Lưu |

### UI / gameplay vocabulary (keep consistent with the existing UI strings)
MENU `START GAME`=BẮT ĐẦU, `OPTIONS`=TÙY CHỌN, `QUIT GAME`=THOÁT GAME, `CONFIRM`=XÁC NHẬN, `CANCEL`=HỦY, `BACK`=QUAY LẠI,
`APPLY`=ÁP DỤNG, `YES`=CÓ, `NO`=KHÔNG, `SELECT`=CHỌN. Stats: HP=HP, MP=MP, `ATTACK`=TẤN CÔNG, `DEFENSE`=PHÒNG THỦ,
`CRITICAL`=CHÍ MẠNG, `EQUIPMENT`=TRANG BỊ, `SKILL`=KỸ NĂNG, `ITEM`=VẬT PHẨM, `MAP`=BẢN ĐỒ, `QUEST`=NHIỆM VỤ.


---

# PART 2 — Chinese → Vietnamese chunks (`work2/chunks/dNN.in.tsv`)

These strings come from the game's data tables (items, weapons, equipment, monsters, bosses, quests, NPC lines,
skill descriptions). There is **no English** for them in the file: translate from the Chinese.
Everything in Part 1 (hard rules, voice decisions, fixed terms) still applies.

- Input line: `ID<TAB>CHINESE`   Output line: `ID<TAB>VIETNAMESE`   (same order, same count, UTF-8 without BOM).
- `\n` / `\r` / `\t` escapes and `<tags>` / `{placeholders}` / `「…」` brackets: keep the escapes and tags exactly; `「…」` may be
  rendered as `"…"`.
- **Reference glossary:** `tools/afterimage/vi/zh_terms.tsv` lists ~1,000 Chinese names already translated elsewhere in the
  game (`中文<TAB>Tiếng Việt`). When a Chinese name appears there, use that Vietnamese exactly. Grep it before inventing a name.
- Item / monster / boss / weapon names are short noun phrases: translate naturally, Title Case (`Giày Dài Cánh Vũ`), no trailing full stop.
- Descriptions are flavour text or mechanics. Keep mechanics precise (numbers, "hit count", "after N hits").
  Keep the in-game wording used in Part 1 for stats: HP, MP, TẤN CÔNG, PHÒNG THỦ, CHÍ MẠNG, Giọt Sương (Dews),
  Cổ Văn (Glyphs), Hợp Lưu (Confluence), Afterimage (keep), Dòng Chảy (Stream).
- A line that is clearly development junk (animation id, file name, debug note, credits, repeated filler, a bare number) must be
  returned **unchanged**, so it never displays.
- Some lines are fragments of a longer sentence; translate the fragment as it stands.
