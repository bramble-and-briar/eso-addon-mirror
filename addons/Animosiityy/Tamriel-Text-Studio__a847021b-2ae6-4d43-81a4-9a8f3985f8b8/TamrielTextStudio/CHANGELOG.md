# Changelog

## Version 2.4.3
- Strengthened the Guild Note / Gamepad private-function error fix.
- Removed the delayed `panel:UpdateControls()` scheduler entirely. A delayed refresh can execute after leaving Tamriel Text Studio and re-enter LibHarvensAddonSettings' shared Gamepad/keybind controls while another screen is opening.
- All composer callbacks now update saved Lua data only. No add-on callback or timer calls `UpdateControls()` or manipulates settings controls.
- The settings library refreshes the panel through its ordinary navigation/reopen flow. This intentionally prioritizes Gamepad UI stability over automatic in-place preview refresh.

## Version 2.4.2
- Removed synchronous settings-panel refreshes from color and edit callbacks.
- Replaced the UTF-8 zero-width-space formatting in the Visible Raw Markup Box with ASCII-only formatting.
