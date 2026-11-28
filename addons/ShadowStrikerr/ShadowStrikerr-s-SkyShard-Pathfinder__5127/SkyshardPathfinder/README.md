# ShadowStrikerr's SkyShard Pathfinder

Version 0.4.24

AI disclosure. OpenAI Codex generated and revised portions of the Lua code.

Follow walked paths saves a limited number of your own walks by map and connects
them where their recorded positions meet on the same level. Arrows follow the
connected route and use its recorded elevations. Walk around an obstacle with
the setting enabled to make that passage available. Ground arrows stop where the recorded route ends unless Allow direct arrows
beyond walked paths is enabled. Direct segments indicate the bearing and may
cross obstacles. Keep arrows visible through terrain is on by default. Turn it
off to let terrain obscure arrows behind it. The distance panel shows
straight-line distances.

Show colored trail dots on AUI minimap draws a matching trail when the optional
AUI minimap is active. Bright dots show a walked stretch, and dimmer dots show the remaining
unverified bearing. Directional arrows
only hides the minimap trail and leaves 3D arrows on.

Directional arrows only (no trail dots) hides Pathfinder's map pins and distance panel while
keeping the ground trail. Turning it off restores your previous pin preferences.

Maximum SkyShard trail distance filters the arrows, minimap trail dots, and
distance panel by straight-line distance to each SkyShard. All is the default.

Enable Include collected SkyShards in trails when leading a group. Pathfinder
adds shards your character has already collected on the current map. Ground
trail destinations still sets the count, independently of map-pin visibility.

The World-map pin style picker previews black uncollected and white collected
pins beside the dropdown. Enable either group independently in the settings panel.
Both groups start on. Disable Pathfinder's pins if another addon already supplies
the SkyShard pins you prefer.
Pins use ESO's native shard status and current-map coordinates. Shards without
usable native positions on the displayed map are omitted.

The ESO Default pin style references the game's built-in textures and preserves
their original colors. Pathfinder's six custom styles support separate
collection colors. Pathfinder map pins offer size, layer, and hover hints from
ESO. For trail-only use, keep Show ground trail on and switch both Pathfinder
map-pin groups off. SkyShards can continue to provide its own pins independently.

Use the two map-pin color pickers to tint Pathfinder's own uncollected and
collected pins. Their default colors are black and white. The four ground-trail
color pickers cover 0-100 m, over 100-500 m, over 500 m, and collection
confirmation. The confirmation color briefly applies when the tracked shard
is collected, or when collecting a shard while a marked test trail is visible.

With LibAddonMenu-2.0 enabled, open Settings > Add-Ons > SkyShard Pathfinder
and use the Ground trail icon dropdown to select a named style and preview it.
LibAddonMenu is optional. Slash commands work independently of the menu.
Use Visit Website in the settings header to open the ESOUI listing.

Open the quick settings popup with `/ssp`, the Quick settings button in
Pathfinder's settings, or the Open quick settings keybind. The popup provides
trail and minimap controls and shortcuts to full settings and keybindings.

Click the SkyShard crystal beside the title to collapse the panel and pause automatic guidance. Click the crystal again to reopen the panel and resume guidance. Drag the collapsed crystal to move both the icon and the panel. Turn off **Show collapsed SkyShard icon** to hide it and use `/ssp panel` to resume.

Close the distance panel with its top-right ×. To show it again, use `/ssp panel` or enable **Show distance panel (expanded)** below the Settings and Keybindings shortcuts in the popup.

Use `/ssp help` to list the available commands. Click a Pathfinder world-map pin to set a target. Its ground arrows and minimap dots use your distance colors, and automatic trails pause. The distance panel labels the target. Announce selected targets in chat is on by default and can be turned off in settings. Use **Auto SkyShards** on the distance panel, **Clear target** in quick settings, or `/ssp reset` to resume automatic selection. When ESO supplies a linked entrance POI, the overland trail leads to that entrance and continues toward the SkyShard inside.

Ground trails also offer **Flat Chevron**, **Double Chevron**, and **Needle Arrow**.
Choose **ESO Default** or use `/ssp icon eso` for ESO's outlined SkyShard map
icon in your trail colors.
World-map styles also include **Ringed Diamond**, **Beacon Crystal**, and **Delve Marker**.
Delve Marker uses the doorway artwork for all Pathfinder SkyShard pins.

