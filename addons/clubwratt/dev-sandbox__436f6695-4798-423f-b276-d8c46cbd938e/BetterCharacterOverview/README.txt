Better Character Overview
Version 1.9.0
PS5 Update 50 native-list architecture test


PERFORMANCE AND MEMORY IN 1.9.0
- Investigated reports of the game crashing / the UI force-reloading while
  BCO is enabled. Console add-ons share a ~100 MB Lua memory pool and a
  1-second-per-frame budget; BCO was holding two full copies of the account
  catalog (SavedVariables snapshots plus the aggregate) at roughly 1 KB and
  2 KB per item, and re-aggregating the whole catalog after every inventory
  change. With several characters, a bank, housing storage and a furnished
  house that is tens of MB, so any other menu allocating could tip the pool
  over the limit. The crash is therefore not tied to opening Inventory
  specifically.
- Snapshots are now just { itemLink, count }. Name, icon, quality, type,
  filter data and set name are derived from the link when the aggregate is
  built. Existing SavedVariables are migrated in place on load, so the next
  save shrinks the file.
- The aggregate is built only when All Inventories is opened, and only if a
  snapshot changed since the last build. Looting, banking, crafting and
  zoning no longer rebuild it in the background. When Inventory closes with
  a stale aggregate, the aggregate is released back to the Lua pool.
- The build walks 200 snapshot entries per frame (was 70) and no longer
  re-derives data already stored; the previous aggregate stays on screen
  until the new one is finished instead of showing an empty catalog.
- Source filters (Banked / Characters / Storage / Listed) no longer deep-copy
  every item on every refresh. Each item gets one small cached view per
  filter that reads other fields through to the aggregate item.
- Searching the category list is one pass over the catalog instead of one
  full pass per category.
- Section headers (weapon class, apparel slot, furniture category, native
  category) are computed once per item and cached; the item rows are sorted
  once instead of twice.
- The Preview keybind's visibility check decides from the item link and no
  longer walks every reachable bag (about 1,500 GetItemLink calls) on every
  selection change. Live-slot lookups happen only when a preview is actually
  requested, and a miss is remembered per item.
- The tooltip, currency tooltip, keybind and header settle timers run two
  passes instead of three, and the second tooltip pass only re-lays the
  tooltip when the target row actually changed.
- ESO fires a search-results update on every inventory change even with an
  empty search box; BCO now ignores those unless the search text changed.
- Login scans the current character once (was twice).

REGRESSION TEST FOR 1.9.0
1. /reloadui. Confirm the add-on manager memory readout is lower than 1.8.x
   with the same cataloged data.
2. Open Inventory > All Inventories. First open shows "Building account
   inventory..." briefly, then the category list.
3. Loot or bank something while All Inventories is open; the list refreshes.
   Do the same with Inventory closed; reopening All Inventories rebuilds.
4. Cycle Square through All/Banked/Characters/Storage/Listed on both the
   category and item lists; type a search; confirm categories hide/show.
5. Scroll a Furnishings list: Preview keybind shows for furnishings, preview
   opens and follows the selection, End Preview works.
6. Confirm the Vengeance tab, tooltip scroll and Craft Bag tab still work.


REVERT 1.6.7 PRE-INSTALL IN 1.6.8
- Reverts the 1.6.7 pre-install attempt, which caused a
  "ZO_GamepadInventoryTopLevelMaskContainerCategory Duplicate Name" error.
- Forcing ESO's gamepad Inventory deferred initialization right after player
  activation is not safe: something inside it is not ready that early and errors
  after the native Category list control has already been created but before ESO
  sets its initialized guard. The guarded retry (and the real first show) then
  ran the initialization again and created the Category container a second time.
- This build restores the confirmed-good 1.6.6 behavior exactly (Vengeance tab,
  tooltip scroll, Craft Bag first-open tab). The first Inventory open of a
  session may again need one close/reopen; a safer fix for that is being
  investigated separately.

REGRESSION TEST FOR 1.6.8
1. Use /reloadui after installing.
2. Confirm no Duplicate Name error appears on load or first Inventory open.
3. Confirm the four-tab bar, Vengeance tabbing, and right-stick tooltip
   scrolling all still work.


FIRST-OPEN FIX IN 1.6.7
- Fixes the very first Inventory open of a session showing a blank, inoperable
  screen that only worked after closing and reopening Inventory.
