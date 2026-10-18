-- Chat: the "Loaded!" message and the chat commands. The settings are in the settings menu (src/Menu.lua); the add-on's
-- one chat command of its own clears the boss timers.
--   /sbtreset    clear every boss timer, as Reset Boss Timers in Timer Settings does
--   /ru          reload the UI

local addon = SlayansBossTimer

local Commands = {}
addon.Commands = Commands

local function Print(text)
    CHAT_ROUTER:AddSystemMessage(text)
end

function Commands.PrintLoadedMessage()
    Print(addon.Util.FallGradient(zo_strformat(SI_SBT_LOADED, addon.name, addon.version)))
end

function Commands.Initialize()
    SLASH_COMMANDS["/sbtreset"] = function()
        addon.Timers.Reset()
    end
    -- /ru is a common shortcut. Another add-on that already registered it keeps it, so nothing changes for its users.
    if not SLASH_COMMANDS["/ru"] then
        SLASH_COMMANDS["/ru"] = function()
            ReloadUI("ingame")
        end
    end
end
