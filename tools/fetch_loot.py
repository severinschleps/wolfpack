#!/usr/bin/env python3
"""Build WolfpackAddon/Data/Loot.lua from Wowhead's Forever section.

Wowhead renders its listings as JSON inside the page, which is what this reads: for every
dungeon: the quests in it, which NPCs drop something worth having, and the table of each. Nothing here is our own research -- it is Wowhead's data, pulled once and
shipped as a Lua table, because an addon cannot reach the network at runtime.

Polite by construction: one request a second, everything cached under tools/.cache, so a rerun
only fetches what is new. Run it when Forever patches:

    python3 tools/fetch_loot.py            # fetch anything missing, write the Lua file
    python3 tools/fetch_loot.py --refresh  # ignore the cache and pull it all again
"""

import json
import os
import re
import sys
import threading
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
OUT = os.path.join(os.path.dirname(HERE), "WolfpackAddon_Loot", "Data.lua")
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


def _match(text, at, open_ch, close_ch):
    """Index just past the bracket pair that starts at `at`, ignoring brackets inside strings."""
    depth, i, in_str, esc = 0, at, False, False
    while i < len(text):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def listview(html, view_id):
    """The JSON rows of one listing on the page.

    Wowhead ships these two ways: newer listing pages put every view in one JSON script tag,
    older detail pages inline them as `new Listview({... id: 'x' ... data:[...]})`. Both the
    id and the data can sit anywhere in a block, so each block is matched whole first."""
    tag = re.search(r'<script type="application/json" id="data\.page\.listPage\.listviews">'
                    r"(.*?)</script>", html, re.S)
    if tag:
        try:
            for view in json.loads(tag.group(1)):
                if view.get("id") == view_id:
                    return view.get("data") or []
        except json.JSONDecodeError:
            pass
    for m in re.finditer(r"new Listview\(", html):
        brace = html.find("{", m.end())
        stop = _match(html, brace, "{", "}")
        if stop < 0:
            continue
        block = html[brace:stop]
        if not re.search(r"id: *'%s'" % re.escape(view_id), block):
            continue
        at = block.find("data:")
        if at < 0:
            continue
        at = block.find("[", at)
        stop = _match(block, at, "[", "]")
        if stop < 0:
            continue
        try:
            return json.loads(block[at:stop])
        except json.JSONDecodeError:
            return []
    return []


def dungeons(refresh=False):
    """Every Forever dungeon: (zone id, name)."""
    html = get("/zones/dungeons", refresh)
    rows = listview(html, "zones")
    out = []
    for z in rows:
        # category 2 with a level range is exactly the dungeon set. Player count cannot be the
        # test -- Blackrock Spire is filed as a ten-player zone.
        if (z.get("id") and z.get("name") and z.get("category") == 2
                and (z.get("maxlevel") or 0) > 0):
            out.append((z["id"], z["name"], z.get("minlevel") or 0, z.get("maxlevel") or 0))
    out.sort(key=lambda d: (d[2], d[1]))
    return out


def items_of(npc_id, refresh=False):
    """What one NPC drops, with the noise taken out.

    An NPC page lists everything ever seen off it -- world-drop greens, gems, potions. Those
    carry `commondrop`, so what is left is the loot people come for."""
    rows = listview(get("/npc=%d" % npc_id, refresh), "drops")
    out = []
    for it in rows:
        if not it.get("id") or not it.get("name") or it.get("commondrop"):
            continue
        if (it.get("quality") or 0) < 2:
            continue
        pct = 0
        if it.get("count") and it.get("outof"):
            pct = round(100.0 * it["count"] / it["outof"], 1)
        change = (it.get("envChange") or {}).get("lines") or []
        out.append({"id": it["id"], "name": it["name"], "quality": it.get("quality", 2),
                    "level": it.get("reqlevel") or 0, "pct": pct,
                    "change": change[0] if change else None})
    out.sort(key=lambda r: (-r["quality"], -r["pct"], r["name"]))
    return out


