#!/usr/bin/env python3
"""
Find the Construct 3 runtime instance by pausing the runtime worker and
walking the scope chain.

The runtime lives in ES-module scope inside workermain.js, so it is not
reachable from globalThis. Pausing execution exposes the module/closure scopes
via Debugger.paused -> callFrames[].scopeChain, which we can enumerate with
Runtime.getProperties.
"""
import json
import sys
import time

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from solcesto_cdp import CDP, browser_ws  # noqa: E402

TARGET_URL = "workermain.js"


class Session:
    def __init__(self):
        self.cdp = CDP(browser_ws())
        self.cdp.ws.sock.settimeout(1.0)
        self.events = []

    def send(self, method, params=None, session_id=None):
        self.cdp._id += 1
        msg = {"id": self.cdp._id, "method": method, "params": params or {}}
        if session_id:
            msg["sessionId"] = session_id
        self.cdp.ws.send(json.dumps(msg))
        return self.cdp._id

    def wait(self, want_id=None, want_method=None, timeout=10.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                raw = self.cdp.ws.recv()
            except Exception:
                continue
            msg = json.loads(raw)
            if msg.get("method"):
                self.events.append(msg)
                if want_method and msg["method"] == want_method:
                    return msg
            if want_id is not None and msg.get("id") == want_id:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg.get("result", {})
        raise TimeoutError(f"timeout waiting id={want_id} method={want_method}")

    def call(self, method, params=None, session_id=None, timeout=10.0):
        return self.wait(self.send(method, params, session_id), timeout=timeout)

    def close(self):
        self.cdp.close()


def main():
    s = Session()
    try:
        targets = s.call("Target.getTargets")["targetInfos"]
        page = next(t for t in targets if t["type"] == "page")
        page_sess = s.call("Target.attachToTarget",
                          {"targetId": page["targetId"], "flatten": True})["sessionId"]
        s.call("Target.setAutoAttach", {
            "autoAttach": True, "waitForDebuggerOnStart": False, "flatten": True,
        }, session_id=page_sess)

        # collect auto-attached worker sessions
        try:
            s.wait(want_method=None, timeout=3)
        except TimeoutError:
            pass
        worker_sess = None
        for ev in s.events:
            if ev.get("method") != "Target.attachedToTarget":
                continue
            ti = ev["params"].get("targetInfo", {})
            if TARGET_URL in (ti.get("url") or ""):
                worker_sess = ev["params"]["sessionId"]
        if not worker_sess:
            print("runtime worker session not found")
            return 1
        print(f"runtime worker session: {worker_sess}")

        s.call("Runtime.enable", session_id=worker_sess)
        s.call("Debugger.enable", session_id=worker_sess)

        # Pause and grab the scope chain
        s.send("Debugger.pause", session_id=worker_sess)
        paused = s.wait(want_method="Debugger.paused", timeout=15)
        frames = paused["params"]["callFrames"]
        print(f"paused with {len(frames)} call frames")

        found = []
        for fi, fr in enumerate(frames[:6]):
            fn = fr.get("functionName") or "(anon)"
            url = fr.get("url") or ""
            print(f"\nframe {fi}: {fn}  {url.split('/')[-1]}")
            for sc in fr.get("scopeChain", []):
                stype = sc.get("type")
                if stype not in ("closure", "module", "script", "local", "global"):
                    continue
                obj = sc.get("object", {})
                oid = obj.get("objectId")
                if not oid:
                    continue
                try:
                    props = s.call("Runtime.getProperties", {
                        "objectId": oid, "ownProperties": True,
                    }, session_id=worker_sess, timeout=8).get("result", [])
                except Exception as e:
                    print(f"  [{stype}] getProperties failed: {e}")
                    continue
                names = []
                for p in props:
                    nm = p.get("name")
                    val = p.get("value", {})
                    cls = val.get("className") or val.get("type")
                    names.append(f"{nm}:{cls}")
                    # heuristics for the runtime object
                    if cls and any(k in str(cls) for k in ("Runtime", "C3Runtime")):
                        found.append((stype, nm, cls, val.get("objectId")))
                if names:
                    print(f"  [{stype}] {len(names)} props: {names[:25]}")

        print("\n=== runtime-looking objects ===")
        for f in found:
            print(f"  scope={f[0]} name={f[1]} class={f[2]}")
            print(f"    objectId={f[3]}")

        s.send("Debugger.resume", session_id=worker_sess)
        time.sleep(0.5)
        print("\nresumed")
    finally:
        s.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
