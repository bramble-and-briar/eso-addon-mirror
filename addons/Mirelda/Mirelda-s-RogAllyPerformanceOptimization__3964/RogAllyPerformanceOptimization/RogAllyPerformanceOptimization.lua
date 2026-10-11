-- RogAllyPerformanceOptimization
-- Version: v1.22 (2026-08-03)
-- Note: Added 60fps-specific static quality settings for screen-space reflections, planar reflections, grass, character resolution, and shadows; fixed view-distance restoration and pause/resume handling for energy saving, UI mode, loading screens, and focus loss; added compact independent passive diagnostics with delayed FSR readback for downgrades that remain capped near 30 FPS; aligned idle tracking with actual player movement instead of exact world-coordinate changes or combat state.

local UserSettingsModifier = {name = "RogAllyPerformanceOptimization"}

-- Debug log toggle, default is off
local enableDebugLogging = false

-- Saved variables & log config
local RAPO_SavedVariables
local MAX_LOG_ENTRIES = 30000
local addonLoadTime = 0

-- Performance mode definitions.
-- Each mode stores only values; field names are applied centrally by BuildPerformanceProfile().
local function BuildPerformanceProfile(values)
    return {
        targetFps = values[1],
        lockTargetFps = values[2],
        minAcceptableFps = values[3],
        fpsStabilized = values[4],
        minFrameTime2 = values[5],
        backgroundFpsLimit = values[6],
        screenSpaceWaterReflectionQuality = values[7],
        planarWaterReflectionQuality = values[8],
        clutter2DQuality = values[9],
        characterResolution = values[10],
        shadowQuality = values[11],
    }
end

local PerformanceModeValues = {
    ["45fps"] = {43.30, 41.00, 36.00, 0.70, "0.02222222", "45", "2", "2", "3", "0", "3"},
    ["60fps"] = {55.75, 53.00, 43.00, 2.75, "0.01666667", "60", "4", "3", "4", "3", "4"}
}

local function ResolvePerformanceProfile(modeName)
    local values = PerformanceModeValues[modeName]
    if not values then
        return nil
    end
    return BuildPerformanceProfile(values)
end

local function GetAvailablePerformanceModes()
    local names = {}
    for name in pairs(PerformanceModeValues) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

local activePerformanceModeName = "45fps"
local pendingPerformanceModeName = nil
local activePerformanceProfile = ResolvePerformanceProfile(activePerformanceModeName)

-- Runtime FPS thresholds for the active performance mode.
local targetFps
local lockTargetFps
local minAcceptableFps
local fps_stabilized

local function ApplyPerformanceProfile(modeName)
    local profile = ResolvePerformanceProfile(modeName)
    if not profile then
        return false
    end

    activePerformanceModeName = modeName
    activePerformanceProfile = profile

    targetFps = profile.targetFps
    lockTargetFps = profile.lockTargetFps
    minAcceptableFps = profile.minAcceptableFps
    fps_stabilized = profile.fpsStabilized

    return true
end

-- Initialize runtime thresholds from the default active mode.
ApplyPerformanceProfile(activePerformanceModeName)

-- FPS & time configuration - target FPS and time windows for checks
local checkInterval = 300              -- Main monitoring interval (ms)
local lockCheckInterval = 100          -- Low-FPS lock evaluation interval (ms)
local fsrSwitchDelay = 1500            -- Delay between FSR Stage 2 evaluation steps (ms)
local fsrSwitchThreshold = 5           -- Stage 1: number of windows required to trigger Stage 2
local fsrSwitchGracePeriod = 10000     -- Grace period after addon load before allowing FSR changes (ms)

-- Lock & threshold configuration - low FPS lock and unlock thresholds
local lowFpsCounter = 0
local lockThreshold = 5700             -- Time (ms) of low FPS to enter lock (~5.7s)
local unlockThreshold = 100000         -- Hard upper bound for lock duration (ms, ~100s)

-- Cooldown configuration - cooldowns for graphics adjustments
local cooldownDuration = 600           -- Cooldown for most graphics changes (ms)
local lastAdjustmentTime = 0
local viewDistanceCooldownDuration = 900
local lastViewDistanceAdjustmentTime = 0

-- Cooldown for FSR switching
local fsrSwitchCooldown = 45000        -- 45 seconds cooldown for FSR changes
local lastFsrSwitchTime = 0            -- Last time we actually changed FSR mode

-- Evaluation cooldown for FSR Stage 2 (downgrade / upgrade)
local fsrEvalCooldownUpgrade = 15000   -- 15s for upgrade evaluations
local fsrEvalCooldownDowngrade = 1000  -- 1s for downgrade evaluations
local lastFsrDowngradeEvalEndTime = 0
local lastFsrUpgradeEvalEndTime = 0

-- FSR & lock state tracking - counters and accumulated times during lock
local fsrCounter = 0
local lockResetTime = 7000             -- Time window after restore to detect relapse (ms)
local lockDuration = 0
local lockBelowTargetTime = 0
local lockBelowTargetThreshold = 0.58
local minFpsDuringLockTime = 0
local minFpsThresholdPercent = 0.30

-- FSR auto-upgrade tracking
local highFpsWindowDuration = 0          -- Total duration of current high FPS window (ms)
local highFpsAboveTargetTime = 0         -- Time spent above upgrade FPS threshold (ms)
local fsrUpgradeViewDistanceMismatchTime = 0 -- Time spent with invalid view distance during Stage 1 (ms)

-- Upgrade window configuration
local fsrUpgradeWindowDuration = 60000   -- Observation window length for upgrade (ms)
local highFpsUpgradeRatio = 0.70         -- Required ratio of time above threshold within the window
local fsrUpgradeViewDistanceGraceMs = 3000 -- Freeze Stage 1 briefly before resetting on invalid view distance

-- Runtime state flags - track current lock / restore / combat states
local combatEnded = false
local isRestoreComplete = false
local restoreEndTime = nil
local lockStartTime = nil
local lockActiveDurationMs = 0
local restoreCompleteElapsedMs = 0
local isAdjustmentLocked = false
local isRestoringVisuals = false
local isRestoringVisualsActive = false
local isLowFpsLocked = false

-- FSR evaluation state flags
local isFsrDowngradeEvaluating = false    -- True while Stage 2 downgrade evaluation is running
local isFsrUpgradeEvaluating = false      -- True while Stage 2 upgrade evaluation is running

-- Track post-downgrade Stage 2 requests within cooldown window
local lastFsrActualDowngradeTime = 0
local fsrPostDowngradeStage2BlockedCount = 0

-- Early unlock tracking while in low-FPS lock
local lockHighFpsStableTime = 0         -- Time (ms) FPS has been stable/high during lock
local earlyUnlockStableTimeMs = 12000   -- Required stable time (ms) to allow early unlock

-- Graphics setting constants - used with SetSetting() API
local SETTING_TYPE_GRAPHICS = 5
local GRAPHICS_SETTING_VIEW_DISTANCE = 1

-- FPS sampling buffers - circular buffer for smoothing FPS readings
local fpsSamples = {}
local fpsSampleIndex = 1
local fpsSampleCount = 10
local lastSmoothedFps = 0

-- Power saving / idle detection - thresholds and last-activity tracking
local powerSavingIdleThreshold = 270000
local powerSavingFpsMin = 27
local powerSavingFpsMax = 33
local lastActivityTime = 0

-- Adaptive graphics configuration - available levels for each setting
local AdaptiveSettings = {
    SHOW_ADDITIONAL_ALLY_EFFECTS = {"1", "0"},
    DISTORTION = {"1", "0"},
    GOD_RAYS = {"1", "0"},
    FSR_MODE = {"4", "3", "2", "1"},
    -- 1.28 is highest view distance, 0.56 is lowest
    viewDistanceLevels = {"1.28", "1.20", "1.12", "1.04", "0.96", "0.88", "0.80", "0.72", "0.64", "0.56"},
}

-- Current graphics indices - current level index for each adaptive setting
local currentIndex = {
    SHOW_ADDITIONAL_ALLY_EFFECTS = 1,
    DISTORTION = 1,
    GOD_RAYS = 1,
    FSR_MODE = 2, -- default to "3" (Quality)
    VIEW_DISTANCE = 1
}

-- FSR mode name mapping & order for stats and messages
local fsrModeNameMap = {
    ["4"] = "Ultra",
    ["3"] = "Quality",
    ["2"] = "Balanced",
    ["1"] = "Performance",
}

local fsrModeOrder = {"4", "3", "2", "1"}

-- Track last known FSR CVar value and internal-change flags
local lastKnownFsrValue = "3"
local fsrChangeInProgress = false       -- true when addon itself is changing FSR_MODE
local fsrWorkaroundPending = false      -- true while FSR=0 workaround is scheduled/running

local ResetFsrAutomationState

-- Session & lifetime statistics
local sessionTotalTimeMs = 0
local sessionActiveTimeMs = 0
local sessionLockTimeMs = 0
local sessionFsrTimeMs = {["4"] = 0, ["3"] = 0, ["2"] = 0, ["1"] = 0}
local nextSessionStatsThresholdMs = 15 * 60 * 1000 -- 15 minutes of total play time

local lifetimeStats = nil
local lastStatsUpdateTimeMs = 0
local monitoringStarted = false

-- Pause state. These gates only automatic tuning and effective-time statistics.
local pauseReasons = {
    loading = true,
    ui = false,
    unfocused = false,
    powerSavingProbe = false,
    powerSaving = false,
}

-- ESO power saving mode runtime state
local isPowerSavingModeActive = false
local powerSavingDetector = {
    state = "normal",
    probeTicks = 0,
    probeHits = 0,
    exitMisses = 0,
    probeSampleCount = 5,
    probeHitThreshold = 3,
    exitMissThreshold = 3,
    exitFpsMax = 35,
}

-- Passive diagnostic state. It observes actual addon-driven FSR downgrades
-- without sharing or modifying the tuning FPS buffer.
local energyDiagConfig = {
    sampleIntervalMs = 300,
    sampleCapacity = 36,
    preWindowMs = 3000,
    confirmationTimeoutMs = 1000,
    settleMs = 1500,
    postWindowMs = 3000,
    decisionGraceMs = 600,
    minSamples = 8,
    minFps = 27,
    maxFps = 33,
    minHitRatio = 0.80,
    maxAverageGain = 1.0,
    chainWindowMs = 90000,
    listPageSize = 10,
}

local energyDiag = {
    enabled = true,
    observerStarted = false,
    times = {},
    values = {},
    nextSample = 1,
    token = 0,
    pending = nil,
    chain = nil,
    contextSerial = 0,
    cleanSerial = 0,
    lastObservedFsrCode = nil,
    lastMainTickTime = 0,
    lastActivityReason = "addon-load",
}

-- Minimum warning configuration
local lastMinimumWarningTime = 0
local minimumWarningCooldownMs = 30000 -- 30 seconds cooldown for minimum setting warning

------------------------------------------------------------
-- Time & logging helpers - get timestamps and write debug logs
------------------------------------------------------------
local function GetTimeStamp()
    local time = GetGameTimeMilliseconds()
    return time
end

local function DebugLog(message)
    if not enableDebugLogging then
        return
    end

    local timestamp = GetTimeStamp()
    local elapsedTimeMs = GetGameTimeMilliseconds() - addonLoadTime
    local elapsedTimeSec = elapsedTimeMs / 1000
    local formattedTime = string.format("%.3f", elapsedTimeSec)

    -- Normalize embedded FPS values to 3 decimal places if pattern matches
    message = message:gsub("FPS：(%d+%.%d+)", function(fps)
        return string.format("FPS：%.3f", tonumber(fps))
    end)

    local logEntry = string.format("[RAPO][%s][%d] %s", formattedTime, timestamp, message)

    d(logEntry)

    if RAPO_SavedVariables and RAPO_SavedVariables.logs then
        table.insert(RAPO_SavedVariables.logs, logEntry)
        if #RAPO_SavedVariables.logs > MAX_LOG_ENTRIES then
            local numToRemove = #RAPO_SavedVariables.logs - MAX_LOG_ENTRIES
            for i = 1, numToRemove do
                table.remove(RAPO_SavedVariables.logs, 1)
            end
        end
    end
end

------------------------------------------------------------
-- FPS sampling & smoothing - maintain sliding window and smoothed FPS
------------------------------------------------------------
local function AddFpsSample(rawFps)
    -- Ignore extreme/unrealistic samples
    if rawFps <= 5 or rawFps > 200 then
        DebugLog("FPS sample out of range, ignored: " .. string.format("%.3f", rawFps))
        return
    end

    fpsSamples[fpsSampleIndex] = rawFps
    fpsSampleIndex = (fpsSampleIndex % fpsSampleCount) + 1
end

local function GetSmoothedFps()
    local sum, count = 0, 0
    for i = 1, fpsSampleCount do
        local v = fpsSamples[i]
        if v then
            sum = sum + v
            count = count + 1
        end
    end

    if count == 0 then
        local fps = GetFramerate()
        DebugLog(string.format("No FPS samples yet, using raw FPS: %.3f", fps))
        return fps
    end

    local avg = sum / count
    return avg
end

------------------------------------------------------------
-- Player activity tracking - update last active time only from actual movement
------------------------------------------------------------
local function UpdatePlayerActivity()
    if IsPlayerMoving() then
        lastActivityTime = GetGameTimeMilliseconds()
        energyDiag.lastActivityReason = "player-moving"
    end
end

------------------------------------------------------------
-- Helper: format ms as H:MMh
------------------------------------------------------------
local function FormatTimeHoursMinutes(ms)
    if not ms or ms <= 0 then
        return "0:00h"
    end
    local totalSeconds = math.floor(ms / 1000)
    local totalMinutes = math.floor(totalSeconds / 60)
    local hours = math.floor(totalMinutes / 60)
    local minutes = totalMinutes % 60
    return string.format("%d:%02dh", hours, minutes)
end

------------------------------------------------------------
-- Build stats line for chat output
------------------------------------------------------------
local function BuildStatsLine(label, totalTimeMs, activeTimeMs, lockTimeMs, fsrTimeTable, currentFsrName, currentModeName, legacyFormat)
    totalTimeMs = totalTimeMs or 0
    activeTimeMs = activeTimeMs or 0
    lockTimeMs = lockTimeMs or 0
    fsrTimeTable = fsrTimeTable or {}

    local showCurrentFsr = (label == "Session")
    local displayTimeMs = legacyFormat and activeTimeMs or totalTimeMs
    local denominatorTimeMs = activeTimeMs
    local segments = {string.format("%s %s", label, FormatTimeHoursMinutes(displayTimeMs))}

    if not legacyFormat then
        table.insert(segments, "effective " .. FormatTimeHoursMinutes(activeTimeMs))
    end

    if denominatorTimeMs > 0 then
        local lockPercent = (lockTimeMs / denominatorTimeMs) * 100.0
        table.insert(segments, string.format("lock %.1f%%", lockPercent))
    else
        table.insert(segments, "lock 0%")
    end

    local fsrSegments = {}
    if denominatorTimeMs > 0 then
        for _, mode in ipairs(fsrModeOrder) do
            local modeTime = fsrTimeTable[mode] or 0
            if modeTime > 0 then
                local percent = (modeTime / denominatorTimeMs) * 100.0
                local name = fsrModeNameMap[mode] or mode
                table.insert(fsrSegments, string.format("%s %.0f%%", name, percent))
            end
        end
    end

    if #fsrSegments > 0 then
        table.insert(segments, "FSR: " .. table.concat(fsrSegments, " / "))
    end

    if showCurrentFsr and currentFsrName and currentFsrName ~= "" then
        table.insert(segments, "Current FSR: " .. currentFsrName)
    end

    if currentModeName and currentModeName ~= "" then
        table.insert(segments, "Mode: " .. currentModeName)
    end

    return "[RAPO] " .. table.concat(segments, ", ")
