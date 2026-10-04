-- Frostfall: Temperature System for ESO
-- Main addon file — core logic, state management, event handling
--
-- v2.5.0: Overlay redesign — single window per side, pure linear alpha ramp.
--         Freezing emote removed; cold emote thresholds remapped.
-- v2.6.0: Emote defaults changed; fast independent emote loop (15 s).
--         HUD rebuilt as TopLevelWindow. ZO_Alert band notifications.
-- v2.7.0: Emote catalogue corrected; HUD 3-row equal-size; real °C/°F display.
-- v2.8.0: Emote system uses stable emoteId + GetEmoteIndex() at play time.
-- v2.9.0: Emote thresholds corrected; exact display-name matching for defaults.
-- v2.9.1: Very Cold lower bound removed — mirrors Very Hot.
-- v3.0.0: Abolished 0–100 comfort scale. All internal temps now in °C.
-- v3.0.1: Overlay ramps use FV.TEMP thresholds.
-- v3.1.0: HEAT_DANGER 38°C; drift rate quartered; water/station mechanics added.
-- v3.1.1: Water/station mechanics gated to cold/warm sides of comfortable band.
-- v3.1.2: Water cooling and station warming reduced to 5°C.
-- v3.1.3: Hot/Very Hot notification messages updated.
-- v3.1.4: Fix water loot handler — was reading 6th EVENT_LOOT_RECEIVED argument
--         instead of 5th (itemType). Now matches RolePlayNeeds exactly.
-- v3.1.5: Updated temperature thresholds to be more logical/reasonable and
--         corrected a bug in the code.
-- v3.2.0: ConfigMenu thresholds synced with Frostfall.lua; /fv slash command
--         renamed to /ff; version numbers updated throughout; README updated.
-- v3.3.0: Added the "Increase Spell Resist" reagent buff — consuming a
--         reagent with that alchemy trait nudges the player's effective
--         temperature toward neutral (capped at 10°C) for 30 real-world
--         minutes (scaled by the Medicinal Use passive), with re-consumption
--         resetting the timer and per-minute fade warnings in the last
--         5 minutes. See FV.SPELL_RESIST_REAGENT_IDS below. Player temp is
--         tracked as a "true" physical value (FV.State.playerTemp,
--         unaffected by the buff and still driven by ambient/weather/swim
--         drift); FV:GetEffectiveTemp() recalculates the steadying offset
--         live from the player's CURRENT real differential every time it
--         runs (not a fixed snapshot from consumption time), and is the
--         value shown on HUD/overlay/emotes/band alerts.
-- v3.4.0: Added the remaining two confirmed "Increase Spell Resist" reagent
--         IDs to FV.SPELL_RESIST_REAGENT_IDS — Clam Gall (139020) and White
--         Cap (30154) — alongside Bugloss and Mudcrab Chitin from 3.3.0, so
--         all four canonical UESP reagents now trigger the buff.
-- v3.4.1: BUGFIX — GetMedicinalUseRank() called GetCraftingSkillLineIndices()
--         and used a SKILL_TYPE_CRAFTING constant, neither of which exists
--         in the ESO UI API. The resulting Lua error silently aborted the
--         entire OnReagentInventoryChange handler before it ever reached
--         ApplySpellResistReagent/ZO_Alert — i.e. it broke reagent
--         consumption detection outright, not just the duration bonus.
--         Replaced with GetNumSkillLines(SKILL_TYPE_TRADESKILL) +
--         GetNumSkillAbilities() + GetSkillAbilityInfo(), all confirmed
--         against esoui/esoui's ESOUIDocumentation.txt.
-- v3.4.2: Reagent consumption detection is now also gated off while the
--         personal bank or guild bank is open (EVENT_OPEN_BANK/CLOSE_BANK,
--         EVENT_OPEN_GUILD_BANK/CLOSE_GUILD_BANK) — withdrawing or
--         depositing a reagent fires the same EVENT_INVENTORY_SINGLE_SLOT
--         _UPDATE as eating one, and was previously mistaken for
--         consumption, same as the merchant/crafting-station case.
-- v3.4.22: BUGFIX — FV.SV.spellResistRemainingSeconds (the offline-pause
--          persistence added in 3.4.21) was being written only once, inside
--          the EVENT_PLAYER_DEACTIVATED handler, and was confirmed (via
--          debug logging + direct inspection of FrostfallSV.lua) to
--          sometimes lose the race against the client's own SavedVariables
--          flush and never reach disk — silently dropping the buff on
--          relog despite the save appearing to succeed in memory. Fixed by
--          also writing spellResistRemainingSeconds on every 1-second
--          OnSpellResistTick while the buff is active (same
--          always-current pattern already used for FV.SV.playerTemp),
--          so a value is already safely in FV.SV well before any flush,
--          rather than depending on a single deactivate-time write. The
--          EVENT_PLAYER_DEACTIVATED write is kept as a final tightening-up
--          at logout, not the sole write path.
-- v3.4.22: Also clears the orphaned FV.SV.spellResistEndTimestamp key left
--          behind by the pre-3.4.21 (v3.4.19-3.4.20) persistence scheme —
--          nothing has read this field since 3.4.21 replaced it with
--          spellResistRemainingSeconds, so it was just dead weight in
--          SavedVariables for anyone who used the addon before upgrading.
-- v3.4.23: New "Temperature Adaptation Rate" slider (ConfigMenu, 0.25-5.0
--          in 0.25 steps) exposes the previously-hardcoded BASE_DRIFT_RATE
--          (°C/min at insulation 50) as FV.SV.driftRate. Default matches
--          the old hardcoded value (1.75) exactly, so existing behavior is
--          unchanged until a player moves the slider. CalculatePlayerTemperature
--          now reads FV.SV.driftRate (falling back to the BASE_DRIFT_RATE
--          constant if FV.SV is unavailable); insulation-based scaling via
--          ComputeDriftRate is unaffected and still applies on top of it.
-- v3.4.25: Added a passive indoor-shelter steadying effect via
--          LibInteriorDetection (a NEW ## OptionalDependsOn - not
--          required, degrades to a no-op if not installed). Whenever
--          LibInteriorDetection reports the player is currently indoors,
--          effective temperature is nudged toward neutral (22°C), capped
--          at INDOOR_PROTECTION_MAX_SHIFT (initially 5°C). STACKS
--          ADDITIVELY with the spell-resist reagent buff rather than
--          replacing it - both computed independently from the same true
--          playerTemp differential and summed in FV:GetEffectiveTemp(),
--          now a plain function plus a shared SteadyingOffset() helper.
--          /ff status and the HUD's "FEELS LIKE" indicator (renamed
--          UpdateSpellResistIndicator -> UpdateSteadyingIndicator in
--          ui/TemperatureHUD.lua) report either or both effects when
--          active.
-- v3.4.26: Raised INDOOR_PROTECTION_MAX_SHIFT from 5°C to 15°C (1.5x the
--          spell-resist reagent's 10°C cap, up from 0.5x), per explicit
--          request - being genuinely sheltered indoors judged stronger
--          protection than the temporary alchemical buff, not weaker.
-- v3.4.27: Fixed the HUD showing empty (no data) on login when the master
--          "Enable Frostfall" toggle is off but "Show Thermal Status HUD"
--          is on. HUD:Initialize() set visibility from FV.SV.showHUD
--          alone, ignoring FV.SV.enabled; now checks both.
-- v3.4.28: Fixed the spell-resist reagent buff continuing to decay
--          against real wall-clock time while the master toggle is off.
--          FV:SetEnabled(false)/true now pause/resume it the same way a
--          real logout already did, reusing SaveSpellResistRemaining/
--          RestoreSpellResistBuff; FV:Initialize() only auto-resumes if
--          the toggle is already on at load.
-- v3.4.29: Compliance: added a version floor to
--          ## OptionalDependsOn: LibInteriorDetection (now >=28), per an
--          ESOUI moderator's written rule that version checks are
--          mandatory for OptionalDependsOn too, not just hard DependsOn.
-- v3.4.30: REVERTED v3.4.29's version floor - a follow-up moderator
--          comment clarified OptionalDependsOn does not support >= at
--          all, only DependsOn does. Likely a real functional bug, not
--          just non-compliant syntax: LibInteriorDetection>=28 was
--          probably read as a literal dependency name, meaning the
--          optional-dependency detection could have been silently
--          failing to recognize LibInteriorDetection as installed at
--          all. Back to the bare name, no version.
-- v3.4.31: BUGFIX - reported as effective temperature reading ABOVE
--          ambient (and rising) while cold, indoors, with the spell-resist
--          buff active. Root cause: each of the two steadying effects
--          independently capped itself at min(itsMax, distanceToNeutral),
--          correctly preventing either ONE from overshooting past neutral
--          alone - but GetEffectiveTemp() simply summed both, so their
--          COMBINED push could still exceed the real distance to neutral
--          whenever both were active (their caps sum to 25°C, easily more
--          than most real gaps), blowing straight through neutral and out
--          the opposite side. Fixed by scaling both offsets down
--          proportionally whenever their combined demand would exceed the
--          actual distance to neutral - single-effect cases are
--          unaffected (scale=1, no-op), only the combined-overshoot case
--          changes. Confirmed via direct code inspection that this
--          integration never touches LibZoneTemp's own ambient
--          temperature calculation (INTERIOR_MODIFIER is unchanged, still
--          -3°C, still a cooling adjustment) - the bug was entirely in
--          this file's own effective-temperature stacking.
-- v3.4.32: REDESIGNED indoor shelter from a display-only mask (matching
--          the spell-resist buff's shape) to a REAL, additional drift
--          toward neutral applied directly to playerTemp in
--          CalculatePlayerTemperature. Prompted by a follow-up report: a
--          real, modest warmth source (a cooking fire's one-time +5°C)
--          combined with the old display mask to show a misleadingly
--          "perfect" 72°F reading while genuinely still cold underneath,
--          which then appeared to jump right back down the moment the
--          player stepped outside and the mask vanished - even though
--          the true temperature barely changed either time, since the
--          mask never touched it. Shelter is now governed by
--          INDOOR_SHELTER_DRIFT_RATE (3.0°C/min before insulation
--          scaling, replacing INDOOR_PROTECTION_MAX_SHIFT's old 15°C
--          cap) and runs alongside the existing ambient drift rather
--          than overriding the display - the two can reinforce or
--          partially compete, settling at whatever equilibrium point
--          they reach together. GetEffectiveTemp() is back to handling
--          only the spell-resist mask, the single-effect shape it had
--          before v3.4.25 - the v3.4.31 combined-overshoot fix is now
--          moot for this pairing specifically, since shelter no longer
--          contributes a display offset to stack with anything. The
--          spell-resist reagent buff itself is UNCHANGED - this was a
--          deliberate, explicit request to redesign shelter specifically,
--          not the reagent mechanic.
-- v3.4.33: Fixed the RETICLE:TryHandlingInteraction pre-hook reading the
--          wrong argument. ZO_PreHook passes the method's self (RETICLE)
--          first - confirmed in the ESOUI client source (zo_hook.lua,
--          reticle.lua, 12.0.8) - so the hook's `interactionPossible`
--          was actually RETICLE and always truthy. Now reads
--          (self, interactionPossible), and clears the remembered prompt
--          text when nothing is interactable, so a later interact-key
--          press with nothing targeted can't reuse an old "Sit" prompt.
-- v3.4.34: Renamed the LibAddonMenu panel from "Frostfall" to
--          "FrostfallPanel". LAM names the panel control after it, and ESO
--          makes every named control a global, so the old name overwrote
--          the global Frostfall table with the panel control once
--          ConfigMenu initialized. Frostfall kept working (it uses the
--          local FV), but other addons reading the global - RND's
--          Frostfall:GetEffectiveTemp() / Frostfall.State.isSwimming -
--          silently fell back to LibZoneTemp's raw ambient temperature.

Frostfall = Frostfall or {}
local FV = Frostfall

-- ============================================================
-- CONSTANTS
-- ============================================================
FV.NAME            = "Frostfall"
FV.VERSION         = "3.4.35"
FV.DISPLAY_NAME    = "Frostfall Temperature System"
FV.SAVED_VARS_VER  = 8   -- unchanged: spellResistRemainingSeconds (v3.4.21, replacing v3.4.19's spellResistEndTimestamp) is additive and needs no data migration

-- ============================================================
-- TEMPERATURE UNITS
--
-- All internal temperature values (playerTemp, ambientTemp, thresholds)
-- are stored and calculated in DEGREES CELSIUS.  LibZoneTemp returns °C
-- directly, so no intermediate comfort scale is needed.
--
-- Display converts to °F when FV.SV.useFahrenheit is true.
-- The insulation value (0–100) remains a dimensionless factor.
-- ============================================================

local function CelsiusToFahrenheit(c)
    return c * 9 / 5 + 32
end

local function FahrenheitToCelsius(f)
    return (f - 32) * 5 / 9
end

-- Format a Celsius value for display in the player's chosen unit.
function FV.FormatTemp(celsius)
    if FV.SV and FV.SV.useFahrenheit then
        return string.format("%d°F", math.floor(CelsiusToFahrenheit(celsius) + 0.5))
    else
        return string.format("%d°C", math.floor(celsius + 0.5))
    end
end

-- Format the ambient (zone) temperature for display.
function FV.FormatAmbientTemp()
    local celsius = FV.State.ambientTempCelsius
    if FV.SV and FV.SV.useFahrenheit then
        return string.format("%d°F", math.floor(CelsiusToFahrenheit(celsius) + 0.5))
    else
        return string.format("%d°C", math.floor(celsius + 0.5))
    end
end

-- ============================================================
-- TEMPERATURE THRESHOLDS  (degrees Celsius)
--
-- These are real °C values.  Emote and overlay logic compares
-- playerTemp (stored in °C) directly against these constants.
--
-- Fahrenheit equivalents for reference:
--   FREEZE_DANGER  = -10°C  (14°F)
--   VERY_COLD      =   0°C  (32°F)
--   COLD           =  10°C  (50°F)
--   COMFORTABLE_LO =  20°C  (68°F)
--   COMFORTABLE_HI =  24°C  (75°F)
--   WARM           =  26°C  (79°F)
--   HOT            =  35°C  (95°F)  ← 80°F triggers Hot emote
--   HEAT_DANGER    =  41°C  (105°F) ← 105°F triggers Very Hot emote
-- ============================================================
FV.TEMP = {
    FREEZE_DANGER  = -10,   -- 14°F
    VERY_COLD      =   0,   -- 32°F
    COLD           =  10,   -- 50°F
    COMFORTABLE_LO =  20,   -- 68°F
    COMFORTABLE_HI =  24,   -- 75°F
    WARM           =  26,   -- 79°F
    HOT            =  35,   -- 95°F
    HEAT_DANGER    =  41,   -- 105°F
}

-- ============================================================
-- TEMPERATURE BANDS  (for ZO_Alert notifications)
-- ============================================================
local BAND_FREEZING  = 1
local BAND_VERY_COLD = 2
local BAND_COLD      = 3
local BAND_COOL      = 4
local BAND_COMFORT   = 5
local BAND_WARM      = 6
local BAND_HOT       = 7
local BAND_SCORCHING = 8

local function GetTempBand(temp)
    local T = FV.TEMP
    if temp <= T.FREEZE_DANGER       then return BAND_FREEZING
    elseif temp <= T.VERY_COLD       then return BAND_VERY_COLD
    elseif temp <= T.COLD            then return BAND_COLD
    elseif temp <= T.COMFORTABLE_LO  then return BAND_COOL
    elseif temp <= T.COMFORTABLE_HI  then return BAND_COMFORT
    elseif temp <= T.WARM            then return BAND_WARM
    elseif temp <= T.HOT             then return BAND_HOT
    else                                  return BAND_SCORCHING
    end
end

local BAND_ENTER_MESSAGES = {
    [BAND_FREEZING]  = "|c4488FFYou are freezing! Seek shelter or warmth immediately.|r",
    [BAND_VERY_COLD] = "|c66AAFFYou are very cold.|r",
    [BAND_COLD]      = "|c88CCFFYou feel cold.|r",
    [BAND_WARM]      = "|cDDDD44You are feeling warm.|r",
    [BAND_HOT]       = "|cFF9933You are uncomfortably hot. Seek shade or cool water.|r",
    [BAND_SCORCHING] = "|cFF2211Dangerously hot! You risk overheating — find relief immediately.|r",
}

-- ============================================================
-- EMOTE SYSTEM — emoteId vs emoteIndex
--
-- ESO has two separate emote identifier systems:
--
--   emoteId    — a STABLE named ID managed by PLAYER_EMOTE_MANAGER.
--                Survives patches; safe to save to disk.
--                Retrieved via PLAYER_EMOTE_MANAGER:GetEmoteListForType().
--
--   emoteIndex — a VOLATILE positional integer used only by
--                PlayEmoteByIndex().  Changes whenever ZOS adds or reorders
--                emotes.  NEVER save this value.
--
-- The correct pattern (from CShortcutPieMenu):
--   1. Store emoteId in saved vars.
--   2. At play time: local idx = GetEmoteIndex(emoteId)
--                    if idx then PlayEmoteByIndex(idx) end
--
-- Default emoteIds are resolved at Initialize() time by searching
-- PLAYER_EMOTE_MANAGER for emotes whose slash name matches a target string.
-- This is patch-safe — it finds the right emote regardless of what index
-- ZOS assigns it this patch.
--
-- The ConfigMenu dropdown is built dynamically from PLAYER_EMOTE_MANAGER
-- at init time so the player sees every emote available on their client,
-- including personality-overridden variants they own.
-- ============================================================

-- Display-name targets used to resolve default emoteIds at startup.
-- "Shivering Cold" and "Shiver Cold" are two distinct ESO emotes —
-- we match by exact display name so they are never confused.
-- Adjust if ZOS renames an emote in a future patch.
FV.EMOTE_DISPLAY_DEFAULTS = {
    very_cold = "Shivering Cold",   -- intense cold shiver (different from Shiver Cold)
    cold      = "Shiver Cold",      -- mild cold shiver (different from Shivering Cold)
    hot       = "Wipe Brow",        -- heat relief gesture
    scorching = "Breathless",       -- heat distress / panting
}
-- Slash fallbacks used if the exact display name is not found on this client.
FV.EMOTE_SLASH_FALLBACKS = {
    very_cold = "shivering",
    cold      = "shiver",
    hot       = "wipe",
    scorching = "breathless",
}

-- Populated at Initialize() time via ResolveEmoteDefaults().
-- Keys are emoteIds (stable), value 0 = disabled.
FV.EMOTE_DEFAULTS = {
    very_cold = 0,
    cold      = 0,
    hot       = 0,
    scorching = 0,
}

-- Populated at Initialize() time for the LAM dropdown.
-- FV.EMOTE_CHOICES_LABELS and FV.EMOTE_CHOICES_VALUES are filled by
-- BuildEmoteChoices() from PLAYER_EMOTE_MANAGER at runtime.
FV.EMOTE_CHOICES_LABELS = { "None (disabled)" }
FV.EMOTE_CHOICES_VALUES = { 0 }

-- ============================================================
-- DRIFT CONSTANTS
-- BASE_DRIFT_RATE: °C per MINUTE at neutral insulation (50).
-- 1.75°C/min = 7.0 / 4 — quadrupled drift time per design spec.
-- ============================================================
local BASE_DRIFT_RATE = 1.75  -- °C per minute at insulation 50 -- fallback/default only; the
                               -- live value now lives in FV.SV.driftRate (user-adjustable via
                               -- the "Temperature Adaptation Rate" slider in ConfigMenu).
local DRIFT_RATE_MIN  = 0.1   -- multiplier floor

local SPELL_RESIST_MAX_SHIFT = 10  -- °C cap on the spell-resist reagent's temperature-steadying effect

-- REDESIGNED (was a display-only masking cap through v3.4.31, same shape
-- as the spell-resist buff above). Reported issue with that design: a
-- real, modest warmth source (e.g. a cooking fire's one-time +5°C) could
-- combine with the display mask to show a misleadingly "perfect" reading
-- (e.g. 72°F while genuinely still cold underneath), which then appeared
-- to jump right back down the moment the player stepped outside and the
-- mask disappeared - even though the true temperature barely changed
-- either time, since the mask never touched it. Indoor shelter is now a
-- REAL, additional drift toward NEUTRAL (not ambient) applied directly to
-- playerTemp in CalculatePlayerTemperature, alongside the existing
-- ambient drift - so the displayed value always reflects the true state,
-- and there's no discontinuity when entering/leaving, only a faster (or
-- slower) rate of change while sheltered. The spell-resist reagent buff
-- above is UNCHANGED - it remains a display-only mask, per explicit
-- request to redesign shelter specifically, not the reagent mechanic.
local INDOOR_SHELTER_DRIFT_RATE = 3.0  -- °C per minute pulling toward neutral while indoors, before
                                        -- insulation scaling (same ComputeDriftRate() curve as the
                                        -- ambient drift uses). Set noticeably higher than
                                        -- BASE_DRIFT_RATE's 1.75°C/min default, reflecting that shelter
                                        -- is meant to feel like a meaningfully strong benefit - purely a
                                        -- balance choice; adjust directly if it feels wrong in play.

local EMOTE_LOOP_INTERVAL = 15000   -- ms

-- ============================================================
-- DEFAULTS
-- ============================================================
FV.Defaults = {
    version                = FV.SAVED_VARS_VER,
    enabled                = true,
    showHUD                = true,
    hudPosition            = { x = 100, y = 200 },
    hudScale               = 1.0,
    hudAlpha               = 0.9,
    enableEmotes           = true,
    enableOverlay          = true,
    -- Caps the hot/cold overlay's alpha ramp (see OverlayEffects.lua's
    -- ColdAlpha/HotAlpha) — was a hardcoded MAX_ALPHA=0.75 local constant
    -- with zero Settings exposure; this default matches that original
    -- value exactly, so nobody's overlay changes strength on upgrade.
    overlayMaxOpacity      = 0.75,
    showTopNotifications  = true,   -- native top-of-screen ZO_Alert banner
    alsoLogChat            = false, -- also print the same notification to chat
    debugMode              = false,
    updateIntervalMinutes  = 2,
    useFahrenheit          = false,
    driftRate              = BASE_DRIFT_RATE,  -- °C/min at insulation 50; user-adjustable via
                                                -- the "Temperature Adaptation Rate" slider
    -- emoteId* keys store PLAYER_EMOTE_MANAGER emoteIds (stable across patches).
    -- Values are resolved at Initialize() time; 0 = disabled.
    emoteIdVeryCold        = 0,
    emoteIdCold            = 0,
    emoteIdHot             = 0,
    emoteIdScorching       = 0,
}

-- ============================================================
-- STATE
-- ============================================================
FV.State = {
    ambientTemp        = 20,   -- °C
    ambientTempCelsius = 20,   -- °C (same value, kept for display)
    playerTemp         = 20,   -- °C — the "true" physical temperature, driven
                                -- only by ambient/weather/swim drift. Never
                                -- touched by the spell-resist buff.

    -- Spell-resist reagent buff (see FV.SPELL_RESIST_REAGENT_IDS).
    -- spellResistOffset is a transient display-only delta added on top of
    -- playerTemp by FV:GetEffectiveTemp() while the buff is active.
    -- spellResistEndTime is keyed to GetGameTimeMilliseconds() (this
    -- session's uptime clock) and is NOT itself saved -- the buff PAUSES
    -- while offline and resumes with whatever time was left, rather than
    -- counting down in real time regardless of login state. The remaining
    -- duration at logout is captured into FV.SV.spellResistRemainingSeconds
    -- (via EVENT_PLAYER_DEACTIVATED) and consumed back into a fresh
    -- spellResistEndTime at the next Initialize(). See
    -- RestoreSpellResistBuff / SaveSpellResistRemaining below.
    spellResistOffset       = 0,
    spellResistEndTime      = nil,  -- game-time seconds when the buff expires (this session only)
    spellResistWarnedMinute = nil,  -- last minute-mark we already warned for

    -- Indoor shelter (LibInteriorDetection integration): as of the
    -- redesign, this is a REAL drift effect applied directly to
    -- playerTemp in CalculatePlayerTemperature, not a display offset -
    -- there is no separate numeric magnitude to track here anymore, only
    -- whether it's currently active, kept for the HUD/status display.
    isIndoorProtected       = false,

    insulation         = 0,
    insulationSource   = "none",

    isSwimming  = false,

    currentZoneName  = "Unknown",
    lastTempBand     = BAND_COMFORT,
    overlayActive    = false,
    _initialized     = false,
}

-- ============================================================
-- UTILITY
-- ============================================================

local function FV_Log(msg)
    if FV.SV and FV.SV.debugMode then
        d("[Frostfall] " .. tostring(msg))
    end
end

-- Central dispatch for all player-facing temperature notifications (band
-- transitions, spell-resist buff apply/fade/warn, water/station mechanics).
-- Controlled by two independent settings:
--   FV.SV.showTopNotifications — the native top-of-screen ZO_Alert banner
--   FV.SV.alsoLogChat          — the same message, also printed to chat
-- Both can be on, both off, or either one alone.
function FV:Notify(msg)
    if FV.SV and FV.SV.showTopNotifications ~= false then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, msg)
    end
    if FV.SV and FV.SV.alsoLogChat then
        CHAT_SYSTEM:AddMessage(msg)
    end
end

local function GetUpdateIntervalMs()
    local mins = (FV.SV and FV.SV.updateIntervalMinutes) or FV.Defaults.updateIntervalMinutes
    return math.max(1, math.min(10, mins)) * 60 * 1000
end

-- ============================================================
-- ZONE TEMPERATURE — via LibZoneTemp
-- ============================================================

function FV:GetZoneAmbientTemp()
    if not LibZoneTemp then
        FV_Log("LibZoneTemp not available — using default temperature")
        FV.State.currentZoneName    = "Unknown"
        FV.State.ambientTempCelsius = 20
        return 20, "Unknown"
    end

    local celsius, zoneName = LibZoneTemp.GetCurrentTemperature()
    if not celsius then
        FV_Log("LibZoneTemp returned nil — using default temperature")
        FV.State.currentZoneName    = "Unknown"
        FV.State.ambientTempCelsius = 20
        return 20, "Unknown"
    end

    zoneName = zoneName or "Unknown"
    FV.State.currentZoneName    = zoneName
    FV.State.ambientTempCelsius = celsius

    FV_Log(string.format("LibZoneTemp: %s → %.1f°C", zoneName, celsius))
    return celsius, zoneName
end

-- ============================================================
-- SWIMMING
-- ============================================================

function FV:UpdateSwimmingState()
    FV.State.isSwimming = IsUnitSwimming("player")
    return FV.State.isSwimming
end

-- ============================================================
-- INSULATION — via LibArmorInsulation
-- ============================================================

function FV:GetPlayerInsulation()
    if not LibArmorInsulation then
        FV_Log("LibArmorInsulation not available — defaulting to 0")
        FV.State.insulation       = 0
        FV.State.insulationSource = "none"
        return 0
    end

    local breakdown  = LibArmorInsulation.GetInsulationBreakdown()
    local insulation = breakdown and breakdown.total  or 0
    local source     = breakdown and breakdown.source or "naked"

    FV.State.insulation       = insulation
    FV.State.insulationSource = source
    FV_Log(string.format("LibArmorInsulation: source=%s total=%d", source, insulation))
    return insulation
end

-- ============================================================
-- DRIFT RATE
-- ============================================================

local function ComputeDriftRate(insulationFactor, driftingCold)
    local neutral = 0.5
    local multiplier
    if driftingCold then
        multiplier = 1.0 + (neutral - insulationFactor) * 2
    else
        multiplier = 1.0 + (insulationFactor - neutral) * 2
    end
    return math.max(DRIFT_RATE_MIN, multiplier)
end

-- ============================================================
-- CORE TEMPERATURE CALCULATION
-- ============================================================

function FV:CalculatePlayerTemperature(tickSeconds)
    tickSeconds = tickSeconds or 0

    -- ambientTemp and playerTemp are both in °C.
    local ambientTemp, zoneName = self:GetZoneAmbientTemp()
    FV.State.ambientTemp = ambientTemp

    local insulationValue  = self:GetPlayerInsulation()
    -- insulationFactor: 0.0 (naked) → 1.0 (fully insulated).
    -- Symmetric around 0.5 (insulation 50):
    --   insulation < 50 → cools faster, heats slower
    --   insulation > 50 → heats faster, cools slower
    local insulationFactor = insulationValue / 100

    local tickMinutes  = tickSeconds / 60
    local currentTemp  = FV.State.playerTemp
    local delta        = ambientTemp - currentTemp
    local driftingCold = delta < 0

    local rateMultiplier = ComputeDriftRate(insulationFactor, driftingCold)
    local baseDriftRate  = (FV.SV and FV.SV.driftRate) or BASE_DRIFT_RATE
    local maxDrift        = baseDriftRate * tickMinutes * rateMultiplier
    local driftAmount    = math.min(math.abs(delta), maxDrift) * (driftingCold and -1 or 1)
    local playerTemp     = currentTemp + driftAmount

    -- Indoor shelter: a REAL, additional pull toward NEUTRAL (not ambient)
    -- while indoors - see the redesign note on INDOOR_SHELTER_DRIFT_RATE
    -- above for why this replaced the old display-only masking approach.
    -- Uses the same ComputeDriftRate() insulation curve as the ambient
    -- drift above, applied to the neutral-ward direction instead of the
    -- ambient-ward one, so a well-insulated player still warms up faster
    -- than a poorly-insulated one even while being helped by shelter.
    -- This runs independently of, and in addition to, the ambient drift
    -- above - the two can reinforce (ambient happens to be near neutral
    -- too) or partially compete (ambient is pulling toward a temperature
    -- far from neutral), in which case the player settles at whatever
    -- equilibrium point the two opposing pulls balance out to, rather
    -- than fully reaching either target - a natural consequence of this
    -- being a real physical-style model now, not a display override.
    local isIndoorProtected = (LibInteriorDetection and LibInteriorDetection.IsPlayerIndoors and LibInteriorDetection.IsPlayerIndoors()) and true or false
    FV.State.isIndoorProtected = isIndoorProtected

    if isIndoorProtected then
        local neutral = (FV.TEMP.COMFORTABLE_LO + FV.TEMP.COMFORTABLE_HI) / 2
        local neutralDelta = neutral - playerTemp
        local shelterDriftingCold = neutralDelta < 0  -- true if cooling toward neutral, false if warming toward it
        local shelterRateMultiplier = ComputeDriftRate(insulationFactor, shelterDriftingCold)
        local maxShelterDrift = INDOOR_SHELTER_DRIFT_RATE * tickMinutes * shelterRateMultiplier
        local shelterDriftAmount = math.min(math.abs(neutralDelta), maxShelterDrift) * (shelterDriftingCold and -1 or 1)
        playerTemp = playerTemp + shelterDriftAmount
    end

    -- NOTE: precipitation drag was removed — ESO's addon API does not expose
    -- any live weather state (no EVENT_WEATHER_CHANGED event, no WEATHER_*
    -- constants), so this could never be detected.

    -- Swimming drag in °C/min. Cold water (<15°C) is much more dangerous.
    if FV.State.isSwimming then
        local swimmingDrag = 0.125 * tickMinutes
        if ambientTemp < 15 then swimmingDrag = swimmingDrag * 2.5
        elseif ambientTemp < 25 then swimmingDrag = swimmingDrag * 1.5 end
        playerTemp = playerTemp - swimmingDrag * (1 - insulationFactor * 0.3)
    end

    -- Clamp to realistic survivable range
    playerTemp = math.max(-20, math.min(70, playerTemp))
    FV.State.playerTemp = playerTemp

    FV_Log(string.format(
        "Zone: %s | Ambient: %.1f°C | Insulation: %d [%s] | " ..
        "Swimming: %s | Drift: %+.2f°C | PlayerTemp: %.1f°C",
        zoneName, ambientTemp,
        insulationValue, FV.State.insulationSource,
        tostring(FV.State.isSwimming),
        driftAmount, playerTemp
    ))

    return playerTemp
end

-- ============================================================
-- EFFECTIVE TEMPERATURE — true playerTemp + spell-resist offset
--
-- FV.State.playerTemp is the "true" physical temperature. As of the
-- indoor-shelter redesign (see INDOOR_SHELTER_DRIFT_RATE above), shelter
-- is now baked directly into playerTemp's own drift in
-- CalculatePlayerTemperature - it is NOT applied here anymore. Only the
-- spell-resist reagent buff remains a display-only mask at this layer.
--
-- The spell-resist offset is capped at min(SPELL_RESIST_MAX_SHIFT,
-- distanceToNeutral) - a single effect capped this way can never
-- overshoot past neutral on its own, since its own cap is bounded by the
-- actual remaining distance. (The combined-overshoot bug fixed in
-- v3.4.31 only existed because TWO such independently-capped offsets
-- were being summed together; with shelter no longer contributing an
-- offset here at all, that failure mode no longer applies - this
-- function is back to the single-effect shape it had before v3.4.25.)
--
-- FV:GetEffectiveTemp() is what the player actually perceives/sees — HUD,
-- overlay, emotes, and band-transition alerts all read this value instead
-- of FV.State.playerTemp directly. When the reagent buff isn't active,
-- the offset is 0 and the effective temp simply reflects the true temp
-- directly — i.e. "calculations proceed as normal."
-- ============================================================
function FV:GetEffectiveTemp()
    local spellResistOffset = 0
    if FV.State.spellResistEndTime then
        local neutral = (FV.TEMP.COMFORTABLE_LO + FV.TEMP.COMFORTABLE_HI) / 2  -- 22°C
        local diff = FV.State.playerTemp - neutral
        local shiftMag = math.min(SPELL_RESIST_MAX_SHIFT, math.abs(diff))
        if diff > 0 then
            spellResistOffset = -shiftMag   -- hot  → cool off
        elseif diff < 0 then
            spellResistOffset = shiftMag    -- cold → warm up
        end
    end
    FV.State.spellResistOffset = spellResistOffset   -- kept in sync for /ff status display

    local t = FV.State.playerTemp + spellResistOffset
    return math.max(-20, math.min(70, t))
end

-- ============================================================
-- THRESHOLD NOTIFICATIONS
-- ============================================================

local function CheckBandTransition(newTemp)
    local newBand = GetTempBand(newTemp)
    local oldBand = FV.State.lastTempBand

    if newBand ~= oldBand then
        local msg = BAND_ENTER_MESSAGES[newBand]
        if msg then
            local enteringDanger  = (newBand < oldBand and newBand <= BAND_COLD)
                                 or (newBand > oldBand and newBand >= BAND_WARM)
            local enteringComfort = (newBand == BAND_COMFORT)
            if enteringDanger or enteringComfort then
                FV:Notify(msg)
            end
        end
        FV.State.lastTempBand = newBand
    end
end

-- ============================================================
-- EMOTE SYSTEM
-- ============================================================

local function IsAnyMajorUIOpen()
    return not SCENE_MANAGER:IsShowing("hud")
end

-- Searches PLAYER_EMOTE_MANAGER for an emote whose slash name contains
-- the given string (case-insensitive).  Returns the emoteId, or 0 if not found.
-- Shared category list used by both emote search helpers.
local EMOTE_SEARCH_CATEGORIES = {
    EMOTE_CATEGORY_PHYSICAL,
    EMOTE_CATEGORY_SOCIAL,
    EMOTE_CATEGORY_EMOTION,
    EMOTE_CATEGORY_CHEERS_AND_JEERS,
    EMOTE_CATEGORY_ENTERTAINMENT,
    EMOTE_CATEGORY_CEREMONIAL,
    EMOTE_CATEGORY_FOOD_AND_DRINK,
    EMOTE_CATEGORY_GIVE_DIRECTIONS,
    EMOTE_CATEGORY_POSES_AND_FIDGETS,
    EMOTE_CATEGORY_PROP,
    EMOTE_CATEGORY_COLLECTED,
}

-- Searches by slash name substring (case-insensitive).
-- Returns the first matching emoteId, or 0.
local function FindEmoteIdBySlash(slashSubstring)
    local needle = slashSubstring:lower()
    for _, cat in ipairs(EMOTE_SEARCH_CATEGORIES) do
        local emoteIds = PLAYER_EMOTE_MANAGER:GetEmoteListForType(cat) or {}
        for _, emoteId in ipairs(emoteIds) do
            local info = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(emoteId)
            if info and info.slashName then
                if info.slashName:lower():find(needle, 1, true) then
                    return emoteId
                end
            end
        end
    end
    return 0
end

-- Searches by EXACT display name (case-insensitive).
-- Use this when two emotes share a common slash-name substring
-- (e.g. "Shiver Cold" vs "Shivering Cold") and you need the specific one.
-- Returns the first exact match, or falls back to FindEmoteIdBySlash(fallbackSlash).
local function FindEmoteIdByDisplayName(exactName, fallbackSlash)
    local needle = exactName:lower()
    for _, cat in ipairs(EMOTE_SEARCH_CATEGORIES) do
        local emoteIds = PLAYER_EMOTE_MANAGER:GetEmoteListForType(cat) or {}
        for _, emoteId in ipairs(emoteIds) do
            local info = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(emoteId)
            if info and info.displayName then
                if info.displayName:lower() == needle then
                    return emoteId
                end
            end
        end
    end
    -- Exact name not found — fall back to slash search so we get something
    return fallbackSlash and FindEmoteIdBySlash(fallbackSlash) or 0
end

-- Called once at Initialize().  Resolves default emoteIds by slash name
-- and writes them into FV.EMOTE_DEFAULTS.  Also sets saved var defaults
-- for any slot that is still 0 (first run or reset).
function FV:ResolveEmoteDefaults()
    local d = FV.EMOTE_DISPLAY_DEFAULTS
    local f = FV.EMOTE_SLASH_FALLBACKS
    -- Use exact display name matching to distinguish "Shiver Cold" from "Shivering Cold"
    FV.EMOTE_DEFAULTS.very_cold = FindEmoteIdByDisplayName(d.very_cold, f.very_cold)
    FV.EMOTE_DEFAULTS.cold      = FindEmoteIdByDisplayName(d.cold,      f.cold)
    FV.EMOTE_DEFAULTS.hot       = FindEmoteIdByDisplayName(d.hot,       f.hot)
    FV.EMOTE_DEFAULTS.scorching = FindEmoteIdByDisplayName(d.scorching, f.scorching)

    -- Apply resolved defaults to saved vars if still unset (0 = unresolved)
    if FV.SV.emoteIdVeryCold == 0 then
        FV.SV.emoteIdVeryCold = FV.EMOTE_DEFAULTS.very_cold
    end
    if FV.SV.emoteIdCold == 0 then
        FV.SV.emoteIdCold = FV.EMOTE_DEFAULTS.cold
    end
    if FV.SV.emoteIdHot == 0 then
        FV.SV.emoteIdHot = FV.EMOTE_DEFAULTS.hot
    end
    if FV.SV.emoteIdScorching == 0 then
        FV.SV.emoteIdScorching = FV.EMOTE_DEFAULTS.scorching
    end

    FV_Log(string.format("Emote defaults resolved — veryCold=%d cold=%d hot=%d scorching=%d",
        FV.EMOTE_DEFAULTS.very_cold, FV.EMOTE_DEFAULTS.cold,
        FV.EMOTE_DEFAULTS.hot, FV.EMOTE_DEFAULTS.scorching))
end

-- Builds FV.EMOTE_CHOICES_LABELS and FV.EMOTE_CHOICES_VALUES from
-- PLAYER_EMOTE_MANAGER so the dropdown lists every emote the player owns,
-- including personality-overridden variants, in a natural sorted order.
-- Called once at Initialize() after ResolveEmoteDefaults().
function FV:BuildEmoteChoices()
    local labels = {}
    local values = {}

    -- Categories to include, in display order
    local categories = {
        EMOTE_CATEGORY_PHYSICAL,
        EMOTE_CATEGORY_EMOTION,
        EMOTE_CATEGORY_SOCIAL,
        EMOTE_CATEGORY_CHEERS_AND_JEERS,
        EMOTE_CATEGORY_ENTERTAINMENT,
        EMOTE_CATEGORY_CEREMONIAL,
        EMOTE_CATEGORY_FOOD_AND_DRINK,
        EMOTE_CATEGORY_GIVE_DIRECTIONS,
        EMOTE_CATEGORY_POSES_AND_FIDGETS,
        EMOTE_CATEGORY_PROP,
        EMOTE_CATEGORY_COLLECTED,
    }

    local seen = {}
    for _, cat in ipairs(categories) do
        local emoteIds = PLAYER_EMOTE_MANAGER:GetEmoteListForType(cat) or {}
        for _, emoteId in ipairs(emoteIds) do
            if not seen[emoteId] then
                seen[emoteId] = true
                local info = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(emoteId)
                if info and info.displayName and info.displayName ~= "" then
                    local slash = info.slashName and ("/" .. info.slashName) or ""
                    table.insert(labels, string.format("%s  %s", info.displayName, slash))
                    table.insert(values, emoteId)
                end
            end
        end
    end

    -- Always add None at the end
    table.insert(labels, "None (disabled)")
    table.insert(values, 0)

    FV.EMOTE_CHOICES_LABELS = labels
    FV.EMOTE_CHOICES_VALUES = values
    FV_Log("BuildEmoteChoices: " .. (#labels - 1) .. " emotes available")
end

-- Plays the emote for a given saved emoteId using the correct two-step
-- pattern: GetEmoteIndex(emoteId) → PlayEmoteByIndex(index).
local function PlaySavedEmote(emoteId, label)
    if not emoteId or emoteId == 0 then return end
    local emoteIndex = GetEmoteIndex(emoteId)
    if emoteIndex then
        PlayEmoteByIndex(emoteIndex)
        FV_Log("TickEmote: " .. label .. " emoteId=" .. emoteId .. " index=" .. emoteIndex)
    else
        FV_Log("TickEmote: GetEmoteIndex returned nil for emoteId=" .. emoteId)
    end
end

function FV:TickEmote()
    if not FV.SV.enabled       then return end
    if not FV.SV.enableEmotes  then return end
    if IsUnitInCombat("player") then return end
    if IsMounted()              then return end
    if IsAnyMajorUIOpen()       then return end
    -- Don't let a temperature emote cancel a sit or sleep pose already in
    -- progress — whether that pose came from a native /sit-/sleep-family
    -- command or from interacting with a real chair/bench. See the
    -- "Sit/Sleep detection" section above.
    if FV:IsResting()           then return end

    local temp = FV:GetEffectiveTemp()

    -- All comparisons are in °C (playerTemp is stored in °C).
    -- Very Cold: < 0°C   (< 32°F)  — "Shivering Cold"
    -- Cold:      0–10°C  (32–50°F) — "Shiver Cold"
    -- Hot:       35–41°C (95–105°F)— "Wipe Brow"
    -- Very Hot:  ≥ 41°C  (≥ 105°F) — "Breathless"
    if temp < FV.TEMP.VERY_COLD then
        PlaySavedEmote(FV.SV.emoteIdVeryCold, "veryCold")
    elseif temp >= FV.TEMP.VERY_COLD and temp <= FV.TEMP.COLD then
        PlaySavedEmote(FV.SV.emoteIdCold, "cold")
    elseif temp >= FV.TEMP.HEAT_DANGER then
        PlaySavedEmote(FV.SV.emoteIdScorching, "scorching")
    elseif temp >= FV.TEMP.HOT and temp < FV.TEMP.HEAT_DANGER then
        PlaySavedEmote(FV.SV.emoteIdHot, "hot")
    end
end

-- ============================================================
-- MAIN UPDATE LOOP
-- ============================================================

function FV:OnUpdate(tickSeconds)
    if not FV.SV.enabled then return end

    self:UpdateSwimmingState()

    self:CalculatePlayerTemperature(tickSeconds or 0)
    local effectiveTemp = self:GetEffectiveTemp()

    CheckBandTransition(effectiveTemp)

    if FV.SV.showHUD and Frostfall_HUD then
        Frostfall_HUD:Update(effectiveTemp, FV.State)
    end

    if FV.SV.enableOverlay and Frostfall_Overlay then
        Frostfall_Overlay:Update(effectiveTemp, FV.State)
    end
end

-- Forward declaration: assigned further down (see "EVENT REGISTRATION,
-- GATED ON FV.SV.enabled" section), after the local state/handlers it
-- references are themselves declared. SetEnabled below is defined earlier
-- in the file but still correctly sees the later assignment once this
-- function is actually called, since Lua resolves the upvalue by this
-- declaration, not by where the assignment happens to sit in the file.
local CheckIfEventsNeeded
local _eventsRegistered = false

-- ============================================================
-- MASTER ENABLE / DISABLE
--
-- FV.SV.enabled is checked by OnUpdate/TickEmote/OnReagentInventoryChange
-- etc. to stop any FURTHER temperature checking, but merely skipping those
-- checks does nothing about a HUD window or overlay that's already on
-- screen from before the toggle flipped -- they'd just sit there frozen at
-- their last displayed values instead of actually going away. FV:SetEnabled
-- is the single place that both flips FV.SV.enabled AND immediately
-- reconciles every visible effect with the new state, in both directions:
-- turning off proactively hides the HUD and both overlay windows outright
-- (regardless of their own showHUD/enableOverlay settings), and turning
-- back on immediately forces a fresh update so everything reappears without
-- waiting for the next tick.
-- ============================================================
function FV:SetEnabled(val)
    FV.SV.enabled = val
    CheckIfEventsNeeded()

    if val then
        -- Resume any spell-resist buff that was paused while the master
        -- toggle was off, the same way a real relogin resumes one paused
        -- by going offline - both share the same
        -- FV.SV.spellResistRemainingSeconds snapshot and
        -- FV:RestoreSpellResistBuff() re-anchoring logic. Guarded so this
        -- can never overwrite an already-active buff (shouldn't be
        -- possible given disable always clears spellResistEndTime below,
        -- but cheap to guard against regardless).
        if not FV.State.spellResistEndTime then
            self:RestoreSpellResistBuff()
        end
        self:OnUpdate(0)
    else
        -- Pause the spell-resist buff's countdown the same way a real
        -- logout pauses it: snapshot the remaining time into
        -- FV.SV.spellResistRemainingSeconds via the existing
        -- SaveSpellResistRemaining, then stop the absolute clock it was
        -- counting down against and unregister the tick, so it can't
        -- keep expiring in real time while the addon's own simulation is
        -- switched off.
        if FV.State.spellResistEndTime then
            self:SaveSpellResistRemaining()
            FV.State.spellResistEndTime = nil
            EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_SpellResistTick")
        end

        if Frostfall_HUD and Frostfall_HUD.container then
            Frostfall_HUD.container:SetHidden(true)
        end
        if Frostfall_Overlay then
            if Frostfall_Overlay.coldWindow then Frostfall_Overlay.coldWindow:SetHidden(true) end
            if Frostfall_Overlay.hotWindow  then Frostfall_Overlay.hotWindow:SetHidden(true)  end
        end
    end
end

-- ============================================================
-- EVENT HANDLERS
-- ============================================================

function FV:OnPlayerActivated()
    if not FV.State._initialized then
        local ambientTemp = self:GetZoneAmbientTemp()
        FV.State.playerTemp   = ambientTemp   -- ambientTemp is already °C
        FV.State.lastTempBand = GetTempBand(ambientTemp)
        FV.State._initialized = true
        FV_Log("First activation — setting playerTemp to ambient: " .. ambientTemp)
    end
    self:OnUpdate(0)
end

function FV:OnZoneChanged()
    FV_Log("Zone changed — drift will adjust playerTemp toward new ambient")
    FV.State.currentZoneName = "Unknown"
end

-- ============================================================
-- SPELL-RESIST REAGENT BUFF
--
-- Reagents that carry the "Increase Spell Resist" alchemy trait, per UESP
-- (https://en.uesp.net/wiki/Online:Bugloss, .../Online:White_Cap,
-- .../Online:Mudcrab_Chitin, .../Online:Clam_Gall): Bugloss, Clam Gall,
-- Mudcrab Chitin, White Cap.
--
-- CORRECTED: this comment previously claimed the item IDs below were
-- "cross-checked against RolePlayNeeds' own RPN_REAGENT_TRAITS table."
-- No such table exists in RolePlayNeeds' published source (confirmed by
-- direct inspection of the official v0.7 BETA release) — RolePlayNeeds has
-- no alchemy-trait/reagent handling at all. This is a static item-ID
-- lookup this project built itself, since GetAlchemyItemTraitInfo only
-- works at an open alchemy station and so can't detect traits on a reagent
-- being eaten out in the field. Item IDs: Bugloss (30160) and Mudcrab
-- Chitin (77591) confirmed against UESP esolog item-link data; Clam Gall
-- (139020) and White Cap (30154) confirmed directly in-game.
-- ============================================================
FV.SPELL_RESIST_REAGENT_IDS = {
    [30160]  = true,  -- Bugloss
    [77591]  = true,  -- Mudcrab Chitin
    [139020] = true,  -- Clam Gall
    [30154]  = true,  -- White Cap
}

-- ============================================================
-- Alchemy water solvents (used by OnWaterLoot below to detect harvested
-- water for the cooling mechanic). There is no single "water" item or
-- itemType -- water solvents are a whole family of separate items, one
-- per potion tier. Matched here by itemId (language-independent) rather
-- than display name, per UESP's ESO Item database
-- (https://ts.uesp.net/esolog/itemLink.php?itemid=<id>), cross-referenced
-- against a second, independent source (eso-hub.com's trading pages,
-- which encode the same itemId in their URL) for each entry below,
-- except Star Dew, which the developer looked up manually and confirmed.
-- ============================================================
FV.WATER_SOLVENT_ITEM_IDS = {
    [883]   = true,  -- Natural Water
    [1187]  = true,  -- Clear Water
    [4570]  = true,  -- Pristine Water
    [23265] = true,  -- Cleansed Water
    [23266] = true,  -- Filtered Water
    [23267] = true,  -- Purified Water
    [23268] = true,  -- Cloud Mist
    [64500] = true,  -- Star Dew
    [64501] = true,  -- Lorkhan's Tears
}

local SPELL_RESIST_BASE_DURATION = 30 * 60   -- 30 real-world minutes, in seconds
local SPELL_RESIST_WARNING_WINDOW = 5 * 60   -- warn once per minute for the last 5 minutes

-- ── Medicinal Use passive rank (Alchemy skill line) ──────────────────────
-- Rank 1/2/3 extends potion-effect duration by 10%/20%/30%. We apply the
-- same scaling to this reagent's temperature-steadying duration.
--
-- BUGFIX (v3.4.1): this previously called GetCraftingSkillLineIndices(),
-- which does not exist anywhere in the ESO UI API (verified against
-- esoui/esoui's ESOUIDocumentation.txt). Calling a nil global throws a Lua
-- error, which silently aborted the ENTIRE OnReagentInventoryChange handler
-- before it ever reached ApplySpellResistReagent/ZO_Alert — i.e. it broke
-- reagent consumption detection outright, not just the duration bonus.
--
-- Fixed by not trying to look up the Alchemy skill line by ID at all.
-- GetNumSkillLines(SKILL_TYPE_TRADESKILL) + GetNumSkillAbilities() +
-- GetSkillAbilityInfo() are all real, documented functions; we just walk
-- every crafting skill line's abilities looking for the passive named
-- "Medicinal Use" (a name unique to Alchemy), which sidesteps needing to
-- identify the Alchemy line by name or ID in the first place.
local function GetMedicinalUseRank()
    if not GetNumSkillLines or not GetNumSkillAbilities or not GetSkillAbilityInfo then
        return 0
    end

    local numLines = GetNumSkillLines(SKILL_TYPE_TRADESKILL)
    for skillLineIndex = 1, numLines do
        local numAbilities = GetNumSkillAbilities(SKILL_TYPE_TRADESKILL, skillLineIndex)
        for abilityIndex = 1, numAbilities do
            local name, _, earnedRank, passive = GetSkillAbilityInfo(SKILL_TYPE_TRADESKILL, skillLineIndex, abilityIndex)
            if passive and name == "Medicinal Use" then
                return earnedRank or 0
            end
        end
    end
    return 0
end

function FV:GetSpellResistDurationSeconds()
    local rank = GetMedicinalUseRank()
    local bonus = (rank or 0) * 0.10   -- 0 / 0.10 / 0.20 / 0.30
    local duration = SPELL_RESIST_BASE_DURATION * (1 + bonus)
    FV_Log(string.format("SpellResist duration: base=%ds, MedicinalUse rank=%d, total=%.0fs",
        SPELL_RESIST_BASE_DURATION, rank or 0, duration))
    return duration
end

-- Ticks once per second only while the buff is active; unregistered the
-- instant the buff ends or is never started, so it costs nothing at rest.
function FV:OnSpellResistTick()
    if not FV.State.spellResistEndTime then
        EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_SpellResistTick")
        return
    end

    local now = GetGameTimeMilliseconds() / 1000
    local remaining = FV.State.spellResistEndTime - now

    -- Keep FV.SV.spellResistRemainingSeconds continuously current while the
    -- buff is running, rather than relying solely on the one-shot write in
    -- SaveSpellResistRemaining (EVENT_PLAYER_DEACTIVATED). That single
    -- deactivate-time write was observed NOT reaching disk in practice --
    -- likely a race between our callback and the client's own SavedVariables
    -- flush -- so mirroring this every tick (same pattern already used
    -- successfully for FV.SV.playerTemp) means whatever value is sitting in
    -- FV.SV at flush time is already correct, independent of that race.
    if FV.SV then FV.SV.spellResistRemainingSeconds = remaining end

    if remaining <= 0 then
        FV.State.spellResistOffset       = 0
        FV.State.spellResistEndTime      = nil
        FV.State.spellResistWarnedMinute = nil
        if FV.SV then FV.SV.spellResistRemainingSeconds = nil end
        EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_SpellResistTick")
        FV:Notify("|c88CCFFThe reagent's steadying effect on your body temperature fades.|r")
        FV_Log("SpellResist: buff expired — modifier removed, calculations proceed as normal.")
        self:OnUpdate(0)
        return
    end

    if remaining <= SPELL_RESIST_WARNING_WINDOW then
        local minuteMark = math.ceil(remaining / 60)
        if minuteMark >= 1 and minuteMark ~= FV.State.spellResistWarnedMinute then
            FV.State.spellResistWarnedMinute = minuteMark
            FV:Notify(string.format("|cFFCC66The reagent's steadying effect will fade in %d minute%s.|r",
                    minuteMark, minuteMark == 1 and "" or "s"))
        end
    end
end

-- Applies (or refreshes) the spell-resist temperature-steadying buff.
-- Per spec: shift the effective temp toward the midpoint of the comfortable
-- band by up to 10°C — close differentials are fully neutralized, larger
-- ones are only partially offset.
-- Applies (or refreshes) the spell-resist temperature-steadying buff.
-- Just starts/resets the 30-min(+rank bonus) timer — the actual offset is
-- computed live every time FV:GetEffectiveTemp() runs (see above), so it
-- always reflects the player's CURRENT real differential from neutral,
-- not a snapshot taken at the moment of consumption.
function FV:ApplySpellResistReagent()
    local wasActive = FV.State.spellResistEndTime ~= nil
    local duration = self:GetSpellResistDurationSeconds()
    FV.State.spellResistEndTime      = GetGameTimeMilliseconds() / 1000 + duration
    FV.State.spellResistWarnedMinute = nil

    -- No SV write here anymore -- the buff pauses while offline rather than
    -- counting down in real time, so there's nothing meaningful to persist
    -- until the player actually logs out. SaveSpellResistRemaining (below,
    -- registered on EVENT_PLAYER_DEACTIVATED) captures FV.State.spellResistEndTime's
    -- remaining duration at that point instead. Clear any stale saved value
    -- from a previous session in case this application is itself happening
    -- very early (e.g. before EVENT_PLAYER_DEACTIVATED could ever fire) --
    -- RestoreSpellResistBuff already consumes/clears it on load, so this is
    -- just defensive.
    if FV.SV then
        FV.SV.spellResistRemainingSeconds = nil
    end

    EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_SpellResistTick")
    EVENT_MANAGER:RegisterForUpdate(FV.NAME .. "_SpellResistTick", 1000, function() FV:OnSpellResistTick() end)

    FV_Log(string.format("SpellResist: %s — ends in %.0fs",
        wasActive and "timer reset" or "buff applied",
        FV.State.spellResistEndTime - GetGameTimeMilliseconds() / 1000))

    if wasActive then
        FV:Notify("|c88CCFFThe reagent's steadying effect on your body temperature is renewed.|r")
    else
        FV:Notify("|c88CCFFThe reagent steadies your body temperature.|r")
    end

    self:OnUpdate(0)
end

-- ============================================================
-- DEBUG: RESET STATUS
--
-- Immediately resets the player's temperature status to neutral and clears
-- any active modifier from a consumed spell-resist reagent. Used by
-- "/ff debug resetStatus" — mainly for testing/debugging, or for a player
-- who wants a clean slate without waiting for drift or a buff to expire.
-- ============================================================
function FV:ResetStatus()
    -- Neutral = the midpoint of the comfortable band, matching the value
    -- FV:GetEffectiveTemp() itself treats as neutral for the spell-resist offset.
    local neutral = (FV.TEMP.COMFORTABLE_LO + FV.TEMP.COMFORTABLE_HI) / 2

    FV.State.playerTemp   = neutral
    FV.State.lastTempBand = GetTempBand(neutral)

    -- Clear the spell-resist reagent buff outright, rather than letting it
    -- expire naturally.
    FV.State.spellResistOffset       = 0
    FV.State.spellResistEndTime      = nil
    FV.State.spellResistWarnedMinute = nil
    EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_SpellResistTick")

    if FV.SV then
        FV.SV.playerTemp = neutral
        FV.SV.spellResistRemainingSeconds = nil
    end

    FV_Log(string.format("ResetStatus: playerTemp reset to neutral (%.1f°C), spell-resist buff cleared.", neutral))
    self:OnUpdate(0)
end

-- ── Alchemy reagent consumption → spell-resist buff ──────────────────────
-- Mirrors RolePlayNeeds' OnInventoryChange pattern: EVENT_INVENTORY_SINGLE
-- _SLOT_UPDATE with a negative stackCountChange indicates an item left the
-- stack (consumed, not just moved/sold), gated off while a merchant,
-- crafting station, or bank (personal or guild) window is open so buying/selling/refining reagents can't
-- be mistaken for eating them.
FV._lastInventoryState = {}
local _ff_isMerchantOpen        = false
local _ff_isCraftingStationOpen = false
local _ff_isBankOpen            = false

function FV:OnReagentInventoryChange(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    if not FV.SV or not FV.SV.enabled then return end

    local key = bagId .. ":" .. slotId
    local prevLink = FV._lastInventoryState[key]
    local currentLink = GetItemLink(bagId, slotId)
    local itemLink = (currentLink ~= "" and currentLink) or prevLink
    FV._lastInventoryState[key] = (currentLink ~= "" and currentLink) or nil

    if stackCountChange >= 0 then return end
    if not itemLink or itemLink == "" then return end
    if _ff_isMerchantOpen or _ff_isCraftingStationOpen or _ff_isBankOpen then return end

    local itemType = GetItemLinkItemType(itemLink)
    if itemType ~= ITEMTYPE_REAGENT then return end

    local itemId = GetItemLinkItemId and GetItemLinkItemId(itemLink)
    FV_Log(string.format("Reagent consumed: %s (itemId=%s)",
        GetItemLinkName(itemLink) or "?", tostring(itemId)))

    if itemId and FV.SPELL_RESIST_REAGENT_IDS[itemId] then
        self:ApplySpellResistReagent()
    end
end

-- ── Dynamic reagent-listener register/unregister ────────────────────────
-- The reagent-consumption listener matters almost all of the time (that's
-- when players actually eat food/potions/etc.) and essentially never while
-- a merchant, crafting station, or bank window is open (those only ever
-- produce buy/sell/refine/withdraw/deposit noise on the same event) -- so
-- rather than leaving it registered permanently and filtering that noise
-- out in Lua, it's unregistered for the (short, relatively rare) windows
-- where a trade/bank/craft UI is open, and re-registered the moment none
-- of them are anymore.
local _reagentListenerRegistered = false

local function RegisterReagentListener()
    if _reagentListenerRegistered then return end
    EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_ReagentInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(...) FV:OnReagentInventoryChange(...) end)
    -- Filtered to BAG_BACKPACK (reagents are eaten from the carried backpack,
    -- never the bank or worn-equipment bags) AND to
    -- INVENTORY_UPDATE_REASON_DEFAULT (the "an item actually moved into or
    -- out of the inventory" reason -- excluding INVENTORY_UPDATE_REASON_
    -- DURABILITY_CHANGE and similar non-consumption reasons this event also
    -- fires for, e.g. gear durability or charges changing). Both filters
    -- stop the event from ever reaching Lua at all for updates that can't
    -- possibly be a reagent being eaten. See https://wiki.esoui.com/AddFilterForEvent.
    EVENT_MANAGER:AddFilterForEvent(FV.NAME .. "_ReagentInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BACKPACK,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    -- Second registration, identical aside from the bag id, so reagents
    -- eaten straight from the craft bag (BAG_VIRTUAL -- where they live
    -- instead of the backpack once a player has craft bag access) are also
    -- picked up. AddFilterForEvent only takes one bag id per named
    -- registration, so this needs its own name rather than a second filter
    -- on "_ReagentInventory" above. OnReagentInventoryChange itself needs no
    -- change -- its bagId..":"..slotId key already keeps backpack and craft
    -- bag slots from colliding.
    EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_ReagentInventory_CraftBag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(...) FV:OnReagentInventoryChange(...) end)
    EVENT_MANAGER:AddFilterForEvent(FV.NAME .. "_ReagentInventory_CraftBag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_VIRTUAL,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    _reagentListenerRegistered = true
end

local function UnregisterReagentListener()
    if not _reagentListenerRegistered then return end
    EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_ReagentInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_ReagentInventory_CraftBag", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    _reagentListenerRegistered = false
end

-- ── Merchant / crafting-station / bank gating ───────────────────────────
-- Buying/selling, refining, or withdrawing/depositing a reagent fires the
-- same EVENT_INVENTORY_SINGLE_SLOT_UPDATE as actually eating one, so all
-- three windows are tracked here; the reagent listener itself is
-- unregistered for as long as any one of them is open (see above), rather
-- than staying registered and being checked/ignored in Lua.
local function OnStoreOpen()
    _ff_isMerchantOpen = true
    UnregisterReagentListener()
end
local function OnStoreClose()
    _ff_isMerchantOpen = false
    if not (_ff_isMerchantOpen or _ff_isCraftingStationOpen or _ff_isBankOpen) then
        RegisterReagentListener()
    end
end
local function OnCraftOpen()
    _ff_isCraftingStationOpen = true
    UnregisterReagentListener()
end
local function OnCraftClose()
    _ff_isCraftingStationOpen = false
    if not (_ff_isMerchantOpen or _ff_isCraftingStationOpen or _ff_isBankOpen) then
        RegisterReagentListener()
    end
end
local function OnBankOpen()
    _ff_isBankOpen = true
    UnregisterReagentListener()
end
local function OnBankClose()
    _ff_isBankOpen = false
    if not (_ff_isMerchantOpen or _ff_isCraftingStationOpen or _ff_isBankOpen) then
        RegisterReagentListener()
    end
end

-- ============================================================
-- ENVIRONMENTAL TEMPERATURE MECHANICS
-- ============================================================

-- ── Water ingredient loot → cooling ─────────────────────────────────────────
-- When the player loots an alchemy water ingredient (solvent), their temperature
-- drops by 5°C.
--
-- EVENT_LOOT_RECEIVED's real, documented signature is:
--   (eventId, receivedBy, itemName, quantity, soundCategory, lootType,
--    isSelf, isPickpocketLoot, questItemIcon, itemId, isStolen)
-- The previous version of this handler had the parameters misaligned --
-- it named the 4th param itemName2, the 5th itemType, and the 6th
-- itemName4, then compared that mis-named 5th param (which is actually
-- soundCategory, an ItemUISoundCategory value, not an item type at all)
-- against a hardcoded 19. It was later fixed to match by item name
-- instead (see FV.WATER_SOLVENT_NAMES, no longer present), but itemId is
-- the more robust, language-independent choice -- see
-- FV.WATER_SOLVENT_ITEM_IDS above for how water is actually identified now.
local function OnWaterLoot(eventId, receivedBy, itemName, quantity, soundCategory, lootType,
        isSelf, isPickpocketLoot, questItemIcon, itemId, isStolen)
        if not FV.SV or not FV.SV.enabled then return end
        if not itemId or not FV.WATER_SOLVENT_ITEM_IDS[itemId] then return end
        -- Only cool the player if they are already warm (above the comfortable band).
        -- Cold or comfortable players get no benefit — the water is refreshing,
        -- not hypothermia-inducing.
        if FV.State.playerTemp <= FV.TEMP.COMFORTABLE_HI then return end

        local newTemp = math.max(-20, FV.State.playerTemp - 5)
        FV.State.playerTemp = newTemp
        FV:Notify("|c88CCFFThe cold water cools you down.|r")
        FV_Log(string.format("WaterLoot: playerTemp reduced by 10 → %.1f°C", newTemp))
        if FV.SV.showHUD and Frostfall_HUD then
            Frostfall_HUD:Update(FV:GetEffectiveTemp(), FV.State)
        end
        if FV.SV.enableOverlay and Frostfall_Overlay then
            Frostfall_Overlay:Update(FV:GetEffectiveTemp(), FV.State)
        end
end

-- ── Crafting station interaction → warming ───────────────────────────────────
-- When the player opens a provisioning or smithing station, their temperature
-- rises by 5°C (forges and cooking fires are hot).  Rate-limited to once per
-- minute so rapid open/close spam cannot be exploited.
local _lastStationWarmTime = 0
local STATION_WARM_COOLDOWN = 60   -- seconds

-- Registered inside FV:Initialize() below (see "INITIALIZATION" section) —
-- not here at file scope, so FV.SV is guaranteed to exist before this can fire.
local function OnStationWarm(_, craftingType, sameStation)
        if not FV.SV or not FV.SV.enabled then return end
        -- Only trigger for provisioning (cooking) and blacksmithing (forge)
        if craftingType ~= CRAFTING_TYPE_PROVISIONING
        and craftingType ~= CRAFTING_TYPE_BLACKSMITHING then return end
        -- Only warm the player if they are already cold (below the comfortable band).
        -- Warm or comfortable players feel no extra heat from the station.
        if FV.State.playerTemp >= FV.TEMP.COMFORTABLE_LO then return end

        local now = GetGameTimeMilliseconds() / 1000
        if now - _lastStationWarmTime < STATION_WARM_COOLDOWN then return end
        _lastStationWarmTime = now

        local newTemp = math.min(70, FV.State.playerTemp + 5)
        FV.State.playerTemp = newTemp
        local stationName = craftingType == CRAFTING_TYPE_PROVISIONING
            and "cooking fire" or "forge"
        FV:Notify(string.format("|cFF9933The heat of the %s warms you.|r", stationName))
        FV_Log(string.format("StationWarm: playerTemp +5 → %.1f°C (%s)", newTemp, stationName))
        if FV.SV.showHUD and Frostfall_HUD then
            Frostfall_HUD:Update(FV:GetEffectiveTemp(), FV.State)
        end
        if FV.SV.enableOverlay and Frostfall_Overlay then
            Frostfall_Overlay:Update(FV:GetEffectiveTemp(), FV.State)
        end
end

-- ── Sit/Sleep detection (for gating temperature emotes) ─────────────────
-- Ported and scoped down from Realistic Needs and Diseases' own Rest.lua —
-- RND needed full sit/sleep tracking for its fatigue-recovery mechanics
-- (three separate regen rates, drunkenness sober-up acceleration, etc.);
-- Frostfall only needs the single FV:IsResting() boolean this produces, to
-- stop TickEmote from firing a cold/hot emote that cancels an already-in-
-- progress sit/sleep pose. No recovery/regen logic is ported, only the
-- detection itself. See RND's Rest.lua for the fuller history/reasoning
-- behind each piece below — it's reproduced here essentially unchanged.
--
-- Two independent detection paths, both confirmed against the current
-- ESOUI source (same as RND's own comments document):
--   1. Native /sit-/sleep-family slash commands, HOOKED (original handler
--      preserved and still called).
--   2. Interacting with a real in-world object whose reticle prompt reads
--      "Sit" (a placeable chair, bench, etc.) — via ZO_PreHook on
--      RETICLE:TryHandlingInteraction (to read the prompt text) plus
--      reassigning INTERACTIVE_WHEEL_MANAGER.StartInteraction (the actual
--      "interact key was just pressed" trigger point; unprotected, unlike
--      GameCameraInteractStart).
--
-- A generous, position-based tolerance clears the resting flag once the
-- player actually stands up and walks away — deliberately looser than a
-- normal "did the player move" check, since a sit/sleep pose's own settle-
-- in animation and idle sway can shift the tracked root position more than
-- a tight tolerance would allow without falsely canceling the pose seconds
-- after it starts (this was RND's own hard-won fix; ported directly).
local REST_POSITION_EPSILON = 150
local _restLastPosition = nil
local _isSeated  = false
local _isSleeping = false

local function HasRestPositionChanged()
    local x, y, z = GetUnitWorldPosition("player")
    if not x then return true end  -- fail safe: assume moved if the API fails, rather than getting stuck resting forever

    if not _restLastPosition then
        _restLastPosition = { x = x, y = y, z = z }
        return false
    end

    local dx, dy, dz = x - _restLastPosition.x, y - _restLastPosition.y, z - _restLastPosition.z
    local distSq = dx * dx + dy * dy + dz * dz
    _restLastPosition = { x = x, y = y, z = z }
    return distSq > (REST_POSITION_EPSILON * REST_POSITION_EPSILON)
end

-- "Meditate" has no literal ESO emote — /pray and /kneelpray are the
-- closest thematic stand-ins, same as RND documents for its own copy of
-- this list.
local REST_SIT_COMMANDS   = { "/sit", "/sit2", "/sit3", "/sit4", "/sit5", "/sit6", "/sitchair" }
local REST_SLEEP_COMMANDS = { "/sleep", "/sleep2", "/faint", "/pray", "/kneelpray" }

local function HookRestCommand(commandString, onTriggered)
    local original = SLASH_COMMANDS[commandString]
    if not original then return end  -- command not available in this client; nothing to hook
    SLASH_COMMANDS[commandString] = function(args)
        original(args)
        onTriggered()
    end
end

local function OnRestSitTriggered()
    _isSeated  = true
    _isSleeping = false
    -- Re-baseline rather than comparing against a pre-pose position — the
    -- act of sitting down itself shifts the tracked root position, and
    -- without this reset that shift alone could immediately read as
    -- "moved" on the very next check.
    _restLastPosition = nil
end

local function OnRestSleepTriggered()
    _isSleeping = true
    _isSeated  = false
    _restLastPosition = nil
end

-- Only "Sit" (action verb) and "Chair" (object name) have actually been
-- observed in-game here — the rest is speculative/defensive, same caveat
-- RND's own copy of this list carries.
local REST_SIT_INTERACTION_WORDS = {
    "sit", "seat", "chair", "bench", "stool", "pew", "throne",
    "couch", "sofa", "settee", "loveseat", "ottoman", "stump", "log",
}
local REST_SLEEP_INTERACTION_WORDS = { "sleep" }

local function RestInteractionMatchesAnyWord(text, words)
    if not text then return false end
    for token in text:gmatch("%a+") do
        local lowerToken = token:lower()
        for _, word in ipairs(words) do
            if lowerToken == word then return true end
        end
    end
    return false
end

local _lastRestInteractionText = nil

local function HookRestWorldInteractionDetection()
    -- Never blocks anything (always returns false) — only records what the
    -- current interaction prompt says.
    -- ZO_PreHook passes the method's self (RETICLE) as the first argument
    -- (v3.4.33 fix - see header).
    ZO_PreHook(RETICLE, "TryHandlingInteraction", function(self, interactionPossible)
        if interactionPossible then
            local action, interactableName = GetGameCameraInteractableActionInfo()
            _lastRestInteractionText = (action or "") .. " " .. (interactableName or "")
        else
            _lastRestInteractionText = nil
        end
        return false
    end)

    if INTERACTIVE_WHEEL_MANAGER then
        local originalWheelStartInteraction = INTERACTIVE_WHEEL_MANAGER.StartInteraction
        INTERACTIVE_WHEEL_MANAGER.StartInteraction = function(...)
            if RestInteractionMatchesAnyWord(_lastRestInteractionText, REST_SIT_INTERACTION_WORDS) then
                OnRestSitTriggered()
            elseif RestInteractionMatchesAnyWord(_lastRestInteractionText, REST_SLEEP_INTERACTION_WORDS) then
                OnRestSleepTriggered()
            end
            return originalWheelStartInteraction(...)
        end
    end
    -- If INTERACTIVE_WHEEL_MANAGER doesn't exist (future API change), this
    -- silently skips the world-interaction path — the native /sit-/sleep-
    -- family slash-command hooks above still work independently of this.
end

-- Exposed for TickEmote's gate above.
function FV:IsResting()
    return _isSeated or _isSleeping
end

-- Dedicated 5-second poll, deliberately decoupled from Frostfall's own
-- (much slower, user-configurable 1-10 minute) Drift update interval —
-- resting state needs to clear promptly once the player actually stands up
-- and walks away, regardless of how that unrelated interval is configured.
local function OnRestPositionCheck()
    if not (_isSeated or _isSleeping) then return end
    if HasRestPositionChanged() then
        _isSeated  = false
        _isSleeping = false
    end
end

local function InitializeRestDetection()
    for _, cmd in ipairs(REST_SIT_COMMANDS) do
        HookRestCommand(cmd, OnRestSitTriggered)
    end
    for _, cmd in ipairs(REST_SLEEP_COMMANDS) do
        HookRestCommand(cmd, OnRestSleepTriggered)
    end
    HookRestWorldInteractionDetection()
end

-- ============================================================
-- EVENT REGISTRATION, GATED ON FV.SV.enabled
--
-- Previously, every event below was registered unconditionally inside
-- FV:Initialize() and simply checked `if not FV.SV.enabled then return end`
-- at the top of each handler -- meaning a disabled Frostfall still received
-- and processed every single one of these events for nothing, just to
-- immediately bail. CheckIfEventsNeeded is now the one place that actually
-- registers or unregisters all of them, based on FV.SV.enabled: nothing
-- fires at all while disabled, aside from EVENT_ADD_ON_LOADED itself
-- (registered separately, once, at the very end of this file -- that one
-- is always needed regardless of this setting). Called once at the end of
-- FV:Initialize(), and again from FV:SetEnabled() whenever the setting is
-- flipped, in either direction, at runtime.
-- ============================================================
CheckIfEventsNeeded = function()
    if FV.SV and FV.SV.enabled then
        if _eventsRegistered then return end

        EVENT_MANAGER:RegisterForEvent(FV.NAME, EVENT_PLAYER_ACTIVATED,
            function() FV:OnPlayerActivated() end)
        EVENT_MANAGER:RegisterForEvent(FV.NAME, EVENT_ZONE_CHANGED,
            function() FV:OnZoneChanged() end)

        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_StoreOpen", EVENT_OPEN_STORE, OnStoreOpen)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_StoreClose", EVENT_CLOSE_STORE, OnStoreClose)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_CraftOpen", EVENT_CRAFTING_STATION_INTERACT, OnCraftOpen)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_CraftClose", EVENT_END_CRAFTING_STATION_INTERACT, OnCraftClose)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_BankOpen", EVENT_OPEN_BANK, OnBankOpen)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_BankClose", EVENT_CLOSE_BANK, OnBankClose)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_GuildBankOpen", EVENT_OPEN_GUILD_BANK, OnBankOpen)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_GuildBankClose", EVENT_CLOSE_GUILD_BANK, OnBankClose)

        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_WaterLoot", EVENT_LOOT_RECEIVED, OnWaterLoot)
        EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_StationWarm", EVENT_CRAFTING_STATION_INTERACT, OnStationWarm)

        -- None of the trade/bank/craft windows should already be open at
        -- this point, but check anyway rather than assume.
        if not (_ff_isMerchantOpen or _ff_isCraftingStationOpen or _ff_isBankOpen) then
            RegisterReagentListener()
        end

        local tickSeconds = GetUpdateIntervalMs() / 1000
        EVENT_MANAGER:RegisterForUpdate(FV.NAME .. "_Drift", GetUpdateIntervalMs(), function()
            if FV.SV then FV.SV.playerTemp = FV.State.playerTemp end
            FV:OnUpdate(tickSeconds)
        end)
        EVENT_MANAGER:RegisterForUpdate(FV.NAME .. "_Emote", EMOTE_LOOP_INTERVAL, function()
            FV:TickEmote()
        end)
        EVENT_MANAGER:RegisterForUpdate(FV.NAME .. "_RestCheck", 5000, OnRestPositionCheck)

        _eventsRegistered = true
    else
        if not _eventsRegistered then return end

        EVENT_MANAGER:UnregisterForEvent(FV.NAME, EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME, EVENT_ZONE_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_StoreOpen", EVENT_OPEN_STORE)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_StoreClose", EVENT_CLOSE_STORE)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_CraftOpen", EVENT_CRAFTING_STATION_INTERACT)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_CraftClose", EVENT_END_CRAFTING_STATION_INTERACT)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_BankOpen", EVENT_OPEN_BANK)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_BankClose", EVENT_CLOSE_BANK)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_GuildBankOpen", EVENT_OPEN_GUILD_BANK)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_GuildBankClose", EVENT_CLOSE_GUILD_BANK)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_WaterLoot", EVENT_LOOT_RECEIVED)
        EVENT_MANAGER:UnregisterForEvent(FV.NAME .. "_StationWarm", EVENT_CRAFTING_STATION_INTERACT)
        UnregisterReagentListener()
        EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_Drift")
        EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_Emote")
        EVENT_MANAGER:UnregisterForUpdate(FV.NAME .. "_RestCheck")

        -- Reset trade-window state so a stale "open" flag can't linger
        -- across a disable/re-enable cycle.
        _ff_isMerchantOpen        = false
        _ff_isCraftingStationOpen = false
        _ff_isBankOpen            = false

        _eventsRegistered = false
    end
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

-- Restores an in-progress spell-resist reagent buff across a relog, PAUSED
-- while offline rather than counting down in real time. FV.SV.spellResist
-- RemainingSeconds is a plain duration (seconds left, captured at the
-- moment of the previous logout by SaveSpellResistRemaining below) — not
-- an absolute timestamp of any kind — so restoring it is just re-basing
-- that same duration onto THIS session's GetGameTimeMilliseconds() clock,
-- with no elapsed-offline-time math involved at all. However long the
-- player was actually offline, they come back to exactly the time that was
-- left when they logged out. FV:OnSpellResistTick/ApplySpellResistReagent
-- take it from there exactly as if the buff had never stopped ticking.
function FV:RestoreSpellResistBuff()
    -- Orphaned field from the pre-3.4.21 (v3.4.19/3.4.20) persistence
    -- scheme, which stored an absolute epoch timestamp here instead of a
    -- plain duration. Nothing has read this field since 3.4.21; clear it
    -- out for anyone upgrading from an older save rather than leaving it
    -- as permanent dead weight in SavedVariables.
    if FV.SV and FV.SV.spellResistEndTimestamp ~= nil then
        FV.SV.spellResistEndTimestamp = nil
    end

    if not FV.SV or not FV.SV.spellResistRemainingSeconds then
        FV_Log("RestoreSpellResistBuff: no saved spellResistRemainingSeconds found — nothing to restore.")
        return
    end

    local remaining = FV.SV.spellResistRemainingSeconds
    -- Consumed once, not left sitting around -- the live value going
    -- forward is FV.State.spellResistEndTime; SaveSpellResistRemaining
    -- re-populates this field fresh at the NEXT logout. Leaving a stale
    -- value here after a session that ends without EVENT_PLAYER_DEACTIVATED
    -- firing (e.g. a crash) is a possible, accepted edge case -- the same
    -- as any other addon's SavedVariables not surviving an unclean exit.
    FV.SV.spellResistRemainingSeconds = nil
    if remaining <= 0 then return end

    FV.State.spellResistEndTime = GetGameTimeMilliseconds() / 1000 + remaining
    EVENT_MANAGER:RegisterForUpdate(FV.NAME .. "_SpellResistTick", 1000, function() FV:OnSpellResistTick() end)
    FV_Log(string.format("SpellResist: resumed after a relog with %.0fs remaining (paused while offline).", remaining))
end

-- Captures the buff's current remaining duration into SavedVariables right
-- before the player leaves this session (reload UI, logout, or camping),
-- so RestoreSpellResistBuff above can resume it with the exact same time
-- left next login -- pausing while offline instead of continuing to count
-- down against real-world wall-clock time regardless of login state.
-- EVENT_PLAYER_DEACTIVATED is the standard ESO hook for "save state before
-- the session ends," used the same way by many other addons.
function FV:SaveSpellResistRemaining()
    if not FV.SV then return end
    if not FV.State.spellResistEndTime then
        -- No currently-active buff. This could genuinely mean no buff was
        -- ever applied, OR that it's already paused (master toggle off)
        -- with its remaining time already correctly sitting here from
        -- FV:SetEnabled(false) - don't clear a real paused snapshot to
        -- nil just because a real logout also happens to fire while
        -- paused (EVENT_PLAYER_DEACTIVATED still fires normally even
        -- with the master toggle off).
        if FV.SV.spellResistRemainingSeconds == nil then
            FV_Log("SaveSpellResistRemaining: no buff active at logout — nothing to save.")
        else
            FV_Log("SaveSpellResistRemaining: buff already paused (master toggle off) — leaving saved remaining time as-is.")
        end
        return
    end

    local remaining = FV.State.spellResistEndTime - (GetGameTimeMilliseconds() / 1000)
    FV.SV.spellResistRemainingSeconds = (remaining > 0) and remaining or nil
    FV_Log(string.format("SaveSpellResistRemaining: saved %.0fs remaining at logout.", remaining))
end

function FV:Initialize()
    -- Namespaced by GetWorldName() ("EU Megaserver" / "NA Megaserver" / "PTS")
    -- so each server keeps its own saved data instead of all three sharing
    -- (and overwriting) one account-wide table.
    FV.SV = ZO_SavedVars:NewAccountWide("FrostfallSV", FV.SAVED_VARS_VER, GetWorldName(), FV.Defaults)

    if FV.SV.playerTemp then
        FV.State.playerTemp   = FV.SV.playerTemp
        FV.State.lastTempBand = GetTempBand(FV.SV.playerTemp)
        FV.State._initialized = true
    end

    -- Only resume/consume a saved paused spell-resist buff if the master
    -- toggle is actually on - otherwise leave
    -- FV.SV.spellResistRemainingSeconds parked untouched, so it resumes
    -- correctly (with zero decay across the entire disabled period)
    -- whenever the player later re-enables via FV:SetEnabled(true),
    -- instead of restoring an active countdown that immediately starts
    -- expiring in real time despite the toggle being off.
    if FV.SV.enabled then
        self:RestoreSpellResistBuff()
    end

    -- Sit/sleep command + world-interaction hooks (see the section above
    -- for full reasoning) are registered unconditionally, once, same as
    -- the spell-resist-save hook just above — they're cheap, passive state
    -- tracking regardless of FV.SV.enabled, and SLASH_COMMANDS/
    -- INTERACTIVE_WHEEL_MANAGER hooks aren't the kind of thing that's safe
    -- or meaningful to install/remove repeatedly across an enable/disable
    -- cycle. Only the periodic position-poll timer that clears the resting
    -- flag is tied to FV.SV.enabled, inside CheckIfEventsNeeded below.
    InitializeRestDetection()

    -- Registered unconditionally (not inside the FV.SV.enabled-gated block
    -- further down) since it needs to fire and capture remaining time
    -- regardless of whether the rest of the addon's simulation is enabled —
    -- an in-progress buff shouldn't silently lose its pause/resume tracking
    -- just because the player has Frostfall's other features toggled off.
    EVENT_MANAGER:RegisterForEvent(FV.NAME .. "_SpellResistSaveOnDeactivate", EVENT_PLAYER_DEACTIVATED,
        function() FV:SaveSpellResistRemaining() end)

    -- Resolve stable emoteIds from PLAYER_EMOTE_MANAGER before building the
    -- config menu, so the dropdown is populated when the panel is registered.
    self:ResolveEmoteDefaults()
    self:BuildEmoteChoices()

    if Frostfall_HUD        then Frostfall_HUD:Initialize()        end
    if Frostfall_Overlay    then Frostfall_Overlay:Initialize()    end
    if Frostfall_ConfigMenu then Frostfall_ConfigMenu:Initialize()  end

    -- Registers (or doesn't, if FV.SV.enabled is false) every event and
    -- update-loop Frostfall uses beyond EVENT_ADD_ON_LOADED itself. See
    -- "EVENT REGISTRATION, GATED ON FV.SV.enabled" above for what this
    -- covers and why.
    CheckIfEventsNeeded()

    SLASH_COMMANDS["/ff"]        = function(args) FV:HandleSlashCommand(args) end
    SLASH_COMMANDS["/frostfall"] = function(args) FV:HandleSlashCommand(args) end

    FV_Log("Frostfall v" .. FV.VERSION .. " initialized.")
    CHAT_SYSTEM:AddMessage("|c88CCFF[Frostfall]|r Temperature system active. Type /frostfall for options.")
end

-- ============================================================
-- SLASH COMMANDS
-- ============================================================

function FV:HandleSlashCommand(args)
    local cmd = string.lower(args or "")

    -- /ff findEmote <needle>
    -- Searches PLAYER_EMOTE_MANAGER for emotes matching the needle.
    -- Prints the stable emoteId for each match — use this value in the
    -- settings dropdown.  The emoteId is patch-safe; raw emoteIndex is not.
    if cmd:sub(1, 9) == "findemote" then
        local needle = cmd:sub(11)
        if needle == "" then
            CHAT_SYSTEM:AddMessage("[Frostfall] Usage: /ff findEmote <n>  e.g. /ff findEmote shiver")
            return
        end
        needle = needle:lower()
        local found = 0
        local cats = {
            EMOTE_CATEGORY_PHYSICAL, EMOTE_CATEGORY_EMOTION, EMOTE_CATEGORY_SOCIAL,
            EMOTE_CATEGORY_CHEERS_AND_JEERS, EMOTE_CATEGORY_ENTERTAINMENT,
            EMOTE_CATEGORY_CEREMONIAL, EMOTE_CATEGORY_FOOD_AND_DRINK,
            EMOTE_CATEGORY_GIVE_DIRECTIONS, EMOTE_CATEGORY_POSES_AND_FIDGETS,
            EMOTE_CATEGORY_PROP, EMOTE_CATEGORY_COLLECTED,
        }
        for _, cat in ipairs(cats) do
            local emoteIds = PLAYER_EMOTE_MANAGER:GetEmoteListForType(cat) or {}
            for _, emoteId in ipairs(emoteIds) do
                local info = PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(emoteId)
                if info then
                    local dname = (info.displayName or ""):lower()
                    local slash = (info.slashName   or ""):lower()
                    if dname:find(needle, 1, true) or slash:find(needle, 1, true) then
                        d(string.format("[Frostfall] emoteId=%d  /%s  \"%s\"",
                            emoteId, info.slashName or "?", info.displayName or "?"))
                        found = found + 1
                    end
                end
            end
        end
        if found == 0 then
            CHAT_SYSTEM:AddMessage("[Frostfall] No emotes found matching: " .. needle)
        end
        return
    end

    if cmd == "help" or cmd == "" then
        CHAT_SYSTEM:AddMessage("|c88CCFF[Frostfall] Commands:|r")
        CHAT_SYSTEM:AddMessage("  /ff help                — Show this help")
        CHAT_SYSTEM:AddMessage("  /ff status               — Show current temperature status")
        CHAT_SYSTEM:AddMessage("  /ff config               — Open configuration menu")
        CHAT_SYSTEM:AddMessage("  /ff toggle               — Enable/disable Frostfall")
        CHAT_SYSTEM:AddMessage("  /ff findEmote <name>     — Search for emote index by name")
        CHAT_SYSTEM:AddMessage("  /ff debug enable         — Turn on debug logging")
        CHAT_SYSTEM:AddMessage("  /ff debug disable        — Turn off debug logging")
        CHAT_SYSTEM:AddMessage("  /ff debug status         — Print current status (same as /ff status)")
        CHAT_SYSTEM:AddMessage("  /ff debug update         — Force an immediate recalculation")
        CHAT_SYSTEM:AddMessage("  /ff debug reset          — Reset all settings to default")
        CHAT_SYSTEM:AddMessage("  /ff debug resetStatus    — Reset temperature to neutral, clear reagent buff")
    elseif cmd == "status" then
        local s = FV.State
        local unit = FV.SV.useFahrenheit and "°F" or "°C"
        CHAT_SYSTEM:AddMessage(string.format(
            "|c88CCFF[Frostfall]|r Zone: %s | Zone Temp: %s | " ..
            "Player Temp: %s | Insulation: %d [%s] | Interval: %d min",
            s.currentZoneName,
            FV.FormatAmbientTemp(),
            FV.FormatTemp(FV:GetEffectiveTemp()),
            s.insulation, s.insulationSource,
            FV.SV.updateIntervalMinutes
        ))
        if s.spellResistEndTime then
            local remaining = math.max(0, s.spellResistEndTime - GetGameTimeMilliseconds() / 1000)
            CHAT_SYSTEM:AddMessage(string.format(
                "|c88CCFF[Frostfall]|r Spell-resist reagent steadying effect: %+.1f°C, fades in %d:%02d",
                s.spellResistOffset, math.floor(remaining / 60), math.floor(remaining % 60)))
        end
        if s.isIndoorProtected then
            CHAT_SYSTEM:AddMessage(
                "|c88CCFF[Frostfall]|r Indoor shelter is active - your true temperature is drifting toward comfortable faster than it would outdoors.")
        end
    elseif cmd == "config" then
        if Frostfall_ConfigMenu then Frostfall_ConfigMenu:Show() end
    elseif cmd:sub(1, 5) == "debug" then
        -- Replaces the old settings-menu "Debug" section (Debug Logging
        -- checkbox, Print Current Status / Force Update Now / Reset All
        -- Settings to Default buttons) with slash-command equivalents,
        -- plus the new resetStatus subcommand.
        local sub = cmd:sub(7)
        if sub == "enable" then
            FV.SV.debugMode = true
            CHAT_SYSTEM:AddMessage("[Frostfall] Debug logging: ON")
        elseif sub == "disable" then
            FV.SV.debugMode = false
            CHAT_SYSTEM:AddMessage("[Frostfall] Debug logging: OFF")
        elseif sub == "status" then
            self:HandleSlashCommand("status")
        elseif sub == "update" then
            self:OnUpdate(0)
            CHAT_SYSTEM:AddMessage("[Frostfall] Manual update triggered.")
        elseif sub == "reset" then
            for k, v in pairs(FV.Defaults) do FV.SV[k] = v end
            -- FV.Defaults.emoteId* are hardcoded 0 ("resolved at Initialize() time");
            -- re-resolve them now instead of leaving all four emotes disabled.
            self:ResolveEmoteDefaults()
            CHAT_SYSTEM:AddMessage("[Frostfall] Settings reset to defaults.")
            if LibAddonMenu2 then LibAddonMenu2:RefreshPanel("Frostfall") end
        elseif sub == "resetstatus" then
            self:ResetStatus()
            CHAT_SYSTEM:AddMessage("[Frostfall] Temperature status reset to neutral; reagent buff cleared.")
        else
            CHAT_SYSTEM:AddMessage("[Frostfall] Usage: /ff debug <enable|disable|status|update|reset|resetStatus>")
        end
    elseif cmd == "toggle" then
        FV:SetEnabled(not FV.SV.enabled)
        CHAT_SYSTEM:AddMessage("[Frostfall] " .. (FV.SV.enabled and "Enabled" or "Disabled"))
    else
        CHAT_SYSTEM:AddMessage("[Frostfall] Unknown command. Type /fv help for options.")
    end
end

-- ============================================================
-- ADDON LOADED
-- ============================================================
EVENT_MANAGER:RegisterForEvent(FV.NAME, EVENT_ADD_ON_LOADED, function(eventCode, addonName)
    if addonName == FV.NAME then
        FV:Initialize()
        EVENT_MANAGER:UnregisterForEvent(FV.NAME, EVENT_ADD_ON_LOADED)
    end
end)
