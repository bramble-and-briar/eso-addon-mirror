# Crown Crate Codex

Version 0.12.6, targeting ESO API 101051. Tracking works without required libraries; the AddOns settings page uses recommended LibAddonMenu-2.0 r43 or newer (AddOnVersion 43). Core tracking and automatic language selection work without it.

## PC controller navigation

ESO must recognize your controller. Set ESO's Gamepad Mode to Automatic or On, open Codex with `/ccc` or its configurable toggle, then use the D-pad to move the cyan focus outline. Navigation is enabled by default and can be disabled in Codex settings. The same setting controls keyboard/gamepad transitions without changing saved history.

Standard Xbox-style UI bindings (your ESO bindings determine the actual buttons):

- A / Primary: select the focused control or reward; Codex entries toggle their wishlist.
- B / Negative: dismiss details, close a picker/dialog, or close Codex.
- X / Secondary: open the focused collectible in Collections.
- Y / Tertiary: controller options, including search, filters, settings, import, export, and UI reload.
- Right-stick click: view the focused reward/control description without mouse hover.
- LB/RB: switch History, Reward rates, Codex, and Status tabs.
- LT/RT: previous/next page or visible row group; also page through long choice menus and CSV parts.

Controller settings use the same option definitions and stable values as the keyboard settings page. Dropdowns/sliders use a scrollable picker; the hint color has four presets. The keyboard page still provides the custom color picker. Language changes still require a UI reload. The keybindings shortcut opens ESO's native gamepad keybindings scene where available; configure the Codex toggle there. No default controller shortcut is assigned and no existing binding is overwritten.

Search delegates text entry to ESO's native edit focus helpers; actual PC virtual-keyboard behavior depends on the client/controller setup. Physical keyboard input remains available. CSV parts are viewable using controller triggers; copying text into an external file still uses the PC clipboard workflow. This release does not add console compatibility.

The separate `Gamepad.lua` module registers a temporary named action layer only while a Codex window is visible in gamepad mode. It releases the layer on close/mode changes and during search editing. It does not register an OnUpdate polling loop, call protected key-binding setters, extract items, open crates, or change the recording/statistics algorithms. Menus reuse existing controls and import retains the explicit server/ownership confirmation.

Automated gamepad checks cover focus, selection, descriptions, Collections, tabs, pages/scrolling, long menus, settings, edit-focus transitions, import guards, cleanup, and unchanged history/CSV. Initial in-game controller testing by the author succeeded. Other controllers, localized clients and layouts are not comprehensively verified. Extra Large controller footer hints can clip; Large mode showed all hints in the supplied capture. Future ESO API changes can still require maintenance.

## Languages

Settings > AddOns > Crown Crate Codex > Language offers Automatic — follow ESO (default), English, Chinese (Simplified), French, German, Japanese, Russian, and Spanish. Automatic and English stay first; the remaining entries follow alphabetical English language names and include their native names. Changes apply after `/reloadui`. An unsupported game language falls back to English.

The selection translates Codex's interface, warnings, descriptions, and statistics labels. ESO supplies crate/reward names and collectible categories in the game client's language; choosing a different addon language does not translate those game assets. Stored numeric identities, server/account profiles, CSV field names, and internal setting values remain independent of display language. Existing records are preserved.

Historical tier lookup retains verified catalog identities beside numeric crate IDs and can use exact product IDs and quantities when every catalog occurrence agrees. Conflicting references remain unresolved instead of guessing from a translated name or item quality. It does not promise to reconstruct every unknown historical reward or future reward pool.

The seven translation dictionaries are checked for completeness, format placeholders, line breaks, fallback behavior, and data/statistics preservation. They are AI-drafted translations, not certified official terminology. Native-speaker review and actual localized-client testing are welcome, particularly for CJK glyphs, font sizes, and long labels. If a manual language override displays missing glyphs, test with the corresponding ESO client language. The English UI remains available.

Translation source/review matrix: `tools/CrownCrateCodex-translations.tsv` in the development source. Rebuild generated `lang/*.lua` with `node tools/Build-CrownCrateLanguages.cjs`. Edit the matrix, not generated files.

## Install and open

