# MANA Junk

An Elder Scrolls Online (PC) add-on by **Beardborn** that marks unwanted items as junk and sells them — only after you confirm.
Русская версия: [README.ru.md](README.ru.md)

## What it does

1. **On pickup** every new item is checked and marked as junk if it matches your filters or rules.
2. **Scan now** (settings) or `/manajunk scan` checks the whole inventory.
3. **At a merchant** a window lists all junk (quality-sorted, rarest first, with prices and the total). Press **Sell** or **Cancel**.

## What counts as junk (each is a checkbox)

- Ornate gear (gold pouch icon)
- Treasures (not stolen), incl. antiquity treasures
- Trash items
- Known recipes and blueprints (for the current character)
- Lower-tier crafting materials — below the highest tier of the same craft you have in your inventory or bank
- Food and drinks (except player-crafted)
- Potions and poisons (except player-crafted and Crown Store ones)

## Rules

Keep **N stacks in the inventory**, everything above goes to junk (0 = all to junk):
- **Item rule** — right-click an item → "Junk: keep in the inventory".
- **Category rule** — right-click → "Junk: category …" or in the settings.

Priority: item rule → category rule → checkboxes.

## Never touched

Locked items (game lock or FCO ItemSaver) and stolen items. New items are not checked while a store, bank, guild bank or trade window is open.

## Commands

- `/manajunk preview` — what would be marked and why (changes nothing)
- `/manajunk scan` — mark junk now
- `/manajunk materials` — material tier diagnostics
- `/manajunksettings` — settings

## Notes

If you use **Dustman**, disable its auto-sell (otherwise junk is sold without the confirmation window) and avoid conflicting rules.

## Requirements

LibAddonMenu-2.0, LibCustomMenu

## License

MIT — see [LICENSE](LICENSE).

## AI disclosure

The code and translations of this add-on were written with the help of an AI assistant (Claude by Anthropic), based on my design and instructions. I test releases in game and maintain the add-on.

## Credits

- LibAddonMenu-2.0 by Seerah, sirinsidiator and contributors
- LibCustomMenu by votan
- FCO ItemSaver API by Baertram
- Inspired by Dustman
