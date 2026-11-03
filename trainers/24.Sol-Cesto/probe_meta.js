// Where is the meta-progression (star purchase) state stored?
(() => {
  const rt = globalThis.__c3rt;
  const out = { ok: true };
  const find = (n) => (rt._allObjectClasses || []).find(c => c._name === n);

  // 1. metaProgression object instance variables
  const mp = find('metaProgression');
  if (mp) {
    const names = (mp._instVars || []).map(v => v && (v.name !== undefined ? v.name : v._name));
    const inst = (mp._instances || [])[0];
    out.metaProgression = {};
    if (inst) {
      const vals = inst._instVarValues || [];
      for (let i = 0; i < vals.length; i++) out.metaProgression[names[i]] = vals[i];
    }
  }

  // 2. Array_metaSave contents (Construct Array plugin)
  const arr = find('Array_metaSave');
  if (arr) {
    const inst = (arr._instances || [])[0];
    out.arrayMetaSave = { found: !!inst };
    if (inst) {
      const sdk = inst._sdkInst;
      out.arrayMetaSave.sdkKeys = sdk ? Object.keys(sdk).slice(0, 25) : null;
      // The Array plugin keeps a nested JS array; dig for it.
      for (const k of ['_data', '_arr', '_array', 'data']) {
        try {
          const d = sdk && sdk[k];
          if (Array.isArray(d)) {
            out.arrayMetaSave.key = k;
            out.arrayMetaSave.dims = [d.length, d[0] ? d[0].length : 0,
                                      (d[0] && d[0][0] !== undefined && d[0][0].length) || 0];
            // flatten a preview
            out.arrayMetaSave.preview = JSON.stringify(d).slice(0, 900);
            break;
          }
        } catch (e) {}
      }
    }
  }

  // 3. What object classes look like star/meta trackers?
  out.metaClasses = (rt._allObjectClasses || [])
    .filter(c => /etoile|meta|save|progress/i.test(c._name || ''))
    .map(c => [c._name, (c._instances || []).length]);

  return JSON.stringify(out, null, 1);
})()
