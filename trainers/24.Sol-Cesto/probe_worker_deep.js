// Deep search inside the Construct 3 runtime worker for the runtime instance.
// The runtime is not a top-level global, so walk a bounded object graph looking
// for the event sheet manager (which owns global variables) or a globalVars map.
(() => {
  const g = globalThis;
  const out = { c3Keys: [], hits: [], globalVars: null, errors: [] };

  try { out.c3Keys = Object.keys(g.C3 || {}).slice(0, 120); } catch (e) {}

  const isRuntime = (o) => {
    if (!o || typeof o !== 'object') return false;
    try {
      return ('_eventSheetManager' in o) ||
             ('_allGlobalVars' in o) ||
             (typeof o.GetEventSheetManager === 'function') ||
             ('globalVars' in o && '_runtime' in o);
    } catch (e) { return false; }
  };

  const seen = new Set();
  const queue = [];
  const push = (obj, path, depth) => {
    if (!obj || depth > 3) return;
    if (typeof obj !== 'object' && typeof obj !== 'function') return;
    if (seen.has(obj)) return;
    seen.add(obj);
    queue.push([obj, path, depth]);
  };

  // seed from globalThis own properties
  for (const k of Object.getOwnPropertyNames(g)) {
    let v; try { v = g[k]; } catch (e) { continue; }
    push(v, k, 0);
  }

  let steps = 0;
  while (queue.length && steps < 4000) {
    steps++;
    const [obj, path, depth] = queue.shift();
    if (isRuntime(obj)) {
      out.hits.push(path);
      if (out.hits.length >= 5) break;
      continue;
    }
    let keys;
    try { keys = Object.getOwnPropertyNames(obj).slice(0, 40); } catch (e) { continue; }
    for (const k of keys) {
      if (k === 'caller' || k === 'callee' || k === 'arguments') continue;
      let v; try { v = obj[k]; } catch (e) { continue; }
      push(v, path + '.' + k, depth + 1);
    }
  }
  out.steps = steps;

  // try to read global variables from the first hit
  const resolve = (p) => p.split('.').reduce((o, k) => (o ? o[k] : undefined), g);
  if (out.hits.length) {
    try {
      const rt = resolve(out.hits[0]);
      const esm = rt._eventSheetManager ||
                  (rt.GetEventSheetManager && rt.GetEventSheetManager());
      let vars = rt._allGlobalVars ||
                 (esm && (esm._allGlobalVars ||
                          (esm.GetAllGlobalVariables && esm.GetAllGlobalVariables()))) || [];
      out.globalVars = Array.from(vars).map(v => ({
        name:  (v._name  !== undefined) ? v._name  : (v.GetName  && v.GetName()),
        value: (v._value !== undefined) ? v._value : (v.GetValue && v.GetValue()),
      }));
    } catch (e) { out.errors.push(String(e)); }
  }
  return JSON.stringify(out);
})()
