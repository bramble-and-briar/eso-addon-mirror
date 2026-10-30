-- ===========================================================================
-- CameraResponse.lua
-- ---------------------------------------------------------------------------
-- One global response profile for every camera transition BAV owns.
-- ===========================================================================

local addon = BureauOfAcceptableViews
local private = addon.private

addon.CameraResponse = addon.CameraResponse or {}
local CameraResponse = addon.CameraResponse

local CameraSettings = addon.CameraSettings
local Ease = addon.Ease
local EVENT_MANAGER = EVENT_MANAGER
local next = next
local pairs = pairs
local type = type
local mathabs = math.abs
local mathexp = math.exp
local mathfloor = math.floor
local mathpi = math.pi
local mathsqrt = math.sqrt

local MODE_NATIVE = "native"
local MODE_INSTANT = "instant"
local MODE_RESPONSIVE = "responsive"
local MODE_SMOOTH = "smooth"

-- BAV-owned transitions use the unit-step response of a damped second-order
-- mechanical system:
--
--     x'' + 2*zeta*omega_n*x' + omega_n^2*x = omega_n^2
--
-- Unit mass is assumed, so omega_n defines spring stiffness and zeta defines
-- damping. Both shipped profiles are non-oscillating (zeta >= 1): responsive is
-- critically damped, while smooth is slightly overdamped for a gentler arrival.
-- Duration is not chosen directly; it is solved as the time required to settle
-- within SETTLE_ERROR of the target.
--
-- The exponential solution is sampled ONCE while this file loads. Runtime Ease
-- ticks only interpolate two adjacent lookup values, avoiding exp/sqrt work on
-- the per-frame path.
local TWO_PI = 2 * mathpi
local SETTLE_ERROR = 0.01
local SETTLE_SOLVER_ITERATIONS = 28
local CURVE_SEGMENTS = 64
local MAX_SETTLE_SECONDS = 2
local CRITICAL_DAMPING_EPSILON = 0.000001

local function MechanicalStepResponse(timeSeconds, naturalFrequencyHz, dampingRatio)
    local omega = TWO_PI * naturalFrequencyHz

    -- Critical damping: x(t) = 1 - e^(-omega*t) * (1 + omega*t)
    if mathabs(dampingRatio - 1) <= CRITICAL_DAMPING_EPSILON then
        local omegaTime = omega * timeSeconds
        return 1 - mathexp(-omegaTime) * (1 + omegaTime)
    end

    -- Overdamping: the two real poles produce a monotonic, no-overshoot step.
    local root = mathsqrt(dampingRatio * dampingRatio - 1)
    local slowPole = -omega * (dampingRatio - root)
    local fastPole = -omega * (dampingRatio + root)
    return 1 + (fastPole * mathexp(slowPole * timeSeconds)
        - slowPole * mathexp(fastPole * timeSeconds)) / (slowPole - fastPole)
end

local function SolveSettlingTime(naturalFrequencyHz, dampingRatio)
    local target = 1 - SETTLE_ERROR
    local low = 0
    local high = 1 / naturalFrequencyHz

    while high < MAX_SETTLE_SECONDS
        and MechanicalStepResponse(high, naturalFrequencyHz, dampingRatio) < target do
        high = high * 2
    end
    if high > MAX_SETTLE_SECONDS then
        high = MAX_SETTLE_SECONDS
    end

    -- The zeta >= 1 response is monotonic, so binary search finds the first time
    -- it enters the 1% settling band without a frame-rate-dependent simulation.
    for _ = 1, SETTLE_SOLVER_ITERATIONS do
        local midpoint = (low + high) * 0.5
        if MechanicalStepResponse(midpoint, naturalFrequencyHz, dampingRatio) < target then
            low = midpoint
        else
            high = midpoint
        end
    end
    return high
end

local function BuildMechanicalCurve(durationSeconds, naturalFrequencyHz, dampingRatio)
    local samples = {}
    local finalPosition = MechanicalStepResponse(
        durationSeconds, naturalFrequencyHz, dampingRatio)

    for index = 0, CURVE_SEGMENTS do
        local elapsed = durationSeconds * index / CURVE_SEGMENTS
        local position = MechanicalStepResponse(elapsed, naturalFrequencyHz, dampingRatio)
        samples[index + 1] = position / finalPosition
    end
    samples[1] = 0
    samples[CURVE_SEGMENTS + 1] = 1

    return function(t)
        if t <= 0 then return 0 end
        if t >= 1 then return 1 end

        local scaled = t * CURVE_SEGMENTS
        local leftIndex = mathfloor(scaled)
        local fraction = scaled - leftIndex
        local left = samples[leftIndex + 1]
        local right = samples[leftIndex + 2]
        return left + (right - left) * fraction
    end
end

local function BuildMechanicalProfile(naturalFrequencyHz, dampingRatio)
    local durationSeconds = SolveSettlingTime(naturalFrequencyHz, dampingRatio)
    return {
        durationMs = mathfloor(durationSeconds * 1000 + 0.5),
        curve = BuildMechanicalCurve(durationSeconds, naturalFrequencyHz, dampingRatio),
        suspendEngineSmoothing = true,
    }
end

local MODE_ORDER = {
    MODE_NATIVE,
    MODE_INSTANT,
    MODE_RESPONSIVE,
    MODE_SMOOTH,
}

