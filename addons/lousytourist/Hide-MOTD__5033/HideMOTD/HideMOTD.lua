local HideMOTD = {
    name = "HideMOTD"
}

function HideMOTD.SuppressMOTD()
    local handlers = ZO_ChatSystem_GetEventHandlers()
    if not handlers then return end

    -- 1. Suppress live Guild MOTD updates in chat
    if handlers[EVENT_GUILD_MOTD_CHANGED] then
        handlers[EVENT_GUILD_MOTD_CHANGED] = function() return true end
    end

    -- 2. Suppress Guild MOTDs printed when initially loading guild data
    if handlers[EVENT_GUILD_DATA_LOADED] then
        handlers[EVENT_GUILD_DATA_LOADED] = function() return true end
    end

    -- 3. Suppress Zenimax System/Server MOTDs on login
    if handlers[EVENT_SYSTEM_MOTD_CHANGED] then
        handlers[EVENT_SYSTEM_MOTD_CHANGED] = function() return true end
    end
end

-- Wait until the UI and chat system are completely initialized
function HideMOTD.OnPlayerActivated(event, initial)
    EVENT_MANAGER:UnregisterForEvent(HideMOTD.name, EVENT_PLAYER_ACTIVATED)
    HideMOTD.SuppressMOTD()
end

function HideMOTD.OnAddOnLoaded(event, addonName)
    if addonName == HideMOTD.name then
        EVENT_MANAGER:UnregisterForEvent(HideMOTD.name, EVENT_ADD_ON_LOADED)
        -- Register for PLAYER_ACTIVATED instead of running immediately
        EVENT_MANAGER:RegisterForEvent(HideMOTD.name, EVENT_PLAYER_ACTIVATED, HideMOTD.OnPlayerActivated)
    end
end

EVENT_MANAGER:RegisterForEvent(HideMOTD.name, EVENT_ADD_ON_LOADED, HideMOTD.OnAddOnLoaded)
