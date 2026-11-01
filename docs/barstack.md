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
3. Click **New** to create a bar, pick when it shows under **Show**, and click **Add spell**.
   Every spell shows as Blizzard's icon, with its own countdown. "Only while aura / debuff / proc is
   active" borrow from **Tracked Buffs** only, which Blizzard shows just while the aura is up. That
   is what makes a stack work as a priority list: a higher bar covers the ones below only while it
   has something to say. Bars set to "Always" use the cooldown icon, which never hides.
   "Only while debuff is missing" draws its own icon and only watches Blizzard's frame, so one
   spell in Tracked Buffs serves a "debuff is active" icon and a "debuff is missing" icon together.
   Both debuff choices show only while you have a target.
   **Icon gap** spaces the icons in a bar.

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
4. Use **Move up** / **Move down** (or drag) to reorder. The top of the list is the top layer.
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
