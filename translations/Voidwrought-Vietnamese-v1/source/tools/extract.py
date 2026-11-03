# Builds the translation work set from the runtime dump (vw-vi/dumpdata/terms.jsonl) -> vw-vi/work/chunks/chunk_NN.in.json
# Every unique English text term value gets a stable integer id. Output: work/strings.json (id -> en) + chunk files.
import json, re, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'dumpdata')
W = os.path.join(ROOT, 'work')
os.makedirs(os.path.join(W, 'chunks'), exist_ok=True)

src = json.loads(open(os.path.join(D, 'terms.jsonl'), encoding='utf-8').read())
terms = src['terms']

occ = {}   # en -> [first_order, [term keys]]
for n, t in enumerate(terms):
    if t['ty'] != 0 or not t['v']:
        continue
    en = t['v'][0]
    if not en or not en.strip():
        continue
    if en not in occ:
        occ[en] = [n, []]
    occ[en][1].append(t['t'])

order = sorted(occ.items(), key=lambda kv: kv[1][0])
items = []
for i, (en, (n, keys)) in enumerate(order):
    ctx = 'term ' + keys[0] + (' (+%d more)' % (len(keys) - 1) if len(keys) > 1 else '')
    items.append({'id': i, 'ctx': ctx, 'en': en})


def needs_tr(s):
    t = re.sub(r'<[^>]*>|\[[^\]]*\]|\{[^}]*\}', '', s)
    return re.search(r'[A-Za-z]', t) is not None


todo = [x for x in items if needs_tr(x['en'])]
skip = [x for x in items if not needs_tr(x['en'])]
json.dump(items, open(os.path.join(W, 'strings.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
print('unique', len(items), 'to translate', len(todo), 'skipped (no letters)', len(skip))

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 11000
chunks, cur, cl = [], [], 0
for x in todo:
    n = len(x['en']) + len(x['ctx']) + 30
    if cur and cl + n > LIMIT:
        chunks.append(cur); cur, cl = [], 0
    cur.append(x); cl += n
if cur:
    chunks.append(cur)
for f in os.listdir(os.path.join(W, 'chunks')):
    if f.endswith('.in.json'):
        os.remove(os.path.join(W, 'chunks', f))
for i, c in enumerate(chunks):
    p = os.path.join(W, 'chunks', 'chunk_%02d.in.json' % i)
    json.dump(c, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(os.path.basename(p), len(c), 'strings', sum(len(x['en']) for x in c), 'chars')
