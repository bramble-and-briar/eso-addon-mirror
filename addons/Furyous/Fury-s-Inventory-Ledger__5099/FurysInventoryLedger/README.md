# Fury's Inventory Ledger

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own characters before it goes up, and I maintain it. Please report any problem in the comments.

Every item you own in one list: every character's bags and gear, the bank, the craft bag, house storage,
the Furniture Vault, furniture placed in your houses, and your currencies. See it all on a summary page
with running currency totals, copy it in game, or export it to Excel.

**Requires:** LibAddonMenu-2.0 (version 43 or newer). Install it separately; without it the addon will not load.

## What it lists

- **Each character:** backpack, equipped gear, the summoned companion's gear, and the character's wallet
  (gold, Alliance Points, Tel Var, writ vouchers).
- **Account-wide:** bank (including the ESO Plus half), craft bag, banked currencies, and account currencies
  such as transmute crystals and Undaunted keys.
- **House storage** (each coffer by its name or nickname) and the **Furniture Vault**.
- **Placed furniture**, counted per house, for houses you own.

Identical stacks in the same place are added together. Stolen copies get their own row.

## When it reads

- At login, and a moment after anything in your bags, bank or craft bag changes.
- House storage and the Furniture Vault: when you open and close them. Open each one once after installing.
- Placed furniture: when you enter a house you own, and after you place or remove furniture there.
- Other characters only update when you log in on them. `/ledger chars` lists the ones still missing.

## Summary page (`/ledger`)

- **Tiles:** total items, different items, stacks, gold, vendor value and characters scanned, with the
  change since yesterday.
- **Currencies:** every currency on characters and in the bank (account-wide ones count as bank), with the total and how much it
  changed since yesterday and over the last 7 days. Currencies update the moment they change.
- **Where it is:** items, stacks, vendor value and share for each place (characters, companions, bank,
  craft bag, house storage, Furniture Vault, placed furniture).
- **By item type** and **by quality:** how many of each you own.
- **Most owned:** your top 25 items by count, and where you keep them.
- **Characters:** items carried and equipped, gold, and when each was last scanned. Characters not scanned
  yet are listed too.

The change columns compare against a total the addon saves once a day (at logout, reload, zoning and when
you open the summary). They fill in from your second day with the addon. If there is no saved total from
exactly yesterday or 7 days ago, the column heading shows the date it compares to instead. Saved totals are
kept for 120 days.

Changes are shown in green when they went up and in rose when they went down. Gold amounts show in gold with the game's coin icon.

## Getting it into Excel

**Full file (Windows):**
1. Log out, or type `/reloadui`. The game only writes saved data at those moments.
2. Download the separate **Windows tools** zip (in game: **Get the Windows tools** under `/ledger settings`, or `/ledger tools`; the game asks before it opens your browser. The link is also on the addon's ESOUI page) and unzip it anywhere,
   for example `Documents\Elder Scrolls Online`. It is not part of the addon download, because ESOUI addon
   zips may only hold addon files.
3. Double-click `ExportToExcel.cmd`. It writes `ESO Inventory <date time>.csv` to your Desktop and opens it.

**In game:** `/ledger copy` (or **Copy for Excel** on the summary) opens the copy window. Click **Select All**, press Ctrl+C, paste into Excel.
Large lists are split into pages; paste each page under the last. The copy window leaves out the Item Link
column to keep pages small.

The .cmd and .ps1 files are plain-text scripts you can open in Notepad. They only read the addon's own saved
data file (`Documents\Elder Scrolls Online\live\SavedVariables\FurysInventoryLedger.lua`) and write one CSV
file to your Desktop. They never connect to the internet, never touch the game's files, and only run when you
start them. The game itself never runs them.

## Columns

Account, Character, Location, Container, Item, Qty, Quality, Item Type, Sub Type, Equip Slot, Armor/Weapon,
Trait, Set, Style, Level, CP, Bound, Stolen, Crafted, Vendor Value (each), Vendor Value (total), Item ID,
Scanned, Item Link.

## Settings

The gear on the summary or the copy window, Settings > Addons > Fury's Inventory Ledger, `/ledger settings`
or `/ledgersettings`: open the summary, copy window separator (tab or comma), open the copy window, rescan now.

## Commands

- `/ledger` open the summary
- `/ledger copy` open the copy window
- `/ledger scan` read everything that can be read right now
- `/ledger chars` characters scanned so far, and the ones still missing
- `/ledger forget <name>` remove a deleted character
- `/ledger sep tab` | `comma` separator for the copy window
- `/ledger settings` the settings page
- `/ledger tools` opens the Windows tools download page (Excel export) in your browser

**Keybinds:** Controls > Addon Keybinds > Fury's Inventory Ledger has "Open/close the summary" and
"Open/close the copy window". Both start unbound; pick your own keys.

## Notes

- Saved data is account-wide, separate per account and megaserver. Every account that plays on this PC
  saves into the same file.
- Two game clients at once: each client writes its own copy of the saved data at logout or /reloadui, so the
  one that saves last wins. Let one client log out before the other logs in.
- Item names, qualities and types come from the game in your client's language. Column headings are in English.

## Credits

- Settings page uses **LibAddonMenu-2.0** by Seerah and sirinsidiator.
- Game API details from the ESOUI wiki and ZeniMax's ESO UI source code.
