# Dungeon Scores companion

The optional companion is a portable .NET 8 assembly distributed under
`DungeonScoresRecords/Companion` for Windows, Linux, and Intel/Apple Silicon
macOS. It requires the separately installed .NET 8 runtime. In the standard
location it discovers the matching ESO `live/SavedVariables` and
`live/AddOns` directories without configuration.

The OS-specific `Install-DungeonScores-*` launcher starts the watcher and
registers per-user login startup. The installer copies the watcher and a
path-only configuration into `DungeonScoresUploader/runtime/0.5.15` beneath
the user's local application-data directory; startup uses this copy, not the
AddOns assembly. The installer opens a local browser control window afterward.
`Open-Controls-*` first refreshes that installed copy, then runs the browser
controls from it. The launcher exits before the controls become persistent,
so the AddOns assembly is not held open during Minion updates. Its Start/Stop
buttons control monitoring now,
its login switch controls future sign-ins, and Sync uses the saved ESO queue.
The browser controls bind only to 127.0.0.1 on a temporary port with a random
path token. Troubleshooting, manual sync, startup repair, and startup
removal launchers are supplied in `Companion/Advanced`.

## SavedVariables and publication boundary

The companion parses the local `DungeonScores.lua` SavedVariables file, but
only `publicationQueue` payloads created by the player's **Send selected
score** action are uploaded. It does not upload other run history, unselected
personal bests, character names, chat, Encounter.log, BETA diagnostics, or
unrelated settings, and it never edits `DungeonScores.lua`.

The addon's queue payload contains a named team and exact ESO `@accountname`
roster, submitter account, source megaserver, dungeon and run identifiers,
addon/schema version, outcome and timestamps, competitive/eligibility
flags, party-size measurements, elapsed time, deaths, HM/trifecta results,
score components, coefficient, and final signed standard score. An explicitly
selected Race to the Bottom request additionally includes its low-score result
and applicable abandonment, abandoned-HM, companion, and pitstop deductions.
Completed submissions
may also carry a selected public guild/event ID and route-specific membership
check booleans; the user's entire ESO guild list is not sent. The payload
always includes an explicit `raceToBottomRequested` boolean; the Worker must
not infer an opt-in from score eligibility alone.

World Record scoring and optional guild/event destinations are independent.
For a completed run, a separate Race to the Bottom request can be selected;
for an abandoned run it is the only permitted publication destination, and
requires minimum credible boss progress. A successfully uploaded submission
does not necessarily change a standing or produce a Discord announcement.

The Worker, rather than the companion, decides eligibility and rankings. The
records contract contains overall and per-party-size World Records and ordinal
high standings, plus zone-agnostic Race to the Bottom records ranked by lowest
score within party-size divisions. Race to the Bottom records can disclose
whether a run was `completed` or `abandoned` and the relevant penalties.
World Record and Race to the Bottom standings have a depth of ten; guild
record publication depth is configured per guild from one to ten. Guild
events use their configured eligibility and placement rules. Rank updates
may be reflected in server-managed Discord announcements. The companion
never receives or stores the Discord bot credential or private channel IDs.

Explicitly submitted team names and ESO account rosters may appear in public
rankings and Discord messages. Obtain consent from every named teammate before
queueing publication. Community-submitted results are not cryptographic
proof of an in-game clear. The complete field and privacy disclosure is in
the bundled [`../PRIVACY.txt`](../PRIVACY.txt); mirror or link it on ESOUI.

## Record downloads and ESO-start monitoring

ESO saves addon data on logout, quit, or `/reloadui`. The watcher syncs when
ESO starts, after relevant SavedVariables writes, after ESO exits, and about
every five minutes while ESO is running. A SavedVariables write can also
trigger a sync with ESO closed; absent a new write, there is no periodic
network activity when ESO is closed. Public-record refreshes do not upload
unselected scores. A local `submitted.json` ledger remembers handled queue
keys so the same request is not resubmitted endlessly.

Each sync downloads `GET /v1/records` for the public PC NA/EU records,
party-size and top-ten standings, Race to the Bottom, guild records/events,
and opt-in guild directory/recruitment settings. The validated snapshot is
written to `AddOns/DungeonScoresRecords/Records.lua` for ESO's next UI load.
This generated file can include public ESO account rosters belonging to
other teams and guild recruitment/contact details. Use `/reloadui` to load
newly downloaded records or guild/event choices into the current ESO session.

The one-time installer sets a per-user Windows Run entry, macOS LaunchAgent,
or Linux XDG autostart entry. Advanced/Disable-Startup removes that startup
entry and stops the watcher. Disabling it or deleting local files does not
remove previously published records or Discord announcements.

The private installation credential (`credential.json`) is generated at the
first attempted explicit queued upload unless a credential is supplied in configuration.
It is stored in local application data rather than SavedVariables or the
public data addon. The companion also keeps a submitted-key ledger and watcher
status locally. Leave `BearerToken` empty in custom config and do not share
the credential. The production service endpoint uses HTTPS.

## Custom paths and development

For a custom layout, copy `DungeonScoresCompanion.example.json` to
`DungeonScoresCompanion.json` and edit the paths. The legacy name
`DungeonScoresUploader.json` remains accepted.

For correction or deletion of public records, contact the Dungeon Scores ESOUI
support thread or community support channel. The bundled client does not
establish a server retention deadline or automated deletion guarantee.

Development-only checks (not necessary for users):

```text
dotnet run -- --self-test
dotnet run -- --config DungeonScoresCompanion.json --dry-run
```
