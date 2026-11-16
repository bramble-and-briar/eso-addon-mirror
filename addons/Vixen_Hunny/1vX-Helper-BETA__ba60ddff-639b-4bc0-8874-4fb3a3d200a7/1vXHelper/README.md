# 1vX Helper (ESO add-on)

By **Vixen Hunny**.

Burst monitor + 1vX map tools for Elder Scrolls Online. Every feature can be toggled in
**Settings > Addons > 1vX Helper** (LibAddonMenu-2.0).

## Install
1. Install **LibAddonMenu-2.0** (Minion / ESOUI).
2. Copy this `1vXHelper` folder (manifest: `1vXHelper.addon`) to `Documents\Elder Scrolls Online\live\AddOns\`.
3. `/reloadui` in game. If it shows as "out of date", update `## APIVersion` in `1vXHelper.addon`
   to the current value (`/script d(GetAPIVersion())`) or tick "Allow out of date add-ons".

## Burst Monitor
- Sums incoming damage in a sliding **1s window** (adjustable).
- When it reaches your threshold (flat damage, or % of max health), a flashing red **KITE NOW!**
  shows for **2s**, then there's a **2s grace period** where it can't retrigger (amber countdown).
- Options: count DoTs / blocked / shield-absorbed damage, PvP-zones only, extend on repeat burst,
  custom text, text size, sound, live burst meter (SAFE / KITE / GRACE).

## Map Pins (kite spots, safe places, choke points)
- Drop a pin at your position from a **keybind**, the **gamepad screen**, or `/1vx kite|safe|choke <note>`.
- Pins show on the world map (green = kite, blue = safe, orange = choke) with your note as a tooltip.
- Remove the nearest pin (within 60m), list pins on the current map, clear the map or clear everything.

## Gamepad
- Main menu > **1vX Map Pins** (directly above Inventory) opens a gamepad screen with
  **Map Choke Here**, **Map Safe Here**, **Kite Here** and **Remove Nearest Pin**. The header shows the
  current map and how many 1vX pins it has; each action pops an on-screen alert.
- Pins and their tooltips show on the gamepad world map.
- Can be hidden in settings (Gamepad > menu entry). Also opens via `/1vx pad` or the keybind.

## Spot Tracker
- Distance and clock direction (relative to your camera) to the nearest pin of each type.
- Orange **CHOKE POINT** warning when you're within range of a choke point.

## Extras
- Low health warning (threshold %), combat timer.

## Performance
- Damage events are filtered by the game engine (only damage you take reaches the add-on),
  hits go in a garbage-free ring buffer, and timers only run fast while something is happening.
- The tracker caches your zone's pins, skips updates while you stand still, and pauses while it's hidden.
- **Settings > Performance (CPU)**: burst timer rate, tracker rate, skip-while-still and a Low CPU preset.

## UI
- The only on-screen element is the **burst alert / meter** and the **spot tracker** (plus the optional extras, off by default).
- **Unlock UI** (settings or `/1vx unlock`) shows every element with a red frame so you
  can drag it. **Reset Positions** puts everything back.
- The UI re-applies itself after every loading screen and also shows while on siege weapons.
  If anything ever goes missing, `/1vx refresh` brings it back without a reload.

## Commands
`/1vx kite|safe|choke <note>` · `/1vx remove` · `/1vx list` ·
`/1vx test` · `/1vx pad` · `/1vx refresh` · `/1vx unlock` / `lock` · `/1vx settings` · `/1vxsettings`

Keybinds: Controls > Keybindings > **1vX Helper**.
