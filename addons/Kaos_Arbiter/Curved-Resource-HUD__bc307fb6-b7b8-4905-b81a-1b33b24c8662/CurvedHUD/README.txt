Curved Resource HUD 1.1.3

Upload CurvedHUD as one folder with CurvedHUD.addon at its root.
The package contains exactly one .addon manifest, as required by the console uploader.

Settings libraries are optional by design:
- LibAddonMenu-2.0
- LibHarvensAddonSettings (listed as LibVotans in the Bethesda.net console store)

If neither library loads, the HUD still renders. Chat commands:
  /curvedhud preview  - toggle fixed test values
  /curvedhud debug    - toggle diagnostic logging
  /curvedhud report   - print release diagnostics and the latest guarded error
  /curvedhud          - show version/load status

0.7.0 includes ESO-style gradient fills for Health, Stamina, and Magicka. The
"Show default ESO resource bars" setting can hide the stock player resource
frame; while hidden, ESO's self-buff row moves down into the available space.

Expected startup chat line:
  [CurvedHUD] Loaded 1.1.3; HUD, shield, and trackers created

1.1.3 updates CurvedHUD for ESO Update 51. Nothing Wasted now uses its new
12-second decay window, and Imbue Weapon and its morphs use their new six-second
activation window. Retired Sorcery and Prophecy tracker selections are migrated
to Brutality and Savagery, and Illuminate reflects its new unique Armor bonus.

1.1.2 makes Soul Burst tracking script-aware. When Anchorite's Potency is
equipped, the tracker follows its separate five-second Soul Gem/Ultimate
lockout, ignores the damage-shield and Minor Courage durations, and does not
restart on ineligible casts. Without Anchorite's Potency, Soul Burst uses its
API-reported effect duration or the character's configured fallback duration.

1.1.1 refines the consolidated settings hierarchy so only the seven primary
category headers are blue. Individual classes, skill lines, and item-set
families retain their own collapsed submenus with standard-colored titles.

1.1.0 consolidates CurvedHUD into one settings entry. Seven blue category
headers organize ordinary-colored collapsed LibVotans submenus for global HUD
and appearance, buffs, individual classes, weapon lines, guild and other skill
lines, armor skills, and item-set families. The session-safe HUD reuse,
one-time settings registration, and scene-callback protections remain in place.

1.0.8 fixes session accumulation during rapid character changes. CurvedHUD now
reuses its existing HUD controls, settings definitions, and scene callbacks
instead of recreating them for every character. Initial registration is also
distributed across fresh frames so it cannot exhaust ESO's shared add-on CPU
allowance while other add-ons are loading.

1.0.7 removes CurvedHUD's late settings registration. Its LibVotans pages now
register during the normal add-on initialization phase, matching established
add-ons and avoiding delayed AddAddon calls that rebuild the shared console
settings tables after every other add-on has finished. Supported AddSettings
batching and duplicate-page reuse remain enabled.

1.0.6 uses LibVotans' supported AddSettings batch API and makes registration
idempotent across character changes. Existing populated CurvedHUD pages are
reused instead of receiving another copy of every control, preventing the
session-wide menu registry from growing with each login. Fully restart ESO once
after installing this build to clear duplicate pages retained by older builds.

1.0.5 makes Contingency's priming phase effect-driven as well as its triggered
phase. The three persistent prepared-runes effects now establish and refresh
the primed state directly, allowing one-bar Contingency configurations to keep
working across weapon swaps and crafted action-slot ID changes.

1.0.4 tracks Ulfsild's Contingency through its complete generated effect-ID
family. The initial priming timer is replaced when ESO applies the triggered
signature or affix effect, using that effect's real begin and end times. If a
crafted combination applies several related effects, the tracker retains the
latest endpoint rather than continuing the original priming countdown.

1.0.3 corrects Ulfsild's Contingency trigger detection on console. The initial
cast still displays its priming window, while the next ability or hard action
now restarts the visible timer from the actual proc. Trigger recognition no
longer depends on a transformed crafted ability ID, and the applied Contingency
effect provides an authoritative fallback when the action-slot event is vague.

