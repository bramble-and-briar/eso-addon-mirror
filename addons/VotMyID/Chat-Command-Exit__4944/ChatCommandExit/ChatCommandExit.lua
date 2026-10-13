-- Chat Command Exit
-- AI-assisted code; uses ESO's built-in API functions only.

local ChatCommandExit = { name = "ChatCommandExit" }

local function LeaveGroupCommand()
    if IsUnitGrouped("player") then
        GroupLeave()
    end
end

local function ExitDungeonCommand()
    if IsUnitInDungeon("player") then
        ExitInstanceImmediately()
    end
end

local function GroupAndDungeonOutCommand()
    LeaveGroupCommand()
    -- Allow ESO to process the group-leave request before exiting the instance.
    zo_callLater(ExitDungeonCommand, 1000)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ChatCommandExit.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ChatCommandExit.name, EVENT_ADD_ON_LOADED)

    -- Register slash commands only after this addon has loaded.
    SLASH_COMMANDS["/groupout"] = LeaveGroupCommand
    SLASH_COMMANDS["/dangeout"] = ExitDungeonCommand
    SLASH_COMMANDS["/dungeonout"] = ExitDungeonCommand
    SLASH_COMMANDS["/gdtout"] = GroupAndDungeonOutCommand
end

-- This is the single bootstrap event needed to defer initialization.
EVENT_MANAGER:RegisterForEvent(ChatCommandExit.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
