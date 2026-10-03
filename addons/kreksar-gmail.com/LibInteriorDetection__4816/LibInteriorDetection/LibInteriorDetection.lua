-------------------------------------------------------------------------------
-- LibInteriorDetection
-- Version: 1.3.6
--
-- A library that reports whether the player is currently indoors, by
-- combining a per-zone "interior" default with live door-transition and
-- map-teleport toggles, per-character logout/reload persistence, a
-- settings menu for per-zone overrides and tuning, and an optional
-- debug HUD.
--
-- CONFIRMED API USAGE:
--   ESO native:
--     GetZoneNameById(zoneId)
--     GetUnitRawWorldPosition("player")           -> zoneId, x, y, z
--     EVENT_PLAYER_ACTIVATED / EVENT_PLAYER_DEACTIVATED
--     EVENT_BEGIN_LOCKPICK / EVENT_LOCKPICK_SUCCESS / EVENT_LOCKPICK_FAILED /
--       EVENT_LOCKPICK_BROKE - confirmed in the ESOUI client source
--       (ingame/lockpick/lockpick.lua, 12.0.8, Aug 2026)
--     INTERACTIVE_WHEEL_MANAGER.StartInteraction  -> hooked as a generic
--                                                     interaction trigger
--     zo_callLater(fn, delayMs)
--     GetWorldName(), GetCurrentCharacterId()     -> combined into an
--                                                     explicit per-
--                                                     character namespace
--     WINDOW_MANAGER:CreateTopLevelWindow/CreateControl, CT_LABEL, TOP,
--       CENTER, DL_OVERLAY (standard UI constants)
--     ZO_SavedVars:NewAccountWide(name, version, namespace, defaults)
--     SCENE_MANAGER:GetScene("worldMap") - confirmed via the actual
--       ESOUI client source that "worldMap" is the real scene name
--     LibZone:GetCurrentZoneIds()
--
--   LibAddonMenu-2.0: LAM:RegisterAddonPanel / RegisterOptionControls
--
--   NOT independently re-verified this session (flagged, not fabricated
--   - each warns in chat if missing, so a future API rename is visible
--   rather than silently broken):
--     FastTravelToNode(...) - sourced from a decade-old ESOUI forum
--       thread; RequestJumpToHouse/JumpToHouse/JumpToSpecificHouse -
--       sourced from UESP's API export data (multiple versions) and
--       live 2022/2024 forum confirmations; the worldMap scene's
--       StateChange callback pattern and its SCENE_SHOWING/SCENE_HIDDEN
--       constant names.
--
-- METHODOLOGY - ZONE_INTERIOR TABLE (same category as LibZoneTemp's
-- weather table - there is no live ESO API for this, so it is authored,
-- not read from a game source):
--     1. "known-zone" / "known-name" - author's direct game knowledge.
--     2. "notes:interior(...)" / "notes:exterior(...)" - derived from
--        UESP-verified descriptive text, position-scored so regional
--        climate flavor text isn't misread as describing the structure.
--     3. "keyword:<word>" - a clear structural word in the bare zone name.
--     4. "verified:web:<summary>" / "verified:user:<summary>" - the
--        highest-confidence tier, individually researched and confirmed.
--   Every entry's table default can be overridden per-zone via the
--   settings menu - use that rather than editing the table directly.
--
-- PLAYER HOUSES (1.3.2):
--   A house zone's default comes from the game's own data instead of the
--   ZONE_INTERIOR table: houses that support Weather Control are
--   EXTERIOR, all others INTERIOR (author's rule). Read via
--   GetHouseFlags(houseId) + HOUSE_FLAGS_SUPPORTS_WEATHER_CONTROL - the
--   same flag the housing book's "Supports Weather Control" line uses -
--   and GetHouseZoneId(houseId) (0 = invalid house), all confirmed in the
--   ESOUI client source (12.0.8). A zoneId -> weather map is built once
--   by scanning houseIds 1..HOUSE_ID_SCAN_MAX. Precedence: player zone
--   override > HOUSE_EXCEPTIONS (1.3.3: author-verified houses where the
--   flag doesn't match the home's actual layout) > house weather flag >
--   ZONE_INTERIOR table (fallback if the API is ever unavailable).
--
-- RETURN POINTS (1.3.1):
--   Some zones are TEMPORARY: another player's house, a group dungeon, a
--   trial, a battleground. Logging out in one (or being removed from a
--   group instance) puts the player back where they stood BEFORE entering
--   - confirmed by the author for houses (including several house hops),
--   group dungeons and trials. That spot may be inside a building of an
--   exterior zone, whose state the normal logout save (which recorded the
--   temporary zone) doesn't have. So on leaving any NON-temporary zone
--   the library also saves a "return point" (position + state), which
--   temporary zones never overwrite. On arriving from a temporary zone,
--   if the player is back in the return point's zone and near it, that
--   state is restored instead of the zone default.
--   Temporary = GetCurrentZoneHouseId() ~= 0 (any house, own included -
--   harmless: logging out in your own house logs you back into it, which
--   the normal restore covers) OR IsActiveWorldGroupOwnable() (what the
--   game's own leave-group dialog uses to warn that leaving removes you
--   from the instance) OR IsActiveWorldBattleground(). All three confirmed
--   in the ESOUI client source; that IsActiveWorldGroupOwnable() is true
--   for exactly dungeons+trials is inferred from that dialog, and
--   battlegrounds are included by analogy, not tested. Classified on
--   ARRIVAL (EVENT_PLAYER_ACTIVATED), not on leaving.
--
-- METHODOLOGY - LIVE DOOR-TOGGLE (DOOR WATCH, 1.3.0):
--   Ordinary building interiors get no zone/map change and no event of
--   any kind on entry. INTERACTIVE_WHEEL_MANAGER.StartInteraction (the
--   interact key's handler, confirmed in the ESOUI client's
--   bindings.xml) is hooked as a generic "an interaction just happened"
--   trigger. Each interaction starts - or extends - a DOOR WATCH that
--   samples position every POLL_INTERVAL_MS until the watch window
--   (settings slider) has passed since the LAST interaction, and toggles
--   on each single sudden JUMP (> threshold) between two consecutive
--   samples. A door moves the player in one step whenever it lands, so
--   slow doors (e.g. Daggerfall Cathedral, >3s) and fast ones are both
--   caught, and running/riding never produces a jump. This replaced
--   (1.3.0) a single position comparison at a fixed delay, which missed
--   slow doors and let sprinting read as a door.
--   Counting rules:
--   - Every interaction (or lockpick success) adds one CREDIT; a counted
--     jump spends one. A jump with no credit left is ignored (logged),
--     since every real crossing needs an interaction.
--   - A jump within DOOR_JUMP_COOLDOWN_MS of the last counted one is
--     ignored (logged), in case a landing ever settles in two steps.
--     UNVERIFIED whether that ever happens; the cooldown is a guess.
--   - Each crossing is its own jump, so several in one window (cook fire
--     then out; in and straight back out; double presses) count right.
--   A door is symmetric (used once to enter, once to exit), so the flag
--   TOGGLES - but only when the zone's default is exterior (an
--   interior-default zone has no "outside" to toggle back into short of
--   leaving the zone).
--   LOCKPICKED DOORS: after a successful pick ESO moves the player
--   through the door with no further press (confirmed via the trace), so
--   EVENT_LOCKPICK_SUCCESS starts/extends the watch like an interaction.
--   A chest never moves the player, so a chest pick can't toggle.
--   Only the interact-key wheel type (ZO_INTERACTIVE_WHEEL_TYPE_FISHING -
--   the type the interact key passes, per bindings.xml) counts; the
--   quickslot and target-marker wheel keys also call StartInteraction
--   and are ignored (1.3.0).
--   KNOWN LIMITATION: assumes symmetric in/out door pairs. Nested
--   interiors (e.g. a basement beneath a tavern) desync the flag.
--
-- METHODOLOGY - FAST-TRAVEL / MAP-TELEPORT:
--   A teleport is NOT symmetric like a door - it can land the player
--   anywhere regardless of prior state, so this RESETS to the zone
--   default rather than toggling. Three independent trigger sources
--   feed the same check (PollForTeleport): the four hooked global
--   functions above (confirmed to fire at actual-teleport-execution
--   time), and the world map's own open/close lifecycle as a fallback
--   for cases where the specific internal function isn't known (e.g. a
--   player house's exterior-door sub-option fires none of the four).
--   The check POLLS position every POLL_INTERVAL_MS for about
--   15 seconds rather than using a fixed delay, and (1.2.3) looks for a
--   single sudden JUMP between two consecutive samples rather than total
--   distance from the starting point - running away after closing the
--   map (confirmed in-game: 27.5m in ~3s) was reading as a teleport.
--   A fixed delay would not work either:
--   travel initiated while standing at a wayshrine is instant, but
--   travel initiated remotely from the map (to either a wayshrine or a
--   house) is gated behind an 8-second "Recall" ability cast - a fixed
--   delay tuned for one case would be wrong for the other.
--
-- METHODOLOGY - PERSISTENCE ACROSS LOGOUT/RELOAD:
--   On EVENT_PLAYER_DEACTIVATED, raw zoneId/position and the live
--   isInterior flag are saved to CHARACTER-SPECIFIC SavedVariables (a
--   different character logging in elsewhere should not inherit
--   another character's saved state). On the next EVENT_PLAYER_ACTIVATED,
--   the saved flag is restored if the saved raw zoneId matches the
--   current one AND EITHER the event's own `initial` parameter is true
--   (a genuine login - position is not checked, since ESO does not
--   reliably restore exact coordinates across a real relogin; a loose
--   50m gate exists but is LOG-ONLY as of 1.3.5, see below),
--   OR the current position is within RELOAD_POSITION_MATCH_TOLERANCE of
--   the saved one (a /reloadui, which reports initial=false despite
--   being a legitimate resume, but never actually moves the player).
--   Any other case - including a same-zone teleport, which fails both
--   checks at once - resets to the zone default instead.
--   IMPORTANT: raw zoneId/position must only ever be compared to other
--   raw values, never to LibZone:GetCurrentZoneIds()'s zoneId (used
--   elsewhere in this file for ZONE_INTERIOR lookups) - those are two
--   different numbering schemes.
--   LOGIN POSITION GATE (added 1.3.4, LOG-ONLY since 1.3.5 - see
--   LOGIN_POSITION_GATE_ENABLED): the saved
--   record only reaches disk when ESO writes SavedVariables (logout,
--   menu Quit, /reloadui). A session that ends without that write (crash,
--   disconnect - and, unverified, possibly an idle kick or a force-close)
--   leaves the record from an EARLIER clean exit on disk. Before 1.3.4 a
--   login restored that record with no age or position check, as long as
--   the raw zone matched - which an interior pocket of an exterior zone
--   always does. A 50m gate would reject such a record when it comes
--   from elsewhere in the zone, but it can also reject a CORRECT record
--   if login drift ever exceeds 50m, and drift for a login inside an
--   interior pocket has never been measured. So 1.3.5 only traces the
--   distance and what the gate would have done; restore behavior is the
--   same as 1.3.3.
--
-- SAVE DIAGNOSTICS (1.3.4 - diagnostic only, no effect on behavior):
--   Unexplained login failures after a "proper" logout have four
--   candidate causes the code could not previously tell apart: the save
--   silently not happening (the deactivation position read returning
--   nil, seen once in 0.6.5 and never resolved), the save storing a wrong
--   raw zoneId (the read happens while the world is being torn down - an
--   x/y/z-vs-zoneId split was seen in 0.6.4), a later event overwriting
--   a correct restore, or the live flag already being wrong at logout.
--   So OnPlayerDeactivated now records, BEFORE anything that can bail
--   out: a GetTimeStamp() (confirmed in the ESOUI client source,
--   timedactivities_manager.lua - seconds), the raw zoneId it read (nil
--   if the read failed), the raw zoneId captured at the last activation
--   (lib.state.rawZoneId - read while the world was stable, so it is a
--   cross-check on the teardown-time read), the live state, and whether
--   the save completed. A trace line covers the silent early return,
--   though chat at logout can't be read afterwards - the persisted
--   record is what /lid debug saved and the login trace report.
--
-- LIVE SAVES (1.3.6): in-game testing showed quitting the game client
--   writes SavedVariables (an account-wide setting changed that session
--   survived the quit) but NOT our deactivation update: twice, a quit
--   left the record from the previous load screen or idle kick on disk,
--   while an idle kick to the login screen saved correctly. Whether
--   EVENT_PLAYER_DEACTIVATED doesn't fire on quit or fires after the
--   write is unknown, and doesn't matter for the fix: the saved record is
--   now kept current while playing, so whatever ESO writes at quit is
--   already right. SetIsInterior writes lastIsInterior on every change,
--   and every handled activation writes the zone, position and
--   temporary flag. No Quit() hook (see 0.6.6) and no polling - a
--   periodic position save was evaluated and judged cheap but not yet
--   needed (see CHANGELOG 1.3.6). Consequence: after a quit, the saved
--   position is where the current zone was loaded, not where the player
--   quit, so the login trace's distance and age are not meaningful for
--   quit exits (the zone and state still are). OnPlayerDeactivated
--   still runs a full update for exits where it fires (reload, logout,
--   idle kick, load screens), which keeps the /reloadui position check
--   exact.
--
-- SETTINGS MENU (LibAddonMenu-2.0): door watch window (5-20s, default 10),
-- door-transition distance threshold (1000-8000 raw units, default
-- 2000), and per-zone interior/exterior overrides (dropdown built from
-- this library's own ZONE_INTERIOR table, not ESO's zone enumeration,
-- since that doesn't cover delves/dungeons).
--
-- DEBUG COMMANDS: /lid debug hud on|off shows/hides an on-screen
-- INDOORS/OUTDOORS label. Persisted (account-wide), not exposed in the
-- settings menu, matching the /rnd debug <subcommand> convention already
-- used in Realistic Needs and Diseases.
--   /lid debug saved dumps saved-vs-current raw zoneId/position/state, to
--   diagnose the restore-on-login logic in OnPlayerActivated directly
--   rather than guessing at it.
--   /lid debug flip inverts the live isInterior flag for the current
--   session only (not persisted) - a manual escape hatch for when the
--   restore-on-login logic gets it wrong; the next real zone change, door
--   interaction, or map teleport overrides it normally, same as if the
--   command had never been run.
--   /lid debug trace on|off (1.2.0) logs every change to the live flag
--   (which mechanism made it, timestamp, measured delta) plus every
--   interaction, door-check outcome, travel trigger and player
--   (de)activation, to diagnose unexpected flips from real data. Every
--   write to isInterior goes through SetIsInterior() so nothing can
--   change the flag without appearing in the trace. Persisted
--   (account-wide) so activation at login is traced too - whether chat
--   output that early in the load actually displays is NOT verified.
--
-- SAME-ZONE ACTIVATION DURING A DOOR CROSSING (1.2.0):
--   If EVENT_PLAYER_ACTIVATED fires in the SAME raw zone (not a login)
--   while a door check is pending or has just toggled, the zone-default
--   reset is SKIPPED and the door check alone decides. Both mechanisms
--   would otherwise react to the same crossing (reset, then toggle),
--   which is right on the way in and wrong on the way out. UNVERIFIED
--   whether ESO actually fires the event for any ordinary door - this
--   guards against it; the trace will show whether it ever happens.
-------------------------------------------------------------------------------

local LIB_NAME  = "LibInteriorDetection"
local ADDON_ID  = "LibInteriorDetection"  -- LAM panel name / slash command namespace
local LIB_VERSION = 43

-- Cached once rather than calling GetEventManager() repeatedly throughout
-- the file - same singleton either way, avoids the repeated lookup.
local EM = GetEventManager()

-- Guard against loading an older version over a newer one.
if LibInteriorDetection and LibInteriorDetection.version >= LIB_VERSION then
    return
end

LibInteriorDetection = LibInteriorDetection or {}
local lib = LibInteriorDetection
lib.version = LIB_VERSION

-- Default when a zoneId isn't in the table at all (e.g. a zone released
-- after this table was last updated). Same "unlisted falls back to a
-- sensible default" pattern LibZoneTemp uses for DEFAULT_TEMP.
local DEFAULT_IS_INTERIOR = false

-- Door-toggle tuning.
-- Distance threshold: raw world units (centimeters). Now a settings-menu
-- slider (see ACCOUNT_DEFAULTS below). Range enforced by the slider:
-- 1000-8000 (10m-80m), default unchanged at 2000 (20m).
local DOOR_DELTA_THRESHOLD_DEFAULT = 2000
local DOOR_DELTA_THRESHOLD_MIN = 1000
local DOOR_DELTA_THRESHOLD_MAX = 8000
local DOOR_DELTA_THRESHOLD_STEP = 100

-- 1.3.0: the fixed door-check delay (3-13s, last default 5) is replaced by
-- a watch window: how long after the LAST interaction the door watch
-- keeps sampling. New saved key (doorWatchSeconds); the old
-- doorCheckDelaySeconds / doorDelayMigrated126 values are simply no
-- longer read. 10s default is a judgment call covering the slowest door
-- seen so far (>3s) with margin; not a measured limit - the trace logs
-- each door's actual time-to-land so this can be tuned from data.
local DOOR_WATCH_SECONDS_DEFAULT = 10
local DOOR_WATCH_SECONDS_MIN = 5
local DOOR_WATCH_SECONDS_MAX = 20

-- Shared sampling interval for every jump check (door watch and teleport
-- poll). Short enough that running/riding covers far less than the
-- threshold per sample (~2m per 250ms at an observed sprint).
local POLL_INTERVAL_MS = 250

local DOOR_WATCH_MAX_CREDITS = 4      -- cap so a burst of presses can't bank many
local DOOR_JUMP_COOLDOWN_MS = 1500    -- see "Counting rules" in the header (guess)
local RECENT_TOGGLE_MS = 3000         -- "just toggled" window for OnPlayerActivated

-- 1.3.1: how close (any axis, raw units) the arrival point must be to the
-- saved return point. Login positions have drifted by tens of meters
-- before without the player moving, so this is loose. Judgment call, not
-- measured - the trace logs the actual distance.
local RETURN_POINT_TOLERANCE = 5000

-- 1.3.4: how close (any axis, raw units) the login position must be to the
-- saved logout position for a genuine login (initial=true) to restore the
-- saved flag. Exact matching across a relogin was abandoned in 0.6.7
-- (drift of tens of meters, confirmed in testing); this is deliberately
-- loose - it exists to reject a STALE record from elsewhere in the same
-- raw zone (a session whose logout never reached disk), not to prove the
-- player is on the same spot. 50m is a judgment call, NOT measured: the
-- trace and /lid debug saved both report the actual distance so it can be
-- tuned from data. If real login drift ever exceeds it, the result is a
-- fallback to the zone default (traced), not an error.
local LOGIN_POSITION_TOLERANCE = 5000

-- 1.3.5: the gate above is LOG-ONLY until real data justifies it. When
-- false, a login restores exactly as 1.3.3 did (raw zone match only) and
-- the trace reports what the gate WOULD have done. Why: the gate can only
-- make restores rarer, it targets a cause (an exit that never wrote
-- SavedVariables) the reported case makes less likely, and login drift
-- has never been measured for a login INSIDE an interior pocket - which
-- is spatially far from its door, so drift there may differ. Turn on
-- only once traces show real drift and at least one confirmed stale
-- record.
local LOGIN_POSITION_GATE_ENABLED = false

-- Account-wide saved variables: preferences and zone overrides that
-- should be the same across every character.
local ACCOUNT_DEFAULTS = {
    doorWatchSeconds = DOOR_WATCH_SECONDS_DEFAULT,
    doorDeltaThreshold = DOOR_DELTA_THRESHOLD_DEFAULT,
    zoneOverrides = {},   -- [tostring(zoneId)] = true (interior) | false (exterior)
    hudShown = false,     -- debug HUD visibility; persisted but deliberately
                           -- NOT exposed in the settings menu - toggle via
                           -- /lid debug hud on|off only, per explicit request
    traceEnabled = false, -- /lid debug trace on|off (1.2.0); same persistence
                           -- and no-settings-menu treatment as hudShown
}

-- Character-specific saved variables: last known position/state, used
-- only for the logout/login persistence check.
local CHARACTER_DEFAULTS = {
    lastPosition = nil,      -- { zoneId = n, x = n, y = n, z = n }
    lastIsInterior = nil,    -- boolean
    lastZoneTemporary = nil, -- 1.3.1: was the logout zone a temporary one?
    returnPoint = nil,       -- 1.3.1: { zoneId, x, y, z, isInterior } - see RETURN POINTS
    -- 1.3.4 diagnostics (never read by any restore logic): what the last
    -- OnPlayerDeactivated call saw, written before anything that can bail
    -- out. See "SAVE DIAGNOSTICS" in the header.
    lastDeactivate = nil,    -- { timestamp, rawZoneRead, activationRawZoneId, state, saved }
    -- 1.3.6 diagnostics: when the saved record was last updated live (see
    -- LIVE SAVES in the header) and by what. Never read by restore logic.
    lastLiveUpdateTime = nil,   -- GetTimeStamp() seconds
    lastLiveUpdateSource = nil, -- the SetIsInterior source string, or "activation"
}

