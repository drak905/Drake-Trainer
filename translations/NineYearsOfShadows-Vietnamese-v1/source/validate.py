import re, glob, sys, collections

SPK = {'Horned God': 'Thần Có Sừng', 'Spirit': 'Linh Hồn'}


def load(path_glob, untab=False):
    d = {}
    for f in sorted(glob.glob(path_glob)):
        for ln in open(f, encoding='utf-8'):
            ln = ln.rstrip('\n')
            if not ln or ln.startswith('#'):
                continue
            k, _, v = ln.partition('\t')
            if untab:
                v = v.replace('\u21e5', '\t')
            if k in d:
                print('DUP', k)
            d[k] = v
    return d


def toks(s):
    return collections.Counter(re.findall(r'\{\{?\d+\}?\}|<[^>]+>|\[[^\]]+\]', s))


def esc(s):
    return (s.count('\\r\\n'), s.count('\\n'))


def read_src(path, ui):
    src = {}
    for ln in open(path, encoding='utf-8'):
        ln = ln.rstrip('\n')
        if not ln or ln.startswith('#'):
            continue
        if ui:
            i, t, x = ln.split('\t', 2)
        else:
            i, _, x = ln.partition('\t')
        src[i] = x
    return src


def main(kind):
    if kind == 'ui':
        src = read_src('work/ui_src.tsv', True)
        vi = load('work/ui_vi_*.tsv')
    else:
        src = read_src('work/dlg_src.tsv', False)
        vi = load('work/dlg_vi_*.tsv', True)
    missing = [k for k in src if k not in vi]
    extra = [k for k in vi if k not in src]
    print('src', len(src), 'vi', len(vi), 'missing', len(missing), 'extra', extra[:5])
    bad = 0
    for k, v in vi.items():
        if k not in src:
            continue
        e = src[k]
        te, tv = toks(e), toks(v)
        probs = []
        if set(te) - set(tv):
            probs.append('lost tokens %s' % (set(te) - set(tv)))
        if set(tv) - set(te):
            probs.append('new tokens %s' % (set(tv) - set(te)))
        if kind == 'ui' and esc(e) != esc(v):
            probs.append('escapes %s vs %s' % (esc(e), esc(v)))
        if kind == 'dlg':
            se = e.split(':', 1)
            sv = v.split(':', 1)
            if len(sv) < 2:
                probs.append('no speaker colon')
            else:
                if SPK.get(se[0], se[0]) != sv[0]:
                    probs.append('speaker changed %r->%r' % (se[0], sv[0]))
                if ':' in sv[1]:
                    probs.append('colon in body')
            if e.count('\t') != v.count('\t'):
                probs.append('tabs')
        if e.strip() and not v.strip():
            probs.append('empty')
        if probs:
            bad += 1
            print(k, probs, '|', e[:60], '|', v[:60])
    print('problems', bad)
    if missing:
        print('first missing', missing[:10])


main(sys.argv[1])
