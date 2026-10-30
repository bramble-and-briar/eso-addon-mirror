local checks = 0

local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, string.format("%s: expected %s, got %s",
        message, tostring(expected), tostring(actual)))
end

local function loadAddonFile(env, path)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end

local function fixture(overrides)
    local state = {
        camera = { distance = 4, horizontalOffset = 0, verticalOffset = 0 },
        timers = {}, events = {}, hooks = {}, logs = {}, writes = 0, now = 0,
    }
    local env = setmetatable({ SLASH_COMMANDS = {} }, { __index = _G })
    local strings = {}
    local nextStringId = 0
    env.ZO_CreateStringId = function(name, text)
        nextStringId = nextStringId + 1
        env[name] = nextStringId
        strings[nextStringId] = text
    end
    env.GetString = function(id) return assert(strings[id], tostring(id)) end
    env.d = function(message) state.logs[#state.logs + 1] = message end
    env.GetSetting = function(_, key)
        if state.readFailed then return nil end
        return tostring(state.camera[key] or 0)
    end
    env.SetSetting = function(_, key, value)
        state.writes = state.writes + 1
        if state.writeFailed then return false end
        state.camera[key] = tonumber(value)
    end
    env.SETTING_TYPE_CAMERA = "camera"
    local settingIds = {
        DISTANCE = "distance", THIRD_PERSON_FIELD_OF_VIEW = "thirdPersonFov",
        FIRST_PERSON_FIELD_OF_VIEW = "firstPersonFov",
        THIRD_PERSON_HORIZONTAL_OFFSET = "horizontalOffset",
        THIRD_PERSON_VERTICAL_OFFSET = "verticalOffset",
        THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER = "shoulder",
        FIRST_PERSON_HEAD_BOB = "headBob", SCREEN_SHAKE = "screenShake",
        SMOOTHING = "smoothing",
    }
    for id, key in pairs(settingIds) do env["CAMERA_SETTING_" .. id] = key end
    for _, event in ipairs({ "EVENT_ADD_ON_LOADED", "EVENT_PLAYER_ACTIVATED",
        "EVENT_PLAYER_DEACTIVATED" }) do env[event] = event end
    env.EVENT_MANAGER = {
        RegisterForEvent = function(_, _, event, callback) state.events[event] = callback end,
        UnregisterForEvent = function(_, _, event) state.events[event] = nil end,
        RegisterForUpdate = function(_, name, delay, callback)
            state.timers[name] = { delay = delay, callback = callback }
        end,
        UnregisterForUpdate = function(_, name) state.timers[name] = nil end,
    }
    env.ZO_PreHook = function(name, callback) state.hooks[name] = callback end
    env.IsGameCameraSiegeControlled = function() return state.siege or false end
    env.IsMounted = function() return false end
    env.IsPlayerInWerewolfForm = function() return false end
    env.IsUnitSwimming = function() return false end
    env.GetGameTimeMilliseconds = function() return state.now end
    env.ZO_SavedVars = {
        NewAccountWide = function(_, _, _, _, defaults)
            local vars = {}
            for key, value in pairs(defaults) do vars[key] = value end
            for key, value in pairs(overrides or {}) do vars[key] = value end
            return vars
        end,
    }
    loadAddonFile(env, "Localization\\en.lua")
    loadAddonFile(env, "BureauOfAcceptableViews.lua")
    loadAddonFile(env, "CameraSettings.lua")
    loadAddonFile(env, "Settings.lua")
    local addon = env.BureauOfAcceptableViews
    addon.ContextPresets = {
        GetStyleIds = function() return { "off", "subtle", "cinematic", "action" } end,
        GetOffStyleId = function() return "off" end,
    }
    state.events[env.EVENT_ADD_ON_LOADED](env.EVENT_ADD_ON_LOADED, addon.name)
    state.vars = addon.private.savedVars
    state.addon, state.env = addon, env
    return state
end

for _, direction in ipairs({ -1, 1 }) do
    for _, zoom in ipairs({ 0, 0.01, 0.34, 0.35, 1.99, 2, 2.01, 4, 9.9, 10 }) do
        for _, step in ipairs({ 0.05, 0.35, 2.25 }) do
            for _, threshold in ipairs({ 0, 2, 10 }) do
                local state = fixture({ zoomStep = step, lastZoomThreshold = threshold,
                    lastThirdPersonZoom = 4 })
                local addon = state.addon
                addon.debugMode = 4
                state.camera.distance = zoom
                local hook = state.hooks[direction < 0 and "CameraZoomIn" or "CameraZoomOut"]
                equal(hook(), true, "zoom input handled")
                local atBoundary = direction < 0 and zoom <= 0 or direction > 0 and zoom >= 10
                local expected = atBoundary and zoom or tonumber(string.format("%.2f",
                    math.max(0, math.min(10, zoom + direction * step))))
                equal(state.camera.distance, expected, "zoom distance")
                equal(state.writes, atBoundary and 0 or 1, "zoom write count")
                equal(addon.private.GetLastZoom(),
                    not atBoundary and expected > threshold and expected or 4, "remembered zoom")
                local timer = state.timers[addon.name .. "_QueuedSave"]
                equal(timer ~= nil, not atBoundary, "save queued after successful write only")
                if timer then
                    equal(timer.delay, 1000, "save delay")
                    timer.callback()
                    equal(state.vars.currentZoom, expected, "persisted zoom")
                    equal(state.timers[addon.name .. "_QueuedSave"], nil, "save self-teardown")
                end
                local preserveText = string.format(state.env.GetString(
                    state.env.SI_BAV_LOG_SOURCE_PRESERVING_LASTZOOM),
                    state.env.GetString(direction < 0 and state.env.SI_BAV_SOURCE_ZOOM_IN
                        or state.env.SI_BAV_SOURCE_ZOOM_OUT), 4)
                local preserved = false
                for _, log in ipairs(state.logs) do
                    if log:find(preserveText, 1, true) then preserved = true end
                end
                equal(preserved, not atBoundary and direction < 0
                    and expected <= threshold and 4 > threshold, "direction-specific preservation log")
            end
        end
    end
end

for _, hookName in ipairs({ "CameraZoomIn", "CameraZoomOut" }) do
    for _, failure in ipairs({ "siege", "readFailed", "writeFailed" }) do
        local state = fixture()
        local lastZoom = state.addon.private.GetLastZoom()
        state[failure] = true
        equal(state.hooks[hookName](), false, "failed zoom passes through to ESO")
        equal(state.camera.distance, 4, "failed zoom leaves distance unchanged")
        equal(state.addon.private.GetLastZoom(), lastZoom, "failed zoom preserves remembered distance")
        equal(state.timers[state.addon.name .. "_QueuedSave"], nil, "failed zoom does not queue save")
        equal(state.writes, failure == "writeFailed" and 1 or 0, "failed zoom write count")
    end
    local state = fixture({ zoomStep = 0.35, pvpZoomStep = 0.5 })
    state.addon.PvpMode = { IsActiveInPvpWorld = function() return true end }
    equal(state.hooks[hookName](), true, "PvP zoom handled")
    equal(state.camera.distance, hookName == "CameraZoomIn" and 3.5 or 4.5, "dedicated PvP step")
end

local stateIds = { "combat", "werewolf", "stealth", "interaction", "mounted", "swimming", "sprint" }
local stateSettings = {
    { key = "presetStates", get = "GetPresetStates", single = "GetPresetState", set = "SetPresetState",
        default = "off", samples = { { "cinematic", "cinematic" }, { "unknown", "off" }, { false, "off" } } },
    { key = "presetStateIntensities", get = "GetPresetStateIntensities", single = "GetPresetStateIntensity",
        set = "SetPresetStateIntensity", default = 1,
        samples = { { "0.4", 0.4 }, { -1, 0 }, { 2, 1 }, { false, 1 } } },
    { key = "presetStateCoalesce", get = "GetPresetStateCoalesces", single = "GetPresetStateCoalesce",
        set = "SetPresetStateCoalesce", default = 0,
        samples = { { "1500", 1500 }, { -1, 0 }, { 12.5, 12.5 }, { false, 0 } } },
}
for _, spec in ipairs(stateSettings) do
    local state = fixture()
    local settings = state.addon.Settings
    local applies = 0
    settings.ApplyOptionalFeatureConfig = function() applies = applies + 1 end
    for _, malformed in ipairs({ false, "invalid", 12 }) do
        state.vars[spec.key] = malformed
        local map = settings[spec.get]()
        for _, id in ipairs(stateIds) do equal(map[id], spec.default, "malformed map fallback") end
        equal(settings[spec.single]("combat"), spec.default, "malformed single fallback")
    end
    state.vars[spec.key] = nil
    local defaults = settings[spec.get]()
    for _, id in ipairs(stateIds) do equal(defaults[id], spec.default, "missing map fallback") end
    for _, sample in ipairs(spec.samples) do
        for _, id in ipairs(stateIds) do
            state.vars[spec.key] = { [id] = sample[1], stale = sample[1] }
            local before = state.vars[spec.key]
            local map = settings[spec.get]()
            local count = 0
            for _ in pairs(map) do count = count + 1 end
            equal(count, #stateIds, "full map has exactly the supported states")
            equal(map[id], sample[2], "map normalization")
            equal(settings[spec.single](id), sample[2], "single normalization")
            equal(map.stale, nil, "full map omits stale keys")
            equal(before[id], sample[1], "reading does not mutate saved state")
            map[id] = "changed"
            equal(settings[spec.get]()[id], sample[2], "maps are fresh copies")
            local calls = applies
            equal(settings[spec.set](id, sample[1]), nil, "setter return contract")
            equal(state.vars[spec.key][id], sample[2], "setter normalization")
            equal(applies, calls + 1, "one configuration refresh per accepted change")
        end
    end
    state.vars[spec.key] = false
    local calls = applies
    settings[spec.set]("unknown", "invalid")
    equal(type(state.vars[spec.key]), "table", "setter repairs map before rejecting unknown state")
    equal(state.vars[spec.key].unknown, nil, "new unknown state rejected")
    equal(applies, calls, "unknown state does not refresh configuration")
    state.vars[spec.key].stale = "invalid"
    settings[spec.set]("stale", nil)
    equal(state.vars[spec.key].stale, spec.default, "existing stale key behavior preserved")
    state.addon.private.savedVars = nil
    settings[spec.set]("combat", "invalid")
    equal(applies, calls + 1, "setter without saved variables is inert")
    equal(settings[spec.single]("combat"), spec.default, "uninitialized saved variables fallback")
end

for _, axis in ipairs({ "Horizontal", "Vertical" }) do
    local state = fixture()
    local addon = state.addon
    loadAddonFile(state.env, "OffsetNudge.lua")
    local nudge = addon.OffsetNudge
    nudge.Configure({ overlay = false })
    nudge["Start" .. axis](1)
    equal(nudge.IsHolding(), false, "nudge without home is blocked")
    equal(state.timers.BAV_OffsetNudge_Move, nil, "blocked nudge has no updater")
    nudge.Configure({ home = { horizontal = 0, vertical = 0 } })
    nudge["Start" .. axis](1)
    local timer = state.timers.BAV_OffsetNudge_Move
    equal(timer ~= nil, true, "nudge starts updater")
    equal(nudge.IsHolding(), true, "nudge holds axis")
    state.now = 16
    timer.callback()
    local key = axis == "Horizontal" and "horizontalOffset" or "verticalOffset"
    equal(state.camera[key], 0.06, "positive nudge moves requested axis")
    nudge["Start" .. axis](-1)
    equal(state.timers.BAV_OffsetNudge_Move, timer, "direction change reuses updater")
    nudge["Stop" .. axis](1)
    equal(nudge.IsHolding(), true, "release of older direction does not cancel newer hold")
    state.now = 32
    timer.callback()
    equal(state.camera[key], 0, "opposite direction reverses movement")
    nudge["Start" .. (axis == "Horizontal" and "Vertical" or "Horizontal")](1)
    nudge["Stop" .. axis](-1)
    equal(nudge.IsHolding(), true, "other axis remains held")
    nudge["Stop" .. (axis == "Horizontal" and "Vertical" or "Horizontal")](1)
    equal(nudge.IsHolding(), false, "final release clears hold")
    equal(state.timers.BAV_OffsetNudge_Move, nil, "final release removes updater")
    nudge["Start" .. axis](1)
    state.events[state.env.EVENT_PLAYER_DEACTIVATED]()
    equal(nudge.IsHolding(), false, "load screen cancels held nudge")
    equal(state.timers.BAV_OffsetNudge_Move, nil, "load screen removes updater")
end

local SMOOTHING_RESTORE_TIMER = "BAV_CameraResponse_RestoreSmoothing"

local function smoothingFixture(initialValue)
    local state = fixture()
    state.camera.smoothing = initialValue or 1
    loadAddonFile(state.env, "Ease.lua")
    loadAddonFile(state.env, "CameraResponse.lua")
    state.response = state.addon.CameraResponse
    return state
end

local function runSmoothingRestore(state)
    local timer = state.timers[SMOOTHING_RESTORE_TIMER]
    equal(timer ~= nil, true, "smoothing restore is scheduled")
    timer.callback()
end

for _, initialValue in ipairs({ 0, 1 }) do
    local state = smoothingFixture(initialValue)
    local response = state.response
    equal(response.AcquireSmoothing("first"), true, "first smoothing owner acquired")
    equal(response.AcquireSmoothing("second"), true, "overlapping smoothing owner acquired")
    equal(response.AcquireSmoothing("first"), false, "duplicate smoothing owner rejected")
    equal(state.camera.smoothing, 0, "smoothing suspended while owned")
    equal(response.ReleaseSmoothing("first"), true, "first smoothing owner released")
    equal(state.timers[SMOOTHING_RESTORE_TIMER], nil, "remaining owner prevents restore")
    equal(response.ReleaseSmoothing("second"), true, "last smoothing owner released")
    equal(state.timers[SMOOTHING_RESTORE_TIMER].delay, 0, "normal restore waits one frame")
    runSmoothingRestore(state)
    equal(state.camera.smoothing, initialValue, "original smoothing value restored")
    equal(state.timers[SMOOTHING_RESTORE_TIMER], nil, "successful restore removes timer")
    equal(state.writes, initialValue == 0 and 0 or 2, "unchanged smoothing avoids writes")
    state.camera.smoothing = 1 - initialValue
    response.AcquireSmoothing("later-transition")
    response.ReleaseSmoothing("later-transition")
    runSmoothingRestore(state)
    equal(state.camera.smoothing, 1 - initialValue, "successful recovery clears the old snapshot")
end

for _, recoveryPath in ipairs({ "deferred", "immediate", "native" }) do
    local state = smoothingFixture()
    local response = state.response
    response.AcquireSmoothing("transition")
    state.writeFailed = true
    if recoveryPath == "deferred" then
        response.ReleaseSmoothing("transition")
        runSmoothingRestore(state)
    elseif recoveryPath == "immediate" then
        response.RestoreSmoothingNow()
    else
        response.Configure({ mode = "native" })
    end
    equal(state.camera.smoothing, 0, "rejected restore leaves current smoothing unchanged")
    equal(state.timers[SMOOTHING_RESTORE_TIMER] ~= nil, true, "rejected restore schedules retry")
    equal(state.timers[SMOOTHING_RESTORE_TIMER].delay, 100, "rejected restore schedules delayed retry")
    state.writeFailed = false
    runSmoothingRestore(state)
    equal(state.camera.smoothing, 1, "transient failure preserves original smoothing value")
    equal(state.timers[SMOOTHING_RESTORE_TIMER], nil, "recovered restore removes retry timer")
end

for _, recoveryPath in ipairs({ "new-owner", "immediate" }) do
    local state = smoothingFixture()
    local response = state.response
    response.AcquireSmoothing("transition")
    response.ReleaseSmoothing("transition")
    state.writeFailed = true
    for attempt = 1, 4 do runSmoothingRestore(state) end
    equal(state.timers[SMOOTHING_RESTORE_TIMER], nil, "permanent rejection stops after three retries")
    equal(state.writes, 5, "restore retries are bounded")
    state.writeFailed = false
    if recoveryPath == "new-owner" then
        response.AcquireSmoothing("later-transition")
        response.ReleaseSmoothing("later-transition")
        runSmoothingRestore(state)
    else
        response.RestoreSmoothingNow()
    end
    equal(state.camera.smoothing, 1, "exhausted retries retain original value for later recovery")
    equal(state.timers[SMOOTHING_RESTORE_TIMER], nil, "later recovery removes timer")
end

for _, failedReadback in ipairs({ false, true }) do
    local state = smoothingFixture()
    local response = state.response
    response.AcquireSmoothing("transition")
    response.ReleaseSmoothing("transition")
    local originalGet = state.addon.CameraSettings.Get
    if failedReadback then
        state.addon.CameraSettings.Get = function() return nil, false end
    else
        state.writeFailed = true
    end
    runSmoothingRestore(state)
    state.addon.CameraSettings.Get = originalGet
    state.writeFailed = false
    if failedReadback then
        equal(state.camera.smoothing, 1, "unverified restore may already have applied")
    end
    equal(response.AcquireSmoothing("next-transition"), true, "new owner interrupts recovery")
    equal(state.camera.smoothing, 0, "new owner ensures smoothing is disabled after failed verification")
    equal(state.timers[SMOOTHING_RESTORE_TIMER], nil, "new owner cancels retry timer")
    response.ReleaseSmoothing("next-transition")
    runSmoothingRestore(state)
    equal(state.camera.smoothing, 1, "new owner preserves original recovery value")
end

for _, failure in ipairs({ "readFailed", "writeFailed" }) do
    local state = smoothingFixture()
    local response = state.response
    response.AcquireSmoothing("transition")
    response.ReleaseSmoothing("transition")
    local originalGet = state.addon.CameraSettings.Get
    state.addon.CameraSettings.Get = function() return nil, false end
    runSmoothingRestore(state)
    state.addon.CameraSettings.Get = originalGet
    local retry = state.timers[SMOOTHING_RESTORE_TIMER]
    state[failure] = true
    equal(response.AcquireSmoothing("unavailable"), false, "failed acquisition does not take ownership")
    equal(state.timers[SMOOTHING_RESTORE_TIMER], retry, "failed acquisition preserves recovery timer")
    state[failure] = false
    runSmoothingRestore(state)
    equal(state.camera.smoothing, 1, "recovery survives failed acquisition")
    equal(state.timers[SMOOTHING_RESTORE_TIMER], nil, "recovery after failed acquisition removes timer")
end

print(string.format("PASS: %d regression assertions", checks))
