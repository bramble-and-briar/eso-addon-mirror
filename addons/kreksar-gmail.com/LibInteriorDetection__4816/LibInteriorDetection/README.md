[size=6][b]LibInteriorDetection[/b][/size]
[i]by @Kreksar5 and Claude.ai[/i]

[color=orange][b]AI-ASSISTED ADDON.[/b][/color] Written with Claude.ai. Reviewed and tested in-game by the author — see the Design Notes section below for what has and hasn't been specifically verified.

A library for [i]The Elder Scrolls Online[/i] that reports whether the player is currently indoors, combining a per-zone "interior" default with live door-transition and map-teleport toggles for the cases that produce no zone change and no reliable event at all, plus an optional on-screen HUD.

For the full version history, see the Change Log tab, or CHANGELOG.md included in the download.

[size=5][b]Overview[/b][/size]

The ESO addon API has no function that reports whether a zone is indoors or outdoors, and no function that exposes world geometry, collision, or occlusion data of any kind — see Design Notes below for what was actually investigated and ruled out before landing on this approach. LibInteriorDetection works around that gap with three layers:

[list=1]
[*]A [b]static per-zone default[/b] (interior/exterior), looked up whenever the player enters a new zone.
[*]A [b]live door-transition toggle[/b] that flips the flag when the player crosses through an ordinary building doorway that produces no zone change and no reliable event at all — the case the static table alone cannot see.
[*]A [b]map-teleport check[/b] that resets the flag to the zone default when the player fast-travels via the world map to a different part of the SAME zone — a case that fires neither a zone-change event nor a door interaction.
[/list]

[size=5][b]Client Language Support[/b][/size]

Zone lookups are keyed entirely by real, language-independent [b]zoneId[/b] — never by zone name, and never resolved from one at runtime. The only zone name shown to the player is display text (the [code]/amioutside[/code] diagnostic line), sourced directly from ESO's own native [code]GetZoneNameById(zoneId)[/code].

[b]The HUD text itself is not localized.[/b] Unlike LibZoneTemp's fully language-independent design, the on-screen "INDOORS" / "OUTDOORS" labels and all slash command chat output in this library are hardcoded English strings. This is a real gap, not an oversight being hidden — flagged here so it isn't mistaken for the same client-language coverage LibZoneTemp provides.

[size=5][b]Features[/b][/size]

[list]
[*][b]Per-zone interior/exterior defaults[/b] for all 1,053 zoneIds LibZoneTemp v2.3.15 tracks — overland zones, delves, dungeons, trials, and player houses
[*][b]Live door-transition toggle[/b] for ordinary building interiors with no zone/map change, ported from the DoorDeltaTest diagnostic addon, including doors entered by picking the lock
[*][b]Map-teleport check[/b] that resets to the zone default when the player fast-travels to a different part of the same zone — covering wayshrine travel, player-house map travel, and a general world-map-open/close fallback for cases where the specific triggering function isn't known
[*][b]Logout/login persistence[/b] — normally, a player who logs out inside an interior pocket of an exterior-default zone and logs back into the same spot stays flagged interior; a known gap exists for some cases after a long offline gap specifically (see Design Notes) — `/lid debug flip` is available as a manual workaround
[*][b]Settings panel[/b] — configurable door watch window, door-transition distance threshold, per-zone interior/exterior overrides
[*][b]Debug-only on-screen HUD[/b] showing live INDOORS/OUTDOORS status, off by default
[*][b]Slash commands[/b] — [code]/amioutside[/code], [code]/lid debug hud on|off[/code], [code]/lid debug saved[/code], [code]/lid debug flip[/code], [code]/lid debug trace on|off[/code]
[/list]

[size=5][b]Dependencies[/b][/size]

Please install the newest available version of each:

[list]
[*][url=https://www.esoui.com/downloads/info1496-LibZone.html][b]LibZone[/b][/url] — reports the player's current zoneId/parentZoneId
[*][url=https://www.esoui.com/downloads/info7-LibAddonMenu.html][b]LibAddonMenu-2.0[/b][/url] — settings panel UI
[/list]

Both are hard dependencies — ESO will refuse to load LibInteriorDetection at all if either is missing. LibAddonMenu-2.0 is a new requirement as of v0.5.0.

[size=5][b]Installation[/b][/size]

[list=1]
[*]Download and unzip LibInteriorDetection into your addons folder:
[code]<ESO User Data>\live\AddOns\LibInteriorDetection\[/code]
The folder should contain:
[code]LibInteriorDetection/
├── LibInteriorDetection.lua
├── LibInteriorDetection.txt
├── CHANGELOG.md
└── README.md[/code]
[*]Ensure LibZone is also installed — always use the newest available version.
[*]Launch ESO. LibInteriorDetection will initialise automatically on the EVENT_ADD_ON_LOADED event.
[/list]

[size=5][b]Public API[/b][/size]

[code]
-- Returns the player's current LIVE indoor state (combines zone default +
-- door toggle). Returns nil if state hasn't been established yet (before
-- the first EVENT_PLAYER_ACTIVATED).
local isInterior = LibInteriorDetection.IsPlayerIndoors()

