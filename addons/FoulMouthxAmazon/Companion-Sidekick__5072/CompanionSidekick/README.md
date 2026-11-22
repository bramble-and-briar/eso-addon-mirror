# Companion Sidekick 0.1.2

Developed with ChatGPT-assisted code generation. Created and maintained by FoulMouthxAmazon.

Author: FoulMouthxAmazon

A compact companion dashboard for ESO PC/Mac. No extra libraries required.
Developed with ChatGPT-assisted code generation and automated verification.

## Install and open

Extract the **CompanionSidekick** folder into:
`Documents/Elder Scrolls Online/live/AddOns/`

The manifest must be at `AddOns/CompanionSidekick/CompanionSidekick.txt`.
Enable Companion Sidekick in ESO, then restart or `/reloadui`.
Open with **`/csidekick`**. `/companions` is an alias if another addon has not
already registered that command.

## First scan

Log into each character once. On each character, summon the companions whose
rapport you want recorded. Build details are shared, so gear and skills only
need to be scanned once per companion, then update whenever that companion is
active and gear, skills or level change. First-time quest/perk indexing runs in
small batches and may take several seconds.

The character dropdown includes your character roster plus Account overview.
Companions include the eight known collectible seeds and any additional companion
collectibles ESO exposes. Unsupported personal quest chains stay Unknown.

Click a row for:

- **Progress:** recruitment, personal quest completion, current objective,
  rapport number/tier, permanent perk, and remaining keepsake criteria.
- **Gear & Skills:** shared level, equipped ability priority including ultimate,
  gear quality/traits, skill-line ranks, unlocked abilities and passive abilities.
- **Characters:** which characters recruited this companion, their last recorded
  rapport, quest stage and scan time.

Main rows show character access, rapport, shared level, permanent keepsake and
quest summary. Account overview counts unlocked characters and scanned records;
it does not invent an account-wide rapport number.

## Controls

- `/csidekick` opens/closes the roster.
- `/csidekick refresh` rescans current character and active companion.
- `/csidekick help` opens instructions.
- `/csidekick scale 70` sets window scale (55-120%).
- Open **Colors & Size** in the title bar for Smaller/Larger buttons (55-120%), a percentage display and Reset Size (85%). All addon windows resize together. `_` minimizes the roster.
- Drag the window to move it; the roster position and size are saved.

## Colors & Size

Seven color presets: Teal (default), Plum, Emerald, Ocean, Ember, Midnight and Rose. Choose a complete preset or mix Background, Title bar and Borders independently. Changes apply immediately to the roster, detail window, rows and appearance menu. Reset Colors restores Teal. Colors save per character; the existing size preference remains account-wide. /csidekick colors and /csidekick size also open the menu.

## What is shared, and what is recorded

Companion level, equipment and skill progress are shared across characters.
Recruitment and personal quests plus rapport are character-specific.
The permanent keepsake is an account collectible. The normal perk applies while
summoned; the keepsake grants the permanent version. They are shown separately.

Character and companion records are stored in SavedVariables for this ESO
account and megaserver. They are last-seen snapshots, not remote queries into
offline characters. NA and EU records stay separate. Unvisited characters and
unseen rapport are Unknown. Dismissing a companion preserves prior build scans.

"Complete" means that character's recruitment and known personal quests are
complete, shared level is at least 20, and the permanent keepsake is unlocked.
It does not mean every skill line is maxed; inspect the build tab for those.

## Test-build limits

Automated Lua and mocked UI checks passed. Live ESO layout, collectible-to-perk
matching, quest indexing and event timing still need in-game verification.
This is an early public release; additional in-game verification is ongoing.

Personal story titles are initially mapped in English and resolved to real quest
IDs from ESO. Existing known Bastian/Mirri quest IDs also work independently of
client language. On other languages, unsupported story titles stay Unknown.
The index checks quest IDs 1-15000. Future or renamed quests outside that mapping
will stay Unknown. It never infers historical completion from an account-wide
achievement. No fixed rapport quest-availability thresholds are guessed.

Keepsakes are identified by the exact localized passive name in the collectible
description and its achievement reward. Missing or ambiguous matches remain
Unknown. Their actual achievement criteria are displayed rather than hardcoded
completion requirements.

No automatic summoning, gear changes, skill changes, chat messages to other
players, or third-party network services are used. UI labels are English;
names, quests and abilities come from the client where available.

## Validation

`tests/runtime_test.lua` provides a mocked ESO runtime. The development runner
inlines Data.lua, Core.lua and UI.lua at `-- @MODULES@`, then executes the result
with Lua or Fengari. It covers first install, character independence, inactive
companions, equipment, uninitialized skills, journals with gaps, quest indexing,
keepsake mapping, criteria, account access counts, UI controls, resizing and events.

## Credits

Original implementation by FoulMouthxAmazon with ChatGPT assistance. ESO UI APIs
and game-provided names, descriptions, icons and identifiers belong to ZeniMax.
The four initial Bastian/Mirri personal quest identifiers were cross-checked
against the LibQuestData dataset maintained by its contributors. No library code
is bundled or required. Research references are listed in SOURCES.md.

This addon is not created by, affiliated with or sponsored by ZeniMax Media Inc.
or its affiliates. The Elder Scrolls and related marks belong to their owners.
