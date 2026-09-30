# PB's QuestTrackerFontChanger

Adjusts the fonts of the HUD trackers stacked down the top right of the screen in The Elder
Scrolls Online on console.

- **Author:** PinkBanther
- **Version:** 1.3.0
- **Requires:** `LibHarvensAddonSettings` >= 20106

## What it does

Three trackers, kept separate everywhere — settings, saved variables, chat commands — because
they are different pieces of UI that happen to sit on top of each other, and somebody who wants
a bigger house name usually does not want a bigger quest tracker. On screen they run

```
(dynamic events)
quest tracker
  (zone story)
Golden Pursuits
house information
```

and the settings panel is built in that order, so it reads the same way as the HUD.

Since the HUD tracker rewrite (API 101051) all of them sit in one scrolling column,
`ZO_HUDTrackers`, which the game stacks by priority. 1.3.0 is the version rebuilt for that
client; see [What the HUD tracker rewrite changed](#what-the-hud-tracker-rewrite-changed).

### Quest tracker

The tracked quest in the top right. Three kinds of text, three sizes, because the game gives
them three different fonts:

| | |
| --- | --- |
| **Quest name size** | 10–72. The name at the top of the tracker. |
| **Step description size** | 10–72. The line under the name saying what this stage is about. Not every quest step has one. |
| **Objective size** | 10–72. What you actually have to do, and any counters. |
| **Horizontal / vertical position** | ±1000. A nudge for the **whole tracker column** from wherever the game puts it; 0/0 leaves it alone. |
| **Panel scale** | 50–200%. The quest tracker drawn bigger or smaller, in proportion. |

In gamepad mode the game's own sizes are 27 for the quest name, 22 for the step description
and **34 for the objective lines** — the objectives are drawn *larger* than the quest name.
That is the game's design, not a mistake, and one slider for all three would flatten it. Set
all three to the same number if you want them uniform. In keyboard mode all three are 18.

The position moves the whole column — the game keeps every tracker in it, so they move
together and keep their order. The scale is the quest tracker's alone; the panels under it keep
their size and follow its new height.

### Golden Pursuits

The panel between the quest tracker and the house information, showing the pursuit you are
tracking and a bar for how far along it is. **The same panel is reused for Tamriel Tomes and a
pinned achievement** — it is `ZO_TimedActivityTracker` since the rewrite — so these settings
cover all of them.

| | |
| --- | --- |
| **Heading size** | 10–72. The line next to the icon: "Golden Pursuits", or "Tamriel Tomes". |
| **Pursuit name size** | 10–72. What you are tracking. |
| **Progress size** | 10–72. The numbers inside the progress bar. The bar keeps its size, so a much larger setting spills over it. |

The progress used to be a text line sharing the pursuit name's font. It is now text inside a
`StatusBar` with a font of its own from the bar's platform template (`ZoFontGamepadBold27` /
`ZoFontWinH4`), so it gets its own slider.

### House tracker

The panel under the quest tracker while you are in a house — yours, or someone else's on a
home tour. It carries the house name, its nickname and owner, how many people are inside, and
the House Tours tags.

| | |
| --- | --- |
| **House name size** | 10–72. The name at the top of the panel. |
| **House details size** | 10–72. Everything under it: nickname and owner, visitor count, tags. |

Two sliders rather than four, because the game gives the house name one font and all three
lines under it the same second font — three identical sliders would only be three ways to make
them disagree. The Golden Pursuits panel is split the same way, for the same reason.

### Line spacing follows the text

The gaps between the rows are **not** part of the font. They are separate numbers the game
sets alongside it, and they do not move when the font does — so shrinking the text on its own
would just leave the rows floating apart, and enlarging it would run them together. Every gap
is therefore scaled by the same ratio as the text it sits above, automatically. There is no
setting for it: at the game's own size the ratio is 1 and nothing is touched.

Which text a gap follows is the game's own answer, not a guess. An offset positions the top of
a row against the bottom of the row before it, so it belongs to the row it places — the gap
under the quest name is the step description's, and it follows the **step description** size.
Shrinking only the quest name therefore does not close that gap; shrinking the step description
does.

