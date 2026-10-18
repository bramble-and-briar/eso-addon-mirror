# PB's FurnitureEditor

Copies a group of **linked furnishings** from one of your houses into another, in The Elder
Scrolls Online on console.

- **Author:** PinkBanther
- **Version:** 1.0.6 (reading a house and the editor's Copy button are confirmed on a console; placing, linking, removing, travelling, the wheel and the cursor point are still being checked, see `FINDINGS.md`)
- **Needs:** nothing. No libraries.

## What it does

A build made of linked furnishings — a table with everything on it, a bookcase with its books —
cannot be carried to another house; the game has no copy button. This add-on reads the links in
the house you are standing in, keeps a group as a clipboard, and in another house places the same
furnishings at the same positions relative to you, from your own bags, and links them again.

It is **a copy, not a move**. Placing a furnishing takes it out of a bag, so you need the items
in hand: duplicates in your backpack, bank, house chests or the furnishing vault. A paste starts
as a dry run that tells you what is short.

## The first session

This build is for finding out what the console allows. Do these in order; the first four change
nothing in your house. Whatever they print is what the next version is built from.

```
/pbfe api                    does every function exist, and is any of them private
/pbfe state                  house, editor mode, limits, what is on the clipboard
/pbfe list                   the linked groups here, nearest first
/pbfe where                  your position and the nearest furnishings: is it one space
/pbfe calib                  work out how the client turns things (read-only)
/pbfe aim                    where the cursor meets the floor (look down at it first)
/pbfe kind 3                 item or collectible? what the client says about the nearest 3 pieces
/pbfe items                  placeable items in your backpack, with slot numbers
/pbfe probe place 12         place ONE item at your feet, read it back, take it away
/pbfe probe link 12          two of them: link, move the parent, unlink, take both away
```

`probe` needs a house you own. `probe link` needs a stack of two or more of something cheap.
Both clean up after themselves; `/pbfe stop` cancels them where they stand.

## Copying a group

```
/pbfe list                   see the groups; the numbers are for this list
/pbfe copy 1                 the nearest group (also: copy near, copy sel, copy all, copy 2 5)
```

`copy sel` takes the furnishing you have selected or are aiming at, and its whole tree. Stand
next to the group when you copy: **where you stand is the anchor.**

Copying works in any house you can edit. The clipboard is kept in saved variables, so it
survives going to the other house, logging out and coming back. **A paste that places everything
empties it**, so a copy that has been used does not sit there to be pasted by mistake. To paste the same
thing more than once, `/pbfe save <name>` it first and `/pbfe load <name>` it each time. If a paste
could not place everything (a piece missing from your bags, a stop half way) the clipboard is kept, and
the message says how many were not placed.

```
/pbfe save table             keep it under a name (also: load, drop, saved, show, clear)
```

## Pasting

Go to the other house (you must own it). Stand where the group should start.

```
/pbfe paste                  dry run: the plan, what is short, what would be skipped
/pbfe paste go               place it, then link it
```

| word | meaning |
| --- | --- |
| `to 2` | go to house #2 (see `/pbfe houses`) first, and paste there; see below |
| `outside` | with `to`: travel to the outside of the house, not the inside |
| `here` | (default) put the group where you stand, by the same offsets it had from you when copied |
| `same` | keep the original coordinates |
| `rot 90` | turn the group by 90° (needs `/pbfe calib` first) |
| `up 20` | raise it 20 cm |
| `force` | place what can be placed, skip what is short |
| `go` | do it |

### Pasting into a house you are not in

A paste works on the house you are standing in. To name another one:

```
/pbfe houses                 your houses, numbered
/pbfe paste to 2             travel to #2, and show the plan when you arrive
/pbfe paste to 2 same go     travel there and place the group at its original coordinates
```

The player lands on the doorway, where the game refuses to place anything, so **after a trip
`here ... go` shows the plan and waits**: walk to where the group goes, then `/pbfe paste go`.
`same` does not depend on where you stand, so `paste to 2 same go` runs by itself once the house
has finished loading. `/pbfe stop` cancels a trip that has not arrived.

```
/pbfe stop                   stop after the furnishing in flight
/pbfe undo                   take back everything the last paste placed
/pbfe speed 300              ms between requests (default 450; raise it if the server complains)
```

`undo` returns the furnishings to the bag the editor retrieves to (your backpack unless you
changed it), so keep some room there.

## Moving instead of copying (cut)

A furnishing exists once, so a move has to take it out of the house into your bag before it can
go into the next. `cut` does that, and then the paste is the one you already know.

```
/pbfe list
/pbfe cut 1                  preview: what leaves, and whether the bag has room. Removes nothing.
/pbfe cut 1 go               copy the group, then take it out of this house
/pbfe paste to 2 same go     (or walk to the other house and /pbfe paste) put it there
```

`cut` takes the same words as `copy` (`near`, `sel`, `all`, several numbers). It needs a house
you own, and room in the bag the editor retrieves to. Whether an item stacks is read from its item link when
the group is copied (`IsItemLinkStackable`): a piece that does not stack takes a slot of its own, and that is
counted exactly even for a kind that is in no bag yet. The room is counted the way the game stores
things: a retrieved furnishing joins a stack of its own kind that still has space, and takes a new slot
only when none has, so the preview counts **stacks, not pieces** ("they go to your backpack: 40 free
slots, 3 needed"). A cut is refused only when it is certain not to fit (fewer free slots than the least
it can need). One thing cannot be known: how a kind stacks that is in no bag and has never been seen.
For those the preview gives a range ("3 needed (up to 4 if the 3 kinds not yet seen do not stack)") and
a cut that falls inside it starts with a warning; if the bag does fill, the cut stops there, nothing is
lost, and `/pbfe cut resume go` finishes it once there is room. Every stack size the add-on sees in a
bag is remembered, so the range closes by itself over time.

A cut is built to be undone from either end, because the dangerous moment is between "out" and
"in":

* The clipboard holds the whole group **before** anything is removed. While a cut is pending,
  `copy`, `cut`, `load` and `clear` refuse to replace it unless you add `force`.
* **Put it back:** in the same house, `/pbfe paste same go`. If the cut stopped part way, only the
  missing pieces are placed; what is still standing is just linked again.
* **Finish it:** `/pbfe cut resume go` removes whatever is still there.
* When every piece is placed again the move is complete, and the clipboard is emptied (a cut that
  is only part way in keeps it: it is the only record of where the rest goes).
* If a paste into the new house only gets part of it in, `/pbfe undo` takes that part back into your
  bag, and you can paste again.

Saved variables are written by the game when you log out or reload the UI. If the game crashes
between the cut and the paste, the clipboard may not have been written yet. The furnishings are
safe in your bag either way; it is the arrangement that would be lost.

## Reservations: decide now, paste when you get there

A house can only be edited from inside it, so a paste cannot be sent to a house you are not in.
What can be done is to decide now and have it happen when you next enter. Several reservations can
wait at once, copies and moves alike.

```
/pbfe list
/pbfe reserve copy 1 to 2 same go        read group 1 now; house #2 gets it on your next visit
/pbfe reserve copy 2 to 3 same           ...and group 2 for house #3, but only SHOW the plan there
/pbfe reserve cut 1 to 2 same go yes     take group 1 OUT of this house now, put it into #2 later
/pbfe reservations                       what is waiting
```

The words are the ones a paste takes (`same`, `here`, `rot 90`, `up 20`, `force`, `go`), with
`to <number>` from `/pbfe houses` saying where. Pick `same` for anything that should happen by itself:
you arrive on the doorway, so `here` has no meaning until you have walked somewhere.

**When you enter a house that has reservations** it is given time to finish loading, then they are
worked through one at a time, oldest first:

* with `go`: "reservation #1 starts in 10 s -- /pbfe stop cancels it". The ten seconds are there on
  purpose, so that a reservation made long ago and forgotten cannot rearrange a house unannounced.
  `/pbfe stop` cancels it for this visit; the reservation stays on the list.
* without `go`: the plan is shown and nothing is placed. `/pbfe reservations run 1 go` does it.
* if it cannot be done (short of items, not your house), it says why and stays for the next visit.
* a paste that placed some but not all is marked **partial** and is not repeated, because that would
  place the pieces twice. `/pbfe undo`, then `/pbfe reservations retry <n>`.

**A cut reservation takes the furnishings out now.** The reservation then holds the only record of
where they go, so `reservations drop` refuses to forget it unless you add `force`; and the last word
is `yes`, not `go` (`go` already means "paste by itself"). Without `yes` you get the same preview as
`/pbfe cut`. If the cut stops half way (the bag filled up), `reservations load <n>` puts it on the
clipboard and `/pbfe cut resume go` finishes it.

```
/pbfe reservations run 2 go       go to its house now, and do it (a trip, then the paste)
/pbfe reservations drop 3|all     forget one (a move needs 'force')
/pbfe reservations load 2         put its clip on the clipboard
/pbfe reservations retry 2        make a partial one wait again
```

Reservations are kept in saved variables, so they survive logging out. Inside and outside a house
are not told apart: a reservation fires when you enter the house by either door.

## Copy and Cut in the housing editor (gamepad)

In the housing editor, aiming at a **linked** furnishing already shows buttons beside the reticle
(× Edit, △ Precision Edit, L3 Link). Two more appear:

| button | does |
| --- | --- |
| **○ Copy** | puts the whole link tree the furnishing belongs to on the clipboard |
| **□ Cut** | the same, and it leaves this house at once (into your bag) |

That is all. **There is no house to choose.** The clipboard is a clipboard: leave the editor, go to any
house of yours, and hold the quickslot button. The wheel offers **Paste** (after a copy) or **Move**
(after a cut); point at it and let go.

* **Where it lands** is set by `/pbfe position`: `aim` (the default: the floor where the cursor points,
  taken the moment you let go), `here` (where you stand) or `same` (the original coordinates; only
  faithful in the house it came from). If `aim` cannot be read (looking at the horizon, up, or too far),
  **the group is pasted where you stand instead, and the chat says so**; a pick never ends in
  "nothing happened".
* **□ is also Browse.** The square button is already "Browse" (the furniture browser) in the editor,
  and the game keeps only one button per key. So both live on it: **while a linked furnishing is in the
  reticle □ is Cut, and at any other time it is Browse as before.** Cut is drawn on the palette beside Copy
  and **nowhere else**: the button bar along the bottom of the screen shows no "Cut" (it would only repeat the
  palette's), and Browse's button there comes back when the reticle leaves a linked piece.
* **Copy** needs a house you can edit; **Cut** needs one you own. A cut counts the bag's room first (stacks, not pieces).
* **A cut waits to be pasted.** Until it is (Move, or `/pbfe paste same go` to put it back), a second
  copy or cut is refused, because the clipboard is the only record of where its furnishings go. The refusal
  says where the cut stands: how many of its furnishings are still standing in this house, or that all are
  out and waiting for Move.
* **A cut that stopped part way carries on** when you press Cut (square) on one of the furnishings still
  standing (or `/pbfe cut resume go`). The usual reason it stopped is a full bag: make room first. The same
  headlines (cut done, cut stopped, refused, paste result) also appear on the screen, because the chat is not
  in view while you are in the editor.
* After a paste or move that places everything the clipboard is emptied and the wheel is the game's
  again. If something was not placed, the clipboard stays (for `/pbfe paste`), but the wheel entry is gone.
* `/pbfe editor off` takes both buttons away (and Browse is Browse again); `/pbfe editor on` brings
  them back; `/pbfe editor` shows the state. Gamepad interface only. Japanese names (コピー / カット)
  on a Japanese client.

## Paste and Move on the quickslot wheel

Typing a paste with a console keyboard is slow. So when you arrive in a house that has something
waiting for it, **the quickslot wheel** (hold the quickslot button) temporarily gains up to two
entries at the end, **Paste** and **Move**. Point at one, let go, and it is done, with you standing
where you are, so `here` finally means something: walk to the spot first.

```
quickslot wheel: Paste (1) / Move (1). hold the quickslot button, point at it, let go
```

* **What is on it.** *Paste (n)* stands for every waiting copy, *Move (n)* for every waiting move.
  They are: the clipboard from the editor (or `/pbfe copy` / `/pbfe cut`) until it has been pasted, in
  any house of yours; your reservations for this house; and a paste that travelled here
  (`/pbfe paste to 2`) and only showed its plan. Picking one runs all of its kind, one after the
  other, as if you had typed `/pbfe paste ... go`.
* **When.** Only in a house you own, only when something is waiting, and never in combat. The other
  wheels (emotes, mementos, tools, allies) are left alone.
* **When it goes.** Entries are added only while there is something to do. When the last one is done
  the chat says "the quickslot wheel is back to normal", and the wheel is the game's again. (The
  entries are at the end, so while they are there the eight slots are spread round a ten-slot circle.)
* **At most two.** The accessible wheel has ten hotkeys and the quickslot wheel eight slots, so two
  extra entries fit and no more. That is why there are exactly two kinds.
* **It does not pop up by itself.** A wheel opens when you hold the button; the chat tells you it is
  there.
* **Off switch:** `/pbfe menu off` (and `on`, and `/pbfe menu` for the status). Names are Japanese on
  a Japanese client.

It uses `SecurePostHook`, the game's hook that runs after the original, apart from its call chain,
and it hooks only the first time something is waiting. If that is not available, or anything
unexpected happens inside it, it stops itself for good with a message and the wheel is the game's
again; the commands keep working.

## The progress bar

A cut, a move and a paste are hundreds of requests, and the chat is not in view in the housing editor, so a bar is
drawn over the screen (top centre by default): what is being done (Cut, Move, Paste, Undo), how far it has got, and
roughly how long is left once there is something to go on.

* "Done" is what has been **confirmed**: a piece is out of the house, or placed, or linked. A request that fails
  leaves the bar short of full; the end says "done, 3 failed" and the bar is red. A stopped run says "stopped".
* A paste counts its placements and its links together; the word beside the count says which it is doing
  (placing, linking, retrying, finishing).
* It stays three seconds after the end, unless another run starts.
* `/pbfe progress on|off`, `top|center|bottom` for where, and `test` for a bar that fills over a few seconds, to see
  where it is and how it reads without cutting anything. The add-on settings have a switch and a test button.
* It is a plain window that takes no clicks, drawn in front of everything, with a font the console already has
  loaded. If it cannot be built it turns itself off, says so once, and the cut or paste goes on without it.

## Forgetting what is held

The add-on holds the clipboard (a copy, or a cut that has not been pasted), a record of the last paste (what
`undo` works from), reservations, and a trip that has been started. A paste that places everything empties the
clipboard by itself; for the times it did not, or to start clean:

```
/pbfe reset                  forget the copy or cut on the clipboard
/pbfe reset all              also the undo record, reservations, a trip and the wheel offers
/pbfe reset show             what is held
/pbfe reset ... force        without asking twice
```

With `LibHarvensAddonSettings` installed (optional) the same is in the add-on settings, under "PB's
FurnitureEditor": Clear copy / cut, Clear everything, Stop what is running, Show what is held (the labels are
in Japanese on a Japanese client). A cut that has not been pasted is asked twice (press again within ten
seconds): its clipboard is the only record of where its furnishings go. Nothing here touches furnishings in a
house or a bag, a running paste is not interrupted (stop it first), and saved clipboards (`/pbfe saved`) are
never cleared. The panel has no row that shows the state, because the library cannot rewrite a row after it is
built; "Show what is held" prints it to chat.

