# OneDungeon

AI disclosure: Code and translations were generated with OpenAI Codex. Full in-game and native-speaker review is pending.

## Dependencies

[LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) **r43 or newer** is required for settings. Install it separately; it is not bundled. Dungeon, quest and pledge data are built in.

## Credits

OneDungeon: **oneDOK**. LibAddonMenu-2.0: **sirinsidiator and Seerah**. Quest ID mappings adapted from MyDung 1.1.1 by **@AwfulDead**. Game data cross-checked against [Raidificator](https://www.esoui.com/downloads/info1101-RaidificatorTrialArenaandDungeonTimer.html) by **code65536 / Olivierko** and [LibUndauntedPledges](https://www.esoui.com/downloads/info3946-LibUndauntedPledges.html) by **code65536**. ESO UI/API and built-in textures: **ZeniMax Online Studios** and respective rights holders. See [third-party notices](THIRD_PARTY_NOTICES.md).

## About OneDungeon

OneDungeon brings normal and veteran dungeons together in ESO's **Dungeon Finder → Specific Dungeons**. See story quests, Undaunted Pledges and achievement progress alongside each dungeon, then select the difficulties you want to queue for.

- Switch between the standard ESO order and alphabetical sorting by localized dungeon names.
- One row per dungeon, with independent **N** (Normal) and **V** (Veteran) selections.
- Icons for unfinished story quests, today's pledges and accepted pledges.
- **Vet**, **HM** and **Tri** columns for Veteran Clear, Hard Mode and Trifecta achievements, with native ESO achievement tooltips.
- Combined Hard Mode progress for dungeons that require multiple boss achievements.
- Quest and achievement updates while the list is open, with pledge refresh at the daily reset.

## Install and use

Copy this `OneDungeon` folder into `Documents/Elder Scrolls Online/live/AddOns/`, so that `AddOns/OneDungeon/OneDungeon.txt` exists. Install LibAddonMenu-2.0 r43+, enable both addons and run `/reloadui`.

Open **Dungeon Finder → Specific Dungeons**. Select **N**, **V** or both, then use the usual queue controls. Hover over the Quest header for the icon legend and over achievements for details.

- **White quest icon:** story quest not completed.
- **Blue pledge icon:** today's Undaunted Pledge; the accepted-pledge icon and glow indicate a pledge in your quest journal, including pledges kept from earlier days.
- **Bright achievement icon:** completed. **Dim icon:** incomplete. **—:** no achievement. **?:** unknown.

## Languages and compatibility

Includes English, German, French, Russian, Spanish, Chinese and Japanese interface text. Uses the client's language automatically, with English as the fallback. Settings: **Settings → Addons → OneDungeon**. Choose **Standard (ESO order)** or **Alphabetical**; the selection is shared by your characters and applies immediately, without clearing your dungeon selections. The default is Standard. Diagnostic commands are `/onedungeon debug`, `/onedungeon dump` and `/onedungeon refresh`.

Version **26.11.1**, targeting ESO API **101051**, for the PC keyboard/mouse interface. The gamepad interface is unchanged. Today's pledge calculation supports APIs **101045–101051**; newer APIs require an updated schedule. Unknown data is shown as **?**.

Other addons that replace the same dungeon list may conflict. If integration fails, OneDungeon restores the standard list until `/reloadui`. In-game layout, queue behavior and compatibility still need verification.