end

------------------------------------------------------------
-- Initialize lifetime stats structure from SavedVariables
------------------------------------------------------------
local function CreateEmptyModeStats(includeTotalTime)
    local bucket = {
        activeTimeMs = 0,
        lockTimeMs = 0,
        fsrTimeMs = {}
    }

    if includeTotalTime then
        bucket.totalTimeMs = 0
    end

    for _, mode in ipairs(fsrModeOrder) do
        bucket.fsrTimeMs[mode] = 0
    end

    return bucket
end

local function EnsureModeStatsBucket(stats, modeName)
    stats.byMode = stats.byMode or {}
    stats.byMode[modeName] = stats.byMode[modeName] or CreateEmptyModeStats(true)

    local bucket = stats.byMode[modeName]
    bucket.totalTimeMs = bucket.totalTimeMs or 0
    bucket.activeTimeMs = bucket.activeTimeMs or 0
    bucket.lockTimeMs = bucket.lockTimeMs or 0
    bucket.fsrTimeMs = bucket.fsrTimeMs or {}

    for _, mode in ipairs(fsrModeOrder) do
        bucket.fsrTimeMs[mode] = bucket.fsrTimeMs[mode] or 0
    end

    return bucket
end

local function CreateEmptyOldStatsRoot()
    return { byMode = {} }
end

local function EnsureOldModeStatsBucket(oldStats, modeName)
    oldStats.byMode = oldStats.byMode or {}
    oldStats.byMode[modeName] = oldStats.byMode[modeName] or CreateEmptyModeStats(false)

    local bucket = oldStats.byMode[modeName]
    bucket.activeTimeMs = bucket.activeTimeMs or 0
    bucket.lockTimeMs = bucket.lockTimeMs or 0
    bucket.fsrTimeMs = bucket.fsrTimeMs or {}

    for _, mode in ipairs(fsrModeOrder) do
        bucket.fsrTimeMs[mode] = bucket.fsrTimeMs[mode] or 0
    end

    return bucket
end

local function AddStatsIntoOldBucket(oldStats, modeName, source)
    if type(source) ~= "table" then
        return
    end

    local bucket = EnsureOldModeStatsBucket(oldStats, modeName)
    bucket.activeTimeMs = (bucket.activeTimeMs or 0) + (source.activeTimeMs or 0)
    bucket.lockTimeMs = (bucket.lockTimeMs or 0) + (source.lockTimeMs or 0)

    local sourceFsr = source.fsrTimeMs or {}
    bucket.fsrTimeMs = bucket.fsrTimeMs or {}
    for _, mode in ipairs(fsrModeOrder) do
        bucket.fsrTimeMs[mode] = (bucket.fsrTimeMs[mode] or 0) + (sourceFsr[mode] or 0)
    end
end

local function HasStatsData(bucket)
    if type(bucket) ~= "table" then
        return false
    end

    if (bucket.activeTimeMs or 0) > 0 or (bucket.lockTimeMs or 0) > 0 then
        return true
    end

    local fsrTable = bucket.fsrTimeMs or {}
    for _, mode in ipairs(fsrModeOrder) do
        if (fsrTable[mode] or 0) > 0 then
            return true
        end
    end

    return false
end

local function CleanupEmptyOldStats(oldStats)
    if type(oldStats) ~= "table" or type(oldStats.byMode) ~= "table" then
        return nil
    end

    local hasAnyOldData = false
    for modeName, bucket in pairs(oldStats.byMode) do
        if HasStatsData(bucket) then
            hasAnyOldData = true
        else
            oldStats.byMode[modeName] = nil
        end
    end

    if hasAnyOldData then
        return oldStats
    end

    return nil
end

local function InitializeLifetimeStats()
    if not RAPO_SavedVariables then
        return
    end

    RAPO_SavedVariables.stats = RAPO_SavedVariables.stats or {}
    local stats = RAPO_SavedVariables.stats

    if stats.schemaVersion ~= 2 then
        local oldStats = CreateEmptyOldStatsRoot()

        if type(stats.byMode) == "table" then
            for modeName, bucket in pairs(stats.byMode) do
                AddStatsIntoOldBucket(oldStats, modeName, bucket)
            end
        end

        local hasLegacyFlatStats =
            (stats.activeTimeMs ~= nil) or
            (stats.lockTimeMs ~= nil) or
            (type(stats.fsrTimeMs) == "table")

        if hasLegacyFlatStats then
            AddStatsIntoOldBucket(oldStats, "45fps", {
                activeTimeMs = stats.activeTimeMs or 0,
                lockTimeMs = stats.lockTimeMs or 0,
                fsrTimeMs = stats.fsrTimeMs or {},
            })
        end

        stats.old = CleanupEmptyOldStats(oldStats)
        stats.byMode = {}
        stats.activeTimeMs = nil
        stats.lockTimeMs = nil
        stats.fsrTimeMs = nil
        stats.migratedToModeBuckets = true
        stats.schemaVersion = 2
    end

    for _, modeName in ipairs(GetAvailablePerformanceModes()) do
        EnsureModeStatsBucket(stats, modeName)
    end

    if type(stats.old) == "table" and type(stats.old.byMode) == "table" then
        for modeName in pairs(stats.old.byMode) do
            EnsureOldModeStatsBucket(stats.old, modeName)
            stats.old.byMode[modeName].totalTimeMs = nil
        end
    end

    stats.migratedToModeBuckets = true
    lifetimeStats = stats
end

------------------------------------------------------------
-- Reset session stats (per /reload / new session)
------------------------------------------------------------
local function ResetSessionStats()
    sessionTotalTimeMs = 0
    sessionActiveTimeMs = 0
    sessionLockTimeMs = 0
    sessionFsrTimeMs["4"] = 0
    sessionFsrTimeMs["3"] = 0
    sessionFsrTimeMs["2"] = 0
    sessionFsrTimeMs["1"] = 0
    nextSessionStatsThresholdMs = 15 * 60 * 1000
    lastStatsUpdateTimeMs = 0
end

------------------------------------------------------------
-- Pause helpers and statistics flushing
------------------------------------------------------------
local function IsRapoPaused()
    return pauseReasons.loading or pauseReasons.ui or pauseReasons.unfocused
        or pauseReasons.powerSavingProbe or pauseReasons.powerSaving
end

local function IsRapoPausedForExternalState()
    return pauseReasons.loading or pauseReasons.ui or pauseReasons.unfocused
end

local function IsViewDistanceAtMaximum()
    local maxViewDistance = tonumber(AdaptiveSettings.viewDistanceLevels[1])
    local currentViewDistance = tonumber(GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE))

    if maxViewDistance and currentViewDistance then
        return math.abs(currentViewDistance - maxViewDistance) < 0.001
    end

    return (currentIndex.VIEW_DISTANCE or 1) <= 1
end

function UserSettingsModifier:FlushStatsToNow()
    if not monitoringStarted or not lifetimeStats then
        return
    end

    local now = GetGameTimeMilliseconds()
    if lastStatsUpdateTimeMs <= 0 then
        lastStatsUpdateTimeMs = now
        return
    end

    local deltaTimeMs = now - lastStatsUpdateTimeMs
    if deltaTimeMs <= 0 then
        lastStatsUpdateTimeMs = now
        return
    end

    lastStatsUpdateTimeMs = now

    local modeStats = EnsureModeStatsBucket(lifetimeStats, activePerformanceModeName)

    -- Total play time always advances after monitoring has started.
    sessionTotalTimeMs = sessionTotalTimeMs + deltaTimeMs
    modeStats.totalTimeMs = (modeStats.totalTimeMs or 0) + deltaTimeMs

    -- Effective time and dependent buckets advance only while automatic tuning is active.
    if not IsRapoPaused() then
        sessionActiveTimeMs = sessionActiveTimeMs + deltaTimeMs
        modeStats.activeTimeMs = (modeStats.activeTimeMs or 0) + deltaTimeMs

        if isLowFpsLocked then
            sessionLockTimeMs = sessionLockTimeMs + deltaTimeMs
            modeStats.lockTimeMs = (modeStats.lockTimeMs or 0) + deltaTimeMs
        end

        local currentFsrValue = AdaptiveSettings.FSR_MODE[currentIndex.FSR_MODE]
        if currentFsrValue and sessionFsrTimeMs[currentFsrValue] then
            sessionFsrTimeMs[currentFsrValue] = sessionFsrTimeMs[currentFsrValue] + deltaTimeMs
            modeStats.fsrTimeMs[currentFsrValue] = (modeStats.fsrTimeMs[currentFsrValue] or 0) + deltaTimeMs
        end
    end

    -- 15-minute auto stats use total play time, not effective time.
    while sessionTotalTimeMs >= nextSessionStatsThresholdMs do
        local currentFsrValue = AdaptiveSettings.FSR_MODE[currentIndex.FSR_MODE]
        local currentName = fsrModeNameMap[currentFsrValue] or currentFsrValue or "Unknown"
        local line = BuildStatsLine(
            "Session",
            sessionTotalTimeMs,
            sessionActiveTimeMs,
            sessionLockTimeMs,
            sessionFsrTimeMs,
            currentName,
            activePerformanceModeName,
            false
        )
        d(line)
        DebugLog("Auto Session stats: " .. line)
        nextSessionStatsThresholdMs = nextSessionStatsThresholdMs + (15 * 60 * 1000)
    end
end

function UserSettingsModifier:SetPauseReason(reason, value)
    if pauseReasons[reason] == value then
        return
    end

    self:FlushStatsToNow()
    pauseReasons[reason] = value and true or false
    energyDiag.contextSerial = energyDiag.contextSerial + 1

    -- An external pause breaks the continuity of FPS-based wake evidence,
    -- even if it begins and ends between two 300ms monitoring ticks.
    if pauseReasons[reason]
        and (reason == "loading" or reason == "ui" or reason == "unfocused")
        and powerSavingDetector.state == "active" then
        powerSavingDetector.exitMisses = 0
    end

    DebugLog(string.format("Pause reason changed: %s=%s", tostring(reason), tostring(pauseReasons[reason])))
end

------------------------------------------------------------
-- Power saving detection - confirm entry and debounce exit around ~30 FPS
------------------------------------------------------------
function UserSettingsModifier:CancelPowerSavingProbe()
    if powerSavingDetector.state ~= "probe" then
        return
    end

    powerSavingDetector.state = "normal"
    powerSavingDetector.probeTicks = 0
    powerSavingDetector.probeHits = 0
    powerSavingDetector.exitMisses = 0
    self:SetPauseReason("powerSavingProbe", false)
    DebugLog("ESO energy saving probe canceled by an external pause state")
end

function UserSettingsModifier:UpdatePowerSavingState(fps)
    local now = GetGameTimeMilliseconds()
    local idleEnough = (now - lastActivityTime) >= powerSavingIdleThreshold
    local fpsMatchesIdleCap = fps >= powerSavingFpsMin and fps <= powerSavingFpsMax
    local fpsShowsWake = fps > powerSavingDetector.exitFpsMax

    -- Actual player movement is a definitive exit signal.
    if not idleEnough then
        local wasActive = isPowerSavingModeActive

        powerSavingDetector.state = "normal"
        powerSavingDetector.probeTicks = 0
        powerSavingDetector.probeHits = 0
        powerSavingDetector.exitMisses = 0
        isPowerSavingModeActive = false

        -- Reset both detector-owned reasons; SetPauseReason is idempotent, and
        -- no Lua event can interleave while this synchronous reset is running.
        self:SetPauseReason("powerSaving", false)
        self:SetPauseReason("powerSavingProbe", false)

        if wasActive then
            d("[RAPO] Leaving ESO energy saving mode: auto-tuning resumed.")
            DebugLog("ESO energy saving mode ended after player movement, auto-tuning resumed")
        end
        return
    end

    if powerSavingDetector.state == "normal" then
        if fpsMatchesIdleCap then
            powerSavingDetector.state = "probe"
            powerSavingDetector.probeTicks = 1
            powerSavingDetector.probeHits = 1
            powerSavingDetector.exitMisses = 0
            self:SetPauseReason("powerSavingProbe", true)
            DebugLog("ESO energy saving probe started; automatic tuning frozen during confirmation")
        end
        return
    end

    if powerSavingDetector.state == "probe" then
        powerSavingDetector.probeTicks = powerSavingDetector.probeTicks + 1
        if fpsMatchesIdleCap then
            powerSavingDetector.probeHits = powerSavingDetector.probeHits + 1
        end

        if powerSavingDetector.probeTicks >= powerSavingDetector.probeSampleCount then
            if powerSavingDetector.probeHits >= powerSavingDetector.probeHitThreshold then
                powerSavingDetector.state = "active"
                powerSavingDetector.exitMisses = 0
                isPowerSavingModeActive = true

                -- Set the confirmed reason before clearing the probe reason so
                -- automatic tuning remains continuously paused.
                self:SetPauseReason("powerSaving", true)
                self:SetPauseReason("powerSavingProbe", false)

                d("[RAPO] Entering ESO energy saving mode: auto-tuning suspended.")
                DebugLog("ESO energy saving mode confirmed (idle & FPS at or below the 30 FPS cap), auto-tuning suspended")
            else
                powerSavingDetector.state = "normal"
                powerSavingDetector.probeTicks = 0
                powerSavingDetector.probeHits = 0
                powerSavingDetector.exitMisses = 0
                self:SetPauseReason("powerSavingProbe", false)
                DebugLog("ESO energy saving probe rejected; FPS pattern was not sustained")
            end
        end
        return
    end

    -- Once confirmed, only sustained FPS above the idle cap is evidence of a
    -- wake-up. Lower FPS may be a heavy scene or hitch and must stay paused.
    if fpsShowsWake then
        powerSavingDetector.exitMisses = powerSavingDetector.exitMisses + 1
    else
        powerSavingDetector.exitMisses = 0
    end

    if powerSavingDetector.exitMisses >= powerSavingDetector.exitMissThreshold then
        powerSavingDetector.state = "normal"
        powerSavingDetector.probeTicks = 0
        powerSavingDetector.probeHits = 0
        powerSavingDetector.exitMisses = 0
        isPowerSavingModeActive = false
        self:SetPauseReason("powerSaving", false)

        d("[RAPO] Leaving ESO energy saving mode: auto-tuning resumed.")
        DebugLog("ESO energy saving mode ended after sustained FPS recovery, auto-tuning resumed")
    end
end

------------------------------------------------------------
-- Passive energy diagnostics - FSR downgrade pre/post evidence
------------------------------------------------------------
function UserSettingsModifier:GetEnergyDiagnosticStore()
    if not RAPO_SavedVariables then
        return nil
    end

    local store = RAPO_SavedVariables.fsrEnergyDiagnostics
    if type(store) ~= "table" then
        store = {schemaVersion = 1, nextId = 1, reports = {}}
        RAPO_SavedVariables.fsrEnergyDiagnostics = store
    end

    store.nextId = tonumber(store.nextId) or 1
    store.reports = type(store.reports) == "table" and store.reports or {}
    return store
end

