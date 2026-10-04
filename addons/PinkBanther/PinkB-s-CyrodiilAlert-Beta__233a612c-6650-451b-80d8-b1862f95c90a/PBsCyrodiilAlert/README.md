# PB's CyrodiilAlert

Tells you in chat when one of your alliance's holdings in Cyrodiil comes under attack, on
**The Elder Scrolls Online**.

- **Author:** PinkBanther

## Why this exists

Cyrodiil already knows a keep is being attacked — and shows it as a crossed-swords pin you have
to open the campaign map to see. If you are riding, farming a resource or fighting two keeps
away, the siege that takes your home keep happens in silence.

This add-on reads that same pin data on a timer and says it in the chat window, in colour:

| colour | when |
| --- | --- |
| **red** | one of your holdings has come under attack — and again while the attack lasts |
| **blue** | the attack is over and the holding is still yours — **defended** |
| **yellow** | the holding changed hands — **lost**, and which alliance took it |

Switch on **fights at enemy holdings** and the same watch points the other way:

| colour | when |
| --- | --- |
| **green** | a fight has started at a holding another alliance owns — with your own alliance's siege count there, where the game offers one |
| **blue** | that holding is now yours — **taken** |

Every line names the holding and what kind it is: `[Keep] Chalman Keep`, `[Town] Vlastarus`.

## Its own window, not your chat window

**Everything the add-on says goes into a window of its own** — alerts, command replies, the
list, the summary. Chat holds a conversation; an add-on's running commentary is not part of it,
and on console there are no tabs to put it in.

```
/pbalert log window | chat | both
/pbalert log clear
```

Newest line at the top. That is not a preference: it is the one arrangement a wrapped line
cannot break. The label's own line count is what bounds the window, and a bound that keeps the
*first* N lines would hide the newest the moment a long line wrapped into two.

| adjustable | |
| --- | --- |
| Where it speaks | its own window (default), the chat window, or both |
| Width and height | 240–1200 × 80–700 |
| Text size | 14–64; the typeface and outline are the alerts' |
| Lines kept | 3–40 |
| Background | 0–100% — a dark panel behind the text, because white text over a keep wall is not text |
| Position | the five corners and the middle, plus a sideways and an up/down offset |
| Draw order | in front of everything (default), normal, or behind everything — its own, separate from the summary's |

The window has no mouse, like the other two surfaces, so it cannot be dragged or clicked and can
never take a click away from the game. That is why the size and place are settings rather than a
drag handle — on a controller, a window you can grab by accident is a window that eventually
eats a keybind.

**The window belongs to Cyrodiil and the Imperial City.** Anywhere else it is not merely empty —
it is not there, and it comes back empty rather than carrying an hour-old alert into the next
session in the field. Output does not stop out there: it goes to chat, which is where it would
have gone anyway. (This is not the watch's *only while in an AvA zone* setting. That one decides
whether the campaign is being read; this decides where a window is allowed to sit.)

**It will not swallow its own output.** If the window cannot be created on a client, every line
goes to chat instead and `/pbalert` says why.

## On screen as well as in chat

Chat is a record you can scroll back through; the screen is where you notice something while
you are riding. Switch on **Show alerts on screen** and the same alerts are drawn over the game,
shortened to what can be read at a glance:

```
UNDER ATTACK: [Keep] Chalman Keep
LOST: [Town] Vlastarus (Aldmeri Dominion)
```

Chat still gets everything — the screen is a second surface, never a replacement — and each
kind of alert has its own switch for whether it appears there. Out of the box that is
**under attack** and **lost**, the two you have to react to.

| adjustable | |
| --- | --- |
| Typeface | five faces, all of them ones the console UI already has loaded |
| Size | 14–64 |
| Outline | thick outline, soft shadow (thin or thick), plain shadow, or none |
| Position | top centre, middle, bottom centre, top left, top right, bottom left, bottom right — plus a sideways and an up/down offset that reaches the whole screen |
| How long each line stays | 2–30 s; up to three lines at once, a fourth pushes the oldest off |
| Which alerts appear | one switch per alert |

**Show a test** in the panel, or `/pbalert test`, puts one of each alert up with made-up names,
so the look can be judged without waiting for a siege.

