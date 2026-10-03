# LibInteriorDetection — Changelog

Full version history for LibInteriorDetection (renamed from LibIndoorDetection as of 0.6.0 — see below). Historical entries below the rename retain the LibIndoorDetection name, since that was accurate at the time each version shipped, matching the precedent set by Spoilage's own rebrand from ProvisioningSpoilageTracker. See README.md for current features, installation, and usage.

---

## What's New in 1.3.6

- **Fixed: quitting the game could restore the wrong indoor/outdoor
  state at the next login.** The saved state is now kept current while
  playing, instead of being written only by `OnPlayerDeactivated`:
  - `SetIsInterior` writes `lastIsInterior` on every change (door,
    teleport check, restore, zone default, `/lid debug flip`).
  - Every handled zone activation writes the zone, position and
    temporary flag (`SaveLiveRecord`), after the restore decision has
    already read the previous record. An activation that's ignored
    (LibZone returned no zoneId) writes nothing.
  - `OnPlayerDeactivated` is unchanged and still does a full update for
    the exits where it runs.
- **Why - found from in-game traces:**
  - An idle kick to the login screen saved correctly: the record age
    matched the kick to the second.
  - Quitting the client did not, twice. The next login restored the
    record from the previous load screen (the Daggerfall Outlaws Refuge
    exit, the night before) or the previous idle kick. Each time the
    trace counter reset, which only happens on a client restart, and
    there was no deactivation record for the quit.
  - An account-wide setting changed during a session survived a quit, so
    the game does write SavedVariables then. It just doesn't include our
    logout update.
  - Whether `EVENT_PLAYER_DEACTIVATED` doesn't fire on quit or fires
    after the write is **unknown**. The fix doesn't depend on it.
- **No `Quit()` hook** (the pattern removed in 0.6.6) and **no polling.**
  A periodic position save was evaluated first, at the author's request,
  for its cost on low-end systems: one native position read and four
  field writes every few seconds, with no disk I/O. That would be
  negligible next to the existing 0.25s door and teleport watches, as
  long as it reuses one table and does no string work per tick. It isn't
  needed yet, because the login restore uses only the zone and state.
  It's an estimate from what the calls do, not a benchmark.
- **Trade-off:** after a quit, the saved position is where the zone was
  loaded, not where the player quit. So the login trace's distance and
  age aren't meaningful for quit exits, and the log-only login position
  check would need the periodic save before it could be enabled for
  them.
- **Diagnostics:** new `lastLiveUpdateTime` / `lastLiveUpdateSource`
  fields, shown in the login trace and `/lid debug saved` as "Last live
  update". After a quit, expect a recent live update alongside an older
  deactivation record.
- Offline-tested with stubbed ESO functions:
  - A flip followed by a simulated quit restores Interior.
  - The night-before sequence (refuge, refuge exit, building, quit)
    restores Interior.
  - An ignored activation leaves the record alone.
  - The reload and same-zone-teleport paths still behave correctly.
  - The `/lid debug flip` message is unchanged.
  - The 1.3.4/1.3.5 suites still pass, with the gate both off and on.
- **In-game results** (same evening, in Pathierry House, Daggerfall):
  - **Confirmed: state survives a quit.** `/lid debug flip` to Interior,
    quit, relaunch: the login restored Interior. The trace's "last live
    update" pointed to the flip to the second, while "Last deactivation"
    was still an idle kick from an hour earlier - the logout handler
    again didn't run on quit, and the live save covered for it.
  - **Confirmed: the zone-load live save survives a quit.** A quit with
    no state change in between restored the record written at the
    previous login's activation.
  - **Confirmed: a door crossing triggers the live save** (`/lid debug
    saved` showed "Last live update ... (Door)"), and both directions of
    Pathierry House's door are detected (~2.8k-unit jumps).
  - **Not yet confirmed end to end: a door crossing followed by a quit.**
    The save is the same `SetIsInterior` path as the flip, so this is
    low risk, but no login after a door-then-quit has been traced yet.
  - **Confirmed: an idle kick to the login screen saves normally**
    (record age matched the kick to the second) - this resolves the
    open question listed in 1.3.4.
  - **Login drift inside a building: 0-1 units** across three logins.
    This is the first indoor drift data for the log-only login gate,
    which still can't be used for quit exits without a periodic
    position save.
  - The 1.3.4 logout diagnostics and the 1.3.5 log-only login check were
    exercised in the same sessions and behaved as documented.
- **Observed limitation, not new:** a wrong state at login (here, the
  record left by the pre-1.3.6 quit) carries through door crossings
  inverted - leaving the building flipped it to Interior and re-entering
  flipped it back to Exterior - since the door toggle can only invert.
  `/lid debug flip` corrects it. Door interaction text appears to name
  the destination ("Daggerfall" leading out, "Pathierry House" leading
  in), which might let a future version correct the state rather than
  only invert it; **untested**, and doors that don't name a destination
  (basements, district gates) would need a fallback.

---

## What's New in 1.3.5

- **The 1.3.4 login position check is now log-only** (new
  `LOGIN_POSITION_GATE_ENABLED = false`). A login restores exactly as
  1.3.3 did - raw zone match only - and the trace reports the distance
  and whether the check *would* have rejected the record.
  `/lid debug saved` shows whether the check is on or log-only.
- **Why:** on review, enforcing it was premature.
  - It can only make restores rarer. It can't fix a restore that never
    happened, and the reported failure (logging in inside, getting the
    exterior zone default) is exactly that.
  - It targets an exit that never wrote SavedVariables, which the
    author's report of a proper logout makes less likely.
  - Its 50m tolerance is applied to the case that already works, and
    login drift has never been measured for a login *inside* an interior
    pocket. Those are spatially far from their doors (why a door reads as
    a >20m jump), so drift there may differ from the earlier tests. If it
    exceeded 50m, a clean logout inside would have newly fallen back to
    exterior.
  - In 1.3.4 the check was also shipped in the same release as the
    diagnostics meant to decide whether it was needed.
- **When to turn it on:** once traces give real drift numbers (including
  logins inside interior pockets) and at least one `lastDeactivate`
  record confirms a stale save. Then it's this one constant.
- The 1.3.4 logout diagnostics (`lastDeactivate`, record timestamps,
  login trace, `/lid debug saved` additions) are unchanged.
- Offline-tested with stubbed ESO functions: with the gate off, a record
  200m away now restores (the trace marks it "REJECTED it as stale"),
  one at 30m restores; the same 1.3.4 scenarios with the gate switched
  on still behave as before; reload, teleport, nil-read and debug-saved
  checks unchanged. **Not yet tested in-game.**

---

## What's New in 1.3.4

Response to a report that logging out inside an interior pocket of an
exterior zone sometimes logs back in with the wrong state the next day,
even without the character moving and after what the author believes
was a proper logout.

- **A login now only restores the saved state if the player is within
  50m (any axis) of the saved logout position** (new
  `LOGIN_POSITION_TOLERANCE`). Why: the saved record only reaches disk
  when ESO writes SavedVariables (logout, menu Quit, `/reloadui`). A
  session that ends without that write leaves the record from an earlier
  clean exit, and the login branch restored it with no age or position
  check as long as the raw zone matched - which an interior pocket of an
  exterior zone always does. This partly reverses 0.6.7's "no position
  on login": that dropped *exact* matching, which drift makes
  impossible; this check is loose and only rejects records from
  elsewhere in the zone. **Unverified:** that 50m always exceeds real
  login drift (the "tens of meters" measured earlier); if it doesn't,
  the result is the zone default, and the trace logs the distance. A
  stale record from the same building still passes.
- **Logout diagnostics** (no effect on behavior): `OnPlayerDeactivated`
  now writes a `lastDeactivate` record before anything that can bail
  out - a timestamp, the raw zoneId it read (nil if the read failed),
  the raw zoneId captured at the last load screen
  (`lib.state.rawZoneId`, read while the world was stable), the live
  state, and whether the save completed. Why: four causes of a failed
  restore after a proper logout couldn't be told apart - the save
  silently not happening (the nil-position early return had no trace
  line; seen once in 0.6.5, never resolved, and 0.6.5's
  `lastDeactivateRan` diagnostics are no longer in the code), a wrong
  teardown-time zoneId (cf. the 0.6.4 x/y/z-vs-zoneId split), a
  correct restore overwritten moments after login, or the state already
  wrong at logout. The early return and a teardown-vs-activation zoneId
  mismatch are now traced too, though chat at logout can't be read
  afterwards - the persisted record is what matters.
- `lastPosition` now carries a timestamp, so a record's age is visible.
  Records from earlier versions show as "unknown (pre-1.3.4 record)"
  and are still subject to the position check.
- **Login trace** now reports the saved record (zone, state, age) and the
  last deactivation record, plus the distance and whether it was
  restored or treated as stale.
- **`/lid debug saved`** now also prints the last deactivation record
  (even when no position was ever saved), the distance from the saved
  position against the login tolerance, and the record's age.
- `GetTimeStamp()` confirmed in the ESOUI client source
  (`timedactivities_manager.lua`, seconds). Still **unverified**: whether
  an inactivity logout or force-closing the client writes SavedVariables.
- Offline-tested with stubbed ESO functions (19 checks): restore at 30m
  login drift; a stale record 200m away falling back to the zone
  default; a nil position read leaving the old record in place with
  `saved=false`; pre-1.3.4 records; the reload and same-zone-teleport
  paths unchanged; the zone-mismatch trace; and `/lid debug saved` with
  and without a saved position. **Not yet tested in-game.**

