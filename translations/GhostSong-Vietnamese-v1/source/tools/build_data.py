"""Merge the translated chunks into the plugin data files.

  gs-vi/data/vi_dlg.tsv : <escaped CODE> TAB <escaped Vietnamese>        (LocalizationData CSV, column CONTENT)
  gs-vi/data/vi_ui.tsv  : <UItexty field name> TAB <escaped Vietnamese>  (UItexty.processlanguage fields)

Escaping is the same as in prep_src.py (\\\\, \\t, \\n, \\r).
Optional overrides: gs-vi/data/overrides_dlg.tsv / overrides_ui.tsv (id-less: key TAB text) win over the chunk output.
"""
import os, sys, glob
ROOT = r"E:\002.Github\043.ReverseEngine"
C = os.path.join(ROOT, "artifacts", "gsvi", "work", "chunks")
OUT = os.path.join(ROOT, "gs-vi", "data")
os.makedirs(OUT, exist_ok=True)

def read_lines(p):
    with open(p, encoding="utf-8", newline="") as f:
        return [l.rstrip("\r") for l in f.read().split("\n") if l != ""]

def load_vi(prefix):
    vi = {}
    for p in sorted(glob.glob(os.path.join(C, prefix + "_*.vi.tsv"))):
        for l in read_lines(p):
            i, t = l.split("\t", 1)
            vi[i] = t
    return vi

GAMESIGHT_VI = ("Bằng việc chọn “Đồng ý”, bạn cho phép Old Moon và Humble Games thu thập và xử lý các thông tin như địa chỉ IP và dữ liệu người chơi "
                "ẩn danh như hệ điều hành đang dùng, múi giờ, độ phân giải và ngôn ngữ hệ thống. Toàn bộ thông tin được xem xét ở dạng tổng hợp và giúp "
                "chúng tôi hiểu mức độ tương tác của người chơi nhằm cải thiện trải nghiệm chơi game của bạn. Chúng tôi có thể dùng bên xử lý thứ ba, chẳng "
                "hạn như các nền tảng phân tích, để hỗ trợ phân tích dữ liệu thu thập được.  Tuy nhiên, chúng tôi sẽ không bao giờ bán dữ liệu của bạn cho "
                "bên thứ ba nếu không có sự đồng ý của bạn.\\n\\nBạn có thể thay đổi cài đặt chia sẻ bất cứ lúc nào trong menu tùy chọn của game.\\n\\n"
                "Để biết thêm thông tin, vui lòng xem <color=#61AFF0><b>https://www.humblebundle.com/privacy</b></color>.")

def main():
    # ---- dialogue ----
    vi = load_vi("dlg")
    n = miss = 0
    with open(os.path.join(OUT, "vi_dlg.tsv"), "w", encoding="utf-8", newline="\n") as f:
        for l in read_lines(os.path.join(ROOT, "artifacts", "gsvi", "work", "dlg_src.tsv")):
            i, code, spk, eng = l.split("\t")
            t = vi.get(i)
            if t is None:
                miss += 1; continue
            f.write("%s\t%s\n" % (code, t)); n += 1
    print("vi_dlg.tsv: %d entries, %d missing" % (n, miss))
    # ---- UI ----
    vi = load_vi("ui")
    n = miss = 0
    names = []
    with open(os.path.join(OUT, "vi_ui.tsv"), "w", encoding="utf-8", newline="\n") as f:
        for l in read_lines(os.path.join(ROOT, "artifacts", "gsvi", "work", "ui_src.tsv")):
            i, field, eng = l.split("\t")
            t = vi.get(i)
            if t is None:
                miss += 1; continue
            f.write("%s\t%s\n" % (field, t)); n += 1; names.append(field)
        # the one English field built by string concatenation in the game (devname/pubname/policyurl), translated by hand
        f.write("gamesighttextbody\t%s\n" % GAMESIGHT_VI); n += 1
    print("vi_ui.tsv: %d entries, %d missing" % (n, miss))

if __name__ == "__main__":
    main()
