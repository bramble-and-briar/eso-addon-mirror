# GroupFrames

Group frames for The Elder Scrolls Online that show what the default frames don't: each member's magicka, stamina, ultimate, DPS/HPS, active weapon bar and buffs with timers. Works on PC and console, and replaces the game's own group frames.

Author: Vixen Hunny · Version 1.2.0

## What each frame shows

From top to bottom:

| Row | Content | Where the data comes from |
| --- | --- | --- |
| Name | Role icon (class icon if no role is set), name, crown for the group leader | Game |
| Health | Bar with percentage, "Dead" or "Offline"; damage shields as a pale blue overlay | Game |
| Magicka, stamina | Thin bars | LibGroupResources |
| Ultimate | Icon of the member's current ultimate, a gold bar that fills towards its cost, and `current / needed` points. Turns bright when it can be cast | LibGroupCombatStats |
| Stats line | `FRONT` / `BACK` weapon bar on the left; DPS (red) and HPS (green) in thousands on the right | GroupFrames / LibGroupCombatStats |
| Buffs | Icons with remaining time and stack count. Timers turn yellow under 6 s and red under 3 s, and the icon pulses before it runs out. Debuffs have a red border | Game |

Members who are offline or out of support range are faded. Your own frame has a gold border.

Bars and labels stay empty or dimmed for members whose data is not available — see [What other players need](#what-other-players-need).

## Requirements

| Library | Needed for | Required? |
| --- | --- | --- |
| LibAddonMenu-2.0 | Settings menu | Yes |
| LibHarvensAddonSettings | Settings menu on console | Console only |
| LibGroupBroadcast | Everything shared between players | Optional |
| LibGroupResources | Magicka and stamina of other members | Optional |
| LibGroupCombatStats | Ultimate, DPS and HPS of other members | Optional |

Without the optional libraries the frames still work, with health, buffs and your own resources and ultimate.

## Installation

1. Copy the `GroupFrames` folder into your `AddOns` folder.
2. Install the libraries above.
3. Enable GroupFrames in the game's add-on list and reload the UI.

## What other players need

The game only tells an addon the health and buffs of group members. Everything else has to be sent by the other player's own client:

- **Magicka and stamina** show for members who run LibGroupResources.
- **Ultimate, DPS and HPS** show for members who run LibGroupCombatStats.
- **Front / back bar** shows only for members who also run GroupFrames, because no library shares it and GroupFrames sends it itself.

Sending can be switched off per addon in the LibGroupBroadcast settings. Installing these libraries also means your own values are sent to your group.

## Tracking buffs

Three groups of effects can be shown:

- **Major and Minor buffs.** All 21 of each are tracked by default. Each has its own checkbox, plus a switch for all Major and all Minor buffs.
- **Other Major/Minor effects.** Two toggles add Major/Minor buffs that are not in the list, and Major/Minor debuffs.
- **Other buffs (additional effects).** Anything else you choose, such as set procs or synergy buffs.

To add an effect, open the settings and go to **Other buffs (additional effects)**:

1. Pick a **Groupmate**, or leave it on Everyone.
2. Pick the effect under **Effects seen on them**. The list holds effects that were active on that member since you logged in. If one is missing, press **Refresh lists** while it is active.
3. Press **Add selected effect**.

You can also type an effect name or an ability id. A name tracks every ability with that name; an id tracks only that exact ability. To stop tracking, choose the effect under **Tracked effects** and press **Remove selected effect**.

The listed Major/Minor buffs are always controlled by their own checkboxes. They cannot be added as additional effects, by hand or by sharing, so unticking one always hides it.

### Blacklist

Under **Blacklist (never track)** you can block effects completely. A blacklisted effect is never shown, whatever the other settings say, and is ignored when a groupmate shares it. Pick one under **Effects seen** (all effects seen this session, Major/Minor buffs included) and press **Blacklist selected effect**, or type a name or ability id. To unblock an effect, choose it under **Blacklisted effects** and press **Remove from blacklist**.

The icons can be sorted by type (Major, Minor, added), by remaining time or by maximum duration, shortest or longest first.

## Sharing your effects with the group

Under **Share with groupmates**, **Share my effects** sends your additional effects to everyone in the group who uses GroupFrames. What they receive appears under **Shared with you**, where they add the ones they want. Nothing is added to anyone's frames without them choosing it, unless they turned on **Add shared effects automatically**.

Limits:

- Up to 30 effects tracked by id and 30 tracked by name per share.
- An effect you added by typing its name can only be shared once it has been seen in game.
- The Major/Minor checkboxes are not shared.

## Layout

- **Position.** On PC, unlock the frames (settings, or `/groupframes`) and drag them. On console, use the Position X and Position Y sliders.
- **Scale and width.** Sliders in the settings. On PC, while unlocked, the mouse wheel scales the frames and Shift + wheel changes their width.
- **Columns.** Frames stack downwards and start a new column after 6, so a 12-player group is 6 left and 6 right. "Wrap after" changes that number; 0 wraps automatically at the screen edge. "Direction" switches to rows.
- **Balanced wrapping.** On by default: 8 members become 4 + 4 instead of 6 + 2.
- **Adaptive size.** Frames shrink to 80 % once the group has more than 4 members. Both numbers are adjustable.
- **Preview.** "Toggle 12-frame preview" shows copies of your own frame so you can set the layout up without a group. Close the menu to see it.

## Slash commands

| Command | Effect |
| --- | --- |
| `/groupframes` | Lock or unlock dragging |
| `/groupframes lock` / `unlock` | Set the lock explicitly |
| `/groupframes test 12` | Preview that many frames |
| `/groupframes test` | Turn the preview on (12 frames) or off |
| `/groupframessettings` | Open the settings (PC) |

## Console

Console uses its own settings menu, built on LibHarvensAddonSettings. It has the same options as PC, with two differences: the position sliders replace mouse dragging, and a status line in the Other buffs section shows the result of the last button press, since there is no chat output.

Consoles show no error messages for addons. The **Diagnostics** section at the bottom of the settings stands in for that. It lists the version, which libraries were found, how many effects are on you and how many of them are tracked, and the first error if one occurred. Include that text when reporting a problem.

## Known limitations

- **English only for Major/Minor buffs.** They are recognised by their English names.
- **Nearby members only.** The game reports buffs only for group members near you.
- **Base morph icon.** LibGroupCombatStats shares the base ability of an ultimate, so the icon can be the unmorphed version.
- **Unknown bar.** For members who don't run GroupFrames the frame shows their front-bar ultimate.
- **Protocol ids are not reserved yet.** LibGroupBroadcast requires each addon to reserve its message ids on the [ESOUI wiki](https://wiki.esoui.com/LibGroupBroadcast_IDs). GroupFrames uses 230 (effect sharing) and 231 (weapon bar). Reserve them, or change `PROTOCOL_ID` in `Share.lua` and `BAR_PROTOCOL_ID` in `Stats.lua`, before publishing. If an id clashes with another addon, that feature turns itself off and the rest keeps working.

## Files

| File | Purpose |
| --- | --- |
| `GroupFrames.addon` | Manifest: version, dependencies and load order |
| `Buffs.lua` | The Major/Minor buff lists, the player's own effect list, the blacklist, and the decision whether an effect is tracked |
| `Share.lua` | Sending and receiving effect lists through LibGroupBroadcast |
| `Stats.lua` | Ultimate, DPS/HPS and weapon bar of each member |
| `GroupFrames.lua` | Creates and lays out the frames and runs the update loop |
| `Settings.lua` | The options menu for PC and console |

The files load in that order. `GroupFrames.lua` starts with an overview of how the frames are built and updated.

Settings are saved account-wide in `SavedVariables/GroupFrames.lua`.