1.0.2 finalizes each of CurvedHUD's six native LibVotans settings pages once,
restoring every selectable settings page while retaining batched registration.
The library's console list is rebuilt six times rather than once per control,
avoiding both missing menus and the former rapid-character startup spike.

1.0.1 batches registration of CurvedHUD's six native LibVotans settings pages.
The library's console section list is now rebuilt once after every CurvedHUD
control has been added, instead of once per control. This removes the quadratic
startup spike that could exhaust ESO's shared 1000 ms add-on CPU budget during
rapid character changes and make whichever add-on ran next appear responsible.
The library method is restored even if page construction encounters an error.

1.0.1 corrects Ulfsild's Contingency's two-phase timer. The initial cast starts
the priming countdown, and the next action-slot ability restarts the countdown
from the moment the runes actually trigger. A guarded Magicka/Stamina-spend
fallback captures dodge rolls and other resource actions while ignoring the
priming cast's own delayed power event. This no longer relies on ESO returning a
nonzero cost for Scribing or transformed ability IDs.

1.0.0 divides the native LibVotans settings into focused selectable pages for
Global HUD, Class Timers, Weapon Timers, Guild & Other Timers, Armor Timers and
Item Set Timers. Every page clearly identifies whether its options are global
or character-specific. All classes remain together on the Class Timers page,
separated by blue class headings. This keeps the stable native console settings
path without restoring LibAddonMenu's costly console conversion step.

0.9.22 restores blue section headings in the native LibVotans settings menu and
moves HUD alignment, scale, spacing and appearance controls into their own
section instead of the Quest & Golden Pursuits section. Quest reduction now
includes the assisted quest title/header as well as objectives and details, and
refreshes late-created tracker controls while in combat or an instance.
Ulfsild's Contingency now begins with its priming window and restarts the timer
when the next qualifying resource-costing ability or dodge actually triggers it.

0.9.21 restores Encase, Vibrant Shroud and Shattering Spines tracking after the
periodic-tick safety changes. Direct action-slot and filtered combat events now
share one cast dispatcher, so legacy special cases cannot be skipped while the
table-driven class, weapon, guild, scribing and armor/set paths use a different
route. Morph-aware icons and API-reported full durations remain preserved.

0.9.20 bypasses LibAddonMenu's costly console-to-LibVotans option converter
when LibVotans is installed. CurvedHUD now registers directly with LibVotans,
while LibAddonMenu remains the fallback provider. This removes the recursive
conversion path shown in the CPU-budget traceback. Infrequent out-of-combat
memory maintenance also prunes expired set-effect records and performs a tiny
incremental garbage-collection step without forcing a full global purge.

0.9.19 restores Turning Tide's complete state cycle. Flowing Water displays the
green READY state, consuming it early with the activating Bash begins the full
15-second cooldown countdown, and allowing it to expire unused returns to WAIT.
All four upper tracker icons now share one vertical row and all four lower icons
share another, without altering their calibrated horizontal positions.

0.9.18 moves CurvedHUD's large console settings-tree construction out of the
shared add-on-load frame. Settings register twelve seconds after the character
becomes active, after Fancy Action Bar, LibAddonMenu/LibVotans and other large
add-ons have normally completed initialization. The HUD remains available
immediately; only opening CurvedHUD's settings is briefly delayed after login.

0.9.17 hardens repeated character loading against ESO's 1000 ms UI watchdog.
Inventory event bursts are debounced, activation work is coalesced, and learned
skill/icon discovery is processed in small delayed chunks. Fast timer animation
is separated from slower resource and buff checks, and recurring work waits one
second for the login scene and other add-ons to settle. No new textures or
persistent runtime caches are introduced.

0.9.16 clears enemy-bound timers when combat ends, matching ESO's removal of
hostile DoTs, ground effects, target debuffs and combat-only stacks. Carve also
forgets its accumulated 12/22/32-second tier so the next combat begins at 12.
Self-buffs, heals, shields, utility windows, readiness states and item-set
cooldowns remain untouched.