---

## What's New in 1.3.3

- **Built-in exceptions to the Weather Control house rule** (new
  `HOUSE_EXCEPTIONS` table), from the author's review of
  `/lid debug houses` on 1.3.2. These homes' actual layouts don't match
  their Weather Control support:
  - **Exterior:** Agony's Ascent (1343, entry area exterior), Doomchar
    Plateau (1306, whole zone exterior), Hunding's Palatial Hall (879,
    large exterior entry area), The Fair Winds (1435, entry area and
    most of the zone exterior).
  - **Interior:** Emissary's Enclave (1434, only a moderate courtyard),
    Gardner House (881, only a small courtyard), Snugpod (860, entirely
    interior despite supporting weather), Water's Edge (1276, entry area
    and most of the zone interior).
  All eight end up with the same value their old `ZONE_INTERIOR` entry
  had.
- **Precedence is now:** player zone override > `HOUSE_EXCEPTIONS` >
  Weather Control flag > `ZONE_INTERIOR` table.
- `/lid debug houses` now applies the exceptions before comparing,
  reports how many were applied, and tags any changed house that comes
  from an exception. With these eight in place it should report **0
  differences** from the old table, unless the scan finds houses the
  1.3.2 review didn't list.
- Offline-tested with stubbed ESO functions reproducing the reported
  flags: all eight exceptions, an unaffected weather house, a player
  override beating an exception, and `/lid debug houses` (0 differences).
  The 1.3.0 and 1.3.1 suites still pass. **Not yet tested in-game.**

---

## What's New in 1.3.2

- **Player houses are now classified by Weather Control support** (the
  author's rule): houses that support it are **exterior**, all others
  **interior**. Read from the game at runtime rather than listed by hand:
  `GetHouseFlags(houseId)` with `HOUSE_FLAGS_SUPPORTS_WEATHER_CONTROL`
  (the same flag the housing book's "Supports Weather Control" line
  uses) and `GetHouseZoneId(houseId)` (returns 0 for an invalid house),
  all confirmed in the ESOUI client source (12.0.8). A zoneId -> weather
  map is built once by scanning houseIds 1-500; invalid IDs are skipped.
  **Unverified:** that 500 covers every house ID (house IDs aren't
  documented - a house beyond it would fall back to the table).
- **Precedence:** a per-zone override in the settings > the house
  Weather Control flag > the `ZONE_INTERIOR` table. The table's house
  rows - including earlier hand-verified corrections and the 12 houses
  queued for review - are superseded for any house the game reports,
  and remain only as a fallback if the API is ever unavailable.
- **New `/lid debug houses`:** prints how many houses the scan found, how
  many support Weather Control, and every house whose classification
  differs from its old table entry - an easy in-game check of what
  changed.
- **Doomvault Capraxus, Doomvault Vulpinaz and Doomvault Porcixid
  (1241 / 1248 / 1256) are now interior**, per the author, despite
  having exterior sub-sections. Previously exterior.
- Offline-tested with stubbed ESO functions: a weather house (exterior),
  a non-weather house (interior), a house with no table row, a player
  override beating the flag, all three Doomvaults, `/lid debug houses`,
  and the 1.3.0/1.3.1 suites. **Not yet tested in-game.**

---

## What's New in 1.3.1

- **Fixed: wrong state after logging out in another player's house, a
  group dungeon or a trial.** ESO returns the player to where they stood
  before entering, not to the house or instance. Saved variables from a
  reported case showed the logout saved in raw zone 868 (Humblemud, a
  player house) - so on the next login the zone didn't match, nothing
  was restored, and the flag fell back to the zone default even though
  the player reappeared inside a building.
- **New "return point":** leaving any NON-temporary zone also saves the
  position and state. Temporary zones never overwrite it, so it survives
  any number of house hops. When arriving FROM a temporary zone - at
  login (via the saved logout record) or in-session (e.g. removed from a
  group instance) - into the return point's zone within
  `RETURN_POINT_TOLERANCE` (5000 raw units, ~50m, any axis), that state
  is restored instead of the zone default.
- **Temporary zone** = `GetCurrentZoneHouseId() ~= 0` or
  `IsActiveWorldGroupOwnable()` or `IsActiveWorldBattleground()`, all
  present in the ESOUI client source (12.0.8). The client's own
  leave-group dialog uses `IsActiveWorldGroupOwnable()` to warn that
  leaving removes you from the instance - that it covers exactly
  dungeons and trials is inferred from that usage. Classified on arrival
  and logged in the trace. Each call is guarded, so if one is ever
  renamed it degrades to the pre-1.3.1 behavior instead of erroring.
- **Confirmed by the author in-game:** the return behavior for houses
  (including several hops), group dungeons and trials. **Unverified:**
  battlegrounds (included by analogy) and the 50m tolerance (login
  positions have drifted tens of meters before; the trace logs the
  actual distance).
- Own houses count as temporary too - harmless, since logging out there
  logs you back in there, which the normal restore already handles.
- New saved fields: `lastZoneTemporary`, `returnPoint`.
  `/lid debug saved` now also prints the return point.
- The leftover `lastDeactivateRan` / `lastDeactivateRawZoneId` keys seen
  in saved variables are from an old diagnostic version and are not
  read by any current code.
- Offline-tested with stubbed ESO functions: two house hops then logout
  with ~30m login drift, logout in a dungeon, removal from a trial
  in-session, leaving a house to a spot 200m away (correctly NOT
  restored), plus normal logout/login inside and outdoors (return point
  correctly not used). The 1.3.0 door-watch suite still passes. **Not
  yet tested in-game.**

---

## What's New in 1.3.0

**Door detection rewritten: a "door watch" that looks for the sudden jump
a door makes, instead of comparing two positions at a fixed delay.**

- **Why:** the fixed-delay check (1.2.6 and earlier) missed slow doors -
  traced in-game at Daggerfall Cathedral, where the player had moved
  only 16 units when the 3s check fired - and let sprinting or riding
  after any interaction add up to the 20m threshold. 1.2.6's 5s default
  was a stopgap.
- **How it works now:** each interaction starts (or extends) a watch
  that samples position every 250ms until the watch window has passed
  since the LAST interaction, and toggles on each single jump over the
  threshold between two consecutive samples. A slow door is counted
  whenever it lands; running never produces a jump. The trace reports
  how long each door took to land (`landed Nms after the last
  interaction`), so real door timings can now be measured.
- **Counting rules:** every interaction or lockpick success adds one
  credit, each counted jump spends one, and a jump with no credit left
  is ignored and logged. A jump within 1.5s of a counted one is also
  ignored and logged, in case a landing ever settles in two steps
  (**unverified** - the 1.5s cooldown is a guess). Several crossings in
  one window each count once: cook fire then out, in and straight back
  out, double presses.
- **Replaces 1.2.1's start-position/extension/cap rules and 1.2.4's
  separate lockpick poll.** A lockpick success now simply adds a credit
  to the same watch.
- **Coordination with teleports:** a hooked travel call
  (`FastTravelToNode` etc.) ends any door watch - e.g. the one started by
  pressing E on the wayshrine - so only the teleport reset acts; an
  interaction ends a running world-map-close poll, so a door taken after
  closing the map counts as a door; if the door watch sees a jump while
  a teleport poll is running, it stands down; a teleport reset ends the
  door watch. So one move is never counted by both.
- **Only the interact key counts.** Per the ESOUI client's
  `bindings.xml`, the interact key calls `StartInteraction` with
  `ZO_INTERACTIVE_WHEEL_TYPE_FISHING`; the quickslot and target-marker
  wheel keys call it with other types and used to start door checks
  too. They're now ignored (logged in the trace). If that constant ever
  disappears, every call counts again (the old behavior).
- **Settings:** "Door Check Delay" (3-13s) is replaced by "Door Watch
  Window" (5-20s, default 10; new saved key `doorWatchSeconds`). The
  window doesn't delay detection - it only needs to outlast the slowest
  door. 10s is a judgment call, not measured. The old
  `doorCheckDelaySeconds` / `doorDelayMigrated126` saved values are no
  longer read, and 1.2.6's one-time migration is removed. The distance
  threshold slider is unchanged and now means "per 0.25s sample".
- **Unchanged:** zone-change handling, logout/reload persistence, the
  teleport poll's behavior (it now shares the 250ms interval constant
  and can be stopped by token), and the same-zone-activation rule
  (1.2.0), which now keys off "watch still running" instead of "check
  pending" - removing the gap where a fixed-delay check had already run
  without toggling.
- Offline-tested with stubbed ESO functions, 16 scenarios: slow
  (4.5s) and fast doors, cook fire then double-press exit, in and
  straight out, sprinting after an interaction, a two-step landing with
  one press and with two presses (cooldown), a second jump with no
  credit, a 13s lockpick with the automatic move, a chest pick plus
  sprint, the quickslot key, a wayshrine E press plus
  `FastTravelToNode`, a door after closing the map, sprinting after
  closing the map, same-zone activations in both directions, and a real
  zone change mid-watch. **Not yet tested in-game.**

---

## What's New in 1.2.6

- **Stopgap for slow doors: door-check delay default raised 3s -> 5s.**
  Traced in-game: entering Daggerfall Cathedral, the 3s check measured
  only 16 units of movement - the door's transition hadn't moved the
  player yet, so the entry was missed and leaving later flipped the flag
  from Exterior to Interior. (The safebox lockpick in the same trace was
  handled correctly.)
