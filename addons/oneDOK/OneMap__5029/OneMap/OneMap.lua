local A = OneMap

local function OnLoaded(_, addonName)
    if addonName ~= A.name then return end
    EVENT_MANAGER:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)
    A.saved = ZO_SavedVars:NewAccountWide("OneMapSavedVariables", 1, nil, A.defaults)
    -- Removed settings stay enabled, including accounts with older disabled values.
    for _, key in ipairs({ "compactHouses", "showDungeons", "showTrials", "questZone",
        "rightClickTravel", "freeTravel", "travelTooltips", "useGroup", "useFriends", "useGuilds" }) do
        A.saved[key] = true
    end
    A:InitializeTravel()
    A:InitializeMap()
    A:InitializeScroll()
    A:InitializeMapInput()
    A:InitializePanels()
    A:CreateSettings()
    A:ApplyMapSettings()
end

EVENT_MANAGER:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
