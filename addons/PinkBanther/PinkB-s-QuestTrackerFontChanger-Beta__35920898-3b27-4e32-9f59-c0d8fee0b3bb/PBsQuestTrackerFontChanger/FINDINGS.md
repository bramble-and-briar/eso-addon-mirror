# Findings

What was checked before writing the add-on, and where the answers came from. The source is
the client's own Lua, cloned from `esoui/esoui` (branch `live`) — the same repository that
ships `ESOUIDocumentation.txt`, which marks functions `private` / `protected`.

Anything marked **measured** was observed on a real client. Anything marked **from source** is
read out of the client's own Lua and has not been contradicted, but has not been seen on a
PS5 either. The distinction matters: on console a wrong guess costs a whole test round.

---

## 0. The HUD tracker rewrite (API 101051, live 2026-09-28)

**Measured**, in the sense that matters: after this update the player reported that the tracker
could no longer be moved. Everything below is **from source**, read out of the `live` branch
merged on 2026-09-28, and it accounts for that report and for two more breakages nobody had
noticed yet.

Every tracker in the top right was rebuilt on one base class and moved into one container:

- `ZO_HUDTrackers` (`hud/hudtracker_manager.xml`) is a single top-level control with a scroll
  container. `HUD_TRACKER_MANAGER:RegisterTracker(template, name)` creates each tracker in it
  with `CreateControlFromVirtual`, at file load, in priority order
  (`ZO_HUD_TRACKER_PRIORITY`: dynamic events 400, quest 500, zone story 510, timed activity 600,
  achievement 610, house information 700, …).
- `ZO_FocusedQuestTrackerPanel` is no longer a `TopLevelControl` but the name of a tracker
  created from `ZO_FocusedQuestTrackerPanel_Template`, which inherits
  `ZO_HUDTracker_Base_Template`. `ZO_Tracker` is now `ZO_HUDTracker_Base:Subclass()`; its panel
  field `trackerPanel` is gone (it is `primaryControl` / `control`).
- `HUD_TRACKER_MANAGER:RefreshLayout()` re-parents and re-anchors **every** tracker —
  `ClearAnchors`, `SetParent`, `SetAnchor(TOPRIGHT, previousControl, BOTTOMRIGHT)` — from every
  tracker's `OnShowing` / `OnHidden`, on `EVENT_PLAYER_ACTIVATED`, and on `HUD_MANAGER`'s
  `PropagateSettings` / `OffsetsChanged`. It never touches a tracker's scale.
- The Golden Pursuits panel is now `ZO_TimedActivityTracker` (`TIMED_ACTIVITY_TRACKER`), shared
  with Tamriel Tomes and a pinned achievement. `PROMOTIONAL_EVENT_TRACKER` survives only as an
  alias in `addoncompatibilityaliases_shared.lua`. Its progress is a `StatusBar` (`progressBar`)
  with a `Progress` label inside, whose font comes from
  `ZO_HUDTracker_Base_ProgressBar_{Keyboard,Gamepad}_Template`, not from the style table.
- The HUD panels' styles are now applied at `EVENT_ADD_ONS_LOADED` (plural, after every add-on)
  rather than at `ZO_Ingame`'s own load — so an add-on's `EVENT_ADD_ON_LOADED` now sees them
  **unstyled**.
- There is a customisable HUD: every tracker, and the column itself, is registered with
  `HUD_MANAGER` as a keyboard and a gamepad HUD element. But the editor is
  `hud_editor_keyboard` only, opened from the keyboard game menu ("Edit HUD (Beta)" /
  「HUD編集(Beta)」). There is no gamepad editor, and on console the saved offsets are not
  even read (section 6c).

What that did to 1.2.0:

| | cause |
| --- | --- |
| Position did nothing | `QuestPanel()` returned `tracker.trackerPanel`, now `nil`. And even with the right field, any anchor on a tracker is wiped by the next `RefreshLayout`. |
| Smaller and "off" did nothing | `ZO_Tracker:ApplyPlatformStyle(style)` now passes `style` to `ZO_HUDTracker_Base.ApplyPlatformStyle`, which reads `style.TEXT_HORIZONTAL_ALIGNMENT` unconditionally. 1.2.0 called it with no argument; the error was swallowed by `pcall`. Bigger still worked, because the pool hook styles each newly acquired label. |
| Golden Pursuits progress stopped changing | 1.2.0 styled `tracker.progressLabel`, which no longer exists, and scaled `PROGRESS_LABEL_PRIMARY_ANCHOR`, now `PROGRESS_BAR_PRIMARY_ANCHOR`. Both were skipped silently. |
| (latent) | 1.2.0 wrapped the HUD panels' `ApplyPlatformStyle` on the instance. The rewritten Golden Pursuits method re-applies its keybind button's platform template, so under that wrapper the client was building keybind controls with an add-on frame on the stack. |

