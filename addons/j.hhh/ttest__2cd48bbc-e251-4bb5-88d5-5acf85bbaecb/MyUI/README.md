# Satuve Xbox UI

Satuve Xbox UI is a modified fork of **Bandits User Interface**, adapted and maintained by **Satuve** for the ESO client on PC that connects to Xbox servers and is used with mouse and keyboard.

## Controller settings requirements

The controller settings libraries are installed and enabled separately:

- **Required and shown by ESO under Required Add-Ons:** LibGamepad AddOnVersion 107 (1.0.7) or newer
- **Required:** LibAddonMenu-2.0 r41 or newer
- **Required for the Minimap:** Votan's Minimap 2.2.2, LibAsync 3.1.4 or newer, and LibHarvensAddonSettings 2.1.6 or newer

Open the controller settings through ESO's **Extensions / Manage My Extensions** area and select **Bandit UI**. The Side Panel settings button also opens this controller panel directly. Both libraries are required manifest dependencies for this console-focused package. Install the newest Xbox versions available; the manifest accepts LibGamepad AddOnVersion 107+ and LibAddonMenu-2.0 AddOnVersion 41+.

## Credits

- Xbox adaptation, packaging and maintenance: **Satuve**
- Original Bandits User Interface: **secretrob**, **Hoft**, and contributors
- Portions of the original project were based on Foundry Tactical Combat by **Atropos**

Thank you to the Bandits UI authors and contributors for the original foundation.

## Changes in 1.0.0-xbox

- New add-on identity, folder and `.addon` manifest
- Separate SavedVariables to avoid collisions with the original add-on
- All runtime texture paths changed to `SatuveXboxUI`
- Xbox-server PC compatibility fixes from the prior test build
- Added `/sxui` and `/satuveui` diagnostic commands
- Keyboard/mouse mode detection retained for this client configuration
- Quickslot, regrouping, localization and custom-bar fixes included

## Installation

Install and enable Votan's Minimap, LibAsync and LibHarvensAddonSettings first. Then extract the folder `SatuveXboxUI` into the add-on directory used by your ESO Xbox-server PC client. Do not install it alongside an enabled copy of the original Bandits User Interface because both still use parts of the internal `BUI` Lua namespace.

## Xbox memory and add-on compatibility

- **SatuveXboxUI replaces Bandits User Interface. Never enable both together.** Both add-ons still use the global `BUI` namespace, `BUI_*` controls, event/update names, slash commands, and keybinding actions. Load order cannot make that combination safe.
- `LibGamepad` 1.0.7 or newer must be installed and enabled. `LibGamepadContextMenuBridge` is a different library and does not satisfy this dependency.
- Avoid enabling overlapping unit-frame, action-bar, reticle, or minimap modules from AUI, LUI Extended, or another full UI add-on at the same time. Disable the overlapping module in one add-on before testing the other.
- The runtime now keeps at most 12 completed unsaved combat reports. Reports explicitly saved by the player remain available.
- The packaged textures occupy about 8 MiB when decoded to RGBA if every texture were resident at once. The largest curved-frame textures are only referenced when the curved-frame option is enabled, so leave that option off on memory-constrained systems unless it is needed.

## Version 1.9.26

- Removes the remaining temporary Combat Log camera-state chat logging and diagnostic-only release artifact.
- Keeps Combat Log controller input, focus, camera-mode ownership, mouse support and native keybind hints unchanged.
- Keeps the final RaidFrame `TOPLEFT`/`TOPLEFT` persistence fix and legacy compatibility unchanged.

## Version 1.9.25

- Removes the temporary RaidFrame chat command, stored snapshots, geometry capture, initialization hooks and on-screen inspection panel.
- Keeps the canonical `TOPLEFT`/`TOPLEFT` RaidFrame save and restore behavior and legacy-anchor compatibility unchanged.
- Makes no functional changes to Move Frames or other UI systems.

## Version 1.9.24

- Forces the existing live player-resource renderer to repaint newly rebuilt PlayerFrame labels.
- Prevents `Health`, `Magicka`, `Stamina` and `Pct%` construction labels from remaining visible after Move Frames, settings rebuilds or UI loading when the cached values did not change.
- Initializes those six labels empty so placeholder words cannot flash during control creation.
- Does not change resource calculations, PlayerFrame dimensions/positions, RaidFrame, Frame Editor movement, Combat Log, Sidebar, Custom Bar, Quick Menu or controller navigation.

## Version 1.9.23

