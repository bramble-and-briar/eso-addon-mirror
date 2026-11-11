# PvPCooldownTracker

PvPCooldownTracker is an Elder Scrolls Online addon that displays on-screen
countdowns for the cooldowns of set bonuses, synergies, and class passives
that are otherwise hard to track by eye (e.g. anything longer than the
default ~30 second ability cooldown).

## What the code does

- **PvPCooldownTracker.addon** - the addon manifest (title, API version, SavedVariables, load order, and
  dependency on `LibAddonMenu-2.0`).
- **src/Main.lua** - startup/bootstrap logic: creates and upgrades the `SavedVariables`
  containers (account-wide and per-character), sanitizes saved data against
  defaults, and kicks off initialization.
- **src/Data.lua** - the catalog of tracked sets/synergies/passives (proc type, ability IDs,
  combat-event result codes, icon texture, cooldown duration, etc.) plus
  extensive author notes on how to add new entries.
- **src/Tracking.lua** - registers for `EVENT_COMBAT_EVENT` / `EVENT_ABILITY_COOLDOWN_UPDATED`,
  detects when a tracked proc fires, starts/stops cooldown timers, and
  reacts to combat-state and death/alive events.
- **src/EquippedSets.lua** - scans the player's equipped gear, matches set names against the
  `Data.lua` catalog, and auto-registers/enables tracking for sets you're
  actually wearing.
- **src/Interface.lua** - builds and styles the on-screen icon/label/progress-bar controls for
  each tracked cooldown (size, color, font, glow, etc.).
- **src/Settings.lua** - builds the in-game settings menu (via LibAddonMenu) for configuring
  position, size, colors, sounds, and which sets/synergies are tracked.
- **src/Defaults.lua** - default SavedVariables values (styling, layout, sounds) generated per
  tracked set.
- **src/ProcCapture.lua** - records the procs that recently went off on you and powers the
  "Add a Proc" menu, so you can start tracking any of them yourself (see below).
- **src/Sounds.lua** - the list of ~100 built-in game sounds selectable for "on proc" / "off
  cooldown" alerts.
- **lib/LibEquipmentBonus/LibEquipmentBonus.lua** - a bundled helper library that inspects equipped gear slots to report
  which item-set bonuses are currently active, used by `EquippedSets.lua` in
  place of the original `LibSets` dependency.

Together these pieces let a player equip a tracked set/synergy, have the
addon automatically detect it, and show a repositionable, resizable,
color-customizable icon with a countdown bar and optional proc/ready sounds
whenever that cooldown is active.

## Adding your own procs

Saw something proc that the addon does not track? You do not need to look up
ability IDs:

1. Let the proc go off in combat. The addon keeps a short list of what
   recently fired on you (buffs/effects by default; switch **What To Record**
   to *Everything* for procs that only deal damage, heal, or restore resources).
2. Open **Settings > PvPCooldownTracker > Add a Proc** and pick it from
   **Recent Procs**. If it fired more than once, the cooldown is pre-filled
   from the shortest gap seen between two procs.
3. Set the cooldown, optionally rename it, and press **Track This Proc**.

Added procs are tracked all the time (they are not tied to equipped gear),
are saved account-wide, and show up under **Tracked Cooldowns** where you can
move, resize, and change their sounds like any built-in set. Remove them
again from **Add a Proc > Your Procs**. `/pvpcooldowntracker procs` prints
the recent list to chat.

## Appearance

Trackers are drawn as a card with the icon, name, countdown, and a progress
bar that turns to the "ready" color with a glow pulse when the proc is back
up. **Settings > Appearance** offers color themes (Ember, Frost, Venom,
Blood, Gold, Mono), per-color pickers, an icon-only layout, and toggles for
the background card, name, and the floating proc/ready announcements.
**Arrange In A Column** stacks all enabled trackers so they do not overlap,
and **Preview Cooldown** fakes a proc so you can check the look and sounds.

## Credits / Origin

PvPCooldownTracker is a **console port** of the original **Cooldowns**
addon (https://github.com/inimicus/Cooldowns) created by **g4rr3t**
(a.k.a. **inimicus**), reworked here by **@VixenHunny** to remove the
keyboard/mouse-only LibSets dependency (replaced with the bundled
`LibEquipmentBonus` helper) and other controller-unfriendly bits so it can
run on the console (PlayStation/Xbox) versions of Elder Scrolls Online,
along with simplified SavedVariables handling and restyled UI defaults.

All credit for the original concept, the tracked-set data, and the core
tracking/UI logic goes to **g4rr3t / inimicus** and the **Cooldowns**
contributors (including **Baertram** for multi-language assistance). See the
upstream project here: https://github.com/inimicus/Cooldowns

## License

This addon, like the original Cooldowns addon it is ported from, is
distributed under the **GNU General Public License (GPL)**. You are free to
use, study, modify, and redistribute this code under the same license,
provided that you retain attribution to the original authors.
