# MountSwap 0.8.11

Author: ShadowStrikerr

ESO desktop addon with four Multi-Rider favorites, four Single-Rider favorites, a searchable pop-up picker, and random mount selection. Earlier Windows keyboard/mouse functionality was user-tested. Mac compatibility is unverified. PC gamepad navigation was confirmed working by the author in 0.8.6; 0.8.7 changes author metadata, optional-dependency declarations, documentation and direction-hint grouping and native Escape/menu routing. This is not a console release. No ShowMount source/assets or bundled third-party libraries. Optional LibAddonMenu-2.0 r43+ provides the keyboard settings panel.

Dependencies: no required libraries. Optional manifest entries are `LibAddonMenu-2.0`, `libAddonKeybinds`, and `VotansKeybinder`. Optional entries control load order and do not enforce numeric minimum versions. LibAddonMenu-2.0 r43 (AddOnVersion 43), by Seerah, sirinsidiator and contributors, is the tested/recommended library for the keyboard settings panel. libAddonKeybinds (AddOnVersion 6), by merlight, Baertram and votan, is a separate optional keybinding-panel addon, also marked as a library in its manifest. Votan's Keybinder by votan is an optional search integration with no inspected numeric AddOnVersion. These are not bundled. Optional references are resolved when used and absence is covered by fallback tests. See CREDITS.txt for full attribution.

## Installation

Exit ESO and extract the ZIP into your active AddOns directory, usually `Documents\Elder Scrolls Online\live\AddOns`. Check for `AddOns\MountSwap\MountSwap.txt` without an extra folder level. Replace earlier MountSwap files and disable the SteadyMount prototype. Enable MountSwap in game.

API 101051 is declared, matching the public esoui/esoui live documentation retrieved during development. Compatibility with your installed game still needs verification. Use ESO's out-of-date addon option for testing if needed and available.

## Choosing favorites

1. Type `/mountswap`. The main window contains M1–M4 (Multi-Rider) and S1–S4 (Single-Rider).
2. Click a favorite slot. A pop-up shows only unlocked mounts of that slot's type, sorted A–Z ignoring capitalization from first display.
3. Browse with the **mouse wheel** or drag the **vertical scrollbar** on the right. Eight rows are visible at a time; additional rows are virtualized without creating a control for every mount. The scrollbar hides when eight or fewer results remain.
4. Search by name to narrow the list. Search is case-insensitive and treats punctuation literally. Changing search resets scrolling to the top. Each newly opened picker starts with a fresh search and scroll position.
5. Click a mount to save it and close the picker. This does not activate or summon the mount. Cancel/X leaves the favorite unchanged. Clear slot explicitly removes the saved favorite and closes.
6. Click Use or press your assigned favorite hotkey to select the saved mount. Press your normal mount key to ride. ESO may reject switches during combat, cooldowns or restricted situations; protected actions are not bypassed.

The main window is blocked/dimmed while the picker is open. Closing the main window also closes the picker. Escape in the search field cancels the picker; ESO's general Escape handling can dismiss the registered top-level windows. Actual input routing and rendering need an in-game check.

## Mount grouping and category management

MountSwap first discovers the actual Multi-Rider Collections subcategory through known multi-rider collectible IDs, regardless of the game or interface language. Locked reference mounts need not be owned. Members of that subcategory are Multi-Rider; mounts in its sibling mount subcategories are Single-Rider. Multi membership takes priority if a mount appears in multiple categories. Official categories override old guesses or manual classifications.

If reference metadata and the legacy English category fallback are unavailable, MountSwap falls back to saved choices, observed riding status and explicit English wording. It does not silently assume that missing multi-rider wording means one seat. Remaining mounts need review.

**Manage mount categories** opens a separate searchable, scrollable browser of all unlocked mounts, labeled Multi, Single or Review. Clicking a row there selects it for classification and does not change any favorite. Multi-Rider, Single-Rider and Automatic buttons manage fallback classifications. Official ESO category membership cannot be overridden. Classification choices persist by collectible ID.

Riding observation uses GetTargetMountedStateInfo with your character name while riding as the driver; this fallback still needs in-game validation. Standing on foot or riding as a passenger does not supply a classification. Unknown mounts still go to Review if category metadata and the existing fallbacks are unavailable.

