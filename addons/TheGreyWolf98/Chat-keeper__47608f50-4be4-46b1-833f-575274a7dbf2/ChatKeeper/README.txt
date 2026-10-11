Chat Keeper 1.0.0
By @TheGreyWolf98

Persistent conversation history, timestamps and native HUD chat positioning.
Designed for ESO console gamepad UI. No external addon libraries required.
The HUD remains transparent; no custom backgrounds or artwork.

HISTORY
Records supported player chat received while running: say, yell, zone,
group, whispers, emotes, guild and officer channels. History is shared across
characters on the same account and server. Stores the latest 100 messages;
messages older than 48 hours are removed. An additional 256 KiB text budget
bounds stored message content; this is not an exact Lua memory measurement.

Recent history is restored locally once after character login or UI reload
when the previous recorded activity was less than 30 minutes ago. After a
longer absence, automatic replay is skipped but unexpired messages remain in
the history viewer. Activity is recorded every minute and on deactivation.
Choose 25, 50, 75 or 100 messages to restore, or disable automatic restoration.

Restored lines are marked [Saved] and use local system messages. They are never
sent to other players, and original channel filters do not apply to those
replayed system lines. Restricted communication categories are excluded.
Saved links are plain text; new live chat keeps normal ESO links.
Cannot capture chat while offline or recover messages from before installation.

CONTROLS
/chatkeeper                 Settings
/chatkeeper history         Saved conversation viewer
/chatkeeper reset           Restore original HUD chat position
/chatkeeper clear           Show deletion instructions
/chatkeeper clear confirm   Delete this server's saved conversations

Settings: stick/D-pad selects, X decreases/toggles, Y increases/toggles,
A switches history/settings, RB resets position, B closes.
History: X older, Y newer; stick/D-pad also changes pages. Ten messages per page.
The viewer limits each message to two display lines.

HUD position: horizontal and vertical offsets in UI units. Negative vertical
values move chat up; default -40. Close settings to inspect the HUD position.
Native menu chat placement is retained. No chat scaling controls.
Timestamps can be disabled or shown in 24-hour / 12-hour format.
Reply through normal ESO chat. Chat Palette can manage native channel colours.

UPGRADING
Existing saved conversations and positioning preferences are retained.
Obsolete artwork settings are removed. Messages from early testers without
absolute timestamps are discarded because their age cannot be established.

1.0.0
Transparent HUD chat, bounded history and controller settings.
Removed tester labels; view-switch button labels refresh correctly.
History viewer trims expired messages when opened and shows an empty state.
