OneChat 26.11.1 - PC keyboard chat, ESO API 101051

AI disclosure: generated with OpenAI Codex. Source-reviewed and automatically
checked outside the game. Not yet tested in ESO. Custom translations have not
received native-speaker review. This is an in-game acceptance candidate.

INSTALL
Extract the OneChat folder into Documents/Elder Scrolls Online/live/AddOns.
The manifest must be at AddOns/OneChat/OneChat.txt. Requires LibAddonMenu-2.0 version 43 or later.
Enable the addon in ESO and reload the interface if already logged in.

USE
Open the existing tab options for Incoming and Outgoing channel groups.
Nested channels are always visible, with indentation. A dash indicates a partial
selection. Incoming Zone includes all language zones; outgoing Zone is only the
base Zone channel. Language zones are not selectable for outgoing chat. NPC is
incoming-only.

The channel selector remembers a separate selection for each tab. Empty tabs
show an em dash and allow manual channel commands. A manual command or whisper
does not replace the saved selection; the next message submission restores it.
Cancelling keeps the temporary channel and draft behavior unchanged.

Open Settings > Addons > OneChat (or /onechat) for message
appearance, guild abbreviations and the optional primary residence button.
Player names open temporary whispers; guild labels select an allowed guild
channel. Normal channel colors and embedded game links are retained.

Right-click a message or name, choose Copy, then press Ctrl+C in the selectable
field. Right-click native embedded links to append Copy to their usual menu.
When an identical embedded link occurs in several retained messages, the field
lists all matches because ESO exposes no exact message-under-mouse query.
Blank space after a message is not clickable. Old pre-addon history is unchanged.

SETTINGS
SavedVariables are isolated by world (NA/EU/PTS). Appearance is account-wide;
tab preferences are per character. Guild preferences follow guild IDs. Tabs
renamed or moved while the addon is enabled retain preferences. Renaming or
reordering identical tabs while disabled may require reconfiguration.

LIMITS
Home/social travel uses normal game APIs; combat, offline players, inaccessible
destinations and housing permissions can prevent travel. No restriction is
bypassed. OneChat never automatically sends chat messages or mail.
Competing chat-formatting, tab-options and input addons may conflict.
The mouse-driven UI is not a console/gamepad implementation.

BEFORE PUBLICATION
Verify UI scaling, Enter-key sends, commands, whispers, zero outgoing channels,
guild changes/permissions, tab rename/delete/transfer/reset, links and copy menus,
home travel, reload/relog persistence and all client languages in the game.
The full source repository includes validators and an API/source audit trail.

CREDITS
ESO UI/API and built-in art: ZeniMax Online Studios and respective owners.
No game art or upstream UI source is redistributed. See LICENSE.txt for original
OneChat code. Disclose AI generation in the public ESOUI addon description.
