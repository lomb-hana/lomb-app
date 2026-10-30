#!/usr/bin/env python3
"""Third pass for the bundled data (v0.6.3 / addon 0.8.5 features): classes and their
abilities (trainer reminder), gathering (herbs, ore, skinning, fishing), disenchanting,
item sets, rogue poisons and battlegrounds. Same polite, cached, strictly sequential
fetcher (tools/fdb_fetch.py): one request at a time, >= 2 s apart, nothing fetched twice.

    python3 tools/fdb_pull_features.py            # step 1: the list endpoints
    python3 tools/fdb_pull_features.py --details  # step 2: per-class / per-zone / per-set details
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fdb_fetch import get, count  # noqa: E402

MAX_LEVEL = 30


def all_pages(path, params=None):
    off, out = 0, []
    while True:
        r = get(path, dict(params or {}, limit=100, offset=off))
        out += r.get("data") or []
        if not r or not r.get("data") or (r.get("meta") or {}).get("next") is None:
            return out
        off += 100


def step1():
    get("classes")
    get("disenchant")
    get("poisons")
    get("battlegrounds")
    for slug in ("herbalism", "mining", "skinning", "fishing"):
        get("gathering/" + slug)
    all_pages("itemsets")


def step2():
    import json  # noqa: F401
    for c in get("classes", cache_only=True)["data"]:
        get("classes/" + c["name"].lower())
    sk = get("gathering/skinning", cache_only=True)["data"]
    for z in skin_zones(sk):
        get("gathering/skinning", {"zone": z})
    for s in sets_in_range():
        get("itemsets/%d" % s)


def skin_zones(sk):
    """Zones whose beasts are within the level cap (from the skinning summary)."""
    out = []
    for z in sk.get("zones") or []:
        lo = (z.get("levels") or {}).get("min") or 0
        if lo <= MAX_LEVEL:
            out.append(z.get("mapId"))
    return [z for z in out if z]


def sets_in_range():
    """Non-speculative sets with at least one piece in the cached items list (required level <= 30)."""
    import glob, json
    from fdb_fetch import CACHE
    lowitems = set()
    for f in glob.glob(os.path.join(CACHE, "items_limit_100_maxLevel_30_offset_*.json")):
        with open(f) as fh:
            lowitems.update(i["id"] for i in json.load(fh)["data"])
    out, off = [], 0
    while True:
        r = get("itemsets", {"limit": 100, "offset": off}, cache_only=True)
        if not r:
            break
        for s in r["data"]:
            if not s.get("speculation") and not s.get("betaEvent") and any(i in lowitems for i in s.get("items") or []):
                out.append(s["id"])
        if (r.get("meta") or {}).get("next") is None:
            break
        off += 100
    return out


if __name__ == "__main__":
    step2() if "--details" in sys.argv else step1()
    print("requests so far:", count())
