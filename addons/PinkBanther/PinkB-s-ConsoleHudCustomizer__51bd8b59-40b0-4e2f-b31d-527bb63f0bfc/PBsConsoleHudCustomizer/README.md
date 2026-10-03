# PB's ConsoleHudCustomizer

Moves and resizes the health, magicka, stamina and skill bars on the HUD, can draw the resource
bars as plain rectangles, shows the weapon set you are not on, and marks how long is left on each ability --
as a shade that clears down the icon, a countdown, and a target count -- in The Elder Scrolls
Online on console.

- **Author:** PinkBanther
- **Version:** 1.13.0
- **Optional:** `LibHarvensAddonSettings` >= 20106 (for the settings panel; the chat commands work
  without it)

## What it does

The game pins the three resource bars and the skill bar to the bottom of the screen at one fixed
size, and offers no setting for any of it. This add-on gives each of the four three of its own:

| | |
| --- | --- |
| **Sideways** | How far the middle of the bar is from the middle of the screen. 0 is dead centre, negative left, positive right. |
| **Height** | How far the middle of the bar is up from the bottom edge. The game's own bars sit 137 up. |
| **Size** | 50% to 200% of the game's own size. Frame, background, bar and numbers all together. |

The four are independent, so health can sit in the middle of the screen with magicka and stamina
low in the corners, the skill bar higher up, or the whole lot moved out of the way of a minimap.

Every setting starts at the game's own value, **measured off the real bars** rather than assumed,
and nothing is changed until you move something. Installed and left alone, the add-on is
indistinguishable from not having it.

### Size is one number, on purpose

The bar's width is not the add-on's to keep. The game stretches a bar to 323 wide, or shrinks it
to 141, every time a buff or debuff moves one of your maximums — food, Undaunted Mettle, a
debuff — and animates it there. A width written by an add-on would survive until your next meal.

So "size" is a scale: 100% is the game's own, and everything in the bar grows and shrinks in
proportion, which is also the only way the arrow-shaped frame ends stay the right shape. The bar
keeps the position of its **middle**, so it grows evenly both ways and stays where you put it —
including when the game stretches it for a buff.

### The small bars follow

The werewolf bar lives under magicka, mount stamina under stamina and siege health under health.
Each one is anchored to its partner in the game's own XML, so it moves with it, and this add-on
gives it the same size so the pair still lines up.

### A plain look for the resource bars

**Bar style** switches the three resource bars between:

- **Standard** — the game's own bars, untouched. Nothing is built and nothing runs.
- **Square** — each bar as a flat rectangle: a dark track, and a solid block in that power's own
  colour, with the game's own resource numbers lifted over it.
- **Liquid** — keeps the game's own frame, background and gloss, and makes the fill read as a
  liquid, the way Diablo's orbs do: the
  lower part sinks into shadow, soft light and dark currents drift through it, a glow at the
  moving end swells when the amount changes and settles again, what was just lost stays a moment
  as a pale trace and drains away, bubbles rise, and a reflection runs along the top of the glass
  with a glint crossing it. There is no line at the moving end, and its glow is gone before the
  moving end reaches the full end, so nothing flickers at the point while a bar regenerates.
  Select it with `/pbhud style liquid`.
- **Crystal** — the same, as a cut crystal: the fill lifted towards white, faceted planes along
  the bar lit from alternating corners and catching the light in turn, darker planes below a bright
  girdle line, and small sparkles that twinkle and move on. Select it with `/pbhud style crystal`.

  Both are as solid as the game's own bars; **How solid** (the opacity slider) makes the whole bar
  see-through -- the game's background, frame and fill, and every effect over them.

  Both are drawn to the frame's own shape: the effects fill the triangular points at the ends and
  follow the same point at the fill's moving end, without crossing either. Everything is untextured
  rectangles with per-corner colours -- no art -- cut into rows where a slope has to be followed,
  from a pool per bar section that is built once and reused, updated every 50ms while the style is
  active and the HUD is shown. Coming back from a menu the bars fade in as the game does it, and the
  effect appears as the fade ends. `/pbhud plain` prints each bar's band, moving end and piece count, and where the game's own fill and
  frame pieces sit inside their container; `/pbhud plain margin <left> <right>` pulls the effect in
  from each end by a pixel or two, for a fill whose art ends before its control does.
  `lua test/preview_liquid.lua out.html [liquidflow|crystal]` renders five seconds of either from
  the add-on's own writes, to judge the look without a console.

  They make no garbage while they run and build a fixed pool of 110 pieces per bar section when
  chosen, so memory is flat from then on. `lua test/memory.lua` measures every style's garbage per
  update, memory kept over a long run, controls built after warm-up, and a long fight on a stream of
  new targets.
