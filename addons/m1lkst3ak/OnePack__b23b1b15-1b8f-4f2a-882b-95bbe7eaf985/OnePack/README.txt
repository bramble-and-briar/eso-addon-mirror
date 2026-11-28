ONEPACK 1.0.4 — Trash Man Enterprises
Everything you carry. One place.

PS5 / console first-test build. A standalone inventory and personal-bank replacement extracted from ESO Hardcore 0.9.50. No Hardcore rules, progression, economy modules or required libraries.

INSTALL / TEST
Package uses the same .addon manifest and PS5 API versions as the source build. Install through the supported ESO console add-on workflow. Disable ESO Hardcore's inventory/bank replacement (or disable ESO Hardcore entirely during the first test); OnePack skips automatic interception when Hardcore reports active. Do not run two inventory replacements at once.

Inventory opens when you enter native gamepad inventory. Personal bank opens when you interact with a banker and enter the bank screen. R2 hands control to the original ESO screen. Optional LibRadialMenu entry opens OnePack. /onepack (or /op) toggles it; /onepack bank opens the grid at a banker; /onepack off pauses, /onepack on resumes, /onepack manual disables automatic replacement, /onepack auto re-enables automatic replacement. These switches are session-only.

INVENTORY
D-pad moves around the 60-slot page; moving down past the last row reaches the next page. L1/R1 category; Square sort; Triangle equipment panel; L2 name search; L3 location (all carried, backpack, craft bag); R3 quality; X actions; Circle back; R2 native inventory. Search uses native console keyboard; select text field, enter all or part of a name, then Apply search. Clear search is a separate option. Search results remain limited to active category/location/quality filters. All carried includes backpack and craft bag; equipped gear is visible in the equipment panel and can also appear in a name search or Equipped category. Backpack capacity excludes craft bag. Rows retain their physical bag/slot identity and stack counts.

ITEM ACTIONS
Equip / unequip, use / learn / open container, lock/unlock, split physical stack, enchant, recharge, repair, quickslot, bind, chat link, craft bag stow/retrieve, junk (when API permits), native destruction confirmation. Applicable actions are determined by game predicates. Native improvement and quickslot screens handle compatible items and confirmation. Destruction uses native prompt. Craft bag uses native transfer UI. Split and bank actions use protected string dispatch where required; if a request is blocked, use R2. Do not assume success until the game confirms it.

BANK
L1/R1 category; Square sort; Triangle deposit/withdraw mode; L2 gold transfer; L3 search; X item actions; R2 native bank; Circle back. Whole-stack and partial transfers, split, lock/unlock, chat link, destroy where allowed. Personal and ESO Plus bank supported. Partial transfers use a single compatible stack or empty slot; use native bank for transfers requiring multiple slots. Gold transfer respects game limits. Guild banks, housing storage and quest-item-specific actions remain native.

FIRST PASS TESTS (not yet performed on console)
1. Open native inventory; D-pad, page navigation, close, reopen, R2 fallback.
2. Search a partial name, mixed case, no matches, clear and cancel; repeat in bank.
3. Craft bag view: quantities match native and retrieval/stow opens the correct native prompt.
4. Split an inexpensive stack; verify both quantities. Try full backpack; cancel safely.
5. Enchant inexpensive gear; check compatible glyph list and return. Repeat with recharge and repair.
6. Assign quickslot, equip each weapon bar, unequip, lock/unlock, learn a cheap recipe, open a container, link in chat.
7. Test bank deposit/withdraw (full and partial), stacking, and gold transfer. Leave banker, confirm native menu works.
8. Destroy only a worthless unlocked item after testing Cancel; verify locked item cannot be destroyed.

Validation: Lua syntax and mocked data/search/action-routing tests only. PS5 runtime behavior, protected APIs, native dialogs and controller layer still require in-game verification. Public source reviewed: esoui/esoui gamepadinventory.lua and inventoryslot.lua; UESP API v101050 inventorylist_gamepad.lua; official Dark Brotherhood API notes for BAG_VIRTUAL. API manifest targets inherited from ESO Hardcore 0.9.50, not independently verified against live console build.