- ESO's gamepad Inventory does not create its native lists and headers until the
  first time the scene shows, so BCO previously had to install during that first
  show (adding its lists, secure hooks, and header tab mid-show), which left the
  first open half-built. BCO now forces ESO's (guarded) deferred initialization
  shortly after player activation and installs while the scene is still hidden,
  so the first open behaves exactly like a reopen.
- Falls back to the previous install-on-first-show path if the pre-install is
  not possible yet, so there is no regression on slower loads.
- No behavioral change to the confirmed 1.6.6 Vengeance tab and tooltip-scroll
  fixes; they are unchanged.

REGRESSION TEST FOR 1.6.7
1. Fully quit to the login screen (or reload) so the session starts cold.
2. Open Inventory for the first time and confirm it is populated and operable
   immediately, with no need to close and reopen.
3. Confirm the four-tab bar, Vengeance tabbing, and right-stick tooltip
   scrolling from 1.6.6 all still work.


VENGEANCE TAB AND TOOLTIP SCROLL INPUT FIX IN 1.6.6
- Fixes the All Inventories tab appearing to be created and deleted while
  tabbing in a Vengeance campaign. BCO only injected its tab into the regular
  Inventory and Craft Bag headers, so the Vengeance inventory showed three tabs
  while the others showed four. The tab is now injected into the Vengeance
  header too, so all three native tabs show a stable four-tab bar, and BCO
  redraws the correct Vengeance header instead of the regular one.
- Fixes right-stick scrolling being dead on long tooltips (for example an item
  set piece whose 2/3/4/5-piece bonuses run off the bottom). The diagnostic
  showed the tooltip was scrollable (canScroll=true, extents>0) but its scroll
  input was disabled. The shared left-tooltip scroll input is used by every
  left tooltip and native inventory never disables it; BCO was disabling it when
  leaving All Inventories and never restoring it, which killed scrolling on the
  native Inventory, Craft Bag, and Vengeance item tooltips too. BCO now restores
  ESO's enabled default when handing control back to a native list and no longer
  leaves the input disabled on empty rows.
- Reverts the 1.6.5 scroll-preserve skip, which could blank the item tooltip
  when a native update tick cleared it. The item tooltip is re-rendered on each
  tick again (which also keeps its scroll input enabled).
- Keeps the 1.6.5 Craft Bag first-open tab fix and the /bcoscroll diagnostic.

REGRESSION TEST FOR 1.6.6
1. Use /reloadui after installing.
2. In a Vengeance campaign, open Inventory and tab across Vengeance, Inventory,
   and Craft Bag; confirm all three show four tabs (including All Inventories)
   with no flicker of a tab being added or removed.
3. Highlight an item set piece in All Inventories and scroll the tooltip down
   with the right stick to reveal the 5-piece bonus.
4. Switch to the native Inventory item list, highlight a long set-piece tooltip,
   and confirm the right stick scrolls it there too.
5. If scrolling still fails, highlight the item and run /bcoscroll, then report
   the printed line (input should read true).


CRAFT BAG FIRST-OPEN AND TOOLTIP SCROLL FIX IN 1.6.5
- Reverts the ineffective 1.6.4 attempts, which re-activated the tooltip scroll
  input after the current native list had already switched and only re-matched
  the header pip to whatever list was active, so neither issue changed.
- Fixes Inventory opening on the Craft Bag tab after visiting All Inventories.
  ESO's tab bar remembers the previously selected tab index and, on the next
  open, clamps it down to the number of native tabs. Because All Inventories is
  the last tab, that clamp landed on Craft Bag and fired its callback, switching
  the freshly opened Inventory to the Craft Bag list. BCO now resets the
  remembered tab index to the native Inventory tab while the scene hides, so the
  next open lands on Inventory and the All Inventories resume runs cleanly.
- Improves right-stick scrolling of long All Inventories item tooltips (for
  example an item set piece whose 2/3/4/5-piece bonuses run off the bottom).
  Incidental native update ticks re-laid-out the tooltip and reset the scroll
  position to the top; BCO now keeps the scroll position when the highlighted
  item has not changed.
- Adds a /bcoscroll diagnostic command that prints the left tooltip's live
  scroll state (hidden, input, canScroll, extents, heights) to help pinpoint any
  remaining scroll issue while a long set tooltip is highlighted.
