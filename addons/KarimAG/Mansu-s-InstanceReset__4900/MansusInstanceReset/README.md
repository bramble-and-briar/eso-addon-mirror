# Mansu's InstanceReset

ESO add-on that puts the **Dungeon Mode** setting of the group window (Normal / Veteran) on two bindable keys, so you never have to open the group window for it:

| Key | What one press does |
|---|---|
| **Reset instance** | switches the dungeon mode to the other value and straight back. The mode ends where it started. |
| **Toggle dungeon mode** | switches between Normal and Veteran and stays there. |

Bind them under **Settings > Controls > Keybindings > Mansu's InstanceReset**. Nothing is bound by default.

Each change is confirmed by the game's usual alert and sound ("Dungeon difficulty changed to Veteran." / "Dungeon difficulty changed to Normal."), so a reset shows the two messages one after the other.

## Chat commands

| Command | Effect |
|---|---|
| `/mir` | prints the current mode, whether you can change it, and the commands |
| `/mir reset` | same as the Reset key |
| `/mir toggle` | same as the Toggle key |
| `/mir vet` | sets Veteran |
| `/mir normal` | sets Normal |

`/instancereset` is an alias of `/mir`.

## About the reset

Switching the dungeon mode and back is the usual way to get a fresh dungeon instance without disbanding the group. The add-on only switches the mode; the reset itself is done by the game, so it follows the game's behaviour:

* Leave the instance first: the game does not let you change the mode while you are inside a dungeon.
* Forum reports say the instance resets right away when you are in a group and lead it, and that a solo character may have to wait a few minutes for the old instance to expire.

## When the game refuses

Changes are requested exactly the way the two buttons of the group window request them, so the same rules apply. The game refuses, and its own explanation is shown as an alert, when:

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
* The add-on's own texts are in English and French. The alerts, mode names and refusal reasons are the game's and follow the client language.
* Checked against the ESO UI source 12.1.5 (API 101051).

## Files

```
MansusInstanceReset/
├── MansusInstanceReset.txt   manifest (title, API version, files to load)
├── MansusInstanceReset.lua   the add-on
├── Bindings.xml              the two bindable actions
└── README.md
```

## Licence

MIT (see `LICENSE`). Not affiliated with ZeniMax Online Studios.

## Links

* Source: https://github.com/Karimag1/MansusInstanceReset
* Bug reports: open an issue on GitHub

## AI disclosure and credits

**AI disclosure:** the code was generated with an AI assistant (Anthropic Claude) under the author's direction, working from the official ESO UI source ([esoui](https://github.com/esoui/esoui)). Not every line has been audited by a human — bug reports welcome.

**Credits:** resetting instances from a key already exists in [Raidificator](https://esoui.com/downloads/fileinfo.php?id=1101) (code65536, Olivierko), which does it by disbanding and reforming the group (formerly the [Dungeon and Trial Instance Reset Tool](https://www.esoui.com/downloads/info3718.html)). Its ESOUI page (not its code) was reviewed while designing this add-on, which uses a different method (switching the dungeon mode). No code was taken from it.
