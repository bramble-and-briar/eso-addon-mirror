# Changelog

## 1.0.1
- FCO ItemSaver: uses its junk/sell protection API instead of the generic lock check; new setting "Respect FCO ItemSaver protection".
- Manifest: minimum versions for required libraries (LibAddonMenu-2.0>=43, LibCustomMenu>=730).
- Settings are now saved per server (EU/NA); existing settings are copied to every server automatically.
- AI disclosure and credits added.

## 1.0.0 — first public release
- Bank rules per item (right-click menu) and per category (settings or right-click menu): keep N stacks in the bank, 0 = everything to junk, or unlimited.
- On opening the bank: deposits items up to the limit (fills partial stacks first), marks the excess left in the inventory as junk.
- Junk-marked, stolen and character-bound items are never deposited; locked items (game lock / FCO ItemSaver) are never marked as junk.
- Gold management: keep a set amount on hand — excess is deposited, the shortfall is withdrawn.
- Settings panel (LibAddonMenu), chat reports, slash commands.
- English and Russian localization.