- Keeps all 1.6.3 header-alignment, 1.6.2 tooltip-scroll, 1.6.1 reopen, 1.6.0
  Use/Equip, and 1.5.9 item-name behavior unchanged.

REGRESSION TEST FOR 1.6.5
1. Use /reloadui after installing.
2. Open All Inventories, close Inventory, reopen it, and confirm Inventory does
   not jump to the Craft Bag list.
3. Switch to native Craft Bag, close and reopen Inventory, and confirm Craft Bag
   still reopens on Craft Bag (native behavior is preserved).
4. In All Inventories open a category, highlight an item set piece, and scroll
   the tooltip down with the right stick to reveal the 5-piece set bonus.
5. If scrolling still does not work, highlight the set piece and run /bcoscroll,
   then report the printed line.


HEADER TAB ALIGNMENT FIX IN 1.6.3
- Fixes the All Inventories title appearing mixed with letters from another Inventory tab after closing and reopening Inventory from All Inventories.
- Fixes the divider pip temporarily remaining on the middle native tab even though All Inventories is active.
- Re-selects the existing All Inventories tab after every BCO category-header rebuild using ESO's native GenericHeader tab-index function with callbacks blocked.
- Handles native header redraws that finish after the scene-resume callback without changing list, tooltip, search, preview, use, or equip behavior.
- Keeps the 1.6.2 tooltip-scroll fix, 1.6.1 scene-reopen fix, 1.6.0 Use/Equip isolation, and 1.5.9 item-name formatting fix unchanged.

REGRESSION TEST FOR 1.6.3
1. Use /reloadui after installing.
2. Open All Inventories and close Inventory completely while its category page is active.
3. Reopen Inventory and confirm the title is clean and the rightmost All Inventories pip is selected immediately.
4. Repeat from an opened All Inventories item category.
5. Switch through Inventory, Craft Bag, and All Inventories with L1/R1 and verify all three titles and pips remain aligned.
6. Re-test Inventory reopening, ordinary tooltip scrolling, and native use/equip actions.


ITEM TOOLTIP SCROLL FIX IN 1.6.2
- Restores right-stick scrolling for ordinary item tooltips inside All Inventories.
- Explicitly enables ESO's native left-tooltip input after each BCO item-link tooltip is laid out.
- Fixes the input state remaining disabled after visiting the category page, closing Inventory, or collapsing the expanded Item Locations view.
- Disables tooltip input when no valid item row exists so input is not left attached to an empty tooltip.
- Keeps the 1.6.1 scene-reopen fix, the 1.6.0 native Use/Equip isolation, and the 1.5.9 ^n/^p item-name formatting fix unchanged.

REGRESSION TEST FOR 1.6.2
1. Use /reloadui after installing.
2. Open All Inventories and enter a category containing an item with a long tooltip.
3. Scroll the item tooltip with the right stick.
4. Back out to categories, enter the item list again, and confirm scrolling still works.
5. Close and reopen Inventory, return to the item list, and confirm scrolling still works.
6. Expand and collapse Item Locations, then verify the normal item tooltip still scrolls.
7. Re-test native Inventory use/equip actions and the All Inventories reopen path.


INVENTORY REOPEN FIX IN 1.6.1
- Fixes All Inventories reopening with its header visible but the list completely empty after closing and reopening Inventory.
- Normalizes ESO's remembered previousListType to the native categoryList descriptor while the Inventory scene hides.
- Lets ESO securely activate its normal category list first when the scene reopens, then restores the All Inventories category list on the next UI tick.
- Handles both SCENE_HIDING and SCENE_HIDDEN callback ordering used by different console UI builds.
- Does not force All Inventories to reopen when Inventory was closed from a native Inventory or Craft Bag tab.
- Keeps the 1.6.0 native Use/Equip isolation and the 1.5.9 ^n/^p item-name formatting fix unchanged.

REGRESSION TEST FOR 1.6.1
1. Use /reloadui after installing.
2. Open All Inventories, then close Inventory completely.
3. Reopen Inventory; All Inventories should repopulate instead of showing an empty panel.
4. Repeat from both the category page and an opened item category.
5. Switch to native Inventory and Craft Bag, close and reopen, and confirm both native tabs still work.
6. Re-test using a consumable and equipping a weapon, armor piece, and jewelry item.

