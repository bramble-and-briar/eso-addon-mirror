# Diablo Frames Console — 0.1.1 prototype

A dependency-free gamepad adaptation using the original Diablo Frames artwork.
This is an untested-in-game prototype, not a published Xbox addon or a guarantee against UI errors.

## Implemented

- Original Forsion demon/angel, gothic frame, red health orb and split magicka/stamina orb textures.
- ESO's native active skill buttons, Xbox/gamepad bindings, cooldowns and ultimate controls.
- Active bar stays on top; both bars retain full color. Six display-only inactive-bar icons refresh on slot and bar changes; no custom timer engine.
- Native ESO controller prompts below the active skills, including the ultimate combination.
- Larger resource values using ZoFontGamepad34.
- Orange line represents active ultimate readiness (not XP or food duration).
- Settings > Diablo Frames Console: enabled state, three size presets, inactive row toggle, reset.
- Automatic return to native resource bars while mounted or in werewolf form.
- Native bar anchor/scale restoration when disabled; gamepad-only activation.
- Native companion ultimate retained beside the HUD.
- Current COMBAT_MECHANIC_FLAGS constants, not removed PC compatibility aliases.
- No external libraries, no global texture redirection, no custom key rebinding, no combat-event scan, no per-frame update loop.

## Test on PC first

1. Unzip and copy the DiabloFramesConsole folder into your ESO AddOns directory.
2. Enable Diablo Frames Console; disable original DiabloFrames, DiabloOrbs, Fancy Action Bar and other action-bar movers during initial testing.
3. Switch to gamepad preferred mode. Keyboard mode intentionally uses the native HUD.
4. Open gamepad Settings > Diablo Frames Console. `/dfc`, `/dfc on`, `/dfc off`, `/dfc reset` are optional chat shortcuts.
5. Verify active controls X/Y/B/LB/RB, ultimate, quickslot, native durations, swaps, special bars, companion ultimate, resource changes, death/resurrection, mounts, werewolf, scene transitions, resizing and disabling.
6. Repeat in a dense trial encounter. Record any Lua error including full source location.

If native back-bar duration icons visually overlap the preview, disable ESO's native back-bar timer display while testing the custom icon row, or turn off this port's inactive row. Native active timers are retained. Exact native control placement and timer animation require client testing.

## Xbox release

Xbox cannot directly install this ZIP. It must go through ESO's Bethesda.net console addon upload/distribution workflow. This package includes the console `.addon` manifest plus a matching `.txt` PC-test manifest. API version 101051 comes from the current upstream ESO UI documentation used for the port; confirm the target client's API version and uploader manifest validation before upload. No public upload has been performed.

PC gamepad testing does not prove Xbox performance. Validate on console before using during progression. Disable the addon through the addon manager if a failure prevents opening its settings. It cannot fix crashes caused by other addons or the game engine.

## Validation completed here

- Lua syntax check using texluac.
- 58 assertions in a mocked ESO API harness, including loading only for the correct addon, zero/over-max resource values, deduplicated deferred layouts, inactive-bar selection, mounts, transformations, native restoration and controller settings.
- Manifest/resource-path checks and DDS texture decode.
- Two visual previews rendered from the original artwork and example skill-icon crops from Damien's reference screenshot. They are design mockups, not ESO captures. Skill selection, values, timers and resource values and timers are illustrative. Controller glyphs use actual ESO texture assets mirrored by UESP.
- Visual spacing review for both Xbox and PlayStation previews; live native animations still require in-game testing.

## Credits and source

Original Diablo Frames: BulDeZir (code), Forsion (art/textures).
https://www.esoui.com/downloads/info3051-DiabloFrames.html
https://gitlab.com/teso-addons/diablo-frames
Original source commit: b7e89ac42d232896f7ee4b0c5f063bf34e6db2ea

Console adaptation replaces the old runtime with a gamepad-specific implementation while preserving the selected original texture files unchanged. GPL-3.0-or-later; included LICENSE applies. Preserve credits and license in further distributions.

ESO UI reference: https://github.com/esoui/esoui
Reference commit: 6639eb2adecc0480557d9068579319919a0c3fe6 (API 101051).
ZOS console guidance: https://www.esoui.com/forums/showpost.php?p=50999&postcount=2

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