Unchanged: the quest tracker's three pools and their `SetCustomAcquireBehavior`, the tree-node
spacing, `QUEST_HEADER_BASE_HEIGHT = 28`, and the house panel's labels and style keys.

---

## 1. All three trackers are Lua UI, not engine-drawn

**From source.** `esoui/ingame/zo_quest/questtracker.lua` builds the focused quest tracker out
of three `ZO_ControlPool`s of `LabelControl`s:

```lua
self.headerPool          = ZO_ControlPool:New("ZO_TrackedHeader", trackerControl, "TrackedHeader")
self.conditionPool       = ZO_ControlPool:New("ZO_QuestCondition", trackerControl, "QuestCondition")
self.stepDescriptionPool = ZO_ControlPool:New("ZO_QuestStepDescription", trackerControl, "QuestStepDescription")
```

`ZO_TrackedHeader`, `ZO_QuestCondition` and `ZO_QuestStepDescription` are `<Label>` virtuals in
`questtracker.xml`, and `LabelControl:SetFont(fontDescriptor)` is public in
`ESOUIDocumentation.txt`.

Two more panels sit under it in the same column, and both are `ZO_HUDTracker_Base` subclasses
whose labels are `<Label>`s in their own XML plus `hudtracker_base.xml`:

```lua
-- timedactivitytracker.lua      (Golden Pursuits, Tamriel Tomes, a pinned achievement)
self.progressBar     = self.container:GetNamedChild("ProgressBar")   -- text in its "Progress" child
-- houseinformationtracker.lua
self.populationLabel = control:GetNamedChild("ContainerPopulation")
self.tagsLabel       = control:GetNamedChild("ContainerTags")
-- and from ZO_HUDTracker_Base:Initialize, for both
self.headerLabel     = self.container:GetNamedChild("Header")
self.subLabel        = self.container:GetNamedChild("SubLabel")
```

The order down the screen comes from `ZO_HUD_TRACKER_PRIORITY`: `HUD_TRACKER_MANAGER` stacks
every active tracker in its column in that order, each anchored to the bottom of the one before
(section 0). Before the rewrite the same order came from a chain of top-level anchors.

Same conclusion for all three, and it is the whole difference from PB's NamePlateChanger. There the nameplate is drawn by the
engine and the only surface is `SetNameplateGamepadFont`, a *client setting* — it outlives the
session, it is re-read after every loading screen, and changing the face reloads the UI. Here
there is no setting at all: the font lives on a control, for as long as that control is alive.

Consequences, all of them things the nameplate add-on needed and this one does not:

- no UI reload on a face change,
- no captured "original" to protect, and no repair path for a capture that went wrong,
- no write budget or reload-loop defence,
- uninstalling is a complete undo.

## 2. There are eight fonts across the three, not one

**From source.** Each file keeps a constants table per platform:

| section | role | control | gamepad | keyboard |
| --- | --- | --- | --- | --- |
| quest | `questName` | `ZO_TrackedHeader` | `ZoFontGamepadBold27` | `ZoFontGameShadow` |
| quest | `questStep` | `ZO_QuestStepDescription` | `ZoFontGamepadBold22` | `ZoFontGameShadow` |
| quest | `questGoal` | `ZO_QuestCondition` | `ZoFontGamepad34` | `ZoFontGameShadow` |
| pursuit | `pursuitName` | `...ContainerHeader` | `ZoFontGamepadBold27` | `ZoFontGameShadow` |
| pursuit | `pursuitDetail` | `...SubLabel` | `ZoFontGamepad34` | `ZoFontGameShadow` |
| pursuit | `pursuitProgress` | `...ProgressBarProgress` | `ZoFontGamepadBold27` | `ZoFontWinH4` |
| house | `houseName` | `...ContainerHeader` | `ZoFontGamepadBold27` | `ZoFontGameShadow` |
| house | `houseDetail` | `...SubLabel` / `...Population` / `...Tags` | `ZoFontGamepad34` | `ZoFontGameShadow` |

