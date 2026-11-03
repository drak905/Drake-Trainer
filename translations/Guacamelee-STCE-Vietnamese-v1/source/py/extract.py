import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import arc

src, out = sys.argv[1], sys.argv[2]
a = arc.Arc(src)
os.makedirs(out, exist_ok=True)
ok = 0
idx = []
for i, n in enumerate(a.names):
    try:
        d = a.data(i)
    except Exception as e:
        print('ERR', i, n, repr(e)[:100])
        idx.append((i, n, 'ERR'))
        continue
    safe = n.replace('\\', '__').replace('/', '__').replace(':', '').replace('.__', '')
    p = os.path.join(out, '%04d_%s' % (i, safe))
    open(p, 'wb').write(d)
    idx.append((i, n, len(d)))
    ok += 1
print('extracted', ok, 'of', a.count)
open(os.path.join(out, '_index.txt'), 'w').write('\n'.join('%s\t%s\t%s' % x for x in idx))
