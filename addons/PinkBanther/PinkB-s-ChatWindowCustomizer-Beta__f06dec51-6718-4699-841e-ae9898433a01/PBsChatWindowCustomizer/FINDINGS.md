# Findings

What the client's own source says about the console chat window, and why the add-on is built the
way it is. Everything here is **from source** (`esoui/esoui`, branch `live`, API 101050) unless
it says it was measured; the list at the end is what still has to be looked at on a PS5.

## 1. The HUD chat is one top-level control

On console, `ZO_ChatSystem_DoesPlatformUseGamepadChatSystem()` is true and the HUD chat is
`GAMEPAD_CHAT_SYSTEM`, a `ZO_GamepadChatSystem` built on the top-level control
`ZO_GamepadTextChat` (`gamepadchatsystem.xml`). That control is also the chat's primary
container (`SharedChatSystem:LoadChatFromSettings` passes `self.control` to the container), and
everything visible hangs off it:

- the message area, `$(parent)WindowContainer`, is anchored `TOPLEFT` to the control and
  `BOTTOMRIGHT` to the input line (`GamepadChatContainer:SetAsPrimary`);
- the input line, `$(parent)TextEntry`, is anchored to the control's bottom, 13 up, 37 in from
  the right, 30 high;
- the background, `$(parent)Bg`, is anchored to the control, 10 out to the left and 25 above.

So the control's anchor and dimensions are the whole window's position and size. Nothing else in
the UI is anchored to it — `ZO_GamepadTextChat` appears nowhere outside the chat's own files.

## 2. Where the game puts it, and when

`GamepadChatContainer:LoadSettings`:

```lua
self.control:ClearAnchors()
self.control:SetAnchor(BOTTOMRIGHT, nil, BOTTOMRIGHT, 0, -215)
self.control:SetDimensions(490, 280)
```

It runs once, from `CreateChatContainer`, when the chat loads on its own
`EVENT_PLAYER_ACTIVATED` (after `ZO_Ingame`'s saved variables are ready). The only other caller
is `ResetContainerPositionAndSize`, reached from the keyboard chat options. Later zone loads call
`RedockContainersToPrimary`, which only moves tabs between containers. So once the add-on has
written the anchor, nothing in the client puts it back during a session.

Before the chat has loaded, the control still has the XML template's 350 × 155 and no anchor.
That is why the add-on waits for `GAMEPAD_CHAT_SYSTEM.loaded` before reading or writing
anything, and retries for a few seconds if the chat is late.

## 3. The size limits are recomputed from four fields

`SharedChatContainer:CalculateConstraints` runs from `PerformLayout`, whenever the tabs are laid
out:

```lua
local minWidth = zo_max(width, self.system.minContainerWidth)       -- 300
local maxWidth = zo_max(width + 70, self.system.maxContainerWidth)  -- 550
self.control:SetDimensionConstraints(minWidth, self.system.minContainerHeight,  -- 170
                                     maxWidth, self.system.maxContainerHeight)  -- 380
```

Setting the constraints alone would last only until the next tab layout. The four fields are
plain data on the chat system, so they are written too, and the game's own recomputation then
arrives at our limits. They are restored with everything else.

## 4. The text size setting, and `$(GP_n)`

The chat's font is built in `SharedChatContainer:GetChatFontFormatString`:

```lua
local face = self:GetChatFont():GetFontInfo()          -- ZoFontGamepadChat
local shadowStyle = fontSize <= 14 and "soft-shadow-thin" or "soft-shadow-thick"
local fontSizeString = self.system:GetFontSizeString(fontSize)  -- "$(GP_%d)"
```

`fontSize` is `GetGamepadChatFontSize()`, the Small / Medium / Large setting
(`GAMEPAD_CHAT_TEXT_SIZE_SETTING_*`). Changing that setting calls
`GAMEPAD_CHAT_SYSTEM:SetFontSize(value)`, which re-sets the font on each tab's `TextBuffer` —
but only on tabs whose `window.fontSize` differs from the new value. The game never touches the
buffer's font otherwise.

`$(GP_20)` is not 20. The `GP_*` strings are defined per language in `fontstrings/`: identical
on the western client, and on the Japanese client `GP_18`=14, `GP_20`=15, `GP_22`=17, `GP_25`=20.
There is no API to evaluate one, and `TextBufferControl` has no `GetFontSize`. So the game's
real size is read off a hidden label of the add-on's own, given exactly the game's descriptor,
with `LabelControl:GetFontSize()`. That is the same font the chat already has, so the
measurement builds nothing.

The setting has no event. The add-on remembers the setting value its font was applied for, and
compares on every HUD show (`HUD_FRAGMENT` → `SCENE_FRAGMENT_SHOWN`); if the player changed the
setting in the meantime, the game has just put its own font back, and ours goes on again.

## 5. The input line is left alone

`TextEntry:SetFont` sets the edit box and the channel label, and the game's `SetFontSize` does
change both. But the input line is a fixed 30 high (`ZO_ChatWindowTopLevelTemplate`) inside a
`ZO_SingleLineEditBackdrop_Gamepad`; text larger than the game's would be clipped. Only the
message buffers are changed.

## 6. Why nothing is hooked

The rule from PB's MailerExtension (measured on PS5): a client closure created while an add-on
frame is on the stack is permanently untrusted, and fails the moment it reaches a private
function. The chat is the worst place to risk that — sending a message, the virtual keyboard,
`StartTextEntry` (which itself calls `SetSetting`) all run client closures.

So the add-on never wraps a chat method and never calls one. Everything is a write to a control
or a field:

| | written | the game's own equivalent |
| --- | --- | --- |
| position | `ClearAnchors` / `SetAnchor` on `ZO_GamepadTextChat` | `LoadSettings` |
| size | `SetDimensions` | `LoadSettings` |
| limits | `SetDimensionConstraints`, and `min/maxContainerWidth/Height` | `CalculateConstraints` |
| text | `SetFont` on each `window.buffer` | `SharedChatContainer:SetFontSize` |

The one registration is a `"StateChange"` callback on `HUD_FRAGMENT`: our function is stored
beside the client's, nothing of theirs is wrapped.

The preview is built entirely from controls of the add-on's own. Showing the real chat in the
menu would mean calling its `Maximize` and fade animations from add-on code.

## 6b. When the settings panel is actually open

**Found on PS5 in 1.0.0, confirmed in the library's source** (`votan73/ESO`,
`LibHarvensAddonSettings/Console/Settings.lua` and `Main.lua`). 1.0.0 showed the preview on
`LibHarvensAddonSettings_AddonSelected`, and on console it never appeared until the preview
checkbox was switched off and on again. The add-on list opens a panel in two steps:

