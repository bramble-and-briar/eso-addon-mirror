-- =============================================================================
-- Under Pressure -- PressureEngine.lua
-- =============================================================================
-- Core model. Maintains rolling damage and effect windows, computes the
-- estimated time-to-die under "no healing, no mitigation from now" hypothesis,
-- and decides the current visual state.
--
-- HISTORY: prior versions distinguished damage by sourceType (player vs NPC
-- vs unknown) and tracked a separate damage shield pool via shieldPower. The
-- ESO console runtime does NOT expose either of those APIs at this time, so
-- those paths were removed in 0.2.6. The model now treats every damage event
-- uniformly and uses raw health for time-to-die.
-- =============================================================================

UP = UP or {}
UP.Engine = {}

-- ---------------------------------------------------------------------------
-- State enumeration
-- ---------------------------------------------------------------------------
UP.STATE = {
    GREEN_SQUARE   = "green_square",        -- safe / low current pressure
    YELLOW_EMPTY   = "yellow_empty",        -- recent damage but not lethal
    YELLOW_FILLED  = "yellow_filled",       -- moderate pressure, ttd 2-4s
    RED_ONE        = "red_one",             -- ttd 1-2s
    RED_TWO        = "red_two",             -- ttd 0.5-1s
    RED_THREE      = "red_three",           -- ttd < 0.5s
}

-- Ordered severity, defined here rather than in the UI because the engine now
-- needs it too (the persistence gate is asymmetric -- see UP.Engine.Tick).
-- UI/Indicator.lua reads this instead of keeping its own copy.
UP.STATE_SEVERITY = {
    green_square   = 0,
    yellow_empty   = 1,
    yellow_filled  = 2,
    red_one        = 3,
    red_two        = 4,
    red_three      = 5,
}

-- ---------------------------------------------------------------------------
-- Tunables (overridden by saved variables)
-- ---------------------------------------------------------------------------
UP.Defaults = {
    -- Window weight multipliers
    weight_1s        = 1.25,
    weight_2s        = 1.15,
    weight_3s        = 1.00,
    weight_6s        = 0.75,

    -- Single risk-bonus weight applied to all active debuffs. (Previously
    -- split into effect_player_weight / effect_npc_weight / effect_unknown
    -- but sourceType is not available so the split was a no-op.)
    effect_weight    = 1.00,

    -- Burst multiplier: if >50% of the 2s damage arrived in the last 0.5s,
    -- multiply pressure by this. Tunable 1.0 (off) to ~2.0.
    burst_share_threshold = 0.50,
    burst_multiplier      = 1.20,

    -- Execute threshold: at or below this health %, execute risk bonus
    -- magnifies. Default mirrors common ESO execute thresholds (25%).
    execute_health_pct    = 0.25,
    execute_amplifier     = 2.0,

    -- Floor used in division to avoid TTD blowup with no recent damage.
    pressure_floor        = 100,    -- DPS minimum when computing TTD

    -- State decision thresholds (seconds)
    red_three_ttd         = 0.5,
    red_two_ttd           = 1.0,
    red_one_ttd           = 2.0,
    yellow_filled_ttd     = 4.0,

    -- "Recent damage" window for yellow_empty / green_square decision
    recent_pressure_window_s = 10.0,

    -- Persistence interval: a new state must hold this long before being shown
    state_persistence_ms     = 200,

    -- Effect (debuff) lingering window in ms after FADED
    effect_lingering_ms      = 500,

    -- Attacker counter window
    attacker_window_s        = 3,
}

-- ---------------------------------------------------------------------------
-- Runtime state
-- ---------------------------------------------------------------------------
-- EFFECT_RESULT_FADED resolved once. Engine constants exist before addon files
-- are parsed, so this is safe at file scope; the fallback covers the constant
-- being absent entirely.
local EFFECT_FADED = (type(EFFECT_RESULT_FADED) == "number") and EFFECT_RESULT_FADED or 2

