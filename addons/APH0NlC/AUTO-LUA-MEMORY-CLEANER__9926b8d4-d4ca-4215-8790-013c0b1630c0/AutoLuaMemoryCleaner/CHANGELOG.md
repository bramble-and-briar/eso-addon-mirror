AutoLuaMemoryCleaner - Changelog
=================================

Version: 2026.10.07.17.24 (26100717)
---------------------------

Memory Cleanup
  - Cleanups from other add-ons that use LibAPH show in the window, chat logs and announcements.

Slash Commands
  - /alcon, /alccsa, /alclogs, /alcui and /alclock now say what they switched on or off.
  - /alclock and /alcreset are hidden while Show UI is off, and /alcpoolconfirm while Auto Pool Cleanup After Travel is off.

Settings Menu
  - The status window settings and the Auto Pool Cleanup After Travel Confirmation checkbox only appear while their setting is on.

Version: 2026.10.07.07.01 (26100707)
---------------------------

Cleanup Method
  - Update Automatic cleanup method, now the default: it picks the best method for each cleanup.
  - Added Vanilla, which leaves memory management to the game engine.
  - Chat, the center-screen message and the status window show which method Automatic picked; the status window shows it for 3 seconds.
  - Fixed the Cleanup Method dropdown showing empty text after switching methods.

Technical Style & Logic
  - The status window refreshes once a second only while it is on screen, instead of checking every frame, and only re-measures its width when the text layout changes.

Version: 2026.10.06.08.01 (26100608)
---------------------------

Technical Style & Logic
  - Now depends on LibAPH, a shared helper library for my addons.
  - Added a Module Manager - the Wizard, Menu, Migration, and UI modules can each be soft-disabled independently (/alcunloadwizard, /alcunloadmenu, /alcunloadmigration, /alcunloadui).
  - New Codebase changes, various stability and settings-menu fixes across PC and Console and language localization support.
  - Updated the Versioning.

Memory Pool Cleanup
  - Added Auto Pool Cleanup After Travel - watches for you traveling and reloads the UI afterward if the addon memory pool is worth clearing, or if you set a specific custom threshold for clearing. It only reloads when the pool has also grown since login or the last reload, so it never reloads for nothing.
  - Improved the accuracy of the Pool Cleanup report with an adaptive re-check.
  - Added Cleanup Method - Automatic (the default) picks the best of them each time and says which one it used, Background cleans up in small steps over several frames, so clearing a big Lua heap no longer have micro-stutters for the game, Vanilla leaves memory to the game engine; Aggressive and Deep Clean run one or two full passes. /alccleanupmode switches between them.

UI & Console Updates
  - Added a Setup Wizard on first install to ask your preferences.
  - Added LibHarvensAddonSettings support for the console Settings Menu.
  - Fixed Chat output on console for slash commands.
  - Added a Library Warning Messages toggle to enable or disable the optional-library popup, screen announcement, and chat reminder (/alclibwarn).
  - Updated the optional-library chat and screen announcement messages to clearly state whether LibAddonMenu or LibHarvensAddonSettings is missing, disabled, or outdated, with the popup and screen announcement (shown only once).
  - Updated settings-menu submenus remembering whether they were left open or closed across a reload (PC only).
  - Added a warning icon and a confirmation to Reset UI Position, Reset UI Size and Reset to Defaults.

General Additions
  - Updated Bug Report.
  - Removed Live statistics in favor of Client information for easier bug tracking and stability.
  - Removed the script profiler, memory graph, session history, FPS/ping/frame-time trackers and the cleanup percentage bar, along with their slash commands and the LibCombatAlerts dependency.
  - Updated Savedvariables: settings from 0.0.8 are reset to defaults once on first login, with a chat message.


Version: 2026.03.26.21.30 (26032621)
---------------------------

Technical Style & Logic
  - Improved Addon Code for better readability.
  - Updated Internal Function Calls to standardized dot notation for better consistency.
  - Optimized Console Thresholds by lowering the default cleanup trigger to 60MB (existing users are auto-migrated to the new cleanup threshold).
  - Improved Memory Tracking Accuracy by separating logical Lua memory from the physical Console Memory Pool across the UI and graph.

