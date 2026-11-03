# Dead Cells — English → Vietnamese translation guide

Game: Dead Cells (Motion Twin / Evil Empire), a fast 2D roguelite action-platformer ("roguevania"). You play
**the Beheaded** (a mute, headless blob of cells that possesses a corpse in a prison of a cursed island). Every run
you fight through biomes, collect weapons, blueprints, cells and gold, and die a lot. Tone: tongue-in-cheek, dark
humour, lots of pop-culture jokes, snarky NPCs. Item descriptions are short, precise game mechanics text.
Includes DLCs: The Bad Seed, Fatal Falls, The Queen and the Sea, Return to Castlevania, Everyone is Here.

## File format
Input  `E:\002.Github\043.ReverseEngine\dc-vi\work\chunks\chunk_NN.in.json`:
`[{"id": 12, "en": "...", "ctx": "U29_FONT_CLASSIC"}, ...]` (`ctx` is optional, only a hint: a developer key or a
platform note such as "PS4 terminology"; never translate or output it).
Output `E:\002.Github\043.ReverseEngine\dc-vi\work\chunks\chunk_NN.out.json`:
`[{"id": 12, "vi": "..."}, ...]` — one entry for **every** input id, valid UTF-8 JSON (escape `"` as `\"`,
line breaks as `\n`). Write the file with a file-writing tool (not with shell echo/redirection, which breaks UTF-8).
Check with: `python E:\002.Github\043.ReverseEngine\dc-vi\tools\validate_chunk.py NN` — it must report 0 errors.

## Hard rules (the game breaks otherwise)
1. `::name::` placeholders (`::prct::`, `::duration::`, `::+dps2::`, `::*prct::`, `::key::`, `::user::` …) are replaced
   by numbers/names at run time. Copy them **exactly**, same count. Keep the `%` after `::prct::%`, keep `+`/`-` signs.
2. Colour tags `{text@CODE}` (e.g. `{critical hits@CC}`, `{bleed@BL}`, `{parry@PA}`, `{Brutality@BR}`): keep the braces
   and the `@CODE` exactly, **translate the text inside** (`{bleed@BL}` → `{chảy máu@BL}`). A placeholder inside a tag
   stays: `{::gold::@GO}`. Icon tags `{iconCoin@img}` stay completely unchanged. Same number of `{…}` as the English.
3. Button icons like `:a:` and `$power` stay unchanged. Keep the same number of `*` (used for *emphasis* and footnote
   stars) and the same number of line breaks `\n`.
4. Real Vietnamese with full diacritics, Unicode NFC (precomposed letters). No telex/unaccented text.
5. Translate everything, except proper names (see below), key names (Ctrl, Shift, Enter, Num *, F1…), brand names
   (Steam, Epic, Xbox, PlayStation, Nintendo Switch, DualSense, Joy-Con, Twitch, Discord, Motion Twin, Evil Empire),
   and strings that are only numbers/symbols.

## Style
- Natural, fluent game-localisation Vietnamese, not word for word. Keep the humour; adapt jokes/puns/pop-culture
  references into something that works in Vietnamese (an achievement title may stay in English only if it is a famous
  title, e.g. a song/film name, and a Vietnamese version would lose the joke).
- UI (menus, buttons, options, short labels): short, as compact as the English, sentence case
  ("Tiếp tục", "Thoát trò chơi", "Âm lượng nhạc"). Item/weapon/enemy/biome names: Title Case words
  ("Kiếm Roi", "Bù Nhìn", "Khu Giam Giữ").
- Item/mutation descriptions: concise mechanics language: "Gây ::prct::% sát thương…", "trong ::duration:: giây".
  "DPS" stays "DPS". "HP"/"health" → "máu". "Cooldown" → "hồi chiêu". "Damage" → "sát thương".
- Address the player as **"bạn"** in UI/tutorial/system text.
- NPC dialogue: the Collector, the Time Keeper, the Queen, Dracula, Death and other bosses or arrogant characters speak
  **"ta – ngươi"**; friendly/common NPCs (the Blacksmith, Guillain, the Tailor, the Gardener, villagers, prisoners)
  use **"tôi – bạn/anh"** or casual "tao – mày" only for rude goons. Keep one speaker consistent inside a chunk.
- Numbers, "x2", "+1", percentages unchanged.

