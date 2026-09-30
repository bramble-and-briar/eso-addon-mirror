# Frostfall — Changelog

Full version history for Frostfall. See README.md for current features, installation, and usage.

---

### v3.4.34
- **Fixed the settings panel overwriting the global `Frostfall` table.**
  The LibAddonMenu panel was registered under the name `"Frostfall"`.
  LAM names the panel's control after it, and ESO exposes every named
  control as a global, so once the settings panel initialized, the
  global `Frostfall` was the panel control instead of the addon table.
  Frostfall itself was unaffected (it uses its local `FV` reference), but
  any other addon reading the global - notably Realistic Needs and
  Diseases' `Frostfall:GetEffectiveTemp()` and `Frostfall.State.isSwimming`
  - silently fell back to LibZoneTemp's raw ambient temperature, ignoring
  insulation, indoor shelter, and the spell-resist reagent buff. This is
  why RND could roll Frostbite in a sheltered, well-insulated spot.
- Panel renamed to `"FrostfallPanel"`, matching the `...Panel` naming the
  other addons in the suite already use. The panel's displayed title is
  unchanged. No other changes. **Not yet tested in-game.**

### v3.4.33
- **Fixed the rest-detection reticle hook reading the wrong argument.**
  `ZO_PreHook` passes the hooked method's `self` (`RETICLE`) first -
  confirmed in the ESOUI client source (`libraries/utility/zo_hook.lua`
  and `ingame/reticle/reticle.lua`, 12.0.8). The hook's
  `interactionPossible` parameter was actually receiving `RETICLE`, so it
  was always true. It now takes `(self, interactionPossible)`.
- **Clears the remembered prompt text when nothing is interactable.**
  Without this, fixing the argument alone would have let an old "Sit"
  prompt linger after looking away, so a later interact-key press with
  nothing targeted could wrongly start a seated rest.
- Found while reviewing LibInteriorDetection 1.2.5's identical hook. No
  other changes. Syntax-checked; **not yet tested in-game.**

### v3.4.32
- **Redesigned indoor shelter from a display-only mask to a real,
  accelerated recovery toward neutral.** Prompted by a follow-up report
  after v3.4.31: standing indoors near a cooking fire (a real, modest
  one-time +5°C warmth source) produced a misleadingly "perfect" 72°F
  effective reading, which then appeared to jump right back down the
  moment the player stepped outside - even though the true temperature
  barely changed either time. The old design steadied the *displayed*
  value only, capped at 15°C, completely independent of the true
  temperature underneath - so the display and the reality could diverge
  by a large margin, and reconciling them (by leaving the building)
  looked like a sudden, ungraduated jump even though nothing sudden had
  actually happened to the true temperature.
- **Indoor shelter is now a real, additional pull toward neutral (not
  ambient) applied directly to the player's true temperature** in
  `CalculatePlayerTemperature`, governed by a new
  `INDOOR_SHELTER_DRIFT_RATE` (3.0°C/min before insulation scaling,
  replacing the old `INDOOR_PROTECTION_MAX_SHIFT` 15°C display cap). It
  runs alongside the existing drift toward ambient, not instead of it -
  the two can reinforce each other or partially compete (a very cold
  room still pulls you cold even while sheltered), settling at whatever
  equilibrium the two forces reach together, rather than snapping
  straight to comfortable. Uses the same insulation-based rate curve
  (`ComputeDriftRate`) as the ambient drift, so better-insulated players
  still warm up faster than poorly-insulated ones even while sheltered.
- **Because the displayed value now always reflects the true state**,
  there's no more discontinuity when entering or leaving a building -
  only a faster or slower rate of change while the effect is active.
- `GetEffectiveTemp()` is back to handling only the spell-resist reagent
  mask, the single-effect shape it had before v3.4.25 - the v3.4.31
  combined-overshoot fix is now moot for this specific pairing, since
  shelter no longer contributes a display offset to stack with anything.
  **The spell-resist reagent buff itself is unchanged** - this was a
  deliberate, explicit request to redesign shelter specifically, not the
  reagent mechanic.
- Removed `FV.State.indoorProtectionOffset` (no longer a meaningful
  concept); `/ff status` and the HUD's "Sheltered" tag are updated to
  describe the new mechanic accurately.
- **Also fixed a stale doc/log discrepancy** found while investigating
  this report: the cooking-fire/forge warming comment and its debug log
  message both said "+10°C", but the code has always added `+5` (matching
  the README, which was already correct). Cosmetic only - no functional
  change, since the actual behavior was already the documented 5°C.

---

### v3.4.31
- **Fixed a real bug reported directly from play**: effective temperature
  reading *above* ambient (and rising) while cold, indoors, with the
  spell-resist reagent buff (Bugloss etc.) also active - e.g. a 60°F zone
  producing a 74°F effective reading that kept climbing.
- **Root cause**: each of the two steadying effects (spell-resist buff,
  indoor shelter) independently capped itself at
  `min(itsOwnMax, distanceToNeutral)` - correctly preventing either ONE
  effect from ever overshooting past neutral (22°C/71.6°F) on its own.
  But `GetEffectiveTemp()` simply summed both offsets together with no
  check on the combined total. Since the two caps sum to 25°C
  (10°C + 15°C) - more than most real temperature gaps - having both
  effects active at once routinely pushed the combined total past the
  actual distance to neutral, overshooting straight through it and out
  the opposite side. Worse, since the true temperature (unaffected by
  this bug) kept drifting further from neutral while cold, both
  offsets kept growing toward their caps, so the overshoot - and the
  backwards-seeming "rising" effective temperature - grew right along
  with it, even while the true temperature was actually falling.
