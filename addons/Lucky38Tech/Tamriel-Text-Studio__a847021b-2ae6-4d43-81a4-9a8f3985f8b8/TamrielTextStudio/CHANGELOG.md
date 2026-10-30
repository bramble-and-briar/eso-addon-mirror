# Changelog

## 2.3.4
- Added a console-native text-entry path using ESO's chat text-entry API to prefill generated output, with a registered edit-box dialog as fallback. It never submits/sends the text automatically.
- Updated guidance to cancel/back out of chat after using the PS5 keyboard's selection/copy controls. Console chat text-entry can be scene-dependent; if it is unavailable from the Add-ons menu, open normal HUD chat first and retry.
- Added more image-size presets and custom 8–256 px sizing. Default remains 32 px.

## 2.3.3
- Replaced the invalid assumed `EDIT_TEXT` dialog call with a registered ESO dialog that contains an edit box.
- Added additional inline image size presets and custom sizing.

## 2.3.2
- Attempted a native text-entry handoff for output selection; this was not sufficient on PS5.


## 2.3.5
- Reworked output transfer to use a registered ESO dialog with the generated markup assigned directly to its edit box before opening; removed the unreliable chat-entry handoff.
- Made color-picker callback handling compatible with control-first and table-based callback signatures. Invalid callback arguments no longer silently convert the selected color to white.
- Persist and refresh the selected color immediately.
- PS5 text selection/copy behavior still requires in-game verification; ESO add-ons do not have direct clipboard access.


## Version 2.3.6
- Replaced the nonfunctional custom dialog handoff. Output now queues a native ESO console chat text-entry request until the HUD scene returns, using the documented console-safe `IsChatSystemAvailableForCurrentPlatform` + `ZO_GetChatSystem():StartTextEntry(...)` route. This avoids attempting to open the PS5 keyboard from the full-screen Add-ons menu, where ESO's chat API can silently do nothing.
- Color picker now uses LibHarvensAddonSettings' documented `setFunction(r, g, b, a)` signature, handles normalized and 0..255 channels, persists the selected target color, and does not refresh/rebuild the settings panel while the picker callback is active. Invalid callback data is ignored instead of becoming white.
- Static validation only; the PS5 keyboard and picker still require live console testing.