### In every section

| | |
| --- | --- |
| **Typeface** | The game's own faces, offered as aliases (`$(GAMEPAD_MEDIUM_FONT)` and friends) rather than resolved paths, so the client keeps picking a face that can draw the current language. |
| **Outline** | The descriptor style tokens the client's own font definitions use. |

Each slider **starts at the size the game itself draws that part at**, measured off a real
label rather than assumed — see [Sizes are measured, not assumed](#sizes-are-measured-not-assumed).
So an install that has not been touched looks exactly like no add-on at all, and it is not
just that it looks that way: while every setting in a section still matches the game's own,
the add-on never calls `SetFont` there and the client never builds a font.

Sizes are stored **per mode**. Gamepad and keyboard start from different numbers, so one
shared value would be wrong in whichever mode it was not chosen in. On console only the
gamepad set is ever used.

### Typefaces

The same list as PB's NamePlateChanger, for the same reasons. Only faces the console UI
**already has loaded** are offered: any other has to be built when it is set, and that build
is billed to the 100 MB pool every console add-on shares — measured on PS5, it crashes the
add-on.

| Setting | Alias | Western | Japanese |
| --- | --- | --- | --- |
| Console (medium) | `$(GAMEPAD_MEDIUM_FONT)` | FTN57 | FTN57 for Latin; Japanese falls back to the gothic |
| Console (bold) | `$(GAMEPAD_BOLD_FONT)` | FTN87 | FTN87 for Latin; Japanese falls back to the gothic |
| Console (light) | `$(GAMEPAD_LIGHT_FONT)` | FTN47 | ESO_FWNTLGUDC70-DB |
| Interface (medium) | `$(MEDIUM_FONT)` | Univers57 | ESO_FWNTLGUDC70-DB |
| Interface (bold) | `$(BOLD_FONT)` | Univers67 | ESO_FWNTLGUDC70-DB |

**Default** is not one face: it keeps whatever the game picked for each part separately, which
in gamepad mode means a bold name over medium text under it. Picking a face here deliberately
collapses that distinction onto one face.

**Not offered**, because they were measured to crash on PS5: `$(CHAT_FONT)`,
`$(ANTIQUE_FONT)`, `$(HANDWRITTEN_FONT)`, `$(STONE_TABLET_FONT)`. A saved setting pointing at
one of them is dropped back to Default on load, in every section — the list of offered faces
is the authority, so removing one is always enough to stop it being used.

### Outlines

A `LabelControl`'s `SetFont` parses the style out of the descriptor string as a **token**, not
as a `FONT_STYLE_*` number the way the nameplate API did — and the tokens are not the enum
names lowercased either (`FONT_STYLE_OUTLINE_THICK` is written `thick-outline`). Only the four
tokens the client's own font definitions use are offered: `shadow`, `soft-shadow-thin`,
`soft-shadow-thick`, `thick-outline`. `FONT_STYLE_OUTLINE` and `FONT_STYLE_OUTLINE_SHADOW`
exist as enum values with no token anywhere in the client source, so they are left out until
one is measured — a font that fails to build is not a good surprise on console.

**Outline styles are the expensive setting.** The client has to generate outline glyphs, and
the game's own source puts that at about 100 MB for a CJK font — the same size as the whole
pool console add-ons share. If the game becomes unstable, put this back to Default.

## Why this can do more than PB's NamePlateChanger

The overhead nametag is drawn by the engine: an add-on can only hand the client a font
descriptor through a client setting, that setting outlives the session, and changing the face
reloads the UI.

Every tracker here is the opposite. They are ordinary Lua UI —
`esoui/ingame/zo_quest/questtracker.lua`,
`esoui/ingame/timedactivities/timedactivitytracker.lua` and
`esoui/ingame/housingeditor/houseinformationtracker.lua` build them out of `LabelControl`s,
and a `LabelControl` takes `SetFont(descriptor)` directly. So:

- **no interface reload**, whatever the face is changed to,
- **nothing outlives the session**: uninstalling the add-on is enough to undo it, and there is
  no captured "original" to keep safe,
- **no write budget and no reload loop** to defend against, because nothing here is a client
  setting that could be written back at us.

The full evidence is in [FINDINGS.md](FINDINGS.md).

## How it hooks in

The rule this is built around, measured on PS5 in another PB's add-on: anything the client
creates while an add-on frame is on the stack is untrusted for good, and nothing breaks until
one of those poisoned closures reaches a restricted function — possibly in a feature the add-on
never touched. So the client's code is only ever run under this add-on where it can build
nothing.

**Quest tracker — the pools.** `ApplyPlatformStyleToHeader` / `...ToCondition` /
`...ToStepDescription` are file-local in `questtracker.lua` — but they are installed on the label
pools with `SetCustomAcquireBehavior`, and `pool.customAcquireBehavior` is a plain field. The
wrapper around it calls the game's function first and styles on top, so every label is ours from
the moment it is acquired, including the ones the tracker rebuilds by itself when a quest step
advances. What it runs is `SetFont`, `SetDimensions` and anchors — nothing that builds.
`UpdateTreeView` is wrapped the same way, for the spacing, and only lays out anchors.

**Golden Pursuits and the house panel — no hook at all.** Both are `ZO_HUDTracker_Base`
subclasses whose fonts are only ever set by their own `ApplyPlatformStyle`. That method is not
safe to run under an add-on frame any more — the rewritten Golden Pursuits panel re-applies its
keybind button's platform template inside it — so it is neither wrapped nor called. The client
runs it at exactly two moments, `EVENT_ADD_ONS_LOADED` and a keyboard/gamepad switch, and each is
followed by an event this add-on already listens for (`EVENT_PLAYER_ACTIVATED`,
`EVENT_GAMEPAD_PREFERRED_MODE_CHANGED`). The labels are written directly then, and whenever a
setting changes.

**Handing a label back** is a direct write too: the game's own font is read from the tracker's
own style table (`tracker.styles.gamepad.FONT_GENERAL` and friends — the tables the tracker
itself reads) and set on the label. Nothing asks the tracker to restyle itself, so a change to
that method's signature can no longer break "off" — which is exactly how 1.2.0 broke.

### Sizes are measured, not assumed

The game names its fonts `ZoFontGamepadBold27`, and `esoui/fontdefs/` defines that as
`$(GAMEPAD_BOLD_FONT)|$(GP_27)|soft-shadow-thick`. `$(GP_27)` is 27 **after the client's own
resolution scaling**, which an add-on cannot compute. Writing 27 back would therefore not be
"the same size", it would be a size change nobody asked for.

A label is measured only while it carries the game's own font — straight after the pool's own
styling for the quest tracker, and straight after being handed back for the two panels — so
`control:GetFontSize()` there is the client's real number for that part. That is what the
sliders start from, and it is stored in saved variables so the panel knows it before you are
anywhere near a quest or a house.

It is read once per part per session, and the label is checked before it is believed: the game
always styles with a *named* font (`ZoFontGamepadBold27`) and this add-on always writes a
descriptor, which by construction contains a `|`. A label carrying a pipe is one of ours and is
refused. Reading one of our own fonts back would make it the new "default" and the client's
real number would be gone for good — that is the mistake PB's NamePlateChanger had to grow a
repair path for, and here it is a string test rather than a load-order assumption.

Until a label has been seen, the sliders fall back to the numbers in the font names (27 / 22 /
34 for the quest tracker, 27 / 34 / 27 for Golden Pursuits, 27 / 34 for the house panel, and 18
for everything in keyboard mode).

### Moving the column

Since the rewrite, `HUD_TRACKER_MANAGER:RefreshLayout()` re-parents and re-anchors every tracker
inside the column — `ClearAnchors`, `SetParent`, `SetAnchor` — on every fragment show and hide,
every activation and every HUD setting change. An anchor written on a tracker does not survive a
second. That is why 1.2.0's position setting stopped working.

The column itself is a different matter. `ZO_HUDTrackers` is registered with `HUD_MANAGER` as a
HUD element, and the only thing that ever places it is `ZO_HUDManager_Element`'s
`RevertOffsetModifications()` — `GetSavedAnchor():Set(control)` — run from
`HUD_MANAGER:PropagateSettings()` at start-up, on a keyboard/gamepad switch and on a screen
resize. On console `GetSavedAnchor()` does not even look at saved offsets:

```lua
--TODO Custom HUD: Remove this check once we build the gamepad editor
if ZO_IsConsoleOrGameCoreUI() then
    return self.defaultAnchor
end
```

So on a PS5 the column is placed by exactly one object, `element.defaultAnchor`, every time.
This add-on changes that `ZO_Anchor`'s offsets in place, and the game's own placement then puts
the column where the player asked, whenever it runs. The anchor is prepared at
`EVENT_ADD_ON_LOADED`, before `HUD_MANAGER` first places anything, so at start-up the game does
the moving itself.

- **Nothing is wrapped** and **nothing is written to the game's saved variables** — the HUD
  editor's saved offsets are deliberately left alone. Removing the add-on is a complete undo at
  the next load.
- It is changed **in place** rather than replaced, because the tracker manager asks
  `IsUsingDefaultAnchor()` — which compares the object — to decide how far down the screen the
  column may reach.
- The position is stored as a **nudge** from the game's own offsets, captured the first time and
  remembered with the same "is it still what we wrote?" test the spacing uses, so re-applying
  never accumulates.
- On **PC**, the keyboard **Edit HUD (Beta)** screen writes saved offsets, and `GetSavedAnchor()`
  prefers them when they exist. That is the right precedence: the game's own editor wins, and
  this setting applies when it has not been used. On console there is no HUD editor at all —
  `hud_editor_keyboard` is keyboard-only — which is what makes this setting worth having.

The column's bottom is tied to the screen (or to the gamepad chat), and what does not fit
scrolls. Moving it down therefore leaves less of it on screen at once.

### Scaling the quest tracker

`RefreshLayout` never calls `SetScale` on a tracker, so a scale written on
`FOCUSED_QUEST_TRACKER.control` stays written. It is the quest tracker's alone; the trackers
under it are anchored to its bottom and follow its new height. Scale is free — it makes the
client build nothing, so it costs nothing on console, which makes it the cheap way to make the
tracker bigger if the memory warnings above are a worry.

Every call that places or scales — `RevertOffsetModifications`, `SetScale` — goes through a
deferred, isolated tick, so if the client ever refuses one it takes the position with it and
leaves the fonts, the spacing and the settings panel standing.

### Where the spacing numbers live

Two different places, which is why this is done in two places:

- **Quest tracker** — `ZO_TreeControlNode`'s `m_OffsetY`, set from
  `QUEST_TRACKER_TREE_LINE_SPACING` right after each node is created. Scaled in a wrapper
  around `UpdateTreeView`, which is both the first moment every node is present and the last
  moment before the tree is laid out with them.
- **Golden Pursuits and the house panel** — the `offsetY` on the `ZO_Anchor` objects in the
  platform style table, re-applied to the labels by the panel's own `RefreshAnchors` (which only
  clears and re-adds anchors). Scaled just before that call, each gap by the row it places —
  the gap above the progress bar follows the progress size. Only the anchors that place one row
  against another are touched; `CONTAINER_*` and `HEADER_*` place the panel's contents in it and
  are left alone.

