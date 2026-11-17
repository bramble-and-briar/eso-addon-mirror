# Changelog

## 1.4.0 — By Animosity (Guild: CRY)
- **Fixed Character Sheet (`GAMEPAD_STATS`) Scroll-To-Top Bug**:
  - Replaced the post-commit `ZO_PostHook` and `CommitWithoutReselect()` call (which forced `ZO_ParametricScrollList` to reset selection to row 1 on every buff tick or attribute update) with pre-commit persistent `ZO_GamepadEntryData` injection and a post-commit selection guard (`SetSelectedIndexWithoutAnimation`).
  - Added in-place row label updates via `mainList:RefreshVisible()` so toggling cycling or stepping speed in the Character Sheet never rebuilds the list or resets scroll position.
  - Isolated `UI_SHORTCUT_PRIMARY` (`X` button) so it is only registered when highlighting a Favorite Guild Cycler row, keeping native Attribute Respec spinners (`Magicka`, `Health`, `Stamina`), `Outfit`, `Title`, and `Guild` dropdowns 100% conflict-free.
  - Added automatic background pause while viewing the Character Sheet (`pauseInCharacterSheet = true` by default) and automatic sync if you manually pick a guild from ESO's native dropdown.
- **Fixed Quick Dialog Live Refresh & Cursor Retention**:
  - Fixed row selection callbacks in the Quick Dialog so `dialog.info.parametricList` rebuilds properly and preserves your highlighted row position.
- **Fixed Priority Bias Mode & Upgraded Shuffle Bag**:
  - Fixed an issue in Priority Bias Mode where returning to the primary guild reset the secondary cursor and prevented Guilds 3–5 from being reached.
  - Upgraded Random mode to a true Fisher-Yates Shuffle Bag so all favorite guilds appear once per shuffle cycle with no immediate boundary repeats.
- **Added New Features & Quality-of-Life Improvements**:
  - Added **Ping-Pong Bounce (`1 <-> 5`)** rotation mode.
  - Added **Quick Guild Pin (`/fgc pin <1-5|off>`)** in the Quick Dialog, Settings, and slash commands to temporarily lock a single guild without clearing saved favorites.
  - Added **Dungeon / Trial Instance Guild Lock (`pveInstanceOverrideSlot`)** to automatically represent your PvE progression guild in 4-man Dungeons, 12-man Trials, and Arenas.
  - Added **Pause During Crafting / Bank / Shrine Interactions** (`pauseInInteractions = true` by default) and **Pause While Mounted** (`pauseWhenMounted`).
  - Added live currently-displayed guild readout and session switch counter (`/fgc status`).
  - Silenced repetitive startup chat warning by default (`showStartupMessage = false` toggle added).
- **Updated Author & Guild Credits**:
  - Updated developer credit to **Animosity** with special credit to the guild **CRY**.

## 1.3.1
- Removed custom keybind-strip registration from the Guild Hub scene to prevent conflicts with native guild-row selection.
- Kept Character Sheet controls, the add-on settings menu, saved settings, and slash commands intact.
- Updated comments and documentation to clarify that the Guild menu is intentionally not modified.

## 1.3.0
- Enforced a minimum 1-second represented-guild change interval and removed sub-second speed controls.
- Added rate-limit / Error 318 warnings in the startup message, settings, manifest, and README.
- Saved favorite selections by guild ID and added migration from the older slot-based saved settings.
- Synced favorite IDs when guild membership changes and prevented duplicate calls through multiple setter paths.
- Updated the declared ESO API versions through 101051.
