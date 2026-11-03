"""Pretty-print the ACQUIS verification without shell quoting problems."""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
out = subprocess.run(
    [sys.executable, "c3vars.py", "jsfile", "verify_cells.js"],
    capture_output=True, text=True, encoding="utf-8",
    cwd=HERE,
)
raw = out.stdout.strip()
if not raw:
    print("no output; stderr:", out.stderr[:500])
    sys.exit(1)
rows = json.loads(raw)
print(f"{'y':>3}  {'ELEMENT (star)':38} {'acq':>3}   {'PERSO slot':16} {'name':12} {'acq':>3}")
print("-" * 92)
for r in rows:
    el = (r["elemLabel"] or "")[:38]
    ps = (r["persoLabel"] or "")[:16]
    nm = (r["persoName"] or "")[:12]
    print(f"{r['y']:>3}  {el:38} {str(r['elemAcq']):>3}   {ps:16} {nm:12} {str(r['persoAcq']):>3}")
