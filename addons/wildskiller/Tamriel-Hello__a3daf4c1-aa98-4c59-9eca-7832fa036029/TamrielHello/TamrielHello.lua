local addonName = "TamrielHello"

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_PLAYER_ACTIVATED)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Tamriel Hello is active.")
end

local function OnAddonLoaded(_, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, OnAddonLoaded)
