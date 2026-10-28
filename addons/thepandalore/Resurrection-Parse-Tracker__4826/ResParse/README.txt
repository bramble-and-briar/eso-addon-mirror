ResParse 0.3.2 - RELEASE
Author: thepandalore

PURPOSE AND SCORING
ResParse maintains a group scoresheet of successful resurrection results
reported by participating ResParse clients. Each client increments only its
own contribution and sends its authoritative total; it does not infer other
players' casts from combat events, effects, distance, or dead/alive scans.

A native EVENT_RESURRECT_RESULT with RESURRECT_RESULT_SUCCESS adds one point
for an identified target other than the local player. Self account and
character names are excluded. There is no duration gate, channel timer, or 
cast-wide deduplication. Three successful results for three different 
Necromancer resurrection targets therefore add three points. The public event 
signature alone does not establish which ability paths emit these results, 
when acceptance occurs, or which clients receive them. Confirm those 
behaviors in game before publishing compatibility claims.

Only addon participants report scores. The target need not run ResParse.
Zero scores are omitted from the displayed and printed list. Ties are sorted
by account name after descending score. Totals saturate at 65,535 per player,
matching the existing 16-bit protocol; local and transmitted limits agree.

INSTALLATION AND DEPENDENCIES
Install with MINION or by dragging the ResParse addon directly into your addons
folder. Close the game or return to the appropriate addon management screen, 
replace the old ResParse addon folder with this archive's ResParse folder, and 
reload the UI. Removing the old addon folder prevents an obsolete Bootstrap.lua 
or ResParse.xml from remaining from an overlay install. Do not delete 
SavedVariables/ResParseSavedVariables.lua during this upgrade.

Direct hard dependencies (minimum integer AddOnVersion, not display version):
  LibAddonMenu-2.0>=43
  LibGroupBroadcast>=91

LibGroupBroadcast also requires LibDebugLogger. Install and enable the
libraries' dependencies as well; ResParse does not bundle third-party libraries.
The manifest targets ESO API 101050, the reviewed live API documentation.

COMMANDS
  /resparsers       Print the current synchronized scoresheet, even while hidden.
  /resparse sync    Request current totals from participating peers (silent).

Chat output is local to the person entering the command. /resparsers does not
automatically post the list to group chat. Normal initialization, scoring,
synchronization, resets and window changes do not print chat notifications.
Native Lua errors and dependency errors are not swallowed or disguised as a
successful initialization. Other addons and libraries control their own output.

WINDOW
Use Settings > Addons > ResParse to show/hide the scoresheet, adjust its width
or background opacity, or reset its position. Drag the window header to move
it. Hiding the window does not disable scoring, synchronization or /resparsers.
The window follows the native HUD/HUD UI scene fragments and contains no debug
information. Hidden windows do not continuously sort or rebuild their rows.

PERSISTENCE AND UPGRADE NOTICE
The SavedVariables profile is now GetWorldName(), separating NA, EU and PTS
world names rather than sharing one unscoped Default profile.

IMPORTANT: The first 0.3.2 load in each world copies only presentation settings
from the old Default profile and starts a fresh tally. Old scores cannot be
assigned to a world reliably, so they are NOT imported into every world. The
old Default data is left intact for manual recovery. Subsequent same-world,
same-group /reloadui operations preserve the new profile's tally. Upgrade the
whole participating group together and preferably between scoring sessions.

Leaving the group clears the active local session. A complete current roster
prunes departed accounts; an incomplete roster during loading is not treated
as proof of departure. Offline members are not removed merely for being
unavailable. Initial roster work waits for EVENT_PLAYER_ACTIVATED. Group changes
while the addon is unloaded cannot always be distinguished from the same group
without a shared session identifier; this build does not claim to solve that.

SYNCHRONIZATION AND BANDWIDTH
Protocol 340 remains ResParseScoresheet. The wire layout is unchanged:
  requestSync: one flag, followed by resurrectionCount: unsigned 16-bit total.

The local score increments once per accepted success result. Receivers SET the
sender's row to the supplied total; receiving the same total twice does not add
two points. LGB replaces older queued messages for this protocol with the newest
state, so rapid updates can be delivered as one final total. Intermediate
counts are not required for an authoritative state scoresheet.

An outstanding sync request is carried forward when newer local totals replace
queued messages. Valid peer state clears this request latch after a request
was queued. This is best-effort synchronization, NOT an acknowledgement or a
guarantee that every group member has replied. Disabled transmission is
respected without chat nagging or an automatic busy retry loop. Use
/resparse sync after re-enabling the protocol or when a sheet needs refreshing.

Custom event 4, ResParseCompletedResurrection, is no longer declared or emitted
by this build because its notification duplicates the scoresheet update. The
existing reservation has been released from the wiki. No code queries or edits 
the wiki. ResParse's handler exposes a copy-returning GetScoresheet function 
through LGB:GetHandlerApi("ResParse").

KNOWN PROTOCOL LIMITATION
Duplicate-safe SET is not the same as ordering-safe synchronization. The
preserved payload has no session epoch or sequence number. A delayed lower
count cannot be distinguished from an intentional owner reset. This build
accepts the owner's lower total; it does not silently use max(old,new), which
would break resets. A robust ordering/session revision needs a coordinated
wire-protocol change, not an extra field silently inserted under protocol 340.
Disconnected clients and rejected/dropped transmissions are not guaranteed to
recover until a later owner update or manual sync. This is not an anti-cheat
or independently verified resurrection history.

0.3.2 CHANGES
- Added minimum dependency versions and integer AddOnVersion 302.
- Added world-scoped SavedVariables with settings-only legacy migration.
- Replaced generic SafeCall/pcall and API-existence probes with documented calls.
- Removed the bootstrap fallback and redundant custom-event transmission.
- Coalesced roster, send and draw work; avoided unchanged/hidden UI rebuilds.
- Preserved sync requests during queued-state replacement; ignored own echoes.
- Delayed initial roster handling until activation; protected incomplete rosters.
- Kept DEV diagnostics separate from the byte-identical common RELEASE core.
- Added disclosure, credits, scope limits and reproducible audit materials.

CREDITS AND REFERENCES
Maintainer and addon author: thepandalore.
LibAddonMenu-2.0: sirinsidiator, Seerah, and contributors (settings API).
LibGroupBroadcast: sirinsidiator and contributors (group data transport).
LibDebugLogger: the library used by LibGroupBroadcast for its own diagnostics.
ESO UI source and API documentation: ZeniMax Online Studios, published through
ESOUI's source repository. ESOUI community upload guidance informed the review.
Codex: AI-assisted implementation, refactoring and offline audit support.
These credits describe dependencies and reference material; no third-party
library source is embedded in this package.

AI DISCLOSURE
This addon was developed and revised with AI assistance (Codex). This build
has received source review and offline regression tests, but those tests are
not a substitute for live ESO validation, which has been accomplished daily. 
In particular, native resurrection attribution and multi-target event delivery 
still need the in-game checks in the accompanying production audit. No claim 
of independent certification or complete in-game validation is made.


https://www.esoui.com/forums/showthread.php?t=10790
https://www.esoui.com/downloads/info7.html
https://www.esoui.com/downloads/info1337
https://github.com/esoui/esoui/tree/live
https://github.com/sirinsidiator/ESO-LibGroupBroadcast
https://github.com/sirinsidiator/ESO-LibAddonMenu
