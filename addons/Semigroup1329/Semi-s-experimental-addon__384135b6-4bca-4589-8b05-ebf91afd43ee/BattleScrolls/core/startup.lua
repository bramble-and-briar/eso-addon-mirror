if not SemisPlaygroundCheckAccess() then return end

---@class BattleScrollsStartup
---@field addonLoaded Fiber<nil>
---@field playerActivated Fiber<nil>
local startup = {}
BattleScrolls.startup = startup

-- Register while loading the manifest so neither event can be missed by a
-- delayed initializer. These callbacks only resolve latches, never do setup.
-- IsPlayerActivated() is not a substitute for observing event delivery:
-- regular update callbacks can run before the queued activation handlers.
startup.addonLoaded = LibEffect.FromCallback(function(resolve)
    EVENT_MANAGER:RegisterForEvent('BattleScrolls_Startup', EVENT_ADD_ON_LOADED, function(_, addonName)
        if addonName ~= 'ESOSemisDebugPlayground' then return end
        EVENT_MANAGER:UnregisterForEvent('BattleScrolls_Startup', EVENT_ADD_ON_LOADED)
        resolve(nil)
    end)
end):Run()

startup.playerActivated = LibEffect.FromCallback(function(resolve)
    EVENT_MANAGER:RegisterForEvent('BattleScrolls_Startup', EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent('BattleScrolls_Startup', EVENT_PLAYER_ACTIVATED)
        resolve(nil)
    end)
end):Run()