The window has the mouse switched off: it cannot be clicked, dragged or focused, so it can
never take a click away from the game underneath it. That is also why the position is set from
the panel rather than by dragging.

## Elder Scrolls — the one thing the game will name

`EVENT_ARTIFACT_CONTROL_STATE` is the only event in the whole AvA API that hands an add-on a
player's name, so these lines can say **who**:

```
Someone (Aldmeri Dominion) has taken Ghartok from Chalman Keep.
```

Taken, picked up off the ground, captured, returned, dropped, and returned by the timer (which
names nobody, because nobody did it). There are six scrolls in a campaign and they change hands
rarely, so it is quiet — and each line is one of the few things in Cyrodiil worth turning a raid
around for. On by default; `/pbalert scrolls off`.

It is an event, not a poll: the checking interval does not apply, and nothing about it can be
late. On console the line uses the display name, on desktop the character name — the same choice
the client makes for its own announcements.

## The campaign at a glance

A standing summary in a corner of the screen, on its own switch and in its own place:

```
Chalman
> Ebonheart Pact  keeps 8  score 12,345  under attack 2  pop [▮▮ ]
  Aldmeri Dominion  keeps 5  score 9,000  under attack 0  pop [▮▮▮]
  Daggerfall Covenant  keeps 2  score 3,000  under attack 0  pop [▮  ]
Volendrung: Aldmeri Dominion
Emperor: Someone (Aldmeri Dominion)
```

Each line is in its alliance's own colour, yours is marked, and they are in score order.
`/pbalert board` prints the same thing into chat without switching the screen one on.

**The population is an estimate in four buckets**, not a headcount — Low, Medium, High, Full.
The game publishes no player count anywhere, so there is nothing to turn those buckets into.

It is drawn as **the game's own campaign-browser icon** — the same picture the campaign screen
shows on the way in (the gamepad art on a console, the keyboard art otherwise), sized `100%` so
it follows whatever font it lands in, on screen or in chat.
`/pbalert board pop text` (or the panel) swaps it for the word, which is also what a client that
cannot produce the icon falls back to on its own, so the column is never blank.

It comes from the campaign *selection* data, which is filled by a request to the server
(`QueryCampaignSelectionData`, the same one the campaign browser makes each time it opens). So
it is asked for **every five minutes, and no more often**: a summary that refreshes every five
seconds must not become five seconds of server requests, and a four-bucket estimate does not
move fast enough to be worth one. It is asked for only while the summary is on screen (and, with
the watch's timer stopped, never outside Cyrodiil); printing it with `/pbalert board` is a direct
question and may ask too. Until an answer arrives the column reads `-`, and `/pbalert` says how
long ago the last one came in.

**Volendrung gets an alliance and no name.** Unlike the scrolls, the client is never told who
carries the Daedric artifact: `EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED` carries a
`holderAlliance` and nothing else, and the game's own announcement says no more than
*Volendrung is revealed*. The alliance is read off the map pin type, which is where the client
itself keeps it. The line appears only while the artifact is actually out, says *unclaimed* when
nobody has it, and says so plainly when the one carrying it is you.

**The artifact's clock.** Nothing in the API says when Volendrung will spawn, be revealed or
leave, and the game's own announcements carry no times. So the add-on times the three
announcements it can hear — *seeks a wielder*, *is revealed*, *returns to Oblivion* — and adds
the community's observed figures (UESP, not ZeniMax: revealed 10–15 minutes after spawning, gone
about 30 minutes after that, sooner after four or five changes of hands) as a forecast:

```
Volendrung: seeking a wielder (6:20 ago / revealed in about 4-9 min)
Volendrung: Aldmeri Dominion (revealed 22:10 ago / gone in about 8 min)
Volendrung: returned to Oblivion (1:04:30 ago)
```

Every forecast says *about*, and one that runs out says *any moment* rather than going negative.
When to expect the *next* one cannot be said at all: four or five a day, at no fixed time. The
clock only knows what it was there to see, so an artifact already out when you arrived reads
*time unknown*. While you carry it yourself, the line shows what is left of the hunger meter —
the one lifetime number the client does hand over.

