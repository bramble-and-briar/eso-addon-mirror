# Changelog

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