-------------------------------------------------------------------------------
-- ZONE_INTERIOR - keyed by real zoneId (see methodology note above).
-- true = interior/enclosed by default, false = exterior/open-air by default.
-- Per-zone overrides (settings menu) take precedence over this table at
-- runtime - see lib.IsZoneInterior().
-------------------------------------------------------------------------------
local ZONE_INTERIOR = {
    [3] = false, -- Glenumbra | no-notes|prior:exterior:known-zone
    [11] = true, -- Vaults of Madness | no-notes|prior:interior:known-name
    [19] = false, -- Stormhaven | no-notes|prior:exterior:known-zone
    [20] = false, -- Rivenspire | no-notes|prior:exterior:known-zone
    [22] = true, -- Volenfell | notes:interior(underground,beneath,buried)
    [31] = true, -- Selene's Web | notes:inconclusive|prior:interior:known-name
    [38] = true, -- Blackheart Haven | notes:interior(interior,cave,dungeon)
    [41] = false, -- Stonefalls | no-notes|prior:exterior:known-zone
    [57] = false, -- Deshaan | no-notes|prior:exterior:known-zone
    [58] = false, -- Malabal Tor | no-notes|prior:exterior:known-zone
    [63] = true, -- Darkshade Caverns I | no-notes|prior:interior:known-name
    [64] = true, -- Blessed Crucible | no-notes|prior:interior:known-name
    [92] = false, -- Bangkorai | no-notes|prior:exterior:known-zone
    [101] = false, -- Eastmarch | no-notes|prior:exterior:known-zone
    [103] = false, -- The Rift | no-notes|prior:exterior:known-zone
    [104] = false, -- Alik'r Desert | no-notes|prior:exterior:known-zone
    [108] = false, -- Greenshade | no-notes|prior:exterior:known-zone
    [117] = false, -- Shadowfen | no-notes|prior:exterior:known-zone
    [124] = false, -- Root Sunder Ruins | no-notes|prior:exterior:known-name
    [126] = true, -- Elden Hollow I | no-notes|prior:interior:known-name
    [130] = true, -- Crypt of Hearts I | no-notes|prior:interior:known-name
    [131] = false, -- Tempest Island | notes:exterior(island,coast,storm-lashed)
    [134] = true, -- Sanguine's Demesne | no-notes|prior:interior:known-name
    [137] = false, -- Rulanyil's Fall | no-notes|prior:exterior:known-name
    [138] = false, -- Crimson Cove | notes:exterior(coast,cove)
    [142] = false, -- Bonesnap Ruins | notes:exterior(village)
    [144] = true, -- Spindleclutch I | no-notes|prior:interior:known-name
    [146] = true, -- Wayrest Sewers I | no-notes|prior:interior:known-name
    [148] = true, -- Arx Corinium | no-notes|prior:interior:known-name
    [159] = false, -- Emeric's Dream | notes:inconclusive|prior:exterior:known-name
    [162] = true, -- Obsidian Scar | notes:interior(interior,cave,dungeon)
    [166] = true, -- Cath Bedraud | notes:interior(crypt)
    [168] = false, -- Bisnensel | notes:inconclusive|prior:exterior:known-name
    [169] = true, -- Razak's Wheel | notes:interior(interior)
    [176] = true, -- City of Ash I | no-notes|prior:interior:known-name
    [181] = false, -- Cyrodiil | no-notes|prior:exterior:known-zone
    [187] = false, -- Loriasel | notes:exterior(marsh,fen)
    [188] = true, -- The Apothecarium | notes:interior(interior,workshop)
    [189] = true, -- Tribunal Temple | notes:interior(enclosed)
    [190] = true, -- Reservoir of Souls | notes:interior(underground,sealed,spirit reservoir)
    [191] = false, -- Ash Mountain | no-notes|prior:exterior:keyword:mountain
    [192] = false, -- Virak Keep | verified:web:outdoor-fort-courtyard
    [193] = false, -- Tormented Spire | verified:web:outdoor-volcano-path
    [199] = true, -- The Harborage | no-notes|prior:interior:known-name
    [200] = true, -- The Foundry of Woe | no-notes|prior:interior:known-name
    [201] = true, -- Castle of the Worm | verified:web:indoor-daedric-stronghold-solo-instance
    [203] = true, -- Cheesemonger's Hollow | no-notes|prior:interior:keyword:hollow
    [207] = true, -- Mzeneldt | notes:interior(sealed,interior)
    [208] = true, -- The Earth Forge | no-notes|prior:interior:keyword:forge
    [209] = true, -- Halls of Submission | verified:web:indoor-daedric-ruin-corridors-solo-instance
    [212] = true, -- Mournhold Sewers | notes:interior(underground,beneath,sewer)
    [213] = false, -- Sunscale Ruins | notes:exterior(marsh,fen)
    [214] = true, -- Lair of the Skin Stealer | notes:interior(underground,sealed)
    [215] = false, -- Vision of the Hist | notes:inconclusive|prior:exterior:known-name
    [216] = false, -- Crow's Wood | notes:exterior(woodland)
    [217] = true, -- The Halls of Torment | verified:web:indoor-prison-stronghold-solo-instance
    [218] = true, -- Circus of Cheerful Slaughter | notes:inconclusive|prior:interior:known-name
    [219] = false, -- Chateau of the Ravenous Rodent | notes:exterior(isle)
    [222] = false, -- Dresan Keep | verified:web:outdoor-fort-courtyard
    [223] = true, -- Tomb of Lost Kings | notes:interior(sealed,interior,crypt)
    [224] = true, -- Breagha-Fin | notes:interior(cave)
    [227] = true, -- Sunken Road | notes:interior(underground)
    [228] = false, -- Bangkorai Garrison | no-notes|prior:exterior:known-name
    [229] = false, -- Nilata Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [231] = true, -- Hall of Heroes | notes:interior(underground,sealed,crypt)
    [232] = false, -- Silyanorn Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [233] = false, -- Ruins of Ten-Maur-Wolk | notes:exterior(fen)
    [234] = true, -- Odious Chapel | notes:interior(sealed,interior)
    [235] = false, -- Temple of Sul | verified:web:outdoor-overland-temple-quest-hub
    [236] = true, -- White Rose Prison Dungeon | notes:interior(subterranean,dungeon,prison)
    [237] = true, -- Impervious Vault | notes:interior(sealed,vault)
    [238] = false, -- Salas En | notes:inconclusive|prior:exterior:known-name
    [239] = true, -- Kulati Mines | notes:interior(underground,mine shaft)
    [241] = true, -- House Indoril Crypt | notes:interior(sealed,interior,crypt)
    [242] = true, -- Fort Arand Dungeons | notes:interior(underground,beneath,dungeon)
    [243] = false, -- Coral Heart Chamber | notes:exterior(coast,coastal)
    [245] = true, -- Heimlyn Keep Reliquary | notes:interior(sealed,vault,chamber)
    [246] = true, -- Iliath Temple Mines | notes:interior(underground,beneath,sealed)
    [247] = true, -- House Dres Crypts | notes:interior(sealed,crypt,chamber)
    [248] = true, -- Mzithumz | notes:interior(sealed)
    [249] = true, -- Tal'Deic Crypts | notes:interior(underground,sealed,crypt)
    [250] = false, -- Narsis Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [252] = true, -- The Hollow Cave | notes:interior(underground,interior,cave)
    [253] = true, -- Shad Astula Underhalls | notes:interior(underground,beneath,sealed)
    [254] = true, -- Deepcrag Den | notes:interior(underground,sealed,cave)
    [255] = true, -- Bthanual | notes:interior(sealed)
    [256] = true, -- Crosswych Mine | notes:interior(underground)
    [257] = true, -- Vaults of Vernim | notes:interior(underground,vault)
    [258] = false, -- Arcwind Point | notes:inconclusive|prior:exterior:known-name
    [259] = false, -- Trolhetta | notes:exterior(mountain)
    [260] = true, -- Lost Knife Cave | notes:interior(interior)
    [261] = true, -- Bonestrewn Barrow | notes:interior(underground,crypt)
    [262] = true, -- Wittestadr Crypts | notes:interior(beneath,sealed,crypt)
    [263] = false, -- Mistwatch Crevasse | notes:inconclusive|prior:exterior:known-name
    [264] = false, -- Fort Morvunskar | verified:web:outdoor-fort-courtyard
    [265] = true, -- Mzulft | no-notes|prior:interior:known-name
    [266] = false, -- Cragwallow | verified:web:outdoor-overland-poi
    [267] = false, -- Eyevea | notes:exterior(island)
    [268] = false, -- Stormwarden Undercroft | notes:exterior(coast,coastal)
    [269] = false, -- Abamath Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [270] = false, -- Shrine of the Black Maw | notes:exterior(marsh,fen)
    [271] = false, -- Broken Tusk | notes:exterior(marsh,fen)
    [272] = true, -- Atanaz Ruins | notes:interior(interior)
    [273] = false, -- Chid-Moska Ruins | notes:exterior(marsh,fen)
    [274] = false, -- Onkobra Kwama Mine | notes:exterior(marsh,fen)
    [275] = true, -- Gandranen Ruins | verified:web:indoor-delve
    [280] = false, -- Bleakrock Isle | no-notes|prior:exterior:known-zone
    [281] = false, -- Bal Foyen | no-notes|prior:exterior:known-zone
    [283] = true, -- Fungal Grotto I | no-notes|prior:interior:known-name
    [284] = true, -- Bad Man's Hallows | notes:interior(underground,cave)
    [287] = true, -- Inner Sea Armature | notes:interior(interior)
    [288] = true, -- Mephala's Nest | notes:interior(interior)
    [289] = true, -- Softloam Cavern | notes:interior(cave)
    [290] = true, -- Hightide Hollow | notes:interior(cave)
    [291] = false, -- Sheogorath's Tongue | notes:exterior(isle)
    [296] = true, -- Emberflint Mine | no-notes|prior:interior:keyword:mine
    [306] = true, -- Forgotten Crypts | notes:interior(underground,sealed,crypt)
    [308] = true, -- Lost City of the Na-Totambu | notes:interior(beneath,buried,subterranean)
    [309] = true, -- Ilessan Tower | verified:web:indoor-delve
    [310] = false, -- Silumm | notes:inconclusive|prior:exterior:known-name
    [311] = true, -- Mines of Khuras | notes:interior(underground,mine tunnels)
    [312] = true, -- Enduum | notes:interior(sealed,interior)
    [313] = true, -- Ebon Crypt | notes:interior(underground,sealed,tomb)
    [314] = true, -- Cryptwatch Fort | notes:interior(underground,sealed,crypt)
    [315] = true, -- Portdun Watch | verified:web:indoor-delve
    [316] = true, -- Koeglin Mine | notes:interior(underground,beneath)
    [317] = true, -- Pariah Catacombs | notes:interior(sealed,crypt,tomb)
    [318] = true, -- Farangel's Delve | notes:interior(underground,cave)
    [319] = true, -- Bearclaw Mine | notes:interior(interior)
    [320] = true, -- Norvulk Ruins | verified:web:indoor-delve
    [321] = true, -- Crestshade Mine | notes:interior(underground,subterranean)
    [322] = true, -- Flyleaf Catacombs | notes:interior(sealed,tomb)
    [323] = true, -- Tribulation Crypt | notes:interior(tomb)
    [324] = true, -- Orc's Finger Ruins | verified:web:indoor-delve
    [325] = true, -- Erokii Ruins | verified:web:indoor-delve
    [326] = true, -- Hildune's Secret Refuge | notes:interior(sealed,cave)
    [327] = false, -- Santaki | no-notes|prior:exterior:known-name
    [328] = true, -- Divad's Chagrin Mine | no-notes|prior:interior:keyword:mine
    [329] = false, -- Aldunz | no-notes|prior:exterior:known-name
    [330] = true, -- Coldrock Diggings | notes:interior(underground,mine tunnels)
    [331] = true, -- Sandblown Mine | no-notes|prior:interior:keyword:mine
    [332] = false, -- Yldzuun | no-notes|prior:exterior:known-name
    [333] = true, -- Torog's Spite | verified:web:indoor-delve
    [334] = false, -- Troll's Toothpick | notes:exterior(mountain)
    [335] = false, -- Viridian Watch | notes:exterior(outpost)
    [336] = true, -- Crypt of the Exiles | notes:interior(underground,tomb)
    [337] = true, -- Klathzgar | notes:interior(sealed,interior)
    [338] = false, -- Rubble Butte | notes:exterior(cove)
    [339] = true, -- Hall of the Dead | notes:interior(interior)
    [341] = false, -- The Lion's Den | notes:exterior(valley)
    [346] = false, -- Skuldafn | verified:web:outdoor-overland-ruin-quest-hub
    [347] = false, -- Coldharbour | no-notes|prior:exterior:known-zone
    [353] = true, -- Hall of Trials | notes:interior(interior,chamber)
    [354] = true, -- Cradlecrush Arena | notes:inconclusive|prior:interior:known-name
    [359] = true, -- The Chill Hollow | no-notes|prior:interior:keyword:hollow
    [360] = true, -- Icehammer's Vault | no-notes|prior:interior:keyword:vault
    [361] = true, -- Old Sord's Cave | notes:interior(underground,cave)
    [362] = true, -- The Frigid Grotto | no-notes|prior:interior:keyword:grotto
    [363] = true, -- Stormcrag Crypt | no-notes|prior:interior:keyword:crypt
    [364] = true, -- The Bastard's Tomb | notes:interior(underground,sealed,tomb)
    [365] = false, -- Library of Dusk | notes:exterior(fen)
    [366] = true, -- Lightless Oubliette | notes:interior(underground,sealed,oubliette)
    [367] = true, -- Lightless Cell | notes:interior(underground,sealed,prison)
    [368] = true, -- The Black Forge | no-notes|prior:interior:keyword:forge
    [369] = true, -- The Vile Laboratory | no-notes|prior:interior:keyword:laboratory
    [370] = true, -- Reaver Citadel Pyramid | verified:web:indoor-daedric-pyramid-interior
    [371] = true, -- The Mooring | verified:web:indoor-daedric-ruin-mechanism-room
    [372] = false, -- Manor of Revelry | verified:web:outdoor-overland-daedric-ruin-grounds
    [374] = true, -- The Endless Stair | verified:web:indoor-daedric-labyrinth-citadel
    [375] = true, -- Chapel of Light | notes:inconclusive|prior:interior:known-name
    [376] = false, -- Grunda's Gatehouse | verified:web:unresolved-defaulted-outdoor-gatehouse
    [377] = false, -- Dra'bul | notes:inconclusive|prior:exterior:known-name
    [378] = false, -- Shrine of Mauloch | notes:inconclusive|prior:exterior:known-name
    [379] = true, -- Silvenar's Audience Hall | notes:inconclusive|prior:interior:known-name
    [380] = true, -- The Banished Cells I | notes:interior(sealed,prison)
    [381] = false, -- Auridon | no-notes|prior:exterior:known-zone
    [382] = false, -- Reaper's March | no-notes|prior:exterior:known-zone
    [383] = false, -- Grahtwood | no-notes|prior:exterior:known-zone
    [385] = true, -- Ragnthar | notes:interior(sealed,interior)
    [386] = true, -- Fort Virak Ruin | verified:web:indoor-ruin-tunnels-beneath-fort
    [387] = false, -- Tower of the Vale | notes:exterior(forest)
    [388] = true, -- Phaer Catacombs | notes:interior(underground,beneath,sealed)
    [389] = true, -- Reliquary Ruins | notes:interior(sealed,interior,vault)
    [390] = true, -- The Veiled Keep | notes:interior(sealed,interior)
    [392] = true, -- The Vault of Exile | notes:interior(underground,sealed,vault)
    [393] = true, -- Saltspray Cave | notes:interior(cave)
    [394] = true, -- Ezduiin Undercroft | notes:interior(underground,sealed)
    [395] = false, -- The Refuge of Dread | verified:web:outdoor-deadlands-pocket-plane
    [396] = false, -- Ondil | no-notes|prior:exterior:known-name
    [397] = true, -- Del's Claim | notes:interior(underground)
    [398] = false, -- Entila's Folly | no-notes|prior:exterior:known-name
    [399] = false, -- Wansalen | no-notes|prior:exterior:known-name
    [400] = true, -- Mehrunes' Spite | verified:web:indoor-delve
    [401] = false, -- Bewan | notes:exterior(coast,sea)
    [402] = true, -- Shor's Stone Mine | no-notes|prior:interior:keyword:mine
    [403] = true, -- Northwind Mine | no-notes|prior:interior:keyword:mine
    [404] = true, -- Fallowstone Vault | no-notes|prior:interior:keyword:vault
    [405] = true, -- Lady Llarel's Shelter | notes:interior(interior)
    [406] = true, -- Lower Bthanual | notes:interior(sealed)
    [407] = true, -- The Triple Circle Mine | notes:interior(sealed,interior)
    [408] = true, -- Taleon's Crag | notes:interior(underground,sealed,cave)
    [409] = true, -- Knife Ear Grotto | no-notes|prior:interior:keyword:grotto
    [410] = true, -- The Corpse Garden | notes:interior(sealed,interior,crypt)
    [411] = false, -- The Hunting Grounds | verified:web:outdoor-oblivion-wilderness-realm
    [412] = true, -- Nimalten Barrow | notes:interior(underground,beneath,sealed)
    [413] = true, -- Avanchnzel | verified:web:indoor-delve
    [414] = true, -- Pinepeak Caverns | no-notes|prior:interior:keyword:caverns
    [415] = true, -- Trolhetta Cave | notes:interior(beneath,interior,cave)
    [416] = true, -- Inner Tanzelwil | notes:interior(sealed,interior,chamber)
    [417] = true, -- Aba-Loria | notes:interior(crypt)
    [418] = true, -- The Vault of Haman Forgefire | no-notes|prior:interior:keyword:vault
    [419] = true, -- The Grotto of Depravity | notes:interior(cave)
    [420] = true, -- Cave of Trophies | notes:interior(underground,sealed,cave)
    [421] = true, -- Mal Sorra's Tomb | notes:interior(sealed,tomb,chamber)
    [422] = true, -- The Wailing Maw | notes:interior(cave)
    [424] = false, -- Camlorn Keep | verified:web:outdoor-fort-courtyard
    [425] = false, -- Daggerfall Castle | verified:web:outdoor-fort-courtyard
    [426] = true, -- Angof's Sanctum | notes:interior(underground,subterranean,sealed)
    [429] = true, -- Glenumbra Moors Cave | notes:interior(cave)
    [430] = true, -- Aphren's Tomb | notes:interior(sealed,interior)
    [431] = true, -- Taarengrav Barrow | notes:interior(sealed)
    [433] = true, -- Nairume's Prison | notes:interior(underground,sealed,prison)
    [434] = true, -- The Orrery | notes:interior(chamber)
    [435] = false, -- Cathedral of the Golden Path | notes:inconclusive|prior:exterior:keyword:path
    [436] = true, -- Reliquary Vault | notes:interior(sealed,vault)
    [437] = false, -- Laeloria Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [438] = true, -- Cave of Broken Sails | notes:interior(cave)
    [439] = true, -- Ossuary of Telacar | notes:inconclusive|prior:interior:keyword:ossuary
    [440] = true, -- The Aquifer | notes:interior(underground)
    [442] = true, -- Ne Salas | verified:web:indoor-delve
    [444] = true, -- Burroot Kwama Mine | notes:inconclusive|prior:interior:keyword:mine
    [447] = true, -- Mobar Mine | notes:interior(underground)
    [449] = true, -- Direfrost Keep | verified:web:indoor-group-dungeon
    [451] = false, -- Senalana | verified:web:outdoor-overland-ruin-quest-hub
    [452] = true, -- Temple to the Divines | notes:interior(interior)
    [453] = true, -- Halls of Ichor | notes:interior(underground)
    [454] = true, -- Do'Krin Temple | verified:web:indoor-temple-building
    [455] = true, -- Rawl'kha Temple | verified:web:indoor-temple-building
    [456] = false, -- Five Finger Dance | verified:web:outdoor-oblivion-pocket-realm
    [457] = true, -- Moonmont Temple | verified:web:indoor-temple-building
    [458] = false, -- Fort Sphinxmoth | notes:exterior(dune)
    [459] = false, -- Thizzrini Arena | notes:exterior(camp)
    [460] = false, -- The Demiplane of Jode | verified:web:outdoor-pocket-realm-visions
    [461] = true, -- Den of Lorkhaj | notes:interior(catacomb)
    [462] = true, -- Thibaut's Cairn | notes:interior(sealed,interior,crypt)
    [463] = true, -- Kuna's Delve | notes:interior(sealed,interior,cave)
    [464] = true, -- Fardir's Folly | notes:interior(underground)
    [465] = true, -- Claw's Strike | verified:web:indoor-delve
    [466] = true, -- Weeping Wind Cave | notes:interior(interior,cave)
    [467] = true, -- Jode's Light | verified:web:indoor-delve
    [468] = true, -- Dead Man's Drop | notes:interior(underground,cave)
    [469] = true, -- Tomb of Apostates | notes:interior(cave)
    [470] = true, -- Hoarvor Pit | no-notes|prior:interior:keyword:pit
    [471] = true, -- Shael Ruins | verified:web:indoor-delve
    [472] = true, -- Roots of Silvenar | notes:interior(beneath)
    [473] = false, -- Black Vine Ruins | notes:exterior(jungle)
    [475] = true, -- The Scuttle Pit | no-notes|prior:interior:keyword:pit
    [477] = true, -- Vinedeath Cave | notes:interior(cave)
    [478] = true, -- Wormroot Depths | notes:interior(underground,dungeon)
    [480] = true, -- Snapleg Cave | no-notes|prior:interior:keyword:cave
    [481] = true, -- Fort Greenwall | verified:web:indoor-delve
    [482] = true, -- Shroud Hearth Barrow | notes:interior(underground,sealed,tomb)
    [484] = true, -- Faldar's Tooth | verified:web:indoor-delve
    [485] = true, -- Broken Helm Hollow | notes:interior(underground,cave)
    [486] = true, -- Toothmaul Gully | verified:web:indoor-public-dungeon-cave
    [487] = true, -- The Vile Manse | verified:web:indoor-public-dungeon-cave
    [492] = false, -- Tormented Spire Summit | verified:web:outdoor-volcano-summit
    [493] = true, -- Breakneck Cave | notes:interior(underground,sealed,cave)
    [494] = true, -- Capstone Cave | notes:interior(underground,cave)
    [495] = true, -- Cracked Wood Cave | notes:interior(underground,cave)
    [496] = true, -- Echo Cave | notes:interior(underground,cave)
    [497] = true, -- Haynote Cave | notes:interior(cave)
    [498] = true, -- Kingscrest Cavern | notes:interior(interior,cave)
    [499] = false, -- Lipsand Tarn | verified:web:outdoor-overland-ruin-quest-hub
    [500] = true, -- Muck Valley Cavern | notes:interior(cave)
    [501] = true, -- Newt Cave | notes:interior(cave)
    [502] = true, -- Nisin Cave | notes:interior(cave)
    [503] = true, -- Pothole Caverns | notes:interior(underground,cave,cavern)
    [504] = true, -- Quickwater Cave | notes:interior(underground,cave)
    [505] = true, -- Red Ruby Cave | notes:interior(underground,cave)
    [506] = true, -- Serpent Hollow Cave | notes:interior(enclosed,interior,cave)
    [507] = true, -- Bloodmayne Cave | notes:interior(cave)
    [508] = false, -- Foyada Quarry | notes:exterior(ravine)
    [509] = true, -- Ald Carac | notes:interior(interior)
    [510] = false, -- Ularra | verified:web:outdoor-overland-ruin-quest-hub
    [511] = true, -- Arcane University | verified:web:indoor-battleground-ruined-buildings
    [512] = true, -- Deeping Drome | notes:interior(underground,sealed)
    [513] = true, -- Mor Khazgur | notes:interior(forge)
    [514] = false, -- Istirus Outpost | notes:inconclusive|prior:exterior:keyword:outpost
    [515] = false, -- Istirus Outpost Arena | notes:exterior(outpost)
    [516] = true, -- Ald Carac | notes:interior(interior)
    [517] = false, -- Eld Angavar | verified:web:outdoor-void-ayleid-platform-battleground
    [518] = false, -- Eld Angavar | verified:web:outdoor-void-ayleid-platform-battleground
    [520] = false, -- Reman's Folly | verified:web:outdoor-overland-ruin-quest-hub
    [525] = true, -- Cheesemonger's Hollow | no-notes|prior:interior:keyword:hollow
    [526] = true, -- Greenhill Catacombs | notes:interior(underground,sealed,catacomb)
    [527] = true, -- Sancre Tor | verified:web:indoor-dungeon-chambers
    [529] = true, -- Eyevea Mages Guild | notes:interior(interior)
    [530] = true, -- Haj Uxith Corridors | notes:interior(underground)
    [531] = true, -- Toadstool Hollow | notes:interior(cave,cavern,chamber)
    [532] = true, -- Vahtacen | notes:interior(underground,sealed,chamber)
    [533] = true, -- Underpall Cave | notes:interior(underground,cave)
    [534] = false, -- Stros M'Kai | no-notes|prior:exterior:known-zone
    [535] = false, -- Betnikh | no-notes|prior:exterior:known-zone
    [537] = false, -- Khenarthi's Roost | no-notes|prior:exterior:known-zone
    [539] = false, -- Carzog's Demise | notes:exterior(island,cove)
    [541] = false, -- Glade of the Divines | notes:exterior(forest)
    [542] = false, -- Buraniim | notes:exterior(isle,coast)
    [543] = true, -- Dourstone Vault | notes:interior(sealed,vault)
    [544] = false, -- Stonefang Cavern | notes:exterior(island)
    [545] = false, -- Alcaire Keep | notes:exterior(coast,coastal)
    [546] = true, -- Wayrest Castle | verified:web:indoor-castle-building
    [547] = true, -- Shrouded Hollow | notes:interior(cave,cavern)
    [548] = false, -- Silatar | notes:exterior(island,coast)
    [549] = true, -- The Middens | notes:interior(cave)
    [551] = true, -- Imperial Underground | verified:web:indoor-sewer
    [552] = false, -- Shademist Enclave | notes:exterior(island,coast)
    [553] = false, -- Ilmyris | verified:web:outdoor-overland-ruin-quest-hub
    [554] = true, -- Serpent's Grotto | notes:interior(cave)
    [555] = false, -- Abecean Sea | notes:exterior(sea)
    [556] = true, -- Nereid Temple Cave | notes:interior(cave)
    [557] = false, -- Village of the Lost | notes:exterior(village)
    [558] = true, -- Hectahame Grotto | notes:inconclusive|prior:interior:keyword:grotto
    [559] = true, -- Valenheart | verified:web:indoor-ayleid-inner-sanctum-chamber
    [560] = true, -- Nimalten Barrow | notes:interior(underground,beneath,sealed)
    [561] = false, -- Isles of Torment | no-notes|prior:exterior:keyword:isles
    [562] = false, -- Khaj Rawlith | verified:user:outdoor
    [565] = true, -- Ren-dro Caverns | notes:interior(cave,cavern)
    [566] = true, -- Heart of the Wyrd Tree | verified:web:indoor-tree-inner-sanctum
    [567] = false, -- The Hunting Grounds | verified:web:outdoor-oblivion-wilderness-realm
    [569] = false, -- Ash'abah Pass | notes:exterior(mountain)
    [570] = true, -- Tu'whacca's Sanctum | notes:interior(interior)
    [571] = true, -- Suturah's Crypt | notes:interior(underground,sealed,crypt)
    [572] = false, -- Stirk | notes:exterior(island,sea)
    [573] = true, -- The Worm's Retreat | notes:interior(underground)
    [574] = false, -- The Valley of Blades | notes:exterior(valley,mountain)
    [575] = true, -- Carac Dena | verified:web:indoor-delve
    [576] = true, -- Gurzag's Mine | notes:interior(subterranean)
    [577] = true, -- The Underroot | notes:interior(cave)
    [578] = true, -- Naril Nagaia | verified:web:indoor-delve
    [579] = true, -- Harridan's Lair | notes:interior(interior,cave)
    [580] = true, -- Barrow Trench | verified:web:indoor-delve
    [581] = true, -- Heart's Grief | verified:web:indoor-daedric-palace-halls
    [582] = true, -- Temple of Auri-El | verified:web:indoor-temple-domed-chamber
    [584] = false, -- Imperial City | no-notes|prior:exterior:known-zone
    [585] = true, -- Nchu Duabthar Threshold | notes:interior(sealed,interior)
    [586] = true, -- The Wailing Prison | no-notes|prior:interior:keyword:prison
    [587] = true, -- Fevered Mews | notes:interior(interior,cave)
    [588] = true, -- Doomcrag | verified:web:indoor-ayleid-tower-tiers
    [589] = false, -- Northpoint | verified:web:outdoor-overland-port-city
    [590] = true, -- Edrald Undercroft | notes:interior(beneath,sealed,cellar)
    [591] = false, -- Lorkrata Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [592] = true, -- Shadowfate Cavern | notes:interior(cave,cavern)
    [593] = false, -- Bangkorai Garrison | no-notes|prior:exterior:known-name
    [594] = false, -- The Far Shores | verified:web:outdoor-aetherius-realm
    [595] = true, -- Abagarlas | notes:interior(beneath,interior)
    [596] = true, -- Blood Matron's Crypt | notes:interior(underground,sealed,crypt)
    [598] = false, -- The Colored Rooms | verified:web:outdoor-void-realm-floating-stones
    [599] = false, -- Elden Root | verified:web:outdoor-overland-tree-city
    [600] = true, -- Mournhold | notes:interior(enclosed)
    [601] = false, -- Wayrest | verified:web:outdoor-overland-capital-city
    [628] = true, -- Doomcrag | verified:web:indoor-ayleid-tower-tiers
    [632] = false, -- Skyreach Hold | verified:web:outdoor-overland-ruin-quest-hub
    [635] = true, -- Dragonstar Arena | verified:web:indoor-instanced-arena
    [636] = true, -- Hel Ra Citadel | verified:web:indoor-trial-dungeon
    [637] = true, -- Quarantine Serk Catacombs | notes:interior(beneath,sealed,catacomb)
    [638] = true, -- Aetherian Archive | verified:web:indoor-trial-dungeon
    [639] = true, -- Sanctum Ophidia | no-notes|prior:interior:keyword:sanctum
    [640] = false, -- Godrun's Dream | verified:web:outdoor-quagmire-nightmare-realm
    [641] = true, -- Themond Mine | notes:interior(underground,sealed)
    [642] = true, -- The Earth Forge | no-notes|prior:interior:keyword:forge
    [643] = true, -- Imperial Sewers | no-notes|prior:interior:keyword:sewers
    [649] = true, -- The Dragonfire Cathedral | verified:web:indoor-subterranean-vault
    [676] = false, -- Shark's Teeth Grotto | notes:exterior(coast,sea)
    [677] = true, -- Maelstrom Arena | verified:web:indoor-instanced-arena
    [678] = true, -- Imperial City Prison | no-notes|prior:interior:keyword:prison
    [681] = true, -- City of Ash II | no-notes|prior:interior:known-name
    [684] = false, -- Wrothgar | no-notes|prior:exterior:known-zone
    [688] = true, -- White-Gold Tower | verified:web:indoor-tower-dungeon
    [689] = true, -- Nikolvara's Kennel | notes:interior(cave)
    [691] = true, -- Thukhozod's Sanctum | notes:interior(sealed,interior)
    [692] = true, -- Watcher's Hold | verified:web:indoor-delve
    [693] = true, -- Coldperch Cavern | no-notes|prior:interior:keyword:cavern
    [694] = true, -- Argent Mine | notes:interior(subterranean)
    [695] = true, -- Coldwind's Den | no-notes|prior:interior:keyword:den
    [697] = true, -- Zthenganaz | notes:interior(buried,chamber)
    [698] = true, -- Morkul Descent | notes:interior(cave)
    [699] = true, -- Honor's Rest | verified:web:indoor-crypt
    [700] = true, -- Exile's Barrow | notes:interior(underground,crypt)
    [701] = true, -- Graystone Quarry Depths | notes:interior(underground,enclosed)
    [702] = false, -- Frostbreak Fortress | verified:web:outdoor-fort-courtyard
    [703] = true, -- Paragon's Remembrance | verified:web:indoor-fortress-chambers-halls
    [704] = true, -- Bonerock Cavern | notes:interior(subterranean,cave)
    [705] = true, -- Rkindaleft | verified:web:indoor-public-dungeon
    [706] = true, -- Old Orsinium | verified:web:indoor-public-dungeon
    [707] = true, -- Ice-Heart's Lair | no-notes|prior:interior:keyword:lair
    [708] = true, -- Temple Library | notes:interior(interior)
    [710] = true, -- Fharun Prison | notes:interior(underground,prison)
    [711] = true, -- Temple Rectory | notes:interior(interior)
    [712] = true, -- Chambers of Loyalty | notes:interior(underground,sealed,interior)
    [715] = true, -- Sanctum of Prowess | notes:interior(interior)
    [719] = true, -- Time-Lost Throne Room | verified:web:indoor-throne-room
    [723] = true, -- Heart's Grief | verified:web:indoor-daedric-palace-halls
    [724] = false, -- Sorrow | notes:exterior(isle)
    [725] = true, -- Maw of Lorkhaj | notes:interior(underground)
    [726] = false, -- Murkmire | no-notes|prior:exterior:known-zone
    [745] = false, -- Charred Ridge | verified:web:outdoor-overworld-ridge
    [746] = true, -- Vulkhel Guard Outlaws Refuge | notes:interior(underground,beneath)
    [747] = true, -- Elden Root Outlaws Refuge | notes:interior(underground,beneath,enclosed)
    [748] = true, -- Marbruk Outlaws Refuge | notes:interior(underground,beneath)
    [749] = true, -- Velyn Harbor Outlaws Refuge | notes:interior(underground,beneath)
    [750] = true, -- Rawl'kha Outlaws Refuge | notes:interior(underground,beneath)
    [751] = true, -- Belkarth Outlaws Refuge | notes:interior(underground,beneath)
    [752] = true, -- Wayrest Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [753] = true, -- Daggerfall Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [754] = true, -- Evermore Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [755] = true, -- Shornhelm Outlaws Refuge | notes:interior(underground,beneath)
    [756] = true, -- Sentinel Outlaws Refuge | notes:interior(underground,beneath,chamber)
    [757] = true, -- Davon's Watch Outlaws Refuge | notes:interior(underground,beneath,enclosed)
    [758] = true, -- Windhelm Outlaws Refuge | notes:interior(underground,beneath)
    [759] = true, -- Stormhold Outlaws Refuge | notes:interior(underground,beneath)
    [760] = true, -- Mournhold Outlaws Refuge | notes:interior(underground,beneath)
    [761] = true, -- Riften Outlaws Refuge | notes:interior(underground,beneath)
    [763] = true, -- Secluded Sewers | no-notes|prior:interior:keyword:sewers
    [764] = true, -- Underground Sepulcher | verified:web:indoor-tomb
    [765] = true, -- Smuggler's Den | notes:interior(cave,cellar)
    [766] = false, -- Trader's Cove | notes:exterior(coast,coastal,cove)
    [767] = true, -- Deadhollow Halls | notes:interior(underground,sealed,tomb)
    [769] = true, -- Sewer Tenement | no-notes|prior:interior:keyword:sewer
    [770] = true, -- The Hideaway | verified:web:indoor-cave-subterranean-hideout
    [771] = true, -- Glittering Grotto | notes:interior(underground,cave)
    [773] = true, -- Cold-Blood Cavern | notes:interior(cave)
    [774] = true, -- Sugar-Slinger's Den | notes:interior(underground)
    [780] = true, -- Orsinium Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [808] = true, -- Dragon Bridge Smuggler Caves | notes:interior(beneath,cave)
    [809] = true, -- The Wailing Prison | no-notes|prior:interior:keyword:prison
    [810] = true, -- Smuggler's Tunnel | notes:interior(underground,beneath)
    [811] = false, -- Ancient Carzog's Demise | notes:exterior(coast,fen)
    [814] = true, -- Temple of Ire | verified:web:indoor-temple-building
    [815] = true, -- Scarp Keep | verified:web:indoor-palace-chambers
    [816] = false, -- Hew's Bane | no-notes|prior:exterior:known-zone
    [817] = true, -- Bahraha's Gloom | verified:web:indoor-delve
    [818] = true, -- Iron Wheel Headquarters | verified:web:indoor-underground-chambers
    [819] = true, -- Al-Danobia Tomb | notes:interior(interior,tomb)
    [820] = true, -- Hubalajad Palace | verified:web:indoor-palace-solo-instance
    [821] = true, -- Thieves Den | notes:interior(underground,interior)
    [823] = false, -- Gold Coast | no-notes|prior:exterior:known-zone
    [824] = true, -- Hrota Cave | no-notes|prior:interior:keyword:cave
    [825] = true, -- Garlas Agea | verified:web:indoor-delve
    [826] = true, -- Dark Brotherhood Sanctuary | notes:interior(underground,sealed)
    [827] = false, -- Jarol Estate | verified:web:outdoor-overland-estate-courtyard
    [828] = false, -- At-Himah Estate | notes:exterior(coast)
    [829] = false, -- Knightsgrave | notes:exterior(coast)
    [831] = false, -- Anvil Castle | notes:exterior(coast)
    [832] = false, -- Castle Kvatch | notes:exterior(coast)
    [833] = true, -- Enclave of the Hourglass | notes:interior(sealed)
    [834] = false, -- Fulstrom Homestead | verified:web:outdoor-overland-manor-grounds
    [836] = true, -- Cathedral of Akatosh | notes:interior(catacomb)
    [837] = true, -- Anvil Outlaws Refuge | notes:interior(underground,beneath)
    [841] = false, -- Jerall Mountains Logging Track | notes:exterior(mountain)
    [842] = false, -- Blackwood Borderlands | verified:web:outdoor-overland-transitional-zone
    [843] = true, -- Ruins of Mazzatun | verified:web:indoor-group-dungeon
    [844] = false, -- Sulima Mansion | notes:exterior(coast)
    [845] = true, -- Velmont Mansion | notes:interior(interior)
    [848] = true, -- Cradle of Shadows | verified:web:indoor-group-dungeon
    [849] = false, -- Vvardenfell | no-notes|prior:exterior:known-zone
    [852] = true, -- Captain Margaux's Place | verified:user:indoor-player-house
    [853] = false, -- Ravenhurst | verified:user:outdoor-player-house
    [854] = false, -- Mournoth Keep | verified:user:outdoor-player-house
    [855] = false, -- Hammerdeath Bungalow | verified:user:outdoor-player-house
    [856] = false, -- Twin Arches | verified:user:outdoor-player-house
    [857] = true, -- House of the Silent Magnifico | notes:interior(interior)
    [858] = false, -- Cliffshade | verified:user:outdoor-player-house
    [859] = false, -- Black Vine Villa | verified:user:outdoor-player-house
    [860] = true, -- Snugpod | verified:user:indoor-player-house
    [861] = false, -- Bouldertree Refuge | verified:user:outdoor-player-house
    [862] = false, -- Sleek Creek House | verified:user:outdoor-player-house
    [863] = true, -- Moonmirth House | verified:user:indoor-player-house
    [864] = false, -- Autumn's-Gate | verified:user:outdoor-player-house
    [865] = true, -- Grymharth's Woe | notes:interior(cave,dungeon)
    [866] = false, -- Velothi Reverie | verified:web:unresolved-defaulted-outdoor
    [867] = false, -- Kragenhome | notes:exterior(marsh,fen)
    [868] = false, -- Humblemud | notes:exterior(marsh,fen,village)
    [869] = true, -- The Ample Domicile | notes:interior(interior)
    [870] = false, -- Domus Phrasticus | notes:exterior(marsh)
    [871] = false, -- Cyrodilic Jungle House | verified:user:outdoor-player-house
    [872] = false, -- Strident Springs Demesne | verified:user:outdoor-player-house
    [873] = false, -- Stay-Moist Mansion | verified:user:outdoor-player-house
    [874] = false, -- Quondam Indorilia | verified:user:outdoor-player-house
    [875] = false, -- Old Mistveil Manor | verified:user:outdoor-player-house
    [876] = false, -- Dawnshadow | verified:user:outdoor-player-house
    [877] = false, -- The Gorinir Estate | verified:user:outdoor-player-house
    [878] = false, -- Mathiisen Manor | verified:user:outdoor-player-house
    [879] = false, -- Hunding's Palatial Hall | verified:user:outdoor-player-house
    [880] = false, -- Forsaken Stronghold | verified:user:outdoor-player-house
    [881] = true, -- Gardner House | notes:interior(interior)
    [882] = false, -- Grand Topal Hideaway | verified:user:outdoor-player-house
    [883] = true, -- Earthtear Cavern | notes:interior(cave)
    [888] = false, -- Craglorn | no-notes|prior:exterior:known-zone
    [889] = true, -- Molavar | verified:web:indoor-delve
    [890] = true, -- Rkundzelft | notes:interior(sealed)
    [891] = true, -- Serpent's Nest | notes:interior(cave)
    [892] = true, -- Ilthag's Undertower | notes:interior(underground)
    [893] = true, -- Ruins of Kardala | verified:web:indoor-delve
    [894] = true, -- Loth'Na Caverns | notes:interior(enclosed,interior,cave)
    [895] = true, -- Rkhardahrk | notes:interior(sealed,interior)
    [896] = true, -- Haddock's Market | verified:web:indoor-delve
    [897] = true, -- Chiselshriek Mine | notes:interior(underground)
    [898] = true, -- Buried Sands | notes:interior(beneath,buried,subterranean)
    [899] = true, -- Mtharnaz | notes:interior(sealed,interior)
    [900] = true, -- The Howling Sepulchers | verified:web:indoor-delve
    [901] = true, -- Balamath | verified:web:indoor-delve
    [902] = true, -- Fearfangs Cavern | notes:interior(cave)
    [903] = true, -- Exarch's Stronghold | notes:interior(sealed)
    [904] = true, -- Zalgaz's Den | notes:interior(interior,cave)
    [905] = true, -- Tombs of the Na-Totambu | notes:interior(sealed,interior,tomb)
    [906] = true, -- Hircine's Haunt | notes:interior(interior,cave)
    [907] = true, -- Rahni'Za, School of Warriors | notes:interior(enclosed,interior)
    [908] = true, -- Shada's Tear | notes:interior(underground,interior)
    [909] = true, -- Seeker's Archive | verified:web:indoor-archive-regulated-climate
    [910] = true, -- Elinhir Sewerworks | notes:interior(underground,beneath,sewer)
    [911] = true, -- Reinhold's Retreat | notes:interior(interior)
    [913] = true, -- The Mage's Staff | notes:interior(interior)
    [914] = true, -- Skyreach Catacombs | notes:interior(sealed,crypt,catacomb)
    [915] = true, -- Skyreach Temple | notes:interior(sealed,enclosed,interior)
    [916] = false, -- Skyreach Pinnacle | verified:web:outdoor-exposed-summit
    [918] = true, -- Nchuleftingth | verified:web:indoor-public-dungeon
    [919] = false, -- Forgotten Wastes | no-notes|prior:exterior:keyword:wastes
    [920] = true, -- Inanius Egg Mine | no-notes|prior:interior:keyword:mine
    [921] = true, -- Khartag Point | notes:interior(cave)
    [922] = true, -- Zainsipilu | verified:web:indoor-delve
    [923] = true, -- Matus-Akin Egg Mine | no-notes|prior:interior:keyword:mine
    [924] = true, -- Pulk | verified:web:indoor-delve
    [925] = true, -- Nchuleft | verified:web:indoor-delve
    [926] = true, -- Pinsun | notes:interior(underground,cave)
    [927] = true, -- Vassir-Didanat Mine | no-notes|prior:interior:keyword:mine
    [928] = true, -- Zalkin-Sul Egg Mine | no-notes|prior:interior:keyword:mine
    [929] = true, -- Gnisis Egg Mine | no-notes|prior:interior:keyword:mine
    [930] = true, -- Darkshade Caverns II | no-notes|prior:interior:known-name
    [931] = true, -- Elden Hollow II | no-notes|prior:interior:known-name
    [932] = true, -- Crypt of Hearts II | no-notes|prior:interior:known-name
    [933] = true, -- Wayrest Sewers II | no-notes|prior:interior:known-name
    [934] = true, -- Fungal Grotto II | no-notes|prior:interior:known-name
    [935] = true, -- The Banished Cells II | notes:interior(sealed,prison)
    [936] = true, -- Spindleclutch II | no-notes|prior:interior:known-name
    [937] = false, -- Flaming Nix Deluxe Garret | verified:user:outdoor-player-house
    [938] = true, -- Sisters of the Sands Apartment | notes:interior(interior)
    [939] = true, -- Barbed Hook Private Room | notes:interior(interior)
    [940] = true, -- Mara's Kiss Public House | notes:interior(interior)
    [941] = false, -- The Ebony Flask Inn Room | verified:user:outdoor-player-house
    [942] = true, -- The Rosy Lion | notes:interior(interior)
    [943] = false, -- Daggerfall Overlook | verified:user:outdoor-player-house
    [944] = false, -- Serenity Falls Estate | verified:user:outdoor-player-house
    [945] = false, -- Ebonheart Chateau | verified:user:outdoor-player-house
    [946] = true, -- Bal Ur | verified:web:indoor-daedric-shrine-interior
    [947] = true, -- Ramimilk | verified:web:indoor-daedric-shrine-interior
    [948] = true, -- Tusenend | verified:web:indoor-vvardenfell-ruin-pattern
    [949] = true, -- Dreudurai Glass Mine | no-notes|prior:interior:keyword:mine
    [950] = true, -- Zaintiraris | verified:web:indoor-daedric-ruin-interior
    [951] = true, -- Vassamsi Mine | no-notes|prior:interior:keyword:mine
    [952] = true, -- Shulk Ore Mine | no-notes|prior:interior:keyword:mine
    [953] = true, -- Arkngthunch-Sturdumz | verified:web:indoor-dwemer-ruin
    [954] = true, -- Galom Daeus | verified:web:indoor-dwemer-ruin
    [955] = true, -- Mallapi Cave | no-notes|prior:interior:keyword:cave
    [956] = true, -- Kaushtarari | verified:web:indoor-vvardenfell-ruin-pattern
    [957] = true, -- Dreloth Ancestral Tomb | notes:interior(underground,sealed,tomb)
    [958] = true, -- Veloth Ancestral Tomb | notes:interior(tomb)
    [959] = true, -- Andrano Ancestral Tomb | notes:interior(underground,sealed,interior)
    [960] = true, -- Hleran Ancestral Tomb | notes:interior(underground,sealed,tomb)
    [961] = true, -- Ashalmawia | verified:web:indoor-delve
    [962] = true, -- Library of Andule | verified:web:indoor-crypt
    [963] = true, -- Barilzar's Tower | verified:web:indoor-tower-four-rooms
    [964] = true, -- Ashimanu Cave | no-notes|prior:interior:keyword:cave
    [965] = true, -- Skar | notes:interior(hollowed)
    [966] = true, -- Cavern of the Incarnate | no-notes|prior:interior:keyword:cavern
    [967] = true, -- Clockwork City Vault | notes:interior(beneath,vault)
    [968] = false, -- Firemoth Island | no-notes|prior:exterior:keyword:island
    [969] = true, -- Ashurnibibi | verified:web:indoor-vvardenfell-ruin-pattern
    [970] = false, -- Redoran Garrison | notes:exterior(garrison)
    [971] = true, -- Vivec City Outlaws Refuge | notes:interior(underground,beneath)
    [972] = true, -- Kudanat Mine | notes:inconclusive|prior:interior:keyword:mine
    [973] = true, -- Bloodroot Forge | no-notes|prior:interior:keyword:forge
    [974] = false, -- Falkreath Hold | notes:exterior(cove,forest)
    [975] = true, -- Halls of Fabrication | verified:web:indoor-trial-dungeon
    [977] = true, -- Prison of Xykenaz | notes:interior(prison)
    [979] = true, -- Clockwork City Vault | notes:interior(beneath,vault)
    [980] = false, -- Clockwork City | no-notes|prior:exterior:known-zone
    [981] = false, -- The Brass Fortress | verified:web:outdoor-city-day-night-cycle
    [982] = true, -- Slag Town Outlaws Refuge | notes:interior(forge)
    [983] = true, -- Mechanical Fundament | verified:web:indoor-underground-tunnels
    [984] = false, -- Machine District | no-notes|prior:exterior:keyword:district
    [985] = true, -- Halls of Regulation | verified:web:indoor-delve
    [986] = true, -- The Shadow Cleft | verified:web:indoor-delve
    [988] = true, -- Clockwork City Vaults | notes:interior(vault)
    [989] = true, -- Ventral Terminus | verified:web:indoor-trial-subzone
    [990] = true, -- Incarnatorium | notes:interior(chamber)
    [991] = true, -- Cogitum Centralis | verified:web:indoor-trial-subzone
    [992] = false, -- Everwound Wellspring | verified:web:outdoor-farming-facility
    [993] = true, -- Mnemonic Planisphere | notes:interior(interior)
    [994] = false, -- Saint Delyn Penthouse | verified:user:outdoor-player-house
    [995] = false, -- Amaya Lake Lodge | notes:exterior(lakeside)
    [996] = true, -- Tel Galen | notes:interior(interior)
    [997] = false, -- Ald Velothi Harbor House | notes:exterior(coast,coastal)
    [998] = false, -- Dranil Kir | verified:web:outdoor-quest-specific-island
    [999] = false, -- Evergloam | verified:web:outdoor-oblivion-realm-mountain-forest
    [1000] = true, -- Asylum Sanctorium | no-notes|prior:interior:keyword:asylum
    [1004] = true, -- The Serviflume | verified:user:indoor
    [1005] = true, -- Linchal Grand Manor | notes:interior(interior)
    [1006] = false, -- Exorcised Coven Cottage | verified:web:outdoor-player-house
    [1007] = false, -- Hakkvild's High Hall | verified:web:outdoor-player-house
    [1008] = false, -- Coldharbour Surreal Estate | verified:web:outdoor-player-house
    [1009] = false, -- Fang Lair | notes:exterior(mountain)
    [1010] = false, -- Scalecaller Peak | no-notes|prior:exterior:keyword:peak
    [1011] = false, -- Summerset | no-notes|prior:exterior:known-zone
    [1012] = true, -- The Spiral Skein | verified:web:indoor-cavern-realm
    [1013] = true, -- Eldbur Sanctuary | notes:interior(underground,beneath,sealed)
    [1014] = true, -- Tor-Hame-Khard | verified:web:indoor-delve
    [1015] = true, -- Eton Nir Grotto | no-notes|prior:interior:keyword:grotto
    [1016] = true, -- Traitor's Vault | no-notes|prior:interior:keyword:vault
    [1017] = false, -- Archon's Grove | no-notes|prior:exterior:keyword:grove
    [1018] = true, -- King's Haven Pass | verified:web:indoor-delve
    [1019] = true, -- Wasten Coraldale | verified:web:indoor-delve
    [1020] = false, -- Karnwasten | no-notes|prior:exterior:known-zone
    [1021] = false, -- Sunhold | notes:exterior(isle,coast,coastal)
    [1022] = false, -- Direnni Acropolis | verified:web:outdoor-overland-settlement-ruin
    [1023] = true, -- Shimmerene Waterworks | notes:interior(underground,beneath)
    [1024] = false, -- Eldbur Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [1025] = false, -- Cey-Tarn Keep | verified:web:outdoor-fort-courtyard
    [1026] = true, -- The Vaults of Heinarwe | no-notes|prior:interior:keyword:vaults
    [1027] = false, -- Artaeum | notes:exterior(isle)
    [1028] = true, -- Alinor Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [1029] = true, -- Ebon Sanctum | notes:interior(underground,sealed)
    [1030] = false, -- Corgrad Wastes | no-notes|prior:exterior:keyword:wastes
    [1031] = true, -- Illumination Academy Stacks | verified:web:indoor-library
    [1032] = false, -- Sea Keep | verified:web:outdoor-fortress
    [1033] = true, -- Red Temple Catacombs | notes:interior(underground,beneath,sealed)
    [1034] = false, -- College of Sapiarchs | verified:web:outdoor-overland-institution
    [1035] = true, -- The Spiral Skein | verified:web:indoor-cavern-realm
    [1036] = false, -- Cathedral of Webs | verified:web:outdoor-overland-ruin-striking-locale
    [1037] = true, -- The Crystal Tower | verified:web:indoor-tower-dungeon
    [1038] = true, -- Rellenthil Sinkhole | verified:web:indoor-grotto-network
    [1039] = true, -- Psijic Relic Vaults | notes:interior(sealed,vault)
    [1040] = false, -- Evergloam | verified:web:outdoor-oblivion-realm-mountain-forest
    [1042] = false, -- Pariah's Pinnacle | notes:exterior(peak)
    [1043] = false, -- The Orbservatory Prior | verified:web:outdoor-player-house
    [1044] = true, -- The Erstwhile Sanctuary | notes:interior(underground)
    [1045] = false, -- Princely Dawnlight Palace | notes:exterior(docks)
    [1046] = true, -- Saltbreeze Cave | notes:interior(cave)
    [1047] = true, -- Monastery of Serene Harmony | verified:web:indoor-monastery-building
    [1048] = true, -- Alinor Royal Palace | verified:web:indoor-palace-throne-room
    [1051] = false, -- Cloudrest | no-notes|prior:exterior:known-zone
    [1052] = true, -- Moon Hunter Keep | notes:interior(sealed,interior)
    [1055] = false, -- March of Sacrifices | no-notes|prior:exterior:keyword:march
    [1059] = true, -- Golden Gryphon Garret | verified:user:indoor-garret
    [1060] = false, -- Alinor Crest Townhouse | notes:exterior(town,district)
    [1061] = true, -- Colossal Aldmeri Grotto | notes:interior(cave,cavern)
    [1063] = false, -- Grand Psijic Villa | verified:web:outdoor-player-house
    [1064] = true, -- Hunter's Glade | notes:interior(beneath)
    [1065] = true, -- Blight Bog Sump | notes:interior(cave,prison)
    [1066] = true, -- Tsofeer Cavern | notes:interior(cave)
    [1067] = true, -- The Dreaming Nest | notes:inconclusive|prior:interior:keyword:nest
    [1068] = true, -- Ixtaxh Xanmeer | verified:web:indoor-xanmeer-dungeon
    [1069] = true, -- Tomb of Many Spears | notes:interior(cave)
    [1070] = true, -- Lilmoth Outlaws Refuge | notes:interior(underground,beneath)
    [1071] = true, -- Xul-Thuxis | verified:web:indoor-xanmeer-temple-dungeon
    [1072] = true, -- Norg-Tzel | verified:web:indoor-murkmire-xanmeer-pattern
    [1073] = true, -- Teeth of Sithis | verified:web:indoor-delve
    [1074] = true, -- The Sunless Hollow | notes:interior(underground)
    [1075] = true, -- The Sunless Hollow | notes:interior(underground)
    [1076] = true, -- The Sunless Hollow | notes:interior(underground)
    [1077] = true, -- The Swallowed Grove | notes:interior(subterranean,cave,prison)
    [1078] = true, -- Remnant of Argon | verified:web:indoor-ayleid-realm-refuge
    [1079] = true, -- Vakka-Bok Xanmeer | verified:web:indoor-xanmeer-dungeon
    [1080] = true, -- Frostvault | verified:web:indoor-group-dungeon
    [1081] = true, -- Depths of Malatar | notes:interior(interior)
    [1082] = true, -- Blackrose Prison | notes:interior(prison)
    [1083] = true, -- Deep-Root | verified:web:indoor-cavern
    [1085] = true, -- Halls of Colossus | notes:interior(underground,subterranean,sealed)
    [1086] = false, -- Northern Elsweyr | no-notes|prior:exterior:known-zone
    [1088] = true, -- Rimmen Outlaws Refuge | notes:interior(underground,beneath,chamber)
    [1089] = true, -- Rimmen Necropolis | notes:interior(underground,sealed,crypt)
    [1090] = false, -- Orcrest | verified:web:outdoor-ruined-city
    [1091] = true, -- Abode of Ignominy | notes:interior(interior,cave)
    [1092] = true, -- Predator Mesa | notes:interior(interior,cave)
    [1094] = true, -- Tomb of the Serpents | notes:interior(sealed,crypt)
    [1095] = true, -- Darkpool Mine | notes:interior(interior,cave)
    [1096] = true, -- The Tangle | notes:interior(cave)
    [1097] = true, -- Sleepy Senche Mine | notes:inconclusive|prior:interior:keyword:mine
    [1098] = false, -- Riverhold | verified:web:outdoor-city
    [1099] = true, -- Rimmen Palace | verified:web:indoor-palace
    [1101] = true, -- Rimmen Palace Recesses | notes:interior(interior)
    [1102] = true, -- Sepulcher of Mischance | notes:interior(underground,sealed)
    [1103] = false, -- Moon Gate of Anequina | verified:web:outdoor-desert-gate
    [1105] = false, -- Skooma Cat's Cloister | verified:user:outdoor
    [1106] = false, -- Star Haven Adeptorium | verified:web:outdoor-settlement-complex
    [1108] = false, -- Lakemire Xanmeer Manor | verified:web:outdoor-player-house
    [1109] = true, -- Enchanted Snow Globe Home | notes:interior(enclosed,interior)
    [1110] = true, -- Dov-Vahl Shrine | verified:user:indoor
    [1111] = true, -- Cicatrice Caverns | notes:interior(underground,interior,cave)
    [1112] = true, -- Tenarr Zalviit Ossuary | notes:interior(sealed,crypt)
    [1113] = true, -- Hidden Moon Crypts | notes:interior(underground,sealed,interior)
    [1114] = true, -- Hakoshae Tombs | notes:interior(interior,tomb)
    [1115] = true, -- Merryvale Sugar Farm Caves | notes:interior(beneath,cave)
    [1116] = false, -- Moon Gate | verified:web:outdoor-desert-gate
    [1117] = true, -- Shadow Dance Temple | notes:interior(sealed,interior)
    [1118] = true, -- Vault of the Heavenly Scourge | notes:interior(sealed,vault)
    [1119] = true, -- Desert Wind Caverns | notes:interior(interior,cave)
    [1120] = false, -- Meirvale Keep | verified:web:outdoor-fort-courtyard
    [1121] = true, -- Sunspire | verified:web:indoor-trial-dungeon
    [1122] = true, -- Moongrave Fane | verified:web:indoor-group-dungeon
    [1123] = true, -- Lair of Maarselok | no-notes|prior:interior:keyword:lair
    [1125] = false, -- Frostvault Chasm | verified:web:outdoor-chasm-approach
    [1126] = true, -- Elinhir Private Arena | notes:interior(enclosed)
    [1128] = true, -- Sugar Bowl Suite | verified:user:indoor
    [1129] = false, -- Hall of the Lunar Champion | verified:web:outdoor-player-house
    [1130] = false, -- Jode's Embrace | verified:web:outdoor-player-house
    [1133] = false, -- Southern Elsweyr | no-notes|prior:exterior:known-zone
    [1134] = true, -- Forsaken Citadel | verified:web:indoor-delve
    [1135] = false, -- Moonlit Cove | notes:exterior(coast,coastal,cove)
    [1136] = true, -- Zazaradi's Quarry and Mine | notes:interior(enclosed)
    [1137] = false, -- Path of Pride | notes:inconclusive|prior:exterior:keyword:path
    [1138] = false, -- Dragonhold | verified:web:outdoor-flying-island-mainquest
    [1139] = true, -- Senchal Outlaws Refuge | notes:interior(underground,beneath,chamber)
    [1140] = true, -- Wind Scour Temple | notes:interior(beneath,sealed,interior)
    [1141] = false, -- Dark Water Temple | notes:exterior(fen)
    [1142] = false, -- The Valley of Blades | notes:exterior(valley,mountain)
    [1143] = true, -- Storm Talon Temple | verified:user:indoor
    [1144] = false, -- Vahlokzin's Lair | notes:exterior(coast)
    [1145] = true, -- Passage of Dad'na Ghaten | notes:interior(underground)
    [1146] = false, -- Tideholm | notes:exterior(island,coast)
    [1147] = true, -- New Moon Fortress | notes:interior(sealed,interior)
    [1148] = true, -- Halls of the Highmane | notes:interior(underground,sealed)
    [1149] = false, -- Doomstone Keep | verified:web:outdoor-overland-ruin-keep
    [1150] = true, -- Doomstone Caverns | notes:interior(underground,sealed,cave)
    [1151] = false, -- Dragonhold Ruins | verified:web:outdoor-overland-ruin
    [1152] = true, -- Icereach | verified:web:indoor-group-dungeon
    [1153] = true, -- Unhallowed Grave | verified:web:indoor-group-dungeon
    [1154] = false, -- Moon-Sugar Meadow | verified:user:outdoor-player-house
    [1155] = true, -- Wraithhome | notes:interior(crypt)
    [1160] = false, -- Western Skyrim | no-notes|prior:exterior:known-zone
    [1161] = true, -- Blackreach: Greymoor Caverns | no-notes|prior:interior:keyword:caverns
    [1165] = true, -- The Scraps | verified:web:indoor-delve
    [1166] = true, -- Chillwind Depths | no-notes|prior:interior:keyword:depths
    [1167] = true, -- Dragonhome | verified:web:indoor-delve
    [1168] = false, -- Frozen Coast | no-notes|prior:exterior:keyword:coast
    [1169] = true, -- Midnight Barrow | verified:web:indoor-delve
    [1170] = true, -- Shadowgreen | verified:web:indoor-delve
    [1172] = true, -- Greymoor Keep | verified:web:indoor-underground-fortress-blackreach
    [1173] = true, -- Greymoor Keep: West Wing | verified:web:indoor-fortress-wing
    [1174] = true, -- Verglas Hollow | notes:interior(interior,chamber)
    [1176] = true, -- Kilkreath Temple | notes:interior(interior)
    [1177] = true, -- Bleakridge Barrow | verified:web:indoor-barrow
    [1178] = true, -- Solitude Outlaws Refuge | notes:interior(beneath,catacomb,chamber)
    [1179] = true, -- Mor Khazgur Mine | notes:interior(subterranean)
    [1180] = true, -- Imperial Cache Annex | notes:interior(sealed,vault)
    [1181] = true, -- Kagnthamz | verified:web:indoor-dwemer-ruin-blackreach
    [1182] = true, -- Morthal Barrow | notes:interior(sealed)
    [1183] = true, -- Tzinghalis's Tower | notes:interior(interior)
    [1184] = true, -- Castle Dour | notes:interior(interior)
    [1185] = true, -- Deepwood Vale | notes:interior(beneath)
    [1186] = false, -- Labyrinthian | verified:user:outdoor-half-exterior
    [1187] = true, -- Nchuthnkarst | verified:web:indoor-dwemer-ruin-pattern
    [1188] = true, -- Palace of Kings | notes:interior(interior)
    [1189] = true, -- Palace of Kings | notes:interior(interior)
    [1190] = true, -- Riften Ratway | notes:interior(sewer)
    [1191] = true, -- Blackreach | verified:web:indoor-underground-cavern-zone
    [1192] = false, -- Lucky Cat Landing | verified:user:outdoor-player-house
    [1193] = false, -- Potentate's Retreat | verified:web:outdoor-player-house
    [1195] = true, -- The Undergrove | notes:interior(beneath,cave)
    [1196] = false, -- Kyne's Aegis | verified:user:outdoor
    [1197] = false, -- Stone Garden | no-notes|prior:exterior:keyword:garden
    [1199] = false, -- Forgemaster Falls | verified:web:outdoor-player-house
    [1200] = true, -- Thieves' Oasis | notes:interior(interior)
    [1201] = false, -- Castle Thorn | verified:user:outdoor-half-exterior
    [1205] = false, -- Grayhome | verified:user:outdoor-player-house
    [1206] = true, -- Grayhome Ritual Chamber | notes:interior(sealed,chamber)
    [1207] = false, -- The Reach | no-notes|prior:exterior:known-zone
    [1208] = true, -- Blackreach: Arkthzand Cavern | no-notes|prior:interior:keyword:cavern
    [1209] = true, -- Gloomreach | verified:web:indoor-delve
    [1210] = true, -- Briar Rock Ruins | verified:web:indoor-delve
    [1211] = true, -- Markarth Outlaws Refuge | verified:web:indoor-outlaws-refuge
    [1212] = true, -- Arkthzand Research Wing | verified:web:indoor-underground-cavern-zone
    [1213] = true, -- Sanuarach Mine | no-notes|prior:interior:keyword:mine
    [1214] = true, -- Bthar-Zel | verified:web:indoor-dwemer-ruin-blackreach
    [1215] = true, -- Bthar-Zel Vaults | no-notes|prior:interior:keyword:vaults
    [1216] = true, -- The Dark Descent | verified:web:indoor-underground-descent
    [1217] = true, -- The Arkthzand Orrery | verified:web:indoor-underground-cavern-zone
    [1218] = true, -- Snowmelt Suite | notes:interior(interior)
    [1219] = false, -- Proudspire Manor | verified:web:outdoor-player-house
    [1220] = true, -- Bastion Sanguinaris | notes:interior(underground,beneath,cave)
    [1221] = false, -- Grayhaven | verified:web:outdoor-overland-settlement
    [1222] = true, -- Valthume | verified:user:indoor
    [1223] = false, -- Lost Valley Redoubt | no-notes|prior:exterior:keyword:valley
    [1224] = true, -- Nighthollow Keep | notes:interior(underground,cave,cavern)
    [1225] = true, -- Nchuand-Zel | verified:web:indoor-dwemer-ruin
    [1226] = true, -- Reachwind Depths | no-notes|prior:interior:keyword:depths
    [1227] = true, -- Vateshran Hollows | notes:interior(chamber)
    [1228] = false, -- Black Drake Villa | notes:exterior(coast)
    [1229] = true, -- The Cauldron | verified:web:indoor-group-dungeon
    [1233] = false, -- Antiquarian's Alpine Gallery | verified:web:outdoor-player-house
    [1234] = false, -- Stillwaters Retreat | notes:exterior(coast)
    [1235] = true, -- Ne Salas Cache Annex | notes:interior(underground,sealed)
    [1236] = true, -- Imperial Sewers | no-notes|prior:interior:keyword:sewers
    [1237] = true, -- The Deadlands: Testing Grounds | verified:web:indoor-testing-arena
    [1238] = true, -- Tidewater Cave | no-notes|prior:interior:keyword:cave
    [1239] = true, -- Welke | verified:user:indoor
    [1240] = false, -- Leyawiin Castle | notes:exterior(marsh)
    [1241] = true,  -- Doomvault Capraxus | 1.3.2: interior per author (has exterior sub-sections; treated as interior anyway)
    [1242] = true, -- Vandacia's Deadlands Keep | verified:web:indoor-daedric-fortress-dungeon
    [1243] = false, -- Fort Redmane | notes:exterior(marsh,fen)
    [1244] = false, -- Isle of Balfiera | notes:exterior(isle)
    [1245] = false, -- Borderwatch Ruins | verified:web:outdoor-fort-battlements
    [1246] = true, -- Deepscorn Hollow | notes:interior(cave)
    [1247] = false, -- Veyond | verified:web:outdoor-overland-ruin
    [1248] = true,  -- Doomvault Vulpinaz | 1.3.2: interior per author (has exterior sub-sections; treated as interior anyway)
    [1249] = false, -- Twyllbek Ruins | verified:web:outdoor-overland-ruin-quest-hub
    [1250] = true, -- Glenbridge Xanmeer | verified:web:indoor-xanmeer-dungeon
    [1251] = true, -- Xynaa's Sanctuary | notes:interior(sealed,interior)
    [1252] = true, -- Leyawiin Outlaws Refuge | notes:interior(underground,beneath)
    [1253] = true, -- Undertow Cavern | notes:interior(cave)
    [1254] = true, -- Arpenia | verified:web:indoor-delve
    [1255] = true, -- Bloodrun Cave | notes:interior(cave)
    [1256] = true,  -- Doomvault Porcixid | 1.3.2: interior per author (has exterior sub-sections; treated as interior anyway)
    [1257] = false, -- Xi-Tsei | verified:user:outdoor
    [1258] = false, -- Vunalk | verified:user:outdoor
    [1259] = false, -- Zenithar's Abbey | verified:user:outdoor
    [1260] = true, -- The Silent Halls | notes:interior(dungeon)
    [1261] = false, -- Blackwood | no-notes|prior:exterior:known-zone
    [1262] = true, -- Festival Arena | notes:interior(enclosed,interior)
    [1263] = false, -- Rockgrove | verified:user:outdoor
    [1264] = false, -- Stone Eagle Aerie | notes:exterior(cliff)
    [1265] = false, -- Shalidor's Shrouded Realm | verified:web:outdoor-player-house
    [1266] = false, -- Xal Irasotl | notes:exterior(marsh)
    [1267] = true, -- Red Petal Bastion | notes:interior(dungeon)
    [1268] = true, -- The Dread Cellar | notes:interior(underground,sealed,cellar)
    [1270] = false, -- Kushalit Sanctuary | verified:web:outdoor-player-house
    [1271] = false, -- Varlaisvea Ayleid Ruins | verified:web:outdoor-player-house
    [1272] = false, -- Atoll of Immolation | notes:exterior(atoll)
    [1274] = false, -- Garden of Shadows | notes:exterior(garden)
    [1275] = false, -- Pilgrim's Rest | verified:web:outdoor-player-house
    [1276] = true, -- Water's Edge | verified:user:indoor-starts-interior
    [1277] = true, -- Pantherfang Chapel | notes:interior(cave)
    [1278] = true, -- Lyranth's Hidden Lair | notes:inconclusive|prior:interior:keyword:lair
    [1279] = false, -- Waking Flame Camp | no-notes|prior:exterior:keyword:camp
    [1280] = true, -- Waking Flame Fargrave Conclave | verified:web:indoor-cave-base
    [1281] = true, -- Waking Flame Fargrave Conclave | verified:web:indoor-cave-base
    [1282] = false, -- Fargrave | verified:web:outdoor-overland-trading-city
    [1283] = false, -- The Shambles | notes:exterior(district)
    [1284] = true, -- The Collector's Villa | notes:interior(interior)
    [1285] = false, -- Burning Gyre Keep | verified:web:outdoor-deadlands-pattern
    [1286] = false, -- The Deadlands | verified:web:outdoor-chapter-zone
    [1287] = false, -- Wretched Spire | verified:web:outdoor-deadlands-settlement
    [1289] = true, -- Fort Grief Citadel | notes:interior(sealed,interior,chamber)
    [1290] = false, -- Deadlight | notes:exterior(coast,coastal)
    [1291] = true, -- Ardent Hope | reconsidered:indoor-daedric-citadel-solo-instance
    [1292] = false, -- The Path of Cinders | no-notes|prior:exterior:keyword:path
    [1293] = true, -- Fargrave Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [1294] = false, -- Isle of Joys | notes:exterior(island)
    [1295] = true, -- Destruction's Solace | reconsidered:indoor-daedric-fortress-solo-instance
    [1296] = false, -- Fort Sundercliff | verified:web:outdoor-fort
    [1297] = false, -- The Brandfire Reformatory | verified:user:outdoor
    [1298] = true, -- False Martyrs' Folly | notes:interior(underground,sealed,dungeon)
    [1300] = true, -- Fort Grief | notes:interior(interior)
    [1301] = false, -- Coral Aerie | verified:user:outdoor
    [1302] = false, -- Shipwright's Regret | verified:user:outdoor
    [1304] = true, -- The Bathhouse | notes:interior(interior)
    [1306] = false, -- Doomchar Plateau | no-notes|prior:exterior:keyword:plateau
    [1307] = false, -- Sweetwater Cascades | verified:user:outdoor-player-house
    [1310] = false, -- Atoll of Immolation | notes:exterior(atoll)
    [1311] = true, -- Ascendant Order Hideout | notes:interior(underground,beneath,sealed)
    [1312] = true, -- Sareloth Grotto | notes:interior(cave)
    [1313] = true, -- Systres Sisters Vault | notes:interior(underground,sealed,vault)
    [1314] = false, -- Sword's Rest Isle | notes:exterior(island,coast,coastal)
    [1315] = true, -- Abhain Chapel Crypts | notes:interior(beneath,sealed,interior)
    [1316] = false, -- Old Coin Fort | notes:exterior(island)
    [1317] = false, -- All Flags Islet | notes:exterior(island,coast)
    [1318] = false, -- High Isle | no-notes|prior:exterior:known-zone
    [1319] = true, -- Gonfalon Bay Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [1320] = true, -- Tarnished Grotto | no-notes|prior:interior:keyword:grotto
    [1321] = true, -- Navire Dungeons | notes:interior(beneath,dungeon)
    [1322] = true, -- Mistmouth Cave | no-notes|prior:interior:keyword:cave
    [1324] = false, -- Steadfast Manor | verified:web:outdoor-player-house-presumed
    [1325] = true, -- Loom of the Untraveled Road | notes:interior(interior)
    [1326] = true, -- Castle Navire | verified:user:indoor
    [1327] = true, -- The Undergrove | notes:interior(beneath,cave)
    [1328] = true, -- Garick's Rest | verified:user:indoor
    [1329] = true, -- Castle Navire | verified:user:indoor
    [1330] = true, -- Brokerock Mine | notes:interior(prison)
    [1331] = true, -- Death's Valor Keep | notes:interior(interior)
    [1332] = true, -- The Firepot | verified:web:indoor-delve
    [1333] = true, -- Breakwater Cave | no-notes|prior:interior:keyword:cave
    [1334] = true, -- Whalefall | verified:web:indoor-delve
    [1335] = false, -- Shipwreck Shoals | notes:exterior(island,isle,coast)
    [1336] = true, -- Coral Cliffs | notes:interior(cave)
    [1337] = false, -- Spire of the Crimson Coin | notes:exterior(isle,archipelago)
    [1338] = true, -- Ghost Haven Bay | notes:interior(interior,cave)
    [1342] = false, -- Ossa Accentium | verified:web:outdoor-player-house
    [1343] = false, -- Agony's Ascent | verified:web:outdoor-player-house
    [1344] = false, -- Dreadsail Reef | verified:web:outdoor-reef-island
    [1345] = false, -- Seaveil Spire | notes:exterior(coast,atoll)
    [1360] = false, -- Earthen Root Enclave | verified:web:outdoor-druid-sanctuary-grove
    [1361] = false, -- Graven Deep | verified:user:outdoor-starts-exterior
    [1363] = false, -- Highhallow Hold | notes:exterior(isle)
    [1364] = true, -- Ancient Anchor Berth | notes:interior(interior)
    [1365] = true, -- Eimhir's Cavern | notes:interior(cave)
    [1366] = true, -- Glenmoril Ritual Site | notes:interior(interior,cave)
    [1367] = true, -- Vastyr Outlaws Refuge | notes:interior(underground,beneath,sealed)
    [1368] = false, -- Y'ffre's Path | notes:exterior(forest)
    [1369] = false, -- Dreadsail Sea Witch Sanctum | notes:exterior(archipelago,sea)
    [1370] = false, -- Castle Tonnere | notes:exterior(archipelago)
    [1371] = false, -- Vastyr Cathedral District | notes:exterior(island,isle,district)
    [1372] = false, -- Temple of Y'ffelon | notes:exterior(island,archipelago)
    [1373] = false, -- Mount Firesong | verified:web:outdoor-mountain
    [1374] = false, -- Fauns' Thicket | notes:exterior(forest)
    [1375] = true, -- Embervine | verified:web:indoor-cave-system-delve
    [1376] = true, -- Suncleft Grotto | notes:inconclusive|prior:interior:keyword:grotto
    [1377] = true, -- Clohaigh | notes:interior(cave)
    [1378] = true, -- Steadfast Manor Cellars | notes:interior(underground,cellar)
    [1379] = false, -- The Mad Maiden | notes:exterior(archipelago)
    [1380] = true, -- Garick's Rest Dungeons | notes:interior(underground,beneath,sealed)
    [1381] = false, -- Y'ffre's Path Ruins | notes:inconclusive|prior:exterior:keyword:path
    [1382] = true, -- All Flags Castle | verified:user:indoor
    [1383] = false, -- Galen | no-notes|prior:exterior:known-zone
    [1385] = false, -- Draoife Dell | notes:exterior(isle,archipelago)
    [1386] = false, -- Temple of Y'ffelon | notes:exterior(island,archipelago)
    [1387] = false, -- Ivyhame | notes:exterior(coast)
    [1389] = false, -- Bal Sunnar | verified:user:outdoor
    [1390] = true, -- Scrivener's Hall | verified:web:indoor-dungeon-library
    [1391] = true, -- Emerald Glyphic Vault | notes:interior(underground,sealed,vault)
    [1392] = true, -- Shrine of the Golden Eye | verified:user:indoor
    [1393] = true, -- The Tranquil Catalog | verified:web:indoor-archive-apocrypha-pattern
    [1394] = true, -- The Infinite Panopticon | verified:web:indoor-endless-labyrinth
    [1395] = true, -- The Infinite Panopticon | verified:web:indoor-endless-labyrinth
    [1396] = true, -- Anchre Egg Mine | no-notes|prior:interior:keyword:mine
    [1397] = false, -- Camonnaruhn | verified:user:outdoor
    [1398] = true, -- Quires Wind | verified:web:indoor-delve
    [1399] = true, -- The Disquiet Study | verified:web:indoor-delve
    [1400] = false, -- Fathoms Drift | verified:user:outdoor
    [1401] = true, -- Apogee of the Tormenting Eye | verified:web:indoor-delve
    [1402] = false, -- Necrom Necropolis | verified:web:outdoor-overland-necropolis-city
    [1403] = true, -- Tel Rendys | verified:web:indoor-tower-halls
    [1404] = true, -- Tel Baro Cavern | no-notes|prior:interior:keyword:cavern
    [1405] = true, -- Tel Huulen Assembly Hall | verified:web:indoor-assembly-hall
    [1406] = false, -- Shrine of Vaermina | verified:user:outdoor
    [1407] = true, -- Tel Dreloth | verified:web:indoor-telvanni-tower-pattern
    [1408] = true, -- Kemel-Ze | verified:user:indoor
    [1409] = true, -- The Sidereal Cloisters | verified:user:indoor
    [1410] = false, -- Cenotaph of the Remnants | verified:user:outdoor
    [1411] = true, -- The Rectory Corporea | notes:interior(interior)
    [1412] = true, -- Necrom Outlaws Refuge | notes:interior(underground,beneath)
    [1413] = false, -- Apocrypha | no-notes|prior:exterior:known-zone
    [1414] = false, -- Telvanni Peninsula | no-notes|prior:exterior:known-zone
    [1415] = false, -- Gorne | verified:user:outdoor
    [1416] = true, -- The Underweave | notes:interior(underground)
    [1417] = false, -- The Mythos | verified:user:outdoor
    [1420] = true, -- Bastion Nymic | verified:user:indoor
    [1421] = false, -- The Forbidden Exhibit | verified:user:outdoor
    [1422] = true, -- Sailenmora Crypts | no-notes|prior:interior:keyword:crypts
    [1423] = false, -- Old Sailenmora Outpost | notes:exterior(peninsula)
    [1424] = true, -- Obscured Forum | verified:user:indoor
    [1425] = true, -- Alavelis Glass Mine | no-notes|prior:interior:keyword:mine
    [1427] = false, -- Sanity's Edge | verified:user:outdoor
    [1429] = true, -- The Harborage | no-notes|prior:interior:known-name
    [1432] = false, -- Fogbreak Lighthouse | notes:exterior(island,isle,archipelago)
    [1433] = true, -- Journey's End Lodgings | notes:interior(interior)
    [1434] = true, -- Emissary's Enclave | notes:interior(interior)
    [1435] = false, -- The Fair Winds | notes:exterior(coast,coastal)
    [1436] = true, -- Infinite Archive | verified:user:indoor
    [1437] = false, -- Shadow Queen's Labyrinth | verified:web:outdoor-player-house
    [1438] = false, -- Sword-Singer's Redoubt | verified:web:outdoor-player-house
    [1439] = true, -- Shrine of Inevitable Secrets | verified:user:indoor
    [1440] = true, -- Miscarcand | verified:user:indoor
    [1441] = true, -- Loom of the Untraveled Road | notes:interior(interior)
    [1442] = false, -- Hoperoot | notes:exterior(grove)
    [1443] = false, -- West Weald | verified:web:outdoor-chapter-zone
    [1444] = true, -- Legion's Rest | notes:interior(sealed,interior,crypt)
    [1445] = true, -- Fyrelight Cave | no-notes|prior:interior:keyword:cave
    [1446] = true, -- Nonungalo | verified:user:indoor
    [1447] = false, -- Fort Colovia | verified:user:outdoor
    [1448] = false, -- Haldain Lumber Camp | notes:exterior(forest,camp)
    [1449] = false, -- Varen's Watch | verified:user:outdoor
    [1450] = true, -- Rustwall Catacombs | notes:interior(underground,catacomb)
    [1451] = true, -- Elenglynn | verified:user:indoor-ayleid-ten-ancestors
    [1452] = true, -- Essondul | verified:user:indoor-ayleid-ten-ancestors
    [1453] = true, -- Niryastare | verified:user:indoor-ayleid-ten-ancestors
    [1454] = false, -- Feldagard Keep | verified:user:outdoor
    [1455] = false, -- Ceyond | verified:user:outdoor
    [1456] = true, -- Sutch Mine | notes:interior(underground)
    [1457] = false, -- Scholarium Outer Ruins | verified:user:outdoor
    [1458] = false, -- The Mythos | verified:user:outdoor
    [1459] = true, -- Wendir | verified:user:indoor-ayleid-ten-ancestors
    [1460] = false, -- Valente Winery | notes:exterior(coast,vineyard)
    [1461] = true, -- Outcast Inn Cellar | notes:interior(beneath,cellar)
    [1462] = false, -- Weatherleah | verified:user:outdoor
    [1463] = true, -- The Scholarium | verified:web:indoor-library-building
    [1464] = false, -- Fargrave Outer Ruins | notes:exterior(district)
    [1465] = true, -- Skingrad Outlaws Refuge | notes:interior(underground,beneath)
    [1466] = true, -- Leftwheal Trading Post | notes:interior(dungeon)
    [1467] = true, -- Silorn | verified:user:indoor
    [1468] = false, -- Kelesan'ruhn | verified:user:outdoor
    [1470] = true, -- Oathsworn Pit | no-notes|prior:interior:keyword:pit
    [1471] = false, -- Bedlam Veil | verified:user:outdoor
    [1472] = true, -- Gladesong Arboretum | notes:interior(forge)
    [1473] = false, -- Tower of Unutterable Truths | verified:user:outdoor
    [1474] = false, -- The Mythos | verified:user:outdoor
    [1475] = false, -- Seat of Detritus | verified:user:outdoor
    [1478] = false, -- Lucent Citadel | verified:user:outdoor
    [1479] = false, -- Willowpond Haven | verified:user:outdoor
    [1481] = false, -- Mota-ka | notes:exterior(village)
    [1482] = false, -- Strid River Valley | no-notes|prior:exterior:keyword:valley
    [1483] = false, -- Huntsman's Fortress | notes:exterior(isle)
    [1484] = false, -- Shehai Waystation | verified:web:outdoor-battleground-ruins
    [1485] = false, -- Port Dufort | notes:exterior(archipelago,town)
    [1487] = false, -- Zhan Khaj Crest | verified:web:outdoor-player-house
    [1488] = true, -- Wing of the Crow | notes:interior(enclosed,interior)
    [1491] = false, -- Rosewine Retreat | notes:exterior(coast,vineyard)
    [1492] = false, -- Merryvine Estate | notes:exterior(coast,vineyard)
    [1494] = false, -- Seabloom Villa | notes:exterior(coast,coastal)
    [1495] = true, -- Haven of the Five Companions | notes:interior(interior)
    [1496] = false, -- Exiled Redoubt | notes:exterior(camp)
    [1497] = false, -- Lep Seclusa | verified:user:outdoor
    [1498] = false, -- Dusk Keep | notes:exterior(coast)
    [1499] = false, -- Star Haven Adeptorium | verified:web:outdoor-settlement-complex
    [1500] = false, -- Kthendral Deep Mines | notes:exterior(mountain)
    [1501] = true, -- Grand Gallery of Tamriel | notes:interior(interior)
    [1502] = false, -- Solstice | no-notes|prior:exterior:known-zone
    [1504] = true, -- Coldharbour Colosseum | notes:inconclusive|prior:interior:keyword:colosseum
    [1505] = true, -- Underground Sanctum | notes:interior(underground,subterranean,sealed)
    [1506] = true, -- Worm Cult Lair | notes:interior(underground,sealed,cave)
    [1507] = true, -- The Earth Forge | no-notes|prior:interior:keyword:forge
    [1508] = false, -- Stirk | notes:exterior(island,sea)
    [1509] = false, -- Vosgah Shrine | verified:web:outdoor-open-air-shrine
    [1510] = false, -- Sunport Palace District | notes:exterior(island,district)
    [1511] = false, -- Vale of Revelry | notes:inconclusive|prior:exterior:keyword:vale
    [1512] = true, -- Carapace Cavern | notes:interior(cave)
    [1513] = false, -- Tainted Leel | notes:exterior(isle)
    [1514] = true, -- Deetra Grotto | notes:interior(cave)
    [1515] = true, -- Sunport Outlaws Refuge | notes:interior(beneath,cave)
    [1516] = true, -- Corelanya Manor | verified:user:indoor
    [1517] = true, -- Li-Xal Pass | notes:interior(underground,subterranean)
    [1518] = true, -- Broken Light Temple | notes:interior(sealed,interior,chamber)
    [1520] = true, -- Tarnur Mine | notes:interior(underground)
    [1521] = false, -- The Colored Rooms | verified:web:outdoor-void-realm-floating-stones
    [1534] = false, -- Tide-Born Dream-Wallow | verified:user:outdoor
    [1535] = true, -- Shrine of Sithis | notes:interior(underground,sealed)
    [1546] = false, -- Shattered Mirror Isle | notes:exterior(moor,district)
    [1547] = false, -- Castle Skingrad | verified:user:outdoor
    [1548] = true, -- Ossein Cage | notes:interior(sealed,prison)
    [1554] = true, -- Theater of the Ancestors | notes:interior(vault)
    [1555] = false, -- Bismuth Steam Baths | verified:user:outdoor-player-house
    [1556] = true, -- The Sleepy Sloth | verified:user:indoor
    [1557] = false, -- Hero's Return | verified:user:outdoor
    [1584] = false, -- Glenumbra | no-notes|prior:exterior:known-zone
}

