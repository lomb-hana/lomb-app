#!/usr/bin/env python3
"""Polite, cached, strictly sequential fetcher for the ForeverDB.net API.

- The API key is read ONLY from the FOREVERDB_API_KEY environment variable.
  It is never printed, logged, cached or written to any file.
- One request at a time, at least MIN_GAP seconds apart; backs off on 429 / 5xx
  (honouring Retry-After).
- Raw responses are cached under $FDB_CACHE (default: ../lomb-companion-notes/fdb-cache,
  outside the repo) so nothing is fetched twice.
- Keeps a running request count in the cache dir and refuses to go past FDB_MAX_REQUESTS
  (default 8000, well under ForeverDB's 10,000 a day per key).
- A lock file in the cache dir keeps requests one at a time even across processes.

Usage as a module:  from fdb_fetch import get ; data = get("quests", {"page": 1})
Usage as a script:  python3 tools/fdb_fetch.py meta
"""
import fcntl, hashlib, json, os, sys, time, urllib.parse, urllib.request, urllib.error

BASE = "https://foreverdb.net/api/v1/"
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.environ.get("FDB_CACHE") or os.path.normpath(os.path.join(HERE, "..", "..", "lomb-companion-notes", "fdb-cache"))
MIN_GAP = float(os.environ.get("FDB_MIN_GAP", "2.0"))
MAX_REQ = int(os.environ.get("FDB_MAX_REQUESTS", "8000"))
UA = "LOMBCompanion-databuild/0.6 (+https://github.com/lomb-hana/lomb-app)"
_last = [0.0]


def _counter_path():
    return os.path.join(CACHE, "_request_count.json")


def count():
    try:
        with open(_counter_path()) as f:
            return json.load(f)["count"]
    except Exception:
        return 0


def _bump():
    c = count() + 1
    with open(_counter_path(), "w") as f:
        json.dump({"count": c, "last": time.strftime("%Y-%m-%d %H:%M:%S")}, f)
    return c


def _cache_file(path, params):
    q = urllib.parse.urlencode(sorted((params or {}).items()))
    key = path.strip("/") + ("?" + q if q else "")
    safe = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in key)[:120]
    h = hashlib.sha1(key.encode()).hexdigest()[:10]
    return os.path.join(CACHE, safe + "." + h + ".json"), key


def get(path, params=None, cache_only=False):
    os.makedirs(CACHE, exist_ok=True)
    fn, key = _cache_file(path, params)
    if os.path.exists(fn):
        with open(fn) as f:
            return json.load(f)
    if cache_only:
        return None
    apikey = os.environ.get("FOREVERDB_API_KEY")
    if not apikey:
        sys.exit("FOREVERDB_API_KEY is not set")
    if count() >= MAX_REQ:
        sys.exit("request budget reached (%d); stopping" % MAX_REQ)
    url = BASE + key
    attempt = 0
    while True:
        with open(os.path.join(CACHE, "_lock"), "a+") as lk:
            fcntl.flock(lk, fcntl.LOCK_EX)          # one request at a time, across processes
            lk.seek(0)
            try:
                last = float(lk.read().strip() or 0)
            except ValueError:
                last = 0.0
            wait = max(_last[0], last) + MIN_GAP - time.time()
            if wait > 0:
                time.sleep(wait)
            if count() >= MAX_REQ:
                sys.exit("request budget reached (%d); stopping" % MAX_REQ)
            req = urllib.request.Request(url, headers={"X-API-Key": apikey, "Accept": "application/json", "User-Agent": UA})
            n = _bump()
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    body = r.read().decode("utf-8")
                err = None
            except urllib.error.HTTPError as e:
                err, body = e, None
            finally:
                _last[0] = time.time()
                lk.seek(0); lk.truncate(); lk.write(str(_last[0])); lk.flush()
        try:
            if err:
                raise err
            data = json.loads(body)
            with open(fn, "w") as f:
                f.write(body)
            print("[fdb %d] %s" % (n, key), file=sys.stderr)
            return data
        except urllib.error.HTTPError as e:
            attempt += 1
            if e.code == 429 or e.code >= 500:
                ra = e.headers.get("Retry-After")
                delay = float(ra) if ra and ra.isdigit() else min(120, 10 * 2 ** attempt)
                print("[fdb %d] %s -> HTTP %d, backing off %ss" % (n, key, e.code, delay), file=sys.stderr)
                if attempt > 5:
                    sys.exit("too many failures; stopping")
                time.sleep(delay)
                continue
            print("[fdb %d] %s -> HTTP %d" % (n, key, e.code), file=sys.stderr)
            body = e.read().decode("utf-8", "replace")[:500]
            raise RuntimeError("HTTP %d for %s: %s" % (e.code, key, body))


if __name__ == "__main__":
    p = sys.argv[1] if len(sys.argv) > 1 else "meta"
    params = dict(a.split("=", 1) for a in sys.argv[2:])
    print(json.dumps(get(p, params), indent=1)[:20000])
    print("requests so far:", count(), file=sys.stderr)


def all_pages(path, params=None):
    """Every page of a list endpoint (100 per request), as one list. Stops at the
    first empty page, when there's no next page, or once `total` is reached."""
    off, out = 0, []
    while True:
        r = get(path, dict(params or {}, limit=100, offset=off))
        data = (r or {}).get("data") or []
        out += data
        meta = (r or {}).get("meta") or {}
        off += 100
        if not data or not meta.get("next") or off >= meta.get("total", float("inf")):
            return out