NATIVE USE/EQUIP UI-ERROR FIX IN 1.6.0
- Removes every direct replacement of ESO's native gamepad Inventory methods.
- Uses SecurePostHook for native list switching, header refreshes, search updates, and tooltip recovery so ESO builds Use/Equip/Move callbacks in its protected execution context.
- Keeps BCO snapshot rows out of GAMEPAD_INVENTORY.currentlySelectedData because native inventory, currency, death, and reincarnation events can feed that field into the live item-action controller.
- Holds BCO in ESO's category/read-only action mode and clears pending item-action refreshes while either custom list is active.
- Preserves native tooltips after switching back to Inventory or Craft Bag.
- Keeps the 1.5.9 ^n/^p item-name formatting fix unchanged.

REGRESSION TEST FOR 1.6.0
1. Install the three files and use /reloadui.
2. Open Inventory, enter All Inventories, open several categories, use search, and cycle the Square source filter.
3. Switch back to the native Inventory and use a container or consumable.
4. Equip and unequip a weapon, armor piece, and jewelry item, including an item that previously raised the UI error.
5. Repeat the use/equip tests after visiting Craft Bag and All Inventories several times.
6. Run /bcostatus; Hooks H/S should report true/true and Search should name the hooked search callback.

ITEM-NAME FORMATTING FIX IN 1.5.9
- Resolves ESO localization grammar markers such as ^p and ^n before item names are displayed.
- Uses the same SI_TOOLTIP_ITEM_NAME formatter as ESO's native inventory and equipment screens.
- Formats legacy saved snapshot names while rebuilding the account index, so a fresh rescan is not required.
- Keeps item links, aggregation keys, tooltips, and furnishing preview behavior unchanged.

FURNISHING PREVIEW POLISH IN 1.5.8
- Opens live and snapshot-only furnishings through the same shared item-link preview type from the first model.
- Removes the one-time inventory-slot to item-link handoff that could flash on the first scroll for current-character, Bank, and Furnishing Vault items.
- Keeps native bag-slot previewing only as a compatibility fallback when the console rejects item-link previewing.
- Preserves seamless other-character previews and the existing 90 ms held-scroll settle window.

FURNISHING PREVIEW POLISH IN 1.5.7
- Uses the seamless item-link replacement path for every active furnishing preview, including current-character, Bank, housing-storage, and Furnishing Vault items.
- Keeps ESO's native live-slot method only for opening the first preview scene and as a compatibility fallback.
- Avoids PreviewInventoryItem during normal scrolling because the live-slot replacement path briefly exposes the character model on PS5.
- Preserves working other-character item-link previews and the 90 ms held-scroll settle window.

FURNISHING PREVIEW POLISH IN 1.5.6
- Fixes the eligibility test for furnishings stored only on another character by accepting ESO's generic item-link preview validator when needed.
- Uses the shared item-link preview entry point when the current gamepad build exposes it, with a low-level fallback and confirmation retry.
- Replaces active live previews through one pending-collection commit instead of rerunning the full shared preview setup for every selected row.
- Adds a 90 ms selection settle window and matching native buffer so held-stick scrolling skips intermediate model loads and keeps the previous furnishing visible.

FURNISHING PREVIEW POLISH IN 1.5.5
- Uses ESO's shared preview-target buffer while preview mode is active.
- Keeps the current furnishing rendered until the next selected furnishing is applied.
- Coalesces rapid gamepad scrolling without briefly exposing the character model.
- Restores ESO's default preview-buffer behavior when preview mode ends.

FURNISHING PREVIEW POLISH IN 1.5.4
- Removed the custom target-change debounce that lengthened preview swaps.
- Active previews now replace the target through ESO's shared preview object without clearing the shown collection first.
- Snapshot-only furnishings can use ESO's item-link furniture preview path when no live bag slot is loaded.
- The first row is assigned after ESO installs the keybind group, because that installation clears selected inventory data.

This build is based on live PS5 diagnostics.

Unlike the earlier versions, it does not replace or reuse ESO's live
categoryList, itemList, or craftBagList. It registers two dedicated native
parametric lists through GAMEPAD_INVENTORY:AddList:

- BCOCategory
- BCOItems

The third Inventory tab activates those lists directly. Saved offline items
remain read-only and are never passed into ESO's live bag-slot action system.

FEATURES IN THIS TEST

