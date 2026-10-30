# Changelog

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
