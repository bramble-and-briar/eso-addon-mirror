-- =============================================================================
-- Under Pressure -- AbilityClassifier.lua
-- =============================================================================
-- PROVENANCE (2026-10-06): the 0.3.3 copy of this file was lost to OneDrive
-- NUL-byte damage. This is the 0.3.0 copy from UnderPressure-Archive/ with the
-- two later edits re-applied from Docs/UnderPressure.md: the SILENCE entry
-- removed from the status-effect map (0.3.2) and the stale "extend it via the
-- LibAddonMenu settings panel" claim removed from this header (0.3.3). The
-- lost file was ~1 KB longer, so some 0.3.2/0.3.3 comment text is paraphrased
-- rather than verbatim; the code is believed identical.
--
-- Maps incoming hostile effects to risk categories. Two-tier strategy:
--
-- 1. If the live EVENT_EFFECT_CHANGED callback delivers a usable
--    statusEffectType value (see FeatureDetect.statusEffectType), the
--    classifier prefers the type-based mapping below. This automatically
--    covers new abilities introduced by content updates.
--
-- 2. Otherwise the classifier falls back to a static abilityId table. The
--    starter table covers common Cyrodiil / Battlegrounds threats as of
--    Update 48-49 plus a few historically iconic anti-heal and execute IDs.
--    The table is intentionally NOT exhaustive. Saved-variable overrides
--    (abilityOverrides / riskBonusOverrides, read in init below) can extend
--    it, but no settings panel has ever exposed them under either library and
--    console users cannot edit saved-variable files -- so in practice entries
--    are added here, in code, after observing real combat events through the
--    debug overlay.
--
-- IMPORTANT
-- ---------
-- Every numeric ability ID in this file should be treated as best-effort.
-- ESO patches frequently renumber or replace ability IDs. The debug overlay
-- prints the incoming abilityId so the user can verify and correct entries.
-- =============================================================================

UP = UP or {}
UP.Classifier = {}

-- ---------------------------------------------------------------------------
-- Risk category constants
-- ---------------------------------------------------------------------------
UP.RISK = {
    NONE           = "none",
    CONTROL        = "control",        -- stun, root, fear, disorient (silence
                                       -- too, but injected by EventIngest, not
                                       -- classified here -- see the map below)
    ANTIHEAL       = "antiheal",       -- major/minor defile, healing reduction
    VULNERABILITY  = "vulnerability",  -- major vulnerability, off-balance, breach
    EXECUTE        = "execute",        -- execute-style damage amplifiers
    DOT            = "dot",            -- heavy bleeds / poisons (sustained DPS)
    BURST_SETUP    = "burst_setup",    -- visible burst windups (e.g. crystal frags incoming)
}

-- ---------------------------------------------------------------------------
-- Risk bonus magnitudes (additive DPS injected into the threat estimate)
-- ---------------------------------------------------------------------------
-- Not adjustable from the settings panel: the effect_weight slider that scaled
-- all of these went in 0.2.9, and per-category overrides only exist as the
-- riskBonusOverrides saved variable. Treat these as untuned starting points --
-- they were authored against a model that silently discarded them until the
-- 0.2.8 seconds/milliseconds fix made them live (see Docs/UnderPressure.md).
UP.DefaultRiskBonus = {
    [UP.RISK.CONTROL]       = 2500,   -- you cannot react -> high implicit risk
    [UP.RISK.ANTIHEAL]      = 1500,
    [UP.RISK.VULNERABILITY] = 2000,
    [UP.RISK.EXECUTE]       = 3000,   -- multiplied further at low health
    [UP.RISK.DOT]           = 500,    -- sustained, not bursty
    [UP.RISK.BURST_SETUP]   = 1500,
}

-- ---------------------------------------------------------------------------
-- StatusEffectType -> risk category mapping
-- ---------------------------------------------------------------------------
-- The constants below may be nil on console; we guard each lookup. The
-- engine consults this table only when FeatureDetect.statusEffectType=true.
local function buildStatusEffectMap()
    local m = {}
    if type(STATUS_EFFECT_TYPE_STUN)        == "number" then m[STATUS_EFFECT_TYPE_STUN]        = UP.RISK.CONTROL end
    if type(STATUS_EFFECT_TYPE_DISORIENT)   == "number" then m[STATUS_EFFECT_TYPE_DISORIENT]   = UP.RISK.CONTROL end
    if type(STATUS_EFFECT_TYPE_FEAR)        == "number" then m[STATUS_EFFECT_TYPE_FEAR]        = UP.RISK.CONTROL end
    -- No SILENCE entry (0.3.2). Silence reaches the engine as CONTROL directly
    -- from EventIngest.onEffectChanged, off SilenceTracker's dual-signal test
    -- (abilityType OR statusEffectType), which is strictly more robust than a
    -- statusEffectType-only row here would be. Re-adding it would create a
    -- second, weaker detector for the same fact. See Docs/UnderPressure.md,
    -- "Unified silence detection".
    if type(STATUS_EFFECT_TYPE_SNARE)       == "number" then m[STATUS_EFFECT_TYPE_SNARE]       = UP.RISK.CONTROL end
    if type(STATUS_EFFECT_TYPE_ROOT)        == "number" then m[STATUS_EFFECT_TYPE_ROOT]        = UP.RISK.CONTROL end
    if type(STATUS_EFFECT_TYPE_BLEED)       == "number" then m[STATUS_EFFECT_TYPE_BLEED]       = UP.RISK.DOT end
    if type(STATUS_EFFECT_TYPE_POISON)      == "number" then m[STATUS_EFFECT_TYPE_POISON]      = UP.RISK.DOT end
    if type(STATUS_EFFECT_TYPE_DISEASE)     == "number" then m[STATUS_EFFECT_TYPE_DISEASE]     = UP.RISK.DOT end
    if type(STATUS_EFFECT_TYPE_MAGIC)       == "number" then m[STATUS_EFFECT_TYPE_MAGIC]       = UP.RISK.VULNERABILITY end
    return m
