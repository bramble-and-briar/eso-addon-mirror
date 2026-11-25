-- Skill Point Finder: queue the Dungeon Finder for every dungeon whose quest this character hasn't done.

local SP = ESOC_SkillPointFinder
local Queue = {}
SP.Queue = Queue

local function finderLocations(manager, activityType)
    local list
    pcall(function() list = manager:GetLocationsData(activityType) end)
    return list or {}
end

-- Selects the dungeons in the game's own Dungeon Finder (which skips locked ones), then queues.
-- If the game won't let an add-on start the queue, the dungeons stay ticked so you can press Queue.
function Queue.Start(veteran)
    if SP.Safe(IsCurrentlySearchingForGroup) then
        SP.Alert("you're already in a queue. Leave it first.")
        return
    end
    local state = SP.Scan.Get()
    local wanted, count = {}, 0
    for _, dungeon in ipairs(SP.Scan.MissingDungeons(state)) do
        wanted[dungeon.zoneId] = true
        count = count + 1
    end
    if count == 0 then
        SP.Alert("this character has done the quest in every dungeon you can queue for.")
        return
    end

    local activityType = veteran and LFG_ACTIVITY_MASTER_DUNGEON or LFG_ACTIVITY_DUNGEON
    local manager = ZO_ACTIVITY_FINDER_ROOT_MANAGER
    local selected = 0
    if manager then
        pcall(function() manager:ClearSelections() end)
        for _, location in ipairs(finderLocations(manager, activityType)) do
            local zoneId = SP.Safe(function() return location:GetZoneId() end)
            local locked = SP.Safe(function() return location:IsLocked() end)
            if zoneId and wanted[zoneId] and not locked then
                pcall(function() manager:SetLocationSelected(location, true) end)
                selected = selected + 1
            end
        end
    end

    local started = false
    if selected > 0 then
        started = pcall(function() manager:StartSearch() end)
    else
        -- The finder's list isn't ready: queue directly by activity.
        SP.Safe(ClearActivityFinderSearch)
        for _, dungeon in ipairs(SP.Scan.MissingDungeons(state)) do
            local activityId = veteran and dungeon.vetId or dungeon.normalId
            if activityId and SP.Safe(DoesPlayerMeetActivityLevelRequirements, activityId) then
                SP.Safe(AddActivityFinderSpecificSearchEntry, activityId)
                selected = selected + 1
            end
        end
        if selected > 0 then
            local result = SP.Safe(StartActivityFinderSearch)
            started = result == ACTIVITY_QUEUE_RESULT_SUCCESS
            if not started and result then pcall(ZO_AlertEvent, EVENT_ACTIVITY_QUEUE_RESULT, result) end
        end
    end

    if selected == 0 then
        SP.Alert(veteran and "none of the missing dungeons are open to you on veteran yet." or "none of the missing dungeons can be queued from here.")
        return
    end
    local mode = veteran and "veteran" or "normal"
    zo_callLater(function()
        if SP.Safe(IsCurrentlySearchingForGroup) then
            SP.Alert("queued for " .. selected .. " " .. mode .. " dungeons. Remember to pick up each dungeon's quest.")
        else
            SP.Alert(selected .. " " .. mode .. " dungeons are ticked in the Dungeon Finder. Open it and press Queue.")
        end
    end, 1500)
    return selected, started
end