-- Returns the CURRENT ZONE'S static default only, ignoring the live
-- toggle. Useful for diagnosing when the two have diverged.
local isInterior, zoneId, isKnown = LibInteriorDetection.GetCurrentZoneInterior()

-- Returns the static default for an arbitrary zoneId.
local isInterior, isKnown = LibInteriorDetection.IsZoneInterior(zoneId)
[/code]

[size=5][b]Slash Commands[/b][/size]

[list]
[*][b]/amioutside[/b] — prints the live state as true/false, plus a diagnostic line with zone name, zoneId, the zone's static default, the current door-delta threshold, and the current door watch window
[*][b]/lid debug hud on|off[/b] — shows/hides the on-screen debug HUD. Off by default; state persists across relogs (account-wide) but is deliberately not exposed in the settings menu
[*][b]/lid debug saved[/b] — dumps saved-vs-current raw zoneId/position/state, for diagnosing a failed restore-on-login
[*][b]/lid debug flip[/b] — inverts the live indoor/outdoor flag for the current session only (not persisted); a manual workaround if the automatic detection ever gets it wrong, overridden normally by the next real zone change, door interaction, or map teleport
[*][b]/lid debug trace on|off[/b] — logs every change to the indoor/outdoor flag to chat (which mechanism made it, a timestamp, and the measured distance), plus every interaction, door-check result, travel trigger, and zone (de)activation. For diagnosing unexpected flips from real data. Off by default; persists across relogs (account-wide), not exposed in the settings menu. Chatty while on - turn it off when done
[/list]

[size=5][b]Settings Panel[/b][/size]

Access via [b]/lidsettings[/b] or [b]Settings → Addons → LibInteriorDetection Settings[/b]:

[list]
[*][b]Door Watch Window (seconds)[/b] — slider, 5-20, default 10. How long after your last interaction the library keeps watching for the sudden position jump a door makes. A door is counted the moment it lands (the trace reports how long each door took), so this only needs to exceed your slowest door; it does not delay detection. Replaced the fixed Door Check Delay in 1.3.0.
[*][b]Door Transition Distance Threshold[/b] — slider, 1000-8000 raw world units (10m-80m), default 2000 (20m). How far the player's raw position must move after an interaction to count as a door transition.
[*][b]Zone to Override[/b] / [b]Override[/b] — pick any zone from the library's own 1,053-entry table and force it to Interior, Exterior, or back to the library default. A live list shows every override currently set, and a "Clear All Overrides" button resets them all.
[/list]

[size=5][b]How the Door Toggle Works[/b][/size]

[code]
On EVENT_PLAYER_ACTIVATED (a real zone change):
  liveFlag = zone's static default        -- always wins, resets mid-toggle state

If zone default is INTERIOR:
  liveFlag stays true                     -- door interactions tracked but never flip it

If zone default is EXTERIOR:
  liveFlag starts false
  each detected door transition flips it  -- interaction (or lockpick
                                           -- success), then a single
                                           -- same-zone position JUMP over
                                           -- threshold between two samples
                                           -- 0.25s apart, within the watch
                                           -- window
[/code]

[b]Known limitation:[/b] this assumes symmetric in/out door pairs. A player going tavern → basement → tavern → street (three real door crossings from one exterior-default zone) desyncs the flag, since nested interiors aren't tracked as a stack in this version.

[size=5][b]Zone Data Coverage & Confidence[/b][/size]

The 1,053 zoneId entries were classified in four tiers of decreasing/increasing confidence, recorded per-line in the source as a trailing comment:

[list]
[*][b]90 zones[/b] — [i]known-zone / known-name[/i]: author's direct game knowledge (overland zones, well-known named dungeons/delves)
[*][b]499 zones[/b] — [i]notes:interior / notes:exterior[/i]: derived from real UESP-verified descriptive text (see Design Notes)
[*][b]98 zones[/b] — [i]keyword[/i]: the bare zone name contains a clear structural word (cave, crypt, sewer, island, valley, etc.) with no descriptive note available
[*][b]366 zones[/b] — [i]verified[/i]: individually researched and confirmed by the author, either via web research or direct game knowledge — the highest-confidence tier alongside tier 1
[/list]

Final split: [b]671 interior / 382 exterior[/b].