The holdings and scores are the campaign's own numbers — `GetTotalCampaignHoldings` and
`GetCampaignAllianceScore`, the same three calls the client's scoreboard makes
(`campaignscoring_shared.lua:44`). The **under attack** column is not: no API answers "how many
of this alliance's holdings are being fought over", so it is counted off the add-on's own pass.
That column is the reason to have the summary on screen rather than opening the map.

**In an Imperial City campaign the keep columns are dropped.** There are no keeps there, the
campaign is scored on districts, and nothing the keep watch counts can be under attack — three
columns of zeroes are not a summary, they are furniture. What is left is the alliance, whether
it is yours, and how busy it is, which is the part that still means something there. The test is
the client's own `IsImperialCityCampaign`, the same one the world map uses to decide which set
of pins it is drawing. With nothing left to sort on, the alliances keep their own order rather
than shuffling on every refresh.

It degrades one column at a time. Not in a campaign, or the client has not said yet: holdings
fall back to the add-on's own count and the score reads `-`. Outside Cyrodiil, or with the
watch switched off, it takes itself down rather than showing correct scores next to a frozen
under-attack column.

It has its own size, position and **draw order** — in front of everything (the default), normal,
or behind everything — for when the corner you want is a corner something else is already using.
The typeface and outline come from the alert display, so the add-on's two on-screen texts always
match.

```
/pbalert board front | normal | back
```

Those are the ends and the middle of the client's own two draw enums: `DL_OVERLAY`/`DT_HIGH` is
what an overlay uses, `DL_BACKGROUND`/`DT_LOW` is where the housing editor puts its indicators,
and `DL_CONTROLS`/`DT_MEDIUM` is an ordinary interface control. If a client refuses the call the
summary keeps drawing where it was and `/pbalert` says so, rather than letting the setting look
as though it did something.

## The whole of Cyrodiil, in a corner

An overview map, on its own switch, sized and placed like everything else:

- every keep, outpost, town, scroll temple and border keep, in the game's own pin art for its
  owner — so a keep that changes hands changes colour;
- the game's attack burst behind any keep under attack, drawn under the keep as the world map
  draws it;
- the Elder Scrolls and Volendrung where they are — only the ones actually in play, by the same
  three tests the game's own map makes (every place Volendrung *can* spawn is an objective of its
  own, twenty-three of them, each with a valid-looking pin);
- the transitus network: your own alliance's links in the colours the world map uses *at a
  shrine* — green where you can travel now, faint white where you cannot — and everyone else's in
  their owner's colour, faint when nobody holds them, dashed while fighting has cut them
  (`/pbalert map ready off` for owner colours throughout, `/pbalert map links off` to hide them);
- the rest of your group where they are, the leader with the crown — the members the world map
  itself would pin: online and on the current map (`/pbalert map group off`);
- you, as the world map's arrow, turned the way the camera faces — on its own switch and its own
  size, smaller than a keep as on the world map (`/pbalert map player off`).

The farm, mine and lumbermill around each keep are drawn too, on their own switch (`/pbalert
map resources off`): at the world map's own proportion to a keep (27 against 53), and *under* the
keeps rather than over them as the world map has it — at this scale the three sit almost on top
of their keep, and drawn over it they would hide it.

**It does not borrow the game's world map.** A minimap add-on — PB's MiniMap, Votan's — works by
parking the world map on the HUD, and the world map is one control showing one map at one
zoom: a second add-on borrowing it takes it from the first. So this one draws its own map from
the same parts, by map id, without changing what the world map shows:

| | |
| --- | --- |
| `GetCyrodiilMapIndex` → `GetMapIdByIndex` | which map Cyrodiil is |
| `GetMapNumTilesForMapId` / `GetMapTileTextureForMapId` | its tiles, laid out row-major as the world map lays them out |
| `GetUniversallyNormalizedMapInfo` | where any map sits in one shared space |

The last one is what puts the pins in the right place. The pin functions answer in the
coordinates of whatever map the world map has set — Cyrodiil, a city inside it, wherever a
minimap has zoomed to — and the two maps' places in the shared space convert one into the
other. A keep's position, once known, is kept; one that cannot be converted leaves the last good
position standing rather than inventing one, and the arrow is hidden rather than guessed.

