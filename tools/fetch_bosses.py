#!/usr/bin/env python3
"""Add boss positions to WolfpackAddon_Loot/Data.lua.

Wowhead marks nothing inside an instance and the client will not say where anything is in
there, so the positions come from SimpleDungeonMap (MIT licence, Babilounet), which carries
hand-calibrated coordinates for every Classic dungeon boss as a percentage across the map --
the same space as the pictures we ship.

    python3 tools/fetch_bosses.py          # fetch, match, rewrite the loot file
    python3 tools/fetch_bosses.py --check  # also draw a picture per dungeon to look at
"""

import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache")
LOOT = os.path.join(os.path.dirname(HERE), "WolfpackAddon_Loot", "Data.lua")
MAPS = os.path.join(os.path.dirname(HERE), "WolfpackAddon_Maps", "Maps")
SRC = "https://raw.githubusercontent.com/Babilounet/SimpleDungeonMap/master/DungeonData.lua"


def flat(name):
    return re.sub(r"[^a-z]", "", name.lower())


def source(refresh=False):
    hit = os.path.join(CACHE, "SimpleDungeonMap.lua")
    if not refresh and os.path.exists(hit):
        return open(hit, encoding="utf-8").read()
    req = urllib.request.Request(SRC, headers={"User-Agent": "wolfpack-addon-build"})
    with urllib.request.urlopen(req, timeout=30) as r:
        body = r.read().decode("utf-8")
    os.makedirs(CACHE, exist_ok=True)
    open(hit, "w", encoding="utf-8").write(body)
    return body


def bosses_by_place(text):
    """{flattened dungeon name: [(boss, x, y, floor)]}, read off the boss tables."""
    out = {}
    for row in re.finditer(
            r'\{\s*"([^"]+)",\s*([\d.]+),\s*([\d.]+),\s*(\d+),\s*"([^"]+)",\s*\d+\s*\}', text):
        name, x, y, floor, folder = row.groups()
        out.setdefault(flat(folder), []).append((name, float(x), float(y), int(floor)))
    return out


def on_the_map(zone, x, y):
    """Is there any map under that spot, or is it black nothing?

    A dungeon on several floors has a picture per floor on the site these came from, while
    Wowhead publishes one. Coordinates for the other floors land off the drawing, and the
    drawing is on pure black, so the picture itself says which ones to drop."""
    from PIL import Image
    src = os.path.join(CACHE, "maps", "%d.jpg" % zone)
    if not os.path.exists(src) or not os.path.getsize(src):
        return True     # no picture to check against: keep it
    art = on_the_map.cache.get(zone)
    if art is None:
        art = Image.open(src).convert("RGB").resize((768, 512))
        on_the_map.cache[zone] = art
    px, py = int(x / 100 * 768), int(y / 100 * 512)
    # the brightest thing nearby: a boss in a dark corridor still has map around it, while one
    # belonging to another floor sits on pure black
    best = 0
    for dx in range(-10, 11, 2):
        for dy in range(-10, 11, 2):
            at = (min(max(px + dx, 0), 767), min(max(py + dy, 0), 511))
            r, g, b = art.getpixel(at)
            best = max(best, r + g + b)
    return best > 45


on_the_map.cache = {}


def main():
    text = source("--refresh" in sys.argv)
    found = bosses_by_place(text)
    print("%d places in SimpleDungeonMap" % len(found))

    loot = open(LOOT, encoding="utf-8").read()
    if "spots = {" in loot:
        sys.exit("This one has boss positions already. Rebuild the loot file first:\n"
                 "  python3 tools/fetch_loot.py && python3 tools/fetch_bosses.py")

    placed, missed = 0, []
    # backwards: every insertion shifts everything after it, and nothing before it
    for m in reversed(list(re.finditer(r'\{ id = (\d+), name = "([^"]+)", lo = ', loot))):
        zone, name = int(m.group(1)), m.group(2)
        rows = found.get(flat(name))
        if not rows:  # Wowhead's name is not always theirs
            for key, value in found.items():
                if key in flat(name) or flat(name) in key:
                    rows = value
                    break
        if not rows:
            missed.append(name)
            continue
        kept = [r for r in rows if on_the_map(zone, r[1], r[2])]
        if len(kept) < len(rows):
            print("      (%d of %d land off the picture and are left out)"
                  % (len(rows) - len(kept), len(rows)))
        rows = kept
        if not rows:
            missed.append(name)
            continue
        block = ["spots = {"]
        for boss, x, y, floor in rows:
            block.append('            { %s, %.1f, %.1f, %d },'
                         % ('"%s"' % boss.replace('"', '\\"'), x, y, floor))
        block.append("        },")
        # in the dungeon's own table, ahead of its bosses -- not inside the list that follows
        at = loot.index(" bosses = {", m.end())
        loot = loot[:at] + "\n        " + "\n".join(block) + "\n       " + loot[at:]
        placed += len(rows)
        print("  %-34s %2d bosses placed" % (name, len(rows)))
    for name in missed:
        print("  %-34s nobody has placed these" % name)

    loot = loot.replace(
        "-- WolfpackAddonLootData[i] = { id, name, lo, hi, bosses",
        "-- Boss positions (spots) come from SimpleDungeonMap by Babilounet, MIT licence:\n"
        "-- { name, x, y, floor } as a percentage across the map picture.\n"
        "--\n"
        "-- WolfpackAddonLootData[i] = { id, name, lo, hi, spots, bosses", 1)
    open(LOOT, "w", encoding="utf-8").write(loot)
    print("%d boss positions written" % placed)

    if "--check" in sys.argv:
        draw(loot)


def draw(loot):
    """A picture per dungeon with the pins on it, to be looked at before shipping."""
    from PIL import Image, ImageDraw
    out = os.path.join(CACHE, "check")
    os.makedirs(out, exist_ok=True)
    for m in re.finditer(r'\{ id = (\d+), name = "([^"]+)", lo = .*?spots = \{(.*?)\n        \},',
                         loot, re.S):
        zone, name, block = int(m.group(1)), m.group(2), m.group(3)
        src = os.path.join(CACHE, "maps", "%d.jpg" % zone)
        if not os.path.exists(src) or not os.path.getsize(src):
            continue
        art = Image.open(src).convert("RGB").resize((768, 512))
        pen = ImageDraw.Draw(art)
        for row in re.finditer(r'\{ "([^"]+)", ([\d.]+), ([\d.]+), (\d+) \}', block):
            boss, x, y, floor = row.group(1), float(row.group(2)), float(row.group(3)), row.group(4)
            px, py = x / 100 * 768, y / 100 * 512
            pen.ellipse([px - 5, py - 5, px + 5, py + 5], fill=(255, 40, 40), outline=(0, 0, 0))
            pen.text((px + 8, py - 5), "%s (%s)" % (boss, floor), fill=(255, 255, 0))
        art.save(os.path.join(out, "%s.png" % flat(name)))
    print("check pictures in %s" % out)


if __name__ == "__main__":
    main()
