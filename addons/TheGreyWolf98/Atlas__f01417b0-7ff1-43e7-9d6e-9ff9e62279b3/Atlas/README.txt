ATLAS 1.0.2
by @TheGreyWolf98

INSTALL / UPGRADE
Use ESO's console add-on upload/install workflow with Atlas-1.0.2.zip.
Select only this ZIP in the release form: previous file selections may
accumulate. The archive contains one Atlas/Atlas.addon manifest.
If upgrading from 0.1.5, reload UI after installing to clear its old input
registration. Existing account-wide Atlas settings are preserved.

REMOVE OVERLAPPING PINS
Remove or disable other add-ons providing the same skyshard, lorebook,
treasure-map, survey or boss pins to avoid duplicates. When retaining an
addon for uncovered features, disable its overlapping layers or the matching
Atlas layer. Votan's minimap may stay enabled. Native ESO map filters and
other add-ons' non-overlapping pins remain independent.

CONTROLS
/atlas opens or closes the panel. Optional Open Atlas keybinding available.
D-pad selects a switch: up/down wraps within a column; left/right changes
columns. A toggles; Y refreshes; B closes. Follow the corresponding ESO
prompts on PlayStation. PC users can click rows.
Analog left-stick navigation inside Atlas is not implemented.
/atlas refresh, /atlas all on, /atlas all off are also available.
All on/off affects thirteen layers; filtering preferences are preserved.

LAYERS / FILTERS
Thirteen layers: skyshards, Shalidor lorebooks, treasure-map digs, interior
bosses, delves, world bosses, public-dungeon entrances, dolmens/world events,
wayshrines, striking locales, Mundus stones, set crafting stations, surveys.
All fifteen switches fit on one panel. Counts apply to the viewed map.
Hide collected follows the current character's skyshards and known books.
Boss pins stay visible; account achievements are not character clear records.
Carried maps / surveys only checks this character's backpack, excluding
banks, housing and other characters. Maps/reports are still required to use
these sites. Settings are saved account-wide.

COVERAGE
Native skyshard and discovery data applies to the viewed map, including
undiscovered POIs where ESO supplies them. Wayshrine pins do not unlock
travel. Events are locations, not spawn tracking. Crafting means set sites,
not every city service station.

Recorded treasure/survey data includes a reusable snapshot and supplements
for High Isle, Blackwood, Galen, Necrom, Gold Road and Solstice. Shalidor
books use a historical snapshot plus recent-zone supplements. Coverage
varies by zone and map floor; no all-game completeness is claimed.
Eidetic Memory and side-quest starts are not included.

Interior bosses cover recorded delve/public-dungeon locations, including
recent-zone supplements. Group-dungeon boss interiors, including Graven
Deep and Earthen Root Enclave, remain incomplete. An achievement-derived
label may name the location rather than the individual boss. Source data
may contain gaps or inaccuracies. Report the zone, map floor and item/boss
name for missing or misplaced pins.

VALIDATION
Based on the console-tested 0.1.6 build: Galen carried-map filtering and
Gorne public-dungeon boss pins were confirmed in-game by the tester.
Lua syntax, manifest paths, XML bindings and simulated ESO integration pass,
including D-pad selection, scene-hide callback cleanup, saved settings,
backpack/collection filters, coordinate bounds and map changes. Both actual
ESO tooltip sorters and the native keybind dispatcher were exercised.
Atlas does not poll private directional input functions.

Source attribution and license notices are bundled. Release-Listing.txt
contains the overview and description for the addon listing.

1.0.2 VISIBILITY UPDATE
All Atlas pins increased from 24 to 28. Survey sites use a parchment scroll
with a red ring; treasure-map digs use a gold chest. Filters and locations
are unchanged. Check icon visibility on Xbox before publishing the update.

PERFORMANCE UPDATE 1.0.2
Atlas builds location lists and creates pins progressively with one shared
worker: at most 12 operations or about 2ms per 50ms tick. Each native layer
refresh/removal gets its own tick. Individual native calls cannot be interrupted.
Queued work pauses during combat, stops when idle and cancels on map changes.
Pins may fill in over a few seconds on maps with large location lists.

The viewed map is cached in memory only; saved settings remain unchanged.
Counts reuse cached lists instead of rescanning all enabled layers. The minimap
can read completed lists without triggering synchronous scans. Survey and
treasure layers share one backpack pass. Collection/discovery events refresh
only affected layers, with bursts merged into one pending refresh. Opening the
settings panel no longer forces another pin rebuild.

No external libraries added. Creator remains @TheGreyWolf98.
Validation: mocked operation/time budgets, complete pin sets, cache reads,
combat pause, targeted refresh, shared backpack pass, map-change cancellation,
toggle cleanup and idle worker removal passed. Live Xbox CPU-budget behaviour
still needs a test alongside the other enabled addons.
