# Bureau of Private Dispatches

A lightweight whisper-notification addon for *The Elder Scrolls Online*. It
turns every incoming private message into a compact, movable notification, so a
whisper cannot disappear unnoticed in a busy chat window. Each sender owns one
notification: a later message updates that notification and moves it to the top
instead of filling the screen with duplicates.

> **Compatibility:** API: LIVE 101051. Requires LibAddonMenu-2.0. pChat is an
> optional dependency used only to fill restored whisper previews.

---

## What it does

When another player whispers you, a notification area appears with that
player's account `@id`, a short preview of the latest message, how long ago it
arrived, and how many unread messages that sender has sent. The newest sender is
normally first. A second whisper from the same sender refreshes the existing
notification, restarts its pulse, and returns it to the top; an overdue sender
can later be promoted for its one explicit follow-up reminder.

The first visible sender owns one expanded two-line card. It is normally the
newest sender, while a one-time overdue reminder can temporarily promote an
older one. Every sender below it uses a compact one-line row, so the active
message keeps its context without making the full stack tall. Six sender
notifications are visible by default; settings can raise this to eight or
twelve. Additional senders remain in the ordered model and are available
through the paged overflow row.

Drag the header to place the notification area anywhere on screen. Its exact
position is saved account-wide and restored after logout or `/reloadui`.

---

## Reading a notification

Every card carries the same five pieces of information in fixed positions, so a
dense stack stays scannable without reading it word by word.

```text
┌─────────────────────────────────────────────┐
│ ✉ DISPATCHES                  6 · 9   ⌃  ⊘ │  senders, messages, controls
├─────────────────────────────────────────────┤
│▌ @Alpha                      ×2  !   12s  × │  identity, unread, status, age
│▌ Are you free for the dungeon...             │  expanded latest sender
├─────────────────────────────────────────────┤
│▌ @Vesta  Trading the motif now     *   1m  × │  compact waiting sender
│▌ @Orion  Invite after the boss  ×3 ...   4m  │  reply composer opened
├─────────────────────────────────────────────┤
│▌ @Aster  Ready when you are          5m   × │
│▌ @Nyra   Thanks for the trade        6m   × │
│▌ @Theo   See you tomorrow            7m   × │
└─────────────────────────────────────────────┘
```

- **Colored identity.** A stable hash of the sender's `@id` picks one of five
	palette hues, so the same person always arrives in the same color. Every row
	keeps its colored rail without a letter badge. Group, friend, and guild
	relations are listed in the tooltip rather than taking space in the row.
- **Unread counter.** Shown only from the second unread message onward, capped at
	`99+` so a spammer cannot widen the card.
- **Follow-up status.** Empty while pending, `...` while reply grace is active,
	amber `*` while waiting, orange `!` when overdue, and green `R` after reply.
- **Relative age.** `now`, `12s`, `4m`, `2h`, refreshed once per second while
	tracked dialogs exist.
- **Per-card dismiss.** The reserved dismiss target stays stable, while its `×`
	label appears only on hover.

---

## Features

### One notification per sender
- Incoming whispers are keyed by the sender's account `@id` when ESO supplies
	it, with the character name as a defensive fallback.
- A sender can own only one active notification.
- The latest message replaces that sender's previous preview and moves the
	sender to the front of the list.
- Unread messages accumulate per sender until an outgoing whisper confirms the
	reply or the notification is dismissed explicitly.
- Dismissing a sender removes only the current notification. A later whisper
	from that sender creates a fresh one normally.

### Adaptive, readable presentation
- The first visible sender is always expanded: sender, unread count, follow-up
	status, and age on the first line, plus up to 34 UTF-8 characters of the latest
	message below. It is normally the newest sender, but an overdue reminder can
	promote an older sender once.
- Every older sender uses a compact one-line row with separate areas for the
	account id and muted preview, followed by unread count, status, and age.
- Moving the pointer over the panel temporarily freezes presentation order. New
	messages still update immediately, but no row can jump away under the cursor;
	new senders are appended until the interaction ends, then newest-first order
	is restored in one redraw.
- Six sender cards are rendered by default. The visible-notifications setting
	selects six, eight, or twelve per page; an overflow row provides access to
	additional waiting senders.
- Long account names and previews use ellipsis rather than resizing or shifting
	the panel. The ellipsis is counted inside the character budget, so a preview
	never exceeds its configured width.
- Rich chat markup is cleaned before display: visible link captions are kept,
	while color tags, texture tags, line breaks, tabs, and repeated whitespace are
	removed. Malformed markup is handled by stripping every remaining pipe, so a
	whisper cannot inject formatting into the notification chrome.

