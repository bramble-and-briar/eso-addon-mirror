-- Addon namespace
local ADDON_NAME = "BureauOfAcceptableViews"
local SAVED_VARIABLES_NAME = "BureauOfAcceptableViews_SavedVariables"

BureauOfAcceptableViews = {
    name = ADDON_NAME,
    savedVariablesName = SAVED_VARIABLES_NAME,
    version = "3.11.012748",
    -- 0=off, 1=errors, 2=warnings, 3=info, 4=verbose. Seeded silent here and
    -- overwritten from SavedVariables at load (see DEBUG_MODE_DEFAULT below, which
    -- must stay in sync -- this literal exists only because the addon table is
    -- built before the constant block).
    debugMode = 0,
}

local private = {}
BureauOfAcceptableViews.private = private

-- Hot-path global caching
-- ---------------------------------------------------------------------------
-- In Lua, every reference to a global is a hash lookup in _G. Camera zoom
-- helpers run on every zoom/toggle input, so the ESO API and standard library
-- functions they touch are bound to locals (upvalues) once at load time. This
-- turns repeated global lookups into cheap upvalue reads without changing
-- behaviour. Keep this block above the first function definition so the
-- closures below capture these locals.
local GetSetting    = GetSetting
local SetSetting    = SetSetting
local GetString     = GetString
local d             = d
local tonumber      = tonumber
local select        = select
local type          = type
local stringformat  = string.format
local stringgmatch  = string.gmatch
local stringlower   = string.lower
local tableinsert   = table.insert
local mathmax       = math.max
local mathmin       = math.min

-- Localization/chat helpers
local CHAT_PREFIX = "|c6FCB9F[Bureau Of Acceptable Views]|r: "
local CHAT_ERROR_PREFIX = "|cFF0000[Bureau Of Acceptable Views]|r: "

local DEBUG_LEVEL_STRING_IDS = {
    SI_BAV_DEBUG_LEVEL_OFF,
    SI_BAV_DEBUG_LEVEL_ERRORS,
    SI_BAV_DEBUG_LEVEL_WARNINGS,
    SI_BAV_DEBUG_LEVEL_INFO,
    SI_BAV_DEBUG_LEVEL_VERBOSE,
}

local SOURCE_STRING_IDS = {
    ToggleFPV = SI_BAV_SOURCE_TOGGLE_FPV,
    ZoomIn = SI_BAV_SOURCE_ZOOM_IN,
    ZoomOut = SI_BAV_SOURCE_ZOOM_OUT,
}

local function ResolveLocalizedText(message)
    if type(message) == "number" then
        return GetString(message)
    end

    return tostring(message)
end

local function FormatLocalizedText(message, ...)
    local localizedText = ResolveLocalizedText(message)
    if select("#", ...) > 0 then
        return stringformat(localizedText, ...)
    end
    return localizedText
end

local function GetLocalizedBoolean(value)
    return GetString(value and SI_BAV_BOOL_TRUE or SI_BAV_BOOL_FALSE)
end

local function GetDebugLevelName(level)
    level = mathmax(0, mathmin(4, tonumber(level) or 0))
    return GetString(DEBUG_LEVEL_STRING_IDS[level + 1] or DEBUG_LEVEL_STRING_IDS[1])
end

local function GetLocalizedSourceName(sourceName)
    local stringId = SOURCE_STRING_IDS[sourceName]
    if stringId then
        return GetString(stringId)
    end
    return tostring(sourceName)
end

local function ChatInfo(message, ...)
    d(CHAT_PREFIX .. FormatLocalizedText(message, ...))
end

local function ChatError(message, ...)
    d(CHAT_ERROR_PREFIX .. FormatLocalizedText(message, ...))
end

-- Debug logging system
-- ---------------------------------------------------------------------------
-- Log levels are defined once here. The numeric values double as the
-- debugMode thresholds (emit when debugMode >= level), so this enum is the
-- single source of truth for both the public debugMode contract and the
-- generated Log* helpers below.
-- Shipped debugMode default and its valid range. 0 = silent: internal Log* output
-- is opt-in, while genuine user-facing failures keep going through ChatError
-- (which is independent of debugMode). Persisted per account by Settings.lua.
local DEBUG_MODE_DEFAULT = 0
local DEBUG_MODE_MIN     = 0
local DEBUG_MODE_MAX     = 4

local LOG_LEVEL = {
    ERROR = 1,
    WARN  = 2,
    INFO  = 3,
    DEBUG = 4,
}

-- String id per level. Kept as ids (not resolved strings) so GetString is
-- only ever called at log time -- this file stays independent of the
-- localization load order.
local LOG_LEVEL_STRING_IDS = {
    [LOG_LEVEL.ERROR] = SI_BAV_LOG_LEVEL_ERROR,
    [LOG_LEVEL.WARN]  = SI_BAV_LOG_LEVEL_WARN,
    [LOG_LEVEL.INFO]  = SI_BAV_LOG_LEVEL_INFO,
    [LOG_LEVEL.DEBUG] = SI_BAV_LOG_LEVEL_DEBUG,
}

local function Log(level, message, ...)
    if BureauOfAcceptableViews.debugMode < level then
        return
    end

    local stringId = LOG_LEVEL_STRING_IDS[level]
    local prefix = stringId and (GetString(stringId) .. " ") or ""
    d(CHAT_PREFIX .. prefix .. FormatLocalizedText(message, ...))
end

-- Level-specific helpers (LogError/LogWarn/LogInfo/LogDebug) are generated
-- from LOG_LEVEL so adding a level needs no extra boilerplate. They are
-- forward-declared as locals first, so closures defined later in the file
-- capture them as upvalues and tooling still resolves each name.
local LogError, LogWarn, LogInfo, LogDebug
do
    local generated = {}
    for name, level in pairs(LOG_LEVEL) do
        generated[name] = function(...) Log(level, ...) end
    end
    LogError = generated.ERROR
    LogWarn  = generated.WARN
    LogInfo  = generated.INFO
    LogDebug = generated.DEBUG
end

-- Default constants (user-configurable values are stored in SavedVariables)
local ZOOM_MAX                     = 10.0  -- Maximum zoom distance
local ZOOM_MIN_MOUNTED             = 2.0   -- Default fallback zoom when mounted/werewolf/swimming
local LASTZOOM_THRESHOLD           = 2.0   -- Default minimum zoom value to save as lastZoom
local ZOOM_FPV                     = 0.0   -- First person view zoom
local ZOOM_STEP                    = 0.35  -- Default zoom step size
local PRESERVE_FPV_BETWEEN_ZONES   = true  -- Default behavior: keep FPV across relogs and zone changes
local ZOOM_STEP_MIN                = 0.05  -- Minimum configurable zoom step
local ZOOM_STEP_MAX                = 2.25   -- Maximum configurable zoom step
local CONFIG_MIN_THIRD_PERSON_ZOOM = 0.10  -- Lowest sensible configurable third-person fallback zoom

