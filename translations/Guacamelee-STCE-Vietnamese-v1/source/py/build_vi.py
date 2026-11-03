"""Build the Vietnamese misc.dat for Guacamelee! STCE.

usage: python build_vi.py <vanilla misc.dat> <out misc.dat> [--no-fonts]
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arc
import fontgen
import langio

WORK = os.environ.get('GCM_VI_DATA', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data'))
CHUNKS = os.path.join(WORK, 'chunks')
VI_NAME = 'Tiếng Việt'
TERM_FIX = {'Rooster Uppercut': 'Móc Gà Trống', 'Frog Slam': 'Đập Ếch', "Olmec's Headbutt": 'Húc Đầu Olmec',
            'Dashing Derpderp': 'Lướt Đấm', 'Pollo Bomb': 'Bom Gà'}


def load_translations():
    idx = json.load(open(os.path.join(CHUNKS, '_index.json'), encoding='utf-8'))
    tr = {}
    for f in sorted(glob.glob(os.path.join(CHUNKS, 'chunk_*.out.json'))):
        for d in json.load(open(f, encoding='utf-8')):
            tr[idx[str(d['id'])]] = d['vi']
    # post-processing overrides (terminology consistency etc.)
    ov = os.path.join(WORK, 'overrides.json')
    if os.path.exists(ov):
        o = json.load(open(ov, encoding='utf-8'))
        for en, vi in o.items():
            tr[en] = vi
    for en in list(tr):
        v = tr[en]
        for a, b in TERM_FIX.items():
            v = v.replace(a, b)
        tr[en] = v
    return tr


def decode_lang(raw):
    if raw[:2] == b'\xff\xfe':
        return langio.decode(raw)[0]
    return raw.decode('cp1252')          # langCostumes.txt ships as ANSI


def convert_lang(raw, tr, stats):
    t = decode_lang(raw)
    rows = langio.parse(t)
    hdr = [x[2] for x in rows[0]]
    ei = hdr.index('English')
    col = hdr.index('Japanese') if 'Japanese' in hdr else len(hdr)
    values = {}
    for ri, r in enumerate(rows):
        if ri == 0 or len(r) <= ei:
            continue
        en = r[ei][2]
        if not en.strip():
            continue
        raw = t[r[ei][0]:r[ei][1]]
        alt = raw[1:-1].replace('""', '"') if (len(raw) > 1 and raw[0] == '"' and raw[-1] == '"') else raw
        if en in tr:
            values[ri] = tr[en]
            stats['translated'] += 1
        elif alt in tr:
            values[ri] = tr[alt]
            stats['translated'] += 1
        else:
            values[ri] = en          # IDs, names, untranslatable text: keep the English text
            stats['copied'] += 1
    t2 = langio.set_column(t, rows, col, values, header_name='Vietnamese')
    return t2


def vi_general_row():
    cells = ['VietnameseLang', '', 'dnt (already translated)', ''] + [VI_NAME] * 6 + ['', VI_NAME, '']
    return '\t'.join(cells)


def build(src, dst, fonts=True):
    a = arc.Arc(src)
    tr = load_translations()
    stats = dict(translated=0, copied=0, fonts=0, glyphs=0)
    entries = []
    for i, name in enumerate(a.fullnames):
        raw = a.raw(i)
        low = name.lower()
        if re.match(r'misc\\lang(?!list).*\.txt$', low):
            data = a.data(i)
            text = convert_lang(data, tr, stats)
            if low == 'misc\\langgeneral.txt':
                if not text.endswith('\n'):
                    text += '\r\n'
                text += vi_general_row() + '\r\n'
            raw = arc.write_stream(langio.encode(text, True))
        elif low == 'misc\\platformregioninfo.ini':
            data = a.data(i)
            s = data.decode('latin1')
            assert 'EnableLanguages English French Italian German Spanish Portuguese' in s
            s = s.replace('EnableLanguages English French Italian German Spanish Portuguese',
                          'EnableLanguages English French Italian German Spanish Portuguese Vietnamese')
            raw = arc.write_stream(s.encode('latin1'))
        elif fonts and re.match(r'fonts\\.*\.latin\.fnt$', low):
            data = a.data(i)
            newdata, n = fontgen.extend_font(data)
            stats['fonts'] += 1
            stats['glyphs'] += n
            raw = arc.write_stream(newdata)
        entries.append((name, raw))
    # loading bar for the new language slot (reuses the English "LOADING..." bar unless a Vietnamese one exists)
    bar = os.path.join(WORK, 'Load_bar_vi.dds')
    if os.path.exists(bar):
        bar_data = open(bar, 'rb').read()
    else:
        bar_data = a.data(a.fullnames.index('.\\meshes\\textures\\Load_bar.dds'))
    entries.append(('.\\meshes\\textures\\Load_bar_Japanese.dds', arc.write_stream(bar_data)))
    arc.build_archive(dst, entries, a.unk)
    return stats


if __name__ == '__main__':
    src, dst = sys.argv[1:3]
    print(build(src, dst, fonts='--no-fonts' not in sys.argv))