### Clear visual cue and direct controls
- The most recently changed notification pulses a wash of the sender's own
	identity hue across the card a fixed number of times. Older simultaneous cues
	stop, so a burst of whispers never animates the whole stack.
- Re-rendering the panel never restarts a pulse. The cue is bound to the message
	revision, not to the card slot, so dismissing one sender does not make the
	remaining cards look newly arrived.
- **Left-click a card** to open a whisper to that sender. Opening the composer
	does not remove the notification or count as an answer.
- **Right-click a card** to hide it onto the session tape.
- **Middle-click** marks the sender read without closing the card.
- **Shift+Left** opens chat without starting reply grace. **Ctrl+Left** opens
	mail, **Ctrl+Shift+Left** teleports when the sender is a group member, friend,
	or guildmate, and **Ctrl+Alt+Right** asks before ignoring. Ignore uses a
	different modifier from teleport so swapping only the mouse button cannot
	trigger it. The hover tooltip lists only the actions that currently apply.
- Every sender card has its own dismiss button, armed on mouse-down so a whisper
	arriving mid-click cannot redirect the dismissal to a different sender. The
	button always hides; it never ignores.
- The header uses stock ESO icons for lock, collapse, and clear-all. The
	clear-all icon is distinct from each card's hover dismiss cross.
- The header count reports both waiting senders and accumulated messages.
- A new whisper never expands a collapsed panel automatically. Instead, the
	header briefly pulses with that sender's identity color.
- Incoming whispers play a short sound, throttled so a burst does not stack
	alerts. `/bpd mute` silences incoming and overdue sounds. `/bpd dnd` and combat
	auto-DND keep collecting cards but hold pulses and sounds until the mode
	ends, then deliver the deferred visual cue once.
- Mouse-hover tooltips show the full cleaned latest message above the available
	actions. Restored cards without message text show an explanation instead.
- Keyboard bindings live in Controls → Bureau of Private Dispatches. They are
	unassigned by default. Reply uses the focused sender, or the latest incoming
	whisper if nothing is focused, and does not overwrite text already in the chat
	box. Clear-all from a key only works while the panel is visible and expanded.
	The header lock icon, and its matching binding, freeze placement.
- `/bpd scale` and `/bpd opacity` resize the panel and dim only its backgrounds.
	Text, glyphs, and identity rails stay fully opaque. `/bpd autocollapse` hides
	cards while in combat without changing the saved collapsed state and without
	replacing DND: combat auto-DND still holds sounds and pulses, and expanding
	the header during a fight keeps it open until combat ends.
- Settings are in ESC → Settings → Addon Settings → Bureau of Private
	Dispatches. LibAddonMenu-2.0 is required. `/bpd settings` opens the same
	panel. Keyboard bindings remain in Controls.

### Follow-up tracking
- Incoming whispers start one unanswered cycle per sender. Repeated messages
	update the preview and unread count without postponing the original deadline.
- The addon listens for `CHAT_CHANNEL_WHISPER_SENT`. Only an observed outgoing
	whisper to the same sender confirms that the current incoming revision was
	answered; opening or closing the chat input alone does not.
- Address resolution first matches the outgoing event's account/character
	aliases, then checks `CHAT_ROUTER`'s current whisper target. A recently opened
	card is used only as a bounded fallback when the event and router expose no
	explicit foreign target, preventing a manual whisper to another player from
	closing the wrong cycle.
- Opening a reply shows `...` and grants a 30-second reminder grace period while
	the player types.
- After 90 seconds without a reply, the card shows a quiet amber `*`.
- After three minutes, the card becomes overdue: it shows an orange `!`, moves
	to the front when interaction is not locked, pulses more strongly, and plays
	one guarded notification sound.
- The overdue cue is deferred while the player is in combat, in DND, outside a
	gameplay HUD scene, dragging the panel, or interacting with its controls. The
	deadline still advances in the background and the cue is delivered once
	conditions are suitable. Restored and queued reload whispers do not replay
	arrival pulses or sounds.
- A confirmed reply shows a green `R`, clears unread state, and keeps the card
	visible for four seconds before removing it automatically.
- A later incoming whisper starts a fresh unanswered cycle. Right-click,
	per-card dismiss, and clear-all mean that no follow-up is required.
- Read is separate from answered and dismissed. Clearing unread leaves the card
	in place and keeps the follow-up timer running, but does not replay the
	overdue sound. Dismiss hides the sender onto a session-only tape (RAM only);
	the last hidden sender can be restored from the overflow row. An outgoing
	whisper to a taped sender drops that tape entry instead of bringing the card
	back. Clear-all empties both the panel and the tape.
- Overflow is paged. Left-click walks through extra senders using the selected
	page size of six, eight, or twelve; a new incoming whisper returns to the
	first page.
