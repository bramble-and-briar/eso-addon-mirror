# Findings

What the client's own source says about the player's attribute bars, and why the add-on is built
the way it is. Everything here is **from source** (`esoui/esoui`, tag 12.0.8, API 101050) unless
it says it was measured; the list at the end is what still has to be looked at on a PS5.

## 1. Three controls in one top-level

`ZO_PlayerAttribute` (`playerattributebars.xml`) is the top-level, 64 high and hidden until the
HUD shows it. Inside it are six controls: the three the player knows —

| | anchor in the XML |
| --- | --- |
| `ZO_PlayerAttributeHealth` | `CENTER` of the group |
| `ZO_PlayerAttributeMagicka` | `RIGHT` on the group's `LEFT`, +237 |
| `ZO_PlayerAttributeStamina` | `LEFT` on the group's `RIGHT`, -237 |

— and three small companions, each anchored to the bar it belongs to: `Werewolf` under magicka,
`MountStamina` under stamina, `SiegeHealth` under health. All six are `ZO_PlayerAttributeContainer`
(237 × 23) or `...ContainerSmall` (228 × 12), and everything visible — background, frame, the
status bars, the warner, the resource numbers — is anchored inside its container. So a container's
anchor and scale are the whole bar's position and size.

The group itself is placed by `ZO_PlayerAttribute_Gamepad_Template`: `BOTTOM` of `GuiRoot`,
105 up. Its width comes from `ResizeToFitScreen`:

```lua
local barAreaWidth = screenWidth - BAR_OFFSET_FROM_SCREEN_EDGE * 2   -- 502
barAreaWidth = zo_clamp(barAreaWidth, MIN_BAR_AREA_WIDTH, MAX_BAR_AREA_WIDTH)  -- 1014, 1600
```

At 1920 wide that is 1014 — the minimum, not the screen — which is why the bars sit where they do
regardless of the TV. The middles work out at 137 up from the bottom, and 0 / -388 / +389 from the
middle of the screen. The add-on measures all six numbers off the controls anyway; those are only
the fallback.

## 2. What the client writes to these controls, and when

- `ResizeToFitScreen`, on `EVENT_SCREEN_RESIZED` and once at startup: the **group's width**. With
  the three containers anchored to the group, that moves magicka and stamina. Once they are
  anchored to `GuiRoot` instead, it does not reach them.
- `ZO_PlayerAttributeBars:ApplyStyle`, on `EVENT_GAMEPAD_PREFERRED_MODE_CHANGED`: templates for
  the group, the textures and the sub-bars. It re-anchors the **sub-bars inside** each container
  and the **group**, but never a container itself.
- `ZO_UnitVisualizer_ShrinkExpandModule`: the **container's width**, and its background's, as
  buffs and debuffs move a maximum:

```lua
ATTRIBUTE_BAR_STATE_EXPANDED -> 323
ATTRIBUTE_BAR_STATE_SHRUNK   -> 141
ATTRIBUTE_BAR_STATE_NORMAL   -> 237
```

  instantly on `EVENT_PLAYER_ACTIVATED`, and through a 750 ms `SizeAnimation` the rest of the time.

Nothing in the client writes a container's **anchor** or its **scale** after the UI is built.

## 3. Why scale, and not `SetDimensions`

§2 is the whole argument. A width written by an add-on survives until the player eats a meal,
takes a debuff, or zones — and then the visualiser animates the bar to 141, 237 or 323 and leaves
it there. Fighting that would mean rewriting the width on every one of those changes, which is a
loop with the client's own animation. Scale is never touched by the client, needs no upkeep, and
takes the frame textures, the background, the status bar and the resource numbers with it in
proportion — a stretched-width bar keeps its 64-pixel arrow ends and looks wrong.

The cost is that size is one number rather than two. For a HUD bar that reads as the right trade:
nobody wants a health bar three times as tall as it is wide.

## 4. Why the middle, and `GuiRoot`

Each container is anchored `CENTER` → `GuiRoot` `BOTTOM`, at (x, -y). Two reasons for the middle
rather than a corner: the width is not ours (§2), so a bar held by an edge would slide as buffs
come and go; and whatever ESO's scaling pivot turns out to be, a control whose anchor point is its
own centre stays put when it is scaled.

`GuiRoot` rather than the group, because three bars anchored to a 1014-wide group cannot be placed
apart from each other, and because the group's width moves on `EVENT_SCREEN_RESIZED`. The
containers stay **children** of `ZO_PlayerAttribute` — only the anchor changes — so
`PLAYER_ATTRIBUTE_BARS_FRAGMENT` (a `ZO_HUDFadeSceneFragment` over the group) still fades and
hides them exactly as before, and the game's own "fade out of combat" setting still works.

The companions keep their own anchors, which are relative to their partner, so they follow it.
They are given the same scale, or the pair no longer meets.

## 5. Measuring the game's own position

Taken once per session per bar, before anything is written, off `GetLeft` / `GetTop` /
`GetDimensions` — and **only while the container is its normal 237 wide**. The middle of a
stretched bar is not where the middle of a normal one is: the game holds magicka by its right edge
and stamina by its left, so at 323 the middle has moved 43 in. A bar that is not at its normal
width is left for the next HUD show to measure, and the worked-out fallback stands in meanwhile.
The two agree exactly at 1920 × 1080, which the tests check.

## 6. Why nothing is hooked

The rule from PB's MailerExtension (measured on PS5): a client closure created while an add-on
frame is on the stack is permanently untrusted, and fails the moment it reaches a private
function. These controls run combat code — `EVENT_POWER_UPDATE` several times a second in a fight,
the attribute visualiser's modules, the warners, the fade timeline — so a tainted closure here
would surface in the middle of a fight.

So the add-on never wraps an attribute bar method and never calls one. Everything is a write to a
control:

| | written | the game's own equivalent |
| --- | --- | --- |
| position | `ClearAnchors` / `SetAnchor` on each container | the XML anchors |
| size | `SetScale` on each container and its companion | (nothing — the client never scales them) |

The one registration is a `"StateChange"` callback on `HUD_FRAGMENT`: our function is stored
beside the client's, nothing of theirs is wrapped. The preview is built entirely from controls of
the add-on's own — showing the real bars in a menu would mean driving the group's fragment from
add-on code.

## 7. When the settings panel is actually open

Carried over from PB's ChatWindowCustomizer 1.0.1, found on PS5 and confirmed in the library's
source (`votan73/ESO`, `LibHarvensAddonSettings/Console/Settings.lua`): the console add-on list
opens a panel in two steps —

```lua
addon:Select()                                      -- fires AddonSelected, then sets .selected
SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  -- and only then shows the panel
```

— so `AddonSelected` arrives while the *list* is still the current scene, and `Select()` returns
early for the add-on already selected, firing nothing at all on a second visit. The preview
follows the library's own panel scene instead. The test harness opens panels in that same order.

## 8. Cost on console

Moving and scaling a control costs nothing lasting, and no font or texture is built: the preview
uses `ZoFontGamepad22`, which the gamepad UI has already, and plain colour textures. Nothing is
written at all while the settings still equal the game's own, so an installed-but-unset add-on is
indistinguishable from not having it.

## 9. The skill bar is one top-level too

`ZO_ActionBar1` (`actionbar.xml`) is 70 high and, on the gamepad, 606 wide and `BOTTOM` of
`GuiRoot` at -25 (`GAMEPAD_CONSTANTS` in `actionbar.lua`). Every button hangs inside it: the five
abilities and the ultimate are `ActionButton3` to `ActionButton8`, chained off
`ZO_ActionBar1WeaponSwap`, with the quickslot and the companion ultimate anchored to those. So
its anchor and its scale are the whole bar's, and it is placed and sized exactly like the three
attribute bars -- the same `CENTER` → `GuiRoot` `BOTTOM` anchor, the same scale, the same
measurement before the first write.

The one client write to watch is `ApplyStyle`, through `ZO_PlatformStyle`: on
`EVENT_GAMEPAD_PREFERRED_MODE_CHANGED` it does `ZO_ActionBar1:ClearAnchors()`, re-anchors and
sets the width back to 606. That is the same case the attribute bars have, and the same answer:
every HUD show compares and rewrites only what no longer matches.

The buttons are named controls (`CreateControlFromVirtual("ActionButton"..slotNum, ...)`), so
they are reached with a plain `_G` lookup. `ZO_ActionBar_GetButton` is never called -- not
because that function is dangerous in itself, but because a name lookup cannot be.

## 10. The client has a back row, and it is not the one the player wants

`ZO_ActionBarTimer` (`actionbutton.lua`) is a real back row: `ActionBarTimer3` to
`ActionBarTimer8`, anchored `CENTER` on each main button at `backRowSlotOffsetY` = -17, with the
other set's icon and a fill bar. But:

- it is gated on two settings, `UI_SETTING_SHOW_ACTION_BAR_TIMERS` and
  `UI_SETTING_SHOW_ACTION_BAR_BACK_ROW`, and
- `UpdateFillBar` hides a slot the moment it has no running effect
  (`self.slot:SetHidden(true)` whenever `HasValidDuration()` is false).

So it shows a slot while a timer runs on it and nothing the rest of the time -- it is a timer
display, not a second bar. Forcing those controls to stay visible would mean fighting an
`OnUpdate` handler of the client's on every frame, so this add-on draws a row of its own instead
and leaves the client's alone. If the player has the game's own row on, both are drawn; that is
the game's setting to turn off, and status prints what it is set to.

## 11. The countdown is the client's own number

`HandleSlotEffectUpdated` in `actionbar.lua`:

```lua
local timeRemainingMS = GetActionSlotEffectTimeRemaining(slotNum, g_backHotbar)
local durationMS = GetActionSlotEffectDuration(slotNum, g_backHotbar)
...
local stackCount = GetActionSlotEffectStackCount(slotNum, hotbarCategory)
```

Three functions, and the crucial part is the second argument: **they answer for the hotbar you
are not on**. That is the whole countdown for both weapon sets, straight from the client, with no
need to work out which effect came from which cast -- the problem that makes Action Duration
Reminder two thousand lines of heuristics. This add-on reads them for slots 3-8 of both
categories, every 100 ms, and writes the number on the icon.

`MINIMUM_ACTION_BAR_TIMER_DISPLAYED_TIME_MS` is 1000 in the client, and the same floor is used
here: a number that flashes up for half a second as an ability is cast is noise.

## 12. Counting targets is the one part with no API

There is no `GetActionSlotEffectTargetCount`, and nothing else in the client answers it. So it is
counted from `EVENT_EFFECT_CHANGED`, filtered with the client's own
`REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE` / `COMBAT_UNIT_TYPE_PLAYER` so only what the player
applied is seen: one entry per effect name, holding the units under it and when each expires.
Effects on `group*` unit tags are skipped -- a group member's copy of a buff would otherwise turn
a self-buff into "12".

A slot is matched to an entry by **name**, with the ability id as a second chance. That is a
heuristic, and an honest one: an effect usually carries the name of the ability that applied it,
but a morph that applies something under another name will not line up. The countdown does not
depend on it, so the worst case is a missing count, never a wrong time.

The table is bounded: expired units are dropped as they are read and again every 3 s, and at 96
effect names the least recently touched is dropped. On console that cap is the point -- a long
fight in a crowd must not grow a table for ever against the 100 MB pool.

## 13. Where the add-on's own controls live

`Controls.xml` holds two virtual templates -- one back bar slot (52 x 68 with a 44 x 44 icon, the
sizes and texture coordinates of `ZO_ActionBarTimer_BackBarSlot_Gamepad`, drawn in the game's own
back row art) and one pair of labels. They are laid out in XML rather than assembled with
`SetAnchor` from Lua, after PB's MailerExtension ran into anchor limits and zero-height rows
doing the latter on the console gamepad UI.

Only the parent is chosen at runtime, with `CreateControlFromVirtual`, because the controls they
hang on do not exist until the UI has loaded. Each one is parented to the `ActionButton` it
belongs to, which is what makes the action bar's own `ZO_HUDFadeSceneFragment` fade and hide
them with the bar, and what makes them inherit the scale this add-on puts on the bar.

## 14. What the update costs

One `RegisterForUpdate` at 100 ms, reading three numbers for each of twelve slots and writing at
most twenty-four short strings. It runs only while the HUD is up and only while something it
draws is switched on: `SCENE_FRAGMENT_HIDDEN` unregisters it, and so does the master switch. Two
fonts are built, one per text size in use.

## 15. The game's own countdown, and why it is faded rather than left alone

`ActionButton<n>TimerText` is the client's own number on the front bar, written by
`ActionButton:SetTimer` and sized by the platform template (`ZoFontGamepad27` on the gamepad).
Its size is not an add-on's to change, and the setting that turns it on
(`UI_SETTING_SHOW_ACTION_BAR_TIMERS`) is read-only from here. So with that setting on and this
add-on drawing its own number, the icon carries two.

