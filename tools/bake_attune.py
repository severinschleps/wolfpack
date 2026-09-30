#!/usr/bin/env python3
"""Build WolfpackAddon/Data/Attune.lua -- what stands between you and each locked door.

The Attune addon is All Rights Reserved, so none of it is copied. Which quest or key opens a
place is a fact about the game, and every id below is checked against Wowhead's Forever pages
before it ships: if the name it comes back with is not the name we expect, the step is dropped
rather than shipped wrong. Same rule as the boss pins.

    python3 tools/bake_attune.py           # verify and write
    python3 tools/bake_attune.py --loose   # write even the steps that did not verify
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_loot as F   # its cache and its polite fetching

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "WolfpackAddon", "Data", "Attune.lua")

# { place, side, [ (kind, id, expected name) ] }.  kind: q = quest, i = item, r = reputation
ATTUNEMENTS = [
    ("Blackrock Depths", "both", [
        ("i", 11000, "Shadowforge Key"),
        ("i", 11197, "Dark Keeper Key"),
    ]),
    ("Upper Blackrock Spire", "both", [
        ("q", 4742, "Seal of Ascension"),
        ("i", 12219, "Unadorned Seal of Ascension"),
        ("i", 12335, "Gemstone of Smolderthorn"),
        ("i", 12336, "Gemstone of Spirestone"),
        ("i", 12337, "Gemstone of Bloodaxe"),
    ]),
    ("Scholomance", "both", [
        ("i", 13704, "Skeleton Key"),
    ]),
    ("Stratholme", "both", [
        ("i", 12382, "Key to the City"),
        ("q", 5214, "The Great Fras Siabi"),
    ]),
    ("Dire Maul", "both", [
        ("i", 18249, "Crescent Key"),
        ("i", 18250, "Gordok Shackle Key"),
    ]),
    ("Maraudon", "both", [
        ("q", 7046, "The Scepter of Celebras"),
        ("i", 17191, "Scepter of Celebras"),
    ]),
    ("Molten Core", "both", [
        ("q", 7848, "Attunement to the Core"),
        ("i", 17333, "Aqual Quintessence"),
    ]),
    ("Onyxia's Lair", "alliance", [
        ("q", 6502, "Drakefire Amulet"),
    ]),
    ("Onyxia's Lair", "horde", [
        ("q", 4903, "Warlord's Command"),
    ]),
    ("Blackwing Lair", "both", [
        ("q", 7761, "Blackhand's Command"),
    ]),
    ("Naxxramas", "both", [
        ("r", 529, "Argent Dawn"),
    ]),
]


def title(kind, ident):
    """What Wowhead calls it, or None."""
    path = {"q": "/quest=%d", "i": "/item=%d"}[kind] % ident
    html = F.get(path)
    if not html:
        return None
    got = re.search(r"<title>(.*?)</title>", html, re.S)
    if not got:
        return None
    name = got.group(1)
    name = re.sub(r"\s*-\s*(Quest|Item)\s*-\s*Forever\s*$", "", name).strip()
    return name or None


def q(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    loose = "--loose" in sys.argv
    rows = []
    for place, side, steps in ATTUNEMENTS:
        kept = []
        for kind, ident, expect in steps:
            if kind == "r":
                kept.append((kind, ident, expect))     # a faction id, nothing to look up
                continue
            got = title(kind, ident)
            same = got and got.lower() == expect.lower()
            print("  %-22s %s %-7d %-34s %s" % (place, kind, ident, expect,
                                                "ok" if same else "-> %s" % got))
            if same or loose:
                kept.append((kind, ident, got or expect))
        if kept:
            rows.append((place, side, kept))

    out = ["-- What stands between you and each locked door.",
           "-- Checked against Wowhead's Forever pages by tools/bake_attune.py: a step whose name",
           "-- does not come back the same is left out rather than shipped wrong. Nothing here is",
           "-- taken from the Attune addon, which is All Rights Reserved.",
           "--",
           "-- ns.attune[i] = { place, side, steps = { { kind, id, name } } }",
           "-- kind: q a quest you must have finished, i an item you must hold, r a reputation",
           "local _, ns = ...",
           "ns.attune = {"]
    for place, side, steps in rows:
        out.append('    { place = %s, side = %s, steps = {' % (q(place), q(side)))
        for kind, ident, name in steps:
            out.append('        { %s, %d, %s },' % (q(kind), ident, q(name)))
        out.append("    } },")
    out.append("}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("%d places, %d steps" % (len(rows), sum(len(s) for _, _, s in rows)))


if __name__ == "__main__":
    main()
