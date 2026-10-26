ENGLISH CLIENT REQUIRED FOR AUTOMATIC TRACKING.
Other client languages can use the manual checklist only.
AI DISCLOSURE: Code generated and revised with ChatGPT/Codex. See CREDITS.txt.
DEPENDENCIES: None.

GOLDEN SKULL TRACKER 1.1.2

INSTALL
Extract GoldenSkullTracker into your active ESO live/AddOns folder and
replace the existing add-on files. Keep your SavedVariables. There must be
no extra nested folder: AddOns/GoldenSkullTracker/GoldenSkullTracker.txt.
Restart ESO or reload its UI.

USE
/skulls or /goldenskulls toggles the window; X closes it without stopping
tracking. Drag to move it. Click Y/N to correct a category manually; an
asterisk identifies a manual entry. /skulls debug prints details on request.

Records are shared across characters on the same account/server; NA and EU
are separate. Saved-data name, schema version, and profile remain unchanged
from 1.1.0, retaining today's records, position, and visibility.

The tracker watches category-specific English golden Dremora Plunder Skull
names in boss loot, loot notifications, and newly acquired backpack skulls.
The two English festival quest turn-ins are also detected. Other players'
loot and ordinary purple skulls do not count. A golden reward visible in
the loot window may be recorded before it is taken; remember to loot it.

LIMITS
N means not recorded; it is not proof of never killing a boss. Rewards from
before installation or while disabled cannot be reconstructed. Existing
unopened skulls, simple bag moves, and bank withdrawals are not intentionally
counted as new daily rewards. Use manual corrections if a detection is missed.
This release retains name-based detection; it does not claim an item-ID
catalogue or multilingual automatic tracking. The window remains in English.

Daily reset behavior remains NA 10:00 UTC (20:00 Brisbane) and EU 03:00 UTC.
The day is checked while hidden; UI writes are skipped unless the day changes
or the visible countdown advances to a new minute. ESO saves data on logout
or UI reload; a forced exit may lose unsaved progress.

VERIFICATION
Lua 5.1 mocked tests cover filters, private scope, quiet startup, language
handling, reward detection, old saved data, day reset, bag moves, and bank
withdrawals. Actual festival rewards, UI layout, and game event delivery
still require testing inside ESO. See CHANGELOG.txt and CREDITS.txt.
