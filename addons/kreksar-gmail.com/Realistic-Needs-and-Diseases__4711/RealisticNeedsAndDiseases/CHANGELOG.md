# Realistic Needs and Diseases — Changelog

Full version history. See README.md for current features, installation, and usage.

---

### 0.19.32
- **Fixed the remaining "first food/drink isn't detected, second one is"
  bug.** Root cause was in `OnFoodDrinkInventoryChange`, not the
  buff-confirmation gate: the trade-window guard
  (`RN.IsTradeWindowOpen()` — merchant, crafting station, bank, guild bank)
  was an early `return` at the very top of the handler, so it skipped not
  just consumption crediting but also the `_lastSlotState` cache refresh.
  Any stack change made while one of those windows was open — buying food
  or drink, **crafting it at a provisioning station** (the most common way
  to get it), or withdrawing it from a bank — never reached the cache.
  Afterward, the first item eaten from that stack was compared against
  stale data: for a stack that had grown, the new size was larger than the
  cached size so it didn't look like a shrink; for a brand-new slot there
  was no cached state at all. Either way the consumption was silently
  dropped, and that same event then refreshed the cache, which is why the
  second item always worked.
- **Fix**: the trade-window check now only suppresses crediting (inside
  `MaybeHandleConsumption`); the cache is always refreshed. This matches
  how `Disease.OnRemedyInventoryChange` already ordered things (cache
  update before its trade-window check).
- **What was verified**: traced the handler's control flow for the
  craft/buy/withdraw → close window → eat sequence before and after the
  change; confirmed the remedy handler in Disease.lua doesn't share the
  bug; `luac -p` clean. **What wasn't**: no live-client test yet. Priority
  in-game check: craft (or buy) a food or drink you already have a stack
  of, close the station, eat one — it should register on the first try.
  The 500ms buff-confirmation window is unchanged; if misses still occur
  with no trade window involved, high latency stretching the gap between
  the buff and inventory events past 500ms is the next suspect.
- **Manifest APIVersion bumped to `101051 101052`** (Update 51 /
  Season One is live).
