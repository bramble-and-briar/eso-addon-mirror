# PB's FurnitureEditor — findings

Read from `ESOUIDocumentation.txt` (API 101051, `esoui/esoui` branch `live`) and the client's own
Lua before any code was written. Sections 1-3 are source evidence. Section 4 is the design that
follows from it, section 5 says what the offline tests prove and what they cannot, and section 6
is the list of things only a console can settle — each with the command that settles it.

**Nothing in this directory has run on a console yet.** The code is complete enough to copy and
paste a link group, travelling to the target house first, against a stub client (416 checks,
`test/run.lua`); whether the real client
behaves like the stub is the first session's whole job.

## 1. What the API gives us, and it is all public

None of the functions below carries a `*private*` marker in the documentation
(`IsPrivateFunction` reports it at run time; `/pbfe api` asks it about every call the add-on
makes).

| job | functions |
| --- | --- |
| walk a house | `GetNextPlacedHousingFurnitureId`, `GetPlacedHousingFurnitureInfo` (name, icon, `furnitureDataId`) |
| where a piece is | `HousingEditorGetFurnitureWorldPosition` (integer cm), `HousingEditorGetFurnitureOrientation` (pitch, yaw, roll, radians) |
| how big | `HousingEditorGetFurnitureLocalBounds` (metres), `HousingEditorGetFurnitureWorldBounds` (cm) |
| **the links** | `GetPlacedFurnitureParent` (nilable id64), `GetPlacedFurnitureChildren` (variable returns) |
| item or collectible | `GetPlacedFurnitureLink` (item link, collectible link: the one that is not empty says which). **Not** `GetCollectibleIdFromFurnitureId`: see section 9 |
| state | `GetPlacedHousingFurnitureCurrentObjectStateIndex`, `...NumObjectStates` |
| **place** | `HousingEditorRequestItemPlacement(bag, slot, x, y, z, pitch, yaw, roll)`, `HousingEditorRequestCollectiblePlacement(collectibleId, x, y, z, pitch, yaw, roll)` |
| **move** | `HousingEditorRequestChangePositionAndOrientation(id, x, y, z, pitch, yaw, roll)`, `...ChangePosition`, `...ChangeOrientation` |
| **link** | `HousingEditorRequestSetFurnitureParent(childId, parentId)`, `HousingEditorRequestClearFurnitureParent(id)` |
| take back | `HousingEditorRequestRemoveFurniture(id)`, `HousingEditorSetRetrieveToBag(bag)` |
| state | `HousingEditorRequestChangeState(id, stateIndex)` |
| in the bags | `GetBagSize`, `HasItemInSlot`, `IsItemPlaceableFurniture`, `GetItemFurnitureDataId`, `GetSlotStackSize`, `IsItemStolen` |
| limits | `GetFurnitureDataInfo` (4th return is the limit type), `GetHouseFurnishingPlacementLimit`, `GetNumHouseFurnishingsPlaced` |
| you | `GetPlayerWorldPositionInHouse` (x, y, z, rotation), `IsOwnerOfCurrentHouse`, `HasAnyEditingPermissionsForCurrentHouse` |
| events | `EVENT_HOUSING_FURNITURE_PLACED(furnitureId, collectibleId)`, `...REMOVED`, `EVENT_HOUSING_EDITOR_REQUEST_RESULT`, `EVENT_HOUSING_EDITOR_COMMAND_RESULT` |

`GetPlayerWorldPositionInHouse` is the function the client's own housing code uses to sort
furnishings by distance from the player (`furnituremanager_shared.lua`), so it and the
furnishings share a coordinate space. (`/pbfe where` checks it on the numbers anyway.)

## 2. The calls the client itself never makes

Counting every call site in the client's Lua (`grep -rw` over the whole of `esoui/`), these have
**zero** callers:

```
HousingEditorRequestItemPlacement          HousingEditorRequestCollectiblePlacement
HousingEditorRequestChangePosition         HousingEditorRequestChangeOrientation
HousingEditorRequestChangePositionAndOrientation
HousingEditorRequestSetFurnitureParent     HousingEditorRequestClearFurnitureParent
GetPlacedFurnitureParent                   GetPlacedFurnitureChildren
GetCollectibleIdFromFurnitureId            HousingEditorRequestChangeState
HousingEditorGetFurnitureLocalBounds       HousingEditorGetFurnitureWorldBounds
```

Of those, two have already been run on a PS5: `PBsFurniturePreview` read
`HousingEditorGetFurnitureLocalBounds` and `...WorldBounds` over 143 and 202 furnishings with the
editor closed, and found local bounds are metres and world bounds are centimetres. So *reading*
a house through calls the client never makes is known to work on the console. The *write* calls
(placing, moving, linking) have not been tried.

That is the whole of what this add-on is built on, and it is the whole of the risk. The official
editor never calls them; it goes through a ghost object and the reticle (section 3). They are
public, they are documented, and the previous add-on in this family
(`PBsFurniturePreview`) found that "not marked private" is not "will obey" (`SetSetting` is
unmarked and private; the preview calls were public and ignored). Whether the console obeys
these is section 6, questions 1-4, and nothing else in this file matters until they are
answered.

## 3. How the client's own editor does the same jobs

**Placing.** `ZO_TryPlaceFurnitureFromInventorySlot` (`inventoryslot.lua`): guard
`GetCurrentZoneHouseId() ~= 0 and IsOwnerOfCurrentHouse()` (`globals.lua`) and
`IsItemPlaceableFurniture` and not `IsItemStolen`; if `GetHousingEditorMode()` is not
`SELECTION`, `HousingEditorRequestModeChange(HOUSING_EDITOR_MODE_SELECTION)`; then
`HousingEditorCreateItemFurnitureForPlacement(bag, slot)` makes a ghost the reticle drags
(or, in precision mode, `HousingEditorAdjustPrecisionEditingPosition` /
`HousingEditorAdjustSelectedObjectRotation` set it by numbers), and
`HousingEditorRequestSelectedPlacement()` commits it.

*So placement is owner-only in the client's own guard; copying from a house you merely edit is
allowed here, pasting is not.* And `HousingEditorRequestModeChange` to `PLACEMENT` from
`DISABLED` was already measured on a PS5 as result 21 (`INCORRECT_MODE`); `SELECTION` is the mode
the client itself asks for, so `SELECTION` is what a paste asks for first, then `BROWSE`.

**Which bags.** `ZO_PLACEABLE_FURNITURE_BAGS` (`furnituremanager_shared.lua`): backpack, bank,
subscriber bank, the ten house banks and the furniture vault. Not the craft bag.

**Linking.** In `SELECTION` mode, aim at a furnishing (`HousingEditorGetTargetInfo`) and
`HousingEditorBeginLinkingTargettedFurniture()` (refused when the furnishing has path nodes);
the editor goes to `LINK` mode; aim at another and the primary action runs
`HousingEditorPerformPendingLinkOperation()`. The relationship preview is
`HousingEditorGetLinkRelationshipFromSelectedChildToPendingFurniture()`
(`NO_LINK`, `LINKED_AS_CHILD`, `LINKED_TO_PARENT`, `BAD_LINK`) and a bad link's reason is
`HousingEditorGetPendingBadLinkResult()`. That flow needs a reticle target and cannot be driven
from chat, which is why `HousingEditorRequestSetFurnitureParent` matters: it takes two ids.

**What the client says when a link is refused** (`en_client.lua`, `SI_HOUSINGREQUESTRESULT*`):
cannot parent these together; cannot parent to itself; would cause an infinite loop; already the
child of this furniture; already has a parent; has no parent; no children; cannot have any more
children (a per-parent limit exists, its size is not in the API).

