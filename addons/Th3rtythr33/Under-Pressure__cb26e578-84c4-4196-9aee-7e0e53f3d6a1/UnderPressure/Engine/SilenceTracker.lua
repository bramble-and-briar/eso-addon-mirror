-- =============================================================================
-- Under Pressure -- SilenceTracker.lua
-- =============================================================================
-- Tracks whether the local player is currently SILENCED, and nothing else.
--
-- Silence is the crowd-control state a player can do least about: it blocks
-- ability use, which blocks the heal, the shield and the break-free that every
-- other bad situation is answered with. The pressure indicator escalates while
-- silenced (silence classifies as UP.RISK.CONTROL, worth 2500 risk DPS) but the
-- shape says "you are in danger", not "you cannot cast". Hence a separate
-- readout -- see UI/SilenceRing.lua.
--
-- READOUT ONLY, ITSELF. This module's own code never touches the pressure
-- model -- it has no reference to UP.Engine anywhere below. It does not
-- follow that silence is invisible to the risk bonus: EventIngest.lua's
-- onEffectChanged calls IsSilenceEffect() (below) to drive the ring, and, in
-- the SAME branch, separately calls UP.Engine.IngestEffect() directly with
-- UP.RISK.CONTROL (0.3.2). One detector, two independent downstream effects,
-- both living in EventIngest rather than here -- see the comment there before
-- assuming "SilenceTracker doesn't feed the engine" means "silence doesn't
-- feed the engine". This module still must never become the second one
-- itself; that is what "READOUT ONLY" protects.
--
-- TWO DETECTION SIGNALS, DELIBERATELY
-- -----------------------------------
-- Both arrive on EVENT_EFFECT_CHANGED, which EventIngest already subscribes to
-- and already filters to unitTag == "player". No new event, no new filter.
--
--   * abilityType == ABILITY_TYPE_SILENCE
--   * statusEffectType == STATUS_EFFECT_TYPE_SILENCE
--
-- Either one counts. The redundancy is the point: whether the console runtime
-- populates statusEffectType is the one capability this addon still cannot
-- confirm (see FeatureDetect), and abilityType is an independent field on the
-- same event that costs nothing to read. `abilityType` was already a named
-- parameter of onEffectChanged before this feature existed -- it was simply
-- unused. This is also now the ONLY silence detector left in the addon
-- (0.3.2): AbilityClassifier's statusEffectType map used to carry a redundant,
-- less robust, single-signal copy of the same test; it was removed once this
-- one started feeding the risk bonus too, so there is exactly one place that
-- decides "is this a silence" and everything downstream reads from it.
--
-- Both constants verified present in ESOUIDocumentation.txt at API 101050.
-- There is no direct state query -- no IsUnitSilenced(). (IsPlayerStunned()
-- exists, but stun is not silence.)
-- =============================================================================

UP = UP or {}
UP.Silence = {}

-- Resolved once at file scope. Engine constants exist before addon files are
-- parsed; the fallback covers the constant being absent entirely.
local EFFECT_FADED = (type(EFFECT_RESULT_FADED) == "number") and EFFECT_RESULT_FADED or 2

-- Grace period after a debuff's own end timestamp before the failsafe sweep
-- drops it. Covers clock jitter between the event's seconds-based clock and
-- GetGameTimeMilliseconds.
local EXPIRY_GRACE_MS = 250

-- abilityId -> endTimeMs (0 means "no timed expiry": toggles, permanent auras).
--
-- A SET, not a boolean. Two sources can silence at once, and when the first
-- fades the ring must stay up for the second. A boolean would drop it early.
local active = {}
local activeCount = 0

-- Last state pushed to the UI, so the UI is only poked on an actual change.
local publishedActive = false

-- ---------------------------------------------------------------------------
-- The predicate
-- ---------------------------------------------------------------------------
-- Shared by the live event path and the Resync() buff scan, so the two can
-- never disagree about what counts as a silence.
--
-- Resolved to locals at file scope. This predicate runs on EVERY player effect
-- event, which includes every buff the player has -- food, mundus, passives,
-- every refreshing skill aura -- not just the debuffs the risk layer cares
-- about. Resolving the constants once turns each call into two truthiness tests
-- and at most two comparisons, with no repeated global lookups or type() calls.
-- Engine constants exist before addon files are parsed and cannot change
-- without a client restart, so caching them is safe.
--
-- Storing nil when a constant is absent is load-bearing, not tidiness: it makes
-- the `if CONST and field == CONST` form short-circuit. A bare equality test
-- against a missing constant would compare nil == nil whenever the incoming
-- field was also nil, and report every effect in the game as a silence.
local SILENCE_ABILITY_TYPE =
    (type(ABILITY_TYPE_SILENCE) == "number") and ABILITY_TYPE_SILENCE or nil
local SILENCE_STATUS_TYPE =
    (type(STATUS_EFFECT_TYPE_SILENCE) == "number") and STATUS_EFFECT_TYPE_SILENCE or nil

