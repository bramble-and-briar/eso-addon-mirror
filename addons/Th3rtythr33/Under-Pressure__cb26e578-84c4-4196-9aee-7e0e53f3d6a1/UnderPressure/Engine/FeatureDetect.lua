-- =============================================================================
-- Under Pressure -- FeatureDetect.lua
-- =============================================================================
-- Runtime detection of API capabilities that could not be verified on console
-- without hardware. Each probe is non-destructive.
--
-- TWO SEPARATE JOBS, DELIBERATELY SPLIT
-- -------------------------------------
-- 1. DETECTION -- UP.RunFeatureDetect(), at startup, exactly once. This is
--    NOT diagnostics: both surviving flags are consumed as configuration.
--
--      * combatFilter     -- decides whether EventIngest registers a
--                            server-side target filter. Without it the
--                            subscription is UNFILTERED, so every combat
--                            event in the zone crosses into Lua and gets
--                            discarded in the callback instead.
--      * statusEffectType -- decides whether the classifier can categorise
--                            debuffs by type or must fall back to the static
--                            ability-ID table.
--
--    Both fail silently if unset, and console does not surface Lua errors.
--    So do not move this off startup or make it lazy: it must run before
--    UP.Ingest.Register(), which reads combatFilter to decide how to
--    register, and before the first debuff is classified.
--
--    Six further probes were retired on 2026-07-29 -- four abandoned, two
--    hardcoded into ASSUMED below. All are archived with their consuming
--    guards in APIAUDITS.md at the workspace root.
--
-- 2. REPORTING -- UP.RunApiAudit(), on demand from the "Print API audit"
--    button under Settings > Debug (the /up-api-audit slash command through
--    0.3.3), printed to chat. Nothing depends on it. This used to be a block in
--    the debug overlay plus a startup dump into the debug log buffer; both are
--    gone.
--
--    It reports the STARTUP SNAPSHOT, so what you read is what the addon is
--    actually running on. It does not re-probe -- see the comment above
--    UP.RunApiAudit for why that was tried and dropped. The single exception
--    is when detection never ran at all, where there is no snapshot to report.
-- =============================================================================

UP = UP or {}
UP.features = {}

-- ---------------------------------------------------------------------------
-- Startup diary
-- ---------------------------------------------------------------------------
-- The addon prints NOTHING to chat unless the user asks for it. Anything that
-- would previously have been a d() during load -- the version banner, the
-- saved-vars migration notice, and the three failure messages -- is recorded
-- here instead and printed by the API audit (Settings > Debug > Print).
--
-- Diagnosability is the point: on console Lua errors are invisible, so a
-- failed load that also says nothing anywhere is undebuggable. This keeps the
-- information without putting it in the player's face.
--
-- Lives in this file only because it is first in the manifest load order, so
-- every other module can call UP.Note() at any point during startup.
UP.startupNotes = {}