1.0.1 PATCH
- Search dialog uses native blockDialogReleaseOnPress; X focuses the console keyboard without releasing the dialog. Apply/Clear/Cancel release explicitly.
- Chat linking now uses native chat-link construction and console-safe StartTextEntry with the fourth argument true; fills chat text without submitting. Technique credited to sirinsidiator / LibSlashCommander (https://www.esoui.com/forums/archive/index.php/t-11323.html). If the HUD input is not visible, open normal text chat. No claim of live PS5 success.
- Item details show armor weight, weapon type and hand count, and all set bonus tiers from the native item-link API. Wider detail panel with paging via X > Next item info page when needed. Applies to bank, backpack, equipped items and craft bag where applicable.
- Retest search X, enter text, Apply, Clear and Cancel in inventory and bank. Link one item; confirm it appears in chat entry and is not auto-sent. Check light/medium/heavy, one-handed/two-handed, shield, 2-piece/5-piece/long set, non-set items and details paging.
- Search flag verified against ESO native parametric dialog examples; set data uses documented GetItemLinkSetInfo/GetItemLinkSetBonusInfo. Console testing still required.

1.0.2 PATCH
- Square cycles through the new TSC / Guild Trader Value sort in inventory and personal bank. Descending estimated total stack value (unit price x quantity). Items without a positive market estimate, including known bound or stolen items, sort last by name. Existing vendor value sort unchanged.
- Item panel displays estimated unit and stack prices, or the reason a price is unavailable. Prices use optional installed TSCPriceDataAPI or TSCPriceDataLite; no Gold Standard dependency, no vendor-price substitution and no mandatory library. Lite prices may be item-ID averages, not exact trait/quality estimates.
- Test with and without TSC installed, multiple stack sizes, bound/stolen items, missing prices, and all bank/inventory filters. Data read once per unique link per market sort scan; refreshed when the grid rescans.
- LibRadialMenu: assign OnePack > Open OnePack in the library's wheel settings. The entry opens inventory (does not toggle it closed), preserves the existing entry ID and retries registration for up to 25 seconds after activation if the library is not ready. If the wheel is disabled, configure its location in LibRadialMenu settings. No required library. Verify wheel assignment and reopening from gameplay on PS5.

1.0.3 PATCH — SAVED GEAR PRESETS
- Triangle opens the Equipped panel; Square opens its Gear presets dropdown. Select a saved preset with X to Load, Overwrite with current equipment, or Delete. Select + Save currently equipped as new preset to name a new setup with the native console keyboard. Circle backs out; D-pad up/down navigates the dropdown. Overwrite, delete and load require confirmation. Delete removes only the preset, never the gear.
- Up to 50 named presets per character, stored with ESO's native saved variables; persistence requires normal game save/logout behavior. Presets cover the 14 armor, jewelry and primary/backup weapon slots displayed in Equipped, including intentional empty slots. Skills, champion points, poisons, cosmetics and Armory settings are not changed. Each item is identified by its unique instance ID, not name. Identical items are not substituted, and items in the bank must be withdrawn manually.
- Preflight verifies all exact items are available and simulates free backpack space. Gear is moved explicitly, one at a time, with source/destination checks and confirmation of each move before proceeding. Some swaps need one or more spare backpack slots. No automatic destruction, unlock, binding, banking or substitution. No load in combat or at the bank. Circle cancels further moves; leaving inventory, combat, failed moves or a timeout also stops the operation. A stopped load may leave a partial setup; correct the issue and load again. Native item moves may be restricted by the console API; PS5 testing is required.
- Test: create two distinct sets; switch between them; test rings in reversed positions, both bars, two-handed vs dual wield, intentional empty slots, duplicate names, missing gear in bank, full backpack, combat, interrupted load, overwrite, delete, and persistence after relog. Verify earlier TSC, radial, search, chat and item detail behavior. No new required dependencies.
- Local validation: Lua syntax; mocked exact instance lookup, ring/bar swaps, intentional empty slots, missing items, full/available backpack, combat rejection, rejected request, timeout, cancellation, duplicate names, overwrite/delete, saved-variable reinitialization. These mocks do not prove native PS5 requests or dialogs work.


1.0.4 PATCH — RADIAL GEAR PRESETS
- In LibRadialMenu settings, select OnePack > Equip: [preset name] and assign it to a wheel slot. Open OnePack remains a separate action. Existing presets register on player activation, new presets register after saving, and overwriting a preset preserves its stable character-specific wheel ID. Existing gear data is migrated in place. Selecting an assigned preset from the HUD loads it directly without opening inventory or showing a confirmation dialog; the explicit radial selection is the confirmation. The Equipped menu retains its confirmation dialog.
- Radial loads share the existing secure move engine, exact-item lookup, backpack-space preflight, combat checks and per-move verification. No gear changes while at the bank, in combat, while paused or outside the gameplay HUD; switching scenes or entering combat stops further moves. No automatic rollback after a partial swap. A deleted preset's old callback is inert; LibRadialMenu only documents registration, so unassign stale slots manually and reload UI if the deleted entry remains in its list. Recreating the same name never reuses its ID. The wheel library is optional.
- Test on console: save two sets, assign both separately, switch directly from gameplay; overwrite and verify existing binding uses new gear; delete and attempt old binding, recreate same name and verify old binding cannot activate it; reload, verify bindings and existing inventory action persist; test combat and missing items. Native protected equipment requests from the HUD still require live PS5 verification.