- **MURA-HIGE NEO Style** — uses the same width and height settings as MURA-HIGE Style,
  with health, magicka and stamina all filling from left to right. Health is one continuous bar.
- **MURA-HIGE Style** — the same rectangle, drawn at a **width and a height in pixels**: the two
  extra sliders in each bar's section, live only in this style. Choosing it is enough — the bars
  are drawn at the game's own size until you change one. The percentage slider is greyed out here,
  and the pixel ones are greyed out in the other styles; the skill bar is scaled either way. The game's arrow-shaped frame and background are put away while this is chosen, and come
  straight back when it is not. **How solid** takes the rectangles from fully opaque down to
  letting the game's own fill show through, and **Draw an outline** puts a thin line round
  each bar — the game's arrow-shaped frame is always put away while one of these styles is on, so
  that line is the only frame on offer.

The bars themselves are left alone and still doing their work, so the damage shield overlay, the
armour and possession effects, the low-health warning and the out-of-combat fade all still happen
on top. Nothing is drawn from an art file — the rectangles are backdrops, which are a colour and
nothing else.

> The liquid style of 1.3.x is gone: it never drew anything on a console. If you had chosen it,
> you now have this one.

### A shade over a skill while its effect runs

While an ability's effect is running, its icon is shaded over, and the shade is **wiped away down
the icon** as the time runs out, so how much is left can be seen without reading the number. It
runs on both weapon sets.

The sweep is the game's own `Cooldown` control — the same machinery as an ability cooldown — given
the effect's real length, so it is always exactly as long as the effect and costs nothing per
frame. How dark it is, whether the moving edge is lit, and which way it clears are all settings.

### Leaving the skill bar alone

**Let this add-on touch the skill bar**, at the top of the skill bar's section, hands the whole
bar back to the game and to any other add-on that lays it out. Its position and size, the spacing
along it, the other weapon set's row, the countdown and target count on the icons and the shade
over a skill in use are all put back and stay off — including the watch that would otherwise put
them back. Your settings are kept for when you turn it on again, and the health, magicka and
stamina bars are not affected.

### Spacing along the skill bar

The game leaves a lot of room around the ultimate and the item. Three sliders close it up:

| | the game's |
| --- | --- |
| **Between the abilities** | 10 |
| **Before the ultimate** | 65 — what makes it sit out on its own |
| **Before the item** | the whole width of the weapon swap marker, plus 15 |

That last one is the big one. On console the weapon swap marker is never drawn, but it is still a
control sitting between the quickslot and the first ability, with the quickslot anchored to its
far side. This add-on anchors the item to the first ability directly, so the number you set is the
gap you see. While a companion is out, its ultimate joins that side of the row and takes the same
gap.

The first ability does not move — it is what the rest of the row hangs off — so the bar closes up
towards it. Re-centre it with the skill bar's own position slider if you want it dead centre.

### The weapon set you are not on

With **Show the other weapon set** on, a row of that set's abilities is drawn above the skill bar,
in the game's own back row frame. It follows the skill bar wherever you put it, swaps over when
you swap weapons, and has its own size and gap.

The game has a row of its own (Settings > Interface, *Action Bar Timers* and *Back Row*), but it
only appears for a slot whose effect is still running and disappears again when it ends. This one
is always there, so both sets can be read at a glance. If you want only this one, turn the game's
Back Row setting off.

**The row follows your display setting, even while weapon swapping is temporarily locked.**
The Oakensoul Ring is an exception: equipping it in either ring slot hides the row; removing
it restores your saved display choice without changing that setting. It inherits
visibility from the action bar rather than individual front slots, so hiding a front slot cannot
hide its back slot. Special hotbars without an opposite weapon set still hide the row.

### Countdown and target count

On **both** sets, each icon can carry:

| | |
| --- | --- |
| **Countdown** | How long is left on that ability's effect. Gold, at the bottom of the icon. A minute or more reads as `1m`, the last ten seconds as `9.4` (optional). |
| **Target count** | How many targets are under the effect. White, in the top corner. From one target, or from two if you would rather a single-target ability did not carry a 1. |

Each has its own text size, 12 to 48, **per bar**: the countdown and the target count on the bar
you are on, and the countdown and the target count on the other set's row. The row's icons are
smaller than the bar's, so a smaller number often reads better there.

Until you move one of the row's two sliders it **follows the bar's**, so one size for both stays
one slider. **Match the other set to this bar** puts it back to following.

The countdown starts at the player's cast (placement for aimed ground abilities).
For **channeled abilities**, `GetAbilityCastInfo` supplies the channel time; effect notifications
cannot replace it with a passive buff's duration. Ordinary cast time is not treated as effect
duration. For **ordinary lasting abilities**, `GetAbilityDuration` supplies the initial duration.
An effect can refine that duration only when its ability ID, normalized name or icon matches
and its duration is within the allowed tolerance. Matching is heuristic, not proof of causality.