private.constants = {
    ZOOM_MAX = ZOOM_MAX,
    ZOOM_MIN_MOUNTED = ZOOM_MIN_MOUNTED,
    LASTZOOM_THRESHOLD = LASTZOOM_THRESHOLD,
    ZOOM_FPV = ZOOM_FPV,
    ZOOM_STEP = ZOOM_STEP,
    PRESERVE_FPV_BETWEEN_ZONES = PRESERVE_FPV_BETWEEN_ZONES,
    ZOOM_STEP_MIN = ZOOM_STEP_MIN,
    ZOOM_STEP_MAX = ZOOM_STEP_MAX,
    CONFIG_MIN_THIRD_PERSON_ZOOM = CONFIG_MIN_THIRD_PERSON_ZOOM,
    -- Shipped log verbosity and its valid range. Shared with Settings.lua, which
    -- owns the persisted debugMode key and the panel slider bounds, so the default
    -- and the accepted levels are defined exactly once.
    DEBUG_MODE_DEFAULT = DEBUG_MODE_DEFAULT,
    DEBUG_MODE_MIN = DEBUG_MODE_MIN,
    DEBUG_MODE_MAX = DEBUG_MODE_MAX,
}

-- These defaults are a shared contract consumed by Settings.lua and must not
-- drift at runtime. A __newindex guard turns any accidental write into a clear
-- error instead of a silent, hard-to-trace state change. Field reads and
-- pairs() iteration are unaffected, since the values live directly in the table.
setmetatable(private.constants, {
    __newindex = function(_, key, _value)
        error(stringformat("BAV: attempt to modify read-only constant '%s'", tostring(key)), 2)
    end,
})

-- Local variables
local savedVars = {}
local lastZoom = ZOOM_MIN_MOUNTED -- Default to minimum zoom, not 0
local saveQueued = false
local SAVE_DELAY_MS = 1000
local SAVE_TIMER_NAME = ADDON_NAME .. "_QueuedSave"


-- Re-entrancy protection for the FPV toggle.
-- ---------------------------------------------------------------------------
-- isTogglingFPV guards true re-entrancy: the camera write that an owned toggle
-- triggers now happens in ZoomReconciler's deferred callback, which sets this
-- flag around its SetCameraZoom so that if the write somehow re-triggered the
-- FPV toggle, this hook sees the guard and passes through instead of recursing.
-- The programmatic same-frame PAIR case (an addon such as PvpAlerts calling
-- ToggleGameCameraFirstPerson() twice in one frame to measure the camera) is no
-- longer handled by frame-timing bookkeeping here: ownership and camera
-- convergence live in ZoomReconciler, whose intent model makes a probe pair net
-- to zero regardless of frame timing. See ZoomReconciler.lua.
local isTogglingFPV = false          -- Flag to prevent re-entrant calls