Neither number is hardcoded — both are read back from the node and the anchor. And neither is
allowed to compound: the quest header's node is written once and never reset by the game, and
the style table's anchors live for the whole session, so a naive rescale on every update would
multiply the gap again and again. The same test the fonts use applies here — if the current
value is not what we last wrote, the game wrote it and it is the base.

### The quest name box

The gamepad quest name is the one control in any of the three that is given a fixed height
(`QUEST_HEADER_BASE_HEIGHT = 28`); every other label — both HUD panels included — is left
unconstrained and sizes itself to its text. Since the quest tree stacks nodes by anchoring each
control's top to the previous one's bottom, a larger quest name would be clipped and the step
description would be drawn over it. The box is grown in the same proportion as the font. Only
grown — the game's own box has headroom, and shrinking it would pull the rest of the tracker up
into it.

## What the HUD tracker rewrite changed

The update that shipped API 101051 rebuilt every tracker in the top right. For this add-on:

| | 1.2.0 | 1.3.0 |
| --- | --- | --- |
| Position | Anchored `FOCUSED_QUEST_TRACKER.trackerPanel`, which no longer exists — the setting silently did nothing, and a tracker's own anchor would be wiped by `RefreshLayout` anyway | Moves the whole column through its HUD element's `defaultAnchor` |
| Smaller / off | Called `ApplyPlatformStyle()` with no style, which the rewrite made an error — bigger still worked through the pool hook, smaller and off silently did not | Writes the game's font back directly, read from the tracker's style table |
| Golden Pursuits progress | Pointed at `progressLabel`, which became a `StatusBar` | Its own role, on the bar's `Progress` label |
| Golden Pursuits / house | Wrapped `ApplyPlatformStyle` | No hook; written directly from events |

