Weyland Vampire Stage Tracker 1.2.0

Features
- Adds an in-game settings panel under Settings -> Addons (requires LibAddonMenu-2.0).
- The settings panel has a live preview: a replica of the HUD plate drawn by the same code, updated while you move the sliders. "Preview stage" switches between Stage I-IV.
- The HUD is only visible in the game view; it hides in menus, inventory, map and settings.
- Adjustable overall HUD scale and independent stage icon size.
- Adjustable background/frame opacity, optional background, decorative frame and stage icon, plus timer font size.
- Toggle the timer and stage icon; blood drops and the progress bar are controlled together as one group.
- The HUD always keeps at least one stage indicator visible; stages II-IV also keep at least one time indicator visible. Stage I has no timer.
- Choose compact or clock timer format and set the low-time warning threshold.
- Move and lock the widget; the default/reset position is the center of the screen.
- An existing saved position is preserved when upgrading; use Reset position (or LAM Defaults) once to move it to the new centered default.
- Shows the live Vampire Stage as Roman numerals I-IV.
- Detects the stage from the Vampire Stage ability IDs first.
- Continuously rescans player buffs so stage changes stay synchronized.
- Refreshes immediately on player activation/reload and effect updates.
- Shows the live remaining stage time reported by the Vampire Stage buff API, including after relog.
- Calculates the progress bar from the same live buff timeStarted/timeEnding timestamps and game clock as the timer.
- Stage icons are drawn without their empty transparent margins; the plate grows with the icon size (32-120).
- Hidden automatically when no vampire stage is detected.
- UI is draggable and position is saved account-wide on move-stop, player deactivation and lock.
- The saved position is restored on player activation after a zone transition.

Languages
- English, German, French, Spanish and Russian (settings panel, chat messages, hints).
- The text follows the language of your ESO client. Any other client language uses English.
- The timer always uses digits and Latin units (3h 25m / 03:25:00), so it looks the same in every language.
- Translations are community-style, not professional. Corrections are welcome.

Dependencies
- LibAddonMenu-2.0 (optional) - only needed for the in-game settings panel. Without it the tracker works and is controlled with /vst commands.
- No other libraries are required.

Settings
- Open Settings -> Addons -> Weyland Vampire Stage Tracker.
- Or type /vst settings (also /vstsettings) in chat.
- LibAddonMenu-2.0 is optional for the tracker itself, but required for the in-game settings panel.

Commands
/vst settings - open the settings panel
/vst unlock  - move mode: shows a sample plate and the mouse cursor; drag it with the LEFT mouse button
/vst lock    - lock the UI
/vst reset   - reset the saved position to the center of the screen
/vst colors  - switch palette, or choose it: /vst colors blood | /vst colors classic
/vst debug   - print stage, ability ID, timer, raw timestamps, icon path and buff name
/vst         - toggle unlock/lock
/vampirestage - same as /vst

Install
1. Remove the old VampireStageTracker folder, then copy the folder WeylandVampireStageTracker into Documents\\Elder Scrolls Online\\live\\AddOns\\
2. Enable the addon in ESO.
3. Type /vst unlock, drag the plate with the left mouse button, then type /vst lock. The HUD starts centered until you move it.


Support
- The addon is free and every feature is available to everyone.
- If you like it, you can optionally send a gift in gold or from the in-game Crown Store to @The'Inquisitor (EU megaserver). The same note is in the settings panel.

Credits and licenses
- Timer font: Cinzel Bold, Copyright 2020 The Cinzel Project Authors (https://github.com/NDISCOVER/Cinzel),
  SIL Open Font License 1.1, converted to the ESO font format. License text: fonts/OFL.txt
- Stage icons, blood drop and plate textures: created for this addon with AI image tools.
- Full version history: CHANGELOG.txt
