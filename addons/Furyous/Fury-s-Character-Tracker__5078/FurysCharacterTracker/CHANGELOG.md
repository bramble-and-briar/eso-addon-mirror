# Changelog

## 1.8.5
- **Finished writs stay finished.** A writ you hand in now always shows as Done, even when the game doesn't tell the addon about the hand-in. When a writ taken today leaves your journal, the addon counts it as handed in. It also reads your writs again whenever you finish a quest and when you log out or switch characters.
- **Alchemy writs are read right.** An alchemy writ could be taken for another craft's writ, so its column stayed "-". On an English client the writ's name now decides which craft it is.
- If the game crashes, anything since your last logout, character switch or reload is still lost. The game saves addon data only at those moments.
- Windows Tools 1.8.5: no change, same version number as the addon.

## 1.8.4
- **Smaller version number.** The version in the title bar is now in small print, the same in every Fury window, so the name and your other Fury addons' icons stand out.
- Windows Tools 1.8.4: no change, same version number as the addon.

## 1.8.3
- **Title-bar icons moved to the left.** The row of your other Fury addons' icons now sits on the left of the title bar, between the addon's name and its version, the same in every Fury window. On the right it could cover other controls, such as Invite by code on the Guild Toolset's Events tab.
- Windows Tools 1.8.3: no change, same version number as the addon.

## 1.8.2
- **The sidebar shows only with your cursor out.** The Fury sidebar can only be clicked in cursor mode, so it now hides while you play without the cursor and comes back when the cursor does. A new box in the list (`/fury menu`), "Show the sidebar without the cursor too", keeps it on screen all the time.
- Windows Tools 1.8.2: no change, same version number as the addon.

## 1.8.1
- **Your other Fury addons in the title bar.** Every Fury addon's window now has a row of small icons in its title bar, one per other Fury addon you have installed. Left-click an icon to open that addon, right-click for its settings. Icons that don't fit in a narrow window are left out.
- **Slimmer sidebar.** The Fury sidebar is now about half as wide, with small icons. A new box in the list (`/fury menu`), "Bigger sidebar icons", brings the big ones back.
- Windows Tools 1.8.1: no change, same version number as the addon.

