// Inspect the door object: animations available and current visual state.
(() => {
  const rt = globalThis.__c3rt;
  const cls = (rt._allObjectClasses || []).find(c => c._name === 'Porte');
  if (!cls) return JSON.stringify({ ok: false, error: 'no Porte class' });
  const out = { ok: true, animations: [], instances: [] };
  try {
    out.animations = (cls._animations || []).map(a => a._name);
  } catch (e) { out.animErr = String(e); }
  for (const inst of Array.from(cls._instances || [])) {
    const rec = { uid: inst._uid };
    try {
      const names = (cls._instVars || []).map(v => v && (v.name !== undefined ? v.name : v._name));
      const vals = inst._instVarValues || [];
      rec.vars = {};
      for (let i = 0; i < vals.length; i++) rec.vars[names[i]] = vals[i];
    } catch (e) { rec.varErr = String(e); }
    // current animation + frame, and whether it is visible/enabled
    try {
      const sdk = inst._sdkInst || inst.GetSdkInstance && inst.GetSdkInstance();
      if (sdk) {
        rec.currentAnim = sdk._currentAnimation ? sdk._currentAnimation._name : undefined;
        rec.animFrame = sdk._currentFrameIndex;
      }
    } catch (e) { rec.sdkErr = String(e); }
    try { rec.visible = inst._wi ? inst._wi.IsVisible() : undefined; } catch (e) {}
    out.instances.push(rec);
  }
  return JSON.stringify(out, null, 1);
})()
