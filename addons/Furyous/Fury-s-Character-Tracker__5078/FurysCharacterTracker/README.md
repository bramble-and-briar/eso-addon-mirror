# Fury's Character Tracker

Your whole roster on one board: every character's skill lines, guild ranks, crafting, research,
scribing, motifs, recipes, furnishing plans, companions, riding and time played, read straight
from the game. Pick each character's role and gear, share a brag card, export to Excel.

## Using it

- Log in on each character once with the addon on. It is read a few seconds after login and again
  after any progress (rank up, trait researched, recipe learned, riding lesson, new companion).
- `/fct` opens the board (or bind a key: Controls > Fury's Character Tracker).
- Views: Overview, Weapons, Armor, Guilds & AvA, World, Crafting, Research, Daily, Collections, Wallet & CP,
  Roles & gear.
  `/fct weapons` (or any view name; `traits` for Research, `sets` for Roles & gear) opens straight to it.
- **Research**: traits known per craft (Smith, Cloth, Wood, Jewelry), research slots busy right now, and
  the time until the next research finishes. Hover a craft for what is researching and every missing trait
  per item. Timers count down live for every character.
- **Research timers** (button on the board, `/fct timers`, or a key in Controls): every research in progress,
  one line each, with character, craft, item, trait, time left and when it finishes, soonest first.
  Finished and idle slots are listed at the top in gold. `/fct research` lists slots and timers in chat,
  and at login a line names any character whose research has finished.
- **Gold tile** = maxed. Light text = in progress. Dim dash = not started.
- Hover any cell for details. Click a column title to sort; again to reverse; a third time for your order.
- **Roles & gear**: click a blue cell for a dropdown. Role (Tank, Healer, DPS, any two, or all three),
  DPS gear and Tank/healer gear (Trial set, Crafted set, Overland set, Mixed, None), planned race.
  These are your own notes; the addon never reads what a character is wearing.
- **Other accounts and megaservers**: the button at the top right picks which account and megaserver the
  board (and the brag card) shows. Every account that plays on this PC saves into the same file, so each
  one shows up after it logs in once with the addon on. Another account shows what it saved at its last
  logout.
- **Two game clients at once**: the game keeps one saved-data file per addon for the whole PC. Each client
  reads it at login and writes its own copy at logout or /reloadui, so the client that saves last wins and
  the other client's progress since its login is lost (true for every addon that saves across accounts).
  Let one client log out before the other logs in, or log a character in again on its own afterwards.
- **Daily**: crafting writs since today's reset (started, ready to deliver, done) and the next riding lesson.
  Writs reset at 10:00 UTC on NA and 03:00 UTC on EU. Writs are matched by their English quest names.
- **Wallet & CP**: gold, Tel Var, Alliance Points, writ vouchers and bag space per character with totals; the
  bank and transmute crystals on the line above; Champion Points spent per tree.
- **Alerts**: a chat line when research or a riding lesson becomes ready on any character (`/fct alerts off`).
- Click a character for a details window: picks, progress, every skill line, research with timers and
  every missing trait.
- Right-click a row to remove a deleted character ("Show removed" brings it back).
- `/fct ids` prints the language-neutral IDs of the skill lines and companion quests (for translators).
- `/fct todo` lists every character on the account the addon has never read, then the ones not read
  in 7 days (`/fct todo 30` for 30), oldest first. Log in on each for a few seconds.

## Brag card

`/fct brag` (or the Brag card button, or a key) opens one screen of your best numbers: hours played,
Champion Points, skill points, skill lines maxed, traits researched, Grandmaster crafters, Vampire +
Werewolf, scribing, companions, riding, the character with the most achievement points / recipes /
furnishing plans / motif styles, set items collected (sticker book) and outfit styles (both
account-wide), and which roles you play on every class. Tiles with a finish line show % complete
and a progress bar. Sized for a screenshot to share on Discord.

## Notes on the numbers

- **Skill points** = points spent, as the game's own skill data counts them (subclass skills cost
  double) + points not assigned yet. Max 586.
- **Vampire / Werewolf**: the game hides these lines when you are cured, so the board keeps the best
  rank it has ever seen.
- **Alliance War** shows Assault (Support ranks with it). **Antiquities** shows Excavation (Scrying
  ranks with it).
- **Companions**: the collectible is account-wide, but each character has to finish the companion's
  intro quest to use them. A companion counts for a character once its intro quest is done there, or
  once you have summoned that companion on it.
- **Scribing** is learned like recipes: grimoires + scripts known.
- **Motifs**: styles known in full, the game's own count. It can be off by one or two from crafting
  addons that track chapters by hand (the game misreports a style or two, e.g. Mercenary).
- **Languages**: skill lines and companion quests are matched by the game's language-neutral IDs,
  so the board works on any client language. Names on the board are in English.
- **Renamed characters** show up as a new row; right-click the old one to remove it.

## Offline viewer (Windows)

See everything saved, for every account and megaserver on this PC, in your browser with the game closed.
Same board as in game: tabs, columns, account button, brag card, research timers and character details.

1. Log out, or type /reloadui. The game only writes its saved data at those moments.
2. Open this folder (Documents\Elder Scrolls Online\live\AddOns\FurysCharacterTracker).
3. Double-click **Open Offline Viewer.cmd**. Your browser opens **Fury's Character Tracker.html**, also saved
   in Documents\Elder Scrolls Online.
4. For newer data, run Open Offline Viewer.cmd again; the old .html keeps the data from when it was made.

Picks are read-only there, and in-game-only buttons are grayed out. Text can be selected and copied.

## Settings

The gear at the top of the board, Settings > Addons > Fury's Character Tracker, or `/fct settings`: chat alerts,
login summary, open the board at login, reset window positions, show removed characters, export.
Requires LibAddonMenu-2.0.

## Export to Excel (Windows)

**One-time setup:** double-click `Turn On Auto Export.cmd` in this folder. A small helper then runs in
the background (now, and every time you sign in to Windows). No admin rights needed.

**Then, any time:** click **Export to Excel** on the board (or `/fct export`). The UI reloads, and a few
seconds later `ESO Characters.csv` is in Documents\Elder Scrolls Online, updated.

- If you have that CSV open in Excel, it can't be replaced, so you get a dated copy beside it instead.
- `Turn Off Auto Export.cmd` stops the helper. `AutoExport.log` here shows what it did.
- Without the helper: click Export to Excel, then run `ExportToExcel.cmd` yourself.

Mac: the export lines are in the saved data file below (lines starting `FCT|`, tab separated).

## Saved data

`SavedVariables\FurysCharacterTracker.lua`, account-wide, separate for NA and EU.
