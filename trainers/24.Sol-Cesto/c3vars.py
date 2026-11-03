#!/usr/bin/env python3
"""
Read and write Sol Cesto's Construct 3 state by NAME (no memory addresses).

Prerequisites:
  1. Game launched with --remote-debugging-port=9222
  2. python stash_runtime.py     (pins __c3rt/__c3esm inside the runtime worker)

Usage:
  python c3vars.py list                    # all global variables
  python c3vars.py get <name>              # read one global
  python c3vars.py set <name> <value>      # write one global
  python c3vars.py types                   # object types with instance counts
  python c3vars.py inst <ObjectType>       # instances + their instance variables
  python c3vars.py js "<expression>"       # raw JS in the runtime worker
"""
import json
import sys
import time

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from solcesto_cdp import CDP, browser_ws  # noqa: E402

WORKER_URL = "workermain.js"


class Worker:
    def __init__(self):
        self.cdp = CDP(browser_ws())
        self.cdp.ws.sock.settimeout(1.0)
        self.events = []
        self.sess = self._attach()
        if not self.sess:
            raise SystemExit("runtime worker not found (is the game running?)")

    def _send(self, m, p=None, sess=None):
        self.cdp._id += 1
        msg = {"id": self.cdp._id, "method": m, "params": p or {}}
        if sess:
            msg["sessionId"] = sess
        self.cdp.ws.send(json.dumps(msg))
        return self.cdp._id

    def _wait(self, want_id=None, timeout=12.0):
        end = time.time() + timeout
        while time.time() < end:
            try:
                raw = self.cdp.ws.recv()
            except Exception:
                continue
            msg = json.loads(raw)
            if msg.get("method"):
                self.events.append(msg)
            if want_id is not None and msg.get("id") == want_id:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg.get("result", {})
        raise TimeoutError("cdp timeout")

    def _call(self, m, p=None, sess=None, timeout=12.0):
        return self._wait(self._send(m, p, sess), timeout=timeout)

    def _attach(self):
        targets = self._call("Target.getTargets")["targetInfos"]
        page = next(t for t in targets if t["type"] == "page")
        ps = self._call("Target.attachToTarget",
                        {"targetId": page["targetId"], "flatten": True})["sessionId"]
        self._call("Target.setAutoAttach",
                   {"autoAttach": True, "waitForDebuggerOnStart": False,
                    "flatten": True}, sess=ps)
        try:
            self._wait(timeout=3)
        except TimeoutError:
            pass
        for ev in self.events:
            if ev.get("method") == "Target.attachedToTarget":
                ti = ev["params"].get("targetInfo", {})
                if WORKER_URL in (ti.get("url") or ""):
                    return ev["params"]["sessionId"]
        return None

    def js(self, expression):
        r = self._call("Runtime.evaluate",
                       {"expression": expression, "returnByValue": True,
                        "awaitPromise": True}, sess=self.sess)
        if r.get("exceptionDetails"):
            raise RuntimeError(r["exceptionDetails"].get("text"))
        return r.get("result", {}).get("value")

    def close(self):
        self.cdp.close()