[b]Note on "tested in-game":[/b] the detection mechanism itself (zone-change handling, the door toggle, the map-teleport check, and logout/reload persistence) has been directly tested and confirmed working in-game across all of its documented cases. The 1,053 zone classifications above have NOT been individually walked in-game one by one — tiers 1-3 remain lore/naming-derived judgment calls, and tier 4 was verified via web research or direct game knowledge rather than an in-game visit to each zone. Treat a specific zone's classification as correctable, not as verified fact, and use the settings-menu override if one is wrong for you.

[size=5][b]Design Notes[/b][/size]

[b]Why is there no live "is indoors" signal at all?[/b] Extensively investigated and ruled out before building this library: ESO exposes no raycasting, collision, or terrain-height query to addons; no multi-floor map layer system (unlike some other MMOs); no ambient-audio query API; and `GetMapContentType()`/`GetCurrentZoneHouseId()` only cover dungeons and player houses specifically, not ordinary buildings. The three-layer design here (static zone table, live door toggle, map-teleport check) is the result of working through each of those dead ends in turn.

[b]Why is the zone table a judgment call and not verified data?[/b] There is no ESO API for this at all, so — same as LibZoneTemp's static weather-probability table — this is authored, not read from a game source. Where LibZoneTemp's temperature values are lore-derived climate estimates, this library's interior/exterior flags are lore-derived enclosure judgments. Every zoneId itself, however, IS real and verified: pulled directly from LibZoneTemp v2.3.15's own audited tables.

[b]Known recurring failure mode, found and fixed once already:[/b] the notes-based tier (499 zones) can misfire when a descriptive note's first sentence describes the location's [i]setting[/i] rather than its own structure — e.g. "A player house in Daggerfall, near the docks" triggered "docks" as an exterior signal for what is, architecturally, an indoor house. Found and corrected 14 such cases across every "player house/home" entry as of this version. The same failure mode may exist uncaught in other structure categories (chapels, garrets, studies, etc.) that weren't specifically audited — flagged here rather than assumed fixed everywhere.

[b]Known residual gap:[/b] zones in the "Black Marsh" province can trigger a "marsh" exterior-keyword false positive from the province name itself rather than the location's own terrain. Checked all 21 affected zones by hand — none actually changed classification because of it in the current table, but this has not been proven safe in general.

[b]Why does the door toggle only fire on interaction, not continuously?[/b] Hooking `INTERACTIVE_WHEEL_MANAGER.StartInteraction` catches the moment a player opens a door; polling position continuously would be far more expensive for no real benefit, since a position jump without an interaction immediately beforehand isn't a door crossing.

