-- ===========================================================================
-- DynamicFov.lua
-- ---------------------------------------------------------------------------
-- Optional zoom-dependent field of view.
--
-- When enabled, the third-person FOV is driven by the current camera zoom
-- distance: zoomed all the way in uses one FOV, zoomed all the way out uses
-- another, and everything in between is linearly interpolated. This keeps the
-- framing feeling consistent as the player zooms, without them having to touch
-- the FOV slider.
--
-- Design notes:
--   * All engine I/O goes through the shared CameraSettings layer; this module
--     never touches GetSetting/SetSetting directly.
--   * The feature is OFF by default and does nothing until Configure() is
--     called with enabled = true (Settings.lua owns the SavedVars and wires
--     that up). When disabled, Apply() is a no-op, so the player's manual FOV
--     is left exactly as the game left it.
--   * Nothing here is on a per-frame path: Apply() is called only when the
--     zoom distance actually changes, so a linear interpolation is plenty.
-- ===========================================================================

local addon = BureauOfAcceptableViews
local private = addon.private

addon.DynamicFov = addon.DynamicFov or {}
local DynamicFov = addon.DynamicFov

-- Hot-path globals bound to locals once at load (mirrors the core file style).
local tonumber = tonumber
local mathabs  = math.abs
local EVENT_MANAGER = EVENT_MANAGER

-- The optional smoothing glide runs through the shared Ease primitive (Ease.lua)
-- instead of a hand-rolled updater: a temporary per-frame updater that eases FOV
-- toward its target and tears itself down the moment it lands, so there is no
-- standing per-frame cost when FOV is not moving. This module supplies only the
-- payload (which FOV to write each step); Ease owns the register/progress/land/
-- self-tear lifecycle. Keep zoom-driven FOV animation separate from the global
-- camera-smoothing setting so it leaves native camera input unchanged. The
-- response profile still supplies the FOV glide duration and curve.
-- Resolved eagerly here because Ease loads before this file in the manifest
-- (same as CameraSettings below).
local Ease = addon.Ease
local CameraResponse = addon.CameraResponse
local ANIM_UPDATE_NAME = "BAV_DynamicFovSmoothing"
local OBSERVER_UPDATE_NAME = "BAV_DynamicFovObserver"
local OBSERVER_INTERVAL_MS = 100

-- Total time (ms) for a smoothed FOV transition. Short enough to feel immediate,
-- long enough to read as a glide rather than a snap. Each zoom step restarts the
-- animation from the live FOV, so overlapping steps chain smoothly.
local ANIM_DURATION_MS = 150

-- Logging helpers are generated in the core file and exported on private.
-- Resolve them lazily so load order between files cannot break us.
local function LogWarn(...)
    if private.LogWarn then private.LogWarn(...) end
end

local function LogDebug(...)
    if private.LogDebug then private.LogDebug(...) end
end

-- ---------------------------------------------------------------------------
-- Configuration / state
-- ---------------------------------------------------------------------------
-- Runtime configuration, mirrored from SavedVariables by Configure(). Defaults
-- are intentionally inert: enabled = false means the module changes nothing.
-- nearFov applies at the closest (zoomMin) distance, farFov at the farthest
-- (zoomMax) distance. The zoom bounds are resolved from the CameraSettings
-- "distance" range so we never duplicate the engine's clamp limits here.
local config = {
    enabled = false,
    ready   = false,
    nearFov = nil,   -- resolved to the FOV range min on first Configure()
    farFov  = nil,   -- resolved to the FOV range max on first Configure()
    smooth  = false, -- when true, FOV glides to its target instead of snapping
}

-- The last FOV we wrote, so we can skip redundant CameraSettings.Set calls when
-- the interpolated value has not meaningfully changed since the last apply.
local lastAppliedFov = nil
local baseFov = nil
local lastObservedZoom = nil