--- Returns whether a given zoneId defaults to interior, checking a
--- user-configured override first (see settings menu).
--- @param zoneId number
--- @return boolean isInterior
--- @return boolean isKnown   False only if there's no override AND no table entry.
-- 1.3.3: author-verified houses where Weather Control support doesn't
-- match the home's actual layout (reviewed from /lid debug houses).
-- true = interior, false = exterior. Beats the weather flag; a player's
-- own zone override still beats this.
local HOUSE_EXCEPTIONS = {
    [1343] = false, -- Agony's Ascent - no weather control, but the entry area is exterior
    [1306] = false, -- Doomchar Plateau - no weather control, but the whole zone is exterior
    [1434] = true,  -- Emissary's Enclave - weather control, but only a moderate courtyard; mostly interior
    [881]  = true,  -- Gardner House - weather control, but only a small courtyard; mostly interior
    [879]  = false, -- Hunding's Palatial Hall - no weather control, but a large exterior entry area
    [860]  = true,  -- Snugpod - weather control, but the whole zone is interior
    [1435] = false, -- The Fair Winds - no weather control, but entry area and most of the zone are exterior
    [1276] = true,  -- Water's Edge - weather control, but entry area and most of the zone are interior
}

-- 1.3.2: see PLAYER HOUSES in the header. The scan bound is a guess with
-- headroom (house IDs aren't documented; invalid IDs just return 0), so
-- a house added past it would fall back to the ZONE_INTERIOR table.
local HOUSE_ID_SCAN_MAX = 500
local houseZoneWeather = nil  -- zoneId -> supports Weather Control (boolean)
local houseScanCount = 0

local function GetHouseZoneWeatherMap()
    if houseZoneWeather then
        return houseZoneWeather
    end
    houseZoneWeather = {}
    if type(GetHouseZoneId) ~= "function" or type(GetHouseFlags) ~= "function"
        or HOUSE_FLAGS_SUPPORTS_WEATHER_CONTROL == nil or not ZO_FlagHelpers
    then
        return houseZoneWeather -- API unavailable: table fallback for every house
    end
    for houseId = 1, HOUSE_ID_SCAN_MAX do
        local zoneId = GetHouseZoneId(houseId)
        if zoneId and zoneId ~= 0 then
            houseZoneWeather[zoneId] = ZO_FlagHelpers.MaskHasFlag(GetHouseFlags(houseId), HOUSE_FLAGS_SUPPORTS_WEATHER_CONTROL)
            houseScanCount = houseScanCount + 1
        end
    end
    return houseZoneWeather
end

function lib.IsZoneInterior(zoneId)
    if lib.savedVars and lib.savedVars.zoneOverrides then
        local override = lib.savedVars.zoneOverrides[tostring(zoneId)]
        if override ~= nil then
            return override, true
        end
    end

    -- 1.3.3: author-verified exceptions to the weather rule.
    local exception = HOUSE_EXCEPTIONS[zoneId]
    if exception ~= nil then
        return exception, true
    end

    -- 1.3.2: player houses - Weather Control support means exterior.
    local supportsWeather = GetHouseZoneWeatherMap()[zoneId]
    if supportsWeather ~= nil then
        return not supportsWeather, true
    end

    local value = ZONE_INTERIOR[zoneId]
    if value == nil then
        return DEFAULT_IS_INTERIOR, false
    end
    return value, true
end

-------------------------------------------------------------------------------
-- Live state
-------------------------------------------------------------------------------
lib.state = {
    zoneId = nil,
    zoneDefaultInterior = nil,
    isInterior = nil,       -- the live, combined flag
    -- 1.3.0 door watch: nil when idle, else { token, deadlineMs, credits,
    -- prevZone, prevX, prevY, prevZ, startMs, lastTriggerMs,
    -- lastCountedMs, crossings }. Stale timers are dropped by token.
    doorWatch = nil,
    doorWatchToken = 0,
    -- Teleport poll (independent of the door watch - see 0.7.1 note in the
    -- CHANGELOG for why the two never share one pending flag).
    fastTravelCheckPending = false,
    teleportPollToken = 0,
    teleportPollSource = nil,
    mapOpenPosition = nil,  -- set by OnWorldMapOpened(), consumed by OnWorldMapClosed()
    lastDoorToggleMs = nil, -- GetGameTimeMilliseconds() of the last door toggle
    rawZoneId = nil,        -- raw zoneId at the last EVENT_PLAYER_ACTIVATED
    lastReticleText = nil,  -- trace-only: what the reticle offered at interact time
    lockpickText = nil,     -- trace-only: reticle text when the pick began
    zoneIsTemporary = nil,  -- 1.3.1: classification of the current zone (set on arrival)
}

--- Returns the player's current live indoor state.
--- @return boolean|nil isInterior  nil if state hasn't been established yet
---                                 (before the first EVENT_PLAYER_ACTIVATED).
function lib.IsPlayerIndoors()
    return lib.state.isInterior
end

--- Returns whether the player's current zone defaults to interior
--- (including any override), independent of the live toggle. Requires
--- LibZone (hard ## DependsOn requirement).
--- @return boolean|nil isInterior
--- @return number|nil  zoneId
--- @return boolean|nil isKnown
function lib.GetCurrentZoneInterior()
    local zoneId = LibZone:GetCurrentZoneIds()
    if not zoneId then
        return nil, nil, nil
    end
    local isInterior, isKnown = lib.IsZoneInterior(zoneId)
    return isInterior, zoneId, isKnown
end

--- Returns the configured door watch window in milliseconds (1.3.0).
local function GetDoorWatchMs()
    local seconds = (lib.savedVars and lib.savedVars.doorWatchSeconds) or DOOR_WATCH_SECONDS_DEFAULT
    return seconds * 1000
end

--- Returns the currently configured door-transition distance threshold
--- (raw world units - centimeters).
local function GetDoorDeltaThreshold()
    return (lib.savedVars and lib.savedVars.doorDeltaThreshold) or DOOR_DELTA_THRESHOLD_DEFAULT
end

-- Renders an isInterior boolean (or nil) unambiguously in plain English
-- for chat/diagnostic output. Added after a report suspecting an
-- inversion between /amioutside's printed result (which deliberately
-- answers "am I outside," the logical negation of isInterior) and the
-- bare "isInterior=true/false" diagnostic messages used everywhere else
-- in this file. Tracing confirmed no inversion exists in the actual
-- save/restore/HUD pipeline - /amioutside's inversion is the only one,
-- and is intentional given its name - but printing a bare boolean
-- alongside a differently-framed command was a legitimate source of
-- confusion regardless. This does not change any stored or compared
-- value, only how it is displayed.
local function DescribeIsInterior(isInterior)
    if isInterior == nil then
        return "unknown"
    end
    return isInterior and "Interior" or "Exterior"
end

local function IsTraceEnabled()
    return lib.savedVars and lib.savedVars.traceEnabled or false
end

-- Trace output for /lid debug trace. Callers must pass tostring() for any
-- boolean/nil argument - ESO's Lua 5.1-based string.format does not
-- accept booleans for %s. pcall-guarded so a bad format string can never
-- break the detection code that calls this.
local function Trace(fmt, ...)
    if not IsTraceEnabled() then
        return
    end
    local ok, msg = pcall(string.format, fmt, ...)
    CHAT_ROUTER:AddSystemMessage(string.format("[LID trace %d] %s",
        GetGameTimeMilliseconds(), ok and msg or ("(format error) " .. tostring(fmt))))
end

local function MaxAxisDelta(ax, ay, az, bx, by, bz)
    local biggest = zo_abs(bx - ax)
    local dy = zo_abs(by - ay)
    local dz = zo_abs(bz - az)
    if dy > biggest then biggest = dy end
    if dz > biggest then biggest = dz end
    return biggest
end

-------------------------------------------------------------------------------
-- HUD (debug-only as of 0.5.0 - see /lid debug hud below)
-------------------------------------------------------------------------------
local HUD = {
    topLevel = nil,
    label = nil,
    shown = false,  -- actual initial value set in CreateHud() from SavedVariables
}

local HUD_TEXT_INTERIOR = "INDOORS"
local HUD_TEXT_EXTERIOR = "OUTDOORS"
local HUD_COLOR_INTERIOR = { 0.85, 0.6, 0.2, 1 }  -- warm amber
local HUD_COLOR_EXTERIOR = { 0.4, 0.8, 1.0, 1 }   -- sky blue

local function CreateHud()
    -- Persisted (account-wide) but deliberately not exposed as a settings
    -- menu control - see ACCOUNT_DEFAULTS.hudShown.
    HUD.shown = (lib.savedVars and lib.savedVars.hudShown) or false

    HUD.topLevel = WINDOW_MANAGER:CreateTopLevelWindow(LIB_NAME .. "HudTopLevel")
    HUD.topLevel:SetDimensions(200, 30)
    HUD.topLevel:SetAnchor(TOP, GuiRoot, TOP, 0, 150)
    HUD.topLevel:SetMovable(true)
    HUD.topLevel:SetMouseEnabled(true)
    HUD.topLevel:SetClampedToScreen(true)
    HUD.topLevel:SetDrawLayer(DL_OVERLAY)
    HUD.topLevel:SetHidden(not HUD.shown)

    HUD.label = WINDOW_MANAGER:CreateControl(LIB_NAME .. "HudLabel", HUD.topLevel, CT_LABEL)
    HUD.label:SetAnchor(CENTER, HUD.topLevel, CENTER, 0, 0)
    HUD.label:SetFont("ZoFontGameLargeBold")
    HUD.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    HUD.label:SetText("...")
end

local function UpdateHud()
    if not HUD.label then
        return
    end

    local isInterior = lib.state.isInterior
    if isInterior == nil then
        HUD.label:SetText("...")
        return
    end

    if isInterior then
        HUD.label:SetText(HUD_TEXT_INTERIOR)
        HUD.label:SetColor(unpack(HUD_COLOR_INTERIOR))
    else
        HUD.label:SetText(HUD_TEXT_EXTERIOR)
        HUD.label:SetColor(unpack(HUD_COLOR_EXTERIOR))
    end
end

local function SetHudShown(shown)
    HUD.shown = shown
    if HUD.topLevel then
        HUD.topLevel:SetHidden(not shown)
    end
    if lib.savedVars then
        lib.savedVars.hudShown = shown
    end
    CHAT_ROUTER:AddSystemMessage(string.format("[LibInteriorDetection] HUD %s.", shown and "shown" or "hidden"))
end

-- The ONLY place the live flag is written (1.2.0). Centralized so every
-- change - including one that sets the same value it already had - shows
-- up in /lid debug trace with the mechanism responsible.
local function SetIsInterior(value, source, detail)
    local old = lib.state.isInterior
    lib.state.isInterior = value
    -- 1.3.6 LIVE SAVES (see header): keep the saved state current so a
    -- quit, which skips our deactivation update, still writes it. Plain
    -- field writes into the existing SavedVariables table - no new
    -- tables, nothing written to disk until ESO's own save.
    local sv = lib.charSavedVars
    if sv and value ~= nil then
        sv.lastIsInterior = value
        sv.lastLiveUpdateTime = GetTimeStamp()
        sv.lastLiveUpdateSource = source
    end
    UpdateHud()
    Trace("%s: %s -> %s%s", source, DescribeIsInterior(old), DescribeIsInterior(value),
        detail and (" | " .. detail) or "")
end

-------------------------------------------------------------------------------
-- Zone-change handling - always wins, resets the live flag unless this is
-- a genuine resume (real login, or a same-position reload) into the same
-- raw zone we logged out of.
-------------------------------------------------------------------------------

-- Used ONLY for the near-exact "did the player actually stay put" check
-- below (a /reloadui, which never moves the player), NOT for matching
-- position across a genuine relogin - that was tried in 0.5.0-0.6.5 and
-- abandoned after testing proved ESO does not reliably restore exact
-- coordinates across a real login (positions differed by tens of meters
-- even without the player moving). A /reloadui is a fundamentally
-- different case: the player never left the 3D world, so position should
-- match exactly or almost exactly if genuinely unmoved. Confirmed via
-- testing that /reloadui's `initial` reads false, same as a same-session
-- zone change or teleport - meaning `initial` alone can't distinguish
-- "reloaded in place" from "teleported elsewhere in the same zone."
-- Position is what makes that distinction: a real teleport moves the
-- player far enough to fail this tight tolerance, a reload does not.
local RELOAD_POSITION_MATCH_TOLERANCE = 50

-- Ends the door watch; any timer still scheduled is dropped by token.
local function StopDoorWatch(reason)
    local w = lib.state.doorWatch
    if w then
        Trace("Door watch #%d stopped (%s)", w.token, reason)
    end
    lib.state.doorWatch = nil
    lib.state.doorWatchToken = lib.state.doorWatchToken + 1
end

-- Ends the teleport poll if one is running, optionally only for one
-- source (e.g. only the world-map-close fallback).
local function StopTeleportPoll(reason, onlySource)
    if not lib.state.fastTravelCheckPending then
        return
    end
    if onlySource and lib.state.teleportPollSource ~= onlySource then
        return
    end
    Trace("Teleport poll (%s) stopped (%s)", tostring(lib.state.teleportPollSource), reason)
    lib.state.fastTravelCheckPending = false
    lib.state.teleportPollSource = nil
    lib.state.teleportPollToken = lib.state.teleportPollToken + 1
end

-- 1.3.1: see RETURN POINTS in the header. Each API is guarded so a
-- future rename degrades to "not temporary" (the pre-1.3.1 behavior)
-- instead of an error.
local function IsTemporaryZone()
    local inHouse = type(GetCurrentZoneHouseId) == "function" and GetCurrentZoneHouseId() ~= 0
    local inGroupInstance = type(IsActiveWorldGroupOwnable) == "function" and IsActiveWorldGroupOwnable() or false
    local inBattleground = type(IsActiveWorldBattleground) == "function" and IsActiveWorldBattleground() or false
    return (inHouse or inGroupInstance or inBattleground) and true or false,
        string.format("house=%s groupInstance=%s battleground=%s", tostring(inHouse), tostring(inGroupInstance), tostring(inBattleground))
end

-- Returns true when the activation was handled (the live state belongs
-- to the zone just loaded), false when it was ignored. 1.3.6: the
-- wrapper below uses this to decide whether to save the live record.
local function HandlePlayerActivated(eventCode, initial)
    local zoneId = LibZone:GetCurrentZoneIds()
    if not zoneId then
        Trace("Activated: initial=%s but LibZone returned no zoneId - ignored", tostring(initial))
        return false
    end

    local zoneDefaultInterior = lib.IsZoneInterior(zoneId)
    local curZone, curX, curY, curZ = GetUnitRawWorldPosition("player")
    local prevRawZone = lib.state.rawZoneId

    -- 1.3.1: did we just come from a temporary zone? At login, from the
    -- saved logout record; otherwise from the zone we were just in (a
    -- /reloadui wipes this, but a reload never changes zone anyway).
    local cameFromTemporary
    if initial then
        cameFromTemporary = lib.charSavedVars and lib.charSavedVars.lastZoneTemporary == true or false
    else
        cameFromTemporary = lib.state.zoneIsTemporary == true
    end
    local isTemporary, temporaryDetail = IsTemporaryZone()

    lib.state.zoneId = zoneId
    lib.state.zoneDefaultInterior = zoneDefaultInterior
    lib.state.rawZoneId = curZone
    lib.state.zoneIsTemporary = isTemporary

    local now = GetGameTimeMilliseconds()
    local sinceToggleMs = lib.state.lastDoorToggleMs and (now - lib.state.lastDoorToggleMs) or nil

    Trace("Activated: initial=%s rawZone %s -> %s, libZone=%s (default %s), doorWatch=%s, msSinceDoorToggle=%s",
        tostring(initial), tostring(prevRawZone), tostring(curZone), tostring(zoneId),
        DescribeIsInterior(zoneDefaultInterior), tostring(lib.state.doorWatch ~= nil), tostring(sinceToggleMs))
    Trace("Activated: this zone temporary=%s (%s), came from temporary=%s",
        tostring(isTemporary), temporaryDetail, tostring(cameFromTemporary))

    -- 1.2.0: same-raw-zone activation during a door crossing. If this
    -- event was caused by the door itself, the door check (pending, or
    -- just finished and toggled) already accounts for the crossing -
    -- resetting here as well would count it twice. Only applies when the
    -- zone default is exterior: an interior-default zone pins the flag
    -- to interior regardless, so it takes the normal reset below.
    -- Checked BEFORE the restore logic below: a pending door check can
    -- never survive a genuine /reloadui (all Lua state is wiped, which
    -- also leaves prevRawZone nil so sameRawZone is false), so a
    -- non-initial same-zone activation WITH a pending check is never a
    -- reload - letting the reload-restore branch catch it would cancel
    -- the door check and restore the pre-door state.
    -- (1.3.0: with the door watch, "pending" means the watch is still
    -- sampling, so the old gap - a fixed-delay check firing before the
    -- move and finishing without toggling - no longer exists.)
    local sameRawZone = prevRawZone ~= nil and curZone ~= nil and curZone == prevRawZone
    if not initial and sameRawZone and zoneDefaultInterior == false then
        local recentToggle = sinceToggleMs ~= nil and sinceToggleMs <= RECENT_TOGGLE_MS
        if lib.state.doorWatch or recentToggle then
            Trace("Activated: same raw zone during a door crossing - zone-default reset SKIPPED, door watch owns it (watching=%s, recentToggle=%s); state stays %s",
                tostring(lib.state.doorWatch ~= nil), tostring(recentToggle), DescribeIsInterior(lib.state.isInterior))
            UpdateHud()
            return true
        end
    end

    -- Restore the saved flag if the saved raw zoneId matches AND EITHER:
    --   (a) initial is true - a genuine login, where position may have
    --       drifted unreliably (proven in testing). The 50m login gate is
    --       evaluated and traced but only enforced if
    --       LOGIN_POSITION_GATE_ENABLED (off since 1.3.5), or
    --   (b) the current raw position is a near-exact match to the saved
    --       one - proving nothing moved (a /reloadui, which reports
    --       initial=false despite being a legitimate resume - confirmed
    --       via testing).
    -- A same-zone teleport (wayshrine or otherwise) fails BOTH checks at
    -- once - it isn't a login, and the position is genuinely far away -
    -- so it still correctly falls through to the zone default rather
    -- than carrying over a stale flag from before the teleport.
    -- 1.3.4 diagnostics: report the saved record at login, whatever the
    -- outcome, so a failed restore shows WHY in the trace.
    if initial and lib.charSavedVars then
        local saved = lib.charSavedVars.lastPosition
        local d = lib.charSavedVars.lastDeactivate
        Trace("Activated (login): saved rawZone=%s state=%s age=%s | last deactivation: %s",
            saved and tostring(saved.zoneId) or "none",
            DescribeIsInterior(lib.charSavedVars.lastIsInterior),
            (saved and saved.timestamp) and (tostring(GetTimeStamp() - saved.timestamp) .. "s") or "unknown (pre-1.3.4 record)",
            d and string.format("%ss ago, read rawZone=%s, activation rawZone=%s, state=%s, saved=%s",
                tostring(d.timestamp and (GetTimeStamp() - d.timestamp) or "?"), tostring(d.rawZoneRead),
                tostring(d.activationRawZoneId), DescribeIsInterior(d.state), tostring(d.saved))
              or "no record (none since 1.3.4, or it never reached disk)")
        Trace("Activated (login): last live update %s (%s)",
            lib.charSavedVars.lastLiveUpdateTime and (tostring(GetTimeStamp() - lib.charSavedVars.lastLiveUpdateTime) .. "s ago") or "never (none since 1.3.6)",
            tostring(lib.charSavedVars.lastLiveUpdateSource))
    end

    local shouldRestore = false
    if lib.charSavedVars and lib.charSavedVars.lastPosition
        and lib.charSavedVars.lastPosition.zoneId == curZone
        and lib.charSavedVars.lastIsInterior ~= nil
    then
        local saved = lib.charSavedVars.lastPosition
        if initial then
            if curX and saved.x then
                local distance = MaxAxisDelta(saved.x, saved.y, saved.z, curX, curY, curZ)
                local withinGate = distance <= LOGIN_POSITION_TOLERANCE
                if LOGIN_POSITION_GATE_ENABLED then
                    shouldRestore = withinGate
                    Trace("Activated (login): %.0f from the saved logout position (tolerance %d) - %s",
                        distance, LOGIN_POSITION_TOLERANCE,
                        withinGate and "restoring" or "treated as a STALE record, not restored")
                else
                    shouldRestore = true
                    Trace("Activated (login): %.0f from the saved logout position (tolerance %d, gate LOG-ONLY) - restoring; gate would have %s",
                        distance, LOGIN_POSITION_TOLERANCE,
                        withinGate and "restored too" or "REJECTED it as stale")
                end
            else
                shouldRestore = true -- no position to compare: pre-1.3.4 behavior
            end
        elseif curX then
            if zo_abs(curX - saved.x) <= RELOAD_POSITION_MATCH_TOLERANCE
                and zo_abs(curY - saved.y) <= RELOAD_POSITION_MATCH_TOLERANCE
                and zo_abs(curZ - saved.z) <= RELOAD_POSITION_MATCH_TOLERANCE
            then
                shouldRestore = true
            end
        end
    end

    if shouldRestore then
        StopDoorWatch("activation restore")
        SetIsInterior(lib.charSavedVars.lastIsInterior, "Activated (restore saved state)")
        return true
    end

    -- 1.3.1: back from a temporary zone at the saved return point?
    local rp = lib.charSavedVars and lib.charSavedVars.returnPoint
    if cameFromTemporary and rp and rp.zoneId == curZone and rp.isInterior ~= nil and curX then
        local distance = MaxAxisDelta(rp.x, rp.y, rp.z, curX, curY, curZ)
        if distance <= RETURN_POINT_TOLERANCE then
            StopDoorWatch("return point restore")
            SetIsInterior(rp.isInterior, "Activated (return point)",
                string.format("back from a temporary zone, %.0f from the saved return point (tolerance %d)", distance, RETURN_POINT_TOLERANCE))
            return true
        end
        Trace("Activated: return point in this zone but %.0f away (tolerance %d) - not used", distance, RETURN_POINT_TOLERANCE)
    elseif cameFromTemporary then
        Trace("Activated: came from a temporary zone, but the return point is %s", rp and ("in rawZone " .. tostring(rp.zoneId)) or "missing")
    end

    StopDoorWatch("activation reset")
    SetIsInterior(zoneDefaultInterior, "Activated (zone default)")
    return true
end

-- 1.3.6 LIVE SAVES (see header): after a handled activation, record the
-- zone just loaded, so a quit later this session still leaves the right
-- zone on disk. Runs AFTER the handler, which has already read the
-- previous record for its restore decision. Once per load screen.
local function SaveLiveRecord()
    local sv = lib.charSavedVars
    if not sv or lib.state.isInterior == nil then
        return
    end
    local zoneId, x, y, z = GetUnitRawWorldPosition("player")
    if not zoneId then
        Trace("Activated: live save skipped - raw position read returned nil")
        return
    end
    local now = GetTimeStamp()
    sv.lastPosition = { zoneId = zoneId, x = x, y = y, z = z, timestamp = now }
    sv.lastIsInterior = lib.state.isInterior
    sv.lastZoneTemporary = lib.state.zoneIsTemporary == true
    sv.lastLiveUpdateTime = now
    sv.lastLiveUpdateSource = "activation"
end

local function OnPlayerActivated(eventCode, initial)
    if HandlePlayerActivated(eventCode, initial) then
        SaveLiveRecord()
    end
end

local function OnPlayerDeactivated()
    if not lib.charSavedVars then
        return
    end

    local zoneId, x, y, z = GetUnitRawWorldPosition("player")
    local now = GetTimeStamp()

    -- 1.3.4: diagnostic record first, before anything that can bail out
    -- (see SAVE DIAGNOSTICS in the header). Never read by restore logic.
    local record = {
        timestamp = now,
        rawZoneRead = zoneId,                    -- nil = the read failed
        activationRawZoneId = lib.state.rawZoneId,
        state = lib.state.isInterior,
        saved = false,
    }
    lib.charSavedVars.lastDeactivate = record

    if not zoneId then
        Trace("Deactivated: raw position read returned nil - NOTHING saved; the previous logout record stays in place")
        return
    end
    if lib.state.rawZoneId ~= nil and zoneId ~= lib.state.rawZoneId then
        Trace("Deactivated: teardown read rawZone=%s differs from activation rawZone=%s (saving the teardown read, as before)",
            tostring(zoneId), tostring(lib.state.rawZoneId))
    end

    lib.charSavedVars.lastPosition = { zoneId = zoneId, x = x, y = y, z = z, timestamp = now }
    lib.charSavedVars.lastIsInterior = lib.state.isInterior
    lib.charSavedVars.lastZoneTemporary = lib.state.zoneIsTemporary == true
    Trace("Deactivated: saved rawZone=%s state=%s temporary=%s", tostring(zoneId),
        DescribeIsInterior(lib.state.isInterior), tostring(lib.state.zoneIsTemporary == true))
    record.saved = true

    -- 1.3.1: leaving a normal zone also records the return point;
    -- temporary zones never overwrite it (see RETURN POINTS).
    if lib.state.zoneIsTemporary == false and lib.state.isInterior ~= nil then
        lib.charSavedVars.returnPoint = { zoneId = zoneId, x = x, y = y, z = z, isInterior = lib.state.isInterior }
        Trace("Deactivated: return point saved (rawZone=%s state=%s)", tostring(zoneId), DescribeIsInterior(lib.state.isInterior))
    end
end

-------------------------------------------------------------------------------
-- Door-transition toggle - ported from DoorDeltaTest.
-------------------------------------------------------------------------------
local function GetRawPosition()
    return GetUnitRawWorldPosition("player")
end

local function DoorWatchTick(token)
    local w = lib.state.doorWatch
    if not w or w.token ~= token then
        return -- stopped or replaced
    end

    local now = GetGameTimeMilliseconds()
    local curZone, curX, curY, curZ = GetRawPosition()
    if not curZone then
        lib.state.doorWatch = nil
        Trace("Door watch #%d: no position available - ended", token)
        return
    end

    if curZone ~= w.prevZone then
        -- A real zone change - OnPlayerActivated handles it.
        lib.state.doorWatch = nil
        Trace("Door watch #%d: raw zone changed %s -> %s - ended (zone load handles it)",
            token, tostring(w.prevZone), tostring(curZone))
        return
    end

    local step = MaxAxisDelta(w.prevX, w.prevY, w.prevZ, curX, curY, curZ)
    w.prevX, w.prevY, w.prevZ = curX, curY, curZ
    local threshold = GetDoorDeltaThreshold()

    if step > threshold then
        local sinceTrigger = now - w.lastTriggerMs
        if lib.state.fastTravelCheckPending then
            -- A teleport poll is watching the same move; teleports win.
            lib.state.doorWatch = nil
            Trace("Door watch #%d: jump %.0f at +%dms, but a teleport poll (%s) is running - door watch stands down",
                token, step, sinceTrigger, tostring(lib.state.teleportPollSource))
            return
        elseif w.credits <= 0 then
            Trace("Door watch #%d: jump %.0f at +%dms IGNORED - no interaction left to account for it", token, step, sinceTrigger)
        elseif w.lastCountedMs and (now - w.lastCountedMs) < DOOR_JUMP_COOLDOWN_MS then
            Trace("Door watch #%d: jump %.0f IGNORED - %dms after the last counted jump (cooldown %dms)",
                token, step, now - w.lastCountedMs, DOOR_JUMP_COOLDOWN_MS)
        else
            w.credits = w.credits - 1
            w.crossings = w.crossings + 1
            w.lastCountedMs = now
            if lib.state.zoneDefaultInterior == false then
                lib.state.lastDoorToggleMs = now
                SetIsInterior(not lib.state.isInterior, "Door",
                    string.format("watch #%d jump %.0f > %.0f, landed %dms after the last interaction", token, step, threshold, sinceTrigger))
            else
                Trace("Door watch #%d: jump %.0f, but zone default is Interior - no toggle", token, step)
            end
        end
    end

    if now >= w.deadlineMs then
        lib.state.doorWatch = nil
        Trace("Door watch #%d ended after %dms - %d crossing(s)", token, now - w.startMs, w.crossings)
        return
    end

    zo_callLater(function()
        DoorWatchTick(token)
    end, POLL_INTERVAL_MS)
end

-- Shared by the interaction hook and the lockpick-success handler.
local function StartOrExtendDoorWatch(label)
    local now = GetGameTimeMilliseconds()
    local w = lib.state.doorWatch

    if w then
        w.deadlineMs = now + GetDoorWatchMs()
        w.lastTriggerMs = now
        w.credits = math.min(w.credits + 1, DOOR_WATCH_MAX_CREDITS)
        Trace("Door watch #%d extended (credits %d): %s", w.token, w.credits, label)
        return
    end

    local zoneId, x, y, z = GetRawPosition()
    if not zoneId then
        return
    end

    lib.state.doorWatchToken = lib.state.doorWatchToken + 1
    local token = lib.state.doorWatchToken
    lib.state.doorWatch = {
        token = token, deadlineMs = now + GetDoorWatchMs(), credits = 1,
        prevZone = zoneId, prevX = x, prevY = y, prevZ = z,
        startMs = now, lastTriggerMs = now, lastCountedMs = nil, crossings = 0,
    }
    Trace("Door watch #%d started (%dms window): %s", token, GetDoorWatchMs(), label)

    zo_callLater(function()
        DoorWatchTick(token)
    end, POLL_INTERVAL_MS)
end

-- Trace-only (1.2.0): records what the reticle currently offers, so each
-- traced interaction says what was interacted with. Same
-- ZO_PreHook(RETICLE, "TryHandlingInteraction") pattern Frostfall already
-- uses for its rest detection; never blocks anything (always returns
-- false), and does no work at all unless the trace is on. Has no effect
-- on detection - the door check still fires for every interaction.
local function HookReticleText()
    if not RETICLE or type(RETICLE.TryHandlingInteraction) ~= "function" then
        return
    end
    -- 1.2.5: ZO_PreHook passes the method's self (RETICLE) first -
    -- confirmed in the ESOUI client source (zo_hook.lua). Before this
    -- fix, `interactionPossible` was actually RETICLE and always truthy.
    ZO_PreHook(RETICLE, "TryHandlingInteraction", function(self, interactionPossible)
        if not IsTraceEnabled() then
            return false
        end
        if interactionPossible then
            local action, interactableName = GetGameCameraInteractableActionInfo()
            lib.state.lastReticleText = string.format("'%s' / '%s'", tostring(action), tostring(interactableName))
        else
            lib.state.lastReticleText = nil
        end
        return false
    end)
end

local function OnPlayerInteract()
    -- An interaction means any following jump is a door's, not a
    -- world-map teleport's: the map-close fallback poll ends here so the
    -- two can't both act on one move. (Hooked-travel polls are left alone
    -- - those follow a confirmed travel call.)
    StopTeleportPoll("interaction", "worldMap close")
    StartOrExtendDoorWatch(lib.state.lastReticleText or "(no reticle text)")
