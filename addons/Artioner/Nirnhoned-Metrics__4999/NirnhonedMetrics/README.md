# Nirnhoned Metrics

*English · [Español](README.es.md)*

![Nirnhoned Metrics](screenshots/01-group-damage.png)

<sub><i>Screenshots taken with the Spanish game client. The add-on is fully translated into English, German and French and follows your game language.</i></sub>

**A damage and healing meter for The Elder Scrolls Online.** Colored bars with every player's total damage or healing, DPS/HPS and share of the group for each fight, plus a breakdown of your own abilities. Everything in a small window you can move, resize and configure.

<details>
<summary><b>Screenshots</b> (9)</summary>
<br>
<table>
<tr>
<td align="center"><a href="screenshots/01-group-damage.png"><img src="screenshots/01-group-damage.png" width="260" alt="Group damage"></a><br><sub>Group damage</sub></td>
<td align="center"><a href="screenshots/02-rest-of-group.png"><img src="screenshots/02-rest-of-group.png" width="260" alt="Rest of group in a boss fight"></a><br><sub>Rest of group in a boss fight</sub></td>
<td align="center"><a href="screenshots/03-group-healing.png"><img src="screenshots/03-group-healing.png" width="260" alt="Group healing"></a><br><sub>Group healing</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/04-my-abilities-damage.png"><img src="screenshots/04-my-abilities-damage.png" width="260" alt="My abilities: damage"></a><br><sub>My abilities: damage</sub></td>
<td align="center"><a href="screenshots/05-my-abilities-healing.png"><img src="screenshots/05-my-abilities-healing.png" width="260" alt="My abilities: healing"></a><br><sub>My abilities: healing</sub></td>
<td align="center"><a href="screenshots/06-settings-window.png"><img src="screenshots/06-settings-window.png" width="260" alt="Settings: window"></a><br><sub>Settings: window</sub></td>
</tr>
<tr>
<td align="center"><a href="screenshots/07-settings-bars.png"><img src="screenshots/07-settings-bars.png" width="260" alt="Settings: bars and class colors"></a><br><sub>Settings: bars and class colors</sub></td>
<td align="center"><a href="screenshots/08-settings-text-data.png"><img src="screenshots/08-settings-text-data.png" width="260" alt="Settings: text and data"></a><br><sub>Settings: text and data</sub></td>
<td align="center"><a href="screenshots/09-ability-tooltip.png"><img src="screenshots/09-ability-tooltip.png" width="260" alt="Ability details in the tooltip"></a><br><sub>Ability details in the tooltip</sub></td>
</tr>
</table>
</details>

## Features

- **Damage meter with colored bars** — `4.43M (53.4K, 9.5%)`: total damage, DPS and percentage of the group, ranked from highest to lowest, with class icons and class colors.
- **Damage and healing** — switch between measuring damage and healing; healing shows HPS and, in the tooltip, overhealing.
- **Your group** — ESO only tells each player about their own damage, so every group member measures theirs and shares it through [LibGroupCombatStats](https://github.com/m00nyONE/LibGroupCombatStats). Group members with Nirnhoned Metrics appear with their own bar; your numbers are exact, theirs are approximate (the library sends DPS in thousands).
- **Rest of group** — in boss fights, the health the bosses lose minus the damage already known gives an estimated bar for everyone who does not share theirs.
- **My abilities** — switch the view to see your own damage or healing per ability (and per pet), colored by damage type. Hover over a bar for hits, critical rate, average and highest hit.
- **Fight history** — the last fights are kept (10 by default); open any of them from the fights icon.
- **Fight duration** — the footer shows how long the fight lasted (with a clock icon) and which fight you are viewing.
- **Title bar icons** — in three groups: damage and healing · group and my abilities · fights, reset, collapse, lock, settings and close.
- **Collapse** — the arrow in the title bar folds the window down to its title bar and unfolds it again.
- **Custom title** — keep the default title or write your own, with a color of your choice or ESO color codes.
- **Move and resize** — unlock the window with the padlock, drag it from anywhere and resize it from its edges or the bottom-right corner. Mouse wheel scrolls when there are more bars than fit.
- **Settings** — window title, size, bar style (progress bar or flat), bar height, spacing, bar and title text size, opacities, colors per class, single color, damage-type colors, which values to show, character or @account names, only show in combat, hide in PvP, pet damage, fight end delay, history size, DPS sharing and the rest-of-group estimate.
- **Languages** — English, Spanish, German and French (follows the game client language).

## Installation

**Minion:** search for *Nirnhoned Metrics* and install it.

**Manually:**
1. Download the latest release.
2. Extract the `NirnhonedMetrics` folder into `Documents\Elder Scrolls Online\live\AddOns\`.
3. Start the game and enable Nirnhoned Metrics in the Add-Ons menu.

**Required libraries** (Minion installs them automatically):
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) r43 or newer — the settings in *Settings → Add-Ons*.
- [LibGroupCombatStats](https://www.esoui.com/downloads/info4024-LibGroupCombatStats.html) 2026-10-04 or newer — sharing damage with your group (it brings LibGroupBroadcast and LibCombat with it).

## Quick start

1. The meter appears on the left of the screen. Type `/nm` to show or hide it, or bind a key in *Controls → Nirnhoned Metrics*.
2. Fight: the bars fill up while you are in combat.
3. Use the icons in the title bar to switch between **Damage** and **Healing**, between **Group** and **My abilities**, or open a previous fight. Right-click the meter for the full menu.
4. Click the padlock to unlock the window, then drag it from anywhere and resize it from its edges or the bottom-right corner.

## Chat commands

```
/nm                          show/hide the meter
/nm mode [group|abilities]   switch view
/nm damage | healing         measure damage or healing
/nm reset                    clear all fights
/nm lock | unlock            lock or unlock the window
/nm resetpos                 move the window back to its starting position
/nm settings                 open the settings
```

## Support

Bug reports and ideas are welcome in [Issues](../../issues).

If you enjoy Nirnhoned Metrics, you can support it:
- On [Ko-fi](https://ko-fi.com/artion).
- With gold in-game to **@Artioner** (EU megaserver) — there is a *Donate gold* button in the settings.

## Credits

- **sirinsidiator** — [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) (settings panel) and LibGroupBroadcast.
- **m00nyONE** — [LibGroupCombatStats](https://www.esoui.com/downloads/info4024-LibGroupCombatStats.html) (sharing DPS/HPS with the group).
- **Solinur** — LibCombat, used by LibGroupCombatStats.
- The icons are the game's own art (ZeniMax Online Studios).

## AI disclosure

Nirnhoned Metrics was developed with the help of an AI coding assistant (Claude Code, by Anthropic). I reviewed and tested the code in game and maintain it myself.

## Development

See the [Spanish README](README.es.md#desarrollo) for the project structure and release checklist. Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

Copyright (C) 2026 @Artioner. Nirnhoned Metrics is free software, licensed under the [GNU General Public License v3.0](LICENSE): you may redistribute and modify it under those terms, keeping the author credit and publishing your changes under the same license.

---

*This add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries.*