- Follow-up timers keep running across `/reloadui`. Unanswered senders are
	snapshotted per character so a reload cannot wipe pending cards. The snapshot
	stores only sender identity, unread count, and timestamps: never message
	text, public chat, or answered cards. A restored card shows a placeholder
	preview and does not replay its arrival pulse or overdue reminder. If pChat
	is loaded, the placeholder may be replaced from pChat's in-memory whisper
	history after reload; that text is never written back to this addon's
	SavedVariables. Snapshots older than six hours, and leftover character
	buckets beyond eight, are discarded.
- Whispers that arrive after the addon file loads and before initialization
	finishes are queued and applied once the panel exists, covering the gap where
	vanilla chat may still be unready. This cannot invent a whisper the server
	never delivered during a loading screen.

### Movable and persistent
- Drag the header with the left mouse button to move the entire notification
	area.
- The position is saved when the drag ends, sampled from where the panel actually
	came to rest rather than from the anchor it was created with, so the placement
	survives logout and `/reloadui`.
- The panel is clamped to the screen, and the clamped result is what gets saved,
	so the panel cannot drift on the next login, and a resolution change cannot
	strand it out of view.
- Position and collapsed state are stored in account-wide SavedVariables, and both
	are validated on load: a corrupt or out-of-range coordinate falls back to the
	release default instead of leaving the panel unanchored.
- A position saved by 1.2 or earlier is converted to the current format on first
	load, so upgrading keeps the panel where it was.
- `/bpd reset` restores the release default placement and saves it immediately.
- `/bpd scale [0.85-1.5]` and `/bpd opacity [0.4-1]` persist account-wide. Opacity
	multiplies backdrop alpha only. Scale uses the top-level window's `SetScale`.
- `/bpd autocollapse` is off by default. When on, combat hides the card stack for
	the duration of the fight and restores the previous expanded layout afterwards.

### Stays out of open windows
- The panel is shown only during gameplay: the ordinary HUD, and the cursor-released
	HUD state where it can be dragged.
- Opening inventory, the map, a menu, or any other full window hides the panel for
	as long as that window is open, and returning to gameplay restores it.
- Nothing is lost while hidden. Whispers that arrive continue to be collected and
	ordered, so closing the window reveals the current state rather than a stale
	one. New-message and overdue cues are delivered only when gameplay returns.

### Localization and dependencies
- Full English and Russian runtime localization.
- English is loaded first as the complete fallback; the active client language
	overrides only the strings it translates.
- Uses only ESO's built-in UI and event APIs. No external libraries are needed.

---

## Why it is built well

- **One bounded scheduler.** The addon does no per-frame polling. One one-second
	update handles both relative timestamps and follow-up deadlines while tracked
	dialogs exist, including when the panel is collapsed or scene-hidden. It is
	unregistered as soon as the model becomes empty.
- **O(1) sender lookup.** A dictionary keyed by sender `@id` finds the existing
	notification directly. A small newest-first array owns presentation order;
	promoting a sender to the front is a bounded array operation because the model
	itself is capped.
- **Bounded model.** Tracked senders are capped, and trimming the ordered array
	always trims the dictionary with it, so a long session with many unique
	senders cannot grow state without limit.
- **Fixed UI allocation.** The maximum number of visible card controls is
	created once during initialization. Refreshes only rebind and reposition those
	controls; whisper bursts do not allocate new UI trees.
- **One redraw per action.** Clear-all replaces the model and refreshes once,
	rather than redrawing after every removed sender.
- **Self-healing render pass.** The refresh tolerates an ordered id with no
	matching entry: it prunes the stale id and blanks the slot instead of aborting
	mid-layout and leaving the panel in a half-built geometry.
- **UTF-8 safe previews.** Preview truncation walks encoded code points and
	validates continuation bytes, so Cyrillic, CJK, and emoji sequences are not
	split in half and malformed input cannot emit an orphaned byte.
- **Presentation separated from language.** Runtime logic contains no visible
	English or Russian prose; all player-facing text lives under `Localization/`.

---

## Architecture at a glance

The runtime is split by responsibility and loaded in dependency order by the
manifest. Modules share the `BureauOfPrivateDispatches` namespace; reusable
implementation helpers stay under its `private` table rather than becoming
additional globals.

```text
Localization/*  complete fallback and active-language overrides
		|
BureauOfPrivateDispatches.lua
		namespace, release identity, SavedVariables identity
		|
Config.lua      visual and behavioral release defaults
		|
Utilities.lua   formatting, sanitization, UTF-8, color helpers
		|
Model.lua       sender state and incoming-whisper transitions
		|
Position.lua    saved position, validation, migration, clamping
		|
UI.lua          pooled controls, scenes, layout, clock, animation
		|
Commands.lua    slash commands and deterministic smoke-test fixtures
		|
Settings.lua    LibAddonMenu-2.0 settings panel
		|
Bootstrap.lua   SavedVariables creation and event registration
```