Codex registers its main window, choice menus, export window, and import dialog with ESO's native top-level UI manager. Opening `/ccc` from the world now activates cursor mode and keeps it while chat closes. Closing Codex lets ESO decide whether another open panel or chat still needs the cursor; Codex does not forcibly hide another panel's cursor.

Extract the ZIP into `Documents/Elder Scrolls Online/live/AddOns`, giving `AddOns/CrownCrateCodex/CrownCrateCodex.txt`. Enable Crown Crate Codex and reload the UI. If ESO does not detect the new addon folder, restart the client.

- `/ccc` or `/crowncratecodex`: open the window.
- `/ccc import`: open the Crown Crate Tracker import confirmation dialog.
- `/ccc scan`: refresh owned/on-sale crate discovery.
- `/ccc status`: recording diagnostics.
- `/ccc keys`: open the keybinding panel, with Codex search where supported.
- `/ccc settings`: open Settings → AddOns → Crown Crate Codex.
- Controls → Crown Crate Codex: assign a toggle key.

The Crown Crates scene gains a native, clickable **Codex history** footer action beside the old Tracker history action. It uses its own `CROWN_CRATE_CODEX_TOGGLE` binding and does not take over R or automatically bind any key. Assign an unused key in Controls → Crown Crate Codex; for example, Alt+C if it is free in your setup. `/ccc` always remains available. The history window overlays the scene and scales to the screen. It does not replace the game's crate-opening logic or require buying a crate.

## Layout

The 1820×930 panel presents opening rows and five reward columns. Each cell adds an ESO-provided icon, readable reward name, quantity, rarity group, and bonus marker. **Text** cycles between **Compact** (32-pixel reward icons, six rows), **Large** (48-pixel icons, four rows), and **Extra Large** (64-pixel icons, 22-pixel text, three rows). Existing size choices migrate automatically. The window always fits inside the screen; a saved 75–130% scale slider is available in Settings. Help text, reference hints, summary, and buttons also respond to size changes.

**View: Pages / View: Scrolling** switches the saved navigation preference. Scrolling supports the mouse wheel and a draggable scrollbar, reuses the same visible row controls, and uses the cached matching list and existing statistics during movement. It does not create one row control per historical record or recalculate drop rates on each notch. Search/filter/data changes rebuild the matching list normally. Settings includes scroll speed.

Normal current crates show up to five reward cards, so the extra **Cards** controls are hidden. They are available only when actual loaded records contain more than five slots; they are defensive data navigation, not a claim about current game rewards.

Search now uses ESO's standard edit control, explicitly takes focus, and includes **Clear**. Search combines with the crate/type filters. Neither search nor scrolling changes percentage denominators.

The window defaults to the high draw tier/topmost and raises itself when opened or clicked, to appear above normal map/Collections panels. **Keep Codex above other panels** is configurable. Right-clicking a collectible intentionally hides Codex before opening Collections. Background opacity and reset-position controls are also available.

Hover descriptions use a wider, screen-clamped tooltip (640 UI units by default, configurable in Settings). Crate hover shows concise reward lines instead of repeating every reward's provenance. Individual reward hover retains source and tier details. Oversized descriptions are limited to screen height with an explicit note to hover individual rewards. The right-click action is cyan by default; its color is configurable.

The statistics sidebar is wider and uses separately positioned labels for every total, percentage, and denominator. It no longer depends on embedded newline characters for layout. History opening number/source and date are also separate labels.

The window's **Keybindings** shortcut opens Controls and searches for Codex when Votan's Keybinder is available, following the same menu integration used by MountSwap. It never assigns or overwrites keys. The **Settings** shortcut opens the LibAddonMenu panel under Settings → AddOns. Settings include display size, window scale, import percentage switches, import, and keybinding/history shortcuts. If LibAddonMenu is unavailable, tracking and the standalone controls continue to work.

Click a crate's row background to filter to that crate. The crate-type dropdown lists **All crate types** first, followed by known crates in alphabetical order (case-insensitive, stable ID ordering for identical names). Selecting a crate resets the list position and updates both history and statistics. The boxed **SHOW ALL CRATES** button also returns to all crate types. Search matches crate names, reward names/types, bonus status, raw tier IDs such as `tier 99`, and recognized rarity group names. Click **Opening / date** to reverse chronological order.