```lua
addon:Select()                                      -- fires AddonSelected, then sets .selected
SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  -- and only then shows the panel
```

So the callback arrives while the add-on *list* is still the current scene. The preview noted
that scene, and hid itself a quarter of a second later when it saw the scene had changed to the
panel. The checkbox worked because it runs inside the panel scene. And `Select()` returns early
for the add-on already selected, so a second visit to the same panel fires no callback at all.

From 1.0.1 the preview follows the library's own panel scene instead: shown with our panel
`.selected` means up, hiding means down. The scene is created when the main menu first opens
(`LibHarvensAddonSettings:Initialize`, from `MAIN_MENU_GAMEPAD_SCENE`), after every add-on has
loaded, so it is looked up on the first `AddonSelected` -- which always comes before the first
time the scene is shown -- and its `"StateChange"` registered then. The PC copy of the library
has no such scene and shows panels in place, so there the callback still shows the preview at
once.

The test harness now opens panels in that same order, and fails on 1.0.0.

## 7. Cost on console

Moving and resizing a control costs nothing lasting. A text size the client has not drawn
before makes it build one font — `.slug` vector text, so no atlas, but still charged to the
100 MB pool console add-ons share. At most one descriptor of ours is ever in play, the preview
uses the same one, and while the size equals the game's the add-on writes the game's own
descriptor or nothing at all.

## 8. The 20-second minimise, and the one function worth calling

`ZO_GAMEPAD_CHAT_SYSTEM_SECONDS_VISIBLE_UNPINNED` is 20. The chat control's `OnUpdate`
(`ZO_GamepadChatSystem:Initialize`) compares `GetFrameTimeSeconds()` with a **file-local**
`g_expirationTime` and, past it, calls `GamepadChatContainer:HandleVisibleTimeExpired` ->
`ZO_GamepadChatSystem:Minimize`, which fades the background and the input line to nothing, hides
the input box and channel name, and hides the message area.

That expiry is written in exactly one place:

```lua
function ZO_GamepadChatSystem:StartVisibilityTimer()
    local secondsToExpire = ZO_GAMEPAD_CHAT_SYSTEM_SECONDS_VISIBLE_UNPINNED
    g_expirationTime = GetFrameTimeSeconds() + secondsToExpire
end
```

One assignment, no closure created, nothing shown or built -- so calling it does not put an
add-on frame anywhere that matters (§6), and it is the only way to reach a file-local. Pushed
every ten seconds against a twenty-second expiry, the client's `Minimize` never runs.

