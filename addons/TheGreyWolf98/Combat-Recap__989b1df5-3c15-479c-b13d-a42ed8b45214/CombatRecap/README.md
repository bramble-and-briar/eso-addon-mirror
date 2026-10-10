# Combat Recap 1.0.0

By @TheGreyWolf98. No external dependencies.

## Use

- `/recap`: latest saved fight.
- `/recap N`: history entry N (1 is newest).
- `/recap stop`: save the current fight and suspend recording until combat ends.
- `/recap help`: commands and controls.
- `/recap clear confirm`: delete this character's saved fight history.

A opens the fight build. B returns to the combat report or closes it. X pages additional abilities/effects. Y changes fights.

## Recording

Twenty fights are saved per character/server. Personal damage and player pets only; group and companion damage are excluded. DPS spans first to last outgoing damage, with a minimum of one second. Hits include damage ticks.

Recorded player effects use their observed uptime; no target debuff uptime is reported. Light attack inputs and classified damage events are separate observations. Input events do not prove landed attacks, and the report does not calculate a missed-weave score.

The build is captured at first outgoing damage: gear, traits and enchants, both skill bars, slotted champion points, identity, Mundus and purchased class masteries. Optional unavailable data is labelled accordingly. Later build changes do not alter saved history.

## Updating from the tester

Upload this package as the next version of Combat Recap. Existing saved history is retained. Record a new fight for complete build data if an older report lacks it. The tested opaque layout, two-column effects and coloured champion point groups are retained.

## Release 1.0.0

Release labels and documentation updated from the Xbox-tested 0.0.6 build. ESO U51 marker retained. Development files are excluded from the release package.


## 1.0.1 Xbox test build
Automatic chat announcements now require a detected boss-tag target, matching reticle classification (elite/champion/boss where exposed), or English training-dummy name. All fights still save to history and remain available via /recap. /recap chat on and /recap chat off toggle automatic announcements. Note: ESO may not expose every champion/dummy classification consistently; test on Xbox and report missed cases.
