#!/usr/bin/env python3
r"""
Sol Cesto trainer - continuously enforces your loadout.

    python solcesto_trainer.py                 enforce forever (recommended)
    python solcesto_trainer.py --once           apply once and exit
    python solcesto_trainer.py --show           read current values, change nothing
    python solcesto_trainer.py --gate           also force porte_Requis to 1
    python solcesto_trainer.py --interval 0.5   how often to check (default 1s)

Prerequisite - the game must be running with the debugging port open:

    $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="--remote-debugging-port=9222"
    & "E:\EpicGames\SolCesto\SolCesto.exe"

or just use PlaySolCesto.bat, which does all of it.

Why enforcement rather than a single write: Construct initialises the hero's
stats a moment AFTER the instance is created, and resets them when you pick a
new character. Writing once loses that race. This keeps re-asserting the values,
so they survive new runs, character changes and floor transitions.

It also reconnects on its own if you close and relaunch the game.
"""
import json
import sys
import time

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stash_runtime import S, worker_session, stash          # noqa: E402
from c3vars import HELPERS                                   # noqa: E402

# ---------------------------------------------------------------- loadout

# Continuously enforced: re-written whenever the game changes them.
ENFORCE_VARS = {
    "vie":                100,   # current HP  (kept topped up = effectively immortal)
    "vieMax":             100,   # max HP
    "pouvoir_force":       10,   # attack
    "pouvoir_magie":       10,   # magic attack
    "capacite_seuilMax":    1,   # special skill threshold -> always ready
    "or_multiplicateur":  100,   # gold multiplier
    "inventaireMax":        6,   # inventory slots
    "bouclierActif":      100,   # shield active
}

# Instance variables enforced on EVERY instance of other object classes.
# Currently unused - see ENFORCE_OBJECTS below (gate tampering removed).

# Applied ONCE per run. Deliberately EMPTY.
#
# `actions` used to be forced to 1 here. Don't do that: the door opens on a
# TRIGGER - the game compares actions against Porte.requis at the moment an
# action is performed. Writing the value directly satisfies the comparison but
# never fires the check, so the door stays shut. Worse, re-running the trainer
# reset the counter and undid real progress.
PER_RUN_VARS = {}

# Gate / door tampering has been REMOVED on request.
#
# Left empty (rather than deleted) so the mechanism is available if ever wanted.
# Previously held {"porte_Requis": 1} and {"Porte": {"requis": 1}}, which lowered
# the gate requirement from 5 to 1. Both are now untouched, so gates behave
# exactly as the game intends.
ENFORCE_GLOBALS = {}
ENFORCE_OBJECTS = {}

# ------------------------------------------------------------------ plumbing

READ_JS = r"""
(() => {
  const rt = globalThis.__c3rt;
  if (!rt) return JSON.stringify({ ok:false, error:'runtime not pinned' });
  const cls = (rt._allObjectClasses || []).find(c => c._name === 'heros');
  if (!cls) return JSON.stringify({ ok:false, error:'hero class not found' });
  const inst = (cls._instances || [])[0];
  if (!inst) return JSON.stringify({ ok:false, error:'no hero (title screen)' });
  const names = (cls._instVars || []).map(v => v && (v.name !== undefined ? v.name : v._name));
  const vals  = inst._instVarValues || [];
  const out = {};
  for (let i = 0; i < vals.length; i++) out[names[i] || ('#'+i)] = vals[i];
  return JSON.stringify({ ok:true, uid: inst._uid, vars: out });
})()
"""

# Enforce every value in one round trip - far cheaper than one call per variable.
ENFORCE_JS_TEMPLATE = r"""
(() => {
  const want = %s;
  const rt = globalThis.__c3rt;
  if (!rt) return JSON.stringify({ ok:false, error:'runtime not pinned' });
  const cls = (rt._allObjectClasses || []).find(c => c._name === 'heros');
  if (!cls) return JSON.stringify({ ok:false, error:'hero class missing' });
  const inst = (cls._instances || [])[0];
  if (!inst) return JSON.stringify({ ok:false, error:'no hero' });
  const names = (cls._instVars || []).map(v => v && (v.name !== undefined ? v.name : v._name));
  const vals = inst._instVarValues;
  const changed = [];
  for (const k in want) {
    const i = names.indexOf(k);
    if (i < 0) continue;
    if (vals[i] !== want[k]) { changed.push([k, vals[i], want[k]]); vals[i] = want[k]; }
  }
  return JSON.stringify({ ok:true, uid: inst._uid, changed });
})()
"""