- **One-time migration for existing installs.** `ZO_SavedVars` copies
  defaults into the saved table (confirmed in the ESOUI source,
  `zo_savedvars.lua`), so everyone already has `3` stored and would
  never see the new default. On first load of 1.2.6, a stored `3` is
  raised to `5` with a chat notice; any other value is left alone. It
  runs once per account, so choosing 3 again afterward is respected.
  Slider range is unchanged (3-13).
- **Trade-off:** a longer window gives sprinting or riding more time to
  add up to the 20m threshold after an interaction. This version is a
  stopgap; 1.3.0 is planned to replace the fixed delay with the same
  sudden-jump polling the teleport and lockpick checks use.
- **Unverified:** whether 5s is long enough for every door - the
  cathedral's actual transition time wasn't measured.
- Syntax-checked; **not yet tested in-game.**

---

## What's New in 1.2.5

- **Fixed the trace's reticle hook reading the wrong argument.**
  `ZO_PreHook` passes the hooked method's `self` (`RETICLE`) first -
  confirmed in the ESOUI client source (`libraries/utility/zo_hook.lua`,
  12.0.8). The hook's `interactionPossible` was actually `RETICLE`, so
  it was always true and the "nothing targeted" branch never ran. It now
  takes `(self, interactionPossible)`, so the trace shows
  `(no reticle text)` when nothing was targeted instead of `'nil' /
  'nil'`. Trace-only - detection is unaffected. Same fix applied to
  Frostfall v3.4.33.
- Also verified this session (no code change): LID's `StartInteraction`
  wrapper passes the game's return value through unchanged, and its
  handler completes before returning - so it cannot swallow an interact
  press. The occasional need to press E twice when leaving right after
  a lockpicked entry was reproduced with LID and Frostfall disabled,
  i.e. it's game behavior.

---

## What's New in 1.2.4

- **Fixed: lockpicked doors were still missed on some doors.** In-game
  trace (Gane House): a single E press on a locked door produced ONE
  `StartInteraction` call, so 1.2.2's door-vs-chest test (2+ calls =
  door) classified it as a chest and ignored the success. Entry wasn't
  counted, and the exit then flipped the flag the wrong way. The earlier
  2-call observation (Landreau House) was real but not consistent, so
  the call-count classification is **removed**.
- **Confirmed via the same trace:** ESO moves the player through the door
  automatically after a successful pick - the next interaction after the
  success was the exit door from inside, with no press in between.
- **New approach - no classification at all:** after any lockpick
  success, a short poll (every 250ms, ~5s) toggles the flag on a single
  sudden JUMP between consecutive samples, the same idea as the 1.2.3
  teleport poll. A door transition is one jump (4657 units in the
  reported log); a chest never moves the player, and running covers
  ~2m per sample, so a chest pick can't toggle anything. Language-
  independent.