## Commands and hotkeys

- `/ms`: open/toggle MountSwap (or settings in settings-only mode).
- `/m1`–`/m4`: select M1–M4; `/s1`–`/s4`: select S1–S4.
- Customize these nine shortcuts in **Settings → Addons → MountSwap → Chat command shortcuts**. Press Enter or leave a field to apply immediately. Commands are case-insensitive; a leading `/` is optional when entering a command. Use a letter followed by letters, numbers or underscores, up to 24 characters. Leave a field blank to disable that shortcut. Changes save in the existing account/server profile.
- Duplicate shortcuts, original MountSwap commands, registered ESO/addon commands and chat channel switches are rejected. Invalid edits leave the previous shortcut intact and explain the problem in chat, even when normal chat messages are disabled. Conflicting saved shortcuts are skipped and shown in settings; originals remain usable. Checks run again on first player activation and when settings open. An addon registering commands later can still take a shortcut; MountSwap does not overwrite it when checking again.
- **Reset command shortcuts to defaults** restores `/ms`, `/m1`–`/m4` and `/s1`–`/s4`. If any default is in use by ESO or another addon, the entire reset is cancelled, preserving custom shortcuts. To swap two shortcuts, clear one field first. `/ms` also accepts the same arguments as `/mountswap`, such as `settings` and `debug`.
- All original commands below remain available regardless of shortcut changes.
- `/mountswap`: toggle main window.
- `/mountswap1`–`/mountswap4`: select M1–M4.
- `/mountswap5`–`/mountswap8`: select S1–S4.
- `/mountswapr`: choose another usable unlocked mount randomly from the entire collection, excluding the active one. Random ignores picker filters and includes unclassified mounts.
- `/mountswap save 1`–`/mountswap save 8`: save the currently selected mount in a matching favorite slot.

Controls → Keybindings contains separate MountSwap categories for Multi-Rider Favorites, Single-Rider Favorites and General (random/open selector). General also has a separate **Open MountSwap (controller)** action. **No default keys are assigned or overwritten.** Existing action IDs are preserved. Assign your own keys.

## PC controller support (0.8.0)

Enable ESO's gamepad preferred mode and assign **Open MountSwap (controller)** under MountSwap - General, or open with `/ms`. Existing keyboard/mouse buttons, commands and keybinding actions continue to work. This is PC gamepad support, not a console release.

- D-pad moves a cyan focus outline. Select activates the focused control; Back closes the current picker/menu before the dashboard. Details opens a scrollable description of the focused mount or control.
- Dashboard: focus a favorite and use the Secondary action to select its saved mount, or Select to choose a replacement. Shoulders switch between corresponding Multi-Rider and Single-Rider favorite rows. ESO's normal mount key is still needed to ride.
- Picker: D-pad traverses all results, scrolling at row boundaries. Triggers page by eight results. Secondary starts Search; Options opens Search, Clear search and (for favorites) Clear favorite. Category management's Multi-Rider, Single-Rider and Automatic buttons remain navigable.
- Options on the dashboard, its Settings button, or `/mountswap settings` opens a controller settings menu. It reuses the same option definitions, callbacks and saved preferences as the keyboard LibAddonMenu panel. It works without LibAddonMenu. Select changes an option; Secondary uses the favorite or opens the enabled dashboard where applicable. Triggers page settings lists. Keyboard settings-only mode still requires LibAddonMenu; controller settings-only mode does not.
- Hints inherit ESO's existing UI bindings and use native button textures (including modifiers), rather than fixed Xbox letters. Unbound actions and missing native icon helpers are labelled clearly. Hint/setting text wraps and its height is measured. **Controller text size** offers Normal, Large and Extra Large; windows fit within the available screen.
- Search and shortcut editing use ESO edit controls and native gamepad focus/virtual-keyboard helpers when available. Navigation is suspended during text entry. Keyboard fallback remains available; Enter saves a settings edit and Escape cancels. Native completion/focus loss also saves; closing the addon cancels an unfinished settings edit.
- Controller input is active only while a MountSwap window is open in gamepad preferred mode and no text control has focus. It is released on close, text focus, and input-mode changes. No repeating update/polling loop is used. Scene-managed top-level windows let ESO acquire the keyboard mouse cursor and preserve other panels' cursor/UI needs on close.