- **Fixed** by scaling both offsets down proportionally whenever their
  combined demand would exceed the actual distance to neutral, so the
  combined push can bring the player to neutral but never past it.
  Single-effect cases (only one of the two active, or neither near its
  own cap) are completely unaffected - the scaling factor is exactly 1
  in those cases, a no-op - only the combined-overshoot case changes.
- **Also directly verified, per a follow-up question**: this integration
  does not touch `LibZoneTemp`'s own ambient temperature calculation in
  any way - confirmed via direct code inspection that `INTERIOR_MODIFIER`
  (a `-3°C` cooling adjustment) is completely unchanged, and our change
  there only ever affects which signal feeds the `isInterior` boolean,
  never what that boolean does once determined. The reported 60°F
  ambient reading was accurate; the entire discrepancy traced to this
  file's own effective-temperature stacking, not to the zone calculation.

---

### v3.4.30
- **Reverted v3.4.29's version floor** on
  `## OptionalDependsOn: LibInteriorDetection` (back to no version, just
  the bare name). A follow-up moderator comment clarified that
  `OptionalDependsOn` does not support `>=` version syntax at all - only
  `DependsOn` does, since a missing *hard* dependency is what actually
  stops an addon from loading, which is what the version check exists to
  guard against. An optional dependency doesn't block loading either way,
  so a version check on it isn't just unsupported syntax, it's not a
  meaningful concept there.
- **This was likely a real functional bug, not just a style issue**:
  `LibInteriorDetection>=28` was almost certainly being read as a literal
  dependency name, which would never match the real `LibInteriorDetection`
  addon - meaning the optional-dependency detection may have been
  silently failing to recognize it as installed at all, even when it
  genuinely was.
- **This also resolves the tension flagged in v3.4.29's own entry
  below**: that entry raised a concern about reopening a
  previously-solved blocking-risk tradeoff. It turns out the original
  no-floors-on-optional-dependencies precedent was correct all along;
  v3.4.29's floor was the actual mistake, not a justified reversal of it.

---

### v3.4.29
- **Compliance fix**: added a version floor to
  `## OptionalDependsOn: LibInteriorDetection` (now `>=28`), per an
  ESOUI moderator's written rule that version checks are mandatory for
  `OptionalDependsOn` too, not just hard `DependsOn`. Worth flagging: this
  reopens a tradeoff this project previously decided the other way on
  purpose for a different addon (Realistic Needs and Diseases) - version
  floors were deliberately removed from an optional dependency there,
  since a floor can block the whole addon from loading if the optional
  dependency is present but outdated. Added here to comply with the
  written rule regardless; if a stale-but-present LibInteriorDetection
  install is ever reported as blocking Frostfall from loading entirely -
  rather than gracefully falling back to no indoor-shelter effect - that
  floor is the reason.

---

### v3.4.28
- **Fixed the spell-resist reagent buff (Bugloss etc.) continuing to
  decay against real wall-clock time while the master "Enable Frostfall"
  toggle is off.** It was already paused correctly across a real logout
  (since v3.4.21) but not across the master toggle — `FV:SetEnabled(false)`
  never touched it, so the buff's absolute end-time kept advancing
  regardless of the toggle.
- `FV:SetEnabled(false)` now snapshots the remaining time (reusing the
  existing `SaveSpellResistRemaining`) and stops the countdown tick;
  `FV:SetEnabled(true)` resumes it (reusing the existing
  `RestoreSpellResistBuff`) the same way a relogin already did.
- `FV:Initialize()` now only restores/resumes the buff if the master
  toggle is already on at load — previously it restored (and immediately
  started decaying) the countdown unconditionally, even when loading in
  with the toggle off.
- **Fixed a related edge case**: a real logout firing while the buff was
  already paused by the master toggle would previously wipe the paused
  snapshot to `nil` (it saw no active countdown and assumed there had
  never been a buff at all). It now leaves an already-paused snapshot
  alone instead of clearing it.

---

### v3.4.27
- **Fixed the HUD showing empty (no data) on login** when the master
  "Enable Frostfall" toggle is off but "Show Thermal Status HUD" is on.
  `HUD:Initialize()` set visibility from `FV.SV.showHUD` alone, ignoring
  `FV.SV.enabled` — unlike the overlay (which starts hidden and only
  becomes visible via the master-toggle-gated `Update()` call), the HUD
  eagerly set its own visibility at load time, before the tick loop that
  actually populates it had run even once.
- Now hidden unless both `showHUD` and `enabled` are true.
  `FV:SetEnabled()` (the mid-session toggle path, e.g. `/ff` or the
  settings checkbox) was already correct since v3.4.14 — this only
  affected loading in with the master toggle already off.

---

### v3.4.26
- **Raised the indoor shelter effect's cap from 5°C to 15°C** — 1.5x the
  spell-resist reagent buff's 10°C cap, up from 0.5x, per explicit
  request. Being genuinely sheltered indoors is now treated as stronger
  protection than the temporary alchemical buff, not weaker.
- No other change — still stacks additively with the spell-resist reagent
  buff (each capped independently, now 15°C and 10°C respectively), still
  requires `LibInteriorDetection` to be installed.

