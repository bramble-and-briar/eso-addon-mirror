# Satuve Xbox UI 1.7.6

- Fixed the Xbox A button in Frame Edit Mode. The editor's focused top-level control previously consumed the physical A press while direct A handling was disabled whenever the modal ESO keybind state existed. As a result, UI_SHORTCUT_PRIMARY never reached the editor callback.
- Physical A/B events are now passed to the active modal ESO keybind strip. The underlying ESO/Bandit options list remains deactivated, and its older keybind groups remain hidden behind the pushed keybind state.
- A now transitions select -> move and move -> select, so the same button grabs and places a frame. The primary keybind stays visible in every editor state.
- B now cancels the current move and restores that frame's position from when it was grabbed. In preview it returns to repositioning; from selection it exits and restores the unsaved layout.
- Added Skills / Action Bar (ZO_ActionBar1) to the controller frame registry.
- Added opt-in diagnostics with BUI.FrameEditor:SetDebug(true). Logging only occurs while the editor is active.
- Kept existing SavedVariables and the preview/save workflow unchanged.

Validation completed:

- All 41 Lua files parse successfully.
- Physical A/B to modal keybind dispatch is simulated before callbacks, matching the reported failure path.
- Minimap and Skills / Action Bar both pass A grab, stick movement, A place, preview save, close, reopen, and persistence checks.
- D-Pad and A do not affect the suspended underlying settings list.
- B move cancellation restores the grab-start position.
- Repeated open/close cycles leave no keybind state or movement update registered.
- Existing minimap, memory, delayed-callback, template-guard, combat-report, and quick-navigation regressions pass.