Note the gamepad objective lines are **34**, larger than the 27 quest name. That is
deliberate, and it is why the quest size is three settings rather than one.

`houseDetail` is one setting for three labels because the game gives all three the same font:
`FONT_SUBLABEL`, `FONT_POPULATION` and `FONT_TAGS` are all `ZoFontGamepad34` in
`ZO_HouseInformationTracker:InitializeStyles`. One slider per font the game actually uses, no
more and no fewer.

That rule is also why the Golden Pursuits progress has its own slider. Before the rewrite it was
a label sharing `ZoFontGamepad34` with the pursuit name. Since the rewrite it is the text inside
a `StatusBar`, and its font comes from `ZO_HUDTracker_Base_ProgressBar_Gamepad_Template` /
`..._Keyboard_Template` (`ZoFontGamepadBold27` / `ZoFontWinH4`), not from the style table — a
different font, so a different slider, and its game font is named in the add-on because there
is no style field to read it from.

**Golden Pursuits is also Tamriel Tomes, and a pinned achievement.** The file used to open with
`-- TODO Tamriel Tomes: Rename file to TimedActivityTracker.lua`; the rewrite did exactly that,
and `ZO_TimedActivityTracker` fills the same controls from whichever system is being tracked, so
one section covers all of them.

Resolved in `esoui/fontdefs/`:

```xml
<Font name="ZoFontGamepadBold27" font="$(GAMEPAD_BOLD_FONT)|$(GP_27)|soft-shadow-thick"/>
<Font name="ZoFontGamepadBold22" font="$(GAMEPAD_BOLD_FONT)|$(GP_22)|soft-shadow-thick"/>
<Font name="ZoFontGamepad34"     font="$(GAMEPAD_MEDIUM_FONT)|$(GP_34)|soft-shadow-thick"/>
<Font name="ZoFontGameShadow"    font="$(BOLD_FONT)|$(KB_18)|soft-shadow-thin"/>
```

So the descriptor form to write back is `face|size|style` — the same form PB's NamePlateChanger
discovered it had to smuggle the size through, here as the client's own documented syntax.

## 3. The quest tracker: the platform style functions cannot be hooked — but the pools can

**From source.** `ApplyPlatformStyleToHeader`, `ApplyPlatformStyleToCondition` and
`ApplyPlatformStyleToStepDescription` are `local function`s in `questtracker.lua`. Nothing
exports them, so `ZO_PreHook` has nothing to attach to.

They are, however, installed on the pools:

```lua
self.headerPool:SetCustomAcquireBehavior(ApplyPlatformStyleToHeader)
```

and `ZO_ObjectPool:SetCustomAcquireBehavior` just assigns `self.customAcquireBehavior`
(`esoui/libraries/utility/zo_objectpool.lua`), which `AcquireObject` calls. The field is
readable, so the local can be captured through it and wrapped even though its name is not in
scope.

That wrapper is the whole integration:

- it runs on **every** acquire, so the labels the tracker rebuilds by itself — a step advancing,
  a condition counter changing — are styled without any polling,
- the game's own call has just run, so the label is pristine and safe to measure,
- the tracker's own `UpdateTreeView()` still runs after the rebuild, so the new text heights
  are laid out by the game rather than by us.

The two paths that bypass acquire are `ZO_Tracker:ApplyPlatformStyle()` (a gamepad/keyboard
mode change) and any label already on screen when the add-on loads. Both are handled by
walking `pool:GetActiveObjects()`.

`ApplyPlatformStyle` is also the restore path: it is the tracker's own public method for
putting the platform's named fonts back on every active label. "Off" is that call, and so is
the first half of every settings change — without it, a label would keep the larger font it was
just given and nothing would ever shrink.

## 3b. The two HUD panels: written directly, never hooked

**From source.** Nothing in `timedactivitytracker.lua` or `houseinformationtracker.lua` is
pooled. Their labels are created once with the control and live for the session, and exactly one
thing ever sets their fonts: the panel's own `ApplyPlatformStyle(style)`. `Update()`,
`Refresh()` and `RefreshListingTags()` call `SetText`, never `SetFont`.