end

-------------------------------------------------------------------------------
-- Lockpicked doors - see LOCKPICKED DOORS in the header.
-------------------------------------------------------------------------------
local function OnLockpickBegin()
    lib.state.lockpickText = lib.state.lastReticleText
    Trace("Lockpick BEGIN: %s", lib.state.lockpickText or "(no reticle text)")
end

local function OnLockpickSuccess()
    local target = lib.state.lockpickText or "(no reticle text)"
    lib.state.lockpickText = nil
    if lib.state.fastTravelCheckPending then
        Trace("Lockpick SUCCESS: %s - teleport poll running, not watching", target)
        return
    end
    StartOrExtendDoorWatch("lockpick success on " .. target)
end

local function OnLockpickEnded(label)
    return function()
        Trace("Lockpick %s", label)
        if label == "FAILED" then
            lib.state.lockpickText = nil
        end
    end
end

local function HookInteraction()
    if not INTERACTIVE_WHEEL_MANAGER or not INTERACTIVE_WHEEL_MANAGER.StartInteraction then
        CHAT_ROUTER:AddSystemMessage(
            "[LibInteriorDetection] INTERACTIVE_WHEEL_MANAGER.StartInteraction not found - door-toggle disabled."
        )
        return
    end

    local originalStartInteraction = INTERACTIVE_WHEEL_MANAGER.StartInteraction
    INTERACTIVE_WHEEL_MANAGER.StartInteraction = function(self, interactiveWheelType, ...)
        local result = originalStartInteraction(self, interactiveWheelType, ...)
        -- 1.3.0: only the interact key counts. Per the ESOUI client's
        -- bindings.xml, the interact key passes
        -- ZO_INTERACTIVE_WHEEL_TYPE_FISHING; the quickslot and
        -- target-marker wheel keys pass other types and aren't
        -- interactions. If the constant ever disappears, count everything
        -- (the pre-1.3.0 behavior) rather than nothing.
        if ZO_INTERACTIVE_WHEEL_TYPE_FISHING == nil or interactiveWheelType == ZO_INTERACTIVE_WHEEL_TYPE_FISHING then
            OnPlayerInteract()
        else
            Trace("StartInteraction for wheel type %s ignored (not the interact key)", tostring(interactiveWheelType))
        end
        return result
    end
