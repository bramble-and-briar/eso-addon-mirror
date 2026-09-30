-- ESO Adventurer Suite
-- v0.29.630 - unified runtime performance controller.
-- Consolidates the old HUD/trial runtime guards into one ownership layer.
-- Dense 8+ player combat removes nonessential event traffic and world/UI work
-- before it reaches expensive Suite paths. Normal gameplay keeps full features.
-- No permanent frame OnUpdate loop is introduced.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER then return end

EPC.RuntimePerformanceController = EPC.RuntimePerformanceController or {}
local P = EPC.RuntimePerformanceController
local EM = EVENT_MANAGER
local PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_RuntimePerf029630"
local TEAM_PREFIX = (EPC.name or "EAS") .. "_TeamVisibility"
local RESOURCE_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_ResourcePins"
local TICK_DRAW_NAME = PREFIX .. "_TickTrackerDraw"
local takeCoreOwnership
local ownTeamVisibilityTimers
local RUNTIME_OWNER = "RuntimePerformance"

local function registerOwnedEvent(registration, eventId, callback)
    local runtime = EPC.Runtime
    if runtime and type(runtime.RegisterNamedEvent) == "function" then
        return runtime:RegisterNamedEvent(RUNTIME_OWNER, registration, eventId, callback)
    end
    EM:UnregisterForEvent(registration, eventId)
    EM:RegisterForEvent(registration, eventId, callback)
    return true
end

local function unregisterOwnedEvent(registration, eventId)
    local runtime = EPC.Runtime
    if runtime and type(runtime.UnregisterNamedEvent) == "function" then
        runtime:UnregisterNamedEvent(RUNTIME_OWNER, registration, eventId)
        return
    end
    EM:UnregisterForEvent(registration, eventId)
end

local function registerOwnedUpdate(registration, intervalMs, callback)
    local runtime = EPC.Runtime
    if runtime and type(runtime.RegisterNamedUpdate) == "function" then
        return runtime:RegisterNamedUpdate(RUNTIME_OWNER, registration, intervalMs, callback)
    end
    EM:UnregisterForUpdate(registration)
    EM:RegisterForUpdate(registration, intervalMs, callback)
    return true
end

local function unregisterOwnedUpdate(registration)
    local runtime = EPC.Runtime
    if runtime and type(runtime.UnregisterNamedUpdate) == "function" then
        runtime:UnregisterNamedUpdate(RUNTIME_OWNER, registration)
        return
    end
    EM:UnregisterForUpdate(registration)
end

local STATE = {
    groupSize = 0,
    inCombat = false,
    hard = false,
    teamWasHidden = nil,
    resourceWasHidden = nil,
}

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function readGroupSize()
    if type(GetGroupSize) == "function" then
        local ok, value = pcall(GetGroupSize)
        STATE.groupSize = ok and math.max(0, tonumber(value) or 0) or 0
    else
        STATE.groupSize = 0
    end
end

local function readCombatState()
    if type(IsUnitInCombat) == "function" then
        local ok, value = pcall(IsUnitInCombat, "player")
        STATE.inCombat = ok and value == true
    else
        STATE.inCombat = false
    end
end

local function hardMode()
    return STATE.hard == true
end

function P:IsHardTrialMode()
    return hardMode()
end

function EPC:IsHardTrialPerformanceMode029630()
    return hardMode()
end

