# Changelog

## 0.2.3-beta - 2026-11-14

- Added a Colors menu accessible from the title bar or `/surveys colors`.
- Added Plum, Emerald, Ocean, Ember, Midnight and Rose presets, plus independent
  background, title bar and border choices.
- Colors apply immediately, save per character, and carry across the minimized
  tracker, quantity box, help/report copy window and color menu.
- Added Reset Colors to restore the default Plum preset.

## 0.2.2-beta - 2026-11-14

- Gave Survey Sidekick a separate color scheme: dark plum background, violet title
  bar, lavender borders and pale lavender text.
- Applied the matching colors to the minimized tracker, copy/help window and
  quantity entry box.

## 0.2.1-beta - 2026-11-14

- Removed the automatic startup chat message.
- Replaced the protected TTC price lookup with a direct call to its documented API;
  missing TTC and missing price data still leave materials marked as unpriced.
- Added local references for repeatedly used Lua functions, game APIs and UI constants.
- Clarified the AI disclosure and credits in the release documentation and website copy.
- Kept existing saved variables, gathering rules and controls unchanged.

## 0.2.0-beta — 2026-11-14

First public-beta candidate.

- Survey inventory with duplicate counts and crafting-type selection.
- Optional LibTreasure map waypoints and nearest-unlocked-wayshrine travel.
- Live gathering totals, automatic estimated loot split and named material collection goals.
- The Hoard Report with saved runs, personal record, copyable summary and detailed export.
- Optional TTC value estimates and explicit unpriced totals.
- Smaller adjustable window, live minimized bar and action-button descriptions.
- Quantity input takes focus when clicked; survey rows and dropdowns have no tooltips.
- Window position and open/closed state now survive reload/login.
- Hidden windows no longer redraw for each loot event; visible loot bursts share one refresh.
- Collection setup restores the full window when opened from its slash command.
- Public-facing report text and documentation cleaned up; existing saved data retained.
