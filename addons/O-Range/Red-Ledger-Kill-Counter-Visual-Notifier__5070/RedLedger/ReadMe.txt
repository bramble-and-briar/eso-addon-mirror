# Red Ledger

Version: 0.6  
Author: O-Range  
Game: The Elder Scrolls Online  
API: 101051 / 101052

A lightweight PvP kill counter with dramatic blood splatter effects.

---

## Features

- On-screen session kill counter (Roman numerals or normal numbers)
- Custom “Friday the 13th” style font for the counter
- Lifetime kill tracking (account-wide)
- Blood splatter effects on every kill using a single high-quality master decal
- Heavy randomization: size, rotation, flips/mirrors, color variation
- Fully movable and resizable counter
- Works in Cyrodiil, Imperial City, Battlegrounds, and open-world PvP
- Settings menu via LibAddonMenu-2.0
- Slash commands + keybind for testing

---

## Installation

1. Download and extract the `RedLedger` folder into your `AddOns` directory.
2. Make sure **LibAddonMenu-2.0** is installed (optional but recommended for the settings panel).
3. Enable the addon in the character select screen or in-game AddOn menu.
4. Type `/reloadui` after installing or updating.
5. Fully restart the game once if the custom font does not appear.

---

## How Kill Detection Works

Red Ledger uses the game’s dedicated PvP events for reliable kill tracking:

- `EVENT_PVP_KILL_FEED_DEATH` → Cyrodiil, Imperial City, open-world PvP
- `EVENT_BATTLEGROUND_KILL` → Battlegrounds

These are the same events the game uses for the official kill feed and scoreboard.

A combat-event fallback is still present for edge cases (such as certain duels).

A short debounce prevents rare double-counting.

---

## Commands

| Command              | Description                          |
|----------------------|--------------------------------------|
| `/redledger test`    | Simulate a kill + blood splash       |
| `/redledger reset`   | Reset session kill counter           |
| `/redledger lifetime`| Show lifetime kills                  |
| `/redledger toggle`  | Toggle counter visibility            |
| `/redledger`         | Show available commands              |

**Keybind:**  
`Simulate Killing Blow` (Controls → AddOns)

---

## Settings

Open **Settings → AddOns → Red Ledger**

- Unlock Counter Position
- Use Roman Numerals
- Counter Size (0.6 – 2.2)
- Hide Counter Completely
- Hide Counter in PvE Zones
- Play Sound on Kill
- Reset Session Kill Count

Lifetime kills are displayed at the bottom of the settings panel.

---

## Notes

- The counter starts at **N** (Roman for 0) or **0**.
- Blood texture is located in `RedLedger/texture/blood_master.dds`.
- Custom font is located in `RedLedger/font/Friday13v12.slug`.
- Session kills reset when you reload UI or relog.
- Lifetime kills are saved account-wide.

---

## Changelog

### v0.6
- Switched to a single high-quality master blood decal (`blood_master.dds`)
- Added heavy randomization: size, full rotation, horizontal/vertical flips, color & desaturation variation
- Feathered texture edges – black line / hard edge issue completely eliminated
- Added custom Friday-style font for the kill counter (Roman & Arabic numerals)
- Major code cleanup and polish
- Improved multi-splat weighting (1–3 splatters per kill)
- Richer blood-red counter color
- Better animation cleanup

### v0.5
- Added counter visibility toggle command
- Added hide counter setting
- Added auto-hide in PvE option
- Added kill sound toggle
- Improved settings panel organization
- Continued use of dedicated PvP kill feed events
- Combat-event fallback retained
- Debounce protection against double counting
- Enhanced blood splatter intensity
- Added sound effect on kill

### v0.4
- Completely reworked kill detection
- Now uses `EVENT_PVP_KILL_FEED_DEATH` and `EVENT_BATTLEGROUND_KILL`
- Added combat-event fallback with stricter name checks
- Added debounce to prevent double counting
- Fixed issue where real PvP kills were not registering
- +20% blood intensity (larger size + longer fade)
- Brighter blood effects
- SOUNDS.DEATH on kill

### v0.3
- Initial public version
- Counter, blood effects, settings, slash commands

---

## Credits

Created by **O-Range**