## 1.8.0
- **The Fury sidebar.** A slim bar of icons, one per Fury addon you have installed, that can stay on screen: left-click an icon to open that addon, right-click for its settings. Type `/fury` or press the key (Controls > Keybindings > Fury's Addons, now named "Show or hide the Fury sidebar") to show or hide it, and drag its violet line to move it. The gear on it, or `/fury menu`, opens the list of your Fury addons with the sidebar's options: a row or a column, lock in place, hide in combat. The sidebar starts turned off.
- Windows Tools 1.8.0: no change, same version number as the addon.

## 1.7.6
- **One key for the Fury addons menu.** "Open the Fury addons menu" now shows once in Controls > Keybindings, under Fury's Addons, instead of once under every Fury addon. If you had set a key for it, set it again there.
- Fury's Guild Management Toolset is now called **Fury's Guild Toolset**; More from Fury and the Fury addons menu show the new name.
- Windows Tools 1.7.6: no change, same version number as the addon.

## 1.7.5
- **More from Fury** now lists Fury's Quality of Life, a new addon of small comforts: Select all on the deconstruct screens, a fishing bite alert with the right bait, a queue alert and a lock for everything you wear.
- Windows Tools 1.7.5: no change, same version number as the addon.

## 1.7.4
- **The Fury addons menu.** Type `/fury`, or set the key "Open the Fury addons menu" (under this addon in Controls > Keybindings), for a small window that lists every Fury addon you have installed, each with an Open and a Settings button.
- Windows Tools 1.7.4: no change, same version number as the addon.

## 1.7.3
- **New Weekly tab.** The weekly leaderboards. The first two columns are this week's trial (some weeks a group arena) and this week's arena challenge, titled with the names the game gives them, then Infinite Archive (solo and duo) and battlegrounds. Each row shows which characters ran what this week, and the reward tier earned in the Cyrodiil home campaign. The bottom row is the account's best score and place on each leaderboard, because a leaderboard keeps one entry per account. Amber means the score is outside the top 500, where the leaderboard rewards go, or has no place, so you can see which run to redo. The line above the columns counts down to the reset and lists what needs a better run. Log in on a character to read its account's scores.
- The Weekly tab asks the game for this week's leaderboards by itself, a few seconds after you log in, so the names, scores and places fill in without opening the game's leaderboard window (about 15 seconds).
- **Daily tab tidied.** Class and Trials moved out to make room. New **Free slots** column (free research slots, amber when one is waiting) and the daily Tales of Tribute reward next to the dungeon and battleground ones.
- **The Todo List is gone.** The Daily tab shows the same things in a better layout. Its button and key went with it. `/fct todo` now opens the Daily tab.
- Daily tab: the hover texts now say that the first random dungeon and battleground of the day carry a large XP bonus.
- Amber is now a color on the board: something is waiting on you.
- The tab row makes room by itself when a tab is added.
- Windows Tools 1.7.3: the offline viewer has the Weekly tab and the tidied Daily tab.

## 1.5.8
- **One shared library file.** Chat lines, the welcome line and confirm pop-ups now come from the same file every Fury addon carries, next to the look, Start here and More from Fury, so all of them stay identical. Nothing changes in how the addon works, and it still needs no other addon.

## 1.5.7
- **More from Fury.** The Start here page and the settings page now end with a short list of my other addons; click one on the Start here page, or its button in the settings, to open its ESOUI page (the game asks first). No chat lines, no pop-ups.

## 1.5.6
- **One look across all of Fury's addons.** Every window now has the same header as the Guild Toolset: the name with its version, a **Start here** button right after it, the settings gear and the close button at the right, and a hover tip on each.
- The version moved into the board's title, and the Start here button moved next to it.
- Close buttons on every window have a hover tip.
- Chat lines start with [Character Tracker]. `/fct help` starts with "commands:".
- Keybinds are named "Open/close ..." like the other Fury addons. The settings page links to the addon's ESOUI page.

## 1.5.5
- **Who needs me is now the Todo List.** Open it with the button under the board, a key, or /fct todo.
- The Todo List shows writs for every character that is certified for them, not only the ones that did writs lately.
- The chat list of characters that still need a login moved from /fct todo to /fct unread.

## 1.5.4
- **Class** tab: class mastery is no longer listed as a line to track. It is not earned, it comes with a pure class build, so a new **Build** column says Pure or Subclass instead, and a character's details say which it is.

## 1.5.3
- The export texts now say where Auto Export is turned on: it is the file Turn On Auto Export.cmd in the Windows Tools folder, not a setting in game.

## 1.5.2
- **Class mastery** is shown the way the game counts it. It is not a skill line with a rank, so it no longer shows as 1 / 50: the Class tab lists it as "(mastery)", and the hover and the character details show its Class Mastery Points and whether it is off because the character is subclassing. Only the character's own class mastery is listed, once it is open.
- **Public dungeons** on the Skill points tab now counts group events, the thing that gives the skill point. It used to count dungeons finished in the zone guide, which goes by their quests, so a character could show 31 of 36 with every group event done. Hover a cell for the group events still to do.
- **Who needs me** counts a writ for every craft the character is certified for, so a writ you skipped yesterday is still on the list today. A character is listed for writs if it did any writ in the last 14 days. Until you log in on a character once to read its certifications, all seven count.
- Nothing reloads the UI without asking: /fct export and the export button in the settings now show the same warning as the button on the board, with Cancel.
- **Skill points** tab: the Guilds and World columns are gone from it. They count maxed skill lines, not skill points, and they are still on the Overview tab.
- Log in once on a character with class mastery to read its points; until then it shows as open.

## 1.5.0
A big update: easier for a new player, lighter on the game, and a lot more on the board. Your characters, picks and settings carry over. **Log in on each character once** to fill the new columns; until then they show a dash, and the line above the board says how many are left.

New player friendly
- **Start here** page: getting your characters on the board, what the colors mean, what each tab is for, and the alert switches, on one page. It opens once on a new install; after that use the Start here button on the board or /fct start.
- Every character on the account is on the board from the first login. The ones not read yet are dim rows that say what to do: log in on each once.
- **Everything starts turned off** on a new install: the research and riding alerts, the login summary and opening the board at login. Turn each on with one click on the Start here page or in the settings. If you already use the addon, your settings stay exactly as they are.
- Plainer words everywhere, and a hover text on every tab, column title, cell and button.

New on the board
- **Class** tab: level, race, alliance and the three class skill lines each character is using, with subclassing (hover a line for the class it comes from). Other class lines the character has trained are listed beside them.
- **Skill points** tab: where the points still to earn are. Skyshards (hover for the zones that still have some), public dungeon group events and Alliance War rank.
- **Progress** tab: what each character gained in the last 7 and 30 days: gold, hours played, skill points, achievement points and traits. It starts counting with this version.
- **Daily** tab: crafting writs are now found on every game language. New columns for the daily dungeon and battleground rewards and for trial quests handed in this week. The line above shows your daily and weekly Challenges.
- **Roles & gear** tab: a Wearing column shows the sets each character had on when it was last read (hover for every slot), and a Note column holds anything you want to remember about a character.
- **Wallet & CP** tab: the line above now also shows what the whole account shares, such as Undaunted Keys, Seals of Endeavor, Archival Fortunes, Crown Gems and Crowns.
- **Companions**: hover the Companions cell for each companion's level, and open a character's details for rapport. Both show for a companion once you have had it out.
- **Who needs me** (button under the board, /fct needs, or a key): one list of what your characters are waiting on you for. Writs to do or hand in, riding lessons, free research slots and full bags.
- **Your own row order**: right-click a row, Move up or Move down. A third click on a column title goes back to your order.
- **Copy for Discord**: the tab you are looking at, or one character from its right-click menu, as text ready to paste into Discord.
- Character details now have a daily checklist, class lines, skill points still to earn, worn gear and progress over time.
- A renamed character keeps its row.

Looks
- Flat tabs across the top, a bar behind each number that shows how far along it is, and class and alliance icons.
- The board, details, Who needs me, research timers and brag card windows share one look and remember where you put them. Reset window positions in the settings puts them back.

Lighter on the game
- After the first read, the addon reads only what changed. A skill rank-up re-reads the skill lines and nothing else, about one twentieth of the work of a full read.
- Nothing is read while you are in combat; it waits until the fight is over.
- A burst of changes (learning twenty recipes in a row) is one read, not twenty.
- The rows for the Excel file are built once, when you log out, instead of after every read.

Windows Tools 1.5.0 (separate download, /fct tools)
- **Get the new tools with this version.** The 1.4.1 tools cannot read what 1.5.0 saves.
- The offline viewer now runs the addon's own board files, so it shows exactly what the game shows: every tab, Start here, Who needs me, research timers, the brag card, details and Copy for Discord.
- New **Save for Excel** button in the viewer: a CSV of the account on screen, with no export or reload in game.
- The viewer and the Excel export read both megaserver folders (live for NA, liveeu for EU).
- The Excel file has an Account and a Server column in front, and one row per character for every account.
- The viewer includes Fengari, an open-source Lua engine (MIT license), to run the addon's files in your browser.

## 1.4.1
- Windows Tools 1.4.1, offline viewer fixes:
  - Fixed: on the Daily tab, a character who had turned in all seven writs showed Jewelry as not done (6/7), and when the first few writs were done the others could land in the wrong columns. The viewer now reads every writ under its own craft, the same as in game.
  - The viewer window now opens in the middle of your browser, up and down as well as side to side, and stays centered when you resize the browser. Drag it if you want it elsewhere; it opens centered again next time.
- Nothing changes in game.

## 1.4.0
- New button in Settings > Addons > Fury's Character Tracker: "Get the Windows Tools" opens the download page for the offline viewer and Excel export in your browser (the game asks first). /fct tools does the same, so there's no more hunting for the link on the addon page.

## 1.3.2
- Fixed: the violet "maxed" tile was hidden on every other row and on the row under the mouse, leaving dark text on a dark row. The tile now shows on every row, on every tab of the board.

## 1.3.1
- Code cleanup for the ESOUI addon check: the addon's one global table is now named FurysCharacterTracker (was FuryCT), and its window and control names start with FurysCharacterTracker_, so they can't clash with other addons.
- Your roster, picks and settings carry over unchanged (saved variables keep their name), and so do your keybinds.

## 1.3.0
- New look, "Fury Night", shared by all of Fury's addons: deep blue-black windows with an indigo frame, a soft glow behind the title, a violet line under it and a character icon beside it. Titles use the game's book font (Prose Antique).
- Blue column headers, striped rows, and the row under the mouse lights up.
- The "ready" color is now violet instead of gold; research timers that need you are amber.
- The Brag window uses the same look, with a larger Prose Antique title.
- Chat messages and the settings title use the new violet color.
- Nothing about what the addon does or your settings has changed.

## 1.2.2
- The offline viewer and Excel export helper (Windows scripts) are now a separate download, Fury's Character Tracker Windows Tools, linked on the addon page. ESOUI asks that addon downloads hold only addon files. Nothing changes in game; the Export to Excel button works as before.
- Shorter description line in the addon manifest, so the game reads all of it.

## 1.2.1
- Shows as up to date in the game's Add-Ons list again (API version 101051, today's live game, plus 101052).
- Now asks for LibAddonMenu-2.0 version 43 or newer, the current release.
- Chat lines go straight to the game's chat router (code cleanup for the ESOUI addon check).

