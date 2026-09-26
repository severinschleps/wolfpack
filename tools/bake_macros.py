#!/usr/bin/env python3
"""Turn a WoW macros-cache.txt into WolfpackAddon/Data/Macros.lua.

The game writes its macro list as `VER 3 <id> "<name>" "<icon>"`, the lines of the macro, then
END. The names in this one say which class each belongs to -- "war", "pri", "..." for the ones
that suit anybody -- so that is what sorts them onto shelves.

A macro named after its class is no use on an action bar, so each gets a name read out of what
it actually does: the spell in its #showtooltip, or the first thing it casts.

    python3 tools/bake_macros.py <macros-cache.txt>
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "WolfpackAddon", "Data", "Macros.lua")

SHELVES = {
    "...": "GENERAL", "dru": "DRUID", "hnt": "HUNTER", "htn": "HUNTER",  # htn is a typo for hnt
    "mag": "MAGE", "pal": "PALADIN", "pri": "PRIEST", "rog": "ROGUE",
    "shm": "SHAMAN", "war": "WARRIOR", "wl": "WARLOCK",
}
QUESTION_MARK = "134400"   # the game's default icon: let the addon pick from the spell instead
ORDER = ["GENERAL", "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN",
         "WARLOCK", "WARRIOR"]

SLASH = re.compile(r"^/(\w+)\s*(.*)$")


def title(text):
    small = {"of", "the", "and", "to"}
    words = text.split()
    out = []
    for i, w in enumerate(words):
        out.append(w if (w.lower() in small and i > 0) else w[:1].upper() + w[1:])
    return " ".join(out)


def spell_of(line):
    """The spell in one macro line, with any [conditional] and ;fallbacks stripped off."""
    line = re.sub(r"\[[^\]]*\]", "", line)
    line = line.split(";")[0].split(",")[0]
    line = line.replace("!", "").strip()
    return line or None


def name_for(body, fallback):
    """What to call it: what its tooltip shows, else the first thing it casts or uses.

    /startattack comes first in half of these and says nothing about the macro, so the spells
    are looked for across every line before any other verb is considered."""
    head = body.splitlines()[0] if body else ""
    m = re.match(r"^#show(?:tooltip)?\s+(.+)$", head.strip())
    if m:
        got = spell_of(m.group(1))
        if got:
            return title(got)
    for line in body.splitlines():
        m = SLASH.match(line.strip())
        if not m or m.group(1).lower() not in ("cast", "use", "castsequence"):
            continue
        rest = re.sub(r"^reset=\w+\s*", "", m.group(2))
        got = spell_of(rest)
        if got and not got.lower().startswith("item:") and got.lower() != "null":
            return title(got)
    for line in body.splitlines():
        m = SLASH.match(line.strip())
        if not m:
            continue
        verb, rest = m.group(1).lower(), m.group(2)
        if verb in ("equip", "equipslot"):
            return "Weapon swap"
        if verb == "click":
            return title(re.sub(r"(?<!^)(?=[A-Z])", " ", rest).replace("Micro Button", "").strip())
        if verb in ("petattack", "petfollow"):
            return "Pet " + verb[3:]
        if verb == "cancelaura":
            return title("cancel " + rest)
    return fallback


def parse(path):
    shelves = {k: [] for k in ORDER}
    lines = open(path, encoding="utf-8").read().splitlines()
    i = 0
    while i < len(lines):
        head = re.match(r'^VER \d+ \w+ "(.*)" "(.*)"$', lines[i])
        if not head:
            i += 1
            continue
        tag, icon = head.group(1), head.group(2)
        body = []
        i += 1
        while i < len(lines) and lines[i].strip() != "END":
            body.append(lines[i].rstrip())
            i += 1
        i += 1
        text = "\n".join(body).strip()
        shelf = SHELVES.get(tag)
        if not shelf:  # a macro the user named themselves: sort it by what it casts
            shelf = "HUNTER" if "hunter's mark" in text.lower() else "GENERAL"
        shelves[shelf].append({
            "name": name_for(text, tag),
            "body": text,
            "icon": None if icon == QUESTION_MARK else icon,
        })
    # names have to be unique on a shelf, or they collide in the game's own macro list
    for rows in shelves.values():
        seen = {}
        for r in rows:
            base = r["name"][:16]
            n = seen.get(base, 0) + 1
            seen[base] = n
            r["name"] = base if n == 1 else ("%s %d" % (base[:14], n))
        rows.sort(key=lambda r: r["name"])
    return shelves


def q(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main():
    src = sys.argv[1]
    shelves = parse(src)
    out = ["-- Macros to start from, one shelf per class plus the ones that suit anybody.",
           "-- Baked by tools/bake_macros.py out of a macros-cache.txt; they are copied onto a",
           "-- shelf the first time it is seen and are yours to change or delete after that.",
           "--",
           "-- ns.bakedMacros.CLASS[i] = { name, body, icon }",
           "local _, ns = ...",
           "ns.bakedMacros = {"]
    for shelf in ORDER:
        rows = shelves[shelf]
        out.append("    %s = {" % shelf)
        for r in rows:
            out.append("        { name = %s, body = %s, icon = %s },"
                       % (q(r["name"]), q(r["body"]), q(r["icon"]) if r["icon"] else "nil"))
        out.append("    },")
        print("%-9s %d" % (shelf, len(rows)))
    out.append("}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("wrote %s" % OUT)


if __name__ == "__main__":
    main()
