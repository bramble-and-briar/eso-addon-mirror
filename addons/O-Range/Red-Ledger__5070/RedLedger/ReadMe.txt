# Red Ledger

Version: 0.5
Author: O-Range
Game: The Elder Scrolls Online
API: 101051 / 101052

A lightweight PvP kill counter with dramatic blood splatter effects.

---

## Features

- On-screen session kill counter (Roman numerals or normal numbers)
- Lifetime kill tracking
- Blood splatter effects on every kill
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

---

## How Kill Detection Works (v0.5)

Red Ledger uses the game's dedicated PvP events for reliable kill tracking:

- `EVENT_PVP_KILL_FEED_DEATH` → Cyrodiil, Imperial City, open-world PvP
- `EVENT_BATTLEGROUND_KILL` → Battlegrounds

These are the same events the game uses for the official kill feed and scoreboard.

A combat-event fallback is still present for edge cases (such as certain duels).

A short debounce is included to prevent rare double-counting.

---

## Commands

| Command | Description |
|----------|-------------|
| `/redledger test` | Simulate a kill + blood splash |
| `/redledger reset` | Reset session kill counter |
| `/redledger lifetime` | Show lifetime kills |
| `/redledger toggle` | Toggle counter visibility |
| `/redledger` | Show available commands |

**Keybind:**

`Simulate Killing Blow` (can be bound in Controls → AddOns)

---

## Settings

Open **Settings → AddOns → Red Ledger**

- **Unlock Counter Position** – Allows you to drag the counter
- **Use Roman Numerals** – Toggle between Roman and normal numbers
- **Counter Size** – Scale the counter (0.6 – 2.2)
- **Hide Counter Completely** – Completely hides the counter
- **Hide Counter in PvE Zones** – Automatically hide outside PvP areas
- **Play Sound on Kill** – Toggle death sound effect
- **Reset Session Kill Count** – Instantly reset the session counter

Lifetime kills are displayed at the bottom of the settings panel.

---

## Notes

- The counter starts at **N** (Roman for 0) or **0**.
- Blood textures are located in `RedLedger/texture/`.
- Session kills reset when you reload UI or relog.
- Lifetime kills are saved account-wide.

---

## Changelog

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