A minimise that already happened -- at login (`LoadChatFromSettings` ends with `Minimize`), or
from a menu -- is undone with control writes: the message area shown, and the background's alpha
put back to 1, stopping the `ZO_AlphaAnimation` first if it is still fading. `chat.isMinimized`
is set to false as data so the client agrees with what is on screen: `MINIMIZE_CHAT_FRAGMENT`
reads it when a menu opens and maximises again on the way out, and
`ZO_GamepadChatSystem:StartNewChatNotification` is only for a window that cannot be seen.

The input line is deliberately left as the game has it.

Switching the option off pushes the expiry one last time rather than minimising the window here,
so the client's own timer minimises it in its own way.

Things that turn out not to need handling: `GamepadChatContainer:FadeOutLines`,
`ZO_GamepadChatSystem:FadeOutWindowContainers` and `SetPinnedAndFaded` have **no callers
anywhere in esoui**, and nothing listens for `GamepadChatSystemActiveOnScreen`. Lines therefore
never fade on their own.

## 8b. The chat is drawn on the HUD and nowhere else

`ZO_GamepadChatSystem:IsHidden` answers hidden unless `HUD_FRAGMENT:IsShowing()` (and the
player's `UI_SETTING_GAMEPAD_CHAT_HUD_ENABLED` is on), and `SharedChatSystem:RefreshVisibility`
is the only thing that turns that answer into a `SetHidden`:

```lua
function SharedChatSystem:RefreshVisibility()
    self.control:SetHidden(self:IsHidden())
end
```

Its callers are few and all known: `ZO_HUDFragment:UpdateVisibility` (every scene transition, and
player death), the chat's own `OnPlayerActivated`, the gamepad-mode and keyboard-chat setting
changes, and `SetHUDEnabled`. So the control's hidden state only changes at those moments, and
writing `SetHidden(false)` after them is enough -- no polling for the common case.

Three places do it: the HUD fragment's state change (for any state other than shown, which is
the HUD going away), the scene manager's `"SceneStateChanged"` (menu to menu never touches the
HUD fragment), and `zo_callLater` 50 ms later, because `MINIMIZE_CHAT_FRAGMENT` belongs to the
same transition and nothing orders the two fragments. The ten-second push from §8 is the backstop
for anything else. Both registrations are our function stored beside the client's, nothing
wrapped.

`hudEnabled` is read but never written: a player who has switched the chat off in Settings >
Social is not meant to have a window at all, so nothing is forced there.

Switching the option off calls `RefreshVisibility` rather than copying its rule -- one
`SetHidden`, no closure, so the same reasoning as the timer in §8.

## 9. Draw order

`ZO_ChatWindowTopLevelTemplate` is `tier="MEDIUM" level="ZO_MEDIUM_TIER_KEYBOARD_CHAT_WINDOW"`,
and that constant is 30 (`commonconstants.lua`). A top-level window is drawn by tier, then by
level within the tier, so the chat sits above the HUD -- most of which is `DT_LOW` -- and below
what the client puts at `DT_HIGH`: keybind strips (100-120), tooltips (140), alerts (145),
announcements (20).

`GetDrawTier` / `GetDrawLevel` exist, so the pair is read off the control with the anchor and put
back on reset. `DT_PARENT` is not offered: it is meaningless for a top-level window.

## 10. Update 51: the chat is a customizable HUD element

**Found on a PS5 (the window wrong after a wayshrine or a dungeon, right again after opening a
menu), then read in the U51 source.** `ZO_GamepadChatSystem:Initialize` now ends with

```lua
local CONFIG =
{
    defaultAnchor = ZO_Anchor:New(ANCHOR_SETTINGS.point, nil, ANCHOR_SETTINGS.relPoint, ANCHOR_SETTINGS.x, ANCHOR_SETTINGS.y),
    isValid = function(element) ... end,
}
self.hudElement = HUD_MANAGER:RegisterGamepadElement(self.control, DISPLAY_NAME, CONFIG)
```

and `ZO_GamepadTextChat` inherits `ZO_HUDManager_Element`. The manager re-applies elements itself:

```lua
function ZO_HUDManager:PropagateSettings()
    for _, element in self:GamepadElementIterator() do
        element:RevertOffsetModifications()   -- savedAnchor:Set(self.control)
    end
end
```

`ZO_Anchor:Set` is `ClearAnchors()` plus `SetAnchor()`, and on console `GetSavedAnchor` returns
the **default** anchor -- the gamepad editor is still a TODO in the client's own comment -- so
every propagation is the game's bottom-right 490 x 280 placement. It runs on
`EVENT_SCREEN_RESIZED`, on `EVENT_GAMEPAD_PREFERRED_MODE_CHANGED`, and once on
`EVENT_ADD_ONS_LOADED`.

