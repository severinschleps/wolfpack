#!/usr/bin/env python3
"""Build WolfpackAddon_Maps from Wowhead's Forever dungeon maps.

This client ships map art for outdoor zones only -- 57 of them, not one dungeon -- and gives no
map id inside an instance, so the game cannot draw these and cannot say where you are on them.
The pictures therefore have to travel with the addon.

Wowhead's own mapper builds its url as /images/wow/<env>/maps/<locale>/<size>/<zone>.jpg, and
Forever's tree is `classicplus`. The originals are 1002x668, which scales to 768x512 exactly --
six 256x256 tiles, three across -- so nothing is padded or cropped.

    python3 tools/fetch_maps.py            # fetch what is missing, write the addon
    python3 tools/fetch_maps.py --refresh  # fetch it all again
"""

import io
import os
import re
import sys
import time
import urllib.request

try:
    from PIL import Image
except ImportError:
    sys.exit("This needs Pillow: python3 -m pip install Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, ".cache", "maps")
ADDON = os.path.join(os.path.dirname(HERE), "WolfpackAddon_Maps")
LOOT = os.path.join(os.path.dirname(HERE), "WolfpackAddon_Loot", "Data.lua")
BASE = "https://wow.zamimg.com/images/wow/classicplus/maps/enus/original"

TILE = 256
ACROSS, DOWN = 3, 2          # 768 x 512, the exact shape of a 1002x668 original
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
                  "(KHTML, like Gecko) Version/17.4 Safari/605.1.15",
    "Referer": "https://www.wowhead.com/",
}
last = [0.0]


def dungeons():
    """(zone id, name) for everything in the loot tables."""
    text = open(LOOT, encoding="utf-8").read()
    # only the dungeon rows: a boss row has no level range after its name
    return [(int(z), name) for z, name in
            re.findall(r'\{ id = (\d+), name = "([^"]+)", lo = ', text)]


def grab(zone, refresh=False):
    hit = os.path.join(CACHE, "%d.jpg" % zone)
    if not refresh and os.path.exists(hit):
        return open(hit, "rb").read() or None
    wait = 1.0 - (time.time() - last[0])
    if wait > 0:
        time.sleep(wait)
    last[0] = time.time()
    req = urllib.request.Request("%s/%d.jpg" % (BASE, zone), headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read()
    except Exception:
        body = b""      # no map for this one; remember that so we stop asking
    os.makedirs(CACHE, exist_ok=True)
    open(hit, "wb").write(body)
    return body or None


def cut(raw, zone):
    """Six tiles, written as the uncompressed TGA the game reads. Returns how many bytes."""
    art = Image.open(io.BytesIO(raw)).convert("RGB").resize(
        (TILE * ACROSS, TILE * DOWN), Image.LANCZOS)
    out = os.path.join(ADDON, "Maps")
    os.makedirs(out, exist_ok=True)
    written = 0
    for i in range(ACROSS * DOWN):
        col, row = i % ACROSS, i // ACROSS
        tile = art.crop((col * TILE, row * TILE, (col + 1) * TILE, (row + 1) * TILE))
        path = os.path.join(out, "%d_%d.tga" % (zone, i + 1))
        tile.save(path)          # Pillow writes uncompressed 24-bit TGA
        written += os.path.getsize(path)
    return written


def main():
    refresh = "--refresh" in sys.argv
    found, bytes_out = [], 0
    for zone, name in dungeons():
        raw = grab(zone, refresh)
        if not raw:
            print("  %-34s no map on Wowhead" % name)
            continue
        bytes_out += cut(raw, zone)
        found.append((zone, name))
        print("  %-34s %d KB of tiles" % (name, bytes_out // 1024))

    lines = ["-- Dungeon maps, cut from Wowhead's Forever pictures by tools/fetch_maps.py.",
             "-- Its own addon so it can be switched off: 20-odd megabytes of tiles.",
             "--",
             "-- This client draws no dungeon maps of its own and will not say where you are",
             "-- inside one, so these are pictures only -- no arrow, no floors.",
             "--",
             "-- WolfpackAddonMapData[wowhead zone id] = { name, across, down, tiles = { path } }",
             "WolfpackAddonMapData = {"]
    for zone, name in found:
        tiles = ", ".join('"Interface\\\\AddOns\\\\WolfpackAddon_Maps\\\\Maps\\\\%d_%d.tga"'
                          % (zone, i + 1) for i in range(ACROSS * DOWN))
        lines.append('    [%d] = { name = "%s", across = %d, down = %d, tiles = { %s } },'
                     % (zone, name.replace('"', '\\"'), ACROSS, DOWN, tiles))
    lines.append("}")
    os.makedirs(ADDON, exist_ok=True)
    open(os.path.join(ADDON, "Data.lua"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

    toc = ["## Interface: 16001",
           "## Title: Wolfpack Addon |cff888888- Dungeon Maps|r",
           "## Notes: Pictures of the dungeons for the Dungeons & Raids panel, taken from "
           "Wowhead. Untick it to save the space; everything else carries on without it.",
           "## Author: severin",
           "## Version: 1.0.0",
           "",
           "Data.lua"]
    open(os.path.join(ADDON, "WolfpackAddon_Maps.toc"), "w", encoding="utf-8").write(
        "\n".join(toc) + "\n")
    print("%d maps, %.1f MB" % (len(found), bytes_out / 1048576.0))


if __name__ == "__main__":
    main()
