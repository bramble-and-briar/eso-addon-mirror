# Changelog

## 1.0.1
- Safety: the station is switched to the Deconstruction / Refinement / Extraction tab before any action.
- FCO ItemSaver: dedicated API per action (deconstruction, glyph extraction, refinement) instead of the generic lock check; new setting "Respect FCO ItemSaver protection".
- Gamepad mode is skipped for now (not supported yet).
- Manifest: minimum versions for required libraries (LibAddonMenu-2.0>=43).
- Settings are now saved per server (EU/NA); existing settings are copied to every server automatically.
- AI disclosure and credits added.

## 1.0.0 — first public release
- Automatic deconstruction at blacksmithing, clothing, woodworking and jewelry stations.
- Glyph deconstruction at the enchanting station with its own quality limit.
- Raw material refining (ore, raw cloth/hides, rough wood, jewelry dust), including stacks stored in the bank.
- Filters: quality limit, keep crafted items, keep items with unresearched traits, keep set items.
- Never touches locked (game lock / FCO ItemSaver), stolen, companion, equipped or mythic items.
- Preview command, manual run/stop, debug mode.
- English and Russian localization.