local state = {
    -- Damage buffer as PARALLEL ARRAYS rather than an array of {t, amount}
    -- tables. Damage events are the highest-frequency thing this addon
    -- handles, and a table per event meant one allocation per incoming hit
    -- plus GC pressure on a platform with a 100MB pool shared across every
    -- installed addon. Two flat arrays allocate nothing per event.
    dmgT         = {},   -- ms timestamps, ascending
    dmgA         = {},   -- amounts, parallel to dmgT
    dmgHead      = 1,    -- index of the oldest live entry
    lastDamageT  = 0,    -- ms timestamp of most recent damage event (0 = none yet)
    activeEffects = {},  -- abilityId -> {category, gainedT, endT, fadedAt}
    lastPowerUpdate = 0,
    currentHealth   = 0,
    maxHealth       = 1,
    inCombat        = false,
    -- Set by EventIngest's death/alive handlers. Gates Tick() below so the
    -- model doesn't spend the 10 Hz budget recomputing a meaningless TTD from
    -- zeroed health for however long the player stays dead.
    isDead          = false,

    candidateState  = nil,
    candidateSince  = 0,
    publishedState  = "green_square",
    publishedSince  = 0,

    lastPressureDps    = 0,
    lastTtd            = math.huge,
    lastBurstMul       = 1.0,
    lastRiskBonus      = 0,
}

UP.Engine.state = state  -- exposed for debug overlay

-- ---------------------------------------------------------------------------
-- Public ingest entry points (called from EventIngest)
-- ---------------------------------------------------------------------------
-- Both entry points take plain values rather than a normalised event table.
-- The table was a per-event allocation in the hottest path in the addon, and
-- with exactly two producers and one consumer it bought no real abstraction.
function UP.Engine.IngestDamage(t, amount)
    local n = #state.dmgT + 1
    state.dmgT[n] = t
    state.dmgA[n] = amount
    -- Timestamp of the most recent damage, kept so the "was there damage in
    -- the last N seconds" test is O(1) instead of a window sum. See decideState.
    state.lastDamageT = t
end

function UP.Engine.IngestEffect(t, abilityId, category, changeType, endTimeMs)
    if changeType == EFFECT_FADED then
        local rec = state.activeEffects[abilityId]
        if rec then rec.fadedAt = t end
        return
    end

    -- Reuse the existing record on refresh. DoTs and reapplied debuffs refresh
    -- constantly, so replacing the table each time would allocate for no
    -- reason.
    local rec = state.activeEffects[abilityId]
    if rec then
        rec.category = category
        rec.gainedT  = t
        rec.endT_ms  = endTimeMs   -- ms, converted at the ingest boundary
        rec.fadedAt  = nil
    else
        state.activeEffects[abilityId] = {
            category = category,
            gainedT  = t,
            endT_ms  = endTimeMs,
            fadedAt  = nil,
        }
    end
end

function UP.Engine.UpdatePower(powerType, value, max)
    if type(COMBAT_MECHANIC_FLAGS_HEALTH) == "number" and powerType == COMBAT_MECHANIC_FLAGS_HEALTH then
        state.currentHealth = value
        state.maxHealth     = max > 0 and max or 1
    end
    -- Damage-shield power updates are intentionally ignored: the console
    -- runtime does not expose COMBAT_MECHANIC_FLAGS_DAMAGE_SHIELD reliably.
    state.lastPowerUpdate = GetGameTimeMilliseconds()
end

function UP.Engine.SetCombatState(inCombat)
    state.inCombat = inCombat
end

function UP.Engine.SetDead(isDead)
    state.isDead = isDead == true
end

-- Clears every accumulated reading so a stale pre-death burst can never carry
-- across a resurrection. Without this, the damage buffer's 8s horizon and the
-- persistence gate's "escalation is instant" rule combine badly: a lethal
-- burst that killed the player is still sitting in the buffer, still reads as
-- high DPS against whatever health the player resurrects with, and the shape
-- was never told to change away from RED_THREE while hidden (SetState only
-- fires on an actual change, and nothing changed while dead -- see Tick()'s
-- isDead guard). Called from EventIngest's onPlayerAlive, before combat state
-- or visibility are touched, so nothing can reveal the stale reading first.
--
-- Mirrors UP.Silence.Clear(), called from the same onPlayerDead/onPlayerAlive
-- pair for the same reason: effects and readings that don't survive a death
-- shouldn't be left for the next life to inherit.
function UP.Engine.Reset()
    local dmgT, dmgA = state.dmgT, state.dmgA
    for i = 1, #dmgT do
        dmgT[i] = nil
        dmgA[i] = nil
    end
    state.dmgHead     = 1
    state.lastDamageT = 0
    state.activeEffects = {}

    state.candidateState = nil
    state.candidateSince = 0
    state.publishedState = UP.STATE.GREEN_SQUARE
    state.publishedSince = GetGameTimeMilliseconds()

    state.lastPressureDps = 0
    state.lastTtd         = math.huge
    state.lastBurstMul    = 1.0
    state.lastRiskBonus   = 0

    -- Push immediately rather than waiting for the next tick -- Tick() skips
    -- all work while isDead is true, and the caller clears that flag right
    -- after this returns, so nothing else would force the shape back to
    -- green_square before the indicator becomes visible again.
    if UP.UI and UP.UI.SetState then UP.UI.SetState(UP.STATE.GREEN_SQUARE) end
