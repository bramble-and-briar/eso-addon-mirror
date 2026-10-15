# Satuve Xbox UI 1.7.11

## Minimap controller sliders

- Removed the Minimap-only `controllerSafeSliders` conversion that changed numeric sliders into custom finite-value lists.
- Minimap size, transparency, pin scale, zone/subzone/dungeon/PvP zoom, mounted zoom ratio, and global zoom now use the same native ESO Gamepad slider control as the other Bandit settings.
- `SXUI_LAMBridge.SafeSliderSetup` remains the console-safe write path: D-Pad left/right changes the native slider, and its handler calls the original Bandit `setFunc` directly instead of ESO's protected `SetSetting` function.
- Slider minimum, maximum, and step values remain unchanged.

## Requirements

- LibGamepad AddOnVersion 107 (1.0.7) or newer.
- LibAddonMenu-2.0 AddOnVersion 41 (r41) or newer.

## Other behavior

- Frame Edit Mode remains on the restored Bandit `MoveFrames` pointer/A-drag path from 1.7.10.
- No localization, SavedVariables, Minimap rendering, or full-map behavior was changed.
