# Diablo Frames Console 0.1.3

Unofficial gamepad adaptation using the original Diablo Frames artwork.
This remains an in-game test prototype. Offline tests do not establish Xbox
compatibility, rendering, or the absence of UI-security errors.

## Changes In 0.1.3

- Settings now register in the shared main-menu Add-Ons section, alongside
  other addon settings, instead of a separate top-level Settings category.
- Requires LibHarvensAddonSettings version 2.0.8 or later. Its console store
  listing may be named LibVotans; the internal addon name remains
  LibHarvensAddonSettings. Install the matching required library.
- Player buff bar and synergy prompt each have a movement toggle, horizontal
  and vertical offset sliders, and a position-reset button.
- Their default positions are above the Diablo HUD. Movement is constrained
  to the screen. Disabling movement restores the original native position.
- Native icons, timers, prompt bindings, and visibility remain controlled by ESO.
- Disabling the HUD or entering mount, werewolf, or keyboard mode restores
  the native anchors and scales. Native resize/style updates are respected.
- Removes the addon's custom gamepad settings dialog.
- Removes personal names from author and settings metadata while retaining
  original creator credits.
- Includes the single .addon manifest correction prepared in 0.1.2.

These changes are not a proven fix for the native GetModListingInstallState
insecure-code error reported while downloading the original release.

## HUD

- Original Forsion demon/angel, gothic frame, red health orb, and split
  magicka/stamina orb textures.
- ESO's native active skill buttons, controller bindings, durations,
  cooldowns, ultimate, quickslot, and companion ultimate controls.
- Full-color active skills and a display-only inactive-bar preview.
- Three size presets: Compact, Standard, and Large.
- Event-driven resources and layout updates, with no per-frame update loop,
  custom timer engine, global texture replacement, or key rebinding.
- Orange line displays active ultimate readiness, not XP or food duration.

## Client Acceptance Testing

1. Install Diablo Frames Console and the required settings library. Initially
   disable original DiabloFrames, DiabloOrbs, Fancy Action Bar, and other
   action-bar movers to avoid competing anchors.
2. Use gamepad preferred mode. Open main menu > Add-Ons > Diablo Frames Console.
3. Check toggles, size presets, inactive-bar preview, offset sliders, position
   resets, and Restore All Defaults. Confirm buff timers and synergy bindings.
4. Check active skills, ultimate, quickslot, companion ultimate, bar swaps,
   special bars, death, resurrection, mounts, werewolf, and scene transitions.
5. Check resizing and disabling. Native control positions should return.
6. Test in combat and record any complete Lua error, including source location.

Optional chat commands: /dfc, /dfc on, /dfc off, and /dfc reset.
Keyboard mode intentionally retains the native HUD. If native inactive-bar
duration icons overlap the preview, turn off this addon's inactive-bar row.

## Xbox Distribution

Xbox cannot directly install this ZIP. It uses ESO's Bethesda.net console addon
upload and distribution workflow. The package contains one .addon manifest,
which also supports PC testing. API version 101051 matches the pinned ESO UI
reference used for this adaptation.

Version 0.1.1 was previously published. This 0.1.3 package is a new local release
candidate; publishing must be verified separately. No ESO client was launched
to build or test it, and no live installed addons or system settings were changed.
Disable the addon through the addon manager if an error prevents its settings
from opening. It cannot repair native game crashes or Windows blue screens.

## Offline Validation

- Lua 5.1 syntax checks using luaparse and simulated execution using Fengari.
- 111 behavioral assertions covering lifecycle, shared settings, offsets,
  individual resets, bounds, missing controls, and native restoration.
- Settings registration tested with actual functions from the inspected
  LibHarvensAddonSettings source.
- Single-manifest, resource-path, DDS header, and mipmap-length checks.
- Automated checks reject personal names in release metadata.

The test harness does not reproduce ESO's engine trust/security system or
live Xbox rendering. Existing artwork previews are mockups, not client tests.

## Credits And License

Original Diablo Frames: BulDeZir (code), Forsion (art/textures).
Console adaptation: Console Adaptation Contributors.
Original source: https://www.esoui.com/downloads/info3051-DiabloFrames.html
Repository: https://gitlab.com/teso-addons/diablo-frames
Original source commit: b7e89ac42d232896f7ee4b0c5f063bf34e6db2ea

Selected original textures are unchanged. GPL-3.0-or-later; the included LICENSE
applies. Preserve original credits and license in further distributions.

ESO UI reference: https://github.com/esoui/esoui
Reference commit: 6639eb2adecc0480557d9068579319919a0c3fe6 (API 101051).
Settings library: https://www.esoui.com/downloads/info584-HarvensAddonSettings.html
Library source: https://github.com/Baertram/ESO-LibHarvensAddonSettings
ZOS manifest guidance: https://cdn.esoui.com/forums/showthread.php?p=51005#post51005

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc.
or its affiliates. The Elder Scrolls and related logos are registered trademarks
or trademarks of ZeniMax Media Inc. in the United States and/or other countries.
All rights reserved.
