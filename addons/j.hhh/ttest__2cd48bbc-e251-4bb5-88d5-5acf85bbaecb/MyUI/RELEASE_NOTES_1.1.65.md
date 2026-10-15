# Satuve Xbox UI 1.1.65

- Added controller Frame Edit Mode to Bandit UI's existing settings. Select with the D-Pad, move with A, fine tune with the left stick, move faster with the right stick, place with B, and preview with Menu. Save with A from preview or cancel the session with View/Back.
- Frame Edit Mode now temporarily owns the gamepad keybind strip and suspends the underlying ESO options list. D-Pad and A input can no longer navigate or activate settings behind the editor; closing the editor restores the previous list and keybind state.
- Added a simultaneous layout preview with safe sample labels for player, target, boss, and group frames, making overlaps visible before saving.
- Reworked the Bandit minimap around ESO's native world-map mode and fragment. It no longer moves ESO's shared map scroll control into a custom viewport. Login, travel, map scenes, gamepad changes, and temporary missing map controls trigger centralized recovery.
- Kept Bandit's minimap settings and SavedVariables: enabled state, position, size, transparency, title, pin options, and zoom.
- Kept the existing mouse Move Frames option. No new runtime library or settings menu is needed.
- Reduced persistent Xbox work: player-resource fallback refreshes now reuse state, skip unchanged redraws, pause before player activation, and run at 10 Hz instead of 20 Hz.
- The main-menu LB/RB fallback poll now runs only while the native gamepad menu is visible, preventing background focus changes and reducing idle work.
- Limited unsaved in-session combat history to 12 completed reports while preserving explicitly saved reports.
- Namespaced delayed callbacks to avoid collisions with other add-ons that use the common `CallLater_*` update name.
- Documented that SatuveXboxUI replaces the original Bandits User Interface and must not be enabled alongside it.
- Scoped the ESO template guard to the native compass and player-progress controls only when Satuve owns their saved position; other add-ons can apply the same templates to their own controls.
- Added a nil guard for the gamepad action-bar keybind background on clients where that native control is unavailable.

Automated syntax and regression checks pass. Complete the real-hardware acceptance steps in `XBOX_TEST_CHECKLIST.md` before public distribution.
