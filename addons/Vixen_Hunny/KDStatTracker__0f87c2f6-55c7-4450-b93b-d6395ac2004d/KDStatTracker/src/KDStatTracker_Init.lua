-- KDStatTracker_Init.lua
-- Load order glue: saved variables -> migration -> UI -> events -> settings.

local KDST = KDStatTracker

local function OnAddOnLoaded(_, addonName)
    if addonName ~= KDST.name then return end
    EVENT_MANAGER:UnregisterForEvent(KDST.name, EVENT_ADD_ON_LOADED)

    -- Same saved-variable names / versions as v2.0, so existing stats carry over.
    KDST.data     = ZO_SavedVars:NewAccountWide("KDStatTrackerVars", 1, nil, KDST.dataDefaults)
    KDST.settings = ZO_SavedVars:NewAccountWide("KDStatTrackerSettings", 1, nil, KDST.settingDefaults)
    KDST.charName = GetUnitName("player") or "Unknown"

    KDST.MigrateData()
    KDST.MigrateSettings()
    KDST.NewSession()

    KDST.HUD:Initialize()
    KDST.InitializeDialogs()
    KDST.RegisterEvents()
    KDST.RegisterSettings()
    KDST.RegisterSlashCommands()
end

EVENT_MANAGER:RegisterForEvent(KDST.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
