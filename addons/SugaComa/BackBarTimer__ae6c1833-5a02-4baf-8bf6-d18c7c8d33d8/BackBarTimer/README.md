# BackBarTimer 1.0-rc2

BackBarTimer 1.0 is the standalone milestone release produced from the PS5-tested BackBarTimer + Cadence experiment in Suga's Test Zone.

It retains the original BackBarTimer modes and adds a lightweight Dual-Bar HUD designed for console. CadenceCoach remains a separate, unchanged add-on.

## Modes

- **Dual-Bar HUD** displays tracked front-bar skills on the right and back-bar skills on the left.
- **PvE (Per-Skill)** retains the original individual back-bar expiry alerts.
- **PvP (Grouped)** retains the original grouped back-bar expiry alert.

The ultimate slot is not tracked. Skills with a duration below four seconds are ignored. Every normal skill slot on both bars can be enabled or disabled independently.

## Dual-Bar prompts

The default is to show each qualifying skill for its full tracked duration. This can be changed to a custom start time from 3 to 60 seconds before expiry.

Before the final two seconds, the prompt shows the mapped controller button and a whole-second countdown. At two seconds it changes to the skill image and a decimal countdown. Controller glyphs use the approved 100% size and are raised four UI pixels to keep the countdown clear.

## Cadence prompts

The first enabled block or light-attack trigger starts a single-event one-second visual cycle:

```text
1 -> image -> 1 -> image
```

The number appears in the fixed cadence prompt position. At the one-second boundary it changes to the appropriate image for 300 ms, then the countdown restarts. Light attack uses the equipped front-main-hand weapon image on the right. Block uses the player's alliance Banner-Bearer shield on the left.

Unlike the earlier CadenceCoach-derived schedule, this uses only one image event in each cycle. There is no secondary skill/light event that could make the same prompt feel like it is firing at half-second intervals. Timing continues until combat ends, a menu opens, or cadence settings change.

The scheduler uses a 10 ms update rate only while cadence is active or waiting for a block trigger. Ordinary skill countdowns update at 100 ms to keep the console workload light.

## Menu safety

When the active ESO scene changes away from `hud` or `hudui`, BackBarTimer treats it as a menu:

1. all active skill timers are cancelled;
2. cadence timing and queued legacy alerts are cancelled;
3. every BackBarTimer HUD image is hidden immediately;
4. automatic action-bar refreshes cannot restore cancelled imagery;
5. tracking resumes only after the player uses a tracked skill again.

Expired timers also force their prompt to hide before the update scheduler stops.

## Version 1.0 defaults

- Mode: Dual-Bar HUD
- Front and back skill tracking: all enabled
- Show full skill countdown: enabled
- Block cadence: disabled
- Light-attack cadence: enabled
- HUD scale: 100%
- Left inset: 500 px
- Left vertical offset: -50 px
- Right inset: 700 px
- Right vertical offset: -50 px

Version 1.0 uses saved-variable schema 2 so these milestone defaults are applied independently of settings saved by the older BackBarTimer build.

## Installation

Copy the `BackBarTimer` folder into the ESO add-ons location used by the PS5 transfer process. Keep the folder name unchanged. LibHarvensAddonSettings is optional for runtime operation but is required to change settings through the console menu.

