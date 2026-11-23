# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.8.1-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20ES-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

**English** | [Español](README.es.md)

A native, **zero-dependency** add-on for **The Elder Scrolls Online** (`APIVersion: 101051`) that lets you create, play, complete, and share **custom Roleplay quests** directly inside ESO's native UI.

---

## Key Features

- **Native Quest Journal Integration (`J`):** Adds a dedicated **RPQuests** tab inside the standard Quest Journal (`QUEST_JOURNAL_KEYBOARD`) with exclusive accordion sections for **Pending** offers, active **Quests**, **Completed** missions, **Preparing** (unsent drafts), and **Sent** (dispatched contracts with live status and completion results), plus native Journal shortcuts for **Show on Map** and **Abandon**.
- **Reticle NPC Target Capture:** Aim at any living NPC and press your **Capture Target Under Reticle (NPC)** keybind to register objectives automatically. Capturing the same NPC name multiple times stacks into `Imp x3`; different named NPCs are tracked individually, with per-target location conditions (`Required` within `8m` / `15m` / `30m` or `Not Required`—eliminating a `Required` target outside its radius marks the quest as `Failed`), an `Optional` objective toggle (enabling manual quest completion once mandatory objectives are done), and custom elimination messages.
- **Hidden Discovery Points:** Capture in-world exploration coordinates via your **Capture Hidden Discovery Point Here** keybind with configurable trigger radii (`8m`, `15m`, `30m`) without cluttering the map or compass with spoilers.
- **Optional Stealth / Undetected Condition & Completion Message:** Require players to complete objectives without being detected in combat (**Undetected (Optional)**) and optionally configure a **Completion Message (Optional)** shown when the quest finishes.
- **World Map Search Area (`M`):** Displays an approximate search circle on the World Map (`ZO_WorldMap_GetPinManager():AddCustomPin`) using a deterministic, fixed random offset—keeping the target inside the circle without revealing its exact center (or toggle **Hide area on map** to conceal it completely). Automatically clears upon completion or deactivation.
- **Native NPC Dialogue Injection:** Open dialogue (`E`) with up to 3 native ESO NPCs and click **+ Last NPC** in the editor to bind custom RPQuest dialogue lines and per-NPC player response options, injected seamlessly into the native interaction window without altering original NPC options.
- **Combat & Discovery Tracking + Native Alerts:** Tracks kills (`EVENT_COMBAT_EVENT`) and exploration proximity, triggering native `CENTER_SCREEN_ANNOUNCE` banners and official quest sounds (`SOUNDS.QUEST_COMPLETED`).
- **Local Quest Master Testing, Reset & Migration:** Test any **Preparing** or **Sent** quest locally with **Test Quest** / **Stop Testing**, restart a prepared or `Failed` quest with **Reset**, or update older quest schemas with **Migrate**.
- **1-to-1 In-Game Mail Flow (Zero Copy/Paste):**
  - Assign a single `@AccountName` recipient (and optional `To (Character)` name) in the quest editor and click **Send Quest** from the quest detail pane (opening the Mail Send pane with an **Optional Roleplay Message** and a live 1–6 part counter via `RPQP` over `ShareCodec`; works within the same megaserver, e.g. PC-NA to PC-NA, and ESO prevents sending mail to your own account). Both `From:` and `To:` character names are displayed below `Status:` in the quest details.
  - **Auto-Ingested Pending Quests:** Incoming quest mails are automatically ingested into the player's **Pending** list with a visible alert and **Accept** / **Reject** actions directly in the RPQuests Journal (mismatched-language quest mails are automatically rejected with an error alert).
  - **Automatic Acceptance, Completion & Rejection Reports:** Accepting, completing, or rejecting a received quest automatically sends an `RPQC1` result mail back to the Quest Master, updating the prepared quest's live status (`Draft` / `Sent` / `Accepted` / `Completed` / `Rejected`).
