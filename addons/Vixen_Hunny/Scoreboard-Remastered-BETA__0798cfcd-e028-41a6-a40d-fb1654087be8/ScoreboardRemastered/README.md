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

**PC: Scoreboard Remastered in place of the battleground scoreboard, with the selected player's details**
![PC scoreboard](docs/screenshots/pc-scoreboard.jpg)

**Gamepad / console: the scoreboard key opens Scoreboard Remastered (details open)**
![Open Remastered on the native scoreboard](docs/screenshots/gamepad-native.jpg)

**Console: Scoreboard Remastered, the PC table driven by the controller (details open with A / Cross)**
![Console table](docs/screenshots/console-table.jpg)

**Console: the list layout (setting), Players tab, with details in the right tooltip**
![Console scoreboard](docs/screenshots/console-scoreboard.jpg)

**Console: Kill feed tab with the death recap of the selected kill**
![Console kill feed](docs/screenshots/console-killfeed.jpg)

**Console: Match tab, your LibFights fights**
![Console match](docs/screenshots/console-match.jpg)

**Console: Battleground records, the same window as on PC, Matches tab**
![Records, matches](docs/screenshots/console-records-matches.jpg)

**Console: Battleground records, Players tab**
![Records, players](docs/screenshots/console-records-players.jpg)

**Console: Battleground records, lifetime stats (Y / Triangle)**
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
(`history`, 20 by default, 10 on console). A match still in progress (`current`) survives `/reloadui`.

## Using it

### PC with mouse and keyboard

- The scoreboard key opens the panel in place of ESO's board (see above). On the
  end-of-match board, or with the replacement turned off, it opens **over** ESO's board
  on a dimmed backdrop. `/sbr attach right|left|below` places it next to the board
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

### Round-based modes (Elimination)

