# Satuve Xbox UI 1.9.12

- Restores the confirmed V1 Combat Log controller input architecture.
- Uses direct `OnKeyDown`, `TakeFocus()`, `LoseFocus()` and the native keybind strip.
- Retains the 2x2 controller-focus edge texture fix and direct Combat Log menu entry.
- Removes the experimental `SatuveCombatLog` action layer, its binding actions and input diagnostics.
- Intentionally does not attempt to fix the known post-close controller-stick issue in this restoration build.
