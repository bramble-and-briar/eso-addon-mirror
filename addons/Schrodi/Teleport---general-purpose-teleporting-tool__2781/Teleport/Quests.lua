Teleport.Quests = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

-------------------------------------------------------------------------------
-- Travel to the tracked quest without opening the world map.
--
-- 1. Every open objective of the quest is located with SetMapToQuestCondition,
--    then the map is zoomed out (MapZoomOut, no UI) until it shows a known
--    wayshrine. That gives the zone(s) of the quest synchronously.
-- 2. Exact objective positions come from RequestJournalQuestConditionAssistance
--    (the same thing the map uses to draw quest pins), which answers
--    asynchronously with EVENT_QUEST_POSITION_REQUEST_COMPLETE. All objectives
--    are requested, so quests with multiple markers just pick the marker
--    closest to a wayshrine.
-- The current map is pushed before and popped after, so the map / minimap
-- never sees any of it.

local REQUEST_TIMEOUT_MS = 1500
local BUSY_TIMEOUT_MS    = 10000
local MAX_MAP_LEVELS     = 8

local MODE_FREE = 1
local MODE_PAID = 2
local MODE_BOTH = 3

-------------------------------------------------------------------------------
-- Which objectives

local function getOpenConditions(questIndex)
    local conditions = {}

    if not GetJournalQuestIsComplete(questIndex) then
        for step = QUEST_MAIN_STEP_INDEX, GetJournalQuestNumSteps(questIndex) do
            for condition = 1, GetJournalQuestNumConditions(questIndex, step) do
                local _, _, isFailCondition, isComplete, _, isVisible = GetJournalQuestConditionValues(questIndex, step, condition)
                if isVisible and not (isFailCondition or isComplete) then
                    table.insert(conditions, { step = step, condition = condition })
                end
            end
        end
    end

    -- finished quests (and quests without visible conditions) - go to the ending
    if #conditions == 0 then
        table.insert(conditions, { step = QUEST_MAIN_STEP_INDEX, condition = 1, ending = true })
    end

    return conditions
end

local function describeCondition(questIndex, condition)
    local text
    if condition.ending then
        text = GetJournalQuestEnding(questIndex)
    else
        text = GetJournalQuestConditionInfo(questIndex, condition.step, condition.condition)
    end
    if text and text ~= "" then
        return zo_strformat("<<1>>", text)
    end
end

-------------------------------------------------------------------------------
-- Where (synchronous, caller takes care of push/pop)

local function setMapToCondition(questIndex, condition)
    local result = SetMapToQuestCondition(questIndex, condition.step, condition.condition)

    if result == SET_MAP_RESULT_FAILED and condition.ending then
        for step = QUEST_MAIN_STEP_INDEX, GetJournalQuestNumSteps(questIndex) do
            if IsJournalQuestStepEnding(questIndex, step) then
                result = SetMapToQuestStepEnding(questIndex, step)
                if result ~= SET_MAP_RESULT_FAILED then break end
            end
        end
    end

    return result ~= SET_MAP_RESULT_FAILED
end

local function isPvPMap()
    local mapIndex = GetCurrentMapIndex()
    return mapIndex ~= nil and (mapIndex == GetCyrodiilMapIndex() or mapIndex == GetImperialCityMapIndex())
end

-- Walks up from the currently set map. Returns
--   travelMapId - lowest map showing a known wayshrine (delve -> zone, etc.)
--   zoneIds     - zones the objective is in, most specific first
--   isPvP       - Cyrodiil / Imperial City
local function resolveFromCurrentMap()
    local result = { zoneIds = {} }
    local zoneSet, seenMaps = {}, {}

    for _ = 1, MAX_MAP_LEVELS do
        local mapId = GetCurrentMapId()
        if not mapId or seenMaps[mapId] then break end
        seenMaps[mapId] = true

        local mapType = GetMapType()
        if mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC then break end

        if isPvPMap() then result.isPvP = true end

        local zoneIndex = GetCurrentMapZoneIndex()
        if zoneIndex then
            for _, zoneId in ipairs(Teleport.Zones:getZoneChain(GetZoneId(zoneIndex))) do
                if not zoneSet[zoneId] then
                    zoneSet[zoneId] = true
                    table.insert(result.zoneIds, zoneId)
                end
            end
        end

        if not result.travelMapId and #Teleport.Nodes:getKnownWayshrinesOnCurrentMap() > 0 then
            result.travelMapId = mapId
        end

        if mapType == MAPTYPE_ZONE and result.travelMapId then break end
        if MapZoomOut() ~= SET_MAP_RESULT_MAP_CHANGED then break end
    end

    return result
end