function UserSettingsModifier:FormatEnergyDiagnosticId(id, store)
    store = store or self:GetEnergyDiagnosticStore()
    local maxId = store and math.max(0, (tonumber(store.nextId) or 1) - 1) or 0
    if store then
        for _, report in ipairs(store.reports) do
            maxId = math.max(maxId, tonumber(report.id) or 0)
        end
    end

    local width = math.max(1, #tostring(math.floor(maxId)))
    return string.format("%0" .. tostring(width) .. "d", tonumber(id) or 0)
end

function UserSettingsModifier:ResetEnergyDiagnostic(actualCode)
    energyDiag.token = energyDiag.token + 1
    energyDiag.pending = nil
    energyDiag.times = {}
    energyDiag.values = {}
    energyDiag.nextSample = 1
    energyDiag.cleanSerial = energyDiag.contextSerial
    energyDiag.lastObservedFsrCode = actualCode
        or GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)

    energyDiag.chain = nil
end

function UserSettingsModifier:IsEnergyDiagnosticBlocked()
    if pauseReasons.loading or pauseReasons.ui or pauseReasons.unfocused
        or pauseReasons.powerSavingProbe or pauseReasons.powerSaving
        or IsUnitInCombat("player") then
        return true
    end

    if IsPlayerActivated and not IsPlayerActivated() then
        return true
    end
    if IsGameCameraUIModeActive and IsGameCameraUIModeActive() then
        return true
    end
    if DoesGameHaveFocus and not DoesGameHaveFocus() then
        return true
    end

    return false
end

function UserSettingsModifier:PushEnergyDiagnosticSample(now, fps)
    if type(fps) ~= "number" or fps <= 5 or fps > 200 then
        return
    end

    local slot = energyDiag.nextSample
    energyDiag.times[slot] = now
    energyDiag.values[slot] = fps
    energyDiag.nextSample = (slot % energyDiagConfig.sampleCapacity) + 1
end

function UserSettingsModifier:GetEnergyDiagnosticStats(startTime, endTime)
    local samples, hits, total = 0, 0, 0

    for i = 1, energyDiagConfig.sampleCapacity do
        local sampleTime = energyDiag.times[i]
        local fps = energyDiag.values[i]
        if sampleTime and fps and sampleTime >= startTime and sampleTime < endTime then
            samples = samples + 1
            total = total + fps
            if fps >= energyDiagConfig.minFps and fps <= energyDiagConfig.maxFps then
                hits = hits + 1
            end
        end
    end

    return {
        samples = samples,
        hits = hits,
        average = samples > 0 and (total / samples) or 0,
    }
end

function UserSettingsModifier:IsEnergyDiagnosticWindowStable(stats)
    return stats.samples >= energyDiagConfig.minSamples
        and (stats.hits / stats.samples) >= energyDiagConfig.minHitRatio
        and stats.average >= energyDiagConfig.minFps
        and stats.average <= energyDiagConfig.maxFps
end

function UserSettingsModifier:CaptureEnergyDiagnosticEvidence(now)
    return {
        idleAgeMs = now - lastActivityTime,
        activityReason = energyDiag.lastActivityReason,
        mainTickAgeMs = energyDiag.lastMainTickTime > 0
            and (now - energyDiag.lastMainTickTime) or -1,
        detectorState = powerSavingDetector.state,
        probeTicks = powerSavingDetector.probeTicks,
        probeHits = powerSavingDetector.probeHits,
        activeFlag = isPowerSavingModeActive,
        pauseFlags = (pauseReasons.loading and "1" or "0")
            .. (pauseReasons.ui and "1" or "0")
            .. (pauseReasons.unfocused and "1" or "0")
            .. (pauseReasons.powerSavingProbe and "1" or "0")
            .. (pauseReasons.powerSaving and "1" or "0")
            .. (IsUnitInCombat("player") and "1" or "0"),
    }
end

function UserSettingsModifier:FindEnergyDiagnosticReport(id)
    local store = self:GetEnergyDiagnosticStore()
    if not store then
        return nil, nil
    end

    id = tonumber(id)
    for index, report in ipairs(store.reports) do
        if type(report) == "table" and tonumber(report.id) == id then
            return report, index
        end
    end

    return nil, nil
end

function UserSettingsModifier:BeginEnergyDiagnostic(oldIndex, newIndex, oldCode, newCode)
    if not energyDiag.enabled or newIndex <= oldIndex then
        return nil
    end

    local actualCode = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)
    local now = GetGameTimeMilliseconds()
    if energyDiag.pending then
        self:UpdateEnergyDiagnostic(now, GetFramerate())
    end

    if energyDiag.pending or energyDiag.contextSerial ~= energyDiag.cleanSerial
        or self:IsEnergyDiagnosticBlocked() or actualCode ~= oldCode then
        self:ResetEnergyDiagnostic(actualCode)
        return nil
    end

    local pre = self:GetEnergyDiagnosticStats(now - energyDiagConfig.preWindowMs, now)
    if not self:IsEnergyDiagnosticWindowStable(pre) then
        self:ResetEnergyDiagnostic(actualCode)
        return nil
    end

    energyDiag.token = energyDiag.token + 1
    energyDiag.pending = {
        token = energyDiag.token,
        oldIndex = oldIndex,
        newIndex = newIndex,
        oldCode = oldCode,
        newCode = newCode,
        pre = pre,
        switchEvidence = self:CaptureEnergyDiagnosticEvidence(now),
    }
    return energyDiag.token
end

function UserSettingsModifier:ConfirmEnergyDiagnostic(pending, now, actualCode)
    pending.confirmedAt = now
    pending.settleEnd = now + energyDiagConfig.settleMs
    pending.postEnd = pending.settleEnd + energyDiagConfig.postWindowMs
    energyDiag.lastObservedFsrCode = actualCode
end

function UserSettingsModifier:CompleteEnergyDiagnostic(token)
    local pending = energyDiag.pending
    if not pending or pending.token ~= token then
        return
    end

    local actualCode = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)
    local now = GetGameTimeMilliseconds()
    pending.confirmationDeadline = now + energyDiagConfig.confirmationTimeoutMs
    if actualCode == pending.newCode then
        self:ConfirmEnergyDiagnostic(pending, now, actualCode)
    elseif actualCode and actualCode ~= "" and actualCode ~= pending.oldCode then
        self:ResetEnergyDiagnostic(actualCode)
    end
end

function UserSettingsModifier:SaveEnergyDiagnostic(pending, post, now)
    local store = self:GetEnergyDiagnosticStore()
    if not store then
        self:ResetEnergyDiagnostic(pending.newCode)
        return
    end

    local event = {
        fromCode = pending.oldCode,
        toCode = pending.newCode,
        actualCode = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE),
        preAverage = pending.pre.average,
        preHits = pending.pre.hits,
        preSamples = pending.pre.samples,
        postAverage = post.average,
        postHits = post.hits,
        postSamples = post.samples,
        switch = pending.switchEvidence,
        after = self:CaptureEnergyDiagnosticEvidence(now),
    }

    local chain = energyDiag.chain
    local report = nil
    if chain and now - chain.completedAtMs <= energyDiagConfig.chainWindowMs
        and chain.newIndex == pending.oldIndex and chain.newCode == pending.oldCode then
        report = self:FindEnergyDiagnosticReport(chain.reportId)
    end

    if report and report.schema == "fsr-cap-v1" then
        table.insert(report.events, event)
        report.confidence = "high"
    else
        local dateText = GetDate and tostring(GetDate()) or "unknown-date"
        local timeText = GetTimeString and tostring(GetTimeString()) or "unknown-time"
        local year, month, day = dateText:match("^(%d%d%d%d)(%d%d)(%d%d)$")
        if year then
            dateText = string.format("%s-%s-%s", year, month, day)
        end
        report = {
            schema = "fsr-cap-v1",
            id = store.nextId,
            stamp = dateText .. " " .. timeText,
            world = GetWorldName and tostring(GetWorldName()) or "unknown",
            mode = activePerformanceModeName,
            status = "mismatch",
            confidence = "possible",
            events = {event},
        }
        store.nextId = store.nextId + 1
        table.insert(store.reports, report)
    end

    energyDiag.chain = {
        reportId = report.id,
        completedAtMs = now,
        newIndex = pending.newIndex,
        newCode = pending.newCode,
    }
    energyDiag.pending = nil

    local oldName = fsrModeNameMap[pending.oldCode] or pending.oldCode
    local newName = fsrModeNameMap[pending.newCode] or pending.newCode
    local reportId = self:FormatEnergyDiagnosticId(report.id, store)
    d(string.format(
        "[RAPO][Diag] Saved #%s: FSR %s -> %s, FPS %.2f -> %.2f (%s 30 FPS-cap mismatch).",
        reportId,
        oldName,
        newName,
        pending.pre.average,
        post.average,
        report.confidence
    ))
end

function UserSettingsModifier:UpdateEnergyDiagnostic(now, rawFps)
    if not energyDiag.enabled then
        return
    end

    local actualCode = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)

    if energyDiag.contextSerial ~= energyDiag.cleanSerial then
        self:ResetEnergyDiagnostic(actualCode)
    end

    if self:IsEnergyDiagnosticBlocked() then
        if energyDiag.pending or energyDiag.chain or energyDiag.times[1] then
            self:ResetEnergyDiagnostic(actualCode)
        end
        return
    end

    local pending = energyDiag.pending
    if not pending then
        if energyDiag.lastObservedFsrCode and actualCode ~= energyDiag.lastObservedFsrCode then
            self:ResetEnergyDiagnostic(actualCode)
        end
        energyDiag.lastObservedFsrCode = actualCode
        self:PushEnergyDiagnosticSample(now, rawFps)
        return
    end

    if not pending.confirmedAt then
        if now > pending.confirmationDeadline then
            self:ResetEnergyDiagnostic(actualCode)
            return
        end

        if actualCode == pending.newCode then
            self:ConfirmEnergyDiagnostic(pending, now, actualCode)
        elseif actualCode and actualCode ~= "" and actualCode ~= pending.oldCode then
            self:ResetEnergyDiagnostic(actualCode)
            return
        end

        self:PushEnergyDiagnosticSample(now, rawFps)
        return
    end

    if actualCode ~= pending.newCode or not pending.postEnd then
        self:ResetEnergyDiagnostic(actualCode)
        return
    end

    energyDiag.lastObservedFsrCode = actualCode

    if not pending.post then
        self:PushEnergyDiagnosticSample(now, rawFps)
        if now < pending.postEnd then
            return
        end

        local post = self:GetEnergyDiagnosticStats(pending.settleEnd, pending.postEnd)
        local averageGain = post.average - pending.pre.average
        if not self:IsEnergyDiagnosticWindowStable(post)
            or averageGain > energyDiagConfig.maxAverageGain then
            self:ResetEnergyDiagnostic(actualCode)
            return
        end

        -- Freeze the fixed post window, then give the main detector one tick
        -- to react before concluding that its pause path failed.
        pending.post = post
        pending.decisionDeadline = pending.postEnd + energyDiagConfig.decisionGraceMs
    end

    if energyDiag.lastMainTickTime >= pending.postEnd
        or now >= pending.decisionDeadline then
        self:SaveEnergyDiagnostic(pending, pending.post, now)
    end
end

function UserSettingsModifier:RunEnergyDiagnosticTick(now, rawFps)
    if not energyDiag.enabled then
        return
    end

    local ok, err = pcall(self.UpdateEnergyDiagnostic, self, now, rawFps)
    if not ok then
        self:DisableEnergyDiagnostic("runtime", err)
    end
end

function UserSettingsModifier:DisableEnergyDiagnostic(phase, err)
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "EnergyDiag")
    energyDiag.enabled = false
    energyDiag.observerStarted = false
    energyDiag.pending = nil
    energyDiag.chain = nil
    DebugLog("Passive energy diagnostic disabled after " .. tostring(phase) .. " error: " .. tostring(err))
end

function UserSettingsModifier:StartEnergyDiagnosticObserver()
    if energyDiag.observerStarted or not energyDiag.enabled then
        return
    end

    energyDiag.observerStarted = true
    EVENT_MANAGER:RegisterForUpdate(self.name .. "EnergyDiag", energyDiagConfig.sampleIntervalMs, function()
        self:RunEnergyDiagnosticTick(GetGameTimeMilliseconds(), GetFramerate())
    end)
    DebugLog("Independent passive energy diagnostic observer started")
end

------------------------------------------------------------
-- Statistics update: compatibility wrapper for older call sites
------------------------------------------------------------
function UserSettingsModifier:UpdateStatistics(fps, deltaTimeMs)
    self:FlushStatsToNow()
end

------------------------------------------------------------
-- Output Session stats on demand
------------------------------------------------------------
function UserSettingsModifier:OutputSessionStats()
    self:FlushStatsToNow()

    local currentFsrValue = AdaptiveSettings.FSR_MODE[currentIndex.FSR_MODE]
    local currentName = fsrModeNameMap[currentFsrValue] or currentFsrValue or "Unknown"
    local line = BuildStatsLine(
        "Session",
        sessionTotalTimeMs,
        sessionActiveTimeMs,
        sessionLockTimeMs,
        sessionFsrTimeMs,
        currentName,
        activePerformanceModeName,
        false
    )
    d(line)
    DebugLog("Manual Session stats: " .. line)
end

------------------------------------------------------------
-- Output Lifetime stats on demand
------------------------------------------------------------
function UserSettingsModifier:OutputLifetimeStats()
    self:FlushStatsToNow()

    if not lifetimeStats or not lifetimeStats.byMode then
        local line = BuildStatsLine(
            "Lifetime",
            0,
            0,
            0,
            {},
            nil,
            activePerformanceModeName,
            false
        )
        d(line)
        DebugLog("Lifetime stats requested but no lifetimeStats available")
        return
    end

    local modeStats = lifetimeStats.byMode[activePerformanceModeName]
    if not modeStats then
        local line = BuildStatsLine(
            "Lifetime",
            0,
            0,
            0,
            {},
            nil,
            activePerformanceModeName,
            false
        )
        d(line)
        DebugLog("Lifetime stats requested but mode bucket missing: " .. tostring(activePerformanceModeName))
        return
    end

    local line = BuildStatsLine(
        "Lifetime",
        modeStats.totalTimeMs or 0,
        modeStats.activeTimeMs or 0,
        modeStats.lockTimeMs or 0,
        modeStats.fsrTimeMs or {},
        nil,
        activePerformanceModeName,
        false
    )
    d(line)
    DebugLog("Lifetime stats: " .. line)
end

------------------------------------------------------------
-- Output old stats for current active mode only
------------------------------------------------------------
function UserSettingsModifier:OutputOldStats()
    self:FlushStatsToNow()

    if not lifetimeStats or not lifetimeStats.old or not lifetimeStats.old.byMode then
        return
    end

    local oldStats = lifetimeStats.old.byMode[activePerformanceModeName]
    if not HasStatsData(oldStats) then
        return
    end

    local line = BuildStatsLine(
        "Old",
        nil,
        oldStats.activeTimeMs or 0,
        oldStats.lockTimeMs or 0,
        oldStats.fsrTimeMs or {},
        nil,
        activePerformanceModeName,
        true
    )
    d(line)
    DebugLog("Old stats: " .. line)
end

------------------------------------------------------------
-- Minimum warning at lowest settings with cooldown
------------------------------------------------------------
function UserSettingsModifier:CheckMinimumWarning(fps)
    local now = GetGameTimeMilliseconds()

    -- 30-second cooldown
    if now - lastMinimumWarningTime < minimumWarningCooldownMs then
        return
    end

    -- Only when low-FPS lock is active (we assume minimum visuals)
    if not isLowFpsLocked then
        return
    end

    -- FSR must be at lowest mode ("1" = Performance)
    if currentIndex.FSR_MODE < #AdaptiveSettings.FSR_MODE then
        return
    end

    -- FPS still below minimum acceptable threshold
    if fps >= minAcceptableFps then
        return
    end

    lastMinimumWarningTime = now
    d("[RAPO] Warning: running at minimum visuals/FSR, performance may still be limited.")
    DebugLog("Minimum visuals/FSR warning triggered due to sustained low FPS at minimum settings")
