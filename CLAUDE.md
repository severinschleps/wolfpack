# Wolfpack Addon

## Install to the game after every change

Whenever you change anything under `WolfpackAddon/`, run the test and then
mirror the folder into the live game so the next `/reload` picks it up:

```bash
luajit test/smoke.lua \
  && rsync -a --delete WolfpackAddon/ \
     "/Users/severin/Games/World of Warcraft/_classic_beta_/Interface/AddOns/WolfpackAddon/" \
  && rsync -a --delete WolfpackAddon_Loot/ \
     "/Users/severin/Games/World of Warcraft/_classic_beta_/Interface/AddOns/WolfpackAddon_Loot/"
```

There are two addon folders: `WolfpackAddon/` and `WolfpackAddon_Loot/`, which holds
only the dungeon tables so they can be switched off in the game's addon list. Both
need installing.

Do this before you report the change as done, in the same turn as the edit.
Never install a version whose test fails; fix it first.

`--delete` mirrors exactly, so files you removed here disappear there too. The
game keeps its settings in `WTF/`, not in the addon folder, so nothing of the
user's is lost.

Note the target is the addon folder, not `Interface/` itself — WoW only loads
addons from it. On this Mac the disk spells it `AddOns` and `Addons` reaches
the very same directory, so either works in the command above.

## Testing

`test/smoke.lua` runs the addon against a mock WoW API: `luajit test/smoke.lua`
prints `smoke ok`. Every non-trivial change gets a check there, and a fix for a
real bug gets a test that fails without the fix.

## Dungeon and training data

`WolfpackAddon/Data/` holds generated tables. Nothing in there is hand-written:

- `Training.lua` — trainer spells, copied from What's Training? (MIT), `Classes/Camelot`.
- `../WolfpackAddon_Loot/Data.lua` — dungeon bosses, loot and quests, built by
  `tools/fetch_loot.py` from Wowhead's Forever section. It sets a global,
  `WolfpackAddonLootData`, because it is a separate addon. Rerun it when Forever
  patches:
  `python3 tools/fetch_loot.py` (add `--refresh` to ignore the cache).

- boss positions inside that same file (`spots`), added by `tools/fetch_bosses.py` from
  SimpleDungeonMap (MIT, Babilounet). Run it after `fetch_loot.py`, which it expects to
  have just rebuilt the file:
  `python3 tools/fetch_loot.py && python3 tools/fetch_bosses.py --check`
  `--check` draws a picture per dungeon under `tools/.cache/check` with the pins on it.
  A position that lands on black is dropped rather than shipped in the wrong place, which
  is what happens to the other floors of a multi-floor dungeon.

- `Attune.lua` — what each locked door wants, built by `tools/bake_attune.py`. The table of
  ids lives in that script and every one is checked against Wowhead's Forever pages before
  it ships; a name that does not come back the same is dropped. Nothing is taken from the
  Attune addon, which is All Rights Reserved.

An addon cannot reach the network at runtime, so shipping a generated table is the
only way this data gets in. Keep `tools/.cache/` out of git.

## Dungeon maps

`WolfpackAddon_Maps/` is a third addon folder, built by `tools/fetch_maps.py` from
Wowhead's Forever map pictures (`classicplus` tree, 1002x668 originals cut into six
256x256 TGA tiles each). It exists because this client ships map art for outdoor
zones only and gives no map position inside an instance. Install it alongside the
other two:

```bash
rsync -a --delete WolfpackAddon_Maps/ \
  "/Users/severin/Games/World of Warcraft/_classic_beta_/Interface/AddOns/WolfpackAddon_Maps/"
```