`PROMOTIONAL_EVENT_TRACKER` still resolves — the client aliases it to `TIMED_ACTIVITY_TRACKER`
— but the add-on looks for the new name first.

## What it does not touch

- **The quest timer** (the countdown above the tracker on timed quests) has its own controls
  and its own fonts, and is left alone.
- **The order and wording of the lines** in any of them, which are built from journal, pursuit
  and housing data.
- **Whether any of them is shown at all**, which is the game's own setting under
  Settings > Interface.
- **The other HUD panels** in the same column — zone story, endless dungeon, adventure zone,
  dynamic events. They would each hook exactly like Golden Pursuits does.

## Settings

Settings → Add-On Settings → PB's QuestTrackerFontChanger. The panel is split into a
**Quest tracker**, **Golden Pursuits** and **House tracker** section — in the order they appear
on screen — each with its own switch, sliders, typeface and outline, and a single Reset at the
bottom for all three.

Chat commands:

```
/pbquest                        this list
/pbquest status                 settings, and the font actually on screen
/pbquest quest <n>              all three quest tracker sizes
/pbquest quest <part> <n>       one part: name | step | goal
/pbquest pursuit <n>            every Golden Pursuits size
/pbquest pursuit <part> <n>     one part: name | detail | progress
/pbquest house <n>              both house tracker sizes
/pbquest house <part> <n>       one part: name | detail
/pbquest size <n>               every size in every tracker
/pbquest pos <x> <y>            nudge the tracker column from where the game puts it
/pbquest pos reset              put it back
/pbquest scale <50-200>         draw the whole quest tracker bigger or smaller
/pbquest on | off               every section
/pbquest <section> on | off     one section: quest | pursuit | house
/pbquest reset                  back to the game's own fonts and layout
```

