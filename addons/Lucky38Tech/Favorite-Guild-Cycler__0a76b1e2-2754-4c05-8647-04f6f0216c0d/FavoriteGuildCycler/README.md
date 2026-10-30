# Favorite Guild Cycler (v1.3.1)

Favorite Guild Cycler rotates the represented/displayed guild beneath your character nameplate through selected guilds. It includes sequential, reverse, random, and priority rotation modes; account-wide or per-character profiles; optional combat/menu/stealth/housing pauses; PvP and group-leader context rules; a character-sheet quick dialog; slash commands; optional notifications; and optional physical tabard synchronization.

## Important rate-limit warning

**Do not configure guild switching faster than once per second.** ESO's represented-guild API has been reported by an ESO addon developer to permit changing the represented guild once per second. This add-on now enforces a 1-second minimum, removes the sub-second speed controls, and also guards against manual/quick-switch attempts that happen too soon after another change.

ESO does **not** publish a fixed numeric threshold for Error 318 / "message rate limit." ZeniMax says Error 318 can result from sending messages too quickly, add-on-related in-game errors, or connection/latency problems. The 1-second minimum is a conservative safeguard for the *represented-guild API*; it is not a guarantee that Error 318 can never occur, and this add-on does not send guild-chat messages.

## Favorite persistence

Favorites are saved by the actual guild ID rather than only by the current guild slot number. This helps keep the same guilds selected across logins and prevents a different guild from silently inheriting a favorite when guild-slot order changes. Existing v1 slot-based favorites are migrated to guild IDs when guild data becomes available. Other settings, including enabled state, cycle speed, rotation mode, pauses, and notification preferences, continue to use ESO SavedVariables.

If the selected favorites belong to guild IDs that are no longer on the character, the add-on will not guess based on slot order. Newly joined/unrecognized guilds are left unselected until the user selects them.

## Speed and commands

- Minimum cycle interval: **1 second**.
- Settings slider: 1 to 300 seconds.
- Slash command allows 1 to 600 seconds, for example `/fgc speed 5`.
- `/fgc` toggles cycling.
- `/fgc on` and `/fgc off` control cycling directly.
- `/fgc next` immediately attempts the next selected guild, subject to the one-second API guard.
- `/fgc fav 2` toggles favorite status for guild slot 2.
- `/fgc list`, `/fgc status`, `/fgc mode seq`, `/fgc speed 5`, and `/fgc help` are also available.

## Settings persistence

ESO SavedVariables stores the user's settings. By default, settings are account-wide for the current ESO world; enable "Use Per-Character Settings" for a separate profile. Favorite guild identities are matched against guild IDs at login, with slot-based values migrated from older saved data when possible.

## Compatibility note

ESO's UI/API can change between game updates. The add-on calls the public `SetRepresentedGuildId` API when available and avoids submitting duplicate setter calls for one guild switch. If an update removes or changes that API, guild switching will report that it is unavailable rather than pretending the guild changed.


## Guild menu compatibility (v1.3.1)

The add-on no longer attaches its custom controller keybind strip to the actual Guild Hub menu. This avoids competing with ESO's native Guild menu selection controls, which could make a guild row appear unresponsive until another row was selected. The Character Sheet rows and shortcuts remain enabled, and the add-on's own settings menu and slash commands are unchanged.
