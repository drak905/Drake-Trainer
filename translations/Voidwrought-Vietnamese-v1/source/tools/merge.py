# Merges work/chunks/chunk_NN.out.json -> work/vi_map.json and src/vi.tsv (embedded in the plugin).
# TSV line:  <fnv1a64(en) as 16 hex>\t<escaped vi>      escapes: \\ \n \r \t
import json, os, re, glob, collections, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = os.path.join(ROOT, 'work')
items = json.load(open(os.path.join(W, 'strings.json'), encoding='utf-8'))
by_id = {x['id']: x['en'] for x in items}
vi = {}
for p in sorted(glob.glob(os.path.join(W, 'chunks', 'chunk_*.out.json'))):
    for o in json.load(open(p, encoding='utf-8')):
        assert o['id'] in by_id, (p, o['id'])
        assert o['id'] not in vi, ('dup', o['id'])
        vi[o['id']] = unicodedata.normalize('NFC', o['vi'])

TOKEN = re.compile(r'<[^>]*>|\[[^\]]*\]|\{[^}]*\}')


def needs_tr(s):
    t = TOKEN.sub('', s)
    return re.search(r'[A-Za-z]', t) is not None


def fnv1a64(s):
    h = 0xcbf29ce484222325
    for ch in s:
        for b in (ord(ch) & 0xFF, (ord(ch) >> 8) & 0xFF):   # UTF-16 code units, little endian
            h ^= b
            h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


def utf16_units(s):
    # match C# string (UTF-16) iteration for astral chars
    out = []
    for ch in s:
        o = ord(ch)
        if o > 0xFFFF:
            o -= 0x10000
            out += [0xD800 + (o >> 10), 0xDC00 + (o & 0x3FF)]
        else:
            out.append(o)
    return out


def fnv(s):
    h = 0xcbf29ce484222325
    for u in utf16_units(s):
        h ^= u
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


missing = [i for i, en in by_id.items() if needs_tr(en) and i not in vi]
print('translated', len(vi), 'missing', len(missing), missing[:10])
for i, en in by_id.items():
    if i not in vi:
        vi[i] = en            # no letters -> identity

# sanity: untranslated long strings, diacritic presence
same = [(i, by_id[i]) for i in vi if vi[i] == by_id[i] and needs_tr(by_id[i]) and len(by_id[i].split()) > 3]
print('identical (>3 words):', len(same))
for i, s in same[:15]:
    print('   ', i, s[:80].replace('\n', ' '))
noacc = [i for i in vi if needs_tr(by_id[i]) and len(by_id[i]) > 60 and not re.search(r'[À-ỹ]', vi[i])]
print('long strings without any Vietnamese letter:', len(noacc), noacc[:10])

# hash collision check + write
hashes = {}
for i, en in by_id.items():
    h = fnv(en)
    assert h not in hashes or hashes[h] == en, ('collision', en, hashes[h])
    hashes[h] = en
json.dump({by_id[i]: vi[i] for i in vi}, open(os.path.join(W, 'vi_map.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)


def esc(s):
    return s.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')


os.makedirs(os.path.join(ROOT, 'src'), exist_ok=True)
with open(os.path.join(ROOT, 'src', 'vi.tsv'), 'w', encoding='utf-8', newline='\n') as f:
    for i in sorted(vi):
        f.write('%016x\t%s\n' % (fnv(by_id[i]), esc(vi[i])))
print('wrote', len(vi), 'entries ->', os.path.join(ROOT, 'src', 'vi.tsv'), os.path.getsize(os.path.join(ROOT, 'src', 'vi.tsv')), 'bytes')