## Groups of mixed kinds

A linked group can hold crafted items, crate items, special furnishings, and Crown Store collectibles at
once. They differ in what the add-on must do: an item is placed from a bag, a collectible from your
collection; and each counts against one of the house's four limits (traditional, special, collectible,
special collectible). The plan lists each limit against what the group needs ("special furnishings: 1 to
place, room for 2"), and `/pbfe show` and the cut preview say how many of each kind a group holds.

A "no room" answer from the game is about **one** limit, so it does not stop the paste: that kind is
marked full, its remaining pieces are not asked for, and everything else goes on. The house's performance
budget (`METRICS_LIMIT_HIT`) is the same: a heavy piece is refused, three in a row stop the paste.
`/pbfe kind <n>` says, for the nearest n furnishings, which limit each counts against and what the bags hold.

## Big groups

ESO lets one furnishing take **50 children**, and each child can have children of its own, so a group can be
hundreds of furnishings. A paste of one is hundreds of requests, and each is a chance for the server to
say "not now". So:

* The plan says how wide the group is ("links: 80, most children on one furnishing: 50") and `go` says
  roughly how long it will take.
* A placement or link that fails for a reason that may pass is **asked for again**, in rounds, after a
  pause; rounds go on while they get something through, up to eight, and stop when four in a row get
  nothing through. A refusal that cannot change (a bad position, a stolen item) is not repeated.
* An answer that comes **late** (after the add-on gave up waiting) is taken in as the piece it was, not
  placed a second time. Before a piece that was never answered is asked for again, it waits once more.
* If the server says a furnishing **takes no more children** (`LINK_HAS_TOO_MANY_CHILDREN`), the add-on
  remembers how many it took and links the rest under a sibling that the parent already holds. The group is
  still one tree and still moves as one. A group copied from the game never needs this, because the game
  made it within its own limit.
* A cut or undo that leaves furnishings behind asks for them again the same way.

The 50 comes from ESO's Update 20 announcement; the API does not expose it, so the add-on learns the real
limit from the server's own refusal. None of this has run on a console yet.

## Limits

* Path data (furniture that follows a path) is not copied; the piece is, and the copy says so.
* Links to a furnishing that is skipped are dropped, and reported.
* A group can only be turned if the client's rotation order has been measured (`/pbfe calib`),
  and tilted pieces only if yaw is applied last. Otherwise `rot` places flat pieces only, with
  `force`, and tells you what it left out.

## Testing without a console

```
luajit test/run.lua          (from this folder; any Lua 5.1+)
```

`test/harness.lua` stands in for the client: houses with links, bags, the editor's
request-then-event rhythm, a server that is sometimes busy, silent or refuses. It proves the
logic is consistent with itself. It cannot say the console behaves like it — that is `/pbfe probe`.

See `FINDINGS.md` for what the client's own code says, the design, and the list of questions only
a console can answer.