---

### v3.4.25
- **New: passive indoor-shelter steadying effect** via `LibInteriorDetection`
  (a new `## OptionalDependsOn` — not required; degrades to a no-op if not
  installed). Whenever `LibInteriorDetection` reports the player is
  currently indoors, effective temperature is nudged toward neutral
  (22°C), capped at 5°C — half the spell-resist reagent buff's 10°C cap
  at the time (later raised to 1.5x in v3.4.26).
- **This STACKS ADDITIVELY with the spell-resist reagent buff** (Bugloss
  etc.) rather than replacing or capping against it — both effects are
  computed independently from the player's true temperature differential
  and summed. Standing indoors while under the reagent buff gives the
  combined steadying of both, each still capped on its own.
- `FV:GetEffectiveTemp()` is restructured around a shared
  `SteadyingOffset()` helper used by both effects, rather than one inline
  calculation specific to the reagent buff.
- `/ff status` and the HUD's "FEELS LIKE" indicator (renamed
  `UpdateSpellResistIndicator` -> `UpdateSteadyingIndicator` in
  `ui/TemperatureHUD.lua`) now report either or both effects when active.
- **`LibZoneTemp` updated alongside this (v2.3.16)** to prefer
  `LibInteriorDetection` for its own interior penalty and weather/time
  shielding calculation too — previously delve/dungeon/trial-only via
  `LibZone`, now covers ordinary buildings and player houses when
  `LibInteriorDetection` is installed. See `LibZoneTemp`'s own changelog.
- No SavedVariables schema changes — the new state is derived live each
  tick, not persisted.

---

**Correcting the record**: v3.4.25 through v3.4.29 above were originally
drafted and shipped as an erroneous "v3.4.24" through "v3.4.28," built
against a stale v3.4.23 baseline that predated this addon's real v3.4.24
(the sit/sleep-detection port and Screen Overlay Max Opacity slider,
below) — a version collision discovered only when the actual latest
published files were compared directly against what that work was based
on. That erroneous numbering was never the actual released v3.4.24-28 and
is not reflected anywhere else in this changelog. The entries above are
the correct continuation, built on top of the real v3.4.24 rather than
the stale baseline. No functional loss: none of the fixes themselves
changed, only which version numbers they're correctly attached to.

---

### v3.4.24
- **Temperature emotes no longer interrupt sitting or sleeping.** Previously,
  a cold/hot temperature emote firing while the player was mid-sit or
  mid-sleep would cancel that pose outright (ESO cancels a sit/sleep
  animation whenever any other emote plays), making it hard to actually
  rest while cold or hot. Ported and scoped down from Realistic Needs and
  Diseases' own sit/sleep detection (which RND built for its fatigue-
  recovery mechanics) — `FV:IsResting()` now gates `TickEmote`, backed by
  the same two detection paths RND uses: hooked `/sit`-/`/sleep`-family
  slash commands, and a real in-world "Sit" interaction prompt (chairs,
  benches). A dedicated 5-second position-poll clears the resting flag
  once the player actually stands up and walks away, independent of
  Frostfall's own (much slower, user-configurable) update interval. No new
  Settings — this is a pure bugfix, always on.
- **New: "Screen Overlay Max Opacity" slider** in ConfigMenu (0.1–1.0) —
  caps how strong the hot/cold screen vignette can get at the temperature
  extremes. Previously a hardcoded `MAX_ALPHA = 0.75` constant in
  `OverlayEffects.lua` with zero Settings exposure — separate from the
  existing HUD Opacity slider, which only ever affected the status window,
  not the screen-tint overlay itself. Default (0.75) matches the old
  hardcoded value exactly, so nobody's overlay changes strength on
  upgrade.

---

### v3.4.23
- **New: "Temperature Adaptation Rate" slider** in ConfigMenu (0.25–5.0
  °C/min, in 0.25 steps) — controls how fast your character's temperature
  drifts toward ambient, previously a hardcoded constant
  (`BASE_DRIFT_RATE = 1.75`) with no in-game way to adjust it. Stored as
  `FV.SV.driftRate`; the default (1.75) matches the old hardcoded value
  exactly, so nobody's actual drift behavior changes on upgrade unless they
  move the slider themselves. Insulation-based scaling
  (`ComputeDriftRate`/armor via `LibArmorInsulation`) is unaffected — it
  still multiplies on top of whichever base rate is set.

---

### v3.4.22
- **BUGFIX — the offline-pause persistence added in 3.4.21 could silently
  fail to reach disk.** `FV.SV.spellResistRemainingSeconds` was written
  only once, inside the `EVENT_PLAYER_DEACTIVATED` handler
  (`SaveSpellResistRemaining`). Debug logging plus direct inspection of
  `FrostfallSV.lua` confirmed the write succeeded in memory every time
  (the log correctly reported the remaining seconds) but sometimes never
  made it into the saved file — a race against the client's own
  SavedVariables flush that a value written *during* the deactivate
  handler could lose, while values already sitting in `FV.SV` from
  earlier in the session (like `playerTemp`, updated continuously) were
  never affected. Fixed by also writing `spellResistRemainingSeconds` on
  every 1-second `OnSpellResistTick` while the buff is active, mirroring
  the always-current pattern `playerTemp` already used successfully. The
  deactivate-time write is kept as a final tightening-up at logout, not
  the sole write path, so the value in `FV.SV` is now correct well before
  any flush happens rather than depending on one to land in time.
