# Skull Issue - Elder Scrolls Online Addon

A lightweight, specialized UI tracker for the Necromancer **Venom Skull** passive (**AbilityId: 117625**).

## Features
- **Accurate Stack Tracking**: Monitors the Venom Skull passive buff stacks in and out of combat.
- **Custom Visual States**:
  - **1 Stack**: Displays the custom Skull Face (`SkullFace.dds`, 96x96 px).
  - **2 & 3 Stacks**: Displays the Skull Face with the Green Flame (`GreenFlame.dds`, 136x136 px) radiating behind it, and displays **"Spooky"** (Venom Skull is empowered at both 2 and 3 stacks of AbilityId 117625; text can be toggled via `/skullissue text`).
  - **0 Stacks**: Frame hides smoothly when no stacks are active.
- **Automatic Menu Suppression**: Automatically hides when opening full-screen menus such as the World Map, Inventory, Character sheet, Skills, or Crafting stations via ESO's native HUD scene manager.
- **Persistent Out of Combat**: As Venom Skull stacks never decay, the frame stays visible between fights until consumed.
- **Movable & Scaleable**: Unlock and drag anywhere on your screen. Coordinates and scale are saved account-wide.
- **Native DDS Textures**: Converted to DirectDraw Surface (`.dds` DXT5) with alpha channel for high rendering performance in the ESO engine.

## Installation Instructions

1. Extract the zip file so you have a single folder named `SkullIssue`.
2. Move the `SkullIssue` folder into your ESO AddOns directory:
   - **Windows**: `Documents\Elder Scrolls Online\live\AddOns\SkullIssue\`
   - **Mac**: `~/Documents/Elder Scrolls Online/live/AddOns/SkullIssue/`
3. The folder should contain:
   ```
   SkullIssue/
   ├── SkullIssue.txt
   ├── SkullIssue.lua
   ├── SkullIssue.xml
   ├── SkullFace.dds
   ├── GreenFlame.dds
   └── README.md
   ```
4. Launch Elder Scrolls Online (or type `/reloadui` if already in-game).
5. Open your in-game menu (**ESC**) -> **Add-Ons** -> ensure **Skull Issue** is checked. If prompted, enable "Allow out of date add-ons".

## In-Game Slash Commands

| Command | Action |
| :--- | :--- |
| `/skullissue` | Display all available commands in chat |
| `/skullissue unlock` | Unlock frame so you can drag and reposition it |
| `/skullissue lock` | Lock frame in place |
| `/skullissue test [0-3]` | Test and preview stack visuals (e.g. `/skullissue test 2`) |
| `/skullissue scale [0.5-2.5]` | Adjust frame scale (e.g. `/skullissue scale 1.2`) |
| `/skullissue number` | Toggle numeric stack badge on or off |
| `/skullissue text` | Toggle "Spooky" text overlay on or off |
| `/skullissue sound` | Toggle subtle chime sound on reaching empowered state (2 or 3 stacks) |
| `/skullissue reset` | Reset position back to screen center |
