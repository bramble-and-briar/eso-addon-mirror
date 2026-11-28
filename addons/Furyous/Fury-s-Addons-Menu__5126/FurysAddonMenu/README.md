# Fury's Addons Menu

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own characters before it goes up, and I maintain it. Please report any problem in the comments on ESOUI or in the issues here.

> **New:** every Fury addon now requires this library. Minion 3 does not install libraries for you, so if a Fury addon stops loading after its update, install Fury's Addons Menu from ESOUI or in Minion.

A library for **Fury's addons** in The Elder Scrolls Online. It runs the **Fury sidebar**: a slim bar with one icon per Fury addon you have installed, the `/fury` addons list, and the other Fury addons' icons in each Fury window's title bar, so any of them is one click away.

Every Fury addon requires it, like LibAddonMenu-2.0. Install it from ESOUI or Minion; Minion 3 does not install libraries for you.

## Downloads

Get it from ESOUI or Minion: search for "Fury's Addons Menu". The same files are in [`FurysAddonMenu/`](FurysAddonMenu/) here, and as [FurysAddonMenu-1.3.2.zip](https://github.com/AlbertHoffpauir/FurysAddonMenu/raw/main/downloads/FurysAddonMenu-1.3.2.zip). To install by hand, copy the `FurysAddonMenu` folder to `Documents/Elder Scrolls Online/live/AddOns/`.

## What it does

- **The sidebar.** `/fury` shows or hides it. Left-click an icon to open that addon, right-click for its settings, drag its violet line to move it. A column or a row, small or big icons, lock in place, hide in combat, and shown only with the cursor out unless you ask for it all the time.
- **The addons list.** `/fury menu`, or the sidebar's gear: every installed Fury addon with an Open and a Settings button, and the sidebar's options.
- **Title-bar icons.** Each Fury window shows the other Fury addons you have as small icons next to its name.
- **One key**, "Show or hide the Fury sidebar", under Fury's Addons in Controls > Keybindings.
- **One set of settings** for the whole PC, saved in `SavedVariables/FurysAddonMenu.lua`.

Everything starts turned off.

## Used by

- [Fury's Guild Toolset](https://www.esoui.com/downloads/info5063.html)
- [Fury's Character Tracker](https://www.esoui.com/downloads/info5078.html)
- [Fury's Inventory Ledger](https://www.esoui.com/downloads/info5099.html)
- [Fury's Account Sync](https://www.esoui.com/downloads/info5106.html)
- [Fury's Quality of Life](https://www.esoui.com/downloads/info5115.html)

## For addon authors

Other addons are welcome to use it, but it is made for Fury's addons and may change with them. Add `FurysAddonMenu>=130` to your `## DependsOn:` line, the same way Fury's addons do. Then:

- `FurysAddonMenu:Register({ name = "My Addon", glyph = "path/to/icon_up.dds", open = function() ... end, settings = function() ... end })` once while your addon loads. The sidebar and the list are built when the first character enters the world.
- `FurysAddonMenu:TitleIcons(window, { skip = "My Addon", label = titleLabel, version = versionLabel, rightOf = leftmostRightControl, reserve = 0, start = startButton })` puts the other registered addons' icons in a window's title bar the first time it shows.
- `FurysAddonMenu.Toggle()` shows or hides the sidebar; `FurysAddonMenu.Menu()` opens or closes the list.

## License

Free to use and share for noncommercial purposes under the PolyForm Noncommercial License 1.0.0 (see [LICENSE](LICENSE)). Selling it, or any other commercial use, needs a separate license from the author.

Bug reports and ideas are welcome in the comments on ESOUI or in the issues here.
