#!/usr/bin/env python3
"""
Evaluate JavaScript inside Construct 3's runtime Web Worker.

Attaching to a worker straight from the browser target yields a sessionId that
never responds. The working route is:

    browser -> attach to PAGE (flatten)
            -> Target.setAutoAttach on the page session
            -> receive Target.attachedToTarget events carrying usable sessionIds

Usage:
    python worker_eval.py <file.js>     # run JS in every attached worker
    python worker_eval.py --probe       # locate the C3 runtime + list globals
"""
import json
import sys
import time

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from solcesto_cdp import CDP, browser_ws, WORKER_PROBE_JS  # noqa: E402


def pump(cdp, want_id=None, collect_events=None, timeout=8.0):
    """Read frames until we see want_id, collecting named events meanwhile."""
    deadline = time.time() + timeout
    cdp.ws.sock.settimeout(1.0)
    while time.time() < deadline:
        try:
            raw = cdp.ws.recv()
        except Exception:
            continue
        msg = json.loads(raw)
        method = msg.get("method")
        if collect_events is not None and method in collect_events:
            collect_events[method].append(msg.get("params", {}))
        if want_id is not None and msg.get("id") == want_id:
            if "error" in msg:
                raise RuntimeError(msg["error"])
            return msg.get("result", {})
    if want_id is not None:
        raise TimeoutError(f"no reply for id={want_id}")
    return None


def send(cdp, method, params=None, session_id=None):
    cdp._id += 1
    msg = {"id": cdp._id, "method": method, "params": params or {}}
    if session_id:
        msg["sessionId"] = session_id
    cdp.ws.send(json.dumps(msg))
    return cdp._id


def main(argv):
    js = WORKER_PROBE_JS
    if len(argv) > 1 and argv[1] != "--probe":
        with open(argv[1], "r", encoding="utf-8") as fh:
            js = fh.read()

    cdp = CDP(browser_ws())
    events = {"Target.attachedToTarget": []}
    try:
        # 1. find the page target
        mid = send(cdp, "Target.getTargets")
        targets = pump(cdp, mid, events)["targetInfos"]
        page = next(t for t in targets if t["type"] == "page")
        print(f"page target: {page['targetId']}  {page.get('url')}")

        # 2. attach to the page with a flat session
        mid = send(cdp, "Target.attachToTarget",
                   {"targetId": page["targetId"], "flatten": True})
        page_sess = pump(cdp, mid, events)["sessionId"]
        print(f"page session: {page_sess}")

        # 3. ask the PAGE session to auto-attach its workers
        mid = send(cdp, "Target.setAutoAttach", {
            "autoAttach": True,
            "waitForDebuggerOnStart": False,
            "flatten": True,
        }, session_id=page_sess)
        try:
            pump(cdp, mid, events, timeout=10)
        except Exception as e:
            print(f"setAutoAttach: {e}")

        # 4. drain a moment so attachedToTarget events arrive
        pump(cdp, None, events, timeout=3)

        attached = events["Target.attachedToTarget"]
        print(f"\nauto-attached sessions: {len(attached)}")
        for p in attached:
            ti = p.get("targetInfo", {})
            print(f"  [{ti.get('type')}] session={p.get('sessionId')} url={ti.get('url')!r}")

        # 5. evaluate in each worker session
        found_any = False
        for p in attached:
            ti = p.get("targetInfo", {})
            if ti.get("type") not in ("worker", "shared_worker"):
                continue
            sess = p["sessionId"]
            print(f"\n=== worker session {sess} url={ti.get('url')!r}")
            send(cdp, "Runtime.enable", session_id=sess)
            mid = send(cdp, "Runtime.evaluate", {
                "expression": js, "returnByValue": True, "awaitPromise": True,
            }, session_id=sess)
            try:
                res = pump(cdp, mid, events, timeout=8)
            except Exception as e:
                print(f"    eval failed: {e}")
                continue
            if res.get("exceptionDetails"):
                print(f"    exception: {res['exceptionDetails'].get('text')}")
                continue
            val = res.get("result", {}).get("value")
            found_any = True
            try:
                info = json.loads(val)
            except Exception:
                print(f"    {val}")
                continue
            # Dump everything; different probes return different shapes.
            txt = json.dumps(info, indent=2)
            for line in txt.splitlines():
                print("    " + line)
        if not found_any:
            print("\nNo worker responded.")
    finally:
        cdp.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
