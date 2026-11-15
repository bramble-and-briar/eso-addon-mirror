NQOL = NQOL or {}

-- Initialization runs only after ESO has restored the manifest's saved variables.
-- A task must be bounded itself: Lua cannot interrupt an individual initializer.
local Initialization = {}
local UPDATE_NAMESPACE = "NQOL_Initialization"
local SLICE_MS = 3
local MAX_STEPS_PER_FRAME = 4
local tasks
local nextTask = 1
local playerActive = false
local updateRegistered = false
local lastFrame
local status = "idle"
local failedStep
local RunFrame

local function StopUpdates()
    if updateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE)
        updateRegistered = false
    end
end

local function StopEvents()
    EVENT_MANAGER:UnregisterForEvent(UPDATE_NAMESPACE, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(UPDATE_NAMESPACE, EVENT_PLAYER_DEACTIVATED)
end

local function HasSharedBudget()
    if type(GetTotalUserAddOnCPUTimeAvailableEachFrameMS) ~= "function"
        or type(GetTotalUserAddOnCPUTimeUsedNowMS) ~= "function" then
        return true
    end
    local available = GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
    -- The console pool APIs can report zero outside console flow.
    if type(available) ~= "number" or available <= 0 then
        return true
    end
    local used = GetTotalUserAddOnCPUTimeUsedNowMS()
    return type(used) ~= "number" or used < available - math.max(SLICE_MS, available * 0.1)
end

local function Wake()
    if not tasks or updateRegistered then
        return
    end
    status = "running"
    updateRegistered = true
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAMESPACE, 1, RunFrame)
end

RunFrame = function()
    local frame = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds()
    if frame ~= nil and frame == lastFrame then
        return
    end
    lastFrame = frame
    local started = GetGameTimeMilliseconds and GetGameTimeMilliseconds()
    local steps = 0

    while tasks and steps < MAX_STEPS_PER_FRAME do
        local task = tasks[nextTask]
        if not task then
            tasks = nil
            status = "ready"
            StopUpdates()
            StopEvents()
            return
        end
        if task.requiresPlayer and not playerActive then
            status = "waiting"
            StopUpdates()
            return
        end
        if not HasSharedBudget() then
            return
        end
        if started and GetGameTimeMilliseconds() - started >= SLICE_MS then
            return
        end

        local ok, err = pcall(task.run)
        if not ok then
            failedStep = task.name
            status = "failed"
            tasks = nil
            StopUpdates()
            StopEvents()
            -- Preserve ESO's normal Lua-error reporting; never mark partial startup ready.
            error(err, 0)
        end
        tasks[nextTask] = false
        nextTask = nextTask + 1
        steps = steps + 1
        if task.yieldAfter then
            return
        end
    end
end

function Initialization.Start(steps)
    if status ~= "idle" then
        return
    end
    tasks = steps
    -- Latch activation even if it happens before the saved-variable steps finish.
    EVENT_MANAGER:RegisterForEvent(UPDATE_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        playerActive = true
        Wake()
    end)
    EVENT_MANAGER:RegisterForEvent(UPDATE_NAMESPACE, EVENT_PLAYER_DEACTIVATED, function()
        playerActive = false
    end)
    Wake()
end

function Initialization.IsReady()
    return status == "ready"
end

function Initialization.GetStatus()
    return status, failedStep
end

NQOL.Initialization = Initialization
