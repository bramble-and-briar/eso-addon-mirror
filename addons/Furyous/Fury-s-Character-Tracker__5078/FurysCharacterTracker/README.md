# Fury's Character Tracker

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own characters before it goes up, and I maintain it. Please report any problem in the comments.

Every character on your account, on one board: skill and class lines, crafting, research, daily writs,
weekly leaderboards, skill points still to earn, wallet, worn gear, companions and progress over time, read straight from
the game. A brag card, copy for Discord, export to Excel.

**Requires:** LibAddonMenu-2.0 (version 43 or newer). Install it separately; without it the addon will not load.

## Start here

1. Log in on each character once with the addon on. A few seconds is enough: it is read right after
   login, and again by itself whenever you make progress.
2. Type `/fct` to open the board (or bind a key: Controls > Keybindings > Fury's Character Tracker).
   Characters not read yet are the dim rows at the bottom.
3. Click **Start here** on the board (or `/fct start`) for one page on how it all works. It opens by
   itself the first time.

**Everything starts turned off.** The research and riding alerts, the login summary and opening the
board at login are off on a new install. Turn each on with one click on the Start here page or in
the settings. Updating from an older version keeps your settings as they were.

## Reading the board

- **Violet tile** = maxed. A **bar** behind a number = how far along. Dim dash = not started.
  **Blue** = your own pick.
- Hover any cell, column title, tab or button for what it means.
- Click a column title to sort; again to reverse; a third time for your own order.
- Click a character for everything saved about it.
- Right-click a row for its menu: details, move up or down, note, copy for Discord, remove.
- The bottom row counts how many characters have each column maxed (or adds up, on Wallet & CP and Progress).

## The tabs

`/fct class` (or any tab name; `traits` for Research, `points` for Skill points, `sets` for Roles & gear) opens straight to it.

- **Overview**: how many skill lines of each kind are maxed, with skill points, research, companions,
  riding, achievement points and hours played.
- **Class**: level, race, alliance and the three class skill lines each character is using, with
  subclassing. Hover a line for the class it comes from. Lines in training and lines trained earlier
  are listed beside them. **Build** says Pure or Subclass: a pure class build has class mastery,
  subclassing gives it up.
- **Weapons, Armor, Guilds & AvA, World, Crafting**: the rank of every skill line.
- **Research**: traits known per craft (Smith, Cloth, Wood, Jewelry), research slots in use, and the time
  until the next research finishes. Hover a craft for what is researching and every missing trait.
  Timers count down for every character, not just the one you are on.
- **Daily**: what each character can still do today. Crafting writs since today's reset (started,
  ready to hand in, done), the next riding lesson, free research slots, and the first random dungeon,
  battleground and Tales of Tribute match of the day (reward and large XP bonus). The line above shows
  your daily and weekly Challenges. Writs are found on every game language.
- **Weekly**: the weekly leaderboards. The first two columns are this week's trial (some weeks a group arena) and this week's arena challenge, and their titles are the names the game gives them. Then Infinite Archive (solo and duo), battlegrounds, and the reward tier earned in the Cyrodiil home campaign. Each row shows which characters ran what this week. The bottom row is the account's best score and place on each leaderboard: a leaderboard keeps one entry per account, and its rewards go to the top 500. Amber = a score outside the top 500 or with no place, so you know which run to redo. The line above counts down to the reset and lists what needs a better run. Everything empties by itself when the week turns over.
- **Collections**: recipes, furnishing plans, motifs, scribing, riding, companions and time played.
- **Skill points**: where the points still to earn are. Skyshards (hover for the zones that still have
  some), public dungeon group events (hover for the ones still to do) and Alliance War rank.
- **Wallet & CP**: gold, Tel Var, Alliance Points, writ vouchers and bag space per character with totals,
  and Champion Points spent per tree. The line above shows the bank and what the whole account shares
  (Transmute Crystals, Undaunted Keys, Seals of Endeavor, Crown Gems and more).
- **Progress**: what each character gained in the last 7 and 30 days: gold, hours played, skill points,
  achievement points and traits. One line is saved for each day you play a character, so the numbers
  show from the second day on.
- **Roles & gear**: click a blue cell to pick a Role (Tank, Healer, DPS, any two, or all three), DPS gear
  and Tank/healer gear (Trial set, Crafted set, Overland set, Mixed, None) and a planned race. **Wearing**
  shows the sets the character had on when it was last read (hover for every slot). **Note** holds
  anything you want to remember about it.

## The buttons under the board

- **Research timers** (`/fct timers`, or a key): every research in progress, one line each, with time left
  and when it finishes, soonest first. Finished and free slots are at the top in amber.
- **Brag card** (`/fct brag`, or a key): your best numbers on one screen, sized for a screenshot. Hours
  played, Champion Points, skill points, skill lines maxed, traits researched, Grandmaster crafters,
  scribing, companions, riding, set items collected, outfit styles, and which roles you play on every class.
- **Copy for Discord**: the tab you are looking at as text. It opens selected: press Ctrl+C, then paste.
  One character: right-click its row.
- **Export to Excel** (`/fct export`): see Windows Tools below.
- **Read this character** (`/fct scan`) and **Show removed**.

## Other accounts and megaservers

The button at the top right picks which account and megaserver the board, the brag card and the lists
show. Every account that plays on this PC saves into the same file, so each one shows up after it logs
in once with the addon on. Another account shows what it saved at its last logout.

