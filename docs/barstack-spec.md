# Bar Stack — WoW Addon Spec

Nov 1, 2026 · @severin

## Overview

Bar Stack (working name) is a WoW addon that lets the player build any number of single-purpose bars, each holding one or a few spells, and layer them on top of each other in a fixed order inside one movable parent frame. It targets WoW Midnight retail (12.x) and WoW Forever (1.60.x, interface 16001), which both run on the Midnight client.

The player decides layout and layer order. Blizzard decides when something is visible. Because of Midnight's secret-value rules, the addon never reads combat state itself: it borrows Blizzard's Cooldown Manager frames, which Blizzard shows and hides, and places them into the player's bars.

Example: an Overpower proc bar sits on top of a base-rotation bar. When the proc is active, its bar appears and covers the layer below. When it ends, the bar hides and the lower layer shows through.

## Goals and non-goals

**Goals**

- Create unlimited bars, each with one or more spells.
- Per-bar visibility mode: always, only while a buff/debuff is active, or only while a spell/proc is active.
- Fixed, player-chosen layer order (which bar is on top, which underneath).
- One parent frame the player moves in the WoW UI; every bar is anchored to it.
- One codebase for Midnight and WoW Forever.
- Settings that persist reliably on both clients.

**Non-goals**

- No automatic priority sorting or rotation logic. Midnight blocks it, and Blizzard's own rotation helper covers it.
- No combat-log parsing or reading secret values.
- No support for Classic Era or other non-Midnight clients in v1.

## Core concepts

| Concept | What it is | Key settings |
| --- | --- | --- |
| Stack | The single parent frame; all bars anchor to it | Position (Edit Mode), scale, opacity, show in/out of combat |
| Bar | A container inside the stack holding 1+ spell widgets | Name, offset from stack, size, orientation, layer index, visibility mode, style |
| Spell widget | One borrowed Cooldown Manager frame (icon or bar) for one spell | Spell (ranks grouped), display type, glow, text |
| Visibility mode | Which Blizzard frame type the widget borrows | Always (cooldown frame) · While aura active (buff/debuff tracker frame) · While proc active (proc/aura frame) |
| Layer index | Integer per bar; higher = drawn on top | Set by drag-reorder in the config list |

Layering uses frame levels inside one strata: layer index maps to `SetFrameLevel(base + index * step)`. Bars at the same offset overlap; a hidden bar is transparent, so the next layer down shows through.

## UX

There are two surfaces: the config window builds and orders bars, and Edit Mode only moves the stack.

**Config window** (`/bs`, addon compartment button)

- Left: bar list. Top of list = top layer. Drag to reorder layers. Buttons: new, duplicate, delete.
- Right: selected bar's settings: name, visibility mode, spells, size, orientation, offset from stack, style.
- Spell picker: lists spells currently in Blizzard's Cooldown Manager, ranks grouped into one entry. A hint links to Blizzard's Cooldown Manager to add missing spells.
- Live preview: toggle "show all bars" to see every layer out of combat, even hidden ones, with layer numbers.
- Profiles: per character + spec; import/export string.

**In the game world**

- One stack frame, registered with Blizzard Edit Mode (via LibEditMode). In Edit Mode it shows an outline and a label; drag to move. Nothing else is editable there.
- Out of Edit Mode it's invisible except for the bars Blizzard currently shows.

**Rules**

- Layout changes apply out of combat only; changes made in combat queue until combat ends.

## Technical architecture

The addon owns layout; Blizzard owns state. It borrows the Cooldown Manager's frames instead of computing anything from combat data.

**Data flow**

1. The player adds spells in Blizzard's Cooldown Manager (Essential, Utility, Tracked Buffs, Tracked Bars). The addon can't edit that list.
2. On load and on Cooldown Manager refresh, the addon scans the viewer frames and maps each child frame to its spell ID.
3. For each configured spell widget, it re-parents the matching Blizzard frame into the bar container, or mirrors it into its own frame if re-parenting proves unstable.
4. Blizzard keeps driving the frame: cooldown swipe, charges, glow, and show/hide for auras.
5. The addon applies size, style and layer level, and re-applies after every Cooldown Manager layout pass.

**Secret-value constraints**

- The addon never branches on a combat value (cooldown remaining, aura present, proc active). Visibility comes only from Blizzard's own show/hide.
- Its own cooldown frames, if any, are configured only with `SetCooldownFromDurationObject`.
- Wrap every Blizzard read in `pcall`; treat secret returns as "unknown".
- Never call Blizzard's protected layout manager; it taints the session.

