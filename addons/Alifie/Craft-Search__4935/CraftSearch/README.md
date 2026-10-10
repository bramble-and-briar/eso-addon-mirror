# Craft Search

Version 1.0 · by teodor

Adds a search box to the furnishing recipe list at every crafting station, so you can find a blueprint, pattern, diagram, praxis, formula or design by typing part of its name instead of scrolling through every category.

## What it does

- Adds a search box to the **Recipes** tab at blacksmithing, clothing, woodworking, jewelry, enchanting and alchemy stations.
- Adds the same box to the **Furnishings** tab at the provisioning station.
- Filters the recipe list as you type. Matching ignores upper/lower case and finds the text anywhere in the name, so `bed` finds every recipe with "bed" anywhere in its name.
- Shows nothing extra anywhere else. The box stays hidden on the provisioning station's food, drink and filleting tabs, and on all item lists.

## Installing

### Manual install

1. Close Elder Scrolls Online, or be ready to type `/reloadui` in chat afterwards.
2. Open your AddOns folder:
   - **Windows:** `Documents\Elder Scrolls Online\live\AddOns`
   - **Mac:** `~/Documents/Elder Scrolls Online/live/AddOns`

   If your Documents folder is synced with OneDrive, it is usually `OneDrive\Documents\Elder Scrolls Online\live\AddOns`.
3. Extract the zip into that folder. The result should be `AddOns\CraftSearch\CraftSearch.txt`, not `AddOns\CraftSearch\CraftSearch\CraftSearch.txt`.
4. Start the game. On the character select screen, click **Add-Ons** and make sure **Craft Search** is ticked.
5. If Craft Search is marked "out of date", tick **Allow out of date add-ons** at the top of that screen. The addon still works; the warning only means the game version number in the addon is older than the game.

### Updating

Delete the old `CraftSearch` folder from your AddOns folder, then follow the install steps again.

### Uninstalling

Delete the `CraftSearch` folder from your AddOns folder.

## Using it

1. Go to any crafting station and open the **Recipes** tab. At a provisioning station, open the **Furnishings** tab.
2. Click the search box under the "Has ingredients / Has skills / Quests only" checkboxes and type part of a recipe name.
3. Press **Enter** to close the box. Clear the text to see the full list again.

The search works together with the game's checkboxes. If a recipe you know is missing, untick **Has ingredients** or **Has skills**.

## Limitations

- Works in the keyboard and mouse interface only, not in gamepad mode.
- Searches recipe names only, not ingredients or categories.

## Troubleshooting

**The search box doesn't appear.** Check that Craft Search is enabled in the Add-Ons menu, and that you are on a furnishing recipe tab, not an item list.

**The box overlaps the checkboxes or the recipe list.** Open `CraftSearch.lua` in a text editor. Line 6 has three numbers that set the box's position and how far the list moves down. Adjust them, save, and type `/reloadui` in chat.

**The "out of date" warning bothers you.** Type `/script d(GetAPIVersion())` in chat to see the current game version number. Put that number on the `## APIVersion:` line of `CraftSearch.txt`, save, and type `/reloadui`.
