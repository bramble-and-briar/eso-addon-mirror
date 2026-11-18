# Scoreboard Remastered (ESO)

An Elder Scrolls Online add-on that remasters the battleground scoreboard. It opens
over the native scoreboard, logs everything the native scoreboard tracks, adds fight
data for every player (your own from **LibFights**, everyone else from a per-player
combat ledger), and keeps a database of every match and every player you've met. That
database opens from the inventory, anywhere in the game.

## Screenshots (simulated)

> These are **renders of the add-on's own UI code, not in-game captures.** The add-on ran
> through eight simulated battlegrounds in a stand-in ESO client. Every control it built
> was recorded and laid out with ESO's anchor rules on ESO's 1920×1080 UI canvas, using ESO's
> real font sizes and colours. See [How the screenshots are made](#how-the-screenshots-are-made)
> for what is exact and what is approximated.

**PC: the panel over the battleground scoreboard, with the selected player's details**
![PC scoreboard](docs/screenshots/pc-scoreboard.jpg)

**Gamepad / console: "Open Remastered" on the battleground scoreboard's button bar**
![Open Remastered on the native scoreboard](docs/screenshots/gamepad-native.jpg)

**Console: Scoreboard Remastered, the PC table driven by the controller (details open with A / Cross)**
![Console table](docs/screenshots/console-table.jpg)

**Console: the list layout (setting), Players tab, with details in the right tooltip**
![Console scoreboard](docs/screenshots/console-scoreboard.jpg)

**Console: Kill feed tab with the death recap of the selected kill**
![Console kill feed](docs/screenshots/console-killfeed.jpg)

**Console: Match tab, your LibFights fights**
![Console match](docs/screenshots/console-match.jpg)

**Console: Battleground records, Matches tab**
![Records, matches](docs/screenshots/console-records-matches.jpg)

**Console: Battleground records, Players tab (opponents sorted by who killed you most)**
![Records, players](docs/screenshots/console-records-players.jpg)

**Console: Battleground records, Lifetime tab**
![Records, lifetime](docs/screenshots/console-records-lifetime.jpg)

**Gamepad inventory: Battleground records on the button bar**
![Gamepad inventory](docs/screenshots/gamepad-inventory.jpg)

**PC inventory: the Battleground records button**
![PC inventory](docs/screenshots/pc-inventory.jpg)

**PC: Battleground records with the mouse**
![PC records](docs/screenshots/pc-records.jpg)

## Install

Copy this folder into
`Documents/Elder Scrolls Online/live/AddOns/ScoreboardRemastered/`
(the folder name must match `ScoreboardRemastered.addon`). Works on PC/Mac and on
console (Xbox / PlayStation). Optional: LibFights, LibAddonMenu-2.0 (PC settings
panel), LibHarvensAddonSettings (console / gamepad settings panel).

## What it logs

From the native scoreboard, re-read on every `EVENT_BATTLEGROUND_SCOREBOARD_UPDATED`
and every 5 seconds:

- Battleground name, game type, team size, rounds, state, timer, your team
- Every team's name, color and score, plus per-round team scores
- Every player: character name, @account, team, class and class icon
- **Every score type the client defines:** all 20 `SCORE_TRACKER_TYPE_*` types in
  API 101051. A type ZOS adds later needs one line in `Data/Battleground.lua`.
- Medals per player (name, icon, count) and your own medals in the order you earned them
- A kill feed (`EVENT_BATTLEGROUND_KILL`): killer, victim, teams, ability, time
- Players who left mid-match are kept and marked *(left)*
- The result (victory, defeat, tie or left early) and the match duration

Fight data for **every player on the scoreboard**:

- **You:** [LibFights](https://github.com/0xsint/LibFights), summed across every fight in the
  match. That covers damage, healing, DPS/HPS (over active time), damage/healing taken, shields
  absorbed, mitigation, blocked damage, overheal, killing blows, deaths, interrupts and CC done
  and received, crit rate, max hit and its ability, light/heavy attacks, skills, ultimates,
  weaves, top damage and heal abilities with icons, and the number of fights.
- **Teammates and enemies:** a per-player combat ledger that records every combat event the
  client sends during the match. It gives damage done and taken, healing done and taken,
  DPS/HPS over each player's own active time, crit and heal-crit rate, max hit and its ability,
  killing blows, interrupts, CC applied and taken, shields absorbed, damage blocked, and top
  damage and heal abilities. It uses LibFights' own result categories, so both sources agree
  on what counts as damage, healing or CC.
- **You vs each player:** damage each way, healing each way, and kills each way. These are in
  every player's details pane; on PC they can also be shown as table columns (setting).
- **Death recaps for every kill** in the kill feed: the last hits the victim took before dying.
  Your own deaths also get LibFights' full recap.
- **A fight list** for the match (LibFights): title, duration, DPS, damage, healing, KBs and deaths.

**What the client can see.** ESO only sends combat events where the source or target is
you, your pet or a member of your group:

| Player | Coverage |
|---|---|
| You | complete |
| Teammates in your group | complete for everything they do and everything done to them |
| Enemies | everything they did to your team and everything your team did to them. Their healing, and fights with a third team in 3-team modes, aren't visible. Their healing shows "-", not 0 |

In 2-team modes, an enemy's damage done is all their damage. The native scoreboard's
Damage/Healing columns stay authoritative for everyone.

Matches are saved in `SavedVariables/ScoreboardRemastered.lua`
(`history`, 50 by default). A match still in progress (`current`) survives `/reloadui`.

## Using it

### PC with mouse and keyboard

- The panel opens and closes with the native battleground scoreboard. By default it sits
  **over** the board on a dimmed backdrop, because ESO's board is about 1300 px wide and
  there's no room beside it. `/sbr attach right|left|below` places it next to the board
  instead (kept on screen). Drag it to give it a fixed position (`/sbr reset` undoes this).
- **Click a row** to open its details beside the panel: medals, every fight stat, top
  abilities and the you-vs-them breakdown. Click the row again, or the X, to close.
- Click a column header to sort. Hover a header to see what it measures.
- **Fits any screen.** The panel sizes itself to ESO's UI canvas, which depends on your
  resolution and UI scale. If all the columns don't fit, the least important ones go
  first: you-vs-them, then minor score types (buffs, shields, flag-carrier healing...),
  then the less-used fight stats. Anything dropped is still in the details pane. With
  more players than fit, the mouse wheel scrolls the table. On a small canvas, the
  details pane opens over the panel. The records window scales down to fit.
- `<` `Live` `>` browse saved matches. **Export** gives a CSV and **Kill feed** gives
  the kill log, both in a pre-selected box ready for Ctrl+C.
- Keybinds: *Controls → Scoreboard Remastered*.

### Console, or gamepad mode on PC

While the native battleground scoreboard is open, its button bar gets
**Open Remastered** (right stick click by default; you can change it in settings).

**Scoreboard Remastered** is the same table as on PC, sized for the TV and driven by the
controller. Your row starts selected. A / Cross opens that player's details beside the
table, and they follow the selection as you move.

| Xbox | PlayStation | Action |
|---|---|---|
| Up / Down (D-pad or left stick) | same | move the selection (hold to repeat) |
| Left / Right | same | sort by the previous / next column |
| LT / RT | L2 / R2 | page up / down |
| A | Cross | show / hide details |
| Right stick | same | scroll the details |
| X | Square | flip the sort order |
| Y | Triangle | kill feed |
| LB / RB | L1 / R1 | older / newer saved match |
| L3 | L3 | group by team on / off |
| R3 | R3 | Battleground records |
| B | Circle | close details, then close the table |

The kill feed, the match summary and the records use ESO's own gamepad list screens
(`ZO_Gamepad_ParametricList_Screen`, the generic header with a tab bar, the right-side
tooltip). B from them goes back to the table with your selection and details as you
left them. **Settings → Gamepad: scoreboard layout → List** uses the list screen for
the scoreboard too:

- **Players:** grouped under team headers with team scores. X changes the sort.
- **Kill feed:** newest first, with killer, victim, killing blow and the last hits.
- **Match:** overview, your LibFights fights and your deaths.

**Smooth updates.** The table changes only what changed. A data update touches only the
numbers that moved (no rebuild), the header is laid out again only when the columns or
the sort change, rows that are scrolled out of view aren't filled, and bursts of updates
(scoreboard, kills, medals) become one refresh on the next frame. The selection stays on
the same player when the order changes, and stays in view.

Settings has an **Open Scoreboard Remastered** button so you can browse the last match
outside a battleground, since consoles have no slash commands. On console, 10 full
matches are kept by default because console SavedVariables are smaller.

### Battleground records: matches and players (open from the inventory)

A records screen usable anywhere, not just in battlegrounds:

- **Inventory:** on PC, a **Battleground records** button sits above the inventory window. On
  gamepad / console, **Battleground records** is on the inventory's button bar (right stick
  click by default; you can change it in settings). B / Esc returns to the inventory.
- **Also opens from:** R3 on Scoreboard Remastered, the settings panel,
  `/sbr db` and `/sbr players`.
- **PC:** a mouse-driven window. Click a tab, row or the filter line, use the mouse wheel
  to scroll, and double-click a match to open it.

**Matches tab:** every match you've played. Each finished match writes a compact record
(500 kept on PC, 150 on console), so this outlasts full scoreboards. On console the list
is grouped by date; the tooltip shows the result, team scores, K/D/A, damage, healing,
your rank, the match MVP, medals and top abilities.

**Players tab:** everyone you've shared a battleground with, including your own profile
across all your characters (2000 players kept on PC, 400 on console). Each player shows:
- whether they've been your **teammate**, **opponent** or both, and your win-loss record
  with them and against them
- their totals and per-match averages for kills, deaths, assists, damage, healing and
  score, plus K/D
- **you vs them:** how often they killed you and you killed them, damage each way and
  healing each way
- the classes they've played and their top abilities
- best score, medals, flags, the map you meet them on most, and their character names

Filters: everyone, teammates, opponents, players who've killed you, and you.
Sorts: most seen, last seen, kills, damage, healing, times they killed you, name.

**Lifetime tab:** win rate, K/D, times MVP, streak, bests and totals, then by class and by map.

| Xbox | PlayStation | Action |
|---|---|---|
| LB / RB | L1 / R1 | Matches / Players / Lifetime tab |
| Up / Down | same | select |
| LT / RT | L2 / R2 | page up / down |
| A | Cross | open the match's full scoreboard (Matches tab, while stored) |
| X | Square | change the filter |
| Y | Triangle | change the sort |
| B | Circle | back (to the inventory or the scoreboard) |

### Slash commands (PC)

| Command | |
|---|---|
| `/sbr` | toggle panel |
| `/sbr export` / `/sbr kills` | CSV / kill feed of the viewed match |
| `/sbr history [n]` | list saved matches / open match *n* |
| `/sbr live` | back to the live match |
| `/sbr db`, `/sbr players` | battleground records (matches / players tab) |
| `/sbr attach over\|right\|left\|below\|free`, `/sbr reset` | positioning |
| `/sbr status` | LibFights state and the score types detected |
| `/sbr hooks` | which native scoreboard scenes/fragments were hooked |
| `/sbr clear`, `/sbr debug` | clear history, toggle debug output |

## LibFights integration

Nothing needs configuring. When a battleground starts:

1. If LibFights isn't already logging, Scoreboard Remastered calls
   `Start_Logging({ rawEvents = false, saveFights = false })`.
   If another add-on or you already started logging, it shares that session and
   never stops it.
2. Every `FIGHT_ENDED` during the match is stored. Each snapshot also reads
   `LibFights.GetCurrentFight()`, so the panel stays live mid-fight.
3. Your row is built from `f:GetSummary()` and `f:GetAbilityBreakdown()`.
   `f:GetTargets()`, `f:GetSources()` and `f.healTargets` are a fallback for the
   you-vs-them columns if the ledger is turned off. Your death recaps come from
   the `DEATH` callback.
4. When the match ends, it calls `Stop_Logging()`, but only if it started the
   logging. That closes the running fight, so the last fight is counted too.
   Per-fight breakdowns are then reduced to a compact fight list, which keeps
   SavedVariables small.

Settings: *Use LibFights*, and *Also save fights in LibFights' SavedVariables* (off by
default, so battlegrounds don't fill your LibFights saved fights). Other players' stats
come from the combat ledger (*Fight stats for every player*), not from LibFights' group
mode, so LibFights runs in its lighter player-only mode.

LibFights drops fights shorter than its `minFightSeconds` (2s by default), so
very short skirmishes don't count toward the fight stats. The native scoreboard
columns are unaffected.

## How the screenshots are made

`tools/simulate.lua` runs the add-on and the real LibFights library in a stand-in ESO
client, plays eight battlegrounds, then drives each screen. Its control mock records
every call the add-on makes (`SetAnchor`, `SetDimensions`, `SetFont`, `SetColor`,
`SetText`, `SetTexture`, `SetHidden` and so on). `tools/render.js` lays those controls
out with ESO's anchor rules and draws them in a headless browser.

| | |
|---|---|
| **Exact** | Layout: positions and sizes come from the add-on's own code, on ESO's 1920×1080 UI canvas. All text and numbers come from the add-on's real output. Font **sizes** come from ESO's font definitions (`EsoUI/FontDefs`, western strings), for example `ZoFontGamepad34` = 34 px and `ZoFontWinH1` = 30 px. Colours are what the add-on sets, including ESO's stock text colours (`ZO_NORMAL_TEXT` C5C29E, `ZO_SELECTED_TEXT` FFFFFF). The gamepad button bar follows `KEYBIND_STRIP_GAMEPAD_STYLE`: ZoFontGamepad34, uppercase, 96 px insets, 53 px from the bottom, 128 px background. The console screens use ESO's quadrant layout (list in x 56–526, tooltip in x 1394–1864) and its tooltip styles (title 42 px, stat 27 px uppercase, value 42 / 34 px). Native positions also come from ESO's XML: the inventory window (565 px wide on the 575×750 right panel), the gamepad inventory panel (x 56–526) and the battleground board (~1124×810, centred). |
| **Approximated** | Font **faces**: ESO uses Univers 57/67 (keyboard) and Futura Condensed 47/57/87 (gamepad), which are licensed, so the renders use Barlow Semi Condensed and Barlow Condensed. ESO's art isn't redistributable, so backdrops, highlights and class, medal and ability icons are drawn as stand-ins. |
| **Stand-ins** | Anything ESO itself draws (the 3D world, the native battleground scoreboard, both inventories, the PC keybind strip) is simplified and labelled in the image. Only the add-on's controls are rendered from its code. |

Rendering the real layout at ESO's real font sizes found layout bugs that are now fixed:
- The PC panel was wider than the screen.
- With all 20 of the game's score types, the PC panel was 2506 px wide (ESO's canvas is
  1920 at most UI scales). Score columns now have short names and a priority, the table
  drops columns to fit the canvas, and the simulator uses the client's full score list.