-- Runaway-oscillation detector + reversible backoff.
-- ---------------------------------------------------------------------------
-- A safety net for FUTURE, unknown addon conflicts (the PvpAlerts probe-pair
-- case is handled structurally by ZoomReconciler's intent model). If something
-- drives the view
-- to flip first-person<->third-person at a rate no human could produce, we stop
-- OUR hook from participating: it goes passive (pass every call straight to the
-- engine = vanilla behavior), breaking our side of the loop. This is purely a
-- session-local runtime flag -- it touches no SavedVariables and is undone by a
-- relog or `/bav reset`. We deliberately do NOT name or blame any addon (a
-- ZO_PreHook cannot know its caller) and count settled view flips, not raw calls.
-- Native transitions use a one-shot next-frame observation; there is no standing
-- camera polling for this detector.
local OSCILLATION_WINDOW_MS       = 3000  -- sliding window for counting view flips
local OSCILLATION_FLIP_THRESHOLD  = 8     -- flips within the window that trip backoff

local viewFlipTimestamps = {}    -- sliding window of observed real-flip times (ms)
local lastObservedFpv    = nil   -- last observed FPV-ness, to detect a real flip
local togglePassive      = false -- backoff: when true, our FPV hook is a no-op
local viewStateObservationPending = false
local VIEW_STATE_OBSERVER_UPDATE_NAME = ADDON_NAME .. "_ViewStateObserver"

-- Camera-write health.
-- ---------------------------------------------------------------------------
-- Count of consecutive VERIFIED-write rejections from the engine (SetCameraZoom
-- returning false because CameraSettings.Set could not read the value back). A
-- single failure is noise, but a RUN of them means the engine is refusing our
-- distance writes -- e.g. ZOS's reworked werewolf manages its own camera distance
-- and rejects ours, which previously left the camera stuck in first person while
-- another addon's measurement toggles kept re-forcing it. Reset to 0 on the first
-- good write instead of the symptom showing up only as a mystery bug report.
-- Readable through private.GetZoomWriteFailureCount() and reported by
-- `/bav status`, which is what makes the run visible instead of a dead counter.
local consecutiveZoomWriteFailures = 0

-- Threshold at which a rejection run stops being noise and is worth reporting.
-- Mirrors ZoomReconciler's RECONCILE_MAX_RETRIES.
local ZOOM_WRITE_FAILURE_REPORT_THRESHOLD = 3

-- Helper function to check if zoom value is valid
local function IsValidZoom(zoom)
    return type(zoom) == "number" and zoom >= ZOOM_FPV and zoom <= ZOOM_MAX
end

-- Helper function to check if zoom value is a valid third-person distance
local function IsValidThirdPersonZoom(zoom)
    return IsValidZoom(zoom) and zoom > ZOOM_FPV
end

-- Camera setting API coupling
-- ---------------------------------------------------------------------------
-- The raw camera distance I/O (the string-based GetSetting/SetSetting contract
-- on SETTING_TYPE_CAMERA / CAMERA_SETTING_DISTANCE) now lives in the shared
-- CameraSettings layer. What remains here is zoom-precision rounding: the
-- camera distance setting carries two decimals, and several call sites compare
-- and persist zoom values, so we round consistently to that precision via
-- EncodeCameraZoom / NormalizeZoomValue.
local CAMERA_ZOOM_DECIMALS  = 2                                      -- Precision used by the camera distance setting
local CAMERA_ZOOM_FORMAT    = "%." .. CAMERA_ZOOM_DECIMALS .. "f"    -- Format string used to round zoom to that precision

-- Round a numeric zoom to the camera distance precision, as a string.
-- Returns nil when the value is not numeric.
local function EncodeCameraZoom(zoom)
    zoom = tonumber(zoom)
    if not zoom then
        return nil
    end

    return stringformat(CAMERA_ZOOM_FORMAT, zoom)
end

-- Helper to round zoom-like values to the precision used by the camera setting
local function NormalizeZoomValue(zoom)
    local encodedZoom = EncodeCameraZoom(zoom)
    if not encodedZoom then
        return nil
    end

    return tonumber(encodedZoom)
end

-- Helper to normalize a zoom-like value to a guaranteed number using a fallback
local function NormalizeZoomNumber(zoom, fallback)
    local normalizedZoom = NormalizeZoomValue(zoom)
    if normalizedZoom == nil then
        return fallback
    end

    return normalizedZoom
end

-- Helper to clamp numeric configuration values
local function ClampNumber(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function GetSettingsModule()
    return BureauOfAcceptableViews.Settings
end

local function GetConfiguredZoomStep()
    local settings = GetSettingsModule()
    local pvpMode = BureauOfAcceptableViews.PvpMode
    if pvpMode and pvpMode.IsActiveInPvpWorld
        and pvpMode.IsActiveInPvpWorld() and settings.GetPvpZoomStep then
        return settings.GetPvpZoomStep()
    end
    return settings.GetConfiguredZoomStep()
end

local function GetConfiguredLastZoomThreshold()
    return GetSettingsModule().GetConfiguredLastZoomThreshold()
end

local function GetConfiguredMinMountedZoom()
    return GetSettingsModule().GetConfiguredMinMountedZoom()
end

local function ShouldPersistFPVBetweenZones()
    return GetSettingsModule().ShouldPersistFPVBetweenZones()
end

-- Read the raw camera zoom from the settings API and decode it to a number.
-- Returns the decoded zoom and a success flag; the value is nil on failure.
local function ReadCameraZoomSetting()
    -- Engine I/O is delegated to the shared CameraSettings layer, which owns the
    -- string-based GetSetting contract. We keep the zoom-specific normalization
    -- so callers continue to receive values rounded to the zoom precision.
    local rawZoom, success = BureauOfAcceptableViews.CameraSettings.Get("distance")
    if not success then
        return nil, false
    end

    local zoom = NormalizeZoomValue(rawZoom)
    if zoom == nil then
        return nil, false
    end

    return zoom, true
end

-- Helper function to get current zoom with nil protection and error handling
-- Returns zoom and whether the value was read successfully
local function GetCameraZoom()
    local zoom, success = ReadCameraZoomSetting()
    if success and zoom and zoom >= 0 then
        return zoom, true
    end
    return GetConfiguredMinMountedZoom(), false
end

-- Helper to resolve which current zoom should be persisted across relogs and zones
local function GetPersistedCurrentZoom(currentZoom)
    currentZoom = NormalizeZoomNumber(currentZoom, GetConfiguredMinMountedZoom())

    if currentZoom > ZOOM_FPV or ShouldPersistFPVBetweenZones() then
        return currentZoom
    end

    if IsValidThirdPersonZoom(lastZoom) then
        return NormalizeZoomValue(lastZoom)
    end

    local savedLastThirdPersonZoom = NormalizeZoomValue(savedVars.lastThirdPersonZoom)
    if IsValidThirdPersonZoom(savedLastThirdPersonZoom) then
        return savedLastThirdPersonZoom
    end

    return GetConfiguredMinMountedZoom()
end

-- Helper to normalize persisted current zoom against the active persistence policy
local function NormalizeSavedCurrentZoom()
    local normalizedCurrentZoom = NormalizeZoomValue(savedVars.currentZoom)
    local savedLastThirdPersonZoom = NormalizeZoomValue(savedVars.lastThirdPersonZoom)

    if IsValidThirdPersonZoom(savedLastThirdPersonZoom) then
        savedVars.lastThirdPersonZoom = savedLastThirdPersonZoom
    elseif IsValidThirdPersonZoom(lastZoom) then
        savedVars.lastThirdPersonZoom = NormalizeZoomValue(lastZoom)
    else
        savedVars.lastThirdPersonZoom = GetConfiguredMinMountedZoom()
    end

    if IsValidZoom(normalizedCurrentZoom) then
        savedVars.currentZoom = GetPersistedCurrentZoom(normalizedCurrentZoom)
    elseif IsValidThirdPersonZoom(savedVars.lastThirdPersonZoom) then
        savedVars.currentZoom = savedVars.lastThirdPersonZoom
    else
        savedVars.currentZoom = GetConfiguredMinMountedZoom()
    end
end

-- Helper function to save camera state to SavedVariables
-- Persists both the active zoom and the last valid third-person zoom
local function SaveCameraState(currentZoom)
    -- While a context preset owns distance, the live camera carries the
    -- preset's offset rather than the player's real zoom. Persist the captured
    -- baseline instead so a logout/reload cannot bake cinematic framing into
    -- currentZoom and then overwrite snapshot recovery on the next activation.
    local presets = BureauOfAcceptableViews.ContextPresets
    if presets and presets.GetBaseZoomForPersistence then
        local baseZoom = presets.GetBaseZoomForPersistence()
        if baseZoom ~= nil then
            currentZoom = baseZoom
        end
    end

    if currentZoom == nil then
        local readZoom, success = GetCameraZoom()
        if not success then
            LogWarn("SaveCameraState: live zoom unavailable; keeping persisted camera state")
            return false
        end
        currentZoom = readZoom
    end
    currentZoom = NormalizeZoomNumber(currentZoom, GetConfiguredMinMountedZoom())
    if not IsValidZoom(currentZoom) then
        currentZoom = GetConfiguredMinMountedZoom()
    end

    local storedCurrentZoom = GetPersistedCurrentZoom(currentZoom)
    local storedLastZoom = NormalizeZoomNumber(lastZoom, GetConfiguredMinMountedZoom())

    if savedVars.currentZoom ~= storedCurrentZoom then
        savedVars.currentZoom = storedCurrentZoom
    end

    if IsValidThirdPersonZoom(storedLastZoom) and savedVars.lastThirdPersonZoom ~= storedLastZoom then
        savedVars.lastThirdPersonZoom = storedLastZoom
    end
    return true
end

-- Throttled save to prevent excessive disk writes
-- Saves at most once per second, and only on the final camera state
local function QueueSave()
    if not saveQueued then
        saveQueued = true
        EVENT_MANAGER:RegisterForUpdate(SAVE_TIMER_NAME, SAVE_DELAY_MS, function()
            EVENT_MANAGER:UnregisterForUpdate(SAVE_TIMER_NAME)
            SaveCameraState()
            saveQueued = false
        end)
    end
end

-- Save immediately on player deactivation (logout/zone change)
local function SaveImmediately()
    if saveQueued then
        EVENT_MANAGER:UnregisterForUpdate(SAVE_TIMER_NAME)
        saveQueued = false
    end
    SaveCameraState()
end

-- Helper function to set camera zoom using the shared CameraSettings layer.
-- Zoom-specific validation stays here; the encode/SetSetting/verify contract is
-- owned by CameraSettings.Set (which verifies the applied value within epsilon).
local function SetCameraZoom(zoom)
    zoom = NormalizeZoomValue(zoom)
    if not IsValidZoom(zoom) then
        LogWarn(SI_BAV_LOG_INVALID_ZOOM, tostring(zoom))
        return false
    end

    -- The write-verify tolerance is owned by CameraSettings (its default
    -- VERIFY_EPSILON); we no longer keep a second copy of that 0.05 here. Omit
    -- the epsilon argument so there is a single source of truth for it.
    local applied = BureauOfAcceptableViews.CameraSettings.Set("distance", zoom)
    if not applied then
        -- The engine rejected (or could not verify) this distance write. Track a
        -- run of these: a single miss is noise, but a sustained run means the
        -- engine is refusing our writes (e.g. reworked werewolf owns its camera
        -- distance), which `/bav status` reports once the run passes the
        -- reporting threshold.
        consecutiveZoomWriteFailures = consecutiveZoomWriteFailures + 1
        LogWarn(SI_BAV_LOG_SET_APPLY_FAILED, zoom)
        return false
    end

    -- A verified write went through; the engine is honoring our distance again.
    consecutiveZoomWriteFailures = 0

    local reconciler = BureauOfAcceptableViews.ZoomReconciler
    if not isTogglingFPV and reconciler and reconciler.SyncIntent then
        reconciler.SyncIntent(zoom)
    end

    -- Keep zoom-dependent FOV in sync. This is the single verified zoom-write
    -- point, so it is the natural place to re-evaluate dynamic FOV. Route through
    -- the FOV arbiter rather than calling DynamicFov directly: while a preset
    -- holds FOV, the arbiter suppresses this dynamic write so the pinned FOV is
    -- not stomped on the next zoom change. With no hold (and DynamicFov off by
    -- default) this is a no-op, so default behaviour (FOV untouched) is preserved.
    if BureauOfAcceptableViews.FovArbiter then
        BureauOfAcceptableViews.FovArbiter.RequestDynamic(zoom)
    elseif BureauOfAcceptableViews.DynamicFov then
        BureauOfAcceptableViews.DynamicFov.Apply(zoom)
    end

    LogDebug(SI_BAV_LOG_SET_APPLIED, zoom)
    return true
end

-- Check if player is in a state where zoom is normally limited
local function IsZoomLimited()
    return IsMounted() or IsPlayerInWerewolfForm() or IsUnitSwimming("player")
end

local function CancelViewStateObservation()
    if viewStateObservationPending then
        EVENT_MANAGER:UnregisterForUpdate(VIEW_STATE_OBSERVER_UPDATE_NAME)
        viewStateObservationPending = false
    end
end

-- Observe the settled view after a verified reconcile or a native transition.
-- Balanced probe pairs are sampled after both intents cancel, not between calls.
local function NoteViewStateAndCheckOscillation(nowMs)
    local zoom, success = GetCameraZoom()
    if not success then
        return
    end
    local isFpv = zoom <= ZOOM_FPV

    if lastObservedFpv == nil then
        lastObservedFpv = isFpv
        return
    end
    if isFpv == lastObservedFpv then
        return  -- no actual flip; nothing to record
    end
    lastObservedFpv = isFpv

    -- Append this flip, then drop any timestamps that fell out of the window.
    viewFlipTimestamps[#viewFlipTimestamps + 1] = nowMs
    local cutoff = nowMs - OSCILLATION_WINDOW_MS
    local kept = {}
    for i = 1, #viewFlipTimestamps do
        if viewFlipTimestamps[i] >= cutoff then
            kept[#kept + 1] = viewFlipTimestamps[i]
        end
    end
    viewFlipTimestamps = kept

    if not togglePassive and #viewFlipTimestamps >= OSCILLATION_FLIP_THRESHOLD then
        togglePassive = true
        CancelViewStateObservation()
        local reconciler = BureauOfAcceptableViews.ZoomReconciler
        if reconciler and reconciler.Cancel then
            reconciler.Cancel()
        end
        LogDebug("ToggleFPV: runaway view oscillation detected; FPV hook is now passive")
    end
end

local function ScheduleViewStateObservation()
    if viewStateObservationPending then
        return
    end
    viewStateObservationPending = true
    EVENT_MANAGER:RegisterForUpdate(VIEW_STATE_OBSERVER_UPDATE_NAME, 0, function()
        CancelViewStateObservation()
        NoteViewStateAndCheckOscillation(GetGameTimeMilliseconds())
    end)
end

-- Pre-hook for ToggleGameCameraFirstPerson
-- Returns true to block original function, false/nil to allow it
local function PreHookToggleGameCameraFirstPerson()
    local sourceName = GetLocalizedSourceName("ToggleFPV")
    LogDebug(SI_BAV_LOG_SOURCE_CALLED, sourceName)

    -- Backoff: once runaway oscillation has been detected this session, our hook
    -- stays out of the way entirely (vanilla pass-through) until /bav reset or a
    -- relog clears it. Checked first so we add zero behavior while backed off.
    if togglePassive then
        return false
    end

    -- True re-entrancy: our own SetCameraZoom must never recurse into this hook.
    -- Pass through (don't block) so we never break a caller's toggle.
    if isTogglingFPV then
        LogDebug(SI_BAV_LOG_TOGGLE_BLOCKED_REENTRANT)
        return false
    end

    -- Don't interfere with siege weapons - let original function handle it
    if IsGameCameraSiegeControlled() then
        LogInfo(SI_BAV_LOG_TOGGLE_SIEGE_PASS)
        return false  -- Allow original function to execute
    end

    -- Delegate the ownership decision and the camera convergence to the
    -- ZoomReconciler. It returns true when it took ownership (limited state, or
    -- leaving FPV) -- in which case it has flipped its intent and scheduled a
    -- single next-frame write, and we block the engine. It returns false for the
    -- normal third-person -> FPV case, which we pass through to the engine's
    -- native transition. There is no synchronous camera write here anymore, so
    -- no same-frame-pair bookkeeping and no dependency on frame timing: a probe
    -- pair is just two intent flips that net to zero. See ZoomReconciler.lua.
    local reconciler = BureauOfAcceptableViews.ZoomReconciler
    if reconciler and reconciler.HandleToggle(viewStateObservationPending) then
        CancelViewStateObservation()
        return true  -- owned: intent flipped, reconcile scheduled
    end
    ScheduleViewStateObservation()
    return false     -- passthrough (engine balances any probe pair itself)
end

-- Shared handler for zooming in (reducing camera distance)
local function HandleZoomIn(sourceName)
    local localizedSourceName = GetLocalizedSourceName(sourceName)
    LogDebug(SI_BAV_LOG_SOURCE_CALLED, localizedSourceName)
    
    -- Don't interfere with siege weapons
    if IsGameCameraSiegeControlled() then
        LogInfo(SI_BAV_LOG_SOURCE_SIEGE_PASS, localizedSourceName)
        return false  -- Allow original function to execute
    end
    
    local zoom, success = GetCameraZoom()
    if not success then
        LogWarn("%s: live zoom unavailable, passing input to ESO", localizedSourceName)
        return false
    end
    
    -- Already at FPV minimum - block original function to prevent game's default behavior
    if zoom <= ZOOM_FPV then
        LogDebug(SI_BAV_LOG_SOURCE_ALREADY_AT_FPV, localizedSourceName, zoom)
        return true  -- Block original function - stay at FPV
    end
    
    local zoomStep = GetConfiguredZoomStep()
    local lastZoomThreshold = GetConfiguredLastZoomThreshold()
    local newZoom = NormalizeZoomNumber(mathmax(ZOOM_FPV, zoom - zoomStep), ZOOM_FPV)
    
    LogInfo(SI_BAV_LOG_SOURCE_TRANSITION, localizedSourceName, zoom, newZoom)
    if not SetCameraZoom(newZoom) then
        LogWarn(SI_BAV_LOG_SOURCE_SET_FAILED, localizedSourceName)
        return false  -- Let the original function handle the input if our set failed
    end
    
    -- Remember zoom for FPV toggle only if it's a "normal" zoom (> configured threshold)
    if newZoom > lastZoomThreshold then
        lastZoom = newZoom
        LogDebug(SI_BAV_LOG_SOURCE_UPDATED_LASTZOOM, localizedSourceName, lastZoom)
    elseif newZoom <= lastZoomThreshold and lastZoom > lastZoomThreshold then
        LogDebug(SI_BAV_LOG_SOURCE_PRESERVING_LASTZOOM, localizedSourceName, lastZoom)
    end
    QueueSave()
    return true  -- Block original function only after verified addon handling
end

-- Shared handler for zooming out (increasing camera distance)
local function HandleZoomOut(sourceName)
    local localizedSourceName = GetLocalizedSourceName(sourceName)
    LogDebug(SI_BAV_LOG_SOURCE_CALLED, localizedSourceName)
    
    -- Don't interfere with siege weapons
    if IsGameCameraSiegeControlled() then
        LogInfo(SI_BAV_LOG_SOURCE_SIEGE_PASS, localizedSourceName)
        return false  -- Allow original function to execute
    end
    
    local zoom, success = GetCameraZoom()
    if not success then
        LogWarn("%s: live zoom unavailable, passing input to ESO", localizedSourceName)
        return false
    end
    
    -- Already at maximum - block original function to prevent game's default behavior
    if zoom >= ZOOM_MAX then
        LogDebug(SI_BAV_LOG_SOURCE_ALREADY_AT_MAX, localizedSourceName, zoom)
        return true  -- Block original function - stay at max
    end
    
    local zoomStep = GetConfiguredZoomStep()
    local lastZoomThreshold = GetConfiguredLastZoomThreshold()
    local newZoom = NormalizeZoomNumber(mathmin(ZOOM_MAX, zoom + zoomStep), ZOOM_MAX)
    
    LogInfo(SI_BAV_LOG_SOURCE_TRANSITION, localizedSourceName, zoom, newZoom)
    if not SetCameraZoom(newZoom) then
        LogWarn(SI_BAV_LOG_SOURCE_SET_FAILED, localizedSourceName)
        return false  -- Let the original function handle the input if our set failed
    end
    
    -- Remember zoom for FPV toggle only if it's a "normal" zoom (> configured threshold)
    if newZoom > lastZoomThreshold then
        lastZoom = newZoom
        LogDebug(SI_BAV_LOG_SOURCE_UPDATED_LASTZOOM, localizedSourceName, lastZoom)
    end
    QueueSave()
    return true  -- Block original function only after verified addon handling
end

-- Pre-hook for CameraZoomIn
-- Returns true to block original function, false/nil to allow it
local function PreHookCameraZoomIn()
    return HandleZoomIn("ZoomIn")
end

-- Pre-hook for CameraZoomOut
-- Returns true to block original function, false/nil to allow it
local function PreHookCameraZoomOut()
    return HandleZoomOut("ZoomOut")
end

-- Helper to resolve the best persisted current zoom for reapplication in the world
local function GetRestoredCurrentZoom()
    if IsValidZoom(savedVars.currentZoom) then
        return savedVars.currentZoom
    end

    if IsValidThirdPersonZoom(savedVars.lastThirdPersonZoom) then
        LogWarn(SI_BAV_LOG_INVALID_SAVED_CURRENT_FALLBACK,
            tostring(savedVars.currentZoom))
        return savedVars.lastThirdPersonZoom
    end

    return nil
end

-- Helper to initialize the preferred third-person zoom from persisted state
local function InitializeLastZoom(currentZoom)
    if IsValidThirdPersonZoom(savedVars.lastThirdPersonZoom) then
        lastZoom = NormalizeZoomNumber(savedVars.lastThirdPersonZoom, GetConfiguredMinMountedZoom())
        LogDebug(SI_BAV_LOG_INITIALIZE_LAST_FROM_SAVED_TP, lastZoom)
    elseif IsValidThirdPersonZoom(currentZoom) then
        lastZoom = NormalizeZoomNumber(currentZoom, GetConfiguredMinMountedZoom())
        LogDebug(SI_BAV_LOG_INITIALIZE_LAST_FROM_CURRENT, lastZoom)
    elseif IsValidThirdPersonZoom(savedVars.currentZoom) then
        lastZoom = NormalizeZoomNumber(savedVars.currentZoom, GetConfiguredMinMountedZoom())
        LogDebug(SI_BAV_LOG_INITIALIZE_LAST_FROM_SAVED_CURRENT, lastZoom)
    else
        lastZoom = GetConfiguredMinMountedZoom()
        LogDebug(SI_BAV_LOG_INITIALIZE_LAST_DEFAULT, lastZoom)
    end
end

-- Event handler for EVENT_PLAYER_ACTIVATED
-- Reapplies the saved camera state after login and zone changes
local function OnPlayerActivated(event)
    LogDebug(SI_BAV_LOG_ONPLAYERACTIVATED_REAPPLY)

    local cameraResponse = BureauOfAcceptableViews.CameraResponse
    if cameraResponse and cameraResponse.AcquireSmoothing then
        cameraResponse.AcquireSmoothing("PlayerActivation", true)
    end

    -- Drop any reconcile that was pending when the load screen hit: the engine
    -- reset the camera across the zone change, so a stale deferred write must not
    -- fire after the saved-state restore below (which is authoritative here).
    local reconciler = BureauOfAcceptableViews.ZoomReconciler
    if reconciler and reconciler.Cancel then
        reconciler.Cancel()
    end

    -- Recover a camera that a context preset was overriding when the previous
    -- session ended (reloadui/logout/crash mid-preset). Runs once per session,
    -- before the preset controller can capture anything, and before the zoom
    -- restore below so the player's saved zoom has the final say on distance
    -- while FOV/shoulder/vertical come back from the recovered snapshot. No-op
    -- in the normal case (nothing persisted) and when the module is absent.
    local presets = BureauOfAcceptableViews.ContextPresets
    if presets and presets.RecoverPersistedSnapshot then
        presets.RecoverPersistedSnapshot()
    end

    -- Same recovery for the shoulder swap: if the previous session ended while the
    -- camera was swung over a shoulder, the engine still holds the swung value and
    -- Settings has the player's real base. Recover it once per session, before the
    -- module is allowed to capture anything as its new base.
    local shoulder = BureauOfAcceptableViews.ShoulderControl
    if shoulder and shoulder.RecoverPersistedSnapshot then
        shoulder.RecoverPersistedSnapshot()
    end

    -- Dynamic FOV must not capture its manual-FOV baseline until the persisted
    -- preset/shoulder recovery above has handed the real camera back. Activate
    -- its observer now; the saved zoom write below then provides the first
    -- authoritative distance sample through FovArbiter.
    local dynamicFov = BureauOfAcceptableViews.DynamicFov
    if dynamicFov and dynamicFov.ActivateAfterRecovery then
        dynamicFov.ActivateAfterRecovery()
    end

    local targetZoom = GetRestoredCurrentZoom()
    if targetZoom then
        LogInfo(SI_BAV_LOG_APPLYING_SAVED_STATE,
            targetZoom, lastZoom)
        if not SetCameraZoom(targetZoom) then
            LogWarn(SI_BAV_LOG_FAILED_APPLY_SAVED_STATE, targetZoom)
        end
    else
        LogWarn(SI_BAV_LOG_INVALID_SAVED_STATE,
            tostring(savedVars.currentZoom), tostring(savedVars.lastThirdPersonZoom))
    end

    -- Configuration may have enabled presets before this first activation, but
    -- ContextPresets deliberately stays inert until recovery and the saved zoom
    -- restore above are complete. Start its first state bootstrap/apply now; on
    -- later zone changes this is a no-op and the final ReassertActive below owns
    -- recovery after every state owner has sampled the new world.
    if presets and presets.ActivateAfterRecovery then
        presets.ActivateAfterRecovery()
    end

    -- PvPMode only selects the dedicated manual zoom step and optionally
    -- suppresses camera shake. Start it after recovery so a persisted shake
    -- snapshot is restored or renewed against the authoritative world state.
    local pvpMode = BureauOfAcceptableViews.PvpMode
    if pvpMode and pvpMode.ActivateAfterRecovery then
        pvpMode.ActivateAfterRecovery()
    end

    -- EVENT_PLAYER_ACTIVATED also fires on every zone change, and the engine
    -- resets camera settings across the load screen. Reassert ordinary context
    -- presets only after every world-scoped feature sampled the new world.
    if presets and presets.ReassertActive then
        presets.ReassertActive()
    end

    -- The engine also reset the shoulder offset across the load screen, and the
    -- shoulder swap's trigger flags survive a zone change without re-firing their
    -- events, so re-assert the active swing here too. No-op when shoulder swap is
    -- off or already centered.
    if shoulder and shoulder.ReassertActive then
        shoulder.ReassertActive()
    end

    if cameraResponse and cameraResponse.ReleaseSmoothing then
        cameraResponse.ReleaseSmoothing("PlayerActivation")
    end

end

-- Event handler for EVENT_PLAYER_DEACTIVATED (logout/zone change)
local function OnPlayerDeactivated(event)
    LogDebug(SI_BAV_LOG_ONPLAYERDEACTIVATED_SAVING)
    CancelViewStateObservation()
    lastObservedFpv = nil
    local cameraResponse = BureauOfAcceptableViews.CameraResponse
    if cameraResponse and cameraResponse.RestoreSmoothingNow then
        cameraResponse.RestoreSmoothingNow()
    end
    -- Drop any pending reconcile: we are leaving this world state (logout/zone
    -- change) and the engine will reset the camera, so a deferred write queued
    -- here would target a context that no longer exists.
    local reconciler = BureauOfAcceptableViews.ZoomReconciler
    if reconciler and reconciler.Cancel then
        reconciler.Cancel()
    end
    local pvpMode = BureauOfAcceptableViews.PvpMode
    if pvpMode and pvpMode.OnPlayerDeactivated then
        pvpMode.OnPlayerDeactivated()
    end
    -- Save immediately when player logs out or changes zone
    SaveImmediately()
end

-- Event handler for EVENT_ADD_ON_LOADED
local function OnAddonLoaded(event, addonName)
    if addonName ~= BureauOfAcceptableViews.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(BureauOfAcceptableViews.name, EVENT_ADD_ON_LOADED)
    LogInfo(SI_BAV_LOG_ONADDONLOADED_LOADING, BureauOfAcceptableViews.version)
    
    -- Initialize the settings module and SavedVariables
    savedVars = GetSettingsModule().InitializeSavedVariables()
    private.savedVars = savedVars

    -- Initialize lastZoom from persisted third-person preference or current setting
    local currentZoom, hasCurrentZoom = GetCameraZoom()
    LogDebug(SI_BAV_LOG_CURRENT_GAME_ZOOM, currentZoom)
    InitializeLastZoom(hasCurrentZoom and currentZoom or nil)
    NormalizeSavedCurrentZoom()

    LogDebug(SI_BAV_LOG_SAVEDVARS_INITIALIZED,
        savedVars.currentZoom or 0, savedVars.lastThirdPersonZoom or 0)
    LogDebug(SI_BAV_LOG_CONFIG_INITIALIZED,
        GetConfiguredZoomStep(), GetConfiguredLastZoomThreshold(), GetConfiguredMinMountedZoom(),
        GetLocalizedBoolean(ShouldPersistFPVBetweenZones()))
    
    -- Register pre-hooks for camera functions
    ZO_PreHook("ToggleGameCameraFirstPerson", PreHookToggleGameCameraFirstPerson)
    ZO_PreHook("CameraZoomIn", PreHookCameraZoomIn)
    ZO_PreHook("CameraZoomOut", PreHookCameraZoomOut)

    -- NOTE:
    -- GameCameraGamepadZoomDown/GameCameraGamepadZoomUp are private in the current client build.
    -- Accessing those symbols directly from insecure addon code taints the callstack and throws.
    -- Keep the controller fallback logic and diagnostics, but do not touch the private functions here.
    LogInfo(SI_BAV_LOG_GAMEPAD_DOWN_UNAVAILABLE)
    LogInfo(SI_BAV_LOG_GAMEPAD_UP_UNAVAILABLE)

    LogInfo(SI_BAV_LOG_HOOKS_REGISTERED)
    
    -- Register world reapplication and save events
    EVENT_MANAGER:RegisterForEvent(BureauOfAcceptableViews.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(BureauOfAcceptableViews.name, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)

    BureauOfAcceptableViews.RegisterSettingsPanel()

    -- Push saved optional-feature config (Dynamic FOV + Context Presets) into the
    -- modules now that SavedVariables and the modules themselves are available.
    -- Safe if a module is missing: ApplyOptionalFeatureConfig guards each one.
    GetSettingsModule().ApplyOptionalFeatureConfig()

    LogInfo(SI_BAV_LOG_ADDON_LOADED)
end

-- Register add-on load event
EVENT_MANAGER:RegisterForEvent(BureauOfAcceptableViews.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- Diagnostic helper functions
local function GetStateDescription()
    local zoom = GetCameraZoom()
    local state = {
        isFPV = zoom <= ZOOM_FPV,
        isMounted = IsMounted(),
        isWerewolf = IsPlayerInWerewolfForm(),
        isSwimming = IsUnitSwimming("player"),
        isSiege = IsGameCameraSiegeControlled(),
        isLimited = IsZoomLimited(),
    }
    return state
end

local function SimulateScenario(scenario)
    local zoom = GetCameraZoom()
    local state = GetStateDescription()
    
    ChatInfo(SI_BAV_MSG_SCENARIO, scenario)
    
    if scenario == GetString(SI_BAV_SCENARIO_TOGGLE_FPV) then
        ChatInfo(SI_BAV_MSG_CURRENT_ZOOM_FPV, zoom, GetLocalizedBoolean(zoom <= ZOOM_FPV))
        if zoom <= ZOOM_FPV then
            ChatInfo(SI_BAV_MSG_WOULD_RESTORE_TO, lastZoom)
        else
            ChatInfo(SI_BAV_MSG_WOULD_SAVE_LASTZOOM, zoom)
            ChatInfo(SI_BAV_MSG_WOULD_SET_ZOOM_TO_FPV, ZOOM_FPV)
        end
        
    elseif scenario == GetString(SI_BAV_SCENARIO_ZOOM_IN) then
        local zoomStep = GetConfiguredZoomStep()
        local lastZoomThreshold = GetConfiguredLastZoomThreshold()
        local newZoom = NormalizeZoomValue(mathmax(ZOOM_FPV, zoom - zoomStep))
        ChatInfo(SI_BAV_MSG_ZOOM_TRANSITION, zoom, newZoom)
        ChatInfo(SI_BAV_MSG_WOULD_UPDATE_LASTZOOM,
            GetLocalizedBoolean(newZoom > lastZoomThreshold))
        if zoom <= ZOOM_FPV then
            ChatInfo(SI_BAV_MSG_ALREADY_AT_FPV)
        end
        
    elseif scenario == GetString(SI_BAV_SCENARIO_ZOOM_OUT) then
        local zoomStep = GetConfiguredZoomStep()
        local newZoom = NormalizeZoomValue(mathmin(ZOOM_MAX, zoom + zoomStep))
        ChatInfo(SI_BAV_MSG_ZOOM_TRANSITION, zoom, newZoom)
        if zoom >= ZOOM_MAX then
            ChatInfo(SI_BAV_MSG_ALREADY_AT_MAX)
        end

    elseif scenario == GetString(SI_BAV_SCENARIO_MOUNTED_TOGGLE) then
        ChatInfo(SI_BAV_MSG_IS_MOUNTED, GetLocalizedBoolean(state.isMounted))
        ChatInfo(SI_BAV_MSG_IS_LIMITED, GetLocalizedBoolean(state.isLimited))
        if state.isLimited then
            ChatInfo(SI_BAV_MSG_TOGGLE_HANDLED)
        else
            ChatInfo(SI_BAV_MSG_TOGGLE_GAME)
        end
        
    elseif scenario == GetString(SI_BAV_SCENARIO_FPV_RECOVERY) then
        ChatInfo(SI_BAV_MSG_FPV_RECOVERY, lastZoom)
        ChatInfo(SI_BAV_MSG_LASTZOOM_VALIDITY,
            GetLocalizedBoolean(IsValidZoom(lastZoom)), GetLocalizedBoolean(lastZoom > ZOOM_FPV))

    elseif scenario == GetString(SI_BAV_SCENARIO_RELOG_FPV) then
        local persistedCurrentZoom = GetPersistedCurrentZoom(zoom)
        ChatInfo(SI_BAV_MSG_PRESERVE_FPV_STATE,
            GetLocalizedBoolean(ShouldPersistFPVBetweenZones()))
        ChatInfo(SI_BAV_MSG_CURRENTZOOM_WOULD_BECOME, persistedCurrentZoom)
        if zoom <= ZOOM_FPV and not ShouldPersistFPVBetweenZones() then
            ChatInfo(SI_BAV_MSG_FPV_REPLACED_ON_RELOG)
        end
            
    else
        ChatError(SI_BAV_MSG_UNKNOWN_SCENARIO)
    end
end

local function SetDebugMode(level, suppressOutput)
    return GetSettingsModule().SetDebugMode(level, suppressOutput)
end

local function ResetCameraState(suppressOutput)
    -- First hand the camera back from any optional feature that might be holding
    -- it: a swung shoulder, a stuck FOV hold, or an un-restored context-preset
    -- snapshot. Clear the shoulder swing first, then the preset hold/snapshot, so
    -- the zoom reset below lands on a neutral, un-held, un-swung camera. Each is
    -- a no-op when its feature is off or idle.
    local CameraResponse = BureauOfAcceptableViews.CameraResponse
    if CameraResponse and CameraResponse.AcquireSmoothing then
        CameraResponse.AcquireSmoothing("EmergencyReset", true)
    end

    local OffsetNudge = BureauOfAcceptableViews.OffsetNudge
    if OffsetNudge and OffsetNudge.StopAll then
        OffsetNudge.StopAll()
    end

    local ShoulderControl = BureauOfAcceptableViews.ShoulderControl
    if ShoulderControl and ShoulderControl.EmergencyRestore then
        ShoulderControl.EmergencyRestore()
    end

    local PvpMode = BureauOfAcceptableViews.PvpMode
    if PvpMode and PvpMode.EmergencySuspend then
        PvpMode.EmergencySuspend()
    end

    local ContextPresets = BureauOfAcceptableViews.ContextPresets
    if ContextPresets and ContextPresets.EmergencyRestore then
        ContextPresets.EmergencyRestore()
    end

    if CameraResponse and CameraResponse.ForceReleaseSmoothing then
        CameraResponse.ForceReleaseSmoothing()
    end

    -- Clear the oscillation backoff: /bav reset is the explicit recovery point, so
    -- the FPV hook resumes normal handling and the detector starts fresh.
    CancelViewStateObservation()
    togglePassive = false
    viewFlipTimestamps = {}
    lastObservedFpv = nil
    -- Clear the camera-write failure run too: reset is a clean slate, and the very
    -- next SetCameraZoom below re-establishes the true state.
    consecutiveZoomWriteFailures = 0

    -- Drop any pending reconcile and its intent: the explicit SetCameraZoom below
    -- is authoritative, so a stale deferred write must not fire after it.
    local reconciler = BureauOfAcceptableViews.ZoomReconciler
    if reconciler and reconciler.Cancel then
        reconciler.Cancel()
    end

    local resetZoom = GetConfiguredMinMountedZoom()
    lastZoom = resetZoom

    if SetCameraZoom(resetZoom) then
        SaveCameraState(resetZoom)
        if not suppressOutput then
            ChatInfo(SI_BAV_MSG_RESET_SUCCESS, resetZoom)
        end
        return true
    end

    SaveCameraState(resetZoom)
    if not suppressOutput then
        ChatError(SI_BAV_MSG_RESET_FAILED_SYNCED, resetZoom)
    end
    return false
end

local function GetLastZoomValue()
    return lastZoom
end

-- Current length of the consecutive camera-write rejection run (0 when healthy).
-- Read by `/bav status` and available to modules for diagnostics; this is the
-- reader that makes the counter a real metric rather than write-only bookkeeping.
local function GetZoomWriteFailureCount()
    return consecutiveZoomWriteFailures
end

local function SetLastZoomValue(value)
    lastZoom = value
end

-- Raise/lower the re-entrancy guard. ZoomReconciler wraps its deferred camera
-- write with this so a write that somehow re-triggers the FPV toggle is passed
-- through (see the isTogglingFPV check in PreHookToggleGameCameraFirstPerson).
local function SetTogglingFPV(value)
    isTogglingFPV = value and true or false
end

private.ChatInfo = ChatInfo
private.ChatError = ChatError
private.GetLocalizedBoolean = GetLocalizedBoolean
private.GetDebugLevelName = GetDebugLevelName
-- All four level helpers are exported: the modules resolve them lazily through
-- private.Log*, so a missing entry here silently kills that level everywhere
-- (their local wrappers guard with `if private.LogX then`).
private.LogError = LogError
private.LogWarn = LogWarn
private.LogInfo = LogInfo
private.LogDebug = LogDebug
private.NormalizeZoomNumber = NormalizeZoomNumber
private.ClampNumber = ClampNumber
private.IsValidZoom = IsValidZoom
private.IsValidThirdPersonZoom = IsValidThirdPersonZoom
private.GetLastZoom = GetLastZoomValue
private.GetZoomWriteFailureCount = GetZoomWriteFailureCount
private.SetLastZoom = SetLastZoomValue
private.GetCameraZoom = GetCameraZoom
private.NormalizeSavedCurrentZoom = NormalizeSavedCurrentZoom
private.SaveCameraState = SaveCameraState
private.ResetCameraState = ResetCameraState

-- Exposed for ZoomReconciler (resolved lazily there at toggle time, never at
-- load): the verified camera write, the limited-state predicate, the throttled
-- save, and the two configured-zoom getters it needs to resolve its intent.
private.SetCameraZoom = SetCameraZoom
private.IsZoomLimited = IsZoomLimited
private.QueueSave = QueueSave
private.GetConfiguredLastZoomThreshold = GetConfiguredLastZoomThreshold
private.GetConfiguredMinMountedZoom = GetConfiguredMinMountedZoom
private.SetTogglingFPV = SetTogglingFPV
private.NoteViewStateAndCheckOscillation = NoteViewStateAndCheckOscillation

local function HandleConfigCommand(args)
    return GetSettingsModule().HandleConfigCommand(args)
end

local function OpenSettingsPanel()
    return GetSettingsModule().OpenPanel()
end

function BureauOfAcceptableViews.RegisterSettingsPanel()
    return GetSettingsModule().RegisterSettingsPanel()
end

local function ForceSetZoom(value)
    value = NormalizeZoomValue(value)
    if not value then
        ChatError(SI_BAV_MSG_USAGE_SET)
        return
    end
    
    if SetCameraZoom(value) then
        ChatInfo(SI_BAV_MSG_ZOOM_SET, value)
        if value > GetConfiguredLastZoomThreshold() then
            lastZoom = value
            ChatInfo(SI_BAV_MSG_LASTZOOM_UPDATED, lastZoom)
        end
        SaveCameraState(value)
    else
        ChatError(SI_BAV_MSG_SET_FAILED, value, ZOOM_FPV, ZOOM_MAX)
    end
end

-- Comprehensive slash command
-- ---------------------------------------------------------------------------
-- Sub-commands are looked up in a dispatch table instead of an if/elseif
-- ladder: adding a command is a single table entry, lookup is O(1), and each
-- handler receives the parsed, lower-cased argument list. Unknown actions fall
-- through to the shared error handler.
local SLASH_HELP_STRING_IDS = {
    SI_BAV_MSG_HELP_TITLE,
    SI_BAV_MSG_HELP_STATUS,
    SI_BAV_MSG_HELP_SETTINGS,
    SI_BAV_MSG_HELP_DEBUG,
    SI_BAV_MSG_HELP_SET,
    SI_BAV_MSG_HELP_CONFIG,
    SI_BAV_MSG_HELP_CONFIG_STEP,
    SI_BAV_MSG_HELP_CONFIG_THRESHOLD,
    SI_BAV_MSG_HELP_CONFIG_MINMOUNTED,
    SI_BAV_MSG_HELP_CONFIG_PRESERVEFPV,
    SI_BAV_MSG_HELP_CONFIG_RESET,
    SI_BAV_MSG_HELP_SIMULATE,
    SI_BAV_MSG_HELP_RESET,
    SI_BAV_MSG_HELP_SHOULDER,
    SI_BAV_MSG_HELP_SCENARIOS,
}

local SLASH_COMMAND_HANDLERS = {
    status = function(args)
        local zoom = GetCameraZoom()
        ChatInfo(SI_BAV_MSG_STATUS,
            zoom, lastZoom, savedVars.currentZoom or 0, savedVars.lastThirdPersonZoom or 0,
            GetDebugLevelName(BureauOfAcceptableViews.debugMode), BureauOfAcceptableViews.debugMode)

        -- Camera-write health. Only printed while a run is actually in progress, so
        -- the normal case stays a one-line status; a sustained run is the signal
        -- that something else owns the camera distance and is rejecting our writes.
        if consecutiveZoomWriteFailures >= ZOOM_WRITE_FAILURE_REPORT_THRESHOLD then
            ChatError(SI_BAV_MSG_STATUS_WRITE_FAILURES, consecutiveZoomWriteFailures)
        elseif consecutiveZoomWriteFailures > 0 then
            ChatInfo(SI_BAV_MSG_STATUS_WRITE_FAILURES, consecutiveZoomWriteFailures)
        end
    end,
    debug = function(args)
        SetDebugMode(args[2])
    end,
    set = function(args)
        ForceSetZoom(args[2])
    end,
    config = function(args)
        HandleConfigCommand(args)
    end,
    settings = function(args)
        if not OpenSettingsPanel() then
            ChatError(SI_BAV_MSG_SETTINGS_UNAVAILABLE)
        end
    end,
    simulate = function(args)
        SimulateScenario(args[2] or "unknown")
    end,
    reset = function(args)
        ResetCameraState()
    end,
    shoulder = function(args)
        -- Manual-mode over-the-shoulder control. The two active shoulder modes are
        -- mutually exclusive: this command is only meaningful in Manual mode, so in
        -- Off/Auto we print a notice instead of silently doing nothing.
        local settings = GetSettingsModule()
        if settings.GetShoulderMode() ~= "manual" then
            ChatInfo(SI_BAV_MSG_SHOULDER_NOT_MANUAL)
            return
        end

        local shoulder = BureauOfAcceptableViews.ShoulderControl
        if not (shoulder and shoulder.SetManualSide) then
            return
        end

        -- args[2] (already lower-cased) may be left/right/center; absent toggles.
        local requested = args[2]
        if requested ~= "left" and requested ~= "right" and requested ~= "center" then
            requested = nil  -- toggle
        end

        local ok, side = shoulder.SetManualSide(requested or "toggle")
        if ok then
            local SIDE_STRING_IDS = {
                left   = SI_BAV_SETTING_SHOULDER_SIDE_LEFT,
                right  = SI_BAV_SETTING_SHOULDER_SIDE_RIGHT,
                center = SI_BAV_SETTING_SHOULDER_SIDE_CENTER,
            }
            local sideId = SIDE_STRING_IDS[side]
            ChatInfo(SI_BAV_MSG_SHOULDER_SET, sideId and GetString(sideId) or side)
        end
    end,
    help = function(args)
        for index = 1, #SLASH_HELP_STRING_IDS do
            ChatInfo(SLASH_HELP_STRING_IDS[index])
        end
    end,
}

-- Convenience aliases so `/bav ui` and `/bav panel` also open the settings
-- window, mirroring the primary `settings` sub-command.
SLASH_COMMAND_HANDLERS.ui = SLASH_COMMAND_HANDLERS.settings
SLASH_COMMAND_HANDLERS.panel = SLASH_COMMAND_HANDLERS.settings

SLASH_COMMANDS["/bav"] = function(cmd)
    local args = {}
    for word in stringgmatch(cmd, "%S+") do
        tableinsert(args, stringlower(word))
    end

    local action = args[1] or "status"
    local handler = SLASH_COMMAND_HANDLERS[action]
    if handler then
        handler(args)
    else
        ChatError(SI_BAV_MSG_UNKNOWN_COMMAND)
    end
end
