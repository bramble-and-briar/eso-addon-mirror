## Current release: 2.4.11
The shared Activity Finder accept/decline dialog mover is unavailable. Its saved position is retained, but the add-on no longer reads, moves, or hooks any shared gamepad dialog. Queue status, ready-check progress and HUD prompts still have movers. There are now 54 available native mover entries. This takes precedence over historical dialog-mover descriptions below.

# MovableHUD 2.4.11

Built from the supplied 2.2.4 ZIP. The unavailable 2.3.0 package was not used.
Preserves existing Chat, Quest, Group and solo Companion settings and the account-wide saved-variable namespace/version. Adds 55 native HUD entries, all OFF by default.

## Use
Use your existing console add-on upload/install workflow with the MovableHUD folder. Keep the existing LibHarvensAddonSettings dependency installed. No saved-variable deletion is needed.
Open Options > Settings > Addons > Movable HUD. Enable desired elements and adjust Horizontal/Vertical position in 5-pixel steps. Native positions are offsets from ESO anchors, not absolute coordinates. Native Reset disables its override and restores anchors. Reset All also uses the original reset behavior for existing movers. Native size/scale controls are omitted; existing sizing/scaling is preserved.

## Coverage
Golden Pursuits / Tamriel Tomes / Endeavors (shared tracker in newer UI), achievement tracker, Activity Finder queue status, ready-check progress, specific accept/decline dialog and HUD prompt; compass, action bar, six resource bars, target health, boss health and separate brackets, buffs/debuffs, combat tips, reticle, stealth, interaction text, synergy, resurrection, capture meter, Battleground scores/keybind, trial lives, death prompts, ram, bounty/infamy, Tel Var, Daedric energy, equipment, loot history, subtitles, alerts, notification icons, voice chat, announcements, instance kick warnings, adventure/dynamic/house/Archive/zone-story/event-selection trackers, adventure and Archive scores, Archive buffs, and optional performance meters.
MovableHUDRegistry.lua lists exact targets. Missing/hidden controls wait without being forced visible. Linked controls retain their native relationships; moving one can move others anchored to it. Boss brackets are separate because ESO anchors them directly to the compass.

## Safety and limits
Explicitly allowlisted discrete controls only. Screen-sized roots, zero-anchor controls, menus, maps/inventory, radial input systems, world-space nameplates and pooled tutorial popups are excluded. This covers reviewed addressable HUD controls, not every visible item on every client.
Native capture preserves both anchors, relative controls, offsets and constraints. Parent, dimensions, scale, visibility, focus and input remain ESO-owned. Native re-layout replaces the restore point. Hidden/replaced/disabled/reset controls release their overrides. Failed writes attempt rollback and do not stop other native movers.
Corrected the 2.2.4 anchor reader to handle ESO's validity return flag.
Shared gamepad dialogs move only for a known LFG ready-check incoming type and matching dialog name. Show/release hooks restore them before reuse. The global controller keybind strip stays in its native location.
Newer trackers can live inside ESO's scrolling tracker container; its clipping/layout rules remain active. Validate large offsets on PS5. Restricted controls may remain unavailable. No protected API bypass is attempted.

## Validation
Lua 5.1 compilation/load, manifest references/order, ZIP CRC/structure and mocked behavior checks passed. Tests cover 2.2.4 migration, opt-in defaults, dual-anchor constraints, repeated apply without drift, native layout changes, hidden/missing/replaced controls, screen-root rejection, failed-write rollback, reset/re-enable, dialog identity/reuse, settings and Reset All.
Actual PS5 gameplay has NOT been tested. Start with Golden Pursuits, then dungeon/Battleground queue -> prompt -> accept/decline -> completion/cancellation -> unrelated dialog. Check reload persistence, reset while visible/hidden, safe-zone changes, group/raid/companion transitions and activity-specific elements. Report failing settings labels, activity and API version.

Reference: https://github.com/esoui/esoui (live source downloaded 2026-09-28; README identifies UI 12.1.5 / API 101051). Manifest retains baseline API 101050 too. Both old/new Golden Pursuits tracker names are supported.
Only the supplied 2.2.4 migration is validated. Unknown 2.3.0-specific settings cannot be mapped reliably without that package; unknown saved entries are retained.


