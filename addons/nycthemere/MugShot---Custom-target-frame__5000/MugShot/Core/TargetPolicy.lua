-- =========================================================
-- MugShot - TargetPolicy  (Core/TargetPolicy.lua)
-- Determines whether the custom frame should be displayed
-- for the current TargetState via the Strategy Pattern.
-- =========================================================

local MugShot = MugShot

local TargetPolicy = {}

-- ── Built-in Policy Strategies ────────────────────────────

-- 1. Base Strategy: Target must exist and be alive
local function BaseLivingTargetStrategy(state, _settings, _isInTrial)
    if not state or state.exists ~= true then
        return false
    end
    if state.vitals and state.vitals.isDead == true then
        return false
    end
    return true
end

-- 2. Trial Filter Strategy: Only display hostile enemies when inside a raid/trial
local function TrialEnemyOnlyStrategy(state, settings, isInTrial)
    if settings and settings.onlyHostileInTrials and isInTrial then
        if state.identity and state.identity.reaction ~= UNIT_REACTION_HOSTILE then
            return false
        end
    end
    return true
end

-- ── Strategy Registry (Composite) ─────────────────────────
TargetPolicy.Strategies = {
    BaseLivingTargetStrategy,
    TrialEnemyOnlyStrategy,
}

-- Registers a new display policy strategy function.
-- Strategy signature: function(state, settings, isInTrial) -> bool
function TargetPolicy.RegisterStrategy(strategyFn)
    if type(strategyFn) == "function" then
        table.insert(TargetPolicy.Strategies, strategyFn)
    end
end

-- ── ShouldDisplay ─────────────────────────────────────────
-- Executes all active strategies in short-circuit sequence.
-- @param  state      MugShot.TargetState instance
-- @param  settings   table returned by MugShot.Settings:Get()
-- @param  isInTrial  bool: whether player is currently in a raid/trial
-- @return bool       true → show the frame, false → hide it
function TargetPolicy.ShouldDisplay(state, settings, isInTrial)
    local strats = TargetPolicy.Strategies
    for i = 1, #strats do
        if not strats[i](state, settings, isInTrial) then
            return false
        end
    end
    return true
end

MugShot.TargetPolicy = TargetPolicy
MugShot.logger:Info("=== TargetPolicy loaded ===")