- Restores a readable 26-pixel font size for the numeric health value inside `BUI_TargetFrame`.
- Changes only `BUI_TargetFrame_HealthCurrent`; the TargetFrame dimensions, bar, name and position are unchanged.
- Leaves RaidFrame, Frame Editor, Combat Log, Sidebar and Custom Bar behavior unchanged.

## Version 1.9.22

- Gives only `BUI_RaidFrame` a canonical `TOPLEFT` to `GuiRoot TOPLEFT` saved position.
- Saves from direct `GetLeft()` and `GetTop()` screen geometry when movement is confirmed.
- Restores the canonical format directly without passing through centre-relative coordinates.
- Keeps older RaidFrame anchor formats on the existing legacy restore path until the user moves and confirms the frame again.
- Leaves the general Frame Editor, other movable frames and controller navigation unchanged.

## Version 1.9.17

- Fixes only the Group Frame position saved by Move Frames.
- Converts the editor's centre-based position to the Group Frame's persisted top-left anchor before saving.
- Leaves Player Frame, Target Frame, Combat Log and controller navigation behavior unchanged.

## Version 1.9.16

- Removes the insecure sidebar call path through `DIRECTIONAL_INPUT:GetX/GetY` that caused ESO to reject its internal `IsKeyDown` call.
- Keeps the corrected `mainMenuGamepad` scene integration while routing Left, Up, Down and Right through native keybind-strip callbacks.
- Refreshes those callbacks when the existing `BUI_Panel` becomes visible or hidden.
- Retains dynamic sidebar selection, existing mouse actions, A/Back hints and normal-menu restoration.
- Leaves all Combat Log and Statistics files unchanged.

## Version 1.9.15

- Connects the existing far-left icon sidebar to ESO's actual `mainMenuGamepad` scene.
- D-Pad Left pauses the normal menu list and enters sidebar focus; Up/Down moves through the visible actionable icons.
- Controller A invokes each icon's existing mouse action, while Right or B restores the normal menu selection and input.
- Uses ESO's native directional-input manager only while the main gamepad menu is open, with no custom update loop.
- Leaves all Combat Log and Statistics files unchanged.

## Version 1.9.14

- Routes mouse close actions through one complete Combat Log cleanup path.
- Keeps controller B hierarchical while the top-right mouse X closes the full report.
- Synchronizes controller state after mouse Equipment, Uptimes and target-detail actions.
- Makes the existing native keybind strip contextual for report, detail and auxiliary levels.

## Version 1.9.13

- Tracks whether the Combat Log itself enabled Game Camera UI mode and releases it only when owned.
- Closes the complete gamepad menu stack before opening the Combat Log.
- Leaves the restored V1 navigation and controller mapping unchanged.

## Version 1.9.12

- Restores the confirmed V1 Combat Log controller navigation based on direct `OnKeyDown` and `TakeFocus()` handling.
- Keeps the corrected 2x2 focus-frame edge texture and direct Combat Log menu entry.
- Removes the later Combat Log action-layer, binding and diagnostic experiments while preserving unrelated newer features.

## Version 1.9.11

- Adds the Votan Minimap to the existing Move Frames editor as a selectable Minimap frame.
- D-Pad movement updates a temporary editor handle; confirming writes the center offset to Votan's native account.x and account.y position.
- Cancelling restores the uncommitted position, while leaving Move Frames restores the native Minimap at the confirmed position.
- The full world-map control is not moved or resized.

## Version 1.7.19

- Uses Votan's Minimap as the required owner of ESO's native hidden Minimap.
- Removes Satuve's separate viewport/reparenting renderer, so only one Minimap system controls the world map.
- Keeps the Satuve Xbox settings sliders and forwards size, transparency, title, pin scale and zoom values to Votan.
- A size value of 200 produces a 200x200 visible map area; the full map keeps its normal size and opacity.
- Requires VotansMiniMap, LibAsync and LibHarvensAddonSettings; their source is not bundled in Satuve Xbox UI.

## Version 1.7.18

- Displays the native ESO map through the dedicated `BUI_MinimapViewport` clipping window.
- Keeps the complete map renderer active internally while hiding every tile, pin, frame, and floor control outside the selected Minimap square.
- Restores the normal native map hierarchy when the full world map opens.
- Reuses the existing 250 ms player-follow update to correct the viewport only if ESO changes its parent, dimensions, or root visibility.

## Version 1.7.17

- Fixes the native ESO gamepad map overriding the selected Minimap dimensions with its large gamepad layout size.
- Sizes both the Minimap root and the native scroll viewport, so the rendered map is clipped to the selected 200-500 px square.
- Reapplies the Minimap layout after ESO refreshes the map; full world-map mode restores its normal native layout.