end

-------------------------------------------------------------------------------
-- Fast-travel / map-teleport check (0.7.0, UNIFIED in 0.7.6) - same shape
-- as the door check above (hook a trigger, wait, compare raw position),
-- for the gap the door check and EVENT_PLAYER_ACTIVATED both miss: a
-- player teleporting via the world map to a different part of the SAME
-- raw zone. Two independent trigger sources feed the SAME poll-based
-- check below:
--   1. Four hooked global functions (FastTravelToNode, RequestJumpToHouse,
--      JumpToHouse, JumpToSpecificHouse - see HookFastTravel() further
--      down) - confirmed to fire at the moment a teleport actually
--      executes, whether instant or after a delay.
--   2. The world map's own open/close lifecycle (see HookWorldMapScene()
--      further down) - a general fallback for cases where the specific
--      internal function isn't known or hookable (e.g. a player house's
--      exterior-door sub-option, which fires none of the four above).
--
-- UNIFIED in 0.7.6: originally the two sources used different check
-- strategies - the four hooked functions used a single short fixed
-- delay, the map-close path used a bounded poll (added in 0.7.5 after
-- the fixed-delay approach proved too early for it). Testing then
-- clarified WHY: teleporting while standing at a wayshrine and picking
-- another one is instant, but teleporting via the world map from an
-- arbitrary location - to EITHER a wayshrine or a house - triggers an
-- 8-second "Recall" ability cast before the actual position change
-- (per an ESOUI forum source found earlier in this project). Since the
-- four hooked functions fire at actual-teleport-execution time
-- regardless of which of these two cases applies, a short fixed delay
-- was only ever correct for the instant case by coincidence - it was
-- equally too early for a map-initiated wayshrine or house trip, just
-- not yet reported as broken. Both trigger sources now use the same
-- bounded poll instead of either one relying on a fixed delay guess.
--
-- The poll checks position every POLL_INTERVAL_MS for up to
-- ~15 seconds, stopping as soon as either a real change is detected or
-- the window expires.
--
-- STEP-JUMP DETECTION (1.2.3): each sample is compared with the PREVIOUS
-- sample, not the trigger-time position. Previously the whole-window
-- distance was used, so ordinary movement after closing the map
-- (confirmed in-game: 2750 units in ~3s of running) reset the flag to
-- the zone default - harmless outdoors, wrong inside a large interior
-- sub-cell. A teleport lands between two samples as one jump; running
-- covers ~2m per 250ms step at the observed speed, 10x under the 20m
-- threshold. UNVERIFIED: ESO's top mounted speed - a mount would need
-- ~80 m/s to cross the threshold in one step, so this is assumed safe.
-- The FIRST step compares against the trigger-time position (map open /
-- hook call), so a jump that happened before polling began is still
-- caught - the player can't walk while the map is open. This is NOT the continuous
-- position poll rejected earlier in this project's design discussion -
-- that would have run constantly during normal play; this only runs for
-- a few seconds after a genuinely rare trigger (an interaction, a
-- hooked travel function, or closing the world map), so the added cost
-- is negligible.
--
-- IMPORTANT DIFFERENCE FROM THE DOOR CHECK: a door is symmetric (used
-- once to enter, once to exit), so toggling the flag is correct. A
-- teleport is NOT symmetric - it can land the player anywhere regardless
-- of their state beforehand. Toggling on a detected teleport would
-- introduce a new bug (e.g. teleporting between two exterior spots in
-- the same zone would incorrectly flip to "interior"). This check
-- RESETS to the zone's default instead of toggling when a same-zone
-- jump is detected, since a fast-travel destination is essentially
-- always the zone's ordinary outdoor arrival point.
-------------------------------------------------------------------------------
-- 1.2.3: 250ms (was 1000ms) so a step is short enough that no ordinary
-- movement approaches the threshold; attempts scaled to keep the same
-- ~15s window (covers Recall's documented 8s cast plus buffer).
local TELEPORT_POLL_MAX_ATTEMPTS = 60  -- x POLL_INTERVAL_MS = ~15s

local function PollForTeleport(token, source, prevZone, prevX, prevY, prevZ, attemptsRemaining)
    if token ~= lib.state.teleportPollToken then
        return -- stopped (already traced there)
    end
    local curZone, curX, curY, curZ = GetRawPosition()

    if not prevZone or not curZone then
        lib.state.fastTravelCheckPending = false
        return
    end

    if prevZone ~= curZone then
        -- A real zone change - OnPlayerActivated already handled it.
        lib.state.fastTravelCheckPending = false
        Trace("Teleport poll (%s): raw zone changed %s -> %s - no action", source, tostring(prevZone), tostring(curZone))
        return
    end

    -- Distance since the PREVIOUS sample only (see STEP-JUMP DETECTION).
    local stepDelta = MaxAxisDelta(prevX, prevY, prevZ, curX, curY, curZ)
    local threshold = GetDoorDeltaThreshold()

    if stepDelta > threshold then
        lib.state.fastTravelCheckPending = false
        lib.state.teleportPollSource = nil
        -- The teleport owns this move: end any door watch so it can't
        -- also count the same jump.
        StopDoorWatch("teleport detected")
        SetIsInterior(lib.state.zoneDefaultInterior, "Teleport poll (" .. source .. ")",
            string.format("single-step jump %.0f > threshold %.0f, reset to zone default", stepDelta, threshold))
        return
    end

    if attemptsRemaining <= 0 then
        lib.state.fastTravelCheckPending = false
        Trace("Teleport poll (%s): no jump within window - no action", source)
        return -- gave up - no teleport-sized jump within the window
    end

    zo_callLater(function()
        PollForTeleport(token, source, curZone, curX, curY, curZ, attemptsRemaining - 1)
    end, POLL_INTERVAL_MS)
end

local function OnFastTravelInitiated(source)
    source = source or "travel hook"
    -- 1.3.0: a confirmed travel call owns whatever move follows - end any
    -- door watch (e.g. from the E press on the wayshrine itself) so it
    -- can't also count the jump.
    StopDoorWatch("travel: " .. source)
    if lib.state.fastTravelCheckPending then
        Trace("Travel trigger %s IGNORED (teleport poll already pending)", source)
        return -- a check is already running; ignore overlapping triggers
    end

    local zoneId, x, y, z = GetRawPosition()
    if not zoneId then
        return
    end

    lib.state.fastTravelCheckPending = true
    lib.state.teleportPollSource = source
    lib.state.teleportPollToken = lib.state.teleportPollToken + 1
    Trace("Travel trigger %s -> teleport poll started", source)

    PollForTeleport(lib.state.teleportPollToken, source, zoneId, x, y, z, TELEPORT_POLL_MAX_ATTEMPTS)
end

-------------------------------------------------------------------------------
-- World-map-open/close trigger (0.7.4) - a more general fallback for the
-- gap the four hooked travel functions above may still miss (confirmed
-- as of 0.7.4: a player's own house exterior-door option, reached via a
-- sub-menu behind the house map pin, does not fire any of them). Rather
-- than guess yet another specific function name, this watches the world
-- map's own open/close lifecycle instead - it doesn't need to know WHICH
-- internal function actually executes a travel, only that the map was
-- open beforehand. Confirmed via the actual ESOUI client source (fetched
-- during this project) that SCENE_MANAGER:IsShowing("worldMap") is a
-- real, correct way to check the map scene's state, so "worldMap" as a
-- scene name is solid. The StateChange callback REGISTRATION pattern and
-- exact state constant names are NOT independently re-verified this
-- session - flagged, not fabricated - so the callback below prints the
-- raw oldState/newState values every time it fires, letting this be
-- confirmed empirically rather than trusted blindly.
--
-- Feeds the SAME PollForTeleport() used by the four hooked functions
-- above (see 0.7.6 unification note there) - position is captured when
-- the map OPENS (guaranteed to precede any possible travel confirmation)
-- and the poll begins once the map CLOSES.
-------------------------------------------------------------------------------
local function OnWorldMapOpened()
    local zoneId, x, y, z = GetRawPosition()
    if not zoneId then
        return
    end
    lib.state.mapOpenPosition = { zoneId = zoneId, x = x, y = y, z = z }
end

local function OnWorldMapClosed()
    if lib.state.fastTravelCheckPending then
        Trace("Travel trigger worldMap close IGNORED (teleport poll already pending)")
        return -- another check already in flight; see design note above
    end

    local saved = lib.state.mapOpenPosition
    if not saved then
        return
    end

    lib.state.fastTravelCheckPending = true
    lib.state.teleportPollSource = "worldMap close"
    lib.state.teleportPollToken = lib.state.teleportPollToken + 1
    Trace("Travel trigger worldMap close -> teleport poll started")

    PollForTeleport(lib.state.teleportPollToken, "worldMap close", saved.zoneId, saved.x, saved.y, saved.z, TELEPORT_POLL_MAX_ATTEMPTS)
end

local function HookWorldMapScene()
    if not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then
        CHAT_ROUTER:AddSystemMessage(
            "[LibInteriorDetection] SCENE_MANAGER:GetScene not found - map-close teleport detection disabled."
        )
        return
    end

    local worldMapScene = SCENE_MANAGER:GetScene("worldMap")
    if not worldMapScene or type(worldMapScene.RegisterCallback) ~= "function" then
        CHAT_ROUTER:AddSystemMessage(
            "[LibInteriorDetection] worldMap scene not found - map-close teleport detection disabled."
        )
        return
    end

    worldMapScene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            OnWorldMapOpened()
        elseif newState == SCENE_HIDDEN then
            OnWorldMapClosed()
        end
    end)
