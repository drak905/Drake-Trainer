// Verify the ACQUIS column cell by cell against the labels.
(() => {
  const rt = globalThis.__c3rt;
  const cls = (rt._allObjectClasses || []).find(c => c._name === 'Array_metaSave');
  const inst = cls && (cls._instances || [])[0];
  const arr = inst && inst._sdkInst && inst._sdkInst._arr;
  if (!arr) return JSON.stringify({ ok: false });
  const rows = [];
  for (let y = 30; y < 80; y++) {
    rows.push({
      y,
      elemLabel: arr[0][y][0], elemAcq: arr[3][y][0],
      persoLabel: arr[0][y][1], persoName: arr[1][y][1], persoAcq: arr[3][y][1],
    });
  }
  return JSON.stringify(rows);
})()
