local HideMOTD = {
    name = "HideMOTD"
}

function HideMOTD.SuppressMOTD()
    local handlers = ZO_ChatSystem_GetEventHandlers()
    if not handlers then return end

    -- Suppress live Guild MOTD updates in chat
    if handlers[EVENT_GUILD_MOTD_CHANGED] then
        handlers[EVENT_GUILD_MOTD_CHANGED] = function() return true end
    end

    -- Suppress initial Guild MOTDs on login
    if handlers[EVENT_GUILD_DATA_LOADED] then
        handlers[EVENT_GUILD_DATA_LOADED] = function() return true end
    end

    -- Suppress ZeniMax System MOTDs
    if handlers[EVENT_SYSTEM_MOTD_CHANGED] then
        handlers[EVENT_SYSTEM_MOTD_CHANGED] = function() return true end
    end
end

function HideMOTD.OnAddOnsLoaded()
    EVENT_MANAGER:UnregisterForEvent(HideMOTD.name, EVENT_ADDONS_LOADED)
    HideMOTD.SuppressMOTD()
end

EVENT_MANAGER:RegisterForEvent(HideMOTD.name, EVENT_ADDONS_LOADED, HideMOTD.OnAddOnsLoaded)