0.9.15 separates complete cast-owned durations from their periodic child ticks.
Short pulses, final ticks and their fade events can no longer restart, shorten or
clear an expiring parent timer. A later full-duration API endpoint can still
extend the timer when appropriate. Destruction Staff tracking now recognizes
the Fire, Frost and Storm variants of Wall of Elements and Elemental Blockade.

0.9.14 corrects Carve's stacking bleed timer. A fresh application starts at 12
seconds; recasting while it remains active advances it to 22 and then 32 seconds.
Duplicate reports for one cast are ignored. Brawler's short damage-shield effect
is excluded completely and cannot start, shorten, clear or replace this timer.

0.9.13 adds ID-first skill-family matching. Confirmed and automatically learned
ability IDs are persisted account-wide, slotted abilities can also bind through
language-independent icon paths, and localized API names remain the final
fallback. Successful fallback matches teach the ID for later casts and sessions.

Saved data now carries an explicit schema version. The first 0.9.13 load removes
obsolete letter-build calibration settings without resetting character tracker
choices, validates the icon/ID caches, and disables the former default debug
logging. `/curvedhud report` prints version/schema/API information, detected
menu libraries, layout, tracker counts, learned IDs, Lua memory and recent errors.

The Parallel outer resource radius is fixed at the selected 0.8 calibration.
Riding Stamina receives the same correction only while it occupies the outer
Parallel position; its inner and Stacked configurations remain unchanged.

The final Parallel outer-right timer radii are fixed at 0.8 for Thin and 0.5
for Thick. Their shared horizontal offset defaults to 3. Shared spacing defaults
to 3 for Thin, while Thick retains its tested built-in correction to -2.

0.9.12 treats Bar Width 72 as the calibrated timer-radius reference. All timer
textures now stretch or compress horizontally by the current Bar Width divided
by 72, keeping their curve radius aligned as the main HUD radius changes. HUD
Scale remains independent and therefore cannot double-apply this correction.

0.9.11 separates timer-group offset from inside/outside timer spacing. The
settings now expose only one offset and spacing pair for each side, while the
layout-specific curve geometry remains in its dedicated textures. Thin and thick
inside/outside radii were refined from the 0.9.10 screenshots, all thick bars
share the outer-left reference thickness. Upper outside textures retain their
complete caps, while their icons and timer labels now sit closer to the arcs.
The follow-up geometry revision increases both thin-left sweeps and substantially
increases thin-right sweeps, preserves the approved thick inner-left curve, and
separately tunes thick right Parallel and Stacked radii. Upper-outside textures
now retain padded semicircular endpoints, the two outer-right quadrants share
one horizontal baseline, and the Parallel outer resource arc nests more closely.
The memory guard remains definition-driven and lazy. Balance, Bound Aegis, Bound
Armaments, and Crystal Fragments now also allocate controls only when enabled.
Each instantiated timer references only its current side/layout/inside-outside/
thickness fill-and-frame pair, and unchanged layout refreshes skip texture calls.

0.9.10 isolates skill-family matching so partial words such as Carve inside Fate
Carver cannot cross class and weapon trackers. Pulsing effects retain their full
parent duration, while later endpoints extend stackable effects such as Carve.
Timer arcs now compensate for resource-bar width and provide separate left,
right-parallel, and right-stacked horizontal offsets. New characters begin with
all optional trackers disabled; existing character profiles remain unchanged.

0.9.9 keeps Turning Tide visible whenever at least three persistent set pieces
are equipped, supporting common front-bar-only configurations. Its icon displays
WAIT until Flowing Water is primed, READY only when both the block condition and
cooldown permit activation, and the cooldown after the set actually procs.

