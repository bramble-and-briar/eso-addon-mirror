PACT WATCH 0.1.4 - LARGER ACTION BOARD / HAMMER / EMPEROR
by @TheGreyWolf98

Upload the PactWatch folder using your usual ESO console add-on uploader workflow.
The folder must contain PactWatch.addon as its single .addon manifest.
Remove the old extracted folder before extracting this corrected package.
No external libraries required. ZIP contains one add-on folder.
This is a test build, not a claim of verified Xbox early-warning behaviour.

START TONIGHT
1. Enable on an Ebonheart Pact character. Use /pw to open the briefing.
2. Before entering Cyrodiil: population levels are requested from ESO. Corner columns
   are always Pact (red), AD (yellow), DC (blue). Home-campaign holdings appear only if client data
   is available. If needed open Alliance War once and use /pw refresh.
3. Enter Cyrodiil. /pw hud enables a compact top-right activity board.
   Chat and sound warnings default ON. The main window starts closed.
4. Keep the map closed initially. Enemy siege at Pact-owned holdings is
   checked every 3 seconds. Arrival observations appear in the board/log
   without a burst of alarms; subsequent new siege/flags trigger warnings.
5. /pw diag shows API availability, keep records, received death reports,
   and unflagged siege observations. Screenshot this if anything is missing.
6. /pw log shows the latest 12 diagnostic lines; /pw log 30 shows more.
   Screenshot SIEGE and FLAG lines to compare times and map state.

COMMANDS
/pw or /pactwatch       Open/close the full briefing
/pw close              Explicitly close the full briefing (also /pw hide)
/pw open               Explicitly open the full briefing (also /pw show)
/pw hud                Toggle compact live HUD (only inside Cyrodiil)
/pw refresh            Request briefing and scan now (requests throttled 30s)
/pw next / /pw prev    Page through the activity board
/pw alerts on/off      Local chat warnings; sound has its own switch
/pw sound on/off       Warning sound
/pw resources on/off   Resource monitoring (keeps/outposts remain monitored)
/pw auto on/off        Auto-open main panel on arrival (default off)
/pw on / /pw off       Enable/disable live monitoring
/pw diag               Compact diagnostics in your own chat
/pw log [number]       Show up to 30 latest diagnostic lines
/pw debug on/off       Echo diagnostics as they arrive (default off)
/pw test               Clearly labelled synthetic chat/sound check; no fake board data
/pw reset              Re-centre the main window
/pw help               Command reminder
Optional Open Pact Watch / Toggle Pact Watch HUD bindings are registered.
Slash commands remain available if controller binding assignment is unavailable.
The full briefing now uses an ESO UI scene: B/back closes, A next page,
X refresh, Y previous page. Normal gameplay inputs return when closed.
Campaign and activity text now use separate labels for each display line.

WHAT THE BOARD MEANS
- Siege counts are deployed weapons by alliance, NOT numbers of players.
- FLAGGED reflects ESO's official under-attack state.
- Death counts are deduplicated received kill-feed reports in our last 2 minutes,
  NOT a guarantee of every death in the campaign. Very rapid repeat kills
  between the same players may be suppressed by the 10-second dedupe window.
- A siege/flag row is observed again while that signal stays present. Its age
  is last observation of the signal, NOT the timestamp of a weapon firing.
- A fight row's age is the last received death report. No deaths does not prove
  there is no fight. Old rows expire 10 minutes after the last observation.
- Guild guard-kill warnings only cover reports ESO delivers to this character
  for their guild's claimed holdings, not every Pact guard in Cyrodiil.
- Pact holdings / Pact-involved deaths get priority, but the action board also
  shows enemy-on-enemy activity. Only Pact characters run the monitor.
- Monitoring resets across loading screens/campaign changes to prevent stale
  campaign data. It does not reconstruct battle history before monitoring.
- Population levels are LOW/MEDIUM/HIGH/FULL. Exact faction headcounts and
  campaign-wide first wall/door damage are not exposed by this build.
- Warnings stay in YOUR chat. Nothing is broadcast to zone/guild/group.
- The add-on never opens, changes, or adds pins to the world map.

CONTROLLED TEST
At a quiet Pact keep, have an AD/DC friend approach, deploy one siege without
firing, fire, then continue until flagged. Keep your map closed and initially
stay elsewhere in Cyrodiil. Compare logs. Have them pack up and wait for counts
to clear. This establishes whether the client reports siege before flagging.

LIMITATIONS TO VERIFY ON XBOX
API availability; keep enumeration; enemy siege counts before flagging and
with map closed; coverage/timing of kill feed; pre-entry home holdings.
Unknown data shows as unknown/unavailable rather than invented totals.
Polling introduces up to 3 seconds plus ESO's own update/network delay.

Validation: Lua syntax/runtime smoke test and simulated campaigns/alerts.
No live ESO or Xbox execution has been performed by the authoring environment.

V0.1.4 CHANGES
Larger action text; compact three-line population corner (EP / AD / DC).
Keep names match owner alliance. FLAGGED is red. Siege counts match alliance.
A flag with no siege cannot identify attackers and says attacker unknown.
Hammer: spawn announcement can precede location reveal. Revealed objective
pins give nearest keep while the current map is Cyrodiil; no map is changed.
A nearest keep is a reference point, not proof the hammer is at that keep.
Enemy emperor: latest received kill-feed involvement gives a named location
and age; it is a sighting, not continuous tracking. Changes of emperor clear
old sightings. Pact emperor simply shows that Pact holds the throne.
Xbox availability/timing of the new special feeds still needs live testing.

V0.1.4 HAMMER FIX
Missing map pins retain the last hammer report for up to 10 minutes, with
state/location ages shown. A sighting is not a confirmed current position.
Pickup/drop events update the reported state and alliance. Alerts say spotted
or carried, rather than implying a new spawn or that it remains unclaimed.
A new hidden spawn clears the previous hammer cycle. Loading clears reports.

V0.1.4 QUIETER WARNINGS / INACTIVE HAMMER FILTER
Warnings and /pw test use a brief DEFAULT_CLICK instead of duel fanfare.
Sound is throttled to once per five seconds; /pw sound off still mutes it.
Only revealed held/dropped/at-base objective states can create hammer sightings.
Unknown/inactive objective positions never create a location alert. Missing
pins retain a dated Last sighting instead of implying a current position.
This add-on does not create or suppress ESO's native hammer map pin.