**Stability**

- Cooldown Manager re-layouts reposition frames after settings changes. Hook its refresh and re-apply placement each time (approach used by EnhancedUI and others).
- A debug command (`/bs check`) lists which needed APIs exist and which return secrets on the current client.

## WoW Forever specifics

Forever uses the same client and rules as Midnight, with three differences the addon must handle.

- **TOC:** ship one package with interface entries for Midnight (12.x) and Forever (16001); detect the client at load.
- **Cooldown Manager off by default:** on first load, if it's disabled, show a one-time prompt pointing to Options › Gameplay Enhancement.
- **Spell ranks:** Forever lists every rank as a separate Cooldown Manager row. Group by base spell name/ID so the picker shows one entry per ability, and match any rank at runtime.
- **SavedVariables may not persist:** addon devs report the Forever client doesn't create SavedVariables for addons. See persistence below.

Reference addons: Forever Cooldowns (ranks, Edit Mode, persistence workaround) and KickAlert (settings mirrored into Blizzard tables and CVars).

## Persistence and data model

Settings are written through a storage layer with several backends, read in priority order, so the setup survives on both clients.

| Priority | Backend | Used when |
| --- | --- | --- |
| 1 | SavedVariables (`BarStackDB`) | Client creates them (Midnight) |
| 2 | Blizzard Edit Mode / layout store | SavedVariables missing (Forever) |
| 3 | Account CVar chunks | Fallback; settings serialized and split across custom CVars |
| 4 | Export string | Manual backup; always available |

Every save writes to all available backends; load takes the newest by timestamp. The whole profile is serialized and compressed (LibSerialize + LibDeflate) to keep the payload small.

**Profile schema (v1)**

```json
{
  "version": 1,
  "updated": 1730000000,
  "stack": { "point": "CENTER", "x": 0, "y": -180, "scale": 1.0 },
  "bars": [
    {
      "id": "b1",
      "name": "Overpower proc",
      "layer": 2,
      "offset": { "x": 0, "y": 0 },
      "size": { "w": 240, "h": 24 },
      "orientation": "horizontal",
      "visibility": "proc",
      "spells": [ { "baseSpell": 7384, "display": "bar" } ],
      "style": { "texture": "flat", "color": "#C79C6E" }
    }
  ]
}
```

## Risks and open questions

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Blizzard changes Cooldown Manager frame structure in a patch | Widgets stop mapping | Isolate frame scanning in one module; `/bs check` reports failures |
| Re-parenting causes taint or layout fights | Errors in combat, jumping frames | Fall back to mirroring; never touch protected layout calls |
| Forever persistence workaround breaks | Setup lost on relog | Multi-backend storage + export string |
| Proc not exposed as a trackable aura | "While proc active" mode can't work for that spell | Fall back to cooldown frame with Blizzard's proc glow |
| Blizzard tightens API further | Features removed | Keep core (layout + layering) independent of any combat read |

**Open questions**

- [ ] Does re-parenting Cooldown Manager frames survive combat on both clients, or is mirroring required?
- [ ] Is Warrior Overpower (and similar procs) a trackable buff in the Cooldown Manager on Forever?
- [ ] Can cooldown icons be set to hide while on cooldown, so they can be stacked like aura bars?
- [ ] Which Blizzard layout store keys are safe to write on Forever?
- [ ] Final addon name.

## MVP scope and milestones

The MVP proves the two risky parts first, persistence on Forever and borrowing frames, before any UI polish.

1. **Spike: persistence.** Save and reload a test table on Forever through every backend; confirm which survive relog.
2. **Spike: frame borrowing.** Re-parent one Cooldown Manager buff frame into a custom frame; verify it shows/hides correctly in combat on Midnight and Forever.
3. **Stack + Edit Mode.** Parent frame registered with Edit Mode, movable, position saved.
4. **Bars + layering.** Create bars from code, assign spells, set layer order; confirm overlap and show-through.
5. **Config window.** Bar list with drag-reorder, per-bar settings, spell picker with grouped ranks, preview mode.
6. **Profiles + export.** Per spec profiles, import/export string.
7. **Release.** CurseForge + Wago, one package for both clients.

**Out of MVP:** custom textures library, sounds, item/trinket tracking, multiple stacks.