local PROFILES = {
    [MODE_NATIVE] = {
        durationMs = 0,
        curve = Ease.Curves.Linear,
        suspendEngineSmoothing = false,
    },
    [MODE_INSTANT] = {
        durationMs = 0,
        curve = Ease.Curves.Linear,
        suspendEngineSmoothing = true,
    },
    -- Approximately 90 ms to 1% error: fast response without overshoot.
    [MODE_RESPONSIVE] = BuildMechanicalProfile(11.75, 1.0),
    -- Approximately 300 ms to 1% error: softer overdamped cinematic response.
    [MODE_SMOOTH] = BuildMechanicalProfile(5.8, 1.35),
}

local mode = MODE_RESPONSIVE
local smoothingOwners = {}
local previousEngineSmoothing = nil
local restorePending = false
local restoreRetries = 0
local RESTORE_UPDATE_NAME = "BAV_CameraResponse_RestoreSmoothing"
local RESTORE_RETRY_DELAY_MS = 100
local RESTORE_MAX_RETRIES = 3
local RestoreEngineSmoothing
local ScheduleSmoothingRestore

local function LogWarn(...)
    if private.LogWarn then private.LogWarn(...) end
end

local function LogDebug(...)
    if private.LogDebug then private.LogDebug(...) end
end

function CameraResponse.NormalizeMode(value)
    if PROFILES[value] then
        return value
    end
    return MODE_RESPONSIVE
end

function CameraResponse.Configure(options)
    options = options or {}
    local previousMode = mode
    mode = CameraResponse.NormalizeMode(options.mode)
    if mode == MODE_NATIVE and previousMode ~= MODE_NATIVE then
        for owner in pairs(smoothingOwners) do
            smoothingOwners[owner] = nil
        end
        restoreRetries = 0
        RestoreEngineSmoothing()
    end
    LogDebug("CameraResponse.Configure: mode=%s", mode)
end

function CameraResponse.GetMode()
    return mode
end

function CameraResponse.GetModeIds()
    local copy = {}
    for index = 1, #MODE_ORDER do
        copy[index] = MODE_ORDER[index]
    end
    return copy
end

function CameraResponse.GetDurationMs()
    return PROFILES[mode].durationMs
end

function CameraResponse.GetCurve()
    return PROFILES[mode].curve
end

function CameraResponse.IsImmediate()
    return PROFILES[mode].durationMs <= 0
end

function CameraResponse.ShouldSuspendEngineSmoothing()
    return PROFILES[mode].suspendEngineSmoothing
end

local function CancelSmoothingRestore()
    if not restorePending then
        return
    end
    EVENT_MANAGER:UnregisterForUpdate(RESTORE_UPDATE_NAME)
    restorePending = false
end

RestoreEngineSmoothing = function()
    CancelSmoothingRestore()
    if next(smoothingOwners) ~= nil then
        return
    end

    local previous = previousEngineSmoothing
    if previous ~= nil and previous ~= 0
        and not CameraSettings.Set("smoothing", previous) then
        LogWarn("CameraResponse: unable to restore engine smoothing")
        if restoreRetries < RESTORE_MAX_RETRIES then
            restoreRetries = restoreRetries + 1
            ScheduleSmoothingRestore(RESTORE_RETRY_DELAY_MS)
        end
        return
    end
    previousEngineSmoothing = nil
    restoreRetries = 0
end

ScheduleSmoothingRestore = function(delayMs)
    if restorePending or previousEngineSmoothing == nil then
        return
    end
    restorePending = true
    EVENT_MANAGER:RegisterForUpdate(RESTORE_UPDATE_NAME, delayMs or 0, RestoreEngineSmoothing)
end

-- Acquire a named lease on ESO's binary camera-smoothing setting. The first
-- owner captures and disables it; the final owner restores the player's value.
function CameraResponse.AcquireSmoothing(owner, force)
    if type(owner) ~= "string" or owner == ""
        or (not force and not CameraResponse.ShouldSuspendEngineSmoothing())
        or smoothingOwners[owner] then
        return false
    end
    if not CameraSettings.IsSupported("smoothing") then
        return false
    end

    if next(smoothingOwners) == nil then
        local current, ok = CameraSettings.Get("smoothing")
        if not ok then
            return false
        end
        if current ~= 0 and not CameraSettings.Set("smoothing", 0) then
            LogWarn("CameraResponse: unable to suspend engine smoothing")
            return false
        end
        CancelSmoothingRestore()
        -- A rejected restore may outlive its retries; never snapshot the
        -- temporary disabled value over the player's original setting.
        if previousEngineSmoothing == nil then
            previousEngineSmoothing = current
        end
        restoreRetries = 0
    end

    smoothingOwners[owner] = true
    return true
end

function CameraResponse.ReleaseSmoothing(owner)
    if type(owner) ~= "string" or not smoothingOwners[owner] then
        return false
    end

    smoothingOwners[owner] = nil
    if next(smoothingOwners) ~= nil then
        return true
    end
    ScheduleSmoothingRestore()
    return true
end

function CameraResponse.ForceReleaseSmoothing()
    for owner in pairs(smoothingOwners) do
        smoothingOwners[owner] = nil
    end

    restoreRetries = 0
    ScheduleSmoothingRestore()
    return true
end

function CameraResponse.RestoreSmoothingNow()
    for owner in pairs(smoothingOwners) do
        smoothingOwners[owner] = nil
    end
    restoreRetries = 0
    RestoreEngineSmoothing()
    return true
end

CameraResponse.MODE_NATIVE = MODE_NATIVE
CameraResponse.MODE_INSTANT = MODE_INSTANT
CameraResponse.MODE_RESPONSIVE = MODE_RESPONSIVE
CameraResponse.MODE_SMOOTH = MODE_SMOOTH