end

------------------------------------------------------------
-- FSR eval cooldown helpers
------------------------------------------------------------
local function CanStartFsrDowngradeEval()
    local now = GetGameTimeMilliseconds()
    if lastFsrDowngradeEvalEndTime > 0 then
        local elapsed = now - lastFsrDowngradeEvalEndTime
        if elapsed < fsrEvalCooldownDowngrade then
            local remaining = fsrEvalCooldownDowngrade - elapsed
            local remainingPct = (remaining / fsrEvalCooldownDowngrade) * 100.0
            DebugLog(string.format(
                "FSR Stage 2 downgrade evaluation on cooldown, skipping (remaining %.0fms, %.0f%% of cooldown left)",
                remaining, remainingPct
            ))
            return false
        end
    end
    return true
end

local function CanStartFsrUpgradeEval()
    local now = GetGameTimeMilliseconds()
    if lastFsrUpgradeEvalEndTime > 0 then
        local elapsed = now - lastFsrUpgradeEvalEndTime
        if elapsed < fsrEvalCooldownUpgrade then
            local remaining = fsrEvalCooldownUpgrade - elapsed
            local remainingPct = (remaining / fsrEvalCooldownUpgrade) * 100.0
            DebugLog(string.format(
                "FSR Stage 2 upgrade evaluation on cooldown, skipping (remaining %.0fms, %.0f%% of cooldown left)",
                remaining, remainingPct
            ))
            return false
        end
    end
    return true
end

------------------------------------------------------------
-- Resolution helper - clamp to safe 1920x1080 / 1920x1200 for handheld
------------------------------------------------------------
local function EnsureSafeResolutionForHandheld()
    local widthStr = GetCVar("FullscreenWidth")
    local heightStr = GetCVar("FullscreenHeight")

    local width = tonumber(widthStr)
    local height = tonumber(heightStr)

    if not width or not height or width <= 0 or height <= 0 then
        -- Fallback to 1920x1080 if values are invalid
        width, height = 1920, 1080
        SetCVar("FullscreenWidth", tostring(width))
        SetCVar("FullscreenHeight", tostring(height))
        DebugLog("Resolution invalid, set to safe default 1920x1080")
        return
    end

    local longSide = math.max(width, height)
    local shortSide = math.min(width, height)
    local aspect = longSide / shortSide

    local aspect16_9 = 16 / 9
    local aspect16_10 = 16 / 10
    local function isClose(a, b)
        return math.abs(a - b) < 0.05
    end

    -- Within safe range and aspect: respect player setting
    if longSide <= 1920 and (isClose(aspect, aspect16_9) or isClose(aspect, aspect16_10)) then
        DebugLog("Resolution within safe handheld range, kept as: " .. width .. "x" .. height)
        return
    end

    -- Only actively clamp down when long side is above 1920
    if longSide <= 1920 then
        DebugLog("Non-standard aspect but <=1920, keeping resolution as: " .. width .. "x" .. height)
        return
    end

    local targetLong, targetShort
    if isClose(aspect, aspect16_9) then
        targetLong, targetShort = 1920, 1080
    elseif isClose(aspect, aspect16_10) then
        targetLong, targetShort = 1920, 1200
    else
        -- Fallback: clamp to 1920x1080 for odd aspects on handheld
        targetLong, targetShort = 1920, 1080
    end

    local newWidth, newHeight
    if width >= height then
        newWidth, newHeight = targetLong, targetShort
    else
        newWidth, newHeight = targetShort, targetLong
    end

    if newWidth ~= width or newHeight ~= height then
        DebugLog(string.format("Resolution adjusted for handheld: %dx%d -> %dx%d", width, height, newWidth, newHeight))
        SetCVar("FullscreenWidth", tostring(newWidth))
        SetCVar("FullscreenHeight", tostring(newHeight))
    else
        DebugLog("Resolution already at safe clamped value: " .. newWidth .. "x" .. newHeight)
    end
end

------------------------------------------------------------
-- FSR=0 workaround - single delayed SetSetting after 500ms
------------------------------------------------------------
function UserSettingsModifier:ScheduleFsrReenable(defaultCode)
    if fsrWorkaroundPending then
        DebugLog("FSR=0 workaround already pending, skipping re-schedule")
        return
    end

    fsrWorkaroundPending = true
    defaultCode = defaultCode or "3"

    local function ApplyStep()
        if IsRapoPaused() then
            zo_callLater(ApplyStep, 500)
            return
        end

        -- The delayed intent may be stale after a pause. Do not overwrite a
        -- valid FSR mode the player selected while the callback was frozen.
        local currentCode = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)
        if currentCode and currentCode ~= "" and currentCode ~= "0" then
            fsrWorkaroundPending = false
            DebugLog("FSR_MODE workaround canceled because FSR is no longer off: " .. tostring(currentCode))
            return
        end

        -- Mark as internal change so sync logic knows this is addon-driven
        fsrChangeInProgress = true

        -- Restore a supported FSR mode through the graphics setting system
        SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE, defaultCode)

        -- This is a recovery write, not an automatic downgrade candidate.
        pcall(self.ResetEnergyDiagnostic, self, defaultCode)

        ResetFsrAutomationState(true)

        DebugLog("FSR_MODE workaround: restored default FSR mode to " .. tostring(defaultCode))

        -- Sync index to default code
        for i, code in ipairs(AdaptiveSettings.FSR_MODE) do
            if code == defaultCode then
                currentIndex.FSR_MODE = i
                break
            end
        end

        lastKnownFsrValue = defaultCode

        fsrWorkaroundPending = false
    end

    -- Single delayed write to avoid potential rendering hitches
    zo_callLater(ApplyStep, 500)
    DebugLog("FSR_MODE=0 workaround scheduled (single delayed SetSetting after 500ms)")
end

------------------------------------------------------------
-- Sync current indices with actual game CVars / Settings
-- This keeps addon state consistent with manual user changes.
-- Now rate-limited to at most once every 2 seconds.
------------------------------------------------------------
function UserSettingsModifier:SyncCurrentIndicesFromGame()
    -- Rate-limit full sync to avoid doing it every monitoring tick
    local now = GetGameTimeMilliseconds()
    local last = self._lastGraphicsSyncTime or 0
    local graphicsSyncIntervalMs = 2000  -- Run at most once every 2 seconds.

    if now - last < graphicsSyncIntervalMs then
        return
    end
    self._lastGraphicsSyncTime = now

    -- Read FSR mode from the graphics setting system
    local fsrValue = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)
    local idxMap = {["4"] = 1, ["3"] = 2, ["2"] = 3, ["1"] = 4}

    -- Player turned FSR off manually (FSR_MODE=0)
    if fsrValue == "0" then
        if not fsrWorkaroundPending then
            d("[RAPO] FSR off is not supported on handheld. Quality restoration scheduled for performance stability.")
            DebugLog("Detected FSR_MODE=0 (off). Scheduling workaround to restore default FSR mode.")
            -- Schedule delayed re-enable to avoid rendering issues
            self:ScheduleFsrReenable("3")
        end
        -- Keep currentIndex.FSR_MODE pointing at our default while workaround runs
        return
    end

    local idx = idxMap[fsrValue]
    if idx then
        local now2 = GetGameTimeMilliseconds()
        local withinGrace = (addonLoadTime > 0) and ((now2 - addonLoadTime) < fsrSwitchGracePeriod)

        if fsrChangeInProgress then
            -- Internal change from addon: just synchronize, no user-facing message
            currentIndex.FSR_MODE = idx
            lastKnownFsrValue = fsrValue
            fsrChangeInProgress = false
            DebugLog("FSR_MODE synchronized after internal change: " .. fsrValue)
        else
            -- Possible external change observed by sync layer
            local oldCode = lastKnownFsrValue
            if oldCode ~= fsrValue then
                -- Manual/startup changes break passive diagnostic continuity.
                pcall(self.ResetEnergyDiagnostic, self, fsrValue)

                local oldName = fsrModeNameMap[oldCode] or oldCode or "Unknown"
                local newName = fsrModeNameMap[fsrValue] or fsrValue

                if withinGrace then
                    -- Startup initialization is reported directly in ApplyStaticSettings().
                    -- During grace, sync should remain silent to avoid duplicate or misleading output.
                    DebugLog(string.format(
                        "Startup-sync FSR_MODE change detected during grace period: %s (%s) -> %s (%s)",
                        tostring(oldCode), oldName, fsrValue, newName
                    ))
                else
                    d(string.format("[RAPO] FSR mode changed manually: %s → %s (user override).", oldName, newName))
                    DebugLog(string.format(
                        "Detected manual FSR_MODE change: %s (%s) -> %s (%s)",
                        tostring(oldCode), oldName, fsrValue, newName
                    ))

                    -- Treat manual override as a real FSR switch and rebuild automation from this new baseline.
                    ResetFsrAutomationState(true)
                end
            end

            currentIndex.FSR_MODE = idx
            lastKnownFsrValue = fsrValue
        end
    end

    -- Ally effects (1 = enabled, 0 = disabled)
    local ally = GetCVar("SHOW_ADDITIONAL_ALLY_EFFECTS")
    if ally == "1" then
        currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = 1
    else
        currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = #AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS
    end

    -- Distortion
    local dist = GetCVar("DISTORTION")
    if dist == "1" then
        currentIndex.DISTORTION = 1
    else
        currentIndex.DISTORTION = #AdaptiveSettings.DISTORTION
    end

    -- God rays
    local rays = GetCVar("GOD_RAYS")
    if rays == "1" then
        currentIndex.GOD_RAYS = 1
    else
        currentIndex.GOD_RAYS = #AdaptiveSettings.GOD_RAYS
    end

    -- View distance: snap to nearest predefined level
    local vdStr = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE)
    local vd = tonumber(vdStr)
    if vd then
        local bestIndex = currentIndex.VIEW_DISTANCE or 1
        local bestDiff = nil
        for i, levelStr in ipairs(AdaptiveSettings.viewDistanceLevels) do
            local level = tonumber(levelStr)
            if level then
                local diff = math.abs(level - vd)
                if not bestDiff or diff < bestDiff then
                    bestDiff = diff
                    bestIndex = i
                end
            end
        end
        currentIndex.VIEW_DISTANCE = bestIndex
    end
end

------------------------------------------------------------
-- Low FPS lock management - enter/exit low-FPS lock and drive lock state
------------------------------------------------------------
function UserSettingsModifier:ManageLockState(fps)
    -- Skip lock management while restoration is actively running
    if isRestoringVisualsActive then
        DebugLog("Visual restoration in progress, skipping low FPS lock check")
        return
    end

    local currentTime = GetGameTimeMilliseconds()

    -- Post-restore relapse detection advances only while automatic tuning is active.
    if isRestoreComplete then
        restoreCompleteElapsedMs = restoreCompleteElapsedMs + checkInterval

        if restoreCompleteElapsedMs <= lockResetTime then
            if fps < targetFps - fps_stabilized then
                fsrCounter = fsrCounter + 3
                isRestoreComplete = false
                restoreEndTime = nil
                restoreCompleteElapsedMs = 0
                DebugLog("FPS dropped below target within 7 seconds of restoration, FSR counter increased to: " .. fsrCounter)
            end
        else
            isRestoreComplete = false
            restoreEndTime = nil
            restoreCompleteElapsedMs = 0
            DebugLog("Post-restore relapse window expired, clearing restoration completion state")
        end
    end

    if isLowFpsLocked then
        lockActiveDurationMs = lockActiveDurationMs + checkInterval

        -- Hard upper bound on lock duration (safety net), counted in effective tuning time.
        if lockActiveDurationMs >= unlockThreshold then
            isLowFpsLocked = false
            lockHighFpsStableTime = 0
            self:UpdateLowFpsLockState()
            DebugLog("Low FPS lock released by hard timeout, starting view distance restoration")
            return
        end

        -- Track how long FPS has been stable/high during lock
        if fps >= targetFps - fps_stabilized then
            lockHighFpsStableTime = lockHighFpsStableTime + checkInterval
        else
            lockHighFpsStableTime = 0
        end

        -- Early unlock: only when no FSR Stage 2 downgrade evaluation is running
        if (not isFsrDowngradeEvaluating) and lockHighFpsStableTime >= earlyUnlockStableTimeMs then
            isLowFpsLocked = false
            lockHighFpsStableTime = 0
            self:UpdateLowFpsLockState()
            DebugLog("Low FPS lock early released due to stable FPS above threshold")
            return
        end

        -- Stage 1/2 evaluation is driven by StartLockMonitoring -> EvaluateLowFpsWindowForDowngrade
    else
        -- Reset early-unlock accumulation while not in lock
        lockHighFpsStableTime = 0

        -- Accumulate low-FPS time to enter lock
        if fps < targetFps - fps_stabilized then
            lowFpsCounter = lowFpsCounter + checkInterval

            if lowFpsCounter >= lockThreshold then
                isLowFpsLocked = true
                isRestoringVisualsActive = false
                isRestoreComplete = false
                restoreEndTime = nil
                restoreCompleteElapsedMs = 0
                lockStartTime = currentTime
                lockActiveDurationMs = 0
                lockHighFpsStableTime = 0
                self:UpdateLowFpsLockState()
                DebugLog("Low FPS lock triggered, applying minimum quality settings")
            end
        else
            lowFpsCounter = 0
        end
    end
end

------------------------------------------------------------
-- Apply low-FPS lock state (enter/exit) and trigger restoration
------------------------------------------------------------
function UserSettingsModifier:UpdateLowFpsLockState()
    if isLowFpsLocked then
        isRestoreComplete = false
        restoreEndTime = nil
        restoreCompleteElapsedMs = 0
        self:SetLowestSettings(IsUnitInCombat("player"))
        self:StartLockMonitoring()
        DebugLog("Low FPS lock enabled, applying minimum quality settings")
    else
        self:StopLockMonitoring()
        lockActiveDurationMs = 0
        isRestoreComplete = false
        restoreEndTime = nil
        restoreCompleteElapsedMs = 0
        self:GraduallyRestoreViewDistance()
        DebugLog("Low FPS lock disabled, starting gradual view distance restoration")
    end
end

------------------------------------------------------------
-- Lock monitoring loop - detailed per-lock FPS evaluation (Stage 1)
------------------------------------------------------------
function UserSettingsModifier:StartLockMonitoring()
    EVENT_MANAGER:RegisterForUpdate(self.name .. "LockFPS", lockCheckInterval, function()
        self:FlushStatsToNow()

        if IsRapoPaused() then
            return
        end

        local rawFps = GetFramerate()
        AddFpsSample(rawFps)
        local fps = GetSmoothedFps()
        lastSmoothedFps = fps

        self:EvaluateLowFpsWindowForDowngrade(fps, lockCheckInterval)
    end)
    DebugLog("Lock monitoring started")
end

function UserSettingsModifier:StopLockMonitoring()
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "LockFPS")
    DebugLog("Lock monitoring stopped")
end

