# FishAlert 1.5.0

**Author:** @Saggy3214
**Game:** The Elder Scrolls Online (PC)
**License:** MIT (free to use)

FishAlert makes fishing easier to follow. When a fish bites, it shows a large **REEL IN!** message with a sound, so you
don't have to watch the bobber. It also counts your catches, shows how many fish you can fillet, and tracks which rare
fish you still need for the current zone's fishing achievement with its built-in rare fish tracker.

FishAlert never casts or reels in for you. You still fish by hand; it only tells you what is happening.

## Features

- **Bite alert:** a REEL IN! message and sound the moment a fish bites. Works with keyboard and mouse; no controller is
  needed.
- **Counters:** Fish Caught, Rare Fish and Fish to Fillet, in a small window that appears while you fish.
- **Built-in rare fish tracker:** the rare fish of your current zone's fishing achievement, with what you have caught,
  your progress, and each fish colored by its rarity.
- **Catch messages:** RARE FISH!, BONUS LOOT! (Wet Gunny Sack), BAIT FOUND!, FURNISHING FOUND!, JUNK CAUGHT! and
  ZONE COMPLETED!
- **Eight customizable sounds,** one for each kind of alert, each with a preview and a Test button.

## Installation

1. Download the ZIP file.
2. Extract it into your Elder Scrolls Online AddOns folder, which is usually:
   `Documents\Elder Scrolls Online\live\AddOns\`
   You should end up with an `AddOns\FishAlert\` folder containing `FishAlert.txt`.
3. Start the game (or type `/reloadui` if it is already running) and make sure FishAlert is turned on in the Add-Ons
   menu on the character select screen.

**Optional:** install **LibAddonMenu-2.0** to get the settings panel. Without it, FishAlert still works with its
default sounds or the sounds you chose before.

## Settings

With LibAddonMenu-2.0 installed, open **Settings > Addons > FishAlert**. There you can:

- choose a sound (or Off) for each of the eight alerts; choosing a sound plays a preview,
- press **Test** next to an alert to hear exactly what it will play,
- press **Restore Default Sounds** to undo your sound choices,
- reset either counter on its own (see "Resetting the counters" below).

## The counters

The counter window appears while you fish and hides a few seconds after you stop. It stays out of the way in combat,
in menus and on the map.

- **Fish Caught:** every catch that gives you a fish, rare fish included. A catch counts once, even if it gives more than
  one fish. Only catches made while FishAlert is installed are counted.
- **Rare Fish:** catches of rare (trophy) fish.
- **Fish to Fillet:** how many fish in your current character's backpack can be filleted. Rare trophy fish, fish in the
  bank, and fish in the craft bag are not included. This is not a running total. The number refreshes while FishAlert's
  window is visible, including whenever the window appears.

Fish Caught and Rare Fish are saved for your whole account and shared by all your characters.

## Built-in rare fish tracker

Below the counters, under the heading RARE FISH TRACKER, FishAlert lists the rare fish for the zone you are in. This is
part of FishAlert itself and is not related to the separate "Rare Fish Tracker" addon on ESOUI. It shows:

- a checked box for each fish you have already caught for the achievement, and an empty box for the ones you still need,
- each fish name in its rarity color (green, blue, purple, gold),
- your progress, such as `Progress: 7 / 12 - 58%`.

Delves and other areas inside a zone show that zone's achievement. Zones with no supported achievement show
"No supported rare fish achievement here." When you complete a zone's fishing achievement, FishAlert shows
**ZONE COMPLETED!**

## The eight sound notifications

| Alert | When it plays | Default sound |
|---|---|---|
| Fishing Bite | a fish bites (with REEL IN!) | Alert: Duel Start |
| Normal Fish | you catch an ordinary fish | Off |
| Rare Trophy Fish | you catch a rare fish (with RARE FISH!) | Coins: Gold Transaction |
| Wet Gunny Sack | you fish up a Wet Gunny Sack (with BONUS LOOT!) | Treasure: Bonus Item Found |
| Zone Completed | you complete a zone's fishing achievement (with ZONE COMPLETED!) | Victory: Level Up |
| Bait Found | you fish up bait (with BAIT FOUND!) | Off |
| Furnishing Found | you fish up a furnishing (with FURNISHING FOUND!) | Off |
| Junk Caught | you fish up junk (with JUNK CAUGHT!) | Off |

Each alert can use any of up to 50 sounds from the game's own sound library, or Off. The on-screen messages appear
even when a sound is set to Off.

## Chat commands

| Command | What it does |
|---|---|
| `/fishalert help` | Lists the commands (typing just `/fishalert` does the same). |
| `/fishalert move` | Unlocks the counter window so you can drag it. |
| `/fishalert reset` | Sets **both** Fish Caught and Rare Fish to 0 **immediately, without asking for confirmation.** |
| `/fishalert debug` | Turns troubleshooting messages in chat on or off. |
| `/fishalert banner reel` (or `rare`, `bonus`, `bait`, `furnishing`, `junk`, `zone`) | Shows a test message with its sound. |

## Moving the window

- Type `/fishalert move`, then drag the window with the mouse. It locks again by itself when you close chat, open a
  menu, enter combat, or after 2 minutes.
- You can also drag the window at any time while it is showing and your mouse cursor is active (for example while chat
  is open).

The position is saved.

## Resetting the counters

- **Settings panel:** the **Reset Fish Caught** and **Reset Rare Fish** buttons each reset only their own counter, and
  each asks you to confirm first. Cancel leaves the counter unchanged.
- **Chat command:** `/fishalert reset` resets **both** counters **immediately, with no confirmation**, and it cannot be
  undone.

The built-in rare fish tracker is never reset by either option; it reads your achievement progress from the game.

## Known limitations

- **Bite detection** uses a signal the game sends when a fish bites. It is not an official, documented feature for
  addons, so a future game update could change it.
- **FURNISHING FOUND!** has been tested with the test message only; detection of a real furnishing caught while fishing
  has not been confirmed yet.
- **JUNK CAUGHT!** currently recognizes Used Bait only. Other junk is not announced yet.
- **Languages:** FishAlert has not been tested in every game language. Some text and some rarity colors may not work
  everywhere.
- **Rarity colors:** for three fish (two in Hew's Bane, one in Pellitine), the color comes from evidence rather than an
  exact name match, and has not been confirmed in-game yet. Fish that FishAlert can't match keep a plain color.
- **Zones with two fishing achievements** (Gold Coast with the High Seas event, and Solstice) show two sections; this
  layout has not been fully tested yet.
- Not every feature has been tested in every situation. If something looks wrong, `/fishalert debug` shows extra details
  in chat that help with troubleshooting.
- Fish Caught and Rare Fish only count catches made while FishAlert is installed and turned on.

## Troubleshooting

**FishAlert doesn't appear at all**

- Check the folder: it must be `AddOns\FishAlert\` with `FishAlert.txt` directly inside it, not
  `AddOns\FishAlert\FishAlert\`.
- On the character select screen, open **Add-Ons** and make sure FishAlert is turned on. After a game update you may
  also need to tick **Allow out of date add-ons**.
- The window normally appears only while you fish: it shows up when you cast and hides a few seconds after you stop.
  It is also hidden in combat and in menus. To show it at any time, type `/fishalert move`.

**The window is in the wrong place**

- Type `/fishalert move` and drag the window. It locks again on its own, and its position is saved.

**There is no FishAlert settings panel**

- The settings panel needs **LibAddonMenu-2.0**. Install it, turn it on in the Add-Ons menu, then type `/reloadui`.

**No REEL IN! or no sound when a fish bites**

- Type `/fishalert banner reel`. You should see REEL IN! and hear the Fishing Bite sound.
- If the message appears but there is no sound, open **Settings > Addons > FishAlert**, make sure **Fishing Bite** is
  not set to Off, and press its **Test** button. Also check that your game sound is turned on.
- If the test works but real bites show nothing, please report it (see below) and say whether you play with keyboard
  and mouse or a controller.

**Debug mode**

- `/fishalert debug` turns extra chat messages on or off. They show the items you loot, counter changes, rare fish
  tracker details and Fish to Fillet changes. Debug mode does **not** log bite events. Turn it off again when you are
  done, as it adds a lot of chat messages.

**Reporting a problem**

- Please use the comments or bug report section on FishAlert's ESOUI page. Include your FishAlert version, your game
  language, whether you use keyboard and mouse or a controller, what you expected and what happened, and any chat lines
  from `/fishalert debug`.

## Credits

Thanks to **FloIstImGame**, author of **FishingSound** (ESOUI addon #4649), whose public description documented the
vibration values ESO sends when a fish bites.

FishAlert uses those published observations with its own bite-detection implementation.

## License

FishAlert is free software released under the MIT License. Copyright (c) 2026 @Saggy3214. See the `LICENSE` file for
the full text.

## Disclaimer

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