[b]Why doesn't the door toggle also catch a same-zone map teleport?[/b] It's gated on an interaction, and a remote map click isn't one. Testing confirmed this case doesn't fire `EVENT_PLAYER_ACTIVATED` either, unlike a cross-zone teleport or entering a full-zone-change location. Three complementary trigger sources feed a single check: `FastTravelToNode(...)` for wayshrine-style map travel (sourced from a decade-old ESOUI forum thread, confirmed correct in-game), `RequestJumpToHouse`/`JumpToHouse`/`JumpToSpecificHouse` for player-house travel (confirmed real via UESP's own API export data), and a world-map-open/close watcher as a more general fallback for cases where the specific internal function isn't known or hookable (e.g. a house's exterior-door sub-option, which fires none of the other three). All feed the same reset-to-zone-default check rather than toggling, since a teleport (unlike a door) isn't symmetric and can land the player anywhere regardless of their prior state.

[b]Why does the check poll for up to 15 seconds instead of a fixed delay?[/b] Testing revealed ESO's "Recall" ability (used for any world-map-initiated travel, to either a wayshrine or a house) is an 8-second cast, not instant — but standing physically at a wayshrine and picking another one skips that cast entirely. The four hooked functions and the world-map watcher all fire at actual-teleport-execution time regardless of which case applies, so a fixed delay tuned for the instant case would be too early for the cast-gated one. A bounded poll (every 0.25s since 1.2.3, looking for a single sudden jump between samples, stopping as soon as one appears or the window expires) is robust to not knowing which case applies in advance, without needing a third delay-tuning guess after the first two (1-5s, then 3-13s) both proved wrong for at least one real scenario.

[b]How are player houses classified? (1.3.2)[/b] By the game's own data rather than a hand-maintained list: a house that supports Weather Control counts as exterior, any other house as interior. This is the same "Supports Weather Control" property the housing book shows, read at load time, so new houses are covered automatically. A short built-in exception list (1.3.3) covers houses where the flag doesn't match the home's actual layout - e.g. Snugpod supports weather but is entirely indoors. A per-zone override in the settings still wins over both. [code]/lid debug houses[/code] prints how many houses were found and lists any whose classification changed from the old built-in table.

[b]What happens when I log out in someone else's house, a dungeon or a trial? (1.3.1)[/b] ESO doesn't put you back there - it returns you to where you stood before entering, which may be inside a building of an exterior zone. The normal logout save only knows about the house or instance, so before 1.3.1 you got the zone's default (often "outdoors" while standing indoors). Now, whenever you leave a normal zone, the library also saves a "return point" (position + state) that houses, group instances and battlegrounds never overwrite, however many you hop through. Arriving from one of those back near the return point (same zone, within ~50m) restores that state. This also covers being removed from a group instance without logging out. Confirmed for houses, group dungeons and trials; battlegrounds are included by analogy.

[b]Why does the door check watch for a jump instead of comparing two positions? (1.3.0)[/b] Until 1.2.6 it compared the position at the interaction with the position a fixed delay later. Traces showed two problems with that: some doors (Daggerfall Cathedral) take longer than 3 seconds to move the player, so the check fired before the move and the entry was missed; and sprinting or riding after any interaction could add up to the 20m threshold. A door moves the player in one step, so sampling every 0.25s and looking for a single jump catches slow and fast doors alike, and ordinary movement never comes close. Each interaction adds one "credit" and each counted jump spends one, so a stray jump with no interaction behind it is ignored; a jump within 1.5s of a counted one is also ignored in case a landing ever settles in two steps (unverified - a guess, logged when it happens).

[b]Why is the logout/login persistence character-specific, not account-wide?[/b] A saved position only means something for the character that was actually standing there. Account-wide storage (as LibZoneTemp uses for its temperature overrides, a genuine cross-character preference) would let one character's last position leak into a different character's login, producing a wrong restore rather than no restore at all.

[b]How is per-character persistence actually implemented?[/b] Via the same `ZO_SavedVars:NewAccountWide` call already used for the account-wide settings table, but with an explicit namespace string combining `GetWorldName()` (server) and `GetCurrentCharacterId()` (character) — `"<server>_<characterId>"`. An earlier version (0.5.0–0.6.0) used `ZO_SavedVars:NewCharacterIdSettings` instead, passed `GetWorldName()` as its namespace by analogy with the account-wide call; that function's exact parameter semantics were never independently confirmed, and it's the likely reason per-character persistence was reported not working — plausibly leaving data scoped by server only, shared across every character on it. The current construction avoids relying on that function's assumed behavior, using only individually well-established primitives instead.

[b]Why 50 raw units (0.5m) as a position-match tolerance again, after saying it didn't work?[/b] Position-matching across a genuine relogin was abandoned in 0.6.7 for the reason still true today — ESO does not reliably restore exact raw coordinates across a real login, confirmed in testing (positions differed by tens of meters despite no movement). But 0.6.7's `initial`-only design turned out not to cover `/reloadui`: testing confirmed `initial` reads **false** for a reload, not true. A reload is the opposite case from a login, though — the player never leaves the 3D world, so position genuinely should be exact or near-exact if unmoved. 0.6.9 combines both signals: restore if the saved zoneId matches AND EITHER `initial` is true (trust the saved flag, ignore position — a real login) OR the position is within this tolerance (a reload that provably didn't move). A same-zone teleport fails both simultaneously — not a login, and genuinely far from the saved spot — so it still correctly resets to the zone default instead of carrying over a stale flag.

[b]Known gap: restore-on-login can fail for an interior sub-space of an exterior zone, specifically after a long offline gap.[/b] Reported directly: a player logged out inside an interior pocket of an otherwise-exterior zone, was offline for several hours, and logged back in showing as exterior rather than interior. The restore in `OnPlayerActivated` gates entirely on the saved raw zoneId matching the current one when `initial` is true — position isn't even checked in that branch, per the design above. If that raw-zoneId match fails for this specific case (not confirmed exactly why — possibly something about how ESO re-establishes a player's position in a sub-space-style interior specifically, as opposed to a fully separate zone, after an extended absence), the fallback is the zone's own default classification. For an interior pocket that shares its LibZone-scheme zoneId with its exterior parent (plausible given the established raw-vs-LibZone-scheme zoneId divergence this whole project has repeatedly run into), that default reads exterior, with no other signal to catch it — unlike a true separate interior zone (a dungeon, a player house), which would still classify correctly from its own zone default even if the restore itself fails. `/lid debug saved` (added in 1.1.0) now surfaces the saved-vs-current raw zoneId directly so this can be confirmed with real data next time, rather than guessed at; `/lid debug flip` provides an immediate manual workaround in the meantime.

[size=5][b]For Addon Authors[/b][/size]

[code]
-- Minimal usage: check if the player is currently indoors
if LibInteriorDetection.IsPlayerIndoors() then
    -- apply indoor-only gameplay logic
end
[/code]

[size=5][b]Disclaimer[/b][/size]

This Add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
