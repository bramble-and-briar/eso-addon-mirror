-- ============================================================================
-- Bloom HPS - Init
-- Loads settings, builds the UI and hooks into LibFights' fight lifecycle.
-- The meter redraws on a timer only while a fight is running, so it costs
-- nothing out of combat and never runs per combat event.
-- ============================================================================

local M = HPSMeterUI
local TICK_NAME = M.name .. "_Tick"

local function StopTicking()
    EVENT_MANAGER:UnregisterForUpdate(TICK_NAME)
    M.UI.Refresh() -- final numbers of the finished fight
end

-- LibFights drops very short fights without firing FIGHT_ENDED, so the tick
-- also stops itself once no fight is running.
local function OnTick()
    if LibFights.GetCurrentFight() then
        M.UI.Refresh()
    else
        StopTicking()
    end
end

local function StartTicking()
    EVENT_MANAGER:UnregisterForUpdate(TICK_NAME)
    EVENT_MANAGER:RegisterForUpdate(TICK_NAME, M.TICK_MS, OnTick)
    M.UI.Refresh()
end

local function MigrateSettings(saved)
    for key, swap in pairs(M.OLD_DEFAULT_COLORS) do
        if saved[key] == swap[1] then saved[key] = swap[2] end
    end
    saved.labelColor  = M.SanitizeHex(saved.labelColor, M.DEFAULT_HEAL_COLOR)
    saved.shieldColor = M.SanitizeHex(saved.shieldColor, M.DEFAULT_SHIELD_COLOR)
    saved.mitigationColor = M.SanitizeHex(saved.mitigationColor, M.DEFAULT_MITIGATION_COLOR)
end

local function HookLibFights()
    local LF = LibFights
    LF.RegisterCallback(LF.EVENTS.FIGHT_STARTED, StartTicking)
    LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, StopTicking)
    LF.RegisterCallback(LF.EVENTS.LOGGING_STOPPED, StopTicking)

    local ok, reason = M.Data.StartLogging(M.saved.groupMode)
    if not ok then M.Print("Could not start LibFights logging: " .. tostring(reason)) end

    -- Logging may have started mid-fight (e.g. after /reloadui in combat).
    local fight = LF.GetCurrentFight()
    if fight then StartTicking() end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= M.name then return end
    EVENT_MANAGER:UnregisterForEvent(M.name, EVENT_ADD_ON_LOADED)

    if not LibFights then
        d("[Bloom HPS] LibFights is not installed or not enabled.")
        return
    end

    -- Same saved table as earlier versions, so position / colors carry over.
    M.saved = ZO_SavedVars:NewAccountWide("HPSMeterSavedVars", 2, nil, M.defaults)
    MigrateSettings(M.saved)

    local ok, err = pcall(M.UI.Create)
    if not ok then M.Print("UI error: " .. tostring(err)) end

    ok, err = pcall(M.Settings.Create)
    if not ok then M.Print("Settings menu error: " .. tostring(err)) end

    M.Commands.Register()

    -- Check the textures once the loading screen is gone: the game only loads
    -- textures it draws, and consoles take much longer to get there than PC.
    local function OnPlayerActivated()
        EVENT_MANAGER:UnregisterForEvent(M.name .. "_Activated", EVENT_PLAYER_ACTIVATED)
        M.UI.VerifyTextures()
    end
    EVENT_MANAGER:RegisterForEvent(M.name .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    -- DependsOn guarantees LibFights loaded first, but wait for its
    -- initialisation just in case.
    if LibFights.initialized then
        HookLibFights()
    else
        LibFights.RegisterCallback(LibFights.EVENTS.INITIALIZED, HookLibFights)
    end
end

EVENT_MANAGER:RegisterForEvent(M.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
