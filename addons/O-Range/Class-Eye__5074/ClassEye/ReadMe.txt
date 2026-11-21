# ClassEye Changelog

## Version 1.0.3 (Current)
- Renamed "Classic" style → "Base" (file: Base.dds)
- Renamed "Nightblade" style → "Blade" (file: Blade.dds)
- Fixed texture loading issues with the previous Classic and Nightblade filenames
- Kept full index-based reticle system for reliability
- Debug messages remain enabled for now (can be removed later)

## Version 1.0.2
- Switched from string-key texture lookup to index-based system
- Significantly improved reliability of style switching
- Added forced texture reload (SetTexture("") then real path)
- Bumped SavedVariables to version 7

## Version 1.0.1
- Improved ApplyReticleTexture() with better fallback and force-reload
- Added temporary debug chat messages showing which texture path is being applied
- Bumped SavedVariables to version 6

## Version 1.0.0
- Initial release of ClassEye (converted from StormEye 0.3.0)
- Added Reticle Style dropdown with 8 class styles + Classic
- Dynamic texture switching (no /reloadui required)
- Reorganized settings menu into clear sections:
  - General
  - Combat
  - Effects
  - Opacity
  - Colors
- Updated default opacities:
  - Idle: 55
  - Stealth: 75
  - Enemy: 75
- Expanded Reset button to restore style + all visual settings
- Removed "Hide in First Person" option (was causing errors)
- Full rename from StormEye → ClassEye (addon name, windows, saved vars, etc.)
- Bumped SavedVariables to version 5

--------------------------------------------------
# StormEye History (pre-ClassEye)

## 0.3.0
- Added Lightning Intensity slider
- Added Stealth Scale slider
- Added Enemy Pulse Strength slider
- Added optional lightning on enemies
- Added Hide in First Person option
- Smooth opacity transitions
- Reset Colors & Opacities button
- Major polish pass

## 0.2.1
- Independent opacity sliders for Idle, Stealth and Enemy

## 0.2.0
- Full RGB color pickers (Idle / Stealth / Enemy)
- Removed old stealth presets

## 0.1.6
- Initial release