# MANA Recycling

An Elder Scrolls Online (PC) add-on by **Beardborn** that deconstructs junk gear and refines raw materials for you.
Русская версия: [README.ru.md](README.ru.md)

## What it does

When you open a **blacksmithing, clothing, woodworking or jewelry station**, MANA Recycling:

1. deconstructs gear from your inventory that matches your filters (in batches, like the game's own multi-deconstruct);
2. then refines raw materials of that station (ore, raw cloth and hides, rough wood, jewelry dust) — full tens only, including stacks in your bank.

At an **enchanting station** it deconstructs glyphs with their own settings.

## Settings

| Setting | Default |
|---|---|
| Deconstruct automatically | on |
| Deconstruct quality up to (white … gold) | green |
| Keep crafted items (e.g. for daily writs) | on |
| Keep items with unresearched traits | on |
| Keep set items | on |
| Refine raw materials / from the bank | on / on |
| Deconstruct glyphs, glyph quality limit, keep crafted glyphs | on, green, on |

## Never touched

Locked items (game lock or FCO ItemSaver), stolen items, companion gear, equipped items and mythic items. Junk-marked raw materials are not refined.

## Commands

- `/manarecycling preview` — what would be deconstructed/refined and what is skipped and why (changes nothing)
- `/manarecycling run` / `stop` — run or stop manually at a station
- `/manarecycling debug` — detailed chat log
- `/manarecyclingsettings` — settings

## Notes

- Needs at least 3 free inventory slots for materials.
- Before working, the station is switched to the Deconstruction / Refinement / Extraction tab, so protections apply exactly as in the vanilla UI.
- FCO ItemSaver: items protected against deconstruction, glyph extraction or refinement are skipped (setting "Respect FCO ItemSaver protection", on by default).
- Waits while the station is busy (e.g. Dolgubon's Lazy Writ Crafter).
- Turn off automatic deconstruction in other add-ons (e.g. Dustman) to avoid conflicts.
- The universal deconstruction station and gamepad mode are not supported yet.

## Requirements

LibAddonMenu-2.0

## License

MIT — see [LICENSE](LICENSE).

## AI disclosure

The code and translations of this add-on were written with the help of an AI assistant (Claude by Anthropic), based on my design and instructions. I test releases in game and maintain the add-on.

## Credits

- LibAddonMenu-2.0 by Seerah, sirinsidiator and contributors
- FCO ItemSaver API by Baertram — thanks for the review and advice on proper protection checks
- Inspired by Dustman, Mass Deconstructor and Yudo's Inventory Processor