- **Cleans up the orphaned `spellResistEndTimestamp` key** left behind in
  SavedVariables by the pre-3.4.21 (v3.4.19/3.4.20) persistence scheme,
  which stored an absolute epoch timestamp under that name. Nothing has
  read it since 3.4.21 replaced it with `spellResistRemainingSeconds`, so
  it was dead data for anyone upgrading from an older save. Now cleared on
  the first `Initialize()` after upgrading.

---

### v3.4.21
- **Spell-resist reagent buff now PAUSES while offline instead of counting
  down against real-world time regardless of login state.** v3.4.19's
  persistence used `FV.SV.spellResistEndTimestamp`, an absolute real-world
  epoch timestamp — meaning a relog gap longer than the buff's own max
  duration (30-39 minutes, depending on Medicinal Use rank) would always
  correctly, but perhaps counterintuitively, show it as expired, since the
  buff genuinely would have worn off by then even if the player had stayed
  logged in the whole time. Replaced with `FV.SV.spellResistRemainingSeconds`
  — a plain duration, not a timestamp — captured the moment the player
  leaves the session (new `SaveSpellResistRemaining`, hooked to
  `EVENT_PLAYER_DEACTIVATED`) and consumed back into a fresh
  `spellResistEndTime` on the next `Initialize()`. However long the actual
  offline gap was, the player now returns to exactly the time that was left
  when they logged out — the clock doesn't run at all while offline.

---

### v3.4.20
- **HUD now indicates when the spell-resist reagent buff is active.** The
  "FEELS LIKE" row's label (the row this buff actually shifts) switches to a
  soft violet color and appends a rough `(Xm)` remaining-time readout while
  the buff is running, reverting to its normal color/text once it ends.
  No new control or art asset — reuses that row's existing label control.
  Refreshes on the HUD's normal update cadence, plus immediately whenever
  the buff is applied, refreshed, or ends (natural expiry or `/ff debug
  resetStatus`), same as the rest of the HUD already does.

---

### v3.4.19
- **Craft bag reagent consumption now triggers the spell-resist buff too.**
  Reagent detection previously only watched `BAG_BACKPACK`, so a player with
  craft bag access — where reagents auto-deposit instead of sitting in the
  backpack — could eat a spell-resist reagent (Bugloss, Mudcrab Chitin, Clam
  Gall, White Cap) straight from the craft bag and see no effect. Added a
  second `BAG_VIRTUAL`-filtered registration (`RegisterReagentListener`/
  `UnregisterReagentListener` now toggle both together), on the same handler
  — the existing per-slot cache already keys by `bagId .. ":" .. slotId`, so
  backpack and craft bag slots never collide.
- **The herbal thermal-resistance buff (spell-resist reagent effect) now
  survives a relog.** Previously tracked only in `FV.State` (in-memory,
  reset on every UI reload) via `GetGameTimeMilliseconds()` — a session-
  local uptime clock that means nothing carried into a new session. Now also
  mirrored to `FV.SV.spellResistEndTimestamp` in real-world epoch time
  (`GetTimeStamp()`) whenever the buff is applied, refreshed, or cleared
  (naturally or via `/ff debug resetStatus`). A new `RestoreSpellResistBuff`,
  called from `Initialize()`, re-derives the remaining duration into the new
  session's game-time clock and resumes the 1-second tick if time is still
  left — the buff picks up right where it left off instead of vanishing on
  relog.

---

### v3.4.18
- **Star Dew's itemId (64500) confirmed and added** to
  `FV.WATER_SOLVENT_ITEM_IDS`, per the developer's own manual lookup — all
  9 water-solvent tiers are now covered.
- Manifest `## APIVersion` updated to `101050 101051`, covering the newly
  released 101051 alongside the previous 101050.

---