Like ESO's own board, the add-on reads the **current round**. In multi-round modes it
shows **whole-match totals** (the game's cumulative scores). In limited-lives modes it
adds a **Lives** column and greys out eliminated players ("out"), and the team blocks
show rounds won. `SIM_ELIMINATION=1 SIM_AFTER=tools/test-elimination.lua` runs the
simulator in a 3-round, limited-lives mode. It checks that the totals keep growing
past round 1, which is what broke before 1.9.1.

### The look

The scoreboard uses the game's own battleground art, like the battle report:

- **Header:** your team's emblem on a glow, and your team's banner across the top (win
  or loss once the match ends, the team scoreboard background while it runs).
- **Teams:** each team is shown as its emblem and score, in team colour.
- **Column headers:** icons for score, kills, deaths, assists, damage, healing and medals.
- **Rows:** every row sits on its team's scoreboard background with a team-coloured
  edge. Your row gets the team's highlight strip, and the top scorer gets a medal.
- **Details:** the pane leads with the player's team emblem and class icon.

### It replaces the native scoreboard

The scoreboard key now opens Scoreboard Remastered instead of ESO's in-game battleground
scoreboard, on PC and console. It's the same toggle as before: you can still move and
fight while it's up, and the same key closes it. Buttons on the bar while it's up:

| Button | Action |
|---|---|
| Scoreboard key | close |
| Leave key | leave the battleground (ESO's own confirmation) |
| Previous / next player keys (D-pad up / down) | move the selection (hold to repeat) |
| D-pad left / right | sort by the previous / next column (gamepad) |
| Player options key | show / hide the selected player's details (gamepad) |
| R3 | full screen: everything below, including kill feed, history and records (gamepad) |

Only keys the native board already uses are taken, plus D-pad left / right and R3, so
attacks, block and abilities keep working with the board up. On PC, in UI mode (cursor),
the mouse works as below. The **end-of-match** scoreboard stays ESO's, because it has the
round summary and the queue options. There the panel opens over it (PC), or **Open
Remastered** (R3) is on its button bar (gamepad). Turn **Settings → Replace the native
scoreboard** off to get ESO's board back.

How it's done: ESO's two in-game scoreboard scenes stay ESO's. The add-on only takes
the native board fragment and its match-info panel out of them, shows the table in
their place, and swaps the native buttons for its own. Nothing of ESO's is wrapped and
no key layer is pushed (see [The "insecure code" error](#the-insecure-code-error)).

### Console, or gamepad mode on PC

**Full screen** (R3 on the board, or from the settings) is the same table as on PC, sized
for the TV and driven by the controller. Your row starts selected. A / Cross opens that player's details beside the
table, and they follow the selection as you move.

| Xbox | PlayStation | Action |
|---|---|---|
| D-pad up / down | same | move the selection (hold to repeat) |
| D-pad left / right | same | sort by the previous / next column |
| LT / RT | L2 / R2 | scroll the details when they're open, else page up / down |
| A | Cross | show / hide details |
| X | Square | flip the sort order |
| Y | Triangle | kill feed |
| LB / RB | L1 / R1 | older / newer saved match |
| L3 | L3 | group by team on / off |
| R3 | R3 | Battleground records |
| B | Circle | close details, then close the table |

Battleground records (R3) is the same window as on PC too. The kill feed and the match
summary use ESO's own gamepad list screens (`ZO_Gamepad_ParametricList_Screen`, the
generic header with a tab bar, the right-side tooltip). B from any of them goes back to
the table with your selection and details as you left them. **Settings → Gamepad:
scoreboard layout → List** uses the list screens for the scoreboard and records too:

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

### Battle report

When you leave a finished battleground, the battle report opens (setting **Battle report
after each match**). It also opens with A / double-click on a match in the records, the
**Report** button (PC) or the menu button (console) on the scoreboard table, and
`/sbr report`. It has three tabs (LB / RB, or click):

- **Overview:** the result, a **match balance** from 0 to 100 (red for a stomp, green for an
  even fight: how close the final scores were, plus how often the lead changed hands),
  team totals, the MVP, and every player's **title** for the match. A title is the stat
  where that player came closest to the best in the match: Slayer, Vanguard (damage),
  Lifeline (healing), Wingman (assists), Objective runner, Medalist, or Unbreakable (no
  deaths).
- **Timeline:** score over time, the damage race (team damage done) and momentum (kills
  per minute, one team above the line, the others below), in team colours.
- **Your match:** what it earned you (Alliance Points, experience including champion
  XP, Champion Points, medals, Alliance rank, and a rank-up), your title, your medals,
  and your profile against the best player in each category.

**Sharp at any size.** Bars, backgrounds, banners and chart bars are drawn as plain
shapes with smooth colour gradients (`SetVertexColors`) instead of stretched textures,
so they stay sharp at any resolution and UI scale. Icons are never drawn larger than
their file. Large icons use the game's gamepad files, which are the high-resolution
ones: team emblems, class icons, stat and title icons, and the AP currency icon.
Keyboard-size icons are kept at 40 px or less. The percentage bars have a dark track,
a gradient fill, a highlight and quarter tick marks, with the value beside them, and
they all fit inside the panel.

It's drawn with the game's own battleground art rather than text where it can be: your
team's emblem and win / loss banner across the header, the round-recap header art,
each team's scoreboard background and emblem on its card, the capture-bar fills (in
team colours) for every chart and progress bar, highlight strips for your row, title
and stat icons, the Alliance Points / experience / Champion / rank / medal icons, and
a soft glow behind the MVP, your title and the active tab. Every texture path is
checked against the ESO UI source. The screenshots draw stand-ins for that art,
because ZeniMax's art files can't be redistributed.

A (Cross) or the Scoreboard button opens the full scoreboard while the match is stored.
Recording costs almost nothing: one small sample of team totals every 15 seconds, taken
with the normal scoreboard snapshots, saved packed with the match.

**Records button (PC):** a small draggable battleground icon on the HUD that opens the
records. Turn it off with **Records button on screen**.

![Battle report, overview](docs/screenshots/pc-report-overview.jpg)
![Battle report, timeline](docs/screenshots/pc-report-timeline.jpg)
![Battle report, your match](docs/screenshots/pc-report-you.jpg)
![Battle report on console](docs/screenshots/console-report.jpg)

### Battleground records: matches and players (open from the inventory)

A records screen usable anywhere, not just in battlegrounds:

- **Inventory:** on PC, a **Battleground records** button sits above the inventory window. On
  gamepad / console, **Battleground records** is on the inventory's button bar (right stick
  click by default; you can change it in settings). B / Esc returns to the inventory.
- **Also opens from:** R3 on Scoreboard Remastered, the settings panel,
  `/sbr db` and `/sbr players`.
- **The same window on PC and console.** On PC it's mouse-driven: click a tab, row or
  the filter line, use the mouse wheel to scroll, and double-click a match to open it.
  On console it's driven by the controller (table below). **Settings → Gamepad:
  scoreboard layout → List** uses ESO's gamepad list screen instead.

**Matches tab:** every match you've played. Each finished match writes a compact record
(500 kept on PC, 150 on console), so this outlasts full scoreboards (20 on PC, 10 on console). The card shows the
result banner, team scores, six stat tiles, your rank and the match MVP, medals and top
abilities. Y / Triangle switches to lifetime stats: win rate, K/D, bests, by class and
by map.

**Players tab:** everyone you've shared a battleground with, including your own profile
across all your characters (1000 players kept on PC, 400 on console). Each player shows:
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
| LB / RB | L1 / R1 | Matches / Players tab |
| D-pad up / down | same | select (hold to repeat) |
| D-pad left / right | same | change the filter |
| LT / RT | L2 / R2 | page up / down |
| A | Cross | battle report of the match (Matches tab, while stored) |
| X | Square | change the sort |
| Y | Triangle | match card / lifetime stats (Matches tab) |
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

## The "insecure code" error

Earlier versions could trigger ESO's *insecure code* error on console, typically when
using the D-pad on the battleground scoreboard. Three things put add-on code into ESO's
own (protected) input handling, and all three are gone:

- **Hooks on the native scoreboard.** `ZO_PostHook` replaced methods of ESO's scoreboard
  objects with add-on code, so the scoreboard's D-pad player selection and player
  options ran through it. The add-on now only listens to scene and fragment state, and
  reads data from `EVENT_BATTLEGROUND_SCOREBOARD_UPDATED`.
- **A pushed key layer.** To make "Open Remastered" work, the add-on pushed ESO's UI
  shortcut layer over the scoreboard, and that layer also handles the D-pad and A. The
  button is now an action in the scoreboard's own `BattlegroundScoreboard` layer
  (`Bindings.xml`), which takes its key from the R3 / L3 / menu shortcut. No layer is
  pushed.
- **`DIRECTIONAL_INPUT`.** The table and the records read the stick every frame from inside
  ESO's input loop. They now use ESO's D-pad keybinds (`UI_SHORTCUT_INPUT_*`) with
  their own hold-to-repeat, like any keybind button.

None of the functions the add-on calls are private or protected (`tools/check-api.py`).

## Performance

### Loading (`/reloadui`, login)

A saved-variables file is Lua code that ESO runs on every load, before any add-on
code, inside the add-on's load-time CPU budget ("CPU budget reached"). Every saved table
and field costs time there, while a long string costs almost nothing. So:

- **Packed storage:** every finished match, record and player is saved as a few
  strings (`SBR.Pack` in `Util.lua`, at most 1900 bytes each, because ESO keeps saved
  strings only up to about 2000 characters). Only an id and a timestamp stay readable
  so lists can be sorted and searched. Each one is unpacked the first time something
  reads it (a typical match takes about 2 ms), never all at load.
- **Less saved:** recaps as one string per hit, kills and medals with only the shown
  fields, and players with abilities and classes as numbers.
- **Fewer full scoreboards:** 20 by default on PC (was 50) and 10 on console. Every
  older match is still in Battleground records as a summary. A setting you changed
  yourself is kept. The player index keeps 1000 players on PC (was 2000) and 400 on
  console.
- **No load-time work:** the windows are built the first time they open, and nothing
  scans the global table.
- **Older saves** convert in the background after login, one small step every 200 ms
  (about a minute for 30 old matches): history trimmed, matches, records and players
  packed, forgotten match ids and extra players dropped. Then the next save is small.

In the simulation (8 matches), the saved data went from about 22,000 tables to about
400. A 1.3-format test save with 30 matches and 1200 players went from 13,151 tables to
1,081. `lua5.1 tools/test-savedvars.lua` tests packing, recaps and converting an old
save. `SIM_AFTER=tools/test-reload.lua` (with the simulator) saves, reloads and
compares every match, record and player.

### Load report

After every login and `/reloadui`, the add-on times its own load: each of its files,
each setup step and the first steps after login. It also records when every add-on
finishes loading. If its own part took 100 ms or more, it prints a line to chat, for
example:

```
Scoreboard Remastered: load: our files 40 ms, setup 12 ms, after login 9 ms
(slowest: UI/Window.lua 11 ms). Slowest loads overall: LibFights 310 ms, ...
```

"Not ours" is the time between our steps that the game and the other add-ons spend:
loading their files, the world and the loading screen. It isn't counted as ours.
"Slowest loads overall" is the time between one add-on's loaded event and the next.
That's mostly that add-on's saved variables and setup, so it shows when another add-on
is the one using the budget. The last 5 reports are kept in `sv.loadReports`. **Show
load timing** in settings prints the report on every load, and `/sbr load` (PC) prints
the saved ones. The settings panel is built 1.5 s after login, and the console list
screens are set up the first time they open, so neither is part of the load.

### In battle

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