-- Note this uses STATUS_EFFECT_TYPE_SILENCE directly rather than gating on
-- UP.features.statusEffectType. That flag probes for MAGIC / STUN / SNARE, so
-- it is not evidence about SILENCE specifically, and gating on it could suppress
-- a signal that actually works.
local function isSilence(abilityType, statusEffectType)
    if SILENCE_ABILITY_TYPE and abilityType == SILENCE_ABILITY_TYPE then
        return true
    end
    if SILENCE_STATUS_TYPE and statusEffectType == SILENCE_STATUS_TYPE then
        return true
    end
    return false
end

UP.Silence.IsSilenceEffect = isSilence

-- ---------------------------------------------------------------------------
-- Publish to the UI on transition only
-- ---------------------------------------------------------------------------
local function publish()
    local nowActive = activeCount > 0
    if nowActive == publishedActive then return end
    publishedActive = nowActive
    if UP.SilenceRing and UP.SilenceRing.SetActive then
        UP.SilenceRing.SetActive(nowActive)
    end
end

-- ---------------------------------------------------------------------------
-- Live ingest
-- ---------------------------------------------------------------------------
-- Called from EventIngest for any player effect that satisfies isSilence().
--
-- endTimeMs is MILLISECONDS, converted by the caller at the event boundary.
-- EVENT_EFFECT_CHANGED reports endTime in seconds; mixing the two is what
-- silently disabled the entire risk layer for several releases. 0 means no
-- timed expiry and must be preserved as 0, not turned into a real timestamp.
function UP.Silence.Record(abilityId, changeType, endTimeMs)
    -- Unidentified silences collapse onto one key rather than being dropped.
    local key = (type(abilityId) == "number") and abilityId or 0

    if changeType == EFFECT_FADED then
        UP.Silence.Fade(key)
        return
    end

    if active[key] == nil then activeCount = activeCount + 1 end
    active[key] = endTimeMs or 0
    publish()
end

function UP.Silence.Fade(abilityId)
    local key = (type(abilityId) == "number") and abilityId or 0
    if active[key] ~= nil then
        active[key] = nil
        activeCount = activeCount - 1
        if activeCount < 0 then activeCount = 0 end
        publish()
    end
end

function UP.Silence.IsActive()
    return activeCount > 0
end

function UP.Silence.Count()
    return activeCount
end

function UP.Silence.Clear()
    if activeCount == 0 and next(active) == nil then
        publish()
        return
    end
    for k in pairs(active) do active[k] = nil end
    activeCount = 0
    publish()
end

-- ---------------------------------------------------------------------------
-- Failsafe expiry
-- ---------------------------------------------------------------------------
-- The normal path is a FADED event. This exists only for the case where that
-- event never arrives -- a stuck ring is the worst outcome for this feature,
-- since it would tell the player they cannot cast when they can.
--
-- Driven from the 5 Hz UI refresh loop rather than the 10 Hz engine tick: it is
-- a backstop, not the mechanism, so 200ms of worst-case overstay is irrelevant.
-- Entries with endTimeMs == 0 have no timed expiry and are only ever removed by
-- FADED, Clear(), or a Resync().
function UP.Silence.Expire(nowMs)
    if activeCount == 0 then return end
    for id, endTimeMs in pairs(active) do
        if endTimeMs > 0 and nowMs > (endTimeMs + EXPIRY_GRACE_MS) then
            active[id] = nil
            activeCount = activeCount - 1
        end
    end
    if activeCount < 0 then activeCount = 0 end
    publish()
end

-- ---------------------------------------------------------------------------
-- Resync from current player buffs
-- ---------------------------------------------------------------------------
-- EVENT_EFFECT_CHANGED does not replay for effects that are ALREADY active, so
-- a /reloadui mid-silence would otherwise leave the ring off for the rest of the
-- duration -- the same failure shape as the combat-state seeding bug fixed in
-- 0.2.8. Called at startup and on EVENT_EFFECTS_FULL_UPDATE.
--
-- GetUnitBuffInfo returns abilityType and statusEffectType (returns 9 and 10),
-- so the live predicate applies unchanged. timeEnding is SECONDS, like the
-- event's endTime -- converted the same way, at this boundary.
function UP.Silence.Resync()
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return
    end

    local okCount, numBuffs = pcall(GetNumBuffs, "player")
    if not okCount or type(numBuffs) ~= "number" then return end

    -- Rebuild rather than merge: this is a full-state read, so anything absent
    -- from it is genuinely gone.
    for k in pairs(active) do active[k] = nil end
    activeCount = 0

    for i = 1, numBuffs do
        local ok, _, _, timeEnding, _, _, _, _, _, abilityType, statusEffectType, abilityId =
            pcall(GetUnitBuffInfo, "player", i)
        if ok and isSilence(abilityType, statusEffectType) then
            local key = (type(abilityId) == "number") and abilityId or 0
            local endTimeMs = 0
            if type(timeEnding) == "number" and timeEnding > 0 then
                endTimeMs = timeEnding * 1000
            end
            if active[key] == nil then activeCount = activeCount + 1 end
            active[key] = endTimeMs
        end
    end

    publish()
end
