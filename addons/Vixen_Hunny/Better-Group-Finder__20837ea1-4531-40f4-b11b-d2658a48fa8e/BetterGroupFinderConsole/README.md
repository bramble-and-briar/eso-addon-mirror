# Better Group Finder

A replacement front end for ESO's Group Finder. It uses the game's own group finder service, so the listings you see and post are the same ones everyone else sees. You get a faster, clearer interface on top of that service, and listings that mostly write themselves.

There are two add-ons:

| Folder | For | Opens with |
|---|---|---|
| `BetterGroupFinder` | PC / Mac, keyboard and mouse | `/bgf`, a keybind (Controls > Better Group Finder), or the **Better Group Finder** button on the game's Group Finder window |
| `BetterGroupFinderConsole` | Console and gamepad mode | Main Menu > **Better Group Finder** (after Activity Finder), **R3** on the Activity Finder / Group Finder screens, or `/bgf` |

Both can be installed at once. They keep separate saved variables.

## Features

### Browse and search
- Pick a category (Dungeons, Trials, Arenas, Infinite Archive, PvP, Zone, Custom). Each one comes with a short description.
- **Search** matches the title, activity name and abbreviation (`vSS`, `SH`...), leader, playstyle and description. Every word you type has to match.
- **Filters:** Needs my role, I meet the CP requirement, Hide full groups, Auto-accept only, Hide invite-code groups.
- **Sort:** Best match, Most open slots, Nearly full, Lowest or highest CP requirement, Title.
  - *Best match* ranks groups higher when they need your role, accept your CP, are joinable, are nearly full, or accept you instantly.
- Each row shows the open role slots as icons, how full the group is, the leader, the CP requirement, the playstyle and any flags.
- The details panel shows a role-by-role breakdown, the requirements (highlighted when you don't meet them), activity info from the built-in database, and the full description.
- **Apply** sends an optional saved message and takes an invite code when the group needs one. **Join** is shown instead for auto-accept groups. You can also whisper the leader, or cancel your application.

### Create a listing: "What are you doing?"
Choose a preset and the listing is filled in for you:

- **Dungeons:** Pledges, Normal, Veteran, Veteran Hard Mode, Trifecta / Achievements, Gear Farm, Learning / Teaching
- **Trials:** Normal, Veteran, HM / Score, Progression
- **Other:** Group Arena, Infinite Archive Duo, Cyrodiil, Battlegrounds, Imperial City, World Events, Public Dungeons, Zone Story, Social / RP

Each preset sets the category, difficulty, a matching playstyle and a suggested CP minimum. It also feeds the automatic text.

### Automatic roles
Roles are worked out from the activity, the group size and the players already in your group:
- Dungeons use 1 tank, 1 healer, 2 DPS. Trials use 2 / 2 / 8, or the activity's own makeup (for example, Aetherian Archive uses 1 / 2 / 9). PvP leans on healers, and social or world groups leave most slots open to any role.
- Your current members are never removed. If the group is over capacity, DPS slots are cut first.
- You can still adjust each role with +/- (A/X on gamepad). Any slot not assigned to a role becomes "Any role".

### Automatic title and description
- **Title** example: `vSS HM LF 1T 2H 7D CP1500+`. It always shows the roles you *still need* and stays within the game's title rules.
- **Description** lists the activity and difficulty, what you're doing, open roles, requirements and voice chat, then your own extra notes.
- Typing in either field turns its **Auto** switch off, so your own text is never overwritten.

### My Group
- See your listing and how full it is. Edit it or remove it.
- Applicants appear with their role, class, CP or level, note and time left, with **Accept** / **Decline** buttons. You get an alert when someone new applies.

## Settings (LibAddonMenu-2.0)
Settings > Add-ons > **Better Group Finder**, the **Settings** button in the PC window, **All Settings** on the console main page, or `/bgf settings`. On console, LibAddonMenu-2.0 r40+ turns this into a LibHarvensAddonSettings page automatically. LAM is optional: without it everything works with the defaults.

| Section | Options |
|---|---|
| Browse & Search | Default category, sort order, each filter's default, default apply message |
| Create Listing | Default "What are you doing?" preset, automatic roles / title / description, extra notes |
| Auto Generation | Trial tanks and healers for the automatic 12-player makeup, whether titles show open roles and the CP requirement, whether descriptions start with the activity, plus a "Regenerate my draft now" button |
| Notifications & Interface | Applicant alert, chat messages; PC only: button on the game's Group Finder, reset window position |

## Commands

| Command | What it does |
|---|---|
| `/bgf` | Open or close |
| `/bgf browse`, `/bgf create`, `/bgf mine` | Open a specific tab |
| `/bgf search <text>` | Open Browse with that search |
| `/bgf post` | Post or update your listing |
| `/bgf remove` | Remove your listing |
| `/bgf roles` | Regenerate the roles on your draft |
| `/bgf settings` | Open the settings panel |

## Notes
- Your **role** for matching is the one selected in the Activity Finder. Change it there before applying.
- Category, difficulty, activity and size can't be changed while your listing is up (the game doesn't allow it). Title, description, roles and requirements can.
- Playstyle presets match the English playstyle names. On other client languages the playstyle is left as it is.
- Activity descriptions come from a built-in table in `Core/BGF_Activities.lua`. Unknown or new activities still work, they just show no extra info.

## Development
`Core/` is generated from the PC add-on by `BetterGroupFinder/tools/sync_console_core.sh`. Edit it there, not here.
