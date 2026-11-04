# Vigilant — Group Buff Tracker

Track the buffs of every group member at a glance in The Elder Scrolls Online.

> **AI disclosure:** this add-on was written with the help of an AI assistant (Claude).

- **Grid view**: one row per member, one column per buff. Lit icon with the time left when they have it, dimmed (or on red) when they don't.
- **Summary view**: one row per buff with how many members have it (`6/8`). Hover a row to see who is missing it.
- **Common buffs ready to pick**: 44 group buffs (Major/Minor Courage, Force, Slayer, Berserk, Resolve, Powerful Assault, War Horn, Pearlescent Ward...) by category in the settings.
- **Catalog of every buff and proc**: search any effect of the game by name or browse it by category (sets and procs, Major/Minor buffs, classes, weapons...) and track it with one click. *Active now* lists what you and your group have right now, handy to add a proc right after seeing it. No IDs needed.
- A buff counts no matter which skill or set gives it: every variant of *Major Courage* shares its name, so all of them are recognized.
- Buff names come from the game, so they show in your client language.
- Members out of range or offline are dimmed instead of being marked as missing.
- **Uptime in combat**: a bottom bar with the fight duration and, below each buff, the share of the fight the group had it. Hover it to see each member. Optional. Per fight or for the whole run (every fight until you change zone, e.g. a full dungeon), with a reset button.
- **Your own column order**: *Settings → Sort buffs* moves each buff up or down.
- **Account or character settings**: one setup for every character, or its own for this one.
- Same window style as Nirnhoned Metrics. - Title bar with buttons to close, lock/unlock, open the settings and switch view; unlocked, resize it from the corner or the right and bottom edges, and the icons fit the window.

**Requires** [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) (version 43 or later).

## Usage

1. Click the padlock (or type `/vigilant unlock`), drag the panel where you want it and resize it from its corner or edges. Click the padlock again to lock it.
2. Pick the common buffs in *Settings → Add-Ons → Vigilant* (or `/vigilant settings`).
3. For any other buff or proc, open the catalog (*Other buffs and procs → Open catalog*, or `/vigilant browse`) and click **+**.

| Command | |
|---|---|
| `/vigilant` | show/hide the panel |
| `/vigilant unlock` / `lock` | move and resize the panel / fix it in place |
| `/vigilant grid` / `summary` | switch view |
| `/vigilant browse` | catalog of every buff and proc |
| `/vigilant add <name>` | track a buff by its name |
| `/vigilant remove <name or number>` | stop tracking a custom buff |
| `/vigilant list` | tracked buffs |
| `/vigilant reset` | reset the uptime |

Key bindings: *Controls → Vigilant* (show/hide, lock/unlock).

## Performance

- Effect events are filtered by unit in the game engine (`AddFilterForEvent` with `REGISTER_FILTER_UNIT_TAG_PREFIX "group"` and `REGISTER_FILTER_UNIT_TAG "player"`), so Lua never sees effects on enemies or pets. The support range event is filtered the same way.
- Effect events are only registered while the panel is visible; the panel refresh (`RegisterForUpdate`, 200 ms) also stops when it is hidden.
- Each event is a table lookup; a member's buffs are only re-read when a tracked buff fades (another source may still be giving it) or when they come back into range.
- The catalog index of every game effect is only built the first time the catalog is opened, spread over several frames.
- One global (`Vigilant`). Saved variables in `Vigilant_SV`: account-wide by default (shared by all servers on purpose: they only hold the panel position, its look and the tracked buffs), or per character if you turn off *Same settings for all characters* (character settings are already separated by server).

## Credits

- The ability IDs of the built-in buff list were cross-checked against the data of LUI Extended (LuiData), FancyActionBar+ and LibCombat.
- The effect catalog is based on the one in my add-on OmniAura.

## License

GPL-3.0. See [LICENSE](LICENSE).
