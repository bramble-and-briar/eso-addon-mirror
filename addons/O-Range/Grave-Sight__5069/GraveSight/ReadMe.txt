# GraveSight

GraveSight is a polished Necromancer-themed custom reticle for The Elder Scrolls Online.

Designed for PvP and combat-focused gameplay, GraveSight replaces the default reticle with a spectral crosshair that reacts to stealth, execute opportunities, dangerous enemy abilities, and combat conditions while remaining lightweight and highly configurable.

---

## Features

### Visual States

- Spectral idle reticle
- Stealth-aware reticle coloration
- Enemy targeting coloration during combat
- Smooth opacity, scale, and rotation transitions
- Optional lock rotation when engaging enemies
- Adjustable stealth scaling
- Dynamic pulse effects
- Atmospheric Soul Flare visual system

### Execute Awareness

- Execute state detection
- Custom execute threshold (5%–40%)
- Custom execute message
- Default execute callout: REAP
- Distinct execute coloring
- Execute pulse animation

### PvP Danger Warnings

Highlights the reticle when dangerous enemy abilities are detected.

Current warning support includes:

- Corrosive Armor
- Magma Armor
- Magma Shell
- Fossilize
- Petrify

Danger states override all other reticle modes and use their own color, opacity, and pulse settings.

### Combat Insight Text

Optional information displayed above the reticle:

- Execute callouts
- Current and maximum target health
- Active shield values
- Combat-only display option
- Adjustable font size

### Customization

#### General

- Enable / Disable addon
- Reticle Size
- Enemy Coloring
- Lock Rotation
- Soul Flare on Enemies

#### Effects

- Soul Flare Intensity
- Stealth Scale
- Enemy Pulse Strength

#### Opacity

- Idle Opacity
- Stealth Opacity
- Enemy Opacity
- Danger Opacity

#### Colors

- Idle Color
- Stealth Color
- Enemy Color
- Danger Color
- Execute Color

#### Execute & Insight

- Execute State Enable
- Execute Threshold %
- Execute Message
- Insight Text Size
- HP Information Toggle
- Combat-Only HP Information

#### Danger Warnings

- Enable Danger Warnings
- Corrosive Armor Warnings
- Fossilize Warnings

### User Interface Integration

- Automatically hides the default ESO reticle
- Automatically restores the vanilla reticle when disabled
- Hides while menus and UI screens are open
- Fully integrated with LibAddonMenu-2.0

---

## Requirements

- LibAddonMenu-2.0 (version 43 or newer)

---

## Installation

1. Extract the GraveSight folder into:

   Documents\Elder Scrolls Online\live\AddOns\

2. Install LibAddonMenu-2.0 if not already installed.
3. Launch ESO.
4. Enable GraveSight in the Add-On menu.
5. Type:

   /reloadui

---

## Version History

### 0.8.1

- Added PvP Danger Warning system
- Added Corrosive Armor detection
- Added Fossilize detection
- Added execute-state awareness
- Added configurable execute thresholds
- Added execute callout text
- Added compact HP and shield insight display
- Added adjustable insight font sizing
- Added customizable danger colors and effects
- Expanded animation controls
- Improved targeting awareness
- Improved menu integration
- General optimization and cleanup

### 0.5.0

- Added Soul Flare system
- Added color customization
- Added opacity controls
- Added stealth scaling
- Added enemy pulse effects

---

## Credits

Author: O-Range

Texture:
gravesight.dds

Font:
Friday13

---

From the grave, with precision.