Up to 1.2.0 that method was wrapped on the instance. Since the rewrite it is not safe to run
under an add-on frame: `ZO_TimedActivityTracker:ApplyPlatformStyle` ends with
`ZO_ApplyPlatformTemplateToControl(self.assistedKeybindButton, "ZO_KeybindButton")`, and anything
the client builds while an add-on frame is on the stack is untrusted for good — measured on PS5
in PB's MailerExtension, where it cost a working Send button.

It does not need to be wrapped. `ZO_PlatformStyle` runs it at exactly two moments:

1. **`EVENT_ADD_ONS_LOADED`**, from each panel's `DeferredInitialize` — followed by
   `EVENT_PLAYER_ACTIVATED`, where this add-on applies for the first time;
2. **a keyboard/gamepad switch** — which fires `EVENT_GAMEPAD_PREFERRED_MODE_CHANGED`, where
   this add-on applies again, deferred so the client's own handler has run.

So the labels are written directly at those two moments and whenever a setting changes. Each
label is handed back to the game's font first (read from `tracker.styles[platform][FONT_*]`, the
same table the panel reads, or for the progress text the bar's template font), then measured,
then styled. `RefreshAnchors` is still called afterwards: it only clears and re-adds the panel's
own anchors from the style table.

---

## 4. `$(GP_27)` is not 27

**From source, and the reason for the measurement.** The gamepad font sizes are written as
`$(GP_27)`, `$(GP_34)` and so on. Those substitutions are resolved by the engine, not in the
Lua — `GP_34` appears nowhere in `esoui` outside the font definitions and the tooltip styles
that quote it. There is no API to evaluate one.

So an add-on that read the *name* `ZoFontGamepadBold27` and wrote `...|27|...` back would not
be leaving the size alone; it would be setting a size that happens to share a number with the
one the game asked for, before scaling.

`LabelControl` has `GetFontSize()`, and inside the acquire wrapper it is being read off a label
the game has just styled. That is the client's real, scaled number, and it is what the sliders
start from. Recorded once per part per session and persisted, so the settings panel knows it
before any quest is tracked.

Reading it only off a pristine label is the lesson PB's NamePlateChanger learned the hard way:
it captured its own output as "the original" during a rename and needed a repair path to
recover. Here the label is pristine because the game's own styling call is what runs
immediately before ours — but that is an assumption about the client's load order, so the label
is checked as well.

The check is a fact about the string rather than about the ordering. The game always styles
with a **named font object**, `ZoFontGamepadBold27`; this add-on always writes a **descriptor**,
which by construction contains a `|`. A label whose font has a pipe in it is one of ours and is
refused — and not marked as measured either, so a later pristine label still counts. That is
the same `LooksLikeStock` test PB's NamePlateChanger applies to the nameplate descriptor, and it
is what makes the corruption unrepresentable rather than merely unlikely.

## 5. Style tokens are not the enum names

**From source.** The nameplate API took a numeric `FONT_STYLE_*`. A font descriptor takes a
token, and the two do not correspond by name — `FONT_STYLE_OUTLINE_THICK` is written
`thick-outline`, reversed.

Grepping every font descriptor in the client turns up exactly four tokens:

```
shadow  soft-shadow-thin  soft-shadow-thick  thick-outline
```

`FONT_STYLE_NORMAL`, `FONT_STYLE_OUTLINE`, `FONT_STYLE_OUTLINE_SHADOW` and
`FONT_STYLE_OUTLINE_SHADOW_THICK` exist in the enum with no corresponding token anywhere in
the client source. Guessing `outline` and `outline-shadow` would probably work, and "probably"
is not a good basis for a font build on console, so they are left out until one is measured.
"None" is offered as its own entry and is not a token at all — it writes `face|size` with no
third component.

## 6. What the quest header's fixed height does to a larger quest name

**From source.** `ApplyPlatformStyleToHeader` sizes the header control explicitly:

```lua
control:SetDimensions(constants.QUEST_LINE_HEADER_WIDTH, constants.QUEST_HEADER_BASE_HEIGHT)
```

`QUEST_HEADER_BASE_HEIGHT` is 28 in `GAMEPAD_CONSTANTS` and absent from `KEYBOARD_CONSTANTS`.
The conditions and step descriptions are given `UNCONSTRAINED_HEIGHT` (0) and size themselves
to their text.

