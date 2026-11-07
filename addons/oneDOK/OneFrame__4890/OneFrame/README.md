# OneFrame 26.11.1

AI disclosure: Code and translations were generated with OpenAI Codex. Full in-game and native-speaker review is pending.

## Dependencies

Required: [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) r43 or newer. Install separately.

For shared DPS, HPS and Ultimate, install [LibGroupCombatStats](https://www.esoui.com/downloads/info4024-LibGroupCombatStats.html) 2026-10-04 or newer and its dependencies: [LibGroupBroadcast](https://www.esoui.com/downloads/info1337-LibGroupBroadcast.html) AddOnVersion 91 or newer and, on PC, [LibCombat](https://www.esoui.com/downloads/info2528-LibCombat.html) v83 or newer. Install their declared dependencies too. Hodor Reflexes is optional.

## Credits

OneFrame: oneDOK. Shared statistics: LibGroupCombatStats by m00nyONE and LibGroupBroadcast by sirinsidiator. The built-in group damage estimate adapts LibCombat v89 by Solinur under the Artistic License 2.0; see [notices and license](licenses/NOTICE.md). LibAddonMenu-2.0: sirinsidiator and Seerah. ESO UI/API and built-in textures: ZeniMax Online Studios and respective rights holders.

## About OneFrame

OneFrame adds useful information and customization to ESO's standard group and raid frames while keeping their familiar appearance.

- Custom role colors and damage-shield overlay color and opacity.
- Optional visual sorting by role.
- Class icons, level/Champion Points and account-name information.
- Choose DPS, HPS or no rate counter independently for each role.
- A colored Ultimate strip showing received points for group members.
- An optional estimated group DPS total.
- A right-click menu for whispering, travelling to a member and leader removal when permitted.

Settings: **Settings > Addons > OneFrame**. Interface languages: English and Russian; other clients use English. Settings are account-wide. Target ESO API: **101050 and 101051**; in-game acceptance is pending.

## Installation

Copy the `OneFrame` folder into `Documents/Elder Scrolls Online/live/AddOns/`, install the dependencies, enable OneFrame and run `/reloadui`.

Shared statistics use the same library transport as Hodor. Other members must also transmit their data through a compatible addon. Missing or stale data is not a received zero. The local player has a fallback damage/healing meter; its healing includes overhealing. The group DPS total is a client-side estimate.

Once OneFrame requests library sharing, it continues until UI reload, even if OneFrame's display is disabled. The library has no unregister API.

Version format: `YY.MM.Release`, with release numbering within the month.
