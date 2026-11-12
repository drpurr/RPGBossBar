# RPG Target Frame

RPG Target Frame replaces the World of Warcraft: Forever target frame with one decorative unit bar in the Vigor Dark art used by RPG Boss Bar. It is a separate addon. RPG Boss Bar can stay enabled for boss encounters. This addon does not track bosses or the soft enemy target.

## Compatibility

Version **1.60.1-1** supports World of Warcraft: Forever 1.60.1 (`## Interface: 16001`) only.

Install the `RPGTargetFrame` folder at:

`World of Warcraft/_forever_/Interface/AddOns/RPGTargetFrame`

The folder name has to stay `RPGTargetFrame`. A new TOC needs a full client restart. Later Lua edits need `/reload`.

## What it shows

When you have a hard target, the bar shows:

- Name, colored by reaction when that value is readable
- Current health and health percent when those values are readable
- A power bar when the unit has power
- Level, including `??` for a skull level, and a classification label for elite, rare, rare elite, and boss units
- Up to 8 buff icons and 8 debuff icons, with stack counts
- A cast or channel bar, including a shield when the cast is not interruptible
- A smaller target-of-target bar with name, health, and level

The bar stays up for friendly, neutral, hostile, and dead targets. A dead target keeps the bar and shows `Dead`. Clearing your target hides the addon frame.

During combat, Midnight's secret-value rules still apply. Health and power are handed to the status bars directly. If a percent, level, aura, or cast time cannot be read, that text is left blank and the bar stays up. If auras are secret, the icon rows hide instead of erroring.

## What it leaves alone

Portrait, raid icon, PvP flag, combo points, threat, focus, pet, and boss frames are unchanged. The player frame stays visible. Profiles, skins, and Edit Mode are not part of this addon.

The default target frame is hidden out of combat. A change made in combat waits until combat ends. `/rpgtt blizzard` shows Blizzard's target frame again.

## Commands

| Command | Description |
| --- | --- |
| `/rpgtt` | Show command help |
| `/rpgtt lock` | Toggle dragging. While unlocked, drag the bar. The position is saved when you release the mouse. |
| `/rpgtt scale N` | Set the scale from 0.5 to 2 |
| `/rpgtt blizzard` | Hide or restore the default target frame |
| `/rpgtt test` | Toggle a preview with an elite target, buffs, a debuff, a cast, and a target-of-target bar |
| `/rpgtt reset` | Restore the default position, scale, and visibility |

`/rpgtargetframe` is the same command.

## In-game check

Enable script errors with `/console scriptErrors 1`. Run this once with only RPG Target Frame enabled, then again with RPG Boss Bar enabled:

- Open world: hostile, friendly, neutral, dead, and no target
- A casting mob and a channeling mob, including an interrupt
- Buffs and debuffs out of combat, including a stack count
- A dungeon pull and one boss, confirming there is no secret-value error
- The default target frame stays hidden and the player frame stays visible
- Drag the bar, `/reload`, and confirm the position stuck
- `/rpgtt test` with nothing targeted, then run it again to hide the preview

If both `TargetFrame` and `TargetFrameContainer` are missing, `/fstack` the default target frame and add that global name to `FindTargetFrame` in `HideBlizzard.lua`.