local function compactResults(...)
    local out = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value ~= nil then out[#out + 1] = value end
    end
    return out
end

local DAMAGE_RESULTS = compactResults(
    rawget(_G, "ACTION_RESULT_DAMAGE"),
    rawget(_G, "ACTION_RESULT_CRITICAL_DAMAGE"),
    rawget(_G, "ACTION_RESULT_DOT_TICK"),
    rawget(_G, "ACTION_RESULT_DOT_TICK_CRITICAL"),
    rawget(_G, "ACTION_RESULT_DAMAGE_SHIELDED")
)

local HEAL_RESULTS = compactResults(
    rawget(_G, "ACTION_RESULT_HEAL"),
    rawget(_G, "ACTION_RESULT_CRITICAL_HEAL"),
    rawget(_G, "ACTION_RESULT_HOT_TICK"),
    rawget(_G, "ACTION_RESULT_HOT_TICK_CRITICAL")
)

local function coreGroupRegistration(kind, result)
    return string.format("%s_Combat_%s_Group_%s",
        EPC.name or "ESOAdventurerSuite", kind, tostring(result))
end

local function groupCombatCallback(kind)
    return function(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
        sourceName, sourceType, targetName, targetType, hitValue, powerType,
        damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
        local combat = EPC.Combat
        if combat and type(combat.OnCombatEvent) == "function" then
            combat:OnCombatEvent(kind, result, abilityName, sourceName, sourceType,
                targetName, targetType, hitValue, abilityId, sourceUnitId)
        end
    end
end

local GROUP_DAMAGE_CALLBACK = groupCombatCallback("DAMAGE")
local GROUP_HEAL_CALLBACK = groupCombatCallback("HEAL")

local function unregisterGroupCombatStreams()
    if EVENT_COMBAT_EVENT == nil then return end
    for _, result in ipairs(DAMAGE_RESULTS) do
        unregisterOwnedEvent(coreGroupRegistration("DAMAGE", result), EVENT_COMBAT_EVENT)
    end
    for _, result in ipairs(HEAL_RESULTS) do
        unregisterOwnedEvent(coreGroupRegistration("HEAL", result), EVENT_COMBAT_EVENT)
    end
end

local function restoreOneGroupStream(kind, result, callback)
    if EVENT_COMBAT_EVENT == nil or result == nil then return end
    if REGISTER_FILTER_COMBAT_RESULT == nil
        or REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE == nil
        or COMBAT_UNIT_TYPE_GROUP == nil then
        return
    end

    local name = coreGroupRegistration(kind, result)
    unregisterOwnedEvent(name, EVENT_COMBAT_EVENT)
    registerOwnedEvent(name, EVENT_COMBAT_EVENT, callback)
    EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result)
    if REGISTER_FILTER_IS_ERROR ~= nil then
        EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
    end
    EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
end

local function restoreGroupCombatStreams()
    for _, result in ipairs(DAMAGE_RESULTS) do
        restoreOneGroupStream("DAMAGE", result, GROUP_DAMAGE_CALLBACK)
    end
    for _, result in ipairs(HEAL_RESULTS) do
        restoreOneGroupStream("HEAL", result, GROUP_HEAL_CALLBACK)
    end
end

local BOSS_BEGIN_NAME = (EPC.name or "ESOAdventurerSuite") .. "_BossMechanics029198_Begin"

local function bossBeginCallback(_, result, isError, abilityName, abilityGraphic,
    abilityActionSlotType, sourceName, sourceType, targetName, targetType,
    hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    local mechanics = EPC.BossMechanicsAssistant
    if mechanics and type(mechanics.OnBeginEvent) == "function" then
        mechanics:OnBeginEvent(abilityName, abilityActionSlotType, sourceName, targetName, abilityId)
    end
end

local function configureBossBegin(targetPlayerOnly)
    local M = EPC.BossMechanicsAssistant
    if EVENT_COMBAT_EVENT == nil
        or ACTION_RESULT_BEGIN == nil
        or REGISTER_FILTER_COMBAT_RESULT == nil
        or not M
        or type(M.OnBeginEvent) ~= "function" then
        return
    end

    unregisterOwnedEvent(BOSS_BEGIN_NAME, EVENT_COMBAT_EVENT)
    registerOwnedEvent(BOSS_BEGIN_NAME, EVENT_COMBAT_EVENT, bossBeginCallback)
    EM:AddFilterForEvent(BOSS_BEGIN_NAME, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_BEGIN)
    if REGISTER_FILTER_IS_ERROR ~= nil then
        EM:AddFilterForEvent(BOSS_BEGIN_NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
    end
    if targetPlayerOnly
        and REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE ~= nil
        and COMBAT_UNIT_TYPE_PLAYER ~= nil then
        EM:AddFilterForEvent(BOSS_BEGIN_NAME, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
end

local function isHidden(control)
    if not control or type(control.IsHidden) ~= "function" then return nil end
    local ok, value = pcall(control.IsHidden, control)
    if not ok then return nil end
    return value == true
end

local function delayed(callback, delay)
    if type(callback) ~= "function" then return end
    if type(zo_callLater) == "function" then
        zo_callLater(callback, tonumber(delay) or 0)
    else
        callback()
    end
end

local function pauseTeamVisibility()
    local T = EPC.TeamVisibility
    unregisterOwnedUpdate(TEAM_PREFIX .. "_Follow")
    unregisterOwnedUpdate(TEAM_PREFIX .. "_Particles")
    if not T then return end

    if T.particleWindow then
        if STATE.teamWasHidden == nil then STATE.teamWasHidden = isHidden(T.particleWindow) end
        if type(T.particleWindow.SetHidden) == "function" then
            pcall(T.particleWindow.SetHidden, T.particleWindow, true)
        end
    end
    if type(T.HideAllParticles) == "function" then pcall(T.HideAllParticles, T) end
end

local function resumeTeamVisibility()
    local T = EPC.TeamVisibility
    if not T then return end

    unregisterOwnedUpdate(TEAM_PREFIX .. "_Follow")
    unregisterOwnedUpdate(TEAM_PREFIX .. "_Particles")
    if ownTeamVisibilityTimers then ownTeamVisibilityTimers() end

    delayed(function()
        if hardMode() then return end
        local current = EPC.TeamVisibility
        if not current then return end
        if current.particleWindow and type(current.particleWindow.SetHidden) == "function" then
            local shouldHide = STATE.teamWasHidden == true
                or (EPC.saved and EPC.saved.teamVisibilityEnabled == false)
            pcall(current.particleWindow.SetHidden, current.particleWindow, shouldHide)
        end
        STATE.teamWasHidden = nil
        if not (EPC.saved and EPC.saved.teamVisibilityEnabled == false)
            and type(current.RefreshParticles) == "function" then
            pcall(current.RefreshParticles, current)
        end
    end, 250)
end

local function pauseResourcePins()
    local R = EPC.ResourcePins
    unregisterOwnedUpdate(RESOURCE_PREFIX .. "_Interact")
    unregisterOwnedUpdate(RESOURCE_PREFIX .. "_Render")
    if not R or not R.window then return end
    if STATE.resourceWasHidden == nil then STATE.resourceWasHidden = isHidden(R.window) end
    if type(R.window.SetHidden) == "function" then pcall(R.window.SetHidden, R.window, true) end
end

local function resumeResourcePins()
    local R = EPC.ResourcePins
    if not R then return end

    unregisterOwnedUpdate(RESOURCE_PREFIX .. "_Interact")
    unregisterOwnedUpdate(RESOURCE_PREFIX .. "_Render")

    if type(R.CaptureResourceInteraction) == "function" then
        registerOwnedUpdate(RESOURCE_PREFIX .. "_Interact", 900, function()
            local current = EPC.ResourcePins
            if current and not hardMode() and type(current.CaptureResourceInteraction) == "function" then
                current:CaptureResourceInteraction()
            end
        end)
    end

    if type(R.MovementAwareRefreshMarkers029312) == "function" then
        registerOwnedUpdate(RESOURCE_PREFIX .. "_Render", 900, function()
            local current = EPC.ResourcePins
            if current and not hardMode()
                and type(current.MovementAwareRefreshMarkers029312) == "function" then
                current:MovementAwareRefreshMarkers029312()
            end
        end)
    end

    delayed(function()
        if hardMode() then return end
        local current = EPC.ResourcePins
        if not current then return end
        if current.window and type(current.window.SetHidden) == "function" then
            local shouldHide = STATE.resourceWasHidden == true
                or not EPC.saved
                or EPC.saved.resourcePinsEnabled == false
                or EPC.saved.resourcePinsShow3D == false
            pcall(current.window.SetHidden, current.window, shouldHide)
        end
        STATE.resourceWasHidden = nil
        if EPC.saved and EPC.saved.resourcePinsEnabled ~= false
            and type(current.RefreshMarkers) == "function" then
            pcall(current.RefreshMarkers, current)
        end
    end, 300)
end

local function enterHardMode()
    if STATE.hard then return end
    STATE.hard = true
    EPC.trialHardPerformanceMode029630 = true
    EPC.trialHardPerformanceMode029625 = true

    unregisterGroupCombatStreams()
    configureBossBegin(true)
    pauseTeamVisibility()
    pauseResourcePins()
end

local function exitHardMode()
    if not STATE.hard then return end
    STATE.hard = false
    EPC.trialHardPerformanceMode029630 = false
    EPC.trialHardPerformanceMode029625 = false

    restoreGroupCombatStreams()
    configureBossBegin(false)
    resumeTeamVisibility()
    resumeResourcePins()

    delayed(function()
        if hardMode() then return end
        local F = EPC.UnitFrames
        if F and type(F.RefreshGroupFrames) == "function" then pcall(F.RefreshGroupFrames, F) end
        local M = EPC.MiniMap
        if M then
            if type(M.SyncToPlayerMap) == "function" then pcall(M.SyncToPlayerMap, M, true) end
            if type(M.RefreshStaticPins) == "function" then pcall(M.RefreshStaticPins, M) end
        end
    end, 350)
end

local function applyState()
    local shouldHard = STATE.inCombat == true and STATE.groupSize >= 8
    if shouldHard then enterHardMode() else exitHardMode() end
end

local function refreshState()
    readGroupSize()
    readCombatState()
    applyState()
end

local function wrapThrottle(object, methodName, key, hardGap, normalGapResolver)
    if type(object) ~= "table" or type(object[methodName]) ~= "function" then return end
    local marker = "_easUnifiedPerf_" .. key
    if object[marker] then return end
    object[marker] = true

    local base = object[methodName]
    local lastKey = marker .. "_last"
    object[methodName] = function(self, ...)
        local stamp = nowMs()
        local gap = 0
        if hardMode() then
            gap = tonumber(hardGap) or 0
        elseif type(normalGapResolver) == "function" then
            gap = tonumber(normalGapResolver()) or 0
        end

        if gap > 0 and stamp > 0 then
            local last = tonumber(self and self[lastKey]) or -100000
            if (stamp - last) < gap then return end
            if self then self[lastKey] = stamp end
        end
        return base(self, ...)
    end
end

local function wrapHardNoOp(object, methodName, key)
    if type(object) ~= "table" or type(object[methodName]) ~= "function" then return end
    local marker = "_easUnifiedPerf_" .. key
    if object[marker] then return end
    object[marker] = true
    local base = object[methodName]
    object[methodName] = function(self, ...)
        if hardMode() then return end
        return base(self, ...)
    end
end

local function wrapHardSuccess(object, methodName, key)
    if type(object) ~= "table" or type(object[methodName]) ~= "function" then return end
    local marker = "_easUnifiedPerf_" .. key
    if object[marker] then return end
    object[marker] = true
    local base = object[methodName]
    object[methodName] = function(self, ...)
        if hardMode() then return true end
        return base(self, ...)
    end
end

local F = EPC.UnitFrames
wrapThrottle(F, "RefreshGroupFrames", "GroupFrames", 100000, function()
    if STATE.groupSize >= 8 then return STATE.inCombat and 300 or 220 end
    if STATE.inCombat then return 180 end
    if STATE.groupSize >= 4 then return 130 end
    return 90
end)
wrapThrottle(F, "RefreshPlayerAuras", "PlayerAuras", 250)
wrapThrottle(F, "RefreshTargetAuras", "TargetAuras", 300)

if type(EPC.RefreshResponsiveOverlays029343) == "function"
    and not EPC._easUnifiedResponsive029630 then
    EPC._easUnifiedResponsive029630 = true
    local baseResponsive = EPC.RefreshResponsiveOverlays029343
    EPC.RefreshResponsiveOverlays029343 = function(self, ...)
        if hardMode() then return end
        local stamp = nowMs()
        local gap = STATE.inCombat and 120 or 75
        local last = tonumber(self._easUnifiedResponsiveAt029630) or -100000
        if stamp > 0 and (stamp - last) < gap then return end
        self._easUnifiedResponsiveAt029630 = stamp
        return baseResponsive(self, ...)
    end
end

local A = EPC.AbilityOverlays
wrapThrottle(A, "Refresh", "AbilityOverlays", 750)

local RA = EPC.RotationAssistant
wrapThrottle(RA, "Refresh", "RotationAssistant", 850)

local D = EPC.DualActionBar
wrapThrottle(D, "RefreshDynamic029311", "DualDynamic", 650)

local T = EPC.TeamVisibility
wrapThrottle(T, "RefreshParticles", "TeamRefresh", 100000, function()
    return STATE.groupSize >= 8 and 350 or 220
end)
wrapHardNoOp(T, "FollowVisibleParticles", "TeamFollow")
wrapHardNoOp(T, "ResetRenderSpaces", "TeamReset")

local RP = EPC.ResourcePins
wrapHardNoOp(RP, "CaptureResourceInteraction", "ResourceInteract")
wrapHardNoOp(RP, "MovementAwareRefreshMarkers029312", "ResourceRender")
wrapHardNoOp(RP, "RefreshMarkers", "ResourceRefresh")
wrapHardNoOp(RP, "RecoverWorldRenderer", "ResourceRecover")

local MM = EPC.MiniMap
wrapThrottle(MM, "UpdatePlayerMarkerFast", "MiniPlayer", 66)
wrapThrottle(MM, "UpdatePanAndPins", "MiniPanPins", 500)
wrapHardNoOp(MM, "RefreshStaticPins", "MiniStaticPins")
wrapHardNoOp(MM, "RebuildMap", "MiniRebuild")
wrapHardSuccess(MM, "TrySyncHiddenPlayerMap", "MiniHiddenSync")

local PERF = EPC.PerformanceOverlay
wrapThrottle(PERF, "UpdateValues", "PerformanceOverlay", 1000)

local TT = EPC.TickTracker
local function takeTickTrackerOwnership()
    local tracker = EPC.TickTracker
    if not tracker then return end
    if tracker.frame and type(tracker.frame.SetHandler) == "function" then
        pcall(tracker.frame.SetHandler, tracker.frame, "OnUpdate", nil)
    end
end

if type(TT) == "table" and type(TT.Create) == "function" and not TT._easUnifiedCreate029630 then
    TT._easUnifiedCreate029630 = true
    local baseCreate = TT.Create
    TT.Create = function(self, ...)
        local result = baseCreate(self, ...)
        takeTickTrackerOwnership()
        return result
    end
end

unregisterOwnedUpdate(TICK_DRAW_NAME)
registerOwnedUpdate(TICK_DRAW_NAME, 50, function()
    local tracker = EPC.TickTracker
    if not tracker or not tracker.frame or type(tracker.RefreshText) ~= "function" then return end
    if type(tracker.frame.IsHidden) == "function" and tracker.frame:IsHidden() then return end

    local stamp = nowMs()
    local gap = hardMode() and 125 or 50
    local last = tonumber(tracker._easUnifiedDrawAt029630) or -100000
    if stamp > 0 and (stamp - last) < gap then return end
    tracker._easUnifiedDrawAt029630 = stamp
    tracker.lastDrawAt = stamp
    tracker:RefreshText()
end)

takeTickTrackerOwnership()
delayed(takeTickTrackerOwnership, 0)
delayed(takeTickTrackerOwnership, 500)

if EVENT_GROUP_UPDATE then
    registerOwnedEvent(PREFIX .. "_Group", EVENT_GROUP_UPDATE, function()
        readGroupSize()
        applyState()
    end)
end
if EVENT_GROUP_MEMBER_JOINED then
    registerOwnedEvent(PREFIX .. "_Join", EVENT_GROUP_MEMBER_JOINED, function()
        readGroupSize()
        applyState()
    end)
end
if EVENT_GROUP_MEMBER_LEFT then
    registerOwnedEvent(PREFIX .. "_Left", EVENT_GROUP_MEMBER_LEFT, function()
        readGroupSize()
        applyState()
    end)
end
if EVENT_PLAYER_ACTIVATED then
    registerOwnedEvent(PREFIX .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        refreshState()
        delayed(takeTickTrackerOwnership, 50)
        if takeCoreOwnership then
            delayed(takeCoreOwnership, 50)
            delayed(takeCoreOwnership, 500)
        end
    end)
end
if EVENT_PLAYER_COMBAT_STATE then
    registerOwnedEvent(PREFIX .. "_Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        STATE.inCombat = inCombat == true
        readGroupSize()
        applyState()
        if inCombat ~= true and takeCoreOwnership then delayed(takeCoreOwnership, 80) end
    end)
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easperf"] = function()
    local mode = hardMode() and "HARD TRIAL" or "NORMAL"
    local text = string.format(
        "ESO Adventurer Suite Performance: %s | group=%d | combat=%s | Tick Tracker=%s",
        mode,
        tonumber(STATE.groupSize) or 0,
        STATE.inCombat and "yes" or "no",
        (EPC.TickTracker and EPC.TickTracker.frame) and "timer-owned" or "not-created")
    if type(d) == "function" then d(text) end
end

refreshState()

-- v0.29.639 - integrated runtime + weapon-swap hot-path ownership.
-- The final swap gate is installed after every Dual Action Bar compatibility,
-- proc, availability, cast and live-state wrapper. This makes it the outermost
-- gate: normal Primary/Backup swaps cannot enter any deep dynamic/static chain.

local CORE_HUD_TIMER = (EPC.name or "ESOAdventurerSuite") .. "_CombatHUDPulse"
local MINI_TIMER = (EPC.name or "ESOAdventurerSuite") .. "_MiniMap_PlayerMarker"
local ABILITY_TIMER = (EPC.name or "ESOAdventurerSuite") .. "_AbilityOverlays_Tick"
local DUAL_TIMER = (EPC.name or "ESOAdventurerSuite") .. "_DualActionBar029189_Tick"
local ROTATION_TIMER = (EPC.name or "ESOAdventurerSuite") .. "_RotationAssistant_Tick"
local PERFORMANCE_TIMER = (EPC.name or "ESOAdventurerSuite") .. "_PerformanceOverlay_Pulse"
local TEAM_FOLLOW_TIMER = TEAM_PREFIX .. "_Follow"
local TEAM_PARTICLE_TIMER = TEAM_PREFIX .. "_Particles"

local function inCombat()
    return STATE.inCombat == true or (EPC.Combat and EPC.Combat.inCombat == true) or false
end

local function weaponSwapHeavyBlocked()
    local stamp = nowMs()
    local untilMs = tonumber(EPC.weaponSwapBroadRefreshUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029636)
        or tonumber(EPC.weaponSwapSettlingUntil029635)
        or 0
    return stamp > 0 and stamp < untilMs
end

local function activeHotbarCategory()
    if type(GetActiveHotbarCategory) ~= "function" then return nil end
    local ok, value = pcall(GetActiveHotbarCategory)
    return ok and value or nil
end

local function ordinaryWeaponSwapBlocked()
    if not weaponSwapHeavyBlocked() then return false end

    -- Special/transformed bars genuinely change their slot set and are allowed
    -- through the structural path. The hard gate is only for ordinary front/back.
    local D = EPC.DualActionBar
    local category = activeHotbarCategory()
    if D and type(D.IsSingleTransformedHotbar029554) == "function" then
        local ok, transformed = pcall(D.IsSingleTransformedHotbar029554, D, category)
        if ok and transformed == true then return false end
    end

    local primary = rawget(_G, "HOTBAR_CATEGORY_PRIMARY")
    local backup = rawget(_G, "HOTBAR_CATEGORY_BACKUP")
    if primary == nil then primary = 0 end
    if backup == nil then backup = 1 end
    return category == nil or category == primary or category == backup
end

local function due(owner, key, gapMs)
    if type(owner) ~= "table" then return true end
    local stamp = nowMs()
    local last = tonumber(owner[key]) or -100000
    if stamp > 0 and (stamp - last) < (tonumber(gapMs) or 0) then return false end
    owner[key] = stamp
    return true
end

local function bump(key)
    EPC.swapPerfCounters029639 = EPC.swapPerfCounters029639 or {}
    EPC.swapPerfCounters029639[key] = (tonumber(EPC.swapPerfCounters029639[key]) or 0) + 1
end

-- FINAL/OUTERMOST WEAPON-SWAP GATES -----------------------------------------
-- These wrappers are intentionally installed from this late-loaded file, after
-- AbilityAvailabilityFix, AbilityCastPerformanceFix and LiveAbilityStateFix.
-- The old guard in GlobalWeaponSwapPerformanceFix was buried inside later
-- wrappers, so those outer layers could still scan slots/effects before it ran.
local function installFinalSwapGates()
    local D = EPC.DualActionBar
    if D and type(D.RefreshDynamic029311) == "function" and not D._easFinalSwapDynamicGate029639 then
        D._easFinalSwapDynamicGate029639 = true
        local base = D.RefreshDynamic029311
        D.RefreshDynamic029311 = function(self, force, ...)
            if self.layoutMode ~= true and ordinaryWeaponSwapBlocked() then
                bump("dynamic")
                return nil
            end
            return base(self, force, ...)
        end
    end

    if D and type(D.RefreshStatic029311) == "function" and not D._easFinalSwapStaticGate029639 then
        D._easFinalSwapStaticGate029639 = true
        local base = D.RefreshStatic029311
        D.RefreshStatic029311 = function(self, ...)
            if self.layoutMode ~= true and ordinaryWeaponSwapBlocked() then
                bump("static")
                return nil
            end
            return base(self, ...)
        end
    end

    -- EVENT_EFFECT_CHANGED and stack/proc paths can call this with force=true.
    -- Previously force=true bypassed the swap guard and caused the full dynamic
    -- chain ~50 ms after every weapon swap. Drop the request entirely; the normal
    -- controlled timer reconciles the rendered state once ESO settles.
    if D and type(D.QueueDynamicRefresh029386) == "function" and not D._easFinalSwapQueueGate029639 then
        D._easFinalSwapQueueGate029639 = true
        local base = D.QueueDynamicRefresh029386
        D.QueueDynamicRefresh029386 = function(self, force, ...)
            if self.layoutMode ~= true and ordinaryWeaponSwapBlocked() then
                self.pendingDynamicRefreshForce029386 = false
                bump("queue")
                return nil
            end
            return base(self, force, ...)
        end
    end

    local A = EPC.AbilityOverlays
    if A and type(A.Refresh) == "function" and not A._easFinalSwapGate029639 then
        A._easFinalSwapGate029639 = true
        local base = A.Refresh
        A.Refresh = function(self, ...)
            if self.layoutMode ~= true and ordinaryWeaponSwapBlocked() then
                bump("ability")
                return nil
            end
            return base(self, ...)
        end
    end

    local R = EPC.RotationAssistant
    if R and type(R.Refresh) == "function" and not R._easFinalSwapGate029639 then
        R._easFinalSwapGate029639 = true
        local base = R.Refresh
        R.Refresh = function(self, ...)
            if self.layoutMode ~= true and ordinaryWeaponSwapBlocked() then
                bump("rotation")
                return nil
            end
            return base(self, ...)
        end
    end
end

-- RefreshNow builds a broad Engine snapshot that includes gear/set inspection.
-- That is useful for menus, not for a trial gameplay frame. Event requests stay
-- pending and are reconciled after hard mode ends.
if type(EPC.RefreshNow) == "function" and not EPC._easCoreRefreshPerf029634 then
    EPC._easCoreRefreshPerf029634 = true
    local baseRefreshNow = EPC.RefreshNow
    EPC.RefreshNow = function(self, reason, ...)
        if hardMode() and not self.unitFramesMoveMode and not self.combatHudMoveMode then
            self.refreshPending = true
            self.refreshReason = reason or self.refreshReason or "trial-deferred"
            return
        end
        return baseRefreshNow(self, reason, ...)
    end
end

local function ownCombatHudTimer()
    if not EPC.Combat or not EPC.UI or type(EPC.UI.UpdateCombatHUD) ~= "function" then return end

    unregisterOwnedUpdate(CORE_HUD_TIMER)
    registerOwnedUpdate(CORE_HUD_TIMER, 250, function()
        if not EPC.Combat or not EPC.UI or not EPC.saved then return end
        local preview = EPC.combatHudMoveMode == true or EPC.unitFramesMoveMode == true
        if EPC.saved.showCombatHud == false and not preview then return end

        local gap
        if preview then gap = 100
        elseif hardMode() then gap = 750
        elseif EPC.Combat.inCombat then gap = 250
        else gap = 1000 end
        if not due(EPC, "_easCoreHudAt029634", gap) then return end

        local summary = nil
        if type(EPC.Combat.GetHUDSummary) == "function" then
            summary = EPC.Combat:GetHUDSummary()
        end
        EPC.UI:UpdateCombatHUD(summary)
    end)
end

local function ownMiniMapMarkerTimer()
    local M = EPC.MiniMap
    if not M or type(M.UpdatePlayerMarkerFast) ~= "function" then return end

    unregisterOwnedUpdate(MINI_TIMER)
    registerOwnedUpdate(MINI_TIMER, 33, function()
        local mm = EPC.MiniMap
        if not mm or not mm.frame or not EPC.saved then return end
        if type(mm.frame.IsHidden) == "function" and mm.frame:IsHidden() then return end

        local gap = hardMode() and 66 or 33
        if not due(mm, "_easMarkerTimerAt029634", gap) then return end
        mm:UpdatePlayerMarkerFast(false, false)
    end)
end

local function ownAbilityOverlayTimer()
    local A = EPC.AbilityOverlays
    if not A or type(A.Refresh) ~= "function" then return end

    unregisterOwnedUpdate(ABILITY_TIMER)
    registerOwnedUpdate(ABILITY_TIMER, 250, function()
        local current = EPC.AbilityOverlays
        if not current or not EPC.saved or EPC.saved.showAbilityOverlays == false then return end
        if current.layoutMode ~= true and ordinaryWeaponSwapBlocked() then return end
        local combat = inCombat()
        if current.layoutMode ~= true and not combat and not due(current, "_easTimerIdle029634", 1000) then return end
        if hardMode() and current.layoutMode ~= true and not due(current, "_easTimerHard029634", 750) then return end
        current:Refresh()
    end)
end

local function ownDualActionBarTimer()
    local D = EPC.DualActionBar
    if not D or type(D.RefreshDynamic029311) ~= "function" then return end

    unregisterOwnedUpdate(DUAL_TIMER)
    registerOwnedUpdate(DUAL_TIMER, 250, function()
        local current = EPC.DualActionBar
        if not current or not EPC.saved or EPC.saved.showDualActionBar029189 ~= true then return end
        if current.layoutMode ~= true and ordinaryWeaponSwapBlocked() then return end

        local combat = inCombat()
        local gap = current.layoutMode == true and 250 or (hardMode() and 900 or (combat and 300 or 1000))
        if not due(current, "_easDynamicTimerAt029639", gap) then return end
        current:RefreshDynamic029311(false)
    end)
end

local function ownRotationTimer()
    local R = EPC.RotationAssistant
    if not R or type(R.Refresh) ~= "function" then return end

    unregisterOwnedUpdate(ROTATION_TIMER)
    registerOwnedUpdate(ROTATION_TIMER, 350, function()
        local current = EPC.RotationAssistant
        if not current or not EPC.saved or EPC.saved.rotationAssistantEnabled == false then return end
        if current.layoutMode ~= true and ordinaryWeaponSwapBlocked() then return end
        if current.layoutMode ~= true and not inCombat() then return end
        local gap = hardMode() and 900 or 350
        if not due(current, "_easRotationTimerAt029634", gap) then return end
        current:Refresh()
    end)
end

ownTeamVisibilityTimers = function()
    unregisterOwnedUpdate(TEAM_FOLLOW_TIMER)
    unregisterOwnedUpdate(TEAM_PARTICLE_TIMER)
    if hardMode() then return end

    local T = EPC.TeamVisibility
    if not T then return end

    if type(T.FollowVisibleParticles) == "function" then
        registerOwnedUpdate(TEAM_FOLLOW_TIMER, 66, function()
            local current = EPC.TeamVisibility
            if not current or hardMode() or type(current.FollowVisibleParticles) ~= "function" then return end
            if type(current.IsEnabled) == "function" then
                local ok, enabled = pcall(current.IsEnabled, current)
                if ok and enabled == false then return end
            end
            current:FollowVisibleParticles()
        end)
    end

    if type(T.RefreshParticles) == "function" then
        registerOwnedUpdate(TEAM_PARTICLE_TIMER, 1200, function()
            local current = EPC.TeamVisibility
            if not current or hardMode() or type(current.RefreshParticles) ~= "function" then return end
            current:RefreshParticles()
        end)
    end
end

local function ownPerformanceOverlayTimer()
    local P = EPC.PerformanceOverlay
    if not P or type(P.UpdateValues) ~= "function" then return end

    unregisterOwnedUpdate(PERFORMANCE_TIMER)
    registerOwnedUpdate(PERFORMANCE_TIMER, 1000, function()
        local current = EPC.PerformanceOverlay
        if not current or not current.frame or not EPC.saved then return end
        local enabled = EPC.saved.showPerformanceOverlay ~= false
        if type(current.SuppressNative) == "function" then
            current:SuppressNative(enabled and EPC.saved.suppressNativePerformanceMeters ~= false)
        end
        local show = type(current.ShouldShow) == "function" and current:ShouldShow() or enabled
        if type(current.ApplyHudReason) == "function" then current:ApplyHudReason(show) end
        if enabled then current:UpdateValues() end
    end)
end

takeCoreOwnership = function()
    installFinalSwapGates()
    ownCombatHudTimer()
    ownMiniMapMarkerTimer()
    ownAbilityOverlayTimer()
    ownDualActionBarTimer()
    ownRotationTimer()
    ownTeamVisibilityTimers()
    ownPerformanceOverlayTimer()
end

-- All action-bar wrapper files have already loaded before this file, so install
-- the outermost guards immediately. Module initialization can replace timer
-- registrations; the controller's single activation/combat owner above reapplies
-- takeCoreOwnership when needed.
installFinalSwapGates()
takeCoreOwnership()

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easperfmem"] = function()
    local luaKb = nil
    if type(collectgarbage) == "function" then
        local ok, value = pcall(collectgarbage, "count")
        if ok then luaKb = tonumber(value) end
    end

    local poolMb = nil
    if type(GetTotalUserAddOnMemoryPoolUsageMB) == "function" then
        local ok, value = pcall(GetTotalUserAddOnMemoryPoolUsageMB)
        if ok then poolMb = tonumber(value) end
    end

    local parts = {
        "ESO Adventurer Suite runtime",
        hardMode() and "HARD TRIAL" or "NORMAL",
    }
    if luaKb then parts[#parts + 1] = string.format("Lua %.1f MB", luaKb / 1024) end
    if poolMb and poolMb > 0 then parts[#parts + 1] = string.format("addon pool %.1f MB", poolMb) end
    if type(d) == "function" then d(table.concat(parts, " | ")) end
end

SLASH_COMMANDS["/easswapstats"] = function()
    local c = EPC.swapPerfCounters029639 or {}
    local text = string.format(
        "EAS swap blocks | dynamic=%d static=%d queue=%d ability=%d rotation=%d",
        tonumber(c.dynamic) or 0,
        tonumber(c.static) or 0,
        tonumber(c.queue) or 0,
        tonumber(c.ability) or 0,
        tonumber(c.rotation) or 0)
    if type(d) == "function" then d(text) end
end
