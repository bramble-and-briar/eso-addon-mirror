# Fury's Quality of Life

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own characters before it goes up, and I maintain it. Please report any problem in the comments.

> **New:** this addon now requires [Fury's Addons Menu](https://www.esoui.com/downloads/info5126-FurysAddonsMenu.html), a free library like LibAddonMenu-2.0. Minion 3 does not install libraries for you, so if the addon stops loading after this update, install it from the link or in Minion.

Small comforts for everyday play in The Elder Scrolls Online. Each one is a switch on the settings page.

**Everything starts turned off.** The addon does nothing until you turn a feature on.

**Requires:** [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) (version 43 or newer) and [Fury's Addons Menu](https://www.esoui.com/downloads/info5126-FurysAddonsMenu.html) (version 1.3.0 or newer), which gives all of Fury's addons the Fury sidebar and `/fury`. Both are separate downloads: search for them in Minion (Minion 3 does not install libraries for you) or get them from ESOUI. Without them, this addon will not load.

## Select all on the deconstruct screens

Adds a **Select all** button next to the big item slot on every deconstruct screen:

- blacksmithing, clothing, woodworking and jewelry stations
- enchanting tables, when you extract glyphs
- the deconstruct-anything screen of Giladil the Ragpicker

One switch turns it on everywhere. One click puts every item of the list you are looking at into the slot. It only selects: nothing is deconstructed until you press the game's own Deconstruct key, and the game still asks you to confirm. The game takes up to 100 items at a time, so with more than that you deconstruct and click Select all again. **Select none**, right under it, empties the slot again.

### What Select all leaves alone

Always:

- items you locked in the game
- items FCO ItemSaver or Item Saver protect from deconstruction, if you use one of them (neither is needed)

Until you allow it in the settings:

- gear that belongs to an item set
- set pieces that are not in your Set Collection yet
- gear with a trait this character can still research
- gear made by a player
- gear saved in an Armory build
- anything better than the quality you choose (it starts at Superior, blue)

After each click a chat line says how many items were selected and why the others were left out. You can still add any of them by hand.

**Keep the slot filled** (its own switch): after Select all, each deconstruct is followed by the next batch, so a full bag is only a few presses of the Deconstruct key. It stops when the list is empty, when you click Select none or when you leave the station.

## Fishing

Four switches, all start turned off.

**Bite alert.** Plays a sound and flashes "Fish on the line!" across the screen the moment a fish bites, so you can look away while you wait. You still reel in yourself. The settings let you pick the sound, or no sound, and have a button to try it.

**Choose the right bait.** When you look at a fishing hole, the bait that fits its water is chosen for you:

| Water | Baits |
| --- | --- |
| Foul | Crawlers, Fish Roe |
| River | Insect Parts, Shad |
| Lake | Guts, Minnow |
| Saltwater | Worms, Chub |

If you carry both baits for that water, the one you have the most of is used. With neither in the bag, Simple Bait is used if you have any. A chat line says what was chosen. The bait is chosen once each time you look at a hole, so a bait you pick by hand afterwards stays until you look away. The water is read from the English name of the fishing hole, so this part needs the game in English.

**Bag nearly full warning.** When a fish bites and your bag has 5 free slots or fewer, a chat line and a short sound say so.

**Rare fish callout.** When a rare fish (the kind the fishing achievements count) lands in your bag, its name flashes across the screen and a chat line links it.

## Queue alert

When the dungeon finder, a battleground queue or another group finder queue asks if you are ready, a sound and "Your queue is ready!" across the screen tell you. You still accept it yourself. It has its own sound choice and a button to try it. Starts turned off.

## Lock what I'm wearing

One click puts the game's own lock on every piece of gear the character has on, both weapon bars included. A locked item can't be deconstructed, sold, traded or destroyed, and Select all never picks it up. **Unlock what I'm wearing** takes the locks off again. Both are buttons in the settings, `/qol lock` and `/qol unlock`, and keys you can bind. With **Buttons on the inventory screen** turned on, both also sit under your weapons on the left of the inventory screen. It locks what is worn at that moment, so click it again after you change gear.

## Commands and keys

| Command | What it does |
| --- | --- |
| `/qol` | Open or close the Start here page |
| `/qol settings` | Open the settings |
| `/qol select` | Select all on the deconstruct screen you have open |
| `/qol lock` | Lock everything you are wearing |
| `/qol unlock` | Unlock everything you are wearing |
| `/qol help` | List the commands |

`/furyqol` does the same, in case another addon uses `/qol`.

Under Controls > Keybindings > Fury's Quality of Life you can give Select all, Lock and Unlock their own keys.

The Select all buttons are part of the keyboard and mouse interface. In gamepad mode they are not added.

## More from Fury

- [Fury's Guild Toolset](https://www.esoui.com/downloads/info5063.html): an officer's toolkit: bank alerts, member and inactivity reports, trader week totals, raffles, event sign-ups and recruiting.
- [Fury's Character Tracker](https://www.esoui.com/downloads/info5078.html): every character on one board: skill lines, crafting, research, daily writs, wallet and gear.
- [Fury's Inventory Ledger](https://www.esoui.com/downloads/info5099.html): every item you own in one list, across all your characters, the bank and your houses, with export to Excel.
- [Fury's Account Sync](https://www.esoui.com/downloads/info5106.html): make your other accounts on this PC match your main one: settings, keybinds, addon settings and builds.

All free on ESOUI and in Minion.

## Credits

- Written by Furyous.
- Settings page uses LibAddonMenu-2.0 by Seerah and sirinsidiator.
- Works alongside FCO ItemSaver by Baertram and Item Saver by Randactyl: what they protect is left alone.
- Game API details from the ESOUI wiki and ZeniMax's ESO UI source code.
- License: PolyForm Noncommercial 1.0.0. Free to use and share; selling it needs a separate license from the author.