end

-- Generic helper: wraps a global function by name so it also triggers
-- onCalled() after running, without needing to know or preserve the
-- function's exact signature. Warns in chat rather than erroring if the
-- named global doesn't exist as a function - used for every travel-
-- related global this library hooks, since confidence varies per
-- function (see call sites below) and any of them could be renamed in
-- a future API update.
local function HookGlobalFunction(name, onCalled)
    local original = _G[name]
    if type(original) ~= "function" then
        CHAT_ROUTER:AddSystemMessage(
            string.format("[LibInteriorDetection] %s not found - related teleport detection disabled.", name)
        )
        return
    end

    _G[name] = function(...)
        local result = original(...)
        onCalled(name)
        return result
    end
end

local function HookFastTravel()
    -- FastTravelToNode: sourced from a single decade-old ESOUI forum
    -- post, real risk of having been renamed since. Confirmed via
    -- in-game testing to correctly fire for wayshrine-to-wayshrine
    -- same-zone travel.
    HookGlobalFunction("FastTravelToNode", OnFastTravelInitiated)

    -- Player-house travel: a map click on a house's "front door" pin was
    -- reported not to fire FastTravelToNode at all (no confirmation
    -- dialog appears, unlike wayshrine travel - direct evidence it's a
    -- different code path). These three are confirmed real via UESP's
    -- actual API function-export data across four separate API versions
    -- (100020/100021/100026/100029) AND live forum reports from 2022 and
    -- 2024 confirming they still work via slash commands today - a much
    -- stronger confidence tier than FastTravelToNode's single old
    -- source. RequestJumpToHouse is what the housing/collections book UI
    -- calls internally and is the most likely match for a map house-pin
    -- click, since map house pins are tied to the same collectible data;
    -- JumpToHouse/JumpToSpecificHouse are the slash-command-callable
    -- versions, hooked as well since which one a map click actually
    -- routes through hasn't been confirmed.
    HookGlobalFunction("RequestJumpToHouse", OnFastTravelInitiated)
    HookGlobalFunction("JumpToHouse", OnFastTravelInitiated)
    HookGlobalFunction("JumpToSpecificHouse", OnFastTravelInitiated)
