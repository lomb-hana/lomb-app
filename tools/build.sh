#!/usr/bin/env bash
# Build dist/LOMBCompanion-v<version>.zip containing only the LOMBCompanion/ addon folder.
set -euo pipefail
cd "$(dirname "$0")/.."
ver=$(sed -n 's/^## Version: *//p' LOMBCompanion/LOMBCompanion.toc | tr -d '\r')
[ -n "$ver" ] || { echo "no version in TOC" >&2; exit 1; }
bash tests/run.sh >/dev/null || { echo "tests failed" >&2; exit 1; }
mkdir -p dist
out="dist/LOMBCompanion-v${ver}.zip"
rm -f "$out"
# ForeverDB.example.lua is a developer template, not part of the release
python3 - "$out" <<'PY'
import os, sys, zipfile
out = sys.argv[1]
skip = {"LOMBCompanion/Data/ForeverDB.example.lua"}
n = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk("LOMBCompanion"):
        dirs.sort()
        for f in sorted(files):
            p = os.path.join(root, f).replace(os.sep, "/")
            if p in skip or f == ".DS_Store":
                continue
            z.write(p, p); n += 1
print(out, "-", n, "files")
PY