## Glossary (use these exact renderings)
| English | Vietnamese |
|---|---|
| Dead Cells (game title) | Dead Cells |
| the Beheaded / Beheaded | Kẻ Mất Đầu |
| Prisoner / prisoners | tù nhân |
| Cell(s) (currency) | Tế bào |
| Boss Cell / Boss Stem Cell | Tế Bào Trùm / Tế Bào Gốc Trùm |
| Boss / Boss Rush | Trùm / Đấu Trùm Liên Hoàn |
| Gold | vàng |
| Blueprint | Bản thiết kế |
| Mutation | Đột biến |
| Rune (Vine, Teleportation, Ram, Spider, Challenger, Homunculus, Explorer's Rune) | Ấn (Ấn Dây Leo, Ấn Dịch Chuyển, Ấn Húc, Ấn Nhện, Ấn Thách Đấu, Ấn Homunculus, Ấn Thám Hiểm) |
| Scroll of Power / Scroll | Cuộn Giấy Sức Mạnh / Cuộn giấy |
| Brutality / Tactics / Survival (stats, colours) | Bạo Lực / Chiến Thuật / Sinh Tồn |
| Health Flask / flask | Bình Máu / bình máu |
| Curse / Cursed / Cursed Chest | Lời nguyền / bị nguyền / Rương Bị Nguyền |
| Malaise | Dịch Bệnh |
| Forge / Blacksmith | Lò Rèn / Thợ Rèn |
| Outfit / Head / Skin | Trang phục / Đầu / Ngoại hình |
| Aspect | Khía Cạnh |
| Melee weapon / Ranged weapon / Shield | Vũ khí cận chiến / Vũ khí tầm xa / Khiên |
| Skill / Grenade / Trap / Turret / Power | Kỹ năng / Lựu đạn / Bẫy / Tháp pháo / Năng lực |
| Amulet / Pendant | Bùa hộ mệnh / Mặt dây chuyền |
| Food / Recycle | Đồ ăn / Tái chế |
| critical hit / critical damage | đòn chí mạng / sát thương chí mạng |
| bleed / burn / poison / freeze / root / stun / shock / oil / toxic cloud / slow | chảy máu / thiêu đốt / độc / đóng băng / trói chân / choáng / điện giật / dầu / mây độc / làm chậm |
| parry / roll / dodge / block | đỡ đòn / lăn / né / chặn |
| Elite / elite enemy | Tinh Anh / kẻ địch tinh anh |
| Timed door | Cửa hẹn giờ |
| Legendary | Huyền thoại |
| bonus health | máu thưởng |
| Daily Challenge / Custom Mode / Assist Mode / Speedrun Mode | Thử Thách Hằng Ngày / Chế Độ Tùy Chỉnh / Chế Độ Hỗ Trợ / Chế Độ Speedrun |
| Achievement | Thành tựu |
| Options / Controls / Gameplay / Video / Audio / Language | Tùy chọn / Điều khiển / Lối chơi / Hình ảnh / Âm thanh / Ngôn ngữ |
| Play / Continue / New game / Quit / Back / Yes / No / On / Off | Chơi / Tiếp tục / Trò chơi mới / Thoát / Quay lại / Có / Không / Bật / Tắt |
| Keyboard / Controller / Gamepad | Bàn phím / Tay cầm / Tay cầm |

### Places (biomes)
| English | Vietnamese |
|---|---|
| Prisoners' Quarters | Khu Giam Giữ |
| Promenade of the Condemned | Lối Dạo Của Kẻ Bị Kết Án |
| Toxic Sewers / Ancient Sewers | Cống Ngầm Độc Hại / Cống Ngầm Cổ |
| Dilapidated Arboretum | Vườn Cây Đổ Nát |
| Prison Depths / Corrupted Prison | Đáy Ngục / Nhà Ngục Mục Ruỗng |
| Ramparts | Tường Thành |
| Ossuary | Hầm Hài Cốt |
| Black Bridge | Cầu Đen |
| Insufferable Crypt | Hầm Mộ Ngột Ngạt |
| Morass of the Banished | Đầm Lầy Kẻ Bị Lưu Đày |
| Nest | Tổ |
| Stilt Village | Làng Nhà Sàn |
| Slumbering Sanctuary | Thánh Địa Say Ngủ |
| Graveyard | Nghĩa Địa |
| Clock Tower / Clock Room | Tháp Đồng Hồ / Phòng Đồng Hồ |
| Forgotten Sepulcher | Lăng Mộ Bị Lãng Quên |
| Cavern / Guardian's Haven | Hang Động / Nơi Trú Của Hộ Vệ |
| High Peak Castle / Throne Room | Lâu Đài Đỉnh Cao / Phòng Ngai Vàng |
| Astrolab / Observatory | Đài Chiêm Tinh / Đài Quan Sát |
| Fractured Shrines | Đền Thờ Rạn Vỡ |
| Undying Shores / Mausoleum | Bờ Biển Bất Tử / Lăng Tẩm |
| Castle's Outskirts / Defiled Necropolis / Dracula's Castle / Master's Keep | Ngoại Ô Lâu Đài / Nghĩa Trang Ô Uế / Lâu Đài Dracula / Thành Trì Của Chủ Nhân |
| Derelict Distillery | Xưởng Chưng Cất Bỏ Hoang |
| Infested Shipwreck / Lighthouse / The Crown | Xác Tàu Nhiễm Độc / Ngọn Hải Đăng / Vương Miện |
| The Bank | Ngân Hàng |
| Castle / Island | Lâu đài / Hòn đảo |

### Characters
| English | Vietnamese |
|---|---|
| The Collector | Nhà Sưu Tầm |
| The King / The Queen / The Hand of the King | Nhà Vua / Nữ Hoàng / Cánh Tay Của Nhà Vua |
| The Concierge | Gã Gác Cổng |
| The Time Keeper | Người Giữ Thời Gian |
| The Giant | Gã Khổng Lồ |
| Scarecrow / Mama Tick / Conjunctivius | Bù Nhìn / Mama Tick / Conjunctivius |
| The Servants | Đám Hầu Cận |
| Death / Dracula / Richter Belmont / Alucard / Maria (Renard) | Thần Chết / Dracula / Richter Belmont / Alucard / Maria |
| The Tailor / The Gardener / Guillain | Thợ May / Người Làm Vườn / Guillain |
| Zombie / Undead Archer / Grenadier / Inquisitor / Kamikaze | Xác Sống / Cung Thủ Xác Sống / Lính Ném Lựu / Thẩm Phán Dị Giáo / Kamikaze |

Other proper names (people, monsters with invented names, Castlevania weapon names such as "Vampire Killer") stay
unchanged; descriptive enemy and item names are translated (e.g. "Whip Sword" → "Kiếm Roi", "Scythe Claw" →
"Vuốt Lưỡi Hái", "Toothpick" → "Tăm Xỉa Răng", "Stun Grenade" → "Lựu Đạn Gây Choáng"). If the same name appears in
your chunk several times, translate it the same way every time.