The default chat command is `/ssp`. Change it in the Chat command box in
Pathfinder's settings, or clear the box to restore `/ssp`.

Use the Keybindings button in Pathfinder's settings to open ESO's Keybindings menu. Under General > SkyShard Pathfinder, assign keys to
Toggle ground trail and Move distance panel.

Use `/ssp icon` to see the current ground trail icon. Choose `/ssp icon chevron`
for the original crystal chevron, `/ssp icon arrowhead` for a broad arrow, or
`/ssp icon shard` for a faceted crystal with a prominent leading point. The
trail updates immediately and ESO saves the choice account-wide. Each style
uses the same distance colors.

For ESO PC with keyboard and mouse (API 101051). There are no required addon or
library dependencies. Ground arrows are disabled in dungeon contexts. Map pins,
the distance panel, and the optional AUI minimap remain available where supported.

## Install and test

Extract the ZIP into the ESO Documents folder under `Elder Scrolls Online/live/AddOns`.
The resulting manifest should be at `AddOns/SkyshardPathfinder/SkyshardPathfinder.txt`.
Enable SkyShard Pathfinder in the Add-Ons menu. Fully exit and restart ESO when
installing or updating texture files.

By default, flowing ground trails point directly to eligible uncollected shards
on the player's current map. The nearest trail is larger, and similar bearings
share one trail. A panel below and left of the compass shows each eligible destination's straight-line
distance. Use Ground trail destinations to show all eligible shards or the
nearest 1, 3, or 5. Browsing a different map
pauses automatic guidance. Return the world map to the player location to
resume. Use the Show ground trail setting to turn guidance off.
Use `/ssp trail` to report the active target, direct distance, and the number of
arrows sent to the renderer, or the reason guidance is paused.
Type `/ssp move` while the distance panel is visible to activate the cursor,
then left-drag the panel's header. Its location is saved account-wide.

1. On flat ground in an overland zone, stand at a recognizable point and type
   `/ssp mark`. Walk 10-20 meters away, turn toward the point, and check that a
   turquoise trail leads back to it. Approach from several directions and rotate
   the camera while standing still.
2. Repeat on a slope, stairs, and beside a wall. Check whether chevrons float,
   clip, flicker, or show through scenery. Compare first- and third-person views.
3. Repeat with Questbound ground navigation active. Check arrow directions,
   color distinction, visual overlap, and responsiveness with both trails visible.
4. Open and close the world map, transition into a delve, and reload the UI.
   Confirm the test trail hides outside the gameplay HUD and clears on transition
   or reload. Use `/ssp clear` to remove it and `/ssp auto` to resume automatic guidance.
5. With the map on the player location, use `/ssp probe` in overland and delve
   maps. Compare the reported native positions and map membership of known
   undiscovered, discovered, and collected shards. The probe uses the currently
   displayed map for the membership flag and does not change the map.

Trail height blends recent walked heights on the same level and carries that
height forward where nearby samples are missing, with a short slope estimate.
Terrain and objects can occlude arrows, which are rendered behind HUD windows.
The trail updates each frame while active. Arrows flow at 1.4 meters per second
with 2.2 meters between them.
The native SkyShard probe is diagnostic.

`Navigation.lua` produces the trail from player and destination positions.
`Renderer.lua` draws and reuses world-space controls. `Skyshards.lua` provides
native shard locations to both map pins and the trail. `Prototype.lua` owns
target selection, commands, refresh timing, and transition cleanup.

## Credits

- [Questbound by brianmit](https://www.esoui.com/downloads/info4893.html) was a visual reference for the trail and panel.
- [SkyShards by AssemblerManiac, Ayantir, Garkin, and Sharlikran](https://www.esoui.com/downloads/info128-SkyShards.html) informed the settings layout.
- [Map Pins by Hoft and art1ink](https://www.esoui.com/downloads/info1881.html) informed pin refresh behavior. Pathfinder adds an optional click action to compatible Map Pins SkyShard pins.
- [AUI – Advanced UI by Sensi](https://www.esoui.com/downloads/info919-AUI-AdvancedUI.html) supplies the optional minimap. ESO supplies SkyShard positions and the ESO Default pin art at runtime.

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
