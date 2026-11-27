# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.12.0-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20DE%20%7C%20ES%20%7C%20FR%20%7C%20JP%20%7C%20RU%20%7C%20ZH-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Q7W02BAKN7)

**English** | [Español](README.es.md)

A native, **zero-dependency** add-on for **The Elder Scrolls Online** (`APIVersion: 101051`) that lets you create, play, complete, and share **custom Roleplay quests** directly inside ESO's native UI.

---

## Key Features

- **Native Quest Journal Integration (`J`):** Adds a dedicated **RPQuests** tab inside the standard Quest Journal (`QUEST_JOURNAL_KEYBOARD`) with exclusive accordion sections for **Pending** offers, active **Quests**, **Completed** missions, **Preparing** (unsent drafts), and **Sent** (dispatched contracts with live status and completion results)—keeping an active section expanded whenever quests exist and remembering the last open section and selected quest across sessions—plus native Journal shortcuts for **Show on Map** and **Abandon**.
- **Reticle NPC & Player Duel Target Capture:** Aim at any living NPC (or another player for a duel objective) and press your **Capture Target Under Reticle (NPC)** keybind to register objectives automatically. Capturing the same NPC or player name multiple times stacks into `Imp x3` or `PlayerName (Duel) x2`; different targets are tracked individually in the editor's target dropdown (with per-target delete and clear-all buttons), per-target **Map Search Area Size** (`Tiny` / `Small` / `Medium` / `Large` / `Huge`), an **Optional target** checkbox (enabling manual quest completion once mandatory objectives are done), per-target **Location** conditions (**Required** within `Tiny` / `Small` / `Medium` / `Large` / `Huge` (`8m` / `23m` / `39m` / `54m` / `70m`) or optional—eliminating a **Required** target outside its radius fails the quest), and two optional **Elimination Message** fields (**On elimination** and **On elimination (location met)**).
- **Hidden Discovery Points:** Stand at an exploration spot and click the **+** icon button (**Add point**) in the editor's **Hidden Discovery Points (Optional)** accordion with a configurable trigger radius dropdown (`Tiny` / `Small` / `Medium` / `Large` / `Huge` — `8m`, `23m`, `39m`, `54m`, `70m`), a **Required** checkbox per point (`[Req]` in the dropdown), up/down arrow buttons to reorder points, a **Sequential order (unlock points one by one)** checkbox (gating both `DiscoveryTracker` proximity evaluation and player map pin visibility until the preceding point is discovered, while creators see all points), and a required **Discovery Point Message**. Creators automatically see purple discovery areas on the map (with discovery index and message summary tooltips), while players keep them hidden by default with an optional spoiler-free **Discovery** checkbox in **MAP MARKERS**.
- **Stealth / Undetected Condition (Disabled / Optional / Required) & Completion Message:** Choose via dropdown whether staying undetected (no Justice bounty, infamy, or failed pickpocket in the quest area) is **Disabled**, **Optional** (records detection without failing), or **Required** (immediately fails the quest if detected), and optionally configure a **Completion Message (Optional)** shown when the quest finishes.
- **Quest Icons:** Optionally assign an icon (**Black Hand**, **Search**, or **Steal**) in the quest editor to visually identify the quest theme in the journal list, quest details, and shared quests.
- **World Map Search, Location & Discovery Areas (`M`):** Supports per-target emerald-green search circles on the World Map (`ZO_WorldMap_GetPinManager():AddCustomPin`) with a brief initial pulse, deterministic fixed random offset, and automatic radius scaling on city/subzone maps, optional soft-orange captured target location circles (both layers clear per target as each objective is completed), and purple discovery point circles (automatically shown for creators in Edit/Preparing/Sent and hidden by default for players, clearing each point as it is discovered). In the editor's **Mission Settings** accordion, **Recommend no map markers to player** (enabled by default on new drafts) displays **Show map markers: not recommended** inside **MISSION DETAILS**; for players, the **MAP MARKERS** section shows applicable **Search Areas**, **Location**, and **Discovery** checkboxes (all off by default) that can be toggled independently per quest (while **Show on Map** remains available whenever a map/area is defined). When zoomed out to a parent zone or Tamriel world map, displays a medium pulsing emerald reference area with a deterministic offset (keeping the objective inside without revealing its exact spot), and automatically hides it when zooming back into the target map or upon completion/deactivation.
- **Native NPC Dialogue Injection & Objectives:** Open dialogue (`E`) with up to 4 native ESO NPCs and click **+ Last NPC** in the editor to bind custom RPQuest dialogue lines, per-NPC player response options, and an optional **Required** toggle per NPC (`[Req]`), injected seamlessly into the native interaction window without altering original NPC options. Dialogue execution is persisted across `/reloadui` in SavedVariables, displays spoiler-free progress in **TASKS**, and automatically completes dialogue-only quests (`0` targets, `0` discoveries, `>= 1` dialogues) once all dialogues are executed.
- **Combat, Duel & Discovery Tracking + Native Alerts:** Tracks NPC kills (`EVENT_COMBAT_EVENT`), player duel victories (`EVENT_DUEL_FINISHED`), and exploration proximity, triggering native `CENTER_SCREEN_ANNOUNCE` banners and official quest sounds (`SOUNDS.QUEST_COMPLETED`), plus a gold/amber **Compass Area Glow** around `ZO_Compass` when inside a pending active target's search area or exact location (regardless of map marker toggles, excluding hidden discovery points).
- **Local Quest Master Testing, Reset & Migration:** Test any **Preparing** or **Sent** quest locally with **Test Quest** / **Stop Testing**, restart a prepared, `Failed`, or tutorial quest with **Reset**, or update older quest schemas with **Migrate**.
- **Built-in Progressive Tutorial Pack (Daggerfall):** First-time players start with **Tutorial I** in **Pending** (peaceful NPC dialogue around Daggerfall Wayshrine), unlocking **Tutorial II** (sequential discovery trail + optional stealth) and **Tutorial III** (mandatory + optional combat contract) one by one upon completion. All three pills are strictly optional (never re-seeded if abandoned or deleted, and never send mail) and can be cloned into **Preparing** with **Copy** as editable templates or replayed via **Reset**.
- **1-to-1 In-Game Mail Flow (Zero Copy/Paste):**
  - Assign a single `@AccountName` recipient (and optional `To (Character)` / `From (Character)` account-character selector) in the quest editor and click **Send Quest** from the quest detail pane—sending directly when `@AccountName` is already set, or opening the Mail Send pane with an **Optional Roleplay Message** and a live 1–6 part counter via `RPQP` over `ShareCodec` when no recipient is set (works within the same megaserver, e.g. PC-NA to PC-NA, and ESO prevents sending mail to your own account). Both `From:` and `To:` character names are displayed below `Status:` in the quest details (preserving the selected sender character across mail delivery).
  - **Auto-Ingested Pending Quests:** Incoming quest mails are automatically ingested into the player's **Pending** list with a visible alert and **Accept** / **Reject** actions directly in the RPQuests Journal (mismatched-language quest mails are automatically rejected with an error alert).
  - **Automatic Acceptance, Completion, Failure & Rejection Reports:** Accepting, completing, failing, or rejecting a received quest automatically sends an `RPQC1` result mail back to the Quest Master, updating the `Sent` quest's resolution (`Accepted` / `Completed` / `Failed` / `Rejected`) while keeping its lifecycle (`Draft` / `Sent` / `Received`) separate.