PC virtual-keyboard availability and native controller artwork depend on ESO and the current input configuration. A later addon can still replace a short slash command; original `/mountswap` commands remain available. Controller hardware/rendering tests have not been performed for 0.8.0. See `Controller-Test-Checklist.txt`.

## Saved data and safe installation

Exit ESO before replacing addon files so current SavedVariables are flushed. Back up `live/SavedVariables/MountSwap.lua` (and any corresponding backup file) to a private location outside the release folder before installing. Never distribute that personal file. Extract only the `MountSwap` folder into `live/AddOns` and preserve `live/SavedVariables`.

Version 0.8.0 keeps the `MountSwapSavedVariables` name, schema version 1, account-wide/server profiles, favorite layout, legacy assignments, classifications and shortcut preferences. The only new saved preference is optional `controllerTextSize`; absent values use Normal. No history or profiles are reset or rekeyed.

Version 0.8.1 preserves that same saved-data identity and behavior. Its local-reference cleanup does not establish any measured FPS improvement. The startup addon-name handler and shortcut check unregister after use; navigation releases its input layer during player deactivation and resumes only when a relevant window and input mode permit. Session-lived mode/binding events and UI callbacks remain intentional. No frequent combat/effect/inventory event subscriptions need filters, and there is no repeating polling loop. Full live global/lifecycle behavior remains unverified beyond source review and automated coverage.

Favorites and classifications are shared between characters on the same account and server. PC-NA and PC-EU have separate saved profiles, selected automatically with GetWorldName(). The same addon ZIP is used on both. Each server scans its own unlocked collection. Earlier shared prototype settings are copied once into each server profile, importing favorite slots only when their mounts are unlocked on that server; the old settings remain intact. Upgrades from the old four-slot layout move recognized mounts into their matching banks in old slot order, retaining the original assignments as legacySlots. Unresolved legacy mounts remain available through category management. If you used an older prototype, check your favorites and keybindings after upgrading.

## Validation and first ESO test

Simulated Lua tests cover 500 collectible mounts, correct picker type filtering, initial A–Z sorting, scrollbar/wheel bounds, last result access, slider callback recursion, literal search, no matches, scrollbar visibility, save/cancel/clear, search reset, stale locked rows, parent/picker cleanup, management without favorite changes, all eight favorite commands, bank validation, official category priority, fallback classification, and saved-data reuse/repair. Packaging checks cover manifest files, twelve unbound configurable actions, inherited controller actions, and archive equality to source. `tests/mount_swap_gamepad_test.lua` includes the existing suite and adds controller focus, menus, scrolling, text entry, shared settings, cursor ownership, mode switching, missing-helper fallback and measured layout tests. These use mocks, not an ESO client or physical controller.

These checks do not run ESO. In-game validation remains necessary:

1. Disable ShowMount/SteadyMount for the first test and keep Bug Catcher enabled.
2. Open every favorite's picker. Verify Multi and Single lists match Collections and sort immediately.
3. With a large collection, wheel through it, drag the thumb to both ends, and select the last result. Search, cancel, reopen and verify reset behavior.
4. Save each favorite; cancel a replacement; clear a slot. Confirm the intended slot alone changes.
5. Verify main-window blocking, X/Cancel, Escape from search, and closing the whole addon.
6. Manage fallback categories if any mounts need review; ensure management does not overwrite favorites.
7. Assign your own keys and test all eight favorite actions and random.
8. Run `/reloadui` and switch characters to confirm persistence.
9. Send any complete Bug Catcher error/stack trace, triggering action, game language and API version (`/script d(GetAPIVersion())`).

Historical 0.4.2 status (superseded by the current release/test notes): partially tested in ESO by the user. Selection, Clear slot, Cancel and Close were reported working; the reported search-input failure is addressed in 0.4.2 and needs an in-game retest. Not certified bug-free. Author metadata is a placeholder to replace before publishing. Preview images are layout illustrations with sample names.

API reference: https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt

## Version 0.4.1 server handling

