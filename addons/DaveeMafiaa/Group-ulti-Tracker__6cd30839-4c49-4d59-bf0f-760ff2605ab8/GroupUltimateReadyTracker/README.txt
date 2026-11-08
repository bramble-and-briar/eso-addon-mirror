GROUP ULTIMATE TRACKER v2.2.1
For ESO PlayStation 5 / console UI
Author: Daveemafiaa

IMPORTANT FIXES IN THIS BUILD
1. Settings now register through LibHarvensAddonSettings, the console library
   used by ESO's Settings > Add-ons page. The previous v2.0.0 code attempted
   to register a custom GAMEPAD_OPTIONS category and did not create the actual
   Add-ons settings entry.
2. Corrosive classification now normalizes Corrosive Armor and Magma Shell
   through the ability progression API to the original Magma Armor base skill.
   The icon can also refresh from ESO's own base-ability texture data.

SETTINGS DEPENDENCY
The manifest now declares:
    ## ConsoleDependsOn: LibHarvensAddonSettings>=20107

This is a console-specific dependency. It is not LibVotans and it is not
LibGamepadOptions. The console add-on browser/uploader should resolve the
declared dependency. If the dependency is not installed/enabled, the settings
panel cannot be created; the addon prints a diagnostic message.

Where to find the settings:
    Settings -> Add-ons -> Group Ultimate Tracker

Controls:
- HUD Scale: 0.70–2.00
- Horizontal Position (X): -960 to +960
- Vertical Position (Y): -540 to +540
- Reset HUD Position and Scale

FIXED ICON ROW
1. Sorc — unmorphed Negate Magic
2. GIB — unmorphed Gibbering Shield
3. Corrosive — unmorphed Magma Armor
4. Barrier — unmorphed Barrier
5. Dawnbreaker — catch-all for every ultimate outside the first four,
   including actual Dawnbreaker and its morphs.

CORROSIVE FIX
- Uses the Magma Armor base icon texture:
  EsoUI/Art/Icons/ability_dragonknight_018_u49_new.dds
- Morphs are normalized using:
  GetAbilityProgressionXPInfoFromAbilityId(abilityId)
  GetAbilityProgressionAbilityInfo(progressionIndex, 0, 1)
- When a Corrosive Armor or Magma Shell is observed in group data, the icon
  refreshes using the actual unmorphed base ability texture returned by ESO.

DISPLAY
- Individual PSN-labelled bars under each category icon.
- Orange while charging; green when ready.
- Grey when no usable update has been received.
- Both front and back ultimate slots are checked.
- One player appears once per category; if both slots match, the more-ready
  cost ratio is displayed.
- Dawnbreaker column catches all ultimate families not listed above.

PSN NAME FIX
- The displayed name comes from LibGroupCombatStats stats.displayName.
- The character-name field stats.name is only used to match records and is
  never displayed.
- If an account display name cannot be resolved, the addon displays
  "PSN unavailable" instead of substituting a character name.

DEPENDENCIES
- LibGroupCombatStats
- Console: LibHarvensAddonSettings >= 20107
- LibGroupCombatStats itself requires its compatible console broadcast/combat
  libraries. Group members need compatible ULT sharing enabled.
- No LibVotans or LibGamepadOptions dependency.

SLASH COMMANDS
/gurt settings
/gurt scale 1.20
/gurt x -100
/gurt y 180
/gurt move -100 180
/gurt left 20
/gurt right 20
/gurt up 20
/gurt down 20
/gurt reset
/gurt hide
/gurt show
/gurt debug

INSTALLATION
This ZIP is a development source package, not a direct PS5 sideload. Submit
the updated addon through the official ESO Console Add-on Developer Uploader,
including the ConsoleDependsOn declaration. Install/update it through the
in-game Add-ons browser and ensure the LibHarvensAddonSettings dependency is
installed and enabled.

Official uploader:
https://help.elderscrollsonline.com/app/answers/detail/a_id/69621/~/eso-console-add-ons---developer-uploader-tool

TEST STATUS
The package structure and manifest have been checked, and the settings code
now follows the documented LibHarvensAddonSettings API. The Magma Armor
base icon asset has been cross-checked against ESO skill references. However,
this build has not been run inside ESO or tested on a live PS5 group. Live
testing is still required.

ADD-ON TERMS DISCLOSURE
This Add-on is not created by, affiliated with or sponsored by ZeniMax Media
Inc. or its affiliates. The Elder Scrolls® and related logos are registered
trademarks or trademarks of ZeniMax Media Inc. in the United States and/or
other countries. All rights reserved.

V2.2.0 GROUP MEMBERS FIX — IMPORTANT
------------------------------------
Root cause in v2.1.0:
    if stats.isPlayer ~= false then ...
This rejected every remote teammate.

The upstream LibGroupCombatStats source sets:
    isPlayer = AreUnitsEqual(groupTag, "player")
so only YOUR character has isPlayer=true; all remote teammates have false.

Fixes:
- Remote group records are no longer discarded in BuildOrderedMembers().
- /gurt debug now walks the native group roster, printing all group members
  whether or not their ultimate packets have arrived.
- If a teammate has no slotted-ultimate data yet, a GREY PSN-labelled bar
  appears below the fifth/catch-all icon. This is an "unknown/pending" display,
  NOT a claim that they are actually using Dawnbreaker.
- Once a teammate's slotted ultimate IDs are received, the bar moves to
  the correct ultimate family with an individual readiness fill.

NEXT TEST
- All teammates should have a compatible Group Ultimate Tracker installed,
  enabled, and its libraries enabled.
- Update all clients to v2.2.0 and group together.
- Type /gurt debug on the group leader or another player.
- The output should now show EACH group member, including those whose
  ULT data has not arrived.
- Look at front= and back=:
      >0: ultimate type received, can classify and track.
       0: no ultimate slot information received yet.
- If front/back remain 0, check every player's LibGroupCombatStats version;
  the July 26 2026 release made a breaking ultimate-ID encoding change.
  All players should be on mutually compatible newer library releases.

No ESO/PS5 live test was possible in the build environment.


V2.2.1 FOUNDATION TWEAKS
- Keeps the original v2.2.0 icon spacing and overall layout.
- Adds visible box borders around all five icons.
- Makes the player-name bars taller and increases the name text size.
- Improves the Corrosive icon by resolving the actual base-skill icon from ESO ability data and storing it for future sessions.


V2.2.2 CORROSIVE ICON FIX
- This is a targeted icon-only update based on v2.2.1_foundation.
- All HUD positioning, sizing, name fonts, group ultimate tracking and addon settings remain untouched.
- Attempts to resolve the unmorphed Magma Armor texture via the game skill catalogue.
- Adds visible MAGMA fallback text if game art is not available; it does not pretend this is the actual image.
- Not live-tested on PS5.


V2.2.3 — ULTIMATE PRIORITY SORTING
- PSN names below each ability icon are displayed by current ultimate points
  (highest to lowest); re-sorts automatically as group data changes.
- Unknown/pending group records sort below players with valid ultimate data.
- All visuals, icon spacing, Corrosive code and settings remain unchanged.