## 2.4.8 color controls
Added account-wide RGB sliders (0-100%) for placement outline borders/fill and 12 optional HUD color groups: health, magicka, stamina, mount stamina, werewolf timer, siege health, boss health, reticle, subtitles, interaction text, non-interaction text and combat-tip text.
Custom HUD colors start OFF and are independent of position overrides. Each color group has an enable switch and Restore native color button. Outline color has its own reset. Reset Colors restores all color defaults without moving anything; Reset All resets positions and colors. Existing position settings survive the upgrade.
Only explicitly named visual controls are tinted. Other HUD elements do not have color overrides. White outline labels remain white for readability. Outline fill is 10% opacity and borders are 95%; their RGB channels share the selected color. HUD animation opacity is preserved; no HUD alpha slider is exposed.
When enabled, a custom tint replaces ESO's state-based tint for that visual, including reticle feedback. Native changes are detected by a 250ms guard, so transient native color flashes may be visible. Disabling restores the most recently observed native RGB without changing current alpha. Settings reset buttons refresh slider displays.
New mocked tests passed for opt-in colors, saved-color normalization, dual health bars, preserved alpha, native recolors, disable/reset, hidden/replaced controls, failed writes, and outline colors. Actual PS5 rendering and controller interaction still require in-game testing.



## 2.4.8 per-element preview
Every movement section now includes Preview this element. Selecting it isolates that element's labeled preview and turns on the global outline setting. The preview works with its position override disabled; enable the override to use the position sliders. It is temporary and ends when leaving the MovableHUD settings page.
Visible elements use live bounds. Hidden elements use last observed bounds from this session, translated by the position-slider changes. If no bounds have been observed, a labeled sample appears near screen center; that sample is NOT an exact native-position prediction. Activate the relevant activity to confirm final placement. No native control is forced visible and no queue dialog/gameplay action is triggered. Turning off an individual preview returns to the global outlines behavior.
Adjusting a position, size or scale slider now automatically isolates that section's preview box and updates it immediately. Enabling a mover also reveals its box. No separate preview-toggle step is required. This applies only while the MovableHUD settings page is open; commands used outside settings do not open previews. Hidden chat/quest samples also follow size and scale changes.


## 2.4.8 console trust fix
Removed all ZO_PreHook/ZO_PostHook wrappers around ESO-owned functions. Dialog show/release and existing chat/group hooks now use the documented SecurePostHook API, leaving the original ESO function call path intact. This addresses a likely cause of UI Error 5FBC090C in the Mod Browser private update-availability check. The screenshot alone does not prove the complete source of the tainted call stack.
If secure dialog hooks are unavailable or cannot register, the shared accept/decline dialog mover remains inactive; queue/progress movers and previews remain available. No insecure hook fallback is installed. Fully restart ESO after replacing the old build to remove its already-installed wrappers. Re-test the Installed add-ons screen and its dialogs, then ready checks. Real PS5 trust enforcement cannot be reproduced by the local Lua mocks.


## 2.4.8 preview checkbox focus fix
Removed forced panel re-selection from the Preview this element checkbox callback. Pressing X now changes preview state without scheduling a page rebuild or changing the panel selection. The settings library keeps ownership of controller focus. Automatic slider previews and the previous secure-hook fix remain in place. Regression tests invoke every movement-section preview checkbox on/off and reject deferred refreshes or panel re-selection. Actual controller behavior still requires PS5 confirmation.

## 2.4.9 preview visibility fix
Preview visibility now follows the library's LibHarvensAddonSettings_AddonSelected callback and its dedicated scene, instead of gamepad_options_root and stale panel flags. Previews clear immediately when another add-on is selected or the settings scene closes. Late scene creation is supported. Preview outlines render at a higher draw level so the settings background does not cover them. Native hidden frames remain untouched; labeled preview boxes represent unavailable elements.
Package and manifest names no longer include TEST or PS5-TEST. PS5 runtime confirmation is still required; local validation cannot prove console rendering.


## 2.4.10 installer-dialog isolation
Removed all shared-dialog integration following UI Error 941CC4D4 involving GetModListingInstallState. Local regressions verify no shared-dialog getter calls, anchor writes, or hook registrations even when the old setting was saved enabled. This removes MovableHUD's integration with that path; the screenshot cannot establish whether another add-on or previously loaded version also contributes.
Close ESO completely after changing versions. If updating is blocked, disable MovableHUD, restart ESO, update it, then re-enable it and restart. If the installer error persists with MovableHUD disabled after a full restart, another add-on or the game needs isolation. Console runtime confirmation remains outstanding.


## 2.4.11 Update 51 quest tracker compatibility
The enabled quest mover now moves the quest control from the clipping scroll hierarchy to ZO_HUDTrackers, the same non-scrolling HUD parent ESO uses for detached trackers. It retains the HUD parent's scene visibility and the quest fragment's own visibility; no hidden flags or alpha are forced. Existing saved positions/sizes/scales remain in use. ESO layout refreshes reapply the mover through a secure post-hook. Disabling restores the captured parent and anchors. Quest Reset now disables the override and clears position initialization so ESO controls placement again. Older clients without this hierarchy use the previous movement path.
Local tests verify parenting, left-side position, native reattachment, restoration, visibility ownership and fallback. Confirm the left-side placement and menu/quest transitions in-game.