- Persistent third Inventory tab
- Dedicated native category list
- Dedicated native item list
- Account-wide item aggregation
- Character backpack, equipped, Bank, housing storage, and Furnishing Vault locations
- Square-button source filter: All, Banked, Characters, and Storage
- Scrollable cross-character Currencies overview with Total and Banked values
- Native item-link tooltip
- Native hold-to-preview support for furnishing item links
- Chunked account indexing
- Automatic character snapshot updates

TEST ORDER

1. Install and use /reloadui.
2. Open Inventory.
3. Move Inventory -> Craft Bag -> All Inventories.
4. Select a category.
5. Back out to categories.
6. Move back to Inventory and Craft Bag.
7. Close and reopen Inventory.

COMMANDS

/bco
Open All Inventories directly.

/bcorescan
Rescan the current character.

/bcoclear
Delete all saved inventory snapshots.

/bcopreviewstatus
Report the selected furnishing preview path and Update 50 API availability for troubleshooting.


Version 1.4.25:
- Adds ESO's native hold-to-preview action for previewable furnishing items in
  All Inventories.
- Uses item-link previewing so furniture saved in banks, other characters,
  housing storage, and the Furnishing Vault can be previewed remotely.
- Shows the preview keybind only for previewable furnishings, changes it to
  End Preview while active, and closes preview when leaving the item list.
- Moving between previewable furnishing rows refreshes the active preview.

Version 1.4.23:
- Fixes the console currency overview silently falling back to a plain
  title-and-description text block.
- Resolves the actual ZO_Tooltip object inside the PS5 scroll-tooltip wrapper
  before creating native currency sections.
- Restores ESO's currency stat/value pairs: smaller off-white labels on the
  left and white, right-aligned amounts and icons on the right.
- Uses ESO's native white amount-and-icon currency formatter.


Version 1.4.22:
- Rebuilds the cross-character currency tooltip with ESO's dedicated
  gamepad currency sections and stat/value row styles.
- Uses the native smaller currency fonts.
- Shows section names and currency labels in ESO's off-white color.
- Shows values and icons in white.
- Keeps currency names left-aligned and values right-aligned.
- Uses each saved character's actual name as its section heading.


Version 1.3.2:
- Fixes the third tab not appearing after successful list registration.
- Ensures the third entry exists immediately before ESO performs its own
  native RefreshHeader operation.
- Does not replace RefreshHeader and does not trigger a second refresh.
- Reapplies the entry when the Inventory scene is shown if ESO rebuilt either
  native header-data table.


Version 1.3.3:
- Fixes the third tab still showing only two pips.
- Removes the separate pre-hook that was accidentally overwritten later.
- Reattaches the stable third tab directly inside the single RefreshHeader
  wrapper, immediately before ESO performs its normal native refresh.
- Performs one safe blocked-callback refresh when installation finishes while
  the Inventory scene is already open.


Version 1.3.4:
- Fixes installation occurring before the PS5 Inventory finishes deferred
  initialization.
- Waits until the Inventory scene is actually opened.
- Retries list registration at 0, 50, 250, 500, and 1000 ms after the scene
  begins showing.
- No longer gives up after 15 seconds while the player remains in the world.
- Adds /bcostatus to report the exact missing Inventory object if registration
  still cannot complete.


Version 1.3.5:
- Keeps the successfully registered BCOCategory and BCOItems lists.
- Redraws the live gamepad header after ESO finishes a native Inventory or
  Craft Bag switch.
- Uses ZO_GamepadGenericHeader_Refresh with tab callbacks blocked.
- Retries the redraw at 0, 50, and 250 ms to run after the native callback
  stack has completed.
- Adds category, Craft Bag, and active-header tab counts to /bcostatus.


Version 1.3.6:
- Fixes the UI error when opening a category while Dolgubon's Lazy Writ
  Crafter is enabled.
- Removes the synthetic text value previously stored in uniqueId.
- Marks Better Character Overview rows with overrideStatusIndicatorIcons so
  third-party live-inventory status hooks skip these offline, read-only rows.
- Applies the same protection to both category and item entries.


Version 1.3.7:
- Fixes the ipairs(boolean) UI error when All Inventories opens.
- overrideStatusIndicatorIcons is now an empty table, as required by ESO's
  native gamepad row setup.
