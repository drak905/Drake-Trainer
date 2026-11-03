"""Report strings whose English contains a glossary term but whose Vietnamese lacks the fixed rendering."""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = os.path.join(ROOT, "work", "chunks")
TERMS = {
    "Prisoners' Quarters": "Khu Giam Giữ",
    "Promenade of the Condemned": "Lối Dạo Của Kẻ Bị Kết Án",
    "Toxic Sewers": "Cống Ngầm Độc Hại",
    "Ancient Sewers": "Cống Ngầm Cổ",
    "Dilapidated Arboretum": "Vườn Cây Đổ Nát",
    "Prison Depths": "Đáy Ngục",
    "Corrupted Prison": "Nhà Ngục Mục Ruỗng",
    "Ramparts": "Tường Thành",
    "Ossuary": "Hầm Hài Cốt",
    "Black Bridge": "Cầu Đen",
    "Insufferable Crypt": "Hầm Mộ Ngột Ngạt",
    "Morass of the Banished": "Đầm Lầy Kẻ Bị Lưu Đày",
    "Stilt Village": "Làng Nhà Sàn",
    "Slumbering Sanctuary": "Thánh Địa Say Ngủ",
    "Graveyard": "Nghĩa Địa",
    "Clock Tower": "Tháp Đồng Hồ",
    "Clock Room": "Phòng Đồng Hồ",
    "Forgotten Sepulcher": "Lăng Mộ Bị Lãng Quên",
    "Guardian's Haven": "Nơi Trú Của Hộ Vệ",
    "High Peak Castle": "Lâu Đài Đỉnh Cao",
    "Throne Room": "Phòng Ngai Vàng",
    "Astrolab": "Đài Chiêm Tinh",
    "Observatory": "Đài Quan Sát",
    "Fractured Shrines": "Đền Thờ Rạn Vỡ",
    "Undying Shores": "Bờ Biển Bất Tử",
    "Mausoleum": "Lăng Tẩm",
    "Castle's Outskirts": "Ngoại Ô Lâu Đài",
    "Defiled Necropolis": "Nghĩa Trang Ô Uế",
    "Dracula's Castle": "Lâu Đài Dracula",
    "Master's Keep": "Thành Trì Của Chủ Nhân",
    "Derelict Distillery": "Xưởng Chưng Cất Bỏ Hoang",
    "Infested Shipwreck": "Xác Tàu Nhiễm Độc",
    "Lighthouse": "Ngọn Hải Đăng",
    "Collector": "Nhà Sưu Tầm",
    "Concierge": "Gã Gác Cổng",
    "Time Keeper": "Người Giữ Thời Gian",
    "Beheaded": "Kẻ Mất Đầu",
    "Boss Cell": "Tế Bào Trùm",
    "Malaise": "Dịch Bệnh",
    "Blueprint": "Bản thiết kế",
    "Scroll of Power": "Cuộn Giấy Sức Mạnh",
    "Daily Challenge": "Thử Thách Hằng Ngày",
    "Custom Mode": "Chế Độ Tùy Chỉnh",
    "Hand of the King": "Cánh Tay Của Nhà Vua",
}

bad = 0
for f in sorted(glob.glob(os.path.join(CH, "chunk_*.in.json"))):
    nn = os.path.basename(f)[6:-8]
    out = {o["id"]: o["vi"] for o in json.load(open(f.replace(".in.", ".out."), encoding="utf-8"))}
    for x in json.load(open(f, encoding="utf-8")):
        vi = out.get(x["id"], "")
        for en, v in TERMS.items():
            if re.search(r"(?<![A-Za-z])" + re.escape(en), x["en"], re.I) and v.lower() not in vi.lower():
                bad += 1
                print(f"{nn} id {x['id']} [{en} -> {v}]\n   en: {x['en'][:160]!r}\n   vi: {vi[:160]!r}")
print("issues", bad, file=sys.stderr)
