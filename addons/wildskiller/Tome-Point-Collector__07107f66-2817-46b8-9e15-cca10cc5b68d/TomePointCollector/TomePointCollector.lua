local ADDON_NAME = "TomePointCollector"
local claimQueued = false

local function QueueClaim()
    if claimQueued then
        return
    end

    claimQueued = true
    zo_callLater(function()
        claimQueued = false
        if HasAnyUnclaimedTimedActivityRewards() then
            ClaimAllTimedActivityRewards()
        end
    end, 500)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- ESO uses this lookup to decide whether to queue the Tome Points HUD prompt.
    local manager = TIMED_ACTIVITIES_MANAGER
    if manager and type(manager.GetFirstClaimableTimedActivityForHUDPrompt) == "function" then
        manager.GetFirstClaimableTimedActivityForHUDPrompt = function()
            return nil
        end
    end

    if type(HasAnyUnclaimedTimedActivityRewards) ~= "function"
        or type(ClaimAllTimedActivityRewards) ~= "function" then
        return
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, QueueClaim)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_TIMED_ACTIVITIES_UPDATED, QueueClaim)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, QueueClaim)
    QueueClaim()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