# Enforce global variables in one round trip too.
ENFORCE_GLOBALS_JS_TEMPLATE = r"""
(() => {
  const want = %s;
  const esm = globalThis.__c3esm;
  if (!esm) return JSON.stringify({ ok:false, error:'esm not pinned' });
  const vars = esm._allGlobalVars ||
               (esm.GetAllGlobalVariables && esm.GetAllGlobalVariables()) || [];
  const changed = [];
  for (const v of Array.from(vars)) {
    const n = (v._name !== undefined) ? v._name : (v.GetName && v.GetName());
    if (!(n in want)) continue;
    const before = (v._value !== undefined) ? v._value : v.GetValue();
    if (before === want[n]) continue;
    try {
      if (typeof v.SetValue === 'function') v.SetValue(want[n]); else v._value = want[n];
    } catch (e) { try { v._value = want[n]; } catch (e2) { continue; } }
    const after = (v._value !== undefined) ? v._value : v.GetValue();
    changed.push([n, before, after]);
  }
  return JSON.stringify({ ok:true, changed });
})()
"""


# Enforce instance vars across ALL instances of arbitrary object classes.
ENFORCE_OBJECTS_JS_TEMPLATE = r"""
(() => {
  const spec = %s;
  const rt = globalThis.__c3rt;
  if (!rt) return JSON.stringify({ ok:false, error:'runtime not pinned' });
  const changed = [];
  for (const clsName in spec) {
    const cls = (rt._allObjectClasses || []).find(c => c._name === clsName);
    if (!cls) continue;
    const names = (cls._instVars || []).map(v => v && (v.name !== undefined ? v.name : v._name));
    const want = spec[clsName];
    const insts = Array.from(cls._instances || []);
    for (let ii = 0; ii < insts.length; ii++) {
      const vals = insts[ii]._instVarValues;
      if (!vals) continue;
      for (const k in want) {
        const i = names.indexOf(k);
        if (i < 0) continue;
        if (vals[i] !== want[k]) {
          changed.push([clsName + '[' + ii + '].' + k, vals[i], want[k]]);
          vals[i] = want[k];
        }
      }
    }
  }
  return JSON.stringify({ ok:true, changed });
})()
"""


class Trainer:
    def __init__(self):
        self.s = None
        self.sess = None

    def connect(self):
        """(Re)attach to the runtime worker and pin the runtime if needed."""
        self.close()
        self.s = S()
        self.sess = worker_session(self.s)
        if not self.sess:
            raise ConnectionError("runtime worker not found")
        if not self._pinned():
            stash(self.s, self.sess)
            if not self._pinned():
                raise ConnectionError("could not pin runtime")
        self.js(HELPERS)
        return self.sess

    def _pinned(self):
        r = self.s.call("Runtime.evaluate", {
            "expression": "!!(globalThis.__c3rt && globalThis.__c3esm)",
            "returnByValue": True,
        }, sess=self.sess)
        return bool(r.get("result", {}).get("value"))

    def js(self, expression):
        r = self.s.call("Runtime.evaluate", {
            "expression": expression, "returnByValue": True, "awaitPromise": True,
        }, sess=self.sess)
        if r.get("exceptionDetails"):
            raise RuntimeError(r["exceptionDetails"].get("text"))
        return r.get("result", {}).get("value")

    def read_hero(self):
        return json.loads(self.js(READ_JS))

    def enforce(self, mapping):
        expr = ENFORCE_JS_TEMPLATE % json.dumps(mapping)
        return json.loads(self.js(expr))

    def enforce_globals(self, mapping):
        expr = ENFORCE_GLOBALS_JS_TEMPLATE % json.dumps(mapping)
        return json.loads(self.js(expr))

    def enforce_objects(self, spec):
        expr = ENFORCE_OBJECTS_JS_TEMPLATE % json.dumps(spec)
        return json.loads(self.js(expr))

    def set_global(self, name, value):
        expr = ("JSON.stringify(globalThis.__setVar("
                f"{json.dumps(name)},{json.dumps(value)}))")
        return json.loads(self.js(expr))

    def close(self):
        if self.s:
            try:
                self.s.close()
            except Exception:
                pass
        self.s = self.sess = None


