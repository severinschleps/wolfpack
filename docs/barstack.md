# Bar Stack

A WoW addon for Midnight retail (12.x) and WoW Forever (interface 16001). You build single-purpose bars, each holding one or a few spells, and stack them in a fixed layer order inside one movable frame.

The addon handles layout only. It borrows the frames from Blizzard's Cooldown Manager, and Blizzard decides when each one shows. Because of Midnight's secret-value rules, the addon never reads combat state itself.

Full design: [barstack-spec.md](barstack-spec.md)

## Install

Bar Stack now ships inside Wolfpack Addon (`WolfpackAddon/BarStack/`), so installing Wolfpack installs it.
It used to be its own addon, github.com/severinschleps/bar-stack; that repo is no longer where it changes.

## Use

1. Add the spells you want in Blizzard's Cooldown Manager (Options › Gameplay Enhancements).
2. Type `/bs`, or press **Bar Stack** in Wolfpack's options sidebar, to open its page in the options window.
3. The flow is group > bar > icon > conditions. Click **New** to create a bar (**Settings** above
   the list opens its name, size, direction and offset in a flyout), then **Add icon**.
   The **Icon** dialog opens beside the window:
   - **Looks like**: *My own picture* (a spell's picture, or a texture typed in: file ID, path
     or spell name, optionally with the spell's cooldown swipe), *Blizzard's cooldown icon*
     (cooldown and charges), or *Blizzard's aura icon* (Tracked Buffs, with its timer; Blizzard
     shows it only while the aura is up).
   - **Shows while all of these hold**: *Usable* (a spell can be pressed, as the action bar
     shows it), *Aura up* / *Aura missing* (a Tracked Buffs spell), *Target* (you have one), *In form* / *Not in form* (a stance, druid form or anything
     on your stance bar), *Stealthed* / *Not stealthed*.
     None: always shown. Example: Execute's picture, shown while Rend is up AND Thunder Clap is
     up AND Mortal Strike is usable.

   Each condition is one frame between the bar and the icon; opacity multiplies down that chain,
   so the AND never reads the answers, which are secret in combat. Usable and Target need no
   Cooldown Manager. An aura condition, or an icon of Blizzard's, needs its spell there, because
   in combat only Blizzard's frame can say an aura is up. One Rend in Tracked Buffs serves an
   aura icon and any number of conditions at once. A higher bar covers the ones below only
   while it has something to show, so a stack works as a priority list. **Icon gap** spaces
   the icons. Bars from before icons convert by themselves: each spell becomes an icon that
   shows the way the bar's old Show setting did.

   **Why no flash near the end:** tried, and taken out. In Midnight an addon cannot reach an
   aura's time left: Blizzard sets the icon's Cooldown with `SetCooldown(start, length)`, both
   secret; `DurationObject:SetTimeFromStart` refuses them and `C_UnitAuras.GetAuraDuration`
   refuses the aura, both "while tainted". Blizzard's own refresh-window border animation makes
   no Lua call an addon could hear either (timed in game: the border only switches as the debuff
   goes up and drops). What is plain is when the icon shows and hides, so a stopwatch with a
   typed-in or learned duration is the one way left, if it is ever wanted.

   **Why no bars:** no addon can run an aura's timer on a bar of its own -- in Midnight,
   `C_UnitAuras.GetAuraDuration` and `DurationObject:SetTimeFromStart` both refuse secrets from
   addon code (tried, and seen refused in game). Blizzard's own Tracked Bars frames were tried too:
   they did not say reliably which spell they show, so Bar Stack leaves Tracked Bars alone.
   **Hide Blizzard's Cooldown Manager** (on by default, at the bottom of the page) keeps
   Blizzard's viewers invisible. Do not hide them with their own Visibility setting in Edit
   Mode: a hidden viewer fills none of its icons (seen in game, in and out of combat), so Bar
   Stack has nothing to read. Leave that on Always; Edit Mode shows them again to place them.
4. Use the up / down arrows on a bar's row (or drag it) to reorder; icons in a bar have the same arrows. The top of the list is the top layer.
5. **New group** starts another stack with its own position, scale and combat settings. The
   dropdown above the list picks which group you are editing.
6. Open Edit Mode to drag each stack around the screen.

Other commands:
- `/bs check` shows which APIs and storage backends work on this client. Run it after a relog to see which saved settings survived.
- **Export** / **Import** on the Bar Stack page copies a profile as a string.

## Status

Version 0.1.0 has not been tested in game yet. The two spikes from the spec (persistence on Forever, frame borrowing in combat) still need checking on a live client. Use `/bs check` for that.

Things that differ from the spec:
- No LibEditMode, LibSerialize or LibDeflate. Blizzard's `EventRegistry` Edit Mode callbacks and `C_EncodingUtil` do the same jobs, so nothing extra is bundled.
- The Edit Mode layout-store backend is not built yet. Which keys are safe to write is still an open question. Settings are saved through SavedVariables, CVar chunks and the export string.
- Per-widget glow and text options are not included. Blizzard's frames draw their own glow and text.

## Test

`luajit test/barstack.lua` tests the storage, normalization, import and rank-grouping logic using stubbed WoW APIs.
