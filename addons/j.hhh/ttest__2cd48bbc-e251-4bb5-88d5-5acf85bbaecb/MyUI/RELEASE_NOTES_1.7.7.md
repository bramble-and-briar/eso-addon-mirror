# Satuve Xbox UI 1.7.7

- Fixed D-Pad frame selection in Frame Edit Mode. The editor previously relied on raw `OnKeyDown` events even though ESO routes gamepad navigation through its directional-input manager. On Xbox, the highlight could therefore remain on the first frame.
- Frame Edit Mode now activates an ESO-native `DIRECTIONAL_INPUT` owner on its visible overlay and uses `ZO_MovementController` for normal press, hold and repeat behavior.
- D-Pad and both sticks are consumed by the modal editor while it is open. The underlying ESO/Bandit options list remains deactivated and cannot navigate or activate entries behind the editor.
- Directional ownership is removed before the underlying settings list and keybind state are restored. Repeated open/close cycles do not leave duplicate handlers.
- Kept keyboard arrow handling as a fallback without allowing a controller D-Pad press to select twice.
- Restored the Minimap's native gamepad slider rows. Size, transparency, pin scale and every zoom setting now use their configured step values and call the original setters immediately.
- Kept SavedVariables, frame-positioning calculations and localization unchanged.

Validation completed:

- All 41 Lua files parse successfully and every manifest Lua entry is present.
- Native D-Pad ownership, spatial selection, held-input behavior, group-frame selection, A grab/place, B cancel/back and settings-list isolation pass the controller simulation.
- Repeated open/close cycles balance directional activation/deactivation and keybind push/pop operations.
- Minimap size, transparency, pin scale, all contextual zoom values and mount zoom apply through real slider rows.
- Existing Xbox memory, quick-navigation, delayed-callback, combat-report, minimap recovery and compatibility regression checks pass.
