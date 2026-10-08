# ZoneSweep 0.4.0

By @TheGreyWolf98. Current-zone checklist for ESO, with controller navigation.

Type `/zs` or `/zonesweep` to open. Type `/zs help` for instructions.

- Overview: D-pad selects a category; A opens it. LB/RB cycles categories.
- X switches all / unfinished activities on category lists.
- LT/RT pages, Y refreshes current progress, B closes.
- On personal record lists: D-pad selects a site; A ticks or clears its record.

Delves, world bosses, world events and group delves keep separate character records. Account completion totals are displayed separately and never imported. Earlier personal completion history cannot be recovered from account achievements; manually tick known earlier completions. Unknown means no record, rather than proof you have never done it.

Other categories use ESO's zone-guide progress. Named lists depend on available API data. Quest sites are not a complete side-quest checklist. Treasure maps, surveys and antiquity leads are outside this release.

Tracking has been tested on Xbox with base-game delves, a multi-boss world boss, a dolmen, a Blackwood world boss and a Blackwood delve. Saved progress survived character logout/login. This does not establish coverage of every encounter. Legacy multi-boss data uses English boss names.

For a missed completion, type `/zs debug` before the encounter, then reopen it afterward and capture the log pages. Debug capture resets when the addon reloads. Manual ticks provide a fallback.

Final console check: overview selection; LB/RB; X; D-pad/A tick and clear with Show all enabled; LT/RT on a long list; Y; B; `/zs help`. Confirm progress after a full game restart.

BossData.lua includes the MIT licence and attribution for data adapted from silvereyes' CharacterZoneTracker.
