TGW Bind & Invite 1.0.0 — RELEASE
Author: @TheGreyWolf98

One addon, independent AutoBind and AutoInvite features. No library dependencies.
Both automatic features default to OFF. Account settings are separate per server.

OPEN
Type /tgw or /tgwbi in ESO chat. All main options and keyword presets are
available in the controller window. A custom keyword uses /tgw keyword yourword.
This addon opens through a chat command; it does not add a pause-menu entry.
LB/RB: tabs. D-pad: selection. A: change / include / exclude.
X: arm binding, then press again within 10 seconds to commit. Y: refresh. B: close.
LT/RT: pages. Xbox on-screen chat entry can be used for the opening command.

QUICK BIND COMMAND
/tgw bind immediately binds one eligible copy of each missing collection piece
in this character's backpack. It prefers the lowest-quality duplicate and leaves
spare copies alone. Locked items and pieces marked SKIP this session are protected.
This command commits immediately; use the preview for individual choices.

MANUAL BINDING — THE FARMING WORKFLOW
Leave Automatic Binding OFF. Complete the dungeon/trial, offer or trade drops,
then open /tgw and choose Review Backpack, or switch to the preview tab.
One lowest-quality eligible instance per missing collection piece is selected.
A marks individual preview pieces SKIP; X then X binds included pieces.
Binding ends group trading rights. Locked items are always skipped.
SKIP marks last for this session; use the game's inventory lock for lasting protection.
Only backpack gear is considered. Already collected, stolen, locked, non-set,
non-collection and already permanently bound items are excluded.
Items are rechecked and located by unique instance ID immediately before binding.
If an item has moved, become locked, left the backpack or become collected, it is skipped.

AUTOMATIC BINDING
Enable only when you want newly received missing collection pieces bound.
Enabling the toggle does NOT sweep gear already in the backpack.
New inventory arrivals may include transfers, not just monster loot.
Arrivals are gathered for half a second; binding requests are spread over updates.
Combat delays new arrivals; starting combat cancels an active batch. Zone departure
cancels workers. Cancelled remainder can be handled with the manual preview.
Automatic requests are not retried indefinitely if the client rejects binding.

WHISPER INVITES
Choose invite / dungeon / trial / tax, or enter a custom keyword (1-32 characters).
Choose a 4-person dungeon or 12-person trial limit and enable Whisper Auto Invite.
The other player sends the exact keyword as an ESO in-game whisper.
Case and spaces at the beginning/end are ignored. Internal text must match exactly.
You must be solo or group leader. The recipient still accepts the normal invitation.
The console-aware native invitation helper respects platform communication checks.
Pending invites reserve space for 30 seconds; joins release the reservation.
Repeated senders have a 30-second cooldown. One request per second is allowed;
a different sender during that cooldown must repeat the keyword afterwards.
Declined/failed requests may reserve a place until the 30-second timeout expires.
This does not listen to Xbox app messages, recruit roles, queue for activities,
teleport members, accept invitations for them, or promise cross-platform grouping.

FIRST XBOX CHECK
Disable other automatic binding/invitation features, including NQOL invites.
1. Load the addon, open /tgw, cycle tabs and options, close and reopen.
2. Receive an uncollected tradeable set piece with AutoBind OFF: it must stay tradeable.
3. Preview it, mark SKIP, try the batch. Lock another piece and refresh: it must be absent.
4. Use a spare unwanted uncollected piece: X then X should bind it and unlock its
   collection slot. Check the log's confirmed / skipped / unconfirmed result.
5. Enable AutoBind with an existing uncollected item: it should stay untouched.
   Receive a different missing piece: only the new arrival should bind.
6. Enable invites with 'invite'. Ask a friend to whisper 'invite', then repeat it.
   Only one invite request should be sent. 'please invite' must not trigger.
7. Test the 4-person cap, then the 12-person setting, and test while not leader.
8. Travel zones, switch characters and verify settings persist without UI errors.
Send any error text or a screenshot; include the action that triggered it.

VALIDATION
Lua syntax and mocked core scenarios passed locally. Scenarios covered duplicate
selection, eligibility, changed bag slots, locking after preview, combat cancellation,
whisper matching, leadership, ignored/already grouped players, pending capacity,
expiry and new-arrival-only binding. Manual binding and whisper invites were subsequently tested on Xbox.
The 1.0.0 confirmation timing adjustment passed local regression checks;
that latest timing adjustment still needs an Xbox spot-check.
Controller layout reuses the previously tested MasterBaiter scene/keybind pattern.
No uploader submission or publication has been performed for this draft.

1.0.0 BINDING SAFETY UPDATE
Upgrade starts in manual mode once; invite settings are retained. Switching binding
mode cancels all queued binding and clears new arrivals. Automatic requests require
an explicit boolean ON and are checked again immediately before BindItem. The log
labels every request AutoBind or Manual bind. This does not control other addons.

1.0.0 CONFIRMATION UPDATE
Binding confirmation waits up to two seconds for the collection unlock or
permanent item binding. Each item receives one BindItem request only. A timed-out
request remains unconfirmed rather than being incorrectly reported as failed.