- Keeps compatibility protection for Lazy Writ Crafter without assigning a
  fake live-item uniqueId.
- Allows category Commit() to finish so BCO can apply its Select/Back
  keybinds and display the saved category data.


Version 1.3.8:
- Displays native item-link details on GAMEPAD_LEFT_TOOLTIP, matching ESO's
  normal item-list layout.
- Updates the tooltip after the BCO item list becomes active and whenever the
  highlighted item changes.
- Stores each item's native filter type when a character is scanned.
- Uses ITEMFILTERTYPE_QUICKSLOT for Slottable Items and
  ITEMFILTERTYPE_CRAFTING for Crafting Materials.
- Moves food, drinks, potions, poisons, siege items, and repair items into
  Slottable Items, including fallback support for older saved snapshots.
- Makes Supplies the catch-all for non-equipment items that do not belong to a
  more specific category.


Version 1.3.9:
- Prevents ESO's native UpdateItemLeftTooltip path from clearing BCO's
  item-link tooltip after it is rendered.
- Synchronizes currentlySelectedData without invoking the live bag-slot action
  controller.
- Captures every value returned by GetItemLinkFilterTypeInfo instead of only
  the first filter type.
- Rebuilds filter data directly from saved item links, so old character
  snapshots are corrected without requiring every character to be rescanned.
- Adds the native Companion Items category.
- Makes Supplies follow ESO's native non-equipment catch-all rules.
- Keeps Miscellaneous only for items that match none of the known categories.


Version 1.4.0:
- Uses the gamepad LayoutItemWithStackCount item-link path for offline items.
- Adds direct tooltip-control fallbacks for the PS5 UI.
- Redraws item information at 0, 50, and 200 ms after selection so later
  native callbacks cannot immediately clear it.
- Scans the current character synchronously during player deactivation.
- Scans again at 300 ms and 1500 ms after character activation.
- Rebuilds the combined account index after every character scan, even when
  All Inventories is not currently open.
- Adds /bcosnapshots to list every saved character and its stored item counts.

ESO-style subsection headers are intentionally deferred until tooltip display
and cross-character persistence are confirmed stable.


Version 1.4.1:
- Adds the required manifest declaration:
  SavedVariables: BetterCharacterOverviewSavedVariables
- Fixes character snapshots disappearing when switching characters,
  reloading the UI, or restarting ESO.
- Keeps the existing account-wide saved-variable structure and version.
- Characters scanned before this fix must be logged into once again because
  their earlier snapshots were never written to persistent storage.


Version 1.4.3:
- Rebuilt from the stable 1.4.1 code.
- Removes the unsafe PS5 search-control OnTextChanged hook from 1.4.2.
- Prevents the failed partial installation and duplicate BCO list controls.
- Uses only ESO's existing OnUpdateSearchResults inventory callback.
- Filters All Inventories by item name, set name, and storage location.
- Supports multiple search words.
- Filters both the category page and the selected category's item page.
- Does not alter native Inventory or Craft Bag search behavior.


Version 1.4.4:
- Corrected category icons to match ESO's native gamepad Inventory.
- Supplies now uses ESO's bag icon.
- Crafting Materials now uses ESO's hammer-and-materials icon.
- Furnishings now uses ESO's native furnishing-chair icon.
- Miscellaneous now uses ESO's proper miscellaneous inventory icon.
- Kept the already-correct Slottable Items, Companion Items, Quest Items, Weapons, and Apparel icons.
- Preserves the working 1.4.3 search system unchanged.


Version 1.4.5:
- Renamed the All Inventories category "Crafting Materials" to "Materials"
  so it matches ESO's normal Inventory category name.
- No search, tooltip, icon, or saved-inventory behavior was changed.


Version 1.4.6:
- Item names in All Inventories now use their ESO display-quality color.
- The list color now matches the rarity shown in the item tooltip.
- Existing saved item links are re-evaluated for display quality, so players
  do not need to revisit every character before the colors can appear.
- Item icons, search, tooltips, categories, and saved inventory data are
  otherwise unchanged.


Version 1.4.7:
- Added ESO-style subsection headers inside All Inventories item lists.
- Item sections now try to use ESO's own gamepad category-description logic
  first, so headers follow the native inventory layout as closely as possible.
- Added a fallback to localized item-type names when ESO's helper does not
  return a section name for a saved item.
