AI disclosure: Developed by @mettaleggroll with assistance from
ChatGPT (Codex), including AI-generated code and translations.
The counter artwork was created using AI image generation.

Corpse Tracker 0.4.3

Beta for ESO PC/Mac. Estimates selected Necromancer corpse resources
and time until the next expiry.

Install or update

1. Install and enable LibAddonMenu-2.0 (AddOnVersion 43 or newer) separately.
2. Extract CorpseTracker into Documents/Elder Scrolls Online/live/AddOns/.
   The correct path is AddOns/CorpseTracker/CorpseTracker.txt.
3. Replace the old addon folder with this one; keep your SavedVariables.
   Keep only one installed copy. Do not put addon files in SavedVariables.
4. Restart ESO or return to character selection and log in after installation
   or a manifest/dependency update.

Use

Open /crpst settings. New installations use Light.

- Large number: estimated resources from the selected sources.
- ~4.2 or ~4,2: estimated seconds until the next selected resource expires.
- White ?: the displayed remainder may already be empty.

Right-click for source settings. Size and position lock are
configurable. Source switches apply immediately to whole skills and their
morphs. Hidden sources stay tracked for consumption.
Language changes require
/reloadui. Updates keep settings and recordings.

Sources and limits

Seven source switches: BB, Flame Skull, Skeletal Mage, Spirit Mender,
Bone Armor, Malevolent Promise and Banner (Necromancer Class Flourish).
Spirit Guardian and Intensive Mender share one switch and a default 10-second
corpse lifetime after natural death. Armor/Promise are separate virtual resources.

Only recognized events are counted; a whole-skill switch does not add support
for unverified morphs. Base Spirit Mender, other Bone Armor morphs and early pet
recasts are not fully covered. Killed NPCs/allies and unlisted sources are not
tracked. See the website for supported consumers and other limits.

Counts/lifetimes are estimates. Light checks neither distance, line of sight,
Graveyard placement nor skill availability. A positive count does not guarantee
a usable target; zero covers selected sources only. Extended is experimental.

Report a counting problem

1. /crpst test starts a fresh recording, clearing old logs but keeping corpses.
2. Reproduce the issue; /crpst mark LABEL adds an optional observation.
3. /crpst test stops and preserves the log. /reloadui saves it; provide
   SavedVariables/CorpseTracker.lua with the version and symptoms.

Recording is optional and off after UI load. It stops at 15 minutes or 30000
extended events; regular logs keep up to 6000 rows. The next start clears the
session. Records can contain names/game IDs; review before sharing. No uploads.

Release changes: CHANGELOG.txt.

ZeniMax notice

This Add-on is not created by, affiliated with, or sponsored by,
ZeniMax Media Inc. or its affiliates.
The Elder Scrolls® and related logos are registered trademarks or trademarks
of ZeniMax Media Inc. in the United States and/or other countries.
All rights reserved.