- **README: linked both required libraries to their ESOUI pages.**
  LibAddonMenu-2.0 was already linked
  (https://www.esoui.com/downloads/info7-LibAddonMenu.html); LibFoodDrinkBuff
  was listed by name only and is now linked
  (https://www.esoui.com/downloads/info1902-LibFoodDrinkBuff.html). Both URLs
  confirmed against the live ESOUI listings (LAM by sirinsidiator/Seerah,
  LibFoodDrinkBuff by Baertram). Optional dependencies are now linked as
  well: Frostfall (https://www.esoui.com/downloads/info4710-Frostfall.html)
  and LibZoneTemp (https://www.esoui.com/downloads/info4708-LibZoneTemp.html),
  URLs supplied by the author.
- **LibFoodDrinkBuff v19 confirmed to cover Granny's Eel Pie** (Update 50,
  obtainable since the U50 Incremental 2 drop fix): its `FOOD_BUFF_ABILITIES`
  table includes abilityId 267468, and a stubbed load test of the library's
  Constants/Data/API files returned `true` from
  `IsAbilityAFoodOrDrinkBuff(267468)`. No RND code change needed; the
  existing `LibFoodDrinkBuff>=19` floor already covers it. **Unverified**:
  that 267468 is the live in-game buff ID (library author's data) and that
  the pie reports as `ITEMTYPE_FOOD` — needs one in-game test.

---

### 0.19.31
- **Fixed a residual food/drink consumption-crediting bug in the bidirectional
  buff-confirmation gate added in 0.19.14.** That fix held one pending
  inventory-shrink (`_pendingConsumption`, a single value) so a buff-gain
  event arriving shortly after could still confirm it. But eating a food
  item and a drink item back-to-back — a very common combo for the paired
  buff — produces two pending shrinks within the same short window, and the
  second one silently overwrote the first before it could be confirmed.
  Depending on event-arrival timing, this could either drop one of the two
  consumptions entirely (no error, no trace — the exact "doesn't update"
  symptom reported) or misattribute a buff confirmation to the wrong pending
  item.
- **Replaced the single pending slot with a FIFO queue
  (`_pendingConsumptions`)**, so each unconfirmed shrink gets its own entry
  instead of clobbering the previous one. Each `LibFoodDrinkBuff`-confirmed
  buff-gain event now credits the oldest still-valid queued entry — since one
  real consumption produces exactly one confirming buff event, this pairs
  them up correctly regardless of arrival order or how many were consumed in
  quick succession. Stale entries older than `BUFF_APPLICATION_WINDOW_MS`
  (500ms, unchanged) are pruned rather than accumulating.
- **What was verified**: reasoned through the corrected forward/backward
  timing logic line-by-line against the 0.19.14 design intent; confirmed no
  other reference to the old single-value `_pendingConsumption` remains
  anywhere in the file. **What wasn't**: no live-client test of the specific
  eat-food-then-drink-quickly sequence this fix targets — this is the
  priority scenario to check in-game before considering this closed.

---

### 0.19.30
- **Reverted the version floors added to
  `## OptionalDependsOn: Frostfall LibZoneTemp` in 0.19.29** (back to
  bare names, no versions). A follow-up moderator comment clarified that
  `OptionalDependsOn` does not support `>=` version syntax at all - only
  `DependsOn` does, since a missing *hard* dependency is what actually
  stops an addon from loading, which is what the version check exists to
  guard against. An optional dependency doesn't block loading either
  way, so a version check on it isn't just unsupported syntax, it's not
  a meaningful concept there.
- **This was likely a real functional bug, not just a style issue**:
  `Frostfall>=25`/`LibZoneTemp>=21` were almost certainly being read as
  literal dependency names, which would never match the real `Frostfall`/
  `LibZoneTemp` addons - meaning the optional-dependency detection may
  have been silently failing to recognize either as installed at all,
  even when they genuinely were (falling back to no temperature data
  entirely, regardless of whether Frostfall/LibZoneTemp were present).
- **This also resolves the tension flagged in 0.19.29's own entry
  below**: that entry raised a concern about reopening a
  previously-solved blocking-risk tradeoff (the same one that led to
  0.19.6 removing floors from these same two entries originally). It
  turns out the original no-floors-on-optional-dependencies precedent
  was correct all along; 0.19.29's floors were the actual mistake, not a
  justified reversal of it.

---

### 0.19.29
- **Fixed the status displays showing with no/stale data on login when the
  master "Enable the addon" toggle is off but a display's own sub-setting
  is on.** Each display's window already starts hidden by default at its
  own `Initialize()`, but the startup code in
  `RealisticNeedsAndDiseases.lua` called `SetShown()`/`RefreshAll()`
  unconditionally from each sub-setting alone (`showStatusBar`,
  `statusIconsTransparencyEnabled`, `statusBarsEnabled`), ignoring
  `sv.settings.masterEnabled` entirely - the same class of bug fixed in
  Frostfall v3.4.26's `HUD:Initialize()`. Every `SetShown()`/`RefreshAll()`
  call at startup now also requires `sv.settings.masterEnabled ~= false`,
  matching the exact check already used by the checkbox `setFunc`s in
  `RealisticNeedsAndDiseases_Settings.lua`. The master-toggle checkbox's
  own `setFunc` already correctly handled the mid-session case - this
  only affected loading in with the toggle already off.
- **Compliance fix**: added version floors to
  `## OptionalDependsOn: Frostfall LibZoneTemp` (now `Frostfall>=25
  LibZoneTemp>=21`), per an ESOUI moderator's written rule that version
  checks are mandatory for `OptionalDependsOn` too, not just hard
  `DependsOn`. Worth flagging: this reopens a tradeoff this project
  previously decided the other way on purpose - version floors were
  deliberately *removed* from these same two entries in an earlier
  version (0.19.6) specifically because a floor can block the whole
  addon from loading if the optional dependency is present but below the
  floor, defeating the point of it being optional. Added back to comply
  with the written rule regardless; if a stale-but-present Frostfall or
  LibZoneTemp install is ever reported as blocking this addon from
  loading entirely - rather than gracefully falling back to no
  temperature data - that floor is the reason.
- Moved the README's Dependencies section to the very first section
  (previously 7th of 13), per the same rule's guidance that dependencies
  should be visible "at the top at best."
- Confirmed via a full compliance sweep: no `GetEventManager()` repeated
  calls (already uses the cached `EVENT_MANAGER` global throughout), and
  no global variable leaks anywhere (the two functions that looked like
  candidates, `CanPlayEmotesNow` and `HandleConsumedItem`, are both
  legitimate forward-declared locals, not leaks).
- **Correcting the record**: these same fixes were previously drafted
  and shipped as an erroneous "0.19.27" built against a stale 0.19.26
  baseline, before this addon's real 0.19.27 (the disease-overlay-opacity
  slider, below) and 0.19.28 (the water-restore floor change, below) were
  known. That erroneous build was never the actual released 0.19.27 and
  is not reflected anywhere in this changelog - this entry is the correct
  continuation, built on top of the real, already-published 0.19.28
  rather than the stale baseline. No functional loss: none of the fixes
  themselves changed, only which version they're correctly attached to.

---

### 0.19.28
- **"Thirst restored per wild water node harvested" slider's minimum
  lowered from 5 to 0.** Setting it to 0 now disables the mechanic
  entirely — no thirst restore *and* no "You drink from the water source"
  chat message, rather than printing a message about an effect that no
  longer happens.

---

### 0.19.27
- **New: "Disease overlay max opacity" slider** in Settings (0.1–1.0) —
  caps how strong the full-screen disease tint (`RN.Overlay.lua`) can get,
  even at Severe. Scales the existing per-severity ceilings
  (`Overlay.MAX_ALPHA_BY_SEVERITY`: 0.25/0.45/0.75 for Mild/Moderate/
  Severe) proportionally down together via a multiplier, rather than
  replacing them individually — at 0.5, for example, Severe renders at
  half its normal strength and Mild/Moderate scale down right along with
  it. Default (1.0) is unscaled, matching prior behavior exactly. Reads
  live (not cached) each time an overlay refreshes, and the slider's
  setFunc also calls `Overlay.RefreshAll` immediately, so adjusting it
  updates any already-visible overlay right away rather than waiting for
  the next severity change. Mirrors the same overlay-opacity slider added
  to Frostfall's hot/cold screen effect (v3.4.24).

---

### 0.19.26
- **Size and opacity/transparency sliders for both the icon and bar status
  displays.** 4 new Settings sliders, all live-updating (no reload needed):
  - "Icon status display size" (`statusIconsTransparencyScale`, 0.5-2.0)
    and "Icon status display max opacity" (`statusIconsTransparencyMaxOpacity`,
    0.2-1.0) — the opacity slider caps how opaque an icon can get even at
    its worst, multiplying on top of the existing severity-driven
    transparency rather than replacing it.
  - "Bar status display size" (`statusBarsScale`, 0.5-2.0) and "Bar status
    display opacity" (`statusBarsOpacity`, 0.2-1.0) — the opacity slider
    covers the whole window (background, bars, and labels together).
  - Implemented via each display's top-level window's native `SetScale`/
    `SetAlpha`, which cascade to every child control automatically — no
    per-icon or per-row layout/alpha math needed to support this.

---

### 0.19.25
- **Drunkenness bar in the bar-based status display (0.19.24) is no longer
  inverted.** Previously shown as an always-visible "Sobriety" bar (full =
  sober) to keep all 4 needs bars reading the same full-is-good direction.
  Now it's a dynamic row instead — hidden entirely while sober (drunkenness
  0), appearing only once actually inebriated, and filling UP as
  drunkenness increases (raw value, no inversion) — the same shape as the
  disease rows below it, rather than a 4th always-shown fixed row.
  Hunger/thirst/fatigue are unchanged (always shown, full = good).

---

### 0.19.24
- **New: bar-based status display.** New file
  `RealisticNeedsAndDiseases_StatusBars.lua`, opt-in via Settings > "Use
  bar-based status display" (off by default). A fourth status display
  option — mini health-bar-style bars using ESO's native `CT_STATUSBAR`
  control type (the same control the game's own health/magicka/stamina
  bars use), one per need (always shown) plus one per currently-active
  disease (shown/hidden dynamically). Independent toggle — can run
  alongside the text window and/or the transparency-based icon display.
  - Needs bars are full = satisfied, empty = critical, matching a health
    bar's own metaphor directly. Drunkenness is displayed inverted as a
    "Sobriety" bar so all 4 needs bars read the same direction (full =
    good) instead of one filling the "wrong" way.
  - Disease bars fill UP as severity worsens (full = Severe) rather than
    down, since a disease is something being accumulated, not a resource
    being spent.
  - Same color ramp and tooltip text (reusing `GetBandMessage`/
    `GetCureHintText`) as the other display variants.
  - `CT_STATUSBAR` is new to this codebase specifically (though standard
    and well-established across ESO addons generally) — worth a quick
    in-game sanity check on first load.

---

### 0.19.23
- **Real icon art replaces the placeholder icons.** The 9 files in
  `textures/icons/` (Hunger.dds, Thirst.dds, Fatigue.dds, Drunkenness.dds,
  Frostbite.dds, Heatstroke.dds, MagesBane.dds, FightersBane.dds,
  ThiefsBane.dds) — previously all just copies of the ThiefsBane.dds
  overlay texture — are now the author's own AI-generated icon art.
  No code changes needed; `RN.STATUS_ICON_PATHS` already pointed at these
  exact filenames.
- **Added a "Status icon art credit" section to README.md**, crediting
  [url=https://perchance.org/ai-icon-generator]Perchance AI Icon
  Generator[/url] alongside the existing overlay-art credit section for
  the disease overlay textures.

---

### 0.19.22
- **Removed the "Badge & Pip" and simple color-tint icon displays,
  keeping only the transparency-based one.** Of the 3 icon display
  variants added in 0.19.18-0.19.20, only
  `RealisticNeedsAndDiseases_StatusIconsTransparency.lua` remains —
  `RealisticNeedsAndDiseases_StatusIcons.lua` and
  `RealisticNeedsAndDiseases_StatusIconsSimple.lua` are deleted, along with
  their Settings checkboxes, reset-position buttons, and SavedVariables
  fields (`statusIconsEnabled`, `statusIconsSimpleEnabled`, and their
  associated position fields). The remaining display's Settings checkbox
  is renamed from "Use icon-based status display (transparency)" to just
  "Use icon-based status display" now that it's the only one.
  `RN.STATUS_ICON_PATHS` (previously defined in the now-deleted
  StatusIcons.lua) moved into StatusIconsTransparency.lua directly, since
  it was the last remaining consumer.
  - `textures/icons/` (the bundled ThiefsBane.dds-copy placeholder icons)
    is unchanged — the transparency display already used all 9 files.

---

### 0.19.21
- **Placeholder icon art is now bundled with the addon instead of pointing
  at ESO's built-in `icon_missing.dds`.** New `textures/icons/` folder with
  9 files (`Hunger.dds`, `Thirst.dds`, `Fatigue.dds`, `Drunkenness.dds`,
  `Frostbite.dds`, `Heatstroke.dds`, `MagesBane.dds`, `FightersBane.dds`,
  `ThiefsBane.dds`) — each currently just a copy of the existing
  `textures/overlays/ThiefsBane.dds` overlay texture, since no real icon
  art exists yet. `RN.STATUS_ICON_PATHS` in `StatusIcons.lua` (shared by
  all 3 icon display variants) now points at these bundled files using the
  same `RealisticNeedsAndDiseases/textures/...` path convention the
  overlay textures already use, rather than a generic ESO fallback icon.
  Swap the 9 files in `textures/icons/` for real generated art later — no
  code changes needed.
- **Removed `ICON_BRIEF.md`** from the package.

---

### 0.19.20
- **New: transparency-based icon status display (third variant).** New file
  `RealisticNeedsAndDiseases_StatusIconsTransparency.lua`, opt-in via
  Settings > "Use icon-based status display (transparency)" (off by
  default). A third sibling alongside 0.19.18's "Badge & Pip" and 0.19.19's
  simple color-tint displays — independent toggle, any combination of the
  three (plus the original text window) can run at once.
  - Fully transparent (alpha 0) = need satisfied / disease not present.
    Fully opaque (alpha 1) = need completely empty / disease at Severe.
    No color tint, no border, no pips at all — opacity is the only
    variable.
  - Layout is fixed: all 4 need icons and all 5 disease icons occupy the
    same position for the window's lifetime, unlike the other two displays'
    dynamic show/hide — only each icon's alpha changes on refresh.
  - Reuses the same placeholder icons/`RN.STATUS_ICON_PATHS` table as the
    other two icon displays.
  - Worth playtesting against the other two: a satisfied need or absent
    disease is genuinely invisible (not just faint), which is what was
    asked for, but does mean nothing's there to notice or hover until
    something starts going wrong.

---

### 0.19.19
- **New: simpler alternate icon-based status display.** New file
  `RealisticNeedsAndDiseases_StatusIconsSimple.lua`, opt-in via Settings >
  "Use icon-based status display (simple color-tint)" (off by default).
  A simpler sibling to 0.19.18's "Badge & Pip" icon display, not a
  replacement — both have independent toggles and can run alongside each
  other and/or the text status window. This one is the generic buff-icon
  pattern: a plain icon per active status, tinted by severity (flat color
  multiply on the icon texture, no border/pip system), shown only while
  that status is actually active — a need past its comfortable band, or a
  contracted disease — same as any standard buff/debuff icon row, rather
  than a fixed always-visible 4-need layout.
  - Reuses the same placeholder icons and `RN.STATUS_ICON_PATHS` table (and
    the same `ICON_BRIEF.md` art brief) as 0.19.18's display — swapping in
    real art updates both at once.
  - Has no background panel (matching classic buff-icon rows — just icons
    floating), which means it can only be grabbed for dragging in the small
    padding gaps between icons rather than the icons themselves. Untested
    in-game whether that's workable in practice; a "Reset icon status
    window position (simple color-tint)" button is included as a fallback.

---

### 0.19.18
- **New: icon-based status display (proof of concept).** New file
  `RealisticNeedsAndDiseases_StatusIcons.lua`, opt-in via Settings > "Use
  icon-based status display (proof of concept)" (off by default, runs
  alongside the existing text status window rather than replacing it).
  Deliberately a different visual language than the label-above-value text
  row pattern this addon's own StatusBar already uses (itself credited to
  the RolePlayNeeds reference addon) — a horizontal row of icon badges (one
  per need, plus one per currently-active disease) with a small "pip" dot
  row under each badge whose LIT COUNT is the severity readout (4 pips for
  needs' 4 bands, 3 pips for diseases' 3 severities), rather than encoding
  severity through icon tint or a number overlay.
  - All 9 icons currently point at ESO's own placeholder texture
    (`EsoUI/Art/icons/icon_missing.dds`) — swap `RN.STATUS_ICON_PATHS` at
    the top of the new file for real art once available; nothing else
    needs to change.
  - Added `ICON_BRIEF.md`, a self-contained AI-art-generation prompt for
    each of the 9 icons plus a shared style guide, so the placeholder art
    can be replaced with generated icons matching the existing colored-
    border/pip severity system (the icon art itself doesn't need to encode
    severity through color).
  - Drag-movable independently of the text status window's position; new
    "Reset icon status window position" button added alongside the
    existing one.

---

### 0.19.17
- **Needs and disease systems fully decoupled, with a new true master
  switch.** Previously, `needsSystemEnabled` doubled as an undocumented
  master switch — `OnTick` returned early entirely whenever it was off,
  silently skipping disease processing too, while `diseaseSystemEnabled`
  couldn't stop combat-triggered disease contraction from happening with
  needs off, and consumption crediting (food/drink/water restoring needs,
  ingredients curing disease) wasn't gated by either toggle at all. Settings
  now has 3 independent switches:
  - **Enable the addon** (new `masterEnabled`) — the actual master switch.
    Freezes everything: needs decay, all consumption crediting, disease
    contraction/progression/self-cure, and curing.
  - **Enable needs tracking** (`needsSystemEnabled`) — hunger/thirst/
    fatigue/drunkenness decay and restoration only. Fully independent of
    disease processing now.
  - **Enable the disease system** (`diseaseSystemEnabled`) — contraction,
    progression, and self-cure only. Curing an existing disease still works
    even with this off; only needs decay/restoration is unaffected either way.
  - You can now turn off needs tracking and leave the disease system running
    (or vice versa) — the scenario this version was built to support.
  - Heads up if you'd previously turned `needsSystemEnabled` off expecting it
    to act as a master off switch: after this update, the disease system
    will resume running unless you also turn off the new "Enable the addon"
    toggle (default: everything on).

---

### 0.19.16
- **New debug command: `/rnd debug skipprogression <1-5>`** — fast-forwards
  an active, below-Severe disease's untreated-stage progression timer to one
  tick (~5s) short of both its 30-minute threshold and its 5-minute reroll
  interval, so the very next tick fires the escalation roll immediately
  instead of requiring up to 35 minutes of real-time waiting. Makes it
  practical to test the 0.19.15 stage-progression mechanic (including
  repeatedly, to see the 15% chance actually land or miss) without sitting
  around. Requires the target disease to already be active (`/rnd debug
  disease` first if needed) and not already Severe.

---

### 0.19.15
- **Craft bag reagent consumption now cures/progresses diseases too.**
  Remedy-ingredient detection previously only watched `BAG_BACKPACK`, so a
  player with craft bag access — where raw reagents auto-deposit instead of
  sitting in the backpack — could eat a curative ingredient straight from the
  craft bag and see no effect at all. Added a second `BAG_VIRTUAL`-filtered
  registration onto the same handler; the existing per-slot tracking already
  keys by `bagId .. ":" .. slotId`, so backpack and craft bag slots never
  collide.
- **Disease stage progression:** an untreated Mild or Moderate case now has a
  chance to worsen on its own after 30 real-world minutes at that stage,
  rerolling every 5 minutes thereafter (15% per reroll) until it either
  escalates or gets treated. Applies to all 5 diseases; Severe cases don't
  roll since there's nowhere higher to go. The 30-minute clock is tracked per
  stage (any severity change resets it) and persists across a relog rather
  than resetting on logout.
- **Frostbite/Heatstroke self-cure:** a Mild (stage 1) case now has a chance
  to clear up on its own once the player has been continuously out of the
  qualifying cold/heat range for 30 real-world minutes, rerolling every 5
  minutes thereafter (15% per reroll). Only applies at Mild — Moderate/Severe
  still need an ingredient or the care-cure path. Re-entering the
  qualifying temperature range resets the clock.
- The 15% reroll chance used by both new mechanics above is a starting
  default, not a confirmed balance number — worth tuning from actual play
  and eventually exposing in Settings.

---

### 0.19.14
- **Fixed an intermittent food/drink consumption miss** where eating or
  drinking with no other inventory activity would occasionally not restore
  hunger/thirst, requiring a second try. The buff-confirmation gate that
  guards against false positives (selling, banking, etc.) only checked
  BACKWARD in time — was a food/drink buff granted recently, as of the
  inventory-shrink event? ESO doesn't guarantee the buff-gain event and the
  inventory-shrink event fire in a fixed order, so whenever the shrink was
  processed first, the buff timestamp wasn't set yet and the genuine
  consumption was silently dropped. The check is now bidirectional: an
  inventory shrink with no recent buff is held as a pending consumption for
  up to the same 500ms window, and is credited retroactively if the
  confirming buff event arrives shortly after.

---

### 0.19.13
- **Band-transition notifications (the top-right alert banner for hunger/
  thirst/fatigue/drunkenness crossing into a new band) now fire
  immediately** when a need changes from water-solvent harvesting or
  food/drink consumption, instead of waiting for the next periodic tick
  (every 5 seconds). Previously, `OnLootReceived` and `HandleConsumedItem`
  updated the underlying need value directly but never called
  `Feedback.CheckBandTransition` themselves — only the periodic `OnTick`
  did, so a band-crossing notification could lag the actual change by up
  to ~5 seconds. `CheckBandTransition` is idempotent (it only notifies if
  the band actually changed), so calling it both immediately and again on
  the next tick is safe — the tick's call just sees nothing changed and
  does nothing.

---

### 0.19.12
- **Fixed a mislabeled parameter in `OnLootReceived`** (the water-solvent
  thirst-restore handler). Its 3rd parameter was named `itemLink` and
  passed to `GetItemLinkName()` to build the "You drink from the X"
  message, but per the real, now-confirmed `EVENT_LOOT_RECEIVED` signature
  (`eventId, receivedBy, itemName, quantity, soundCategory, lootType,
  isSelf, isPickpocketLoot, questItemIcon, itemId, isStolen`), that
  parameter is actually the item's plain display name, not a formatted
  item link — `GetItemLinkName` expects a real link string and would fail
  to parse a bare name, so the message silently fell back to its generic
  "water source" text every time instead of showing the real item name.
  The itemId-based thirst restore itself was never affected by this — only
  the message text. Renamed the parameter to `itemName` and used it
  directly.

---

### 0.19.11
- Manifest `## APIVersion` updated to `101050 101051`, covering the newly
  released 101051 alongside the previous 101050.

---

### 0.19.10
- **Added native event filters to both `EVENT_INVENTORY_SINGLE_SLOT_UPDATE`
  registrations** (food/drink consumption in the main file, and remedy-
  ingredient consumption in `Disease.lua`) — previously neither had any
  `AddFilterForEvent` at all; bag filtering was done manually in Lua
  (`if bagId ~= BAG_BACKPACK then return end`). Both are now filtered at
  the engine level to `REGISTER_FILTER_BAG_ID` = `BAG_BACKPACK` AND
  `REGISTER_FILTER_INVENTORY_UPDATE_REASON` = `INVENTORY_UPDATE_REASON_DEFAULT`
  in the same `AddFilterForEvent` call (multiple filter type/value pairs
  can be passed to one call) — the update-reason filter matters because
  this event also fires for non-consumption reasons like durability or
  charge changes, which the bag filter alone wouldn't exclude. The
  existing manual Lua-side bag checks are left in place as harmless
  redundancy.

---

### 0.19.9
- **Fixed a self-contradictory claim in the README's "How fatigue works"
  section.** It said fatigue has "no activity tracking (no movement-speed
  sampling, no combat-time accounting)" and listed only 2 mechanisms —
  but the addon has always had a third, real mechanism: stamina-exertion
  tracking (`EVENT_POWER_UPDATE` feeding `Calc.GetExertionMultiplier()`),
  which very much is a form of activity tracking. This wasn't a recent
  change — the mechanic has been in the code for a while and was already
  correctly described in the Known Gaps section — the "How fatigue works"
  section's summary just hadn't been kept in sync with it. Added it as its
  own numbered item alongside the temperature-acceleration mechanic, and
  removed the inaccurate "no activity tracking" framing.

