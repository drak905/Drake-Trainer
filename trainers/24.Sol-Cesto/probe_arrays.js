// Dump the meta-save arrays compactly: labels (x=0) beside values (x>=1).
(() => {
  const rt = globalThis.__c3rt;
  const get = (n) => {
    const c = (rt._allObjectClasses || []).find(c => c._name === n);
    const i = c && (c._instances || [])[0];
    return i && i._sdkInst && i._sdkInst._arr;
  };

  const out = {};

  const save = get('Array_metaSave');
  if (save) {
    out.metaSave = { dims: [save.length, save[0].length, save[0][0].length] };
    // For each y row, show the label (x=0) and the values at x=1..3
    const rows = [];
    for (let y = 0; y < Math.min(save[0].length, 60); y++) {
      const label = [];
      const vals = [];
      for (let z = 0; z < save[0][0].length; z++) label.push(save[0][y][z]);
      for (let x = 1; x < Math.min(save.length, 4); x++) {
        const cell = [];
        for (let z = 0; z < save[x][0].length; z++) cell.push(save[x][y][z]);
        vals.push(cell);
      }
      if (label.some(v => v !== "" && v !== 0) || vals.some(c => c.some(v => v !== "" && v !== 0))) {
        rows.push({ y, label, vals });
      }
    }
    out.metaSave.rows = rows;
  }

  const found = get('Array_metaFondation');
  if (found) {
    out.metaFondation = {
      dims: [found.length, found[0].length, found[0][0].length],
      preview: JSON.stringify(found).slice(0, 700),
    };
  }

  return JSON.stringify(out);
})()