Explicit per-world account-wide profiles prevent changes on PC-NA from overwriting PC-EU favorites. Simulated tests cover switching worlds, profile persistence, one-time migration and excluding unavailable legacy favorites. This is architectural compatibility, not a claim of completed in-game testing on either megaserver. From 0.8.4, Collections category discovery is language-neutral; metadata failures retain the existing fallback category management. The author confirmed successful PC controller use in 0.8.6. Version 0.8.7 uses the requested ShadowStrikerr author credit. API 101051 matches current live documentation. No open-source redistribution license has been selected or inferred; the uploader must personally make the rights/terms declaration when publishing.

## Version 0.4.2 search-input correction

Adds the click-to-focus behavior used by ESO standard edit controls, explicitly enables editing and sets readable input/placeholder colors. Clicking the search field or its background takes focus; Enter releases it while keeping the picker open. Escape retains cancel behavior. Uses ESO scrollbox_elevator thumb artwork and explicitly enables the slider. Tests cover the focus/Enter callbacks as well as the existing search/filter and scrolling checks. Retest typing/filtering and thumb dragging inside ESO.

## Version 0.4.3 activation feedback and button routing

Each favorite and Use button now carries an explicit slotIndex, rather than relying on its loop closure. Chat feedback names the target slot and mount. Upper-right notifications show the collectible icon and name: “M1 favorite saved” when saving a picker choice, “Mount selected” after the active collectible ID confirms a requested change, and “Already selected” when no switch is needed. Notices dismiss after four seconds; older timers cannot dismiss newer notices.

Activation requests are checked immediately, on EVENT_ACTIVE_MOUNT_CHANGED, and after a 2.5-second timeout. Random uses the same confirmation path. If ESO does not confirm a request, chat reports that instead of claiming success. Saving a favorite still does not activate the mount automatically. Type `/mountswap debug` to print version, world, active mount ID, and saved slot IDs/names for troubleshooting.

Additional tests exercise all eight actual Use-button callbacks and the Random button, empty/already-active slots, immediate and delayed changes, unconfirmed requests, and notification timers. The reversed messages and Random behavior reported in game could not be reproduced in the simulated API environment; this update needs an in-game retest. The Bug Catcher message in the user's screenshot was confirmed by the user to belong to ShowMount, not MountSwap.

## Version 0.5.0 nearest multi-rider passenger action

**Use nearest multi-rider mount** is available on the main window, in Controls → Keybindings → MountSwap - General, and through `/mountswapnear`. No key is assigned automatically. It is an independent implementation using ESO's public APIs; Kyzderp's Derps is not required.

The action scans your group, excludes yourself and offline/dead members, requires the target to be riding a group mount as driver with a free passenger slot, and chooses the nearest eligible target by squared three-dimensional world distance in the same zone. It requests boarding with UseMountAsPassenger. It does not change favorite slots or your own selected mount. It does not enumerate arbitrary nearby strangers. ESO decides range, accessibility, permissions and other restrictions; a free seat may fill before the request completes. No arbitrary interaction-distance limit is guessed by the addon.

If already riding as a passenger, the action reports that and makes no request. If no eligible rider or position is found, chat explains the issue. A success notice appears only after IsGroupMountPassengerForTarget confirms the requested rider. Unconfirmed requests produce chat feedback after 2.5 seconds rather than claiming success.

Tests cover the main button and slash command, nearest 3D distance, self/dead/offline/full/single/passenger/other-zone exclusions, unavailable coordinates, already-passenger behavior, delayed confirmation and timeout reporting. In-game validation remains necessary. Group with someone on a multi-rider mount with an empty seat, stand close, then test the button and your chosen key. With two eligible riders at different distances, confirm the nearer is used. Also test no group, full seats, already riding as passenger and out-of-range feedback.

## Version 0.5.1 Keybindings shortcut

A Keybindings button beside Close opens the keyboard Controls keybinding panel. When libAddonKeybinds is installed, it selects its Addon Keybinds panel; otherwise it selects ESO's standard keybindings panel. If Votan's Keybinder and its search API are available, the shortcut fills its search box with `mount` and requests filtering. Both integrations are optional and no keys are assigned or changed. Search is not promised for unrelated search addons; the fallback opens the panel and explains manual search.