**Travelling.** A house is a collectible of category `COLLECTIBLE_CATEGORY_TYPE_HOUSE`; its
reference id is the `houseId` (`GetCollectibleReferenceId`), and the owned ones are the unlocked
ones (`IsCollectibleUnlocked`) — the same list the collections screen builds. The client's travel
dialog calls `RequestJumpToHouse(houseId, travelOutside)` directly after the player confirms; its
only guard is `CanJumpToHouseFromCurrentLocation()`. `/pbfe houses` lists them and
`/pbfe paste to N` calls the same function. Add-on Lua survives a zone change (it is not a UI
reload), so the half-finished command is held in memory and resumed on `EVENT_PLAYER_ACTIVATED`.
The jump lands on the doorway, where the client refuses placement ("cannot place any furnishings
by the entrance"), which is why `here ... go` does not run on arrival.

**Other results a paste has to expect:** `INCORRECT_MODE`, `REQUEST_IN_PROGRESS` ("your previous
action has not fully resolved, try again in a moment" — so the server takes one request at a
time), `INVALID_FURNITURE_POSITION` ("cannot be placed in that location"), `IN_COMBAT`,
`IS_DEAD`, `NOT_IN_HOUSE`, `PERMISSION_FAILED`, `METRICS_LIMIT_HIT` ("your system has reached its
memory capacity" — a console-specific ceiling), the four `*_PLACE_LIMIT` results, and the
"must launder that item" and "only one copy" results for stolen and unique items.
`addon.ResultText` prints the game's own sentence for any of them, in the player's language.

## 4. The design

**A copy is not a move.** Placing consumes the item from a bag. A paste needs the items in
hand: duplicates in the backpack, a bank, a house chest or the vault. The dry run (`/pbfe paste`
with no `go`) counts need against have, per furnishing kind, across all those bags, and names
the shortfall. Collectible furnishings come from no bag
(`HousingEditorRequestCollectiblePlacement`); whether a house may hold two of the same is the
server's to say, so a paste attempts it and logs the answer.

**The clipboard** is the flat list of a group's members, parent first
(`{ dataId, collectibleId, name, x, y, z, pitch, yaw, roll, state, parent = index }`), plus where
the player stood. Plain numbers and strings, so it goes into SavedVariables as it is and
survives a trip between houses and a restart. `/pbfe save|load` keeps several.

**Ids.** A furniture id is an `id64`, and two ids for one furnishing are not promised to compare
equal. Everything stored or compared goes through `Id64ToString`; the stub's ids are tables with
no `__eq`, so any `==` on an id fails the tests.

**Where things go.** Offsets from the player's position when copying (the "anchor") are applied
to the player's position when pasting (`here`, the default), or the original coordinates are kept
(`same`: a house of the same layout, or rebuilding after a clear-out). `up N` shifts the group
N cm. No coordinate-space guess is needed beyond "the player's position and the furnishings'
share one", which is §1's evidence.

**Order.** Place every furnishing first, link afterwards. A link made early would drag its
children along every time the parent is nudged into place. Each placement waits for
`EVENT_HOUSING_FURNITURE_PLACED` (the new furnishing's id is only known from it), falls back to
looking for a new furnishing of the right kind if the event never comes, then reads the piece
back and nudges it once if it landed more than 3 cm or 0.02 rad off. Each link is verified by
reading `GetPlacedFurnitureParent` until the parent shows. State (a lamp on or off) is set last.

**Pace.** One request, then `paceMs` (default 450) of quiet, then the next; `REQUEST_IN_PROGRESS`
is retried; a result that no later request would fare better against (`IN_COMBAT`,
`METRICS_LIMIT_HIT`, a placement limit) ends the run with the client's own words. Everything
placed is written to `lastPaste` before the next request, so `undo` works after a crash, a stop
or a refusal.

**Cut** (a move). A furnishing exists once, so a move cannot place first and remove after: the
item has to come out of the house into a bag before it can go into the next. `cut` is therefore the
dangerous half of a move, and is built to be undone from either end. The clipboard is complete
before the first removal (every node carries `srcKey`, its id in the house it came from) and is
marked `cut`, which `copy`, `cut`, `load` and `clear` will not overwrite without `force`. Removal is
leaf first, so no parent is removed while it still has children. Whether a furnishing is out is
read from the house (`GetPlacedHousingFurnitureInfo`), not taken from the answer, because the
answer may not come. Before it starts, the bag the editor retrieves to
(`HousingEditorGetRetrieveToBag`) is checked: free slots against the number of kinds in the clip
that have no stack there yet (an estimate; a stack's maximum is not considered). Collectible
furnishings return to no bag. A cut that stopped part way is not a state to be afraid of: `paste
same` in that house treats whatever is still standing at its original place as "still in place"
(placed again by nobody, linked as usual), and `cut resume` finishes it. A paste that places every
node and fails none clears the `cut` mark.

**Reservations.** Every placement call acts on the house the player is in, and none takes a house
id (`grep` the docs: no `HousingEditor*` or placed-furniture call has a `houseId` parameter), so a
paste cannot be sent to another house. A reservation is a clip plus the words of a paste, held in
saved variables and fired by `EVENT_PLAYER_ACTIVATED` in the right house, after the same
"furnishing count has stopped changing and the client says you own it" wait a trip uses. Several
wait at once and are worked through oldest first, one run at a time (a job starts only when no run
is going; a run that ends starts the next). The design choices that matter:
a start with `go` is announced and delayed ten seconds so a forgotten reservation cannot act
unannounced, and `stop` cancels it for the visit; "partial" reservations are never repeated, since
a second pass would place the pieces twice; a cut reservation does the removal at reservation time
and owns the only record afterwards, so it is protected from `drop` without `force`; a reservation
that could never run (`rot` with no calibration) is refused when made, not when it fires.
PC add-ons are bound by the same rule: Essential Housing Tools' own changelog describes pasting
"to your current position" and "while in Housing Editor mode", and nothing there pastes into a
house the player is not in.

**Stop** waits for the one request already in flight (it will happen whatever is said), records
it, and sends nothing after it. Otherwise a stop would leave one furnishing in the house that
`undo` did not know about — the stub test found exactly that.

## 5. Rotation, and why it is measured

Turning a group a quarter round needs every position carried round a vertical axis and every
orientation changed to match. Positions are arithmetic. An orientation is a pitch, a yaw and a
roll, and which axis each is about, which way is positive and which is applied first is nowhere
in the API. A wrong guess tilts every shelf in the copy.

So `/pbfe calib` works it out from the house you are standing in, read-only. For each placed
furnishing the client gives the box it fills before it is turned (local bounds, metres) and the
axis-aligned box around it after (world bounds, cm). Turn the local box by each of 48 candidate
conventions (six multiplication orders × the sign of each angle), move it to the position, box
it, compare. The convention the client uses is the one that keeps getting it right.

Only two facts are needed, and each is accepted only if **every** candidate that fits as well as
the best agrees on it:

* `sy`, the yaw sign: turning the group by d of yaw moves positions round the axis by `sy·d`.
* `yawOuter`: yaw is applied last of the three, so "turn the group" is just "add d to every
  yaw" whatever pitch and roll are doing. When it is false or unknown, only flat pieces (pitch =
  roll = 0) can be turned and tilted ones are reported and left out.

Without a saved result, `paste rot N` is refused outright, `force` or not. The calibrator is
tested against synthetic houses built with four different true conventions
(YXZ+, YXZ with a negative yaw sign, XYZ, ZXY) and recovers the sign and `yawOuter` of each.
**What this does not test** is whether the client's local bounds are what the calibrator thinks
they are (relative to the position, not the centre); `calib` prints the no-rotation error as a
control, which should be about zero.

## 6. What only a console can settle

| # | question | settled by | if the answer is no |
| --- | --- | --- | --- |
| 1 | Does `HousingEditorRequestItemPlacement` obey an add-on, and in which editor mode? | `/pbfe probe place <slot>` | fall back to the client's own route: `HousingEditorCreateItemFurnitureForPlacement`, precision placement, `HousingEditorRequestSelectedPlacement` |
| 2 | Does `HousingEditorRequestSetFurnitureParent` link, and does the child follow its parent? | `/pbfe probe link <slot>` (needs a stack of 2) | guide the player through the client's own link flow, one pair at a time |
| 3 | Is the server's answer an event, a poll, or both; how long does it take? | the `events:` line and the millisecond figures `probe` prints | tune `paceMs` and `timeoutMs` (`/pbfe speed`) |
| 4 | Is there a per-parent child limit, and what is it? | a real paste of a wide group; the link results are listed | split wide groups |
| 5 | Do the player's position and the furnishings' share a space? | `/pbfe where`, standing beside a piece you know | add an offset, or anchor on a targeted furnishing |
| 6 | What is the client's rotation order? | `/pbfe calib` in a house with turned and tilted pieces | rotation stays off; translation still works |
| 7 | Does the console hold a large paste (memory ceiling)? | a paste of 100+ pieces | paste in batches |
| 8 | Do collectibles allow two in one house? | a paste that contains one that is already placed | nothing to do; the server's answer is logged |
| 9 | Does `RequestJumpToHouse` obey an add-on, and is the player's arrival (`EVENT_PLAYER_ACTIVATED`) seen by it? | `/pbfe paste to 2` (a dry run) | travel by hand, then paste; everything else is unchanged |
| 10 | How long does a house take to finish loading? | the "waiting for it to finish loading" gap on `paste to` | tune `FIRST_LOOK_MS` / `MAX_LOOKS` in `Travel.lua` |
| 11 | Does `HousingEditorRequestRemoveFurniture` obey an add-on, and which editor mode does it want? | `/pbfe cut 1 go` on a small group (or `probe place`, which removes) | take the furnishings out by hand, then paste |
| 12 | What happens to children when a parent is removed? | `cut` removes leaf first, so it never needs to know; `undo` after a paste shows it | none needed |
| 13 | Does the retrieved item stack with others in the backpack, and is the space estimate right? | the "free slots / needed" line of a cut preview against what actually happens | raise the estimate |
| 16 | Does `SecurePostHook` exist on the console, and do entries added by a hook after `PopulateMenu` show on the wheel? | arrive in a house with a reservation; `/pbfe menu` | the commands do the same; nothing else is lost |
| 17 | Is the borrowed slot number drawn without error, and is the name shown when the entry is highlighted? | the wheel after arrival | pick another slot, or draw the name differently |
| 18 | Is `UTILITY_WHEEL_GAMEPAD` the object that opens on the console (with and without togglable wheels)? | `/pbfe menu` says "hook: installed"; hold the button | hook the other object too |
| 14 | Does `EVENT_PLAYER_ACTIVATED` fire for every way into a house (door, travel, login inside, UI reload), and does `IsOwnerOfCurrentHouse` read true in time? | enter a house that has a reservation by each route | adjust the wait in `Travel.lua`, or run reservations by hand |
| 15 | Is the inside of a house told from its outside by anything an add-on can read? | not settled; a reservation fires on either door | compare `GetUnitWorldPosition`'s zone id with `GetHouseZoneId(houseId)` |

**A first session, in order** (every step before 4 changes nothing in the house):

1. `/pbfe api` — expect "everything this add-on calls exists and is public".
2. In a house you own: `/pbfe state`, `/pbfe list`, `/pbfe where`, `/pbfe calib`.
3. `/pbfe items` to find a slot holding two or more of something cheap.
4. `/pbfe probe place <slot>` — places one at your feet, reads it back, takes it away.
5. `/pbfe probe link <slot>` — two of them, link, move the parent, unlink, take both away.
6. If 4 and 5 say WORKS: `/pbfe copy 1`, go to the other house, `/pbfe paste`, then
   `/pbfe paste go` for a *small* group first.

Whatever 4 and 5 print, in chat, is the next section of this file.

## 7. House rules this add-on works under

Add-on Lua is insecure code, and a tainted closure kills a feature that never touched it. So no
`ZO_PreHook`/`ZO_PostHook` on client functions (the one exception, and the only hook in this add-on,
is `SecurePostHook` on the quickslot wheel, section 10), nothing that calls client Lua which builds a
screen, and every client call is a C API function made through `pcall`. The one exception to
"never touch the client's objects" is `CHAT_ROUTER:AddSystemMessage`, which the sibling add-ons
already use.

Copying is limited to houses the player can edit. Reading a stranger's house works for a visitor
too, but a link tree is somebody's evening of work, and the point here is moving your own builds
between your own houses. Pasting and cutting are limited to houses you own: pasting is the client's own guard, and a cut
removes things from a house, which only its owner should be able to ask of it.

## 8. Not in this version

* **Path data** (furniture that follows a path): the furnishing is copied, the path is not, and
  the copy says so. The API has `HousingEditorRequestInsertPathNode` and friends; a later build.
* **A settings panel** (`LibHarvensAddonSettings`, as the sibling add-ons use) so a paste does not
  have to be typed with the on-screen keyboard. Worth doing once section 6 has answers.
* **Turning by where you are facing.** `GetPlayerWorldPositionInHouse` returns a rotation, but
  how it relates to a furnishing's yaw is not established; `rot N` is explicit until it is.
* **Choosing a house by name.** `to N` uses the numbers in `/pbfe houses`; typing a Japanese
  house name on a console keyboard is not a feature.
* **Unlinked furnishings** can be copied one at a time (`/pbfe copy sel`) but there is no
  "whole house" command yet.

## 9. Session 1 on the console — the first real run

The first thing run on a real client was `/pbfe copy` of one linked group, then `/pbfe paste` in
another house. What the screen showed (a photograph of the chat):

```
plan: here -- 0 to place, 4 skipped, 0 links
shift: x 8.6 m, y (up) -279.2 m, z 73.3 m
skip: 粗雑なブロック(石板) (collectible unavailable)          x4
note: 粗雑なブロック(石板) is a collectible you cannot place (not owned?)   x4
not ready; fix the above, or add 'force' to place what can be placed
```

**What that establishes.**

* The add-on loads and runs on the user's client, and chat output with Japanese names reads
  correctly.
* A clip of four furnishings came out of one house. A group is a root with children, so four
  pieces in a clip can only have come from link data: `GetPlacedFurnitureParent` and
  `GetPlacedFurnitureChildren` read on this client. (The write calls are still untested.)
* The paste planner ran, read the other house, and refused to start rather than half-doing it.

**What it exposed: a wrong assumption about "collectible".** All four pieces were recorded as
collectibles and refused as "a collectible you cannot place". The pieces are ordinary placeable
items ("Rough Block (Slab)"), and the bags were never even asked about them. The add-on had taken
`GetCollectibleIdFromFurnitureId(id) ~= 0` to mean "this is a collectible furnishing". That call has
no caller anywhere in the client's own Lua (section 2), and the evidence is that it answers a
non-zero number for ordinary items. (The number was never printed, so this is inferred from the
effect; `/pbfe kind` now prints it.) The client's own housing code asks a different question:
`GetPlacedFurnitureLink` returns an item link and a collectible link, and a non-empty collectible
link is what makes something a collectible; its id is read from that link.

**What changed (0.4.1).**

* The kind is read from the links, as the client does. With no link call in the build, the raw
  call is believed only if the collectible it names has this furnishing's own furniture data id.
* A clipboard made by the earlier build still says "collectible" for such pieces. The planner now
  treats a recorded collectible as an item when the client says it cannot be placed as one (or the
  id names a different furnishing) and the bags hold the item. This changes the plan only; the saved
  clipboard is not rewritten, and the plan says "treating them as items".
* `/pbfe kind [n]` prints, for the nearest pieces, both links, the raw call's answer and the
  verdict, so the next surprise is one screenshot away.

**A number to watch: the vertical shift.** `y (up) -279.2 m` is the difference between the player's
height when copying and when pasting, in two different houses. Houses do not share a coordinate
origin, so a large figure is expected, and `here` uses only offsets from the player, so it does not
by itself put anything wrong. It does mean question 5 (do the player's position and the furnishings'
share a space?) should be answered on this client before trusting `here` across houses: stand beside
a piece you know and run `/pbfe where`.

## 10. The quickslot wheel (0.5.0)

Asked for: when the player arrives at the destination of a paste or a move, a Paste and a Move
entry on the item quickslot menu, gone again when done. What the client's own code (`ingame/
utilitywheel/*`, `libraries/zo_radialmenu/*`) says about that menu:

* The quickslot wheel is `UTILITY_WHEEL_GAMEPAD` (keyboard: `UTILITY_WHEEL_KEYBOARD`), an
  `ZO_InteractiveRadialMenuController`. Holding the button calls `ShowMenu` (`menu:Clear()`,
  `PopulateMenu()`, `menu:Show()`); letting go calls the highlighted entry's callback. Entries are
  `menu:AddEntry(name, icon, activeIcon, callback, data)` and are laid out evenly round the circle
  whatever their number.
* Each entry is drawn by `SetupEntryControl(control, data)`, which reads `data.slotNum` through
  `GetSlotItemCount`, `GetSlotType`, `GetSlotCooldownInfo` and `GetSlotTexture` (and the keyboard and
  gamepad subclasses add a cooldown setup). The game's own *empty* entries go through that same path
  with the number of an empty slot, so an entry added here borrows an empty slot number; if none is
  free, slot 9 is used, but only after those four calls have been asked whether they accept it.
* With togglable (accessible) wheels each entry gets a hotkey, `ACCESSIBLE_WHEEL_HOTKEY_SLOT_1` to
  `_10`, and `ZO_GetRadialMenuActionNameForOrdinalIndex` asserts on any index above 10. The wheel has
  eight slots, so **two** entries is the room there is: Paste and Move, each standing for everything
  waiting of its kind in the house. (A third entry would be a client assertion.)

**The hook.** Entries have to be added from `PopulateMenu`, which is client code, so something has to
hook it. The house rule against hooks is there because `ZO_PreHook`/`ZO_PostHook` put add-on code
inside the client's call chain, and a tainted chain takes protected calls down with it. The
documentation lists `SecurePostHook(table, functionName, hook)` among the VM functions: a post hook
that runs after the original, apart from its chain. Nothing in the client's own Lua uses it, and the
documentation says no more, so *that it exists and that it works as described are both assumptions*
(questions 16 and 18). The add-on therefore:

* refuses to hook at all if `SecurePostHook` is missing (no fallback to a plain hook);
* hooks only the first time something is waiting, and a hook cannot be removed, so "temporary" means
  the hook is inert (adds nothing) whenever there is nothing to offer;
* wraps everything the hook does in `pcall`, stops itself for good on the first error, and says so;
* leaves every wheel but the quickslot wheel alone, and leaves it alone in combat;
* asks `PickWheelSlot` whether the slot calls cope with the number it will draw entries with.

**Selecting.** The callback runs inside the client's own selection (`SelectCurrentEntry`, then
`Clear`). Protected calls (`UseItem`, `SelectSlotItem`, `ClearSlot`, `PlaceInActionBar` ...) are
marked `*protected*` in the documentation; `SetCurrentQuickslot` and `LockCameraRotation`, the calls
that follow a selection, are not, so an add-on callback there taints nothing that matters. The
callback still does nothing but schedule: the paste begins a moment later, outside that chain.

**What was chosen, and why.** A pick runs the offer with `go` and `here` meaning the spot where the
player stands: that is the point of a wheel on a console, and it is what `here` could not be on
arrival at a doorway. Picks are not delayed, because releasing the button over an entry is the
confirmation; `undo` is there. Entries are *derived* from the current house every time the wheel is
opened (reservations waiting here, plus trips that showed only a plan), so there is no state to go
stale: leaving the house, finishing, dropping a reservation or `/pbfe menu off` removes them.

**Not possible:** making the wheel open by itself. It opens when the button is held; the add-on can
only announce, in chat, that the entries are there.

## 11. Copy and Cut in the housing editor (0.6.0; the house chooser it describes was removed in 0.9.0, section 15)

Asked for: with linked furniture in the reticle, the palette that shows "x Edit, triangle Precision
Edit, L3 Link" gets "circle Copy" and "square Cut", and after either a screen of the player's own
design asks which house. What the client's code (`ingame/housingeditor/housingeditorhud.lua`,
`libraries/zo_keybindstrip`, `libraries/zo_dialog`, `ingame/globals/ingamedialogs.lua`) says:

* **The palette** is `HOUSING_EDITOR_KEYBIND_PALETTE`; `UpdateKeybinds` calls
  `:AddKeybinds(HOUSING_EDITOR_SHARED.selectionModeKeybindPaletteGamepadDescriptor)` and then adds
  the strip group. The list is plain data: `{ name, keybind, callback, enabled, visible, order,
  ethereal = true }`, `visible`/`enabled` evaluated on every refresh, and it sorts itself once
  (`sorted = true`). Selection mode uses PRIMARY (x), TERTIARY (triangle), BEGIN_FURNITURE_LINKING
  (L3) and QUINARY (path). **NEGATIVE (circle) is not used there**, so Copy takes it with no conflict.
* **SECONDARY (square) is the strip's "Browse"**, registered for every target. `ZO_KeybindStrip`
  keeps ONE descriptor per keybind: adding a second one runs `internalassert(false, "Duplicate
  Keybind")` and then `RemoveKeybindButton` on the one registered first. A palette button is drawn
  from its descriptor alone (`SetKeybindButtonDescriptor`), so Cut can be *shown* on the palette
  whether or not the strip keeps its registration. *Who handles* the square button is whichever the
  strip kept, and that depends on the order of the last two calls: `UpdateKeybinds` adds the palette and
  then the strip (Browse is kept); `RefreshKeybinds`, run on a target change, re-adds only the palette
  (the palette's entry is kept, and Browse is dropped until the next `UpdateKeybinds`). So both are
  written to do the same thing: Cut with a linked furnishing in the reticle (and the right to cut),
  otherwise Browse, with the palette entry calling Browse's own callback, and `enabled` answering for
  Browse, when it is not a Cut.
* **No hook is used.** The changes are edits to data in the client's tables (two descriptors
  inserted into the palette list, two fields of the Browse descriptor replaced), made once; `/pbfe
  editor off` removes the entries and puts Browse back exactly.
* **A cost to know about:** with Cut on the palette, `internalassert(false, "Duplicate Keybind...")`
  runs inside the client's own keybind code whenever the palette and the strip both register the
  square button, which is on every rebuild in selection mode. That is `internalassert`, which the
  client's source uses 367 times and which has to be a no-op in a live build for the client's own
  "assert, then clean up" duplicate handling to make sense; but it is an assumption (question 24). The cost is
  that our `visible`, `name` and `callback` functions run inside the client's keybind code, which is
  insecure code in a call chain that includes `UpdateKeybinds`. They only look and schedule, every one
  is in `pcall` and answers "not applicable" on error, which leaves the client's own behaviour
  standing; and the work starts a moment later, outside that chain. Nothing protected is called in
  that chain by the editor.
* **The Browse label is stale unless refreshed.** The client refreshes the palette when the target
  changes (`RefreshKeybinds`) but not the strip, and a button's name is read when the strip is built.
  `EVENT_HOUSING_TARGET_FURNITURE_CHANGED` calls `KEYBIND_STRIP:UpdateKeybindButtonGroup` on the
  HUD's current strip group, so the label follows the target.
* **The screen** is a gamepad parametric dialog, built like the client's own travel-to-house dialog
  and its inventory-actions dialog: `ZO_Dialogs_RegisterCustomDialog` with a `parametricList` that is
  emptied and refilled in `setup` (entries `ZO_GamepadEntryData` on `ZO_GamepadMenuEntryTemplate`),
  buttons `DIALOG_NEGATIVE` (Cancel) and `DIALOG_PRIMARY` (Select, which calls
  `dialog.entryList:GetTargetData()`). `title.text` may be a function of the dialog (`ZO_Eval`).
  **`ZO_Dialogs_ShowGamepadDialog` shows the dialog only if a scene is showing, and does nothing, with
  no error, otherwise.** So a "chooser open" flag is held only until `setup` has run: if it has not a
  moment later the flag is given back and the chat says the chooser did not open.

**Order of events.** A press notes the reticle's furnishing at once (a C call; the reticle may move
the moment the dialog opens) and schedules the rest. The chooser opens. Choosing a house makes the
reservation (a cut removes the furnishings first, with the usual bag-room check and refusal); the
wheel does the rest on arrival. Cancelling changes nothing: nothing is copied or cut until a house is
chosen, so a chooser that cannot open is harmless.

**What is not known** (questions 19-23 below): every one of these is read from source and tested
against a stub, none has run on a console.

| # | question | settled by | if the answer is no |
| --- | --- | --- | --- |
| 19 | Does the circle button appear in the palette beside x / triangle / L3 and fire? | aim at linked furniture in the editor | change the keybind, or put it in the strip |
| 20 | Does the square button read "Cut" while aiming at linked furniture and "Browse" otherwise, and does Browse still work? | aim at linked, then at a wall | `/pbfe editor off`; use the wheel or commands |
| 21 | Does the chooser open from the editor HUD, with a readable title and list? | press circle | the chooser says it did not open; use `/pbfe reserve` |
| 22 | Is circle bound to something else on this console that now conflicts? | the chat and the editor behave | pick another unused editor action |
| 23 | Does the Browse label follow the target? | aim at linked, then away | refresh differently |
| 24 | Does the duplicate-keybind `internalassert` stay silent in a live build, with Cut and Browse both on the square button? | open the editor, aim at things, watch for errors | `/pbfe editor off`; Cut by command or wheel |

## 12. Session 2 on the console — Copy shows, Cut did not

The editor buttons (0.6.0) were tried on the console. Reported: **the circle "Copy" appears on the
palette; the square "Cut" does not.**

**What that establishes.** Adding a descriptor to `selectionModeKeybindPaletteGamepadDescriptor` works:
the palette draws it, beside the game's own buttons, with a linked furnishing in the reticle
(question 19, answered for the display; whether it fires is not yet reported). Editing client data
this way, without a hook, is therefore viable on this client.

**Why Cut did not show.** In 0.6.0 Cut was *not a palette entry*. It was Browse's name and callback,
renamed, to avoid two descriptors on one key (section 11). Browse is a button of the keybind *strip*,
and the strip is not what the player looks at in the editor; the palette is. The rename was invisible
there, and it was wrong to take "no duplicates on one key" as meaning "no palette entry".

**What changed (0.6.1).** Cut is a palette entry too, on the square button, ordered after Copy, drawn
whenever Copy is. The input side is written to survive either of the strip's two registration orders
(section 11): whichever of the palette's entry and Browse's descriptor the strip keeps, the square
button cuts with a linked furnishing in the reticle and browses otherwise. The tests model the strip's
one-handler-per-key rule and run each square-button case after a full rebuild and after a target-change
refresh.

## 13. Pasting at the original coordinates (0.7.0)

Asked: can the paste go to the coordinates the furnishings were copied or cut from? It always could
(`same`, in the commands), but the editor's chooser only made `here` reservations, so the wheel could
only paste where the player stood. The chooser now lists every house twice, original position first;
the choice becomes the reservation's words (`same`, or none for `here`), and the wheel's pick runs
them with `go`.

What "original" can and cannot mean. A furnishing's position is a coordinate in *its house's* world
space, and houses do not share an origin (the first console paste printed a 279 m vertical shift between
two of them). So the original coordinates reproduce the build only in the house they came from (the
cut-and-put-back case, which is the main use) or in one with the same layout and origin; elsewhere
they can land outside the walls and each such piece is refused by the server
(`INVALID_FURNITURE_POSITION`). The planner cannot tell the two cases apart, so for a different house
it adds a note rather than a refusal; `here` is the choice that is always safe. The same note appears
on `/pbfe paste same` in a house the clip did not come from.

Also fixed: a cut for the house the player is standing in (the put-it-back case) now announces the
Move on the quickslot wheel when it finishes, as a copy already did.

## 14. Pasting at the cursor (0.8.0)

Reported: coordinates differ from house to house, so the original coordinates (0.7.0) do not give the
expected result. Asked: can it paste at the target cursor position?

**The call.** `HousingEditorGetScreenPointWorldPlaneIntersection(screenX, screenY, x1,y1,z1, x2,y2,z2,
x3,y3,z3)` turns a screen point into a world point by meeting the camera's ray with the plane through
three world points. The editor HUD uses it to drag a furnishing along an axis
(`ZO_HousingEditorHud:OnDragMousePosition`), treating an all-zero answer as "none". The reticle is the
middle of the screen (`GuiRoot:GetDimensions()` halved). The plane described is the floor the player
stands on: the player's own coordinates (`GetPlayerWorldPositionInHouse`) at the player's own height.
The group is then placed as `here` is, with the cursor's floor point in place of the player's feet.

**The trap, and how it is closed.** A ray meets a plane on one side of the camera only, and the call's
answer does not say which. Looking UP, the floor is met *behind* the camera: a group placed behind the
player. Whether the real call returns zeros for that (as its use suggests) or the point behind is not
documented, so the add-on does not depend on it. It asks `GetCameraForward(SPACE_WORLD)` which way the
camera looks and accepts the point only if the camera looks down (vertical part below -0.02) and the
point is in front (a third-person camera sits up to 2.5 m behind the player, so a point a little behind
the player still counts). Without that call, the same is read from the answers: aim a tenth of the
screen lower, and a point in front comes nearer while one behind goes away. Beyond 30 m from the player
is a wall or the sky, not a spot. The tests run every case against a camera model that answers with
zeros behind it and against one that answers with the point behind it.

**When the point is read.** The quickslot wheel locks the camera while it is up and releases it as the
button is let go (`ZO_InteractiveRadialMenuController:StopInteraction` unlocks, then `SelectCurrentEntry`
calls the entry's callback). The callback is the one place where the camera still points where the
player pointed it, so the point is read there, synchronously, and carried to the paste; anything
scheduled would run after the player may have swung the camera. One pick runs every paste of its kind
from that one point. A paste typed as a command reads it when it runs.

**Limits, stated.** It is a point on the floor of the level the player stands on (a table top is the
floor under the line of sight; `up N` lifts); there is no raycast against walls, so aiming through a
doorway at a distant floor gives a far point (refused beyond 30 m); the group's rotation is not turned
to the camera; at a doorway (right after a trip) `aim ... go` shows the plan and waits for a pick, as
`here` does.

| # | question | settled by | if the answer is no |
| --- | --- | --- | --- |
| 25 | Does the call answer outside UI/mouse mode (the HUD uses it while dragging with the cursor), for the middle of the screen? | `/pbfe aim` looking down at the floor | use the player's feet (`here`), or the targeted furnishing's position |
| 26 | Is the middle of the screen the reticle, and `GuiRoot`'s units the call's? | `/pbfe aim`: does the point sit where the reticle is? | find the reticle's screen position |
| 27 | Does `GetCameraForward(SPACE_WORLD)` share the housing coordinates' axes? | `/pbfe aim` prints the forward vector: down is negative; a point ahead should have a positive dot with it | the second-look test is already the fallback |

## 15. "I can't paste anything now": the destination house was never needed (0.9.0)

Reported after 0.8.0: pasting no longer works, nothing can be done. And the question that follows from
it: why is the destination house chosen at all? Copy or cut, go to any house, paste or move there.

**What probably went wrong.** 0.8.0 made "where the cursor points" the first row of the chooser, and a
paste with that mode ended in "could not read where the cursor points" if the point could not be read.
The call behind it, `HousingEditorGetScreenPointWorldPlaneIntersection`, is used by the client only
while dragging an axis with the mouse (`IsGameCameraUIModeActive()` is part of that code path); that it
answers for the middle of the screen in the gamepad HUD was an assumption (question 25). If it
answers zeros there, *every* paste by default ended in a refusal. No chat was reported, so this is a
hypothesis from the code, not an observation. Whatever the cause on the console, the design was
wrong in one respect that is certain: **a mode that can fail must not be the only way to paste.**

**What changed.**

* The destination house is gone. Copy and Cut put the group on the clipboard (Cut also takes it out of
  the house, with the bag-room check) and mark it *fresh*. In any house you own, while the clipboard is
  fresh, the quickslot wheel offers Paste (a copy) or Move (a cut). Pasting clears *fresh*; the
  clipboard itself stays for `/pbfe paste`. There is no dialog, so the dialog's own unknowns (does it
  open from the editor HUD; the scene check that makes it silently not open) are gone with it.
* A cut is still the only record of where its furnishings go, so while a cut waits, a second copy or
  cut from the editor is refused.
* `/pbfe position aim|here|same` says where the wheel pastes; the default is `aim`. **A wheel pick whose
  cursor cannot be read pastes where the player stands**, and prints why. A typed `/pbfe paste aim go`
  still refuses when the cursor cannot be read, because someone who typed `aim` asked for it.
* The cursor read inside the wheel's callback is in `pcall`: an error there is reported and stood in
  for; it can no longer stop the pick.
* Reservations (`/pbfe reserve`) are kept for anyone who wants a paste decided in advance, but nothing in
  the editor flow uses them.

Reservations had been built on the idea that a paste has a destination. It does not: the clipboard
has none, and the player is the one who knows where it goes, by walking there.


## 16. Cut: counting slots, not pieces (1.0.1)

Asked: what if the bag lacks room for the pieces of a cut? The answer then was "it checks, and it will not
start", but the check was crude: it counted one slot per KIND, ignoring that a kind that does not stack
(or a stack that is full) takes a slot per piece, and that a half-full stack takes pieces without a slot.

**The model** (`RetrieveSpace` in Paste.lua). The game stores a retrieved furnishing into a stack of its own
kind that has space, else a new slot; one slot holds at most `max` of a kind (`GetSlotStackSize(bag,slot)`
returns `(stack, max)`). For each kind with `n` pieces leaving:

    room  = sum over this kind's slots in the retrieve bag of (max - stack)
    slots = ceil(max(n - room, 0) / max)

Collectible furnishings take no slot. `max` is taken from a slot of the kind in the retrieve bag, else in any
other bag (the bank and house chests are indexed too), else from `sv.stackMax[dataId]`, which
`IndexInventory` fills with every stack size it ever sees (so a paste, which looks in the bags, teaches it).

**What cannot be known.** A kind in no bag and never seen has no known `max`. For those the result is a range:
low = they stack as furnishings usually do (200), high = one slot per piece. The decision:

* free < low   -> refused ("not enough room in the backpack: 2 free, at least 3 needed"); `force` overrides.
* low <= free < high -> starts, with "it may fill up"; if it does, the game answers
  `ITEM_REMOVE_FAILED_INVENTORY_FULL`, the cut stops at that piece (removal is leaf-first and verified by
  existence, nothing is lost), the clipboard still holds the whole group, and `cut resume go` finishes it.
* free >= high -> certain to fit.

**Honest limits.** 200 as the "usual" stack size is an assumption, not read from the client: it only sets the
LOW end, and the low end only decides a refusal. If a kind stacks less than 200 the refusal can be too
lenient (it starts, then stops safely); it can never be too strict by more than the actual stack size. The
rule that a retrieved piece joins an existing stack in the retrieve bag, and does not first look at other
bags, is how the editor's Retrieve behaves in the client's own UI as far as is known, not observed here. All
of this is checked only against the mock (section 27 of `test/run.lua`, which models stack maximums and a
bag limit); nothing has run on a console.

Questions for the console: 28. Does `GetSlotStackSize` answer `(stack, max)` for furniture slots as it does
for other items? 29. Does a retrieved furnishing join a partial stack in the retrieve bag? 30. Is the
inventory-full result really `ITEM_REMOVE_FAILED_INVENTORY_FULL`?

## 17. A paste empties the clipboard (1.0.1)

Asked: copied content seems to pile up; clear it when it is pasted. (It did not pile up in the sense of a
list -- there is one clipboard, replaced by each copy -- but it stayed after a paste, was saved across
sessions, and could be pasted again by mistake.)

**Rule** (`FinishRun` in Paste.lua). When the paste that ran was *from the clipboard* (`run.plan.clip ==
sv.clip`) and it is `complete` (every node placed or already standing, nothing failed, nothing skipped), then
`sv.clip = nil`, `clipFresh = false`, and the chat says "pasted; the clipboard is emptied". For a cut this
ends the move ("the move is complete; the clipboard is emptied") and lifts the guard that refuses a new
copy or cut while a cut waits.

**Kept on purpose when it is not complete** (stopped, a piece missing from the bags, a link failed): the
clipboard stays, `clipFresh` is cleared only if something was placed (as before), and the chat says "N not
placed: the clipboard is kept, so it can be tried again". For a cut it is the only record of where the rest
goes (`paste same go` puts back only what is missing). The cost: a second try of a partial *copy* paste
places everything again, so `undo` first if that is not wanted.

**Not touched:** a reservation pastes from its own clip (`resv.clip`), never `sv.clip`, so it neither
empties the clipboard nor is affected by it. Named clipboards (`save`/`load`) are copies, and are the way to
paste the same thing more than once. `undo` works from `sv.lastPaste`, not the clipboard, so it still works
after the clipboard is empty.

**Tests:** section 28 of `test/run.lua`; the many older tests that pasted twice now `save` and `load`
first. Mock only; nothing here depends on a console behaviour.

## 18. Big link groups (1.0.2)

Reported: with many links in the group, copy or move sometimes does not work. No console output came with
it, and nothing in the evidence log so far is about a large group (the console runs were 4-piece groups), so
this section is from reading the code and the game's own data, not from an observed failure.

**What the game says.** ESO's Update 20 announcement (elderscrollsonline.com/en-us/news/post/55085): a parent
can be linked "to up to 50 child items", and children can themselves be linked to more objects (no depth
limit is mentioned). The API has the answer `HOUSING_REQUEST_RESULT_LINK_HAS_TOO_MANY_CHILDREN` ("This
furnishing cannot have any more children", string 42) but no call that returns the number. The 50 is
therefore from an announcement, not from the client; whether it counts direct children only is unconfirmed.

**What in the code scaled badly** (each is a certainty about the code, not about the console):

1. A placement that failed once stayed failed: no retry, apart from the "in progress" answer. A failed parent
   then cost the links of its whole subtree. With ~160 requests per big group, one transient refusal is likely.
2. A link that failed once stayed failed.
3. A placement answered after the 6 s wait was recorded for undo and counted as "not linked", while the node
   it belonged to stayed failed; a repair would have placed a second one.
4. A link took at least 500 ms (settle) + pace before the next, ~1 s each.
5. `LINK_HAS_TOO_MANY_CHILDREN` was an ordinary link failure.
6. Cut and undo left stragglers (a removal that failed once) for the player to finish by hand.

**What changed** (Paste.lua):

* Rounds of repair for placements, links and removals (`MoreRounds`): after a pass, what failed for a reason
  that may pass is asked for again. A round is attempted until four in a row get nothing through, at most
  eight. Final refusals (`NO_RETRY_NAMES`, `NO_RELINK_NAMES`, "no copy left in the bags") are not repeated.
* Late answers are adopted (`RecordLatePlacement` -> `AdoptPlaced`): the piece goes to the nearest failed node
  of its kind and the usual drift check moves it onto that node's target, so which of several identical pieces
  it was does not matter. Nothing is scheduled or cancelled by an adoption (no `run.token` change).
* Before a node that got no answer is asked for again, the repair waits one more timeout (a piece that was
  merely slow would otherwise be placed twice -- the mock showed exactly that).
* `FindNewFurniture` picks the new piece nearest to the node's target, not the first one.
* The first look at a link is at 150 ms (was 500 ms) and then every 350 ms for up to 12 looks. Looking is
  read-only, so this is only faster, not riskier. A link whose answer is "already linked" or "already has a
  parent" is checked: if the child hangs from a piece of this group it counts as made.
* `LINK_HAS_TOO_MANY_CHILDREN`: the number of children that parent held is its cap (`run.cap`, `run.capAny`),
  and this child, and later ones of that parent, are linked to the nearest sibling already linked to it that
  has room. One tree, moves as one. (A group copied from the game was made within the game's limit, so this
  is for a source that exceeds it.)
* The plan prints "links: N, most children on one furnishing: K (ESO's limit is 50)"; `go` prints a rough time.

**Tests.** Mock: `World.maxChildren`, `World.flaky` (every k-th request fails), `World.chance` (random),
`World.slowPlace` (placements announced after the wait). Section 29 pastes the largest legal group (a base
with 50 panels, five of which carry six pins: 81 furnishings, 80 links), the same on a flaky server, with late
answers, wider than the cap, wider than 50, with links that never take, and a cut and move of it. Section 30
runs 25 random-failure pastes and 15 random-failure cuts: each ends with every piece exactly once, in one tree.
Mock only.

**Open questions for the console.** 31. Is the per-parent limit 50, and does it count direct children only?
32. Does a busy house answer a placement after more than 6 s? 33. Does a big group's server latency grow with
the number of links already in the house?

## 19. "Cut seems to have stopped working" (1.0.3)

Reported without console output. Nothing in the evidence log says a cut has ever completed on a console
(sections 9 and 12 are copy and the buttons), so "stopped working" cannot be compared with a known-good run.
What changed in the cut path since 1.0.0: (a) `RetrieveSpace` counts stacks (section 16) and may refuse where
the old one-slot-per-kind count did not; (b) the removal runner asks again for what is left (section 18);
(c) a completed move empties the clipboard (section 17).

Audit by reading and by the mock; one real defect found, and it was older than all three:

* `RemoveNext` counted "not yet" answers (`REQUEST_IN_PROGRESS`, `ALREADY_BEING_MOVED`) in `run.retries`
  over the WHOLE cut, never resetting it (the paste runner resets it per furnishing). A server that is busy
  between requests answers "not yet" about once per removal, so after ten removals the allowance was spent and
  every later "not yet" was a failure: the first pass left the rest standing. Reproduced in the mock with
  `World.cooldown = 700` (22 pieces: 12 left after the first pass; the repair rounds then finished them only
  after four rounds and 29 s). Fixed: the count is per furnishing (`run.retryIndex`). Section 31.

Not found: nothing else in (a)-(c) behaves differently from the old code except the intended cases (a kind that
does not stack, or a stack that is full, now needs its own slots). If a cut is refused the chat says
"not enough room in the backpack: N free, at least M needed"; if it stops, "stopped: <the game's words>".

What would settle it: the chat lines of one failing cut (the "cut:" preview lines and what follows).

## 20. Groups that mix kinds of furnishing (1.0.3)

Reported: a linked group that mixes special furnishings, crate items, Crown Store furnishings and furnishings
crafted from plans does not paste or move well. No output came with it. The nearest earlier event is section 9
(plain items called collectibles), fixed by reading the collectible LINK; nothing before this was about mixes.

A furnishing differs along three lines, and the add-on has to get each right:

1. **Item or collectible** -- decides the call (`HousingEditorRequestItemPlacement` from a bag, or
   `HousingEditorRequestCollectiblePlacement` from the collection), where a cut sends it (a bag slot, or back
   to the collection) and whether the bag-room check counts it.
2. **Which of the house's four limits it counts against** -- `HousingFurnishingLimitType`: traditional
   (LOW_IMPACT_ITEM), special (HIGH_IMPACT_ITEM), collectible (LOW_IMPACT_COLLECTIBLE), special collectible
   (HIGH_IMPACT_COLLECTIBLE). Read with `GetFurnitureDataInfo(dataId)[4]`, checked against the signature in the
   API documentation. A crate item can be special; a Crown Store piece is usually a collectible.
3. **Restrictions of the item** -- a unique item (`ITEM_REMOVE_FAILED_ALREADY_OWN_UNIQUE`), a collectible the
   house already holds (`NO_DUPLICATES`).

**A defect found by reading the code, and it needs a mix to show:** the four "no room" answers
(`*_IMPACT_*_PLACE_LIMIT`) and `METRICS_LIMIT_HIT` were in `STOP_NAMES`, so the FIRST of them ended the whole
paste. Each is about one kind. In a group of one kind that is harmless; in a mix, a house whose special
furnishings are full stopped the traditional pieces and the collectibles too, even though they fit. (The plan's
up-front check covers the usual case, but it relies on `GetNumHouseFurnishingsPlaced`, which the add-on has
never seen answer on a console.)

**Changes:**

* A limit answer marks that limit type full for the run (`run.full`). Nodes of that type are not asked for any
  more ("the house has no room for any more special furnishings"); everything else goes on. Such a failure is
  final: it is not retried.
* `METRICS_LIMIT_HIT` (the house's performance budget) fails that piece and goes on; three in a row stop the run.
* The plan always shows each limit against the group: "special furnishings: 1 to place, room for 0", and
  `show` and the cut preview say how many of each kind the group holds. If the game's own numbers disagree with
  what the add-on expected, this is where it will show.
* `/pbfe kind [n]` now also says which limit a furnishing counts against, how many copies of an item the bags
  hold, and whether a collectible can be placed.
* A cut: a refusal because you already own a unique item is named (`remove Crate Statue: ...`) and is not asked
  for again; the rest of the group still comes out and the cut stays pending.
* A cut says that collectibles go back to the collection and need no bag slot.

**Not changed, and unverified:** whether crate and Crown Store furnishings are items or collectibles on the
console (the add-on reads it from `GetPlacedFurnitureLink`, as the client does); whether a collectible can be
placed again at once after a cut (`HousingEditorCanPlaceCollectible` is read when the move starts; if it says
no, that piece is skipped and named); whether `EVENT_HOUSING_FURNITURE_PLACED` carries the collectible id for a
collectible.

**Tests:** section 32 -- a group of a crafted table, a special crate case, a crate statue, a Crown lamp, a
special collectible banner and a trim: pasted with room, with the special limit full, with a limit met part
way, with the performance budget refusing a heavy piece, cut and moved, and cut with a unique item. Mock only.

**Open questions for the console.** 34. Do crate and Crown Store furnishings read as items or collectibles?
35. Does `GetNumHouseFurnishingsPlaced` answer for each of the four types? 36. What does a placement of a
collectible answer when the house already holds one (`NO_DUPLICATES`)?

## 21. First console log of a large cut (1.0.4)

Evidence, the first for a cut: four screenshots of the chat, taken after the fact. All they show is
"a cut is still waiting (38 furnishings): pick Move on the quickslot wheel in a house of yours, or /pbfe paste
same go to put it back where it was" ten times, one per press of Copy/Cut in the editor, and above them
"quickslot wheel: Move (1). hold the quickslot button, point at it, let go". The lines of the cut itself (how
far it got, whether it stopped) are above what was captured. What can be read from it:

* The clipboard held a pending cut of 38 furnishings (`clip.cut`). The editor refused every new Copy/Cut, with
  one fixed message that did not say whether the cut was finished. If it had stopped part way, the message
  was no help: the player could neither carry it on nor start another, and had no output to tell why.
* A cut that stops part way on a console is therefore a real case, and the likeliest reason for a group this
  size is the bag: pieces that do not stack take a slot each, and 1.0.2 only knew that for a kind it had already
  seen in a bag (`sv.stackMax`), so it estimated "one slot per kind" and started.

**Changes.**

* The copy records, per piece, `IsItemLinkStackable` and `IsItemLinkUnique` from the item link
  (`GetPlacedFurnitureLink`, `ItemTraits` in House.lua). `RetrieveSpace` treats a kind whose pieces never stack
  as one slot per piece, exactly, whether or not it has been seen in a bag (and remembers it in
  `sv.stackMax`). A kind that stacks, by an unknown amount, is at least two to a slot; the range is narrower.
  A clip made by an older build has no such fields and is estimated as before.
* Refusals from a pending cut say where it stands (`CutStatus`, `PrintCutAdvice`): "3 of its 13 furnishings are
  still standing in this house: press Cut on one of them", or "all 13 are out of this house: pick Move", or
  "a cut of 13 furnishings from house N is waiting", and how to let go of it (`/pbfe clear force`).
* Pressing Cut on a furnishing of the pending cut that is still standing **carries the cut on**
  (`ResumeCut`, shared with `/pbfe cut resume`). Copy, or Cut on anything else, is refused with the above.
* A cut that stops because the bag is full says so and what to do (make room, then press Cut again).
* Headlines are also shown on the screen with the client's own alert, `ZO_AlertNoSuppression` through pcall
  (`addon.Alert`): cut refused, done, stopped; a cut unfinished; paste result. A console player in the editor
  does not see the chat, so a message that only went there was a message not seen.

**Not known.** Whether `IsItemLinkStackable` and `ZO_AlertNoSuppression` behave on the console as the
documentation and the client's own use of them suggest; whether the alert is visible while in the editor.
The lines above the captured part of the log would say how that cut actually ended.

**Tests.** Section 33 (mock): 13 non-stacking pieces and 10 slots are refused with exact figures, 13 slots
take them, stackable ones are certain to fit in 7; a cut stopped by a full bag is refused a Copy, refused a Cut
without room, and carried on by Cut once there is room; the advice in the three situations; the alerts.

## 22. A way to forget what is held (settings panel) (1.0.4)

Asked: the add-on keeps the copy and cut state internally; give the settings menu an item to clear it.

What is held (State.lua `HeldState`): `sv.clip` and `sv.clipFresh` (the clipboard, and whether the wheel offers
it), `sv.lastPaste` (the undo record), `sv.reservations`, `self.jump` (a trip begun), `self.tripOffers`,
`self.menuJobs`, and the reservation queue. `sv.library` (named clipboards) is kept on purpose and is never cleared.

* `ClearCopyCut` forgets the clipboard; `ClearAllState` all of the above except the library. Neither runs while
  a paste, cut or undo is running (stop first: the run holds references to the clipboard).
* A cut that has not been pasted, or a reservation that holds one, is asked twice (`Confirmed` / `Arm`, ten
  seconds): the clipboard or the reservation is the only record of where its furnishings go. A press of the other
  button is not an answer to the first. `force` skips the question for the typed commands.
* `/pbfe reset [all] [show] [force]` does the same without the panel.
* The panel (Settings.lua) is built only when `LibHarvensAddonSettings` is present, as in the other PBs add-ons
  (`## OptionalDependsOn: LibHarvensAddonSettings>=20106`, copied from PBsDiceExtension); a failure to build it is
  caught and reported, and does not stop the rest. Rows: heading, explanation, Show, Stop, Clear copy / cut,
  Clear everything. Japanese labels on a Japanese client (`GetCVar("language.2")` is `jp`, as for the editor
  buttons). No row shows the state, because the library builds rows once (the same reason PBsDiceExtension has
  no "last roll" row); every button says in chat, and on the screen, what it did.

* The panel is listed as `PB’s FurnitureEditor` with the TYPOGRAPHIC apostrophe (U+2019). PBsDiceExtension found that an
  ASCII `'` makes the settings library's panel drop the whole `PB's ` and list `FurnitureEditor`; the manifest keeps the
  ASCII form (the add-on list and the store want it), only the panel name differs. The character is written as itself,
  not as `\u{2019}` (Lua 5.3 syntax; the client is 5.1). The test checks the name has no ASCII apostrophe.

**Not verified on a console:** that the panel appears and its buttons work (the mock records the rows and calls
the handlers; the library itself is not in this repository), and the `ST_SECTION` heading (the siblings fall back
to `ST_LABEL` on older copies of the library; so does this).

**Tests.** Section 34 (mock library): the rows, a copy forgotten with one press, a cut asked twice and the question
lapsing after ten seconds, one button's question not answered by the other, nothing forgotten while a paste runs,
Stop, Clear everything (undo record, reservations, trip, offers; library kept), a cut reservation counted as a cut,
the typed commands, Japanese labels, and no panel (and no harm) without the library.

## 23. Second console log: the cut that was never started (1.0.4)

A screenshot of the chat "right after executing a cut". Read in order, top to bottom: another add-on's load lines
(PvPCooldownTracker, "Upgrading SavedVariables"), so this is the start of a session (log-in or UI reload);
a game quest line; then ours: `quickslot wheel: Move (1). hold the quickslot button...` and, after it,
`a cut is still waiting (38 furnishings): pick Move ...` repeated, one pair per press of the editor's Cut/Copy.

* There is **no `cut:` line in this session**. The press of Cut did not start a cut: it was refused at once, because
  the clipboard already held a pending cut of 38 furnishings. That cut is from an earlier session: the clipboard is
  in SavedVariables, so it is still there after a log-out, and a log-in announces it as a Move on the wheel.
* So what looked like "the cut does not work" was a stale pending cut blocking every new one, and the only text the
  player got was a fixed message that did not say where the cut stood or how to leave it. How far that earlier cut
  got (all 38 out, or part way) is not in this capture, and it is the thing the screenshot does not show.
* The text on the screen is the fixed one (`... pick Move on the quickslot wheel in a house of yours, or /pbfe paste
  same go to put it back where it was`), which is the build before the state-aware refusal: the console is running a
  build older than the changes of sections 21 and 22.
* In that build the way out is `/pbfe clear force` (it forgets the clipboard; the furnishings that are out of the house
  are in the bag or the collection, so nothing is lost). Or Move in a house of yours; or `/pbfe paste same go` in the
  house it came from.

**Change.** On arrival in a house (and on log-in), a cut that is still held is said at once, with where it stands and
how to let go of it (`AnnounceMenu(true)` from `ReservationsArrived` and `ResumeAfterJump`), even when nothing is on the
wheel for it. Together with sections 21 and 22 (state-aware refusal, Cut carries the cut on, `/pbfe reset`, the
settings button) the stuck state now explains itself and has three ways out. Test: section 35.

## 24. A progress bar for cut, move and paste (1.0.5)

Asked: show progress as a bar while cutting, moving and pasting. The reason it matters is section 21: a console player
in the housing editor cannot see the chat, so a long run gave no sign of life, and the chat lines of a cut that stopped
were not seen at all.

Built (Progress.lua) the way PBsCraftMaterialAssistant builds its window, whose reasons are in that file's header and
were measured on a console there: a plain top-level window with the mouse off, created on first use, in no scene (the
draw layer, DL_OVERLAY / DT_HIGH, is what puts it over the editor and over a menu), only a font the console UI has already
loaded (`$(GAMEPAD_MEDIUM_FONT)|26|soft-shadow-thick`; faces nothing else uses were measured crashing a PS5), every call
in pcall. Controls: a backdrop for the panel, a title label, a backdrop for the track, a backdrop for the fill (its width is
the progress; the same `SetCenterColor`/`SetEdgeColor` calls the sibling uses), a detail label.

* What the bar counts: cut and undo, pieces out of the house (`run.removed + run.skipped`) of the pieces asked for; paste
  and move, `run.placed + run.linked` of placements plus links. The runs call `Tick` (Paste.lua) where those change and
  where a phase or a repair round begins; the bar reads the run, so nothing is counted twice.
* A move is a paste whose clipboard is a cut. A run that ends with a reason (a stop, a refusal) says "stopped".
* A time left, from the rate so far, once five pieces are done.
* The bar lingers three seconds after the end; a later run takes it over and the earlier run's hide does not take it away
  (a token). `Begin`/`RunEnded` ignore a run that is not the bar's current one.
* Switch and place: `sv.progress`, `sv.progressAt`; `/pbfe progress`; the settings panel's switch and "test" button.
* A control that will not build sets `failed`, says so once, and the bar is off for the session; the cut or paste is
  untouched.

**Unverified on a console:** that the window draws over the housing editor HUD (top centre is a guess about a free spot:
`/pbfe progress test` and `bottom`/`center` exist for that), that `CT_BACKDROP` with only colours draws a solid rectangle (the
sibling does exactly this), and that setting the draw layer and tier is accepted (the sibling treats a refusal as survivable
too; so does this).

**Tests.** Section 36 (mock window manager recording each control): not built until used; shown at the top, no clicks; fills
monotonically to 100%; placing then linking; a time left; Cut, Move, Undo titles; "done, 3 failed" and red; "stopped"; a later run
not hidden by an earlier run's linger; bottom; off; Japanese; a window that cannot be built (said once, the paste unharmed);
the test bar; the settings switch and button.

## 25. "Cut" along the bottom of the screen was a second copy of the palette's (1.0.6)

Reported: with a linked furnishing selected, the button bar along the bottom of the screen showed "□ Cut" as well as the
palette beside the reticle. Redundant: remove the bottom one.

The bottom bar is the keybind strip. Since 0.6.1 the strip's own Browse button had been RENAMED "Cut" while a linked
furnishing was in the reticle (and re-added on every target change by `RefreshEditorStrip`, because the strip keeps one
descriptor per keybind and the client's palette refresh had replaced it with the palette's input-only Cut). Reading the
client again (zo_keybindstrip.lua, housingeditorhud.lua) gives the rules that decide what the bottom shows:

* The strip keeps ONE descriptor per keybind; a second removes the first. A non-ethereal descriptor is drawn as a button
  only while it is the registered one; an ethereal one (all palette entries) is input only.
* `ZO_HousingEditorHud:UpdateKeybinds` (called on every `EVENT_HOUSING_TARGET_FURNITURE_CHANGED` in selection mode, and on
  link / placement / path changes) adds the palette THEN the strip, so Browse is registered last and drawn. The inspection
  HUD's palette `RefreshKeybinds` registers the palette's descriptors again, which removes Browse.
* A button whose control is hidden (its `visible` says no) does NOT handle input (`TryHandlingKeybindDown`). So hiding
  Browse with `visible = false` would leave the square button dead whenever Browse is the registered descriptor. That
  approach was rejected.

**Change.** Browse keeps its own name (nothing says Cut along the bottom). What changed is which descriptor the strip keeps
while a linked furnishing is in the reticle: it is made the palette's Cut (input only, so nothing is drawn at the bottom),
by refreshing the palette a frame after the client's own update (`SettleEditorKeys`; a frame, so that it is the last
word). That is triggered by the target event and also by Browse's wrapped `visible`, which the strip calls when it draws
Browse (so a full update with no target event, e.g. a link being made, is caught too). With anything else in the reticle
the strip's Browse is re-added (`UpdateKeybindButtonGroup`) and drawn as before. Both descriptors' callbacks cut when a
linked furnishing is in the reticle, so the square button cuts in the one-frame window too. Scheduling is debounced.

**Not verified on a console:** all of this follows the client's source and the mock. If Cut ever fails to react with a linked
furnishing selected, `/pbfe editor off` then `on` restores the earlier arrangement's inputs, and the report of what the bottom
bar and the palette showed would say which descriptor the strip kept.

**Tests.** Section 25 now runs each of its square-button checks in three orders (rebuild + target event; refresh; a full
update with no target event) against a mock strip that models drawing and handling: linked piece, nothing drawn along the
bottom and the button cuts; unlinked, Browse drawn and browsing; the one-frame window; bursts of events are one refresh;
repeated updates do not run on; moving between linked and unlinked brings Browse back and takes it away.
