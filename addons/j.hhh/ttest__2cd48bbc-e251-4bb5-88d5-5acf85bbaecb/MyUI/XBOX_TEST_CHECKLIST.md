# Xbox manual acceptance checklist

Use a character with existing Bandit SavedVariables. Record the initial frame layout and minimap preference, position, size, and zoom.

## Controller editor

- [ ] Open Bandit Xbox UI → Misc → Move Frames using only the controller; verify there is no separate Frame Edit Mode entry.
- [ ] Move the controller pointer over Group Frames, hold A, drag the group frame, and release A; verify the frame follows and stays at the new position.
- [ ] Verify Group Frame starts with a visible gold selection. Use all four D-Pad directions to select nearby frames; press A, move the selected frame with D-Pad, and press A again to place it.
- [ ] Verify the Bandit/ESO settings list, its help text, dark left panel, Defaults, and Reload UI are no longer visible over the frame editor; only Exit Move Frames remains in the keybind strip.
- [ ] Repeat the A-drag test with player, target, buffs, notifications, minimap, and one meter that is enabled.
- [ ] While the editor is open, repeatedly press D-Pad Up/Down/Left/Right; verify the hidden settings selection does not move.
- [ ] Press A repeatedly over movable frames; verify no hidden setting activates and the game language cannot change.
- [ ] Press B; verify Move Frames closes and the position is saved.
- [ ] Verify normal settings navigation and A/B work again after closing.
- [ ] Enter and leave Move Frames at least three times; verify there are no duplicate B actions or stuck controls.
- [ ] Run /reloadui; verify saved positions, including the group frame and minimap.
- [ ] Restart ESO; verify positions again.
- [ ] If mouse is available, repeat the same drag test and verify the shared Bandit MoveFrames path works.

## Minimap

- [ ] Set Minimap size to 200; verify the visible Minimap becomes exactly 200x200 px immediately.
- [ ] Set Minimap size to 500; verify the visible Minimap becomes exactly 500x500 px immediately.
- [ ] Close settings and run /reloadui; verify the selected pixel size remains active.

- [ ] Open Bandit UI -> Minimap with a controller and select each numeric slider.
- [ ] Press D-Pad Left/Right on size, transparency, pin scale, every zoom value, mounted zoom ratio, and global zoom; verify each changes by its configured step and applies immediately.
- [ ] Move off each slider and back again; verify D-Pad Up/Down changes rows while Left/Right changes only the selected value.
- [ ] Confirm no protected-function UI error appears while changing sliders.

- [ ] Login; verify the enabled preference, size, anchor, title, alpha, pin settings, and zoom.
- [ ] Run /reloadui repeatedly; verify the minimap appears each time.
- [ ] Use a wayshrine, teleport between zones, and cross zone/subzone boundaries.
- [ ] Enter and leave a building.
- [ ] Enter and leave a house; verify current house and prior outdoor maps.
- [ ] Enter and leave a dungeon; verify map identity and dungeon zoom.
- [ ] Open and close the full world map repeatedly in Gamepad UI; verify both map sizes remain usable.
- [ ] Test Cyrodiil, Imperial City, or other PvP maps if available.
- [ ] Die and respawn if feasible; verify recovery.
- [ ] Mount and dismount; verify the saved mounted zoom ratio.
- [ ] Switch Gamepad UI state and test Accessibility Mode if supported.
- [ ] Disable the minimap in Bandit settings, open/close the world map, and re-enable it; verify preference isolation.
- [ ] Restart ESO; verify minimap preference, position, size, and zoom remain correct.
- [ ] Check for Lua errors, blank tiles, missing player pins, hidden controls, or chrome outside the minimap boundary.

## Memory and long-session stability

- [ ] Leave the character logged in for at least 60 minutes while changing zones and entering combat; verify memory use does not continually accelerate while idle.
- [ ] Complete more than 12 fights lasting at least 10 seconds; verify the oldest unsaved reports are discarded and the newest 12 remain navigable.
- [ ] Save one combat report, complete more than 12 later fights, and verify the saved report remains available.
- [ ] Enable the curved frame, reload once, inspect it, then disable it again; verify no Lua errors and normal frames return.

## Add-on compatibility

- [ ] Disable the original Bandits User Interface before enabling SatuveXboxUI; verify only one of the two is active.
- [ ] Verify `LibGamepad` 1.0.7 or newer is enabled. Do not confuse it with `LibGamepadContextMenuBridge`.
- [ ] Open and close the native gamepad main menu, Move Frames, world map, inventory, and settings repeatedly; verify LB/RB, D-Pad, A, and B never affect a hidden screen.
- [ ] If AUI or LUI Extended is installed, disable its overlapping unit-frame, action-bar, reticle, and minimap modules before testing SatuveXboxUI.
- [ ] If another map/minimap add-on is installed, test zone travel, full-map open/close, pin sizes, pin colors, and map restoration. Keep only one minimap implementation enabled if behavior conflicts.
