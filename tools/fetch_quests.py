#!/usr/bin/env python3
"""Build WolfpackAddon_Quests from Wowhead's Forever quest listings.

Every listing caps at a thousand rows, and Forever has 5,202 quests, so they are gathered two
ways and merged: every zone's own page, and the whole list sliced into level bands. Together
those reach 99% of them; the handful left over belong to no zone and no level.

Each quest then gets its page read once for who hands it out, where that is, and the chain it
belongs to -- the same pages the dungeon loot tables already use, so most are cached.

    python3 tools/fetch_quests.py            # listings only: fast, no givers or chains
    python3 tools/fetch_quests.py --detail   # also read every quest page (slow, hours first time)
    python3 tools/fetch_quests.py --detail --only=dungeon,raid   # just those two
"""

import os
import re
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_loot as F

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(os.path.dirname(HERE), "WolfpackAddon_Quests")

BANDS = [(0, 0), (1, 8), (9, 14), (15, 20), (21, 26), (27, 32), (33, 38), (39, 44),
         (45, 50), (51, 55), (56, 57), (58, 58), (59, 59), (60, 60), (61, 80)]


def listing(path):
    return F.listview(F.get(path), "quests") or []


def gather():
    """Every quest Wowhead will show us, and which of the three lists it belongs on."""
    dungeon = {r["id"] for r in listing("/quests/dungeons") if r.get("id")}
    raid = {r["id"] for r in listing("/quests/raids") if r.get("id")}

    zones = {}
    for z in F.listview(F.get("/zones/dungeons"), "zones"):
        if z.get("id") and z.get("name"):
            zones[z["id"]] = z["name"]

    all_quests = {}
    for zone_id in zones:
        for r in F.listview(F.get("/zone=%d" % zone_id), "quests") or []:
            if r.get("id"):
                all_quests.setdefault(r["id"], r)
    for lo, hi in BANDS:
        for r in listing("/quests?filter=minle=%d;maxle=%d" % (lo, hi)):
            if r.get("id"):
                all_quests.setdefault(r["id"], r)

    out = {"dungeon": [], "raid": [], "normal": []}
    for qid, r in all_quests.items():
        where = "dungeon" if qid in dungeon else "raid" if qid in raid else "normal"
        out[where].append({
            "id": qid,
            "name": r.get("name", "?"),
            "level": r.get("level") or 0,
            "min": r.get("reqlevel") or 0,
            "side": r.get("side") or 3,
            "cls": r.get("reqclass") or 0,       # a bitmask, 0 for anybody
            "zone": zones.get(r.get("category"), None),
        })
    for rows in out.values():
        rows.sort(key=lambda r: (r["min"], r["level"], r["name"]))
    return out


def detail(rows, label, jobs=3):
    """Read each quest's own page for the giver, the spot, and the chain it is part of."""
    done = [0]
    lock = threading.Lock()

    def work(row):
        try:
            where = F.giver(row["id"]) or (None, None, 0, 0)
            row["giver"], row["gzone"], row["x"], row["y"] = where
        except Exception:
            row["giver"], row["gzone"], row["x"], row["y"] = None, None, 0, 0
        try:
            chain = F.series(row["id"])
        except Exception:
            chain = None
        row["step"], row["of"] = (chain[0], chain[1]) if chain else (0, 0)
        row["after"] = chain[2] if chain else None
        with lock:
            done[0] += 1
            if done[0] % 100 == 0:
                print("    %s %d/%d" % (label, done[0], len(rows)), flush=True)

    threads = []
    for row in rows:
        t = threading.Thread(target=work, args=(row,))
        t.start()
        threads.append(t)
        while sum(1 for x in threads if x.is_alive()) >= jobs:
            time.sleep(0.02)
    for t in threads:
        t.join()


def q(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    want = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            want = set(a.split("=", 1)[1].split(","))

    lists = gather()
    for name, rows in lists.items():
        print("%-8s %5d quests" % (name, len(rows)))

    if "--detail" in sys.argv:
        for name in ("dungeon", "raid", "normal"):
            if want and name not in want:
                continue
            print("  reading %s quest pages..." % name, flush=True)
            detail(lists[name], name)

    lines = ["-- Every quest Wowhead lists for Forever, in three piles.",
             "-- Built by tools/fetch_quests.py. Its own addon so it can be switched off.",
             "--",
             "-- WolfpackAddonQuestData.<pile>[i] =",
             "--   { id, name, level, min, side, class, zone, giver, giverZone, x, y,",
             "--     step, of, after }",
             "-- side: 1 Alliance, 2 Horde, 3 anybody. class: a bitmask, 0 for anybody.",
             "WolfpackAddonQuestData = {"]
    for name in ("dungeon", "raid", "normal"):
        lines.append("    %s = {" % name)
        for r in lists[name]:
            lines.append("        { %d, %s, %d, %d, %d, %d, %s, %s, %s, %s, %s, %d, %d, %s },"
                         % (r["id"], q(r["name"]), r["level"], r["min"], r["side"], r["cls"],
                            q(r["zone"]) if r.get("zone") else "nil",
                            q(r["giver"]) if r.get("giver") else "nil",
                            q(r["gzone"]) if r.get("gzone") else "nil",
                            r.get("x") or 0, r.get("y") or 0,
                            r.get("step") or 0, r.get("of") or 0,
                            q(r["after"]) if r.get("after") else "nil"))
        lines.append("    },")
    lines.append("}")
    os.makedirs(ADDON, exist_ok=True)
    open(os.path.join(ADDON, "Data.lua"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

    toc = ["## Interface: 16001",
           "## Title: Wolfpack Addon |cff888888- Quests|r",
           "## Notes: Every quest Wowhead lists for Forever, for the Adventure panels. Untick it "
           "to save the memory; everything else carries on without it.",
           "## Author: severin",
           "## Version: 1.0.0",
           "",
           "Data.lua"]
    open(os.path.join(ADDON, "WolfpackAddon_Quests.toc"), "w", encoding="utf-8").write(
        "\n".join(toc) + "\n")
    print("wrote %s (%.1f MB)" % (ADDON,
          os.path.getsize(os.path.join(ADDON, "Data.lua")) / 1048576.0))


if __name__ == "__main__":
    main()
