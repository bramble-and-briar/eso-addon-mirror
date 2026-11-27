AI DISCLOSURE
Development of Ramaladni was partially AI-assisted, including portions of Lua code, API research, refactoring and automated testing. The author also contributed code changes and performed in-game testing. Automated tests use a simulated ESO API and do not replace full in-game validation.

RAMALADNI — CLASS MASTERY & BUFF/DEBUFF TRACKER
More than a Buff & Debuff Tracker — Master Your Class.
Version: 1.0.1-Stable
Author: Northknightwest (Ramaladni)
Dependencies: None
Platform: ESO PC

CLASS MASTERY — 7 CLASSES, 35 PASSIVES
Ramaladni automatically detects purchased Class Mastery passives available to your current build. There is no manual mastery selection. When you change your build, the HUD updates to show the applicable masteries. New mastery icons appear near the center of the screen; moved positions are remembered per passive.

Supported classes: Dragonknight, Sorcerer, Nightblade, Templar, Warden, Necromancer and Arcanist (five mastery passives per class).
Dedicated trackers show relevant timers, stacks, calculated values and proc indicators where ESO exposes the necessary data. Some mechanics are inferred from combat events rather than directly exposed by the API.

BUFF, DEBUFF & STATUS EFFECT TRACKING
- Separate BUFF and DEBUFF search catalogs: 41 buffs and 33 debuffs/status/special effects (74 named entries in total).
- Search by Russian or English name, partial text or supported Ability ID; click a result to add it.
- Related effect IDs are grouped into a single indicator.
- Automatic game icons, individual timers and movable HUD indicators.
- Up to 12 regular effect indicators, independent of automatic mastery indicators.
- Indicators hide in major game menus and return during gameplay.
- Previously saved regular indicators and their positions are retained by the migration logic.
- World-specific settings for EU, NA and PTS.

INSTALLATION & USE
Exit ESO and extract Ramaladni_buff_debuff_tracker into Documents/Elder Scrolls Online/live/AddOns/. Keep only one copy of the addon. For an update, back up your addon folder and SavedVariables/RamaladniTrackerSaved.lua before replacing the files.
Open settings with /ramaladni or assign a keybinding under Settings > Controls > Keybindings > Ramaladni. Add buffs/debuffs from search results, move icons with the left mouse button and remove regular indicators with X. Mastery indicators follow your build.
Legacy shared settings are imported once only when no world already owns settings; existing world-specific settings take priority.

COMPATIBILITY & VALIDATION
Manifest API versions: 101051 and 101052. No external libraries required.
The addon uses native event filters where applicable and preserves a compatibility path for name-dependent effects. The 200 ms HUD update cadence is retained. Automated regression and stress tests were performed in a simulated Lua environment. The final g4 event-optimization changes still require full in-game regression and engine performance validation; PTS compatibility has not been fully tested in the client. Not every combat situation or ability ID is directly observable through the ESO API.

CREDITS
Developed by Northknightwest (Ramaladni).
- ESO ID Dictionary (Update 52): effect-ID reference data, organized into Ramaladni effect groups from the project’s supplied dataset.
- ESO Logs (https://www.esologs.com/): ability catalogs and combat-event reference data used for Class Mastery research.
- ESO-Hub (https://eso-hub.com/): named-effect and Class Mastery mechanics references.
- MD Community (https://md-eso.ru/): buff/debuff classification reference and community logo. Effect reference: https://md-eso.ru/topic/8229-active-buffs-and-debuffs/
- Untaunted by Solinur (https://www.esoui.com/downloads/info1475-Untaunted.html).
- ZeniMax Online Studios and the ESOUI community: ESO UI/API documentation and reference implementation (https://github.com/esoui/esoui).
- Special thanks to Baertram for technical review and guidance on addon development best practices.
The referenced addons are not runtime dependencies. The Elder Scrolls Online, game icons and associated marks belong to their respective owners. Ramaladni is not affiliated with or endorsed by ZeniMax Online Studios.

COMMUNITY & SUPPORT
Buff/Debuff Base: https://md-eso.ru/topic/8229-active-buffs-and-debuffs/
MD Community: https://md-eso.ru/
Discord: https://discord.gg/azr8QDYhyJ

COMMANDS
/ramaladni, /ramaladni debug, /ramaladni inspect, /ramaladni inspect self, /ramaladni offbalance, /ramaladni test

Copyright (c) 2026 Northknightwest (Ramaladni).
