-- CameraAnglesMain.lua: Entry point; registers the slash command

local CameraAngles = CameraAngles

local function Initialize()
    CameraAngles.state = CameraAngles.State.Create()
    SLASH_COMMANDS[CameraAngles.slashCommand] = CameraAngles.CameraActions.Print
end

EVENT_MANAGER:RegisterForEvent(CameraAngles.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == CameraAngles.name then
        EVENT_MANAGER:UnregisterForEvent(CameraAngles.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)
