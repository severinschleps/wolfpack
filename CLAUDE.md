# Wolfpack Addon

## Install to the game after every change

Whenever you change anything under `WolfpackAddon/`, run the test and then
mirror the folder into both live games -- Forever and Midnight (retail) -- so the
next `/reload` picks it up:

```bash
luajit test/smoke.lua && for g in _forever_ _retail_; do
  rsync -a --delete WolfpackAddon/ \
    "/Users/severin/Games/World of Warcraft/$g/Interface/AddOns/WolfpackAddon/"
done
```

One copy serves both: the toc lists Forever's interface (16001) and Midnight's
(120105, 120107). Add the new number when either client patches.

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

## Training and attunement data

`WolfpackAddon/Data/` holds generated tables. Nothing in there is hand-written:

- `Training.lua` — trainer spells, copied from What's Training? (MIT), `Classes/Camelot`.
- `Attune.lua` — what each locked door wants, built by `tools/bake_attune.py`. The table of
  ids lives in that script and every one is checked against Wowhead's Forever pages before
  it ships (fetched through `tools/wowhead.py`); a name that does not come back the same is
  dropped. Nothing is taken from the Attune addon, which is All Rights Reserved.

An addon cannot reach the network at runtime, so shipping a generated table is the
only way this data gets in. Keep `tools/.cache/` out of git.