**It never reads Tamriel.** Those pin functions answer in terms of the current map, and on a
console whatever the client allocates while an add-on's function is on the stack is billed to the
shared add-on pool — with the world map pulled back to all of Tamriel, one frame of that is
enough to fill it. So they are called only while the HUD is up and has settled, and only while
the current map is Cyrodiil or a map inside it. Otherwise the map keeps what it last drew (keeps
do not move); attack bursts, which depend on no map, stay live; the arrow is hidden.

It shows in Cyrodiil only — the Imperial City is a different map — and only over the game: the
current scene is *read*, never added to, and the map hides whenever a menu is up. Off, or
anywhere else, nothing about it runs.

```
/pbalert map on | off
/pbalert map links on | off
/pbalert map resources on | off
/pbalert map probe
```

`map probe` prints what the map is working with — Cyrodiil's map id, the current one, both maps'
places in the shared space, and the player's position in each. If the pins on a console sit
somewhere other than the keeps, that is the measurement that says why.

## Position

Every surface — the alerts, the summary, the output window, the map — is placed the same way: an
anchor (a corner, an edge's centre, or the middle) and a sideways and an up/down offset from it.
The offsets run the **full width and height of the screen in either direction**, read from
`GuiRoot` because the interface's size depends on the player's UI scale. From any anchor, any
point on the screen can be reached. (They were a fixed ±900 by ±500 before, which left most of a
wide screen out of reach.)

## Colours

Every alert's colour can be set. **The screen uses the chat colours by default**, so there is
one set to keep: recolour an alert for chat and the on-screen line follows it.

They can be split — chat sits on a dark window, the screen sits on whatever you happen to be
looking at, and a shade that reads well on one can vanish on the other. Choosing a colour under
**Colours on screen** is how you ask for that, and doing so switches the following off and says
so; `/pbalert colour follow on` puts them back together without forgetting what you picked.

Twelve shades in the panel's dropdowns, or any hex code at all through the chat command:

```
/pbalert colour lost hud FF00AA
/pbalert colour attack chat red
```

A colour that is neither a name nor six hex digits is refused rather than half-applied — a
malformed one does not fail visibly, it eats the first characters of the line it was meant to
colour.

## The settings

Settings panel (with LibHarvensAddonSettings installed), or `/pbalert`.

| setting | default | |
| --- | --- | --- |
| Watch the campaign map | on | the master switch; off stops the timer entirely |
| Check every | **5 s** | 1–60 s |
| Repeat a standing attack after | **60 s** | 15–600 s — a keep still under attack is said again this long after the last alert about it |
| Keeps and outposts | on | keeps, outposts, scroll temples, border keeps |
| Towns | on | Vlastarus, Cropsford, Bruma… |
| Resources | **off** | farms, mines, lumbermills — flipped constantly, and mostly by one player |
| Imperial City districts | **off** | they change hands too often to be worth an alert |
| Also report fights at enemy holdings | **off** | the offensive half: green when a fight starts at somebody else's holding, blue when it becomes yours |
| Where the add-on speaks | **its own window** | the output window, the chat window, or both |
| Show alerts on screen | **off** | draw alerts over the game as well as printing them in chat |
| Show the campaign on screen | **off** | the standing summary, with its own size and position |
| Only while in an AvA zone | on | outside Cyrodiil the timer is **stopped**, not idling — see below |
| Report attacks already in progress | on | on the first check after you zone in |
| Print the status at login | off | one line saying which build is running and what it watches |

## The chat command

`/pbalert` (or `/pbca`)

```
/pbalert                        what is being watched, and what it has alerted on
/pbalert list                   every holding the client is reporting, with owner and attack state
/pbalert on | off               the master switch
/pbalert every <seconds>        how often to check          (1-60)
/pbalert repeat <seconds>       before a standing attack is said again (15-600)
/pbalert keeps | towns | resources | districts  on | off
/pbalert offense on | off       also report fights at enemy holdings
/pbalert offense ours on | off  only report enemy fights where your siege is up
/pbalert scrolls on | off       report Elder Scrolls being carried
/pbalert log window|chat|both   where the add-on says things
/pbalert log front|normal|back  where the output window sits in the stack
/pbalert log clear              empty the output window
/pbalert hud on | off           the on-screen display
/pbalert hud <alert> on | off   whether that alert appears on screen
/pbalert colour <alert> chat | hud <name or RRGGBB>
/pbalert colour follow on | off whether the screen uses the chat colours
/pbalert board                  print the campaign summary here
/pbalert board on | off         keep it on screen instead
/pbalert test                   show one of each alert, to judge the look
/pbalert ava on | off           check only while in an AvA zone
/pbalert existing on | off      report attacks already in progress when you zone in
/pbalert banner on | off        print the status at login
/pbalert forget                 forget what is being watched and start again
/pbalert reset                  every setting back to default
```

`/pbalert list` is the one to reach for when an alert did not arrive. It says how many holdings
the client reported, how many of them are in the campaign you are standing in, and for each
watched one its owner and whether it is being hit — so you can see whether the client had the
information at all, rather than guess.

## Who is attacking — what the client will and will not say

**There is no "attacking alliance" anywhere in the keep API.** `GetKeepUnderAttack` is a bare
yes/no, and in a three-way campaign a fight at an enemy keep is as likely to be the third
alliance's as yours. So the green line says *a fight has started there* — which is what is
actually known — and never claims your side started it.

The one piece of evidence that bears on it is `GetNumSieges(keepId, bgContext, alliance)`, which
the client's own keep tooltip uses (`keeptooltip.lua:163`) to show each alliance's siege count.
Your alliance having siege standing at a holding it does not own is a push of yours:

```
[Keep] Arrius Keep (Aldmeri Dominion) is under attack -- your alliance has 2 siege standing there.
```

It is evidence, not proof — an attack does not need siege at all — so it is reported as the
count it is rather than rewritten into a claim. It is gated on `DoesKeepTypeHaveSiegeLimit`
exactly as the tooltip gates it, so a resource never carries one.

### Only where your own siege is standing

That siege count is also the closest the client can be made to get to *we are the ones
attacking*, and it is what **Only where your alliance has siege** filters on — **on by
default**. A fight at an enemy holding is reported only once your own alliance has a siege
weapon standing there.

It is a filter on the line, not on the watch: the holding is still tracked, so **taken** is
still reported, and a fight that becomes yours later gets its line the moment your siege goes
up — as a beginning, because for you it is one.

What it costs:

- an attack pressed without siege is never reported;
- nothing is said in the first moments of a push, before the siege goes down;
- holdings the game keeps no siege count for — resources, towns, districts — can never satisfy
  it, so with it on they never report a fight at all.

Turn it off (`/pbalert offense ours off`) and every fight at an enemy holding is reported, which
is the honest superset: something is happening there, and the client will not say whose it is.

Whether that count is live for a keep on the far side of the map is the one thing here that has
to be measured rather than read: `/pbalert list` prints it for every holding, next to the owner
and the attack state. If it is always blank at a keep your alliance is visibly sieging, this
filter cannot work on your client and should be switched off.

## How it works

Five public functions, the same ones the client's own map uses in `esoui/ingame/map/worldmap.lua`
and `esoui/ingame/map/cmaphandlers.lua`:

```lua
GetNumKeeps()
GetKeepKeysByIndex(index)              -- -> keepId, bgContext
GetKeepType(keepId)                    -- -> KEEPTYPE_*
GetKeepAlliance(keepId, bgContext)     -- -> ALLIANCE_*   who owns it
GetKeepUnderAttack(keepId, bgContext)  -- -> bool         the crossed swords
```

All five are reads of state the client already holds. **Nothing is sent, nothing is written,**
and taking the add-on out leaves no trace.

The client reports the same keep twice — once for the campaign you are standing in, once for the
campaign you are homed to. `IsLocalBattlegroundContext(bgContext)` is the client's own test for
"this is the campaign in front of you", and `cmaphandlers.lua` uses exactly it to decide which
keeps to pin; this add-on uses it to decide which keeps to watch. What it alerts on is what the
map in front of you draws.

### Why a timer rather than the event

`EVENT_KEEP_UNDER_ATTACK_CHANGED` exists. A timer was what was asked for, and it is also the
better fit here:

- the interval is a setting, so how noisy the add-on can get is a number you control;
- a poll cannot miss an edge — an event dropped while zoning would leave the state wrong until
  the next one, where the next pass simply sees the truth and corrects itself;
- "still under attack a minute later" is a question about *now*, not about an edge, so it needs
  a timer whatever the first alert came from.

One pass reads a few dozen values already in memory, with no server traffic. The cost of the
choice is latency: at the default five seconds, an alert is at most five seconds late.

### The endings

One entry per holding, created when it first comes under attack and dropped when the attack is
over. Everything the add-on says is a transition of that entry:

```
no entry + mine   + attacked       ->  RED, start watching
entry    + mine   + attacked       ->  RED again, at most once per repeat interval
entry    + mine   + not attacked   ->  BLUE    held
entry    + mine   -> not mine      ->  YELLOW  lost

no entry + theirs + attacked       ->  GREEN, start watching        (offense, optional)
entry    + theirs + attacked       ->  GREEN again, once per repeat interval
entry    + theirs -> mine          ->  BLUE    taken
entry    + theirs + not attacked   ->  dropped, nothing said
```

That last line is the one asymmetry, and it is deliberate: a fight at somebody else's holding
that ends with the holding still theirs has changed nothing about your campaign. Taking it,
on the other hand, usually produces two lines in a row — **taken**, then **under attack**,
because the side that just lost it is already hitting it back.

**Lost is read off the owning alliance, not off the attack flag**, because a keep that has just
been flipped is usually still under attack — your side is already hitting it back. Ownership is
what decides which of the two endings it was.

A holding that is not yours is never watched, so a keep taken back from the enemy and then
besieged is simply a new attack of yours: red again, correctly.

## What it will not do

- **Outside Cyrodiil nothing runs at all.** The zone decides whether the timer exists, not just
  what it does when it fires: `EVENT_PLAYER_ACTIVATED` — which the client sends on every zone
  change — starts it on the way in and stops it on the way out. Most of a session is spent
  outside Cyrodiil, and for all of it this add-on costs nothing. The watch and the summary are
  dropped with the timer, so coming back re-reads reality instead of announcing an ending for a
  fight that finished without you. (`/pbalert ava off` if you would rather it kept trying.)
- **It says nothing when it does not know.** A holding that drops out of the keep list is
  forgotten without an ending, because there is nothing left to report on.
- **The clock on an alert starts when the add-on first saw the attack**, not when the attack
  began. Zone in on a siege already in progress and "3:20 so far" means three minutes twenty of
  watching.
- **Bridges, milegates and scroll gates are never watched.** They are structures inside the
  fight, not holdings that can be owned.
- **It cannot tell you who is attacking, or how many.** Only that the crossed swords are up,
  plus your own alliance's siege count where the game keeps one. See above.

## The files

| | |
| --- | --- |
| `Main.lua` | the watch, the state machine, and everything that decides what to say |
| `Map.lua` | the overview map of Cyrodiil. Optional at runtime like `Hud.lua` |
| `Hud.lua` | all three on-screen surfaces — the alerts, the campaign summary and the output window. Optional at runtime: without it, or on a client where the window cannot be created, every alert still goes to chat and `/pbalert` says so |
| `Settings.lua` | the panel |

## Installing

Copy the `PBsCyrodiilAlert` folder into your `AddOns` folder. `LibHarvensAddonSettings` is
optional — without it there is no settings panel and `/pbalert` does everything.

## Tests

```
lua test/run.lua
```

`test/harness.lua` stubs the part of the client the add-on touches — the keep list with its two
campaign rows per keep, the alliances, the update timer and the clock — so the endings that
cannot be arranged on demand in a real campaign (a siege lasting past the repeat time, a keep
that flips while it is being hit) are played out in milliseconds. It also stubs the window
manager, so what reaches the screen — which lines, in what colours, in what font, anchored
where, and when they expire — and the campaign APIs, so the summary's numbers, ordering,
colours and every way it degrades are checked too. 481 checks.