end

-- ---------------------------------------------------------------------------
-- Math helpers
-- ---------------------------------------------------------------------------
-- The damage buffer is append-only with a moving head index. state.dmgHead is
-- the index of the oldest live event; everything below it is expired but not
-- yet reclaimed. Reclaiming happens in one batch (see trimDamageBuffer) rather
-- than via table.remove(t, 1), which shifts the whole array per removal --
-- O(n) per expired event, at 10 Hz, on a platform with a 1s-per-frame budget
-- shared across every installed addon.
-- All five windows in ONE reverse pass.
--
-- computePressure needs the 0.5s, 1s, 2s, 3s and 6s totals every tick. Summing
-- each separately meant five walks over overlapping ranges of the same buffer,
-- ~2.5x the necessary work. The windows are nested, so a single walk from
-- newest to oldest can accumulate all five, breaking as soon as it passes the
-- widest cutoff.
local function damageWindows(now_ms)
    local c05 = now_ms - 500
    local c1  = now_ms - 1000
    local c2  = now_ms - 2000
    local c3  = now_ms - 3000
    local c6  = now_ms - 6000

    local d05, d1, d2, d3, d6 = 0, 0, 0, 0, 0
    local dmgT, dmgA = state.dmgT, state.dmgA

    for i = #dmgT, state.dmgHead, -1 do
        local t = dmgT[i]
        if t < c6 then break end
        local a = dmgA[i]
        d6 = d6 + a
        if t >= c3 then
            d3 = d3 + a
            if t >= c2 then
                d2 = d2 + a
                if t >= c1 then
                    d1 = d1 + a
                    if t >= c05 then d05 = d05 + a end
                end
            end
        end
    end

    return d05, d1, d2, d3, d6
end

-- Compact once the expired prefix is worth reclaiming, instead of shifting on
-- every expiry. COMPACT_THRESHOLD is a plain "enough garbage to bother"
-- heuristic, not a tuned value.
local COMPACT_THRESHOLD = 64

local function trimDamageBuffer(now_ms)
    -- Drop events older than the largest window (6s) plus a safety margin.
    local horizon = now_ms - 8000
    local dmgT, dmgA = state.dmgT, state.dmgA
    local head = state.dmgHead
    local n = #dmgT

    while head <= n and dmgT[head] < horizon do
        head = head + 1
    end

    if head - state.dmgHead >= COMPACT_THRESHOLD or head > n then
        -- Slide the live tail down to index 1 and clear the remainder.
        local write = 1
        for read = head, n do
            dmgT[write] = dmgT[read]
            dmgA[write] = dmgA[read]
            write = write + 1
        end
        for i = write, n do
            dmgT[i] = nil
            dmgA[i] = nil
        end
        head = 1
    end

    state.dmgHead = head
end

