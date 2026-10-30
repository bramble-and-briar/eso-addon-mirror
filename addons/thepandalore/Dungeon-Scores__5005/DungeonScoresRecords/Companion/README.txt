Dungeon Scores Companion 0.5.15
================================

This optional portable .NET 8 companion is bundled with DungeonScoresRecords
for Windows, macOS, and Linux PC players. Dungeon Scores can score dungeons
locally without it. ESO addons cannot access the internet or launch desktop
programs directly; the companion handles explicitly requested publication and
public-record downloads outside the game.

INSTALL ONCE

Keep this Companion folder inside:
    live\AddOns\DungeonScoresRecords\Companion

Run exactly one installer for your computer:

    Windows: Install-DungeonScores-Windows.cmd
    macOS:   Install-DungeonScores-macOS.command
    Linux:   Install-DungeonScores-Linux.sh

The installer checks for the Microsoft.NETCore.App 8.x runtime. If missing, it
opens or displays the official Microsoft download page:
https://dotnet.microsoft.com/download/dotnet/8.0/runtime

The installer starts the companion immediately and arranges for it to start at
future logins for the current user. It copies the watcher and a path-only
configuration into a versioned DungeonScoresUploader/runtime folder under the
user's local application-data directory. The watcher and browser controls run
from there rather than holding open the copy in AddOns. The AddOns launcher
only starts the installed controls and then exits, so Minion can replace the
addon while the controls are open.

The installer then opens local Companion controls in your default browser.
The browser window controls the background watcher; closing the controls does
not stop monitoring.

OPEN CONTROLS LATER

Run Open-Controls-Windows.cmd, Open-Controls-macOS.command, or
Open-Controls-Linux.sh in this folder. The controls show Running/Stopped,
the last ESO save, and the latest sync result. Start and Stop affect monitoring
now. "Start at login" independently determines whether monitoring begins at
your next computer sign-in. Stop leaves that login preference unchanged.
"Sync saved data now" processes only runs ESO has already saved and refreshes
public records; use /reloadui in ESO if you need an immediate save. The
controls use a temporary 127.0.0.1 address while open and are not a website
hosted by Dungeon Scores. Closing the controls leaves a running watcher alone.

UPGRADING FROM COMPANION 0.5.2 THROUGH 0.5.14

Before replacing an existing 0.5.2 DungeonScoresRecords folder, run the
matching Companion\Advanced\Disable-Startup-* launcher and wait a few seconds.
If upgrading from 0.5.3 through 0.5.14, close any open companion control
window once before replacing DungeonScoresRecords. The watcher itself already
runs outside AddOns. Install the new two-folder package, then run the normal
installer once. Version 0.5.15 and later run both the watcher and browser
controls from the application-data copy, so future Minion updates can proceed
with the controls open.

NORMAL USE AND PUBLICATION

1. Finalize a run in Dungeon Scores and assign a matching registered team.
2. Optionally select a guild for permanent guild records, an event, or the
   separate Race to the Bottom option. Guild/event routes have their own
   eligibility rules; Race to the Bottom requires explicit selection.
3. Press "Send selected score" to queue the chosen run.
4. Allow ESO to save addon data on logout, exit, or /reloadui. The installed
   companion then processes the saved queue request. /reloadui is an
   immediate-save option, not a requirement for ordinary use.

The companion writes local delivery receipts to Delivery.lua. The run browser
shows the status available at its last UI load: queued, server-accepted,
rejected for a reserved team name, or retrying after a delivery error. Reload
the UI to see a newer receipt. Server acceptance does not promise a standing
or Discord post. The browser also shows the age of its captured-record snapshot.

Completed runs can be queued for multiple legitimate publication destinations.
Abandoned runs can be submitted only to Race to the Bottom, provided the
minimum credible boss-progress requirement is met. A queued submission may
fail validation or fail to improve a standing; pressing Send does not promise
that a record or Discord announcement will be awarded.

The companion reads DungeonScores.lua locally but extracts only explicit
publicationQueue payloads for upload. It does not upload unselected history,
personal bests, character names, chat, combat logs, or BETA diagnostics and
never edits DungeonScores.lua. See PRIVACY.txt for the precise fields, public
roster/consent implications, and local storage details.

The ZIP starts with an empty public snapshot so it never ships a stale beta
leaderboard or another team's account roster. Each sync refreshes the sanitized
PC NA/EU public-record snapshot for the
in-game browser: World Records, party-size standings, ordinal top-ten high
standings, Race to the Bottom, configured guild records/events, and guild
recruitment/directory data. Guild and event selection is optional; guild
record publication depth is configurable and events follow their own rules.
When qualifying standings change, configured Discord channels may receive
updated ordinal placements. Server-side ranking and announcement rules, not
the desktop companion, decide what is published. Discord bot tokens and
private channel configuration stay on the server.

BACKGROUND OPERATION

The watcher observes ESO start/exit and SavedVariables writes and refreshes
public records approximately every five minutes while ESO is running. A
SavedVariables write can also trigger a sync while ESO is closed; with ESO
closed and no new save-file write, there is no periodic network activity.
Refreshing public records does not submit unselected scores. Public data downloaded into
DungeonScoresRecords/Records.lua can contain other teams' public ESO account
names and configured guild recruitment/contact details.

Windows, macOS, and Linux cannot execute a program solely from extracting a
ZIP. The companion must be installed explicitly once for publishing to work.
The unsigned community launchers can prompt Windows SmartScreen, macOS
Gatekeeper, or Linux execution-permission warnings.

ADVANCED CONTROLS

Advanced contains manual sync, startup repair, and startup removal launchers
for each operating system. Disable-Startup removes the per-user login entry
and stops the watcher. Removing it does not delete existing public records.

CUSTOM LAYOUTS

If the companion is moved, copy DungeonScoresCompanion.example.json to
DungeonScoresCompanion.json and edit the paths. Leave BearerToken empty.
The publisher generates its private credential on the first queued upload attempt
and stores it under local application data. Do not share that credential.

SOURCE AND PRIVACY

The bundled C# source and project file are in Source. PRIVACY.txt is the
self-contained publication and privacy notice for this release; reproduce it
or link to an up-to-date notice on the ESOUI listing. Publication identifies
the team and all listed members by ESO @accountname, so obtain their consent
before queueing a score. For correction/deletion requests use the Dungeon
Scores ESOUI support thread or community support channel.

The packaged DungeonScoresCompanion.dll is unsigned. Its source is included
in Source; check the SHA-256 of the exact binary you download if verifying a
release. This release's DLL SHA-256 is:
87700522CCED09C0965299E436115E8A28B4A7FFB8D99E791811D3D61B903360
The VirusTotal report for this exact file is:
https://www.virustotal.com/gui/file/87700522cced09c0965299e436115e8a28b4a7ffb8d99e791811d3d61b903360/detection
The report showed 0/71 security vendors flagging it on October 29, 2026.
A scan is evidence for review, not a guarantee of safety.
