#!/usr/bin/env bash
# Run LOMB Companion's offline tests (Lua 5.1, same as the game client).
set -u
cd "$(dirname "$0")/.."
LUA=${LUA:-lua5.1}
status=0
for t in tests/test_*.lua; do
  echo "== $t"
  "$LUA" "$t" || status=1
done
exit $status