The main runtime boundaries are:

- **Chat adapter:** incoming `CHAT_CHANNEL_WHISPER` events create/update cycles;
	outgoing `CHAT_CHANNEL_WHISPER_SENT` events resolve matching cycles without
	creating notifications. Events that arrive before initialization are queued.
- **Sender model:** keeps one entry per sender plus newest-first ordering, with
	per-sender unread counts, message revisions, aliases, and follow-up state.
- **Presentation:** binds the visible portion of that model to a fixed card pool,
	expands the first visible sender, compacts older rows, and owns the temporary
	interaction-locked display order.
- **Persistence:** validates and migrates player-owned placement independently
	from the visual controls that consume it, and snapshots unanswered whisper
	metadata (never message text) so cards survive `/reloadui`.
- **Adapters:** bootstrap owns ESO events, while commands provide diagnostics over
	the same model paths used by live whispers.

---

## Module overview

| Module | Responsibility |
| --- | --- |
| `BureauOfPrivateDispatches.lua` | Creates the addon namespace and stores release/SavedVariables identity. |
| `Config.lua` | Defines all visual and behavioral release defaults. |
| `Utilities.lua` | Provides localized formatting, chat cleanup, UTF-8 truncation, elapsed-time, and color helpers. |
| `Model.lua` | Owns sender notifications, ordering, limits, aliases, incoming/outgoing whisper handling, follow-up transitions, unanswered-whisper restore, and optional pChat preview lookup. |
| `Position.lua` | Owns saved coordinates, legacy migration, validation, clamping, and reset. |
| `UI.lua` | Builds and updates pooled controls, visibility, timestamps, and pulse animations. |
| `Commands.lua` | Registers `/bpd` commands and deterministic test notifications. |
| `Settings.lua` | Registers the LibAddonMenu-2.0 settings panel. |
| `Bootstrap.lua` | Creates SavedVariables, registers chat events early, restores unanswered whispers, and replays queued events after every dependency is loaded. |
| `Bindings.xml` | Registers keyboard actions shown in Controls. |
| `Localization/en.lua` | Complete English source strings and localization IDs. |
| `Localization/ru.lua` | Russian overrides loaded on Russian clients. |

---

## Slash commands

```text
/bpd clear     Dismiss all notifications
/bpd toggle    Collapse or expand the panel
/bpd reset     Restore and save the default panel position
/bpd mute         Toggle incoming and overdue sounds
/bpd dnd          Toggle five-minute do-not-disturb
/bpd scale [n]    Show or set panel scale (0.85-1.5)
/bpd opacity [n]  Show or set background opacity (0.4-1)
/bpd settings     Open the LibAddonMenu settings panel
/bpd autocollapse Collapse the panel while in combat
/bpd debug        Show diagnostic commands
/bpd              Show localized command help
```

Diagnostic fixtures live under `/bpd debug`: `test`, `testmany`, `testoverdue`,
`testreply`, `read`, and `restore`. `/bpd debug test` always updates
`@BPD_Test_01`. `/bpd debug testmany` creates eight senders. `/bpd debug
testoverdue` and `testreply` exercise the follow-up reminder and answered
states. `/bpd debug read` clears that sender's unread count without dismissing
it; `/bpd debug restore` returns the last hidden sender from the session tape.

---

## Developer configuration

All visual and behavioral release defaults live in the table exported by
`Config.lua`. It groups:

- panel, header, card, and overflow dimensions;
- card internals: rail width, text padding, compact sender width, meta column
	widths, row offsets, and header icon textures;
- normal and compact font sizes;
- background, text, hairline, hover, and accent colors;
- the per-sender identity hue palette;
- message and sender preview lengths;
- expanded/compact geometry, visible-sender, and tracked-sender limits;
- follow-up waiting, overdue, reply-grace, reply-target, and answered-display
	timers;
- default screen placement (right-edge inset and top offset), the maximum accepted
	coordinate magnitude, the minimum on-screen margin used when clamping, and
	panel scale/opacity ranges;
- pulse duration, alpha range, tint opacity, and loop count;
- card draw levels, which fix the stacking order of body, hue wash, accent, and
	text independently of control creation order;
- normal and overdue pulse parameters, reminder sound name, and scheduler
	interval;
- interaction-unlock delay used to keep rows stable across child-control mouse
	transitions.

After changing these release defacombat auto-collapse, follow-up timers, sound,
and restore options are deliberately not part of `CONFIG`; they remain in
and combat auto-collapse are deliberately not
part of `CONFIG`; they remain in SavedVariables until reset.
