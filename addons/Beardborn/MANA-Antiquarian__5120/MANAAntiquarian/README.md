# MANA Antiquarian

An Elder Scrolls Online (PC) add-on by **Beardborn**: a friendly window for your antiquity leads.
Русская версия: [README.ru.md](README.ru.md)

## Open

`/manadig` (or `/manaantiquarian`) or your own key: Controls → MANA Antiquarian. The window can be moved and resized; size and position are remembered.

## My leads (default)

Your leads grouped by zone — **current zone on top**, then zones with located dig sites, then the rest.

| Column | Meaning |
|---|---|
| Status | **Dig** (site located), **Scry** (can scry right here), **Unavailable** (right zone, but not now), **Other zone** |
| Antiquity | name colored by quality |
| Set / reward | set or reward; for multi-part sets the **collection progress**, e.g. `2/5 · completed ×1` |
| Codex | discovered codex entries, e.g. `1/3` |
| Expires | days; hours when less than a day |
| Scry / Map | start scrying; open the zone map and track the antiquity |

Double-click a row to scry. The tooltip lists every part of the set with a checkmark or whether you own its lead. Each zone's free lead (e.g. *Augur's Bones*) is shown for the current zone or when already started.

Click a column header to sort within zones.

## All leads

The **All leads** toggle adds leads you do not have, with hints where to find them, and Display Leads-style filters (Obtainable, Codex incomplete, Never excavated, Group dungeons, Latest DLC, All; type: hide common, sets only).

## More

- Search by name, zone or set.
- Zones from DLCs you do not own are hidden automatically; adjust in settings (`/manadigsettings`).
- Chat reminder about expiring leads on login (1 hour / 1 day / 7 days), or `/manadig alert`.

## Display Leads (optional)

If **Display Leads** is installed, MANA Antiquarian uses its location hints, find zones and group dungeon/latest DLC data, and double-clicking a row in the Display Leads window starts scrying. Display Leads itself is not modified.

## Requirements

LibAddonMenu-2.0. Optional: Display Leads.

## License

MIT — see [LICENSE](LICENSE).

## AI disclosure

The code and translations of this add-on were written with the help of an AI assistant (Claude by Anthropic), based on my design and instructions. I test releases in game and maintain the add-on.

## Credits

- LibAddonMenu-2.0 by Seerah, sirinsidiator and contributors
- Display Leads by remosito — location data and the idea of a full leads list (not modified)
