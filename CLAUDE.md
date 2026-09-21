# Wolfpack Addon

## Install to the game after every change

Whenever you change anything under `WolfpackAddon/`, run the test and then
mirror the folder into the live game so the next `/reload` picks it up:

```bash
luajit test/smoke.lua && rsync -a --delete WolfpackAddon/ \
  "/Users/severin/Games/World of Warcraft/_classic_beta_/Interface/AddOns/WolfpackAddon/"
```

Do this before you report the change as done, in the same turn as the edit.
Never install a version whose test fails; fix it first.

`--delete` mirrors exactly, so files you removed here disappear there too. The
game keeps its settings in `WTF/`, not in the addon folder, so nothing of the
user's is lost.

Note the target is `Interface/AddOns/`, not `Interface/` — WoW only loads
addons from `AddOns/`.

## Testing

`test/smoke.lua` runs the addon against a mock WoW API: `luajit test/smoke.lua`
prints `smoke ok`. Every non-trivial change gets a check there, and a fix for a
real bug gets a test that fails without the fix.
