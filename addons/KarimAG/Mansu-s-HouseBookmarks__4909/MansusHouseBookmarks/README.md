# Mansu's HouseBookmarks

ESO add-on that keeps a short list of bookmarked houses, other players' and your own, and takes you there in one click or one key press:

| How | What it does |
|---|---|
| **`/mhb`** | prints your bookmarks in chat as the game's own housing links. Click one and the game asks "Travel to ...?" |
| **`/mhb 3`** | travels straight to bookmark 3 |
| **Five bindable keys** | travel straight to bookmarks 1 to 5 |

It is built to be as light as an add-on can be: one small Lua file, no window, no settings panel, no library. See [Footprint](#footprint).

## The idea

The game already has a link that teleports you to a house:

```
|H1:housing:<house ID>:<@owner>|h[any text]|h
```

Posted in chat, in a mail or in a guild's message, it shows as `[any text]` and offers to travel to that house of that player when clicked. A bookmark is just the two things such a link needs, the house ID and the owner's @name, plus a label if you want one. The add-on prints your bookmarks as those links, and its keys call the same travel functions the game calls when you confirm a link.

## Adding a bookmark

| You have | Type |
|---|---|
| nothing, you are standing in the house | `/mhb add` or `/mhb add My label` |
| a housing link copied from Discord, a website... | `/mhb add ` then paste the link (a label may follow it) |
| the owner's @name and the house ID | `/mhb add @name 98 My label` |
| only the owner's @name | `/mhb add @name My label` bookmarks the **primary residence** |

The label is optional everywhere. Without one the bookmark shows the house's name (the owner's @name for a primary residence); a pasted link brings its own text as the label unless you type another after it. In `/mhb add @name ...`, a number standing alone right after the name is the house ID. To find a house ID, type `/mhb houses` followed by a part of the house's name, in your game's language: every match is listed with its ID.

A bookmark works for any house of any player, primary residence or not, as long as its owner lets you in.

## Travelling

* `/mhb` lists the bookmarks; click a name, confirm the game's prompt.
* `/mhb <number>` goes to that bookmark at once, without a prompt. A chat line says where you are being taken.
* The keys go to bookmarks 1 to 5 at once, without a prompt. Bind them in the game menu under **Controls > Keybindings > Mansu's HouseBookmarks**. Nothing is bound by default. A sixth action, *List bookmarks in chat*, does what `/mhb` does.
* `/mhb @name 98` (or `/mhb @name` for the primary residence) travels without bookmarking anything.

Your own houses work too: you arrive inside.

## Managing the list

| Command | Effect |
|---|---|
| `/mhb name 3 New label` | renames bookmark 3 (`/mhb name 3` goes back to the house's name) |
| `/mhb move 3 1` | moves bookmark 3 to position 1 (`/mhb move 3` does the same). The keys follow the order of the list |
| `/mhb del 3` | removes bookmark 3 |
| `/mhb link 3` | puts the game's link for bookmark 3 in the chat box, so you can share it |
| `/mhb help` | lists the commands |

`/housebookmarks` is an alias of `/mhb`.

## When the game refuses

Travel is requested the way the game itself requests it, so its rules apply and its own messages are shown:

* the owner's visitor permissions decide whether you get in ("You don't have permission to visit this house.");
* some places cannot be left by travelling ("Cannot travel to house from this location.");
* the server may refuse for its own reasons (combat, a jump already in progress...);
* a house you only reached through House Tours may refuse a direct visit: tours have their own access rules.

The add-on cannot know in advance whether a house is open to you; it finds out when you try.

## Footprint

What "lightweight" means here, in facts:

* **Files:** one Lua file (about 22 KB, comments included) and a 1 KB keybinding file. No library, embedded or required. No window, no XML interface, no texture, no settings menu.
* **While you play:** nothing. No per-frame update, no event left registered after loading, no hook on the game's functions. Code runs only when you type `/mhb` or press one of its keys.
* **At load:** the file is read, six keybinding names are created and the saved list is checked. Only one language's texts are kept.
* **Memory:** under 30 KB of Lua memory with five bookmarks, measured in a stock Lua 5.1 interpreter outside the game (the game's own Lua engine may count slightly differently).
* **Saved variables:** your bookmarks and nothing else (owner, house ID, label), kept per megaserver and per account, so NA and EU lists do not mix.

## Limits

* There is no window: the list lives in chat. That is the point of the add-on.
* A bookmark of a primary residence has no house ID, so it cannot be a clickable link; use `/mhb <number>` or a key for it.
* The list is printed as system messages, so it shows in chat tabs that display them (the default tab does). The clickable links and `/mhb link` are made for the keyboard chat window; the other commands and the keys do not depend on it.
* The add-on's own texts are in English and French. House names and the game's messages follow the client language.

## Installation

1. Copy the `MansusHouseBookmarks` folder into `Documents\Elder Scrolls Online\live\AddOns\`
   (`~/Documents/Elder Scrolls Online/live/AddOns/` on macOS). The folder must contain `MansusHouseBookmarks.txt`.
2. Start the game (restart it if it was running: a newly added add-on is only found when the game starts), open the Add-Ons menu and make sure **Mansu's HouseBookmarks** is enabled.
3. Optional: bind the keys under **Controls > Keybindings > Mansu's HouseBookmarks**.

After a game update the add-on may be marked "Out of Date" in the Add-Ons menu until `## APIVersion` in `MansusHouseBookmarks.txt` is updated.

Checked against the ESO UI source 12.1.5 (API 101051).

## Files

```
MansusHouseBookmarks/
├── MansusHouseBookmarks.txt   manifest (title, API version, saved variables, files to load)
├── MansusHouseBookmarks.lua   the add-on
├── Bindings.xml               the six bindable actions
├── README.md
├── LICENSE
├── CHANGELOG.md               (repository only)
└── README_ESOUI.txt           (repository only: the text of the ESOUI page)
```

The game loads the first three.

## Licence

MIT (see `LICENSE`). Not affiliated with ZeniMax Online Studios.

## Links

* Source: https://github.com/Karimag1/MansusHouseBookmarks
* Bug reports: open an issue on GitHub

## AI disclosure and credits

**AI disclosure:** the code was generated with an AI assistant (Anthropic Claude) under the author's direction, working from the official ESO UI source ([esoui](https://github.com/esoui/esoui)). Not every line has been audited by a human — bug reports welcome.

**Credits:** travelling to other players' houses from a list of favourites is not a new idea. The ESOUI pages (descriptions and changelogs, not the code) of the following add-ons were reviewed while designing this one. No code was taken from any of them:

* [Port to Friend's House](https://www.esoui.com/downloads/info1758-PorttoFriendsHouse.html) by Sordrak — the add-on this one is a small alternative to: it has a window, a library of houses and keys for ten favourites
* [Go Home](https://www.esoui.com/downloads/info1604-GoHome.html) by static_recharge
* [House Hotkey](https://www.esoui.com/downloads/info4185-HouseHotkey.html) by thisbeaurielle
* [Hello Tamriel - Travel Tools](https://www.esoui.com/downloads/fileinfo.php?id=4229) by Dharan-Empire
* [Housing Hub](https://www.esoui.com/downloads/info2923-HousingHub.html) by Architectura and Cardinal05

Mansu's HouseBookmarks does much less than they do, on purpose. The travel calls and the checks follow ZeniMax's own UI code (esoui), and the refusal messages are the game's.
