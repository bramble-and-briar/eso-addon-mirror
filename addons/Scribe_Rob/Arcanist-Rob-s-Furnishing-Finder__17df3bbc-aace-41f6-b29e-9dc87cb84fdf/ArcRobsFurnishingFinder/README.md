# Arc Rob's Furnishing Finder

Version 0.1.2 — compact saved records and reusable search results to reduce memory use. No library dependencies.

Updating from 0.1.0 or 0.1.1 preserves your scans. Existing records convert automatically to a shared furnishing catalogue and per-location quantities. SavedVariables version remains 1 deliberately so existing data is loaded for conversion. Do not delete your saved data when upgrading.

Search furnishings you own in a dark-and-gold table inspired by the supplied Antiquity Tracker screenshots. Each result shows an ESO item icon, furnishing name, quantity, location, character (where relevant), and last-checked time. One result represents one furnishing type at one recorded location. Selecting a row shows its name and location beneath the table.

## Install

1. Close ESO or return to character selection.
2. Extract the ZIP. Copy the entire `ArcRobsFurnishingFinder` folder into the `AddOns` directory for the ESO client you use. Keep the manifest files directly inside that folder, without an extra nested folder.
3. Enable **Arc Rob's Furnishing Finder** in the game's Add-Ons menu, then log in.
4. Type `/ff` or `/furnishingfinder` to open it. Alternatively, assign **Open / close Furnishing Finder** in Controls → Keybindings → Arc Rob's Furnishing Finder.

Both `.txt` and `.addon` manifests are included for the respective client formats. The existing managed Antiquity Tracker installation is not modified. Managed console distribution requires the platform's normal add-on publishing process; this ZIP is source for local testing, not a signed/published console package.

For the pccert client shown in the supplied files, your local test AddOns directory exists at:

`C:\Users\Rob\Documents\Elder Scrolls Online\pccert\AddOns`

## First use

- Log into each character to record their inventory.
- Visit each house you own to record placed furnishings. Wait briefly for loading before leaving.
- Open your bank to record the bank and ESO Plus bank storage.
- Open each housing storage chest or coffer to record its contents.
- Open the Furniture Vault, if available, to record it.

Records are shared across your characters on the same account and server. A character or house that has never been visited with this add-on enabled cannot appear in its results. Other players' houses and housing previews are excluded. The Finder shows the house name; use the house's Retrieve menu to find the furnishing inside it.

Storage chests are shared account storage, so they appear by chest name rather than being duplicated under each house containing that chest. Collectible furnishings are counted where placed, not as a separate list of unlocked collectibles. These can be placeable in several houses, so their counts describe placements.

## Keyboard and mouse

- Type a furnishing name in **Search name**. Matching ignores case and treats punctuation literally.
- Click the location filter to cycle All, Houses, Character inventories, Bank, Storage, and Furniture Vault.
- Click a column heading to sort; click it again to reverse the order.
- Scroll the mouse wheel or use the up/down buttons to move through results.
- Click a row to select it. Hover a row for its full name, location, and last-checked time.
- **Scan** or `/ff scan` refreshes the currently accessible locations.
- `/ff stats` reports recorded locations and furnishings, plus the total shared add-on memory pool when available. The memory figure covers all add-ons, not just the Finder.
- **Clear** removes the search text. The close button or the scene's Back action closes the window.

## Controller

Use the configured open/close binding. When the existing Tracking Tools hub from the other add-ons is available, the Finder also registers there.

- Left stick: move through results. D-pad input is excluded because its ESO input path calls a private function on managed clients.
- Left / right trigger: previous / next page.
- Primary action: focus search using ESO's gamepad edit-box handling.
- Secondary action: scan accessible locations.
- Tertiary action: next location type.
- Right-stick click: clear search.
- Left-stick click: switch name / location sorting.
- Back: close.

Action names follow ESO's configured controller layout and appear in its keybind strip. Search text entry depends on the keyboard or virtual keyboard provided by the running client.

## Keeping records accurate

The **Checked** column shows the age of a saved location snapshot. Inventory changes update the active character's record; bank and chest snapshots update while accessed; placed-house records refresh after placing or retrieving furnishings. Older records remain available while you are elsewhere. Visit/open a location again to refresh it, especially after playing without the add-on enabled. **Scan** cannot remotely inspect an offline character or an unvisited house.

ESO saves SavedVariables during normal logout or `/reloadui`. If the game crashes before saving, the latest changes may be lost. Incomplete or interrupted house scans keep the previous house record.

## Validation

Validated in a Lua 5.1 runtime against mocked ESO APIs: syntax, XML parsing, furnishing-only filtering, stack aggregation, item removal, final bank-transfer updates, character isolation, separate bank/Plus/chest/vault records, literal search, location filtering, house ownership and preview guards, empty houses, chunked house scans, scan cancellation on travel, incomplete-scan preservation, UI creation, scene lifecycle, sorting, and gamepad search-focus callbacks.

This build has not been run inside ESO. Live appearance, actual controller input / virtual keyboard behavior, and scanning against your account need an in-game check.

Version 0.1.2 was also stress-tested with 100 simulated houses, 5,000 furnishing types, and 70,000 furnishing/location records in a standalone Lua 5.1 runtime. Estimated Lua heap for the saved records fell from about 31 MB to 6.5 MB; with the results table open it fell from about 83 MB to 15 MB. These figures compare the previous and compact data structures in the test harness, not the live ESO add-on memory pool. Repeated result rebuilds did not retain additional allocations. See `memory-validation.json` for the recorded measurements.

Low-memory warnings may still occur if the shared add-on pool fills. `/ff stats` can help report overall pool usage. Updating reduces the Finder's footprint but does not increase the game's memory limit. Existing large saved data still has to load once before conversion; if the client disables add-ons before conversion can run, that requires separate recovery.

Quick in-game check: open `/ff`, search for a known furnishing, visit its house, open your bank, transfer one furnishing, then log into a second character. Confirm quantities and locations update, and that saved results survive `/reloadui`.

## API references

- [ESO UI source and API documentation](https://github.com/esoui/esoui/tree/live)
- [ESO directional-input implementation](https://github.com/esoui/esoui/blob/live/esoui/libraries/zo_directionalinput/zo_directionalinput.lua)
- [ESO gamepad edit-box templates](https://github.com/esoui/esoui/blob/live/esoui/libraries/zo_templates/editboxtemplates_gamepad.xml)

The add-on only reads inventory / housing information and stores its own records. It does not move, retrieve, place, or destroy furnishings.