------------------------------------------------------------
-- FSR mode control - shared gate for both FSR downgrade and upgrade
------------------------------------------------------------
local function CanSwitchFsr()
    local now = GetGameTimeMilliseconds()

    -- Optional grace period after addon load
    if addonLoadTime > 0 and (now - addonLoadTime) < fsrSwitchGracePeriod then
        DebugLog("Within FSR switch grace period after addon load, skipping FSR mode change")
        return false
    end

    -- Global cooldown for both FSR downgrade and upgrade
    if lastFsrSwitchTime > 0 and (now - lastFsrSwitchTime) < fsrSwitchCooldown then
        local elapsed = now - lastFsrSwitchTime
        local remaining = fsrSwitchCooldown - elapsed
        local remainingPct = (remaining / fsrSwitchCooldown) * 100.0
        DebugLog(string.format(
            "FSR switch on cooldown, skipping (remaining %.0fms, %.0f%% of cooldown left)",
            remaining, remainingPct
        ))
        return false
    end

    return true
end

------------------------------------------------------------
-- Reset FSR automation state after any real FSR mode change
-- (addon-driven or manual override)
------------------------------------------------------------
ResetFsrAutomationState = function(markAsRecentSwitch)
    local now = GetGameTimeMilliseconds()

    -- Reset low-FPS lock entry accumulation so a new FSR mode starts from a clean baseline.
    lowFpsCounter = 0
    lockHighFpsStableTime = 0
    lockActiveDurationMs = 0
    restoreCompleteElapsedMs = 0

    -- Reset Stage 1 downgrade window state
    lockDuration = 0
    lockBelowTargetTime = 0
    minFpsDuringLockTime = 0
    fsrCounter = 0

    -- Reset Stage 1 upgrade window state
    highFpsWindowDuration = 0
    highFpsAboveTargetTime = 0
    fsrUpgradeViewDistanceMismatchTime = 0

    -- Cancel any in-flight Stage 2 evaluation callbacks
    if isFsrDowngradeEvaluating then
        DebugLog("Cancelling in-flight FSR Stage 2 downgrade evaluation due to FSR mode change")
    end
    if isFsrUpgradeEvaluating then
        DebugLog("Cancelling in-flight FSR Stage 2 upgrade evaluation due to FSR mode change")
    end
    isFsrDowngradeEvaluating = false
    isFsrUpgradeEvaluating = false

    -- Clear post-downgrade forced-switch bookkeeping
    lastFsrActualDowngradeTime = 0
    fsrPostDowngradeStage2BlockedCount = 0

    -- Treat this as a fresh baseline so automation does not react immediately
    if markAsRecentSwitch then
        lastFsrSwitchTime = now
        lastFsrDowngradeEvalEndTime = now
        lastFsrUpgradeEvalEndTime = now
    end
end

------------------------------------------------------------
-- Apply FSR mode index change and reset related timers
------------------------------------------------------------
local function ApplyFsrIndexChange(newIndex)
    if IsRapoPaused() then
        DebugLog("FSR mode change blocked because automatic tuning is paused")
        return
    end

    if newIndex == currentIndex.FSR_MODE then
        return
    end

    if newIndex < 1 or newIndex > #AdaptiveSettings.FSR_MODE then
        return
    end

    local oldIndex = currentIndex.FSR_MODE or 0
    local oldCode = AdaptiveSettings.FSR_MODE[oldIndex]
    local oldName = oldCode and (fsrModeNameMap[oldCode] or oldCode) or nil
    local newCode = AdaptiveSettings.FSR_MODE[newIndex]
    local diagnosticToken = nil

    if energyDiag.enabled and newIndex > oldIndex then
        local ok, result = pcall(
            UserSettingsModifier.BeginEnergyDiagnostic,
            UserSettingsModifier,
            oldIndex,
            newIndex,
            oldCode,
            newCode
        )
        if ok then
            diagnosticToken = result
        else
            UserSettingsModifier:DisableEnergyDiagnostic("prepare", result)
        end
    end

    currentIndex.FSR_MODE = newIndex
    local newName = fsrModeNameMap[newCode] or newCode

    -- Mark as internal change so SyncCurrentIndicesFromGame will treat this as addon-driven
    fsrChangeInProgress = true

    -- Use the official graphics setting to switch FSR mode
    SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE, newCode)

    if diagnosticToken then
        local ok, err = pcall(
            UserSettingsModifier.CompleteEnergyDiagnostic,
            UserSettingsModifier,
            diagnosticToken
        )
        if not ok then
            UserSettingsModifier:DisableEnergyDiagnostic("completion", err)
        end
    elseif energyDiag.enabled and newIndex < oldIndex then
        pcall(UserSettingsModifier.ResetEnergyDiagnostic, UserSettingsModifier, newCode)
    end

    -- Reset all automation state so the new FSR mode becomes the fresh baseline
    ResetFsrAutomationState(true)

    lastKnownFsrValue = newCode

    DebugLog("FSR mode changed to: " .. tostring(newCode) .. " (via SetSetting)")

    -- User-facing notification for FSR changes (automatic)
    if oldName then
        if newIndex > oldIndex then
            d(string.format("[RAPO] FSR down: %s → %s (sustained low FPS).", oldName, newName))
        elseif newIndex < oldIndex then
            d(string.format("[RAPO] FSR up: %s → %s (stable high FPS).", oldName, newName))
        end
    end
end
------------------------------------------------------------
-- Stage 1 (downgrade): low-FPS window statistics under low-FPS lock
------------------------------------------------------------
function UserSettingsModifier:EvaluateLowFpsWindowForDowngrade(fps, deltaTime)
    -- Pause freezes Stage 1 without canceling any in-flight Stage 2 evaluation.
    if IsRapoPaused() then
        return
    end

    -- Ignore obviously invalid samples
    if fps < 20 then
        return
    end

    -- If we are not currently in low-FPS lock, clear statistics for this window and exit
    if not isLowFpsLocked then
        lockDuration = 0
        lockBelowTargetTime = 0
        minFpsDuringLockTime = 0
        fsrCounter = 0
        return
    end

    -- When already at the lowest FSR mode, fully skip downgrade evaluation
    -- Do not accumulate fsrCounter and do not enter Stage 2
    if currentIndex.FSR_MODE >= #AdaptiveSettings.FSR_MODE then
        lockDuration = 0
        lockBelowTargetTime = 0
        minFpsDuringLockTime = 0
        fsrCounter = 0
        return
    end

    local windowLimit = lockThreshold

    lockDuration = lockDuration + deltaTime

    if fps < lockTargetFps then
        lockBelowTargetTime = lockBelowTargetTime + deltaTime
    end

    if fps < minAcceptableFps then
        minFpsDuringLockTime = minFpsDuringLockTime + deltaTime
    end

    local elapsed   = lockDuration
    local badLock   = lockBelowTargetTime
    local badMin    = minFpsDuringLockTime
    local remaining = windowLimit - elapsed

    local lockThresholdTime = windowLimit * lockBelowTargetThreshold
    local minThresholdTime  = windowLimit * minFpsThresholdPercent

    local windowCompleted = false
    local success = false

    -- Stage 1: accumulate evidence for downgrade
    if badLock >= lockThresholdTime then
        fsrCounter = fsrCounter + 2
        success = true
    end

    if badMin >= minThresholdTime then
        fsrCounter = fsrCounter + 3
        success = true
    end

    if success then
        windowCompleted = true
    else
        -- End window early if it's impossible to reach thresholds even in the best case
        if remaining <= 0 or
           ((badLock + math.max(remaining, 0)) < lockThresholdTime and
            (badMin  + math.max(remaining, 0)) < minThresholdTime) then
            windowCompleted = true
        end
    end

    if windowCompleted then
        local elapsedPct = math.min(100.0, (elapsed / windowLimit) * 100.0)
        local badLockPct = (badLock / windowLimit) * 100.0
        local badMinPct  = (badMin / windowLimit) * 100.0
        local lockThresholdPercent = lockBelowTargetThreshold * 100.0
        local minThresholdPercent  = minFpsThresholdPercent * 100.0

        DebugLog(string.format(
            "Low FPS window summary: elapsed=%.0fms (%.0f%%), badLock=%.0fms (%.0f%% / %.0f%% needed), badMin=%.0fms (%.0f%% / %.0f%% needed), fsrCounter=%d/%d",
            elapsed, elapsedPct,
            badLock, badLockPct, lockThresholdPercent,
            badMin, badMinPct, minThresholdPercent,
            fsrCounter, fsrSwitchThreshold
        ))

        lockDuration = 0
        lockBelowTargetTime = 0
        minFpsDuringLockTime = 0
    end

    -- Only when not at the lowest FSR mode and fsrCounter reaches the threshold,
    -- we consider entering Stage 2
    if fsrCounter >= fsrSwitchThreshold then
        local now = GetGameTimeMilliseconds()
        local canEval   = CanStartFsrDowngradeEval()
        local canSwitch = CanSwitchFsr()

        if canEval and canSwitch then
            DebugLog("FSR counter threshold reached, starting Stage 2 downgrade evaluation")
            self:StartFsrDowngradeStage2()
        else
            DebugLog("FSR counter threshold reached but FSR evaluation or switch is on cooldown, skipping downgrade in this window")

            -- After the first downgrade, if Stage 2 is triggered twice during the FSR switch cooldown but gets blocked by the cooldown each time,
            -- then force another downgrade and reset the cooldown.
            if canEval and not canSwitch
               and lastFsrActualDowngradeTime > 0
               and (now - lastFsrActualDowngradeTime) <= fsrSwitchCooldown then

                fsrPostDowngradeStage2BlockedCount = fsrPostDowngradeStage2BlockedCount + 1
                DebugLog("FSR Stage 2 downgrade request blocked during cooldown, count=" .. fsrPostDowngradeStage2BlockedCount)

                if fsrPostDowngradeStage2BlockedCount >= 2 then
                    DebugLog("FSR cooldown overridden due to repeated Stage 2 requests, applying forced second downgrade")
                    self:ApplyFsrDowngradeOnce()
                    -- Inside ApplyFsrDowngradeOnce, lastFsrActualDowngradeTime and fsrPostDowngradeStage2BlockedCount will be reset.
                end
            end
        end

        fsrCounter = 0
        lockDuration = 0
        lockBelowTargetTime = 0
        minFpsDuringLockTime = 0
    end
end

------------------------------------------------------------
-- Stage 2 (downgrade): second evaluation window depending on combat / non-combat
------------------------------------------------------------
function UserSettingsModifier:StartFsrDowngradeStage2()
    -- Do not start Stage 2 while automatic tuning is paused. Existing Stage 2 callbacks freeze instead of canceling.
    if IsRapoPaused() then
        return
    end

    -- Prevent double triggering if already evaluating
    if isFsrDowngradeEvaluating then
        return
    end

    -- Shared cooldown and load grace
    if not CanSwitchFsr() then
        return
    end

    if currentIndex.FSR_MODE >= #AdaptiveSettings.FSR_MODE then
        DebugLog("Already at the lowest FSR mode, cannot decrease further")
        return
    end

    -- Mark that FSR downgrade evaluation is currently running
    isFsrDowngradeEvaluating = true

    local retryCount = 0
    local lockTargetFpsDuration = 0
    local minAcceptableFpsDuration = 0

    local maxRetriesCombat    = 17
    local maxRetriesNonCombat = 12
    local maxRetries          = nil

    local function CheckAndSwitchFSR()
        if not isFsrDowngradeEvaluating then
            return
        end

        if IsRapoPaused() then
            DebugLog("Automatic tuning paused, freezing FSR Stage 2 downgrade evaluation")
            zo_callLater(CheckAndSwitchFSR, fsrSwitchDelay)
            return
        end

        local inCombat = IsUnitInCombat("player")

        if maxRetries == nil then
            if inCombat then
                maxRetries = maxRetriesCombat
            else
                maxRetries = maxRetriesNonCombat
            end
        end

        retryCount = retryCount + 1

        -- Use last smoothed FPS; if not initialized, fallback once
        local fps = lastSmoothedFps
        if fps == 0 then
            fps = GetSmoothedFps()
            lastSmoothedFps = fps
        end

        if fps < lockTargetFps then
            lockTargetFpsDuration = lockTargetFpsDuration + fsrSwitchDelay
        end

        if fps < minAcceptableFps then
            minAcceptableFpsDuration = minAcceptableFpsDuration + fsrSwitchDelay
        end

        local totalWindow = fsrSwitchDelay * maxRetries
        local elapsed     = retryCount * fsrSwitchDelay
        local remaining   = totalWindow - elapsed

        local lockThresholdTime = totalWindow * lockBelowTargetThreshold
        local minThresholdTime  = totalWindow * minFpsThresholdPercent

        local badLock = lockTargetFpsDuration
        local badMin  = minAcceptableFpsDuration

        -- Conditions satisfied for FSR downgrade
        if badLock >= lockThresholdTime or badMin >= minThresholdTime then
            local badLockPct = (badLock / totalWindow) * 100.0
            local badMinPct  = (badMin / totalWindow) * 100.0
            local lockThresholdPercent = lockBelowTargetThreshold * 100.0
            local minThresholdPercent  = minFpsThresholdPercent * 100.0

            DebugLog(string.format(
                "FSR Stage 2 downgrade summary (down): window=%.0fms, belowLock=%.0fms (%.0f%% / %.0f%% needed), belowMin=%.0fms (%.0f%% / %.0f%% needed), retries=%d/%d",
                totalWindow,
                badLock, badLockPct, lockThresholdPercent,
                badMin, badMinPct, minThresholdPercent,
                retryCount, maxRetries
            ))

            self:ApplyFsrDowngradeOnce()
            isFsrDowngradeEvaluating = false
            lastFsrDowngradeEvalEndTime = GetGameTimeMilliseconds()
            return
        end

        local worstCaseLock = badLock + math.max(remaining, 0)
        local worstCaseMin  = badMin  + math.max(remaining, 0)

        -- If impossible to reach thresholds or window exhausted, abort evaluation
        if remaining <= 0 or (worstCaseLock < lockThresholdTime and worstCaseMin < minThresholdTime) then
            local badLockPct = (badLock / totalWindow) * 100.0
            local badMinPct  = (badMin / totalWindow) * 100.0
            local lockThresholdPercent = lockBelowTargetThreshold * 100.0
            local minThresholdPercent  = minFpsThresholdPercent * 100.0

            DebugLog(string.format(
                "FSR Stage 2 downgrade summary (keep): window=%.0fms, belowLock=%.0fms (%.0f%% / %.0f%% needed), belowMin=%.0fms (%.0f%% / %.0f%% needed), retries=%d/%d",
                totalWindow,
                badLock, badLockPct, lockThresholdPercent,
                badMin, badMinPct, minThresholdPercent,
                retryCount, maxRetries
            ))

            isFsrDowngradeEvaluating = false
            lastFsrDowngradeEvalEndTime = GetGameTimeMilliseconds()
            return
        end

        if retryCount < maxRetries then
            zo_callLater(CheckAndSwitchFSR, fsrSwitchDelay)
        else
            local badLockPct = (badLock / totalWindow) * 100.0
            local badMinPct  = (badMin / totalWindow) * 100.0
            local lockThresholdPercent = lockBelowTargetThreshold * 100.0
            local minThresholdPercent  = minFpsThresholdPercent * 100.0

            DebugLog(string.format(
                "FSR Stage 2 downgrade summary (max retries, keep): window=%.0fms, belowLock=%.0fms (%.0f%% / %.0f%% needed), belowMin=%.0fms (%.0f%% / %.0f%% needed), retries=%d/%d",
                totalWindow,
                badLock, badLockPct, lockThresholdPercent,
                badMin, badMinPct, minThresholdPercent,
                retryCount, maxRetries
            ))

            isFsrDowngradeEvaluating = false
            lastFsrDowngradeEvalEndTime = GetGameTimeMilliseconds()
        end
    end

    zo_callLater(CheckAndSwitchFSR, fsrSwitchDelay)
    DebugLog("Attempting delayed FSR mode switch (Stage 2), first evaluation in: " .. fsrSwitchDelay .. "ms")