def stamp():
    return time.strftime("[%H:%M:%S]")


def main(argv):
    show_only = "--show" in argv
    once = "--once" in argv
    do_gate = "--no-gate" not in argv
    interval = 1.0
    if "--interval" in argv:
        i = argv.index("--interval")
        if len(argv) > i + 1:
            interval = float(argv[i + 1])

    t = Trainer()
    last_uid = None
    waiting_logged = False

    try:
        print("connecting...")
        t.connect()
        print(f"connected (session {t.sess}); runtime pinned\n")

        if show_only:
            info = t.read_hero()
            gvals = {}
            try:
                gvals = json.loads(t.js(
                    "JSON.stringify(Object.fromEntries("
                    "globalThis.__vars().map(v=>[(v._name!==undefined)?v._name:v.GetName(),"
                    "(v._value!==undefined)?v._value:v.GetValue()])))"))
            except Exception:
                pass
            if not info.get("ok"):
                print(f"hero unavailable: {info.get('error')}")
            else:
                cur = info["vars"]
                print(f"hero uid={info['uid']}")
                for k in list(ENFORCE_VARS) + list(PER_RUN_VARS) + \
                         ["or", "pouvoir_force", "pouvoir_magie", "capacite_seuilActuel"]:
                    print(f"  {k:22} = {cur.get(k)!r}")
            for gname in list(ENFORCE_GLOBALS) + ["porte_Requis_ajout", "EtageActuel"]:
                print(f"  [global] {gname:18} = {gvals.get(gname)!r}")
            return 0

        print("Enforcing loadout. Values are re-applied whenever the game")
        print("resets them - new runs, character changes, floor transitions.")
        print("Leave this window open while you play. Ctrl+C to stop.\n")

        while True:
            try:
                res = t.enforce(ENFORCE_VARS)

                if not res.get("ok"):
                    if not waiting_logged:
                        print(f"{stamp()} waiting for a run ({res.get('error')})")
                        waiting_logged = True
                    last_uid = None
                else:
                    waiting_logged = False
                    uid = res.get("uid")

                    # New hero instance => new run or new character.
                    if uid != last_uid:
                        print(f"\n{stamp()} new run detected (hero uid={uid})")
                        last_uid = uid
                        for name, val in PER_RUN_VARS.items():
                            r2 = t.enforce({name: val})
                            for c in (r2.get("changed") or []):
                                print(f"    {c[0]:22} {c[1]!r} -> {c[2]!r}  (per-run)")

                    for c in (res.get("changed") or []):
                        print(f"{stamp()} {c[0]:22} {c[1]!r} -> {c[2]!r}")

                # Globals exist even on the title screen, so enforce them
                # regardless of whether a hero is currently alive.
                if do_gate and ENFORCE_GLOBALS:
                    gres = t.enforce_globals(ENFORCE_GLOBALS)
                    for c in (gres.get("changed") or []):
                        print(f"{stamp()} [global] {c[0]:13} {c[1]!r} -> {c[2]!r}")

                # Live door objects carry their own `requis` count.
                if do_gate and ENFORCE_OBJECTS:
                    ores = t.enforce_objects(ENFORCE_OBJECTS)
                    for c in (ores.get("changed") or []):
                        print(f"{stamp()} [obj] {c[0]:20} {c[1]!r} -> {c[2]!r}")

                if once:
                    break

            except (ConnectionError, RuntimeError, TimeoutError, OSError) as e:
                print(f"{stamp()} lost connection ({type(e).__name__}: {e}); "
                      "reconnecting in 3s...")
                last_uid = None
                time.sleep(3)
                try:
                    t.connect()
                    print(f"{stamp()} reconnected")
                except Exception as e2:
                    print(f"{stamp()} reconnect failed: {e2}")
                    time.sleep(3)
                continue

            time.sleep(interval)

    except KeyboardInterrupt:
        print("\nstopped")
    finally:
        t.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
