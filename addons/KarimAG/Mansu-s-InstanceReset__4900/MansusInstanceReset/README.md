# Mansu's InstanceReset

ESO add-on that puts on three bindable keys what you otherwise open the group window for when resetting an instance: the **Dungeon Mode** setting (Normal / Veteran) and **Leave Instance**.

| Key | What it does |
|---|---|
| **Reset instance** | switches the dungeon mode to the other value and straight back. The mode ends where it started. |
| **Toggle dungeon mode** | switches between Normal and Veteran and stays there. |
| **Leave instance** | leaves the instance you are in. Press it twice: the first press only asks for the second. |

Bind them under **Settings > Controls > Keybindings > Mansu's InstanceReset**. Nothing is bound by default.

Each change of mode is confirmed by the game's usual alert and sound ("Dungeon difficulty changed to Veteran." / "Dungeon difficulty changed to Normal."), so a reset shows the two messages one after the other.

## Chat commands

| Command | Effect |
|---|---|
| `/mir` | prints the current mode, whether you can change it, and the commands |
| `/mir reset` | same as the Reset key |
| `/mir toggle` | same as the Toggle key |
| `/mir vet` | sets Veteran |
| `/mir normal` | sets Normal |
| `/mir leave` | leaves the instance at once |

`/instancereset` is an alias of `/mir`.

## About the reset

Switching the dungeon mode and back is the usual way to get a fresh dungeon instance without disbanding the group. The add-on only switches the mode; the reset itself is done by the game, so it follows the game's behaviour:

* Leave the instance first (the Leave key does it): the game does not let you change the mode while you are inside a dungeon.
* Forum reports say the instance resets right away when you are in a group and lead it, and that a solo character may have to wait a few minutes for the old instance to expire.

## Leaving the instance

The Leave key calls the same game function as *Leave Instance* in the group window, and works wherever the group window offers it. Instead of the game's confirmation window, the key asks for a second press within 3 seconds, so a stray press in a fight only shows a message. `/mir leave` leaves at once.

Battlegrounds are not left by this key: the game has its own dialog for them, which warns about the penalty.

## When the game refuses

Changes of mode are requested exactly the way the two buttons of the group window request them, so the same rules apply. The game refuses, and its own explanation is shown as an alert, when:

* you are in a group and you are not the leader;
* you are inside a dungeon;
* the group was created by the activity finder;
* the group has an active Group Finder listing;
* the character is below level 50.

These are the situations in which the group window shows the mode as plain text instead of the two buttons.

While a change is waiting for the server's answer (2 seconds at most), further key presses are ignored. If a reset reaches the other mode but cannot come back, an alert says which mode you are left on.

## Installation

1. Copy the `MansusInstanceReset` folder into `Documents\Elder Scrolls Online\live\AddOns\`
   (`~/Documents/Elder Scrolls Online/live/AddOns/` on macOS). The folder must contain `MansusInstanceReset.txt`.
2. Start the game (or `/reloadui`), open the Add-Ons menu at the character-select screen and make sure **Mansu's InstanceReset** is enabled.
3. Bind the keys under **Settings > Controls > Keybindings > Mansu's InstanceReset**.

After a game update the add-on may be flagged "out of date"; tick *Allow out of date add-ons* in the Add-Ons menu, or bump `## APIVersion` in `MansusInstanceReset.txt`.

## Notes

* No settings and no saved variables.
* Checked against the ESO UI source 12.1.5 (API 101051).

## Translations

The add-on's own texts live in `lang/en.lua` (default) and `lang/fr.lua`. To add a language, copy `lang/fr.lua` to `lang/<code>.lua`, where `<code>` is the client's language code (`de`, `es`, `ru`, `jp`, `zh`, …), and translate the texts on the right-hand side. No other file has to change: the manifest loads `lang/$(language).lua` by itself, and anything left untranslated stays in English. Send the file through GitHub or the ESOUI comments to have it included.

The alerts, mode names and refusal reasons are the game's own texts and already follow the client language.

## Files

```
MansusInstanceReset/
├── MansusInstanceReset.txt   manifest (title, API version, files to load)
├── MansusInstanceReset.lua   the add-on
├── Bindings.xml              the three bindable actions
├── lang/
│   ├── en.lua                English texts (default)
│   └── fr.lua                French texts
└── README.md
```

## Licence

MIT (see `LICENSE`). Not affiliated with ZeniMax Online Studios.

## Links

* Source: https://github.com/Karimag1/MansusInstanceReset
* Download / updates: ESOUI (search "Mansu's InstanceReset") or Minion
* Bug reports: open an issue on GitHub or comment on the ESOUI page

## AI disclosure and credits

**AI disclosure:** the code was generated with an AI assistant (Anthropic Claude) under the author's direction, working from the official ESO UI source ([esoui](https://github.com/esoui/esoui)). Not every line has been audited by a human — bug reports welcome.

**Credits:** [Raidificator](https://esoui.com/downloads/fileinfo.php?id=1101) (code65536, Olivierko) already offers a key to reset instances, by disbanding and reforming the group (formerly the [Dungeon and Trial Instance Reset Tool](https://www.esoui.com/downloads/info3718.html)), and a key to leave an instance that must be pressed twice. Its ESOUI page (not its code) was reviewed while designing this add-on. The reset here uses a different method (switching the dungeon mode); the Leave key and its double press follow the same idea. No code was taken from it.
