-- PrismaticEmotes 1.0.0
-- A local, lightweight chat formatter for roleplay emotes.
PrismaticEmotes = {
    name = "PrismaticEmotes",
    version = "1.0.0",
    saved = nil,
}

local PE = PrismaticEmotes

PE.defaults = {
    enabled = true,
    mode = "both",            -- "author", "body", or "both"
    highlightMentions = true, -- known character names in the body
    characters = {},          -- account-wide character -> color registry
}

function PE.Print(message)
    if type(d) == "function" then
        d("|cBCA2FF[PrismaticEmotes]|r " .. tostring(message))
    end
end

local function OnPlayerActivated()
    -- pChat registers its own channel formatter on PLAYER_ACTIVATED.
    -- Deferring our wrapper ensures we capture whichever formatter won.
    EVENT_MANAGER:UnregisterForEvent(PE.name .. "Activated", EVENT_PLAYER_ACTIVATED)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if not PE.Chat.Install() then
                PE.Print("Chat formatter unavailable. Try /pe rehook after login.")
            end
        end, 1000)
    else
        PE.Chat.Install()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= PE.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(PE.name, EVENT_ADD_ON_LOADED)
    PE.saved = ZO_SavedVars:NewAccountWide("PrismaticEmotesSavedVariables", 1, nil, PE.defaults)

    -- Defensive migration if an older/incomplete SavedVariables table exists.
    if type(PE.saved.characters) ~= "table" then
        PE.saved.characters = {}
    end
    if PE.saved.mode ~= "author" and PE.saved.mode ~= "body" and PE.saved.mode ~= "both" then
        PE.saved.mode = "both"
    end

    PE.Palette.MigrateSavedNames()
    PE.Commands.Register()
    EVENT_MANAGER:RegisterForEvent(PE.name .. "Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForEvent(PE.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end