**Two game clients at once:** the game keeps one saved-data file per addon for the whole PC. Each client
reads it at login and writes its own copy at logout or /reloadui, so the client that saves last wins and
the other client's progress since its login is lost (true for every addon that saves across accounts).
Let one client log out before the other logs in, or log a character in again on its own afterwards.

## Alerts

A chat line when research finishes or a riding lesson is ready on any character, on any account saved
on this PC, and one line at login naming what finished while you were away. They start turned off.
Switch each one on the Start here page or in the settings; `/fct alerts on` | `off` switches the two
alerts together.

## Commands

- `/fct` open the board
- `/fct start` the Start here page
- `/fct brag` the brag card
- `/fct timers` the research timers window
- `/fct research` research slots and timers, in chat
- `/fct unread` characters never read, read by an older version, or not read in 7 days (`/fct unread 30` for 30 days)
- `/fct alerts on` | `off` chat alerts for research and riding lessons
- `/fct scan` read this character again now
- `/fct export` export to Excel
- `/fct settings` the settings page
- `/fct tools` get the Windows Tools
- `/fct ids` language-neutral IDs of the tracked skill lines and companion quests (for translators)

## Notes on the numbers

- A character only updates when you log in on it. Research and riding timers keep counting for all of them.
- **Skill points** = points spent, as the game's own skill data counts them (subclass skills cost
  double) + points not assigned yet. Max 586.
- **Vampire / Werewolf**: the game hides these lines when you are cured, so the board keeps the best
  rank it has ever seen.
- **Alliance War** shows Assault (Support ranks with it). **Antiquities** shows Excavation (Scrying
  ranks with it).
- **Companions**: the collectible is account-wide, but each character has to finish the companion's
  first quest to use them. A companion counts for a character once that quest is done there, or once
  you have summoned that companion on it. Level and rapport are saved for a companion while it is out.
- **Wearing** is what the character had on when it was last read. It is never changed by the addon.
- **Trials** counts trial quests handed in during the last 7 days, from the day you start using 1.5.0.
- **Scribing** is learned like recipes: grimoires + scripts known.
- **Motifs**: styles known in full, the game's own count. It can be off by one or two from crafting
  addons that track chapters by hand.
- **Languages**: skill lines, writs and companion quests are matched by the game's language-neutral
  IDs, so the board works on any client language. Names on the board are in English.
- A renamed character keeps its row. Right-click a deleted character to remove it.

## Settings

The gear at the top of the board, Settings > Addons > Fury's Character Tracker, or `/fct settings`: the
alert switches, the login summary, open the board at login, reset window positions, show removed
characters, the Windows Tools and the export.

## Windows Tools (optional, separate download)

The offline viewer and the Excel export run outside the game, so they are not part of the addon download.
They come as a separate free download, **Fury's Character Tracker Windows Tools**: in game, click
**Get the Windows Tools** in the settings or type `/fct tools` (the game asks before it opens your
browser), or use the link on the addon's ESOUI page. Unzip it into any folder you like, for example
Documents\Elder Scrolls Online. Its own README says what each file does. The addon works fully in
game without them. Use Windows Tools 1.5.0 or newer with this version; 1.8.5 has the Weekly tab.

**Offline viewer.** The same board in your browser with the game closed, for every account and
megaserver on this PC: every tab, Start here, research timers, the brag card, details
and Copy for Discord. It runs the addon's own board files, so it shows exactly what the game shows.
Log out or /reloadui (the game only saves then), then double-click **Open Offline Viewer.cmd**.

**Export to Excel.** The quick way: open the offline viewer and click **Save for Excel**. No reload
in game is needed. To have the file written for you instead, double-click **Turn On Auto Export.cmd**
once; after that, click **Export to Excel** on the board (the UI reloads) and a few seconds later
`ESO Characters.csv` is in Documents\Elder Scrolls Online, with one row per character for every account.

Mac or no tools: the export rows are in the saved data file (texts starting `FCT|`, tab separated).

## Saved data

`SavedVariables\FurysCharacterTracker.lua`, account-wide, separate for NA and EU. Nothing leaves your PC.

## More from Fury

- [Fury's Guild Toolset](https://www.esoui.com/downloads/info5063.html): an officer's toolkit: bank alerts, member and inactivity reports, trader week totals, raffles, event sign-ups and recruiting.
- [Fury's Inventory Ledger](https://www.esoui.com/downloads/info5099.html): every item you own in one list, across all your characters, the bank and your houses, with export to Excel.
- [Fury's Account Sync](https://www.esoui.com/downloads/info5106.html): make your other accounts on this PC match your main one: settings, keybinds, addon settings and builds.
- [Fury's Quality of Life](https://www.esoui.com/downloads/info5115.html): small comforts for everyday play: Select all when you deconstruct, a fishing bite alert with the right bait, a queue alert and a lock for everything you wear.

All free on ESOUI and in Minion.

## Credits

- Settings page uses **LibAddonMenu-2.0** by Seerah and sirinsidiator.
- Game API details from the ESOUI wiki and ZeniMax's ESO UI source code.
- The offline viewer in the Windows Tools includes **Fengari** (fengari.io), a Lua engine in JavaScript by Benoit Giannangeli and Daurnimator, MIT license.