1.1.0 answered that by not drawing ours while the game's was on. That was wrong in the way that
matters: the text size slider then did nothing at all, on the bar the player is looking at, and
the only clue was a tooltip. From 1.1.1 the default is to draw ours and set the client label's
**alpha to 0** instead.

Alpha is the right lever because `SetTimer` and `UpdateTimer` only ever write that label's text
and its hidden state -- alpha is never touched, so there is nothing to fight and nothing to
re-apply per frame. It is restored to 1 the moment ours stops being drawn: the mode is changed,
the master switch goes off, or the loop stops.

## 16. Controls.xml not loading is survivable

`CreateControlFromVirtual` raises if the template is not there -- a manifest that missed the XML,
or a client that would not parse it. On a console that is a whole session lost for nothing on
screen and nothing to read, so the failure is recorded (status prints it) and the same controls
are built from plain `CreateControl` calls instead, with the anchors and sizes the XML would have
given them. `/pbhud slots` says which of the two was used.

## 17. The gaps along the bar, and the control nobody sees

`ActionButton:ApplyAnchor` is the whole layout:

```lua
function ActionButton:ApplyAnchor(target, offsetX, isAnchoredLeft)
    if not isAnchoredLeft then
        self.slot:SetAnchor(LEFT, target, RIGHT, offsetX, 0)
    else
        self.slot:SetAnchor(RIGHT, target, LEFT, -offsetX, 0)
    end
end
```

and `ApplyStyle` chains the row with it, off `GAMEPAD_CONSTANTS`: `abilitySlotOffsetX` 10 between
the five abilities, `ultimateSlotOffsetX` 65 before the ultimate, `weaponSwapOffsetX` 61 for the
weapon swap marker inside the bar, and `quickslotOffsetXFromFirstSlot` 5 for the quickslot on the
far side of that marker.

The marker is the catch. On the gamepad `showWeaponSwapButton` is false and
`ZO_WeaponSwap_SetPermanentlyHidden` hides it -- but it is still a control with a width, and the
quickslot is anchored to its other side. So the gap the player sees between the item and the
first ability is `5 + the marker's width + 10`, and no single number in the client is that gap.

This add-on writes the same anchors with its own offsets, and anchors the quickslot to the
**first ability** instead of the marker, so the number in the settings panel is the distance on
screen. `ActionButton3` is left exactly where the client puts it, because it is what the rest of
the row hangs off; everything else closes up towards it. The three gaps are measured off the
controls first (`GetLeft` / `GetRight`, at the bar's own scale, before anything of ours is
written), so an untouched install still writes nothing.

The original anchor of each control is remembered the moment before the first write **to that
control**, never in one pass up front: the row can grow. `SetCompanionAnchors` puts a companion's
ultimate between the item and the abilities when one is summoned, and re-anchors the quickslot
past it -- a button the client has only just laid out, whose own anchor has to be read then, not
before. Reading them all again later would record our own offsets as the game's, which is the
mistake PB's NamePlateChanger had to grow a repair path for.

## 18. Whether the weapon sets can be swapped at all

Two client answers, and neither is a guess at an item:

```lua
local activeWeaponPair, locked = GetActiveWeaponPairInfo()          -- the Oakensoul Ring, etc.
local unearned = GetUnitLevel("player") < GetWeaponSwapUnlockedLevel()
```

Both are what the client's own weapon swap button reads
(`ZO_WeaponSwap_OnInitialized`, `buttontemplates.lua`), with `EVENT_WEAPON_PAIR_LOCK_CHANGED` and
`EVENT_ACTIVE_WEAPON_PAIR_CHANGED` behind the first and `EVENT_LEVEL_UPDATE` behind the second.
Action Duration Reminder looks for `oakensoul` in the icon of each worn ring instead
(`Bar.lua`, `barShowShiftFully`); that misses everything else that locks a bar, and breaks on a
renamed icon.

While either says no, there is no second set to show, so the back bar hides itself -- the
setting is left alone, and it comes back when the ring comes off. The update loop already
re-reads this every tick, so nothing has to be registered for it.

## 19. The shade over a skill is the client's own cooldown control

ESO has a `Cooldown` control type, and two of its sweep shapes are in the client's own Lua:
`CD_TYPE_RADIAL`, which the action bar uses for ability cooldowns, and
`CD_TYPE_VERTICAL_REVEAL`, which the utility wheel uses:

```lua
control.cooldown:SetTexture(GetSlotTexture(slotNum, hotbarCategory))
control.cooldown:SetFillColor(ZO_SELECTED_TEXT:UnpackRGBA())
control.cooldown:SetVerticalCooldownLeadingEdgeHeight(4)
control.cooldown:StartCooldown(remaining, duration, CD_TYPE_VERTICAL_REVEAL, CD_TIME_TYPE_TIME_UNTIL, USE_LEADING_EDGE)
```

That is the whole feature: a `Cooldown` of the add-on's own, over the button's icon, given the
ability's icon and started when an effect starts. **The engine runs the sweep**, so there is no
work per frame here and it cannot drift from the effect -- the length it is given is
`GetActionSlotEffectDuration`, the client's own number, on either weapon set.

It is only ever started again when something changes: a different duration, a different ability
in the slot, or the time left jumping back up, which is a re-cast. Ticking down is left alone.

Which way the sweep runs is `CD_TIME_TYPE_TIME_UNTIL` against `CD_TIME_TYPE_TIME_REMAINING` --
one counts towards the end and the other away from it. The setting is a **direction** rather than
a time type for that reason: nothing in the source says which way round the reveal is drawn, so
if it comes out upside down on a PS5 the player flips it, and a client that ever changes it costs
nobody a release.

## 20. Liquid without any new art (removed in 1.5.0)

The liquid style is drawn **over** the client's own fill, not instead of it. That is the design
decision the rest follows from: the damage shield overlays, the armour, possession and unwavering
modules and the warners are all controls the attribute visualiser hangs on those same bar
controls (`ZO_PlayerAttributeHealthBarLeft`, `...Magicka Bar`, `...StaminaBar`), and a style that
hid the client's bars would take all of that with it. One child per bar control instead: it
inherits the bar's alpha -- the game's own fade out of combat -- its hidden state, and any scale
this add-on has put on the attribute bars.

The look is three things over the fill: a darker bottom for depth, two bands of light drifting
across at different speeds, and a bright line at the surface where the fill ends. Every texture
is one those bars already load (`attributeBar_dynamic_fill_gloss`,
`attributeBar_dynamic_leadingEdge_gloss`) or one the generic progress bars use, so the style adds
**nothing** to the 100 MB pool console add-ons share. There is no art file in this add-on.

Two things have to be worked out rather than read:

- **How full the bar is.** `GetUnitPower("player", COMBAT_MECHANIC_FLAGS_*)` each tick, rather
  than following `EVENT_POWER_UPDATE`: one call per bar is cheaper than keeping a copy of the
  client's bookkeeping in step, and it cannot drift out of it. The two halves of the health bar
  each hold half the value, so the fraction is the same for both.
- **Where the fill ends.** A bar with `barAlignment="REVERSE"` (magicka, and the left half of
  health) fills towards its left, so the overlay hangs off the right edge and the surface is on
  the left; a normal one is the mirror. ESO does not clip a child to its parent, so each band is
  given the width of its overlap with the filled part and the texture coordinates to match.

At 20 updates a second, and only while the HUD is up and the style is chosen: on Standard, the
default, nothing is built and no update is registered.

## 21. Every control needs the fallback, not most of them

1.3.0 shipped the liquid overlay as the only control without a plain-Lua fallback for a template
that did not build, and the shape of that bug is exactly what came back from the PS5: everything
else working, the liquid doing nothing, and nothing to read anywhere. The fallback list now
covers every template this add-on has, and `/pbhud liquid` prints the whole chain -- style, loop,
each bar control, each overlay, the fraction, and the alpha the game has the bar at.

The last of those is worth knowing on its own: the attribute bars fade themselves out while they
are full and the player is out of combat, and anything parented to them fades with them. A liquid
effect checked at full health outside a fight is invisible for a reason that has nothing to do
with the liquid.

## 22. A measurement must never be able to stop a write

Reported from a PS5: the attribute bars' position setting sometimes did not take effect. Nothing
in the client was moving them -- the attribute visualiser's modules (armour, possession,
unwavering, power shield, arrow regeneration) all anchor overlay controls **to** a bar and never
re-anchor the bar itself, and `ApplyStyle` only touches the group, the sub-bars and the textures.
It was this add-on's own doing.

