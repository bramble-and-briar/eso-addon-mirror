<div align="center">

# Auto Lua Memory Cleaner

*A lightweight, event-driven background memory cleaner for The Elder Scrolls Online.*

![Version](https://img.shields.io/badge/version-2026.10.07.17.24-9CD04C?style=flat-square)
![ESO API](https://img.shields.io/badge/ESO%20API-101051%20%7C%20101052-00FFFF?style=flat-square)
![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-fa9c1b?style=flat-square)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Xbox%20%7C%20PlayStation-FF69B4?style=flat-square)

</div>

## Dependencies

Requires **LibAPH** (shared helper library, hard dependency).

Optionals for additional features:
- **LibAddonMenu-2.0:** required for the PC Settings Menu.
- **LibHarvensAddonSettings:** required for the Console Settings Menu.

Without the optional dependencies, the addon still runs entirely independently and can be controlled via built-in slash commands as a standalone utility.

## Why use this over other memory cleaners?

Most memory cleaners run a fixed-interval `OnUpdate` timer that pings your memory every few seconds, looping endlessly from the moment you log in. Some of them do skip the check while you're in combat, but not all of them do - and some still print a memory info line on that same timer regardless of combat state or whether you're even looking at the UI. Most are also built before console APIs existed, and only track `collectgarbage` (ignoring console UI limits).

Auto Lua Memory Cleaner is event-driven first: real triggers (exiting combat, entering a menu, a low-memory warning) do almost all the work. There's still a lightweight ~5-second fallback poll running in the background (one cheap number comparison, not a full scan or UI rebuild) to catch you standing around doing nothing else, but that's a fraction of the constant polling most other memory cleaners run outright.

## Features

- **Near-Zero Idle Footprint:** most checks run only on real triggers - loading screens, exiting combat state, entering a menu - backed by a lightweight ~5-second fallback poll so idle time standing around is still covered without a heavy constant loop.
- **Smart Combat Lockout:** blocks the automatic threshold-based cleanup from running while you're in combat, preventing mid-fight frame drops *(imagine crashing in the middle of your Trifecta, or God Slayer run!)* - the only exception is for a console low-memory event, where the risk is an outright forced reload. *(If you are using "Vanilla" as the cleanup mode, memory management is left entirely to the game engine and may not prevent the forced reload - this addon does not touch how the base-game cleanup works.)*
- **(PC & Console) Support:** automatically adapts to your hardware specific memory rules. On PC, it helps you stay safely below the 512MB performance "soft limit" to prevent UI lag and stuttering. On Console, it safely monitors the strict 100MB hardware memory pool to prevent the game from forcefully reloading your UI. *(If you are using "Vanilla" as the cleanup mode, memory management is left entirely to the game engine and may not prevent the forced reload - this addon does not touch how the base-game cleanup works.)*
- **Cleanup Method:** pick how ALC clears Lua memory. Automatic (Recommended, the default) picks the best method each time. Background cleans up in small steps over several frames with no stutter. Vanilla leaves it to the game engine. Aggressive runs one full pass (a minor stutter) and Deep Clean runs two (a short freeze).
- **Other Add-ons:** Their LibAPH cleanups show in the window and chat too.
- **Single-Pass Engine Sweep:** a single blocking garbage collection cycle that forces execution of pending `__gc` hooks and clears out orphaned weak tables in one pass, with a smaller chance of catching every ready collectible garbage.
- **Double-Pass Engine Sweep:** a dual-pass garbage collection cycle to safely force execution of all pending `__gc` hooks and ensure orphaned weak tables are properly erased from the addon's Lua heap.
- **Background Sweep:** spreads the same garbage collection work across many game frames instead of running it all at once, so the addon's Lua heap gets cleaned without any single-frame pause large enough to notice *(the trade-off is that a full sweep takes a little longer in real time to finish)*.
- **Module Manager:** soft-disable optional feature files when not needed to save up on CPU usage - re-enable any of them anytime via slash command or the dedicated Module Manager settings.

## Usage & Core Settings

- **Auto-cleanup:** runs silently based on your thresholds.
- **Cleanup threshold:** separate sliders for PC (Lua heap MB) and Console (addon memory pool MB).

## Slash commands

| Command | Effect |
|---|---|
| <kbd>/alc</kbd> | List all commands in chat |
<details>
<summary>Show all commands</summary>

| Command | Effect |
|---|---|
| <kbd>/alcon</kbd> | Toggle Auto Lua Cleanup |
| <kbd>/alcclean</kbd> | Force a manual Lua cleanup |
| <kbd>/alcpoolreload</kbd> | Toggle Auto Pool Cleanup After Travel <sub>*(Console)*</sub> |
| <kbd>/alcpoolconfirm</kbd> | Toggle Auto Pool Cleanup After Travel Confirmation <sub>*(Console)*</sub> |
| <kbd>/alccleanupmode</kbd> | Switch the Cleanup Method |
| <kbd>/alcui</kbd> | Toggle the status UI |
| <kbd>/alclock</kbd> | Lock/unlock the UI |
| <kbd>/alcreset</kbd> | Reset UI position |
| <kbd>/alccsa</kbd> | Toggle center-screen announcements |
| <kbd>/alclogs</kbd> | Toggle chat logs |
| <kbd>/alcwizard</kbd> | Re-run the Setup Wizard |
| <kbd>/alclibwarn</kbd> | Toggle Library Warning Messages |
| <kbd>/alcbugreport</kbd> | Open the bug report copy box |
| <kbd>/alcdelvars</kbd> | Reset all settings to defaults |
| <kbd>/alcunloadwizard</kbd> | Toggle unload the Wizard module |
| <kbd>/alcunloadmenu</kbd> | Toggle unload the Menu module |
| <kbd>/alcunloadmigration</kbd> | Toggle unload the Migration module |
| <kbd>/alcunloadui</kbd> | Toggle unload the UI module |

</details>

## System Limits

**Engine Limits & Shared Memory:** because the ESO engine manages memory dynamically in a single global pool, we must rely on smart, threshold-based sweeping rather than passive monitoring. Addons do not run in isolated sandboxes. They share a single global memory pool. It is technically impossible to accurately track memory usage per individual addon without breaking shared libraries and cross-addon communication.

**Important Note On Memory Usage** <sub>*(PC & Console)*</sub>: unlike PC, where memory scales dynamically with a ~512 MB "soft limit" for UI lag, consoles have a strict 100 MB hardware memory pool for addons. Reaching the console cap will often cause the game to forcefully reload your UI or result in "Out of Memory" crashes.

If an automatic pool reload frees less than 0.5 MB (this can happen after switching between the keyboard and console UI), ALC says so instead of reporting a cleanup: ESO keeps that memory until the game is restarted, so ALC stops reloading for the pool until the next game launch.

> [!WARNING]
> While this addon is highly effective at clearing out background "garbage" to keep you under those limits, it cannot magically lower your memory usage if you are running too many heavy addons at once. If your memory remains dangerously high even after a manual cleanup, you should consider disabling a few large addons to ensure stability.

### Does it increase FPS?

No. Nothing here touches rendering, so your frame ceiling is unchanged.

What it protects is the frames you already have. A Lua garbage collection pass costs frame time, and the larger the heap the longer that pause runs. Left alone, the collector picks its own moment, which can be mid-fight. Auto Lua Memory Cleaner collects during dead time instead: a loading screen, the moment you drop out of combat, opening a menu. Keeping the heap small also keeps each pass short.

On Console the same idea covers the 100 MB pool. Clearing it while you are already sitting in a wayshrine loading screen puts the UI reload there, instead of mid-dungeon.

### Does it fix ping or lag spikes?

No. Ping (network latency) and FPS are separate systems - one measures how fast your computer talks to the server, the other measures how fast your CPU/GPU draw frames - and this addon only ever touches the Lua heap and, on console, the addon memory pool. It never reads or changes your connection.

Server-side or network lag shows up as stutter that can feel identical to a frame-rate drop (a burst of delayed data arriving all at once, or characters rubber-banding into position after a connection hiccup), but a Lua memory cleaner has no effect on that kind of stutter, because the cause isn't memory. If your performance dropped along with your connection or the server's condition rather than your addon list, this addon will not be the fix - that's outside what any UI addon can reach.

### Do You Actually Need This? <sub>*(PC & Console)*</sub>

> [!IMPORTANT]
> **NO.** If your total Lua memory usage consistently stays below 300 MB on PC *(with an SSD)*, or below 70 MB on Console, the native ESO engine is usually efficient enough on its own. This addon is specifically built for:

- **Power Users:** players with dozens of heavy addons pushing memory limits.
- **Console Players:** players already pushing to the 100 MB hardware cap.
- **Performance Freaks / Low-End Users:** anyone wanting manual control over when memory is cleared.

> [!WARNING]
> **Console Testing Notes:** This addon was developed and tested on **PC / Steam Deck** *(using Force Console Flow for console testing)*.

## License

Copyright © 2025-2026 @APHONlC. All rights reserved. See LICENSE.md

> [!NOTE]
> This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

For permissions or inquiries, contact @APHONlC on ESOUI.

## Credits

I would like to thank the following, for providing resources and their awesome projects:

- [ESOUI Wiki](https://wiki.esoui.com/Main_Page)
- [ESO Forums](https://forums.elderscrollsonline.com/en/discussion/689370/libharvensaddonsettings-to-libvotan-change-guide)
- [@sirinsidiator](https://github.com/esoui/esoui)
- [@Flat-Badger-1971](https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html)
- [@sirinsidiator & @Seerah](https://www.esoui.com/downloads/info7.html) <sub>*(LibAddonMenu-2.0)*</sub>
- [@Harven & @votan](https://www.esoui.com/downloads/info584.html) <sub>*(LibHarvensAddonSettings)*</sub>
- [@SinusPi, @merlight, @Rhyono, @Dolgubon](https://www.esoui.com/downloads/info1624.html) <sub>*(Zgoo High Isle)*</sub>
- [@Baertram](https://www.esoui.com/downloads/info2601.html) <sub>*(Mer Torchbug - Fixed and Improved "Variable inspector/Scripts/Events/and more")*</sub>

**Inspired the idea of automatic Lua memory cleanup:**

- [Shissu's LUA Memory](https://www.esoui.com/downloads/info883-ShissusLUAMemory.html)
- [Memory Garbage Collector](https://www.esoui.com/downloads/info4086-MemoryGarbageCollector.html)

**Testers & Suggestions:**

<!-- TESTERS:START -->
- @phlupp89
- @Drakius192
- @SeablueSky
- @HeyIt'sAmber
- @Lily
<!-- TESTERS:END -->

**Check out my other addons/projects:**

- [Auto Lua Memory Cleaner](https://www.esoui.com/downloads/fileinfo.php?id=4388#info)
- [Permanent Memento](https://www.esoui.com/downloads/fileinfo.php?id=4116#info)
- [Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater](https://www.esoui.com/downloads/fileinfo.php?id=3249#info) <sub>*(Linux, macOS, SteamDeck, & Windows)*</sub>

If you like the addon and are considering donating, here's a link. Thank you!

[![Buy Me A Coffee](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/aph0nlc)

### Bug Reports

If you encounter any issues, please submit a report here