- Column headers were truncated.
- The details pane and the records dialog ran into the gamepad button bar.
- The stat tiles drew their text badge over the icon.
- The gamepad button labels were too long for ESO's strip.
- Console tooltip rows ran off the right edge of the screen. ESO sizes a tooltip line or
  stat / value pair to its text unless its style gives it a width, and never wraps or
  truncates it. Every row now uses ESO's `fullWidth` style, so long text wraps inside the
  tooltip, and long labels are shortened. The renderer applies the same sizing rules and
  warns about any row that ends past the tooltip's edge.
- The first custom console panels didn't look like ESO's console UI. They were replaced
  with ESO's own gamepad list screen, header and tooltip.

## Checked against the ESO UI source

The add-on was checked against ZeniMax's published UI source and API documentation
(esoui/esoui, API 101051). That covers every game function, event, constant, font,
control template, texture path and scene name it uses. Fixed as a result:

- **Team scores:** `GetCurrentBattlegroundScore` takes `(roundIndex, team)`.
- **Medals:** they are read through `GetNextScoreboardEntryMedalId` and, for whole-match
  totals, the cumulative medal API, exactly like ESO's own medal panel. The medal
  functions guessed earlier don't exist.
- **Class icons:** `ZO_GetClassIcon` (`GetClassIcon` is a PC-only alias).
- **Names and modes:** team names use `GetBattlegroundTeamName`, the game type uses
  `GetCurrentBattlegroundGameType`, and multi-round matches are decided by rounds won.