- Existing rarity colors, icons, tooltips, search, and saved inventory data
  remain unchanged.


Version 1.4.8:
- Fixed subsection headers being allocated but not rendered.
- Header rows now use ESO's native SetHeader plus WithHeader template path.
- Weapon subsections now mirror the current ESO gamepad groupings, including
  One-Handed Melee, Two-Handed Melee, Destruction Staff, Restoration Staff,
  and Bow.
- Non-weapon sections use ESO's native gamepad item-category utility, which
  provides names such as Trophy, Potion, Soul Gem, and crafting disciplines.
- Apparel and Companion Items are grouped by equipment slot (Head, Shoulders,
  Chest, Hands, Waist, Legs, Feet, Neck, and Ring), because ESO's normal
  Inventory separates those items before reaching its item list.

Version 1.4.10:
- Rebuilt strictly from the stable 1.4.8 codebase.
- Restores the corrected category icons and the Materials category name.
- Restores rarity-colored item names and visible ESO-style subsection headers.
- Preserves the working search, tooltips, and cross-character saved inventories.
- Reapplies only the cosmetic Item Locations layout from 1.4.9, listing each
  storage location on its own row beneath ITEM LOCATIONS and above the native
  tooltip separator.


Version 1.4.11:
- All Inventories now ignores every item stored in the account-wide Craft Bag.
- Craft Bag items are no longer scanned, indexed, searched, categorized, or shown as item locations.
- Previously cached Craft Bag snapshot data is removed automatically when the add-on loads.
- ESO's normal Craft Bag tab remains completely unchanged and continues to show all Craft Bag materials.
- All stable 1.4.8/1.4.10 features remain unchanged.

Version 1.4.12:
- Rebuilt directly from the stable 1.4.11 source.
- Item Locations now reserves a fixed-height collapsed area so additional
  characters no longer push the item tooltip upward.
- Collapsed locations are prioritized as Bank, current character, largest
  remaining quantity, then alphabetical.
- Up to three exact locations are shown, followed by a summary such as
  "4 OTHER LOCATIONS  x143" containing the hidden location count and total.
- Triangle toggles a full Item Locations view without losing any location.
- The expanded view replaces the item tooltip and supports right-stick
  scrolling through the standard gamepad tooltip input.
- Selecting another item, changing category, changing tab, or closing the
  Inventory automatically restores the collapsed view.
- Craft Bag exclusion, rarity colors, category icons, search, subsections,
  and all other stable 1.4.11 behavior remain unchanged.

Version 1.4.13:
- Adjusts the fixed Item Locations area one row lower by reducing its reserved
  body from four rows to three.
- The collapsed view now shows up to two exact locations, followed by one
  summary row when additional locations exist.
- Triangle still opens the complete scrollable location list, so no location
  information is removed.
- All other 1.4.12 behavior remains unchanged.


Version 1.4.14:
- Adds a Square-button inventory-source filter to both the category and item lists.
- The filter cycles through All Inventories, Banked Items, and Backpacked Items.
- Backpacked Items includes every saved character backpack but excludes equipped gear.
- Equipped items remain available in All Inventories.
- Item stack counts, search results, and Item Locations are limited to the active source.
- The active source remains selected while navigating between categories and items.
- No custom binding or PC-only input API is used; the filter uses ESO's native
  UI_SHORTCUT_SECONDARY gamepad keybind descriptor.

Version 1.4.15:
- Changes the third Square-button source to Character Items.
- Character Items includes both backpack and equipped locations for every saved character.
- Bank locations remain excluded from Character Items.
- The filter cycle is now All, Banked, Character Items, then back to All.

Version 1.4.16:
- Shortens the Square-button labels to All, Banked, and Characters.
- Removes the redundant "Filter:" prefix without changing filter behavior.


Version 1.4.17:
- The All Inventories category overview keeps the ALL INVENTORIES header.
- Opening a category now changes the header to that category name, matching
  ESO's normal gamepad Inventory behavior.
- The selected category title is saved before switching to the item list,
  avoiding a PS5 issue where the inactive category list can lose its target.
- Source filtering, item locations, tooltips, and all other behavior remain unchanged.


Version 1.4.18:
- Adds account-wide snapshots for housing storage chests and coffers.
- Adds Furnishing Vault snapshots using ESO's native bag-slot iterator.
- Square now cycles All, Banked, Characters, and Storage.
- Storage remains separate from the normal Banked filter.
- Each housing container or Furnishing Vault must be opened once before its
  contents can appear remotely in All Inventories.