end

------------------------------------------------------------
-- Final decision (downgrade): actually step down one FSR level
------------------------------------------------------------
function UserSettingsModifier:ApplyFsrDowngradeOnce()
    if not isLowFpsLocked then
        DebugLog("FSR mode downgrade requested but low-FPS lock is not active, skipping")
        return
    end

    if currentIndex.FSR_MODE < #AdaptiveSettings.FSR_MODE then
        -- Move to the next (lower quality / higher performance) FSR mode
        ApplyFsrIndexChange(currentIndex.FSR_MODE + 1)
        DebugLog("FSR mode decreased due to sustained low FPS")

        -- Record the timestamp of this actual downgrade, and reset the counter for “Stage 2 requests blocked during cooldown”.
        lastFsrActualDowngradeTime = GetTimeStamp()
        fsrPostDowngradeStage2BlockedCount = 0
    else
        DebugLog("FSR mode already at the lowest level, cannot decrease further")
    end
end

------------------------------------------------------------
-- Stage 1 (upgrade): high-FPS window statistics when not in low-FPS lock
------------------------------------------------------------
function UserSettingsModifier:EvaluateHighFpsWindowForUpgrade(fps, deltaTime)
    -- Pause freezes Stage 1 without canceling any in-flight Stage 2 evaluation.
    if IsRapoPaused() then
        return
    end

    -- Do not evaluate upgrade while low-FPS lock is active. Lock invalidates upgrade evidence.
    if isLowFpsLocked then
        highFpsWindowDuration = 0
        highFpsAboveTargetTime = 0
        fsrUpgradeViewDistanceMismatchTime = 0
        return
    end

    -- When already at the highest FSR mode, completely skip the upgrade path.
    if currentIndex.FSR_MODE <= 1 then
        highFpsWindowDuration = 0
        highFpsAboveTargetTime = 0
        fsrUpgradeViewDistanceMismatchTime = 0
        return
    end

    -- FSR upgrade evidence is valid only at maximum view distance.
    -- Short invalid-view periods only freeze Stage 1; sustained invalid view distance resets the window.
    if not IsViewDistanceAtMaximum() then
        fsrUpgradeViewDistanceMismatchTime = fsrUpgradeViewDistanceMismatchTime + deltaTime

        if fsrUpgradeViewDistanceMismatchTime >= fsrUpgradeViewDistanceGraceMs then
            if highFpsWindowDuration > 0 or highFpsAboveTargetTime > 0 then
                DebugLog("FSR upgrade window reset because view distance was not at maximum long enough")
            end
            highFpsWindowDuration = 0
            highFpsAboveTargetTime = 0
        end

        return
    end

    fsrUpgradeViewDistanceMismatchTime = 0

    -- Ignore obviously invalid samples
    if fps < 20 then
        return
    end

    local windowLimit       = fsrUpgradeWindowDuration
    local thresholdHighTime = windowLimit * highFpsUpgradeRatio

    highFpsWindowDuration = highFpsWindowDuration + deltaTime

    if fps >= targetFps + fps_stabilized then
        highFpsAboveTargetTime = highFpsAboveTargetTime + deltaTime
    end

    local elapsed   = highFpsWindowDuration
    local highTime  = highFpsAboveTargetTime
    local remaining = windowLimit - elapsed

    -- Enough high-FPS time accumulated in the upgrade window
    if highTime >= thresholdHighTime then
        local elapsedPct = math.min(100.0, (elapsed / windowLimit) * 100.0)
        local highPct    = (highTime / windowLimit) * 100.0
        local targetPct  = highFpsUpgradeRatio * 100.0

        DebugLog(string.format(
            "FSR upgrade window summary (success): elapsed=%.0fms (%.0f%%), highFpsTime=%.0fms (%.0f%% / %.0f%% needed)",
            elapsed, elapsedPct, highTime, highPct, targetPct
        ))

        if CanStartFsrUpgradeEval() and CanSwitchFsr() then
            DebugLog("Conditions met for FSR mode upgrade in Stage 1, starting Stage 2 evaluation")
            self:StartFsrUpgradeStage2()
        else
            DebugLog("FSR upgrade conditions met but evaluation or switch is on cooldown, skipping this window")
        end

        highFpsWindowDuration = 0
        highFpsAboveTargetTime = 0
        fsrUpgradeViewDistanceMismatchTime = 0
        return
    end

    local worstCaseHigh = highTime + math.max(remaining, 0)
    if remaining <= 0 or worstCaseHigh < thresholdHighTime then
        local elapsedPct = math.min(100.0, (elapsed / windowLimit) * 100.0)
        local highPct    = (highTime / windowLimit) * 100.0
        local targetPct  = highFpsUpgradeRatio * 100.0

        DebugLog(string.format(
            "FSR upgrade window summary (failed): elapsed=%.0fms (%.0f%%), highFpsTime=%.0fms (%.0f%% / %.0f%% needed)",
            elapsed, elapsedPct, highTime, highPct, targetPct
        ))

        highFpsWindowDuration = 0
        highFpsAboveTargetTime = 0
        fsrUpgradeViewDistanceMismatchTime = 0
        return
    end
end

------------------------------------------------------------
-- Stage 2 (upgrade): verify outside combat & still high FPS before upgrading
------------------------------------------------------------
function UserSettingsModifier:StartFsrUpgradeStage2()
    -- Do not start Stage 2 while automatic tuning is paused. Existing Stage 2 callbacks freeze instead of canceling.
    if IsRapoPaused() then
        return
    end

    -- Prevent double triggering if already evaluating
    if isFsrUpgradeEvaluating then
        return
    end

    -- Shared cooldown and load grace
    if not CanSwitchFsr() then
        return
    end

    -- Already at the highest quality FSR level
    if currentIndex.FSR_MODE <= 1 then
        DebugLog("Already at the highest FSR mode, cannot increase further")
        return
    end

    isFsrUpgradeEvaluating = true

    local retryCount = 0
    local maxRetriesUpgrade = 24
    local lastFps = 0

    local function CheckAndUpgradeFSR()
        if not isFsrUpgradeEvaluating then
            return
        end

        if IsRapoPaused() then
            DebugLog("Automatic tuning paused, freezing FSR Stage 2 upgrade evaluation")
            zo_callLater(CheckAndUpgradeFSR, fsrSwitchDelay)
            return
        end

        retryCount = retryCount + 1

        -- Use last smoothed FPS; if not initialized, fallback once
        local fps = lastSmoothedFps
        if fps == 0 then
            fps = GetSmoothedFps()
            lastSmoothedFps = fps
        end
        lastFps = fps

        local inCombat = IsUnitInCombat("player")

        -- Only allow upgrading when:
        -- 1) not in combat, and
        -- 2) FPS is still comfortably above target band.
        -- View distance is intentionally validated only in Stage 1.
        if not inCombat and fps >= targetFps + fps_stabilized then
            DebugLog("FSR upgrade conditions met outside combat, applying change")
            self:ApplyFsrUpgradeOnce()
            isFsrUpgradeEvaluating = false
            lastFsrUpgradeEvalEndTime = GetGameTimeMilliseconds()

            DebugLog(string.format(
                "FSR Stage 2 upgrade summary (upgrade): attempts=%d/%d (%.0f%%), lastFPS=%.3f",
                retryCount, maxRetriesUpgrade, (retryCount / maxRetriesUpgrade) * 100.0, lastFps
            ))
            return
        end

        if retryCount < maxRetriesUpgrade then
            zo_callLater(CheckAndUpgradeFSR, fsrSwitchDelay)
        else
            DebugLog(string.format(
                "FSR Stage 2 upgrade summary (keep): attempts=%d/%d (%.0f%%), lastFPS=%.3f",
                retryCount, maxRetriesUpgrade, (retryCount / maxRetriesUpgrade) * 100.0, lastFps
            ))
            isFsrUpgradeEvaluating = false
            lastFsrUpgradeEvalEndTime = GetGameTimeMilliseconds()
        end
    end

    zo_callLater(CheckAndUpgradeFSR, fsrSwitchDelay)
    DebugLog("Attempting delayed FSR mode upgrade, first evaluation in: " .. fsrSwitchDelay .. "ms")
end

------------------------------------------------------------
-- Final decision (upgrade): actually step up one FSR level
------------------------------------------------------------
function UserSettingsModifier:ApplyFsrUpgradeOnce()
    -- Do not upgrade while low-FPS lock is active
    if isLowFpsLocked then
        DebugLog("FSR mode upgrade requested but low-FPS lock is active, skipping")
        return
    end

    if currentIndex.FSR_MODE > 1 then
        -- Move to the previous (higher quality / lower performance) FSR mode
        ApplyFsrIndexChange(currentIndex.FSR_MODE - 1)
        DebugLog("FSR mode increased due to sustained high FPS")
    else
        DebugLog("FSR mode already at the highest level, cannot increase further")
    end
end

------------------------------------------------------------
-- Static graphics setup - baseline CVar and initial low settings on load
------------------------------------------------------------
function UserSettingsModifier:ApplyStaticSettings()
    -- Static CVar defaults tuned for RogAlly
    local settings = {
        ["MinFrameTime.2"] = activePerformanceProfile.minFrameTime2,
        ["PFX_GLOBAL_MAXIMUM"] = "768",
        ["PFX_SUPPRESS_DISTANCE"] = "35",
        ["CHARACTER_RESOLUTION"] = activePerformanceProfile.characterResolution,
        ["ANTIALIASING_TYPE"] = "2",
        ["AntiAliasingSettingUpgraded"] = "1",
        ["OCCLUSION_CULLING_ENABLED"] = "1",
        ["BACKGROUND_FPS_LIMIT"] = activePerformanceProfile.backgroundFpsLimit,
        ["USE_BACKGROUND_FPS_LIMIT"] = "1",
        ["DistantFoliageEnabled"] = "1",
        ["CachedRLREnabled"] = "1",
        ["CachedReflectionResolution"] = "4",
        ["CachedShadowFiltering"] = "4",
        ["SUB_SAMPLING"] = "2",
        -- NOTE: Do not set FSR_MODE via CVar here anymore
        ["WaterReflectionSettingUpgraded"] = "1",
        ["PLANAR_WATER_REFLECTION_QUALITY"] = activePerformanceProfile.planarWaterReflectionQuality,
        ["SCREENSPACE_WATER_REFLECTION_QUALITY"] = activePerformanceProfile.screenSpaceWaterReflectionQuality,
        ["REFLECTION_QUALITY"] = "0",
        ["PARTICLE_DENSITY"] = "1",
        ["HIGH_RESOLUTION_SHADOWS"] = "0",
        ["SHADOWS"] = activePerformanceProfile.shadowQuality,
        ["CHARACTER_LIGHTING"] = "0",
        ["TerrainShadowsEnabled"] = "0",
        ["GPUSmoothingFrames"] = "10",
        ["MIP_LOAD_SKIP_LEVELS"] = "0",
        ["RAIN_WETNESS"] = "1",
        ["LENS_FLARE"] = "1",
        ["ANTI_ALIASING"] = "1",
        ["AMBIENT_OCCLUSION_TYPE"] = "4",
        ["BLOOM"] = "0",
        ["DepthofFieldSettingUpgraded"] = "1",
        ["DEPTH_OF_FIELD_MODE"] = "3",
        ["DEPTH_OF_FIELD"] = "1",
        ["DIFFUSE_2_MAPS"] = "1",
        ["DETAIL_MAPS"] = "1",
        ["NORMAL_MAPS"] = "1",
        ["SPECULAR_MAPS"] = "1",
        ["CLUTTER_2D_QUALITY"] = activePerformanceProfile.clutter2DQuality,
        ["CLUTTER_2D"] = "1",
        ["WATER_FOAM"] = "2",
        ["RENDERTHREAD"] = "1",
        ["VSYNC_INTERVAL"] = "1",
        ["VSYNC"] = "0",
        ["MAX_ANISOTROPY"] = "3",
    }

    for cvar, value in pairs(settings) do
        SetCVar(cvar, value)
    end

    -- Apply handheld-safe resolution clamp if needed
    EnsureSafeResolutionForHandheld()

    -- FSR default mode should be set via the graphics setting system, not only via CVar.
    -- Report the startup reason here directly instead of relying on later sync-time inference.
    do
        local oldCode = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)
        local newCode = "3"
        local oldName = fsrModeNameMap[oldCode] or oldCode or "Unknown"
        local newName = fsrModeNameMap[newCode] or newCode

        if oldCode ~= newCode then
            d(string.format("[RAPO] FSR mode initialized: %s → %s (addon initialization).", oldName, newName))
            DebugLog(string.format("Startup FSR initialization: %s (%s) -> %s (%s)", tostring(oldCode), oldName, newCode, newName))
        else
            d(string.format("[RAPO] FSR mode initialized: %s unchanged (addon initialization).", newName))
            DebugLog(string.format("Startup FSR initialization executed with no value change: %s (%s)", tostring(newCode), newName))
        end

        SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE, newCode)
        lastKnownFsrValue = newCode
    end

    -- Keep addon-side FSR index aligned with the startup default
    for i, code in ipairs(AdaptiveSettings.FSR_MODE) do
        if code == "3" then
            currentIndex.FSR_MODE = i
            break
        end
    end

    DebugLog(string.format(
        "Static settings applied for performance mode %s (target %.2f / lock %.2f / min %.2f)",
        activePerformanceModeName,
        targetFps,
        lockTargetFps,
        minAcceptableFps
    ))
end

------------------------------------------------------------
-- Initial low settings for dynamic tuning baseline
------------------------------------------------------------
function UserSettingsModifier:ApplyInitialLowSettings()
    -- Start with lowest for dynamic-toggle settings (non-combat baseline)
    currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = #AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS
    SetCVar("SHOW_ADDITIONAL_ALLY_EFFECTS", AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS[currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS])

    currentIndex.DISTORTION = #AdaptiveSettings.DISTORTION
    SetCVar("DISTORTION", AdaptiveSettings.DISTORTION[currentIndex.DISTORTION])

    currentIndex.GOD_RAYS = #AdaptiveSettings.GOD_RAYS
    SetCVar("GOD_RAYS", AdaptiveSettings.GOD_RAYS[currentIndex.GOD_RAYS])

    -- Slightly above absolute minimum view distance for non-combat baseline
    currentIndex.VIEW_DISTANCE = #AdaptiveSettings.viewDistanceLevels - 1
    SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE, AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])

    DebugLog("Initial low-quality settings applied")
end

------------------------------------------------------------
-- Force minimum quality settings for low-FPS lock
------------------------------------------------------------
function UserSettingsModifier:SetLowestSettings(isCombatContext)
    currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = #AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS
    SetCVar("SHOW_ADDITIONAL_ALLY_EFFECTS", AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS[currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS])

    currentIndex.DISTORTION = #AdaptiveSettings.DISTORTION
    SetCVar("DISTORTION", AdaptiveSettings.DISTORTION[currentIndex.DISTORTION])

    currentIndex.GOD_RAYS = #AdaptiveSettings.GOD_RAYS
    SetCVar("GOD_RAYS", AdaptiveSettings.GOD_RAYS[currentIndex.GOD_RAYS])

    -- Low-FPS lock uses different view-distance floors for combat vs non-combat.
    local minIndex
    if isCombatContext then
        minIndex = #AdaptiveSettings.viewDistanceLevels
    else
        minIndex = #AdaptiveSettings.viewDistanceLevels - 1
    end

    currentIndex.VIEW_DISTANCE = minIndex
    SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE, AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])

    DebugLog(string.format(
        "Minimum quality settings applied for low-FPS lock (combat=%s, view distance=%s)",
        tostring(isCombatContext),
        AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE]
    ))
