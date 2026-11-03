// Survey the star upgrade tree: which stars are revealed vs locked.
(() => {
  const rt = globalThis.__c3rt;
  const cls = (rt._allObjectClasses || []).find(c => c._name === 'meta_etoiles');
  if (!cls) return JSON.stringify({ ok: false, error: 'no meta_etoiles' });
  const names = (cls._instVars || []).map(v => v && (v.name !== undefined ? v.name : v._name));
  const iRev = names.indexOf('revealed');
  const iInfo = names.indexOf('infoPourGeraud');
  const iAct = names.indexOf('activationIncoming');
  const iFeuille = names.indexOf('feuille');
  const counts = {};
  const locked = [];
  for (const inst of Array.from(cls._instances || [])) {
    const v = inst._instVarValues || [];
    const r = v[iRev];
    counts[String(r)] = (counts[String(r)] || 0) + 1;
    if (r !== 1) {
      locked.push({ uid: inst._uid, revealed: r, info: v[iInfo],
                    act: v[iAct], feuille: v[iFeuille] });
    }
  }
  return JSON.stringify({
    ok: true,
    total: (cls._instances || []).length,
    revealedCounts: counts,
    lockedCount: locked.length,
    locked: locked.slice(0, 40),
  }, null, 1);
})()