def zone(zid, refresh=False, jobs=2):
    """One dungeon: everything in it that drops something worth having, and its quests.

    The zone page's own drop list is only ever partial -- Sunken Temple lists four items -- so
    the NPC list is what gets walked instead. Every elite in the place is asked what it drops;
    the ones with something blue or better to their name are the ones worth a heading."""
    html = get("/zone=%d" % zid, refresh)
    elites = [n for n in listview(html, "npcs")
              if n.get("id") and n.get("name") and (n.get("classification") or 0) >= 1]
    found = {}

    def work(n):
        items = items_of(n["id"], refresh)
        # What tells a boss from an elite that happens to drop a blue: a boss drops its blues
        # often. Glutton hands one over half the time. A long table is a hint of trash, but only
        # a hint -- plenty of bosses drop from a wide pool, so a high rate outvotes it.
        best = max([it["pct"] for it in items if it["quality"] >= 3] or [0])
        if best >= 8 or (best >= 3 and len(items) <= 30) or (n.get("classification") or 0) >= 2:
            found[n["id"]] = {"id": n["id"], "name": n["name"], "items": items}

    threads = []
    for n in elites:
        t = threading.Thread(target=work, args=(n,))
        t.start()
        threads.append(t)
        while sum(1 for x in threads if x.is_alive()) >= jobs:
            time.sleep(0.05)
    for t in threads:
        t.join()

    # the same boss can sit in the list under several NPC ids; one heading each
    merged = {}
    for b in found.values():
        keep = merged.setdefault(b["name"], {"id": b["id"], "name": b["name"], "items": {}})
        for it in b["items"]:
            old = keep["items"].get(it["id"])
            if not old or it["pct"] > old["pct"]:
                keep["items"][it["id"]] = it
    bosses = []
    for b in merged.values():
        items = sorted(b["items"].values(), key=lambda r: (-r["quality"], -r["pct"], r["name"]))
        bosses.append({"id": b["id"], "name": b["name"], "items": items[:25]})
    bosses.sort(key=lambda b: b["name"])
    quests = []
    for qu in listview(html, "quests"):
        if qu.get("id"):
            quests.append({"id": qu["id"], "name": qu.get("name", "?"),
                           "level": qu.get("level") or 0, "min": qu.get("reqlevel") or 0})
    quests.sort(key=lambda r: (r["level"], r["name"]))
    return bosses, quests


def q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    refresh = "--refresh" in sys.argv
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--zone="):
            only = int(a.split("=", 1)[1])

    found = dungeons(refresh)
    if only:
        found = [d for d in found if d[0] == only] or [(only, "Zone %d" % only, 0, 0)]
    print("%d dungeons" % len(found))

    data = []
    for zid, name, lo, hi in found:
        bosses, quests = zone(zid, refresh)
        if not bosses and not quests:
            print("  %-34s nothing here, skipped" % name)
            continue
        data.append({"id": zid, "name": name, "lo": lo, "hi": hi,
                     "bosses": bosses, "quests": quests})
        print("  %-34s %2d bosses, %3d items, %2d quests"
              % (name, len(bosses), sum(len(b["items"]) for b in bosses), len(quests)))

    by_name = {}
    for d in data:
        weight = sum(len(b["items"]) for b in d["bosses"])
        if weight >= by_name.get(d["name"], (-1, None))[0]:
            by_name[d["name"]] = (weight, d)
    data = [v[1] for v in by_name.values()]
    data.sort(key=lambda d: (d["lo"], d["name"]))

    lines = ['-- Dungeon loot and quests, read off Wowhead\'s Forever section by',
             '-- tools/fetch_loot.py. Rerun that when Forever patches -- an addon cannot',
             '-- reach the network itself, so this table is the only way the data gets in.',
             '--',
             '-- WolfpackAddonLootData[i] = { id, name, lo, hi, bosses = { { id, name, items = { {id, name, quality,',
             '-- level, percent, change}, ... } } }, quests = { {id, name, level, min}, ... } }',
             '-- Its own addon so it can be switched off in the addon list: a global, not a',
             '-- namespace, is how the main addon finds it.',
             'WolfpackAddonLootData = {']
    for d in data:
        lines.append('    { id = %d, name = %s, lo = %d, hi = %d, bosses = {'
                     % (d["id"], q(d["name"]), d["lo"], d["hi"]))
        for b in d["bosses"]:
            lines.append('        { id = %d, name = %s, items = {' % (b["id"], q(b["name"])))
            for it in b["items"]:
                lines.append('            { %d, %s, %d, %d, %s, %s },'
                             % (it["id"], q(it["name"]), it["quality"], it["level"], it["pct"],
                                q(it["change"]) if it["change"] else "nil"))
            lines.append('        } },')
        lines.append('    }, quests = {')
        for qu in d["quests"]:
            lines.append('        { %s, %s, %s, %s },'
                         % (qu["id"], q(qu["name"]), qu["level"], qu["min"]))
        lines.append('    } },')
    lines.append('}')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("wrote %s (%.0f KB)" % (OUT, os.path.getsize(OUT) / 1024.0))


if __name__ == "__main__":
    main()
