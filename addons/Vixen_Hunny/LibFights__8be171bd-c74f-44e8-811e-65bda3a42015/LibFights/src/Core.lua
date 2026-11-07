--[[
    LibFights - Core
    ------------------------------------------------------------------------
    Combat / ability / set / proc / stat / build logging library for
    The Elder Scrolls Online (PC/Mac and PS5/Xbox console add-ons).

    IMPORTANT: NOTHING is logged until Start_Logging() is called.
    No combat-related events are registered before that call, and
    Stop_Logging() unregisters every one of them again.

    Read-only lookups (ability info, set info, build reading, searching)
    work at any time because they only query the game when you ask.
]]

LibFights = LibFights or {}
local LF = LibFights

LF.name        = "LibFights"
LF.displayName = "LibFights"
LF.version     = "1.0.0"
LF.versionNum  = 10000
LF.initialized = false

-- Platform detection ---------------------------------------------------------
LF.isConsole = false
if type(IsConsoleUI) == "function" then
    LF.isConsole = IsConsoleUI() and true or false
end

function LF.IsConsole()
    return LF.isConsole
end

function LF.IsGamepad()
    if LF.isConsole then return true end
    if type(IsInGamepadPreferredMode) == "function" then
        return IsInGamepadPreferredMode() and true or false
    end
    return false
end

-- Callback names fired by the library ------------------------------------
LF.EVENTS = {
    INITIALIZED     = "LibFights_Initialized",
    LOGGING_STARTED = "LibFights_LoggingStarted",    -- (options)
    LOGGING_STOPPED = "LibFights_LoggingStopped",    -- ()
    FIGHT_STARTED   = "LibFights_FightStarted",      -- (fight)
    FIGHT_ENDED     = "LibFights_FightEnded",        -- (fight, reason)
    COMBAT_EVENT    = "LibFights_CombatEvent",       -- (fight, direction, category, result, abilityId, hitValue, overflow, sourceUnitId, targetUnitId, damageType)
    EFFECT_CHANGED  = "LibFights_EffectChanged",     -- (fight, scope, changeType, abilityId, effectName, unitId, stackCount)
    PROC            = "LibFights_Proc",              -- (fight, procEntry)
    DEATH           = "LibFights_Death",             -- (fight, deathEntry)
    CAST            = "LibFights_Cast",              -- (fight, slotIndex, abilityId, castCategory)
    BAR_SWAP        = "LibFights_BarSwap",           -- (fight, activeWeaponPair)
    STATS_SAMPLE    = "LibFights_StatsSample",       -- (fight, statSnapshot)
    GEAR_CHANGED    = "LibFights_GearChanged",       -- (fight, slotIndex)
    SCAN_PROGRESS   = "LibFights_ScanProgress",      -- (progressTable)
    SCAN_DONE       = "LibFights_ScanDone",          -- (progressTable)
}

-- Callback registry (ZO_CallbackObject is available on PC and console) ------
LF.callbackObject = ZO_CallbackObject:New()
LF.listenerCount = {}

function LF.RegisterCallback(eventName, callback, arg)
    if type(eventName) ~= "string" or type(callback) ~= "function" then return false end
    LF.callbackObject:RegisterCallback(eventName, callback, arg)
    LF.listenerCount[eventName] = (LF.listenerCount[eventName] or 0) + 1
    return true
end

function LF.UnregisterCallback(eventName, callback)
    LF.callbackObject:UnregisterCallback(eventName, callback)
    local n = (LF.listenerCount[eventName] or 1) - 1
    LF.listenerCount[eventName] = n > 0 and n or nil
end

function LF.HasListeners(eventName)
    return LF.listenerCount[eventName] ~= nil
end

function LF.FireCallback(eventName, ...)
    if LF.listenerCount[eventName] then
        LF.callbackObject:FireCallbacks(eventName, ...)
    end
end

-- Chat output -------------------------------------------------------------------
local PREFIX = "|c66CCFF[LibFights]|r "

function LF.Print(fmt, ...)
    local msg = tostring(fmt)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, fmt, ...)
        if ok then msg = formatted end
    end
    d(PREFIX .. msg)
end

function LF.PrintLines(lines, header)
    if header then LF.Print(header) end
    if type(lines) ~= "table" then
        LF.Print(tostring(lines))
        return
    end
    for i = 1, #lines do
        d(lines[i])
    end
end

function LF.Debug(fmt, ...)
    local s = LF.settings
    if s and s.debug then
        LF.Print("|c999999[debug]|r " .. tostring(fmt), ...)
    end
end

-- Internal module table (modules attach themselves in their own files) ---------
LF.internal = LF.internal or {}
