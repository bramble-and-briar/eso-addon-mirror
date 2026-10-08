PermMemento - Changelog
=========================

Version: 2026.10.07.17.24 (26100717)
---------------------------

Group Sync
  - Players who already have a memento playing are left out of a sync instead of queuing it.

Settings Menu
  - Fixed the Active, Sync and Learned memento dropdowns that could still show empty text after their lists refresh.
  - Activate Random Memento, Randomize on Zone Change and Randomize on Login only appear while Enable Randomization & Favorites is on, and the Group Sync section only while Group Sync is on.
  - Fixed Select Active Memento staying greyed out when Randomize on Zone Change was on but Randomization & Favorites was off.

Slash Commands
  - Commands that need Randomization & Favorites, Learning or Group Sync are hidden while that option is off.
  - Fixed /pmemacct (/pmemuseaccountsettings) being missing after the first session.
  - Random picks now say so when there is nothing to pick from, and a group sync message that could not be sent says so.
  - The /pmem command list on console no longer shows PC-only commands.

Version: 2026.10.06.08.01 (26100608)
---------------------------

New Features & Improvements
  - Added a Setup Wizard on first install to ask your preferences.
  - Added LibHarvensAddonSettings support for console Settings Menu.
  - Added a Delay Triggers submenu - individually enable or disable which situations pause the auto-loop.
  - Added dedicated delay-length sliders for Death, Crafting, and Attacking.
  - Changed Group Sync to run over LibGroupBroadcast, which it now needs; /pmsync no longer types into party chat.
  - Added a button to delete all saved per-character profile data (Advanced Settings, only available when using account-wide settings).
  - Updated Bug Report.
  - Updated Versioning.

Technical Style & Logic
  - Now depends on LibAPH, a shared helper library for my addons.
  - Updated Module Manager - Sync, Wizard, Menu, UI, and Migration can each be soft-disabled independently (/pmemunloadsync, /pmemunloadmenu, /pmemunloadui, /pmemunloadwizard, /pmemunloadmigration).
  - New Codebase changes and language localization support.
  - Removed a per-tick table allocation from the HUD's update handler.
  - The busy check now stops at the first reason that applies and only looks up that reason's text.

UI & Console Updates
  - The HUD UI auto hides and shows, if theres no active memento.
  - Updated the HUD countdown - now shows what's actually delaying the loop (e.g. "Crafting...", "Attacking...", "Casting...") instead of a generic "Delaying..." message.
  - Added a Library Warning Messages toggle to enable or disable the optional-library popup, screen announcement, and chat reminder (/pmemlibwarn).
  - Updated the optional-library chat and screen announcement messages to clearly state whether LibAddonMenu or LibHarvensAddonSettings is missing, disabled, or outdated, with the popup and screen announcement now shown only once instead of on every reload.
  - Added settings-menu submenus remembering whether they were left open or closed across a reload.
  - Added a warning icon and a confirmation to every button that resets, deletes or clears something, and to Unrestricted Mode.
  - Changed Remove Selected Favorite and Delete Selected Memento to red like the other dangerous buttons on console.

Maintenance & Bug Fixes
  - Fixed Crafting detection.
  - Updated the default Memento Delay values for new installs.
  - Removed Live statistics in favor of Client information for easier bug tracking.
  - Fixed the Active, Sync and Learned memento dropdowns showing empty text after their lists refresh.


Version: 2026.03.26.21.30 (26032621)
---------------------------

New Features & UI Overhauls
  - Added Gamepad UI Movement via LibCombatAlerts to allow PS5/Xbox users to move the status UI with the Right Stick.
  - Updated the old Character Management into Profile Manager to save, load, and delete custom settings profiles.
  - Updated Dropdown Menus to highlight the currently active memento and active profile in green.

Technical Style & Logic
  - Improved Addon Code for better readability.
  - Updated Internal Function Calls to standardized dot notation for better consistency.
  - Optimized Table Operations using ZO_ShallowTableCopy for configuration tables to prevent future accidental issues.

Maintenance & Bug Fixes
  - Fixed the Scene Manager Override Bug that forcefully unhid the PM UI by implementing strict fragment queries.
  - Optimized Reset Logic to safely wipe settings to default while protecting persistent data.
  - Updated Auto Lua Cleanup logic to ensure it stays dormant when core features aren't active.

Thanks to @Baertram for giving me some advice!


Version: 2026.03.17.21.30 (26031721)
---------------------------