`ZO_TreeControl:Update` stacks nodes by anchoring each control's top to the previous control's
bottom (`esoui/libraries/utility/zo_treecontrol.lua`), so the header's 28 is what separates the
quest name from the step description under it. A 40-point name in a 28-tall box would be
clipped and overlapped.

The box is therefore grown in the same proportion as the font. Proportion rather than
measurement, because at acquire time the label has no text yet and `GetTextDimensions()` would
be meaningless. Only grown, never shrunk: 28 is already generous for the game's own size, and
shrinking it would pull the whole tracker up into it.

Neither HUD panel needs any of this. `ZO_HUDTracker_Base_Template` and its `Container` are both
`resizeToFitDescendents="true"`, no label in `timedactivitytracker.xml`,
`houseinformationtracker.xml` or `hudtracker_base.xml` is given a height (only a width,
`ZO_HUD_TRACKER_MAX_WIDTH`), and every one is anchored to the bottom of the one above it. A larger font grows the panel. `RefreshAnchors()` is called after a restyle
anyway, because it is also what the tracker uses to re-place the population line when the owner
line is hidden.

## 6b. The gaps between the rows are separate numbers, in two different places

**From source.** Nothing about the line spacing is part of the font, and the two kinds of
tracker keep it in two different kinds of object.

**The quest tracker** puts it on the tree node. `questtracker.lua` carries a per-platform table

```lua
QUEST_TRACKER_TREE_LINE_SPACING = {
    [QUEST_TRACKER_TREE_HEADER] = 0,   -- 18 on keyboard
    [QUEST_TRACKER_TREE_CONDITION] = 16,
    [QUEST_TRACKER_TREE_SUBCATEGORY_TITLE] = 16,
    [QUEST_TRACKER_TREE_SUBCATEGORY_CONDITION] = 6,
}
```

and calls `treeNode:SetOffsetY(...)` from it immediately after every `AddChild`, and again in
`ApplyPlatformStyleToCondition`. `ZO_TreeControl:Update` then does
`anchor:SetOffsets(indent, node.m_OffsetY or self.m_OffsetY)`, anchoring each control's top to
the previous control's bottom. So the offset is the gap, `ZO_TreeControlNode:SetOffsetY` is
public, and `node.m_OffsetY` reads it back.

**The two HUD panels** put it on `ZO_Anchor` objects in the platform style table --
`SUBLABEL_PRIMARY_ANCHOR`, `PROGRESS_LABEL_PRIMARY_ANCHOR`, `POPULATION_*`, `TAGS_LABEL_*` --
which `RefreshAnchors` re-applies to the labels through `RefreshAnchorSetOnControl`.
`ZO_Anchor` has `GetOffsetX` / `GetOffsetY` / `SetOffsets`, all public.

Three things follow from that, and they are what the implementation is shaped around:

1. **A gap belongs to the row below it.** The offset positions the top of a control against the
   bottom of the one before, so it is set on the *later* control. The gap under the quest name
   is the step description's node, and scales with the step description's size. That is the
   game's own attachment, not a choice made here.
2. **The constants are unreachable but the values are not.** Both tables are file-local, so an
   add-on cannot read `QUEST_TRACKER_TREE_LINE_SPACING` -- but by the time either hook runs the
   number is sitting on the node or the anchor, which is a better source anyway: it survives a
   ZOS change to the constants.
3. **Both would compound.** The quest header's node offset is written once at creation and
   never reset, and `UpdateTreeView` runs many times per quest; the style table's anchors live
   for the whole session and `ApplyPlatformStyle` re-runs on every mode change. Rescaling
   whatever is there each time would multiply the gap again and again. The guard is the same
   shape as the font one: remember what was written, and treat any other value as the game's.

Only the anchors that place one row against another are touched. `TOP_LEVEL_*`, `CONTAINER_*`
and `HEADER_*` place the panel itself on the screen, and scaling those would move the panel
rather than tighten it.

## 6c. The column can be moved through its HUD element's default anchor

**From source.** Up to 1.2.0 the quest tracker was a top-level control anchored once in XML,
and moving it was a matter of anchoring it. Since the rewrite every tracker is re-anchored by
`HUD_TRACKER_MANAGER:RefreshLayout()` whenever anything shows, hides or changes (section 0), so
an anchor on a tracker cannot stick.

