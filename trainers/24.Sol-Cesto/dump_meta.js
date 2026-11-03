// Full dump of both meta arrays, for backup before modification.
(() => {
  const rt = globalThis.__c3rt;
  const get = (n) => {
    const c = (rt._allObjectClasses || []).find(c => c._name === n);
    const i = c && (c._instances || [])[0];
    return i && i._sdkInst && i._sdkInst._arr;
  };
  return JSON.stringify({
    metaSave: get('Array_metaSave'),
    metaFondation: get('Array_metaFondation'),
    metaOr: (() => {
      const c = (rt._allObjectClasses || []).find(c => c._name === 'metaProgression');
      const i = c && (c._instances || [])[0];
      return i ? i._instVarValues : null;
    })(),
  });
})()
