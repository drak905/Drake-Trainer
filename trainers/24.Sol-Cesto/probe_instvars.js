// Find where Construct stores instance-variable NAMES on an object class.
(() => {
  const rt = globalThis.__c3rt;
  const cls = rt._allObjectClasses.find(c => c._name === 'meta_perso');
  const out = { clsKeys: Object.keys(cls).slice(0, 60) };
  // candidate containers for instance variable metadata
  for (const k of ['_instVars', '_instanceVariables', '_instVarNames', '_instVarsByName',
                   '_instVarSids', '_family', '_plugin']) {
    try {
      const v = cls[k];
      if (v === undefined) continue;
      if (Array.isArray(v)) {
        out[k] = { isArray: true, len: v.length,
                   first: v[0] ? (typeof v[0] === 'object' ? Object.keys(v[0]).slice(0, 15) : String(v[0])) : null };
      } else if (v instanceof Map) {
        out[k] = { isMap: true, keys: Array.from(v.keys()).slice(0, 20) };
      } else if (typeof v === 'object') {
        out[k] = { keys: Object.keys(v).slice(0, 20) };
      } else {
        out[k] = String(v);
      }
    } catch (e) { out[k] = 'err ' + e; }
  }
  return JSON.stringify(out, null, 1);
})()
