# Fury's Account Sync

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game on my own accounts before it goes up, and I maintain it. Please report any problem in the comments.

Make your other accounts on this PC match your main one: game settings, keybinds, chat look, addon settings
and window layout, plus character builds you can load onto any character on any account.

**Requires:** LibAddonMenu-2.0 (version 43 or newer).

Everything starts turned off. Nothing changes on any account until you turn it on there.

## How it works

Every account on the same PC shares this addon's saved file. Your main account takes a snapshot of its
setup, and your other accounts copy it when they log in.

1. Log in on your main account. Open Settings > Addons > Fury's Account Sync and press **Make this account the main**.
2. Type `/fas` and press **Take snapshot** (or turn on **Take a snapshot automatically**).
3. Log in on another account. In its settings, set **Copy the main's setup** to **Ask me when I log in** or **Automatically**.
4. `/fas` shows exactly what will change. Press **Apply to this character**.

The game keeps settings, keybinds and chat colors per character, so each character copies once. With
**Automatically** that happens by itself the first time each character logs in after a new snapshot.
After copying, the window lists what was copied and anything the game didn't accept.

**If you use Synced Account Settings:** turn it off (or untick its Sync option). On any account where you
pressed its Save button it puts its saved settings and keybinds back after every login. On the main that can
erase a change before the snapshot is taken, and this addon warns you there. On an account that copies the
main it undoes the copy, so this addon copies nothing there while it is active and says so.

## What it copies (in game)

- The game's Settings pages: Gameplay, Camera, Interface, Nameplates, Social, Combat and Accessibility. Each page can be turned off.
- Keybinds, including addon keybinds. An addon's keybind is copied once that addon is turned on for the account.
- Chat colors, chat text size and how far the chat window fades.
- **Addon settings** (starts turned off): the main's settings for every addon on this addon's list that is turned on for the account, such as options, colors and window positions. An addon's stats, logs and collected data stay as each account has them, and addons that only hold data (inventories, knowledge, guild history and the like) are never touched.
- **Chat window, meters and quest tracker** (starts turned off): where the base game's chat window, frame rate and ping meters and quest tracker sit, taken from the character the snapshot was made on.

Graphics and sound aren't copied because every account on the same PC already shares them.

Copying addon settings or window layout ends with a UI reload, which is what makes the addons load them. The
main's addon settings are read from its saved data, which the game writes when the main logs out or reloads
the UI. **Undo addon copies** in the settings (or `/fas undo`) puts back the addon settings the account had
before it first copied, for a month. With **Automatically**, addon settings are copied once per account for each
new snapshot.

## Character builds

Turn on **Character builds** in the settings to get a builds section in `/fas`:

- **Save build** saves this character's front and back skill bars, champion point stars and quickslot wheel under a name.
- **Load build** puts a saved build on the character you're on, out of combat. Every account on this PC can load it.
- The tickboxes under it choose what gets loaded: skill bars, champion stars, quickslots.
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
- `/fas snapshot` take a snapshot (main account)
- `/fas apply` apply the main's snapshot to this character
- `/fas undo` put back the addon settings and window layout the account had before it copied the main's
- `/fas settings` or `/fassettings` open the settings

A keybind to open the window is under Controls > Keybindings > Fury's Account Sync.

## Credits

By Furyous. Thanks to the authors of Synced Account Settings and Wizard's Wardrobe, whose addons showed which game functions do the job.
