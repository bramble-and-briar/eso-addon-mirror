<div align="center">

# Permanent Memento

*Auto-loops your active memento of choice.*

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
- **LibGroupBroadcast:** required for Group Sync.

Without the optional dependencies, the addon still runs entirely independently and can be controlled via built-in slash commands as a standalone utility.

## Why use this?

Opened so many crates had so many cool mementos but you don't even use them? well Mementos go on a short cooldown after each use, and most players don't have time to go through menus or have extra quickslot to re-activate them manually or just forget they even exist. Permanent Memento watches your chosen memento's cooldown and re-triggers it the instant it's ready again. Set it once and forget it.

It also watches for various things where you don't want a memento to be used, like moving, attacking, blocking, casting, swimming, sneaking, mounting up, being dead, teleporting, or opening a menu, and re-triggers after a short configurable grace delay for each, instead of forcing itself to activate even tho you can't (there's already one active or you are dead or swimming) or shouldn't (you are in combat and dont want to summon your cake and eat it infront of the enemy while it slaps you in the face). So you can focus on other things.

## Features

- **Permanent Memento:** Re-triggers your active memento the instant its cooldown clears, with independent grace delays for movement, combat end, resurrect, teleport, mount, sneak, swim, block, cast, attack, and opening a menu.
- **Delay Triggers:** Individually enable or disable which situations pause the auto-loop.
- **Learned Data:** Scans your collections for mementos you actually own and builds a custom list automatically, if it's not one of the default supported memento.
- **Favorites:** Star a subset of your learned mementos for quick random-select without pulling from your entire collection.
- **Random Modes:** Auto-pick a random supported (or favorited, or learned) memento on login, on zone change, or on demand.
- **Group Sync:** Broadcast your active memento to grouped players running the addon so everyone, you included, plays the same one at the same moment; players who already have a memento playing are left out (needs LibGroupBroadcast).
- **Profiles:** Character-specific or account-wide settings.
- **Module Manager:** soft-disable optional feature files when not needed to save up on CPU usage - re-enable any of them anytime via slash command or the dedicated Module Manager settings.
- **(PC & Console) Support:** Full console settings menu and native right-stick UI window dragging on Xbox/PlayStation.

## Usage

**Activate** - a memento as you normally would and watch it auto loop after it ends. Activate it again and it should stop the loop.

## Slash Commands *(PC & Console)*

| Command | Effect |
|---|---|
| <kbd>/pmem</kbd> | Displays commands in chat |
| <kbd>/pmsync &lt;name&gt;</kbd> | *PC only:* broadcast a memento to your group |
<details>
<summary>Show all commands</summary>

| Command | Effect |
|---|---|
| <kbd>/pmemstop</kbd> | Stop the current loop |
| <kbd>/pmempause</kbd> | Pause/resume the current loop |
| <kbd>/pmemlist</kbd> | List learned mementos |
| <kbd>/pmemplay &lt;name&gt;</kbd> | Start a specific learned memento |
| <kbd>/pmemrand</kbd> | Loop a random supported memento |
| <kbd>/pmemrandfav</kbd> | Toggle random-memento-from-favorites on login/zone |
| <kbd>/pmemrandlrn</kbd> | Toggle random-memento-from-learned |
| <kbd>/pmemrandlog</kbd> | Toggle random-memento-on-login |
| <kbd>/pmemrandzone</kbd> | Toggle random-memento-on-zone-change |
| <kbd>/pmemlearn</kbd> | Toggle learning mode (auto-learn new mementos) |
| <kbd>/pmemfree</kbd> | Toggle unrestricted mode (bypass activation restrictions) |
| <kbd>/pmemscan</kbd> | Scan collections for owned memento and add them to the supported list |
| <kbd>/pmemcsa</kbd> | Toggle screen announcements |
| <kbd>/pmemcombat</kbd> | Toggle looping while in combat |
| <kbd>/pmembugreport</kbd> | Open the bug report copy box |
| <kbd>/pmemui</kbd> | Toggle the HUD UI window |
| <kbd>/pmemlock</kbd> | Lock/unlock the HUD UI window |
| <kbd>/pmemresetui</kbd> | Reset HUD UI window position |
| <kbd>/pmemhudscale &lt;n&gt;</kbd> | Set HUD UI scale |
| <kbd>/pmemmenuscale &lt;n&gt;</kbd> | Set menu UI scale |
| <kbd>/pmemacct</kbd> | Toggle account-wide/character settings |
| <kbd>/pmemset &lt;name&gt; &lt;seconds&gt;</kbd> | Set a delay by name - <kbd>/pmemset list</kbd> shows valid names |
| <kbd>/pmemwipe</kbd> | Wipe all learned data |
| <kbd>/pmemwipefav</kbd> | Wipe all favorites |
| <kbd>/pmemwizard</kbd> | Re-run the first-time setup wizard |
| <kbd>/pmemlibwarn</kbd> | Toggle Library Warning Messages |
| <kbd>/pmemreset</kbd> | Reset all settings to defaults |
| <kbd>/pmemclientinfo</kbd> | Print client information |
| <kbd>/pmemlogs</kbd> | *PC only:* toggle chat log messages |
| <kbd>/pmemnospin</kbd> | *PC only:* stop the character-spin animation during activation |
| <kbd>/pmemunloadsync</kbd> / <kbd>/pmemunloadmenu</kbd> / <kbd>/pmemunloadui</kbd> / <kbd>/pmemunloadwizard</kbd> / <kbd>/pmemunloadmigration</kbd> | Module Manager: soft-disable an optional module |
| <kbd>/pmsyncon</kbd> | *PC only:* toggle group sync listening |
| <kbd>/pmsyncrand</kbd> | *PC only:* broadcast a random supported memento to your group |
| <kbd>/pmsyncdelay</kbd> | *PC only:* toggle a random delay before your sync broadcast |
| <kbd>/pmsyncstop</kbd> | *PC only:* stop group sync |

</details>

## Current Native Supported Mementos

- **[Almalexia's Enchanted Lantern](https://en.uesp.net/wiki/Online:Almalexia%27s_Enchanted_Lantern)**
- **[Astral Aurora Projector](https://en.uesp.net/wiki/Online:Astral_Aurora_Projector)**
- **[Blossom Bloom](https://en.uesp.net/wiki/Online:Blossom_Bloom)**
- **[Dwemervamidium Mirage](https://en.uesp.net/wiki/Online:Dwemervamidium_Mirage)**
- **[Dwarven Tonal Forks](https://en.uesp.net/wiki/Online:Dwarven_Tonal_Forks)**
- **[Fargrave Occult Curio](https://en.uesp.net/wiki/Online:Fargrave_Occult_Curio)**
- **[Fetish of Anger](https://en.uesp.net/wiki/Online:Fetish_of_Anger)**
- **[Finvir's Trinket](https://en.uesp.net/wiki/Online:Finvir%27s_Trinket)**
- **[Floral Swirl Aura](https://en.uesp.net/wiki/Online:Floral_Swirl_Aura)**
- **[Inferno Cleats](https://en.uesp.net/wiki/Online:Inferno_Cleats)**
- **[Mariner's Nimbus Stone](https://en.uesp.net/wiki/Online:Mariner%27s_Nimbus_Stone)**
- **[Remnant of Meridia's Light](https://en.uesp.net/wiki/Online:Remnant_of_Meridia's_Light)**
- **[Soul Crystals of the Returned](https://en.uesp.net/wiki/Online:Soul_Crystals_of_the_Returned)**
- **[Storm Atronach Aura](https://en.uesp.net/wiki/Online:Storm_Atronach_Aura)**
- **[Storm Atronach Transform](https://en.uesp.net/wiki/Online:Storm_Atronach_Transform)**
- **[Summoned Booknado](https://en.uesp.net/wiki/Online:Summoned_Booknado)**
- **[Surprising Snowglobe](https://en.uesp.net/wiki/Online:Surprising_Snowglobe)**
- **[Shimmering Gala Gown Veil](https://en.uesp.net/wiki/Online:Shimmering_Gala_Gown_Veil)**
- **[Swarm of Crows](https://en.uesp.net/wiki/Online:Swarm_of_Crows)**
- **[The Pie of Misrule](https://en.uesp.net/wiki/Online:The_Pie_of_Misrule)**
- **[Token of Root Sunder](https://en.uesp.net/wiki/Online:Token_of_Root_Sunder)**
- **[Wild Hunt Leaf-Dance Aura](https://en.uesp.net/wiki/Online:Wild_Hunt_Leaf-Dance_Aura)**
- **[Wild Hunt Transform](https://en.uesp.net/wiki/Online:Wild_Hunt_Transform)**

## Troubleshooting & System Limits

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
- [UESP](https://en.uesp.net/)
- [@sirinsidiator](https://github.com/esoui/esoui)
- [@Flat-Badger-1971](https://www.esoui.com/downloads/info4074-ESOluaAPIintellisenseforVisualStudioCode.html)
- [@sirinsidiator & @Seerah](https://www.esoui.com/downloads/info7.html) <sub>*(LibAddonMenu-2.0)*</sub>
- [@Harven & @votan](https://www.esoui.com/downloads/info584.html) <sub>*(LibHarvensAddonSettings)*</sub>
- [@sirinsidiator](https://www.esoui.com/downloads/info1337-LibGroupBroadcast.html) <sub>*(LibGroupBroadcast)*</sub>
- [@SinusPi, @merlight, @Rhyono, @Dolgubon](https://www.esoui.com/downloads/info1624.html) <sub>*(Zgoo High Isle)*</sub>
- [@Baertram](https://www.esoui.com/downloads/info2601.html) <sub>*(Mer Torchbug - Fixed and Improved "Variable inspector/Scripts/Events/and more")*</sub>

**Inspired the idea of Permanent Memento:**

- Realizing I had far too many mementos and some of them act like character VFX, I came to ESOUI to see if someone had made an add-on for it. I found some promising ones that worked, until I noticed they had issues or limitations and were abandoned; one needed slash commands every time, and the other ran without them but could be janky at times.
- [Memento Refresh](https://www.esoui.com/downloads/info2671-MementoRefresh.html) <sub>*(@Pretz333)*</sub>
- [PermAlmalexia: Permanent Mementos](https://www.esoui.com/downloads/info3578-PermAlmalexiaPermanentMementos.html#info) <sub>*(@Mouton)*</sub>

**Things my addon is compatible with:**

- [BeamMeUp](https://www.esoui.com/downloads/info2143.html) <sub>*(@DeadSoon, @Gamer1986PAN and others)*</sub>
- [PerfectPixel](https://www.esoui.com/downloads/info2103.html) <sub>*(@KL1SK, @Baertram, @Dakjaniels)*</sub>

**Testers & Suggestions:**

<!-- TESTERS:START -->
- @Drakius192
- @phlupp89
- @AHB182
- @HeyIt'sAmber
- @DemonCatDaphne
- @imPDA
- @Baertram
- @SeablueSky
- @THAMER_AKATOSH
<!-- TESTERS:END -->

**Check out my other addons/projects:**

- [Auto Lua Memory Cleaner](https://www.esoui.com/downloads/fileinfo.php?id=4388#info)
- [Permanent Memento](https://www.esoui.com/downloads/fileinfo.php?id=4116#info)
- [Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater](https://www.esoui.com/downloads/fileinfo.php?id=3249#info) <sub>*(Linux, macOS, SteamDeck, & Windows)*</sub>

If you like the addon and are considering donating, here's a link. Thank you!

[![Buy Me A Coffee](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/aph0nlc)

### Bug Reports

If you encounter any issues, please submit a report here