New Features & Improvements
  - Introduced the Module Manager to the settings menu. Individual features (Stats Tracker, Random/Favorites, Learning Mode, Sync) can now be independently toggled off.
  - Updated all settings to now completely unregister events and background calls when modules are disabled, ensuring 0% CPU footprint for unused features.
  - Added several new slash commands to support the Module Manager toggles: /pmemstats, /pmemrandfav, /pmemlearn, and /pmsyncon (PC only).
  - Updated Auto Lua Memory Cleaner integration to safely synchronize with the recent ALC updates.
  - Added Dependency Warning popups for missing or outdated LibAddonMenu-2.0.
  - Added a Stop Character Spinning toggle and /pmemnospin command to prevent camera shifts in menus.
  - Added a Performance Mode toggle and /pmemperf command to reduce UI update frequency by 75%.

Fixes & Data Migration
  - Auto-Migration: the logic now automatically migrates your saved variables upon updating to ensure performance-first default settings are seamlessly applied without wiping your saved mementos.


Version: 2026.03.01.21.30 (26030121)
---------------------------

Fixes & Improvements
  - Improved cleanup routine checks for the built-in ALC logic.
  - Optimized the console event listener for increased stability on console hardware.
  - Adjusted the auto-cleanup delay to better synchronize with active memento animations.
  - Changed LibAddonMenu-2.0 to an optional dependency. Core cleanup and /pmem commands now work independently (install the library if you want the settings GUI).


Version: 2026.02.27.21.30 (26022721)
---------------------------

Fixes & Improvements
  - Improved CSA message handling to prevent long text strings from being cut off.
  - Updated all settings menu tooltips to accurately reflect recent slash command changes.
  - Enhanced the /pmem slash command chat output for significantly better readability.


Version: 2026.02.17.21.30 (26021721)
---------------------------

New Features & Improvements
  - Implemented Priority Save logic for background data saving to protect your configuration if the game client closes unexpectedly.
  - Updated the Live Statistics dashboard to display the version of LibAddonMenu currently loaded by the game engine.


Version: 2026.02.16.21.30 (26021621)
---------------------------

  - Updated minimum requirement to LibAddonMenu-2.0 version 41.


Version: 2026.02.16.21.29 (26021621)
---------------------------

  - Added support for the Auto Lua Memory Cleaner addon.


Version: 2026.02.15.21.30 (26021521)
---------------------------

New Features & Improvements
  - Updated LEARN: Auto-Scan to instantly scan all owned mementos in the background.
  - Added a Migrate SavedVariables button to the menu for manual data correction.
  - Improved Auto Lua Cleanup by replacing background timers with a dormant, event-driven trigger.
  - Added a DONATE button to the settings menu (PC only).

Fixes & Technical Updates
  - Fixed a critical issue where account-wide settings were saving to an orphaned profile instead of the correct megaserver.
  - Implemented SavedVariables Cleanup to automatically prune obsolete ghost data.
  - Refined Busy Checks to strictly pause during loading screens and buffer for 3 seconds after exiting combat.


Version: 2026.02.14.21.30 (26021421)
---------------------------

Major Feature Update & Optimization
  - Added the Shimmering Gala Gown Veil memento to the native support list.
  - Introduced the Auto Lua Cleanup logic (400MB PC / 85MB Console threshold).
  - Introduced the Auto-Scanner & Learned Data module with the LEARN: Auto-Scan button.
  - Added a Favorites Module for custom randomization pooling.
  - Added the Live Statistics Panel and Character Profiles management menu.
  - Implemented compatibility fixes for BeamMeUp, PerfectPixel, and crafting tables.
  - Transitioned all delay and CSA sliders from milliseconds to seconds.


Version: 2026.02.10.21.30 (26021021)
---------------------------

New Features & Improvements
  - Added Randomize features: Random on Login, Random on Zone, and an Activate Random button.
  - Added UI Scaling and CSA duration sliders for better visual customization.
  - Added the Group Stop button to remotely halt memento loops for your entire party.
  - Added state checks for menus and crafting to prevent interaction bugs.
  - Fixed a SavedVariables crash caused by missing or corrupted UI anchor data.


Version: 2026.02.09.21.30 (26020921)
---------------------------

  - Optimized event registration flow to prevent potential race conditions during initialization.
  - Corrected the AddOnVersion format in the manifest for standard compliance.
  - Updated internal logic to use self references for better stability and conflict prevention.


Version: 2026.02.08.21.30 (26020821)
---------------------------

  - Updated API Version and set UI defaults to the right side of the compass.
  - Added /pmem <name> partial search for quick activation.
  - Added the /pmem uireset command.
  - Integrated the sync module directly into main logic and removed obsolete debug logs.
