# PB's ChatWindowCustomizer

Moves and resizes the chat window on the HUD, changes the size of the text in it, keeps it on
screen instead of fading away, and decides what it is drawn over, in The Elder Scrolls Online on
console.

- **Author:** PinkBanther
- **Version:** 1.3.1
- **Optional:** `LibHarvensAddonSettings` >= 20106 (for the settings panel; the chat commands
  work without it)

## What it does

The game puts the console chat window in the bottom right of the screen at one fixed size —
490 × 280, 215 up from the bottom — and the only related option is the text size, which is
Small / Medium / Large. This add-on makes all of that adjustable:

| | |
| --- | --- |
| **Measured from** | Which corner of the screen the position is measured from: top left, top right, bottom left, bottom right. |
| **Distance from the side** | How far the window is from the left or right edge. |
| **Distance from the top or bottom** | How far the window is from the top or bottom edge. |
| **Width** | 200 up to the width of the screen. The game's own limit is 300–550. |
| **Height** | 100 up to the height of the screen. The game's own limit is 170–380. |
| **Message text size** | 10–48. |
| **Keep the window on screen** | Off by default. On, the window does not minimise after 20 seconds. |
| **Show it in menus too** | Off by default. On, the window stays up in menus, not only on the HUD. |
| **Drawn** | Behind the interface / normal (the game's own) / in front of the interface. |
| **Order within that layer** | 0–200. The game gives the chat 30. |

Every setting starts at the game's own value, read off the real chat window rather than assumed,
and **nothing is changed until you move something**. Installed and left alone, the add-on is
indistinguishable from not having it.

### The corner decides which way the window grows

The window is held by the same corner of itself that its position is measured from. From the
bottom right — the game's own choice, and the default — a taller window grows **upwards** and
the input line stays exactly where it was; a wider one grows to the left. Anchored top left, it
grows down and to the right.

Changing the corner does **not** move the window: the current position is re-expressed from the
new corner, so the sliders change their numbers and the window stays put.

### Preview

The chat is only drawn on the HUD, so it cannot be seen from the settings menu. While this
add-on's panel is open, a **pink frame** is drawn where the window will be, with the input line
marked and a few lines of sample chat in the chosen text size. It follows every slider as you
move it, and goes away when you leave the panel. It can be switched off in the panel.

`/pbchatwin preview` shows the same frame anywhere — on the HUD it sits on top of the real chat,
which is the quickest way to check the two agree.

### Text size

The slider starts at the size the game draws the chat at for your Small / Medium / Large
setting. That is **measured**, not taken from the setting's number: the game writes the size as
`$(GP_20)`, and on the Japanese client `GP_20` is 15. Once you move the slider, its size is used
instead of the game's setting. Change the game's setting afterwards and the add-on puts your size
back the next time the HUD comes up.

Only the **messages** change size. The input line keeps the game's size, because its box is a
fixed 30 high and larger text would be cut off.

### Keeping the window on screen

The console chat minimises itself 20 seconds after the last message: the messages go and the
background fades to nothing until something new arrives. **Keep the window on screen** stops
that, for as long as you are on the HUD.

The **input line is not affected** — it still appears only when you start typing, which is what
the game does. Switching the option off hands the window back to the game's own 20-second timer
rather than minimising it here, so it disappears the way it always did.

A menu still minimises the chat, because the game does that itself through
`MINIMIZE_CHAT_FRAGMENT`; the window is back up by the time the HUD is.

### Menus

The game draws the chat on the HUD and nowhere else: open the map, the inventory or any menu and
the window goes away. **Show it in menus too** keeps it on screen there, for reading chat while
you are in a menu.

- It is still not somewhere you can type from a menu — input there belongs to the menu.
- **Keep the window on screen** comes on with it: a window that appeared in a menu and then faded
  out twenty seconds later would be worse than either behaviour on its own.
- If a menu covers the window, set **Drawn** to in front of the interface.
- Nothing is forced while you have the chat switched off under Settings > Social. That setting is
  the game's answer to whether the window should be there at all.

### Draw order

A top-level window is drawn by tier first, then by level within it. The game draws the chat at
**MEDIUM / 30**: over the HUD, under the client's keybind strips, tooltips and announcements. So

| | |
| --- | --- |
| **Behind the interface** | Under the rest of the UI — anything overlapping wins. |
| **Normal** | The game's own. |
| **In front of the interface** | Over almost everything. Pick this if something covers the chat. |

**Order within that layer** only matters against things in the same tier: higher goes on top. For
reference, at the game's normal tier the keybind strip is 10 and a dialog 20; in front, tooltips
are 140 and alerts 145.

## Chat commands

```
/pbchatwin                     this list
/pbchatwin status              settings, and what the chat window really has on screen
/pbchatwin pos <x> <y>         distances from the corner
/pbchatwin corner tl|tr|bl|br  which corner (keeps the window where it is)
/pbchatwin size <w> <h>        width and height
/pbchatwin font <n>            message text size (10-48)
/pbchatwin always on | off     keep the window on screen, or hand it back to the game
/pbchatwin menus on | off      show it in menus too, not only on the HUD
/pbchatwin tier low|medium|high  draw it under or over the rest of the UI
/pbchatwin level <n>           order within that tier (0-200)
/pbchatwin on | off            switch every change on or off
/pbchatwin preview             show or hide the preview frame
/pbchatwin reset [pos|font|draw]  back to the game's own
```

`/pbcw` is the same command.

## How it works

Nothing in the chat is hooked, wrapped or called. The add-on only **writes to controls and
fields**, and lets the chat carry on running its own code:

- **Position and size** are the anchor and dimensions of the chat's top-level control,
  `ZO_GamepadTextChat`. The message area is anchored to its top left and the input line to its
  bottom, so moving and resizing it moves and resizes the whole chat — the same call the game
  makes in `GamepadChatContainer:LoadSettings`.
- **The size limits** are four plain fields on `GAMEPAD_CHAT_SYSTEM` that the game turns into
  `SetDimensionConstraints` whenever it lays out its tabs. They are widened as data, and the
  constraints set to match.
- **The text** is the font on each chat tab's `TextBuffer`, in the same `face|size|style` form
  the game builds in `GetChatFontFormatString`, with a number where the game has `$(GP_n)`.
- **The draw order** is `SetDrawTier` / `SetDrawLevel` on that same control.
- **Showing it in menus** is `SetHidden(false)` on the control, written after the client's own
  `RefreshVisibility` has hidden it — on the HUD fragment's state change, on a scene change, and
  once more a frame later, because the fragment that minimises the chat belongs to the same
  transition and nothing says which of the two runs first.
- **Keeping the window up** is the one place a chat function is called:
  `ZO_GamepadChatSystem:StartVisibilityTimer`, whose whole body is
  `g_expirationTime = GetFrameTimeSeconds() + 20`. It writes a number, creates no closure and
  touches no screen. Pushed every ten seconds while the option is on, which is what stops the
  client's own `Minimize` ever running; the message area and the background's alpha are plain
  control writes that undo a minimise that already happened. Switching the option off calls
  `RefreshVisibility`, whose whole body is `control:SetHidden(self:IsHidden())`, so the window
  goes back where the client's own rules say it belongs rather than where this add-on guesses.

The chat is where every message the player sends goes through the client's own code, and an
add-on frame near that code is how private-function errors start — see FINDINGS.md.

The game's own anchor, size and limits are read off the control before the first write of each
session. Reset, the on/off switch, and a slider moved back to the default all put exactly those
back.

## Update 51 and the customizable HUD

U51 registers the chat window with the game's new HUD manager. From then on the client puts HUD
elements back by itself — `PropagateSettings` → `RevertOffsetModifications` — whenever the screen
is resized, the input mode changes, or add-ons finish loading. On console it always puts back the
*game's* placement, because the gamepad HUD editor does not exist yet.

That is why a wayshrine or a dungeon left the window wrong until a menu was opened, which is when
this add-on re-applied. From 1.3.0:

- the player's corner and distances are written into the HUD element's own default anchor, so the
  client's re-applies put the window where the player asked. The element still counts as "using
  its default anchor", which is what makes the U51 tracker column keep stacking above the chat;
- the window is **corrected the moment it changes**, not on a timer: a named `OnRectChanged`
  handler on the chat control (the engine's own notice that its rectangle changed, raised when the
  layout is resolved, ahead of the frame being drawn) and a named `OnEffectivelyShown` handler (the
  moment it actually appears) check the window against what was asked and put it right. Named
  handlers sit beside the control's own rather than replacing them, the way the client itself
  registers them. They are added only once something has been written and taken off on reset;
- the same check runs as the HUD comes in (`SHOWING`, before its first frame), and as a backstop
  on a timer after a zone load, screen resize or mode change (50 ms to 10 s);
- anything found out of place is recorded, and `/pbchatwin status` prints the last few — what the
  window had, which of the checks found it, and how long after the zone load — along with how
  many times the window reported a change and how many were corrected.

Reset puts the element's own anchor back exactly as the client had it.

## What it does not touch

- **The input line's text size** — see above.
- **The input line's visibility** — the game hides its box and channel name while the chat is
  minimised, and that is left alone: a permanently visible input line reads as though you were
  typing.
- **Whether the chat is shown on the HUD** — the game's setting under Settings > Social. The
  add-on can read it but `SetSetting` is private.
- **The keyboard chat** on PC, which already has its own move, resize and text size.
- **The chat menu, the channels, the messages themselves.**

## Tests

```
lua test/run.lua
```

from the add-on folder, with any Lua 5.1 or later. `test/harness.lua` stubs the gamepad chat —
its control, its tab buffers, and its own `LoadSettings`, `SetFontSize` and
`CalculateConstraints` — with a label that resolves `$(GP_n)` the way the Japanese client does,
so a build that wrote the setting's number back as a size would fail.

## Licence

This Add-On is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