The shortcut closes MountSwap and its picker, opens the game menu, and waits briefly for the menu tree. Tree lookup retries are bounded and stop if the player leaves the menu. Keyboard mode is required. Tests cover actual button dispatch, panel preference, search integration, missing-addon fallback, delayed tree creation and cancelled navigation. Verify this integration in game with your installed addon versions. No third-party source code is bundled.

## Version 0.5.2 positioning and focused search

The main panel now starts horizontally centered, 160 UI units from the top of GuiRoot instead of vertically centered. It remains draggable and clamped to screen. The picker retains its centered placement. The Keybindings shortcut searches for MountSwap rather than mount; Votan's Keybinder matches category names, so all three MountSwap categories and their eleven actions remain discoverable. The user confirmed that the keybinding shortcut and nearest multi-rider passenger action worked in game in 0.5.1.

## Version 0.6.0 Settings > Addons and chat preference

MountSwap now registers a settings panel with **LibAddonMenu-2.0** when that library is installed/enabled. Publishing on ESOUI is not required. The manifest declares the library as an optional dependency to load it first. Install/enable LibAddonMenu-2.0 if MountSwap is missing from Settings → Addons; the normal addon window still runs without it.

The MountSwap settings panel contains a saved **Show MountSwap chat messages** checkbox and buttons to open the main window and MountSwap keybindings. Chat is enabled by default. Turning it off suppresses normal MountSwap chat output across selection, Random, passenger requests and navigation; upper-right notices remain enabled. The preference is account-wide within each server profile. Explicit `/mountswap debug` diagnostic output and an explicitly requested missing-settings-library explanation are still printed.

Commands: `/mountswap settings` opens the settings panel; `/mountswap chat off` silences messages; `/mountswap chat on` restores them. Settings tests cover panel registration, get/set callbacks, module-wide suppression, debug bypass, visible notices and panel navigation. Retest the panel and preference persistence after `/reloadui` inside ESO.

## Version 0.7.0 full settings-only mode

Settings → Addons → MountSwap now contains all eight favorite selectors, four under Multi-Rider and four under Single-Rider, plus individual Use actions, Random, nearest multi-rider passenger boarding, chat preference and keybindings navigation. Each dropdown lists unlocked mounts of the matching type in A–Z order; None clears the slot. Selecting a mount saves the favorite without activating it. Lists refresh when the panel opens.

**Use standalone panel** defaults on. Turning it off closes the main window/picker and makes `/mountswap` and the open-selector hotkey open settings instead. Favorite, Random and passenger actions continue to work. The mode is saved in the account/server profile. Re-enable it from settings to restore the standalone window.

LibAddonMenu-2.0 was required for settings-only mode in this version. If missing after a reload, the open command restored the standalone window so the player was not locked out. From 0.8.0 controller settings work without the library; from 0.8.2 the keyboard fallback opens temporarily without changing the saved dashboard OFF preference. Category fallback management remains available through the dashboard. Simulated tests cover all eight selector/Use callbacks, clearing, type checks, fresh lists, popup dismissal, redirect behavior, working hotkeys and missing-library recovery. Actual LibAddonMenu layout and preference persistence need an in-game check.

## Version 0.7.1 compact settings rows

Each mount dropdown and its Use button now form a pair of half-width controls on the same settings row. Separate Multi-Rider and Single-Rider headers remain. Keybindings and Join nearest multi-rider labels are shortened to avoid clipping. Dropdown sorting is explicitly name-up so LibAddonMenu does not reorder choices by their numeric collectible IDs. Actual settings spacing is controlled by LibAddonMenu and requires an in-game visual check.

## Version 0.7.2 settings search fields

LibAddonMenu standard dropdowns do not have an embedded search field. MountSwap adds one search edit box above each favorite section instead. Multi-Rider search filters M1–M4 dropdowns; Single-Rider search filters S1–S4 independently. Text-change hooks provide live filtering; the normal editbox setter also applies on Enter/focus loss. Clear the text to restore the full list. Search uses literal case-insensitive matching and is not persisted across reloads. None and the currently saved favorite remain available even when they do not match; a nonmatching saved mount is labeled [Saved]. Searching never changes saved assignments. Tests cover filtering, independent banks, saved-choice retention, punctuation, clearing and live hooks. Verify the new LibAddonMenu edit fields in game.

