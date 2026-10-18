-- GuildNameTickerMain.lua: Entry point; wires state, saved vars, events, and settings.

local GuildNameTicker = GuildNameTicker

local function Initialize()
    local State = GuildNameTicker.State

    GuildNameTicker.state = State.Create()
    GuildNameTicker.state.savedVars = ZO_SavedVars:NewAccountWide(
        GuildNameTicker.savedVarsName,
        GuildNameTicker.savedVarsVersion,
        nil,
        GuildNameTicker.state.savedVars
    )

    GuildNameTicker.CycleActions.InitializeEventHandlers()
    GuildNameTicker.RepresentationSync.Initialize()
    GuildNameTicker.SettingsActions.Initialize()

    -- /gt My Guild Name -> set that name now; /gt alone -> disband/clear.
    SLASH_COMMANDS["/gt"] = function(args)
        local text = zo_strtrim(args or "")
        if text == "" then
            GuildNameTicker.CycleActions.Clear()
        else
            GuildNameTicker.CycleActions.SetName(text)
        end
    end
end

EVENT_MANAGER:RegisterForEvent(GuildNameTicker.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == GuildNameTicker.name then
        Initialize()
        EVENT_MANAGER:UnregisterForEvent(GuildNameTicker.name, EVENT_ADD_ON_LOADED)
    end
end)
