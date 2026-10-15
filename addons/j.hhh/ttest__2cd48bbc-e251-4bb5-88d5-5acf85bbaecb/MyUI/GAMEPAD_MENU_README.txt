SATUVE XBOX UI - GAMEPAD MENU INTEGRATION
Version 1.7.9

CHANGES
1. Native ESO main menu focus transfer:
   - LB while the RIGHT text list is active -> focus moves to the LEFT quick/icon rail.
   - RB while the LEFT quick/icon rail is active -> focus moves back to the RIGHT text list.
   - D-pad left/right is no longer used by this bridge.

2. Bandit UI settings grouping:
   - LibAddonMenu/LibGamepad now receives ONE top-level panel named "Bandit UI".
   - Base Options, Player Frames, Attackers Frame, Group Frames, Target Frame,
     Ability Timers, Buffs, Reticle, Damage Statistics, Notifications,
     Frames Settings, Meters, etc. are submenus inside that one panel.
   - Without LibAddonMenu the original Satuve/BUI menu remains as fallback.

CONTROLLER LIBRARIES
- Required for the controller tree and displayed by ESO under Required Add-Ons:
  LibGamepad AddOnVersion 107 (1.0.7) or newer
- Recommended for the classic settings path and fallback:
  LibAddonMenu-2.0 r41 or newer

LibGamepad must be installed and enabled for the Bandit UI controller settings
tree. Find it under ESO's Extensions / Manage My Extensions area.
The Side Panel Settings button opens the same controller panel directly.
LibGamepad is a required manifest dependency for this console-focused package.
LibAddonMenu-2.0 is also required because LibGamepad uses its option data and
controller integration. Install the newest Xbox versions of both libraries.

3. Minimap controller settings:
   - Minimap is now added as a submenu inside the single Bandit UI panel.
   - Enable/disable, size, title, pin scale, all zoom values, pin colors and reset
     are exposed through LibAddonMenu and therefore available to LibGamepad.
   - Changes use the original minimap callbacks and apply immediately.

1.1.24: Unified Bandit UI controller menu now sorts numbered pages 1..20, includes Side Panel (2), Minimap (9), Automation (18), Custom Bar (20), and keeps nested page groups such as Buffs/Advanced Options inside their parent page instead of the left navigation column.


1.1.25: Preserve native nested LAM submenu trees for compatible LibGamepad versions. Root Bandit UI contains only numbered pages 1..20; page-specific submenus such as Buffs/Passives stay inside their parent page. Minimap controller-safe values retained.

1.1.27: Direct LibGamepad hierarchy. Registration is delayed until after PLAYER_ACTIVATED so LibGamepad/ZO_SharedOptions are initialized; the duplicate legacy native settings panel is suppressed whenever the LibGamepad/LAM bridge is active. Root is limited to numbered sections 1..20 and nested page options remain nested.

1.1.28: Documented controller dependencies and menu location, restored Meters page 21, made Side Panel hover text readable in gamepad mode, and routed the Side Panel Settings button directly to the LibGamepad Bandit UI panel.

1.1.29: Declared LibGamepad as a required dependency so ESO displays it in the add-on details. Minimap size now accepts numeric controller values, saves the normalized value, and resizes all live Minimap controls immediately without rebuilding callbacks.

1.1.55: Custom Bandit UI checkboxes, sliders and dropdowns now call their original addon setters directly instead of entering ESO's protected SetSetting path. Minimap following now derives a fresh absolute viewport offset from the current player/map position and performs one named delayed recenter after scene, map and zone transitions.

1.1.56: Fixed the required LibGamepad dependency to internal AddOnVersion 107. LibGamepad 1.0.7+ is accepted.

1.1.57: Minimap map context now follows the player's real ESO map automatically.
City/local, interior and dungeon maps switch back to the correct outdoor/world
map after leaving them, without opening the full map manually. Map selection and
profile refreshes are event-driven. Normal player movement and arrow rotation are
smoothed at about 30 FPS from authoritative player coordinates without accumulated
offset drift. Zone/loading/teleport/map changes snap and recenter immediately.
The minimap hides in combat while context changes continue in the background, then
refreshes and snaps to the correct current map when combat ends.

1.1.58: Fixed blank delve/interior maps and half-clipped outdoor maps after leaving
local areas. Event-based context changes now run ESO's complete OnWorldMapChanged
tile, pin and pan/zoom initialization, followed by two lightweight viewport geometry
passes. The minimap now stays visible and continues smooth tracking during combat.
LibGamepad remains fixed at required AddOnVersion 107 (1.0.7) or newer.

1.1.59: Restored exact alignment between the minimap and ESO's normal full map.
The addon no longer resizes or repositions ESO's stock map coordinate root while
minimap mode is active. Player centering now prefers ESO's native current-map
coordinates, with universal coordinates used only as a temporary fallback when
the native position is unavailable. The 1.1.58 event-based tile initialization,
delayed viewport stabilization, combat visibility and LibGamepad 107 requirement
remain intact.

1.1.64: Made /reloadui startup idempotent and split the former single-frame
initialization burst into four one-shot stages. Scene fragments, global template
hooks, action-bar OnShow hooks, menu registration and event registration are now
guarded against duplicate installation. LibGamepad registration also handles the
case where PLAYER_ACTIVATED already fired. No layout or SavedVariables changed.

1.1.65: Added modal controller ownership for Frame Edit Mode, native minimap
scene recovery, lower-allocation player resource refreshes, a 12-report cap for
unsaved session history, add-on-specific delayed callback names, and a scoped
native template guard to reduce conflicts with other UI add-ons.

1.7.6: Fixed Frame Edit Mode A-button activation. The editor now lets ESO's
exclusive keybind strip receive physical A/B buttons, A grabs and places frames,
B cancels the current movement, and the Skills / Action Bar is available as a
controller-editable frame. Modal menu isolation and keybind cleanup are retained.

1.7.7: Fixed D-Pad frame selection on Xbox by registering Frame Edit Mode with
ESO's native directional-input manager and movement controller. Controller
directions are consumed while the modal editor is open and released before the
settings list is restored. Minimap controller options also use native gamepad
slider rows again so size, opacity, pin scale and zoom steps apply immediately.

1.7.8: Removed the Frame Editor's DIRECTIONAL_INPUT/GetXY path because it can
reach ESO's private IsKeyDown function from an insecure add-on call stack. D-Pad
selection now uses ethereal entries in the editor's exclusive keybind strip.
The settings list remains deactivated while editing and is restored on exit.

1.7.9: Frame Edit Mode now restores the UI Shortcuts action layer when a console
extension menu did not leave it active and supports left-stick frame selection as
an independent fallback. Minimap numeric settings are finite controller value
lists so value changes always reach the original setters. LibGamepad 1.0.7+ and
LibAddonMenu-2.0 r41+ are required; install the newest Xbox versions available.
ContextMenuBridge is not a replacement.

1.7.10: Restored the confirmed-working Bandit MoveFrames implementation for the
Move and Frame Edit Mode buttons. The guard now deactivates only the underlying
ESO settings list and removes only its A/back/trigger keybind groups. It does not
push a modal keybind state, add an action layer, take focus or poll controller
sticks. Xbox pointer movement and A-drag stay available; B exits and restores the
previous options list when it is still open. The safe Minimap value lists remain.

1.7.11: Minimap size, transparency, pin scale and zoom settings now use
ESO's native Gamepad slider rows again. D-Pad left/right reaches the addon's
console-safe slider callback and applies the original Bandit setFunc immediately.