-- Objectives grouped by the map we'll be looking for wayshrines on.
local function resolveQuest(questIndex)
    local conditions = getOpenConditions(questIndex)
    local groups, groupsByKey = {}, {}

    local function addGroup(resolved, groupConditions)
        local key = resolved.travelMapId or ("zone:" .. tostring(resolved.zoneIds[1]))
        local group = groupsByKey[key]
        if not group then
            group = {
                travelMapId = resolved.travelMapId,
                zoneIds = resolved.zoneIds,
                isPvP = resolved.isPvP,
                conditions = {},
            }
            groupsByKey[key] = group
            table.insert(groups, group)
        end
        for _, condition in ipairs(groupConditions) do
            table.insert(group.conditions, condition)
        end
    end

    Teleport.Helpers:pushMap()

    for _, condition in ipairs(conditions) do
        if setMapToCondition(questIndex, condition) then
            addGroup(resolveFromCurrentMap(), { condition })
        else
            dbg("No map for step " .. condition.step .. " condition " .. condition.condition)
        end
    end

    -- nothing has a map of its own - try the quest's zone with all objectives
    if #groups == 0 and SetMapToQuestZone(questIndex) ~= SET_MAP_RESULT_FAILED then
        addGroup(resolveFromCurrentMap(), conditions)
    end

    Teleport.Helpers:popMap()

    return groups
end

local function groupZoneName(group)
    local zoneId = Teleport.Zones:normalizeZoneId(group.zoneIds[1]) or group.zoneIds[1]
    return zoneId and GetZoneNameById(zoneId) or "?"
end

-------------------------------------------------------------------------------
-- Exact positions (asynchronous)

local currentJob

EVENT_MANAGER:RegisterForEvent("Teleport_Quests", EVENT_QUEST_POSITION_REQUEST_COMPLETE,
    function(_, taskId, _, x, y, areaRadius, insideCurrentMapWorld, _, _, _, symbolicState)
        local job = currentJob
        if not job then return end

        local result = {
            x = x,
            y = y,
            radius = areaRadius,
            inside = insideCurrentMapWorld,
            symbolic = symbolicState == QUEST_PIN_STATE_IS_SYMBOLIC_POSITION,
        }

        if job.pending[taskId] then
            job.add(taskId, result)
        else
            -- either not ours, or it came back before we stored the taskId
            job.early[taskId] = result
        end
    end)

