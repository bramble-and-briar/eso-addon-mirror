-- =========================================================
-- MugShot - TargetState  (Core/TargetState.lua)
-- Holds the canonical runtime state for the current target.
-- All fields are reset atomically via ResetForTargetChange()
-- so stale async callbacks can detect they are out-of-date
-- by comparing their captured generation to state.generation.
-- =========================================================

local TargetState = {}
TargetState.__index = TargetState

-- ── Constructor ───────────────────────────────────────────
function TargetState.New()
    local self = setmetatable({}, TargetState)
    self.generation = 0
    self.exists     = false
    self.unitTag    = "reticleover"
    self.identity   = {
        name            = nil,
        displayName     = nil,
        isPlayer        = nil,
        reaction        = nil,
        portraitTexture = nil,
        raceIcon        = nil,
        allianceIcon    = nil,
        allianceColor   = nil,
    }
    self.vitals = {
        healthKnown   = false,
        currentHealth = nil,
        maxHealth     = nil,
        shield        = 0,
    }
    self.effects = {}
    return self
end

-- ── ResetForTargetChange ──────────────────────────────────
-- Call this whenever the reticle-over unit changes.
-- Increments generation so any in-flight callbacks that
-- captured an older generation know they are stale.
function TargetState:ResetForTargetChange()
    self.generation = self.generation + 1
    self.exists     = false
    self.identity   = {
        name            = nil,
        displayName     = nil,
        isPlayer        = nil,
        reaction        = nil,
        portraitTexture = nil,
        raceIcon        = nil,
        allianceIcon    = nil,
        allianceColor   = nil,
    }
    self.vitals = {
        healthKnown   = false,
        currentHealth = nil,
        maxHealth     = nil,
        shield        = 0,
    }
    self.effects = {}
    MugShot.logger:Debug("TargetState reset (generation=%d)", self.generation)
end

MugShot.TargetState = TargetState
MugShot.logger:Info("=== TargetState loaded ===")