HELPERS = r"""
globalThis.__vars = () => {
  const esm = globalThis.__c3esm;
  if (!esm) throw new Error('not stashed - run stash_runtime.py');
  return Array.from(esm._allGlobalVars ||
    (esm.GetAllGlobalVariables && esm.GetAllGlobalVariables()) || []);
};
globalThis.__getVar = (n) => {
  const v = globalThis.__vars().find(v =>
    ((v._name !== undefined) ? v._name : v.GetName()) === n);
  if (!v) return { ok: false, error: 'no such variable' };
  return { ok: true, value: (v._value !== undefined) ? v._value : v.GetValue() };
};
globalThis.__setVar = (n, val) => {
  const v = globalThis.__vars().find(v =>
    ((v._name !== undefined) ? v._name : v.GetName()) === n);
  if (!v) return { ok: false, error: 'no such variable' };
  const before = (v._value !== undefined) ? v._value : v.GetValue();
  // Preserve the variable's existing type: numeric vars must stay numeric.
  let cast = val;
  if (typeof before === 'number') { cast = Number(val); if (Number.isNaN(cast)) return { ok:false, error:'not a number' }; }
  else cast = String(val);
  try { if (typeof v.SetValue === 'function') v.SetValue(cast); else v._value = cast; }
  catch (e) { try { v._value = cast; } catch (e2) { return { ok:false, error:String(e2) }; } }
  const after = (v._value !== undefined) ? v._value : v.GetValue();
  return { ok: true, before, after };
};
globalThis.__types = () => {
  const rt = globalThis.__c3rt;
  if (!rt) throw new Error('no runtime stashed');
  const all = rt._allObjectClasses || [];
  return Array.from(all).map(t => {
    let name = '?', count = 0;
    try { name = t._name; } catch(e) {}
    try { count = (t._instances || []).length; } catch(e) {}
    return { name, count };
  }).filter(t => t.count > 0);
};
globalThis.__inst = (typeName) => {
  const rt = globalThis.__c3rt;
  const all = rt._allObjectClasses || [];
  const t = Array.from(all).find(c => c._name === typeName);
  if (!t) return { ok: false, error: 'no such object class' };
  const inst = Array.from(t._instances || []);
  // Instance variable names live on the object class; values on the instance.
  let names = [];
  try {
    // Construct stores instance-variable metadata as {sid,type,name,jsPropName}
    names = (t._instVars || []).map(v => (v && (v.name !== undefined ? v.name : v._name)));
  } catch (e) {}
  const out = inst.slice(0, 12).map((i, idx) => {
    const rec = { index: idx, uid: i._uid, vars: {} };
    try {
      const vals = i._instVarValues || i._instanceVariableValues || [];
      for (let k = 0; k < vals.length; k++) rec.vars[names[k] || ('#' + k)] = vals[k];
    } catch (e) { rec.error = String(e); }
    return rec;
  });
  return { ok: true, type: typeName, total: inst.length, instVarNames: names, instances: out };
};
globalThis.__setInst = (typeName, index, varName, val) => {
  const rt = globalThis.__c3rt;
  const t = (rt._allObjectClasses || []).find(c => c._name === typeName);
  if (!t) return { ok: false, error: 'no such object class' };
  const inst = Array.from(t._instances || []);
  if (!inst[index]) return { ok: false, error: 'no such instance index' };
  const names = (t._instVars || []).map(v => (v && (v.name !== undefined ? v.name : v._name)));
  const k = names.indexOf(varName);
  if (k < 0) return { ok: false, error: 'no such instance variable', names };
  const vals = inst[index]._instVarValues;
  const before = vals[k];
  let cast = val;
  if (typeof before === 'number') {
    cast = Number(val);
    if (Number.isNaN(cast)) return { ok: false, error: 'not a number' };
  } else if (typeof before === 'string') {
    cast = String(val);
  }
  vals[k] = cast;
  return { ok: true, type: typeName, index, name: varName, before, after: vals[k] };
};
globalThis.__findVal = (needle) => {
  // Search every live instance for an instance variable equal to `needle`.
  const rt = globalThis.__c3rt;
  const hits = [];
  for (const t of (rt._allObjectClasses || [])) {
    const names = (t._instVars || []).map(v => (v && (v.name !== undefined ? v.name : v._name)));
    if (!names.length) continue;
    const inst = Array.from(t._instances || []);
    for (let ii = 0; ii < inst.length; ii++) {
      const vals = inst[ii]._instVarValues || [];
      for (let k = 0; k < vals.length; k++) {
        if (vals[k] === needle) {
          hits.push({ type: t._name, index: ii, uid: inst[ii]._uid, name: names[k], value: vals[k] });
        }
      }
    }
    if (hits.length > 200) break;
  }
  return hits;
};
'helpers-ok'
"""


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd = argv[1]
    w = Worker()
    try:
        w.js(HELPERS)
        if cmd == "list":
            vs = w.js("JSON.stringify(globalThis.__vars().map(v=>({n:(v._name!==undefined)?v._name:v.GetName(),v:(v._value!==undefined)?v._value:v.GetValue()})))")
            for e in json.loads(vs):
                print(f"  {e['n']!r} = {e['v']!r}")
        elif cmd == "get":
            print(json.dumps(json.loads(w.js(f"JSON.stringify(globalThis.__getVar({json.dumps(argv[2])}))"))))
        elif cmd == "set":
            expr = f"JSON.stringify(globalThis.__setVar({json.dumps(argv[2])}, {json.dumps(argv[3])}))"
            print(json.dumps(json.loads(w.js(expr))))
        elif cmd == "types":
            ts = json.loads(w.js("JSON.stringify(globalThis.__types())"))
            for t in sorted(ts, key=lambda x: -x["count"]):
                print(f"  {t['count']:5d}  {t['name']}")
        elif cmd == "inst":
            print(json.dumps(json.loads(
                w.js(f"JSON.stringify(globalThis.__inst({json.dumps(argv[2])}))")), indent=2))
        elif cmd == "setinst":
            # setinst <Type> <index> <varName> <value>
            expr = ("JSON.stringify(globalThis.__setInst("
                    f"{json.dumps(argv[2])},{int(argv[3])},"
                    f"{json.dumps(argv[4])},{json.dumps(argv[5])}))")
            print(json.dumps(json.loads(w.js(expr))))
        elif cmd == "find":
            # find <number>  -- locate instance variables holding this value
            needle = argv[2]
            try:
                lit = json.dumps(float(needle) if "." in needle else int(needle))
            except ValueError:
                lit = json.dumps(needle)
            res = json.loads(w.js(f"JSON.stringify(globalThis.__findVal({lit}))"))
            print(f"{len(res)} hit(s)")
            for h in res:
                print(f"  {h['type']}[{h['index']}] uid={h['uid']} {h['name']} = {h['value']!r}")
        elif cmd == "js":
            print(w.js(argv[2]))
        elif cmd == "jsfile":
            with open(argv[2], "r", encoding="utf-8") as fh:
                print(w.js(fh.read()))
        else:
            print(f"unknown command {cmd}")
            return 2
    finally:
        w.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