- **Gamepad "Open Remastered" button:** ESO's battleground scoreboard doesn't push the
  UI shortcut key layer, so the button could never fire. The add-on now pushes that layer
  while the scoreboard is open. Keys no button claims still pass through to the game.
- **PC records screen:** it uses `FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW` (cursor,
  keybind strip, shortcut layer).
- **Stat-tile icons:** three icon paths didn't exist. They're replaced with art the game's
  UI references.
- **PC panel placement:** the native scoreboard's top level fills the screen, so
  "attach right" was off screen. The default is now "over", and the side placements
  measure against the visible board.

None of the game functions the add-on calls are **private** (ZeniMax-only, like `IsKeyDown`)
or **protected** (blocked in combat). `tools/check-api.py` checks this against
`ESOUIDocumentation.txt` and fails if one is added:

```sh
python3 tools/check-api.py <path-to>/esoui/ESOUIDocumentation.txt
```

### Regenerating the simulation and screenshots

```sh
lua5.1 tools/simulate.lua . <path-to>/LibFights out/match.json out/screens.json
node tools/render.js out/screens.json docs/screenshots   # needs Playwright + Chromium
```

`SIM_GUIROOT=1366x768` (or any size) runs the simulation on a smaller UI canvas, as
with a low resolution or a large UI scale, and the renderer draws at that size.

