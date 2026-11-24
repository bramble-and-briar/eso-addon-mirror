# Changelog

## 1.4.0
- New button in Settings > Addons > Fury's Inventory Ledger: "Get the Windows tools" opens the download page for the Excel export in your browser (the game asks first). /ledger tools does the same.

## 1.3.0
- New look, "Fury Night", shared by all of Fury's addons: deep blue-black windows with an indigo frame, a soft glow behind the title, a violet line under it and a bag icon beside it. Titles use the game's book font (Prose Antique).
- Summary page: blue column headers with a divider, striped rows, violet lines under each section, and gold amounts in gold with the game's coin icon.
- Changes since yesterday and over 7 days are green when they went up and rose when they went down.
- Chat messages and the settings title use the new violet color.
- Nothing about what the addon does or your settings has changed.

## 1.2.3
- New keybinds: Controls > Addon Keybinds > Fury's Inventory Ledger now has "Open/close the summary" and "Open/close the copy window". Both start unbound; pick your own keys.

## 1.2.2
- Esc now closes the summary and copy windows. They also bring up the mouse cursor when they open, and close when you open another game menu.

## 1.2.1
- Summary page: the account and "characters scanned" line sits under the title again instead of over the Currencies table.
- Summary and copy windows now have a solid background, so other windows and addons behind them no longer show through.
- Currencies table: account-wide currencies are listed under Bank, so the separate Account column is gone.
- Mythic items now show as "Mythic" under By quality on the summary page and in the Quality column of the copy window and export (they were left blank).

## 1.2.0
- New summary page, opened by /ledger: totals by location, item type and quality, your 25 most-owned items, and a line per character (carried, equipped, gold, last scanned).
- Currency running totals: on characters, in the bank and account-wide, with the change since yesterday and over the last 7 days.
- Currencies now update the moment they change, not only when an item does.
- The copy window moved to /ledger copy (or Copy for Excel on the summary). Both windows have a settings gear.
- The Excel export scripts (ExportToExcel.cmd and .ps1) are now a separate Windows tools download, since ESOUI addon zips may only hold addon files. They work from any folder.

## 1.1.1
- Reads your bags only when an item really changes. Durability and charge updates (constant in combat) no longer wake the addon.
- Now asks for LibAddonMenu-2.0 version 43 or newer, the current release.

## 1.1.0
- First public release.
- Lists every character's backpack, equipped gear, summoned companion's gear and wallet.
- Account-wide: bank (including ESO Plus space), craft bag, banked and account currencies.
- House storage coffers (by name or nickname) and the Furniture Vault, read when opened.
- Furniture placed in houses you own, counted per house.
- 24 columns: quality, type, slot, armor/weapon type, trait, set, style, level, CP, bound, stolen, crafted, vendor value, item ID, scan time and item link.
- In-game copy window with pages, tab or comma separated, ready to paste into Excel.
- ExportToExcel.cmd (Windows) writes the full list to a CSV on your Desktop and opens it.
- Settings page: gear on the copy window, Settings > Addons, or /ledger settings. Requires LibAddonMenu-2.0.
- /ledger chars lists characters still to be scanned; /ledger forget removes a deleted one.