0.9.8 substantially reduces the add-on's idle memory footprint. The previous
build instantiated all class, weapon, guild, scribing, and 44 item-set trackers
at startup, including disabled choices. Definition-driven trackers are now
created only when enabled. Quest/Golden Pursuits controls are cached once and
their periodic opacity update no longer allocates temporary tables. Use
`/curvedhud memory` to report the instantiated tracker count and total ESO UI
Lua memory for before/after comparisons. Total Lua memory includes other add-ons.
The second optimization pass also creates Critical Surge, Vibrant Shroud, Crux,
and unused Major/Minor buff controls only when selected. This avoids paying for
their textures, labels, borders, and curved timer layers on characters that do
not use them.

0.9.7 separates live set-effect artwork from worn-item fallback artwork. Once
ESO supplies a valid buff, debuff, proc, or cooldown icon, equipment and weapon
bar refreshes can no longer replace it with an equipped staff, shield, weapon,
or armor icon. The rule applies to every item-set tracker; item artwork remains
only as the last fallback before a live effect has been observed.
This build also adds optional contextual opacity for ESO's focused Quest Tracker
and Golden Pursuits tracker. They can be reduced independently during combat
and while inside dungeons, trials, or Infinite Archive. An opacity of 0% hides
them completely; higher values leave them dimmed. Both behaviors default off.

0.9.6 separates active-bar set counts from overall equipped-set availability.
Sets completed by a front- or back-bar weapon, including Powerful Assault and
Turning Tide, remain eligible across weapon swaps. Two-handed weapons count as
two set pieces, inactive-bar items remain available, and an already-running
effect stays visible through its natural expiration even after a genuine
equipment change.

0.9.5 fixes repeated applications of group set effects such as Powerful Assault.
All duration sets now retain separate live instances per affected unit, ignore
stale fade events after a refresh, and clear every runtime state when unequipped.
The correction is shared by all item-set definitions rather than being specific
to Powerful Assault.

0.9.4 introduces character-specific item-set tracking organized into DPS,
Healer & Support, Tank, Arena Weapon, and Infinite Archive Class Set submenus.
Trackers support live durations, stack counts with expiration windows, cooldown
countdowns, green READY indicators, conditional Turning Tide readiness, and a
five-piece Jorvuld's Guidance ACTIVE indicator. ESO's live begin/end times are
used when available, so Jorvuld-extended Major/Minor buffs and shields retain
their actual extended durations rather than an unmodified fallback value.
The expanded composition pass adds Z'en's Redress, Elemental Catalyst, Roar of
Alkosh, Aegis Caller, Burning Spellweave, Briarheart, Vestment of Olorime,
Saxhleel Champion, Master Architect, War Machine, Drake's Rush, Arkasis's
Genius, Claw of Yolnahkriin, Encratis's Behemoth, Rush of Agony, and Dark
Convergence. Way of Martial Knowledge has a separate character-specific
Stamina cue: light green below 50% while procable and light red at or above
50%. The cue only applies with five pieces equipped and is disabled by default.
Set duration tracking now keeps separate live effect instances per affected
unit. A fade from one group member can no longer cancel a refreshed application
on another member, fixing repeated Powerful Assault casts and protecting every
other group-duration tracker from the same event-ordering problem.

0.9.3 expands standardized buff tracking to two independently selectable Major
buffs and two independently selectable Minor buffs. Each has its own timer
position and color and remains character-specific. The Equilibrium/Balance
penalty is now correctly located under Mages Guild. Additional optional negative
trackers cover Blood for Blood, Blood Frenzy, Nightblade Offering health drain,
and the short Unstoppable self-snare window. Self-penalties never trigger the
positive imminent-expiration warning.

0.9.0 completes the initial class-tracker framework with dedicated expandable
Dragonknight, Nightblade, Templar, and Necromancer submenus. Each tracker is
off by default and remains per-character, with its own position and color.
The new families cover actionable damage-over-time effects, buffs, defenses,
ground effects, summons, and stack windows. Stone Giant, Seething Fury, Grim
Focus, and Nothing Wasted include stack-count support. All new class families
use the shared resilient icon chain: equipped skill, ability data, learned
skill, live event artwork, then the last successfully cached icon.
Settings are grouped beneath blue character-specific section headers: Global
Timers, Class Timers, Weapon Timers, and Guild/Vampire/Werewolf Timers. Every
expandable tracker submenu beneath these headings stores its choices per character.

