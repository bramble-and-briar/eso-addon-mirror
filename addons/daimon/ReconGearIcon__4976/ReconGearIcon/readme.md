# ReconGearIcon

**Requires:** LibAddonMenu-2.0

> **AI disclosure:** The code of this addon was written with the help of an AI assistant (Claude) and reviewed and tested in game by the author.

Shows the game's own **Reconstructed** icon on reconstructed items in the character window's equipment panel.
The inventory already shows this icon in its trait column, but the equipment panel does not.
Optionally the same icon can also be shown on the item icons in the inventory.

## Features

- Marks reconstructed items in all equipment slots (armor, jewelry, both weapon bars).
- Optional: the same icon on the item icons in the inventory, bank and house storage. The game's own Reconstructed icon is then hidden on those rows, so it is not shown twice.
- Works with grid view addons such as GridList: in grid view the icon stays in the corner of the cell, whatever the item icon size.
- Updates automatically when items are equipped, removed, swapped or moved.
- Default position (bottom right) is chosen to avoid conflicts with other addons' slot indicators.

## Settings

Open **Settings > Addons > ReconGearIcon**, or type `/recongearicon`.

| Section | Setting | Options | Default |
|---|---|---|---|
| Equipment panel | Icon size | 8–40 px | 26 px |
| Equipment panel | Icon position | Top left, Top right, Center, Bottom left, Bottom right | Bottom right |
| Inventory | Show icon in inventory | On / Off | Off |
| Inventory | Icon size | 8–40 px | 26 px |
| Inventory | Icon position | Top left, Top right, Center, Bottom left, Bottom right | Bottom right |
| Appearance | Icon color | Any color | Yellow |
| Appearance | Icon opacity | 0–100 % | 60 % |

Inventory size and position can only be changed when **Show icon in inventory** is on.
Color and opacity are shared by both places. Changes are applied immediately. Settings are saved account-wide.

## Version history

### 1.0 (2026-10-22) – API 101051
- First public release.
- New option: show the icon also in the inventory, bank and house storage, with its own size and position settings. The game's own Reconstructed icon is hidden on those rows.
- Settings menu split into sections: Equipment panel, Inventory, Appearance.
- Grid view support (e.g. GridList) without a dependency: the icon is anchored to the grid cell.

### 0.4 (2026-10-21) – API 101051
- Renamed from ReconIcon to ReconGearIcon.
- New defaults: icon size 26 px, color pure yellow, opacity 60 %.
- Fixed: icon stayed on the off hand slot when a two-handed weapon was equipped.
- The icon is now drawn as a solid silhouette, so the chosen color is shown at full brightness.

### 0.3 (2026-10-21) – API 101051
- Added icon color and opacity settings.

### 0.2 (2026-10-21) – API 101051
- Added settings menu (LibAddonMenu-2.0): icon size and position.
- Settings are saved account-wide (SavedVariables).

### 0.1 (2026-10-21) – API 101051
- First test version.
- Reconstructed icon in the character equipment panel.

---

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