**All reward types** opens a category menu with all collectibles, items/consumables, and the collectible categories present in your history, such as mounts, pets, skins, and emotes. Category filtering affects visible records, not percentage denominators. **Right-click a collectible reward** to open its exact entry in ESO Collections. Left-click still selects the individual reward percentage. The statistics panel also has **Open in Collections** for a selected collectible. Codex does not equip, activate, buy, or extract the reward. Item rewards that are not collectibles do not offer this navigation.

The **YOUR DROP RATES** panel remains beside the grid:

- Lifetime openings and openings recorded since this UI load, for the selected crate type.
- Toggle between lifetime and current-session rates without deleting history.
- Rarity-group percentages with numerators and denominators.
- Bonus-card frequency across all openings.
- Recorded automatic-exchange gems; older Tracker exchange amounts are unknown.
- Click a reward cell to see that item's own percentage, number of appearances, cards, and total units.
- **Imported rewards in %**: ON by default for item and bonus rates; switch OFF to exclude every imported opening from percentages. All imports stay in History and the Codex.
- **Imported tiers in %**: ON for new users now that a verified catalog is bundled. ON includes fully classified imports when imported rewards are also enabled; OFF limits rarity rates to native recordings. Unknown tiers never become misses. Existing public users' explicit choices remain unchanged. The private build enables it once on this upgrade as requested, then preserves future choices.

Both switches are saved between UI loads. The panel shows included/excluded imported counts and the number of openings eligible for tier classification. Reward rates follows these switches; the Codex remains a record of all observed rewards and does not show filtered percentages.

Each import switch has a visible **[i]** control. Hover or click it for the OFF/ON explanation; the switch itself also has hover help. The settings-page options have the same descriptions. Lifetime/Session also has an **[i]** explanation: session means recordings since the current UI load, including a reset of the displayed session after `/reloadui`, without deleting lifetime records.

**Reward rates** lists individual reward frequencies separately for each crate. **Codex** lists observed rewards, collectible ownership, and click-to-toggle wishlist entries. These lists do not claim to be complete reward pools.

Search filters the displayed records but never changes the statistics denominator. Crate filters apply to both. The panel labels the combined view when multiple crate types are included.

## Percentages and rarity

The new far-right **Official*** column is separate from your measured rate and opening count. Common through Legendary show 98%, 72%, 86%, 21%, and 14%. Apex shows **2% total*** and Radiant Apex shows **Included***, with a standing note that this is their combined figure. It is not repeated as 2% for each rarity, and no standalone Radiant percentage is invented. General-guidance notes remain visible with the column even if optional help hints are hidden.

**Show official reference column** in Settings can hide the comparison. It never changes history, numerators, or denominators. All-crate views explicitly mark mixed types. Known English-named preview and Ouroboros crates show `--` with **Special crate: no applicable reference**, rather than applying the general purchased-crate figures. Other crate types still carry the general-guidance qualification; this is not a claim that every special variant is validated. No webpage-opening button or automatic browser navigation is included.

The bonus caption now reads **Fifth-card bonus: 10.00% - 1 of 10 crates**, for example. The count means openings in the current scope that included a bonus card, not a limit of ten available cards. Normal purchased crates have four base cards and can receive a fifth bonus card; the measured result is not a published fifth-card probability.

An item's main rate is openings containing that item / recorded openings for that crate. Multiple identical reward cards in one opening count once toward this rate; card count and unit count are displayed separately.

Live results retain ESO's raw crate tier ID. The first five tier-specific NPC reactions classify Common through Legendary. The sixth reaction covers the high-tier group and is not sufficient to distinguish Apex from Radiant. Exact crate/product-ID/quantity catalog matches resolve **Apex** and **Radiant Apex** as separate rarities for both imported and live records. Their percentages and opening counts now appear on separate, color-coded rows. Live high-tier results without a verified split are labelled **Apex tier: split unresolved**, rather than assigned to either group. They remain visible and keep their item/bonus results, but their openings are excluded from the fully classified rarity sample. Hover **Tier data** for unresolved high-tier counts. Future seasons may need updated catalog coverage to split these two groups; ordinary recording remains automatic.