## Version 0.7.3 None ordering and strict settings filtering

None is always inserted first, followed by the already alphabetized matching mounts. LibAddonMenu automatic re-sorting is disabled to keep None pinned. Saved nonmatching mounts are no longer added to the search results. The closed selector can still display its existing saved mount using a separate label lookup; searching does not clear it. Choosing None clears that slot and immediately rebuilds the choices so stale saved entries disappear. This supersedes the 0.7.2 [Saved] search-result behavior. Tests cover None ordering, strict matching, saved-label lookup and immediate clear refresh. Retest on the installed LibAddonMenu version.

## Version 0.7.4 aligned favorite rows

Favorite settings use a custom LibAddonMenu row built around its native dropdown. M1–M4 and S1–S4 labels, mount selectors and Use buttons share one horizontal row. The row is 32 UI units tall; labels take 44 units, Use buttons take 90 units, and the mount selector receives the remaining width with spacing. At a 600-unit row width, the selector is 442 units wide. Resizing recalculates its width. Native dropdown value handling, None-first ordering and section searches are retained. Tests exercise the custom factory sizing, resizing and Use callback. Please verify actual alignment in ESO.

## Version 0.7.5 unified dashboard controls

Enable dashboard, its ON/OFF toggle and Open Dashboard now share one full-width settings row. Open Dashboard is disabled while the toggle is off; clicking Open does not toggle the preference. Keybindings remains on a separate row. The stored standalonePanel preference is retained, so existing settings, settings-only routing and hotkeys remain compatible. Tests cover row sizing, enable/disable synchronization and guarded Open dispatch. Verify actual LibAddonMenu alignment in game.

## Version 0.7.6 settings header alignment

The chat and dashboard ON/OFF controls now use the same shared column layout. Keybindings is right-aligned directly below Open Dashboard with matching 180-by-28 dimensions. Favorite rows, searches and saved preferences remain unchanged. Geometry checks verify shared toggle anchors and the right-aligned button; in-game visual confirmation is still needed.

## Version 0.7.7 editable chat command shortcuts

Adds `/ms`, `/m1`–`/m4` and `/s1`–`/s4` as configurable defaults. Settings include nine editable command fields, availability warnings, and a reset button. Shortcuts update immediately, persist per account/server, and can be disabled individually. Registration and cleanup preserve other addons' handlers; reset validates every default before changing anything. Original slash commands, keybinding action IDs, favorites and existing preferences are retained. Simulated tests cover routing, settings callbacks, input normalization, invalid/duplicate/reserved/channel/addon conflicts, later-addon replacements, atomic reset, persistence and profile isolation. New settings controls still require an in-game check.

## Version 0.8.0 PC gamepad navigation

Adapts Crown Crate Codex's temporary input layer, native binding icons, target/focus navigation, scene-managed windows and shared settings approach to MountSwap. Adds a separate unbound controller open action, outlined dashboard/picker navigation, mount details, context actions, picker/list paging, controller settings and native edit-control text entry with keyboard fallback. Uses measured, wrapped controller hints and three text sizes. All existing action IDs, commands and SavedVariables identity are preserved. Existing automated regressions and the new mock controller suite pass; actual controller operation, visual readability and native text entry remain subject to the included in-game checklist.

Reference reviewed: ESO live API documentation, https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt (API 101051).

## Version 0.8.1 release-guidance audit

Historically added optional dependency constraints/load order (the optional numeric suffixes were ineffective and are corrected in 0.8.7), operation-local references to settings/library registries (including nested callbacks), and controller input release on player deactivation. Centralizes the displayed code/settings version. Adds an addon-environment global-write audit and deactivation regression coverage. Clarifies platform/testing/dependency claims, expands existing source credits, and adds a newest-first CHANGELOG.txt. The AI disclosure, initial Crown Crate Codex reference credit, and ZeniMax notice were already present; they are retained/clarified, not newly introduced by this audit. No SavedVariables reset, rekey, schema bump, gameplay automation or keybinding assignment is added.

## Version 0.8.2 updated handoff and saved OFF preservation

