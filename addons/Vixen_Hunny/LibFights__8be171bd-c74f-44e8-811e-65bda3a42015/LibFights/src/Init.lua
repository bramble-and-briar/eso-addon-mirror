--[[
    LibFights - Init
    Loads SavedVariables and builds the settings panel / HUD / slash commands.
    It does NOT start logging: call Start_Logging() for that.
]]

local LF = LibFights

local function OnAddOnLoaded(_, addonName)
    if addonName ~= LF.name then return end
    EVENT_MANAGER:UnregisterForEvent(LF.name .. "_Init", EVENT_ADD_ON_LOADED)

    LF.Storage.Init()
    LF.Models.Load()
    LF.SettingsUI.Init()
    LF.HUD.Init()
    LF.Slash.Init()

    LF.initialized = true
    LF.FireCallback(LF.EVENTS.INITIALIZED)
end

EVENT_MANAGER:RegisterForEvent(LF.name .. "_Init", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