The selected crate is emphasized in a cyan header band above the percentage controls; the crate dropdown also uses cyan text. **All crates combined** is explicitly labelled when no single crate is selected.

Rarity percentages use only openings whose rewards are all classified, and the panel shows this coverage. In particular, legacy openings with missing tiers are not counted as rarity misses. This classified subset may differ from the full history; it is not an unbiased substitute for missing historical tiers. Individual reward and bonus rates include imported openings because their identities and bonus flags were recorded.

ZOS's published **general purchased-crate** reference appears alongside the rarity groups, marked with an asterisk: Common 98%, Fine 72%, Superior 86%, Epic 21%, Legendary 14%, Apex including Radiants 2%. This is not a per-card distribution and is not assumed to apply to every special, preview, or Ouroboros crate. Hover the reference for details. These published guidelines and personal observations are separate; neither promises the next outcome. [Official source](https://help.elderscrollsonline.com/app/answers/detail/a_id/49828/)

## Importing Crown Crate Tracker

Tracker's original file is read, never modified or deleted. **Both addons can remain enabled.** The optional dependency loads Tracker first when it is enabled, allowing Codex to import `CrownCrateData.Crates["Crate info"]`. Public releases contain an empty LegacySeed.lua. The original Tracker data must be loaded to preview its history; no player data is included in public packages.

Synchronization runs at first world entry, when opening Codex, on manual import, and once after each batch of crate-open response events. The deferred callback allows both addons' event handlers to finish. Current-batch records are paired one-to-one using crate/reward content, retaining both addons' timestamps where the clock crosses a second. Persisted aliases prevent the same live opening being imported again after a reload. This pairing is never used as a fuzzy historical deduplication rule. Identical legitimate openings remain distinct.

The installed Tracker version also writes rows for failed open requests. When its newly appended rows correspond one-to-one with the response-event batch, Codex marks those failed rows as rejected and does not add them to its history or percentages. The original rows remain untouched. Use **Import Crown Crate Tracker History** in Settings or `/ccc import` for an explicitly confirmed historical import.

The importer preserves timestamps, crate IDs, reward order, identities, quantities, bonus flags, and the original serialized record. It preserves even genuinely identical duplicate openings. Re-importing overlapping snapshots does not add duplicates. Malformed records are retained in import diagnostics for inspection rather than silently treated as complete openings.

Settings > AddOns > Crown Crate Codex has **Import Crown Crate Tracker History**. The dialog explicitly warns that the old addon has no server labels, previews readable/unreadable record counts, requires a PC_NA or PC_EU selection and an unchecked ownership confirmation, and keeps Import disabled until confirmed. You must be logged into the selected server to import. Cancel changes nothing. Imports use the previewed snapshot, skip duplicates, and skip records already stored on another server. Fresh-start exclusions remain in force unless particular records are explicitly approved through this dialog. Older unapproved records do not import automatically; new live recording and event synchronization continue. Existing Codex histories are preserved.

Names, types, and icons are resolved from ESO's item/collectible data. Tracker did not save reliable tiers or exchange amounts in these records. The bundled **UESP historical catalog** supplies 3,605 crate-specific product-type/ID/quantity rarity mappings from 42 indexed crate pages. Exact matches show named rarity, including Radiant Apex where explicitly catalogued. Hover for the source revision. This does not fabricate the original internal ESO tier ID or unknown gem amounts. Unmatched entries remain unknown. The catalog currently matches English crate names; reward IDs themselves are language-independent.

To include catalogued imports in rarity percentages, switch **Imported tiers in %** ON while **Imported rewards in %** is also ON. These remain separate from live observations. If a later live opening supplies an unambiguous internal tier for the same crate, reward identity, and quantity, the historical internal tier can also be filled with an explicit provenance label. Conflicting live observations invalidate that live match.

