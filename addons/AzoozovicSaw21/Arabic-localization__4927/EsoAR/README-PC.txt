ESO Arabic 2.2.7 - PC

Fixes the Arabic controller Crown Store balance row and retains the corrected
Minion ZIP layout. See CHANGELOG.txt for details and validation limits.

INSTALL / UPDATE
1. Close ESO completely and back up the existing Arabic addon files.
2. Extract this ZIP directly into the active Elder Scrolls Online/live/AddOns
   folder. The three top-level folders are EsoAR, EsoUI and gamedata.
   Merge folders and replace this addon's matching files.
3. If an old AddOns/ESO_Arabic folder remains from 2.2.5, move that folder to
   a backup location OUTSIDE AddOns to avoid duplicate/nested copies.
4. Enable EsoAR. Use /ar to select Arabic, then fully restart ESO.

Expected paths:
AddOns/EsoAR/EsoAR.addon
AddOns/EsoUI/lang/ar_client.str
AddOns/EsoUI/lang/ar_pregame.str
AddOns/gamedata/lang/ar.lang

Keep SavedVariables and other addons. Before uninstalling, use /en while the
addon is still installed and then exit ESO completely. Do not delete entire
shared EsoUI or gamedata directories.

If character loading fails after removing Arabic files while Arabic was
selected, close ESO and back up UserSettings.txt in the live folder. Set the
existing Language.2, LastPlatformLanguage and LastValidLanguage entries to en,
restore the files at the paths above, and retry. Retain new .dmp/.extra files
from live/Errors if a crash persists.

The corrected folder layout passed an English character-load test on 2.2.5
runtime files. The 2.2.7 hook fix passed automated regression tests; its native
game appearance still requires confirmation. Console gameplay is untested.
