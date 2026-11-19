TTC Motif Prices 0.4.2 - PC publication edition
Author: TjeEmpejoj

AI disclosure: This add-on was developed with code-generation assistance from ChatGPT/Codex. Automated syntax and mocked-API regression checks have been performed. These checks do not establish in-game compatibility, performance or correctness of every acquisition source.

REQUIRED: Tamriel Trade Centre and LibCharacterKnowledge >= 3.1.3 (AddOnVersion 301020).
Install these and their own dependencies separately through ESOUI/Minion.
TTC: https://www.esoui.com/downloads/info1245
LibCharacterKnowledge: https://www.esoui.com/downloads/info3317
TTC's own price-data setup is necessary for prices. This archive contains no TTC client,
price tables or updater. No association with or endorsement by TTC is claimed.

WHAT IT DOES
Adds TTC average prices and acquisition-only Source text to keyboard/mouse Outfit Style
collection tooltips. Includes motif chapters, complete books and tradeable style pages.
Binding rules control price/purchase suggestions; Source does not require a market price.
It appends its own lines and does not replace ESO's original tooltip description.

INSTALLATION
Exit ESO. Back up and replace the TTC_Motif_Prices folder in
Documents/Elder Scrolls Online/live/AddOns with the folder from this archive.
Keep SavedVariables. Do not enable two copies of the same addon.
Enable the addon and required dependencies, then log in and hover an Outfit Style.

COMMANDS
/ttcmp audit - export public collectible/source diagnostics; /reloadui saves them.
/ttcmp diag, /ttcmp hover, /ttcmp styles, /ttcmp style <ID> - diagnostics.
/ttcmp buy [book] - open a TTC web search for the hovered style or full book,
through ESO's external-link confirmation. It does not buy items in game.

COVERAGE AND LIMITATIONS
Based on an actual ESO API 101051 English catalog snapshot of 8,253 collectible IDs.
6,118 entries use native acquisition wording; 1,987 are supplemented/corrected using
research; 141 have explicitly unconfirmed sources; seven are Hide controls.
Counts describe individual collectible variants, not unique motif families.
Text coverage is not independent verification of all drop sources or current availability.
Events, Crown Store packs and crates may rotate. Historical/hidden variants may be listed.
Source text is acquisition-only. English native texts currently remain English on Russian
clients; researched additions have English/Russian text. Other languages fall back to English.
Keyboard/mouse PC support; gamepad and console compatibility are not claimed.
SOURCE_REFERENCES.txt is an offline provenance index, not a runtime-loaded database.
No private account, ownership, character or price history export is bundled.

VALIDATION
See the separate publication validation report for executed checks and remaining live tests.
Mocked-API checks do not establish in-game rendering or correctness of every source.

CREDITS AND RIGHTS
See THIRD_PARTY_NOTICES.txt. Original code is maintained by TjeEmpejoj, with
ChatGPT/Codex assistance. No new open-source license is imposed by this packaging change.
Third-party authors retain their rights.

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