- **Account-Wide Persistence & Auto-Localization:** Stores quests, progress, and last open Journal section / selected quest account-wide via `ZO_SavedVars:NewAccountWide` (matching ESO's account-wide mail, with automatic non-destructive migration from legacy per-character data) and auto-detects all 7 official ESO client languages (`en`, `de`, `es`, `fr`, `jp`, `ru`, `zh`).

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
   - Click **+ New** (which immediately creates a **New Quest** draft in **Preparing** and opens it in the editor), use the single-open animated accordion form sections (with `Tab` / `Shift+Tab` field navigation) to set **Title**, **Description / Story:**, **Quest Icon** (*None*, *Black Hand*, *Search*, or *Steal*), per-target **Map Search Area Size**, **Optional target**, **Location**, and optional **On elimination** / **On elimination (location met)** messages in **Target (NPC) & Search Area**, plus **Completion Message**, **Undetected Stealth Condition** (`Disabled`, `Optional`, or `Required`), and **Recommend no map markers to player** in **Mission Settings**, as well as optional **NPC Dialogues**.
   - In the world, aim at NPCs and press your **Capture Target Under Reticle (NPC)** keybind, or stand at a location and click the **+** icon button (**Add point**) in **Hidden Discovery Points (Optional)** (each discovery point requires a **Discovery Point Message**). In-progress edits are automatically preserved when switching quests or closing the journal, or click **Save Draft** to save and finish editing (free-form and dialogue-only quests without NPC targets or discovery points can also be tested and sent; use **Abandon** in the bottom keybind strip to delete a draft).
2. **Send to a Player (1-to-1 Mail):**
   - Set the target `@AccountName` (and optional `To (Character)` name) in the quest editor, save, and click **Send Quest** from the prepared quest details.
   - The player receives an alert and sees the quest under **Pending** in their **RPQuests** tab to **Accept** or **Reject**.
   - **Same-language requirement:** Quests must be played on a game client using the same language as the creator so NPC names and dialogue targets match; mismatched-language mails are rejected automatically.
3. **Play & Auto-Report:**
   - Accepting the quest activates tracking and any injected NPC dialogues immediately; map markers are off by default and can be toggled independently per quest in the **MAP MARKERS** section (**Search Areas** / **Location** / **Discovery**).
   - Accepting, completing, failing, or rejecting the quest automatically mails the result back to the Quest Master, keeping the contract in **Sent** with its live resolution (`Sent`, `Accepted`, `Rejected`, `Completed`, `Failed`) and completion/failure results (such as `Undetected` vs `Detected` and optional objective outcomes).

---

## How to Use / Guide

### 1. Roles: Quest Master vs. Player
- **Quest Master (Creator):** Authors custom quests in **Preparing**, captures NPC targets or discovery spots in the world, tests locally with **Test Quest**, configures optional rules or dialogues, and dispatches contracts via in-game mail. Once sent, the Quest Master tracks live status and final outcomes in **Sent**.
- **Player (Recipient):** Receives quest offers in **Pending**, reviews the briefing, and chooses **Accept** or **Reject**. Active quests are tracked automatically in-world, and results are mailed back to the Quest Master with zero manual copy/paste.

### 2. Journal Sections (Exclusive Accordion)
The **RPQuests** tab inside the Quest Journal (`J`) uses an exclusive accordion—expanding one section collapses the others (one active section stays expanded whenever quests exist, and your last open section and selected quest are restored across sessions):
- **Pending:** Incoming quest offers waiting for you to **Accept** or **Reject**.
- **Quests:** Your currently accepted and active quests (including `Failed` quests that can be restarted with **Reset**). Select a quest to view **MISSION DETAILS** and **TASKS**, toggle applicable **MAP MARKERS** (**Search Areas** / **Location** / **Discovery**), toggle tracking, jump to the map (**Show on Map**), **Abandon**, or manually complete it via **Complete** (for pure *free-form* quests with no targets/discoveries/dialogues, or once all mandatory targets are done; missing any **Required** discovery or dialogue at resolution fails the quest).
- **Completed:** Archive of finished quests you have played, including final stealth and optional objective outcomes.
- **Preparing:** Unsent quest drafts you are creating or editing as a Quest Master. You can also copy any **Preparing** or **Sent** quest into **Preparing** to create a fresh editable draft, test it locally (**Test Quest**), or update older schemas (**Migrate**).
- **Sent:** Contracts you have already mailed to players, showing `From:` / `To:` names, lifecycle and live resolution (`Sent`, `Accepted`, `Rejected`, `Completed`, `Failed`), and automatic completion/failure results (such as `Undetected` vs `Detected` and optional objectives).

### 3. Quest Building Blocks
- **Targets (NPC Elimination & Player Duels):** Aim at any living NPC or another player and press your **Capture Target Under Reticle (NPC)** keybind. Player targets are registered as duel objectives (`EVENT_DUEL_FINISHED`, counting local victories and opponent forfeits while ignoring defeats). Capturing the same target name multiple times stacks into a count (e.g. `Imp x3`); different targets become separate objectives managed from the target dropdown (with delete selected and delete all buttons). For each target, you can set **Map Search Area Size** (`Tiny` / `Small` / `Medium` / `Large` / `Huge`), toggle **Optional target** (allowing the player to finish the quest once all mandatory objectives are complete), configure **Location** (**Capture Loc**, `Tiny` / `Small` / `Medium` / `Large` / `Huge` (`8m` / `23m` / `39m` / `54m` / `70m`) radius, and the **Required** checkbox—unchecked means optional/anywhere, checked fails the quest if eliminated outside the radius), and enter optional **On elimination** and **On elimination (location met)** messages.
- **Hidden Discovery Points:** Stand at an exploration spot and click the **+** icon button (**Add point**) in the **Hidden Discovery Points (Optional)** accordion. You can configure the trigger radius (`Tiny` / `Small` / `Medium` / `Large` / `Huge` — `8m`, `23m`, `39m`, `54m`, or `70m`), mark points as **Required** (`[Req]`), reorder them with the up/down arrow buttons, toggle **Sequential order (unlock points one by one)** so locked points stay hidden and inactive until the previous point is discovered, and must write a **Discovery Point Message** before saving, testing, or sending. Discovery points remain hidden on the map and compass by default for players to avoid spoilers (creators see purple discovery areas automatically, and players can toggle **Discovery** in **MAP MARKERS**).
- **Stealth (`Undetected`) & Completion Message:** Use the **Undetected Stealth Condition** dropdown in the quest editor (`Disabled`, `Optional`, or `Required`) to track stealth as a bonus condition or fail the quest immediately upon detection. You can also set a **Completion Message (Optional)** displayed when the quest finishes.
- **World Map Search, Location & Discovery Areas (`M`):** Displays per-target approximate search circles using a fixed random offset (with automatic radius scaling on city/subzone maps) and optional soft-orange captured target location circles; circles clear per target as each objective is completed (as well as when the quest is completed or deactivated). All three map layers (Search Areas, Location, and Discovery) are off by default for players and can be toggled independently per quest in **MAP MARKERS** (while any **Show map markers: not recommended** note from **Recommend no map markers to player** appears in **MISSION DETAILS**); **Show on Map** (**M**) remains available whenever a map/area is defined.
- **NPC Dialogues:** Open dialogue (`E`) with up to 4 native ESO NPCs and click **+ Last NPC** to capture them into the quest's **NPC Dialogues** section, optionally mark each as **Required** (`[Req]`), and write a custom player response option and NPC reply for each. When the player speaks to those NPCs, your custom line is injected seamlessly into the native dialogue window without modifying original game options; execution state persists across reloads, live progress appears in **TASKS**, and dialogue-only quests auto-complete when all dialogues are executed.

### 4. In-Game Mail Flow (Automatic)
- **Sending:** Enter the recipient's `@AccountName` (and optional `To (Character)` name) in the quest editor, save, and click **Send Quest** in the quest detail pane. When `@AccountName` is already set in the editor, clicking **Send Quest** sends directly; if no recipient is set, the Mail Send pane opens with an **Optional Roleplay Message** field and a live part counter (1–6 parts via `RPQP`). Both players must be on the same megaserver (e.g. PC-NA or PC-EU) and use the same client language, and ESO blocks sending mail to your own account.
- **Arrival Announcement & Auto-Open:** When a quest mail arrives, RPQuest ingests it automatically and displays an on-screen announcement alerting the player that a new quest is waiting in **Pending** (or rejects and alerts if the quest language does not match the client). By default, **Auto-open RPQuests journal when receiving a new quest** is enabled to automatically open the **RPQuests** tab and select the newly received quest (skipped if you are in combat), and can be toggled off at the bottom of the quest list panel.
- **Accepting & Rejecting:** Clicking **Accept** activates the quest and NPC dialogues (map markers remain off by default until toggled in the quest details), and notifies the Quest Master. Clicking **Reject** declines the offer and notifies the Quest Master.
- **Completion & Failure Reporting:** When the player finishes all objectives (or manually completes a *free-form* quest or one with only optional targets remaining), or fails a required condition (such as stealth, target location, or a **Required** discovery/dialogue missed at resolution), RPQuest automatically mails the `RPQC1` report back to the Quest Master and updates the contract's resolution in **Sent**.

---

## Controls (`Settings -> Controls -> RPQuest - Custom Quests`)

| Action | Description |
| :--- | :--- |
| **Capture Target Under Reticle (NPC)** | Captures the living NPC currently under your reticle into the quest draft. |
| **Open / Close Custom Quests Tab** | Opens or closes the Quest Journal directly on the **RPQuests** tab. |

---

## Requirements & Compatibility

- **Game Version:** The Elder Scrolls Online (`APIVersion: 101051`)
- **External Libraries:** None (`Zero-Dependency`)
- **SavedVariables:** `RPQuest_SavedVariables` (account-wide)
- **Supported Languages:** English (`en`), German (`de`), Spanish (`es`), French (`fr`), Japanese (`jp`), Russian (`ru`), Simplified Chinese (`zh`)

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
│   ├── de.lua                   # German strings
│   ├── es.lua                   # Spanish strings
│   ├── fr.lua                   # French strings
│   ├── jp.lua                   # Japanese strings
│   ├── ru.lua                   # Russian strings
│   └── zh.lua                   # Simplified Chinese strings
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
│   ├── TutorialQuest.lua        # Built-in 3-pill progressive Daggerfall tutorial pack
│   ├── Announcements.lua        # CENTER_SCREEN_ANNOUNCE & sound alerts
│   ├── TargetCapture.lua        # Reticle NPC & discovery point capture
│   ├── CombatTracker.lua        # Kill & stealth tracking (EVENT_COMBAT_EVENT)
│   ├── DiscoveryTracker.lua     # Hidden discovery proximity polling
│   ├── DialogueInjector.lua     # Native NPC dialogue injection
│   ├── WorldMapArea.lua         # Emerald search & zoom-out areas, soft-orange location & purple discovery circles on ZO_WorldMap
│   ├── CompassAreaGlow.lua      # Gold/amber compass border glow inside active target areas
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
- **Support:** [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Q7W02BAKN7)

---