function UP.Note(msg)
    UP.startupNotes[#UP.startupNotes + 1] = tostring(msg)
end

-- ---------------------------------------------------------------------------
-- Capabilities we no longer probe
-- ---------------------------------------------------------------------------
-- These are settled: field use of the shipped addon proves them true, and
-- they are properties of the client build, so they cannot vary between
-- sessions. Probing them every load was re-asking an answered question.
--
--   gameTime         -- if false, PressureEngine.Tick returns immediately and
--                       the addon does nothing at all. It works, so: true.
--   combatStateEvent -- 0.2.6's hide-when-out-of-combat depends on
--                       EVENT_PLAYER_COMBAT_STATE being registered, and that
--                       behaviour works. So: true.
--
-- They still appear in the API audit, labelled (assumed), so the readout
-- never implies a measurement that did not happen. The probes and the guards
-- they gated are preserved in APIAUDITS.md at the workspace root -- restore
-- from there if ZOS ever changes this.
local ASSUMED = {
    gameTime         = true,
    combatStateEvent = true,
}

-- ---------------------------------------------------------------------------
-- 1. Combat event filter availability
-- ---------------------------------------------------------------------------
-- Still genuinely unknown. The addon works either way -- with server-side
-- filters, or registering unfiltered and filtering inside the callback -- so
-- "it works in the field" is no evidence at all about this one.
local function probeCombatFilter()
    local hasConstant = (type(REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE) == "number")
                    and (type(COMBAT_UNIT_TYPE_PLAYER) == "number")
    local hasMethod = (EVENT_MANAGER and type(EVENT_MANAGER.AddFilterForEvent) == "function")
    return hasConstant and hasMethod
end

-- ---------------------------------------------------------------------------
-- 2. Status-effect-type field on EVENT_EFFECT_CHANGED
-- ---------------------------------------------------------------------------
-- Still genuinely unknown. It only selects a classification strategy, and the
-- whole risk layer was inert from the seconds/milliseconds bug until 0.2.8,
-- so no field evidence exists either way.
local function probeStatusEffectType()
    return type(STATUS_EFFECT_TYPE_MAGIC) == "number"
        or type(STATUS_EFFECT_TYPE_STUN) == "number"
        or type(STATUS_EFFECT_TYPE_SNARE) == "number"
end

-- ---------------------------------------------------------------------------
-- Probe table -- drives both detection and the audit report
-- ---------------------------------------------------------------------------
-- "impact" is what a FALSE result costs, which is the only useful thing to
-- read in a report like this. Four further probes (shieldPower,
-- attributeVisual, groupTags, sourceType) were retired on 2026-07-29 -- they
-- existed to scope features that were then abandoned or never built. See
-- APIAUDITS.md for the code and the reasoning.
local PROBES = {
    { key = "combatFilter",     fn = probeCombatFilter,
      impact = "no server-side filtering; all combat events reach Lua" },
    { key = "statusEffectType", fn = probeStatusEffectType,
      impact = "classifier falls back to the static ability-ID table" },
}

local function runProbes()
    local results = {}
    for key, value in pairs(ASSUMED) do results[key] = value end
    for _, p in ipairs(PROBES) do
        local ok, value = pcall(p.fn)
        results[p.key] = ok and (value and true or false) or false
    end
    return results
end

-- ---------------------------------------------------------------------------
-- DETECTION (startup)
-- ---------------------------------------------------------------------------
-- No longer returns a pass/fail gate. The only fatal capability was gameTime,
-- which is now an assumption rather than a probe, so there is nothing left
-- that can refuse to start. The caller in UnderPressure.lua calls this
-- plainly. See APIAUDITS.md to restore the fatal path.
function UP.RunFeatureDetect()
    UP.features = runProbes()
end

-- ---------------------------------------------------------------------------
-- REPORTING (Settings > Debug > Print API audit)
-- ---------------------------------------------------------------------------
-- Reports the flags the addon is ACTUALLY RUNNING ON -- the startup snapshot,
-- not a fresh probe.
--
-- An earlier draft re-probed live, justified as catching a game patch that
-- changed availability mid-session. That cannot happen: patching ESO requires
-- the client to restart, so the snapshot cannot go stale that way. Nor is any
-- probe state-dependent -- they are constant/function existence checks.
--
-- Re-probing was also strictly worse: it could display values differing from
-- the ones event registration was built on, and it needed drift-detection
-- machinery to manage a discrepancy it introduced itself. Reading the snapshot
-- has neither problem.
--
-- Assumed values are labelled as such. An audit that presented an assumption
-- as a measurement would be worse than useless -- it is exactly the readout
-- someone would consult to find out why something stopped working.
local function report(flags, label)
    d("|cFFD700[Under Pressure] API audit|r")
    d(("addon v%s  |  API %s%s"):format(
        tostring(UP.version or "?"),
        tostring((type(GetAPIVersion) == "function") and GetAPIVersion() or "?"),
        label or ""))

    for _, p in ipairs(PROBES) do
        local ok = flags[p.key]
        d(("  %s  %-16s %s"):format(
            ok and "|c00FF00YES|r" or "|cFF4040NO |r",
            p.key,
            ok and "" or ("-- " .. p.impact)))
    end
    for key in pairs(ASSUMED) do
        d(("  %s  %-16s |cAAAAAA(assumed, not probed -- see APIAUDITS.md)|r"):format(
            flags[key] and "|c00FF00YES|r" or "|cFF4040NO |r", key))
    end
end

function UP.RunApiAudit()
    -- next() == nil means RunFeatureDetect never ran, i.e. startup aborted
    -- before reaching it. Reporting an empty table would show every capability
    -- as missing, which is a lie. Probe fresh and say so -- this is the one
    -- case where probing on demand is the right answer, because there is no
    -- snapshot to report and diagnosing the failed startup is the whole point.
    if next(UP.features) == nil then
        d("|cFFA500[Under Pressure] Feature detection never ran -- startup did")
        d("|cFFA500not complete. Probing now for diagnosis only; these values are")
        d("|cFFA500NOT in use by the addon.|r")
        report(runProbes(), "  (live probe)")
        return
    end

    report(UP.features, "  (in use since load)")

    -- Anything the addon wanted to say during load. Empty on a clean start.
    if #UP.startupNotes > 0 then
        d("  --- startup notes ---")
        for _, note in ipairs(UP.startupNotes) do
            d("  " .. note)
        end
    end

    -- Silence detection (0.3.0). REPORTING ONLY -- deliberately not a probe in
    -- the PROBES table and not a gate on anything, because the two signals are
    -- redundant: either constant alone is enough for the feature to work, so
    -- there is no single false result that should change behaviour.
    --
    -- It earns a line here because "does the console runtime populate these?"
    -- is a genuinely open question, which is the bar APIAUDITS.md sets. Both
    -- constants are documented at API 101050; whether they arrive with real
    -- values on console is what the debug overlay's aT=/sT= columns answer.
    local hasAbilityType  = type(ABILITY_TYPE_SILENCE) == "number"
    local hasStatusType   = type(STATUS_EFFECT_TYPE_SILENCE) == "number"
    d(("  %s  %-16s %s"):format(
        hasAbilityType and "|c00FF00YES|r" or "|cFF4040NO |r",
        "ABILITY_TYPE_SILENCE",
        hasAbilityType and "" or "-- silence signal 1 unavailable"))
    d(("  %s  %-16s %s"):format(
        hasStatusType and "|c00FF00YES|r" or "|cFF4040NO |r",
        "STATUS_EFFECT_TYPE_SILENCE",
        hasStatusType and "" or "-- silence signal 2 unavailable"))
    if not (hasAbilityType or hasStatusType) then
        d("  |cFF4040Silence ring cannot work: neither constant exists|r")
    end

    -- Plaguebreak (0.4.0). The tracker hard-codes two ability ids (159612 the
    -- plague, 159623 the explosion) with a name fallback. REPORTING ONLY, like
    -- the silence lines: a failure here does not change behaviour, it means the
    -- fallback is carrying the feature, which is worth knowing on hardware.
    if UP.Plague and UP.Plague.VerifyIds then
        local ok, detail = UP.Plague.VerifyIds()
        d(("  %s  %-16s %s"):format(
            ok and "|c00FF00YES|r" or (ok == false and "|cFF4040NO |r" or "|cAAAAAA?? |r"),
            "plaguebreakIds",
            ok and tostring(detail) or ("-- " .. tostring(detail) .. "; relying on name matching")))
    end

    -- A Tank-mode block used to follow, reporting whether the group-filtered
    -- second registration was active -- it depended on combatFilter AND
    -- COMBAT_UNIT_TYPE_OTHER_PLAYER at once, which the per-flag list above did
    -- not make obvious. Tank mode was removed in 0.2.9, so the only remaining
    -- consumer of COMBAT_UNIT_TYPE_OTHER_PLAYER is gone with it.
end

-- No slash command (0.4.0). Through 0.3.3 /up-api-audit was registered HERE,
-- at file scope, so the audit still worked when startup bailed before
-- onAddOnLoaded finished -- exactly when it is most useful. Moving it onto an
-- LHAS button gives that up: the button only exists if UP.Settings.Init ran.
-- Accepted knowingly, because on console the command meant typing through the
-- on-screen keyboard and the author wanted every slash command gone. The
-- "never ran" branch in UP.RunApiAudit above is kept so the function stays
-- correct if a future diagnostic path calls it from a failed startup.
