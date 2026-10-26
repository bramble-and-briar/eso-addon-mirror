# Backpack Decon Select All 1.3.3

AI disclosure: Code was generated and revised with ChatGPT/Codex. Automated checks do not replace in-game testing. See CREDITS.txt for sources and acknowledgements.

Dependencies: none required. Optional FCO ItemSaver integration respects its deconstruction locks when installed.

Supports ESO's keyboard/mouse and controller interfaces at equipment deconstruction stations and universal deconstruction assistants. Standalone enchanting extraction and refinement are not supported.

## Keyboard/mouse

The existing warning checkbox remains above the item list. Tick it to select eligible unlocked backpack items; untick to clear the selection.

## Controller

Open the deconstruction screen, use the on-screen **Options** controller prompt, and highlight **Select All?**. The full warning appears in ESO's tooltip panel. Toggle the checkbox using the controller, then close Options to apply it. Untick it in Options and close the menu to clear the selection.

This uses ESO's native controller checkbox and menu layout, so screen resolution and UI scaling are handled by the game rather than fixed screen coordinates. The controller option is only added to the active equipment or universal deconstruction panel, never other crafting menus. ESO's current preferred interface determines which control is available. Changing interface mode resets the controller checkbox.

## Selection rules

The default is unticked, with no saved preference. Manual selection changes, item-category changes, station changes, and crafting reset it. Selection is limited to eligible backpack items accepted by the station; banked, equipped, and player-locked items are excluded. FCO ItemSaver deconstruction protection is respected when available. Other add-on filters/protections are not integrated. Universal crafting-category restrictions are respected. Unlocked valuable, researchable, set, and Armory items can be selected.

ESO's selection limits apply. Partial selection is reported in chat and leaves the checkbox unticked. Process the batch and tick again for the remaining items. The add-on only selects items; the player still initiates and confirms deconstruction.

## Files and installation

Keep all four runtime files together inside `live/AddOns/BackpackDeconSelectAll`:

- BackpackDeconSelectAll.txt
- BackpackDeconSelectAll.lua
- CheckboxAlignmentFix.lua
- ControllerSupport.lua

Replace the installed files and run `/reloadui`.

## Verification

Lua 5.1 mock tests cover the controller Options entry, interface-mode checks, selection after closing Options, unticking, native item locks, FCO protection, selection limits, busy crafting, scene resets, normal stations, universal deconstruction, the shared keyboard selection path, and single/idempotent startup. Actual controller navigation, tooltip wrapping, and placement at different resolutions still require in-game verification. Test first with disposable items and one locked item.

ESO UI sources used:

- https://github.com/esoui/esoui/blob/live/esoui/ingame/crafting/gamepad/zo_craftingoptionsdialog_gamepad.lua
- https://github.com/esoui/esoui/blob/live/esoui/ingame/crafting/gamepad/smithingextraction_gamepad.lua
- https://github.com/esoui/esoui/blob/live/esoui/ingame/crafting/gamepad/universaldeconstructionpanel_gamepad.lua