If the ability duration is unknown, only an effect with an ID, name or icon match is accepted;
the longest effect after a press is no longer used as a guess. If no match arrives, the countdown
stays hidden, including when the client's slot timer reports a passive. Known channels with no
reported channel time also stay hidden. No per-ability duration or effect-ID table is used.
Effects whose ID, name and icon all differ from the skill may therefore have no countdown when
the skill itself reports no duration.

Later targets and periodic refreshes do not restart the cast countdown. After expiry, a lingering
client timer cannot revive it. Casting again updates both slotted copies of the ability. For a
slot with no recorded cast, the game's own number remains the fallback. Channel interruption
tracking is not yet implemented; a channel currently counts to its expected end.

The target count has no API behind it: it is counted from the effects you and anything of yours
apply -- a pet's count too, which matters for the netch, the familiars, the bear and the shade — the same effect
the countdown is for, when the cast was seen, and otherwise matched to the slot by the ability's
**name**, then its **id**, then its **icon**. The icon is what catches a
morph whose effect is called something else, which is most of them. `/pbhud slots` says which of
the three matched, or that nothing did. The countdown is unaffected either way, because that comes
from the client.

**Countdown on the bar you are on** decides what happens when the game is already writing its own
number there (Settings > Interface > Action Bar Timers). That number is drawn at a size no add-on
can change, so:

- **This add-on** (the default) — ours goes in the middle of the icon and the game's own number is
  faded out of the way, so the text size setting always does something and there is only ever one
  number.
- **Both** — ours as well as the game's; ours drops to the bottom of the icon so the two do not
  sit on top of each other.
- **The game** — the front bar is left exactly as it is. The other set still gets ours, because
  the game never writes a number there at all.

The set you are not on is always this add-on's, whichever of the three is chosen.

### Preview

The bars are only drawn on the HUD, so they cannot be seen from the settings menu. While this
add-on's panel is open, an **outline the size of each bar**, in that bar's colour, is drawn where
it will sit — the three resource bars, the skill bar, and the other set's row above it. It follows every slider as you move it, and goes away when you leave the panel. It
can be switched off in the panel.

`/pbhud preview` shows the same outlines anywhere — on the HUD they sit on top of the real bars,
which is the quickest way to check the two agree.

## Chat commands

```
/pbhud                             this list
/pbhud status                      settings, and where the bars really are on screen
/pbhud pos <bar> <x> <y>           x from the middle of the screen, y up from the bottom
/pbhud scale <bar> <n>             size in per cent (50-200)
/pbhud gap skill|ult|item <n>      the space along the skill bar (0-150)
/pbhud style standard|plain|mura    the look of the three resource bars
/pbhud size <bar> <w> <h>          bar size in pixels (MURA-HIGE Style)
/pbhud shade [on|off|up|down|<n>]  the shade over a skill while its effect runs
/pbhud text [back] timer|count <n> size of the text on the skill bar (12-48)
/pbhud timers addon|both|game      whose countdown goes on the front bar
/pbhud slots                       what is on each slot, and why
/pbhud trace [on|off|clear]        record what the game sends as an ability is cast
/pbhud backbar [on|off|empty|<n>]  the other weapon set's row
/pbhud skillbar on|off             whether the skill bar is this add-on's to touch
/pbhud on | off                    switch every change on or off
/pbhud preview                     show or hide the preview outlines
/pbhud reset [bar]                 back to the game's own
```

`<bar>` is `health`, `magicka`, `stamina` or `skillbar` (`hp`, `mag`, `stam`, `bar` also work).
`/pbhc` is the same command.

`trace` is for working out why an ability's countdown is wrong, and the settings panel has the
same two buttons under **Measurement** so it can be used without a keyboard. Start it, cast the
ability -- for one that is aimed, place it once and cancel it once -- then show the record: every
press, ground-targeting circle, effect and combat event the game sent, in order, with the time
each arrived. It records nothing until it is started, stops when the record is shown, and changes
nothing on the screen either way.

## How it works

Nothing in the attribute bars is hooked, wrapped or called. The add-on only **writes to
controls**, and lets the bars carry on running their own code:

- **Position** is the anchor of each control — `ZO_PlayerAttributeHealth`, `...Magicka`,
  `...Stamina` and `ZO_ActionBar1` — re-pointed to `GuiRoot`: `CENTER` of the bar on `BOTTOM` of
  the screen. The attribute bars stay children of `ZO_PlayerAttribute`, so the HUD fragment still
  fades and hides them, and the game's "fade out of combat" setting still works.
- **Size** is `SetScale` on that control, and on its small companion.
- **The shade** is a `Cooldown` control of the add-on's own over the button's icon, started with
  `CD_TYPE_VERTICAL_REVEAL` and the effect's real duration; the engine runs the sweep.
