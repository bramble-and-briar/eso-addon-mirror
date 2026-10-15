# Xbox memory and add-on compatibility audit

Audit date: 2026-09-16

## Scope

The complete packaged add-on was checked: manifest order and dependencies, all Lua/XML files, event and update registrations, controller input, scene/keybind ownership, native UI hooks, SavedVariables, combat-report lifetime, and all packaged DDS textures.

Automated verification covers Lua syntax plus mocked controller, frame-editor, minimap, resource-update, report-retention, delayed-callback, and template-guard behavior. Final validation on real Xbox hardware is still required because ESO memory pressure, scene timing, and other installed add-ons cannot be reproduced completely by the mocks.

## Required installation rule

SatuveXboxUI is a replacement for Bandits User Interface. Do not enable both add-ons together. They share the global `BUI` table, `BUI_*` controls, event/update namespaces, slash commands, and keybinding action names. Whichever add-on loads later can overwrite the other's runtime state.

`LibGamepad` AddOnVersion 107 (1.0.7) or newer is required. `LibGamepadContextMenuBridge` is unrelated and does not satisfy the dependency.

## Fixed in version 1.1.65

- Frame Edit Mode uses Bandit’s proven movable-control path. It deactivates the underlying gamepad list and removes only that menu’s A/back/trigger keybind groups, leaving Xbox pointer movement and A-drag available. B exits and restores the previous list when appropriate.
- The permanent LB/RB fallback poll now runs at 50 ms and only processes input while the native gamepad main menu is visible. Hidden scenes cannot change focus through this poll.
- The player-resource fallback now runs at 100 ms, pauses before player activation, updates existing state tables in place, and skips frame redraws when values are unchanged.
- Completed unsaved combat history is capped at 12 reports per session. Explicitly saved reports are preserved.
- Delayed callbacks use `SXUI_CallLater_*`, avoiding the common `CallLater_*` update namespace used by other add-ons.
- The global ESO template guard now blocks only the native compass or player-progress control when Satuve owns that control's saved position. Custom controls in other add-ons are no longer blocked merely because they use the same template.
- Missing `ZO_ActionBar1KeybindBG` no longer causes an error on clients where that native control is unavailable.

## Memory observations

The package contains 60 DDS files. Their estimated decoded RGBA footprint is about 8 MiB if every texture were resident simultaneously. Four large curved-frame textures account for about 4 MiB of that estimate and are referenced only when curved frames are enabled. Leave curved frames disabled on memory-constrained systems unless required.

The minimap follow loop runs at 250 ms. Buff/action/on-screen timers are feature-gated and generally run at 200 ms. Frame-editor and movement loops exist only while their feature is active. No continuously growing log was found with default settings.

Manually saved combat reports are intentionally not capped. Players on constrained hardware should delete old saved reports they no longer need.

## Known overlap risks

- AUI and LUI Extended can overlap with unit frames, action bars, reticle changes, minimap behavior, and native control anchors. Disable the overlapping modules in one add-on.
- Srendarr and Action Duration Reminder can duplicate buff or action timers. Choose one display for each function.
- Other minimap implementations can compete for ESO's world-map scene, dimensions, pins, and map mode. Enable one minimap implementation at a time if restoration, pin size, or pin color conflicts appear.
- MapPins, HarvestMap, Destinations, QuestMap, and other pin providers should generally work as pin sources, but a provider that also changes global pin size, tint, or map mode can still conflict.
- Satuve intentionally modifies native action bar, compass, resource, alert, reticle, quest tracker, and world-map controls when the matching feature is enabled. Add-ons managing the same native control must be configured to avoid overlap.

## Manual acceptance

Run every item in `XBOX_TEST_CHECKLIST.md`, with special attention to a one-hour play session, more than 12 combat reports, group-frame editing, repeated Frame Edit Mode entry/exit, full-map restoration, and tests with the actual intended add-on set.
