Crown Crate Codex

Install: Extract the CrownCrateCodex folder into Documents/Elder Scrolls Online/live/AddOns.
Updates: Replace only the addon folder. Preserve live/SavedVariables to retain history and settings.
Open: /ccc. Recommended LibAddonMenu-2.0 r43 or newer provides Settings > AddOns > Crown Crate Codex.
Version 0.12.5 includes PC controller navigation and the mouse/camera fix when opening /ccc outside the Crown Crates scene. Use ESO Gamepad Mode Automatic or On. D-pad moves focus; normal UI bindings select/back/open Collections/options; shoulders switch tabs and triggers change pages. No opening shortcut is assigned automatically. Initial in-game controller testing by the author succeeded. Other controller setups remain unverified; XL footer hints may clip, while Large mode showed all hints.
Languages: Automatic (ESO), English, Simplified Chinese, French, German, Japanese, Russian, Spanish. Change in Settings > AddOns > Crown Crate Codex > Language, then /reloadui. ESO controls reward/crate names; the addon controls its own interface text. Translation changes preserve saved history. Translations are AI-drafted and welcome native-speaker review; localized font rendering still requires in-game verification.

Required ZeniMax disclosure
This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

Credits and reference data
Inspired by Crown Crate Tracker by Faunter:
https://www.esoui.com/downloads/info1741-CrownCrateTracker.html

HistoricalCatalog.lua and GemCatalog.lua contain adapted factual reference data from UESP contributors, licensed under Creative Commons Attribution-ShareAlike 2.5. Changes include conversion to Lua lookup tables and extraction of reward IDs, quantities, tiers, and gem values. Exact source revision links accompany the records. No UESP images are redistributed.
https://en.uesp.net/wiki/Online:Crown_Crates
https://en.uesp.net/wiki/UESPWiki:Copyright_and_Ownership
https://creativecommons.org/licenses/by-sa/2.5/

AI-assisted development: Code was generated with assistance from OpenAI Codex and tested through automated checks and in-game use.

See README.md for capabilities, limitations, data preservation, and sources.

Version 0.12.3: local-reference cleanup only. CrownCrateData is read from Crown Crate Tracker by Faunter, never defined or modified by Crown Crate Codex. Saved-data identity and settings behavior are unchanged.

Version 0.12.5 removes the unsupported optional >=43 version constraint. LibAddonMenu-2.0 remains optional; availability is checked before settings registration. r43 is recommended, not enforced by OptionalDependsOn. Crown Crate Tracker by Faunter is a separate optional addon, not a library. Existing saved history and settings are preserved.

Version 0.12.6 fixes Escape closing by removing the native UI-mode lock; cursor ownership remains managed by ESO. No saved-data changes.
