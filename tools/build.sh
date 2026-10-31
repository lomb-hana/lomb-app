#!/usr/bin/env bash
# Build dist/LOMBCompanion-v<version>.zip containing only the git-tracked files of the
# LOMBCompanion/ addon folder (committed versions). Refuses to build if that folder has
# untracked or modified files, so what ships is exactly what's in git.
set -euo pipefail
cd "$(dirname "$0")/.."
ver=$(sed -n 's/^## Version: *//p' LOMBCompanion/LOMBCompanion.toc | tr -d '\r')
[ -n "$ver" ] || { echo "no version in TOC" >&2; exit 1; }
dirty=$(git status --porcelain --untracked-files=all -- LOMBCompanion)
if [ -n "$dirty" ]; then
  echo "LOMBCompanion/ has untracked or uncommitted changes; commit or remove them first:" >&2
  echo "$dirty" >&2
  exit 1
fi
bash tests/run.sh >/dev/null || { echo "tests failed" >&2; exit 1; }
mkdir -p dist
out="dist/LOMBCompanion-v${ver}.zip"
rm -f "$out"
# ForeverDB.example.lua is a developer template, not part of the release
python3 - "$out" <<'PY'
import subprocess, sys, zipfile
out = sys.argv[1]
skip = {"LOMBCompanion/Data/ForeverDB.example.lua"}
files = subprocess.check_output(["git", "ls-files", "-z", "--", "LOMBCompanion"]).decode().split("\0")
n = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(f for f in files if f):
        if p in skip or p.endswith("/.DS_Store"):
            continue
        z.writestr(zipfile.ZipInfo.from_file(p, p), subprocess.check_output(["git", "show", "HEAD:" + p]),
                   zipfile.ZIP_DEFLATED)
        n += 1
print(out, "-", n, "files")
PY