end

UP.Classifier.statusEffectMap = nil  -- built lazily after FeatureDetect runs

-- ---------------------------------------------------------------------------
-- AbilityId -> risk category starter table
-- ---------------------------------------------------------------------------
-- Sources for the IDs below:
--   * 217621 (Lingering Torment DoT) confirmed visible to console add-ons:
--     https://forums.elderscrollsonline.com/en/discussion/679516/console-fancy-action-bar-issues-thread
--   * The remaining IDs are well-known PvP IDs from PC add-on community
--     tables (Code's Combat Alerts, Miat's PvP Alerts, etc.) and may have
--     shifted across patches. Verify with the debug overlay.
--
-- The "name hint" column is a comment so a user editing the saved-vars file
-- can recognize what they're tuning.

UP.Classifier.abilityIdMap = {
    -- Major Defile family (anti-heal)
    [68595]  = UP.RISK.ANTIHEAL,   -- Major Defile (generic)
    [88401]  = UP.RISK.ANTIHEAL,   -- Black Widow / Stinging Slashes Defile (verify)
    [38254]  = UP.RISK.ANTIHEAL,   -- Minor Defile (generic; verify ID)

    -- Major Vulnerability family
    [106754] = UP.RISK.VULNERABILITY, -- Major Vulnerability (Oakensoul/PvP procs; verify)

    -- Off-Balance / Breach
    [134599] = UP.RISK.VULNERABILITY, -- Off-Balance (verify)
    [122729] = UP.RISK.VULNERABILITY, -- Major Breach (verify)

    -- Hard CC family
    [38260]  = UP.RISK.CONTROL,    -- Stun (generic; verify)
    [22418]  = UP.RISK.CONTROL,    -- Knockback / Disorient
    [97743]  = UP.RISK.CONTROL,    -- Time Stop / immobilize

    -- DoT pressure
    [217621] = UP.RISK.DOT,        -- Lingering Torment (verified visible on console)
    [122658] = UP.RISK.DOT,        -- Bleeds (generic; verify)
    [159612] = UP.RISK.DOT,        -- Plague Carrier: the Plaguebreak set's plague
                                   -- (id from UESP skill data 2026-10-06; also
                                   -- tracked by Engine/PlagueTracker.lua)

    -- Execute setups
    [61905]  = UP.RISK.EXECUTE,    -- Reverse Slice / generic execute (verify)
}

-- Allow the saved-variables and settings panel to extend or override this
-- table. Engine consults UP.Classifier.effective() which merges defaults
-- with user overrides.

function UP.Classifier.init(savedVars)
    UP.Classifier.statusEffectMap = buildStatusEffectMap()
    UP.Classifier.savedVars = savedVars  -- table with optional .abilityOverrides and .riskBonusOverrides
end

function UP.Classifier.classifyById(abilityId)
    if not abilityId then return UP.RISK.NONE end
    local overrides = UP.Classifier.savedVars and UP.Classifier.savedVars.abilityOverrides
    if overrides and overrides[abilityId] then return overrides[abilityId] end
    return UP.Classifier.abilityIdMap[abilityId] or UP.RISK.NONE
end

function UP.Classifier.classifyByStatusType(statusType)
    if not statusType or not UP.Classifier.statusEffectMap then return UP.RISK.NONE end
    return UP.Classifier.statusEffectMap[statusType] or UP.RISK.NONE
end

-- Preferred entry point. Uses statusEffectType when available, falls back to
-- ability ID, then returns NONE.
-- Takes plain values rather than an effect table: the caller was allocating
-- one per effect event purely to pass two numbers.
function UP.Classifier.classify(abilityId, statusEffectType)
    if UP.features and UP.features.statusEffectType and statusEffectType then
        local cat = UP.Classifier.classifyByStatusType(statusEffectType)
        if cat ~= UP.RISK.NONE then return cat end
    end
    return UP.Classifier.classifyById(abilityId)
end

function UP.Classifier.bonusFor(category)
    local overrides = UP.Classifier.savedVars and UP.Classifier.savedVars.riskBonusOverrides
    if overrides and overrides[category] ~= nil then return overrides[category] end
    return UP.DefaultRiskBonus[category] or 0
end
