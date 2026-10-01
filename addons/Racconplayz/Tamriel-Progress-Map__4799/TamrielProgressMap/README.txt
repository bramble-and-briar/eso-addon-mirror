Tamriel Progress Map 2.7.5
Developed with AI assistance. The author is responsible for design, maintenance and final in-game validation.
Required dependency: LibAddonMenu-2.0 r43 or newer (install separately).
https://www.esoui.com/downloads/info7-LibAddonMenu.html

Author: Raccoonplayz
PC addon for The Elder Scrolls Online; manifest API versions: 101050 and 101051.
Supported translations: English, German, French, Spanish and Russian.
The active translation follows the ESO client language. English is the fallback.

INSTALLATION / UPDATE
1. Exit ESO or log out before replacing addon files.
2. Extract the TamrielProgressMap folder directly into your ESO live/AddOns folder.
   On Windows this is normally Documents/Elder Scrolls Online/live/AddOns.
   The manifest must be at AddOns/TamrielProgressMap/TamrielProgressMap.txt.
3. Install or update LibAddonMenu-2.0 separately, for example with Minion.
4. Enable Tamriel Progress Map in ESO's Add-Ons menu.
5. NumPad 5 opens/closes statistics. You can remap it in Controls > Keybindings.
   /tpm stats also opens statistics; /tpm shows available commands.

Keep the existing SavedVariables file when updating. Back it up before testing.
Account data is separated by ESO server and combat/economy ledgers by character.
The SavedVariables wrapper version remains 1 to preserve existing data.
A genuine pre-server legacy migration can cause one automatic ReloadUI.
Opening a different server with modern settings does not import another server's data.

WHAT IT TRACKS
- Zone Guide completion and additional informational progress categories.
- Alliance progress views and an optional goal HUD.
- Currency balances, recorded income/spending and separate personal bank transfers.
- Recorded PvE/PvP counters, activity logs and character playtime history.
ESO cannot reconstruct unrecorded historical transactions or combat events.
Kills without a usable name/ID may be displayed as Unknown Enemy.

VALIDATION FOR THIS BUILD
Lua 5.1 syntax and 46 automated regression tests passed in an offline test harness.
Event identifiers were checked against documented APIs 101050 and 101051.
Actual ESO UI rendering, live event timing and addon combinations require an in-game test.
Do not describe this build as independently tested in-game until that test has been completed.

CREDITS / ASSETS
- Original addon and maintenance: Raccoonplayz.
- LibAddonMenu-2.0: sirinsidiator and Seerah. This dependency is not bundled.
- ESO API documentation and UI references: ZeniMax Online Studios; reference mirror:
  https://github.com/esoui/esoui
- Included DDS artwork is unchanged from the author-supplied 2.7.4_Hotfix package.
  The archive did not supply asset provenance or third-party licensing information.
  The author must add any required artwork credits/permissions to the ESOUI description.
This is an unofficial community addon. ESO names and referenced game artwork belong
 to their respective owners. No license change to the original package is asserted.

ESOUI UPLOAD
Use an English description beginning with the AI-assistance disclosure and dependency.
Put update notes in the Changelog tab and supply actual in-game screenshots when required.
Review the current ESOUI rules before publishing:
https://www.esoui.com/forums/showthread.php?t=10790
https://www.esoui.com/forums/showthread.php?t=9
