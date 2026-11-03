# Validates a translated chunk: python validate_chunk.py NN   (reads work/chunks/chunk_NN.in.json + chunk_NN.out.json)
# Checks: every id present exactly once, markup tokens (<...>, [var=..], {..}, [i2nt]) identical to the English,
# newline structure preserved, non-empty, Vietnamese diacritics sanity (no Chinese/Japanese leftovers, no mojibake).
import json, re, sys, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CH = os.path.join(ROOT, 'work', 'chunks')
TOKEN = re.compile(r'<[^>]*>|\[[^\]]*\]|\{[^}]*\}')


def tokens(s):
    return collections.Counter(TOKEN.findall(s))


def check(nn):
    src = json.load(open(os.path.join(CH, 'chunk_%s.in.json' % nn), encoding='utf-8'))
    out = json.load(open(os.path.join(CH, 'chunk_%s.out.json' % nn), encoding='utf-8'))
    errs = []
    got = {}
    for o in out:
        if o['id'] in got:
            errs.append('duplicate id %d' % o['id'])
        got[o['id']] = o['vi']
    for x in src:
        i, en = x['id'], x['en']
        if i not in got:
            errs.append('missing id %d: %r' % (i, en[:50]))
            continue
        vi = got[i]
        if not isinstance(vi, str) or not vi.strip():
            errs.append('empty vi id %d' % i)
            continue
        te, tv = tokens(en), tokens(vi)
        if te != tv:
            errs.append('markup mismatch id %d: en=%s vi=%s' % (i, dict(te - tv), dict(tv - te)))
        if en.count('\n') != vi.count('\n'):
            errs.append('newline count differs id %d (en %d, vi %d)' % (i, en.count('\n'), vi.count('\n')))
        if re.search(r'[\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af\u0400-\u04ff]', vi) and not re.search(r'[\u3040-\u30ff\u4e00-\u9fff\uac00-\ud7af\u0400-\u04ff]', en):
            errs.append('CJK/Cyrillic characters in id %d' % i)
        if '\ufffd' in vi or 'Ã' in vi or 'á»' in vi:
            errs.append('mojibake in id %d' % i)
    extra = set(got) - set(x['id'] for x in src)
    if extra:
        errs.append('unknown ids: %s' % sorted(extra)[:10])
    return errs, len(src)


if __name__ == '__main__':
    bad = 0
    for nn in sys.argv[1:]:
        errs, n = check(nn)
        print('chunk', nn, 'strings', n, 'errors', len(errs))
        for e in errs[:40]:
            print('  -', e)
        bad += len(errs)
    sys.exit(1 if bad else 0)