---

### 0.19.8
- **Removed six `/rnd debug` subcommands**: `ingredients`, `combat on|off`,
  `loot on|off`, `power on|off`, `testemote`, and `libcheck`.
- **Deleted `RealisticNeedsAndDiseases_DebugHelper.lua` entirely** — every
  function in that file existed solely to back one of the six removed
  commands, so once they were gone the whole file (and its two dead
  `EVENT_COMBAT_EVENT`/`EVENT_LOOT_RECEIVED` debug-dump registrations) was
  unreachable dead code. Removed it from the manifest's file list and the
  now-empty `RN.DebugHelper.Initialize()` call in `OnAddOnLoaded`.
- Removed `Feedback.TestCategoryEmote()` (only caller was `testemote`) and
  the `Calc.LastPowerUpdateRaw` debug-only capture (only reader was the
  removed `power` command) — the real stamina-exertion tracking in
  `Calculator.lua`'s `OnPowerUpdate` is untouched and still fully
  functional, only the debug-display side-channel was removed.
- Updated the README's Slash Commands and Known Gaps sections, and a
  couple of stale in-code comments, to stop referencing the removed
  commands.
- **Cut the max unaided drunkenness recovery time in half** — the "Hours
  to sober up unaided (no resting)" slider's range was 1–6 hours; it's now
  1–3. The default (2 hours) is unchanged.

---

### 0.19.7
- **Moved all remaining top-level event registrations into deferred
  Initialize() functions**, matching the same fix applied to Frostfall.
  Previously, several events were registered the moment their file loaded
  — before `RN.SavedVars` exists — including two that drive real gameplay
  logic: `Disease.lua`'s `EVENT_COMBAT_EVENT` (disease contraction from
  combat damage) and `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` (disease curing
  via ingredient consumption). Also moved: the main file's merchant/
  crafting-station/bank gating (8 events), the food/drink buff tracker and
  inventory-consumption detection, the first-login inventory-slot seed,
  water-loot thirst restore, `Calculator.lua`'s `EVENT_POWER_UPDATE`
  (stamina-exertion tracking), and `DebugHelper.lua`'s combat/loot debug
  dumps. `Disease.lua`, `Calculator.lua`, and `DebugHelper.lua` each gained
  a new `Initialize()` function (matching the existing pattern already
  used by `Overlay`, `StatusBar`, `Feedback`, `Rest`, and `Settings`),
  called from the main file's `OnAddOnLoaded` alongside the others.
  Verified with a load test that captures every `EVENT_MANAGER:
  RegisterForEvent` call: exactly one registration (the `EVENT_ADD_ON_LOADED`
  bootstrap itself) exists before `OnAddOnLoaded` fires, and all 17 other
  events register correctly, with no errors, once it does.

---

