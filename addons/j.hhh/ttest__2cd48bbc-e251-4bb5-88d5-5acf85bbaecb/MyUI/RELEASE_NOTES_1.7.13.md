# Satuve Xbox UI 1.7.13

## D-Pad Frame Editor

- Fixed Frame Edit Mode opening correctly but providing no D-Pad frame selection.
- The active Bandit movable controls are now registered with the controller editor when `BUI.Menu.MoveFrames(true)` builds the screen.
- A gold selection border identifies the current frame. D-Pad chooses the nearest frame in the pressed direction.
- A enters movement mode, D-Pad nudges the selected frame in 8-pixel steps, and A saves the position through Bandit's existing `SaveAnchor` path.
- B cancels an unconfirmed movement. From selection mode, B exits Frame Edit Mode; View exits and keeps the current confirmed position.
- Player/target linked buff controls move with their parent frames.
- D-Pad is received through editor keybinds and the focused overlay fallback. The protected `DIRECTIONAL_INPUT:GetXY()`/`IsKeyDown` path is not used.

## Retained fixes

- The underlying ESO/Bandit options menu, tooltip, background, list focus, and all normal settings keybind groups remain suspended and hidden during editing.
- The native Gamepad Minimap sliders and direct Bandit setter path from 1.7.11 remain unchanged.

## Requirements

- LibGamepad AddOnVersion 107 (1.0.7) or newer.
- LibAddonMenu-2.0 AddOnVersion 41 (r41) or newer.