-- Live event count, for the debug overlay.
local function damageEventCount()
    return (#state.dmgT - state.dmgHead) + 1
end

-- Both clocks here are milliseconds. endT_ms is converted from the event's
-- seconds-based endTime at the ingest boundary; mixing the two is what made
-- this function expire every timed debuff instantly through 0.2.8 development.
local function expireEffects(now_ms, tunables)
    local linger = tunables.effect_lingering_ms or UP.Defaults.effect_lingering_ms
    for id, rec in pairs(state.activeEffects) do
        local expired = false
        if rec.fadedAt and (now_ms - rec.fadedAt) > linger then expired = true end
        if rec.endT_ms and rec.endT_ms > 0 and now_ms > (rec.endT_ms + linger) then expired = true end
        if expired then state.activeEffects[id] = nil end
    end
end

-- Reused across ticks instead of allocating two tables 10x/second. Both are
-- cleared on entry and consumed before aggregateRiskBonus returns, so nothing
-- outlives the call. There are at most seven risk categories, so clearing is
-- cheaper than allocating.
local scratchSeen = {}
local scratchCategories = {}

local function aggregateRiskBonus(tunables)
    -- Sum risk bonuses across all currently active debuffs. Each category
    -- contributes its highest-base instance at most once to avoid stacking
    -- the same threat from multiple casters.
    local seen, categories = scratchSeen, scratchCategories
    for k in pairs(seen) do seen[k] = nil end
    for k in pairs(categories) do categories[k] = nil end

    local w = tunables.effect_weight or UP.Defaults.effect_weight
    for _, rec in pairs(state.activeEffects) do
        local base = UP.Classifier.bonusFor(rec.category)
        local weighted = base * w
        if (not seen[rec.category]) or (weighted > seen[rec.category]) then
            seen[rec.category] = weighted
        end
        categories[rec.category] = true
    end
    local total = 0
    for _, v in pairs(seen) do total = total + v end
    return total, categories
end

-- ---------------------------------------------------------------------------
-- The core calculation
-- ---------------------------------------------------------------------------
local function computePressure(now_ms, tunables)
    local d_half, d1, d2, d3, d6 = damageWindows(now_ms)

    local dps1 = d1
    local dps2 = d2 / 2.0
    local dps3 = d3 / 3.0
    local dps6 = d6 / 6.0

    local pressureDps = math.max(
        dps1 * tunables.weight_1s,
        dps2 * tunables.weight_2s,
        dps3 * tunables.weight_3s,
        dps6 * tunables.weight_6s
    )

    -- Burst multiplier: detect spike in the last 0.5s
    local burstMul = 1.0
    if d2 > 0 and (d_half / d2) > tunables.burst_share_threshold then
        burstMul = tunables.burst_multiplier
    end

    local riskBonus, categoriesSeen = aggregateRiskBonus(tunables)

    -- Execute amplification at low health
    local healthPct = (state.maxHealth > 0) and (state.currentHealth / state.maxHealth) or 1.0
    if categoriesSeen[UP.RISK.EXECUTE] and healthPct <= tunables.execute_health_pct then
        riskBonus = riskBonus * tunables.execute_amplifier
    end

    local adjustedDps = (pressureDps * burstMul) + riskBonus
    if adjustedDps < tunables.pressure_floor then adjustedDps = tunables.pressure_floor end

    local ehp = state.currentHealth or 0
    local ttd = ehp / adjustedDps  -- seconds

    state.lastPressureDps = adjustedDps
    state.lastTtd         = ttd
    state.lastBurstMul    = burstMul
    state.lastRiskBonus   = riskBonus

    return ttd
end

local function decideState(ttd, now_ms, tunables)
    -- "Any damage in the last N seconds" is a timestamp comparison, not a sum.
    -- It used to call sumDamageSince, which had two problems: it walked the
    -- whole window every tick for a value only ever tested against zero, and
    -- it could not see past the damage buffer's 8-second trim horizon -- so
    -- the setting silently behaved as 8 for any value above it, despite the
    -- slider going to 30.
    local windowS = tunables.recent_pressure_window_s or UP.Defaults.recent_pressure_window_s
    local hadRecentDamage = (state.lastDamageT > 0)
                            and ((now_ms - state.lastDamageT) <= (windowS * 1000))
    local hasActiveDebuff = next(state.activeEffects) ~= nil

    if ttd < tunables.red_three_ttd then
        return UP.STATE.RED_THREE
    elseif ttd < tunables.red_two_ttd then
        return UP.STATE.RED_TWO
    elseif ttd < tunables.red_one_ttd then
        return UP.STATE.RED_ONE
    elseif ttd < tunables.yellow_filled_ttd then
        return UP.STATE.YELLOW_FILLED
    elseif hadRecentDamage or hasActiveDebuff then
        return UP.STATE.YELLOW_EMPTY
    else
        return UP.STATE.GREEN_SQUARE
    end
end

-- ---------------------------------------------------------------------------
-- Tick loop
-- ---------------------------------------------------------------------------
-- Merged defaults + saved overrides, built once and cached.
--
-- This used to allocate a fresh table and walk every default key on EVERY
-- tick -- 10 tables a second, forever, to produce a value that only changes
-- when the user moves a slider. The cache is invalidated from Settings.lua's
-- tun() accessor, which every tunable write already goes through.
local tunablesCache = nil

function UP.Engine.MarkTunablesDirty()
    tunablesCache = nil
end

local function getTunables()
    if tunablesCache then return tunablesCache end

    local sv = UP.sv and UP.sv.tunables
    local merged = {}
    for k, v in pairs(UP.Defaults) do
        local override = sv and sv[k]
        merged[k] = (override ~= nil) and override or v
    end
    tunablesCache = merged
    return merged
end

function UP.Engine.Tick()
    -- Nothing to compute while dead: health reads 0, so every window would
    -- just recompute TTD=0 (RED_THREE) for as long as the player stays dead,
    -- for no visible benefit -- the indicator is already hidden via SetDead
    -- in Indicator.lua. Skipping the whole tick saves that work outright
    -- rather than computing a result nobody will see. Reset() (called from
    -- onPlayerAlive) is what actually clears the stale reading before this
    -- resumes; this guard only stops it from being recomputed while dead.
    if state.isDead then return end

    -- The gameTime guard that used to sit here was removed on 2026-07-29:
    -- GetGameTimeMilliseconds is now an assumption, not a probe. See
    -- APIAUDITS.md to restore it.
    local now_ms = GetGameTimeMilliseconds()
    local tunables = getTunables()

    trimDamageBuffer(now_ms)
    expireEffects(now_ms, tunables)

    -- If health is unknown (addon just loaded), pull a snapshot.
    if state.maxHealth <= 1 then
        local h, hmax = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
        if h and hmax then
            state.currentHealth = h
            state.maxHealth = hmax > 0 and hmax or 1
        end
    end

    local ttd = computePressure(now_ms, tunables)
    local newState = decideState(ttd, now_ms, tunables)

    -- Persistence gate, ASYMMETRIC by design.
    --
    -- Escalation publishes immediately. This is an early-warning indicator;
    -- delaying "you are about to die" by state_persistence_ms to confirm it
    -- isn't noise defeats the purpose, and the gate used to apply equally in
    -- both directions.
    --
    -- De-escalation still waits for the candidate to hold for
    -- state_persistence_ms. That is where the anti-flicker value actually is:
    -- a brief gap between hits shouldn't drop the indicator a rung and
    -- immediately raise it again.
    if newState ~= state.publishedState then
        local newSev = UP.STATE_SEVERITY[newState] or 0
        local pubSev = UP.STATE_SEVERITY[state.publishedState] or 0

        if newSev > pubSev then
            state.publishedState = newState
            state.publishedSince = now_ms
            state.candidateState = newState
            state.candidateSince = now_ms
            if UP.UI and UP.UI.SetState then UP.UI.SetState(newState) end
        elseif state.candidateState ~= newState then
            state.candidateState = newState
            state.candidateSince = now_ms
        elseif (now_ms - state.candidateSince) >= tunables.state_persistence_ms then
            state.publishedState = newState
            state.publishedSince = now_ms
            if UP.UI and UP.UI.SetState then UP.UI.SetState(newState) end
        end
    else
        state.candidateState = newState
        state.candidateSince = now_ms
    end
end

-- ---------------------------------------------------------------------------
-- Start / stop
-- ---------------------------------------------------------------------------
local TICK_NAMESPACE = "UnderPressure_Tick"
local TICK_INTERVAL_MS = 100  -- 10 Hz

function UP.Engine.Start()
    EVENT_MANAGER:RegisterForUpdate(TICK_NAMESPACE, TICK_INTERVAL_MS, UP.Engine.Tick)
end

function UP.Engine.Stop()
    EVENT_MANAGER:UnregisterForUpdate(TICK_NAMESPACE)
end

function UP.Engine.Snapshot()
    -- LastCount, not Counts: the UI refresh loop has already walked the
    -- attacker map this pass, and Snapshot is only ever called from the debug
    -- overlay immediately afterwards. Calling Counts here would walk it twice.
    local attackerCount = 0
    if UP.Attackers then
        attackerCount = UP.Attackers.LastCount() or 0
    end
    return {
        ttd              = state.lastTtd,
        pressureDps      = state.lastPressureDps,
        burstMul         = state.lastBurstMul,
        riskBonus        = state.lastRiskBonus,
        publishedState   = state.publishedState,
        candidateState   = state.candidateState,
        health           = state.currentHealth,
        maxHealth        = state.maxHealth,
        activeEffects    = state.activeEffects,
        damageEventCount = damageEventCount(),
        attackerCount    = attackerCount,
        inCombat         = state.inCombat,
        isDead           = state.isDead,
    }
end
