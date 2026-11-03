"""Builds data/ui.tsv and data/dlg.tsv (embedded in the plugin) from the translation work files.

ui.tsv : <stringTag> TAB <vietnamese, with \\n \\r \\t \\\\ escapes>
dlg.tsv: <fnv1a64(english yarn line) as 16 hex> TAB <vietnamese yarn line, escaped>
"""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
os.chdir(ROOT)

EXTRA_UI = {  # tags that are missing from ui_src.tsv (their group name contains a trailing TAB in the game data)
    'ControlSettings_Control': 'Điều khiển ',
    'ControlSettings_Actions': 'Hành động',
    'ControlSettings_Controller': 'Tay cầm',
    'ControlSettings_QuickAttack': 'Đánh nhanh',
    'ControlSettings_Jump': 'Nhảy',
    'ControlSettings_Backdash': 'Lướt lùi',
    'ControlSettings_Shoot': 'Bắn',
    'ControlSettings_PrevArmor': 'Giáp trước',
    'ControlSettings_NextArmor': 'Giáp kế tiếp',
    'ControlSettings_Transform': 'Biến hình',
    'ControlSettings_StrongAttack': 'Đánh mạnh',
}


def fnv(s):
    h = 0xcbf29ce484222325
    for ch in s:
        h ^= ord(ch)
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return '%016x' % h


def esc(s):
    return s.replace('\\', '\\\\').replace('\r', '\\r').replace('\n', '\\n').replace('\t', '\\t')


def read_pairs(pattern, untab):
    d = {}
    for f in sorted(glob.glob(pattern)):
        for ln in open(f, encoding='utf-8'):
            ln = ln.rstrip('\n')
            if not ln or ln.startswith('#'):
                continue
            k, _, v = ln.partition('\t')
            if untab:
                v = v.replace('\u21e5', '\t')
            d[k] = v
    return d


# ---- UI (source file keeps the game's own escapes: \n and \r\n are already escaped there)
ui_src = {}
for ln in open('work/ui_src.tsv', encoding='utf-8'):
    ln = ln.rstrip('\n')
    if not ln:
        continue
    i, tag, en = ln.split('\t', 2)
    ui_src[i] = (tag, en)
ui_vi = read_pairs('work/ui_vi_*.tsv', False)
os.makedirs('data', exist_ok=True)
n_ui = 0
with open('data/ui.tsv', 'w', encoding='utf-8', newline='\n') as f:
    for i, (tag, en) in ui_src.items():
        vi = ui_vi[i]
        if not vi:
            continue
        f.write(tag + '\t' + vi + '\n')   # already in escaped form (\n etc.)
        n_ui += 1
    for tag, vi in EXTRA_UI.items():
        f.write(tag + '\t' + vi + '\n')
        n_ui += 1

# ---- dialogue
dlg_src = {}
for ln in open('work/dlg_src.tsv', encoding='utf-8'):
    ln = ln.rstrip('\n')
    if not ln or ln.startswith('#'):
        continue
    i, _, x = ln.partition('\t')
    dlg_src[i] = x
dlg_vi = read_pairs('work/dlg_vi_*.tsv', True)
n_d = 0
seen = {}
with open('data/dlg.tsv', 'w', encoding='utf-8', newline='\n') as f:
    for i, en in dlg_src.items():
        h = fnv(en)
        assert h not in seen, 'hash collision ' + i
        seen[h] = i
        f.write(h + '\t' + esc(dlg_vi[i]) + '\n')
        n_d += 1
print('ui entries', n_ui, 'dialogue entries', n_d)