-- Requests positions of the group's objectives on its travel map and builds
-- a plan from them. The map has to stay on travelMapId until the answers come.
local function runRound(questIndex, group, onDone)
    if SetMapToMapId(group.travelMapId) == SET_MAP_RESULT_FAILED then
        return onDone(nil)
    end

    local job = { pending = {}, early = {}, remaining = 0, targets = {}, symbolic = {}, done = false }

    function job.finish()
        if job.done then return end
        job.done = true
        if currentJob == job then currentJob = nil end

        for taskId in pairs(job.pending) do
            CancelRequestJournalQuestConditionAssistance(taskId)
        end

        -- something else switched the map while we were waiting
        if GetCurrentMapId() ~= group.travelMapId then
            SetMapToMapId(group.travelMapId)
        end

        local targets = #job.targets > 0 and job.targets or job.symbolic
        onDone(#targets > 0 and Teleport.Nodes:planOnCurrentMap(targets) or nil)
    end

    function job.add(taskId, result)
        if job.done then return end
        local condition = job.pending[taskId]
        job.pending[taskId] = nil
        job.remaining = job.remaining - 1

        if result.inside and Teleport.Helpers:isOnMap(result.x, result.y) then
            table.insert(result.symbolic and job.symbolic or job.targets, {
                x = result.x,
                y = result.y,
                radius = result.radius,
                condition = condition,
            })
        end

        if job.remaining <= 0 then job.finish() end
    end

    currentJob = job

    for _, condition in ipairs(group.conditions) do
        local taskId = RequestJournalQuestConditionAssistance(questIndex, condition.step, condition.condition)
        if taskId then
            job.pending[taskId] = condition
            job.remaining = job.remaining + 1
        end
    end

    for taskId, result in pairs(job.early) do
        if job.pending[taskId] then job.add(taskId, result) end
    end

    if job.remaining <= 0 then
        return job.finish()
    end

    zo_callLater(job.finish, REQUEST_TIMEOUT_MS)
end

-- callback(plan) - merged plan over all groups that have a travel map, or nil
local function locate(questIndex, groups, callback)
    local rounds = {}
    for _, group in ipairs(groups) do
        if group.travelMapId then table.insert(rounds, group) end
    end
    if #rounds == 0 then return callback(nil) end

    local plans = {}
    local i = 0

    Teleport.Helpers:pushMap()

    local function nextRound()
        i = i + 1
        if i > #rounds then
            Teleport.Helpers:popMap()
            return callback(#plans > 0 and Teleport.Nodes:mergePlans(plans) or nil)
        end
        runRound(questIndex, rounds[i], function(plan)
            if plan then table.insert(plans, plan) end
            nextRound()
        end)
    end

    nextRound()
end

-------------------------------------------------------------------------------

local function findPlayerFor(groups)
    local zoneSet, ordered = {}, {}
    for _, group in ipairs(groups) do
        for _, zoneId in ipairs(group.zoneIds) do
            if not zoneSet[zoneId] then
                zoneSet[zoneId] = true
                table.insert(ordered, zoneId)
            end
        end
    end

    local players = Teleport.Players:findPlayersInZones(zoneSet)
    for _, zoneId in ipairs(ordered) do
        if players[zoneId] then return players[zoneId] end
    end
end

local function zoneNames(groups)
    local names, seen = {}, {}
    for _, group in ipairs(groups) do
        local name = groupZoneName(group)
        if not seen[name] then
            seen[name] = true
            table.insert(names, color(name, C.ZONE))
        end
    end
    return table.concat(names, ", ")
end

local busySince

function Teleport.Quests:teleportToQuest(tryPaid, forcePaid)
    local mode = forcePaid and MODE_PAID or (tryPaid and MODE_BOTH or MODE_FREE)
    if Teleport.Helpers:isAtWayshrine() then
        mode = MODE_PAID -- free anyway
    end
    local canJump = mode ~= MODE_PAID
    local canPay  = mode ~= MODE_FREE

    if busySince and GetFrameTimeMilliseconds() - busySince < BUSY_TIMEOUT_MS then
        info("Still looking for the quest location...")
        return
    end

    local questIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
    if not questIndex or not IsValidQuestIndex(questIndex) then
        info("Failed to teleport to quest: No quest is being tracked.")
        return
    end

    local questName = color(GetJournalQuestName(questIndex), C.QUEST)
    local numConditions = #getOpenConditions(questIndex)

    local groups = resolveQuest(questIndex)
    if #groups == 0 then
        info("Can't determine quest location of " .. questName)
        return
    end

    local pveGroups = {}
    for _, group in ipairs(groups) do
        if not group.isPvP then table.insert(pveGroups, group) end
    end
    if #pveGroups == 0 then
        info("Teleport can't help you with " .. color(groupZoneName(groups[1]), C.ZONE) .. " quests")
        return
    end

    -- objectives in the zone you're in come first - no zone-to-zone loading screen
    local playerZones = {}
    for _, zoneId in ipairs(Teleport.Zones:getPlayerZoneChain()) do playerZones[zoneId] = true end

    local currentGroups, otherGroups = {}, {}
    for _, group in ipairs(pveGroups) do
        local isCurrent = false
        for _, zoneId in ipairs(group.zoneIds) do
            if playerZones[zoneId] then isCurrent = true break end
        end
        table.insert(isCurrent and currentGroups or otherGroups, group)
    end

    local function targetSuffix(target)
        local text = numConditions > 1 and target and target.condition and describeCondition(questIndex, target.condition)
        return questName .. (text and (": " .. text) or "")
    end

    local function done()
        busySince = nil
    end

    local function jump(groupList)
        local player = findPlayerFor(groupList)
        if not player then return false end
        Teleport.Players:teleportToPlayer(player, nil, " in " .. color(player.zoneName, C.ZONE) .. " - " .. questName)
        return true
    end

    local function travel(plan)
        Teleport.Nodes:travelTo(plan.node.index, " - " .. targetSuffix(plan.nodeTarget))
    end

    local allGroups = {} -- current zone first
    for _, group in ipairs(currentGroups) do table.insert(allGroups, group) end
    for _, group in ipairs(otherGroups) do table.insert(allGroups, group) end

    -- free anywhere beats paid anywhere; within each, current zone first
    local function freeThenPaid(currentPlan)
        if canJump then
            if jump(allGroups) then return done() end

            local msg = "No players in " .. zoneNames(allGroups)
            if not canPay then
                info(msg)
                return done()
            end
            info(msg .. ". Falling back to paid teleport.")
        end

        if currentPlan and currentPlan.node then
            travel(currentPlan)
            return done()
        end

        if #otherGroups == 0 then
            info("Failed to teleport to " .. questName .. ": Couldn't find a known wayshrine near it.")
            return done()
        end

        locate(questIndex, otherGroups, function(plan)
            if plan and plan.node then
                travel(plan)
            elseif plan then
                info("Failed to teleport to " .. questName .. ": No known wayshrines in " .. zoneNames(otherGroups) .. ".")
            else
                info("Can't determine quest location of " .. questName)
            end
            done()
        end)
    end

    busySince = GetFrameTimeMilliseconds()

    if #currentGroups == 0 then
        return freeThenPaid(nil)
    end

    -- objective in the current zone: maybe it's close enough to just walk there
    locate(questIndex, currentGroups, function(plan)
        if Teleport.Nodes:shouldWalk(plan) then
            local suffix = Teleport.Helpers:isAtWayshrine() and " - this is the closest wayshrine." or " - closer than any wayshrine."
            info(targetSuffix(plan.walkTarget) .. " is " .. Teleport.Helpers:formatMeters(plan.walkDistance) .. " away" .. suffix)
            return done()
        end
        freeThenPaid(plan)
    end)
end