### v3.4.17
- **Water solvent detection now matches by real itemId instead of item
  name.** Previously matched against a table of English display names
  (`FV.WATER_SOLVENT_NAMES`), which only worked on an English client.
  `OnWaterLoot` now captures `itemId` (the actual 10th parameter of
  `EVENT_LOOT_RECEIVED`'s real signature) and checks it against
  `FV.WATER_SOLVENT_ITEM_IDS`, a table of verified itemIds cross-referenced
  against two independent sources (UESP's ESO Item database and
  eso-hub.com's trading pages) for 8 of the 9 water-solvent tiers: Natural
  Water (883), Clear Water (1187), Pristine Water (4570), Cleansed Water
  (23265), Filtered Water (23266), Purified Water (23267), Cloud Mist
  (23268), and Lorkhan's Tears (64501). Star Dew's itemId could not be
  independently confirmed and is intentionally left out rather than
  guessed at (the four consecutive IDs 23265-23268 might suggest 23269,
  but Lorkhan's Tears breaks that pattern at 64501, so it can't be
  assumed) -- it simply won't trigger the cooling mechanic until a real
  itemId is confirmed in-game.

---

### v3.4.16
- **Events are now registered/unregistered based on whether Frostfall is
  enabled, instead of always being registered and checking `FV.SV.enabled`
  inside each handler.** A new `CheckIfEventsNeeded()` function is the one
  place that (un)registers everything -- `EVENT_PLAYER_ACTIVATED`,
  `EVENT_ZONE_CHANGED`, the merchant/craft/bank open-close events, the
  reagent-consumption listener, water-loot, station-warm, and both
  `RegisterForUpdate` ticks -- called once from `FV:Initialize()` and again
  from `FV:SetEnabled()` whenever the setting flips at runtime. While
  disabled, nothing but the one-shot `EVENT_ADD_ON_LOADED` bootstrap is
  registered at all.
- **The reagent-consumption listener is now dynamically unregistered while
  a merchant, crafting station, or bank window is open**, instead of
  staying registered permanently and being ignored in Lua via the
  `_ff_isMerchantOpen`/`_ff_isCraftingStationOpen`/`_ff_isBankOpen` flags.
  It's re-registered the moment none of those windows are open anymore.
- **Fixed a real bug in `EVENT_LOOT_RECEIVED` parameter handling** (the
  water-loot cooling mechanic). The handler's parameters were misaligned
  against the event's actual documented signature -- it was reading the
  5th argument (`soundCategory`, an `ItemUISoundCategory` value) as if it
  were an item type, and comparing it to a hardcoded `19` that was never
  the right field to check in the first place. There's also no single
  "water" item -- water solvents are a whole family of separate items, one
  per potion tier (Natural Water, Clear Water, Pristine Water, Cleansed
  Water, Filtered Water, Purified Water, Cloud Mist, Star Dew, Lorkhan's
  Tears -- confirmed against UESP's Alchemy Ingredients page). The handler
  now uses the correct parameter positions and matches by real item name
  against `FV.WATER_SOLVENT_NAMES` instead of the wrong field against a
  guessed number.

---

### v3.4.15
- **Added a second event filter to the reagent-consumption event.**
  `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` was already filtered to
  `REGISTER_FILTER_BAG_ID` = `BAG_BACKPACK` (see v3.4.12), but this event
  also fires for non-consumption reasons within the backpack itself —
  durability changes, charge changes, and similar — which that filter
  alone doesn't exclude. Added `REGISTER_FILTER_INVENTORY_UPDATE_REASON` =
  `INVENTORY_UPDATE_REASON_DEFAULT` in the same `AddFilterForEvent` call
  (multiple filter type/value pairs can be passed to one call), so only
  genuine inventory-quantity changes reach the callback at all.

---

### v3.4.14
- **Fixed "Enable Frostfall" not actually shutting anything down visibly.**
  Turning the master toggle off only stopped `FV:OnUpdate()` from
  recalculating — it never touched a HUD or overlay that was already on
  screen, so both would just sit there frozen at their last displayed
  state instead of disappearing. All enable/disable paths (`/ff toggle`,
  the "Enable Frostfall" checkbox) now go through a new `FV:SetEnabled()`
  that proactively hides the HUD and both overlay windows the instant it's
  turned off (regardless of their own individual show/enable settings),
  and immediately forces a fresh update to bring everything back the
  instant it's turned back on.
- **Replaced the settings-panel "Debug" section with slash commands.**
  The Debug Logging checkbox and the Print Current Status / Force Update
  Now / Reset All Settings to Default buttons are now `/ff debug enable`,
  `/ff debug disable`, `/ff debug status`, `/ff debug update`, and
  `/ff debug reset` respectively — same behavior, just accessible without
  opening the settings panel.
- **New: `/ff debug resetStatus`** — immediately resets the player's
  temperature to neutral (22°C, the comfortable-band midpoint) and clears
  any active spell-resist reagent buff outright, rather than waiting for
  drift or the buff timer to run its course.
- Updated `/ff help` to document all six `/ff debug` subcommands.

---

### v3.4.13
- **Removed the "Enable Sound Effects" setting.** It was never wired to
  anything — no `PlaySound` call or equivalent existed anywhere in the
  addon — so the checkbox did nothing. Removed the checkbox and the
  `enableSound` saved variable.
- **Added two new notification settings, replacing the removed one's slot:**
  "Show native top-screen notifications" (the existing `ZO_Alert`
  top-of-screen banner, now toggleable — previously always on) and "Also
  log notifications to chat" (prints the same message to chat too, off by
  default). All seven of Frostfall's alerts (band transitions, spell-resist
  buff apply/renew/fade/warn, water-loot cooling, station warming) now
  route through one central `FV:Notify()` function that respects both
  toggles independently.
- **Renamed "Show Temperature HUD" to "Show Thermal Status HUD"** (same
  setting, `FV.SV.showHUD`, unchanged).
- **Fixed emote defaults not surviving "Reset All Settings to Default."**
  `FV.Defaults.emoteId*` are hardcoded placeholders (0) that only become
  real emote IDs via `ResolveEmoteDefaults()` at `Initialize()` time; the
  Reset button was overwriting them straight from `FV.Defaults`, silently
  turning off all four temperature emotes until the next `/reloadui`. The
  Reset button now calls `ResolveEmoteDefaults()` immediately afterward, and
  each emote dropdown's `default` is now a function reading the resolved
  `FV.EMOTE_DEFAULTS` value instead of a hardcoded 0, so it lands on the
  right emote instead of "None." Confirmed the resolved defaults are
  exactly the intended four: Very Cold -> "Shivering Cold", Cold ->
  "Shiver Cold", Hot -> "Wipe Brow", Very Hot -> "Breathless".
- **Removed an incorrect line from the Temperature Emotes description** —
  "No emote plays at Freezing (<= 10) — the player is incapacitated" — there
  is no "Freezing" emote band and no incapacitation mechanic; the emote
  system only has the four bands (Very Cold/Cold/Hot/Very Hot) described in
  the rest of that same text.
- **Removed the "Overrides & Library Settings" section** (the two
  "Open LibZoneTemp/LibArmorInsulation Settings" buttons and their
  description) from the settings panel entirely.

---

### v3.4.12
- **SavedVariables are now server-dependent.** `ZO_SavedVars:NewAccountWide`
  previously passed `nil` for the namespace argument, so EU, NA, and PTS all
  read and wrote the *same* account-wide save table — logging into a
  different server would silently overwrite another server's settings and
  state. Now namespaced by `GetWorldName()` (`"EU Megaserver"` /
  `"NA Megaserver"` / `"PTS"`), so each server keeps its own data.
  **One-time effect of this fix:** settings set before this version will
  appear "reset" the first time you load each server after updating —
  they're still in the SavedVariables file under the old shared location,
  just no longer read from there.
- **All event and slash-command registrations moved inside `FV:Initialize()`.**
  The reagent-consumption, merchant/crafting-station/bank gating, water-loot
  cooling, and crafting-station warming events were all previously
  registered at file scope (i.e. the moment the file loaded), before
  `FV.SV` exists — any of them firing early would have hit a nil
  SavedVariables table. They're now registered inside `FV:Initialize()`,
  which only runs once `EVENT_ADD_ON_LOADED` fires and `FV.SV` is already
  set up. (The slash commands `/ff` and `/frostfall` were already
  registered inside `Initialize()`.)
- **Added a proper event filter for the reagent-consumption event**, per
  [AddFilterForEvent](https://wiki.esoui.com/AddFilterForEvent):
  `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` is now filtered to
  `REGISTER_FILTER_BAG_ID` = `BAG_BACKPACK`, so slot updates in the bank,
  worn-equipment, or other bags never reach the callback at all — reagents
  are only ever eaten from the backpack, so this is a strictly narrower,
  more efficient registration than checking the bag in Lua after the fact.
- **Clarified the "Show Temperature HUD" and "HUD Opacity" settings.** Both
  already existed — turning the HUD off leaves temperature emotes and the
  top-of-screen `ZO_Alert` band notifications working exactly as before,
  and the opacity slider controls the HUD's transparency. Reworded both
  tooltips to say so explicitly.

---

### v3.4.11 — documentation accuracy pass
A full review of this README against the actual current code and against
LibZoneTemp/LibArmorInsulation's real current data (the developer supplied
the official RolePlayNeeds release for direct comparison). Found and fixed:
- **RolePlayNeeds misattribution**: a `RPN_REAGENT_TRAITS` static item-ID
  lookup table was credited to RolePlayNeeds — no such table exists in
  RolePlayNeeds' published source (confirmed against the official v0.7 BETA
  release; RolePlayNeeds has no reagent-trait handling at all). This
  addon's own `FV.SPELL_RESIST_REAGENT_IDS` table is an independent lookup
  this project built itself. The `EVENT_LOOT_RECEIVED` argument-signature
  and overlay-window-anchoring credits were checked too and are genuinely
  accurate — kept as-is.
