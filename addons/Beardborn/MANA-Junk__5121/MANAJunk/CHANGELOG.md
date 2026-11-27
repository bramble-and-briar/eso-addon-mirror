# Changelog

## 1.0.1
- FCO ItemSaver: uses its junk/sell protection API instead of the generic lock check; new setting "Respect FCO ItemSaver protection".
- Manifest: minimum versions for required libraries (LibAddonMenu-2.0>=43, LibCustomMenu>=730).
- Settings are now saved per server (EU/NA); existing settings are copied to every server automatically.
- AI disclosure and credits added.

## 1.0.0 — first public release
- Marks items as junk on pickup and via "Scan now".
- Filters: Ornate gear, treasures, trash, known recipes, lower-tier crafting materials, food/drinks and potions/poisons (except player-crafted and Crown).
- Item and category rules: keep N stacks in the inventory, the rest goes to junk.
- Junk sale window at merchants with a full list sorted by quality and value, sells only after confirmation.
- Never touches locked (game lock / FCO ItemSaver) or stolen items; pickups are ignored while a store, bank or trade window is open.
- English and Russian localization.