## Version 1.7.16

- Makes the Minimap size setting a direct pixel value: 200 is 200x200 px and 500 is 500x500 px.
- Applies size changes immediately to the visible Minimap instead of relying on the general map reinitialization path while the controller settings menu is open.
- Keeps the existing 200-500 range and 20 px controller step to avoid an unnecessarily large controller value list.

## Version 1.7.15

- Removes the duplicate `Frame Edit Mode` settings button.
- The original localized `Move Frames` button is now the single entry point for mouse, pointer, D-Pad, A, B, modal menu hiding, and frame-position saving.
- Renames the editor keybind label to `Exit Move Frames` so the menu and active mode use one name.
## Version 1.7.14

- Fixes the Frame Editor selection border failing to initialize because ESO requires power-of-two edge texture dimensions.
- Uses a valid 8x2 edge texture configuration and cleans up the modal menu/input state if editor activation ever fails.
## Version 1.7.13

- Adds a visible gold frame selection controlled by D-Pad Up/Down/Left/Right.
- A switches the selected frame into movement mode; D-Pad nudges it and A confirms its new position.
- B cancels the current unconfirmed movement, while B again or View exits and restores the Bandit settings screen.
- Uses editor keybinds plus the focused overlay fallback and does not call ESO's protected `DIRECTIONAL_INPUT:GetXY()` path.
- Keeps the 1.7.12 modal menu hiding and the 1.7.11 native Minimap slider path.
## Version 1.7.12

- Frame Edit Mode now hides the ESO Gamepad options control, its shared left background, and its settings tooltip while keeping the options scene alive for controller pointer support.
- Suspends the complete settings keybind set, including Defaults and LibGamepad's Reload UI entry, so only the editor exit action remains visible.
- The overlay consumes only Escape/View itself; A and directional input remain available to the controller pointer and Bandit's original hold-A drag controls.
- On exit, the same settings list, visibility, keybinds, selected-row A action, and tooltip are restored through ESO's native selection handler.
## Version 1.7.11

- Restores native ESO Gamepad slider rows for every Minimap numeric setting.
- D-Pad left/right now uses the same controller slider path as the other Bandit settings and applies the original Minimap setFunc immediately.
- Keeps the console-safe slider callback that bypasses ESO's protected SetSetting call.

## Version 1.7.10

- Restored the proven Bandit `MoveFrames` path from the last confirmed movable 1.1.64 build for both Move and Frame Edit Mode.
- Removed the editor-owned keybind-state stack, extra action layer, focus takeover and stick polling that could also block the controller pointer/A drag path.
- While moving frames, only the underlying ESO settings list and its A/back/trigger keybind groups are suspended. A remains available to grab and drag frames; B exits the mode and restores the exact previous list when it is still open.
- Retains the 1.7.9 controller-safe Minimap value lists.

## Version 1.7.9

- Frame Edit Mode now explicitly activates ESO's User Interface Shortcuts action layer when the launching console menu did not keep it active, so D-Pad/A/B reach the exclusive editor keybind state.
- The left stick can also select frames with release-to-repeat debouncing; both sticks continue to move the selected frame after A is pressed.
- Minimap numeric settings use finite controller value lists on Xbox instead of unreliable native slider rows. The original numeric steps and setFunc callbacks are preserved.
- LibGamepad 1.0.7+ and LibAddonMenu-2.0 r41+ are required. Install their newest Xbox versions; LibGamepadContextMenuBridge is not a replacement.

## Version 1.7.8

- Replaced the Frame Edit Mode `DIRECTIONAL_INPUT:GetXY()` path that caused ESO to reject the private `IsKeyDown` call from add-on code.
- D-Pad Up, Down, Left and Right now use ESO's modal keybind strip and select frames without invoking protected input APIs.
- The underlying ESO/Bandit settings list stays deactivated while editing; A, B and D-Pad input remain exclusive to the Frame Editor and normal focus is restored on exit.
- Kept left/right-stick frame movement, frame-positioning calculations, Minimap slider behavior, SavedVariables and localization unchanged.
## Version 1.7.7

- Frame Edit Mode now receives D-Pad selection through ESO's native `DIRECTIONAL_INPUT` and `ZO_MovementController` path. This fixes frame selection on Xbox where raw `OnKeyDown` events were not delivered reliably.
- The editor consumes controller directions while open and releases its directional-input owner before restoring the settings list, so no menu behind it can react.
- Minimap controller options use the bridge's native gamepad slider rows again. Size, opacity, pin scale and zoom values change by their configured steps and apply immediately.
- Verified group-frame selection and movement, repeated entry/exit, modal input isolation, A/B behavior, minimap slider setters, and Lua syntax.

