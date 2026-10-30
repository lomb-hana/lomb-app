#!/usr/bin/env python3
"""Second pass for the bundled data: zones, items up to required level 30 (names,
quality, slot -- so Item lookup knows every levelling item), and what players'
ForeverDB addons saw for quests (rewards and XP). Same polite, cached fetcher."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fdb_fetch import get, count  # noqa: E402


def all_pages(path, params=None):
    off = 0
    while True:
        r = get(path, dict(params or {}, limit=100, offset=off))
        if not r or not r.get("data") or (r.get("meta") or {}).get("next") is None:
            return
        off += 100


all_pages("zones")
all_pages("changes-seen", {"kind": "quest"})
all_pages("items", {"maxLevel": 30})
print("requests so far:", count())
