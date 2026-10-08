Skill Point Finder 1.0.0
By @TheGreyWolf98

OPEN: /spf (legacy /tgwsp and /skillseeker commands also work).
No external libraries required. Tested with Xbox controller UI.

GETTING STARTED
Log into each character once. After entering the world, the addon reads existing
quest, skyshard and public-dungeon group-event progress in small batches.
Completed scans are saved per character and server. Press X to select another
character and view their last saved scan. Y scans the CURRENT logged-in character;
it cannot refresh an offline character. Supported progress changes refresh scans.

CONTROLS
LB/RB: category. D-pad up/down: selection; hold to move repeatedly.
D-pad left/right: column. A: select character or toggle row details.
LT/RT: list pages or expanded quest-detail pages. B: back / close.

WHAT IS TRACKED
Base-game and DLC dungeon skill-point quests; zone quest rewards and skyshards;
Cyrodiil and Imperial City; Alliance Rank; public-dungeon group events;
The Harbourage, character-level awards and Infinite Archive introduction.
The catalogue includes 24 base-game dungeon quests, 34 DLC dungeon quests,
43 zone records and 36 public-dungeon group events.

Zone layout: EP, DC and AD follow their story routes. DLC zones follow release
order across two columns. Other contains Wailing Prison, Coldharbour and Craglorn.
SP: completed catalogued quest skill-point rewards. SS: acquired skyshards.
Their completion colours are independent. Three skyshards award one skill point;
skyshard counts are not displayed as skill-point totals.
Green / checked: complete. Amber / empty: remaining. ?: unknown.
Available points shows the game's unspent point balance, separately from sources.
Offline balances are saved snapshots; older scans need one login to add this value.

IMPORTANT DISTINCTIONS
Dungeon checkboxes track the one-time skill-point QUEST, not every boss kill or
normal/veteran completion achievement. Public-dungeon rows track the GROUP EVENT
skill point, using the character-specific group-event achievement.
All catalogued dungeon quests are listed; missing does not indicate DLC ownership.
Optional tutorials, Folium Discognitum and exceptional/legacy rewards that cannot
be reliably inferred are labelled unknown. The catalogue is not a guarantee of
exhaustive current-game coverage. No map pins or waypoint navigation are included.

UPDATING
Saved character scans are preserved from the test versions. The addon folder and
SavedVariables identifier remain TGWSkillSeeker for compatibility; the displayed
name is Skill Point Finder. Main story quests is renamed The Harbourage in saved
scans without changing their progress.

DATA CROSS-REFERENCE
https://github.com/yachoor/uspf
Factual game identifier mappings were cross-referenced with this source. Tracker
and UI are independently implemented; no USPF code or artwork is bundled.
Character-specific group-event exception:
https://help.bethesda.net/app/answers/detail/a_id/55358/