Catalog attribution: UESP contributors, [Crown Crates](https://en.uesp.net/wiki/Online:Crown_Crates), [Attribution-ShareAlike 2.5](https://creativecommons.org/licenses/by-sa/2.5/), [source terms](https://en.uesp.net/wiki/UESPWiki:Copyright_and_Ownership). The derived catalog is under the same license; each crate includes an exact source revision URL. No UESP images are included. The rest of Codex's implementation is independent of that reference data.

Tracker also did not label accounts or megaservers in these records. Legacy data is imported into the current Codex profile without claiming its original server can be recovered. Native Codex data is account-wide across characters and profiles are separated by megaserver.

## New crates

Codex learns owned crate IDs, the current sale crate, and any successfully opened crate directly from the public ESO API. It refreshes on world entry, crate inventory/quantity changes, crate-system changes, and opening the Codex window. There is no hardcoded season list or required seasonal download. It records new reward IDs, tiers, types, and any number of cards.

Complete unseen historical/future reward pools are not supplied by this discovery API. Recording openings and calculating observed rates do not need an external website. Game API changes can still require compatibility updates.

## History retention and backup

Update policy: addon updates preserve all existing account/server histories and preferences. Startup reset support has been removed, including handling of old private reset requests. Upgrade tests verify that native and imported records, next IDs, wishes, diagnostics, legacy approvals, and import cutoffs survive repeated initialization. Update only the AddOns/CrownCrateCodex folder; leave SavedVariables untouched.

The lifetime history is never automatically pruned and there is no destructive reset control. Session statistics do not erase lifetime records. ESO writes the addon's SavedVariables to `SavedVariables/CrownCrateCodex.lua` on clean logout or `/reloadui`; a crash before saving can lose unsaved results.

An addon cannot recover a deleted SavedVariables file on its own. The repository includes `tools/Watch-CrownCrateHistory.ps1`, which keeps dated, hash-labelled snapshots of both Codex and Tracker outside the ESO directories, without overwriting or pruning older snapshots. It now uses Windows filesystem events: after an initial snapshot, it sleeps until a matching saved file changes. It no longer polls every five seconds. The helper must remain loaded to receive events. It does not recover openings ESO has not written to disk and does not upload information or provide off-device storage.

Start the helper with PowerShell, from the repository:

```powershell
./tools/Watch-CrownCrateHistory.ps1
```

Default backups are under `.local/history-backups`. To recover, exit ESO and use the restore helper with an actual Codex snapshot path:

For automatic startup at Windows sign-in, run `./tools/Install-CrownCrateHistoryBackup.ps1`. It registers **Crown Crate Codex History Backup** as a hidden, current-user task, starts it immediately, and does not request administrator privileges. The task uses the repository script, so keep the repository in its installed location. To stop and remove automatic startup:

```powershell
Stop-ScheduledTask -TaskName 'Crown Crate Codex History Backup'
Unregister-ScheduledTask -TaskName 'Crown Crate Codex History Backup' -Confirm:$false
```

To restore a snapshot:

```powershell
./tools/Restore-CrownCrateHistory.ps1 -SnapshotPath 'C:/path/to/CrownCrateCodex-TIMESTAMP-HASH.lua'
```

Restore checks the snapshot hash and preserves the current file before replacing it. Merely resetting the displayed session never requires a restore. A full disk wipe also removes local backups unless you separately back them up elsewhere.

## CSV and verification

Export follows History's search and crate filter. Copy all numbered parts in order into one UTF-8 CSV file; only the first part has a header. Imported gem fields are blank. ESO addons cannot write arbitrary CSV files directly.

The **Status** tab reports native/imported totals, latest import results, recording failures, historical tier provenance, and when work is triggered. The addon cannot inspect Windows Task Scheduler or the external backup folder, so this tab does not pretend to verify live backup health. Check the Windows task and snapshot directory for that.

The addon stays loaded while ESO is running but does not register an OnUpdate handler or repeating import timer. Recording is triggered by crate-open responses. Discovery also runs on login and crate inventory/system changes; browsing and imports run on their specific UI/event triggers.

Mocked-client Lua tests cover discovery, failed/invalid openings, future tiers and reward counts, statistics, exact legacy round trips, duplicate-aware imports, missing-tier treatment, session scope, UI creation/bounds, extra reward pages, filters, wishlist, CSV, and scene lifecycle. Coexistence tests cover both handler orders, clock boundaries, batched identical outcomes, failed Tracker rows, retained settings/aliases, import exclusion, and the absence of repeating callbacks. PowerShell tests cover byte-identical backups, immutable snapshots, hash-checked restore, preservation of existing files, background file-change notifications, and unchanged-file suppression.

Personal build snapshots are verified separately with an exact source round trip. Names and icons still resolve in the real client. Live visual and event verification remain required; no crate purchase was performed during development.

Public API references: [API 101051](https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt), [crate scene](https://github.com/esoui/esoui/blob/live/esoui/ingame/crowncrates/crowncrates.lua). Inspired by the functionality of [Crown Crate Tracker](https://www.esoui.com/downloads/info1741-CrownCrateTracker.html).


The crate and reward-type dropdowns use their own opaque, topmost picker instead of the global ESO context menu, which could appear behind Codex. Long lists support a mouse wheel and scrollbar; crate names remain alphabetically sorted. The picker closes on selection, through Close, or when the main window is hidden.





The bundled HistoricalCatalog.lua is generated from UESP crate and reward-card pages using tools/Update-CrownCrateCatalog.ps1. It includes exact crate/product-ID/quantity matches plus item-ID fallbacks from explicitly published card reward quality (never ordinary item quality). Conflicting item facts are omitted. Every fact retains its source revision. This covers the fetched pages, not a guarantee that all future or undocumented rewards exist. ESO cannot fetch website updates directly; refresh this file in addon releases, while live ESO metadata continues to classify new openings. Settings provides user-initiated links to UESP and Bethesda Support.




GemCatalog.lua bundles explicit UESP extraction statements for exact item-ID and reward-stack combinations, with source revisions and the Resplendent Sweetroll exception. Tooltips prefer live backpack values, then label offline values as catalog references. Missing values stay unverified. This reference applies to Crown Crate rewards, not identically named items acquired elsewhere; potential extraction values never increment earned gem totals.

## PC_NA and PC_EU

History, crate observations, statistics, diagnostics, and wishlists use separate account-wide megaserver profiles. The title identifies PC_NA or PC_EU. A cyan account label close to the server label in size shows the current ESO @UserID; Settings > Browsing and visibility > Show account name can hide it for screenshots. This display preference does not affect history or account separation. Addon preferences share an account-wide Codex Shared profile, so changing a setting on one server carries over on the next login to the other. ESO keybinding preferences are managed by ESO itself.

Migration preserves existing histories in place and adopts preferences from the profile with the largest existing history on first upgrade. Legacy seed and Tracker record ownership prevent copying the same imported records into both profiles. Tracker did not record megaserver identity: previously mixed history cannot be reliably separated after the fact. Existing Codex locations are preserved; baseline unlabelled Tracker history is assigned to the existing primary profile rather than duplicated. Newly seen Tracker records are associated with the current server when synchronized. Keep Codex enabled while opening crates for reliable server attribution. No history is deleted during migration.

Controller prompts use ESO's device-aware key textures rather than generic Gamepad Button 1/2 names. The footer includes select/back, Collections, options, details, D-pad movement, tab shoulders and page triggers, with text fallback if an icon is unavailable. Existing bindings and modifiers determine the displayed prompts; the addon does not rebind them. Initial user controller navigation testing succeeded; broader controller/device testing is still welcome.

The main Settings button explains that it contains language, appearance, controller and statistics preferences. Hover with the mouse or focus the button and use controller Details to read the hint.

### 0.12.3
Local-reference cleanup in settings, catalogs and translations. Crown Crate Codex reads Crown Crate Tracker by Faunter's externally owned CrownCrateData global at operation time; no additional addon global is created. SavedVariables identity, schema and history are unchanged.

### 0.12.4
Declared an optional library version constraint and synchronized release documentation. That constraint was incorrect; version 0.12.5 removes it. Crown Crate Tracker by Faunter remains a separate optional load-order dependency under its folder identifier CrownCrateLogger; no unsupported version number is invented. No saved-data changes.

### 0.12.5
Corrected OptionalDependsOn to use the plain LibAddonMenu-2.0 identifier. Optional dependencies cannot enforce >= version constraints. Settings registration checks LibAddonMenu2 availability; r43 remains the recommended/tested library release. No saved-data or recording changes.

### 0.12.6
Fixed Escape dismissal by registering Codex windows without locking ESO UI mode. Native top-level management still owns the cursor. Cursor/controller regression checks pass; live retesting is pending. No saved-data changes.
