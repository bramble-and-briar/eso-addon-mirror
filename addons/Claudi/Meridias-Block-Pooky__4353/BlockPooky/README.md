# BlockPooky - ESO Addon


[![ESO API Version](https://img.shields.io/badge/ESO%20API-101050-blue)](https://www.esoui.com/)
[![Version](https://img.shields.io/badge/Version-2.23-green)](https://github.com/your-repo/BlockPooky)

> **Warns the Pooky if blocking is necessary** - A comprehensive PvP awareness addon for Elder Scrolls Online

## Overview

BlockPooky is an Elder Scrolls Online addon that provides critical combat awareness for PvP scenarios. Originally inspired by rumors about ballgroup "BLOCK" warning addons, it has evolved into a comprehensive tool that helps players react to incoming threats and optimize their defensive gameplay.

## Features

### 🛡️ Block Warnings
- **Visual Alerts**: Large, customizable UI frame with "BLOCK Pooky!" message
- **Audio Notifications**: Configurable sound alerts (Duel Start sound)
- **Center Screen Announcements (CSA)**: BA-style messages for critical awareness
- **Chat Integration**: Optional chat warnings with addon tags
- **Group Messaging**: Cross-addon pull warnings via LibGroupBroadcast

### 🎯 Smart Detection
- **Ability Recognition**: Detects incoming pull abilities (Dark Convergence, Rush of Agony, chains, etc.) and gap closers (Critical Rush, Stampede, ...)
- **Two Detection Paths**: Pull effects trigger when the effect lands on you; damage abilities trigger when they hit you (ESO exposes no enemy "cast started" event, so charges are detected on impact)
- **Group Awareness**: Ignores abilities from group members and companions
- **Custom Triggers**: Add your own ability IDs for personalized detection — matched by ID, so morph/rank and language differences cannot break them
- **Language Support**: Works across different ESO client languages

### 📊 Combat Awareness
- **Block Detection**: Shows when you're actively blocking (solves "Am I Blocking?" uncertainty)
- **CC Immunity Tracking**: Visual bar showing immunity duration — now split into **Hard CC** (stun/knockdown/fear/disorient) and **Soft CC** (snares/immobilizes) with separate colors, blended while both are active
- **Active CC Bar**: Shows the highest-priority crowd control currently affecting you (Stun → Fear → Disorient → Silence → Stagger) with per-type text and colors
- **Negate Warnings**: Alerts when standing in enemy Negate Magic fields
- **Ready Hints**: Notifications when DC/ROA abilities are off cooldown
- **Threat Alerts**: Full-screen overlay warnings for dangerous threat abilities with customizable textures, opacity, and timing — assign custom center-screen text per ability ID (falls back to the ability name)
- **Stamina Low Warning**: ⚠️ **Critical** - Alerts when stamina drops below breakfree threshold (prevents getting CC-locked)
- **HoT Counter**: Real-time tracker for Healing-over-Time effects on the player (Update 49 8-cap compliance)

### ⚡ Performance Tools
- **Vigor Timing**: Optimal recasting reminders (8s intervals for group play)
- **Custom Cooldown Bars**: Track any ability or effect with personalized bars
- **Mount Notifications**: Reminds you when it's safe to mount in Cyrodiil, plus optional group-wide messages ("All Pookies Mounted!", "All Pookies can Mount!", "Pooky unmounted!") while grouped
  - **Mount Traffic Light**: Optional single colored light while grouped — green = all mounted, yellow = all can mount, red = at least one Pooky unmounted (movable)


### 🎨 Customization & Combat Visuals
- **Movable UI**: Drag and position all elements anywhere on screen
- **Color Themes**: Customize colors for all UI components
- **Font Sizing**: Adjustable font sizes for visibility
- **Duration Controls**: Configure how long messages stay visible
- **Customizable Messages**: Personalize all in-game messages and UI labels
- **Combat Visuals UI**: Adjust maximum AOE brightness, outline thickness, and target outline intensity from the settings menu
- **RGB AOE Cycling**: Enable color cycling for AOE indicators (with speed and turbo controls)

## Installation

1. Download and install the required dependencies:
   - [LibChatMessage](https://www.esoui.com/downloads/info2382-LibChatMessage.html) (>= 118)
   - [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) (>= 41)
   - [LibGroupBroadcast](https://www.esoui.com/downloads/info1337-LibGroupBroadcast.html) (>= 91)
   - [LibCombat](https://www.esoui.com/downloads/info2528-LibCombat.html) (>= 84)

2. Extract BlockPooky to your ESO AddOns folder:
   ```
   Documents\Elder Scrolls Online\live\AddOns\BlockPooky\
   ```

3. Launch ESO and enable the addon in the Add-ons menu

## Quick Start

1. **Open Settings**: Type `/blockpooky` in chat or access via ESO Settings > Add-ons
2. **Configure Triggers**: Select which abilities should trigger block warnings
3. **Customize UI**: Set colors, positions, and notification preferences
4. **Test Setup**: Use `/blockpookytest` to verify everything works

## Configuration

### Basic Settings
- **Show CSA**: Enable Center Screen Announcements
- **Play Sound**: Audio alerts for block warnings
- **Show UI Frame**: Large visual warning message
- **Chat Warnings**: Text notifications in chat
- **Group Messaging**: Send "They pulled me!" messages to group
  - Uses LibGroupBroadcast's protocol system ("BlockPookyWarnings") for cross-addon group communication
  - Optional filter to only send warnings for Rush of Agony / Dark Convergence pulls


### Advanced Features
- **Custom Triggers**: Add ability IDs for personalized detection (applied immediately, no reload)
- **Customizable Messages**: Edit messages(block warnings, hints, labels)
- **Cooldown Bars**: Create bars for any ability or effect
- **Combat Visuals**: UI controls for AOE brightness, outline thickness, target outline intensity, and RGB AOE cycling
- **Debug Tools**: Investigate ability/effect/damage IDs in real-time
- **UI Positioning**: Lock/unlock mode for moving interface elements

## Usage Tips

### How Triggers Are Detected
- **Pull effects** (Dark Convergence, Rush of Agony, chains, ...) are detected as `ACTION_RESULT_EFFECT_GAINED` when the effect lands on you.
- **Damage abilities** (Critical Rush, Critical Charge, Stampede, ...) never raise an effect-gained event. They are detected when their hit lands on you, so the warning arrives on impact rather than before it. Hits you fully block are ignored on purpose.

### Finding Ability IDs
1. Enable the matching investigation toggle in Debug Tools: "Investigate Abilities" for effects, "Investigate Incoming Damage" for hits that land on you
2. Trigger the ability/effect in-game
3. Check chat for the ID (format: `Effect? Name: <name> | ID: <id>` or `Damage? Name: <name> | ID: <id> | Source: <name>`)
4. Disable investigation to prevent chat spam

### Optimal Vigor Usage
- Enable Vigor hints for group play optimization
- "Vigor!" appears after 8 seconds
- Starts blinking at 16 seconds if not recast
- Essential for maintaining group healing efficiency

### Group Coordination
- Uses LibGroupBroadcast for cross-addon group pull warnings (protocol: "BlockPookyWarnings")
- Incoming group warnings show the ability name and source
- Filters pulls to send only ROA/DC warnings (configurable)

### Testing Group Messaging
The group pull warning is broadcast over LibGroupBroadcast, so it can only be verified with **two clients**.

1. **Group up and stay in the same instance** — both clients must be in the same group *and* the same instance (same Cyrodiil campaign, same overland zone, or same dungeon). LibGroupBroadcast only delivers to group members in your current instance.
2. **Enable group messaging on both clients** — "Send Pull Warning to Group" must be on for the sender and the receiver.
3. **Send a test** — on client A type `/blockpookytest`. This shows the local `TEST` warning *and* broadcasts it to the group. Client B should fire the block warning (`WARNING: Incoming TEST! from me`).
4. **Wait ~5 seconds between sends** — the receiving side applies the warning cooldown, so rapid repeat tests are suppressed.
5. **Real-world behavior** — outside of testing, a pull landing on a **group member (not you)** is what actually broadcasts the warning to the group.

Troubleshooting:
- **Not grouped** → sender gets `Group sync: could not send a warning to your group.` (sending requires being in a group).
- **Grouped but in different instances** → nothing arrives, and **no error is shown** (the send succeeds locally).
- **Protocol disabled** → `Group sync: disabled in LibGroupBroadcast settings.` — enable `BlockPookyWarnings` in LibGroupBroadcast's settings.
- **Setup failure** → `could not start group sync`, `setup failed (protocol ID/name conflict possible)`, or `setup is incomplete` mean the protocol did not finalize.

## Development

### Project Structure
```
BlockPooky/
├── BlockPooky.lua                # Main initialization and event handling
├── BlockPooky_blocking.lua       # Block detection system
├── BlockPooky_ccbar.lua          # CC immunity tracking
├── BlockPooky_cooldowns.lua      # Custom cooldown bars
├── BlockPooky_hints.lua          # Timing hints and notifications
├── BlockPooky_negate.lua         # Negate field detection
├── BlockPooky_threatalert.lua    # Threat alert overlay system
├── BlockPooky_combatvisuals.lua  # Combat visuals and AOE cycling
├── BlockPooky_hottracker.lua     # HoT counter (Update 49 8-cap tracking)
├── BlockPooky_staminalow.lua     # Stamina low / breakfree warning
├── BlockPooky_menue.lua          # Settings UI integration
├── BlockPooky.xml                # UI control definitions
├── BlockPooky.txt                # Addon manifest
├── README.md                     # Documentation
└── textures/                     # Overlay texture files
    ├── gold.dds
    ├── Indigo.dds
    ├── lemon.dds
    ├── red.dds
    ├── explosion.dds
    ├── reddot.dds
    └── staminawarn.dds
```

### Dependencies Location
All libraries should be installed as separate addons:
```
AddOns/
├── BlockPooky/
├── LibChatMessage/
├── LibAddonMenu-2.0/
├── LibGroupBroadcast/
└── LibCombat/
```

### Key Patterns
- Module pattern: `BlockPooky = BlockPooky or {}`
- Event registration with proper filtering
- UI controls with position persistence
- Account-wide and character-specific settings

## Commands

- `/blockpooky` - Open addon settings menu
- `/blockpookytest` - Trigger test warning

## Compatibility

- **ESO API Version**: 101049
- **Group Messaging**: Cross-addon pull warnings via LibGroupBroadcast
- **Languages**: All ESO client languages supported
- **Platforms**: PC/Mac

## Support

For issues, feature requests, or questions:
- Check the [wiki documentation](https://wiki.claudiapps.de/wiki:blockpooky)
- Review the `.github/copilot-instructions.md` for development guidance

## License

This addon is released under standard ESO addon terms. See individual library licenses for dependencies.

## Changelog

### Version 2.23 - Damage-based triggers (gap closers)
- **Gap closers now trigger block warnings**: Critical Rush, Critical Charge, Stampede and other charge abilities were listed but could never fire, because the warning only listened for `ACTION_RESULT_EFFECT_GAINED` and charges only ever deal damage
- **New damage path**: a dedicated `EVENT_COMBAT_EVENT` handler filtered (C level) to damage/critical damage with the player as target; group members, companions and your own hits are still ignored
- **ID matching**: trigger abilities are matched by ability ID as well as by name, so morph/rank differences and localized effect names cannot prevent a match
- **Live trigger list**: toggling abilities, adding custom IDs or clearing the list now applies immediately instead of requiring `/reloadui`
- **New "Incoming Damage Investigation"** debug toggle: logs `Name | ID | Source` for every hit that lands on you, so charge IDs can actually be found
- **Limitation**: ESO has no "enemy cast started" event for other players, so charge warnings are delivered when the hit lands, not before it. Fully blocked hits do not trigger the warning

### Version 2.22 - Threat Alert custom ability labels
- **Threat Alert custom text**: assign custom text to individual ability IDs; it is shown in the center of the overlay when that ability is detected (falls back to the ability's localized name when empty)
- **Ability Text Labels submenu**: "Show Text on Overlay" toggle, ability dropdown, and per-ability custom text
- **Bugfix**: opening the settings menu no longer throws a LibAddonMenu error (`operator # is not supported for function`)
- **Bugfix**: the "Current Threat Abilities" list in the settings menu now shows the configured abilities

### Version 2.21
- **refactor**: remove CC alert cooldown to simplify message handling; update related comments
- **refactor**: enhance event registration patterns for hints and blocking; improve state management
- **refactor**: implement authoritative detection for CC debuffs; enhance event handling and improve reliability

### Version 2.20 - Code Cleanup & Developer Tooling
- **ESO Globals validation**: Added developer test scripts (`testing/Run-ESOGlobals.ps1` / `.bat`) that run votan's ESOGlobals syntax & global-leak validator over the addon source (auto-detects the Lua 5.1 compiler); also fixed the validator's compiler-path handling bug
- **Removed accidental global variables** (namespace leaks) flagged by the validator — no behavior change:
  - Hints: `left` / `top` in the position restore are now locals
  - Cooldown bars: `inner` update closure, `OnCooldownAbilityEvent` / `OnCooldownEffectEvent` factory closures, and `beginTime` / `endTime` are now locals
  - Removed a dead `vigorHint_active` write in the combat handler that could never reach the hints module's own flag
- **Fixed UTF-8 BOM** in `BlockPooky_hottracker.lua` (harmless to ESO, but breaks external Lua compilers/tools like luac)
- **Removed `pcall` wrappers**: `InitGroupMessaging` declares the group protocol directly and `UnRegisterThreatAlert` unregisters directly (no silent error swallowing)
- **Slimmed group message payload**: The LibGroupBroadcast protocol no longer transmits `abilityName` / `sourceName` / `targetName` strings — it now sends only a 1-bit warning type + a 21-bit ability ID (~3 bytes instead of ~198 bytes); receivers derive the ability name from the ID and the source from the sender's unit tag
- **Hoisted per-event closures**: `OnCombat`, `OnNegateChanged` and `OnThreatAlert` no longer allocate a closure on every event — their lookup helpers are now file-local functions (less GC pressure in combat)

### Version 2.19 - Active CC Bar CSA Notifications
- **Center screen alerts when hard CCs land**: You now notice being CC'd even if you miss the bar
  - **Stun** → "STUNNED!", **Fear** → "FEARED!", **Disorient** → "DISORIENTED!" (big CSA text)
  - Only **hard CCs** (stun/fear/disorient) trigger it — staggers and silence don't
- **Independent toggle**: "Show Active CC Bar CSA" enables/disables the alerts separately from the bar
- **Anti-spam cooldown**: Default 2s between messages, adjustable via the "Active CC Bar CSA Cooldown (ms)" slider, so chain-CCs don't spam your screen
- **Customizable texts**: The three CSA messages can be edited in the "Customize Messages" submenu
- **Mount Traffic Light**: Optional single colored light shown while grouped (green = all mounted, yellow = all can mount, red = at least one Pooky unmounted); reuses the existing group mount poll (no extra timer), movable with position persistence, toggle in the "Group Mount Notifications" submenu

### Version 2.18 - HoT Counter Core Rewrite & Group Mount Notifications & CC Immunity Bar Split & Active CC Bar
- **HoT Counter Core Rewrite**:
  - Replaced the manual ability-ID database with game-state counting via `GetUnitBuffInfo`
  - Covers every HoT source automatically (skills, sets, items, scribing effects, procs) — no ability IDs to maintain, nothing goes stale
  - Accurate durations using the game's real begin/end times (refreshes, CP/buff/set modifiers, and expiry handled automatically)
  - Much smaller code: removed ~2000 lines of generated database and the fragile combat/effect event tracking
  - UI unchanged: colored counter bar (green/yellow/red), status bar, movable with position persistence, menu toggle
- **Group Mount Notifications**:
  - Group-wide mount messages (inspired by the AreWeMounted addon):
    - "All Pookies Mounted!" — when every online same-zone group member is mounted
    - "All Pookies can Mount!" — when every online same-zone group member is off mount and out of combat
    - "Pooky unmounted!" — when a group member (not you) dismounts
  - Messages only fire while grouped; the lightweight 500ms poll only runs while grouped (and also powers the personal "Pooky you can MOUNT!" reminder), so it costs nothing when solo
  - Editable texts in a new "Group Mount Notifications" submenu — leave a message empty to disable it
  - Same CSA notification style as the existing Mount Ready message — no extra UI element
- **CC Immunity Bar — Hard vs Soft Split**:
  - The bar now distinguishes HARD CC immunity (stun/knockdown/fear/disorient) from SOFT CC immunity (snares/immobilizes) with separate colors
  - Hard: immunity potions, Heavy Armor "Immovable" buff, Berserker Rage (default green)
  - Soft: Race Against Time, Bird of Prey, Elusive Mist, Swift of the Falcon, Phantasmal Escape, Protective Plate (default blue)
  - Dodge roll grants a short full-immunity window (both kinds)
  - Blended color while both kinds are active at the same time
  - New color pickers: "CC Immunity Bar Color (Hard CC)" and "CC Immunity Bar Color (Soft CC)"
  - Bugfixes: bar drains correctly again, no early-hide during chain dodge-rolls, fixed duplicate event registration, activated `/blockpookytestimmo` test command
- **Active CC Bar**:
  - New bar (separate from the CC immunity bar) showing the highest-priority crowd control currently affecting you
  - Priority order: Stun → Fear → Disorient → Silence → Stagger; switches to the next as each expires
  - Per-type text (STUNNED/FEARED/DISORIENTED/SILENCED/STAGGER) and colors (red/purple/blue/cyan/yellow)
  - Silence detected via standing in enemy Negate Magic fields
  - Stun clears instantly on break free so the bar switches to the next CC immediately
  - Independently toggleable in the menu with its own color pickers and position sliders
  - Test command: `/blockpookytestcc`

### Version 2.17 - UI Positioning Improvements
- **Fixed repositioning mode**: CC immunity bar and custom cooldown bars no longer hide themselves while arranging the UI (undefined `locked` variable)
- **HoT counter & Negate warning**: Now stay visible in repositioning mode and hide again correctly on re-lock
- **Consistent show/hide**: All UI elements (including bars) now toggle reliably when entering/leaving repositioning mode, including at addon load
- **Position sliders**: New "Element Positions" submenu (plus cooldown bar sliders) to set positions precisely as an alternative to dragging - useful when an element has moved off-screen (e.g. after a resolution change)

### Version 2.16 - Group Messaging Rewrite (LibGroupBroadcast)
- **Replaced LibMapPing with LibGroupBroadcast**: Group pull warnings now use LibGroupBroadcast's protocol system ("BlockPookyWarnings", ID 251) instead of the ZOS-flagged MapPing backdoor API
- **Protocol-Based Warnings**: Centralized warning sending/handling - outgoing warnings carry the warning type, ability ID/name, and source/target names
- **Incoming Warning Display**: Group pull warnings from other players trigger the block warning with ability name and source, respecting the spam cooldown
- **Graceful Fallbacks**: Clear chat notifications when LibGroupBroadcast is missing, disabled, or fails to send (local warnings keep working)
- **ROA/DC Filter**: Option to only send group warnings for Rush of Agony / Dark Convergence pulls

### Version 2.15 - HoT Bar Enhancements
- **Fixed HoT Bar Position Persistence**: Position now correctly saves and restores when moved
  - Bar previously reset to default position on each load due to LoadHoTBarPosition() ignoring saved coordinates
  - Now uses TOPLEFT anchor with saved left/top coordinates
- **Over-Cap HoT Display**: Bar now shows counts above the 8-cap limit with dynamic max scaling
  - Displays "10/8" format when overcapped to show actual HoT count
  - Status bar max value dynamically adjusts to accommodate values above 8
  - Red color persists for all values >= 8 (at cap or overcapped)
  - Useful for investigating HoT stacking mechanics during Update 49 testing

### Version 2.14
- **HoT Counter - Update 49 Compliance Tool**:
  - **Real-time HoT Tracking**: Monitors all active Healing-over-Time effects on player toward the 8-cap limit
  - **Game-State Counting (since 2.18)**: Counts HoTs directly from the player's buff list via `GetUnitBuffInfo` — every source (skills, sets, items, scribing effects, procs) is covered automatically, with real remaining durations
  - **Visual Counter Bar**: Shows current count (e.g., "5/8") with color indicators:
    - Green (0-5): Safe zone
    - Yellow (6-7): Warning - approaching cap
    - Red (8+): At cap or overcapped
  - **Auto-Hide on Expiration**: Bar automatically disappears when all HoTs expire
  - **Movable UI**: Drag to reposition anywhere on screen with persistence
  - **Configurable**: Enable/disable from settings menu (default: OFF)
  - **Testing**: `/run BlockPooky.PrintActiveHoTs()` lists active HoT buffs with remaining time

### Version 2.13 - bugfix
- Fix variable name inconsistency

### Version 2.12 - Stamina Low Warning System
- **Full-Screen Stamina Warning**: Critical visual overlay alerts when stamina drops below configured threshold
- **⚠️ Break Free Awareness**: Alerts when stamina is too low to break free from CC (stuns, knockdowns, etc.)
  - **Default threshold: 5000** - Below this, you cannot break free and will be locked down
  - Helps prevent getting locked in place during combat (lethal in PvP)
- **Configurable Threshold**: Set any stamina value as trigger point based on your needs
- **Fade Opacity Control**: Separate min/max opacity sliders for smooth fade effect
  - Minimum opacity at threshold (default: 30%)
  - Maximum opacity at 0 stamina (default: 72%)
  - Creates gradual visual intensity as stamina depletes
- **Texture Support**: Uses staminawarn.dds texture with blue border design
- **Dynamic Initialization**: Auto-detects and fixes overlay dimensions after `/reloadui` for reliability
- **Menu Integration**: Full settings submenu with enable/disable toggle and customizable sliders
- **Survival Tool**: Helps maintain stamina buffer to stay free from crowd control in PvP

### Version 2.11 - Critical OOP Syntax Fixes
- **Fixed Complete OOP Syntax Misuse**: Corrected critical bug where colon syntax (`:`) was incorrectly used for non-OOP functions
  - All function calls now consistently use dot syntax (`.`) matching their definitions
  - Fixed 35+ function calls across all modules (BlockPooky.lua, BlockPooky_menue.lua, BlockPooky_ccbar.lua, BlockPooky_combatvisuals.lua)
  - Affected functions: `SetUiLock`, `InitGroupMessaging`, `StopGroupMessaging`, `LoadGroupMembers`, `SetUseBlocking`, `RegisterNegateWarning`, `UnRegisterNegateWarning`, `CCEventRegisterUpdate`, `RegisterThreatAlert`, `UnRegisterThreatAlert`, `UpdateThreatAlertAlpha`, `AddThreatAbility`, `RebuildThreatAbilityList`, `ResetPosition`, `setBlockPookyFont`, `SetColor`, `SetBlockingColor`, `SetVigorHintColor`, `SetCCBarColor`, `SetNegateWarningColor`, `SetMaxAOEBrightness`, `SetMaxOutlineThickness`, `SetMaxTargetOutlineIntensity`, `ResetMaxAOEBrightness`, `ResetMaxOutlineThickness`, `ResetMaxTargetOutlineIntensity`, `SetAOERGBState`, `UpdateUILabels`, `DecodeMessage`, `WarnThePooky`, `SendWarning`, `ToggleAOERGB`, `showCCbar`
  - This bug was causing saved variables corruption where entire objects were being stored instead of boolean values
  - Resolves Lock UI toggle failures and prevents future configuration data corruption
- **Fixed All Menu Description Controls**: Verified all LibAddonMenu-2.0 description controls now have proper titles
  - Eliminates "[LAM2] Could not create description 'unnamed'" errors
  - Prevents menu initialization failures

### Version 2.10 - Code Refactoring & Documentation Update
- **Fixed OOP Notation Inconsistency**: Refactored entire codebase to eliminate misleading `:` (colon) and `self` notation
  - All function definitions converted from `function BlockPooky:Method()` to `function BlockPooky.Method()`
  - All method calls converted from `self:Method()` to `BlockPooky.Method()`
  - All property accesses converted from `self.property` to `BlockPooky.property`
  - Affected 113+ function definitions, 148+ method calls, and 200+ property accesses across 9 modules
  - Improves code clarity by accurately reflecting simple table pattern (non-OOP/non-class)
- **Fixed SavedVars Initialization**: Corrected escaped quotes in configuration initialization
- **Fixed Menu JSON Structure**: Corrected corrupted table definitions in cooldown bar settings menu
- **Verified Functionality**: All features tested in ESO and confirmed working correctly
  - Block warnings, CC immunity tracking, hints, cooldown bars, negate detection, threat alerts all operational

### Version 2.9 - LibCombat Integration for Threat Alerts
- **LibCombat Integration**: Threat alert system now uses LibCombat's LIBCOMBAT_EVENT_DAMAGE_IN callback for improved reliability
  - More efficient event handling compared to EVENT_COMBAT_EVENT
  - Automatic filtering of player's own damage reduces processing overhead
  - Callback-based registration enables dynamic enable/disable from menu
- **Threat Alert Register/Unregister Pattern**: Implemented register/unregister methods following the negate warning pattern
  - Ability to toggle threat alerts on/off from settings menu without addon reload
  - Proper cleanup with pcall() error handling during unregistration
- **Added LibCombat>=2 Dependency**: Manifest updated to require LibCombat version 84 or higher
  - Ensures threat alert feature is only available when LibCombat is properly installed
  - Addon gracefully handles missing dependency (threat alerts disabled, other features work)

### Version 2.8 - bugfixes
- fixed the is in group check

### Version 2.7 - Threat Alert Awareness System
- **Full-Screen Threat Alert**: Visual alert overlay that covers your entire screen when dangerous threat abilities are cast
- **Configurable Abilities**: Detect Dark Convergence, Rush of Agony, and any custom ability IDs you add
- **Texture Selection**: Choose from 7 different overlay textures (red, gold, indigo, lemon, blood tint, stamina tint, redstar)
- **Opacity Control**: Adjustable overlay transparency (10%-80%) for visibility without full screen blocking
- **Timing Control**: Configure overlay duration (1-30 seconds) and cooldown (0.5-10 seconds) between alerts
- **PvP-Only Mode**: Option to only trigger alerts in Cyrodiil PvP zones (on by default)
- **Removable Abilities**: All threat abilities including defaults (DC/ROA) can be removed or customized
- **Full Menu Integration**: Complete settings submenu with enable/disable toggle, texture dropdown, sliders, and ability management
- **Enemy Source Filtering**: Ignores alerts from allies, companions, and group members

### Version 2.6 - Customizable Messages
- **Message Customization**: All UI frames, CSA messages, and labels are now customizable through the settings menu
- **New Submenu**: "Customize Messages" allows personalization of 8 different messages
- **Default Reset**: One-click reset button to restore all messages to defaults
- **Dynamic Updates**: UI labels update immediately when messages are changed

### Version 2.5 - ESOUI Compliance & Performance
- **Added dependency version checks** in manifest (LibChatMessage>=1, LibAddonMenu-2.0>=2.0, LibMapPing>=100, LibGPS>=1)
  - Prevents addon from loading with outdated/broken libraries
- **Optimized EVENT_COMBAT_EVENT handling** with C-level event filters
  - Filters `ACTION_RESULT_EFFECT_GAINED` and non-errors at C level before Lua processing
  - Significant performance improvement during combat (reduced memory usage and CPU cycles)
- **Group Messaging Warning**: Added warning about LibMapPing backdoor API
  - ZOS flagged MapPing as a backdoor for data sharing (2024-12)
  - Feature remains available but marked as potentially violating ESOUI rules
  - Menu option highlighted in red with `!` indicator

### Version 2.4
- Added Combat Visuals submenu: UI controls for AOE brightness, outline thickness, and target outline intensity
- Added RGB AOE cycling: Enable/disable, speed, turbo, and default color controls
- Improved settings persistence and menu integration
- Updated CC immunity bar logic for new ESO API (Escapist's Poison supported)
- Compatible with latest ESO API (101046)

### Version 2.2
- Full feature set as documented
- Compatible with latest ESO API

---

**Remember**: In PvP, awareness is survival. BlockPooky helps you stay one step ahead! 🛡️