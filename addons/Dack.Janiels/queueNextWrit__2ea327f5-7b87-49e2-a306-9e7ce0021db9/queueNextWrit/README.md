# queueNextWrit

Queue up your next completable master writ for turning in to Rolis.

After you turn in a master writ, the addon looks through your backpack for the next sealed master writ whose crafted result is already there. If it finds one, it uses that writ and accepts the quest. If none of the sealed writs can be turned in yet, it leaves them alone.

There are no settings. The same path runs on keyboard and gamepad.

## Turn-in loop

1. A crafting quest completes, and its name is a master writ quest name for your client language (`GetCVar("language.2")`).
2. The backpack is scanned from the first slot forward. The first sealed master writ that meets the checks below is chosen.
3. 300 ms after that quest complete, keyboard toggles the HUD scene. Gamepad returns to the base scene and waits until the gamepad interaction scene is hidden.
4. Keyboard uses the sealed writ 300 ms later, then accepts the offered quest 200 ms after the use. Gamepad uses the sealed writ once that interaction scene is hidden, and accepts when the quest offer arrives.

Each completed master writ queues at most one new writ. Turn that one in and the addon looks for the next match. A sealed writ that fails the checks is skipped, and a later slot can still be chosen in the same pass.

Bank, house storage, and equipped items are not counted. The result has to be in the backpack, and it has to be crafted by the character you are on.

## What counts as completed

The sealed writ's icon selects the craft. Writs with any other icon, including holiday writs, are ignored.

### Blacksmithing, clothier, woodworking, jewelry

The backpack needs one item that matches the sealed writ:

- Crafting skill matches the writ.
- Champion points are 150.
- Quality is the required writ quality.
- Set and trait match.
- Style matches when the writ names a style. Jewelry writs do not.
- The piece matches the writ's template: weapon type, or armor weight and equip slot. A light robe and a light shirt are separate pieces.

### Enchanting

One glyph with the writ's item id. Writ level `207` is CP 150. Writ level `225` is CP 160. Quality is the writ quality or higher.

### Provisioning

Enough of the result food or drink. The required count is two crafts of that recipe (`GetRecipeResultQuantity` with 2 iterations). If the recipe cannot be resolved, the writ is skipped.

### Alchemy

A combined stack of 16, at CP 150, with the writ's three effects in any order.

- Solvent id `199` requires a potion.
- Any other solvent id requires a poison.

## Quest names

The completed quest must be a crafting quest, and its name must be a master writ quest name for the current client language. Those names are included for de, en, es, fr, jp, ru, and zh. The exact strings live in `queueNextWrit.lua`. They are omitted here because a few of the official quest names are rejected by the Bethesda description filter.
