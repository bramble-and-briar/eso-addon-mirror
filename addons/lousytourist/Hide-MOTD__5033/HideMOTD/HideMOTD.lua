local HideMOTD = {
    name = "HideMOTD"
}

function HideMOTD.SuppressMOTD()
    local handlers = ZO_ChatSystem_GetEventHandlers()
    
    -- Check if the handlers table and the guild MOTD event exist
    if handlers and handlers[EVENT_GUILD_MOTD_CHANGED] then
        -- Overwrite the default handler with an empty function
        handlers[EVENT_GUILD_MOTD_CHANGED] = function(eventCode, guildId)
            -- Returning true or keeping it blank swallows the text/chat alert
            return true 
        end
    end
end

-- Hook into the game's startup sequence
function HideMOTD.OnAddOnLoaded(event, addonName)
    if addonName == HideMOTD.name then
        -- Clean up the startup hook immediately
        EVENT_MANAGER:UnregisterForEvent(HideMOTD.name, EVENT_ADD_ON_LOADED)
        
        -- Run the handler suppression
        HideMOTD.SuppressMOTD()
    end
end

-- Register to check when our specific addon loads into memory
EVENT_MANAGER:RegisterForEvent(HideMOTD.name, EVENT_ADD_ON_LOADED, HideMOTD.OnAddOnLoaded)
