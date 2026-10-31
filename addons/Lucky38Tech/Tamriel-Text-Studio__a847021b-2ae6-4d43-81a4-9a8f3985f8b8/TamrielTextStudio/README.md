# Tamriel Text Studio 2.4.3

ESO console-oriented message composer by CRY.

## Version 2.4.3 — Gamepad UI stability
- Strengthens the fix for UI Error `9FA38F6A` involving the private `GetNumberConsoleFriends` call in ESO's Guild Roster Gamepad UI.
- Removes all add-on-driven `UpdateControls()` calls, including delayed calls. A delayed refresh can run after leaving the settings page and touch LibHarvensAddonSettings' shared Gamepad/keybind controls while another screen is opening.
- Setting callbacks now only update saved Lua data and generated markup. They do not refresh, rebuild, or manipulate settings controls.
- To see all updated preview/label text, back out of Tamriel Text Studio and reopen it. This deliberate limitation avoids re-entering shared ESO Gamepad UI code from a background timer.
- Generated markup and SavedVariables are still updated immediately; this does not change guild information automatically.

## Features
- Controller-friendly destination selector for Guild MOTD, Guild About Us, Guild Member Note, and custom fields.
- Heading and message composer with color presets and custom HEX colors.
- ESO texture catalog search, categories, favorites, custom texture paths, and inline image sizing/placement.
- Generated markup output and an ASCII-visible raw markup reference.

## Install
Extract the `TamrielTextStudio/` folder into your ESO `AddOns` directory, replacing the previous version, then run `/reloadui` or restart the game.

## Notes
This package depends on LibHarvensAddonSettings (or the console-compatible LibVotans equivalent). Keep only the supported library package enabled, not both copies. The add-on does not edit guild fields automatically: copy the generated markup and paste it into the desired Guild UI field yourself.