0.7.0 tracker framework additions:
- selectable standardized Major buff in the lower-left outside slot
- independent Thin/Thick styles for inside and outside timer slots
- color presets for the current Major buff, Balance, and Bound Aegis timers
- reusable inside/outside timer positions in all four HUD corners
- stack-count labels prepared over every tracker icon
- separate font-size controls for resource values and percentages
- revised inside/outside thick curves that follow the Health radius more closely
- optional Balance tracker under Global Trackers, with selectable slot and color
- optional Bound Aegis tracker under Sorcerer Trackers, with selectable slot and color
- per-character Major-buff and individual tracker choices; shared HUD geometry remains account-wide
- flattened tracker titles for console-safe settings controls
- global inside/outside thickness controls moved into the shared layout settings
- clean semicircular timer ends and a small inward adjustment for Thick timers
- corrected console dropdown display/internal-value mapping for tracker positions
- automatic repair of invalid position values saved by 0.6.1/0.6.2
- separately tuned upper-outside and lower-outside Thin timer geometry
- canonical lower-left curves mirrored vertically for upper slots and horizontally for right slots
- approved lower-left Balance geometry reused for every inside Thin tracker
- wider, more curved outside Thin geometry and closer right-side Thick placement
- resource-value visibility settings moved above the optional tracker controls
- inner Thick positions shifted farther inward without changing their curves
- outer Thin radius reduced and shifted inward, especially at its far endpoint
- both lower-right Parallel slots moved closer to the resource bars
- Stacked right slots now select their parent by upper/lower quadrant before radial placement
- corrected the visually reversed upper/lower parent controls in Stacked mode
- reversed inner Thick offsets toward screen center on both sides
- retained the outer Thin midpoint while drawing its far endpoint toward the resource curve
- moved inner Thick three pixels back from its over-corrected center position
- tightened the inner Thick radius while preserving its mirrored geometry
- reshaped outer Thin so its center-side end moves outward and its far end hugs the resource arc
- moved upper-right outside icons farther outward and lower-right inside icons farther inward
- relaxed inner Thick and outer Thin to intermediate radii while preserving midpoint anchors
- replaced skill-specific icon offsets with consistent mirrored inside/outside icon placement
- upper-inner icons moved eight pixels closer to their tracker/stat bars
- upper-outer icons moved sixteen pixels farther horizontally from screen center
- toggleable Bound Armaments stack/duration tracker using any of the eight timer slots
- per-character Bound Armaments position and color settings
- toggleable Crystal Fragments proc-ready alert with Top/Right/Bottom/Left/Center presets
- dual Crystal Fragments detection through effect 46327 and proc action ID 114716
- reusable HUD-relative proc-alert positioning framework for future class proc skills
- Crystal Fragments proc-size slider; the alert inherits the HUD's combat and out-of-combat opacity
- rotating gold/white Bound Armaments ready highlight at four weapon stacks
- toggleable Critical Surge timer using its unique self-buff
- toggleable Vibrant Shroud, Encase, and Shattering Spines timer with a 10-second cast fallback
- Vibrant Shroud timer prefers the slotted/cast skill artwork over Minor Vitality artwork
- guaranteed overlay-layer gold/white Bound Armaments ready border at four stacks
- right-side inside and outside timer bars moved closer to their resource arcs
- per-character Soul Burst and Ulfsild's Contingency trackers in a dedicated Scribing Skills section
- configurable position, color, and script-dependent duration for both scribing timers
- current cast artwork is retained for each character's scribed variant
- bundled console-safe icons for Soul Burst and Ulfsild's Contingency
- bundled individual icons for Vibrant Shroud, Encase, and Shattering Spines
- automatic scribed duration lookup from the equipped crafted ability, with the
  per-character duration setting retained as a fallback for unsupported scripts
- optional global imminent-expiration alerts: positive timers turn red and gain
  a pulsing red icon border at three seconds; negative Balance is excluded
