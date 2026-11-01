"""Polite, cached page fetching from Wowhead's Forever section, for tools/bake_attune.py.

One request a second, everything cached under tools/.cache, so a rerun only fetches what is new.
"""

import os
import re
import sys
import threading
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
BASE = "https://www.wowhead.com/forever"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
                  "(KHTML, like Gecko) Version/17.4 Safari/605.1.15",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
}

last_fetch = [0.0]
gate = threading.Lock()      # one request at a time, spaced out -- be a good guest
RATE = 1.2                   # seconds between requests -- faster gets refused


def get(path, refresh=False):
    """Fetch a Wowhead page, through the cache."""
    name = re.sub(r"[^a-zA-Z0-9=._-]", "_", path) + ".html"
    hit = os.path.join(CACHE, name)
    if not refresh and os.path.exists(hit):
        return open(hit, encoding="utf-8", errors="replace").read()
    body = None
    for attempt in range(4):
        with gate:
            wait = RATE - (time.time() - last_fetch[0])
            if wait > 0:
                time.sleep(wait)
            last_fetch[0] = time.time()
        req = urllib.request.Request(BASE + path, headers=HEADERS)
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                body = r.read().decode("utf-8", errors="replace")
            break
        except urllib.error.HTTPError as e:
            if e.code == 404:  # an npc Wowhead does not have; nothing to retry
                os.makedirs(CACHE, exist_ok=True)
                open(hit, "w", encoding="utf-8").write("")
                return ""
            body = None
        except Exception:  # slow page or a hiccup -- back off and try again
            body = None
        if body is None:
            if attempt == 3:
                print("    giving up on %s" % path)
                return ""
            time.sleep(8 * (attempt + 1))
    os.makedirs(CACHE, exist_ok=True)
    open(hit, "w", encoding="utf-8").write(body)
    return body
