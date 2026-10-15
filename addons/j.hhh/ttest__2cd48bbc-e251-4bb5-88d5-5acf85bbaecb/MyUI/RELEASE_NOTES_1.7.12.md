# Satuve Xbox UI 1.7.12

## Frame Edit Mode modal display and input

- Fixed the ESO/Bandit Gamepad settings menu remaining visible over the movable-frame overlay.
- The cause was incomplete suspension: the options list and its primary/panel keybind groups were disabled, but the base options keybind group, the options control, the shared quadrant background, and the current tooltip stayed active or visible.
- Frame Edit Mode now removes all three settings keybind groups, deactivates the current list, hides the options control and its shared background, and resets the left settings tooltip.
- The options scene itself remains open so ESO's UI mode and controller pointer continue to work with Bandit's original hold-A drag controls.
- The overlay no longer consumes every key. It handles only Escape/View directly; B uses the editor-only exit keybind, while A and pointer movement pass to the movable frame controls.
- Exiting restores the original control/background visibility, base and panel keybinds, the exact list, and ESO's selection-dependent A action and tooltip.

## Minimap controller sliders

- Retains the 1.7.11 native ESO Gamepad slider rows and direct Bandit setFunc path for every Minimap numeric setting.

## Requirements

- LibGamepad AddOnVersion 107 (1.0.7) or newer.
- LibAddonMenu-2.0 AddOnVersion 41 (r41) or newer.

No localization, SavedVariables, frame-position calculations, Minimap rendering, or full-map behavior was changed.