- toggleable trackers for all eleven duration-capable Scribing grimoires, each with a bundled
  console-safe icon, one of eight positions, a color, and automatic configured
  duration lookup with a per-character fallback (the persistent Banner Bearer
  toggle is intentionally excluded because it has no recast-duration window)
- new Warden section with Betty Netch/Blue Betty/Bull Netch, Swarm/Fetcher
  Infection/Growing Swarm, and Scorch/Deep Fissure/Subterranean Assault
- Shalk timing covers both eruptions: 9 seconds for Scorch/Deep Fissure and
  6 seconds for Subterranean Assault before the suggested recast
- added Impaling Shards/Gripping Shards/Winter's Revenge, Lotus Flower/Green
  Lotus/Lotus Blossom, Healing Seed/Budding Seeds/Corrupting Pollen, and
  Crystallized Shield/Shimmering Shield/Crystallized Slab tracker families
- new Warden families resolve the equipped or learned morph's ESO icon at run time
- expanded Sorcerer tracking for Daedric Curse/Prey/Haunting Curse, Lightning
  Splash/Flood/Liquid Lightning, Volatile Familiar and Twilight Tormentor
  activations, Conjured Ward, Lightning Form/Hurricane, Dark Exchange, and
  Daedric Mines families; ultimate abilities remain intentionally excluded
- all definition-driven trackers now share a defensive icon chain: bundled
  artwork, equipped-slot texture, ability-ID texture, learned-skill texture,
  live event artwork, and finally the last valid cached texture
- added optional duration tracking across all six standard weapon lines:
  Two Handed, One Hand and Shield, Dual Wield, Bow, Destruction Staff, and
  Restoration Staff
- added optional Fighters Guild, Mages Guild, Undaunted, Psijic Order,
  Assault, Support, armor, Soul Magic, Vampire, and Werewolf timers
- reorganized customization in the order Class Skills, Weapon Skill Lines,
  then Guild / Other Skill Lines; each scribing grimoire now appears beneath
  the weapon, guild, Alliance War, or Soul Magic line that grants it
- instant-only abilities, passive-only bonuses, permanent toggles, and all
  ultimate abilities are intentionally excluded from selectable timers
- corrected the preceding weapon/guild build's release designation to 0.8.3
- added a dedicated Arcanist section with per-character position, color, and
  enablement settings for ten duration-based skill families
- added a paired Crux tracker occupying one selectable quadrant: the outside arc
  and icon show 1-3 stacks while the matching inside arc counts down the live
  expiration time reported by ESO
- Crux is read defensively from the player's live buff stack and uses ESO's
  Crux artwork when available, with the shared equipped/learned/cached icon chain
- Arcanist duration trackers cover Abyssal Impact, Tome-Bearer's Inspiration,
  The Imperfect Ring, Runic Jolt, Runespite Ward, Fatewoven Armor, Runic
  Defense, Rune of Eldritch Horror, Chakram Shields, and Arcanist's Domain
- customization now prefers LibAddonMenu-2.0 when available so every Global,
  class, weapon, guild, Alliance War, armor, world, and Scribing subsection is
  a real collapsible submenu instead of an always-expanded wall of controls
- LibHarvens/LibVotans remains a functional fallback and uses its native section
  controls because that provider does not expose nested child containers
- Light, Medium, and Heavy Armor trackers are consolidated into one Armor section
- Wield Soul and its Scribing fallback controls now appear under Soul Magic

Diagnosis of the silent v0.2 result:
The prior ZIP was not recoverable from the referenced task, so exact line-level attribution
is impossible. A complete no-HUD/no-menu result most strongly indicates that its add-on-loaded
handler never completed, commonly due to a manifest folder/name mismatch, a hard missing
dependency, an initialization-time Lua error, or controls anchored/hidden before player activation.
This build removes those failure modes by using optional dependencies, exact add-on-name gating,
protected initialization, explicit top-level controls, player-activation refresh, periodic resource
refresh, and visible chat/error reporting.

Packaging note: upload the CurvedHUD folder itself. Do not add an extra directory around it.
