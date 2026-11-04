# Wolfpack Addon

## Install to the game after every change

Every game's `Interface/AddOns/WolfpackAddon` is a symlink to this repo's
`WolfpackAddon/` (main checkout, not a worktree). A save is live at the next
`/reload`, so there is no copy step. Work from a worktree goes live only once it
is merged into the main checkout.

`link-addons.sh` (local, gitignored) finds every `AddOns` folder under
`/Users/severin/Games/World of Warcraft/` and (re)creates the links. Git hooks
(pre-push, post-commit, post-merge, post-checkout) and the Stop hook in
`.claude/settings.json` run it. Never `rsync` into the game folders: it would
write through the symlink into this repo.

Because saves go live right away, run the tests before you `/reload`:

```bash
luajit test/smoke.lua && luajit test/barstack.lua
```

The Stop hook runs them too and says so if they fail.

One copy serves all: the toc lists Classic Era's interface (11509), Forever's
(16001), Anniversary's (20506), Classic's (50504) and Midnight's (120105, 120107). Add the new number
when a client patches.

Run the tests before you report the change as done. If they fail, fix it in the
same turn: the broken version is already live.

## Push to GitHub after every change

Every change that is saved -- tested and installed as above -- is committed and pushed to
GitHub (`origin`, master) in the same turn: `git add -A`, a conventional-commit message,
`git pull --rebase` (other sessions push here too), `git push`. Never leave a finished change
unpushed at the end of a turn.

## Testing

`test/smoke.lua` runs the addon against a mock WoW API: `luajit test/smoke.lua`
prints `smoke ok`. `test/barstack.lua` does the same for Bar Stack and prints `barstack ok`. Every non-trivial change gets a check there, and a fix for a
real bug gets a test that fails without the fix.

## Bar Stack

`WolfpackAddon/BarStack/` is Bar Stack, which used to be its own addon: bars built from
Blizzard's Cooldown Manager frames, with its own page in the options window (`/bs`) and its own saved data
(`BarStackDB`, plus a copy in account CVars). It keeps its names on `ns.bs` so they never meet
Wolfpack's. Design and status notes are in `docs/`.
