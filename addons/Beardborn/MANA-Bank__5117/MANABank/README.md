# MANA Bank

An Elder Scrolls Online (PC) add-on by **Beardborn** that keeps your bank tidy by your own rules.
Русская версия: [README.ru.md](README.ru.md)

## What it does

When you open the bank, MANA Bank goes through your inventory. For every item that has a rule it:

1. counts how much of it is already in the bank;
2. deposits from the inventory until the bank holds the set number of stacks (partial stacks are filled first);
3. marks everything above the limit that is left in the inventory as **junk**.

Example: rule "Rubedite Ingot — 2 stacks" (200 per stack). Bank has 350, inventory has 120 → 50 are deposited (up to 400), the remaining 70 are marked as junk.

Special values: **0 stacks** = keep nothing in the bank, everything to junk; **unlimited** = deposit everything, never mark as junk.

## Rules

- **Item rule** — right-click an item in the inventory or bank → "Bank: this item" → 0 / 1 / 2 / 3 / 5 / 10 stacks / unlimited.
- **Category rule** — right-click → "Bank: category …", or in the settings. Applies to every item of the category separately.
- An item rule takes priority over a category rule. Rules are account-wide.

## Gold

Keep a set amount of gold on hand: when the bank opens, the excess is deposited and the shortfall is withdrawn (can be turned off). Disabled by default.

## Never touched

- Junk-marked items are never deposited (so you can sell them).
- Stolen and character-bound items are ignored.
- Locked items (game lock or FCO ItemSaver) are never marked as junk.
- House storage chests are ignored — only the regular bank is used.

## Commands

- `/manabank run` — run manually (bank must be open)
- `/manabank list` — show rules
- `/manabank gold 100000` — keep 100,000 gold on hand (also enables gold management)
- `/manabank gold` — toggle gold management
- `/manabanksettings` — open settings

## Requirements

- LibAddonMenu-2.0
- LibCustomMenu

## Compatibility

- **Dustman** also marks junk. Don't give the same item conflicting rules in both add-ons.
- ESO Plus subscriber bank and craft bag are not used.

## License

MIT — see [LICENSE](LICENSE).
