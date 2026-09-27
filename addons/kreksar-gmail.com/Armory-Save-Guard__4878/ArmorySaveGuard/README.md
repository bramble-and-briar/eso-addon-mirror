[size=6][b]Armory Save Guard[/b][/size]
[i]by @Kreksar5 and Claude.ai[/i]

[color=orange][b]AI-ASSISTED ADDON.[/b][/color] Written with Claude.ai. This addon has been reviewed and tested in-game by the author for functionality.

Stops you from accidentally overwriting an Armory build. Instead of a one-click Accept, you must type [b]OVERWRITE[/b] before a build can be saved over, just like typing DESTROY to destroy a valuable item.

For the full version history, see the Change Log tab, or CHANGELOG.md included in the download.

[size=5][b]Usage[/b][/size]

[code]/armorysaveguard [on|off|toggle|status][/code]

[list]
[*]With no argument, toggles the typed confirmation on or off. On by default, account-wide.
[*]The word is case-sensitive.
[/list]

[size=5][b]Requirements[/b][/size]

[list]
[*]No dependencies.
[*]Keyboard mode. Gamepad mode uses the game's normal save prompt.
[/list]

[size=5][b]How It Works[/b][/size]

Pre-hooks ZO_ARMORY_MANAGER:ShowBuildOperationConfirmationDialog and, for save requests only, shows a typed-confirmation dialog in place of the game's Accept prompt. On confirm, it saves the build exactly the way the game's own prompt does, so the normal saving/success/failure popups still appear.

[size=5][b]Verification Notes[/b][/size]

All API usage was confirmed against the esoui/esoui source (live API 101050 and PTS API 101051) before being used.

[size=5][b]Known Limitations[/b][/size]

[list]
[*]Keyboard mode only.
[*]Prompt text and confirmation word are English only.
[*]Addons that lock the Armory save option (see Credits) may hook the same code.
[/list]

[size=5][b]Credits[/b][/size]

[list]
[*][b]ZeniMax Online Studios[/b] — the save logic and typed prompt follow the game's own ARMORY_BUILD_SAVE_CONFIRM_DIALOG and CONFIRM_DESTROY_ITEM_PROMPT code.
[*][b]Related addons[/b] — no code or ideas were taken from them, but they offer a build-lock alternative: [url=https://www.esoui.com/downloads/info3949-ArmoryStyleManagerforUpdate44.html]Armory Style Manager[/url] by CyberOnEso, Dekakaruk and loosej, and [url=https://www.esoui.com/downloads/info3560-2026.09.25.html]RidinDirty[/url] by sinnereso and MisB.
[/list]