end

------------------------------------------------------------
-- View distance restoration - gradual view distance restore after lock
------------------------------------------------------------
function UserSettingsModifier:GraduallyRestoreViewDistance()
    if isRestoringVisuals then
        DebugLog("Visual restoration already in progress, skipping")
        return
    end

    isRestoringVisuals = true
    isRestoringVisualsActive = true
    isRestoreComplete = false
    restoreEndTime = nil
    restoreCompleteElapsedMs = 0

    local restoreIndex = currentIndex.VIEW_DISTANCE
    local belowTargetFpsCounter = 0
    local hasRestoredAnyStep = false
    local restoreActiveDurationMs = 0
    local lastRestoreStepTime = GetGameTimeMilliseconds()
    local belowTargetFpsDuration = 0
    local maxRestoreDurationMs = 10000  -- Hard timeout for restore (ms), counted in active tuning time
    local stepDelayMs = viewDistanceCooldownDuration / 3

    local function StopRestoration(markComplete, currentTime)
        combatEnded = false
        isRestoringVisuals = false
        isRestoringVisualsActive = false
        isRestoreComplete = markComplete and true or false
        restoreEndTime = markComplete and currentTime or nil
        restoreCompleteElapsedMs = 0
    end

    local function StepRestore()
        self:FlushStatsToNow()

        local currentTime = GetGameTimeMilliseconds()
        if IsRapoPaused() then
            lastRestoreStepTime = currentTime
            zo_callLater(StepRestore, stepDelayMs)
            return
        end

        local stepDelta = currentTime - lastRestoreStepTime
        lastRestoreStepTime = currentTime
        if stepDelta > 0 then
            restoreActiveDurationMs = restoreActiveDurationMs + stepDelta
        end

        local fps = GetSmoothedFps()
        lastSmoothedFps = fps
        local restoreDuration = restoreActiveDurationMs

        -- Hard timeout: avoid getting stuck in restoration forever
        if restoreDuration >= maxRestoreDurationMs then
            DebugLog("View distance restoration exceeded 10 seconds of active tuning, aborting and returning to normal adjustments")
            StopRestoration(false, currentTime)

            -- If we timed out and FPS is still low, give a small hint to the FSR downgrade logic
            if fps < lockTargetFps then
                fsrCounter = fsrCounter + 1
                DebugLog("Restore timeout with FPS still below lockTargetFps, FSR counter increased to: " .. fsrCounter)
            end

            self:AdjustNonCombatSettings(fps)
            return
        end

        if IsUnitInCombat("player") then
            -- Switch to combat tuning and stop restoration
            StopRestoration(false, currentTime)
            self:AdjustCombatSettings(fps)
            DebugLog("Entered combat, stopping view distance restoration")
            return
        end

        if restoreIndex > 1 then
            -- After restoration has started, require three consecutive below-target
            -- samples before treating the restored view distance as the performance limit.
            if hasRestoredAnyStep then
                if fps < targetFps - fps_stabilized then
                    belowTargetFpsCounter = belowTargetFpsCounter + 1

                    -- Track how long FPS stays below the target during restoration;
                    -- this will later be used to decide whether to bump the FSR counter
                    belowTargetFpsDuration = belowTargetFpsDuration + stepDelayMs

                    if belowTargetFpsCounter >= 3 then
                        DebugLog("View distance restoration reached the performance limit, returning to normal adjustments")
                        currentIndex.VIEW_DISTANCE = restoreIndex
                        StopRestoration(false, currentTime)

                        -- If restoration failed very quickly, slightly bump the FSR counter
                        if restoreDuration >= 800 and restoreDuration <= 4000 then
                            fsrCounter = fsrCounter + 2
                            DebugLog("Restoration duration too short, FSR counter increased to: " .. fsrCounter)
                        end

                        -- If most of the restoration time was spent below the target FPS, also bump the FSR counter
                        if restoreDuration > 0 and belowTargetFpsDuration >= restoreDuration * 0.8 then
                            fsrCounter = fsrCounter + 1
                            DebugLog("FPS below target for more than 80% of restoration, FSR counter increased to: " .. fsrCounter)
                        end

                        self:AdjustNonCombatSettings(fps)
                        return
                    end
                else
                    belowTargetFpsCounter = 0
                end
            end

            -- Continue restoring one level per step until the performance limit is confirmed
            -- (we no longer log each individual step to reduce log spam)
            restoreIndex = restoreIndex - 1
            SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE, AdaptiveSettings.viewDistanceLevels[restoreIndex])
            currentIndex.VIEW_DISTANCE = restoreIndex
            hasRestoredAnyStep = true

            zo_callLater(StepRestore, stepDelayMs)
        else
            -- Fully restored to highest view distance
            currentIndex.VIEW_DISTANCE = restoreIndex
            StopRestoration(true, currentTime)

            -- Log once when view distance restoration is fully completed
            DebugLog("View distance restoration completed, final level: " .. AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])

            -- If the majority of restoration time was below target FPS, give the FSR logic a small hint
            if restoreDuration > 0 and belowTargetFpsDuration >= restoreDuration * 0.8 then
                fsrCounter = fsrCounter + 1
                DebugLog("FPS below target for more than 80% of restoration, FSR counter increased to: " .. fsrCounter)
            end

            self:AdjustNonCombatSettings(fps)
        end
    end

    StepRestore()
    DebugLog("Gradual view distance restoration started")
end

------------------------------------------------------------
-- Main adjustment logic (non-combat) - lower/raise graphics outside combat
------------------------------------------------------------
function UserSettingsModifier:AdjustNonCombatSettings(fps)
    if IsRapoPaused() then
        return
    end

    -- Keep internal indices consistent with actual game settings
    self:SyncCurrentIndicesFromGame()

    if isRestoringVisuals then
        return
    end

    -- Manage global low-FPS lock / early unlock
    self:ManageLockState(fps)

    -- While low-FPS lock is active, keep the lock floor aligned with the current non-combat context.
    if isLowFpsLocked then
        local nonCombatLockIndex = #AdaptiveSettings.viewDistanceLevels - 1
        if currentIndex.VIEW_DISTANCE ~= nonCombatLockIndex then
            self:SetLowestSettings(false)
            DebugLog("Low-FPS lock floor synchronized to non-combat context")
        end
        return
    end

    local currentTime = GetGameTimeMilliseconds()

    -- Downward path: reduce quality if FPS below target band
    if fps < targetFps - fps_stabilized then
        -- First: reduce view distance (lowest priority in non-combat, so last to reduce)
        if currentIndex.VIEW_DISTANCE < (#AdaptiveSettings.viewDistanceLevels - 1) and currentTime - lastViewDistanceAdjustmentTime >= viewDistanceCooldownDuration then
            currentIndex.VIEW_DISTANCE = currentIndex.VIEW_DISTANCE + 1
            SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE, AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])
            lastViewDistanceAdjustmentTime = currentTime

            DebugLog("Reduced view distance to: " .. AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])

        -- Then disable god rays
        elseif currentIndex.GOD_RAYS < #AdaptiveSettings.GOD_RAYS and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.GOD_RAYS = currentIndex.GOD_RAYS + 1
            SetCVar("GOD_RAYS", AdaptiveSettings.GOD_RAYS[currentIndex.GOD_RAYS])
            lastAdjustmentTime = currentTime

            DebugLog("Disabled GOD RAYS")

        -- Then disable distortion
        elseif currentIndex.DISTORTION < #AdaptiveSettings.DISTORTION and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.DISTORTION = currentIndex.DISTORTION + 1
            SetCVar("DISTORTION", AdaptiveSettings.DISTORTION[currentIndex.DISTORTION])
            lastAdjustmentTime = currentTime

            DebugLog("Disabled DISTORTION")

        -- Finally disable additional ally effects
        elseif currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS < #AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS + 1
            SetCVar("SHOW_ADDITIONAL_ALLY_EFFECTS", AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS[currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS])
            lastAdjustmentTime = currentTime

            DebugLog("Disabled additional ally effects")
        end

    -- Upward path: gradually restore quality if FPS above target band
    elseif fps >= targetFps + fps_stabilized then
        -- First restore ally effects
        if currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS > 1 and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS - 1
            SetCVar("SHOW_ADDITIONAL_ALLY_EFFECTS", AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS[currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS])
            lastAdjustmentTime = currentTime

            DebugLog("Enabled additional ally effects")

        -- Then restore distortion
        elseif currentIndex.DISTORTION > 1 and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.DISTORTION = currentIndex.DISTORTION - 1
            SetCVar("DISTORTION", AdaptiveSettings.DISTORTION[currentIndex.DISTORTION])
            lastAdjustmentTime = currentTime

            DebugLog("Enabled DISTORTION")

        -- Then restore god rays
        elseif currentIndex.GOD_RAYS > 1 and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.GOD_RAYS = currentIndex.GOD_RAYS - 1
            SetCVar("GOD_RAYS", AdaptiveSettings.GOD_RAYS[currentIndex.GOD_RAYS])
            lastAdjustmentTime = currentTime

            DebugLog("Enabled GOD RAYS")

        -- Finally increase view distance (highest cost, restore last)
        elseif currentIndex.VIEW_DISTANCE > 1 and currentTime - lastViewDistanceAdjustmentTime >= viewDistanceCooldownDuration then
            currentIndex.VIEW_DISTANCE = currentIndex.VIEW_DISTANCE - 1
            SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE, AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])
            lastViewDistanceAdjustmentTime = currentTime

            DebugLog("Increased view distance to: " .. AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])
        end
    end

    -- While not locked, also evaluate high-FPS windows for possible FSR upgrade
    self:EvaluateHighFpsWindowForUpgrade(fps, checkInterval)
end

------------------------------------------------------------
-- Main adjustment logic (combat) - enforce minimum view distance and tune FX
------------------------------------------------------------
function UserSettingsModifier:AdjustCombatSettings(fps)
    if IsRapoPaused() then
        return
    end

    -- Keep internal indices consistent with actual game settings
    self:SyncCurrentIndicesFromGame()

    local currentTime = GetGameTimeMilliseconds()

    -- Allow combat to enter/maintain low-FPS lock so FSR downgrade logic can run there too.
    self:ManageLockState(fps)

    -- While low-FPS lock is active, keep the lock floor aligned with the current combat context.
    if isLowFpsLocked then
        local combatLockIndex = #AdaptiveSettings.viewDistanceLevels
        if currentIndex.VIEW_DISTANCE ~= combatLockIndex then
            self:SetLowestSettings(true)
            DebugLog("Low-FPS lock floor synchronized to combat context")
        end
        return
    end

    -- Force minimum view distance during combat, but only set & log when it actually changes
    local minIndex = #AdaptiveSettings.viewDistanceLevels
    if currentIndex.VIEW_DISTANCE ~= minIndex then
        currentIndex.VIEW_DISTANCE = minIndex
        SetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_VIEW_DISTANCE, AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])
        DebugLog("Set view distance to minimum during combat: " .. AdaptiveSettings.viewDistanceLevels[currentIndex.VIEW_DISTANCE])
    end

    if fps < targetFps - fps_stabilized then
        -- Disable god rays first
        if currentIndex.GOD_RAYS < #AdaptiveSettings.GOD_RAYS and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.GOD_RAYS = currentIndex.GOD_RAYS + 1
            SetCVar("GOD_RAYS", AdaptiveSettings.GOD_RAYS[currentIndex.GOD_RAYS])
            lastAdjustmentTime = currentTime

            DebugLog("Disabled GOD RAYS during combat")

        -- Then disable distortion
        elseif currentIndex.DISTORTION < #AdaptiveSettings.DISTORTION and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.DISTORTION = currentIndex.DISTORTION + 1
            SetCVar("DISTORTION", AdaptiveSettings.DISTORTION[currentIndex.DISTORTION])
            lastAdjustmentTime = currentTime

            DebugLog("Disabled DISTORTION during combat")

        -- Finally disable additional ally effects
        elseif currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS < #AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS + 1
            SetCVar("SHOW_ADDITIONAL_ALLY_EFFECTS", AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS[currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS])
            lastAdjustmentTime = currentTime

            DebugLog("Disabled additional ally effects during combat")
        end

    elseif fps >= targetFps + fps_stabilized then
        -- If FPS is very good even in combat, we can restore some FX (but not view distance)
        if currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS > 1 and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS = currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS - 1
            SetCVar("SHOW_ADDITIONAL_ALLY_EFFECTS", AdaptiveSettings.SHOW_ADDITIONAL_ALLY_EFFECTS[currentIndex.SHOW_ADDITIONAL_ALLY_EFFECTS])
            lastAdjustmentTime = currentTime

            DebugLog("Enabled additional ally effects during combat")

        elseif currentIndex.DISTORTION > 1 and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.DISTORTION = currentIndex.DISTORTION - 1
            SetCVar("DISTORTION", AdaptiveSettings.DISTORTION[currentIndex.DISTORTION])
            lastAdjustmentTime = currentTime

            DebugLog("Enabled DISTORTION during combat")

        elseif currentIndex.GOD_RAYS > 1 and currentTime - lastAdjustmentTime >= cooldownDuration then
            currentIndex.GOD_RAYS = currentIndex.GOD_RAYS - 1
            SetCVar("GOD_RAYS", AdaptiveSettings.GOD_RAYS[currentIndex.GOD_RAYS])
            lastAdjustmentTime = currentTime

            DebugLog("Enabled GOD RAYS during combat")
        end
    end
end

------------------------------------------------------------
-- Combat end handling - decide whether to restore view distance or keep low
------------------------------------------------------------
function UserSettingsModifier:HandleCombatEnd()
    if isRestoringVisuals then
        combatEnded = false
        return
    end

    if isLowFpsLocked then
        -- Use last smoothed FPS instead of recomputing
        local fps = lastSmoothedFps
        self:AdjustNonCombatSettings(fps)
        DebugLog("Combat ended while low-FPS lock active, running non-combat low-quality logic")
    else
        self:GraduallyRestoreViewDistance()
        DebugLog("Combat ended, starting view distance restoration")
    end

    combatEnded = false
end

------------------------------------------------------------
-- External pause reconciliation - event driven with runtime read-back fallback
------------------------------------------------------------
function UserSettingsModifier:ReconcileExternalPauseReasons()
    if IsPlayerActivated then
        self:SetPauseReason("loading", not IsPlayerActivated())
    end

    if IsGameCameraUIModeActive then
        self:SetPauseReason("ui", IsGameCameraUIModeActive())
    end

    if DoesGameHaveFocus then
        self:SetPauseReason("unfocused", not DoesGameHaveFocus())
    end
end