- **Account-Wide Persistence & Auto-Localization:** Stores quests and progress account-wide via `ZO_SavedVars:NewAccountWide` (matching ESO's account-wide mail, with automatic non-destructive migration from legacy per-character data) and auto-detects client language (`en` / `es`).

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
   - Open the Quest Journal (`J`) and switch to the **RPQuests** tab (or press your **Open / Close Custom Quests Tab** keybind).
   - Click **+ New**, use the collapsible form sections to set **Title**, **Description / Story:**, **Search Area** size (or **Hide area on map**), optional **Undetected (Optional)**, optional **Completion Message**, and optional **NPC Dialogues** lines.
   - In the world, aim at NPCs and press your **Capture Target Under Reticle (NPC)** keybind, or stand at a location and press **Capture Hidden Discovery Point Here**, then click **Create Quest** to save.
2. **Send to a Player (1-to-1 Mail):**
   - Set the target `@AccountName` (and optional `To (Character)` name) in the quest editor, save, and click **Send Quest** from the prepared quest details.
   - The player receives an alert and sees the quest under **Pending** in their **RPQuests** tab to **Accept** or **Reject**.
   - **Same-language requirement:** Quests must be played on a game client using the same language as the creator so NPC names and dialogue targets match; mismatched-language mails are rejected automatically.
3. **Play & Auto-Report:**
   - Accepting the quest activates the World Map search area (unless hidden) and any injected NPC dialogues immediately.
   - Accepting, completing, or rejecting the quest automatically mails the result back to the Quest Master, moving the contract into the **Sent** section with live status (`Sent`, `Accepted`, `Rejected`, `Completed`) and completion results (such as `Undetected` vs `Detected` and optional objective outcomes).

---

## How to Use / Guide

### 1. Roles: Quest Master vs. Player
- **Quest Master (Creator):** Authors custom quests in **Preparing**, captures NPC targets or discovery spots in the world, tests locally with **Test Quest**, configures optional rules or dialogues, and dispatches contracts via in-game mail. Once sent, the Quest Master tracks live status and final outcomes in **Sent**.
- **Player (Recipient):** Receives quest offers in **Pending**, reviews the briefing, and chooses **Accept** or **Reject**. Active quests are tracked automatically in-world, and results are mailed back to the Quest Master with zero manual copy/paste.

### 2. Journal Sections (Exclusive Accordion)
The **RPQuests** tab inside the Quest Journal (`J`) uses an exclusive accordion—expanding one section collapses the others:
- **Pending:** Incoming quest offers waiting for you to **Accept** or **Reject**.
- **Quests:** Your currently accepted and active quests (including `Failed` quests that can be restarted with **Reset**). Select a quest to view objectives, toggle tracking, jump to the map (**Show on Map**), **Abandon**, or manually complete it once all mandatory objectives are done.
- **Completed:** Archive of finished quests you have played, including final stealth and optional objective outcomes.
- **Preparing:** Unsent quest drafts you are creating or editing as a Quest Master. You can also copy any **Preparing** or **Sent** quest into **Preparing** to create a fresh editable draft, test it locally (**Test Quest**), or update older schemas (**Migrate**).
- **Sent:** Contracts you have already mailed to players, showing `From:` / `To:` names, live status (`Sent`, `Accepted`, `Rejected`, `Completed`), and automatic completion results (such as `Undetected` vs `Detected` and optional objectives).

### 3. Quest Building Blocks
- **Targets (NPC Elimination):** Aim at any living NPC and press your **Capture Target Under Reticle (NPC)** keybind. Capturing the same NPC name multiple times stacks into a count (e.g. `Imp x3`); different named NPCs become separate objectives. For each target, you can toggle a **Location** condition (`Required` within `8m` / `15m` / `30m` of the captured spot, or `Not Required`—killing a `Required` target outside its radius fails the quest), add a custom elimination message, or mark the objective as **Optional** (allowing the player to finish the quest once all mandatory objectives are complete).
- **Hidden Discovery Points:** Stand at an exploration spot and press your **Capture Hidden Discovery Point Here** keybind. You can configure the trigger radius (`8m`, `15m`, or `30m`). Discovery points remain hidden on the map and compass to avoid spoilers.
- **Stealth (`Undetected`) & Completion Message:** Enable **Undetected (Optional)** in the quest editor to challenge the player to complete the quest without being detected in combat. You can also set a **Completion Message (Optional)** displayed when the quest finishes.
- **World Map Search Area (`M`):** Displays an approximate search circle on the World Map using a fixed random offset so the objective stays inside the circle without giving away its exact center (or use **Show on Map** from the editor/detail pane, or check **Hide area on map** to disable it). The circle clears automatically when the quest is completed or deactivated.
- **NPC Dialogues:** Open dialogue (`E`) with up to 3 native ESO NPCs and click **+ Last NPC** to capture them into the quest's **NPC Dialogues** section, then write a custom player response option and NPC reply for each. When the player speaks to those NPCs, your custom line is injected seamlessly into the native dialogue window without modifying original game options.

### 4. In-Game Mail Flow (Automatic)
- **Sending:** Enter the recipient's `@AccountName` (and optional `To (Character)` name) in the quest editor, save, and click **Send Quest** in the quest detail pane. If no recipient is set or direct send needs confirmation, the Mail Send pane opens with an **Optional Roleplay Message** field and a live part counter (1–6 parts via `RPQP`). Both players must be on the same megaserver (e.g. PC-NA or PC-EU) and use the same client language, and ESO blocks sending mail to your own account.
- **Arrival Announcement:** When a quest mail arrives, RPQuest ingests it automatically and displays an on-screen announcement alerting the player that a new quest is waiting in **Pending** (or rejects and alerts if the quest language does not match the client).
- **Accepting & Rejecting:** Clicking **Accept** activates the quest, World Map search area (unless hidden), and NPC dialogues, and notifies the Quest Master. Clicking **Reject** declines the offer and notifies the Quest Master.
- **Completion Reporting:** When the player finishes all objectives (or manually completes a quest with only optional objectives remaining), RPQuest automatically mails the completion report (`RPQC1`) back to the Quest Master and updates the contract in **Sent**.

---

## Controls (`Settings -> Controls -> RPQuest - Custom Quests`)

| Action | Description |
| :--- | :--- |
| **Capture Target Under Reticle (NPC)** | Captures the living NPC currently under your reticle into the quest draft. |
| **Capture Hidden Discovery Point Here** | Captures your current character position as a hidden discovery objective. |
| **Open / Close Custom Quests Tab** | Opens or closes the Quest Journal directly on the **RPQuests** tab. |

---

## Requirements & Compatibility

- **Game Version:** The Elder Scrolls Online (`APIVersion: 101051`)
- **External Libraries:** None (`Zero-Dependency`)
- **SavedVariables:** `RPQuest_SavedVariables` (account-wide)
- **Supported Languages:** English (`en`), Spanish (`es`)

---

## Project Structure & Development

```text
RPQuest/
├── RPQuest.txt                  # Official ESO add-on manifest
├── RPQuest.lua                  # Entry point & EVENT_ADD_ON_LOADED lifecycle
├── Bindings.xml                 # Native keybind definitions
├── readme.txt                   # Plaintext package readme for ESOUI
├── LICENSE                      # GNU General Public License v3.0
├── lang/
│   ├── en.lua                   # English strings (Base / Fallback)
│   └── es.lua                   # Spanish strings
├── src/
│   ├── Constants.lua            # Constants, radii, and metadata
│   ├── Locale.lua               # Client language selector & i18n
│   ├── BinaryCodec.lua          # Base85, Base64Url, LZSS, and Varint binary primitives
│   ├── ShareCodec.lua           # RPQ3 & RPQC1 quest/result serialization
│   ├── MailInbox.lua            # Inbox scanning, RPQP multipart reassembly & ingestion
│   ├── MailTransport.lua        # In-game quest & completion mail transport
│   ├── QuestDraftStore.lua      # Draft authoring state & objective normalization
│   ├── QuestMigration.lua       # Non-destructive SavedVars & quest schema migration
│   ├── QuestRepository.lua      # Account-wide CRUD, quest storage & runtime tracking
│   ├── Announcements.lua        # CENTER_SCREEN_ANNOUNCE & sound alerts
│   ├── TargetCapture.lua        # Reticle NPC & discovery point capture
│   ├── CombatTracker.lua        # Kill & stealth tracking (EVENT_COMBAT_EVENT)
│   ├── DiscoveryTracker.lua     # Hidden discovery proximity polling
│   ├── DialogueInjector.lua     # Native NPC dialogue injection
│   ├── WorldMapArea.lua         # Native search circle on ZO_WorldMap
│   ├── JournalWidgets.lua       # Reusable UI widget & formatting helpers for JournalTab
│   ├── JournalDetailPane.lua    # Quest detail pane & action button builders/refresh
│   ├── JournalEditorSections.lua# Accordion section & field builders for quest editor
│   ├── JournalEditorPane.lua    # Multi-section quest editor pane layout/refresh
│   ├── JournalMailSendPane.lua  # In-game mail send pane & transport event UI
│   └── JournalTab.lua           # Native Quest Journal tab coordinator
├── scripts/
│   ├── bump-version.sh          # Synchronized SemVer version bumper
│   ├── check-esoui.sh           # ESOUI compliance & retired-term checker
│   └── package.sh               # Clean ZIP packager
├── docs/
│   ├── esoui-description.bbcode # ESOUI addon page BBCode description
│   ├── roadmap-references.md    # Feature & UX reference notes
│   └── adr/                     # Architecture Decision Records (MADR)
└── tests/
    ├── run.lua                  # Hermetic unit test suite runner (LuaJIT)
    ├── mocks/                   # EsoUI mocks
    └── suites/                  # Modular unit test suites
```

### Running Tests
```bash
luajit tests/run.lua
./scripts/check-esoui.sh
```

---

## AI Disclosure & Credits

- **Author:** [JerbilX](https://github.com/JerbilX)
- **AI Assistance Disclosure:** AI coding assistants were used during development to assist with Lua code drafting, refactoring, localization, documentation, and unit test scaffolding. All feature design, architecture decisions, in-game testing, and final code reviews were directed and verified by the author.

---
