# Satuve Xbox UI 1.7.10

- Restores the original Bandit `BUI.Menu.MoveFrames` implementation from the supplied 1.1.64 build, which was the last version confirmed to move frames correctly.
- Both the existing Move button and Frame Edit Mode now use that same proven movable-control path.
- Replaces the exclusive editor keybind stack, action-layer change, focus takeover and stick polling with a narrow guard around the underlying ESO options screen.
- The guard deactivates the underlying options list and temporarily removes its primary and panel keybind groups. This prevents hidden menu navigation and activation while preserving Xbox pointer movement and A-click dragging.
- B has one edit-mode exit action. On exit, the previous options list and only the keybind groups that were removed are restored when the same options screen is still open.
- Keeps the 1.7.9 controller-safe Minimap finite value lists and does not change language settings or frame-coordinate saving.