So an anchor written once is no longer the whole story. Two changes:

* **The element's default anchor is written instead of fought.** `ZO_Anchor` is a data object with
  `SetMyPoint` / `SetRelativePoint` / `SetOffsets` / `SetTarget`; the player's placement goes in
  there, and the client's own re-application then produces it. `element.currentAnchor` is left
  pointing at that same object, because `IsUsingDefaultAnchor` is an identity test and
  `ZO_HUDTracker_Manager:OnAnchorStateChanged` reads it to decide whether to stack the trackers
  above the chat window -- keeping it true is what makes the tracker column follow the window.
  The original values are captured first and restored on reset, like everything else.
* **Dimensions are not part of an anchor**, and the client gives no "finished" signal after a zone
  load, so the window is looked at again 250 ms, 1 s, 3 s, 6 s and 10 s after
  `EVENT_PLAYER_ACTIVATED`, and 50 ms after a resize or a mode change. Each look writes only what
  no longer matches, and records what it found -- `status` prints the last few, with how long
  after the zone load each was seen. That log is the measurement for the next round: it says
  whether the size, the position, or the element's anchor is what moves, and when.

Also new in U51, and left alone: `GamepadChatSystemStateChanged` (a callback fired on every
minimise and maximise, which would be a tidier signal than the ten-second push if it turns out to
be needed), and `GamepadChatContainer:StartDraggingTab` / `StopDraggingTab`, now no-ops
"managed through Customizable HUD".

---

## Still to measure on a PS5

1. **Does writing the anchor work?** `SetAnchor`, `ClearAnchors` and `SetDimensions` are marked
   `protected-attributes` in the API dump. PC add-ons move client controls with them routinely,
   and PB's QuestTrackerFontChanger resizes a client label, but this is the first PB's add-on to
   re-anchor a client *top-level*. Move a slider, go back to the HUD, and run
   `/pbchatwin status`: the "on screen anchor" line must show the new offsets, and there must be
   no `refused` line. If there is one, it names what was refused and why.
2. **Does the window really grow past 550 × 380?** Set the width to 800. If it stops at 550,
   the constraints are being applied from somewhere not in §3.
3. **Is the measured text size right?** With the slider untouched, `status` prints
   `default=` — on a Japanese client at Medium it should not simply equal `setting=`. Then set
   the slider one step up and one step down and check the text visibly changes by one step each
   way, with no jump at the first move.
4. **Is the preview drawn above the settings panel?** It is `DL_OVERLAY` / `DT_HIGH`. If it is
   hidden behind the panel, that is the only thing to change.
5. **Does the preview come and go with the panel?** Open the panel (it must appear straight
   away), back out to the list and open it again (it must appear again), open another add-on's
   panel (it must not), and leave with the menu button straight to the HUD (it must go). See
   §6b.
6. **Does the text survive changing Small / Medium / Large?** Set a size here, change the game's
   setting, return to the HUD. The chat must come back at the add-on's size.
7. **Does the window really stay up?** Switch on "keep the window on screen" and leave the
   character standing for a minute without a message arriving. If it minimises anyway, the
   expiry is being written from somewhere this add-on cannot see, and `/pbchatwin status` prints
   the state to say which of the two halves gave way -- `messages=` or `background alpha=`.
8. **And come back after a menu?** Open a menu and close it: the window must be up again. The
   HUD show is what puts it right.
9. **Does switching it off let the game minimise it again?** Switch off and wait 20 seconds
   without a message. It must fade as it always did.
10. **Is it up in menus, and does it go away again?** Switch on "show it in menus too", open the
   map and the inventory: the window must be there, with its messages. Switch it off and open a
   menu: it must go. If it flickers on the way in, the 50 ms re-assert is too early for this
   client.
11. **Is it readable over a menu?** This is why the draw order is there; if a gamepad panel
   covers it, "in front of the interface" is the answer.
12. **Is the window still right after a wayshrine and after a dungeon?** This is the U51 report
   (§10). If it is wrong again, run `/pbchatwin status` **without** opening any other menu first
   and send the "put right after something else wrote to the window" lines: they say what the
   window had and how long after the load it was seen, which is what decides whether the looks
   need to run later than 10 s or something else entirely is writing.
13. **Do the trackers still sit above the chat window?** The quest tracker column follows the chat
   through the element, so moving the window should move the column with it.
14. **Do the tiers do what they say?** With "in front of the interface", whatever was covering
   the chat must be behind it. `status` prints the tier and level the control really has.
