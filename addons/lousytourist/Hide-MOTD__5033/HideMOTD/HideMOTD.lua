local HideMOTD = {
    name = "HideMOTD"
}

function HideMOTD.SuppressMOTD()
    local handlers = ZO_ChatSystem_GetEventHandlers()
    if not handlers then return end

    -- Suppress live Guild MOTD updates
    if handlers[EVENT_GUILD_MOTD_CHANGED] then
        handlers[EVENT_GUILD_MOTD_CHANGED] = function() return true end
    end

    -- Suppress initial Guild MOTDs on login
    if handlers[EVENT_GUILD_DATA_LOADED] then
        handlers[EVENT_GUILD_DATA_LOADED] = function() return true end
    end

    -- Suppress Zenimax System MOTDs
    if handlers[EVENT_SYSTEM_MOTD_CHANGED] then
        handlers[EVENT_SYSTEM_MOTD_CHANGED] = function() return true end
    end
end

-- Check and override on EVERY addon load event so we catch it the exact millisecond it exists
function HideMOTD.OnAddOnLoaded(event, addonName)
    HideMOTD.SuppressMOTD()
end

-- Clean up the loop once you are fully loaded into the world
function HideMOTD.OnPlayerActivated(event, initial)
    EVENT_MANAGER:UnregisterForEvent(HideMOTD.name, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:UnregisterForEvent(HideMOTD.name, EVENT_PLAYER_ACTIVATED)
    HideMOTD.SuppressMOTD()
end

EVENT_MANAGER:RegisterForEvent(HideMOTD.name, EVENT_ADD_ON_LOADED, HideMOTD.OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(HideMOTD.name, EVENT_PLAYER_ACTIVATED, HideMOTD.OnPlayerActivated)