end

-------------------------------------------------------------------------------
-- /amioutside - prints true/false for the player's LIVE indoor state.
-------------------------------------------------------------------------------
local function TrimString(s)
    return string.match(s or "", "^%s*(.-)%s*$")
end

local function SlashAmIOutside()
    local isInterior = lib.IsPlayerIndoors()

    if isInterior == nil then
        CHAT_ROUTER:AddSystemMessage("[LibInteriorDetection] State not established yet.")
        return
    end

    local zoneName = GetZoneNameById(lib.state.zoneId) or "Unknown Zone"
    local isOutside = not isInterior

    CHAT_ROUTER:AddSystemMessage(tostring(isOutside))
    CHAT_ROUTER:AddSystemMessage(
        string.format(
            "[LibInteriorDetection] isOutside=%s (i.e. %s) | zone %s (%d), zoneDefault=%s, threshold=%.0f, doorWatch=%ds",
            tostring(isOutside),
            DescribeIsInterior(isInterior),
            zoneName,
            lib.state.zoneId,
            DescribeIsInterior(lib.state.zoneDefaultInterior),
            GetDoorDeltaThreshold(),
            (lib.savedVars and lib.savedVars.doorWatchSeconds) or DOOR_WATCH_SECONDS_DEFAULT
        )
    )