The column cannot be re-anchored by `RefreshLayout` — it is the thing the trackers are anchored
*in*. `ZO_HUDTrackers` is anchored in XML (`TOPRIGHT`, −15, 90) and registered as a HUD element,
and the only code that places it afterwards is:

```lua
-- ZO_HUDManager:PropagateSettings(), on EVENT_ADD_ONS_LOADED, a platform switch, a resize
for _, element in self:GamepadElementIterator() do
    element:RevertOffsetModifications()   -- GetSavedAnchor():Set(self.control)
end

function ZO_HUDManager_Element:GetSavedAnchor()
    --TODO Custom HUD: Remove this check once we build the gamepad editor
    if ZO_IsConsoleOrGameCoreUI() then
        return self.defaultAnchor
    end
    ...saved offsets from the keyboard editor, if any, else defaultAnchor
end
```

`defaultAnchor` is a `ZO_Anchor` built from the XML anchor when the element is created, one per
platform. `ZO_Anchor:SetOffsets` only writes its `data` table (`libraries/utility/zo_anchor.lua`).
So:

- **On a PS5 the column is placed by `element.defaultAnchor` and nothing else.** Changing that
  object's offsets means every placement the game makes, for any reason, puts the column where
  the player asked. This add-on writes them at `EVENT_ADD_ON_LOADED` — before
  `EVENT_ADD_ONS_LOADED`, where `HUD_MANAGER` first places anything — so the game does the moving
  at start-up, and on a settings change calls `RevertOffsetModifications()` itself (an anchor
  `Set`, nothing that builds).
- **The object is changed in place**, never replaced: `ZO_HUDTracker_Manager:OnAnchorStateChanged`
  asks `IsUsingDefaultAnchor()`, which compares `currentAnchor == defaultAnchor`, to decide
  whether the scroll area stops short of the screen bottom and the gamepad chat.
- **Nothing is written to `HUD_MANAGER`'s saved variables.** `HUD_MANAGER:SaveAnchorOffsets` would
  have been the obvious API, and on console it does nothing useful — the check above means saved
  offsets are never read. It would also have left the game's own settings changed after the
  add-on was removed.
- **On PC, the editor wins.** When the keyboard editor has saved offsets, `GetSavedAnchor()`
  returns them instead of `defaultAnchor`, and this setting has no effect. That is the right way
  round.

**The scale** is written on `FOCUSED_QUEST_TRACKER.control`. `RefreshLayout` never calls
`SetScale`, and nothing else in the tracker code does, so it stays written.

### On `protected-attributes`

`ClearAnchors`, `SetAnchor` and `SetScale` carry that marker in `ESOUIDocumentation.txt`. So do
`SetHidden`, `SetDimensions`, `SetAlpha`, `SetWidth`, `SetHeight` and `SetParent` — 33 entries in
total, and they are the functions every add-on calls on ordinary controls all day. The marker
gates controls whose *attributes* the client has protected, not the function itself; it is not
the `private` case that kills the running chunk.

That reasoning is not a measurement, though, and the documentation's markers are not an
authority on what may be called. So every call that places or scales is made from
`RequestLayout`, on its own deferred tick rather than inside a settings handler, a slash command
or start-up. If the client does refuse one, the refusal takes the position and scale with it and
leaves the fonts, the spacing and the settings panel standing.

## 7. Cost on console

The rule inherited from PB's NamePlateChanger, measured there on PS5: **size is free, face is
expensive, outline is very expensive.** ESO's fonts are `.slug` — GPU vector text, resolution
independent — so a size change has no atlas to build. A face the client has not loaded has to
be built. An outline style has to have its glyphs generated, which the game's own source puts
at about 100 MB for a CJK font, against the 100 MB pool every console add-on shares.

What is different here is that the cost is bounded and one-off. `SetFont` on a control is not
a client setting, so there is nothing to re-apply after a loading screen, no reload to pay for
twice, and no "keep the typeface after loading screens" trade-off to expose — the font is
rebuilt from the same descriptor the client already has built.

Two things keep it bounded:

- **Nothing is written while the settings match the game.** `RoleDiffers` is false for a part
  whose size still equals the measured default with the face and outline on Default, and the
  add-on then never calls `SetFont` for it at all. An untouched install builds nothing.
