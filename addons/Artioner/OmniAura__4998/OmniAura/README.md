# OmniAura

*English · [Español](README.es.md)*

![OmniAura](screenshots/01-help.png)

**Your own on-screen alerts for The Elder Scrolls Online.** Track buffs, debuffs, resources, set procs and combat state, and show them as icons, bars or text exactly where you want them — all from an in-game visual editor, without typing a single ability ID.

<details>
<summary><b>Screenshots</b> (9)</summary>
<br>
<table>
<tr>
<td align="center"><a href="screenshots/01-help.png"><img src="screenshots/01-help.png" width="260" alt="Help in Settings"></a><br><sub>Help in Settings</sub></td>
<td align="center"><a href="screenshots/02-chat-commands.png"><img src="screenshots/02-chat-commands.png" width="260" alt="Chat commands"></a><br><sub>Chat commands</sub></td>
<td align="center"><a href="screenshots/03-editor.png"><img src="screenshots/03-editor.png" width="260" alt="Editor"></a><br><sub>Editor</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/04-watched-effects.png"><img src="screenshots/04-watched-effects.png" width="260" alt="Watched effects and options"></a><br><sub>Watched effects and options</sub></td>
<td align="center"><a href="screenshots/05-position-on-screen.png"><img src="screenshots/05-position-on-screen.png" width="260" alt="Position on screen"></a><br><sub>Position on screen</sub></td>
<td align="center"><a href="screenshots/06-icon-with-text.png"><img src="screenshots/06-icon-with-text.png" width="260" alt="Icon with text"></a><br><sub>Icon with text</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/07-bar.png"><img src="screenshots/07-bar.png" width="260" alt="Bar"></a><br><sub>Bar</sub></td>
<td align="center"><a href="screenshots/08-catalog-buffs.png"><img src="screenshots/08-catalog-buffs.png" width="260" alt="Catalog: buffs"></a><br><sub>Catalog: buffs</sub></td>
<td align="center"><a href="screenshots/09-catalog-gear.png"><img src="screenshots/09-catalog-gear.png" width="260" alt="Catalog: gear and sets"></a><br><sub>Catalog: gear and sets</sub></td>
</tr>
</table>
</details>

## Features

- **Visual editor** — type `/omni`, bind a key, or open it from *Settings → Add-Ons → OmniAura*. Create auras from ready-made templates.
- **Drag to place and resize** — *Position on screen* closes the editor and shows the aura you are editing over your game interface; drag it to move it and use its yellow corner to resize it, then press *Done* to return to the editor. **Position auras** hides the editor and shows your normal game interface so you can place every aura at once.
- **What you can track**
  - Buffs and debuffs on you, your target or a boss — while active or when missing, only yours, minimum stacks.
  - Health, magicka, stamina or ultimate, by value or percentage.
  - Procs and combat events, shown for a set number of seconds (set procs, internal cooldowns).
  - In or out of combat.
  - Several conditions per aura ("all" or "any"), and load conditions (always / only in combat / only out of combat).
  - Each aura can be available on all your characters or only on one.
- **Find any ability without IDs**
  - Search every ability in the game by name.
  - Browse a full **catalog** by category: major/minor buffs, debuffs, all seven classes, weapons, armor, guilds, world skills, Alliance War, racial, Mundus stones, companions, gear and consumables — with in-game tooltips.
  - Shortcuts for your current effects, the skills on your bars and recently seen effects and procs.
- **Displays** — icon (timer, stacks, duration shading, greyed out when missing), icon with text above, progress bar, or plain text. Colors via the game's color picker, text templates (`{name} {time} {stacks} {value} {max} {percent}`) and an optional sound.
- **Clean interface** — the editor is organized in sections and only shows the options that make sense for each aura.
- **Languages** — English, Spanish, German and French (follows the game client language).

## Installation

**Minion:** search for *OmniAura* and install it.

**Manually:**
1. Download the latest release.
2. Extract the `OmniAura` folder into `Documents\Elder Scrolls Online\live\AddOns\`.
3. Start the game and enable OmniAura in the Add-Ons menu.

**Optional:** [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) adds an OmniAura entry to *Settings → Add-Ons*.

## Quick start

1. Type `/omni` to open the editor.
2. Pick a template in **+ New aura...**, for example *Buff on me*.
3. Choose the effect from the search, the **catalog** or your current effects.
4. Press *Position on screen* and drag it where you want it, or use **Position auras** to place all of them over your game interface.

## Chat commands (advanced)

```
/omni                     open/close the editor
/omni list                list auras (numbered)
/omni show|on|off|del|copy <n>
/omni set <n> <path> <value>    e.g. set 1 display.type bar
/omni scan [player|target]      current effects with their IDs
/omni log                 log the ability IDs you use
/omni unlock | lock       enter/leave "Position auras" mode
/omni reset confirm       delete all auras
```

## Support

Bug reports and ideas are welcome in [Issues](../../issues).

If you enjoy OmniAura, you can support it:
- On [Ko-fi](https://ko-fi.com/artion).
- With gold in-game to **@Artioner** (EU megaserver) — there is a *Donate gold* button in the editor.

## Development

See the [Spanish README](README.es.md#desarrollo) for the project structure and release checklist. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

Copyright (C) 2026 @Artioner. OmniAura is free software, licensed under the [GNU General Public License v3.0](LICENSE): you may redistribute and modify it under those terms, keeping the author credit and publishing your changes under the same license.

---

*This add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries.*
