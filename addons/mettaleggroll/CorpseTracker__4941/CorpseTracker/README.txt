Corpse Tracker 0.3.4

Light-mode testing release for ESO PC/Mac. Estimates tracked Necromancer
corpses from creation, consumption and expiry events. Recognition uses
ability and unit IDs, independently of the interface language.

Install or update

1. Install and enable LibAddonMenu-2.0 separately.
2. Extract CorpseTracker into Documents/Elder Scrolls Online/live/AddOns/.
   The manifest must be at AddOns/CorpseTracker/CorpseTracker.txt.
3. On update, replace the existing files; do not install another named copy
   or copy addon files into SavedVariables.
4. Enable Corpse Tracker and run /reloadui.
5. /crpst status must show v0.3.4. Settings also show the installed version.

Open settings via /crpst settings or the game's Addons settings page.
A new install defaults to Square, Light, Your BB + Skull, with diagnostics
and recording off. Upgrades retain existing preferences: use /crpst mode light
if you previously selected Extended.

Display

- Large number: estimated corpses from the selected tracked sources.
- ~4.2: estimated seconds until the nearest remaining expiry; hidden at zero.
- White ?: the displayed remainder may already be empty because an unknown
  consumption choice and expiry events could have removed every tracked corpse.
  Uncertain identity alone does not show it if a survivor is guaranteed by the
  tracked events and assumed lifetimes.

Drag to move; right-click changes sources. Lock Position prevents dragging.
The display hides in menus, inventory and map while counting continues.
There are no sounds or automatic chat messages.

Scope and limitations

Your BB + Skull tracks BB explosions and enhanced skull casts that create
corpses. A BB button press or jump is not a creation event. All tracked also
includes recognized skeletal summons and diagnostic rules; it does not mean
all corpses in the world. Enemy deaths, allies and Banner creations are not
added to the counter.

Siphon uses exact target IDs. Those IDs can correct several earlier Yard
assumptions. Yard requires a separate consumption witness from Nothing Wasted
or Corpseburster. A cast, a damage tick or a synergy alone never causes an
extra decrement. Without a witness, Yard does not decrement the counter.

Light does not check distance, Yard placement, obstacles or actual skill
availability. Untracked bodies can be used by Yard; without a target ID its
choice is an estimate. Default estimated lifetimes are 5 seconds for BB and
skull, and 10 seconds after a skeletal summon ends. Diagnostic changes apply
only to future entries.

Languages and diagnostics

Auto selects English, Russian, German, French, Spanish, Japanese, Chinese or
Brazilian Portuguese from the client language; other languages fall back to
English. Manual language changes require /reloadui.

Diagnostics contains Extended experimental mode, range controls, lifetime
estimates, debugging, recording and the Extended display selector. Light always
uses the square; switching to Light returns to it automatically. Ordinary
settings contain sources, language, position lock and size.

After replacing addon files, run /reloadui before starting a new test.
For a counting issue, check /crpst status, then use Start a new diagnostic
test under Diagnostics or /crpst test. This clears previous diagnostics and
starts a recording in the current display, preserving active corpses.
Debugging is optional. Stop recording and run /reloadui, then provide
SavedVariables/CorpseTracker.lua. Video and Encounter.log can help resolve
physical availability and placement.

The manifest's ## SavedVariables: CorpseTrackerSaved declares the table
inside the saved file. The file itself is named CorpseTracker.lua, located in
Documents/Elder Scrolls Online/live/SavedVariables/, and starts with
CorpseTrackerSaved =.

/crpst capture on|off resumes/stops recording; /crpst clearlog clears only
the log; /crpst reset clears the corpse ledger. Logs retain the last 2500
records and are separate per megaserver. A stopped recording is preserved.

Accounting and timer checks run every 200 ms. Text and colour are written only
when changed; the timer is formatted only when its displayed tenth changes.
The hidden HUD skips periodic text, colour and layout writes, then immediately
renders current data when shown. Consumption and expiry continue in menus at
the same cadence. Light without debug recording reads no world positions or
skill ranges and builds no alternative ledger worlds. Timer ticks are not
logged. In-game FPS/CPU costs have not been measured.