- **Zone Temperature Reference table was completely wrong** — every one of
  the 17 listed values was inaccurate, most by 30–80°C (e.g. Coldharbour
  listed as 2°C, actually -8°C; The Deadlands listed as 85°C, actually
  54°C). Rebuilt from `LibZoneTemp.lua`'s actual `ZONE_BASE_TEMPS_BY_NAME`
  table. Also corrected the "80+ zones" / range claims in the Features
  overview (actually 1,000+ zones and sub-zones, -16°C to 55°C).
- **Armor Insulation Reference table was from before the v2.6.0
  staggered-tier rewrite** — raw pre-snap scores that no longer correspond
  to any real output of the current formula, plus four listed
  styles/costumes (Voidsteel, Nightmare, Soul Shriven, Bear Raiment
  Costume) that don't exist anywhere in the current data. Rebuilt with
  real entries and tiers computed through the actual current formula and
  `Calc.SnapToTier()`.
- **Thermal direction was backwards for several Daedric-aligned pieces**:
  Daedric, Ancient Daedric, Dremora, and Waking Flame were all described as
  heat-generating with above-average insulation; the actual code has all
  four with a *negative* `flavorBonus` (explicitly cold-themed flavor
  text), landing them at or near the bottom of the range, not the top.
- **Removed an entirely fictional "Set Insulation Bonuses" feature** — a
  full section describing gear sets granting flat insulation bonuses,
  "detected via LibArmorInsulation" with its own config panel. No part of
  this exists in either addon: no set-detection code, no bonus data table,
  no such config panel. Also removed the matching "active set bonus"
  claim from the HUD Display section.
