#!/usr/bin/env python3
"""Step 1 of the ForeverDB data build: fetch everything v0.6 needs, slowly and once.

Strictly sequential, >= 2 s apart, cached (see fdb_fetch.py). Re-running only fetches
what is missing from the cache. The key comes from FOREVERDB_API_KEY only.
Scope: quests up to level 30, vendors seen in WoW Forever, profession recipes up to
skill 225 (Expert, the most a level-30 character can train), and all dungeons.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fdb_fetch import get, count, all_pages as pages

MAX_SKILL = 225
SLUGS = ["alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring",
         "herbalism", "mining", "skinning", "cooking", "first-aid", "fishing"]


def main():
    get("meta")
    pages("quests", {"maxLevel": 30})
    vendors = pages("vendors", {})
    dungeons = get("dungeons", {"limit": 100, "offset": 0})["data"]
    get("professions")
    for slug in SLUGS:
        off = 0
        while True:
            d = get("professions/" + slug, {"limit": 100, "offset": off})
            recs = d["data"].get("recipes") or []
            off += 100
            lowest = min([(r.get("skill") or {}).get("orange") or 0 for r in recs] or [0])
            if not recs or off >= d["meta"].get("total", 0) or lowest > MAX_SKILL:
                break
    for dg in dungeons:
        get("dungeons/%d" % dg["id"])
    for v in vendors:
        if v.get("seenInForever"):
            get("vendors/%d" % v["id"])
    print("all fetched; requests used so far:", count())


if __name__ == "__main__":
    main()
