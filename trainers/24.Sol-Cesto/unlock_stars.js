// Unlock all star upgrades (ÉLÉMENTS, z=0) and characters/talents (PERSOS, z=1)
// by setting the "ACQUIS ?" column (_arr[3]) to 1 wherever a label exists.
// Rows 0-2 are headers and are skipped.
(() => {
  const rt = globalThis.__c3rt;
  const cls = (rt._allObjectClasses || []).find(c => c._name === 'Array_metaSave');
  const inst = cls && (cls._instances || [])[0];
  const arr = inst && inst._sdkInst && inst._sdkInst._arr;
  if (!arr) return JSON.stringify({ ok: false, error: 'Array_metaSave not found' });

  const ACQ = 3;          // x index of the "ACQUIS ?" column
  const changed = [];
  const skipped = [];
  const HEADER_ROWS = 3;  // y 0,1,2 are titles/headers

  for (let y = HEADER_ROWS; y < arr[0].length; y++) {
    for (let z = 0; z <= 1; z++) {          // 0 = ÉLÉMENTS, 1 = PERSOS
      const label = arr[0][y][z];
      if (typeof label !== 'string' || label === '') continue;
      const before = arr[ACQ][y][z];
      if (before === 1) { skipped.push([y, z, label]); continue; }
      arr[ACQ][y][z] = 1;
      changed.push([y, z, label, before, 1]);
    }
  }
  return JSON.stringify({ ok: true, changedCount: changed.length,
                          alreadyCount: skipped.length, changed });
})()