`CaptureGame` did two jobs: remember the anchor the bar had (which has to succeed, or there would
be nothing to put back) and measure where the game draws it (which is only ever a nicety, because
the fallback is worked out from the client's own constants). It returned one answer for both, and
`ApplyBar` refused to write unless that answer was true:

```lua
local left, top, width, height = self:ScreenRect(control)
if not left then
    return false        -- and ApplyBar then wrote nothing at all
end
```

`ScreenRect` returns nothing while a control has no size on screen, which depends on how far the
UI has got when the first apply runs -- so the position applied on one login and not on the next.
The two are separate calls from 1.3.2: `CaptureAnchors` gates the write, `MeasureGame` is best
effort and is tried again on every HUD show.

## 23. Putting it back, and counting

Everything written is now checked once a second while the HUD is up, and written again if it is
no longer there -- the same watch PB's MiniMap has had since its first release. An anchor and a
scale read per control, nothing written while they match.

It counts what it had to put back, and `/pbhud status` prints that count. That is the measurement
that answers the next report of this kind: a count that climbs means something really is moving
the bars and the watch is fighting it; a count that stays at zero while the bars are wrong means
the write never landed at all, which is a different bug in a different place.

## 24. Where the countdown goes, and the number that would not go away

Reported from a PS5: this add-on's countdown sat off the middle of the icon, next to the game's
own.

The client's is `ActionButton<n>TimerText`, anchored `CENTER` on `CENTER` with
`ACTION_BUTTON_TIMER_TEXT_OFFSET_Y_DEFAULT_GAMEPAD`, which is **4**, in `ZoFontGamepad27` at
`DCD822`. Ours was anchored to the **bottom** of the button, deliberately, from 1.1.0 -- when the
two could be on screen together and had to keep out of each other's way. From 1.1.1 the default
mode fades the client's out instead, so the place ours should stand is exactly where the client's
was. It now uses the client's own anchor, and steps down to the bottom only in "Both", which is a
choice to have two numbers.

Two more things came out of the same report:

- **The labels are anchored to the icon, not the button.** On the gamepad the icon is
  `ZO_GAMEPAD_ACTION_BUTTON_SIZE` = 61 inside a 64 button (67 in 70 for the ultimate), so "the
  middle" and "the corner" now mean the icon's, which is what the player is looking at.
- **The target count moved to the top left.** The client's stack count is at `CENTER` +23, -20 --
  the top right of the icon -- and two numbers in one corner cannot be read.

The duplicate number was a second bug. Fading the client's was conditional on
`GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_ACTION_BAR_TIMERS)` coming back true; a reading
that comes back wrong puts two numbers on one icon, which is the thing it was there to prevent.
Fading a label the game is not drawing on costs nothing, so the condition is gone: in "This
add-on" the client's label is faded, full stop. The setting is still read, for `/pbhud status` to
print.

And the fade remembered *that a slot* was faded rather than *which label* was, so a slot whose
button had been rebuilt was taken for done and left with the game's number on top of ours. It
remembers the control now, and hands back anything it faded earlier.

## 25. One size per bar, without resetting anybody's

The two rows are not the same size on screen: the gamepad action button's icon is 61, and the
other weapon set's row is drawn in the client's back row frame, whose icon is 44. One text size
for both was always going to be a compromise, so each row has its own.

The row's keys (`backTimerSize`, `backCountSize`) are **unset by default**, and an unset one means
"whatever the bar you are on uses" -- the same shape as a position that has not been moved yet.
So an install upgrading from a build with one size for both sees no change at all, moving the
bar's slider still moves both until the row is given a size of its own, and a button in the panel
puts the row back to following. `/pbhud status` prints both, and says which is following.

## 26. Centred means centred, and a label must be as tall as its text

The client puts its own countdown 4 pixels below the middle
(`ACTION_BUTTON_TIMER_TEXT_OFFSET_Y_DEFAULT_GAMEPAD`), and 1.3.3 copied that to keep the two in
the same place. On a PS5 it reads as sitting low, so ours is now on the middle exactly, offset 0.

The second half of that was the label's box. The client's is `<Dimensions x="0" y="25"/>`: width 0
so it sizes to the text, height fixed at 25 for its fixed 27 font. This add-on's size goes to 48,
and text centred in a box shorter than itself does not sit where the middle of the box is. The
height is set from `GetFontHeight()` whenever the font is applied, so the label is always exactly
as tall as what is in it.

## 27. Three chances to match an effect to a slot

There is no API for how many targets an effect is on, so the effects the player applies are
matched to a slot. By name alone, a morph whose effect is called something else is never counted.
The icon is the better key -- the art is nearly always the ability's own even when the name is not
-- so the match is now name, then ability id, then icon, and `/pbhud slots` prints which of the
three caught it, or that nothing did.

## 28. A default thought better of does not reach an install that already ran

`ZO_SavedVars:NewAccountWide` copies the defaults into the saved table on first run. So
`countFromOne`, which started `false` in 1.1.0 and was changed to `true` in 1.1.1 because "nothing
is showing" is worse than a 1, stayed `false` for ever on every install that had run 1.1.0 --
which is the whole of the target count doing nothing for a single-target ability.

Repairing a nil key, which is all `Account()` did, cannot see this: the key is not missing, it
holds an old default. The text settings carry a `version` now, and a change of mind moves the
value on once and stamps it, so a player who then chooses the old value keeps it.

## 29. The liquid style is gone, and what replaced it

The liquid style never drew anything on a PS5, and nothing found from here explained it: the
style was on, the loop ran, the controls were built. 1.5.0 replaces it with a plain one rather
than carrying on guessing, and deliberately changes the two things about the old one that could
each have been the reason:

- **Where it hung.** The liquid overlay was a child of the client's **status bar** controls, and
  nothing in the client does that -- the client's own gloss is a child StatusBar, but every other
  thing drawn on a bar (the frame, the background, the numbers, every attribute visualiser
  overlay) is a child of the **container**. The plain rectangles are children of the container
  too, anchored over the bar.
- **What it was made of.** Textures, blend modes and texture coordinates, any of which can come to
  nothing without an error. A backdrop is a centre colour: `SetCenterColor` and a width, no art to
  fail to load.

What it does not change is the part that was right: the client's own bars are left alone and
still doing their work, so the shield, armour and possession overlays and the low-health warning
all still draw. The frame and background are hidden by their own flag while the style is on, and
put back the moment it is not.

`/pbhud plain` prints the same chain the liquid one did.

## 30. One switch that really does hand the bar back

Another add-on laying out the skill bar has to be able to have it. "Off" here cannot mean "stop
writing": this add-on re-anchors the bar and its buttons, fades a client label, builds controls
parented to the buttons, and has a watch that puts all of that back once a second. Any one of
those left running is a fight.

So `SkillBarAllowed()` is asked by all of them, and the existing paths do the rest without a
special case:

| | asks it through | what happens when it says no |
| --- | --- | --- |
| position, size | `BarDiffers` | `ApplyBar` restores the anchor and the scale |
| the gaps | `SpacingDiffers` | `skillbar:Apply` restores every button's anchor |
| the row, the text, the shade | `Wanted`, `ShowsTimerOn`, `ShowsCount`, `BackBarEnabled`, `ShadeEnabled` | the loop hides its controls, hands the client's countdown back its alpha, and unregisters |
| the watch | `AnythingDiffers` | nothing differs, so it writes nothing |
| the preview | drawn per element | the skill bar's outline is not drawn |

`BarsReady()` stops asking for `ZO_ActionBar1` as well: a bar this add-on has been told to leave
alone is not a reason to hold up the three attribute bars.

## 31. Three from one PS5 round

**The target count appeared and vanished again.** Re-applying a damage-over-time on a target that
already has it sends `EFFECT_RESULT_GAINED` for the new application and `EFFECT_RESULT_FADED` for
the old one **after** it. Taking that fade at face value drops the unit that was just added. The
fade carries the end time of the instance that faded, so the two are told apart: a fade whose
instance was due to end well before what is on record (250 ms of tolerance) is for something
already replaced, and is ignored. `/pbhud slots` counts the ones it ignored.

The same line has a second guard: an effect that arrives with an end time already gone by is the
two clocks disagreeing, not an effect that is over, and taking it at face value would drop it the
moment it is looked at. It is kept as one that does not expire, ended by its own fade, and
counted.

**The game's own countdown came back from behind ours.** `ActionButton:ApplyStyle` calls
`ApplyTemplateToControl` on the button, which re-applies the platform template to its children --
and a template carries an alpha. It runs from `HandleSlotChanged`, which is every weapon swap,
every zone load and every change to what is in a slot. So "we faded it once" is wrong within a
minute of play. The fade is now decided by reading the label's alpha each time rather than by
remembering, and status prints how often it had to put it back.

**The resource numbers were behind the plain rectangle.** `ZO_PlayerAttributeBarText`, which the
numbers inherit, sets no tier at all, and the rectangles are `tier="HIGH"`. The numbers are lifted
to `DT_HIGH` at a level above the rectangle while the style is on, and put back at the client's own
tier and level when it is not -- re-asserted every update, because the client re-applies its
templates to those labels too. The low-health warner needs no such help: `ZO_PlayerAttributeWarner`
is layer `OVERLAY`, tier `HIGH`, level 500.

## 32. The target count is held by the client's own timer

The count still blinked out after §31, so the answer is no longer to find the event that does it.
The number's lifetime is tied to the thing that is already right and already on the same icon:
`GetActionSlotEffectTimeRemaining` for that slot. While the client says the slot's effect is
running, the last count worked out stays on the icon; when that timer reaches zero, or another
ability is in the slot, it goes. The countdown and the count now end together by construction.

A count worked out again always replaces what is held -- targets dying is a real change and
should show. Only a drop to **nothing** is held, because that is the failure mode: the
bookkeeping losing the effect while the effect is plainly still running.

The cost is that a damage-over-time whose targets all die before it expires keeps its last number
until the slot's timer runs out. That is the right way round: a number a few seconds stale beats a
number that is never there.

The two event-level guards stay, because they are still correct:

- a fade whose instance was due to end well before what is on record is for something already
  replaced (§31);
- and, for a client that sends the old instance's fade carrying the **new** times, where comparing
  the two says nothing: a fade arriving within 400 ms of an application for the same effect on the
  same unit is the one being replaced.

`/pbhud effects` prints the last twenty effect events with what the add-on did with each -- gain,
fade, or ignored -- so a third round of this can be answered from the console.

## 33. One slot, two effects

From a PS5: Blue Betty's countdown ran 22, 21, ... and then, a few seconds from the end, started
again at 5.

The number was the client's own. `GetActionSlotEffectTimeRemaining` answers with **one** number
for a slot that can have more than one of the player's effects running at once: the netch grants
its buff for 22 seconds and does something of its own every 5, and a few seconds from the end the
longer of the two is the five-second one. Read straight -- which is what this add-on and the
game's own action bar timers both do -- the countdown hands over to it.

What a player wants is the ability's own effect counted to its end, so from 1.6.3 a reading whose
duration is less than three quarters of the one already running is not taken while that one still
has time on it. A re-cast of the same ability has the same duration, so it is taken and starts
again. A short effect with nothing longer running is shown as it is. And a client that says
nothing is running is believed: an effect purged, or its target dead, is over.

The countdown, the shade and the target count's hold all read through the same call, so the three
cannot disagree about which effect a slot is showing. `/pbhud slots` prints the client's raw
number next to the one on the icon whenever they differ, and counts the readings it did not take.

## 34. The per-slot timer is the wrong source, and always was

Blue Betty came back a second time, with the sentence that settles it: **other add-ons show it
correctly**. So the information is there and reliable, and the source being used was not.

`GetActionSlotEffectTimeRemaining` answers with one number for a slot that can have several of
the player's effects running, and hands over between them -- the netch's 22-second buff giving way
to the five-second thing it does. Guards on top of that reading (1.6.3) could not tell which of
the two the player meant, because the reading does not say.

Action Duration Reminder, which gets this right, **does not call that API at all**. It watches for
the cast: `EVENT_ACTION_SLOT_ABILITY_USED` says which slot was pressed, and the effects that
arrive in the moment after it belong to it. From 1.7.0 this add-on does the same:

- a cast records the slot, the hotbar it was on, and the time;
- an effect arriving within 1.5 s of a cast, lasting at least 0.9 s, is that slot's; the longest
  of one cast's effects wins, which for Blue Betty is the 22-second buff and not the netch's five
  seconds;
- while that effect runs, the client's reading is not asked at all;
- when it ends, a client reading whose duration is under three quarters of it is refused too, so
  the little effect the same ability keeps up alongside cannot step in at the end;
- the slot's own icon, remembered at cast time, says when the slot holds another ability and the
  association is dropped.

The target count now counts the units under **that same effect**, so the number and the countdown
cannot be looking at different things -- and it is why the count kept vanishing: it was matched by
the ability's name, which is not what the effect is called.

The clock the add-on compares effect times against is the client's own as well:
`GetFrameTimeMilliseconds`, which is what the client uses (`zo_stats_gamepad.lua`:
`local timeLeft = (endTime * 1000.0) - GetFrameTimeMilliseconds()`). `/pbhud effects` prints both
clocks, and `/pbhud slots` says for each slot whether the countdown came from the cast, from the
client, or from a reading that was refused.

## 35. One ability, two slots, one countdown

The netch on both weapon sets counted down to two different numbers.

A cast was on record against the slot **and the hotbar** it was made on, so only that bar had it;
the other fell back to the client's per-slot reading, which is the reading that hands over to
something else (§34). But it is one effect however many slots the ability sits in, so a cast is
now also on record against the **slot's own art** -- the ability's icon -- and a slot with no cast
of its own looks there before it falls back to the client.

That is also what makes a weapon swap invisible to the countdown: the bar coming into hand finds
the same record. A different ability in the slot has different art, so it is not given somebody
else's time.

## 36. A great many effects are not applied by the player

The target count still did nothing for some abilities, and one registration is the reason:

```lua
EVENT_MANAGER:AddFilterForEvent(name, EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
```

Filtered to the player as the source, **nothing a pet applies is ever seen**. The netch of Blue
Betty is a pet; so are the sorcerer's familiar and twilight, the warden's bear, the nightblade's
shade. For every one of those the effect never arrives, so there is no effect to tie to the cast
and nothing to count. Action Duration Reminder registers the same event twice for exactly this
reason (`Core.lua`: `addon.name` and `addon.name..'_pet'`), and a third time unfiltered for two
named abilities the client reports with no source at all.

Both registrations are made now: `COMBAT_UNIT_TYPE_PLAYER` and `COMBAT_UNIT_TYPE_PLAYER_PET`.
`/pbhud effects` says how many are in place.

## 37. The cap threw out the wrong entries

The table of tracked effects is capped, and what went to make room was the least recently
**added**. A damage-over-time ticking quietly on three targets is never added again while it
runs, so it was exactly the shape of entry the cap threw out -- the target count disappearing
mid-fight for no reason the player can see. Reading an entry now counts as using it, what goes is
the least recently used entry with **nothing live in it**, and only if every entry is live does a
live one go. The cap is 128 rather than 96, and `/pbhud effects` counts what has been dropped.

## 38. The ability's own length, from the game

From a PS5: Templar's Power of the Light lasts 6 seconds and the countdown read 20.

One cast puts more than one effect on the world -- the ability's own, and Major Breach for twenty
seconds -- and 1.7.0's rule, "the longest effect of that cast", picks the wrong one of the two.
Blue Betty needed the longest; Power of the Light needs the shorter. Nothing about the effects
themselves says which.

FancyActionBar+, which the add-on was given to read, does not guess: it reads
**`GetAbilityDuration`** for the ability in the slot (`main.lua`,
`FancyActionBar.GetAbilityDuration`) and works from there, with a curated table for the ids where
that is not enough. The general half of that is free, and it is what this add-on now does: a cast
records what the game says its ability lasts, and the effect that is followed is the one whose
length is closest to it. With no duration to compare against -- an ability the game gives none for
-- the longest is still the best guess, which is where this started.

## 39. A target without a unit id

Some area effects report `unitId` 0. Keyed by the unit tag alone, as this did, every target of
such an effect collapses onto one key: a count of 1 however many were hit, and one fade clearing
the lot -- another way the target count came to nothing.

The effect's own `effectSlot` tells two instances apart, and is what FancyActionBar+ keys on
(`ResolveUnitKey`). The key is the unit id where there is one, the effect slot where there is not,
and the unit tag only as a last resort.

## 40. A size, for the one style that can have one

Every other style **scales**: the bar keeps the shape the game drew and is made bigger or smaller
whole. That is not a preference, it is §3 -- the width of those controls belongs to the attribute
visualiser, which writes 141 / 237 / 323 onto them as buffs come and go, so a width written here
would last until the player's next meal.

MURA-HIGE Style draws the bar itself, so there is nothing to fight: it takes a width and a height
in pixels and is exactly that. The overlay stands on the edge the bar fills from and level with
the bar the game has, so the position sliders still say where it is; the health bar's two halves
each take half of the width and meet in the middle.

The one thing it needs that the scaling styles do not is the game's own fill **out of the way** --
a bar narrower or shorter than the game's leaves the game's showing round it. The bar control
cannot be hidden for that: `powershield.lua` parents the damage shield overlays to it
(`CreateControlFromVirtual("$(parent)PowerShieldLeftOverlay", attributeBar, ...)`) and they would
go with it. So its gradient is taken to nothing and its gloss, which has no children, is hidden;
putting it back is the client's own line, `ZO_POWER_BAR_GRADIENT_COLORS` for that power, which is
what `ZO_PlayerAttributeBar:RefreshColor` uses.

The sliders were nearly shipped with the same labels as the position ones -- "Stamina: height"
twice in one panel, the second unreachable. They are "bar width" and "bar height" now.

## 41. The preview's row was the width of the whole bar

From a PS5: the other weapon set's outline in the settings panel looked far too wide.

It was drawn at the skill bar's full width, and the bar's control is 606 wide while the six slots
of the row stand over `ActionButton3` to `ActionButton8` and nothing else -- the quickslot and, on
the gamepad, the invisible weapon swap marker hold the left-hand end and have no row above them.
Measured in the harness, the buttons begin a fifth of the way into the bar (61 for the marker's
place, 45 for its width, 10 for the gap, of 606), so the outline promised a row a quarter again
as wide as the one that appears.

Where the buttons sit is now measured off the real controls and given back as **fractions of the
bar's width**. Fractions rather than distances because they are free of scale -- both numbers are
scaled the same and it cancels -- so the outline holds whatever size the bar is set to, and moves
in when the gaps are closed.

## 42. A rounded bar is three pieces, not one texture (withdrawn in 1.10.0)

MURA-HIGE Style came out with square corners. It was drawn as one stretched copy of
`gp_dynamicBar_medium_fill.dds`, and that file is the **fill** -- a plain block, which a status
bar stretches across its length. The round ends are not in it.

Every rounded bar the gamepad interface draws is three textures from
`gp_dynamicBar_medium_frame_white.dds`: a left cap, a right cap, and a middle stretched between
them, each with its own texture coordinates out of the sheet
(`statusbartemplates_gamepad.xml`, `ZO_GamepadWhiteFrameLeftMedium` / `RightMedium` /
`CenterMedium`). `ZO_GamepadSlider` is the plainest example: its whole track is exactly those
three. So is this style's track, and so is its fill.

The caps are 7 wide for the 22-high bar the art was drawn for, and are scaled with the height so
that a thin bar does not end up with caps fatter than it is tall. The height is passed to that
sum rather than read off the container: a control sized by its anchors answers 0 until it has
been laid out, and the caps would come out at their smallest.

## 43. The rounded shape is gone

Built out of the client's own three-piece bar art (§42) it still did not look right on a PS5, and
a shape nobody can see the point of is not worth a third attempt. MURA-HIGE Style is the same flat
rectangle as Square from 1.10.0, and what makes it its own style is the thing that was wanted:
a **width and a height of the player's choosing** rather than a multiple of the game's.

The saved key is still `rounded`, because that is what is in people's saved variables.

## 44. An outline instead of the game's frame

"Keep the game's frame" is gone: a flat rectangle inside an arrow-shaped frame is neither one
thing nor the other, and nobody wanted it. The frame on offer is this add-on's own -- four thin
rectangles round the bar, on or off.

Four rectangles rather than a backdrop's own edge, because an edge needs an edge **texture** and
no art ships with this add-on. Each side is held by two corners so it stretches with the bar,
which also means the outline is right whatever size MURA-HIGE Style is set to.

## 45. Choosing the style is the setting

MURA-HIGE Style appeared to do nothing until a size slider was moved. Whether a bar was drawn at
a size or scaled was decided by whether a size had been **saved**, so a fresh install of the style
fell through to "follow the game's bar" -- which is what Square does -- and the sizes looked as
though they only took on the second attempt.

Choosing the style is the setting. An unset width or height is the game's own size, drawn at that
size by us, which looks the same and behaves the same as every size after it.

The panel now also takes turns: the pixel rows are live only in MURA-HIGE Style and the
percentage only outside it, through `disable` functions on the rows (which
LibHarvensAddonSettings takes as a function, as Votan's Minimap does). The style dropdown calls
`UpdateControls` so the change shows at once. The skill bar is scaled whatever the attribute bars
are doing, so its own percentage stays live.

## 46. The target count against FancyActionBar+'s

Asked whether the number in the icon's corner works the way FancyActionBar+'s does. The idea is
the same -- count the units an effect is on and drop them as they expire -- and three rules were
not.

| | FancyActionBar+ | here |
| --- | --- | --- |
| on yourself | not recorded (`GetAbilityTargetDescription(id, nil, unitTag) == "Self"`) | **now** not counted |
| on your pets | not recorded (`IsPlayerPet`) | **now** not counted |
| area effects | not recorded at all, unless a cast is running with a real unit id | counted |
| the key for a target | the unit id, and only when it is above zero | unit id, else the effect's slot, else the tag |
| shown from | 2 targets, or 1 for a debuff with the option on | 1 by default, 2 by setting |
| a count that comes back empty | recomputed, so it goes | held while the client still times the effect |

The first two are worth having and are taken: a buff on yourself is not a target count -- the
countdown beside it already says it is up -- and neither is one on something of yours. They were
the whole of the "1" that appeared on every self-buff.

The rest are deliberate differences. FancyActionBar+ can leave area effects out because it
carries a table of hand-tuned ability ids to fall back on; this add-on has no such table, so it
keys a target by the effect's own slot where there is no unit id and counts the area effects that
way (§39). The hold (§32) is ours because the bookkeeping under it is simpler than theirs. And
"from 1" is a better default once a buff on yourself no longer produces one.

One thing worth noting about the reference: `GetAbilityTargetDescription(...) == "Self"` compares
against an English string, so on a Japanese client that test never matches. The check here is
`unitTag == "player"`, which holds in any language.

## 47. The countdown against FancyActionBar+'s

Asked the same question of the duration. Both start from `GetAbilityDuration` for the ability in
the slot (§38); what differs is everything around it.

| | FancyActionBar+ | here |
| --- | --- | --- |
| which effect is the slot's | its ability id, through a curated map of effect id to slotted id (`config.lua`, 1700 lines) | the effects that arrive within 1.5 s of the cast, the one whose length is nearest the ability's |
| when the countdown starts | at the cast for the abilities its list names (`onAbilityUsed`: `effect.endTime = duration + t`) | **now** at the cast for any ability that declares a length, with the first effect of that cast taking over |
| several targets | `effect.endTime = maxEnd`: carried out to whichever ends last, never pulled in | **now** the same |
| toggles, ground effects, channels, banners | a handler each | none |
| the client's per-slot timer | never called | the fallback where no cast is on record |

The two marked "now" are taken in this release, and both are the reference's behaviour without
its table: any ability that declares a length starts counting the moment it is cast, so an
ability whose effect the client never reports still shows something, and a later target carries
the countdown out rather than leaving it on the first one's end.

What is deliberately not taken is the table. FancyActionBar+ can key an effect straight to a slot
because it carries a hand-tuned map of ability ids, and a handler for each awkward family --
toggles, grounds, channels, the banner. Seventeen hundred lines of it, maintained release by
release. This add-on has the cast to work from instead: less exact for the families that need a
handler, and nothing to keep up to date.

## 48. The tooltip's length is the reference, not the longest effect that turns up

From a PS5: Templar's Blinding Flashes lasts 10 seconds and the bar read 6.

One cast, more than one effect, for the third time -- and this one the other way round from Power
of the Light. There the ability's own effect was the short one and a 20-second Major Breach came
with it; here the ability's own is what the client does not report at all, and the six-second
effect that comes with it was the only candidate there was. "The candidate closest to the
ability's length" then picks it, because it is the only thing to pick.

So a candidate is now only followed if it is **about as long as the game says the ability is** --
within a quarter, and never less than a second and a half, which leaves room for the passives and
sets that stretch a duration a little. Nothing matching means the length from the tooltip stands,
counted from the cast (§47), and that is the number the player is comparing against anyway.

The three cases together, and what each needs:

| | the game says | effects seen | followed |
| --- | --- | --- | --- |
| Power of the Light | 6 s | 6 s, and 20 s of Major Breach | the 6 s effect |
| Blue Betty | 22 s | 22 s of Major Sorcery, 5 s of netch | the 22 s effect |
| Blinding Flashes | 10 s | 6 s only | the tooltip's 10 s |

FancyActionBar+ gets all three from its table of ability ids. This gets them from
`GetAbilityDuration` and one rule, which is the trade named in §47: no table to keep up to date,
and less exact where an ability's real duration is not what the game declares.

## 49. Ground targeting: two attempts, two defects, and what the reference really does

A ground-targeted ability is pressed once to start aiming and again to place it. Counting from the
press has the countdown running while the circle is still on the floor. 1.12.0 tried to hold such
a press, 1.12.1 tried to make the hold safe, and both took **every** countdown in the add-on with
them. Neither was a mystery once the client's own source and FancyActionBar+ were read properly.

### Why the first attempt failed: the event does not exist

`EVENT_LEAVE_GROUND_TARGET_MODE` is not an event. The client's own source registers one ground
event (`ingamescenemanager.lua:32`, `EVENT_ENTER_GROUND_TARGET_MODE`), and FancyActionBar+
registers that one and **`EVENT_CANCEL_GROUND_TARGET_MODE`** (`main.lua:7084-7085`). There is no
"leave".

1.12.0 registered a table of two:

```lua
for _, event in ipairs({ EVENT_ENTER_GROUND_TARGET_MODE, EVENT_LEAVE_GROUND_TARGET_MODE }) do
```

The second is `nil`, so only `ENTER` was ever registered -- and the handler read

```lua
if eventCode == EVENT_ENTER_GROUND_TARGET_MODE then self.groundActive = true return end
self.groundActive = false   -- unreachable
```

So every event that could arrive **set** the gate and nothing could ever clear it. The first
ground-targeted press of the session closed it for good, and from then on every press of every
ability was held: no cast recorded, no countdown started, nothing on any icon.

### Why the second attempt failed: the safety net was keyed to the wrong thing

1.12.1 added a three-second release for a held press, and kept the same non-existent event. The
release read:

```lua
Later(function()
    if groundPending == pending then ... release ... end
end, GROUND_HOLD_MAX_MS)
```

`groundPending` holds **the most recent** held press. In a fight a press lands every second or
two, each overwriting it, so when press A's timer fired three seconds later the pending press was
C or D and A was dropped without being released. The gate stayed shut for the same reason as
before, and the one thing that might have re-opened it by accident -- the `IsPlayerGroundTargeting()`
poll -- had been removed in the same release.

Two rounds of a PS5's time, and both defects were visible from the client's own source.

### What FancyActionBar+ actually does

The mechanism 1.12.0 copied is not the one that times a cast. `groundTargetMode` in FAB+ queues
`OnHotbarSlotStateUpdated` -- button *usable-state* updates -- while aiming and replays them
afterwards (`main.lua:5792-5850`). It has nothing to do with when a countdown starts.

What times a cast there:

- **`EVENT_ACTION_SLOT_ABILITY_USED` starts no countdown at all** for an ordinary ability. It sets
  `eff.hasActiveCast = true` and `eff.castTime = t` (`main.lua:5983-5987`) -- a hint used later to
  decide whether a target may be recorded -- and nothing else.
- **The countdown comes from the effect.** `OnEffectChanged` takes `beginTime`/`endTime` from the
  event, and `RecordUnit` / `PruneUnits` carry `effect.endTime` out to the furthest target.
- **Starting at the press exists only for a named list.** `specialEffects[id].onAbilityUsed` sets
  `effect.endTime = duration + t` (`main.lua:6037-6051`) for the abilities its config names --
  Cleansing Ritual, the traps, and so on. For traps there is even a setting to *not* do it
  (`SV.ignoreTrapPlacement`), because a trap's timer should not start where it is placed.
- **For those same abilities it waits for proof.** `needCombatEvent[abilityId].result` matched
  against `EVENT_COMBAT_EVENT`, filtered by ability id and player source, then
  `effect.endTime = currentTime + duration` (`main.lua:6848-6856`). That combat event is the
  "it really went off" signal.

And the fact that shapes all of it: **there is no "placed" event**. `ENTER` says aiming began,
`CANCEL` says it was abandoned, and nothing at all says it landed. That is why FancyActionBar+
never tries to time a placement from those events -- it waits for the effect, or for a combat
event it has named in advance.

### Where our own design is wrong, then

Not in the hold: in §47. "Start the countdown at the press, from the tooltip's length" is this
add-on's rule, not the reference's, and it is exactly wrong for anything with an aiming phase.
It was introduced to cover abilities whose effect the client never reports, and it does that --
but it should never have applied to an ability that has not been cast yet.

### What a third attempt needs, in order

1. **A measurement, before any code.** A logging build that prints, with timestamps: `ENTER`,
   `CANCEL`, `ACTION_SLOT_ABILITY_USED` with its slot, the first `EFFECT_CHANGED` for that
   ability, and the first `COMBAT_EVENT` for it. Place a Caltrops; cancel one. That single
   capture answers all of: does `ABILITY_USED` fire at the press or at the placement, do the two
   ground events arrive on console at all, and what arrives at the moment of placement.
2. **Learn which abilities are ground-targeted rather than listing them.** When `ENTER` fires, the
   ability just pressed is one; remember its id. No table to maintain.
3. **For those abilities, do not start from the press.** Start from the effect, as the reference
   does, or from a combat event for that ability id with the player as its source.
4. **Nothing that can hold a press indefinitely.** If a gate is needed at all it must be released
   by something that cannot fail to arrive, and every held press must have its own release, not
   one shared slot.

## 50. The trace (1.14.0): the measurement before the third attempt

Nothing in 1.14.0 changes what is drawn. It adds one thing: a recorder, off until it is asked
for, that writes down what the game actually sends while an ability is cast -- the measurement
§49 says has to come before any third attempt at ground targeting.

**How it is used.** Settings > PB's ConsoleHudCustomizer > Measurement has two buttons, Start and
Show (`/pbhud trace on` / `/pbhud trace` do the same from chat, but a console player should not
have to open the on-screen keyboard to measure something). Press Start, cast Caltrops once and
place it, cast it again and cancel it, press Show. The record goes to the chat window, oldest
first, each line stamped with the time it arrived relative to the first.

**What it records**, and why each one is there:

| line | source | the question it answers |
| --- | --- | --- |
| `press` | `EVENT_ACTION_SLOT_ABILITY_USED` | does the game report the press that raises the circle, the press that places it, or both? The line carries a press counter for exactly this. |
| `ground` | `EVENT_ENTER_GROUND_TARGET_MODE`, `EVENT_CANCEL_GROUND_TARGET_MODE` | do these arrive on console at all, and in what order against the presses? |
| `aiming` | `IsPlayerGroundTargeting()`, polled every 50 ms | the cross-check. If the events are silent but the poll turns over, the poll is what a third attempt must be built on -- and if the poll is flat while the events fire, the reverse. |
| `effect` | `EVENT_EFFECT_CHANGED` (player and pet sources) | "ends in" against the two presses says which one the game measured the duration from. |
| `combat` | `EVENT_COMBAT_EVENT`, player source | whether the "it went off" signal FancyActionBar+ waits for (`needCombatEvent`) arrives here, and when. |

**What it deliberately does not do.** It registers nothing until Start, unregisters everything at
Show, and never touches the countdown, the links or the labels. Effects and combat events are
written only for abilities pressed in the last twelve seconds, and only the first of each kind per
ability, so a fight cannot fill the record; the ring holds 160 lines. The header of every dump
prints which of `ENTER` / `CANCEL` / `LEAVE` the client really has, so the mistake behind 1.12.0
is visible on the first line rather than three builds later.

The harness gained the two ground events, `EVENT_COMBAT_EVENT`, `IsPlayerGroundTargeting` and the
`FireGround` / `FireCombat` helpers -- and deliberately **no** `EVENT_LEAVE_GROUND_TARGET_MODE`,
because a stand-in that invents an event would have let 1.12.0 pass its tests.

## 51. What a PS5 actually sends for an aimed ability, and what 1.15.0 does with it

The trace of §50, run on a PS5 with Scalding Rune (id 40465, the game says 22s): placed once,
cancelled once.

```
+0.00s ground  ENTER (event 131535)  IsPlayerGroundTargeting=true
+0.00s press   slot 6 "Scalding Rune" id=40465  lasts 22.0s  press #1  aiming=true
+0.02s aiming  turned true -- the circle is up
+0.62s aiming  turned false -- the circle is gone
+0.80s combat  "Scalding Rune" id=40465 result=2240
+0.80s effect  GAINED id=40465  runs 24.0s, ends in 24.0s
+3.05s effect  FADED  id=40465                      (the rune was triggered)
+4.10s ground  ENTER;  +4.10s press #2 aiming=true
+4.13s aiming  turned true
+4.63s aiming  turned false
+4.63s ground  CANCEL (event 131536)
+4.63s press   slot 5 "Obsidian Shard" id=29071  lasts 6.0s  press #1  aiming=false
+4.81s combat/effect for Obsidian Shard
```

Four facts, and every one of them contradicts something an earlier attempt assumed:

1. **`EVENT_ACTION_SLOT_ABILITY_USED` fires when the circle goes *up*, and never again.** There
   is no press event for the placement at +0.62. "Wait for the second press" is impossible.
2. **`IsPlayerGroundTargeting()` is already true inside that handler.** ENTER arrives first, and
   the press line's own `aiming=true` proves the read is available synchronously. So an aimed
   press can be told from a cast *at the press*, with no gate, no queue and nothing held back.
3. **Nothing marks the placement.** The circle simply goes down (+0.62) and the effect follows
   180 ms later. The effect is the placement, as far as an add-on can see -- exactly the design
   FancyActionBar+ settled on (§49).
4. **A cancel is distinguishable.** `EVENT_CANCEL_GROUND_TARGET_MODE` arrives with the circle
   going down (+4.63); a placement has no event at all. The cancelling press (○) also casts what
   is bound to it, and that press reads `aiming=false`, so it is not mistaken for an aim.

### What 1.15.0 does

`OnAbilityUsed` reads `IsPlayerGroundTargeting()`. If it is true the press is a circle going up:
it is **held as one pending record** and nothing is counted from it. Then, whichever comes first:

- **an effect links to that slot** -- the ordinary path counts from the effect, and the record is
  dropped. This is what happens for everything the game reports.
- **`GroundTick` sees the circle down, with no cancel** -- it was placed, so the ability's own
  length starts *from the placement*. One update tick of grace first, so a cancel in the same
  frame is seen before anything is counted.
- **`EVENT_CANCEL_GROUND_TARGET_MODE`** -- it was never cast. The record is dropped and nothing
  is counted at all.
- **another press, or ten seconds** -- the record is dropped.

`LinkToCast`'s 1.5-second window runs from the placement rather than the press, or an ability
aimed for three seconds would have its own effect refused as someone else's.

### Why this cannot fail the way 1.12.0 and 1.12.1 did

The whole of the state is one record for one press, and every path out of it drops that record.
There is no flag that gates other abilities: losing the record costs nothing but the tooltip
fallback for that one press, and the effect path -- which is where almost every countdown comes
from -- is untouched. 1.12.x put a single latched flag in front of *every* press, so one
unreachable branch silenced the entire add-on (§49).

## 52. Liquid measured its bar in the wrong pixels (1.24.1)

The Liquid style (1.24.0, written in another session) drew nothing on a PS5's health bar, lit only
the middle of magicka and stamina, and spilled above and below all three. One cause for all of it:
every distance was a fraction of the **status bar's height**, and a console's status bar is
**64 high**, not 17.

`ZO_PlayerAttributeStatusBar_Gamepad_Template` (`playerattributebartemplates.xml`) is
`Dimensions y="64"` with the gamepad fill art, which carries transparent space above and below
its coloured band; the container stays `237 x 23`, and the band the player sees is its 17, as on
keyboard. With 64:

| | worked out as | on a PS5 |
| --- | --- | --- |
| end inset | `max(height * 1.5, 6)` | **96** on each side |
| magicka / stamina, full | `224 - 96 * 2` | **32 pixels**, in the middle |
| each health half, full | `111 - 96 * 2` | **negative** -- hidden outright |
| band | `height * 0.18` .. `height * 0.82` | **41 high** over a bar 17 high |

A sine fade across every strip also put the brightness in a hump in the middle of whatever
was left.

**Why the tests passed.** The harness built every status bar 17 high -- the keyboard size -- so
the insets came to 25 and everything fitted. The harness bars are 64 high now, and the old
formula fails the new checks one by one: health draws nothing, magicka and stamina are narrow,
the band leaves the bar.

**What 1.24.1 does** (`plain:LiquidBounds`):

- the band is `17/23` of the container's height, centred on the status bar, never taller than
  the status bar itself, with a 12% margin inside it;
- only the **pointed outer ends** are kept clear, by half the band, which is how far an arrow's
  slope reaches in. Health's halves meet flat in the middle, so nothing is kept clear there, and
  the right half's wave carries on from where the left half's stops;
- the moving end of the fill keeps 2 pixels clear of the leading edge;
- strips are full strength along the bar and fade in over three strips at an open end only.

`/pbhud plain` prints, per status bar, the control's size, the band and the span the effect is
drawn in, and whether it is shown -- the three numbers to read if a PS5 disagrees.

## 53. Liquid that reads as liquid (1.25.0)

1.24.1 put the effect in the right place, and it still looked like two white wires crossing a
bar: thin hard lines at full strength, rings for bubbles, nothing that said *depth* or *surface*.
What makes Diablo's orbs read as liquid, translated to a 17-pixel horizontal tube:

| orb | here |
| --- | --- |
| dark depths | a shade over the lower 65% of the liquid, clear at the top, 50% black at the bottom |
| swirling contents | six soft masses, four light and two dark, drifting both ways at different speeds and breathing; each is four quarters brightest at the centre corner, so it has no edges |
| the surface | the end of the fill is a bright wobbling edge with a glow behind it; a change in the amount stirs it (6x the change, capped) and it settles over ~450 ms |
| drain | what was just lost stays 150 ms as a pale trace, then drains at 0.9 of the bar per second |
| bubbles | beads with a point of light, rising and fading out at the top |
| the glass | a faint reflection along the top of the whole tube, and a glint that crosses it |

**No art, and no lines.** The softness is `SetVertexColors`: a rectangle given a different alpha at
each corner is interpolated across, so a quarter with alpha only at its inner corner falls off to
nothing at the rim. A mass cut by the edge of the fill has its corner alphas worked out from where
the cut corners really are, so it still fades rather than stopping hard.

**Cheaper than what it replaced.** 43 textures per bar section against 84 (48 strips and 36 bubble
dots), and no per-strip wave: the masses carry the motion.

**Judged offline.** `test/preview_liquid.lua` runs the add-on in the harness through a hit, a
refill and a drop, records every texture's rectangle and corner colours as the add-on wrote them,
and writes a page that plays them back. The game's own fill art is not in the source, so it is
drawn as its gradient; everything over it is the add-on's own output.

**Tests that fail when they should.** Every piece is either "fill" (must stay inside what is
filled) or "tube" (the glass and the drain; must stay inside the bar), and all must stay inside
the band and clear of the points, at seven amounts and many moments. Moving the glass above the
band, not cutting the currents to the fill, and turning the slosh off each fail the tests.

## 54. See-through, and a square tube tried and put back (1.26.0 → 1.26.1)

**See-through (kept).** The game's fill is written at 62% of its gradient's alpha (92% in 1.25.0)
and every effect over it at 80% of its 1.25.0 strength (`LIQUID_EFFECT_ALPHA`).

**The square tube (withdrawn).** 1.26.0 hid the game's arrow-ended frame and background for
Liquid and drew a square frame of its own, on a reading of "the triangular ends do not fit" as a
request to replace them. It was not what was wanted: the game's own frame stays. 1.26.1 is
1.25.0's Liquid -- the game's frame and background, the half-band clearance at the pointed outer
ends (§52) -- with the see-through values above. The outline switch and colour are Square's and
MURA-HIGE's again, not Liquid's.

## 55. An upright line at the full end (1.26.2)

From the PS5: using a resource put an upright line at the bar's full end. A bar spends most of a
fight regenerating a few percent short of full, so the moving end of the fill sits right beside
the full end -- and Liquid drew the surface there as a straight upright line, beside a frame whose
end is a point. The drain's far end (the old level, which is the full end whenever a resource is
spent from full) was the same: an upright edge, only thinned to 30% rather than gone. And every
soft piece -- the shade, the currents -- was cut off square wherever it met the end of the fill or
a pointed end, which leaves a faint upright edge of its own.

**One shape for every end.** The frame's pointed ends are a point at the middle of the band sloping
back 45 degrees to the top and bottom (§52's half-band taper). The fill's moving end is given the
same shape, pointing the way the fill moves -- towards the end it fills to, so a bar nearly full
shows its surface parallel to that end. A row a distance `d` from the middle of the band stops `d`
short of a pointed end and `d` short of the moving end.

- **The surface and its glow** are drawn in seven rows, each stepped back by its own `d`: a `>` on
  a bar that fills rightwards, a `<` on one that fills leftwards.
- **The drain** is seven rows too, so both its ends -- the new level and the old -- have that shape,
  and it fades to nothing at the old level instead of stopping there.
- **Upright pieces** (the shade, the currents, the bubbles) stay inside the upright rectangle their
  farthest row allows, and the shade and the currents fade to nothing over the last 5 pixels before
  any cut, so none of them leaves a line. Health's halves meet in the middle, which is not a cut.
- **The glass and the glint** stop where their own rows meet the pointed ends.

59 textures per bar section (43 before): the rows cost 16.

**Tests.** The containment rule is now the shape itself: every piece, at every amount and moment,
stops `d` short of each pointed end and, if it belongs to the liquid, `d` short of the moving end.
The surface must point the way its bar fills, the drain's far end must have the shape and nothing
at it, and a soft piece at a cut must have nothing at that cut. Making the surface upright, making
the drain's far end upright and solid, and taking the fade off the cuts each fail them. The
preview now draws the game's fill inside its pointed shape and regenerates magicka up to full.

## 56. Into the points, no flicker, and Crystal (1.27.0)

Three from the PS5, one screenshot among them:

1. **The effect did not reach the triangular points.** Every upright piece stopped where its
   farthest row had to stop -- half the band short of each point -- so the triangles at both ends
   stayed plain.
2. **A line flickered at the point while a bar regenerated.** The surface line at the moving end
   was drawn in rows stepped to the point's shape; a few percent short of full those rows were cut
   against the point, appearing and disappearing frame to frame.
3. **A Crystal style**, a cut crystal rather than a liquid.

**One painter.** Liquid and Crystal now draw everything through `Painter:Quad`, which takes a
rectangle, a colour and an alpha that is a number or a bilinear function of position, and cuts the
rectangle into rows of the band (8) wherever a slope has to be followed. Each row reaches exactly
as far as its own distance `d` from the middle of the band allows: `d + 1` short of a pointed end,
and -- for the liquid itself -- `d` short of the moving end. The texture's per-corner colours are
set from the alpha function at each piece's own corners, and a bilinear function is exact there,
so a soft mass cut into rows looks the same as one uncut. Pieces come from a pool per bar section,
built on demand and reused; what a frame does not use is hidden. Vertex colours carry the colour
(`SetColor(1,1,1,1)` first), so a pooled texture keeps nothing of what it drew last frame.

**No line, and nothing at the point.** Liquid has no surface line any more. The moving end is a
glow that rises towards it, and the glow fades out between two band-widths and one band-width from
the full end, so it is gone before the moving end gets anywhere near the point. The soft currents
fade over 5 pixels before the moving end only; into the points they run to the shape.

**Crystal.** The fill's gradient lifted towards white (22-28% and 45%) at 55% alpha. Over it,
per 18 pixels along the whole bar (continuous across health's halves): an upper facet lit from a
corner that alternates facet to facet and brightens and dims in turn, and a darker lower facet
lit the opposite way; a one-pixel girdle line where they meet; a glare of 8 row pieces offset from
one another so it leans, sweeping along every 3.6 seconds; five sparkles, each a 3x1 and a 1x3
cross, placed from a hash of their cycle so they move on without jumping about mid-twinkle; and
a reflection along the top.

**Tests, mutation-checked.** For both styles, at ten amounts and many moments on every bar section:
nothing crosses the band, the fill or an end's shape; both points of a full bar are lit; health's
halves both reach the middle; no controls are created once warmed up. Liquid: a glow at the moving
end that rises towards it, no surface line, no glow within 14 pixels of the point while
regenerating to 99%, the slosh, the drain. Crystal: facets alternate, a facet's light changes,
the glare leans, sparkles appear. Restoring the old upright limit at the points, removing the slope
there, keeping the glow near full, and making the glare upright each fail them.

## 57. Solid by default, no glare, and a memory audit (1.27.1)

**From the PS5.** Crystal's sweeping glare is gone. Liquid and Crystal are no longer see-through by
default: the body is the game's own alpha and the effects are at full strength, both scaled by the
**How solid** slider (100% unless moved), which now applies to these styles as it does to Square.

**Memory, measured.** `test/memory.lua` replaces the harness's stand-in controls with versions that
reuse their tables -- on a console a control write is a C call and makes no Lua garbage -- so what it
reports is the add-on's own. Before:

| loop | runs | garbage per run | per second |
| --- | --- | --- | --- |
| Watch | 1 s | 10.9 KB | 11 KB |
| Timers (skill bar) | 100 ms | 20.9 KB | 209 KB |
| Plain, Liquid | 50 ms | 80 KB | 1.6 MB |
| Plain, Crystal | 50 ms | 122 KB | 2.4 MB |

and a long fight on a stream of new targets kept **504 KB** after 133,000 of them. Four causes:

1. **`addon:Account()` built two tables on every call** -- the renamed timer modes and the list of
   defaulted groups -- and ran its whole repair each time, and it is called many times per update of
   every loop. The tables are module constants now, and the repair runs once, again only when the
   saved table or one of the tables it fills is a different table.
2. **The back row's shade built a wrapper table per slot per update** (`{ control, state }`). Kept on
   the entry now.
3. **The effect painter made closures**: two per rectangle for its row and piece helpers, one for
   every alpha ramp, soft mass or corner gradient, and a new bounds table per bar section per frame.
   The alpha is now numbers kept on the painter (`Alpha`, `Fade`, `Between`), the helpers are
   methods, and each group reuses one bounds table.
4. **A leak: `entry.gained` was never pruned.** `Prune` dropped expired targets from `entry.units`
   but left their gain times, so an effect kept alive by recasting kept one entry for every target
   it had ever touched. They go with their unit now, a moment after it (for as long as `Forget`
   still asks).

After:

| | garbage per update | kept over a long run |
| --- | --- | --- |
| every style | 3.2 KB, all of it the 1 s watch | 0.0 KB |
| a fight | 3.7 KB per cast with six effects | +0.1 KB after 20,000 new targets |

**Controls are never freed**, so the effect pool is built whole when a style is chosen: 110 pieces
per bar section, with every field the painter keeps set at once. Over 100,000 updates (about 80
minutes) the most either style used in one frame was 86, and nothing was dropped. Built lazily, the
pool crept up from 64 to 86 over that time.

**Tests.** 5000 reads of the settings make no garbage; 1200 targets hit by a recast effect leave
only the live ones held and no record of the rest; the pool is 110 and nothing is dropped; the
slider thins the body and the effects together; no glare. Building a table in `Account()`, the old
`Prune`, and ignoring the slider each fail them.

## 58. The slider did not reach the bar (1.27.2)

From the PS5: **How solid** did nothing useful for Liquid or Crystal.

What 1.27.1 scaled by the slider was the alpha in the fill's `SetGradientColors` and the effects
drawn over it. These styles keep the game's own dressing, and none of that was touched: the
background (`BgContainer`, a dark solid texture), the three frame pieces, and the gloss on each
status bar all stayed at full strength. Lowering the slider let the dark background show through the
fill -- the bar went a little darker, and nothing behind it ever showed. The tests passed because
they checked the number written into the gradient, not what stands between the player and the
scene.

1.27.2 applies the slider to the whole bar with `SetAlpha`: `BgContainer`, `FrameLeft`,
`FrameCenter`, `FrameRight`, and each status bar (which takes its gloss child with it). The fill's
gradient keeps its own alpha, so the fill is not thinned twice. The alpha is written whenever it
differs from the slider, because the client sets `bgContainer:SetAlpha(1)` itself in
`armordamage.lua` and `possession.lua`. Each control's alpha is noted before the first write and put
back when the style changes or the bars are handed back. The low-health warner is left alone. Square
and MURA-HIGE are not affected: they hide the game's dressing and thin their own rectangles.

`/pbhud plain` prints, per status bar, `alpha: bar, background, frame (slider)`.

**Tests** now check the alpha of every piece the player sees through, not the gradient: at 50% the
background, frame and status bars are all 0.5, the fill's gradient alpha is unchanged, a background
the client sets back to 1 is thinned again on the next update, everything is 1 again after a style
change, and Square leaves them alone. Taking out the new alpha writes or the restore fails them.

## 59. A flash every time a menu closed (1.27.3)

From the PS5: closing a menu, Liquid or Crystal bars flickered for a moment.

**Why.** The bars are shown by their own fragment, `PLAYER_ATTRIBUTE_BARS_FRAGMENT`, a
`ZO_HUDFadeSceneFragment`: `SHOWING` is the first frame of a 250 ms fade-in (`DEFAULT_HUD_DURATION`)
and `SHOWN` is its end. The add-on did two things wrong around it:

1. On the HUD's `HIDDEN` it **stopped the style and put the game's own look back** -- colours,
   alphas, frame, and the effect hidden.
2. It started again only on the **HUD's** `SHOWN`, after its own fade.

So every time a menu closed, the bars faded in as the game draws them, and then changed. And
whatever the amount did in the menu -- a bar regenerating to full -- arrived all at once on the
first update as a slosh and a drain.

**What 1.27.3 does.**

- Hiding **pauses**: the update loop stops and the look stays on the bars, which are hidden anyway.
  Only a change of style or the add-on being switched off takes the look away. A setting changed in
  the menu is applied straight away to the hidden bars, so they come back showing it.
- The styles drawn on the bars follow **the bars' own fragment**, and resume on its `SHOWING`, the
  first frame of the fade. The HUD fragment still drives positions and the skill bar. The same
  fragment is shown with the siege bar, where the HUD's is not, so the style now runs there too.
- On resuming, the caches of what was last written are dropped, so anything the client put back
  while the bars were hidden is written again.
- Liquid treats a gap of more than 500 ms between updates as the bars having been hidden: no slosh
  and no drain for what changed out of sight.

**Tests.** Hidden, the loop pauses and the effect, the fill's colour and the whole-bar alpha stay; a
setting changed while hidden is applied at once; the first frame of the bars' fade has the style
running; a style changed while hidden still puts the game's look back; no drain for a drop made out
of sight, while the same drop in view does leave one. Restoring on hide, resuming only on the HUD's
`SHOWN`, and dropping the gap reset each fail them.

## 60. Held back until the style is on them (1.27.4)

From the PS5, after 1.27.3: still a brief flicker coming back from a menu, and a request to keep
the bars hidden until they are drawn.

What 1.27.3 could not account for is not known -- the client may put something of its own back as
the bars show, after the add-on's first draw. Rather than guess again, the bars are held back:

- **Held** when they are hidden (the pause, §59): each of the three containers the add-on finds
  showing is set hidden.
- **Shown** once the style has been drawn on them twice with the loop running again -- the draw on
  the first frame of the bars' fade (`SHOWING`) and the next update, about 50 ms later, a fifth of
  the way through the 250 ms fade. The bars appear already in the style, partway into their own fade.
- **Failsafe**: a separate 100 ms check shows them 600 ms after the fade began, whatever happens.
- **Stop** (Standard chosen, or the add-on switched off, even in the menu) shows them at once.
- A draw made for a setting changed in the menu is not counted: it does not bring them back early.
- Only a container this add-on hid is shown again.

**Why the containers' hidden flag.** It is the one thing on these bars the client never writes:
`PLAYER_ATTRIBUTE_BARS_FRAGMENT` shows and fades the group above them (`ZO_PlayerAttribute`,
`SetHidden(false)` then an alpha animation, and its `SHOWING` callback runs before that `Show`), and
the contextual fading plays `PlayerAttributeBarAnimation` on each container's alpha. Nothing in
`playerattributebars` or the attribute visualiser sets or reads the containers' hidden state; the
modules hide only their own child overlays.

Every drawn style is held, not only Liquid and Crystal: they come back the same way. Standard is
never held.

`/pbhud plain` prints the last return: how many milliseconds into the fade the bars were shown, after
how many draws, whether the failsafe did it, and how many returns there have been.

**Tests**, mutation-checked: held on hide for Liquid, Crystal and Square; still held after the first
draw; shown after the second; the failsafe cleared; a menu-time setting does not show them; the
failsafe shows them after 600 ms and not at 300; Standard chosen or the add-on switched off in the
menu shows them; Standard is never held; a bar hidden by someone else stays hidden. No hold, revealing
on the first draw, counting menu-time draws, no failsafe, and a Stop that does not reveal each fail.

## 61. Only the outer ends come to a point (1.27.5)

From the PS5: in Liquid and Crystal, stamina's left end was drawn as a triangle rather than square.

Mine. §52 measured the taper at a pointed end and §56 drew every effect to it, but the shape was
applied to **both** ends of every single bar. Only the ends facing away from the middle of the
screen are pointed (`playerattributebars.xml`):

| | left end | right end |
| --- | --- | --- |
| health | `ZO_PlayerAttributeFrameLeftArrow` | `ZO_PlayerAttributeFrameRightArrow` |
| magicka | `ZO_PlayerAttributeFrameLeftArrow` | `ZO_PlayerAttributeFrameRight` (flat, 4 x 23; 6 x 64 on a console) |
| stamina | `ZO_PlayerAttributeFrameLeft` (flat) | `ZO_PlayerAttributeFrameRightArrow` |

So stamina's left end and magicka's right end were being cut back by half the band -- a triangle of
bare fill at the end the bar fills from, which is the end that is always full. Health was right,
because both of its ends are arrows and its halves meet flat in the middle already.

The three bars carry `pointedLeft` and `pointedRight` now, and `LiquidBounds` takes them from
there; a half of health is still flat where it meets the other half. A flat end gets no taper and
no tip inset: the effect runs to the very edge of the fill.

**Tests.** The shapes themselves are checked, and at each flat end -- just inside the top, at the
middle, and just inside the bottom of the band -- the effect must come within half a pixel of the
edge; a taper leaves the top and bottom short by half the band. Putting both ends back to pointed
fails it on magicka and stamina in both styles. The preview draws each bar's real shape too.

## 62. A pixel past the right ends (1.27.6)

From the PS5, after §61: the effect spilled slightly past magicka's flat right end and stamina's
pointed right end. Both right; neither left.

Nothing in the client's layout is asymmetric. Both pointed ends give the fill the same 9 pixels
inside a 16-wide arrow (the status bar is anchored 7 in from the container on the pointed side:
`ZO_PlayerAttributeBarAnchorLeft/Right_Gamepad_Template`), and both flat ends put the fill's edge
against the inner edge of a 6-wide flat frame piece. Nor is `Limits` asymmetric: `d + inset` on the
left, `width - d - inset` on the right.

What was asymmetric is **how a piece was placed**: one anchored corner and a size. The screen snaps
each anchored edge to a pixel, so the left edge was `snap(x0)` -- exact -- while the right edge came
out as `snap(x0) + snap(x1 - x0)`, two roundings that can add up to a pixel more than `snap(x1)`.
That can only ever overshoot to the right and down, by up to a pixel, which is what a slight spill
past the right ends looks like.

Every piece is anchored by **both** corners now -- `TOPLEFT` and `BOTTOMRIGHT`, both to the group's
top left -- so each edge is snapped once, from its own position. No piece sets a size.

**Tests.** Every shown piece, in both styles, must carry those two anchors to the group, and its
right edge must stay inside the bar once snapped at several screen scales. Going back to a corner
and a size fails the first. (The offline harness takes a control's size from two such anchors now,
as the client does.)

## 63. Measuring the spill instead of guessing at it again (1.27.7)

After §62, magicka's right end still spills a little. Two guesses have now been spent on it, so
1.27.7 ships the means to measure it rather than a third.

**What the client's own layout says.** With a container 237 wide (the normal width):

| | fill | flat frame piece | arrow |
| --- | --- | --- | --- |
| magicka | 7 in from the left, 6 in from the right | right, 6 wide, from 231 | left, 16 wide, from 0 |
| stamina | 6 in from the left, 7 in from the right | left, 6 wide | right, 16 wide |
| health | each half 7 in from its outer end | -- | both ends, 16 wide |

So the status bar's flat end sits exactly on the inner edge of the flat frame piece: there is no
overlap to draw into, and the effect drawn to the control's edge should stop exactly where the
fill does. If it still stands past what the player sees, then what the player sees ends before the
control does -- the fill's own art carrying transparent margin at that end, which no amount of
reading the client's Lua will reveal.

**So it is a measurement.** `/pbhud plain` now prints, for every bar, where the fill and the two
frame pieces really are inside their container, as offsets from its edges, and
`/pbhud plain margin <left> <right>` pulls the effect in from each end by 0-8 pixels, applied in
`Limits` on top of everything else. The number that makes the spill disappear on a PS5 is the
margin the art carries; once known it can stop being a setting.

The harness places its bars and frame pieces at those measurements now (it had every fill 7 in from
the left and no size on the frame pieces).

**How it ended.** The measurement came back from a PS5 -- magicka's container 249 wide (the
visualiser sizes a bar by its maximum, so wider than the 237 of the templates), its fill 7.4 in from
the left and 235 wide, so ending at 242.4, and its flat frame piece starting at 242.5 -- which says
the effect was stopping exactly where the fill's control does, as intended. On that build the spill
was gone: what had caused it was the corner-and-size placement of §62, and the margins were never
needed. They stay at 0, unset, as the instrument for the next time an end looks wrong.

**Tests**: each margin pulls its end in by its own number of pixels and neither pulls by default;
the command sets, mirrors one number onto both ends, and clamps; the report carries the fill and
frame placements and the margins in use. Ignoring the margins fails them.

## 64. The skill bar had the same flaw, and the bars' flicker is measured (1.27.8)

Still a slight flicker coming back to the HUD from a menu.

**The skill bar, found in the source.** It had exactly the flaw §59 took out of the attribute bars:
on the HUD's `HIDDEN`, `timers:Stop()` hid the countdowns, the other set's row and the shades, and
put the game's own countdown back to full; and it started again only on the HUD's `SHOWN`. So every
time a menu closed, the skill bar faded in without this add-on's row and with the game's countdown
showing, then changed. The skill bar is shown by its own `ACTION_BAR_FRAGMENT`, a
`ZO_HUDFadeSceneFragment` like the bars', and nothing in `actionbar.lua` re-lays it out on a show
(`ApplyStyle` runs on a platform change only).

So, as for the bars: hiding **pauses** (`timers:Pause`) and leaves everything on the hidden bar; the
timers follow `ACTION_BAR_FRAGMENT` and resume on its `SHOWING`. A setting changed in a menu keeps
them paused and brings the hidden bar up to date -- `Refresh` used to `Stop` there, because
`Wanted()` is false with the HUD down -- and only switching the skill bar's features off stops them.
`Enabled()` is the settings half of `Wanted()`.

**The attribute bars, measured.** The user's flicker is on the attribute bars, and nothing more can
be read out of the source: the client sets the bars' colours once, at start-up (`RefreshColor`), and
writes neither their anchors nor their hidden state on a show; the add-on's `Apply` on the HUD's
`SHOWN` compares anchors and writes nothing when they match. Two fixes reasoned from the source
(§59, §60) have not been enough, so `ReturnTrace.lua` records what really happens: from the bars'
fragment's `SHOWING`, every frame for 700 ms, whether the group, each bar, its frame, background,
effect or rectangle are shown, how solid the group, each bar and its fill are, whether the bars are
held back and drawn, how much of each effect is drawn, and every kind of write this add-on makes --
keeping only what changes, with the time. `/pbhud plain trace` prints it. A flicker is something
that goes and comes back, or changes after the bars are showing, and will be a line or two in it.

The trace runs only in that window and stops if the bars hide again; its lines reuse their tables.

## 65. What the first trace showed: the add-on was reading the drawn state (1.27.9)

The PS5's first `/pbhud plain trace` (Liquid, How solid 70%), and: **no flicker in Standard**. So
it is this add-on's.

The trace itself ran out of lines at +210 ms, before anything flickered, but it showed two things
the harness never had:

1. `at start: ... held back off` with every bar hidden. The hold of §60 **never engaged on a
   PS5**: by the time the fragment reports `HIDDEN` it has already hidden the group above the bars,
   and `IsHidden()` answers as drawn, parents included -- so each bar read as hidden, and `HoldBars`
   skipped it.
2. Every bar's alpha moving in step with the group's (0.00, 0.29, 0.56, 0.84), and `wrote effect
   alpha` on every update of the fade. `GetAlpha()` too answers as drawn. `EffectAlpha` compared that
   with the slider, found it different all through any fade -- the menu's, or the contextual fade of
   bars full out of combat -- and rewrote it each time; and the alpha it noted to put back on leaving
   the style could be a fade's rather than the bar's own.

The client's own code says which is which: it reads `IsControlHidden()` and `GetControlAlpha()`
where it means the control alone (`ZO_HUDFadeSceneFragment:Show` checks `IsControlHidden`). The
harness's stand-ins answered for the control alone through both pairs, which is why neither showed.

**1.27.9** reads a control's own state through `addon.OwnHidden` and `addon.OwnAlpha` -- in the hold,
in `EffectAlpha`, in the game countdown's dimming on the skill bar, and for the companion's ultimate
(which, with the whole bar hidden behind a menu, read as absent). The harness now answers
`IsHidden`/`GetAlpha` as drawn and `IsControlHidden`/`GetControlAlpha` for the control alone, as the
client does; two older tests that meant "this add-on did not hide its own effect" now say so.

The trace records each control's own state too -- as drawn, every bar just retold the group's fade,
which is what used up the lines -- for 1200 ms and 64 lines, enough for the fade, the fragment's
`SHOWN` and the HUD's.

**Tests** reproduce the PS5's order -- the group hidden before `HIDDEN`, shown at alpha 0 before
`SHOWING` -- and check the bars are held, released after the second draw, have no alpha rewritten
through the fade, and get their own alpha back on leaving a style chosen mid-fade. Reading the drawn
state in either place fails them.

Whether these were the flicker is for the PS5 to say: they are what the trace showed to be wrong.

## 66. The effect ran ahead of the fill (1.27.10)

The second PS5 trace (1.27.9) showed the fixes of §65 working -- `held back on` at the start,
released at +57 ms, and no alpha rewritten through the fade -- and still a flicker. Nothing the trace
watched changed after the bars appeared: no control went or came back, no alpha moved but the
group's fade. So what flickered was *what is drawn*, not whether it is.

The one thing that moves on its own on the way back is the game's fill. The client never jumps a
status bar to a new amount: `ZO_PlayerAttributeBar:UpdateStatusBar` calls
`ZO_StatusBar_SmoothTransition`, which plays an animation that walks the bar there with `SetValue`.
Liquid and Crystal drew their effect from `GetUnitPower` -- the amount itself -- so after any change
the effect stood out past the fill until the fill caught up: after a hit or a regeneration tick, a
few pixels for a moment; coming back from a menu, by everything regained there. Standard has no
effect over the fill, which is why it never showed there.

The effect styles now take how full the bar is from the fill itself (`plain:DrawnFraction`: the
first status bar's `GetValue` over `GetMinMax`; health's halves each hold half of both, so either
gives the same fraction), falling back to the amount where those cannot be read. Square and
MURA-HIGE are unchanged: they blank the game's fill and draw their own, so there is nothing to lag.

The harness's status bars now carry a value and a range, set from the amount as the client does,
and `SetBarValue` lets a test hold the fill behind the amount. The trace records each bar's drawn
fill and its amount, so if this was not the flicker, the next trace says so.

**Tests**: with the amount regained to full and the fill shown at 40% and then 60%, nothing of either
style's liquid stands past the fill, and once the fill catches up it reaches the end. Drawing from
the amount fails all four.

## 67. Taking Liquid apart to find the flicker (1.27.11)

The third PS5 trace (1.27.10): the bars were full when they came back -- `fill drawn 1.00`,
`amount 1.00` -- so §66's lag was not this flicker (it is still a real mismatch, and stays fixed).
And again nothing the trace watches changed once the bars were showing: no control went or came
back, no alpha moved but the group's fade, the fill did not move. Liquid flickers; Standard does
not.

So it is in what is drawn -- the colours written into the fill, the effect's pieces, the numbers'
tier -- which no trace can see, and three fixes reasoned from the source have not found it. Rather
than a fourth, 1.27.11 can take Liquid and Crystal apart on the PS5, one part at a time, for the
session only:

| part | what goes |
| --- | --- |
| `hold` | holding the bars back until drawn (§60) |
| `colour` | the colours written into the game's fill |
| `alpha` | the How solid alpha on the bar's pieces |
| `numbers` | lifting the resource numbers over the effect |
| `effect` | every piece drawn over the fill |
| `shade`, `current`, `bubble`, `glow`, `drain`, `glass` | one kind of Liquid's pieces |
| `facet`, `pavilion`, `girdle`, `sparkle` | one kind of Crystal's |

`/pbhud plain test <part> off`, `... on`, `... reset`. A change starts the style over, so whatever
the part had written is put back before it runs without it. The trace's heading names the parts that
were off. The part whose absence takes the flicker away is the answer; if `effect off` does it, the
piece kinds then narrow it further.

## 68. Stable slots and no re-anchoring: tried in 1.27.12, withdrawn in 1.27.13

The switches of §67 on a PS5: the flicker stopped only with `current`, `glass` and `shade` all off --
each of the wide piece kinds flickers on its own -- and `bubble` made no difference. The flicker is
on, off, on in quick succession. It is not the pool running out: at a PS5's bar sizes the most any
bar section used was 69 of 110, none dropped.

1.27.12 took the one thing the three share as the cause -- every update each piece was cleared and
re-anchored and recoloured, and handed out from the pool in order -- and gave each kind slots of its
own, anchored each piece once and then moved it with `SetAnchorOffsets` (a luaindex in
`ESOUIDocumentation.txt`), and wrote colours, levels and visibility only when they changed.

On the PS5 it **still flickered**, and **the look changed**, though the offline preview drew the same.
So two things are now measured, not reasoned:

- the flicker does not come from rewriting the pieces: with the shade and glass written once and left
  alone, they still flickered;
- something in that painter behaves differently on a console from the documentation and the harness
  -- `SetAnchorOffsets`, or vertex colours set once and assumed to stay. Which, is not known.

1.27.13 is 1.27.11's code again, byte for byte (`Plain.lua` and every other add-on file), under a new
version number. What remains true: the wide pieces of Liquid flicker on the way back from a menu, the
narrow ones do not, and it is not the add-on writing to them.

## 69. Not drawing the style while the bars fade in: two ways to compare (1.27.14)

What §67 and §68 leave: Liquid's wide pieces flicker on the way back from a menu, the narrow ones do
not, and it is not the add-on writing to them. What is left that is particular to the way back is
the fade itself -- 250 ms of the group above the bars at partial alpha, with wide translucent
textures at another draw tier inside it.

So the style can be kept from being seen during the fade, in either of two ways, switched on for the
session with `/pbhud plain test <mode> on` to be compared on a PS5 before one is made the default:

- **wait** -- the bars stay held (§60) through the whole fade, and are shown, already drawn, when the
  bars' fragment reports `SHOWN`. They appear at full strength rather than fading in. The 600 ms
  failsafe still stands.
- **late** -- the bars fade in as they do now, and the effect over the fill is drawn but kept hidden
  until the fade ends. The fill and frame fade in; the liquid appears when the fade is done.

`plain.fadeDone` is false from the bars' fragment's `SHOWING` until its `SHOWN` (or `HIDDEN`), set
before anything is drawn for that state. With neither mode on, drawing is 1.27.11's. The trace's
heading names the modes on.

**Tests**: without a mode, the bars show part-way into the fade; with `wait` they are held through it,
shown with the effect drawn the moment it ends, and the failsafe still works; with `late` the bars
show during the fade but the effect does not until it ends, and then stays. Ignoring either mode
fails them.

## 70. Late it is (1.27.15)

On the PS5 both modes of §69 stopped the flicker. **late** looked more natural -- the bars fade in as
the game does it, and the liquid appears as the fade ends -- and is how it is done from 1.27.15:
through the fade the effect over the fill is drawn, so it is ready, and kept out of sight
(`not plain.fadeDone`); at the bars' fragment's `SHOWN` the next draw shows it. **wait** and the two
mode switches are gone. The per-part switches of §67 stay, as the means to find the next thing.

So, of the flicker, what is measured: Liquid's and Crystal's wide pieces flicker on a PS5 while the
group above them is fading in, and not once it has finished; nothing the add-on wrote caused it; and
not showing them during the fade stops it. Why the console draws them so during a fade is not known.

## 71. Renamed PB's ResourceAndSkillBarCustomizer (1.27.16)

The name shown is now **PB's ResourceAndSkillBarCustomizer** -- in the manifest's `## Title`, the
settings panel and the chat lines (`DISPLAY_NAME` in Main.lua), the README and the store copy.
Everything that identifies the add-on keeps the old name on purpose: the folder and the manifest
file (`PBsConsoleHudCustomizer`), `addon.name`, the saved variables (`PBsConsoleHudCustomizer_Data`),
the global table and every control name. Changing those makes it another add-on to the game -- a new
install, every setting gone -- for no gain. The slash commands stay `/pbhud` and `/pbhc`.

The in-game add-on browser shows the uploader's name field, not `## Title` (LISTING.md), so that field
has to be changed by hand on the uploader.

---

## Still to measure on a PS5

1. **Does writing the anchor work?** `SetAnchor` and `ClearAnchors` are marked
   `protected-attributes` in the API dump. PC add-ons re-anchor client controls routinely, and PB's
   ChatWindowCustomizer re-anchors a client top-level, but this is the first PB's add-on to
   re-anchor a client control *away from its own parent*. Move one slider, go back to the HUD and
   run `/pbhud status`: the bar's `anchor:` line must read `CENTER -> GuiRoot BOTTOM` with the new
   offsets, its `middle=` must match the settings, and there must be no `refused` line. If there
   is one, it names what was refused and why.
2. **Where does `SetScale` scale from?** `status` prints each bar's on-screen rectangle and the
   middle worked back out of it. At 150% the `middle=` must still equal the settings; if it has
   drifted by a quarter of the bar, the pivot is the control's top left and the anchor needs an
   offset of `(scale - 1) * size / 2`.
3. **Is the size really the whole bar?** At 200%, the frame arrows, the background and the
   resource numbers must all grow with the bar — nothing left at its old size, nothing clipped.
4. **Does the fade still work?** With "fade out of combat" on in Settings > Interface, a moved bar
   must still fade out with the other two, and still come back on damage. That is the check that
   re-anchoring did not take the container out of the HUD fragment's reach.
5. **Do the companions still line up?** Mount up (mount stamina under stamina), and at a scale
   other than 100%: the small bar must sit against its partner, not overlap it or float away.
6. **Does a buff still look right?** Eat a meal that raises maximum health. The bar must grow
   evenly both ways from where it was put and stay there, and `status` must still show the
   settings' `middle=`.
7. **Does the measurement come out right?** On a fresh install, before touching anything,
   `status` must show `game's: x=0 y=137 (measured)` for health and ±388/389 for the other two,
   and `differs=false written=false` on all three.
8. **Is the preview drawn above the settings panel?** It is `DL_OVERLAY` / `DT_HIGH`. If it is
   hidden behind the panel, that is the only thing to change.
9. **Does the skill bar move and scale?** Same two questions as 1 and 2, for `ZO_ActionBar1`:
   `/pbhud status` must show `CENTER -> GuiRoot BOTTOM` with the new offsets and no `refused`
   line, and at 80% the ultimate, the quickslot and the weapon swap marker must all come with it.
10. **Does the back row line up?** It is anchored `BOTTOM` on each button's `TOP`. Check the
    ultimate (slot 8, a taller button) sits level with the other five, that the row follows the
    bar when the bar is moved and scaled, and that swapping weapons swaps what it shows.
11. **Are the countdowns the same number the game shows?** Turn the game's own action bar timers
    on, set this add-on's countdown to Always, and cast a damage-over-time ability: the two
    numbers on the front bar must agree. Then swap weapons -- the number must carry on counting
    down on the row, which is the half the game does not draw.
12. **Is the target count right?** Hit three enemies with one damage-over-time ability: the icon
    must read 3, and fall to 2 as the first one dies or the effect drops. A self-buff must read 1
    and not the size of the group. If nothing is written at all, `/pbhud slots` says whether the
    effect is being tracked and under what name -- the name on the left of each slot has to
    appear in the tracked list, and on a Japanese client both are Japanese, so a mismatch there
    is the answer.
13. **Do the gaps come out right?** `/pbhud status` prints the three measured gaps next to the
    three in use. On a PS5 the measured ones should read 10 / 65 / (5 + the marker's width + 10);
    if the item one comes out at 5, the quickslot is not where this add-on thinks it is. Then
    pull all three in and check the row still reads left to right with no overlap, that the
    ultimate and the item are still hittable, and that the back bar row follows.
14. **And with a companion out?** Summon one: its ultimate appears between the item and the
    abilities, and both gaps on that side must take the item setting without the row jumping.
15. **Does the row go away with the Oakensoul Ring on?** Equip it: the back bar must disappear
    on its own and the setting must still say it is on. Take it off and it must come back.
    `/pbhud slots` prints `weapon swap available=false (locked)` while it is on.
16. **Does the text size actually bite?** `/pbhud slots` prints `h=` for each front label, the
    font height the client made of our descriptor. Move the countdown size slider and run it
    again: if `h=` does not move, `$(GAMEPAD_BOLD_FONT)|<n>|thick-outline` is not being
    understood and the face has to change. With the game's own action bar timers on, the default
    mode must also leave exactly one number on the icon, ours.
17. **Is the text legible over the icons?** The labels are `thick-outline` at the chosen size,
    the countdown gold and the count white, over the game's own icon art.
18. **Does the whole lot still fade out of combat?** The labels and the row are children of the
    action bar's buttons, so they should fade with it. If they stay solid over a faded bar, the
    parenting is wrong.
19. **Does the preview come and go with the panel?** Open the panel (the three outlines must
   appear straight away), back out to the list and open it again (they must appear again), open
   another add-on's panel (they must not), and leave with the menu button straight to the HUD
   (they must go). `/pbhud preview` on the HUD draws them over the real bars, which is the
   quickest way to see that the two agree.
20. **Do aimed abilities count from the placement now?** Cast Scalding Rune or Caltrops: nothing
    must appear on the icon while the circle is up, and the countdown must start as it lands,
    full length. Hold the circle for a few seconds before placing it -- the countdown must still
    be full length, not short by the time spent aiming. Cancel one with ○ -- the icon must stay
    empty, and the ability ○ casts instead must count as it always did. `/pbhud slots` prints
    `circles held / placed / cancelled / given up on`: given-up-on should stay 0.
21. **Does Liquid cover the whole bar and stay inside it?** Choose Liquid with all three bars
    part-empty (in a fight). Health must show the effect on both halves and straight across the
    middle; magicka and stamina along everything that is filled, not just the middle. Nothing may
    show above or below the coloured band or past the pointed ends. `/pbhud plain` must read
    `control 224x64` (or `111x64` for a health half); if it reads another height, the band is
    worked out from the container and should still be right, but that is the number to report.
22. **Does Liquid read as liquid on the HUD?** In a fight: the surface at the end of each bar should
    shimmer and visibly slosh when you take a hit or drink a potion, the trace of lost health should
    drain away behind it, the soft currents should be visible without being busy, and the liquid
    should be see-through without looking washed out. If the masses
    look like flat blocks rather than soft glows, per-corner colours (`SetVertexColors`) are not doing
    what they do on PC, and that is the thing to report.
23. **Do Liquid and Crystal fill the points, and stay inside them?** With a bar full, the effect
    must reach into both triangular ends without touching the frame's line. Spend some magicka
    and let it come back: nothing may flicker at the point as it refills.
24. **Does Crystal read as crystal?** Alternating lit and shaded facets along the bar, a bright
    line through it and small twinkling crosses, with no glare sweeping across. If the facets
    look like flat stripes, per-corner colours are the thing to report, as in 22.
25. **Does memory stay flat?** Choose Liquid or Crystal and fight for a while with an add-on memory
    readout open: after the first seconds the add-on's figure must not climb.
26. **Does How solid see-through Liquid and Crystal?** At 50% the whole bar -- background, frame and
    fill -- must let the scene behind show through, and the effects must thin with it. `/pbhud plain`
    must read `alpha: bar 0.50, background 0.50, frame 0.50`. If it reads 0.50 but the bar still looks
    solid, the client is not honouring `SetAlpha` on these controls, and that is the thing to report.
27. **Do the ends stop exactly at the bar?** Look closely at magicka's right end and stamina's right
    end: nothing of the effect may stand outside the frame, at any bar size or screen scale.
28. **Are the flat ends square?** Stamina's left end and magicka's right end are flat, not pointed:
    the effect must fill them squarely, right to the edge, while the outer ends still follow their
    arrow.
29. **Do the bars come back from a menu without a flash?** Open and close the main menu a few times,
    with a bar part-empty and with it regenerating: the bars must appear already in the style, with
    no glimpse of the game's own look. `/pbhud plain` then reads `last return from a menu: bars shown
    ~50 ms into the fade, after 2 draw(s)`. If it still flickers, send that line: "by the failsafe", or
    a time far from 50, says the loop did not run as expected; a normal line says the flicker comes
    after the bars are shown, and that is the next thing to look at.
30. **Is the flicker gone, and if not, what do the bars do coming back from a menu?** Open and close the main menu once, then run
    `/pbhud plain trace` and send the whole of it. Then set the style to Standard, do the same, and
    say whether the flicker is there in Standard too: if it is, it is the game's, not this add-on's.
31. **Do the bars come back cleanly?** With Liquid or Crystal, open and close the menu a few times:
    the bars fade in, and the liquid or crystal appears as the fade ends, with no flicker.