- **Corrected the claimed cultural-origin insulation ordering** ("Nord >
  Orc > Breton > Imperial > Khajiit > Argonian") — the real computed order
  is Nord > Breton > Khajiit/Argonian/Orc (tied) > Imperial.

### v3.4.10 — settings-panel sync
- **Fixed the settings panel's author/version fields**, which were out of
  sync with the manifest and README: `author` incorrectly read "Frostfall"
  (the addon's own title) instead of the actual author, and `version` was
  hardcoded to a stale `"3.4.2"` (the internal `FV.VERSION` constant was
  also stale, at `"3.4.4"`). The panel now reads `author = "@Kreksar5 and
  Claude.ai"` and `version = FV.VERSION`, and `FV.VERSION` itself is kept in
  sync with the manifest `## Version` going forward.

### v3.4.9 — overlay art credit
- **Added an "Overlay art credit" note** to the Credits section, crediting
  the Perchance AI Text-to-Image Generator and Google's Gemini Image
  Creator for generating `HOT_OVERLAY.dds` and `COLD_OVERLAY.dds`, and
  Paint.NET for editing/converting them to the game's `.dds` format.

### v3.4.8 — author credit
- **Standardized the author credit** to `@Kreksar5 and Claude.ai` in the
  `## Author` manifest field and this README's byline, and named Claude.ai
  specifically (rather than generic "AI assistance") in the manifest
  description and the AI-assistance disclosure above, matching the crediting
  convention used across this addon's companion libraries.

### v3.4.7 — non-affiliation disclaimer
- **Added an explicit "not a port, not affiliated with or endorsed by
  Chesko" disclaimer** for the Skyrim mod *Frostfall*, matching the
  disclaimer Realistic Needs and Diseases already carries for its own
  Skyrim namesake. This addon reuses Chesko's mod name and general concept
  as a homage — Chesko's own permissions pages ask to be contacted before
  the mod's name or work is reused elsewhere, so this addon now says
  plainly, in both the manifest description and this README, that it is
  an independent, unaffiliated ESO implementation with no shared code or
  assets (impossible between these two games' engines regardless).
- **Expanded the Credits section** to name Chesko and the Skyrim mod
  directly, rather than only crediting RolePlayNeeds for implementation
  details.

### v3.4.6 — ESOUI release-rules compliance pass
- **Corrected the `## Author` manifest field**, which incorrectly read
  "Frostfall" (the addon's own title) instead of the actual author.
- **Added the required `## AddOnVersion` tag** (previously missing entirely —
  this is the integer the ingame addon manager and Minion use to detect
  updates, separate from the informational `## Version` tag). Started at 6,
  comfortably above the `>=3` floor that Realistic Needs and Diseases'
  `OptionalDependsOn` line already checks for.
- **Added a version floor (`>=1`) to the `LibClockTST` dependency**, which
  previously had none.
- **Added the required AI-assistance disclosure** to the manifest description
  and this README, per ESOUI's addon release rules.
- **Added a Credits section** naming RolePlayNeeds (matheusbk2) for the
  implementation details referenced during development.

### v3.4.5 — API compliance audit
- **Full API audit against the official ESOUI API 101050 documentation.**
  Every function call, method call, and constant referenced across the addon
  was cross-checked against the API doc and, where the doc didn't cover it
  (manager singletons, `ZO_` helpers, third-party libraries), against the
  live ESOUI source.
- **Removed the entire weather feature** (`FV:UpdateWeatherState`,
  `FV:OnWeatherChanged`, the `EVENT_WEATHER_CHANGED` registration, and the
  precipitation-drag term in the temperature drift calculation). Neither
  `EVENT_WEATHER_CHANGED` nor any of the six `WEATHER_*` constants
  (`WEATHER_RAIN`, `WEATHER_SNOW`, `WEATHER_THUNDER`, `WEATHER_ASHCLOUD`,
  `WEATHER_FOG`, `WEATHER_CLOUDY`) exist anywhere in the ESO addon API — ESO
  does not expose live weather state to addons at all, so this feature could
  never have worked. Worse, registering for a `nil` event code at load time
  risked erroring out of the whole `OnPlayerActivated` init sequence,
  breaking the drift-update timer and emote-loop registrations that ran
  after it. Removed the now-dead `isRaining`/`isSnowing`/`isStorming`/
  `isSunny`/`weatherType` state fields and updated `/ff status`, the debug
  log line, and this README to match.
- Everything else checked out: `EVENT_MANAGER`, `WINDOW_MANAGER`,
  `SCENE_MANAGER`, `PLAYER_EMOTE_MANAGER`, `ZO_Alert`, `ZO_PreHook`, and all
  LibAddonMenu/LibSavedVars/LibZone/LibClockTST calls are legitimate and
  correctly used.

### v3.4.4 — dependency version correction
- **Corrected `LibAddonMenu-2.0` dependency floor**: was mistakenly bumped to
  `>=45` in 3.4.3, but LibAddonMenu's own manifest documentation shows `43`
  as the latest available version, not `45`. Fixed to `>=43`. The 3.4.3 entry
  below has also been corrected to reflect the right number.
- **`LibZoneTemp` dependency floor bumped** from `>=9` to `>=11`, following
  LibZoneTemp's own version corrections in the same vein.

### v3.4.3 — ESOUI compliance pass
- **Fixed a manifest bug: 5 separate `## DependsOn:` lines consolidated into 1.** Per the addon manifest spec, multiple non-optional dependencies must be space-separated on a single `## DependsOn:` line; repeating the directive across several lines risks the manifest parser only honoring the last occurrence, which would have silently dropped the `LibClockTST`, `LibAddonMenu-2.0`, `LibZone`, and `LibZoneTemp` checks (leaving only `LibArmorInsulation` actually enforced).
- **Added missing version floors** (`>=`) for `LibAddonMenu-2.0` (`>=43`), `LibZoneTemp` (`>=9`), and `LibArmorInsulation` (`>=7`), matching their current `## AddOnVersion` values. `LibClockTST` still has no version floor — its current `AddOnVersion` wasn't available to check during this pass; recommend confirming and adding one.
- **`## APIVersion` updated** from the stale `101043` to `101049 101050` (current Live/PTS), and the README's compatibility section synced to match.
- **Reviewed for global variable leaks and "what addons cannot do" compliance** — none found. The reagent-consumption mechanic only *listens* for `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` after the player manually eats/uses something; it never calls `UseItem` or any consume/cast/interact function itself, so it doesn't touch the quickslot-automation restrictions.

### v3.4.2
- **Reagent consumption detection now ignores bank activity.** Withdrawing or depositing a reagent from the personal bank or guild bank fires the same `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` as eating it, so the spell-resist buff trigger is now also gated off while either bank window is open (`EVENT_OPEN_BANK`/`EVENT_CLOSE_BANK`, `EVENT_OPEN_GUILD_BANK`/`EVENT_CLOSE_GUILD_BANK`), matching the existing merchant/crafting-station gating.

### v3.4.1 (bugfix)
- **Fixed: reagent consumption detection was completely broken.** `GetMedicinalUseRank()` (used to scale the spell-resist buff's duration) called `GetCraftingSkillLineIndices()` and referenced a `SKILL_TYPE_CRAFTING` constant — neither exists in the ESO UI API. The resulting Lua error aborted the whole consumption handler before it could ever apply the buff, so eating a qualifying reagent did nothing. Replaced with `GetNumSkillLines(SKILL_TYPE_TRADESKILL)` + `GetNumSkillAbilities()` + `GetSkillAbilityInfo()`, all verified directly against esoui/esoui's `ESOUIDocumentation.txt`.

### v3.4.0
- **Spell-resist reagent buff completed** — added the remaining two confirmed item IDs (Clam Gall `139020`, White Cap `30154`) to `FV.SPELL_RESIST_REAGENT_IDS`, alongside Bugloss and Mudcrab Chitin from 3.3.0. All four canonical "Increase Spell Resist" reagents (per UESP) now trigger the buff.

### v3.3.0
- **New: Spell-resist reagent temperature buff** — consuming an alchemy reagent with the "Increase Spell Resist" trait (Bugloss, Clam Gall, Mudcrab Chitin, White Cap) steadies the player's effective temperature toward neutral (22°C, the midpoint of the comfortable band), capped at a 10°C shift in either direction.
  - Lasts 30 real-world minutes, extended by 10%/20%/30% if the player has rank 1/2/3 of the Alchemy passive **Medicinal Use**.
  - Eating another qualifying reagent while the buff is active resets the timer instead of stacking.
  - Fires a fade warning once per minute during the last 5 minutes of the buff.
  - The steadying offset is **recalculated live** from the player's current real temperature differential every time it's applied — it is not a fixed snapshot taken at the moment the reagent was eaten, so it keeps tracking the player's true temperature as they move through zones/weather while the buff is up.
  - Uses a static item-ID lookup table (`FV.SPELL_RESIST_REAGENT_IDS`) built
    for this addon, since alchemy trait APIs only work at an open crafting
    station. *(Corrected: this was previously described as following the
    same pattern as RolePlayNeeds' "`RPN_REAGENT_TRAITS`" — no such table
    exists in RolePlayNeeds' published source; see the correction in
    Credits above.)*
  - Internally, player temperature is now split into a "true" physical value (driven by ambient/weather/swim drift, unaffected by the buff) and an effective/displayed value (`FV:GetEffectiveTemp()`) that HUD, overlay, emotes, and band alerts all read from.

### v3.2.0
- **ConfigMenu synced with Frostfall.lua thresholds** — the emote and threshold descriptions in the settings panel now reflect the correct v3.1.5 values (HOT 35°C/95°F, HEAT_DANGER 41°C/105°F) instead of the old stale values (27°C/80°F and 38°C/100°F).
- **Slash command renamed: `/fv` → `/ff`** — The short-form slash command is now `/ff` to avoid conflicts. `/frostfall` continues to work as before.
- **ConfigMenu panel version updated** — The LAM panel version string now correctly reads `3.2.0`.

### v3.1.5 (included in this release)
- Updated all temperature thresholds to more logical/reasonable values:
  - `COMFORTABLE_LO` raised from 16°C → 20°C (61°F → 68°F)
  - `COMFORTABLE_HI` raised from 26°C → 24°C (79°F → 75°F) *(reordered — now correctly below WARM)*
  - `WARM` raised from 21°C → 26°C (70°F → 79°F)
  - `HOT` raised from 27°C → 35°C (80°F → 95°F)
  - `HEAT_DANGER` raised from 38°C → 41°C (100°F → 105°F)
- Fixed band-transition comparison operators (`<` → `<=`) so boundary temperatures are correctly classified.
- OverlayEffects: pre-computes both cold and hot alpha before applying either, eliminating a mutual-exclusion bug that could mask the hot overlay.
- OverlayEffects: hot overlay comments and ramp references updated to match the new HOT (35°C) and HEAT_DANGER (41°C) thresholds.

### v3.1.4
- Fixed water loot handler — was reading the 6th `EVENT_LOOT_RECEIVED` argument instead of the correct 5th (`itemType`). Now matches RolePlayNeeds exactly.
