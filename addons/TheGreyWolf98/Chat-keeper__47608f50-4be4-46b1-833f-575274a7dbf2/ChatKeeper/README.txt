Chat Keeper 0.1.1 - Console tester
By @TheGreyWolf98

Keeps a bounded, account-wide conversation history on the current server.
Records player chat received while installed, including whispers and guild chat.
Stores up to 500 messages, with an additional 256 KiB text budget. Oldest messages
are removed first. This is a text budget, not an exact Lua memory measurement.

Recent history is replayed locally once after login or UI reload (100 messages
by default). Saved lines are marked [Saved]. These are local system messages;
they are never sent to other players. Original channel filtering does not apply
to replayed system lines. Messages in restricted categories are not restored.
Saved links become plain text. New live messages keep ESO's normal links.
It cannot recover messages from before installation or while you were offline.

/chatkeeper             Settings
/chatkeeper history     Saved history viewer (10 messages per page)
/chatkeeper reset       Restore original HUD chat position
/chatkeeper clear       Show the history deletion command
/chatkeeper clear confirm  Delete this server's stored history

Settings: stick/D-pad selects, X/Y adjusts or toggles, A opens history,
RB restores original position, B closes. History: X older, Y newer, A settings.
Position uses UI units, not physical millimetres. Default vertical offset -40
moves native HUD chat upwards. Close settings to check the HUD position.
Timestamp display defaults to 24-hour HH:MM. 12-hour format is available.

Saved history shares across characters on the same account and server.
Reply using normal ESO chat; restoring text does not reopen or send a reply.
Chat Palette can continue managing your native chat colours.
No external addon libraries required.

TEST THIS ON XBOX
1. Receive a few messages, reload UI, check they return once with [Saved].
2. Switch character on the same server and check the conversation remains.
3. Check timestamps on new chat and links on live messages.
4. Adjust vertical offset, close settings, check minimap clearance.
5. Open/close menus and travel; check chat position and no duplicate replay.

Native HUD positioning and live formatter compatibility require console testing.
History stores received conversation text in ESO SavedVariables until trimmed
or cleared. The history viewer truncates long messages to two display lines.

0.1.1: Explicit player-channel allowlist replaces global enumeration to avoid
protected console globals in the live timestamp formatter and capture filter.
