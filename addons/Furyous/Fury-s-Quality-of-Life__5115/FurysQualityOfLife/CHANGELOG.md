# Fury's Quality of Life changelog

## 0.6.0
- **Saved settings now load the standard way** (ZO_SavedVars), as ESOUI's reviewers asked. Your settings are moved over by themselves the first time you log in, so nothing changes for you.

## 0.5.9
- **Fury's Addons Menu is now a required library**, like LibAddonMenu-2.0, so it shows in the game's Required Add-Ons list. Install it from ESOUI or Minion (Minion 3 does not install libraries for you). It gives all of Fury's addons the Fury sidebar and `/fury`.

## 0.5.8
- **Fishing alerts listen less.** The bite alert, bag warning and rare fish alert now ask the game only for item changes in your backpack and craft bag, instead of checking every inventory change themselves (an ESOUI review suggestion).
- The manifest lists Fury's Addons Menu as an optional library without a version check, as ESOUI asks (the game does not check versions there).

## 0.5.7
- **The Fury sidebar now lives in Fury's Addons Menu.** The sidebar, the `/fury` list and the other Fury addons' icons in the title bar used to be copied into every Fury addon; that code now lives only in the optional library Fury's Addons Menu (1.3.0 or newer), as the ESOUI team suggested. With the library installed nothing changes for you and your sidebar settings carry over. Without it, this addon works the same, just without the sidebar, `/fury` and those title-bar icons.

## 0.5.6
- **Fury's Addons Menu is now a separate library.** The Fury sidebar's key and saved settings used to ship as a small folder inside every Fury addon. At the request of the ESOUI team it is now its own download, Fury's Addons Menu. It is optional: install it to keep the sidebar's key and to have the sidebar remember its settings. Without it, `/fury` and the sidebar still work. Your sidebar settings and your key carry over once it is installed.

## 0.5.5
- **Bite alert only when you are fishing.** Handing in a writ, or anything else that emptied a bag slot, could show "Fish on the line!" and ring the bell. The alert now only counts bait you use at a fishing hole.

## 0.5.4
- **Smaller version number.** The version in the title bar is now in small print, the same in every Fury window, so the name and your other Fury addons' icons stand out.

## 0.5.3
- **Title-bar icons moved to the left.** The row of your other Fury addons' icons now sits on the left of the title bar, between the addon's name and its version, the same in every Fury window. On the right it could cover other controls, such as Invite by code on the Guild Toolset's Events tab.

## 0.5.2
- **The sidebar shows only with your cursor out.** The Fury sidebar can only be clicked in cursor mode, so it now hides while you play without the cursor and comes back when the cursor does. A new box in the list (`/fury menu`), "Show the sidebar without the cursor too", keeps it on screen all the time.

## 0.5.1
- **Your other Fury addons in the title bar.** Every Fury addon's window now has a row of small icons in its title bar, one per other Fury addon you have installed. Left-click an icon to open that addon, right-click for its settings. Icons that don't fit in a narrow window are left out.
- **Slimmer sidebar.** The Fury sidebar is now about half as wide, with small icons. A new box in the list (`/fury menu`), "Bigger sidebar icons", brings the big ones back.

## 0.5.0
- **The Fury sidebar.** A slim bar of icons, one per Fury addon you have installed, that can stay on screen: left-click an icon to open that addon, right-click for its settings. Type `/fury` or press the key (Controls > Keybindings > Fury's Addons, now named "Show or hide the Fury sidebar") to show or hide it, and drag its violet line to move it. The gear on it, or `/fury menu`, opens the list of your Fury addons with the sidebar's options: a row or a column, lock in place, hide in combat. The sidebar starts turned off.

## 0.4.4
- One key for the Fury addons menu: "Open the Fury addons menu" now shows once in Controls > Keybindings, under Fury's Addons. If you had set a key for it, set it again there.
- Fury's Guild Management Toolset is now called Fury's Guild Toolset.

## 0.4.3
- First public release, on ESOUI and GitHub. No change in the game.

## 0.4.2
- Fury addons menu: /fury, or a key you can bind, opens one small window that lists every Fury addon you have installed, with Open and Settings buttons.

## 0.4.1
- Lock worn gear and Unlock worn gear buttons on the inventory screen, under your weapons. Own switch in the settings, starts turned off.

## 0.4.0
- Keep the slot filled: after Select all, each deconstruct is followed by the next batch, until the list is empty, you click Select none or you leave the station. Starts turned off.
- Queue alert: a sound and a flash across the screen when a dungeon, battleground or other group finder queue is ready. Own sound choice and a button to try it. Starts turned off.
- Lock what I'm wearing, and Unlock what I'm wearing: buttons in the settings, /qol lock and /qol unlock, and keys you can bind.
- Fishing: a warning when the bag is nearly full at a bite, and a callout when a rare fish is caught. Both start turned off.

## 0.3.1
- Fixed: the bite alert missed the bite when the bait is kept in the craft bag. The bait count is now watched directly, wherever the bait is.

## 0.3.0
- Select none button under Select all on every deconstruct screen: empties the slot again.

## 0.2.1
- Fixed: the bite alert did not fire. It no longer depends on what the game calls the fishing state.
- /qol fishdebug prints every bag change in chat, to check the alert when it misses a bite.

## 0.2.0
- Fishing: bite alert. A sound and a flash across the screen the moment a fish bites. Choose the sound, or none, in the settings, and try it with a button. Starts turned off.
- Fishing: the right bait. Looking at a fishing hole chooses the bait that fits its water, and of the two that fit, the one you have the most of. With neither, Simple Bait. Needs the game in English. Starts turned off.

## 0.1.0
- First version. Everything starts turned off.
- Select all button on every deconstruct screen: blacksmithing, clothing, woodworking and jewelry stations, enchanting tables (glyph extraction) and the deconstruct-anything screen of Giladil the Ragpicker.
- Select all only selects. Nothing is deconstructed until you press the game's own Deconstruct key.
- Locked items, and items FCO ItemSaver or Item Saver protect, are never selected.
- Set items, set pieces you have not collected yet, gear with a trait you can still research, crafted gear and gear in an Armory build are left out until you allow each in the settings.
- Best quality to pick up: starts at Superior (blue).
- A chat line after each click says how many items were selected and why the others were left out.
- Start here page (/qol), settings page, and a key you can bind for Select all.
