#!/usr/bin/env python3
"""Debug worker attachment: dump target info and watch raw CDP traffic."""
import json
import sys

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from solcesto_cdp import CDP, browser_ws, http_targets  # noqa: E402

cdp = CDP(browser_ws())
cdp.ws.sock.settimeout(25)

targets = cdp.call("Target.getTargets").get("targetInfos", [])
print("=== ALL TARGETS ===")
for t in targets:
    print(json.dumps(t))

workers = [t for t in targets if t.get("type") == "worker"]
print(f"\n=== attaching to {len(workers)} worker(s) ===")

for t in workers:
    tid = t["targetId"]
    print(f"\n--- target {tid}  url={t.get('url')!r}")
    try:
        res = cdp.call("Target.attachToTarget", {"targetId": tid, "flatten": True})
        sess = res.get("sessionId")
        print(f"    sessionId = {sess!r}")
    except Exception as e:
        print(f"    attach error: {e}")
        continue

    # Send a trivial evaluate and dump every frame that comes back.
    cdp._id += 1
    mid = cdp._id
    cdp.ws.send(json.dumps({
        "id": mid,
        "sessionId": sess,
        "method": "Runtime.evaluate",
        "params": {"expression": "1+1", "returnByValue": True},
    }))
    print(f"    sent Runtime.evaluate id={mid}, listening...")
    for _ in range(6):
        try:
            raw = cdp.ws.recv()
        except Exception as e:
            print(f"    recv error: {e}")
            break
        msg = json.loads(raw)
        print(f"    <- {raw[:300]}")
        if msg.get("id") == mid:
            print("    GOT RESPONSE")
            break

cdp.close()
