# Known Vendor Filter

**Version:** 1.1  
**Author:** Ypselon  
**Interface:** ESO PC/Mac, keyboard and mouse  
**ESO API:** 101051

Hide already known or collected items at NPC merchants, guild traders and when withdrawing from your personal bank. The filter settings are shared, but each window has its own on/off switch.

## Supported items

- Food and drink recipes and furnishing plans
- Crafting motifs and outfit style pages
- Scribing grimoires and scripts
- Collectibles and runeboxes
- Set items already collected in the sticker book

Only items positively identified as known or collected are hidden. Recipes and crafting motifs are checked for the current character. Collected set pieces may still be useful for a different trait or for equipping; disable that category if needed.

## Using the filter

1. Open an NPC merchant, the **withdrawal** tab of your personal bank, or a guild trader's search.
2. Click **Hide known** to turn filtering on or off for that window.
3. Click **Filter options** to choose the categories. This selection applies across all three windows; their on/off switches are independent.
4. While the options window is open, drag the buttons to reposition them. Close the options to lock them. Positions are saved separately for each window and can be reset in the options.
5. Use **/kvf** to open the options at any time, including if you have hidden the buttons.

In the options you can show or hide the buttons separately for NPC merchants, the personal bank and guild traders. Hiding a window's buttons also turns off its filter.

The standalone guild trader filter applies to the currently loaded search page. If a page is completely filtered, the addon can skip up to ten consecutive empty pages. A partially filled page is retained so its results remain available. If **AwesomeGuildStore** is active, Known Vendor Filter hides its own guild trader buttons and leaves that addon to manage its own filters.

Bank deposit, guild banks, house storage and the gamepad interface are not supported.

## Installation

Extract the ZIP into the ESO AddOns directory, for example:

`Documents/Elder Scrolls Online/live/AddOns/KnownVendorFilter/`

The folder must directly contain `KnownVendorFilter.txt`. Enable the addon in ESO; if the game is already running, use `/reloadui` or restart ESO if it does not appear in the addon list.

## Libraries

**No libraries are required.**

- **Optional: LibFilters-3.0** helps compatibility with other addons filtering the same merchant or bank lists.
- **Optional: LibAddonMenu-2.0** adds the options under Settings → Add-ons. Without it, the in-game options button and `/kvf` remain available.
- **Optional: AwesomeGuildStore** provides its own guild trader filters. While it is enabled, this addon's guild trader buttons are hidden; merchant and bank filters remain available.

## Languages

The addon automatically detects the ESO client language. It includes English, German, French, Spanish, Russian, Japanese and Simplified Chinese. Unrecognized languages use English.

## AI disclosure

The code and translations were created with the help of an AI assistant. The idea, feature design, and in-game testing are the author's. Please report bugs or performance issues on the ESOUI addon page.
