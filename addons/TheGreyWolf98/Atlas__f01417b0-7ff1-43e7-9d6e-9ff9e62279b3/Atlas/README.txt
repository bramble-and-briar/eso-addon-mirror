ATLAS 1.0.3
by @TheGreyWolf98

INSTALL / UPGRADE
Use ESO's console add-on upload/install workflow with Atlas-1.0.3.zip.
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
All seventeen switches fit on one panel. Counts apply to the viewed map.
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
For 1.0.2, local checks cover both palettes, both pin sizes, immediate
refresh, layer filtering, decorative tooltip exclusion and all 17 switches
in D-pad navigation. API layout/tint handling was checked against ESO UI
source. These checks do not establish Xbox appearance or CPU performance.
Atlas does not poll private directional input functions.

Source attribution and license notices are bundled. Release-Listing.txt
contains the overview and description for the addon listing.

1.0.1 VISIBILITY UPDATE
All Atlas pins increased from 24 to 28. Survey sites use a parchment scroll
with a red ring; treasure-map digs use a gold chest. Filters and locations
are unchanged. Check icon visibility on Xbox before publishing the update.

1.0.2 VISIBILITY OPTIONS
Neon colours adds vivid coloured rings around the existing symbols. It is
enabled by default on upgrade; switch it off to restore the original palette.
Larger pins increases symbols from 28 to 42 (50% larger), with matching rings.
It defaults off. Both switches are in /atlas and apply immediately. Settings
are account-wide. Layer/filter preferences are preserved. Only Atlas pins
are resized; native ESO pins and other addons are independent.
The panel now holds all 17 switches in two columns of up to nine rows.
Neon rings are decorative and do not add duplicate tooltip entries.
Local checks cover both palettes, sizes, refreshes, and navigation.
Confirm colour visibility and size on Xbox before replacing the public build.

1.0.3 LIVE DISCOVERY FIX
Location discovery, POI updates, objective completion and wayshrine unlocks
now trigger a debounced pin refresh. No movement or UI reload required.
Existing settings, neon colours and larger-pin switch are preserved.