------------------------------------------------------------
-- Monitoring loop - FPS sampling, power saving check, route to adjustors
------------------------------------------------------------
function UserSettingsModifier:StartMonitoring()
    if monitoringStarted then
        return
    end

    monitoringStarted = true
    lastStatsUpdateTimeMs = GetGameTimeMilliseconds()

    -- Monitoring started notification
    d("[RAPO] Monitoring started (dynamic tuning enabled).")
    DebugLog("Monitoring started")

    -- Listen for combat state changes
    EVENT_MANAGER:RegisterForEvent(self.name .. "CombatStateChange", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        self:FlushStatsToNow()
        energyDiag.contextSerial = energyDiag.contextSerial + 1
        DebugLog("Combat state change, inCombat: " .. tostring(inCombat))
        combatEnded = not inCombat

        -- Keep the low-FPS lock floor aligned with the new combat context only when tuning is active.
        if isLowFpsLocked and not IsRapoPaused() then
            self:SetLowestSettings(inCombat)
            DebugLog("Low-FPS lock floor synchronized to new combat state")
        end
    end)

    -- Main FPS monitoring loop
    EVENT_MANAGER:RegisterForUpdate(self.name .. "FPS", checkInterval, function()
        local now = GetGameTimeMilliseconds()
        self:FlushStatsToNow()

        -- Events remain the immediate path, while read-back prevents a missed
        -- exit event from leaving an external pause reason stuck forever.
        self:ReconcileExternalPauseReasons()

        -- External pause states fully suspend automatic tuning and FPS sampling.
        if IsRapoPausedForExternalState() then
            self:CancelPowerSavingProbe()
            if powerSavingDetector.state == "active" then
                powerSavingDetector.exitMisses = 0
            end
            return
        end

        local rawFps = GetFramerate()
        UpdatePlayerActivity()

        -- Keep energy-saving samples separate from the tuning FPS buffer.
        self:UpdatePowerSavingState(rawFps)
        energyDiag.lastMainTickTime = now

        if IsRapoPaused() then
            return
        end

        AddFpsSample(rawFps)
        local fps = GetSmoothedFps()
        lastSmoothedFps = fps

        if combatEnded then
            self:HandleCombatEnd()
        elseif IsUnitInCombat("player") then
            self:AdjustCombatSettings(fps)
        else
            self:AdjustNonCombatSettings(fps)
        end

        -- Minimum warning at lowest settings
        self:CheckMinimumWarning(fps)
    end)

    DebugLog("FPS monitoring started")
end

------------------------------------------------------------
-- Pause event hooks - freeze automatic tuning on loading/UI/focus changes
------------------------------------------------------------
function UserSettingsModifier:RegisterPauseEvents()
    EVENT_MANAGER:RegisterForEvent(self.name .. "PausePlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        self:SetPauseReason("loading", false)

        if IsGameCameraUIModeActive then
            self:SetPauseReason("ui", IsGameCameraUIModeActive())
        end
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "PausePlayerDeactivated", EVENT_PLAYER_DEACTIVATED, function()
        self:SetPauseReason("loading", true)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "PauseUIMode", EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
        if IsGameCameraUIModeActive then
            self:SetPauseReason("ui", IsGameCameraUIModeActive())
        end
    end)

    EVENT_MANAGER:RegisterForEvent(self.name .. "PauseFocus", EVENT_GAME_FOCUS_CHANGED, function(_, hasFocus)
        self:SetPauseReason("unfocused", not hasFocus)
    end)

    self:ReconcileExternalPauseReasons()
end

------------------------------------------------------------
-- Addon initialization - SavedVariables, static setup, delayed monitoring
------------------------------------------------------------
function UserSettingsModifier:OnLoad(event, addonName)
    if addonName ~= self.name then return end
    EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED)
    DebugLog("Addon loading...")

    -- Initialize SavedVariables for logs, stats, and performance mode state
    if not RAPO_SavedVariables then
        RAPO_SavedVariables = ZO_SavedVars:NewAccountWide("RogAllyPerformanceOptimization", 1, nil, {
            logs = {},
            stats = {},
            modes = {
                active = "45fps",
                pending = nil,
            },
            fsrEnergyDiagnostics = {
                schemaVersion = 1,
                nextId = 1,
                reports = {},
            },
        })
    end

    RAPO_SavedVariables.logs = RAPO_SavedVariables.logs or {}
    RAPO_SavedVariables.stats = RAPO_SavedVariables.stats or {}
    RAPO_SavedVariables.modes = RAPO_SavedVariables.modes or {
        active = "45fps",
        pending = nil,
    }
    self:GetEnergyDiagnosticStore()

    if not ResolvePerformanceProfile(RAPO_SavedVariables.modes.active) then
        RAPO_SavedVariables.modes.active = "45fps"
    end

    if RAPO_SavedVariables.modes.pending and not ResolvePerformanceProfile(RAPO_SavedVariables.modes.pending) then
        RAPO_SavedVariables.modes.pending = nil
    end

    pendingPerformanceModeName = RAPO_SavedVariables.modes.pending
    ApplyPerformanceProfile(RAPO_SavedVariables.modes.active)

    InitializeLifetimeStats()
    ResetSessionStats()
    self:RegisterPauseEvents()

    addonLoadTime = GetGameTimeMilliseconds()
    lastActivityTime = addonLoadTime
    energyDiag.lastActivityReason = "addon-load"

    -- Initialize lastKnownFsrValue from current CVar at load time
    local initialFsr = GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_FSR_MODE)
    if initialFsr and initialFsr ~= "" then
        lastKnownFsrValue = initialFsr
    end
    energyDiag.enabled = true
    energyDiag.observerStarted = false
    self:ResetEnergyDiagnostic(initialFsr)
    local observerOk, observerError = pcall(self.StartEnergyDiagnosticObserver, self)
    if not observerOk then
        self:DisableEnergyDiagnostic("startup", observerError)
    end

    DebugLog(string.format("Active performance mode loaded: %s", activePerformanceModeName))
    if pendingPerformanceModeName then
        DebugLog(string.format("Pending performance mode detected: %s", pendingPerformanceModeName))
    end

    -- Delay monitoring until player is fully in-game
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function()
            self:StartMonitoring()
            DebugLog("Addon loaded, starting FPS monitoring after 10-second delay")
        end, 10000)

        EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
    end)

    -- Apply static settings and initial dynamic low settings shortly after load
    zo_callLater(function()
        self:ApplyStaticSettings()
        self:ApplyInitialLowSettings()
        DebugLog("Initial settings applied")
    end, 1000)
end

------------------------------------------------------------
-- Event & command hooks - engine entry points for load and commands
------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(UserSettingsModifier.name, EVENT_ADD_ON_LOADED, function(event, addonName)
    UserSettingsModifier:OnLoad(event, addonName)
end)

function UserSettingsModifier:OutputEnergyDiagnostics(arguments)
    local store = self:GetEnergyDiagnosticStore()
    if not store then
        d("[RAPO][Diag] SavedVariables are not ready.")
        return
    end

    arguments = (arguments or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local command, value = arguments:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""

    if command == "" then
        local phase = "waiting"
        if energyDiag.enabled and energyDiag.observerStarted then
            phase = "watching"
            if energyDiag.pending then
                local now = GetGameTimeMilliseconds()
                if not energyDiag.pending.confirmedAt then
                    phase = "readback"
                else
                    phase = now < energyDiag.pending.settleEnd and "settling" or "post"
                end
            end
        elseif not energyDiag.enabled then
            phase = "disabled"
        end

        local latest = store.reports[#store.reports]
        local latestText = latest and string.format(
            "#%s %s %s",
            self:FormatEnergyDiagnosticId(latest.id, store),
            tostring(latest.stamp or "unknown"),
            tostring(latest.confidence or "unknown")
        ) or "none"

        d(string.format(
            "[RAPO][Diag] watcher=%s phase=%s saved=%d latest=%s; use list [page], show <id>, clear <id|all>.",
            tostring(energyDiag.enabled and energyDiag.observerStarted),
            phase,
            #store.reports,
            latestText
        ))
        return
    end

    if command == "list" then
        if #store.reports == 0 then
            d("[RAPO][Diag] saved=0")
            return
        end

        local page = tonumber(value) or 1
        local totalPages = math.ceil(#store.reports / energyDiagConfig.listPageSize)
        if page < 1 or page > totalPages or page ~= math.floor(page) then
            d(string.format("[RAPO][Diag] page %s out of range (1-%d).", tostring(value), totalPages))
            return
        end

        d(string.format("[RAPO][Diag] page %d/%d, newest first:", page, totalPages))
        local first = #store.reports - ((page - 1) * energyDiagConfig.listPageSize)
        local last = math.max(1, first - energyDiagConfig.listPageSize + 1)
        for index = first, last, -1 do
            local report = store.reports[index]
            d(string.format(
                "#%s | %s",
                self:FormatEnergyDiagnosticId(report.id, store),
                tostring(report.stamp or "unknown")
            ))
        end
        return
    end

    if command == "show" then
        local report = self:FindEnergyDiagnosticReport(value)
        if not report then
            d("[RAPO][Diag] Unknown report id. Use /rapo diag list first.")
            return
        end

        local reportId = self:FormatEnergyDiagnosticId(report.id, store)
        d(string.format(
            "[RAPO][Diag #%s] %s status=%s confidence=%s mode=%s events=%d",
            reportId,
            tostring(report.stamp),
            tostring(report.status),
            tostring(report.confidence),
            tostring(report.mode),
            #report.events
        ))

        for sequence, event in ipairs(report.events) do
            local fromName = fsrModeNameMap[event.fromCode] or event.fromCode
            local toName = fsrModeNameMap[event.toCode] or event.toCode
            local gain = (event.postAverage or 0) - (event.preAverage or 0)
            local switch = event.switch or {}
            local after = event.after or {}
            local switchMainAge = (switch.mainTickAgeMs or -1) >= 0
                and string.format("%.1fs", switch.mainTickAgeMs / 1000) or "never"
            local afterMainAge = (after.mainTickAgeMs or -1) >= 0
                and string.format("%.1fs", after.mainTickAgeMs / 1000) or "never"
            d(string.format(
                "[RAPO][Diag #%s.%d] %s>%s pre=%.2f[%d/%d] post=%.2f[%d/%d] gain=%+.2f idle=%.1f>%.1fs activity=%s>%s main=%s>%s detector=%s:%d/%d/%s>%s:%d/%d/%s flags=%s>%s",
                reportId,
                sequence,
                tostring(fromName),
                tostring(toName),
                event.preAverage or 0,
                event.preHits or 0,
                event.preSamples or 0,
                event.postAverage or 0,
                event.postHits or 0,
                event.postSamples or 0,
                gain,
                (switch.idleAgeMs or 0) / 1000,
                (after.idleAgeMs or 0) / 1000,
                tostring(switch.activityReason or "unknown"),
                tostring(after.activityReason or "unknown"),
                switchMainAge,
                afterMainAge,
                tostring(switch.detectorState or "unknown"),
                switch.probeHits or 0,
                switch.probeTicks or 0,
                tostring(switch.activeFlag),
                tostring(after.detectorState or "unknown"),
                after.probeHits or 0,
                after.probeTicks or 0,
                tostring(after.activeFlag),
                tostring(switch.pauseFlags or "??????"),
                tostring(after.pauseFlags or "??????")
            ))
        end
        return
    end

    if command == "clear" then
        if value == "all" then
            store.reports = {}
            energyDiag.chain = nil
            d("[RAPO][Diag] All saved reports cleared.")
            return
        end

        local report, index = self:FindEnergyDiagnosticReport(value)
        if not report then
            d("[RAPO][Diag] Unknown report id. Use /rapo diag list first.")
            return
        end

        table.remove(store.reports, index)
        if energyDiag.chain and energyDiag.chain.reportId == report.id then
            energyDiag.chain = nil
        end
        d(string.format(
            "[RAPO][Diag] Report #%s cleared.",
            self:FormatEnergyDiagnosticId(report.id, store)
        ))
        return
    end

    d("[RAPO][Diag] Usage: /rapo diag | list [page] | show <id> | clear <id|all>")
end

local function OutputRapoUsage()
    d("[RAPO] Usage: /rapo stats | /rapo debug | /rapo diag [list/show/clear] | /rapo mode [name] | /rapo confirm | /rapo cancel")
end

local function ToggleDebugLogging()
    enableDebugLogging = not enableDebugLogging

    if enableDebugLogging then
        if not RAPO_SavedVariables then
            RAPO_SavedVariables = ZO_SavedVars:NewAccountWide("RogAllyPerformanceOptimization", 1, nil, {})
        end
        RAPO_SavedVariables.logs = RAPO_SavedVariables.logs or {}
        d("[RAPO] Debug logging enabled.")
        DebugLog("Debug logging enabled via /rapo debug command")
    else
        d("[RAPO] Debug logging disabled.")
    end
end

local function OutputPerformanceModeStatus()
    if pendingPerformanceModeName then
        d(string.format(
            "[RAPO] Active performance mode: %s. Pending mode: %s. Type /rapo confirm to apply after reload, or /rapo cancel to discard.",
            activePerformanceModeName,
            pendingPerformanceModeName
        ))
    else
        d(string.format("[RAPO] Active performance mode: %s.", activePerformanceModeName))
    end
end

local function SetPendingPerformanceMode(modeName)
    local resolved = ResolvePerformanceProfile(modeName)
    if not resolved then
        d(string.format(
            "[RAPO] Unknown performance mode: %s. Available modes: %s.",
            modeName,
            table.concat(GetAvailablePerformanceModes(), ", ")
        ))
        return
    end

    if modeName == activePerformanceModeName then
        d(string.format("[RAPO] Performance mode %s is already active.", modeName))
        return
    end

    if pendingPerformanceModeName == modeName then
        d(string.format(
            "[RAPO] Performance mode %s is already pending. Type /rapo confirm to apply, or /rapo cancel to discard.",
            modeName
        ))
        return
    end

    pendingPerformanceModeName = modeName
    RAPO_SavedVariables.modes.pending = modeName

    d(string.format(
        "[RAPO] Performance mode change pending: %s → %s. Type /rapo confirm to apply after reload, or /rapo cancel to discard.",
        activePerformanceModeName,
        modeName
    ))
end

local function ConfirmPendingPerformanceMode()
    if not pendingPerformanceModeName then
        d("[RAPO] No pending performance mode change.")
        return
    end

    RAPO_SavedVariables.modes.active = pendingPerformanceModeName
    RAPO_SavedVariables.modes.pending = nil

    local appliedMode = pendingPerformanceModeName
    pendingPerformanceModeName = nil

    d(string.format("[RAPO] Applying performance mode %s. Reloading UI in 3 seconds...", appliedMode))
    zo_callLater(function()
        ReloadUI()
    end, 3000)
end

local function CancelPendingPerformanceMode()
    if not pendingPerformanceModeName then
        d("[RAPO] No pending performance mode change to cancel.")
        return
    end

    pendingPerformanceModeName = nil
    RAPO_SavedVariables.modes.pending = nil
    d("[RAPO] Pending performance mode change canceled.")
end

SLASH_COMMANDS["/rapo"] = function(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")

    UserSettingsModifier:FlushStatsToNow()

    if arg == "" or arg == "stats" then
        UserSettingsModifier:OutputSessionStats()
        UserSettingsModifier:OutputLifetimeStats()
        UserSettingsModifier:OutputOldStats()
        return
    end

    local command, rest = arg:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    rest = rest and rest:lower() or ""

    if command == "debug" then
        ToggleDebugLogging()
        return
    end

    if command == "diag" then
        UserSettingsModifier:OutputEnergyDiagnostics(rest)
        return
    end

    if command == "mode" then
        if rest == "" then
            OutputPerformanceModeStatus()
        else
            SetPendingPerformanceMode(rest)
        end
        return
    end

    if command == "confirm" then
        ConfirmPendingPerformanceMode()
        return
    end

    if command == "cancel" then
        CancelPendingPerformanceMode()
        return
    end

    OutputRapoUsage()
end

return UserSettingsModifier