- **The plain look** is one control per attribute bar, a child of the container and anchored over
  the bar, holding two backdrops: the track and a block whose width comes from `GetUnitPower`.
- **The gaps** are the same anchors the client writes in `ApplyAnchor` (`LEFT` on the previous
  button's `RIGHT`), with the quickslot moved off the hidden weapon swap marker and onto the
  first ability.
- **The countdown** uses a fixed cast origin with the ability/effect duration. The client
  `GetActionSlotEffectTimeRemaining(slot, hotbar)` is a fallback for slots without a recorded cast.
- **The other set's row and the text** are controls of this add-on's own, laid out in
  `Controls.xml`. The back row is parented to the action bar and anchored to the corresponding
  buttons; the front text is parented to its button.
- **Gamepad icon sizes** keep the configured front scale on the action bar and local scale 1
  on its slots, icons and FlipCards. After bounce and weapon swap animations stop, dimensions
  return to 61 (abilities) or 67 (ultimate), and cached swap endpoints are updated to the same
  size. The separate back row keeps its own scale. This also repairs scale-only drift without
  a UI reload. The client's [swap animation setup](https://github.com/esoui/esoui/blob/master/esoui/ingame/actionbar/actionbutton.lua)
  caches the FlipCard dimensions, so restoring only the visible icon is insufficient.

These controls run combat code — power updates, the attribute visualiser, the warners — on every
frame of a fight, and an add-on frame near client code is how private-function errors start. See
FINDINGS.md.

The game's own anchors and scales are read off the controls before the first write of each
session. Reset, the on/off switch, and a slider moved back to the default all put exactly those
back.

## What it does not touch

- **The bar's own width** — the game's, see above.
- **The game's own back row** — its controls are left exactly as they are; turn it off under
  Settings > Interface if you want only this add-on's row.
- **The game's own countdown**, except for fading it out of the way when this add-on is drawing
  one on the same icon. Its text, its size and the setting behind it are the game's.
- **What is slotted, the abilities, the cooldowns and the ultimate meter.**
- **Whether the numbers are shown on the bars**, and **whether the bars fade out of combat** —
  the game's settings under Settings > Interface.
- **The order or the colours of the bars**, the werewolf / mount / siege bars' own positions, and
  anything else on the HUD.

### If the rectangles do not appear

```
/pbhud plain
```

prints what it is doing: whether the style is actually Plain, whether the loop is running, whether
each bar control was found and its rectangle built, how full the bar is, and the alpha the game
has the bar at. That last one is worth knowing — **the game fades the resource bars out while they
are full and you are out of combat**, and this is drawn on them, so look at a bar that is
part-empty or wait until a fight.

### If a bar will not move

Everything this add-on writes is checked once a second while the HUD is up and put back if it is
no longer there, so a bar that is moved by something else comes back on its own. `/pbhud status`
prints how many times it had to do that, along with each bar's position, whether it differs from
the game's, and whether it has been written.

## If something is not showing

`/pbhud slots` prints, for every slot on both sets: what is in it, how many milliseconds the
client says are left, what this add-on made of that, the target count it worked out, and whether
its label was ever built. Underneath it lists the effect names being tracked — a count is only
written when the ability's name is in that list.

`/pbhud status` adds the rest: how many controls were built, whether the game is drawing its own
numbers, and any write the client refused.

## Tests

```
lua test/run.lua
```

from the add-on folder, with any Lua 5.1 or later. `test/harness.lua` stubs the three attribute
bar containers with the game's own anchors, a layout resolver that turns an anchor into a
rectangle, the attribute visualiser's habit of writing 141 / 237 / 323 onto a bar's width, the
action bar with its buttons, the action slot API for both hotbars, and `EVENT_EFFECT_CHANGED` —
so a build that measured the game's position off a stretched bar, that fought the visualiser for
the width, that counted a group member's copy of a buff as another target, or that drew a second
countdown next to the game's own, would fail here rather than on a PS5.

## Licence

This Add-On is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

Outline colour can be selected under the resource bar appearance settings: black (default),
white, silver, gold, red or blue. The choice is shared by all three resources in Square,
MURA-HIGE Style and MURA-HIGE NEO Style, and retains the existing opacity setting.

MURA-HIGE Style and MURA-HIGE NEO Style use a vertical fill gradient: a darker resource
colour at the bottom and a lighter shade at the top, with uniform opacity. Square remains solid.

MURA-HIGE Style and MURA-HIGE NEO Style offer shared resource text alignment: left
(default), right or center. Text aligns within the drawn bar width with a small inset.
Switching to Standard or Square restores the original label layout and alignment; the
game still controls the displayed values and whether resource numbers are visible.
