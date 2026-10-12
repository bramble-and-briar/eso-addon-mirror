AI disclosure: Developed by @mettaleggroll with assistance from
ChatGPT (Codex), including AI-generated Lua code and translations.
The counter artwork was created using AI image generation.

Corpse Tracker 0.3.6

Public beta for ESO PC/Mac. Shows an estimated count of your Necromancer
corpses from selected tracked sources.

Install or update

1. Install and enable LibAddonMenu-2.0 (AddOnVersion 43 or newer) separately.
2. Extract CorpseTracker into Documents/Elder Scrolls Online/live/AddOns/.
   The correct path is AddOns/CorpseTracker/CorpseTracker.txt.
3. On update, replace the files in the existing folder. Keep only one copy
   of the addon; do not copy addon files into SavedVariables.
4. Enable Corpse Tracker. After installation or a manifest/dependency update,
   restart ESO, or log out to character selection and log in again.

Use

Open settings with /crpst settings or Esc > Settings > Addons > Corpse Tracker.
New installations use Light mode and Your BB + Skull sources.

- Large number: estimated corpses from the selected sources.
- ~4.2 or ~4,2: seconds until the nearest estimated corpse expiry.
- White ?: the displayed remainder may already be empty.

Drag the square to move it; right-click to switch sources.
Lock Position prevents dragging. The square hides in menus while counting
continues. Updates keep your settings; /crpst mode light selects Light mode.
Language follows the client or can be chosen manually in settings.
Run /reloadui after changing the language.

Sources and limitations

Your BB + Skull counts BB explosions and corpse-creating enhanced skulls.
All tracked also includes recognized skeletal summons and diagnostic rules.
Enemy deaths, allies and Banner creations are not counted.

Light mode does not check distance, obstacles, Yard placement or actual
skill availability. Counts and lifetimes are estimates; a positive count
does not guarantee a corpse can be used.

Report a counting problem

1. Run /crpst test to start a new recording. This clears previous diagnostics
   and keeps active corpses. Enabling debugging is optional.
2. Reproduce the problem, run /crpst capture off, then /reloadui to save.
3. Provide Documents/Elder Scrolls Online/live/SavedVariables/CorpseTracker.lua.
   A short video and Encounter.log can help if available.

Release changes: CHANGELOG.txt.

ZeniMax notice

This Add-on is not created by, affiliated with, or sponsored by,
ZeniMax Media Inc. or its affiliates.
The Elder Scrolls® and related logos are registered trademarks or trademarks
of ZeniMax Media Inc. in the United States and/or other countries.
All rights reserved.
