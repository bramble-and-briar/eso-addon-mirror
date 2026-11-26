# Fury's Account Sync

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own accounts before it goes up, and I maintain it. Please report any problem in the comments.

Make your other accounts on this PC match your main one: game settings, keybinds, chat look, addon settings
and window layout, plus character builds you can load onto any character on any account.

**Requires:** LibAddonMenu-2.0 (version 43 or newer). Install it separately; without it the addon will not load.

Everything starts turned off. Nothing changes on any account until you turn it on there.

## How it works

Every account on the same PC shares this addon's saved file. Your main account takes a snapshot of its
setup, and your other accounts copy it when they log in.

1. Log in on your main account and type `/fas`. The window lists the three setup steps and marks the next one.
2. Press **Make this account the main**, then **Take snapshot** (or turn on **Take a snapshot automatically** in the settings).
3. Log in on another account and type `/fas`. It shows exactly what will change. Press **Apply to this character**.
4. To have later changes follow by themselves, click **At login** on that account until it says **Ask me** or **Automatic**.

On the main, the window says when something changed since the snapshot, so you know when to take a new one.

The game keeps settings, keybinds and chat colors per character, so each character copies once. With
**Automatically** that happens by itself the first time each character logs in after a new snapshot.
After copying, the window lists what was copied and anything the game didn't accept.

**If you use Synced Account Settings:** turn it off (or untick its Sync option). On any account where you
pressed its Save button it puts its saved settings and keybinds back after every login. On the main that can
erase a change before the snapshot is taken, and this addon warns you there. On an account that copies the
main it undoes the copy, so this addon copies nothing there while it is active and says so.

**Warning: copying addon settings can break an addon.** Some addons keep things that belong to one account or one
character in with their settings. Copy with care, check your addons afterwards, and use **Undo addon copies**
(in game) or **Restore a backup** (Windows tool) if one misbehaves. Game settings, keybinds and chat look are not affected by this.

## What it copies (in game)

- The game's Settings pages: Gameplay, Camera, Interface, Nameplates, Social, Combat and Accessibility. Each page can be turned off.
- Keybinds, including addon keybinds. An addon's keybind is copied once that addon is turned on for the account.
- Chat colors, chat text size and how far the chat window fades.
- **Addon settings** (starts turned off): the main's settings for every ticked addon on this addon's list that is turned on for the account. Only a small set of well-known addons is ticked to begin with; **Which addons** in the settings has a tickbox for each, so you can add them one at a time. This covers things such as options, colors and window positions. An addon's stats, logs and collected data stay as each account has them, and addons that only hold data (inventories, knowledge, guild history and the like) are never touched.
- **Chat window, meters and quest tracker** (starts turned off): where the base game's chat window, frame rate and ping meters and quest tracker sit, taken from the character the snapshot was made on.

**Same keybinds on all your characters** (starts turned off): the game keeps keybinds per character, so a key you set on one character is missing on your others. On the main account, tick "Same keybinds on all this account's characters" in the settings and every other character there takes the main character's keybinds when you log in on it, game and addon keys alike. The main character is the one you last pressed Take snapshot on; automatic snapshots only come from it. `/fas keys` copies them right away.

**HarvestMap** is copied too: which pins show, the filters, sizes and colors. It needs "account-wide settings" turned on in HarvestMap on the main. Its gathered pin locations are not touched.

An addon that isn't on the list is left alone, and the list of changes names the running ones. Under **Addons that aren't on the list** in the settings you can add one by its saved-data name. Everything it keeps for the whole account is then copied, so only add addons that hold settings.

On the main, the window lists your other accounts and whether they have the current snapshot.

Graphics and sound aren't copied because every account on the same PC already shares them.

Copying addon settings or window layout ends with a UI reload, which is what makes the addons load them. A pop-up asks first; with Cancel they load at your next reload or login. The
main's addon settings are read from its saved data, which the game writes when the main logs out or reloads
the UI. **Undo addon copies** in the settings (or `/fas undo`) puts back the addon settings the account had
before it first copied, for a month. With **Automatically**, addon settings are copied once per account for each
new snapshot.

## Character builds

Turn on **Character builds** in the settings to get a builds section in `/fas`:

- **Save build** saves this character's front and back skill bars, champion point stars, quickslot wheel and worn gear under a name.
- **Load build** puts a saved build on the character you're on, out of combat. Every account on this PC can load it.
- The tickboxes under it choose what gets loaded: skill bars, champion stars, quickslots, gear. Gear starts turned off. It is put on from the character's bag, and a piece of the same item, trait and quality counts.
- **Show as text** turns the chosen build into one line of text to copy with Ctrl+C. **Add from text** adds a build pasted into the same box, on this PC or another.
- Anything that doesn't fit is skipped and listed: another class's skills, skills not unlocked yet, champion stars not unlocked, items not in the bag, mementos or mounts not owned. If the character has a different morph of a skill, its own morph is slotted.
- Points spent in skills and champion trees are not changed.

## The Windows tool

A separate Windows tool copies addon settings with the game closed. Use it for addons that aren't turned on
for an account or aren't on this addon's list, and when you want a full backup first. Get it from
**Get the Windows tool** in the settings, or from the link on the ESOUI page. It backs up first, shows
exactly what will change, never copies addon data (inventories, knowledge, guild history and the like), and
can undo.

## Commands

- `/fas` open the window
- `/fas start` the Start here page: how it works, in one page
- `/fas snapshot` take a snapshot (main account)
- `/fas apply` apply the main's snapshot to this character
- `/fas keys` on the main account: give this character the main character's keybinds
- `/fas undo` put back the addon settings and window layout the account had before it copied the main's
- `/fas settings` or `/fassettings` open the settings
- `/fas undo NAME` put back one addon's own settings and untick it
- `/fas report` one line to paste into a comment when something goes wrong
- `/fas help` list the commands

A keybind to open the window is under Controls > Keybindings > Fury's Account Sync.

## More from Fury

- [Fury's Guild Toolset](https://www.esoui.com/downloads/info5063.html): an officer's toolkit: bank alerts, member and inactivity reports, trader week totals, raffles, event sign-ups and recruiting.
- [Fury's Character Tracker](https://www.esoui.com/downloads/info5078.html): every character on one board: skill lines, crafting, research, daily writs, wallet and gear.
- [Fury's Inventory Ledger](https://www.esoui.com/downloads/info5099.html): every item you own in one list, across all your characters, the bank and your houses, with export to Excel.
- [Fury's Quality of Life](https://www.esoui.com/downloads/info5115.html): small comforts for everyday play: Select all when you deconstruct, a fishing bite alert with the right bait, a queue alert and a lock for everything you wear.

All free on ESOUI and in Minion.

## Credits

By Furyous. Thanks to the authors of Synced Account Settings and Wizard's Wardrobe, whose addons showed which game functions do the job.