## Version 1.7.6

- Fixed Xbox A-button activation in Frame Edit Mode. The focused editor now passes physical A/B buttons to its exclusive ESO keybind state instead of consuming A before UI_SHORTCUT_PRIMARY can run.
- A now grabs a selected frame and confirms/releases it after movement. B cancels the current movement and restores that frame's grab-start position.
- Added the native Skills / Action Bar frame to controller editing.
- Added opt-in editor tracing with BUI.FrameEditor:SetDebug(true).
- Verified Minimap and Skills selection, A grab, left/right-stick movement, A placement, save, close, reopen persistence, modal input isolation, and repeated open/close cleanup.

## Version 1.1.65

- Frame Edit Mode now owns controller input while open. D-Pad and A cannot navigate or activate the settings list behind it, and B restores normal settings focus when the editor closes.
- The minimap uses ESO's native map mode and fragment with recovery for login, travel, map scenes, gamepad changes, and temporarily missing map controls.
- Reduced Xbox memory and CPU pressure by reusing player-resource state, skipping unchanged redraws, lowering the fallback refresh rate, and limiting unsaved session combat history to 12 completed reports.
- Reduced add-on conflicts with Satuve-specific delayed callback names and a template guard scoped to native controls whose positions are owned by Satuve.
- Added compatibility documentation and an expanded Xbox acceptance checklist.

## Version 1.1.63

- The gathering-navigation feature was extracted into the independent `SatuveResourceNavigator` add-on.
- SatuveXboxUI no longer owns its settings, HUD controls, events, routes, node data or optional HarvestMap integration.
- The minimap, normal map handling, combat UI and other Bandits UI systems are unchanged.

## License

The original package includes an MIT-style permission notice. This fork keeps the original attribution and permission notice in the manifest. No affiliation with ZeniMax Media Inc. or Microsoft is claimed.


## Version 1.0.2
- Fixed startup crash in BUI_Events.lua when CHAT_SYSTEM is not initialized yet on Xbox-PC.
- Startup messages are now queued until chat is available.


## Version 1.0.3 Xbox fix
- Added a safe fallback for clients where the legacy `MAX_BOSSES` constant is unavailable.
- Boss frame loops now use a validated numeric boss count.


## Version 1.0.4 Xbox compatibility
- Uses the effective maximum resource value returned by GetUnitPower so Health, Magicka and Stamina match the ESO character display.
- Adds a safe GetClassIcon compatibility helper for Xbox-PC clients.


## 1.0.5 Xbox compatibility fix
- Added a fallback for clients without `IsWerewolf()`.
- Protected mount, werewolf, and siege alternate-resource bars from missing or zero maximum values.


## 1.0.10 Xbox fixes
- Safe side-panel placement when the keyboard chat controls are unavailable.
- Player resource frame position is restored after death and HUD rebuilds.
- Added a 35-pixel gap between the player resource frame and the action bar.


## 1.0.28-xbox
- Keep the native ESO top boss-health fill texture so the red fill stays inside the boss-bar frame/brackets.


## v1.0.34-xbox
- Restored the top boss-bar adjustment from v1.0.29.
- Kept the syntax/loading safety correction from v1.0.30.
- Removed the later boss-frame/background shifting experiments.

## Version 1.1.28

- Documented the libraries and location required for controller settings.
- The Side Panel settings button opens Bandit UI's LibGamepad panel directly.
- Side Panel mouse tooltips use a readable gamepad font in controller mode.
- Restored page 21, Meters, in the controller menu.

## Version 1.1.29

- LibGamepad is now declared as a required dependency so ESO displays it under Required Add-Ons.
- LibAddonMenu-2.0 remains listed as an optional/recommended dependency.
- Minimap size values are normalized, saved and applied directly to every existing Minimap control.
- Minimap resizing no longer rebuilds event and scene callbacks.

## Controller layout and native minimap

The Misc page has Frame Edit Mode using Bandit’s proven movable-control path: point at a frame, hold A to drag it, release A to place it, and press B to exit. The Bandit minimap settings drive a native ESO map-mode adapter instead of the old shared-scroll viewport. Existing settings and SavedVariables are retained. See `XBOX_TEST_CHECKLIST.md` and `RELEASE_NOTES_1.7.10.md`. Real Xbox acceptance testing remains recommended.

The map behavior was researched against Votan's Minimap 2.2.2, but its release package provides no code-reuse license. This adapter was written independently; standalone Votan should not be enabled alongside this Bandit minimap because both use ESO's world map.
