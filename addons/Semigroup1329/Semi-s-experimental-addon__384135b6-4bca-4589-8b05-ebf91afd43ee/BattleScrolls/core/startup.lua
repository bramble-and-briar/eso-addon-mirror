if not SemisPlaygroundCheckAccess() then return end

---@class BattleScrollsStartup
---@field addonLoaded Fiber<nil>
---@field playerActivated Fiber<nil>
local startup = {}
BattleScrolls.startup = startup

-- Subscribe during manifest loading. Deferred initialization waits for event
-- delivery; update callbacks can run before queued activation handlers.
startup.addonLoaded = LibEffect.Events(function(events, resolve)
    events:On(EVENT_ADD_ON_LOADED, function(_, addonName)
        if addonName ~= 'ESOSemisDebugPlayground' then return end
        resolve(nil)
    end)
end):Run()

startup.playerActivated = LibEffect.Events(function(events, resolve)
    events:On(EVENT_PLAYER_ACTIVATED, function()
        resolve(nil)
    end)
end):Run()