- **Overlap handling:**
  - A door check still pending at success (from the E press that opened
    the minigame, on a pick faster than the delay) is settled first at
    the pre-pick position, so it can't also see the jump.
  - An interaction during the poll hands the crossing to the door check
    (whose start position is taken before any jump) and ends the poll.
  - A running teleport poll makes the lockpick poll stand down.
  - A same-zone `EVENT_PLAYER_ACTIVATED` during the poll skips the
    zone-default reset (same rule as 1.2.0's door-check case).
  - Real zone changes / login restores cancel the poll.
- **Unverified:** the ~5s window is a judgment call; the actual time
  from success to arrival hasn't been measured (the trace will show it).
- Trace: `Lockpick SUCCESS ... watching for a door jump`, then either
  `Lockpicked door: ... single-step jump` or `no jump within window`.
- Offline-tested with stubbed ESO functions: a replay of the reported
  Gane House sequence (single call, 13s pick, automatic entry, double
  press on exit), a quick pick with the double-call pattern, a chest
  pick followed by a sprint (no toggle), an E press after success but
  before the move (counted once), and a same-zone activation during the
  poll. **Not yet tested in-game.**

---

## What's New in 1.2.3

- **Fixed: moving quickly after closing the world map read as a
  teleport.** Confirmed in-game with the trace: open and close the map,
  run away immediately, and the map-close poll reported a 2750-unit
  delta after ~3s and reset the flag to the zone default. Harmless
  outdoors (the reset matches), but inside a large interior sub-cell of
  an exterior zone it would flip the flag to Exterior. Cause: the poll
  measured total distance from where the map was OPENED, so any
  movement adding up to 20m within the 15s window qualified.
- **The teleport poll now looks for a single sudden jump between two
  consecutive samples**, not total distance from the start. A teleport
  lands between two samples in one step; running does not.
- **Poll interval 1000ms -> 250ms** (attempts 15 -> 60, same ~15s
  window) so each step is short: the observed running speed covers ~2m
  per step, 10x under the 20m threshold.
  **Unverified:** ESO's top mounted speed. A mount would need ~80 m/s to
  cross the threshold in one step, so this is assumed safe.
- The first step still compares against the trigger-time position (map
  open / travel hook call), so a jump that happens before polling
  starts is still caught.
- Applies to all teleport triggers (the four hooked travel functions and
  the map-close fallback). The door check is unchanged - it still
  compares start and end positions (see 1.2.1).
- Offline-tested with stubbed ESO functions: the reported
  map-close-then-run case (no reset), a 20 m/s mounted run (no reset),
  a same-zone map teleport after an 8s Recall, an instant
  `FastTravelToNode`, and a jump while the map is still open (all
  reset). **Not yet tested in-game.**

---

## What's New in 1.2.2

- **Fixed: entering through a lockpicked door was never counted.**
  Reported in-game: pick a door lock, enter, leave immediately - the flag
  ended up Indoors while outside. The E press that opens the lockpick
  minigame starts a door check, but it fires mid-minigame and sees no
  movement; the actual crossing after a successful pick involves no
  further interaction, so nothing checked it. The flag stayed Exterior
  inside, and the exit door then flipped it the wrong way.
- **`EVENT_LOCKPICK_SUCCESS` now starts (or extends) a door check - for
  doors only.** Confirmed in the ESOUI client source
  (`ingame/lockpick/lockpick.lua`, 12.0.8) along with
  `EVENT_BEGIN_LOCKPICK`, `EVENT_LOCKPICK_FAILED` and
  `EVENT_LOCKPICK_BROKE`.
- **Doors vs. chests, language-independently:** the author observed, with
  a single E press each, that a locked door produces TWO
  `StartInteraction` calls ~1s apart and a locked chest produces ONE
  (both show action `'Unlock'`, so the action text can't distinguish
  them, and the target name is localized). A pick counts as a door when
  2+ calls fall in a window around `EVENT_BEGIN_LOCKPICK` (3s before, up
  to 2s after, never past the success itself).
  **Observed on one door and one chest only.** A door that produces a
  single call would be skipped (same behavior as before this version);
  the trace reports the call count and target for every pick, so that
  would show up. An unrelated interaction just before picking a chest
  could make the chest count as a door - harmless (the check sees no
  movement) unless the player also moves 20m+ in the window.
- **Not verified:** whether a successful pick moves the player through
  the door automatically. The check is correct either way - if a second
  E press is needed, it extends the same check.
- Trace now also logs lockpick begin/success/failed/broke.
- Offline-tested with stubbed ESO functions: slow and quick door picks,
  leaving immediately afterward, a chest pick followed by a sprint (no
  check started), and the 1.2.1 cook-fire case. **Not yet tested
  in-game.**

---

## What's New in 1.2.1

- **Fixed: a door used shortly after any other interaction was never
  counted.** Found by the author in-game: enter a building, use a cook
  fire, leave very quickly - the flag stayed Interior. Cause: the cook
  fire started a door check, and `OnPlayerInteract` silently IGNORED the
  exit door because that check was still pending. If the exit transition
  hadn't finished by the time the cook-fire check fired, it saw no
  movement and nothing was toggled - leaving the flag inverted, so every
  later door "flipped" it the wrong way. This is the likely cause of the
  original unexpected-flipping reports.
- **New behavior:** an interaction during a pending check now restarts
  the timer but keeps the check's ORIGINAL starting position, so the
  check compares "before the first interaction" with "after the last one
  settled". Comparing positions gets the crossing count right no matter
  how many crossings happen in between (in-then-out quickly correctly
  produces no toggle).
- **Extension is capped at one door-check delay** after the first
  interaction (longest window ~2x the delay). Past the cap, the pending
  check is evaluated immediately and a fresh one starts from the current
  position - still correct, since a crossing in progress just lands in
  the fresh check. A first draft used a 12s cap; offline testing showed
  that let a run of looting interactions stretch the window long enough
  for ordinary walking to read as a door, so it was tightened before
  release.
- Trace (`/lid debug trace on`) now reports `EXTENDS door check`,
  `finishing door check #N early`, and which check each result started
  from, instead of `Interaction IGNORED`.
- Offline-tested with stubbed ESO functions: the cook-fire case, the
  same with a third press after the cap, in-and-out within one window,
  a looting run while walking (no false door), plus the 1.2.0
  same-zone-activation and zone-change-cancel cases. **Not yet tested
  in-game.**
- Unchanged: door-check false positives from sprinting/riding 20m+
  within a single window. The cap keeps windows short but doesn't
  eliminate this.

---

## What's New in 1.2.0

Prompted by reports of the indoor/outdoor flag flipping unexpectedly
(watched on the LID debug HUD, so not a consumer-side display lag).

- **New `/lid debug trace on|off`.** Logs every change to the live flag
  with the mechanism responsible, a `GetGameTimeMilliseconds()`
  timestamp and the measured delta, plus every interaction (with the
  reticle's action/name text), every door-check outcome including "not a
  door" and "ignored because a check was pending", every travel trigger,
  and every `EVENT_PLAYER_ACTIVATED`/`DEACTIVATED` (with `initial`, raw
  zoneId before/after, and whether a door check was pending).
  Persisted account-wide like the HUD toggle so login activations are
  traced too - **unverified** whether chat output that early in loading
  actually displays.
- **All writes to `isInterior` now go through one `SetIsInterior()`
  function**, so no mechanism can change the flag without appearing in
  the trace. No behavior change by itself.
- **Fix: a same-zone `EVENT_PLAYER_ACTIVATED` during a door crossing no
  longer counts the crossing twice.** Previously, if the event fired in
  the same raw zone while a door check was pending, `OnPlayerActivated`
  reset to the zone default and then the door check toggled on top of
  it - right going in, wrong coming out. Now, when the activation is not
  a login, the raw zone is unchanged, the zone default is exterior, and
  a door check is pending (or toggled within the door-check delay), the
  reset is skipped and the door check alone decides. This is checked
  before the reload-restore branch, since a pending door check can never
  survive a real `/reloadui`.
  **Unverified:** whether ESO ever fires the event for an ordinary door
  at all. This guards against the suspected cause; the trace will show
  whether it actually happens.
- **Fix: a real zone change (or login restore) now cancels any door check
  still in flight** via a per-check token, instead of relying only on
  the check noticing the raw zoneId changed.
- Offline-tested with stubbed ESO functions (door crossings in both
  directions with a same-zone activation mid-crossing, with the
  deactivation save happening both before and after the position
  change; a plain door with no activation; a real zone change during a
  pending check). Not yet tested in-game.
- **Known remaining gaps, deliberately not addressed in this version:**
  if the door check already finished WITHOUT toggling before a
  same-zone activation arrives, the normal restore/reset still applies;
  a non-door interaction followed by a same-zone activation (e.g. a
  same-zone wayshrine trip, if that fires the event) is still
  mishandled, as it was before. Door-check false positives from
  movement and ignored overlapping interactions ("option 4") are
  unchanged.

---

## What's New in 1.1.0

- **Reinstated `/lid debug saved`**, removed in 1.0.0's cleanup on the
  assumption the restore-on-login mechanism had been fully validated by
  then. A report of the restore failing specifically for an interior
  sub-space combined with a multi-hour offline gap showed that
  assumption didn't hold for every case - this command dumps saved vs.
  current raw zoneId/position/state, plus whether the raw-zoneId match
  that gates the restore (`OnPlayerActivated`) actually holds, so that
  case (and any other restore failure) can be diagnosed directly instead
  of guessed at.
- **New `/lid debug flip`**: inverts the live `isInterior` flag for the
  current session only, entirely unpersisted. A manual escape hatch for
  when the restore-on-login logic gets it wrong - the player can correct
  their own indoor/outdoor state in one command rather than wait for a
  real fix, or live with it being wrong until their next real zone
  change, door interaction, or map teleport naturally overrides it
  anyway (which this command doesn't interfere with - the very next one
  of those re-evaluates and overrides normally, as if the flip had never
  happened).

---

## What's New in 1.0.1

- **Fixed an ESOUI moderator-flagged compliance violation**: the manifest's
  `## DependsOn: LibZone LibAddonMenu-2.0` had no version floors at all,
  against the site's explicit mandatory rule (every non-optional
  dependency must specify `>=` its dependency's current `## AddOnVersion`).
  Fixed to `## DependsOn: LibZone>=077 LibAddonMenu-2.0>=43`, matching the
  exact floors already used consistently across LibZoneTemp/Frostfall/
  LibArmorInsulation in this same account.
- **Fixed a second flagged issue**: `GetEventManager()` was called
  separately four times throughout the file instead of being cached
  once. Added `local EM = GetEventManager()` near the top and replaced
  all four call sites (`RegisterForEvent`/`UnregisterForEvent`) with `EM:`.
  No behavior change - same singleton either way, just fewer repeated
  lookups.
- No other functional changes in this version.

---

## What's New in 1.0.0 (first stable release)

- **Removed debug-only tooling added during development**, no longer
  needed now that every mechanism has been confirmed working in-game:
  - `/lid debug saved` and `/lid debug hooks` slash commands
  - Per-event chat diagnostics that would have been spammy in normal
    play: the `Activated: initial=...` line (fired on every zone
    load/login), `Restored saved state: ...`, `Same-zone teleport
    detected...` (fired on every fast-travel), and `worldMap
    StateChange: ...` (fired on every single map open/close)
  - Now-unused diagnostic-only SavedVariables fields:
    `lastDeactivateRan`, `lastDeactivateRawZoneId`, and the
    `libZoneId`/`libParentZoneId` fields on the saved position record
  - The `lib._hookStatus` tracking table that backed `/lid debug hooks`
  - One-time load warnings (a hook target not found, the settings menu
    failing to build) are UNCHANGED and remain - these are genuine,
    low-noise error signals, not debug spam, and stay valuable if a
    future ESO patch renames one of the hooked functions.
- **Condensed the file header comment block**, which had accumulated
  substantial version-by-version bug-fix narrative more appropriate for
  this changelog than for live working comments. The methodology
  explanations that remain load-bearing for future maintenance (the
  raw-vs-LibZone zoneId distinction, why the door toggle differs from
  the teleport check, the persistence design) are kept; the "here's what
  we tried and found wrong in version X" history is not repeated there.
- **Updated the manifest and README** to reflect a tested, stable
  release rather than "not yet tested in-game" - every core mechanism
  (zone-change handling, the door toggle, the map-teleport check across
  all three trigger sources, and logout/reload persistence) has been
  directly confirmed working through extensive in-game testing across
  the 0.5.0-0.7.6 development cycle. The 1,053-entry zone classification
  table is explicitly called out as a separate, ongoing concern - it
  remains a lore/research-derived judgment call, not something verified
  zone-by-zone in-game, and should be treated as correctable via the
  settings-menu override rather than as verified fact.
- No functional/logic changes in this version - cleanup and
  documentation only.

---

## What's New in 0.7.6

- **Unified the two teleport-detection trigger sources onto a single
  check.** Learned that ESO's 8-second "Recall" cast only applies to
  travel initiated remotely from the world map (to either a wayshrine or
  a house) - standing physically at a wayshrine and picking another one
  is instant, no cast at all. The four hooked functions from 0.7.2
  (`FastTravelToNode`, `RequestJumpToHouse`, `JumpToHouse`,
  `JumpToSpecificHouse`) fire at actual-teleport-execution time
  regardless of which case applies - meaning their old single fixed
  delay (inherited from the door check) was only ever correct for the
  instant case by coincidence, and was equally likely to be too early
  for a map-initiated wayshrine or house trip. This had not yet been
  reported as broken only because it hadn't been tested against that
  specific case.
- **Replaced the fixed-delay check with the same bounded poll built for
  the map-close path in 0.7.5** (renamed `PollForMapTeleport` to the more
  general `PollForTeleport`, and its tuning constants from
  `MAP_TELEPORT_POLL_*` to `TELEPORT_POLL_*`, since both trigger sources
  now share it). `FinishFastTravelCheck` and its single-delay
  `zo_callLater` call are removed entirely - nothing in the fast-travel/
  map-teleport detection path relies on a fixed delay guess anymore.
- No change to what triggers a check (still the four hooked functions
  plus the world-map open/close lifecycle) or to the reset-to-zone-
  default behavior - only how long each waits and how it decides a
  teleport actually happened.

---

## What's New in 0.7.5

- **Fixed the world-map-close check from 0.7.4 not working**: reported
  that the map closes to let the player trigger a teleport "animation"
  separately - meaning the map's close event fires well before the
  actual position change, not immediately before it as 0.7.4 assumed.
  A source found earlier in this project (an ESOUI forum thread)
  describes ESO's "Recall" ability (wayshrine travel) as an 8-second
  cast, not instant - the four hooked functions from 0.7.2 apparently
  fire at the moment that cast COMPLETES (explaining why a short fixed
  delay has worked fine for them), while the map's close event fires
  when the cast hasn't even started yet.
- **Replaced the single delayed check with a bounded poll**: after the
  map closes, position is now checked once per second for up to 15
  attempts (`MAP_TELEPORT_POLL_MAX_ATTEMPTS`), comfortably covering the
  documented 8-second cast plus buffer, stopping as soon as either a
  real change is detected or the window expires. Deliberately not
  another fixed-delay guess, since that approach has already needed
  correction twice in this project (1-5s, then 3-13s for the door/
  hooked-function checks) - a bounded poll is robust to not knowing the
  exact timing at all.
- **This is NOT the continuous position poll rejected earlier in this
  project's design discussion** - that would have run constantly during
  normal play, which was the actual objection to it. This only runs for
  a few seconds after a genuinely rare trigger (closing the world map),
  so the added cost is negligible regardless of how the timing question
  resolves.
- The four hooked functions (`FastTravelToNode`, `RequestJumpToHouse`,
  `JumpToHouse`, `JumpToSpecificHouse`) and their existing single-delay
  check (`FinishFastTravelCheck`, reused via `OnFastTravelInitiated`)
  are unchanged - only the world-map-close path was revised.

---

## What's New in 0.7.4

- **Learned the actual mechanism behind the house-teleport gap**: a
  player's own house map pin opens a sub-menu offering interior vs.
  exterior-door travel, each apparently calling a different underlying
  function - explaining why none of the four functions hooked in 0.7.2
  fired for the exterior-door option specifically (they may well cover
  the interior option correctly; that branch hasn't been tested since
  it isn't the gap being chased).
- **Added a fifth, more general detection mechanism** instead of
  guessing a fifth specific function name: watches the world map's own
  open/close lifecycle via `SCENE_MANAGER`'s scene state-change
  callback, rather than any specific travel function. Position is
  captured when the map opens (guaranteed to precede any possible travel
  confirmation) and compared, after the same configurable delay, to
  position after the map closes - reusing `FinishFastTravelCheck()`
  directly, so the reset-to-zone-default behavior and the shared
  `fastTravelCheckPending` guard are unchanged. This doesn't need to
  know which internal function a given travel option calls, only that
  the map was involved - covering the house exterior-door case and
  potentially future cases without another guess-a-function-name cycle.
- **Confirmed via the actual ESOUI client source** (fetched earlier in
  this project) that `SCENE_MANAGER:IsShowing("worldMap")` is real,
  confirming "worldMap" as the correct scene name. The `StateChange`
  callback registration pattern and exact state constant names
  (`SCENE_SHOWING`, `SCENE_HIDDEN`) are NOT independently re-verified
  this session - the callback prints every raw state transition it
  receives to chat, so this can be confirmed empirically rather than
  trusted blindly, the same treatment given every other unverified
  assumption in this project.
- If this mechanism fires for the same physical teleport as one of the
  four hooked functions (e.g. a wayshrine, which also involves opening
  the map), the shared `fastTravelCheckPending` flag means only one of
  them actually runs the check - harmless, since resetting to the zone
  default twice for the same event has no different effect than once.

---

## What's New in 0.7.3

- **Added `/lid debug hooks`** in response to a report of neither a
  hook-triggered chat message NOR a "not found" load-time warning
  appearing for a house map-travel test - an ambiguous result that
  could mean several different things: the load-time warning firing
  during `EVENT_ADD_ON_LOADED` (quite early in the boot sequence)
  possibly happening before chat is ready to render messages, or a
  later-loading game UI module (e.g. housing) overwriting this
  library's hook with a fresh original sometime after install.
- `HookGlobalFunction` now records install status in
  `lib._hookStatus[name]`, including a reference to the exact wrapped
  function it installed. `/lid debug hooks` checks all four hooked
  names (`FastTravelToNode`, `RequestJumpToHouse`, `JumpToHouse`,
  `JumpToSpecificHouse`) at any point in the session - not just at load
  time - and reports one of three states per name: never found at
  install, installed and still active, or installed but since replaced
  by something else. This should distinguish "the function doesn't
  exist under this name" from "it exists but our hook got overwritten"
  from "our hook is fine and something else is preventing detection" -
  three different problems that would otherwise look identical.
- No logic changes to the actual detection mechanism in this version.

---

## What's New in 0.7.2

- **Investigated a report that teleporting to a player house's front
  door via the world map doesn't trigger detection** - confirmed that
  wayshrine-to-wayshrine same-zone travel already works correctly
  (0.7.1's fix), so the house case is a genuinely separate hook point,
  not a repeat of the earlier bug. Direct evidence it's a different
  mechanism: no confirmation dialog appears for a house map-pin click,
  unlike wayshrine travel.
- **Found and hooked three additional real functions**: `RequestJumpToHouse`,
  `JumpToHouse`, `JumpToSpecificHouse`. Confirmed real via UESP's actual
  API function-export data across four separate API versions
  (100020/100021/100026/100029) and live forum reports from 2022/2024
  confirming they still work today - a notably stronger confidence tier
  than `FastTravelToNode`'s single decade-old forum source.
  `RequestJumpToHouse` is called internally by the housing/collections
  book UI and is the most likely match for a map house-pin click, since
  map house pins reference the same collectible data; the other two are
  the slash-command-callable versions, hooked as well since which one a
  map click actually routes through has not been confirmed.
- **Refactored the hook installation into a shared `HookGlobalFunction(name, onCalled)`
  helper**, replacing the standalone `HookFastTravel`-specific wrapping
  code. Reduces duplication now that four different globals are hooked
  the same way, and centralizes the "warn in chat if missing, don't
  error" guard that previously only existed for `FastTravelToNode`.
- All four hooked globals share the same `OnFastTravelInitiated()` /
  `FinishFastTravelCheck()` mechanism from 0.7.0 (reset to zone default,
  not toggle) and the same independent `fastTravelCheckPending` flag
  fixed in 0.7.1 - no changes to that underlying logic in this version.

---

## What's New in 0.7.1

- **Fixed a real regression introduced in 0.7.0**: door-transition
  detection appeared to work asymmetrically (exiting a building
  correctly flipped the flag, entering did not). Root cause: the door
  check and the new fast-travel check from 0.7.0 shared a single
  `lib.state.checkPending` flag as their "don't start a new check while
  one's already running" guard. If `FastTravelToNode` fired for any
  reason - including possibly more broadly than the "user confirmed a
  map-travel dialog" case assumed when it was hooked - it set
  `checkPending = true` for the next several seconds. A door interaction
  during that window would see the flag already true and silently
  return with no error, skipping the check entirely. By the time a
  later door interaction happened, the earlier check had long since
  cleared the flag, so it worked normally - exactly matching "entering
  does nothing, exiting later works fine."
- **Fixed by giving each mechanism its own independent flag**:
  `lib.state.doorCheckPending` and `lib.state.fastTravelCheckPending`.
  Neither can suppress the other now, regardless of what actually
  triggers either one - this also means the underlying question of
  whether `FastTravelToNode` is the right/only hook point, or fires more
  broadly than assumed, remains open but is no longer able to silently
  break unrelated detection either way.
- No other logic changes in this version.

---

## What's New in 0.7.0

- **Investigated a report that the interior/exterior flag doesn't update
  after teleporting via the world map to a different part of the SAME
  zone** (e.g. from an interior sub-cell to the exterior side of a house
  door). Confirmed via testing that this specific case does not fire
  `EVENT_PLAYER_ACTIVATED` at all - unlike a cross-zone wayshrine
  teleport or entering a full-zone-change location like a player house,
  both already handled correctly by existing logic. Neither the door
  check (gated on an interaction, which a map click isn't) nor
  `OnPlayerActivated` had any opportunity to run for this case.
- **Added a second, independent transition check specifically for
  map-based fast travel**, same shape as the door check (hook a trigger,
  wait, compare raw position) but for a different hook point. Research
  found `EVENT_START_FAST_TRAVEL_INTERACTION`, a real documented ESO
  event, does NOT cover this - per a directly relevant ESOUI forum
  thread, it only fires for physically interacting with a wayshrine, not
  a remote map click. That same thread names `FastTravelToNode(...)` as
  firing when the player confirms a map-based travel dialog - the hook
  point actually used here, following the exact same wrap-and-call-
  through pattern as the `INTERACTIVE_WHEEL_MANAGER.StartInteraction`
  hook. **Source is a decade-old forum post** - real risk this global
  has been renamed since API changes; `HookFastTravel()` warns in chat
  if the function doesn't exist, same as the existing interaction hook's
  guard.
- **Deliberately does NOT reuse the door check's toggle logic.** A door
  is symmetric (used once to enter, once to exit), so toggling is
  correct there. A teleport is not symmetric - it can land the player
  anywhere regardless of their state beforehand. Toggling on a detected
  teleport would introduce a new bug (teleporting between two exterior
  spots in the same zone would incorrectly flip to "interior"). The new
  check instead RESETS to the zone's default when a same-zone jump is
  detected, since a fast-travel destination is essentially always the
  zone's ordinary outdoor arrival point. A cross-zone teleport detected
  by this hook correctly defers to `OnPlayerActivated` (same zone-
  mismatch guard as the door check), since that case is already handled.
- Reuses the same door-check delay and distance-threshold settings
  (`doorCheckDelaySeconds`, `doorDeltaThreshold`) rather than introducing
  separate tuning for this - worth reconsidering if map-teleport
  detection turns out to need different values than physical door
  detection.

---

## What's New in 0.6.9

- **Root cause of persistence not surviving `/reloadui` found via a
  clean, isolated test** (all other addons disabled, saved data wiped,
  before/after SavedVariables compared directly): the save side was
  proven fully correct - `lastIsInterior=true`, matching zoneId, and
  `lastDeactivateRan=true` all present exactly as expected before the
  reload. The failure was entirely on the restore side: `initial` reads
  **false** for `/reloadui`, not true as assumed in 0.6.7's design -
  meaning 0.6.7's restore condition (`initial == true` and a zoneId
  match) could never fire for a reload, only for an actual full login.
- **Combined the two signals instead of relying on either alone**, since
  testing has now shown each is reliable for a different case and
  neither covers both:
  - A genuine relogin: `initial` is true, but position is NOT reliable
    (proven in earlier testing - saved and post-login positions
    differed by tens of meters despite no movement).
  - A `/reloadui`: `initial` is false, but position IS reliable, since
    the player never actually leaves the 3D world during a reload -
    genuinely unmoved should mean an exact or near-exact match.
  - Restore now happens if the saved raw zoneId matches AND EITHER
    `initial` is true OR the current raw position is within
    `RELOAD_POSITION_MATCH_TOLERANCE` (50 raw units / 0.5m) of the saved
    one. A same-zone teleport (wayshrine or otherwise) fails both checks
    simultaneously - not a login, and genuinely far from the saved
    position - so it still correctly resets to the zone default rather
    than carrying over a stale flag, preserving the teleport-safety
    property from 0.6.7's redesign.
- This is NOT a return to 0.5.0-0.6.6's position-matching design -
  position is used only as a secondary signal for the specific
  same-position-guaranteed case (`/reloadui`), never as the primary or
  sole signal for a real login, where it was already proven unreliable.
- Diagnostic messages updated to reflect the combined check; the
  `Restored saved state` message no longer says "on login" specifically,
  since it can now also fire for a same-position reload.

---

## What's New in 0.6.8

- **Investigated a suspected inversion between `/amioutside`'s printed
  result and the `isInterior` value stored in SavedVariables.** Traced
  every read/write of the value: `OnPlayerDeactivated`'s save,
  `OnPlayerActivated`'s restore, and the HUD's display all use
  `isInterior` directly with no inversion anywhere. The only inversion
  in the entire file is `/amioutside` printing `not isInterior` -
  deliberate, since the command answers "am I outside," the logical
  negation of "is interior." No bug found in the save/restore/HUD
  pipeline itself from this trace alone.
- **Added `DescribeIsInterior()`**, rendering the boolean as plain
  "Interior"/"Exterior"/"unknown" text, and switched every diagnostic
  message that previously printed a bare `isInterior=true/false` to use
  it instead - `/amioutside`'s second line, the login-restore message,
  and `/lid debug saved`'s output. `/amioutside`'s primary `true`/`false`
  line is unchanged, since that output format was the original request.
  This changes only display formatting, not any stored, compared, or
  restored value.
- Pending confirmation: what `/amioutside` actually printed at the
  reported test, and what the player's actual physical state (indoors or
  outdoors) was at the moment the saved state being restored was
  originally written. If the restored value doesn't match what was
  actually true at that past logout, the bug would be upstream of
  everything traced here - in whatever set `lib.state.isInterior` before
  the save happened, not in this display/storage pipeline.

---

## What's New in 0.6.7

- **Replaced position-based logout/login matching with an `initial`-gated
  design**, following testing that showed ESO does not reliably restore
  a player's exact raw coordinates across a genuine relogin - saved and
  post-login positions differed by tens of meters in a real test even
  though the player hadn't moved. All position-matching machinery
  removed: `POSITION_MATCH_TOLERANCE`, `RESTORE_CHECK_DELAY_MS`, the
  delayed `zo_callLater` check, and `TryRestoreFromSave` entirely.
- **New logic**: `EVENT_PLAYER_ACTIVATED`'s own `initial` parameter
  (true only on a genuine login/reload, false for same-session zone
  changes and teleports - used from established community convention,
  not independently re-verified this session, so a diagnostic chat
  message now prints its value on every activation) determines whether
  to restore. If `initial` is true AND the saved raw zoneId matches the
  current one, the saved `isInterior` flag is restored immediately -
  synchronously, no delay needed since there's no position to wait for.
  Otherwise, the zone's default is used.
- **This also resolves a teleport-safety gap the old design never
  handled**: a wayshrine (or any) teleport fires
  `EVENT_PLAYER_ACTIVATED` with `initial=false` even when it lands in
  the same raw zone as before, so it now always resets to the zone
  default rather than carrying over a stale flag from wherever the
  player was pre-teleport. The old position-matching design only ever
  compared against a previous *logout* and had no logic for a
  same-session teleport at all.
- Raw x/y/z are still saved on logout for diagnostic visibility via
  `/lid debug saved`, but are no longer used in the restore decision
  itself - only the saved raw zoneId and `initial` matter now.
- Everything else from 0.6.6 (the `Quit()` hook removal, the
  `lastDeactivateRan`/`lastDeactivateRawZoneId` diagnostics) is
  unaffected by this change.

---

## What's New in 0.6.6

- **Removed the `Quit()` global function hook added in 0.6.5.** It was
  justified at the time as "the same pattern already confirmed working
  in your own code" — that was wrong. The pattern (save an original
  global function reference, override it to run extra logic, then call
  through to the original) was copied from having read
  VotansDarkerNights' source, a **third-party addon uploaded earlier in
  this project purely for analysis, not authored by Krek and not part
  of this codebase.** Conflating it with Krek's own established
  conventions was a real mistake, not just an imprecise description, and
  is corrected here by removing the hook entirely rather than keeping it
  under different wording.
- **This version therefore relies solely on `EVENT_PLAYER_DEACTIVATED`
  for saving on logout again** - the same single save path as every
  version through 0.6.4. No second save trigger exists as of this
  version.
- The diagnostic fields added alongside the `Quit()` hook in 0.6.5 -
  `lib.charSavedVars.lastDeactivateRan` and `lastDeactivateRawZoneId`,
  and `/lid debug saved`'s reporting of both - are unaffected and remain
  in place, since those are original to this project and don't derive
  from VDN.
- No other functional changes in this version.

---

## What's New in 0.6.5

- **Investigated a report that no `lastPosition`/`lastIsInterior` data
  was saved at all on logout** - the character SavedVariables file
  contained only the `ZO_SavedVars`-internal `"version"` key, meaning
  `OnPlayerDeactivated`'s write statements never executed. Two
  explanations produce an identical symptom: `EVENT_PLAYER_DEACTIVATED`
  never fired for the exit method used, or it fired but
  `GetUnitRawWorldPosition` returned `nil` at that moment (unit data can
  become invalid once the deactivation sequence has started tearing down
  game state). Not yet determined which.
- **Added diagnostics to disambiguate them going forward**:
  `lib.charSavedVars.lastDeactivateRan` is now set unconditionally as the
  very first action in `OnPlayerDeactivated`, before anything that could
  fail, and `lastDeactivateRawZoneId` records the raw position read's
  result (or `nil`) regardless of whether the rest of the function
  continues. `/lid debug saved` now prints both. If `lastDeactivateRan`
  is still absent next test, the event genuinely never fired for that
  exit method; if it's present but the zoneId is `nil`, the position read
  is what failed.
- **Added a second, independent save trigger**: hooked the global
  `Quit()` function, calling `OnPlayerDeactivated()` before passing
  through to the original - justified at the time as "the same pattern
  already confirmed working in your own code." **This attribution was
  wrong and is corrected in 0.6.6, which removes this hook entirely -
  see that entry.**
- No changes to the restore/comparison logic itself in this version -
  purely additional capture points and diagnostics, since the save
  never happening at all is further upstream than anything the 0.6.2
  comparison fix touches.

---

## What's New in 0.6.4

- **Added a second, independent zoneId reading to the saved position
  data**, purely for diagnostic cross-referencing. In response to a
  report that on logout, x/y/z visibly updated in SavedVariables while
  the saved zoneId did not, despite both coming from the exact same
  single `GetUnitRawWorldPosition` call with no code path that should
  allow that split - `lastPosition` now also stores `libZoneId`/
  `libParentZoneId` from `LibZone:GetCurrentZoneIds()`, captured at the
  same moment. This is NOT used by the actual restore comparison (which
  correctly stays on the raw-only scheme per 0.6.2's fix) - it exists
  only so the next test can show whether the raw zoneId genuinely failed
  to update while the LibZone one did (pointing at a `GetUnitRawWorldPosition`-
  specific staleness issue) or both stayed stuck together (pointing
  somewhere else entirely, e.g. save-flush timing).
- `/lid debug saved` now prints both zoneId readings for the saved and
  current position side by side.
- No change to detection/restore logic in this version - the root cause
  of the reported x/y/z-vs-zoneId split has not been identified yet.

---

## What's New in 0.6.3

- **Added `/lid debug saved`**, dumping the raw saved position/state
  (zoneId, resolved zone name, x/y/z, isInterior) alongside the current
  raw position/zone, side by side. Added in response to a report that
  after 0.6.2's zoneId-scheme fix, a restore check reported "saved raw
  zoneId 382 does not match current raw zoneId 3" - those resolve to
  Reaper's March and Glenumbra respectively, two entirely different
  overland zones, not two zoneId schemes for the same physical location
  (the bug class 0.6.2 fixed). This is most likely stale saved data from
  an earlier, unrelated test session/location rather than a new bug -
  the save only writes on `EVENT_PLAYER_DEACTIVATED`, so if the most
  recent real logout happened in a different zone than the current test
  location, the comparison correctly reports a mismatch. This command
  makes that distinction directly checkable instead of relying on memory
  of exact test sequencing.
- No logic changes in this version - investigation and tooling only,
  pending confirmation of which case this actually was.

---

## What's New in 0.6.2

- **Found and fixed the actual reason logout/login persistence still
  wasn't working after 0.6.1's fixes**, reported alongside "the debug
  messages from 0.6.1 never appeared at all." Root cause: `TryRestoreFromSave(zoneId)`
  took the caller's `zoneId` - sourced from `LibZone:GetCurrentZoneIds()`
  - and compared it directly against `saved.zoneId`, which was written
  in `OnPlayerDeactivated` from `GetUnitRawWorldPosition`'s zoneId. These
  are two different zoneId numbering schemes, not interchangeable - the
  same raw-vs-logical distinction established earlier in this project's
  design discussions. For a player standing in a genuine interior
  pocket (the exact scenario this feature exists to handle), these two
  values are likely to differ, so both zoneId comparisons inside
  `TryRestoreFromSave` failed deterministically, every time, rather than
  intermittently - and since the 0.6.1 diagnostic block gated its output
  on that same broken comparison, it explains why no debug messages
  appeared either.
- **Fixed** by removing the `zoneId` parameter from `TryRestoreFromSave`
  entirely - it now reads its own fresh `GetUnitRawWorldPosition` call
  and compares exclusively against that, never against the
  `LibZone`-scheme zoneId used elsewhere in this file for
  `ZONE_INTERIOR` table lookups. Both zoneId schemes are still needed
  for their respective purposes (LibZone's for the table; raw position's
  for detecting whether the player physically returned to the same
  spot) - they just must never be compared against each other.
- **Made the diagnostic output unconditional** rather than nested behind
  the same comparison that was broken. It now always prints exactly one
  of: no saved position on record, current position unreadable, saved
  raw zoneId doesn't match current raw zoneId (with both values shown),
  or the actual position delta against the current threshold - so a
  future "nothing printed" report is distinguishable from "the code
  didn't run" going forward.
- The per-character SavedVariables namespace fix from 0.6.1 (using
  `NewAccountWide` with an explicit `GetWorldName()`/`GetCurrentCharacterId()`
  namespace) is confirmed working as of this report - "the data is
  saving to SavedVariables" was already true before this fix; this
  version addresses the separate read-side bug that prevented that
  saved data from ever being matched back up on login.

---

## What's New in 0.6.1

- **Fixed the changelog rename mistake from 0.6.0** (item 1 of this
  version's requests): historical entries below now correctly retain the
  `LibIndoorDetection` name they shipped under, rather than being
  mechanically renamed. See the corrected note in the 0.6.0 entry below.
- **Investigated and fixed per-character logout/login persistence not
  working** - the reported symptom was that the player's interior/
  exterior state always reset to the zone default on login, even when
  logged out inside an interior pocket of an exterior-default zone.
  Two independent, plausible contributors were found and both addressed,
  since either alone could produce the reported symptom:
  1. **Likely primary cause:** `ZO_SavedVars:NewCharacterIdSettings(...)`
     was passed `GetWorldName()` as its namespace argument, copied
     directly from the account-wide call's pattern. This function was
     flagged as not independently re-verified when first written in
     0.5.0, and its exact parameter semantics may not accept a namespace
     the same way `NewAccountWide` does - plausibly leaving the saved
     data scoped by server only, shared across every character on it,
     rather than genuinely separated per character. **Fixed** by
     replacing it entirely with `ZO_SavedVars:NewAccountWide` (already
     proven working) using an explicit namespace string combining
     `GetWorldName()` and `GetCurrentCharacterId()` - built from
     individually well-established primitives instead of one
     uncertain function's assumed behavior. This also directly
     satisfies the "per character, per account, per server" requirement
     from this version's request #3.
  2. **Possible secondary cause:** `GetUnitRawWorldPosition` read
     immediately at `EVENT_PLAYER_ACTIVATED` may not reflect a fully
     settled position right after a loading screen - a known category of
     ESO addon timing issue. Even with correct saved data, comparing
     against a not-yet-settled position could spuriously fail the
     50-unit tolerance check. **Fixed** by setting the zone-default state
     immediately (so `lib.state.isInterior` is never left `nil`) and
     re-running the restore comparison 1 second later via `zo_callLater`
     (`RESTORE_CHECK_DELAY_MS`, an unverified starting value, same
     category as `POSITION_MATCH_TOLERANCE`).
  - **Added diagnostic chat output** to the delayed restore check,
    printing the actual position delta found (or confirming a restore
    happened) whenever a saved position exists for the current zone.
    This is verbose by design while persistence remains unverified
    in-game - worth quieting down once confirmed working correctly.
  - Not independently confirmed in-game which of the two contributors
    (or both) was the actual cause, since no in-game testing is possible
    from here - the diagnostic output above is intended to make that
    determinable from your own next test.
- **Made the debug HUD's shown/hidden state persist across relogs**
  (request #4), stored account-wide (`lib.savedVars.hudShown`) but
  deliberately still NOT exposed as a settings-menu control, matching
  the original constraint from 0.5.0 - `/lid debug hud on|off` remains
  the only way to change it.

---

## What's New in 0.6.0

- **Rebranded from `LibIndoorDetection` to `LibInteriorDetection`**, per
  author request that the original name was getting confusing. Renamed
  throughout:
  - Addon folder, main `.lua`/`.txt` file names
  - The global library table (`LibInteriorDetection` instead of
    `LibIndoorDetection` — anything consuming this library needs to
    update the reference)
  - Both `## SavedVariables` tables (`LibInteriorDetectionSavedVars`,
    `LibInteriorDetectionCharSavedVars`) — **this means any settings or
    zone overrides saved under the old `LibIndoorDetection*SavedVars`
    names are abandoned, not migrated.** Given the addon's manifest has
    stated "NOT YET reviewed or tested in-game" through every prior
    version, this was judged low-risk, but flagged plainly rather than
    silently dropped.
  - LAM panel name/display name, all chat message prefixes
  - Public API function names (`IsPlayerIndoors()`, etc.) and the
    "INDOORS"/"OUTDOORS" HUD text were deliberately left unchanged —
    the rebrand request was about the library's own name, not its
    descriptive terminology for the concept itself.
  - Historical entries below retain the `LibIndoorDetection` name they
    shipped under, matching the precedent set by Spoilage's own rebrand
    from ProvisioningSpoilageTracker (an initial pass of this rename
    mechanically renamed those entries too; corrected in 0.6.1).
- **Raised the Door Check Delay slider's range from 1-5 seconds
  (default 1) to 3-13 seconds (default 3).** The author found delays
  below ~3 seconds caused door-transition detection to stop working
  entirely on their system. The underlying mechanism has not been
  independently diagnosed (candidates include ESO's own door-open
  animation/position-settling time not having completed by the time the
  position read fires) — this range reflects the author's empirical
  finding via direct testing, not a confirmed root cause.

---

## What's New in 0.5.3

- **Fixed door-interaction detection and `/amioutside` silently never
  updating.** Root cause: `EVENT_PLAYER_ACTIVATED` / `EVENT_PLAYER_DEACTIVATED`
  registration was placed AFTER `BuildSettingsMenu()` in `Initialize()`
  ever since the settings menu was added in 0.5.0. If `BuildSettingsMenu()`
  threw any runtime error - something `luac5.4 -p` cannot catch, since it
  only validates syntax - `Initialize()` would halt right there and those
  two event registrations would silently never happen. That explains both
  symptoms at once: `lib.state.isInterior` never gets set (no zone-change
  handler ever fires), and the door-toggle's `if
  lib.state.zoneDefaultInterior == false then ...` check never passes
  because `zoneDefaultInterior` stays `nil` forever - even though the
  interaction hook itself was still installed and firing correctly.
- **Fixed by reordering `Initialize()`**: event registration and slash
  commands now happen BEFORE `BuildSettingsMenu()`, so core detection
  works regardless of whether the settings panel builds successfully.
  `BuildSettingsMenu()` is now the deliberate last step.
- **Wrapped `BuildSettingsMenu()` in `pcall`.** If it does still error for
  any reason, the actual error text now prints to chat as
  `[LibIndoorDetection] Settings menu failed to build: ...` instead of
  failing silently - this should make any remaining settings-menu bug
  immediately diagnosable rather than presenting as "detection doesn't
  work" with no visible cause.
- Not independently confirmed in-game that `BuildSettingsMenu()` was
  actually the specific thing erroring (no error log was available to
  check against) - this fix addresses the structural hazard regardless,
  and the new pcall wrapper will surface the exact cause if one remains.

---

## What's New in 0.5.2

- **Fixed `/lid debug hud on|off` not working at all** — it opened the
  settings panel instead of toggling the HUD. Cause: `BuildSettingsMenu()`
  set `slashCommand = "/lid"` in the LibAddonMenu-2.0 panel data, which
  tells LAM to register `/lid` itself to open the settings panel. Since
  that ran after this library's own `SLASH_COMMANDS["/lid"] = SlashLid`
  assignment, LAM's registration silently overwrote it every time the
  addon loaded.
- Fixed by giving the settings panel its own distinct command,
  **`/lidsettings`**, freeing `/lid` entirely for the debug dispatcher.
  Also reordered `Initialize()` to register `/lid` after
  `BuildSettingsMenu()` runs, as a defensive measure against this same
  class of collision in the future.
- The settings panel remains reachable the same three ways as before:
  `/lidsettings`, `Settings → Addons → LibIndoorDetection Settings`, or
  clicking through from the addon list.

---

## What's New in 0.5.1

- **Moved the door-transition DISTANCE threshold into the settings menu
  as a slider** (1000-8000 raw units / 10m-80m, step 100), replacing the
  `/setlocdeltathreshold` slash command entirely. Now stored account-wide
  alongside the delay slider added in 0.5.0. Resolves the inconsistency
  flagged at the end of that version's entry.
- **Default value is unchanged (2000 / 20m)** — only the range, control
  type, and persistence changed; no behavior changes for anyone who
  hadn't touched the old slash command.
- `/amioutside`'s diagnostic line now reads the threshold from
  SavedVariables instead of session-only state.

---

## What's New in 0.5.0

- **Added logout/login persistence.** On `EVENT_PLAYER_DEACTIVATED`
  (fires before every loading screen, including logout), the player's
  raw position and current live `isInterior` flag are saved to new
  CHARACTER-SPECIFIC SavedVariables (`LibIndoorDetectionCharSavedVars`,
  via `ZO_SavedVars:NewCharacterIdSettings` — not independently
  re-verified this session, flagged in the source header). On the next
  `EVENT_PLAYER_ACTIVATED`, if the saved zoneId matches and the saved
  position is within 50 raw units (0.5m — an arbitrary, unverified
  tuning constant) of the current position, the saved `isInterior` flag
  is restored instead of resetting to the zone default. This is what
  lets a player logged out inside the interior portion of an
  exterior-default zone log back into the same spot and stay flagged
  interior, per the original design request.
- **Added a LibAddonMenu-2.0 settings panel.** This is a NEW hard
  dependency as of this version — LibAddonMenu-2.0 was not previously
  required. Panel includes:
  - **Door Check Delay slider** (1-5 seconds, default 1) — replaces the
    previously-hardcoded 5-second delay from DoorDeltaTest/0.3.0 with a
    user-configurable value, stored account-wide.
  - **Per-zone interior/exterior override**, mirroring LibZoneTemp's
    zone-override pattern: a dropdown built from this library's own
    1,053-entry `ZONE_INTERIOR` table (not ESO's zone enumeration, which
    doesn't cover delves/dungeons), a second dropdown to force
    "Use Zone Default" / "Force Interior" / "Force Exterior", a live
    list of currently active overrides, and a "Clear All Overrides"
    button. `lib.IsZoneInterior()` checks the override table before
    falling back to the built-in default, so overrides apply everywhere
    the default is used, including the live door-toggle's zone-default
    check.
  - Account-wide (`LibIndoorDetectionSavedVars`), namespaced by
    `GetWorldName()` matching LibZoneTemp's own EU/NA/PTS separation
    convention.
- **Replaced `/toggleindoorhud` with `/lid debug hud on|off`**, matching
  the `/rnd debug <subcommand>` convention already used in Realistic
  Needs and Diseases. Defaults to OFF (previously the HUD defaulted to
  shown) and is deliberately NOT persisted or exposed in the settings
  menu, per explicit request — it resets to hidden on every reload/
  relogin regardless of its previous state.
- **Known inconsistency, not resolved this version:** the door
  transition DISTANCE threshold (`/setlocdeltathreshold`) remains
  slash-command-only and in-memory, resetting to 2000 on every reload,
  while the DELAY is now a persisted settings-menu slider. Only the
  delay was in scope for this request; flagging the asymmetry rather
  than silently changing the threshold's behavior too.

---

## What's New in 0.4.1

- **Fixed Captain Margaux's Place (zoneId 852)**, the entry whose incorrect
  classification originally surfaced the player-house failure mode below —
  it was flagged as exterior via a "docks" keyword false positive and had
  been left unresolved pending confirmation in 0.4.0. Confirmed interior by
  the author; flipped, tagged `verified:user:indoor-player-house`.
- Manifest disclosure updated to remove the "one entry remains unresolved"
  note, since none do as of this version.

---

## What's New in 0.4.0

- **Added an on-screen HUD** showing the player's live indoor/outdoor
  state ("INDOORS" in amber / "OUTDOORS" in blue), built from
  `WINDOW_MANAGER:CreateTopLevelWindow` / `CreateControl(CT_LABEL)`.
  Movable, defaults to shown. Position is not saved between sessions in
  this version (no SavedVariables yet) — resets to its default anchor on
  every reload/relog.
- **Added `/toggleindoorhud`** to show/hide the HUD.
- HUD updates automatically on every zone change and every door-toggle
  flip, via the same `OnPlayerActivated` / `FinishDoorCheck` call sites
  that already maintained `lib.state.isInterior`.
- **Found and corrected a recurring classification bug affecting player
  houses.** Investigating a report that Captain Margaux's Place (a player
  house) was flagged exterior traced the error to the notes-based tier
  scoring geography words from a note's *location* clause ("near the
  docks") rather than the structure's own nature. Audited all 29 zones
  whose descriptive note mentions "player house"/"player home": 15 had
  already been through manual verification in a prior pass and were
  confirmed correct (some ESO player houses genuinely are open-air
  builds); 13 more had never been reviewed and shared the same
  location-clause bug. The author confirmed, per-entry, that 12 of those
  13 are genuinely exterior (upgraded to `verified:user:outdoor-player-
  house`) and one (Golden Gryphon Garret, zoneId 1059 — an attic room)
  is interior (`verified:user:indoor-garret`). Captain Margaux's Place
  itself was not part of that 13-entry list and remained unresolved
  until 0.4.1 above.
- Interior/exterior split: **671 / 382** (previously 670/383 after the
  garret fix in this version; corrected again in 0.4.1).

---

## What's New in 0.3.0

- **`LibIndoorDetection` is now a combined static + live library**, not
  just a static table. Added:
  - `lib.state` — tracks current zoneId, the zone's static default, and
    the live combined `isInterior` flag.
  - `lib.IsPlayerIndoors()` — returns the live flag.
  - `OnPlayerActivated` (hooked to `EVENT_PLAYER_ACTIVATED`) — on every
    real zone change, resets the live flag to the new zone's static
    default unconditionally, overriding whatever the toggle below was
    mid-transition.
  - **Ported the door-transition detection mechanism from the
    DoorDeltaTest diagnostic addon** — hooks
    `INTERACTIVE_WHEEL_MANAGER.StartInteraction` as a generic interaction
    trigger (reads none of its arguments, sidestepping a known past
    argument-order bug on this same hook point in Realistic Needs and
    Diseases), then 5 seconds later compares `GetUnitRawWorldPosition`
    against the pre-interaction reading. If the largest single-axis delta
    exceeds a threshold (default 2000 raw units / 20m), and the zone's
    static default is exterior, the live flag toggles.
  - If the zone's static default is interior, the toggle is disabled
    entirely — door interactions are tracked but never flip the flag,
    since a dungeon's internal doors shouldn't toggle anything and there's
    no "exterior" to fall back into short of leaving the zone.
  - `/setlocdeltathreshold <number>` carried over from DoorDeltaTest for
    tuning door-detection sensitivity.
  - `/amioutside` now reports the live flag instead of the static zone
    default, with a diagnostic second line showing zone name, zoneId,
    zone default, and current threshold for when the two diverge.
- **Known limitation documented:** the toggle model assumes symmetric
  in/out door pairs. A player going tavern → basement → tavern → street
  (three real crossings from one exterior-default zone) desyncs the flag,
  since nested interiors aren't tracked as a stack in this version.

---

## What's New in 0.2.0

- **Replaced the original heuristic-only zone classification with a
  second, higher-confidence pass using real descriptive text.** The
  author supplied a historical UESP-verified CSV export of LibZoneTemp's
  own per-zone notes (705 entries). Re-scored every zone against that
  text using:
  - Position-independent structural phrases ("underground," "crypt,"
    "sewer," "sealed," etc.) — trusted anywhere in the note.
  - Geography phrases ("coast," "valley," "jungle," etc.) — trusted ONLY
    in the note's first sentence, after an earlier pass of this fix
    demonstrated that later sentences are usually regional climate flavor
    text (e.g. a crypt's note mentioning its region's "coastal air") and
    produced false exterior verdicts when scored without that
    restriction.
  - Fallback to the prior name-only heuristic when a note existed but
    gave no clear signal either way.
  - Documented a known residual gap: zones in the "Black Marsh" province
    can trigger the "marsh" exterior phrase from the province name
    itself. Checked all 21 affected zones by hand; none changed
    classification because of it in this pass.
- Of the original 610 zones with no reliable name-based signal, 257
  resolved via this real-text pass. Interior/exterior split moved from
  287/156 (610 uncertain) to 484/569 (353 uncertain).
- **Author supplied a manually-verified correction pass** (CSV
  round-trip) covering the remaining 353 uncertain zones — each
  individually researched and confirmed. Split became **671/382**
  across all 1,053 entries with zero remaining uncertain defaults (one
  entry, Captain Margaux's Place, was inadvertently left out of this
  pass and resolved separately in 0.4.1 — see above).

---

## What's New in 0.1.0

- **Initial release.** `LibIndoorDetection` created, mirroring
  LibZoneTemp's structure: `LIB_NAME`/`LIB_VERSION` guard against
  loading an older version over a newer one, zoneId-keyed data table,
  `DependsOn: LibZone`.
- **`ZONE_INTERIOR` table** built for all 1,053 zoneIds tracked by
  LibZoneTemp v2.3.15 (extracted directly from its `ZONE_BASE_TEMPS`,
  `ZONE_WEATHER`, and `ZONE_WATER_TEMPS` tables — real, verified
  zoneId/name pairs). Classified in three tiers of decreasing
  confidence:
  1. Known overland zones (exterior) and well-known named dungeons
     (interior) / delves (exterior — delves are open-air content by
     ESO's own design even when cave-heavy).
  2. Structural keywords in the bare zone name (cave/crypt/sewer/vault →
     interior; island/valley/coast/delve → exterior).
  3. No reliable signal — defaulted to exterior (610 of 1,053 zones),
     on the reasoning that most unclassified small ESO locations are
     Delves, and an incorrectly-exterior zone is the less sticky failure
     mode given how the flag is meant to be used (an incorrectly-interior
     zone would lock the flag with no way to toggle out short of a real
     zone change).
- `lib.IsZoneInterior(zoneId)` and `lib.GetCurrentZoneInterior()` (via
  `LibZone:GetCurrentZoneIds()`).
- `/amioutside` slash command — prints the current zone's static default
  as true/false.
- Explicitly documented as a lore/naming-derived judgment call, not
  verified game data — there is no live ESO API for indoor/outdoor
  status. Every tier recorded per-line as a trailing comment for future
  correction, the same way LibZoneTemp's own temperature table was
  refined iteratively across multiple audit passes.