Corrects the missing-LibAddonMenu keyboard fallback: opening the temporary dashboard and its pickers no longer changes `standalonePanel=false` to true. When the optional settings library returns, the saved OFF choice still routes to settings. Chat OFF, custom/disabled commands, favorites, legacy slots, schema version 1 and account/server identities remain intact. Explicit settings changes still work normally. New regressions exercise repeated fallback open/close, picker access, library restoration, shared settings getters and OFF preservation under the global-write audit. All previous keyboard/controller mock checks remain included; no new in-game/hardware verification is claimed. Controller text sizes remain Normal, Large and Extra Large; text measurement/wrapping tests do not certify actual client rendering.

## Languages

Languages and automatic selection (0.8.3)
English, Simplified Chinese, French, German, Japanese, Russian and Spanish are
included. Automatic follows ESO's Language.2 setting (jp maps to Japanese);
unsupported languages fall back to English. Settings offers Automatic and all
seven manual choices; changing it requires Reload UI. The optional language
choice is stored in the existing account/server profile without a schema reset.
Mount names/descriptions remain ESO's own client-language text. Command tokens,
saved collectible IDs and existing settings, including OFF choices, are preserved.
Translations are AI-drafted, including common labels adapted from the Crown
Crate Codex workspace dictionaries; native-speaker review is pending. English
fallback covers missing strings. From 0.8.4, category discovery uses known multi-rider collectible identities, not localized labels or fixed category positions. Existing saved/observed/manual fallback remains available when metadata cannot establish the category.
Actual font glyphs, text clipping and controller text entry need in-game checks.

Release preparation and the remaining publication checks are documented in the separate MountSwap ESOUI Submission Guide. No public upload is performed by this build.

## Publication review, 0.8.7

Author credit is ShadowStrikerr. The author reported that the 0.8.6 gamepad works perfectly; this is a user hardware report, not certification of every controller, language or interaction. Automated tests remain separate evidence. AI code-generation disclosure, initial source credits and the ZeniMax notice were already in the package; they are retained. User-supplied stitched screenshots are handled separately and are not bundled with the addon. The supplied combined settings image matches the earlier AI-assisted composite; it is labelled as a presentation overview, with original settings pages available as alternatives.

No separate open-source implementation license is declared. Crown Crate Codex is the user-authorized workspace reference by the same requested author; no UESP catalog, bundled library implementation or ShowMount source is included. No MIT, GPL or CC grant is invented. The author must confirm rights to submit and agree to hosting terms personally at publication.

## AI disclosure and ZeniMax notice

AI code generation and documentation assistance: OpenAI Codex. Translations are AI-drafted and have not been certified by native speakers.

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

### Escape/menu correction in 0.8.7

A later user test found that 0.8.6 could trap Escape. The window registration used ESO's UI-mode lock, which blocks native menu handling before top-level dismissal. 0.8.7 removes that lock while keeping native top-level cursor ownership, and permits native menu/chat/mode actions through its controller layer. First Escape dismisses the addon; subsequent Escape can open the native menu. The targeted automated regression passes, and the author subsequently confirmed that Escape works in the live 0.8.7 retest.

0.8.8 spacing update: directions use four equal columns, 24px horizontal gaps
and a 16px vertical gap below the action hints. Labels are measured/wrapped at
every supported controller text size; actual new spacing awaits visual retest.

0.8.9 supersedes the 0.8.8 equal-width direction cells: hints now form a compact
left-aligned group sized from native text metrics, retaining 24px gaps and the
16px row separation. Automated fitting tests pass; the final English 0.8.9 screenshot was reviewed and accepted.

## Final 0.8.9 submission status

The final English 0.8.9 dashboard screenshot was reviewed and accepted: compact direction hints have clear gaps and no visible clipping. This is not certification of every localized client or text size. The author also confirmed Escape/menu handling works. Current publication documents and the clean ZIP identify ShadowStrikerr as author. The optional combined settings overview is AI-assisted and clearly labelled; original settings pages are supplied. The addon is prepared, not published.

Final submission materials: ESOUI-Description.txt contains the approved public
wording. The separate versioned ESOUI-Post-BBCode file uses Crown Crate Codex
formatting. Detailed test counts and audit evidence remain in verification
documents; the listing retains player-facing limitations and source credits.
AI disclosure and credits were already present; their presentation was revised.
