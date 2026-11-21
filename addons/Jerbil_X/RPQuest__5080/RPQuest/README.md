# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.1.0-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20ES-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

**English** | [Español](README.es.md)

A native, **zero-dependency** add-on for **The Elder Scrolls Online** (`APIVersion: 101051`) that lets you create, play, complete, and share **custom Roleplay quests** directly inside ESO's native UI.

---

## Key Features

- **Native Quest Journal Integration (`J`):** Adds a dedicated **RPQuest** tab inside the standard Quest Journal (`ZO_QuestJournal_Keyboard`) with separate **Prepared** (authored) and **Received** (active/playable) quest lists.
- **Reticle NPC Target Capture:** Aim at any living NPC and press your keybind (or `/rpquest capture`) to register objectives automatically. Capturing the same NPC name multiple times stacks into `Imp x3`; different named NPCs are tracked individually.
- **Hidden Discovery Points:** Capture in-world exploration coordinates (`Keybind` or `/rpquest discovery`) with configurable trigger radii (`Small`, `Medium`, `Large`) without cluttering the map or compass with spoilers.
- **Optional Stealth / Undetected Condition:** Require players to complete objectives without being detected in combat.
- **World Map Search Area (`M`):** Displays an approximate search circle (`ZO_PinBlob`) on the World Map using a deterministic, fixed random offset—keeping the target inside the circle without revealing its exact center. Automatically clears upon completion or deactivation.
- **Native NPC Dialogue Injection:** Bind custom RPQuest dialogue lines to native ESO NPCs (via reticle capture or NPC name), injected seamlessly into the native interaction window without altering original NPC options.
- **Combat & Discovery Tracking + Native Alerts:** Tracks kills (`EVENT_COMBAT_EVENT`) and exploration proximity, triggering native `CENTER_SCREEN_ANNOUNCE` banners (including when accepting a shared quest by code) and official quest sounds (`SOUNDS.QUEST_COMPLETED`).
- **HUD Mini-Tracker:** Displays the active custom quest on the side of your screen (left-click opens the Journal; right-click centers the World Map on the search area).
- **Code Sharing & Completion Proof (`RPQ1` / `RPQC1`):**
  - Export any prepared quest as a compact, CRC16-verified share code (`RPQ1:...`) for other players to import.
  - Completed quests generate a delivery validation code (`RPQC1:...`) to prove completion back to the Quest Master.
- **Per-Character Persistence & Auto-Localization:** Stores progress per character via `ZO_SavedVars:NewCharacterIdSettings` and auto-detects client language (`en` / `es`).

---

## Installation

1. Download the latest release archive (or clone this repository).
2. Extract the `RPQuest` folder into your ESO AddOns directory:
   - **Windows:** `Documents\Elder Scrolls Online\live\AddOns\RPQuest\`
   - **macOS:** `~/Documents/Elder Scrolls Online/live/AddOns/RPQuest/`
   - **Linux (Steam/Proton):** `<SteamLibrary>/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns/RPQuest/`
3. Verify that `RPQuest.txt` is located directly inside `AddOns/RPQuest/RPQuest.txt`.
4. Launch ESO and enable **RPQuest** in the **Add-Ons** menu. No external libraries are required.

---

## Quick Start

1. **Create a Quest (Quest Master):**
   - Open the Quest Journal (`J`) and switch to the **RPQuest** tab (or type `/rpquest`).
   - Click **Create Quest**, use the collapsible form sections to set **Title**, **Description / Lore**, **Search Area** size (`Small`, `Medium`, `Large`), optional **Do not be detected**, and optional **NPC Dialogue** lines.
   - In the world, aim at NPCs and press your **Capture Target** keybind (or `/rpquest capture`), or stand at a location and press **Capture Discovery Point** (or `/rpquest discovery`).
2. **Share with Players:**
   - Select your prepared quest and copy its `RPQ1:...` share code.
   - Players paste that code into the **Import** field in their **RPQuest** tab.
3. **Play & Verify:**
   - Activate the received quest to show the HUD mini-tracker and World Map search area.
   - Once all objectives are completed, copy the generated `RPQC1:...` delivery code to confirm completion.

---

## Controls & Slash Commands

### Keybinds (`Settings -> Controls -> RPQuest`)
| Action | Description |
| :--- | :--- |
| **Capture Target under Reticle** | Captures the living NPC currently under your reticle into the quest draft. |
| **Capture Discovery Point** | Captures your current character position as a hidden discovery objective. |
| **Toggle Custom Quests Tab** | Opens or closes the Quest Journal directly on the **RPQuest** tab. |

### Slash Commands
| Command | Arguments | Description |
| :--- | :--- | :--- |
| `/rpquest` | *(none)* | Opens or closes the **RPQuest** tab in the Quest Journal. |
| `/rpquest` | `capture` / `target` | Captures the NPC currently aimed at under the reticle. |
| `/rpquest` | `discovery` / `point` | Captures your current position as a hidden discovery point. |
| `/rpquest` | `map` | Opens the World Map centered on the active quest's search area. |

---

## Requirements & Compatibility

- **Game Version:** The Elder Scrolls Online (`APIVersion: 101051`)
- **External Libraries:** None (`Zero-Dependency`)
- **SavedVariables:** `RPQuest_SavedVariables` (per character)
- **Supported Languages:** English (`en`), Spanish (`es`)

---

## Project Structure & Development

```text
RPQuest/
├── RPQuest.txt              # Official ESO add-on manifest
├── RPQuest.lua              # Entry point & EVENT_ADD_ON_LOADED lifecycle
├── Bindings.xml             # Native keybind definitions
├── lang/
│   ├── en.lua               # English strings (Base / Fallback)
│   └── es.lua               # Spanish strings
├── src/
│   ├── Constants.lua        # Constants, radii, and metadata
│   ├── Locale.lua           # Client language selector & i18n
│   ├── ShareCodec.lua       # RPQ1 / RPQC1 codec with CRC16 checksum
│   ├── QuestRepository.lua  # Per-character CRUD & search area offset logic
│   ├── Announcements.lua    # CENTER_SCREEN_ANNOUNCE & sound alerts
│   ├── TargetCapture.lua    # Reticle NPC & discovery point capture
│   ├── CombatTracker.lua    # Kill & stealth tracking (EVENT_COMBAT_EVENT)
│   ├── DiscoveryTracker.lua # Hidden discovery proximity polling
│   ├── DialogueInjector.lua # Native NPC dialogue injection
│   ├── WorldMapArea.lua     # Native search circle on ZO_WorldMap
│   └── JournalTab.lua       # Native Quest Journal tab & HUD mini-tracker
├── docs/adr/                # Architecture Decision Records (MADR)
└── tests/
    ├── run.lua              # Hermetic unit test suite (LuaJIT)
    └── mocks/               # EsoUI mocks
```

### Running Tests
```bash
luajit tests/run.lua
```

---

## License

This project is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for details.
