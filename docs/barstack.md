# Bar Stack

A WoW addon for Midnight retail (12.x) and WoW Forever (interface 16001). You build single-purpose bars, each holding one or a few spells, and stack them in a fixed layer order inside one movable frame.

The addon handles layout only. It borrows the frames from Blizzard's Cooldown Manager, and Blizzard decides when each one shows. Because of Midnight's secret-value rules, the addon never reads combat state itself.

Full design: [barstack-spec.md](barstack-spec.md)

## Install

Bar Stack now ships inside Wolfpack Addon (`WolfpackAddon/BarStack/`), so installing Wolfpack installs it.
It used to be its own addon, github.com/severinschleps/bar-stack; that repo is no longer where it changes.

## Use

1. Add the spells you want in Blizzard's Cooldown Manager (Options › Gameplay Enhancements).
2. Type `/bs`, or press **Bar Stack** in Wolfpack's options sidebar, to open the config window.
3. Click **New** to create a bar, then set its visibility mode and click **Add spell**.
4. Drag bars in the list to reorder them. The top of the list is the top layer.
5. Open Edit Mode to drag the stack around the screen.

Other commands:
- `/bs check` shows which APIs and storage backends work on this client. Run it after a relog to see which saved settings survived.
- **Export** / **Import** in the config window copies a profile as a string.

## Status

Version 0.1.0 has not been tested in game yet. The two spikes from the spec (persistence on Forever, frame borrowing in combat) still need checking on a live client. Use `/bs check` for that.

Things that differ from the spec:
- No LibEditMode, LibSerialize or LibDeflate. Blizzard's `EventRegistry` Edit Mode callbacks and `C_EncodingUtil` do the same jobs, so nothing extra is bundled.
- The Edit Mode layout-store backend is not built yet. Which keys are safe to write is still an open question. Settings are saved through SavedVariables, CVar chunks and the export string.
- Per-widget glow and text options are not included. Blizzard's frames draw their own glow and text.

## Test

`luajit test/barstack.lua` tests the storage, normalization, import and rank-grouping logic using stubbed WoW APIs.
