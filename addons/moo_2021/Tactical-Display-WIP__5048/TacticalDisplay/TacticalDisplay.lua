TacticalDisplay = TacticalDisplay or {}
local _TacticalDisplay = TacticalDisplay

local ADDON_NAME = "TacticalDisplay"
local LOAD_EVENT_NAME = "TacticalDisplay_Loaded"

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(LOAD_EVENT_NAME, EVENT_ADD_ON_LOADED)

    local savedVars = _TacticalDisplay.Settings.CreateSavedVars()

    _TacticalDisplay.Base.Initialize(savedVars)
    _TacticalDisplay.Data.Initialize(savedVars)
    _TacticalDisplay.Panel.Initialize(savedVars)
    _TacticalDisplay.Settings.Initialize(savedVars)
end

EVENT_MANAGER:RegisterForEvent(LOAD_EVENT_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
