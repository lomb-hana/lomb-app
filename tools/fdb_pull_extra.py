#!/usr/bin/env python3
"""Second pass for the bundled data: zones, items up to required level 30 (names,
quality, slot -- so Item lookup knows every levelling item), and what players'
ForeverDB addons saw for quests (rewards and XP). Same polite, cached fetcher."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fdb_fetch import count, all_pages  # noqa: E402


all_pages("zones")
all_pages("changes-seen", {"kind": "quest"})
all_pages("items", {"maxLevel": 30})
print("requests so far:", count())
