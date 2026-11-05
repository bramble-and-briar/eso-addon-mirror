RAMALADNI BUFF & DEBUFF TRACKER — v1.0.0 STABLE
Author: Northknightwest (Ramaladni) | 2026-11-04

ABOUT
Standalone buff, debuff, combat status effect and class mastery tracker
for The Elder Scrolls Online (PC).

FEATURES
- Search effects by partial Russian/English name or numeric Ability ID.
- Click a Buff/Debuff search result to add it instantly; no extra Add button.
- Related effect IDs are grouped into one tracked indicator; IDs are hidden
  from the regular user interface.
- Automatic ESO icons, movable HUD elements and effect timers.
- HUD indicators hide in major game menus and return in gameplay.
- Class Mastery: 35 passive mechanics covering all seven classes, with a
  separate Add Mastery button.
- Remove an indicator using X in the indicator list (or Remove All).
- Buttons for the Buff/Debuff Base, the MD community and Discord.
- 70 named predefined effect groups including eight combat status effects;
  this is NOT a complete catalog of all ESO abilities/effects.

INSTALLATION
1. Exit ESO.
2. Back up any previous addon folder and
   Documents/Elder Scrolls Online/live/SavedVariables/RamaladniTrackerSaved.lua
3. Extract the folder Ramaladni_buff_debuff_tracker into
   Documents/Elder Scrolls Online/live/AddOns/
4. Keep only one copy of the addon; start the game and enter /ramaladni.

USE
Buffs/Debuffs: type RU/EN name or ID, then click the matching result.
Class Mastery: choose class/passive/icon and click Add Mastery.
Drag icons with the left mouse button. Remove them via the X button.
Keybindings: Settings > Controls > Keybindings > Ramaladni.

COMMANDS
/ramaladni, /ramaladni debug, /ramaladni inspect,
/ramaladni inspect self, /ramaladni offbalance, /ramaladni test

COMPATIBILITY & NOTES
- Live API 101051; also declared for PTS API 101052. Future live U52
  compatibility requires confirmation in-game.
- No required third-party libraries.
- SavedVariables: RamaladniTrackerSaved; existing saves are preserved.
- Timers depend on ESO API events; every ability ID is not guaranteed to be
  an observable effect event.
- Based on the in-game-tested v1.0.4g RC5 build.
- The experimental full catalog / self-learning approach from v1.0.5 is
  not included.

CREDITS / AI DISCLOSURE
Copyright (c) 2026 Northknightwest (Ramaladni).
Development was partially AI-assisted (including some Lua code, research,
and test workflows). The author also contributed code edits and game testing.
Effect-ID reference data was sourced from ESO ID Dictionary (Update 52)
and organized into effect groups for Ramaladni.
The MD community logo was provided for use in this addon.
This addon is not affiliated with or endorsed by ZeniMax Online Studios.
