# Satuve Xbox UI 1.9.16

- Fixes the `ZO_DirectionalInput.lua:281` insecure-call error reported in 1.9.15.
- Removes every direct add-on call to `DIRECTIONAL_INPUT` and therefore no longer reaches protected `IsKeyDown` code through that path.
- Uses native keybind-strip callbacks for D-Pad Left, Up, Down and Right in the correct `mainMenuGamepad` scene.
- Refreshes the native callbacks whenever the existing sidebar visibility changes.
- Preserves A activation, B return, the existing sidebar mouse actions and normal-menu selection restoration.
- Adds no polling loop, focused control or action layer.
- Does not change Combat Log or Statistics code.