### 0.19.6
- **Fixed the one real global-variable leak in the addon.** `RND_CheckNeeds()`
  was a bare global function (also called directly from `bindings.xml`'s
  keybind). Converted to `RN.CheckNeeds()` — i.e. `RealisticNeeds.CheckNeeds`
  — and updated `bindings.xml` to call `RealisticNeeds.CheckNeeds()` (the
  actual global table; keybind XML has no access to a Lua file's local
  aliases, so it can't call `RN.CheckNeeds()` directly). Verified with a
  full load test that diffs `_G` before/after loading every file: the
  addon now introduces exactly one global, `RealisticNeeds`, and nothing
  else.
- **SavedVariables are now server-dependent.** `ZO_SavedVars:NewAccountWide`
  previously passed `nil` for the namespace argument, so EU, NA, and PTS all
  read and wrote the same account-wide save table. Now namespaced by
  `GetWorldName()`, so each server keeps its own data. Settings set before
  this version will appear reset the first time you load each server after
  updating.
- Manifest cleanup: `## APIVersion` trimmed to only the latest (101050);
  `## OptionalDependsOn` version floors removed (`Frostfall>=3 LibZoneTemp>=12`
  → `Frostfall LibZoneTemp`) — a version tag on an optional dependency can
  still block loading if that dependency is present but older, which
  defeats the purpose of it being optional.
- Updated the AI-assistance notice in the manifest description and README
  to state the addon has been reviewed and tested in-game by the author,
  rather than "UNTESTED."
- Split the changelog out of `README.md` into this file, and reformatted
  `README.md` into BBCode for the ESOUI addon description page. Also
  removed two stale mentions of a "fade-to-black" screen effect that no
  longer exists in the code (removed in an earlier version), and expanded
  the Slash Commands section to list several `/rnd debug` subcommands
  (`checkneeds`, `power`, `frostbiteTimer`, `heatstrokeTimer`, `libcheck`)
  that existed in code but had never been documented in the README.
- The Dependencies section no longer lists minimum version numbers — it
  just tells users to install the newest version of each.

---

### 0.19.5
- **Corrected a misattribution to RolePlayNeeds**, verified against the
  official published v0.7 BETA release (the developer supplied the actual
  release zip for comparison). Three things previously credited to
  RolePlayNeeds in the README's Credits section, and referenced as
  RPN-verified in code comments, do not exist in RolePlayNeeds' real
  published source — they were additions made to a local, personally-
  modified copy of RolePlayNeeds, not the published addon:
  - A `RPN_REAGENT_TRAITS` alchemy-trait lookup table (no such table, and
    no "reagent" string at all, appears anywhere in RolePlayNeeds' source).
  - A "two-stage" water-loot detection fix (RolePlayNeeds' actual
    `EVENT_LOOT_RECEIVED` handler is single-stage, with no inventory-update
    confirmation step).
  - A labeled-row HUD/window layout (RolePlayNeeds' real UI is a set of
    small per-meter icon windows, structurally nothing like this addon's
    or Frostfall's label+value+status row layout).
  - Two credits were confirmed genuinely accurate and are kept: the
    `bindings.xml`/keybind naming convention, and the inventory-seed-on-
    login fix (`ForceInventoryScan()` on `EVENT_PLAYER_ACTIVATED`).
  - Corrected the affected code comments in `RealisticNeedsAndDiseases_Data.lua`
    (Mage's Bane's ingredient-sourcing note, which also named the wrong
    ingredients — Fighter's Bane's set, not Mage's Bane's own) and
    `RealisticNeedsAndDiseases.lua` (the water-loot detection note) to stop
    claiming RPN corroboration for data that was never actually corroborated
    against it.

### 0.19.4
- **Corrected the README's "Diseases" section, which still described the
  disease roster from before the 0.14.0–0.16.0 overhaul** (Bone Chill, Swamp
  Rot, Ashen Cough, Blood Fever, Wormwood Plague — all since renamed,
  redesigned, or removed) instead of the current 5: Frostbite, Heatstroke,
  Mage's Bane, Fighter's Bane, Thief's Bane. Also fixed:
  - The overview paragraph's disease count ("6 independently-trackable" →
    "5") and the manifest's `## Description` ("7 diseases" → "5").
  - The trigger/trait/ingredient tables, rewritten to match
    `RealisticNeedsAndDiseases_Data.lua`'s actual current definitions,
    including the two real trigger mechanisms (sustained exposure for
    Frostbite/Heatstroke vs. per-hit damage-type for the other three) and
    their real Settings-panel chance caps (0–50% vs. 0–10%).
  - The "only itemId is unverified" claim, which was stale now that nearly
    every ingredient has a real in-game-scanned `itemId` — only Thief's
    Bane's tier-3 Dragon's Blood is still unconfirmed.
  - The `/rnd debug disease <1-5>` index labels, the "Known gaps" section's
    Ashen-Cough-specific bullets, the Settings-panel summary's Wormwood
    Plague reference, and a leftover `/realneeds` mention (the alias was
    removed in an earlier version — replaced with `/rnd checkneeds`).
  - This section (and the changelog entries below it) is a historical
    record and intentionally left describing the old names as they existed
    at the time.

### 0.19.3
- **Fixed the settings panel's author field**, which still read the older
  `"Krek (@Kreksar5)"` form rather than the now-standardized `"@Kreksar5 and
  Claude.ai"`. The panel's `version` field already read from `RN.VERSION`
  correctly; that constant is bumped alongside the manifest going forward.

### 0.19.2
- **Expanded the "Overlay art credit" note** for the disease status-overlay
  images to also credit Google's Gemini Image Creator (alongside the
  Perchance AI Text-to-Image Generator) for generation, and Paint.NET for
  editing/converting them to the game's `.dds` format.

### 0.19.1
- **Standardized the author credit** to `@Kreksar5 and Claude.ai` in the
  `## Author` manifest field and this README's byline, and named Claude.ai
  specifically (rather than generic "AI assistance") in the manifest
  description and the AI-assistance disclosure above, matching the crediting
  convention used across this addon's companion libraries.

### 0.19.0
- **Added a standalone "Enable the disease system" toggle** in Settings, next
  to the disease contraction-chance sliders. Independent of the existing
  master "Enable the needs/disease system" switch: turning this off stops all
  new disease contraction and severity escalation (both the sustained cold/
  heat exposure path and the combat-damage path funnel through the same
  `RollContraction` choke point in `RealisticNeedsAndDiseases_Disease.lua`,
  so gating it there covers both with one check) while leaving hunger,
  thirst, fatigue, and drunkenness decaying/restoring exactly as normal.
  Curing an already-active disease still works while this is off. Disease
  overlay tints clear the moment this is switched off and reappear at their
  correct severity when switched back on, mirroring how the master switch
  already handles overlays. The `/rnd status` (`/rnd`) command now also notes
  when the disease system specifically is off (separate from the existing
  note for the master switch).
- **Fixed `RN.VERSION` being stuck at `"0.18.0"`** in
  `RealisticNeedsAndDiseases.lua` — it hadn't tracked the manifest's
  `## Version` since 0.18.1, so `/rnd status` and the settings panel's
  displayed version were both quietly stale. Now synced to match the
  manifest.

### 0.18.9
- **Added the required `## AddOnVersion` tag** (previously missing entirely —
  this is the integer the ingame addon manager and Minion use to detect
  updates, separate from the informational `## Version` tag). Started at 9.
- **Added a version floor (`>=19`) to the `LibFoodDrinkBuff` dependency**,
  which previously had none.
- **Bumped the optional `LibZoneTemp` dependency floor** from `>=10` to
  `>=12`, matching LibZoneTemp's current `## AddOnVersion`.
- **Added the AI-assistance disclosure to the manifest description** (it was
  already present in this README, but not in the manifest's `## Description`,
  which is what Minion shows at a glance).
- **Added a Credits section** naming RolePlayNeeds (matheusbk2) and No
  Interact (Rhyono) for the implementation techniques referenced during
  development.

### 0.18.8
- **Full API audit against the official ESOUI API 101050 documentation.**
  Every function call, method call, and constant referenced across the addon
  was cross-checked against the API doc and, where the doc didn't cover it
  (manager singletons, `ZO_` helpers, third-party libraries), against the
  live ESOUI source.
- **Fixed a nonexistent constant in the combat-event filter**:
  `REGISTER_FILTER_TARGET_TYPE` does not exist anywhere in the ESO API and
  would have errored registering the disease-contraction combat-event
  filter. Corrected to `REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE`, the real
  constant (confirmed against both the API doc and live ESOUI usage).
- Everything else checked out: `EVENT_MANAGER`, `SCENE_MANAGER`,
  `PLAYER_EMOTE_MANAGER`, `RETICLE`, `INTERACTIVE_WHEEL_MANAGER`, `ZO_Alert`,
  `ZO_PreHook`, `ZO_CreateStringId`, and the `LibFoodDrinkBuff`/
  `LibAddonMenu`/`LibSavedVars` calls are all legitimate and correctly used.

### 0.18.7
- **Added `/rnd debug emptyNeeds`** — the inverse of the existing
  `/rnd debug resetneeds`: drops hunger/thirst/fatigue to 0 and drunkenness
  to 100 (its worst value, since high drunkenness is the bad state), for
  quickly reaching a state where the recovery mechanics actually have
  something to recover without waiting for real decay. Doesn't touch
  diseases, same as `resetneeds`.
- **Sitting/sleeping now prints a chat-only confirmation on entering rest
  mode** ("You take a seat to rest." / "You settle in to sleep."), restoring
  feedback that existed under the old `/rnd sit`/`/rnd sleep` commands but
  had gone silent once those commands were removed in favor of automatic
  detection. Added at the single shared point (`OnSitTriggered`/
  `OnSleepTriggered` in `Rest.lua`) that every detection path funnels
  through, so it fires the same way regardless of which path triggered it,
  and only on the actual transition into that pose — not on every
  re-trigger while already resting, to avoid spamming chat.

### 0.18.6
- **Further expanded the sit-recognition word list** with more synonyms for
  "an object you sit on": "stool", "pew", "throne", "couch", "sofa",
  "settee", "loveseat", "ottoman", "stump", "log" (alongside the existing
  "sit", "seat", "chair", "bench"). Only "Sit" and "Chair" have actually
  been observed in-game; the rest are speculative/defensive the same way
  "Sleep" already was — harmless if they never match anything real.

### 0.18.5
- **Expanded the world-object sit-recognition word list** from just "Sit" to
  "Sit", "Seat", "Chair", "Bench". Also widened what gets checked against
  that list: previously only the reticle's action verb was captured; now the
  interactable's own name (e.g. "Wooden Chair", "Tavern Bench") is captured
  alongside it and both are checked together, since "Chair"/"Bench" are
  realistically going to appear in an object's name rather than in the verb.

### 0.18.4
- **Fixed the world-object "Sit" interaction detection silently never
  firing.** No crash this time — the addon loaded fine, but interacting
  with a real chair never engaged fatigue tracking or the
  emote-interruption protection, even though the fix in 0.18.3 resolved the
  load errors. Root cause: `GetGameCameraInteractableActionInfo()` returns
  `(action, interactableName, ...)` — the reticle prompt's *verb* ("Sit",
  "Loot", "Talk to") is the FIRST value, and the target's own display name
  ("Wooden Chair", an NPC's name, etc.) is the SECOND. The code was doing
  `local _, text = GetGameCameraInteractableActionInfo()`, which discards
  "action" and keeps "interactableName" — copied directly from NoInteract's
  own destructuring without noticing NoInteract wants
  `interactableName` for ITS purpose (matching NPC/object names against a
  blacklist), the opposite of what this addon needs (matching the action
  verb "Sit"). Since object display names essentially never contain the
  literal word "sit", the word-match silently never matched anything. Fixed
  to read `action` (the first return value) instead.

### 0.18.3
- **Fixed a second load-time crash**: `Attempt to access a private function
  'GameCameraInteractStart' from insecure code`. 0.18.2's fix for the
  previous crash had reassigned the bare global `GameCameraInteractStart`,
  reasoning it was the function the interact keybind calls — true, but it
  turns out to be a genuinely protected engine function that addons cannot
  even read, let alone override. Traced the actual current keybind chain in
  ESOUI's `bindings.xml`:
  `if not INTERACTIVE_WHEEL_MANAGER:StartInteraction(ZO_INTERACTIVE_WHEEL_TYPE_FISHING)
  then GameCameraInteractStart() end`
  — `INTERACTIVE_WHEEL_MANAGER` is a plain, unprotected Lua object (the
  direct successor to the now-removed `FISHING_MANAGER`), and its
  `:StartInteraction` method fires on every single interact keypress before
  the engine ever considers falling through to the protected call. Hooked
  that instead — same reassign-and-preserve-original pattern NoInteract
  uses, just pointed at the object that actually exists and is actually
  reachable in the current client.

### 0.18.2
- **Fixed a load-time crash** (`attempt to index a nil value` in
  `HookWorldInteractionDetection`) caused by 0.18.1's world-object
  interaction hook reassigning `FISHING_MANAGER.StartInteraction` — ZOS has
  removed the standalone `FishingManager` class from the current client, so
  that global no longer exists at all. Root cause went deeper than a missing
  nil-check, though: pulling the current ESOUI source (github.com/esoui/esoui)
  confirmed that function was never actually the right hook for this even
  when it did exist — `FISHING_MANAGER:StartInteraction()` only ever
  dispatched to the fishing radial-wheel UI, so it would never have fired for
  a chair's "Sit" prompt regardless. Replaced with a hook on the bare global
  `GameCameraInteractStart()`, confirmed via
  `esoui/ingame/globals/bindings.xml`'s `GAME_CAMERA_INTERACT` keybind
  definition to be exactly what the interact key invokes for ordinary
  (non-fishing-wheel) interactions. Also upgraded the native `/sit`/`/sleep`
  slash-command hooking from "assumed reliable" to confirmed: the current
  source shows ZOS's own `PLAYER_EMOTE_MANAGER` registers those commands into
  the same addon-visible `SLASH_COMMANDS` table this addon hooks.

### 0.18.1
- **Added world-object interaction detection for sitting.** Interacting with
  a real in-world chair/bench (reticle prompt "Sit") now starts the same
  fatigue-recovery/emote-interruption-protection tracking as `/rnd sit` used
  to, without needing any slash command at all. Modeled on the NoInteract
  addon's (by Rhyono) two-hook reticle-interaction pattern: `ZO_PreHook` on
  `RETICLE:TryHandlingInteraction` to read the current prompt text via
  `GetGameCameraInteractableActionInfo()`, and wrapping
  `FISHING_MANAGER.StartInteraction` (original preserved, always called) as
  the point where the interaction is actually confirmed. RND never blocks
  the interaction — only observes it. Matching is whole-word (not substring),
  so prompts like "Deposit" or "Visit" can't false-positive against "Sit".
  See `Rest.lua`'s `HookWorldInteractionDetection`.
- **Removed `/rnd sleep` and `/rnd sit`.** Now that native `/sit`-/`/sleep`-
  family command hooking and the new world-object interaction detection
  both reliably start rest tracking on their own, the explicit commands
  (which existed specifically to *guarantee* tracking started, back when
  the native-command hook's reliability was still uncertain) are obsolete.
  Sitting/sleeping normally — by any means — now triggers fatigue recovery
  and emote-interruption protection automatically; `Rest.TriggerSit()` /
  `Rest.TriggerSleep()` are removed along with the commands.
- **Removed the `sleepPose`/`sitPose` configurable-emote settings.** These
  existed only to let `/rnd sleep`/`/rnd sit` play a player-chosen emote
  for that category; with those commands gone there's no remaining code
  path that plays a "configured" sit/sleep emote — whatever the player
  actually does (which real emote, which chair) is simply the emote.
  Removed from `Feedback.EMOTE_DISPLAY_DEFAULTS`/`EMOTE_SLASH_FALLBACKS`/
  `EmoteIds`, the Settings emote dropdown list, `emoteChoiceId` defaults,
  and `/rnd debug testemote`'s category list.

### 0.17.2
- **Fixed Frostfall version gate in manifest** — `OptionalDependsOn` was
  declaring `Frostfall>=4`, which caused ESO's addon loader to treat Frostfall
  as absent even when v3.x (including v3.4.4) was installed. RND then fell back
  to LibZoneTemp's raw ambient zone temperature for all temperature checks,
  silently bypassing Frostfall's insulation, weather/precipitation, swimming
  drag, and spell-resist reagent buff. Changed to `Frostfall>=3` so the 3.x
  series is correctly recognized.
- **No code changes required** — `Calculator.GetCurrentTemperature()` already
  called `Frostfall:GetEffectiveTemp()` (not `GetZoneAmbientTemp()`) when
  Frostfall was present, which is the correct value: the player's physical
  temperature after insulation/weather/swimming drift, plus any active
  spell-resist reagent offset. All hunger/thirst/fatigue decay acceleration and
  frostbite/heatstroke exposure checks therefore already used effective
  temperature — the manifest gate was the only thing preventing them from doing
  so when Frostfall 3.x is installed.
- Expanded the `GetCurrentTemperature()` comment block in Calculator.lua to
  document what `GetEffectiveTemp()` includes, and added a note explaining the
  manifest version gate and what happens if it fails.


- **Reduced Frostbite/Heatstroke's initial exposure threshold from 10
  minutes to 5 minutes**, per request — `Disease.EXPOSURE_THRESHOLD_SECONDS`
  is now `300` instead of `600`. The first contraction roll now happens
  after 5 minutes of continuous qualifying exposure instead of 10; the 60s
  re-roll interval after that threshold (0.17.0) is unchanged. Updated the
  matching comments in Data.lua, Disease.lua, and the main file, and the
  Settings panel's description text, so nothing still says "10 minutes."

### 0.17.0
- **Corrected misunderstanding from 0.16.0**: Frostbite/Heatstroke's
  contraction check now actually REPEATS every 60s once the initial 600s
  exposure threshold is met, for as long as the player stays in the
  qualifying temperature range — it doesn't just roll once and then wait
  out another full 600s. 0.16.0's "verification" confirmed the OLD
  single-roll-per-threshold-crossing behavior was internally consistent,
  but that behavior itself was wrong per what was actually wanted here;
  this is the real fix.
  - `CheckSustainedCold`/`CheckSustainedHeat` are now both thin wrappers
    around a new shared `CheckSustainedExposure` helper in Disease.lua.
    Exposure time keeps accumulating past the 600s threshold (it no longer
    resets at that point); once past it, a second timer
    (`rollTimerSeconds`, new) ticks up and fires a contraction roll every
    `Disease.EXPOSURE_REROLL_INTERVAL_SECONDS` (60s, new constant).
  - It stops repeating the instant EITHER stated condition is met: the
    disease is contracted (`sv.diseaseState[diseaseId]` becomes non-nil —
    checked every tick before rolling, so it can't roll once more after
    contracting), or the player leaves the qualifying temperature range
    (both timers reset to 0 immediately, so re-entering starts the full
    600s wait over from scratch, not a resumed countdown).
  - If a roll succeeds, the long 600s exposure timer is ALSO reset at that
    moment (on top of the disease now blocking further rolls) — so if this
    case gets cured later while the player is still standing in the same
    cold/heat, it requires a full fresh 600s wait before anything can roll
    again, rather than immediately resuming 60s re-rolls right after a cure.
  - Sandbox-simulated 30 minutes of continuous exposure to confirm this
    behaves as intended: first roll at 660s (600s wait + first 60s
    interval), further rolls roughly every 60s after that, stopping
    immediately on contraction; also confirmed leaving exposure zeroes
    both timers.
  - `/rnd debug frostbiteTimer`/`heatstrokeTimer` (0.16.0) updated to match:
    they now report which of three states you're in — not yet at the
    initial threshold, past it and actively re-rolling every 60s, or
    already contracted and not currently rolling at all — rather than a
    single elapsed/remaining number that no longer matched the real
    mechanic. `Disease.GetSustainedExposureStatus` now also takes `sv` (to
    check whether the disease is already active) and reports
    `pastThreshold`/`contracted`/`rerollIntervalSeconds`/`rollTimerSeconds`
    alongside the original fields.

### 0.16.0
- **Verified, by direct code inspection: Frostbite/Heatstroke's contraction
  check does NOT fire repeatedly after the threshold is met.** In both
  `CheckSustainedCold` and `CheckSustainedHeat`, the exposure counter is
  reset to 0 in the SAME branch that calls `RollContraction`, immediately
  before the roll — so once the threshold crosses, the very next tick
  starts accumulating from 0 again, and a full new
  `EXPOSURE_THRESHOLD_SECONDS` (600s) must elapse before the next roll.
  The contraction check fires exactly once per threshold-crossing, not on
  every later tick spent still standing in the cold/heat past the
  threshold. No code change was needed here — this was a read of the
  existing logic, confirming it was already correct.
- **Added `/rnd debug frostbiteTimer` and `/rnd debug heatstrokeTimer`.**
  Each prints whether you're currently in the qualifying temperature range,
  the current temperature, elapsed/threshold exposure seconds, time
  remaining until the next contraction roll, and the dice-roll chance that
  roll will actually succeed (`sv.settings.diseaseChances.<id>`). Backed by
  a new `Disease.GetSustainedExposureStatus(kind)` accessor (`kind` is
  `"cold"` or `"heat"`) that reads the exact same `exposureSeconds` counter
  `CheckSustainedCold`/`CheckSustainedHeat` themselves use — this is a
  read-only view of the real running state, not a separate estimate that
  could drift out of sync with it. If you're not currently exposed, it
  says so rather than printing a stale or misleading countdown (the real
  counter resets to 0 the instant you leave the trigger range, so there's
  nothing counting down until you re-enter it).

### 0.15.0
- **Ashen Lung removed completely, per request** (0.14.0/0.14.1/0.14.2's
  disable-but-keep-the-code approach is gone — this isn't a deeper hide,
  it's an actual deletion):
  - Removed from `RN.DISEASE_ORDER` and `RN.Diseases` (Data.lua) — its
    disease definition, cure ingredients, and flavor text no longer exist
    anywhere.
  - Removed `RN.ASHEN_LUNG_EXCLUDED_HOUSES` (the ~100-entry player-house
    list) entirely — it had no other purpose.
  - Removed `Disease.CheckVolcanicHeatExposure`, its call in
    `Disease.OnTick`, and its three constants
    (`VOLCANIC_HEAT_THRESHOLD_CELSIUS`, `VOLCANIC_EXPOSURE_THRESHOLD_SECONDS`,
    and the `volcanicHeatExposure` exposure-timer entry) from Disease.lua.
  - Removed `Calculator.GetCurrentZoneName()` — it existed solely to
    support Ashen Lung's house-exclusion check and had no other callers.
  - Removed the whole `Disease.ASHEN_LUNG_ENABLED`/`Disease.IsDiseaseEnabled`
    disable-switch mechanism added in 0.14.0–0.14.2 — it existed
    specifically to hide Ashen Lung without deleting it; now that it's
    actually deleted, the indirection has nothing left to gate. Settings.lua,
    DebugHelper.lua, and the main file's `/rnd debug` usage builder are all
    reverted to their simpler pre-0.14.0 forms (just without Ashen Lung).
  - `RN.DISEASE_ORDER` is now `{ frostbite, heatstroke, bloodworms, mageBane,
    fightersBane, thiefsBane }` — 6 entries. `/rnd debug disease <1-6>`;
    index 3 (Ashen Lung's old slot) is gone rather than left as a gap, since
    there's no longer any reason to preserve a hole for a disease that no
    longer exists at all.
  - Removed `textures/overlays/AshenLung.dds` from the package.
  - Thief's Bane keeps its Restore Stamina ingredient set (Blessed Thistle /
    Chaurus Egg / Dragon's Blood) — it was always its own copy of the data,
    just originally commented as "shared with Ashen Lung." That comment
    is now corrected; the ingredients/itemIds themselves are unchanged.
- **Found and fixed the actual cause of the sleep/sit-pose emote interrupt**
  (0.13.0's gating logic was correct but insufficient — this is the real
  fix). Root cause: `Rest.lua`'s movement detection used a single 5-world-
  unit tolerance (`POSITION_EPSILON`) for two very different purposes — (a)
  detecting "stood still long enough to regen" and (b) detecting "got up
  out of the sit/sleep pose." The pose-transition animation itself (and
  likely ongoing idle sway while held) plausibly shifts the tracked root
  position by more than 5 units within a single 5-second tick on its own,
  which was flipping `_isSeated`/`_isSleeping` back to `false` within
  roughly one tick of being set — re-opening `CanPlayEmotesNow`'s gate and
  letting a status emote fire (and visibly cancel the pose) only seconds
  into `/rnd sleep` or `/rnd sit`, even though the emote-gating logic itself
  was working exactly as designed.
  - Added a separate, much more lenient `REST_POSITION_EPSILON` (150 world
    units) used only while `_isSeated`/`_isSleeping` is already true;
    `POSITION_EPSILON` (5) still governs the idle-standing regen mechanic
    unchanged.
  - `OnSitTriggered`/`OnSleepTriggered` now reset the position baseline
    (`_lastPosition = nil`) at the moment a pose starts, so the
    settle-into-pose position shift itself is never compared against a
    pre-pose baseline at all — eliminating the original one-tick race on
    top of widening the ongoing tolerance.
  - **Honesty note**: 150 is a deliberately generous guess, NOT measured
    against real in-client position deltas during a sleep/sit pose. If
    interruptions still happen after this, the right next step is logging
    the actual per-tick `distSq` while seated/sleeping and raising this
    further to match — say so and I'll add a temporary debug print for it.

### 0.14.2
- **Scrubbed Ashen Lung from the debug surface too, per request** (0.14.1
  deliberately left this alone; now fully hidden there as well):
  - `/rnd debug` 's help text now builds its disease-index line dynamically
    from `RN.DISEASE_ORDER`/`RN.Disease.IsDiseaseEnabled` instead of a
    hardcoded string — a disabled disease's name never prints, and its
    index number is simply skipped (the list jumps 1, 2, 4, 5...) rather
    than relabeling every later index, since index positions are meant to
    stay stable/permanent (see Data.lua's own comment on `DISEASE_ORDER`).
  - `/rnd debug disease 3 <severity>` now returns the exact same generic
    "Invalid disease index" message a genuinely out-of-range index would
    — so probing index numbers by hand can't distinguish "doesn't exist"
    from "exists but disabled."
  - `/rnd debug ingredients` had a separate leak: Ashen Lung shares its
    exact ingredient set with Thief's Bane, so scanning Blessed Thistle/
    Chaurus Egg/Dragon's Blood was printing an "applied to Ashen Lung
    tier N" line right alongside the Thief's Bane one. The ingredient
    name index it scans against is now built only from enabled diseases.
  - All of this still routes through the same single
    `Disease.IsDiseaseEnabled` switch added in 0.14.1 — re-enabling Ashen
    Lung restores it everywhere (Settings, Healer's Guide, AND now the
    debug surface) with that one flag, no separate debug-side toggle to
    remember.

### 0.14.1
- **Clarified per request: Ashen Lung being "disabled" means invisible to
  the player, not just inert.** 0.14.0's greyed-out Settings slider and
  unchanged Healer's Guide entry still told the player it existed —
  fixed:
  - New `Disease.IsDiseaseEnabled(diseaseId)` in Disease.lua, a single
    centralized check (currently just `diseaseId == "ashenLung"` gated on
    `Disease.ASHEN_LUNG_ENABLED`) used everywhere a disease might be shown
    in the UI, so future per-disease disables only need one new line here
    rather than hunting down every display call site again.
  - Settings panel's chance-slider loop now skips disabled diseases
    entirely (no slider rendered at all, not greyed out) — and the
    disease-chances description text no longer mentions Ashen Lung by
    name, since that text alone would have told the player it exists even
    with no slider.
  - The Healer's Guide loop (built from `RN.DISEASE_ORDER`) now also skips
    disabled diseases — no header, flavor text, or cure-ingredient lines
    for Ashen Lung while it's off.
  - **Still NOT hidden, by design**: `/rnd debug disease 3 <severity>` and
    the `/rnd debug` help text still reference Ashen Lung by name. That's
    a developer-only debug command, not a normal player-facing surface —
    if you'd also like it scrubbed from there, say so and I'll do it, but
    I didn't want to take away your own ability to force-test a disabled
    disease without being asked.
  - Data.lua's definition, the overlay window (created at load for every
    disease but only ever shown if `Overlay.RefreshDisease` is called, which
    natural contraction can no longer trigger), and the asset file are all
    still fully intact, per "disable, don't remove."

### 0.14.0
- **Ashen Lung's natural contraction trigger is now disabled, per request**
  — disease definition, Healer's Guide entry, overlay (now `AshenLung.dds`,
  unchanged), and `/rnd debug disease 3 <severity>` index slot are all left
  fully intact; only `Disease.CheckVolcanicHeatExposure` is switched off,
  gated by a new `Disease.ASHEN_LUNG_ENABLED = false` constant in
  Disease.lua. While disabled, its exposure timer stays pinned at 0 and the
  disease can never roll naturally from standing in extreme heat — `/rnd
  debug disease 3 <severity>` can still force it directly for testing, and
  any case already active before this was disabled still progresses/cures
  normally (this only blocks NEW natural contraction). Flip the constant
  back to `true` to re-enable.
- Settings panel's Ashen Lung chance slider is now greyed out (`disabled`
  field — see the UNVERIFIED-AGAINST-LAM-SOURCE caveat in Settings.lua;
  worst case if it doesn't visually grey out, the slider is still
  functionally inert) with an explanatory tooltip, and its label/the
  disease-chances description text both updated to say so, rather than
  silently offering a control that does nothing.
- Also fixed two stale wording leftovers from 0.13.x while touching this
  file: Mage's Bane's Settings label and description said "frost" instead
  of the corrected "cold" (matching 0.13.2's `DAMAGE_TYPE_COLD` fix), and
  Fighter's Bane's label still mentioned "bleed" despite 0.13.2 dropping
  that trigger entirely.

### 0.13.2 — hotfix
- **Fixed a load-time crash**: `RealisticNeedsAndDiseases_Disease.lua:324:
  table index is nil`. 0.13.1's `DAMAGE_TYPE_TO_DISEASES` table used
  `DAMAGE_TYPE_FROST` as a literal table key — but that global doesn't
  exist in ESO's API (the real constant is `DAMAGE_TYPE_COLD`; "Frost
  Damage" is UI flavor text, the engine kept the older "Cold" name). A
  nonexistent global evaluates to `nil`, and Lua refuses `nil` as a table
  key in a literal constructor, which failed the whole file (and so the
  whole addon) at load.
- **Rebuilt the table defensively** via a new `AddDiseaseTrigger(diseaseId,
  globalNameAsString)` helper in Disease.lua: each damage-type global is
  looked up by NAME through `_G[globalName]` rather than written as a
  literal key, so a wrong or renamed constant is just a normal `nil` value
  that gets skipped (and reported once to chat, naming exactly which
  globals didn't resolve) instead of crashing the file. This closes off the
  whole class of bug, not just this one instance.
- **Dropped `DAMAGE_TYPE_BLEED` from Fighter's Bane's trigger entirely**,
  rather than swapping in another guess — "Bleed" appears to be a status
  *effect* applied by Physical damage in ESO's combat model, not a
  separate `DamageType` of its own, so there may be no such constant to
  reference at all. Fighter's Bane is wired to `DAMAGE_TYPE_PHYSICAL` only
  for now; if a real distinct Bleed damage-type constant is ever confirmed,
  add it through `AddDiseaseTrigger` the same defensive way, not as a
  literal key.
- Mage's Bane's widened trigger is otherwise unchanged in effect — Magic,
  Fire, Cold (was mis-typed Frost), and Shock — just spelled correctly now
  and resolved defensively.

### 0.13.1
- **Status emotes no longer interrupt a sit/sleep pose already in
  progress.** New `Rest.IsResting()` exposes Rest.lua's existing
  `_isSeated`/`_isSleeping` tracking (already covering `/rnd sit`, `/rnd
  sleep`, and the hooked native `/sit`-/`/sleep`-family commands, including
  `/sitchair` — so this also covers sitting in a real chair) to
  `Feedback.CanPlayEmotesNow()`. Hunger/thirst/fatigue/drunkenness/disease
  status emotes now check this before firing, both on the immediate
  on-band-entry fire (`CheckBandTransition`, which previously fired
  unconditionally — it's now gated through the same combat/mounted/major-UI/
  resting checks the periodic retrigger already used) and on every periodic
  retrigger while a category stays bad. `Feedback.CanPlayEmotesNow` is now
  exposed on the `Feedback` table itself so Disease.lua's own direct
  `OnDiseaseChanged` emote call can gate through it too, rather than firing
  unconditionally.
- **Disease redesign, per spec:**
  - **"Magic Blight" renamed to "Mage's Bane"** (`magicBlight` → `mageBane`
    diseaseId). Its overlay art asset is renamed alongside it —
    `Magicpox.dds` → `MagesBane.dds` — per request, with the `overlayTexture`
    path updated to match. Its trigger is widened from `DAMAGE_TYPE_MAGIC`
    alone to any of the four standard "spell damage" types — Magic, Fire,
    Frost, Shock — each now an independent entry in Disease.lua's new
    `DAMAGE_TYPE_TO_DISEASES` map. Cure (Restore Magicka: Corn Flower /
    Lady's Smock / Vile Coagulant) is unchanged.
  - **New "Fighter's Bane"** — triggered by martial damage taken (Bleed or
    Physical), cured with the SAME Restore Health ingredient set Bloodworms
    already uses (Mountain Flower / Water Hyacinth / Crimson Nirnroot), by
    request. Now has a generated PLACEHOLDER overlay texture
    (`FightersBane.dds`, simple colored vignette, not hand-drawn) — swap in
    real custom art whenever you have it, no code changes needed beyond the
    file itself.
  - **New "Thief's Bane"** — triggered by martial damage taken (Poison or
    Disease), cured with the SAME Restore Stamina ingredient set Ashen Lung
    already uses (Blessed Thistle / Chaurus Egg / Dragon's Blood — the last
    still unconfirmed, as on Ashen Lung's own entry). Also given a generated
    PLACEHOLDER overlay texture (`ThiefsBane.dds`), same caveat as Fighter's
    Bane's above. Note Disease damage now feeds BOTH Bloodworms and Thief's
    Bane — each rolls independently off its own `diseaseChances` entry on
    the same qualifying hit.
  - `Disease.lua`'s old single-disease-per-damage-type
    `DAMAGE_TYPE_TO_DISEASE` map is replaced with `DAMAGE_TYPE_TO_DISEASES`
    (a list per damage type), so any number of diseases can independently
    roll off the same hit. `DAMAGE_TYPE_FIRE`, `DAMAGE_TYPE_FROST`,
    `DAMAGE_TYPE_SHOCK`, `DAMAGE_TYPE_BLEED`, and `DAMAGE_TYPE_PHYSICAL` are
    newly referenced here — same real-but-individually-unconfirmed-in-a-
    live-client status the project's existing `DAMAGE_TYPE_DISEASE`/
    `DAMAGE_TYPE_MAGIC` constants already carried; worth a
    `/script d(damageType)` check the first time each should newly fire.
  - `RN.DISEASE_ORDER` updated to `{ frostbite, heatstroke, ashenLung,
    bloodworms, mageBane, fightersBane, thiefsBane }` — existing entries
    kept in their original index positions, new ones appended, per the
    project's own stated convention for this list. `/rnd debug disease
    <1-7>` index range and help text updated to match (the old help text's
    1-5 labels were already stale Bone Chill/Swamp Rot/Ashen Cough/Blood
    Fever/Wormwood Plague names from before an earlier rename — corrected
    to the current names while touching this anyway).
  - Settings panel's `ROLLABLE_DISEASES`/`LOW_CHANCE_DISEASES` lists and
    description text updated for the rename and two additions. The
    Healer's Guide submenu needed no changes — it was already built
    dynamically from `RN.Diseases`/`RN.DISEASE_ORDER`.
  - **Not migrated**: existing SavedVariables with the old `magicBlight`
    key under `diseaseChances` are left in place as an inert leftover (same
    as this project's earlier disease renames) — the new `mageBane`/
    `fightersBane`/`thiefsBane` keys are filled in from defaults on next
    load via the existing recursive-fill, without touching anything you'd
    already customized under the old key.
  - **Placeholder texture format note**: `FightersBane.dds`/`ThiefsBane.dds`
    are uncompressed 32bpp BGRA DDS files (no DX10 header), unlike the
    project's existing real-art textures which are all BC7/DX10-compressed
    1024×1024. Both are valid DDS and should load the same way in-game, but
    the format difference is worth knowing if you swap in real art later —
    matching the existing BC7/DX10 1024×1024 convention isn't required, just
    consistent with what's already there.

### 0.12.5
- **Disease notifications now include a cure hint.** New
  `Feedback.GetCureHintText(diseaseId, severity)` — looks up the cheapest
  ingredient(s) that would actually cure at the given severity (the tier
  exactly matching it; any rarer tier also works but there's no reason to
  suggest it when the matching one is enough) and the curative trait name,
  e.g. "A dose of Mudcrab Chitin (Protection) would ease this." Wired into:
  contraction ("You have contracted Frostbite. A dose of...");
  worsening ("Your Heatstroke has worsened to Severe. A dose of Vile
  Coagulant or Powdered Mother of Pearl (Protection) would ease this."); and
  `/checkneeds`'s disease lines. `/rnd debug checkneeds` untouched.
- **Added a 1-minute cooldown on tier-1 ("cheap") cures, per disease.**
  Eating a tier-1 ingredient is never blocked — it consumes normally either
  way — this only gates whether it ALSO triggers the curative effect.
  New `sv.tier1CureCooldowns[diseaseId]` (persisted, not just in-memory, so
  reloading doesn't reset it) and `Disease.TIER1_CURE_COOLDOWN_SECONDS = 60`.
  Implemented per-disease rather than as one global cooldown across all 5,
  so curing two different diseases back-to-back with two different tier-1
  ingredients still works fine — only re-curing the SAME disease again
  within 60 seconds is blocked. Tier 2/3 ingredients are unaffected (they
  already can't fire below their own severity requirement at all).
- **Added a "Healer's Guide" panel to Settings** — a lore-friendly,
  read-only reference under a new collapsible submenu, built dynamically
  from `RN.Diseases`/`RN.DISEASE_ORDER` (so it can't drift out of sync with
  the real cure data if Data.lua changes later). Covers the direct-cure and
  care-cure ("curing over time") mechanisms in plain in-universe language,
  then lists each disease's name, its curative trait, and which herb/reagent
  cures it at each severity tier. Flagged in a code comment:
  `type = "submenu"` is the commonly-documented LAM pattern for this kind of
  grouped panel, but unverified against this project's specific LAM version
  — if it doesn't render as expected, the fallback is unwrapping it into
  flat always-visible entries instead.

### 0.12.4
- **Ashen Lung's exposure threshold also raised to 10 minutes**, matching
  Frostbite/Heatstroke. `Disease.VOLCANIC_EXPOSURE_THRESHOLD_SECONDS` 300 →
  600. Also caught and fixed a few stale "90 second"/"5-minute" mentions in
  comments and the Settings panel description left over from the 0.12.3
  bump that didn't get updated everywhere at the time.

### 0.12.3
- **Frostbite/Heatstroke minimum exposure raised to 10 minutes.**
  `Disease.EXPOSURE_THRESHOLD_SECONDS` 90 → 600. This is the wait before
  there's even a CHANCE to roll the disease — the actual
  `sv.settings.diseaseChances.frostbite`/`.heatstroke` odds still apply on
  top of that once the 10 minutes elapse. Ashen Lung's separate 5-minute
  exposure window (`VOLCANIC_EXPOSURE_THRESHOLD_SECONDS`) is untouched —
  only Frostbite/Heatstroke were in scope.
- **Updated Ashen Lung's overlay art** to the newly-supplied `AshenLung.dds`
  (1024x1024, still clean power-of-two/multiple-of-4 — loads fine).
- **Mild-severity overlay alpha raised from 0.20 to 0.25** across all 5
  diseases (`Overlay.MAX_ALPHA_BY_SEVERITY[SEVERITY_MILD]`). 0.20 technically
  already satisfied "at least 20%" exactly at the boundary; 0.25 gives clear
  headroom above that floor instead of sitting exactly on it. Moderate
  (0.45) and Severe (0.75) unchanged.
- **Frostbite/Heatstroke tier 3 cure now accepts either Vile Coagulant OR
  Powdered Mother of Pearl interchangeably.** This required a real schema
  change, not just a data tweak: `remedyIngredients[tier]` is now always a
  LIST of one-or-more ingredient entries (most tiers still have just one),
  rather than a single `{name, itemId}` table. Updated every consumer of
  that shape: `Disease.GetIngredientTier`, `Disease.OnCareCureProgress`,
  the main file's care-cure status printout, and `DebugHelper.lua`'s
  ingredient-scanner (which now also tracks which entry within a tier's
  list to apply a scanned itemId to). All 4 known Protection-trait reagents
  (Beetle Scuttle, Mudcrab Chitin, Powdered Mother of Pearl, Vile Coagulant)
  are now genuinely in use across Frostbite/Heatstroke's tiers 1-3.

### 0.12.2
- **Bloodworms now has real Restore Health ingredients** — reassigned
  Frostbite's previous (pre-Protection-switch) set, which had been sitting
  unused: Mountain Flower (30163), Water Hyacinth (30166), Crimson Nirnroot
  (150672). Same itemIds, already in-game-confirmed, just pointed at a
  different disease.
- **Frostbite and Heatstroke now use the IDENTICAL Protection ingredient
  set**, by request: tier 1 Mudcrab Chitin (77591), tier 2 Beetle Scuttle
  (77583), tier 3 Vile Coagulant (150670). Powdered Mother of Pearl (139019)
  was the other valid tier-3 option per UESP — swap freely if preferred;
  Vile Coagulant was picked since Harrowstorms read as rarer than
  zone-restricted Giant Clam farming.
- **Corrected Ashen Lung's exclusion to be house-level, not zone-level** —
  this was a misunderstanding in 0.12.1, now fixed.
  `RN.ASHEN_LUNG_EXCLUDED_ZONES` replaced with `RN.ASHEN_LUNG_EXCLUDED_HOUSES`:
  118 individual house names (every "Name" column entry across all 4 housing
  tables — Staple, Classic, Notable, Notable Crown Exclusives), transcribed
  directly from the same UESP page. Mechanism unchanged
  (`Calculator.GetCurrentZoneName()` / `GetUnitZone("player")`, still
  UNVERIFIED IN A LIVE CLIENT) — the assumption is that each house is its
  own zone/map instance when you're inside it, so this should match the
  house's own name rather than the open-world zone around its exterior
  door. This removes the previous version's major side effect:
  Vvardenfell, The Deadlands, and Coldharbour are no longer excluded
  wholesale just because each has a house somewhere in it — only the
  specific house instances themselves are now off-limits.

### 0.12.1
- **Renamed Magicpox to Magic Blight** and gave it real Restore Magicka
  ingredients (was empty/unverified before). Sourced from RolePlayNeeds'
  own `RPN_REAGENT_TRAITS` lookup table (a working reference addon, not a
  guess) — Corn Flower (30161), Lady's Smock (30158), Vile Coagulant
  (150670), all independently confirmed against UESP's Alchemy Ingredients
  page as carrying Restore Magicka. Worth noting: tiers 1-2 are both
  Default-node reagents — per UESP, every non-rare Restore Magicka reagent
  (Bugloss/Columbine/Corn Flower/Lady's Smock) is a Default node, so there's
  no real common/uncommon rarity gradient available for this trait the way
  other diseases have.
- **Frostbite and Heatstroke switched from Restore Health to Protection**,
  with real ingredients filled in (Heatstroke's were previously empty;
  Frostbite's previous Restore-Health set — Mountain Flower/Water
  Hyacinth/Crimson Nirnroot — is now unused and could be reassigned to
  Bloodworms' still-empty Restore Health slot later). Per UESP, only 4
  reagents in the entire game carry Protection: Beetle Scuttle (77583),
  Mudcrab Chitin (77591), Powdered Mother of Pearl (139019), and Vile
  Coagulant (150670) — itemIds all carried over from this project's own
  earlier in-game-confirmed scans (previously used for the now-retired
  wormwoodPlague/bloodFever), not re-guessed. With only 4 real candidates
  for 2 diseases needing 3 tiers each, Frostbite and Heatstroke
  necessarily share tier 2 (Powdered Mother of Pearl) and tier 3 (Vile
  Coagulant) — only tier 1 is distinct between them (Mudcrab Chitin vs.
  Beetle Scuttle). Vile Coagulant is now a shared cure ingredient across
  3 diseases total (Frostbite, Heatstroke, Magic Blight), since it
  genuinely carries both Protection and Restore Magicka per UESP.
- **Ashen Lung's volcanic-heat trigger now excludes every zone with player
  housing.** New `RN.ASHEN_LUNG_EXCLUDED_ZONES` in Data.lua — 43 zone names
  transcribed directly from the player-supplied UESP "Online:Player
  Housing" page, checked via a new `Calculator.GetCurrentZoneName()`
  (`GetUnitZone("player")`, UNVERIFIED IN A LIVE CLIENT same as other
  combat/power-event calls in this project — confirm with
  `/script d(GetUnitZone("player"))`). Implemented exactly as specified,
  but flagging a real consequence: since almost every major zone has at
  least one house, this excludes Vvardenfell, The Deadlands, and
  Coldharbour — arguably the 3 best real candidates for an actual volcanic
  zone — purely because each happens to have a house. Also worth flagging:
  a couple of the housing page's zone labels (e.g. "Blackreach: Greymoor
  Caverns") may not exactly match the live `GetUnitZone()` string for that
  area — worth spot-checking a few entries in-game.

### 0.12.0
- **Chat messages for notifications are now opt-in.** New
  `sv.settings.showChatMessages` (default `false`), checkbox "Also log
  notifications to chat" in Settings. `Feedback.Notify()` only prints to
  chat when this is on; the top-right popup (`showNativeNotifications`,
  unchanged/independent) is unaffected either way. `opts.chatOnly` calls
  (e.g. `/rnd sleep`, `/rnd sit`) still always print, since they have no
  popup fallback — gating those too would've meant zero feedback at all with
  the new setting off. `/rnd debug` output and direct command responses
  (usage text, etc.) are untouched — this only affects ambient
  notifications, not things you explicitly typed a command to see.
- **Removed the category prefix from `/checkneeds` popups.** "Hunger: I'm
  hungry." is now just "I'm hungry."; disease popups dropped the "Disease:"
  prefix too, now just "Frostbite (Moderate)". `/rnd debug checkneeds` is
  unaffected and still labels everything for clarity in its numeric dump.
- **Replaced all 5 diseases per the new spec, with the player-supplied
  overlay art wired in** (this time at valid 1024x1024 dimensions — no
  loading-failure repeat of the previous 3 files' issue):
  - **Frostbite** (renamed from Bone Chill, same mechanism, same verified
    ingredients) — confirmed `Calculator.GetCurrentTemperature()`'s existing
    Frostfall-preferred/LibZoneTemp-fallback priority already satisfies
    "use Frostfall if present, else LibZoneTemp zone-only tracking" with no
    code change needed; just renamed the triggered diseaseId.
  - **Heatstroke** (new) — mirrors Frostbite's trigger inverted to the hot
    side of the same comfort band (`Disease.CheckSustainedHeat`). Curative
    trait defaulted to Restore Health (spec said "same as Bone Chill" without
    naming a trait) — flag if a different one was intended. No remedy
    ingredients yet (none specified/verified).
  - **Ashen Lung** (renamed from Ashen Cough, same verified ingredients) —
    now actually wired to a trigger for the first time (previously
    unimplemented). NO verified "volcanic/smoke zone" tag exists, so this is
    an explicitly-flagged HEURISTIC: same temperature signal as Heatstroke,
    but a much more extreme threshold (45°C, a rough guess pending real
    data), a 5-minute exposure requirement, and its own 1% roll —
    `Disease.CheckVolcanicHeatExposure`. Will also fire in any non-volcanic
    zone that happens to cross the same extreme temperature, since there's
    no real zone-identity check yet.
  - **Bloodworms** (new id, same mechanism as the old Wormwood Plague) —
    very slim per-hit chance on real `DAMAGE_TYPE_DISEASE` damage taken,
    cured by Restore Health (no ingredients verified yet).
  - **Magicpox** (new) — same per-hit mechanism, filtered on
    `DAMAGE_TYPE_MAGIC` instead (same unverified-constant caveat as
    `DAMAGE_TYPE_DISEASE` already carried), cured by Restore Magicka (no
    ingredients verified yet).
  - Swamp Rot and Blood Fever (and their swimming/low-health triggers) are
    fully retired — no longer in `RN.Diseases` at all.
  - `sv.settings.diseaseChances` keys renamed/replaced to match
    (`frostbite`, `heatstroke`, `ashenLung`, `bloodworms`, `magicpox`).
    Settings panel's disease-chance sliders and tooltip text updated to
    match; all 5 are now auto-wired (previously Ashen Cough had no slider
    since it had no working trigger).
  - **3 diseases still need an in-game ingredient scan**: Heatstroke,
    Bloodworms, and Magicpox have empty `remedyIngredients` — intentionally,
    per project convention, rather than guessed. They can be contracted and
    will progress in severity, but can't be ingredient-cured yet. Run
    `/rnd debug ingredients` once you've decided on candidates.

### 0.11.10
- **Diagnosed why the 3 custom overlay art files (boneChill/swampRot/
  wormwoodPlague) weren't rendering.** This was NOT a regression from the
  0.11.9 single-texture refactor — `Overlay.lua`'s texture-loading logic is
  unchanged and correct. Parsed the actual DDS headers of the 3 uploaded
  files directly (not assumed) and confirmed two real defects in the source
  files themselves:
  1. **Non-multiple-of-4 dimensions** — `boneChill.dds` (1254x1080) and
     `wormwoodPlague.dds` (1254x1254) are not divisible by 4 in width;
     `swampRot.dds` (667x680) likewise in width. DXT1/BC1 block compression
     requires both dimensions be multiples of 4 — this is very likely why
     the textures failed to load in-engine at all (not a severity-specific
     issue, which matches "doesn't render at any stage").
  2. **No alpha channel** — all 3 files' pixel format flags have only
     `DDPF_FOURCC` set, no `DDPF_ALPHAPIXELS`. Confirmed by decoding them:
     the intended-transparent center of each vignette-style image renders as
     solid opaque white, not transparent. If real per-pixel transparency is
     wanted (e.g. a frost-border vignette with a see-through center), the
     source art needs to be re-exported with an actual alpha channel (DXT5/
     BC3, or uncompressed ARGB) — that's a re-export decision for whoever
     made the art, not something to guess/invent on the code side.
  - As a diagnostic-only stopgap, repacked all 3 files as padded
    (next-multiple-of-4), uncompressed ARGB8888 DDS, preserving their exact
    current (fully opaque) pixel content unchanged — no alpha was invented.
    This isolates whether the dimension/compression issue was the sole
    blocker. These are noticeably larger files (uncompressed) purely for
    testing; production art should still be properly re-exported as DXT5
    with real alpha and clean dimensions for both correctness and file size.

### 0.11.9
- **Consolidated disease overlay textures from 3 files/disease down to 1.**
  `Data.lua`'s `overlayTexture` is now a single path per disease instead of
  an array indexed by severity (`overlayTexture = "...boneChill.dds"`, not
  `{ "..._1.dds", "..._2.dds", "..._3.dds" }`). `Overlay.lua`'s
  `RefreshDisease()` updated to match. Severity is now communicated purely
  through `Overlay.MAX_ALPHA_BY_SEVERITY` (0.20/0.45/0.75 — unchanged, this
  table already existed and already scaled opacity by tier) — the texture
  itself no longer changes between mild/moderate/severe, only how
  transparent the overlay window is. The 15 old per-tier placeholder DDS
  files are gone; replaced with 5 new ones (one per disease,
  `textures/overlays/<diseaseId>.dds`), still solid-color opaque 64x64
  placeholders meant to be swapped for real art later.
- **`/checkneeds` no longer prints anything to chat.** Added
  `Feedback.NotifyAlertOnly()` — fires the same top-right `ZO_Alert` popup as
  `Feedback.Notify()`, but skips the `CHAT_SYSTEM:AddMessage` line entirely.
  `/checkneeds` (and its keybind) now use this exclusively. Note this means
  if "Show native notifications" is turned off in Settings, `/checkneeds`
  produces no feedback at all — there's no chat fallback to drop to anymore,
  which is intentional (chat was the print being removed). `/rnd debug
  checkneeds` is unaffected and still prints full numeric detail to chat.
- **`/checkneeds` now omits drunkenness when the player is completely
  sober** (`sv.needs.drunkenness > 0` gates that one alert) — no more
  "Drunkenness: stone sober" popup every time when it's not relevant.

### 0.11.8
- **Split `/rnd checkneeds` into two distinct commands.**
  - `/rnd debug checkneeds` — exact numeric output to chat, unchanged from
    the previous `/rnd checkneeds` (hunger/thirst/fatigue/drunkenness values,
    temperature source, active disease severities and care-cure progress).
  - `/checkneeds` (new top-level command, no `/rnd` prefix) — no numbers at
    all; fires one `RN.Feedback.Notify()` per need category (band message
    only, e.g. "Hunger: I'm hungry.") and one per active disease (name +
    severity), which shows as a `ZO_Alert` top-right popup the same way
    band-transition alerts already do, respecting
    `sv.settings.showNativeNotifications`. This is now also what the keybind
    (`RND_CheckNeeds()` / bindings.xml) triggers, replacing its previous call
    to the numeric chat printout.
  - `/rnd checkneeds` (the bare old form) no longer exists — it's
    `/rnd debug checkneeds` now.

### 0.11.7
- **Added a hotkey for `/rnd checkneeds`.** New `bindings.xml` (required exact
  filename per ESOUI's keybinding system) defines a `RND_CHECK_NEEDS` action
  under the standard `SI_KEYBINDINGS_LAYER_GENERAL` layer, listed under
  Controls > Keybindings > "Realistic Needs and Diseases". Verified against
  RolePlayNeeds' own working `bindings.xml`/`RPN_CheckNeeds()` pattern rather
  than guessed from memory — same flat-global-function convention
  (`RND_CheckNeeds()` in `RealisticNeedsAndDiseases.lua`, registered via
  `ZO_CreateStringId("SI_BINDING_NAME_RND_CHECK_NEEDS", ...)`), no custom
  action layer needed since the binding reuses the always-active general layer.
- **Confirmed/documented the Frostfall dependency as fully optional.** No code
  change was needed here — `Calculator.lua`'s `GetCurrentTemperature()` and
  `GetIsSwimming()` already guard every Frostfall access behind
  `if Frostfall and Frostfall.XXX then`, and the manifest already lists
  `Frostfall>=4` under `## OptionalDependsOn`, not `## DependsOn`. Audited
  every other file for an unguarded `Frostfall` reference — found none. With
  Frostfall absent, temperature source falls through to LibZoneTemp, then to
  flat baseline-only decay; nothing errors.
- **Added a master on/off switch for the whole needs/disease system.** New
  `sv.settings.needsSystemEnabled` (default `true`), checkbox at the top of
  the Settings panel. Turning it off makes `OnTick` return immediately —
  no decay, regen, disease rolls/progression, or care-cure progress — hides
  the status bar regardless of the separate "show status bar" setting, and
  clears every visible disease overlay tint. Turning it back on restores the
  status bar (respecting that same separate setting) and repaints any
  diseases that were already active. `/rnd checkneeds` still works while
  disabled, but prefixes its output with a note that the numbers are frozen.
  Nothing is uninstalled, no SavedVariables are touched or reset — this is a
  pure pause/resume switch.

### 0.11.6
- **Added placeholder overlay textures for all 5 diseases**, to exercise the
  `def.overlayTexture[severity]` code path in `Overlay.lua` (previously every
  entry was `{ nil, nil, nil }`, so the overlay always fell back to the
  solid `overlayColor` tint). Each disease now has 3 generated 64x64
  solid-color DDS files under `textures/overlays/<diseaseId>_<1|2|3>.dds`
  (mild/moderate/severe), tinted from each disease's existing `overlayColor`
  at increasing brightness per tier purely so the three are visually
  distinguishable while testing. These are throwaway placeholders meant to
  be replaced with real artwork — delete a disease's `overlayTexture` entries
  (or set them back to `nil`) at any time to fall back to the plain color
  tint with no other code changes needed.

### 0.11.5
- **Actually fixed SavedVariables not persisting across logout.** Root cause
  confirmed by reading the real `ZO_SavedVars` engine source
  (`libraries/utility/zo_savedvars.lua`): `ZO_SavedVars:NewAccountWide(...)`
  does **not** return the raw on-disk data table — it returns a separate
  wrapper/interface object (with its own real fields, e.g. `default`, and
  exposed methods like `ResetToDefaults`/`GetInterfaceForCharacter` assigned
  directly onto it) that proxies reads and writes to the real data via a
  metatable. The code was assigning that wrapper straight back onto the same
  global name declared in the manifest:
  `RealisticNeedsAndDiseasesSavedVars = ZO_SavedVars:NewAccountWide("RealisticNeedsAndDiseasesSavedVars", ...)`.
  That silently clobbered the global the engine actually serializes at
  logout/reloadui with the wrapper object instead of the real data — reads
  and writes worked fine all session (the wrapper's metatable still proxies
  correctly), but the file written to disk was the wrapper itself, which is
  why a real `SavedVariables/RealisticNeedsAndDiseasesSavedVars.lua` came back
  showing a flat `default` table plus
  `["ResetToDefaults"] = nil, -- invalid value type [function] used` and
  `["GetInterfaceForCharacter"] = nil, -- invalid value type [function] used`
  instead of the expected per-megaserver/`$AccountWide` structure. Fixed by
  storing the returned interface under its own name, `RN.SavedVars`, exactly
  like Frostfall (`FV.SV = ZO_SavedVars:NewAccountWide("FrostfallSV", ...)`)
  and Spoilage (`PST.savedVars = ZO_SavedVars:NewAccountWide("SpoilageSavedVars", ...)`)
  already do — the manifest's `## SavedVariables:` name and the string passed
  as `NewAccountWide`'s first argument are unchanged; only the variable
  receiving the *return value* changed. Every other file in the addon
  (`RealisticNeedsAndDiseases_Disease.lua`, `_Feedback.lua`, `_StatusBar.lua`)
  was updated to read `RN.SavedVars` instead of the old global. The 0.11.3
  `DeepFillDefaults` shallow-merge fix was real and stays in place, but it
  was never the actual blocker here.

### 0.11.4
- Added `rum` to `RN.ALCOHOL_KEYWORDS` in `Data.lua`. Items like "Alabaster
  Honey Rum" were correctly detected as `ITEMTYPE_DRINK` and restoring thirst,
  but never triggering drunkenness because `rum` was simply absent from the
  keyword list. The same gap existed in Spoilage's `DrinkAlcohol` list (the
  original source) — both fixed in their respective releases (Spoilage v1.6.3).

### 0.11.3
- **Fixed needs resetting to full on every login.** Root cause: ZO_SavedVars
  performs only a shallow merge at the top level. If `sv.needs` is missing or
  nil in the on-disk data (first install, serialization quirk, or save written
  before `needs` was structured as a nested sub-table), ZO_SavedVars replaces
  it wholesale with the defaults table, giving `hunger=100, thirst=100,
  fatigue=100`. Added `DeepFillDefaults(sv, SV_DEFAULTS)` immediately after
  `NewAccountWide` — a recursive fill that inserts any missing key from
  defaults without ever overwriting an existing saved value. Also correctly
  back-fills new fields added across rapid iteration (e.g. `drunkenness`) into
  saves that predate them, which ZO_SavedVars' shallow merge also misses.
- Version bumped (0.11.2 skipped — that was the Disease.lua fix shipped as
  part of the same session as 0.11.1).

### 0.11.2
- **Fixed Mountain Flower (and all remedy ingredients) never curing diseases.**
  `Disease.OnRemedyInventoryChange` used a snapshot approach with a local
  `_lastSlotState` table that was never seeded at load — so the first
  ingredient consumed in any session always had `prevState == nil` and was
  silently dropped. Replaced with Frostfall's proven `stackCountChange < 0` +
  `prevLink` pattern for reagents: simpler, doesn't require a seed pass, and
  is the right tool here because reagent consumption has no LibFoodDrinkBuff
  timing race to guard against.

### 0.11.1
- **Fixed drunkenness never triggering from alcoholic drinks.** Two bugs:
  1. `_lastSlotState` (the slot snapshot cache in the food/drink handler) was
     never seeded at load. The first drink consumed from any given slot always
     had `prevState == nil`, so the "stack shrank" comparison was never entered
     and the item was silently dropped. Fixed by adding `SeedLastSlotState()`
     called one-shot from `EVENT_PLAYER_ACTIVATED`, matching RolePlayNeeds'
     `ForceInventoryScan()` pattern exactly.
  2. Raw alcohol ingredients (`ITEMTYPE_INGREDIENT +
     SPECIALIZED_ITEMTYPE_INGREDIENT_ALCOHOL`) were gated behind
     `RecentlyGrantedFoodDrinkBuff()`, but consuming a raw ingredient doesn't
     grant a food/drink buff — only prepared `ITEMTYPE_FOOD`/`ITEMTYPE_DRINK`
     items do. Removed the raw ingredient branch from `HandleConsumedItem`
     entirely: raw provisioning ingredients are used at a crafting station,
     not consumed directly by the player.

### 0.11.0
- **Food/drink/alcohol detection rebuilt around the real fix** — found by
  inspecting how this same problem was actually solved in RolePlayNeeds: a
  TWO-SIGNAL approach, not a single one. `EVENT_INVENTORY_SINGLE_SLOT_UPDATE`
  (already in place) tells you WHICH item's stack shrank, but isn't
  trustworthy alone — it fires for selling, trading, and other non-
  consumption removals too. The actual fix is a CONFIRMATION gate:
  `EVENT_EFFECT_CHANGED` + `LibFoodDrinkBuff:IsAbilityAFoodOrDrinkBuff(abilityId)`
  reliably confirms a real food/drink buff was just granted (ESO always
  grants one on actual consumption), and the inventory signal is only
  trusted within a 500ms window of that confirmation. `LibFoodDrinkBuff` is
  now a **required** dependency, not optional — there's no reliable fallback
  for this specific signal. This is a structural fix, not a guess: every
  constant and method name here (`EFFECT_RESULT_GAINED`,
  `REGISTER_FILTER_UNIT_TAG`, the 500ms window,
  `IsAbilityAFoodOrDrinkBuff`) was confirmed by reading real working code,
  not assumed.
- **Alcohol detection rebuilt using Spoilage's own real data** (Krek's own
  prior addon, not a third party): the `RN.ALCOHOL_KEYWORDS` list now
  matches Spoilage's actual curated `DrinkAlcohol` keyword set, including
  real ESO-lore drink names (rotmeth, sujamma, flin, mazte, greef, jagga)
  a generic list wouldn't have caught. Also added detection of raw alcohol
  *ingredients* (not just prepared drinks) via the real native
  `SPECIALIZED_ITEMTYPE_INGREDIENT_ALCOHOL` flag, also sourced from
  Spoilage's `GetItemCategory()` — a genuine native flag exists for raw
  ingredients even though prepared drinks still need keyword matching.
- **SavedVariables persistence investigated** — compared this addon's setup
  line-by-line against Frostfall's and Spoilage's confirmed-working pattern
  (manifest tag, `ZO_SavedVars:NewAccountWide` call shape, load order,
  variable shadowing) and found no structural difference. Added a
  diagnostic line on load printing the actual loaded values, so the next
  test session gives real evidence on whether this is a genuine bug here or
  something else (worth checking: `ZO_SavedVars:NewAccountWide` without an
  explicit server/profile parameter is scoped per-megaserver — if you tested
  across NA/EU/PTS between sessions, that would look exactly like data not
  persisting, because it's a different save-file bucket each time, by design).

### 0.10.0 — bug-fix and feature pass from real in-game testing
- **Item IDs updated with genuinely confirmed values** from a real
  `/rnd debug ingredients` scan. Several previously "plausible" guesses were
  actually wrong (e.g. Mountain Flower 30161→30163, Crimson Nirnroot
  77585→150672, Chaurus Egg 139019→150669) — proof the verification step was
  necessary, not a formality. 13 of 14 ingredients now confirmed; Dragon's
  Blood (Ashen Cough tier 3) still needs a scan once you have one.
- **Fixed food/drink/alcohol/coffee detection never firing.** The root cause:
  trusting the `stackCountChange` event parameter, which real testing showed
  doesn't behave as assumed. Replaced with stack-size snapshot comparison
  (tracking item identity per slot, so item-shifting-between-slots doesn't
  misfire, and explicitly handling "last unit of a stack consumed" where the
  slot goes fully empty). Same fix applied to ingredient-cure detection,
  which had the identical bug. Also added `LibFoodDrinkBuff` as an optional
  dependency (the library you noted RolePlayNeeds needed) plus a new
  `/rnd debug libcheck` command that dumps its real API surface, since I
  don't have that library's source to confirm its exact methods.
- **Status window now shows ONLY flavor text**, no numbers — `/rnd
  checkneeds` still shows both, as requested.
- **New `/rnd sleep` and `/rnd sit` commands.** The fade-to-black not
  triggering from typing `/sleep` directly was likely because built-in
  emote commands may not route through the same addon-visible
  `SLASH_COMMANDS` table the way addon-registered commands do — genuinely
  uncertain, but rather than keep guessing, these new commands guarantee the
  rest-state tracking starts, using the already-confirmed-working
  `PlayCategoryEmote` mechanism directly. Both sleep and sit poses are now
  configurable in Settings, like every other category.
- **Decay-rate sliders converted from hours to minutes**, range 5-120
  (5 minutes fastest, 2 hours slowest), each with a hover tooltip explaining
  its effect.
- **New stamina-exertion mechanic feeding fatigue decay**, independent of
  movement — sprinting, attacking, blocking, dodging, bashing all cost
  stamina and now accelerate fatigue drain proportionally, up to 2.5x at
  high exertion. New `/rnd debug power on` dumps raw `EVENT_POWER_UPDATE`
  args for verification, same pattern as the combat/loot debug tools.
- **Emote system restructured for #7**: emotes now fire IMMEDIATELY the
  moment a category first crosses into band 3 or 4 (not just on the next
  periodic check), then repeat at a frequency that scales continuously with
  severity — slowest at the band-3 boundary (25s), fastest at the absolute
  extreme (5s). Each of hunger/thirst/fatigue/drunkenness now has its own
  independent timer, fixing a bug where only the first-bad category in a
  fixed checking order would ever get an emote while others were starved
  out. Disease keeps a simpler fixed 30s re-trigger (no 0-100 value to scale
  against) but still fires immediately on contraction/escalation.

### 0.9.0
- **Default hunger emote changed** from Headache to Angry.
- **4-band status message system** for hunger/thirst/fatigue/drunkenness,
  replacing the old single-threshold binary design — fixed quartiles of the
  0-100 range, each with its own message, each transition (worsening or
  improving) firing its own notification. The old adjustable warning-
  threshold sliders are gone, superseded by this.
- **Emotes now gated by band** (only play at bands 3-4, the worst half)
  instead of a single threshold comparison.
- **Status window now shows the band message text** under each number,
  colored to match.
- **"Show status bar" renamed to "Show needs status window"** for clarity —
  same toggle, same setting.

### 0.8.0
- **New drunkenness mechanic.** Alcoholic drinks (name-keyword detected)
  build up drunkenness; decays on its own over time and much faster while
  resting (any of the three fatigue-recovery mechanics).
- **New coffee mechanic** (explicitly the user's own idea) — coffee restores
  fatigue in addition to the normal thirst restore.
- **Emote and notification systems rebuilt to mirror Frostfall's real
  architecture**: `ZO_Alert` replaces `CENTER_SCREEN_ANNOUNCE` entirely (a
  confirmed-working call already used in this project, not a best-effort
  guess); emotes now resolved via real `PLAYER_EMOTE_MANAGER` enumeration
  and played via the confirmed `GetEmoteIndex → PlayEmoteByIndex` two-step,
  replacing both the earlier guessed-index design and the SLASH_COMMANDS-
  hijacking design from last version. A dedicated 20-second emote timer
  (gated on combat/mounted/major-UI-open) replaces the probabilistic
  chance/cooldown roll.
- **`/rnd debug cureall` split into `/rnd debug curedisease` and
  `/rnd debug resetneeds`.**
- **`/realneeds` alias removed.** Use `/rnd checkneeds`.
- **Status window gains a 4th row** for drunkenness, with an inverted
  color ramp (high = bad, unlike the other three rows).

### 0.7.0
- **Emote system completely redesigned around real, confirmed slash
  commands** sourced from UESP's Online:Emotes page, invoked via
  `SLASH_COMMANDS["/cmd"]("")` instead of guessed numeric
  `PlayEmoteByIndex` indices. Selected: `/headache` (hunger), `/breathless`
  (thirst), `/yawn` (fatigue, has confirmed audio), `/sick` (disease).
- **Settings dropdowns for emote choice**, 3-4 alternatives per category,
  filtered at panel-build time to only commands actually registered in the
  live client (`SLASH_COMMANDS[cmd] ~= nil`).
- **Emotes now used less often** (20% chance / 120s cooldown, down from
  35%/90s) — chat and native toast remain the primary feedback channels.
- **New fatigue recovery system** (`RealisticNeedsAndDiseases_Rest.lua`):
  standing still, sitting, and sleeping/meditating all now restore fatigue,
  closing the gap noted in 0.6.0's fatigue explanation. Sleep/meditate
  triggers an optional fade-to-black screen effect.
- **New `/rnd debug testemote <category>`** replaces the old numeric
  `/rnd debug emote <index>`.

### 0.6.0
- **All commands unified under `/rnd`.** `/rnd checkneeds` replaces
  `/realneeds` (kept as a deprecated alias). All debug tools moved from the
  standalone `/RNDdebugHelper` into `/rnd debug <subcommand>`.
- **New `/rnd debug disease <1-5> <0-3>`** — directly sets any disease's
  severity for testing, bypassing contraction rolls entirely.
- **New `/rnd debug cureall`** — replaces the old Settings-panel "Reset
  needs"/"Clear diseases" buttons with one command that does both.
- **New `/rnd debug emote <index>`** — for discovering real emote indices.
- **New centralized Feedback module** (`RealisticNeedsAndDiseases_Feedback.lua`).
  Every notification now goes through one path: chat message always, plus an
  opt-in native top-screen toast (the screenshot/achievement/loot
  notification system) via `CENTER_SCREEN_ANNOUNCE` — best-effort, unverified
  call signature, wrapped in `pcall` so a wrong signature fails silently to
  chat-only. Disease contraction/escalation now actually notifies the player
  (previously silent except for cure messages).
- **New periodic emote feedback** while critically low on a need or while
  diseased — only the fatigue emote index (91, Stretch) is confirmed; the
  rest are unset pending `/rnd debug emote` discovery.

### 0.5.0
- **Filled in 13 of 14 ingredient itemIds** from a user-compiled list,
  cross-referenced against the original UESP table for plausibility (clean
  sequential/batch ID clustering matching known content-release waves) but
  **not independently verified** — I couldn't find a source that actually
  displays the raw numbers to confirm against. **"Scrib Jelly" (Blood Fever
  tier 1) was absent from the source list entirely** and is left unset.
  `/RNDdebugHelper ingredients` is the real verification path for all 14.
- **Status display redesigned from icons to a Frostfall-style colored-text
  window.** Replicates Frostfall's own `TemperatureHUD.lua` structure: a
  draggable top-level window with a backdrop, label+large-colored-value rows
  for hunger/thirst/fatigue (red→yellow→green by value), and a dynamically-
  sized disease section below. Removes the icon-path verification problem
  entirely — there's no texture path left to get wrong.
- Removed the now-obsolete `/RNDdebugHelper icons` subcommand along with the
  icon system it was built to verify.

### 0.4.1
- **Corrected `LibAddonMenu-2.0` dependency floor**: was mistakenly set to
  `>=45`, but LibAddonMenu's own manifest documentation shows `43` as the
  latest available version, not `45`. Fixed to `>=43`.

### 0.4.0
- **New `/RNDdebugHelper` diagnostic command**, built to confirm/correct every
  piece of data this addon flagged as unverified: ingredient `itemId`s (scans
  your backpack/bank for known ingredient names and auto-applies discovered
  IDs for the session, plus prints a paste-ready line for `Data.lua`), a
  preview window for the StatusBar's candidate icon paths, and raw argument
  dumps for both `EVENT_COMBAT_EVENT` (confirms `DAMAGE_TYPE_DISEASE` and
  parameter order) and `EVENT_LOOT_RECEIVED` (confirms parameter order and
  `itemId` position). Fully opt-in — nothing here runs without being asked.

### 0.3.0
- **Wormwood Plague trigger simplified**: replaced the name-keyword heuristic
  with a real `damageType == DAMAGE_TYPE_DISEASE` check on combat events —
  the game's own damage classification, not a name guess. Very slim default
  chance (1%) per qualifying hit.
- **Settings panel massively expanded**: decay hours, restore amounts,
  warning thresholds, and per-disease contraction chances are all now
  player-adjustable, not hardcoded constants.
- **Remedy ingredients redesigned around real UESP data.** Each disease now
  has a distinct, real alchemy trait and 3 tiers of real, named ingredients
  sourced directly from UESP's Alchemy Ingredients page (only the numeric
  item IDs remain unverified/unfilled).
- **New care-cure system**: stronger afflictions can be cured gradually with
  only the cheap tier-1 ingredient, provided the player stays well fed,
  watered, and rested throughout.

### 0.2.0 — renamed and redesigned
- Renamed from "Sustenance" to **Realistic Needs and Diseases** (homage to
  the Skyrim mod; not a port, not affiliated).
- Confirmed natural-baseline-plus-acceleration decay semantics.
- Disease curing redesigned from shared potion-tier tables to per-disease
  raw-ingredient tiers (at the time, item IDs only, no real ingredient names yet).
- Added the status bar UI and harvest-based thirst restoration.

### 0.1.0 — initial build (as "Sustenance")
- Hunger/thirst/fatigue meters with temperature-coupled decay rates.
- 5 independent diseases, 3 severity tiers each, independent overlays.
- Frostfall/LibZoneTemp optional integration with flat-rate fallback.
- LibAddonMenu settings panel (minimal).
