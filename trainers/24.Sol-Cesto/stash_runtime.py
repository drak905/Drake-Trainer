#!/usr/bin/env python3
"""
Capture Construct 3's runtime + EventSheetManager and pin them to globalThis.

Pausing the runtime worker exposes call frames whose locals include
C3.EventSheetManager (owner of global variables) and whose `this` is the
C3.Runtime. Object IDs die on resume, so while still paused we assign both
onto globalThis. After that, ordinary Runtime.evaluate can read and write game
state for the rest of the session.

    python stash_runtime.py            # stash, then dump global variables
    python stash_runtime.py --dump     # just dump (assumes already stashed)
"""
import json
import sys
import time

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from solcesto_cdp import CDP, browser_ws  # noqa: E402

WORKER_URL = "workermain.js"

DUMP_JS = r"""
(() => {
  const rt = globalThis.__c3rt, esm = globalThis.__c3esm;
  const out = { hasRt: !!rt, hasEsm: !!esm, rtClass: null, vars: [], errors: [] };
  try { out.rtClass = rt && rt.constructor && rt.constructor.name; } catch (e) {}
  try {
    let vars = null;
    if (esm) {
      vars = esm._allGlobalVars ||
             (esm.GetAllGlobalVariables && esm.GetAllGlobalVariables());
    }
    if (!vars && rt) {
      const m = rt._eventSheetManager ||
                (rt.GetEventSheetManager && rt.GetEventSheetManager());
      if (m) vars = m._allGlobalVars ||
                    (m.GetAllGlobalVariables && m.GetAllGlobalVariables());
    }
    if (vars) {
      out.vars = Array.from(vars).map(v => ({
        name:  (v._name  !== undefined) ? v._name  : (v.GetName  && v.GetName()),
        value: (v._value !== undefined) ? v._value : (v.GetValue && v.GetValue()),
        type:  (v._type  !== undefined) ? String(v._type) : undefined,
      }));
    }
  } catch (e) { out.errors.push(String(e)); }
  return JSON.stringify(out);
})()
"""


class S:
    def __init__(self):
        self.cdp = CDP(browser_ws())
        self.cdp.ws.sock.settimeout(1.0)
        self.events = []

    def send(self, m, p=None, sess=None):
        self.cdp._id += 1
        msg = {"id": self.cdp._id, "method": m, "params": p or {}}
        if sess:
            msg["sessionId"] = sess
        self.cdp.ws.send(json.dumps(msg))
        return self.cdp._id

    def wait(self, want_id=None, want_method=None, timeout=12.0):
        end = time.time() + timeout
        while time.time() < end:
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
        raise TimeoutError(f"timeout id={want_id} method={want_method}")

    def call(self, m, p=None, sess=None, timeout=12.0):
        return self.wait(self.send(m, p, sess), timeout=timeout)

    def close(self):
        self.cdp.close()


def worker_session(s):
    targets = s.call("Target.getTargets")["targetInfos"]
    page = next(t for t in targets if t["type"] == "page")
    ps = s.call("Target.attachToTarget",
                {"targetId": page["targetId"], "flatten": True})["sessionId"]
    s.call("Target.setAutoAttach",
           {"autoAttach": True, "waitForDebuggerOnStart": False, "flatten": True},
           sess=ps)
    try:
        s.wait(timeout=3)
    except TimeoutError:
        pass
    for ev in s.events:
        if ev.get("method") == "Target.attachedToTarget":
            ti = ev["params"].get("targetInfo", {})
            if WORKER_URL in (ti.get("url") or ""):
                return ev["params"]["sessionId"]
    return None


def evaluate(s, sess, js):
    r = s.call("Runtime.evaluate",
               {"expression": js, "returnByValue": True, "awaitPromise": True},
               sess=sess)
    if r.get("exceptionDetails"):
        raise RuntimeError(r["exceptionDetails"].get("text"))
    return r.get("result", {}).get("value")


def stash(s, sess):
    """Pause, find useful frames, pin references to globalThis, resume."""
    s.call("Runtime.enable", sess=sess)
    s.call("Debugger.enable", sess=sess)
    s.send("Debugger.pause", sess=sess)
    paused = s.wait(want_method="Debugger.paused", timeout=15)
    frames = paused["params"]["callFrames"]

    esm_frame = esm_var = None
    tick_frame = None
    for fr in frames:
        for sc in fr.get("scopeChain", []):
            if sc.get("type") != "local":
                continue
            oid = sc.get("object", {}).get("objectId")
            if not oid:
                continue
            try:
                props = s.call("Runtime.getProperties",
                               {"objectId": oid, "ownProperties": True},
                               sess=sess, timeout=8).get("result", [])
            except Exception:
                continue
            for p in props:
                cls = (p.get("value") or {}).get("className") or ""
                if "EventSheetManager" in cls:
                    esm_frame, esm_var = fr["callFrameId"], p["name"]
        if fr.get("functionName") == "Tick":
            tick_frame = fr["callFrameId"]

    print(f"esm frame found: {bool(esm_frame)} (var {esm_var!r})")
    print(f"tick frame found: {bool(tick_frame)}")

    def on_frame(cf, expr):
        r = s.call("Debugger.evaluateOnCallFrame",
                   {"callFrameId": cf, "expression": expr, "returnByValue": True},
                   sess=sess, timeout=10)
        if r.get("exceptionDetails"):
            return f"exc: {r['exceptionDetails'].get('text')}"
        return r.get("result", {}).get("value")

    if esm_frame:
        print("stash esm ->", on_frame(
            esm_frame,
            f"globalThis.__c3esm = {esm_var};"
            f" globalThis.__c3rt = (typeof this !== 'undefined' && this) ? this : globalThis.__c3rt;"
            f" (globalThis.__c3esm ? 'esm-ok' : 'esm-fail')"))
    if tick_frame:
        print("stash rt  ->", on_frame(
            tick_frame,
            "globalThis.__c3rt = this;"
            " (globalThis.__c3rt && globalThis.__c3rt.constructor)"
            " ? globalThis.__c3rt.constructor.name : 'rt-fail'"))

    s.send("Debugger.resume", sess=sess)
    time.sleep(0.4)
    try:
        s.call("Debugger.disable", sess=sess, timeout=5)
    except Exception:
        pass


def main(argv):
    s = S()
    try:
        sess = worker_session(s)
        if not sess:
            print("runtime worker not found")
            return 1
        print(f"worker session: {sess}")
        if "--dump" not in argv:
            stash(s, sess)
        raw = evaluate(s, sess, DUMP_JS)
        info = json.loads(raw)
        print(f"\nhasRt={info['hasRt']} hasEsm={info['hasEsm']} rtClass={info['rtClass']}")
        if info.get("errors"):
            print(f"errors: {info['errors']}")
        vs = info.get("vars") or []
        print(f"\nGLOBAL VARIABLES ({len(vs)}):")
        for v in vs:
            print(f"  {v.get('name')!r} = {v.get('value')!r}")
    finally:
        s.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
