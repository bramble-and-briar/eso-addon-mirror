# Satuve Xbox UI 1.7.8

- Fixed the Xbox UI error reported while Frame Edit Mode was open: `ZO_DirectionalInput:GetXY()` can call ESO's private `IsKeyDown` function and is not safe from an add-on call stack.
- Removed all Frame Editor use of `DIRECTIONAL_INPUT`, `ZO_MovementController`, `GetXY` and `ConsumeAll`.
- Registered D-Pad Up, Down, Left and Right as ethereal entries in the Frame Editor's exclusive ESO keybind group. They select frames spatially in select mode and are consumed without moving the settings menu behind the editor.
- Kept A for move/place, B for cancel/back, both analog sticks for movement, the deactivated underlying settings list and clean focus restoration on exit.
- Kept the 1.7.7 Minimap slider correction unchanged.
- Kept SavedVariables, frame coordinates, localization and language settings unchanged.

Validation completed:

- All 41 Lua files parse successfully with a Lua 5.1 runtime.
- A regression guard makes `IsKeyDown` and `DIRECTIONAL_INPUT:GetXY` fail immediately; the full Frame Editor simulation completes without calling either API.
- D-Pad spatial selection includes Group Frames, A enters movement, the sticks move the selected frame, B cancels and restores its starting position, and the underlying list never changes.
- Repeated open/close cycles balance keybind group push/pop and settings-list deactivate/activate operations.