- **At most seven descriptors** are ever in play, one per part across the three trackers, and
  they only differ from each other by size unless a face or outline is chosen. Several collapse
  onto each other whenever the sections are left on the same settings: the game's own quest
  name, pursuit heading and house name are all `ZoFontGamepadBold27`, and the quest objectives,
  pursuit detail and house detail are all `ZoFontGamepad34`.

## 8. Not touched

- **The quest timer.** `questtimer.xml` has its own labels with fonts baked into the XML
  (`ZoFontGamepadBold27`, `ZoFontGamepad42`). It only appears on timed quests and is a separate
  piece of UI; changing it is not what "the quest tracker font" means.
- **The container padding.** `RESIZE_TO_FIT_PADDING_HEIGHT` (10 keyboard, 20 gamepad) is the
  padding around a HUD panel's contents, not a gap between its rows, so it is left alone --
  scaling it would grow the panel rather than tighten it.
- **The other HUD trackers.** `ZO_HUDTracker_Base` also has a zone story tracker, an endless
  dungeon tracker, an adventure zone tracker and a dynamic events tracker, all in the same
  column. Each would hook exactly the way Golden Pursuits and the house panel do — adding one
  is a section entry naming its global and its label fields — but none of them was asked for.
- **The text and its order.** Built from journal data by the tracker.
- **Whether the tracker is shown.** `GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_QUEST_TRACKER)`
  is readable, but `SetSetting` is private — and per the nameplate work, a private function is
  not something to call to find out: it raises a UI error and kills the running chunk, and
  `pcall` does not protect against it.

---

## Still to measure on a PS5

Everything above marked **from source** holds together, but the following would each be a
visible bug rather than a subtle one, so they are the things to look at first on a real client:

1. **Does the objective text really draw larger than the quest name?** If `/pbquest status`
   reports the three measured sizes in the ratio 27 : 22 : 34 after scaling, the constants
   table was read correctly.
2. **Does `GetFontSize()` return the scaled size?** `status` prints the measured default next
   to what is on screen; with everything on Default they must be equal, and the measured value
   should *not* be exactly 27 unless the client happens to scale by 1.
3. **Does the header box growth land correctly?** Set the quest name to 45 and check the step
   description under it is not overlapped and the name is not clipped.
4. **Is `thick-outline` survivable on the Japanese client?** This is the one setting with a
   measured precedent for crashing on console, from the nameplate work.
5. **Do the two HUD panels measure at all?** `status` reports their defaults from anywhere, not
   just while the panels are on screen. After a login they should be the scaled 27 and 34 —
   the panels are first styled at `EVENT_ADD_ONS_LOADED` and measured at the first activation.
6. **Do they grow cleanly?** Set the house details to 45 on a home tour and check the visitor
   count and the tags are not overlapping the owner line; set the pursuit name to 45 and check
   the progress bar is not overlapping it.
7. **Does the progress text sit acceptably in its bar?** The bar keeps its template size, so a
   large progress setting spills over it. Worth seeing where "acceptable" ends.
8. **Do the gaps look right at the extremes?** Set the objectives to 12 and check the lines are
   not touching; set them to 60 and check the gaps have not become a chasm. The scaling is
   linear in the size ratio, which is the obvious rule but not necessarily the prettiest one at
   the ends of the range.
9. **Does the column move?** This is the one to look at first. `/pbquest pos -200 100`, then
   `/pbquest status`: `column anchor=` should show the game's −15/90 plus the nudge, and
   `applied=` the same. If the anchor shows the nudge but the column has not moved, something
   other than `RevertOffsetModifications` is placing it — look for it before changing anything.
10. **Does it stay moved?** Zone, open and close the map, track and untrack a quest, enter a
    house. The column should not jump back at any of them.
11. **Does scaling the quest tracker leave the column tidy?** It sits in a scroll child that
    resizes to fit its children, and the trackers below anchor to its bottom. Set the scale to
    150% and check Golden Pursuits lands just under the quest tracker, not overlapping it and
    not far below it.
12. **Does the Golden Pursuits heading keep its icon aligned?** `ApplyPlatformStyle` anchors the
    icon to the left of the header label with a fixed `HEADER_ICON_SIZE` / `HEADER_ICON_OFFSET`.
    The icon is not resized here, so a much larger heading may sit taller than its 48-point
    icon. That is cosmetic, but worth a look before deciding it is fine.