`/pbqt` is the same command.

`status` prints what is on screen read back off a live label, so it says what the client is
really drawing rather than what the add-on believes it asked for. The quest lines need a quest
to be tracked to have a label to read; the Golden Pursuits and house lines are readable
anywhere, but only show on screen when there is a pursuit tracked or you are inside a house.

## Tests

The add-on runs on a console, where one real test costs a session: build, upload, boot the
PS5, log in. `test/harness.lua` stubs the part of the client the add-on actually touches, in the
shape the HUD tracker rewrite gave it — the `ZO_HUDTrackers` column and its two `HUD_MANAGER`
elements (with the console's "ignore saved offsets" check), the quest tracker's three control
pools, both HUD panels with their style tables and the progress bar, a `LabelControl` that
parses `face|size|style`, saved variables and LibHarvensAddonSettings — so the logic can be
exercised on a desktop first. It loads the add-on in the client's own order (`EVENT_ADD_ON_LOADED`,
then `EVENT_ADD_ONS_LOADED`, then activation).

```
lua test/run.lua
```

The stub scales gamepad font sizes by 0.75, the way the client scales `$(GP_27)`. A build that
wrote the raw font-definition number back instead of the measured size passes against a 1:1
stub and changes the text on a real client, so the stub refuses to be 1:1.

It is also unforgiving about what broke 1.2.0: there is no `trackerPanel`, `ApplyPlatformStyle`
raises without a style, and every client restyle is counted, so the suite proves the add-on
never runs one itself.

## Licence

This Add-On is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls© and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