UI & Scene Manager
  - Added Gamepad UI Movement via LibCombatAlerts to allow PS5/Xbox users to move all ALC windows with the Right Stick.
  - Fixed the Scene Manager Override Bug that forcefully unhid the ALC UI by implementing strict fragment queries.

Profiler & Diagnostics
  - Introduced a Dynamic Severity Color Scale that automatically colors profiler scan results from gray to red based on their actual execution time.
  - Improved Time Formatting to dynamically convert milliseconds into seconds, minutes, or hours.
  - Optimized Console Profiling and reduced the scan time to 30 seconds.
  - Implemented an Emergency Stop for console users that forcefully halts the profiler at 80MB and priority-saves partial data to prevent a hard UI crash.
  - Added Specific Addon Exclusions and Libraries filtering submenus to filter profiler scans without needing to disable addons.
  - Implemented a Combat Safety Delay to pause the profiler from saving results if you are in combat, preventing in-game calculation freezes during combat scenarios.
  - Added a Profiler Results window inside the settings to display and save the complete list of all scan results.

General Additions
  - Added a Reset Button to safely wipe settings to default.
  - Added new slash commands /alcprolist and /alcprostop.


Version: 2026.03.17.21.30 (26031721)
---------------------------

Performance & API Updates
  - Updated API to 101049.
  - Optimized Event Dormancy to unregister background calls when sub-features are disabled.
  - Updated Performance-First Defaults to ensure the Graph, Chat Logs, and Trackers start OFF.
  - Optimized Priority Save logic to only trigger when statistics tracking is active.
  - Added a Track Statistics toggle (defaulted to OFF) for a more lightweight UX.
  - Added KB formatting for smaller memory cleanup reports.
  - Auto-Migration: new performance defaults automatically apply to existing users upon update.

UI & Console Updates
  - Added Console Positioning Sliders to allow PS5/Xbox users to move the UI (thanks to @Lily for the suggestion).
  - Introduced a Detachable Memory Graph Module (movable & lockable position).
  - Implemented Dynamic Visual Graph UI for real-time system monitoring.
  - Added a Dynamic Percentage Bar to indicate cleanup proximity based on user thresholds.
  - Added a Global Rendering Option to keep the UI visible while navigating menus.

Profiler Module & Dependency Warning
  - Added a Script Profiler Module to identify laggy addons via 60-second performance scans.
  - Added Optional Dependency Warning popups for missing or outdated LibAddonMenu-2.0.

Advanced Diagnostics & Session Tracking
  - Introduced a Detachable Session History UI to view previous session data.
  - Added Independent Session Data Logging for Peak, Average, and Final (Last Seen) states.
  - Added 21 new slash commands for full control over all diagnostic modules.


Version: 2026.03.02.21.30 (26030221)
---------------------------

General Updates
  - Improved cleanup routine checks for the built-in ALC logic.
  - Improved console event listener for more stability.
  - Changed LibAddonMenu-2.0 to an optional dependency. Core cleanup and /alc slash commands now work as a standalone utility.
  - Note: without the dependencies you can still run the addon independently and control its settings via built-in slash commands. Install the library if you want the settings GUI.


Version: 2026.02.27.21.30 (26022721)
---------------------------

UI & Slash Command Updates
  - Adjusted CSA messages to prevent text from being cut off.
  - Updated memory formatting to display MB, GB, or TB on the UI statistics panel.
  - Added a "Combat" state indicator to the draggable UI.
  - Updated the minimum memory reporting threshold to 0.01 MB.
  - Increased menu interaction memory check delay from 2s to 6s.
  - Updated slash commands and /alc output for better readability.
  - Updated settings menu tooltips to reflect command changes.


Version: 2026.02.17.21.30 (26021721)
---------------------------

Data & Performance
  - Added a "Live Statistics" panel to track memory usage and freed memory data.
  - Added Automatic Data Migration to prune obsolete SavedVariables from v0.0.1 through v0.0.3.
  - Added "Priority Save" for background SavedVariables to protect data during unexpected game closures.


Version: 2026.02.16.21.30 (26021621)
---------------------------

  - Updated LibAddonMenu-2.0 minimum requirement to version 41.


Version: 2026.02.16.21.29 (26021621)
---------------------------

  - Updated LibAddonMenu-2.0 to latest version requirement.


Version: 2026.02.16.21.28 (26021621)
---------------------------

  - Initial public release.