-- Two writes closer than this are treated as identical (matches the FOV
-- setting's two-decimal precision with a little slack).
local FOV_EPSILON = 0.05
local ZOOM_EPSILON = 0.005

-- ---------------------------------------------------------------------------
-- Range resolution
-- ---------------------------------------------------------------------------
-- We drive the third-person FOV, so both the FOV clamp range and the zoom
-- distance range come straight from CameraSettings (the single source of truth
-- for engine limits). Resolved lazily and cached, because the CAMERA_SETTING_*
-- constants are only meaningful once the client has loaded.
local CameraSettings = addon.CameraSettings

local FOV_KEY  = "thirdPersonFov"
local ZOOM_KEY = "distance"

local function PersistBaseFov(value)
    local settings = addon.Settings
    if settings and settings.SetDynamicFovBaseSnapshot then
        settings.SetDynamicFovBaseSnapshot(value)
    end
end

local function LoadPersistedBaseFov()
    local settings = addon.Settings
    if settings and settings.GetDynamicFovBaseSnapshot then
        return settings.GetDynamicFovBaseSnapshot()
    end
    return nil
end

local function EnsureBaseFov()
    if baseFov ~= nil then
        return true
    end

    baseFov = LoadPersistedBaseFov()
    if baseFov ~= nil then
        return true
    end

    local current, ok = CameraSettings.Get(FOV_KEY)
    if not ok or current == nil then
        LogWarn("DynamicFov: unable to capture the player's base FOV")
        return false
    end

    baseFov = current
    PersistBaseFov(baseFov)
    LogDebug("DynamicFov: captured base FOV=%.2f", baseFov)
    return true
end

local function RestoreBaseFov()
    baseFov = baseFov or LoadPersistedBaseFov()
    if baseFov == nil then
        return true
    end

    local arbiter = addon.FovArbiter
    if arbiter and arbiter.IsHeld and arbiter.IsHeld() then
        return false
    end

    if not CameraSettings.Set(FOV_KEY, baseFov) then
        LogWarn("DynamicFov: base FOV restore failed; retaining recovery snapshot")
        return false
    end

    LogDebug("DynamicFov: restored base FOV=%.2f", baseFov)
    baseFov = nil
    PersistBaseFov(nil)
    return true
end

-- Returns (min, max) FOV for the third-person camera, or nil when the property
-- is unavailable on this client build.
local function GetFovRange()
    return CameraSettings.GetRange(FOV_KEY)
end

-- Returns (min, max) camera zoom distance, or nil when unavailable.
local function GetZoomRange()
    return CameraSettings.GetRange(ZOOM_KEY)
end

-- ---------------------------------------------------------------------------
-- Interpolation
-- ---------------------------------------------------------------------------

-- Clamp helper local to this module (kept tiny rather than reaching into the
-- core file, so DynamicFov has no hard dependency on private.ClampNumber).
local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

-- Map a zoom distance to the FOV it should produce.
-- nearFov applies at zoomMin (closest), farFov at zoomMax (farthest); points in
-- between are linearly interpolated. The zoom is clamped to its range first, so
-- out-of-range inputs saturate at the endpoints instead of extrapolating.
-- Returns nil when either range is unavailable or the zoom span is degenerate.
local function InterpolateFov(zoom, zoomMin, zoomMax, nearFov, farFov)
    local span = zoomMax - zoomMin
    if span <= 0 then
        return nil
    end

    zoom = Clamp(zoom, zoomMin, zoomMax)
    local t = (zoom - zoomMin) / span
    return nearFov + (farFov - nearFov) * t
end

-- ---------------------------------------------------------------------------
-- Smoothing animation
-- ---------------------------------------------------------------------------
-- The glide runs through the shared Ease primitive: a temporary updater that
-- tears itself down when the transition completes. This module supplies only the
-- payload (which FOV to write); Ease owns the register/progress/land/self-tear
-- lifecycle, so nothing runs per-frame unless a transition is in progress.

-- Cancel any in-flight smoothing glide. Idempotent (Ease.Stop is a no-op when the
-- ease is not running), so it doubles as the "cancel" path used when the feature
-- is turned off or reconfigured.
local function StopAnimation()
    Ease.Stop(ANIM_UPDATE_NAME)
end

-- Cancel a pending dynamic-FOV glide when a higher-priority owner takes FOV.
-- Invalidating the dedup cache is essential: after that owner releases FOV,
-- Apply() must write the dynamic target again even if it matches our old target.
function DynamicFov.CancelAnimation()
    StopAnimation()
    lastAppliedFov = nil
end

-- Payload endpoints for the smoothing glide: the from/to FOV of the current ease.
-- Held as module locals (not captured per-call) so the step/land closures and the
-- ease spec below can be built ONCE and reused on every retarget. StartAnimation is
-- reached only when zoom changes, so a fresh closure/table per call would still be
-- unnecessary garbage. Only one smoothing ease exists at a time (one name), so a
-- single shared endpoint pair is safe.
local animFrom = nil
local animTo   = nil

-- Write an FOV value through CameraSettings and update the dedup cache. Returns
-- true only on a verified write. Centralized so both the instant and animated
-- paths share identical write/verify/caching behavior.
local function WriteFov(fov)
    if not EnsureBaseFov() then
        return false
    end
    if not CameraSettings.Set(FOV_KEY, fov) then
        return false
    end
    lastAppliedFov = fov
    return true
end

-- The glide payload, allocated once. onStep writes the interpolated FOV each frame;
-- onLand writes the exact target. Both read the module-local endpoints above, so a
-- retarget only rewrites animFrom/animTo and restarts Ease's clock -- no new closures
-- and no new spec table, even when StartAnimation runs every frame during a ramp.
local function OnSmoothStep(t)
    WriteFov(animFrom + (animTo - animFrom) * t)
end

local function OnSmoothLand()
    WriteFov(animTo)
end

local SMOOTH_SPEC = {
    durMs  = ANIM_DURATION_MS,
    onStep = OnSmoothStep,
    onLand = OnSmoothLand,
}

-- Begin (or retarget) a glide toward targetFov. The start point is the live FOV
-- so an in-flight glide retargets smoothly from wherever it currently is rather
-- than jumping back to a stale value. Returns true if a glide is now in progress.
local function StartAnimation(targetFov, durationMs, curve)
    local startFov = lastAppliedFov
    if startFov == nil then
        local current, ok = CameraSettings.Get(FOV_KEY)
        startFov = ok and current or targetFov
    end

    -- Already there: nothing to animate. Stop any in-flight ease and pin exactly.
    if mathabs(targetFov - startFov) <= FOV_EPSILON then
        StopAnimation()
        return WriteFov(targetFov)
    end

    -- Rewrite the shared endpoints and (re)start the ease over a fresh window.
    -- Ease.Start retargets in place when one is already running, so this allocates
    -- nothing on the per-frame ramp path (reuses SMOOTH_SPEC and its closures).
    animFrom = startFov
    animTo   = targetFov
    SMOOTH_SPEC.durMs = durationMs or ANIM_DURATION_MS
    SMOOTH_SPEC.curve = curve
    Ease.Start(ANIM_UPDATE_NAME, SMOOTH_SPEC)
    return true
end

-- Returns true if zoom-based dynamic FOV is switched on and supported.
function DynamicFov.IsEnabled()
    return config.enabled and CameraSettings.IsSupported(FOV_KEY)
end

-- Returns true if this module should be driving FOV at all.
function DynamicFov.IsEngaged()
    return DynamicFov.IsEnabled() and config.ready
end

local function OnObservedZoom()
    local zoom, ok = CameraSettings.Get(ZOOM_KEY)
    if not ok or zoom == nil then
        return
    end
    if lastObservedZoom ~= nil and mathabs(zoom - lastObservedZoom) <= ZOOM_EPSILON then
        return
    end

    lastObservedZoom = zoom
    local arbiter = addon.FovArbiter
    if arbiter and arbiter.RequestDynamic then
        arbiter.RequestDynamic(zoom)
    else
        DynamicFov.Apply(zoom)
    end
end

local function StartObserver()
    EVENT_MANAGER:RegisterForUpdate(
        OBSERVER_UPDATE_NAME, OBSERVER_INTERVAL_MS, OnObservedZoom)
end

local function StopObserver()
    EVENT_MANAGER:UnregisterForUpdate(OBSERVER_UPDATE_NAME)
    lastObservedZoom = nil
end

-- Compute the FOV for a zoom distance. Returns nil when ranges are unavailable.
local function ComputeBaseFov(zoom)
    if config.enabled then
        local nearFov, farFov = config.nearFov, config.farFov
        if nearFov == nil or farFov == nil then
            return nil
        end

        local zoomMin, zoomMax = GetZoomRange()
        if zoomMin == nil or zoomMax == nil then
            return nil
        end

        return InterpolateFov(zoom, zoomMin, zoomMax, nearFov, farFov)
    end
    return nil
end

-- Apply runtime configuration, typically mirrored from SavedVariables by
-- Settings.lua. Unspecified near/far FOV values default to (and are clamped to)
-- the engine FOV range, so a minimal Configure{ enabled = true } is valid.
-- Calling this resets the "last applied" cache so the next Apply() always
-- writes, and -- when the feature is being turned off -- does not touch FOV,
-- leaving whatever value the player or another module last set.
function DynamicFov.Configure(options)
    options = options or {}
    local wasEnabled = config.enabled
    config.enabled = options.enabled and true or false
    config.smooth  = options.smooth and true or false

    local fovMin, fovMax = GetFovRange()
    if fovMin and fovMax then
        -- nil is an intentional reset signal from Settings: resolve it directly
        -- to the engine defaults instead of retaining a previous runtime value.
        local near = tonumber(options.nearFov) or fovMin
        local far  = tonumber(options.farFov)  or fovMax
        config.nearFov = Clamp(near, fovMin, fovMax)
        config.farFov  = Clamp(far,  fovMin, fovMax)
    else
        -- FOV unavailable on this client. Keep explicit values for a later
        -- supported client, but clear runtime values when Settings resets them.
        config.nearFov = tonumber(options.nearFov)
        config.farFov  = tonumber(options.farFov)
    end

    lastAppliedFov = nil
    -- Any reconfiguration (including being turned off) cancels an in-flight
    -- glide so we never animate toward a now-stale target.
    StopAnimation()

    if config.enabled and config.ready then
        if not wasEnabled then
            baseFov = LoadPersistedBaseFov()
        end
        lastObservedZoom = nil
        StartObserver()
        OnObservedZoom()
    else
        StopObserver()
        if config.ready and not config.enabled then
            RestoreBaseFov()
        end
    end
    LogDebug("DynamicFov.Configure: enabled=%s, smooth=%s, nearFov=%s, farFov=%s",
        tostring(config.enabled), tostring(config.smooth),
        tostring(config.nearFov), tostring(config.farFov))
end

-- Complete startup only after ContextPresets and ShoulderControl recovered any
-- persisted camera snapshots. This prevents a first-run baseline capture from
-- treating a previous session's still-applied preset FOV as the player's own.
function DynamicFov.ActivateAfterRecovery()
    if config.ready then
        return false
    end

    config.ready = true
    if config.enabled then
        baseFov = LoadPersistedBaseFov()
        lastObservedZoom = nil
        StartObserver()
        OnObservedZoom()
    else
        RestoreBaseFov()
    end
    return true
end

-- Recompute and apply the FOV for the given zoom distance. Called whenever the zoom
-- changes. No-op when Dynamic FOV is disabled, unavailable, not yet configured, or
-- when the new FOV is within FOV_EPSILON of the last value we wrote.
function DynamicFov.Apply(zoom)
    if not DynamicFov.IsEngaged() then
        return false
    end

    zoom = tonumber(zoom)

    if zoom == nil then
        return false
    end
    lastObservedZoom = zoom

    local baseFov = ComputeBaseFov(zoom)
    if baseFov == nil then
        return false
    end

    local targetFov = baseFov

    if lastAppliedFov ~= nil and mathabs(targetFov - lastAppliedFov) <= FOV_EPSILON then
        return false
    end

    local durationMs = config.smooth and ANIM_DURATION_MS or 0
    local curve = nil
    if CameraResponse then
        durationMs = CameraResponse.GetDurationMs()
        curve = CameraResponse.GetCurve()
    end

    if durationMs > 0 then
        return StartAnimation(targetFov, durationMs, curve)
    end

    StopAnimation()
    if not WriteFov(targetFov) then
        LogWarn("DynamicFov.Apply: failed to set FOV=%.2f", targetFov)
        return false
    end

    LogDebug("DynamicFov.Apply: FOV=%.2f", targetFov)
    return true
end

-- Called by FovArbiter after the final preset hold releases. If Dynamic FOV was
-- disabled while that hold owned FOV, the deferred manual-FOV restore can now
-- complete without overwriting the preset.
function DynamicFov.OnHoldReleased()
    if config.enabled then
        return false
    end
    return RestoreBaseFov()
end
