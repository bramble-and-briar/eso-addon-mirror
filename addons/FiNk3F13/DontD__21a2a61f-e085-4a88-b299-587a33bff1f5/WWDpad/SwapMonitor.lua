-- Observe WW's asynchronous work without cancelling or modifying its tasks.
WWDpadMonitor = {}
local M = WWDpadMonitor
local tasks = setmetatable({}, {__mode = "k"})
local active
local initialized = false
local canObserveTasks = false
local unpackValues = unpack or table.unpack

local function Pack(...) return {n = select("#", ...), ...} end

function M.Stop()
    active = nil
    EVENT_MANAGER:UnregisterForUpdate("WWDpadSwapWatch")
end

function M.Initialize(ww)
    if initialized then return end
    initialized = true
    if LibAsync and LibAsync.task and type(LibAsync.task.Resume) == "function" then
        ZO_PreHook(LibAsync.task, "Resume", function(task)
            if type(task.name) == "string" and task.name:sub(1, #ww.name) == ww.name then
                tasks[task] = true
                if active then
                    if task.name == ww.name .. "SetupTask" then active.sawSetupTask = true end
                    active.idleSamples = 0
                end
            end
        end)
        canObserveTasks = true
    end
    if ww.validation and type(ww.validation.SetupFailWorkaround) == "function" then
        ZO_PreHook(ww.validation, "SetupFailWorkaround", function()
            if active then active.validationSeen = true end
        end)
    end
    if type(ww.LoadGear) == "function" then
        local original = ww.LoadGear
        ww.LoadGear = function(...)
            local state = active
            local result = Pack(original(...))
            -- WW only starts success validation if all requested items exist.
            -- Preserve every return value; never change the underlying result.
            if state and state == active and not state.gearObserved then
                state.gearObserved = true
                if result[2] == false then state.noValidationExpected = true end
            end
            return unpackValues(result, 1, result.n)
        end
    end
    if type(ww.Log) == "function" and type(GetString) == "function" and WW_MSG_SWAP_FIX_FAIL then
        local original = ww.Log
        local failureText = GetString(WW_MSG_SWAP_FIX_FAIL)
        ww.Log = function(message, ...)
            if active and message == failureText then active.validationFailed = true end
            return original(message, ...)
        end
    end
end

local function Inspect()
    local state = active
    if not state then return end
    local now = GetFrameTimeMilliseconds()
    local delta = math.max(0, now - state.lastCheck)
    state.lastCheck = now
    if IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then
        state.idleSamples = 0
        return -- combat time does not consume the out-of-combat watchdog
    end
    state.elapsed = state.elapsed + delta
    local ww = WizardsWardrobe
    local idle = canObserveTasks and state.sawSetupTask
    for task in pairs(tasks) do
        if type(task.callstack) ~= "table" or next(task.callstack) or task.currentCallLaterId then idle = false end
        if task.Error and task.Error ~= state.previousErrors[task] then idle = false end
    end
    if ww.queue then
        if ww.queue.queueRunning then idle = false end
        if type(ww.queue.Size) == "function" and ww.queue.Size() > 0 then idle = false end
    end
    local plan = state.plan
    local finishedWithoutSignal = (state.noValidationExpected and not state.validationSeen) or state.validationFailed
    if idle and (state.nativeSuccess or finishedWithoutSignal)
        and ww.currentIndex == plan.index and WWDpadRouting.IsCurrent(plan) then
        if state.nativeSuccess then
            M.Stop()
            state.finish()
            return
        end
        state.idleSamples = state.idleSamples + 1
        if state.idleSamples >= 2 then
            M.Stop()
            state.finish(state.validationFailed and "WW meldet fehlgeschlagenen Wechsel. Verarbeitung beendet; Ausruestung in WW pruefen."
                or "WW-Verarbeitung beendet. Keine Abschlussmeldung vorgesehen; fehlende Ausruestung ggf. in WW pruefen.")
            return
        end
    else state.idleSamples = 0 end
    if state.elapsed >= 45000 and not state.warned then
        state.warned = true
        state.warn("WW-Abschluss steht noch aus. Weitere Wechsel bleiben gesperrt; das Add-on bleibt eingeschaltet und wartet weiter.")
    end
end

function M.Signal()
    if active and canObserveTasks and active.sawSetupTask then
        active.nativeSuccess = true
        -- Allow the currently executing WW task to return before inspecting it.
        zo_callLater(M.Check, 0)
        return true
    end
    return false
end

function M.Check()
    local ok = pcall(Inspect)
    if not ok and active and not active.inspectWarning then
        active.inspectWarning = true
        active.warn("WW-Aufgabenstatus nicht lesbar. Schutzsperre bleibt bis zur WW-Abschlussmeldung bestehen.")
    end
end

function M.ResetClock()
    if active then active.lastCheck = GetFrameTimeMilliseconds() end
end

function M.Begin(plan, finish, warn)
    M.Stop()
    local previousErrors = setmetatable({}, {__mode = "k"})
    for task in pairs(tasks) do previousErrors[task] = task.Error end
    local ww = WizardsWardrobe
    active = {
        plan = plan, finish = finish, warn = warn, previousErrors = previousErrors,
        noValidationExpected = ww.settings and ww.settings.auto and ww.settings.auto.gear == false,
        lastCheck = GetFrameTimeMilliseconds(), elapsed = 0, idleSamples = 0,
    }
    EVENT_MANAGER:RegisterForUpdate("WWDpadSwapWatch", 500, M.Check)
end