- Item Locations uses the container nickname when available, otherwise the
  collectible name or a safe housing-storage fallback.
- Duplicate container names are disambiguated without merging their counts.
- Live changes to the currently open bank, housing storage container, or
  Furnishing Vault update the saved snapshot and rebuild the account index.
- Craft Bag remains excluded.


Version 1.4.19:
- Adds a native-style Currencies entry to the All Inventories category page.
- Highlighting Currencies shows a scrollable tooltip instead of opening an item list.
- Shows Total, Banked, and every saved character for Gold, Alliance Points,
  Tel Var Stones, and Writ Vouchers.
- Account-wide currencies are intentionally excluded because their values are
  identical for every character and add no cross-character information.
- Currency values update on login and currency-change events.
- Characters not logged into since this update are marked NOT SCANNED, and
  totals are labeled KNOWN TOTAL until every saved character has been updated.
- Square filtering and Select are hidden while the Currencies row is selected.


Version 1.4.20:
- Reorganizes the Currencies tooltip by owner rather than by currency.
- Sections now appear as Total, Banked, then each saved character.
- Gold, Alliance Points, Tel Var Stones, and Writ Vouchers are listed
  underneath every section in the same order.
- Total includes banked values plus every scanned character.
- Unscanned characters retain four NOT SCANNED rows, and a note explains
  that Total remains incomplete until those characters are visited.
- Account-wide currencies remain intentionally excluded.

Version 1.4.21:
- Restyles the cross-character Currencies tooltip with ESO's native gamepad
  tooltip sections, fonts, colors, spacing, right-aligned values, and currency
  icons.
- Uses the normal Inventory status-label title instead of a plain-text title
  inside the tooltip body.
- Displays each saved character's actual name as its currency section header.
- Keeps the previous plain-text layout as a compatibility fallback.

Version 1.4.22:
- Refines the custom Currencies overview to use smaller gamepad currency fonts,
  sandy labels and headers, white values and icons, and fixed left/right columns.

Version 1.4.23:
- Resolves the actual tooltip object inside ESO's scroll wrapper so the native
  currency section styles render correctly on PS5 instead of falling back to
  plain text.
- Uses native right-aligned white currency values and icons while retaining
  sandy left-aligned labels and section headings.

Version 1.4.24:
- Restores the standard gamepad tooltip background behind the custom Currencies
  overview.
- Removes the explanatory scan-status text from the bottom of the currency
  tooltip.
- Keeps the successful native fonts, colors, icons, alignment, sections, and
  right-stick scrolling unchanged.

Version 1.4.26
- Fixed furnishing preview by using ESO's native live bag/slot preview path whenever the item is currently accessible.
- Retained item-link preview as a fallback for furnishings saved in remote inventories.
- Moved the furnishing Preview / End Preview prompt to ESO's native centered keybind-strip position.
- Prevented the prompt from reporting End Preview when ESO did not actually open a preview.
VERSION 1.4.27

- Centers the furnishing Preview / End Preview prompt in the keybind strip.
- Uses only ESO's native live bag-slot furnishing preview path.
- Checks all currently exposed character, bank, housing storage, and Furnishing Vault bags.
- Hides Preview for snapshot-only furnishings that ESO cannot currently expose as a previewable slot.
- Removes the nonfunctional item-link fallback that could show Preview without opening a model.


VERSION 1.5.3

FURNISHING PREVIEW POLISH
- Preserves the user-requested 1.5.3 release number.
- Makes the first selected furnishing available to the Preview keybind before
  the gamepad list finishes its first target callback.
- Coalesces rapid selection callbacks so an active furnishing preview changes
  only once for the final selected row, reducing the character-model flash
  between furnishings.
- Keeps End Preview active through ESO's one-frame collection replacement.

- Refreshes the furnishing Preview keybind after the first item-list target is fully active, so the first previewable furnishing no longer loses its button.
- Removes the duplicate preview-collection clear that caused the character to flash briefly between furniture selections.
- Resolves each selected furnishing's live slot once instead of scanning every accessible bag twice while preview mode is active.
- Avoids restarting the preview when duplicate selection callbacks refer to the same bag slot.
