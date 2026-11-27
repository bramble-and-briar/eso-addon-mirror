TAMRIEL UNBOUND v1.0.5 | PS5
v1.0.5: Revalidate live positions continuously, expire stale estimates, reject hidden controls, restore three-dimensional range and 18m vertical tolerance, explicit native coordinate conversion. Unmatched signals remain directional cues; no fabricated elevation. PS5 untested.
v1.0.4: Match spawn-filtered HarvestMap character profile: 100m world range, 1m width, 2m height, depth on, 7m match, 50ms position sampling, 3 stable samples, native detection 200m / measurement <190m. Reused native controls reset on appearance; harvested matched signals suppressed until lifecycle changes. Original aura texture and colors retained. Independent calibrated approximation, not HarvestMap source redistribution.
v1.0.3: Rank 30+ displays only live signals, including personally recorded locations. Rank 15–29 retains persistent memory markers. Saved records unchanged.
Less interface. More world.
Trash Man Enterprises

Hardcore Mode: survival, permadeath, ownership restrictions and skill progression.
Immersive Mode: unrestricted gameplay with rank-99 visual perks, normal inventory and banking. Enable per character through Settings or the setup prompt.
Upgrade over ESO Hardcore v0.9.50. Internal ESOHardcore folder, manifest identity and saved-variable names deliberately unchanged to retain existing progress. Do not install a second copy. /unbound and /hardcore both open the dashboard where slash commands are supported.
This is a branding release, not a gameplay fix. Existing camera, settings library and resource elevation limitations remain; live PS5 verification required. Imported resource data is for private testing pending redistribution permission.

v1.0.2: Fix zone-wide marker flood. Mastery uses live-confirmed imported sites within 200m, personal memories within 350m, and visible compass cues for unresolved live nodes. No marker-count cap. No guessed elevations. Original saved data preserved.

LEGACY CHANGELOG (historical entries may describe superseded behavior)

v0.9.49: Rank-15 personal resource auras persist at all later ranks, even when depleted. Live detection is additive; matching live and recorded sites share one marker. No marker-count cap. Existing saved locations retained.

v0.9.48: Direct console settings registration via LibHarvensAddonSettings (LibVotans console distribution), existing LAM fallback, and dependency-free dashboard Settings page (L1 from Skills). Camera module preserved from v0.9.46; PS5 camera API behavior remains unverified. HUD suppression preserved.

ESO Hardcore 0.9.44 | PS5
Five skills: Harvesting, Survivalist, Perception, Endurance, Combat Mastery.
Core inventory, banking, crafting materials, integrity and difficulty retained.
Skill alerts use fading tinted edge textures, not text panels. Perception is last-seen only, not live hidden enemy tracking.
LibRadialMenu optional; user-supplied resource coordinates included for level 99; compatible HarvestMap optional for additional data. No LibMapPins dependency. Disable HarvestMap own map, compass and world markers to preserve Hardcore unlocks.
Existing retained skill XP is preserved; retired skill XP and active assignments removed.
Live PS5 validation required.

Private test build: 1129 unique imported gathering locations across 16 zone IDs. No account settings included. Verify data redistribution rights before public release. Not a complete Tamriel database.

Spawn-only resource beacons require enabled NodeDetection (from HarvestMap). Without it no historical pins are shown. Level 99 shows live signals even without database matches, with estimated elevation. Native compass signals cannot confirm containers or fishing holes. Native uniform fatigue blur is fixed-strength; veil intensity scales. Directional alerts use current/recent reticle world coordinates only.

0.9.32: All positioned live signals at rank 99, no addon count or distance cap. Ranks 30/50/75: 120/220/350m configured radii, personal locations only. Native NodeDetection acquisition range remains limited (190m position measurement threshold in supplied version). Larger distance-scaled beacons for all sources; historical coordinates never establish spawn.

Native ResourceSense replaces external HarvestMap/NodeDetection dependency. Disable both when testing; they override the same compass pin type. Coordinates are estimates; imported locations supply elevation/type, not spawn verification.

0.9.32: Ground-anchored resource beacons. Live signals without a matching recorded elevation are not rendered; imported sites remain available at Harvesting 99. Independently fitted compass calibration. No HarvestMap code or marker assets added.

0.9.33: Isolate per-control measurement and rendering failures; refresh marker selection on native presence changes. Duplicate appearance callbacks no longer reset existing measurements.

0.9.37: Icon-free resource aura, distinct category colors, neutral unknowns. Recorded heights preferred; unmatched mastery signals use estimated elevation only within 8m. Detector unchanged.

0.9.37: Native compass description classification; larger icon-free auras; no 8m undocumented visibility cutoff. Unknown types use gold until identified. Approximate elevation may be inaccurate.

0.9.37: Crafting transactions retain the pre-craft snapshot and credit confirmed material outputs when consumed inputs are HC eligible. Previously missed output cannot be reconstructed automatically.

0.9.38: Separate 3D ground anchors and local aura offsets; explicit native world-to-render conversion. Reject suspect high or ambiguous elevation matches and retain colored compass cues at mastery. No change to detector, aura palette, range, crafting ledger or XP. Height verification is conservative, not a live terrain query.

0.9.39: Full-screen stamina veil from Endurance 15 below 45% stamina. Endurance 30 native uniform blur below 30%, refreshed every 0.75 seconds while active; immediate cleanup on recovery, menus and deactivation. Stronger veil as stamina falls. Native blur has fixed strength; PS5 rendering untested. Endurance reward reports include stamina and blur request diagnostics.

0.9.40: Correct native crafting result count API; match extraction/refinement material outputs by canonical item link ID with name/type fallback; delayed result retry; invalidate overlay cache. HC input eligibility still required.

0.9.41: guarded crafting result APIs and delayed callbacks, bounded ledger retries and recoverable inventory rendering errors.

0.9.42: Independent protected station-overlay refresh; live physical counts intersect existing HC ownership; recover on station reopen and draw errors; restore result-link/virtual-slot indexing. No reset; earlier missed credits are not reconstructed.

0.9.43: Honor-based crafting accounting. Completed crafting material gains credited regardless of input ownership or bank source; non-HC inputs still flagged. Actual gains lacking individual native result confirmation are credited and marked for review. No credit on failed crafts or ordinary inventory changes. No historical backfill. Overlay and inventory display code unchanged.

0.9.44: Rank 15–29 displays recorded personal 3D resource sites within 120m, including depleted sites; rank 30+ retains live spawn filtering. Existing 3D records are reused.

0.9.45: Optional Immersive Combat Camera, enabled by default for active HC characters. Ruleset page X toggles. First-person on combat entry, third-person after two seconds out of combat, with context guards and no repeated toggles. Native camera distance and toggle support on PS5 require live verification.

0.9.46: Combat camera event, bounded retries and diagnostics; optional LAM/LibGamepad settings panel. Console camera API behavior unverified.

0.9.47: Restore Hardcore quest tracker suppression and visually suppress compass via alpha while retaining its native resource observer. Restore prior alpha outside active gameplay.

0.9.50: Optional character-local Immersive Mode for non-HC characters. Rank 99 visual access without changing XP; normal inventory, bank, crafting, nutrition and death behavior. Enable via setup prompt or Settings. HUD, resource auras and fatigue independently configurable. Existing native camera and resource API limitations remain.