## Performance

The add-on keeps its work small enough for ESO's per-frame add-on budget (which consoles
enforce strictly):

- **Combat log:** it registers `EVENT_COMBAT_EVENT` once per result type it counts, with
  the game's result filter, so effects, power changes, misses and the rest never reach
  Lua. Names are formatted once (`zo_strformat` is slow) and cached, and death-recap
  entries are reused instead of allocated per hit.
- **Snapshots** (reading the native scoreboard): at most once a second while a
  scoreboard is on screen, every 4 seconds otherwise, plus a 15-second fallback. The
  reader calls the game directly (about 500 values per snapshot), caches class and medal
  info, and doesn't deep-copy stats that are already plain tables.
- **Load:** nothing walks the global table. Score types, fragments and scenes are
  looked up by their known names.

`SIM_PROFILE=1` makes the simulator print the time spent in the hot paths. Over eight
simulated matches, the changes above cut snapshot time from 5.1 s to 1.6 s (2479
snapshots down to 958, each 20% cheaper) and combat-event time by 45%. The combat
filter's saving is larger in game than in the simulation, which only sends the results
the add-on counts.

If you still see the warning, turn off **Fight stats for every player (combat ledger)**
(`trackCombat`) in settings. That removes the combat-log handler entirely and keeps
LibFights' data for your own row.

