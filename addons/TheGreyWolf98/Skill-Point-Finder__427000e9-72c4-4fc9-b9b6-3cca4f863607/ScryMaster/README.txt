Scry Master 1.0.2
By @TheGreyWolf98

UI UPDATE
Atlas colours and borders, larger explicit gamepad fonts, and a Socials / Support page with Ko-fi QR. Click the left stick from the main menu to open Socials; B returns to the add-on. Search is now on right-stick click. Other controls and saved-variable identities are retained.

Open /sm. Upload ScryMaster.addon through the Bethesda uploader.
Ko-fi: https://ko-fi.com/thegreywolf98
Instagram: https://www.instagram.com/thegreywolf_98/
Discord: https://discord.gg/Fp9RSaeU8h

Local checks cover packaging, Lua syntax and UI navigation in a mocked environment. Xbox testing is still required.

EXISTING INSTRUCTIONS
SCRY MASTER 1.0.2 - CONSOLE TEST BUILD
by @TheGreyWolf98

OPEN
/sm or /scrymaster
Optional keybind: Controls > Scry Master > Open / close Scry Master.
No libraries or other add-ons required. Manifest targets API 101051.

DISPLAY
CraftMaster-inspired dark, two-column layout with 30px list names,
26px supporting text, selectable zones and paged results.
All zones, Current zone, Mythics and Mythics & sets are followed by an
alphabetical zone list.
Mythics lists finished mythic names. Select a parent row and press A to
expand all fragments, each with its excavation zone, digs and codex.
Mythics & sets also includes multi-part furnishings and other rewards.
Mythic classification uses ESO's orange antiquity-set quality.
The full component list is requested for each detected set, including
components not supplied by the main antiquity iterator. Duplicate fragments
are suppressed. No visibility, discovered-lead or dug-before filter is used
to construct the base catalogue.
Each antiquity/fragment has its own row, including never-dug entries
returned by the game's catalogue. New game data is enumerated at runtime.

Filters: All, Never dug, Dug before, Codex unfinished, Codex complete,
Lead ready, Need a lead. Lead ready includes entries requiring no lead;
it does not promise the player has the zone access or scrying skill.
Search matches antiquity name, excavation zone and set/reward name.
Search and status filters apply within the selected zone.
The summary counts the selected zone/category independently of search/filter.
In grouped categories, status filters select parent sets; expanding a matching
set shows every fragment so that the whole checklist stays visible.
Never dug means no fragments dug; Dug before means at least one fragment dug.
Lead ready means at least one ready fragment; Need a lead means at least one
fragment still needs a lead. A set can match both lead filters.
Search can find a parent through its own name, a fragment name or dig zone.

Dug is ESO's excavation count. Codex is ESO's unlocked lore count against
the actual available total: 0/3, 1/3, 2/3, 3/3, or another game-defined total.
Zero-lore entries show n/a and are excluded from both codex filters.
Uses the live values supplied by ESO for the logged-in player; no invented
history or extrapolation from digs, and no cross-character saved cache.
Zone categories count individual fragments. Grouped categories count parent
sets in the summary, while the row/page count includes expanded children.
A parent shows fragments dug and aggregated codex entries, e.g. 3/5 fragments
and 4/15 codex. The full excavation-set count is the lowest component dug
count, matching the native set model. It is not an inventory/ownership check.
A partial or unavailable component list is never marked fully dug or codex
complete. Existing progress is read directly from ESO, with no saved reset.

CONTROLLER
Left stick up/down: move through the focused column, across page edges.
Left/right: switch between zone and antiquity columns.
A: apply the highlighted category, or expand/collapse a parent mythic/set. X: cycle status filter. Y: refresh.
Search button uses ESO's native gamepad edit box (shown in keybind strip).
LB/RB: previous/next page in the focused column. B: close.
Mouse users can click rows/buttons and use the wheel in either column;
click a row in that column to focus it first.

PERFORMANCE
Reads only while open, on opening and relevant game updates/manual refresh.
Small batches: at most 16 entries or a 4ms elapsed budget per update.
Pauses reads during combat, stops all its timers on closing, no chat spam.
A complete snapshot stays visible while a new snapshot is being read.

LEAD LOCATIONS - SCOPE OF THIS BUILD
The excavation zone is shown. Lead held/needed/no-lead-required status and
rounded remaining hours are shown for the selected entry.
Lead DROP sources (bosses, chests, fishing spots, dungeons, etc.) are not
included: the native antiquity API does not provide that catalogue.
The details explicitly say that the drop source is not catalogued.
A verified, distributable source dataset is needed for a later update.

INSTALL / UPLOAD
The ZIP contains one ScryMaster directory with the .addon manifest at its
root, matching the console format used by CraftMaster. Use your usual
console add-on upload workflow. This package has not run inside ESO yet.
PC: extract ScryMaster into the live/AddOns directory and reload UI.

FIRST IN-GAME CHECKS
1. Open /sm outside combat. Check it fits with the controller button strip.
2. Choose a familiar zone with A. Compare dug counts and codex fractions
   for several entries against ESO's own Antiquities journal.
3. Choose Mythics. Check a known mythic by its finished name, including
   one you have never found. Press A on it and check all fragments/zones.
4. X through Never dug / Codex unfinished / Codex complete.
5. Hold the stick down to cross a page; switch columns; try LB/RB.
6. Obtain a lead, reopen and check its status. Dig an antiquity, reopen,
   and check that its excavation and codex counts update.
7. Close, reopen in combat and leave combat: reads should resume.
8. Test a long antiquity/set name and a UI scale you normally use.

VALIDATION
Lua syntax passed. Mocked ESO API and UI tests passed for all seven
filters, zone/set/name search, 1-entry and 0-entry codices, asynchronous
refreshes, full mythic/other-set grouping, omitted iterator components,
deduplication, missing-data guards, aggregate filters/search/codex counts,
combat pause, hidden-window cancellation, expansion, navigation and scene
cleanup. Controls were instantiated at logical 1920x1080 and 1280x720.
Actual console rendering, input and account/character scopes require
in-game verification; mocks cannot establish those.

API REFERENCE
ESO's distributed UI source mirrored by ESOUI, live branch, retrieved
15 October 2026:
https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt
https://github.com/esoui/esoui/blob/live/esoui/ingame/antiquities/antiquitydata.lua
https://github.com/esoui/esoui/blob/live/esoui/ingame/antiquities/antiquitydatamanager.lua
https://github.com/esoui/esoui/blob/live/esoui/ingame/antiquities/antiquitysetdata.lua
Only documented API calls and the user's CraftMaster interaction pattern
are used. No external add-on lead database is bundled.