## 1.2.0
- Settings page (gear on the board, Settings > Addons, or /fct settings): alerts, login summary, open the board at login, reset window positions, export. Now requires LibAddonMenu-2.0.
- Daily tab: crafting writs per character (started, ready to deliver, done since today's reset at 10:00 UTC on NA and 03:00 UTC on EU), and when each character can take its next riding lesson.
- Wallet & CP tab: gold, Tel Var, Alliance Points, writ vouchers and bag space per character with totals; bank, transmute crystals and bank space on the line above; Champion Points spent per tree.
- Alerts while you play: a chat line when research or a riding lesson becomes ready on any character, any account. /fct alerts on | off.
- Character details also show the Daily and Wallet & CP sections.
- Click a character on the board for a details window: picks, progress, every skill line, research with timers and missing traits.
- Windows you open (brag card, research timers, details) come to the front, and a window you click comes to the front.
- Research timers window (button on the board, /fct timers, or a key): every research in progress with character, craft, item, trait, time left and when it finishes, soonest first; finished and idle slots listed at the top.
- Account and megaserver picker on the board: see any account that plays on this PC, on NA or EU. The brag card follows it.
- Offline viewer (Windows): "Open Offline Viewer.cmd" shows every saved account, character and research timer in your browser, no game needed.
- The research-finished line at login covers every account and megaserver.

## 1.1.0
- New Research tab: traits known per craft, research slots busy, and time until the next research finishes. Hover a craft for running research and every missing trait per item.
- Research timers count down live for every character, not just the one you are on.
- /fct research lists slots and timers in chat; at login, a line names characters whose research has finished.

## 1.0.1
- Version number shown in the game's Add-Ons list and on the brag card

## 1.0.0
First public release.
- Board with Overview, Weapons, Armor, Guilds & AvA, World, Crafting, Collections, and Roles & gear views
- Reads every character from the game at login and after progress; Vampire/Werewolf keep their best rank
- Skill points counted the way the game counts them (subclass skills cost double)
- Scribing (grimoires + scripts), motifs, recipes, furnishing plans, companions (per character), riding, achievement points
- Role and gear picks from dropdowns; never reads what a character is wearing
- Brag card with % complete, sized for screenshots
- /fct todo lists characters that still need a login
- Export to Excel, with an optional Windows helper that writes the CSV by itself
