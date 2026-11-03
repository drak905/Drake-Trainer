"""Map Addressables scene keys -> bundle file names using catalog.json (no Unity needed)."""
import base64, json, struct, sys

AA = r"E:\GOGGalaxy\9 Years of Shadows\9 Years of Shadows_Data\StreamingAssets\aa"
c = json.load(open(AA + r"\catalog.json", encoding="utf-8"))
ids = c["m_InternalIds"]
keys_raw = base64.b64decode(c["m_KeyDataString"])
bucket_raw = base64.b64decode(c["m_BucketDataString"])
entry_raw = base64.b64decode(c["m_EntryDataString"])

# keys
keys = []
n = struct.unpack_from("<i", bucket_raw, 0)[0]
buckets = []
off = 4
for _ in range(n):
    key_off, entry_cnt = struct.unpack_from("<ii", bucket_raw, off)
    off += 8
    entries = struct.unpack_from("<" + "i" * entry_cnt, bucket_raw, off)
    off += 4 * entry_cnt
    buckets.append((key_off, entries))
for key_off, _ in buckets:
    t = keys_raw[key_off]
    if t == 0:  # ascii
        ln = keys_raw[key_off + 1]
        keys.append(keys_raw[key_off + 2:key_off + 2 + ln].decode("ascii"))
    elif t == 1:  # utf16
        ln = keys_raw[key_off + 1]
        keys.append(keys_raw[key_off + 2:key_off + 2 + ln].decode("utf-16-le"))
    else:
        keys.append("<type%d>" % t)

# entries: count + 7 ints each
ecount = struct.unpack_from("<i", entry_raw, 0)[0]
ents = []
for i in range(ecount):
    ents.append(struct.unpack_from("<7i", entry_raw, 4 + i * 28))  # internalId, provider, depKey, depHash, data, primaryKey, resType

res = {}
for bi, (key_off, entries) in enumerate(buckets):
    k = keys[bi]
    if not k.startswith("Assets/Scenes/"):
        continue
    for e in entries:
        iid, prov, depkey, *_ = ents[e]
        deps = []
        if depkey >= 0:
            for de in buckets[depkey][1]:
                deps.append(ids[ents[de][0]])
        res[k] = {"id": ids[iid], "deps": deps}
json.dump(res, sys.stdout, indent=1)
