# ALTHI – Changelog

## 0.9.4 · Maintenance

- Unique ALTHarvestItems namespace; updated bindings, existing SavedVariables retained.
- Native crafting-bag and inventory update-reason filters.
- English/client-language manifest loading and separate optional language packs.
- Neutral localization keys; category/source labels and abbreviations in language files.
- Updated AI disclosure, source credits and permissions.
- Based on public 0.9.3, without experimental fishing features.

## 0.9.3 · Cosmetic hotfix

- Rare-material notification reduced to 60% of its previous size; remains centered in the upper third.
- Active column sorting uses v (descending) and ^ (ascending) for all five overview columns.

## 0.9.2 · Beta candidate

- Settings now opens the existing integrated ALTHI panel when LibAddonMenu is available. A standalone fallback remains, without a new required dependency.
- Unified registration and lifecycle for own settings, filter, view, language and price windows. Conditional Escape handling closes the top ALTHI dialog, preserves native confirmations and passes through when no ALTHI dialog is visible.
- Consistent top-right X; save/apply/cancel behavior retained. Closing a parent also cancels dependent editors instead of leaving orphan windows.
- Added an explanation above the guild-trader calculation: the setting affects all prices and values throughout the addon.
- Removed the obsolete filter-footer tooltip instruction. Added bilingual beta installation/scope/feedback documents and a curated public-package builder.

## 0.9.1

- Optional consistent 7% sale-cut display with gross-price storage and a colored status indicator.
- Larger rare notices in the upper third of the screen; English first-run language choice.
- Material-source review: 190 specific IDs, 14 native type rules, native vendor/trait mapping and updated seed candidates.
- Loot-setting static/runtime-spy audit; no direct setting writes found.

## 0.9.0

- Optional automatic overview hiding in ESO menus; directional minimize controls.
- Fading row separators, top-right filter X/Escape and weapon/armor/jewelry trait tabs.

## 0.8.x

- Session-only overview rows, independent minimized tracking, additional keybindings.
- Sticky category controls/tabs, native trait names and rare-resource notices.
- Compact window widths and price/source UI improvements.

## 0.7.x and earlier

- Standalone ID-based resource tracking, pricing adapters, active-time sessions and crafting-bag snapshots.
- Craft filter redesign, localization and source provenance foundations.