end

-------------------------------------------------------------------------------
-- /lid debug hud on|off - replaces /toggleindoorhud (0.5.0).
-- Persisted (account-wide), not exposed in the settings menu.
-------------------------------------------------------------------------------
local function SlashLid(argString)
    local args = {}
    for token in string.gmatch(TrimString(argString), "%S+") do
        args[#args + 1] = string.lower(token)
    end

    if args[1] == "debug" and args[2] == "hud" and (args[3] == "on" or args[3] == "off") then
        SetHudShown(args[3] == "on")
        return
    end

    -- /lid debug saved - dumps saved vs. current raw position/state, to
    -- diagnose the restore-on-login logic (OnPlayerActivated above)
    -- without guessing. Removed in the 1.0.0 "final deployment" cleanup on
    -- the assumption the mechanism was fully validated by then; reinstated
    -- after a report of a failed restore specifically for an interior
    -- sub-space combined with a multi-hour offline gap, which evidently
    -- wasn't covered by the earlier testing that justified removing this.
    if args[1] == "debug" and args[2] == "saved" then
        local curZone, curX, curY, curZ = GetRawPosition()
        local curLibZoneId = LibZone:GetCurrentZoneIds()

        CHAT_ROUTER:AddSystemMessage(
            string.format("[LibInteriorDetection] Current live state: %s (zoneDefault: %s)",
                DescribeIsInterior(lib.state.isInterior), DescribeIsInterior(lib.state.zoneDefaultInterior))
        )
        CHAT_ROUTER:AddSystemMessage(
            string.format("[LibInteriorDetection] Current: rawZone=%s (%s) libZone=%s x=%s y=%s z=%s",
                tostring(curZone), curZone and (GetZoneNameById(curZone) or "?") or "?",
                tostring(curLibZoneId), tostring(curX), tostring(curY), tostring(curZ))
        )

        -- 1.3.4: the last deactivation's diagnostic record, printed even
        -- when no position was ever saved (that is one of the cases it
        -- exists to expose). See SAVE DIAGNOSTICS in the header.
        local d = lib.charSavedVars and lib.charSavedVars.lastDeactivate
        CHAT_ROUTER:AddSystemMessage(d and string.format(
            "[LibInteriorDetection] Last deactivation: %ss ago | read rawZone=%s, activation rawZone=%s, state=%s, saved=%s",
            tostring(d.timestamp and (GetTimeStamp() - d.timestamp) or "?"), tostring(d.rawZoneRead),
            tostring(d.activationRawZoneId), DescribeIsInterior(d.state), tostring(d.saved))
            or "[LibInteriorDetection] Last deactivation: no record (none since 1.3.4, or it never reached disk)")
        local lu = lib.charSavedVars and lib.charSavedVars.lastLiveUpdateTime
        CHAT_ROUTER:AddSystemMessage(lu and string.format(
            "[LibInteriorDetection] Last live update: %ss ago (%s)",
            tostring(GetTimeStamp() - lu), tostring(lib.charSavedVars.lastLiveUpdateSource))
            or "[LibInteriorDetection] Last live update: none (none since 1.3.6)")

        if not lib.charSavedVars or not lib.charSavedVars.lastPosition then
            CHAT_ROUTER:AddSystemMessage("[LibInteriorDetection] No saved position on record for this character.")
            return
        end

        local saved = lib.charSavedVars.lastPosition
        CHAT_ROUTER:AddSystemMessage(
            string.format("[LibInteriorDetection] Saved: rawZone=%s (%s) x=%s y=%s z=%s savedState=%s",
                tostring(saved.zoneId), saved.zoneId and (GetZoneNameById(saved.zoneId) or "?") or "?",
                tostring(saved.x), tostring(saved.y), tostring(saved.z),
                DescribeIsInterior(lib.charSavedVars.lastIsInterior))
        )

        local zoneMatches = curZone ~= nil and saved.zoneId == curZone
        local distance = (curX and saved.x) and MaxAxisDelta(saved.x, saved.y, saved.z, curX, curY, curZ) or nil
        CHAT_ROUTER:AddSystemMessage(
            string.format("[LibInteriorDetection] rawZone match: %s | distance from saved: %s (login tolerance %d, gate %s) | saved record age: %s",
                tostring(zoneMatches),
                distance and string.format("%.0f", distance) or "?",
                LOGIN_POSITION_TOLERANCE,
                LOGIN_POSITION_GATE_ENABLED and "ON" or "log-only",
                saved.timestamp and (tostring(GetTimeStamp() - saved.timestamp) .. "s") or "unknown (pre-1.3.4 record)")
        )
        local rp = lib.charSavedVars.returnPoint
        CHAT_ROUTER:AddSystemMessage(rp and string.format(
            "[LibInteriorDetection] Return point: rawZone=%s (%s) x=%s y=%s z=%s state=%s | logout zone temporary=%s",
            tostring(rp.zoneId), rp.zoneId and (GetZoneNameById(rp.zoneId) or "?") or "?",
            tostring(rp.x), tostring(rp.y), tostring(rp.z), DescribeIsInterior(rp.isInterior),
            tostring(lib.charSavedVars.lastZoneTemporary))
            or "[LibInteriorDetection] Return point: none saved yet")
        return
    end

    -- /lid debug flip - inverts the live isInterior flag for the current
    -- session only. A manual escape hatch for exactly the failure mode
    -- above: if the restore-on-login logic ever gets this wrong (e.g. the
    -- interior-sub-space-plus-long-offline-gap case), the player can
    -- correct it themselves in one command rather than wait for a real
    -- fix. Deliberately NOT persisted anywhere and does not touch
    -- zoneDefaultInterior - the very next real zone change, door
    -- interaction, or map teleport will naturally re-evaluate and
    -- override this the normal way, exactly as if this command had never
    -- been run.
    if args[1] == "debug" and args[2] == "flip" then
        SetIsInterior(not lib.state.isInterior, "/lid debug flip")
        CHAT_ROUTER:AddSystemMessage(
            string.format("[LibInteriorDetection] Flipped to: %s (this session only - not saved)",
                DescribeIsInterior(lib.state.isInterior))
        )
        return
    end

    -- /lid debug houses (1.3.2): the house classification read from the
    -- game, and every house where it disagrees with the old table entry.
    if args[1] == "debug" and args[2] == "houses" then
        local map = GetHouseZoneWeatherMap()
        local weatherCount, exceptionCount, changed = 0, 0, {}
        for zoneId, supportsWeather in pairs(map) do
            if supportsWeather then
                weatherCount = weatherCount + 1
            end
            -- Effective built-in value: exception first, else the flag.
            local effective = not supportsWeather
            local exception = HOUSE_EXCEPTIONS[zoneId]
            if exception ~= nil then
                exceptionCount = exceptionCount + 1
                effective = exception
            end
            local tableValue = ZONE_INTERIOR[zoneId]
            if tableValue ~= nil and tableValue ~= effective then
                changed[#changed + 1] = string.format("%s (%d): %s -> %s%s", GetZoneNameById(zoneId) or "?", zoneId,
                    DescribeIsInterior(tableValue), DescribeIsInterior(effective),
                    exception ~= nil and " (exception)" or "")
            end
        end
        CHAT_ROUTER:AddSystemMessage(string.format(
            "[LibInteriorDetection] Houses found: %d (%d support Weather Control, %d don't; %d author exceptions applied). Differ from the old table: %d",
            houseScanCount, weatherCount, houseScanCount - weatherCount, exceptionCount, #changed))
        table.sort(changed)
        for _, line in ipairs(changed) do
            CHAT_ROUTER:AddSystemMessage("[LibInteriorDetection]   " .. line)
        end
        return
    end

    -- /lid debug trace on|off (1.2.0) - see SetIsInterior/Trace.
    if args[1] == "debug" and args[2] == "trace" and (args[3] == "on" or args[3] == "off") then
        if lib.savedVars then
            lib.savedVars.traceEnabled = (args[3] == "on")
        end
        if args[3] == "off" then
            lib.state.lastReticleText = nil
        end
        CHAT_ROUTER:AddSystemMessage(string.format("[LibInteriorDetection] Trace %s. Current state: %s (zone default %s)",
            args[3] == "on" and "ON" or "OFF",
            DescribeIsInterior(lib.state.isInterior), DescribeIsInterior(lib.state.zoneDefaultInterior)))
        return
    end

    CHAT_ROUTER:AddSystemMessage("[LibInteriorDetection] Usage: /lid debug hud on|off | /lid debug saved | /lid debug flip | /lid debug trace on|off | /lid debug houses")
end

-------------------------------------------------------------------------------
-- SETTINGS MENU (LibAddonMenu-2.0)
-------------------------------------------------------------------------------
local function BuildSettingsMenu()
    -- LibAddonMenu-2.0 is a hard ## DependsOn requirement as of this
    -- version, so LibAddonMenu2 is guaranteed to exist here.
    local LAM = LibAddonMenu2

    local panelData = {
        type        = "panel",
        name        = "LibInteriorDetection",
        displayName = "LibInteriorDetection Settings",
        author      = "@Kreksar5 and Claude.ai",
        version     = tostring(LIB_VERSION),
        website     = "",
        slashCommand = "/lidsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel(ADDON_ID .. "Panel", panelData)

    -- Build the zone picker directly from THIS library's own ZONE_INTERIOR
    -- table, not from ESO's GetNumZones()/GetZoneId() enumeration (as
    -- LibZoneTemp's picker does) - that enumeration does not cover the
    -- delve/dungeon zoneIds this table specifically tracks. Names are
    -- resolved via the confirmed native GetZoneNameById(zoneId); a handful
    -- of entries may not resolve to a name via this function and fall
    -- back to "Zone <id>" display text.
    local zoneChoices    = {}
    local zoneChoiceKeys = {}

    local sorted = {}
    for zoneId in pairs(ZONE_INTERIOR) do
        local zName = GetZoneNameById(zoneId)
        if not zName or zName == "" then
            zName = "Zone " .. tostring(zoneId)
        end
        sorted[#sorted + 1] = { id = zoneId, name = zName }
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    for _, entry in ipairs(sorted) do
        zoneChoices[#zoneChoices + 1] = entry.name
        zoneChoiceKeys[#zoneChoiceKeys + 1] = entry.id
    end

    local selectedZoneIdx = 1
    local OVERRIDE_CHOICES = { "Use Zone Default", "Force Interior", "Force Exterior" }

    local function GetOverrideChoiceForSelected()
        local zId = zoneChoiceKeys[selectedZoneIdx]
        if not (lib.savedVars and lib.savedVars.zoneOverrides) then
            return OVERRIDE_CHOICES[1]
        end
        local override = lib.savedVars.zoneOverrides[tostring(zId)]
        if override == true then
            return OVERRIDE_CHOICES[2]
        elseif override == false then
            return OVERRIDE_CHOICES[3]
        end
        return OVERRIDE_CHOICES[1]
    end

    local optionsData = {
        {
            type = "header",
            name = "Door Detection",
        },
        {
            type = "slider",
            name = "Door Watch Window (seconds)",
            tooltip = "How long after your last interaction (a door, a chest, etc.) the " ..
                      "library keeps watching for the sudden position jump a door makes. " ..
                      "A door is counted the moment it lands, so this only needs to be longer " ..
                      "than your slowest door - it does not delay detection.",
            min = DOOR_WATCH_SECONDS_MIN,
            max = DOOR_WATCH_SECONDS_MAX,
            step = 1,
            getFunc = function()
                return (lib.savedVars and lib.savedVars.doorWatchSeconds) or DOOR_WATCH_SECONDS_DEFAULT
            end,
            setFunc = function(value)
                if lib.savedVars then
                    lib.savedVars.doorWatchSeconds = value
                end
            end,
            default = DOOR_WATCH_SECONDS_DEFAULT,
        },
        {
            type = "slider",
            name = "Door Transition Distance Threshold",
            tooltip = "How far the player's raw position must jump between two samples 0.25s apart (raw world units - " ..
                      "centimeters) to count as a door transition or teleport. Running " ..
                      "and riding never come close per sample. Lower values catch smaller moves but risk false positives; " ..
                      "higher values are more conservative.",
            min = DOOR_DELTA_THRESHOLD_MIN,
            max = DOOR_DELTA_THRESHOLD_MAX,
            step = DOOR_DELTA_THRESHOLD_STEP,
            getFunc = function()
                return GetDoorDeltaThreshold()
            end,
            setFunc = function(value)
                if lib.savedVars then
                    lib.savedVars.doorDeltaThreshold = value
                end
            end,
            default = DOOR_DELTA_THRESHOLD_DEFAULT,
        },
        {
            type = "header",
            name = "Zone Interior/Exterior Overrides",
        },
        {
            type = "description",
            text = "Pick a zone below and force it to Interior or Exterior, overriding the " ..
                   "library's built-in default for that zone. Set back to 'Use Zone Default' " ..
                   "to remove the override.",
        },
        {
            type = "description",
            text = function()
                if not (lib.savedVars and lib.savedVars.zoneOverrides) then
                    return "No overrides set."
                end

                local entries = {}
                for svKey, isInterior in pairs(lib.savedVars.zoneOverrides) do
                    local zId = tonumber(svKey)
                    local zName = (zId and GetZoneNameById(zId))
                    if not zName or zName == "" then
                        zName = "Zone " .. svKey
                    end
                    entries[#entries + 1] = {
                        name = zName,
                        text = string.format("  %s: %s", zName, isInterior and "Interior" or "Exterior"),
                    }
                end

                if #entries == 0 then
                    return "No overrides currently set."
                end

                table.sort(entries, function(a, b) return a.name < b.name end)

                local lines = {}
                for _, entry in ipairs(entries) do
                    lines[#lines + 1] = entry.text
                end
                return table.concat(lines, "\n")
            end,
        },
    }

    if #zoneChoices > 0 then
        optionsData[#optionsData + 1] = {
            type    = "dropdown",
            name    = "Zone to Override",
            tooltip = "Choose which zone to override the interior/exterior default for.",
            choices = zoneChoices,
            getFunc = function()
                return zoneChoices[selectedZoneIdx] or zoneChoices[1]
            end,
            setFunc = function(value)
                for i, name in ipairs(zoneChoices) do
                    if name == value then
                        selectedZoneIdx = i
                        break
                    end
                end
            end,
            default = zoneChoices[1],
        }

        optionsData[#optionsData + 1] = {
            type    = "dropdown",
            name    = "Override",
            tooltip = "Force the selected zone's interior/exterior state, or use the library default.",
            choices = OVERRIDE_CHOICES,
            getFunc = GetOverrideChoiceForSelected,
            setFunc = function(value)
                if not lib.savedVars then return end
                local zId = zoneChoiceKeys[selectedZoneIdx]
                local svKey = tostring(zId)
                if value == "Force Interior" then
                    lib.savedVars.zoneOverrides[svKey] = true
                elseif value == "Force Exterior" then
                    lib.savedVars.zoneOverrides[svKey] = false
                else
                    lib.savedVars.zoneOverrides[svKey] = nil
                end
                -- If the player is currently in the zone being overridden,
                -- re-apply immediately rather than waiting for the next
                -- zone change.
                if lib.state.zoneId == zId then
                    lib.state.zoneDefaultInterior = lib.IsZoneInterior(zId)
                end
            end,
            default = OVERRIDE_CHOICES[1],
        }

        optionsData[#optionsData + 1] = {
            type    = "button",
            name    = "Clear All Overrides",
            tooltip = "Removes every zone interior/exterior override, reverting to library defaults.",
            func    = function()
                if lib.savedVars then
                    lib.savedVars.zoneOverrides = {}
                end
            end,
            isDangerous = true,
        }
    else
        optionsData[#optionsData + 1] = {
            type = "description",
            text = "|cFF4444Warning:|r No zone data available. Override controls are unavailable.",
        }
    end

    LAM:RegisterOptionControls(ADDON_ID .. "Panel", optionsData)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
local function Initialize()
    -- Account-wide: preferences and zone overrides shared across characters.
    lib.savedVars = ZO_SavedVars:NewAccountWide(
        "LibInteriorDetectionSavedVars",
        1,
        GetWorldName(),
        ACCOUNT_DEFAULTS
    )

    -- Character-specific: last known position/state for logout/login
    -- persistence. Built from NewAccountWide (already confirmed working
    -- above) with an explicit namespace combining server + character,
    -- rather than ZO_SavedVars:NewCharacterIdSettings - that function was
    -- flagged as not independently re-verified when first written, and is
    -- the prime suspect for why per-character persistence wasn't actually
    -- working: passing GetWorldName() as its namespace argument may not
    -- do what a NewAccountWide-style namespace does, potentially leaving
    -- data scoped by server only, shared across every character on it.
    -- This construction is fully self-evident instead: one account-wide
    -- SavedVariables table, with a namespace string built from GetWorldName()
    -- (server) and GetCurrentCharacterId() (character) concatenated together,
    -- both individually confirmed/well-established functions.
    local charNamespace = GetWorldName() .. "_" .. tostring(GetCurrentCharacterId())
    lib.charSavedVars = ZO_SavedVars:NewAccountWide(
        "LibInteriorDetectionCharSavedVars",
        1,
        charNamespace,
        CHARACTER_DEFAULTS
    )

    CreateHud()
    HookInteraction()
    HookReticleText()
    HookFastTravel()
    HookWorldMapScene()

    -- Event registration happens BEFORE BuildSettingsMenu() deliberately.
    -- Before 0.5.3, these were registered after the settings panel was
    -- built; if BuildSettingsMenu() ever threw a runtime error (something
    -- luac5.4 -p cannot catch, since it only checks syntax), Initialize()
    -- would halt right there and these registrations - the entire live
    -- indoor/outdoor detection system - would silently never happen. Core
    -- detection should not be able to fail just because the settings UI
    -- has a problem.
    EM:RegisterForEvent(LIB_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(LIB_NAME, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
    EM:RegisterForEvent(LIB_NAME .. "_LockpickBegin", EVENT_BEGIN_LOCKPICK, OnLockpickBegin)
    EM:RegisterForEvent(LIB_NAME .. "_LockpickSuccess", EVENT_LOCKPICK_SUCCESS, OnLockpickSuccess)
    EM:RegisterForEvent(LIB_NAME .. "_LockpickFailed", EVENT_LOCKPICK_FAILED, OnLockpickEnded("FAILED"))
    EM:RegisterForEvent(LIB_NAME .. "_LockpickBroke", EVENT_LOCKPICK_BROKE, OnLockpickEnded("BROKE (pick broke, minigame may continue)"))

    SLASH_COMMANDS["/amioutside"] = SlashAmIOutside
    SLASH_COMMANDS["/lid"] = SlashLid

    -- Deliberately last: if this errors, everything above has already
    -- succeeded and core detection keeps working regardless. Wrapped in
    -- pcall so a settings-menu bug surfaces as a readable chat message
    -- instead of silently eating the rest of Initialize() the way it did
    -- before 0.5.3.
    local settingsOk, settingsErr = pcall(BuildSettingsMenu)
    if not settingsOk then
        CHAT_ROUTER:AddSystemMessage(
            "[LibInteriorDetection] Settings menu failed to build: " .. tostring(settingsErr)
        )
    end
end

local function OnAddOnLoaded(event, name)
    if name ~= LIB_NAME then
        return
    end
    EM:UnregisterForEvent(LIB_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EM:RegisterForEvent(LIB_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