## Notes

- The combat ledger is saved with the in-progress match, so `/reloadui` mid-match keeps
  it. It is dropped when the match ends, since each player's row already holds the totals.
- Battleground teams are normally grouped. If a teammate isn't in your group, they only
  get the stats from their interactions with you.
- Every game API call is protected. If ZOS renames a function, that column goes
  empty and nothing errors. (The scoreboard reader, which runs every snapshot, calls
  the game directly inside one protected call instead, to save CPU.) If the panel doesn't open with the scoreboard, run
  `/sbr hooks` and add the scene or fragment name to `UI/ScoreboardHook.lua`.
- The gamepad view uses ESO's standard gamepad building blocks: its own scene, the
  keybind strip, directional input and the movement controller. Like the rest of the
  add-on, it hasn't been run on a console yet. If a button doesn't show up, the
  settings panel has the open button and the open-key choice.
- The inventory hooks use the `inventory` (PC) and `gamepad_inventory_root` (gamepad) scenes.
  `/sbr hooks` shows whether both were found.
- The panel uses ESO's own text colours (`ZO_NORMAL_TEXT`, `ZO_SELECTED_TEXT`, `ZO_DISABLED_TEXT`)
  and stock list textures (row highlight, selected highlight, divider, sort arrows from
  `EsoUI/Art/Miscellaneous/`). Each texture sits on top of a plain colour, so if a path
  changes in a game update the panel still reads correctly, just with less polish.
- `## APIVersion` is set to 101051, the API version of the ESO UI source the add-on was
  checked against. Update it if your client differs (`/script d(GetAPIVersion())`).
