Battleboard
===========

Battleboard is an addon designed for saving, reviewing, and comparing Battleground match results. It records scoreboard data at match end, stores match history locally through SavedVariables, and presents the data through three in-game pages: History, Metrics, and Observatory.

Required Dependencies
---------------------

- LibMainMenu-2.0
- LibAddonMenu-2.0

Development Note
----------------

Battleboard was developed with AI-assisted coding and manually reviewed/tested by the author.


Core Features
-------------

- Saves Battleground scoreboard results, including teams, scores, match outcome, player rows, class, kills, deaths, assists, damage, healing, medal score, and KD.
- Records queue length, match length, combat time, time dead, DPS, HPS, and deserter cooldown history where available.
- Assigns each saved match a short deterministic match ID so players from the same match should generate the same ID without syncing data.
- Supports 4v4, 4v4v4, 8v8, 6v6v6, and 9v9 Battleground formats, including round-end handling for 4v4 Deathmatch.
- Stores data locally in `BattleboardSavedVariables`.


History Page
------------

The History page is the main match browser. It shows saved Battlegrounds in a scrollable list and opens each selected match in a detailed scoreboard view.

History includes:

- Match result, match ID, timestamp, queue length, and match length.
- Team summary blocks for Fire Drakes, Pit Daemons, and Storm Lords.
- Player table with team, class, user ID, medals, kills, deaths, assists, damage, healing, and KD.
- Team MVP markers based on Battleboard's current MVP calculation.
- Search, locked matches, character, team-size, date-range, and game-type filters.
- Lock protection for important matches.
- Match sharing through Battleboard chat links.



Metrics Page
------------

The Metrics page summarizes performance across the currently filtered match set.

Metrics includes:

- Average contribution breakdown for score, kills, deaths, assists, damage, and healing.
- Personal records for best single-match stat values.
- Match counts by game type.
- Summary blocks for kills, deaths, KD, win rate, damage, healing, and matches.
- Timer summaries for queue length, match length, and deserter time.
- Class performance tables with average and total views.
- Class encounter tables showing how often classes appear and how they perform across saved matches.


Observatory Page
----------------

The Observatory page focuses on class trends and opponents you've seen across saved Battlegrounds.

Observatory includes:

- Trends for most and least popular, survivable, deadly, brutal, and supportive classes.
- Representation table showing class appearance and average/total values.
- Hall of Fame blocks for standout players seen in saved matches.
- Class Spread panel with selectable modes:
  - Popularity (class distribution)
  - Survivability (Average deaths)
  - Deadliness (average kills)
  - Brutality (Average damage)
  - Supportiveness (average healing)

Brutality and supportiveness only count players where their healing to damage ratio reflects a healing or damage role. 


End Match Overlay
-----------------

Battleboard can show a more simplified center-screen scoreboard overlay when a Battleground is saved at match end. This overlay mirrors the match details view but is designed for fast post-game review.

The overlay includes:

- Victory, defeat, or draw result.
- Team score and team-stat blocks.
- Full player table.
- Local-player contribution row.
- Team MVP panel with raw kills, deaths, damage, and healing.
- Small close button in the top-right corner.

The overlay can be enabled or disabled in settings.


MVP Tracking
------------

Battleboard marks one MVP per team for newly saved matches. The current MVP calculation is under review


Match IDs
---------

Battleboard creates a match fingerprint when a match is saved. The fingerprint uses the nearest 5-minute timestamp, battleground ID, team count, team size, team scores, and team kills/deaths, then passes that data through a small deterministic hash.

The result is displayed as a short match ID. Players in the same match should generate the same match ID without syncing data.


Sharing
-------

Battleboard can create compact chat links for saved matches. A recipient with Battleboard installed can click the link to view a standalone popup version of the shared scoreboard.

Shared scoreboards are compact and omit character names. User IDs may be shortened to fit the chat-link payload.


Settings
--------

Battleboard settings are available through LibAddonMenu.

Settings include:

- Show or hide the end-match scoreboard overlay.
- Choose the default Battleboard page.
- Show or hide the debug panel.
- Set the maximum number of saved matches.
- Delete unlocked saved matches while keeping locked records.


Commands and Access
-------------------

- `/bb` opens Battleboard.
- `/bb save` manually saves the current Battleground scoreboard when available.
- `/bb debug` toggles the debug panel.
- `/bbs` toggles the latest saved match in the end-match overlay.
- Battleboard also registers a keybind named `Battleboard: Toggle Window`.



Notes
-----

- Matches are stored at server time.
- Match-time KD is calculated as kills divided by deaths. (Negative KD values are hidden for other players but but the underlying value is still calculated)
- Metrics KD uses total kills divided by total deaths across the selected time period.
- DPS and HPS are calculated from damage or healing divided by active combat time, excluding tracked dead time where available.
- Current MVP calculation is 

output = damage + healing

if healing > damage, combat = -z(deaths). else: combat = z(kills) - z(deaths)

mvp_score = 0.7 * z(output) + 0.3 * combat
