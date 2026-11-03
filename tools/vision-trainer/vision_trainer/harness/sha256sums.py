"""Generate SHA256SUMS.txt for a release directory."""
import hashlib
import os
import sys

target = sys.argv[1] if len(sys.argv) > 1 else "dist/VisionTrainer"
lines = []
for root, _dirs, files in os.walk(target):
    for name in sorted(files):
        path = os.path.join(root, name)
        digest = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                digest.update(chunk)
        rel = os.path.relpath(path, target)
        lines.append(f"{digest.hexdigest()}  {rel}")

out = os.path.join(target, "SHA256SUMS.txt")
with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print(f"Wrote {out} ({len(lines)} files)")
