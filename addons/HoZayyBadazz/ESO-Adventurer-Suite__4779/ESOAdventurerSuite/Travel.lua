-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.Travel = EPC.Travel or {}
local T = EPC.Travel

T.PAGE_SIZE = 6
T.BOOK_PAGE_SIZE = 10
T.modeOrder = {"SHRINES", "FRIENDS", "GUILD", "GROUP"}
T.modeLabels = {
    SHRINES = "Wayshrines",
    FRIENDS = "Friends",
    GUILD = "Guild",
    GROUP = "Group",
}

local function safeNumber(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback or 0 end
    return value
end

local function clean(value, fallback)
    value = tostring(value or "")
    value = string.gsub(value, "[%c]+", " ")
    value = string.gsub(value, "%s+", " ")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    if value == "" then return fallback or "" end
    return value
end

local function lower(value)
    return string.lower(clean(value, ""))
end

local function mapResultSucceeded(ok, result)
    if not ok then return false end
    if SET_MAP_RESULT_FAILED ~= nil and result == SET_MAP_RESULT_FAILED then return false end
    return true
end

local function notifyMapChanged()
    if type(CALLBACK_MANAGER) == "table" and type(CALLBACK_MANAGER.FireCallbacks) == "function" then
        pcall(CALLBACK_MANAGER.FireCallbacks, CALLBACK_MANAGER, "OnWorldMapChanged")
    end
end

-- Undaunted pledge turn-ins use the enclave tied to the player's alliance.
-- Keep this in Travel so Activities and any future routing UI share one source
-- of truth instead of assuming one generic "Undaunted Enclave" destination.
function T:GetUndauntedEnclaveForPlayer()
    local alliance = 0
    if type(GetUnitAlliance) == "function" then
        local ok, value = pcall(GetUnitAlliance, "player")
        if ok then alliance = safeNumber(value, 0) end
    end

    if ALLIANCE_ALDMERI_DOMINION ~= nil and alliance == ALLIANCE_ALDMERI_DOMINION then
        return { alliance = alliance, city = "Elden Root", zone = "Grahtwood", wayshrine = "Elden Root Wayshrine" }
    elseif ALLIANCE_DAGGERFALL_COVENANT ~= nil and alliance == ALLIANCE_DAGGERFALL_COVENANT then
        return { alliance = alliance, city = "Wayrest", zone = "Stormhaven", wayshrine = "Wayrest Wayshrine" }
    elseif ALLIANCE_EBONHEART_PACT ~= nil and alliance == ALLIANCE_EBONHEART_PACT then
        return { alliance = alliance, city = "Mournhold", zone = "Deshaan", wayshrine = "Mournhold Wayshrine" }
    end

    return nil
end

function T:GetAlliancePledgeTurnInWayshrine(entries)
    local enclave = self:GetUndauntedEnclaveForPlayer()
    if not enclave then return nil, nil end

    local exactName = lower(enclave.wayshrine)
    local cityNeedle = lower(enclave.city)
    local zoneNeedle = lower(enclave.zone)
    local zoneFallback = nil

    for i = 1, #(entries or {}) do
        local entry = entries[i]
        local shrineName = lower(entry and entry.name or "")
        local zoneName = lower(entry and entry.zoneName or "")
        if shrineName == exactName or (cityNeedle ~= "" and string.find(shrineName, cityNeedle, 1, true)) then
            return entry, enclave
        end
        if not zoneFallback and zoneNeedle ~= "" and zoneName == zoneNeedle then
            zoneFallback = entry
        end
    end

    return zoneFallback, enclave
end

local function formatNumber(value)
    local number = math.floor(safeNumber(value, 0))
    local sign = number < 0 and "-" or ""
    local digits = tostring(math.abs(number))
    local parts = {}

    while #digits > 3 do
        table.insert(parts, 1, string.sub(digits, -3))
        digits = string.sub(digits, 1, -4)
    end
    table.insert(parts, 1, digits)
    return sign .. table.concat(parts, ",")
end

local function isOnlineStatus(playerStatus, secsSinceLogoff)
    if PLAYER_STATUS_OFFLINE ~= nil then
        return playerStatus ~= PLAYER_STATUS_OFFLINE
    end
    return safeNumber(secsSinceLogoff, 1) == 0
end

local function currentZoneFirstSort(a, b)
    if a.isCurrentZone ~= b.isCurrentZone then
        return a.isCurrentZone == true
    end

    local zoneA = lower(a.zoneName)
    local zoneB = lower(b.zoneName)
    if zoneA ~= zoneB then return zoneA < zoneB end

    local nameA = lower(a.name)
    local nameB = lower(b.name)
    if nameA ~= nameB then return nameA < nameB end

    return lower(a.key) < lower(b.key)
end

local function getCurrentMapIdSafe()
    if type(GetCurrentMapId) ~= "function" then return 0 end
    local ok, mapId = pcall(GetCurrentMapId)
    if not ok then return 0 end
    return safeNumber(mapId, 0)
end

local function getCurrentMapZoneIdSafe()
    if type(GetCurrentMapZoneIndex) ~= "function" or type(GetZoneId) ~= "function" then return 0 end
    local ok, zoneIndex = pcall(GetCurrentMapZoneIndex)
    zoneIndex = ok and safeNumber(zoneIndex, 0) or 0
    if zoneIndex <= 0 then return 0 end
    local idOk, zoneId = pcall(GetZoneId, zoneIndex)
    if not idOk then return 0 end
    return safeNumber(zoneId, 0)
end

local function getZoneIdentity(zoneIndex)
    local numericZoneIndex = safeNumber(zoneIndex, 0)
    local zoneId = 0

    if numericZoneIndex > 0 and type(GetZoneId) == "function" then
        local ok, returnedZoneId = pcall(GetZoneId, numericZoneIndex)
        if ok then zoneId = safeNumber(returnedZoneId, 0) end
    end

    local parentZoneId = zoneId
    if zoneId > 0 and type(GetParentZoneId) == "function" then
        local ok, returnedParentZoneId = pcall(GetParentZoneId, zoneId)
        if ok and safeNumber(returnedParentZoneId, 0) > 0 then
            parentZoneId = safeNumber(returnedParentZoneId, zoneId)
        end
    end

    return zoneId, parentZoneId
end

local function getCanonicalZoneId(zoneId)
    local current = safeNumber(zoneId, 0)
    if current <= 0 then return 0 end
    if type(GetParentZoneId) ~= "function" then return current end

    local seen = {}
    for _ = 1, 8 do
        if seen[current] then break end
        seen[current] = true
        local ok, parent = pcall(GetParentZoneId, current)
        parent = ok and safeNumber(parent, 0) or 0
        if parent <= 0 or parent == current then break end
        current = parent
    end
    return current
end

local function zonesMatch(entry, quest)
    if not entry or not quest then return false end

    local entryZoneIndex = safeNumber(entry.zoneIndex, 0)
    local questZoneIndex = safeNumber(quest.zoneIndex, 0)
    if entryZoneIndex > 0 and questZoneIndex > 0 and entryZoneIndex == questZoneIndex then
        return true
    end

    local entryZoneId = safeNumber(entry.zoneId, 0)
    local questZoneId = safeNumber(quest.zoneId, 0)
    if entryZoneId > 0 and questZoneId > 0 and entryZoneId == questZoneId then
        return true
    end

    local entryParent = safeNumber(entry.parentZoneId, 0)
    local questParent = safeNumber(quest.parentZoneId, 0)
    if entryParent > 0 and questZoneId > 0 and entryParent == questZoneId then
        return true
    end
    if questParent > 0 and entryZoneId > 0 and questParent == entryZoneId then
        return true
    end

    local entryZoneName = lower(entry.zoneName)
    local questZoneName = lower(quest.zoneName)
    return entryZoneName ~= "" and questZoneName ~= "" and entryZoneName == questZoneName
end

local function questAwareWayshrineSort(a, b)
    local distanceA = tonumber(a.questDistance)
    local distanceB = tonumber(b.questDistance)

    if distanceA ~= nil and distanceB ~= nil then
        if math.abs(distanceA - distanceB) > 0.0000001 then
            return distanceA < distanceB
        end
    elseif distanceA ~= nil or distanceB ~= nil then
        return distanceA ~= nil
    end

    if a.isQuestZone ~= b.isQuestZone then
        return a.isQuestZone == true
    end

    return currentZoneFirstSort(a, b)
end

local function getJumpAvailability(zoneId)
    if type(CanJumpToPlayerInZone) ~= "function" or safeNumber(zoneId, 0) <= 0 then
        return true, nil
    end

    local ok, canJump, result = pcall(CanJumpToPlayerInZone, zoneId)
    if not ok then return true, nil end
    return canJump == true, result
end

local function jumpResultText(result)
    if JUMP_TO_PLAYER_RESULT_PLAYER_OFFLINE ~= nil and result == JUMP_TO_PLAYER_RESULT_PLAYER_OFFLINE then
        return "Player is offline"
    elseif JUMP_TO_PLAYER_RESULT_ZONE_COLLECTIBLE_LOCKED ~= nil and result == JUMP_TO_PLAYER_RESULT_ZONE_COLLECTIBLE_LOCKED then
        return "Zone access required"
    elseif JUMP_TO_PLAYER_RESULT_SOLO_ZONE ~= nil and result == JUMP_TO_PLAYER_RESULT_SOLO_ZONE then
        return "Solo-only destination"
    elseif JUMP_TO_PLAYER_RESULT_PLAYER_DIFFICULTY_LOCKED ~= nil and result == JUMP_TO_PLAYER_RESULT_PLAYER_DIFFICULTY_LOCKED then
        return "Difficulty mismatch"
    elseif JUMP_TO_PLAYER_RESULT_CROSS_ALLIANCE_LOCKED ~= nil and result == JUMP_TO_PLAYER_RESULT_CROSS_ALLIANCE_LOCKED then
        return "Alliance restriction"
    elseif JUMP_TO_PLAYER_RESULT_GENERIC_FAILURE ~= nil and result == JUMP_TO_PLAYER_RESULT_GENERIC_FAILURE then
        return "Travel unavailable"
    end
    return "ESO currently blocks travel"
end

-- Some jump failures are truly destination-specific, while ESO also reports a
-- generic failure for a short period after zoning/teleporting.  Auto-discovery
-- must never permanently discard a route because of that transient state.
local function isPermanentJumpFailure(result)
    if result == nil then return false end
    if JUMP_TO_PLAYER_RESULT_PLAYER_OFFLINE ~= nil and result == JUMP_TO_PLAYER_RESULT_PLAYER_OFFLINE then return true end
    if JUMP_TO_PLAYER_RESULT_ZONE_COLLECTIBLE_LOCKED ~= nil and result == JUMP_TO_PLAYER_RESULT_ZONE_COLLECTIBLE_LOCKED then return true end
    if JUMP_TO_PLAYER_RESULT_SOLO_ZONE ~= nil and result == JUMP_TO_PLAYER_RESULT_SOLO_ZONE then return true end
    if JUMP_TO_PLAYER_RESULT_PLAYER_DIFFICULTY_LOCKED ~= nil and result == JUMP_TO_PLAYER_RESULT_PLAYER_DIFFICULTY_LOCKED then return true end
    if JUMP_TO_PLAYER_RESULT_CROSS_ALLIANCE_LOCKED ~= nil and result == JUMP_TO_PLAYER_RESULT_CROSS_ALLIANCE_LOCKED then return true end
    -- GENERIC_FAILURE and unknown results are intentionally transient here.
    return false
end

local InitializeImplArch

function T:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self.selectedKey = nil
    self.lastView = nil
    self.lastFocusedQuestKey = nil
    self.questPositionCache = {}
    self.questPositionRequests = {}
    self.questPendingKeys = {}
    self.pendingServiceWaypoint = nil

    if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED ~= nil then
        EPC.Runtime:RegisterEvent("Travel", "ServiceWaypoint", EVENT_PLAYER_ACTIVATED, function()
            if EPC.Travel and EPC.Travel.TryPlacePendingServiceWaypoint then
                zo_callLater(function() EPC.Travel:TryPlacePendingServiceWaypoint() end, 700)
            end
            if EPC.Travel and EPC.Travel.InitializeMapTeleporter then
                zo_callLater(function() EPC.Travel:InitializeMapTeleporter() end, 250)
            end
            if EPC.Travel and EPC.Travel.ResumeMapTeleporterAutoDiscovery then
                -- ESO can briefly reject the next social jump immediately after a
                -- zone load. Give the travel system time to settle before routing.
                zo_callLater(function() EPC.Travel:ResumeMapTeleporterAutoDiscovery() end, 2600)
            end
        end)
    end

    if EVENT_MANAGER and EVENT_PREPARE_FOR_JUMP ~= nil then
        EPC.Runtime:RegisterEvent("Travel", "DiscoveryPrepare", EVENT_PREPARE_FOR_JUMP, function()
            local travel = EPC.Travel
            local pending = travel and travel.mapTeleporterDiscoveryPending or nil
            if travel and travel.mapTeleporterDiscoveryActive and type(pending) == "table" then
                pending.prepared = true
            end
        end)
    end

    if self.InitializeMapTeleporter then
        self:InitializeMapTeleporter()
    end
end

function T:InvalidateQuestPositionCache()
    self.questPositionCache = {}
    self.questPositionRequests = {}
    self.questPendingKeys = {}
    self.pendingQuestTravelTaskId = nil
end

function T:GetAssistedQuestCondition(questIndex)
    questIndex = safeNumber(questIndex, 0)
    if questIndex <= 0 or type(GetNumTracked) ~= "function" or type(GetTrackedByIndex) ~= "function"
        or type(GetTrackedIsAssisted) ~= "function" or TRACK_TYPE_QUEST == nil then
        return nil, nil
    end

    local okCount, count = pcall(GetNumTracked)
    if not okCount then return nil, nil end
    count = safeNumber(count, 0)

    for trackedIndex = 1, count do
        local ok, trackType, param1, param2, param3 = pcall(GetTrackedByIndex, trackedIndex)
        if ok and trackType == TRACK_TYPE_QUEST and safeNumber(param1, 0) == questIndex then
            local assistedOk, assisted = pcall(GetTrackedIsAssisted, trackType, param1, param2)
            if assistedOk and assisted == true then
                local stepIndex = safeNumber(param2, 0)
                local conditionIndex = safeNumber(param3, 0)
                if stepIndex > 0 and conditionIndex > 0 and type(GetJournalQuestNumConditions) == "function" then
                    local countOk, numConditions = pcall(GetJournalQuestNumConditions, questIndex, stepIndex)
                    if countOk and conditionIndex <= safeNumber(numConditions, 0) then
                        return stepIndex, conditionIndex
                    end
                end
            end
        end
    end
    return nil, nil
end

function T:FindQuestCondition(questIndex)
    -- Prefer the exact sub-objective ESO currently marks as assisted. Multi-part
    -- quests can expose several visible incomplete conditions at once; simply
    -- taking the first one can point the minimap toward a different task.
    local assistedStep, assistedCondition = self:GetAssistedQuestCondition(questIndex)
    if assistedStep and assistedCondition then return assistedStep, assistedCondition end

    if type(GetJournalQuestNumSteps) ~= "function" or type(GetJournalQuestNumConditions) ~= "function" then
        return nil, nil
    end

    local stepsOk, numSteps = pcall(GetJournalQuestNumSteps, questIndex)
    if not stepsOk then return nil, nil end
    numSteps = safeNumber(numSteps, 0)

    local fallbackStep = nil
    local fallbackCondition = nil

    for stepIndex = 1, numSteps do
        local conditionsOk, numConditions = pcall(GetJournalQuestNumConditions, questIndex, stepIndex)
        if conditionsOk then
            numConditions = safeNumber(numConditions, 0)
            for conditionIndex = 1, numConditions do
                if not fallbackStep then
                    fallbackStep = stepIndex
                    fallbackCondition = conditionIndex
                end

                if type(GetJournalQuestConditionValues) == "function" then
                    local valuesOk, _, _, isFailCondition, isComplete, _, isVisible = pcall(
                        GetJournalQuestConditionValues,
                        questIndex,
                        stepIndex,
                        conditionIndex
                    )
                    if valuesOk and isVisible == true and not isFailCondition and not isComplete then
                        return stepIndex, conditionIndex
                    end
                end
            end
        end
    end

    return fallbackStep, fallbackCondition
end

function T:RequestFocusedQuestPosition(quest)
    if not quest or not quest.positionKey then return end
    if self.questPositionCache[quest.positionKey] or self.questPendingKeys[quest.positionKey] then return end

    if type(RequestJournalQuestConditionAssistance) ~= "function" then
        self.questPositionCache[quest.positionKey] = { available = false }
        return
    end

    -- v0.26.21: objective lookups are background work and must never leave ESO's
    -- visible World Map on a quest sub-map. Remember the map that was active before
    -- selecting the quest condition, capture the objective map id for coordinate
    -- conversion, then restore the original map immediately after submitting the
    -- asynchronous assistance request.
    local originalMapId = getCurrentMapIdSafe()
    local objectiveMapId = originalMapId
    local objectiveZoneId = getCurrentMapZoneIdSafe()

    if type(SetMapToQuestCondition) == "function"
        and safeNumber(quest.questIndex, 0) > 0
        and safeNumber(quest.stepIndex, 0) > 0
        and safeNumber(quest.conditionIndex, 0) > 0 then
        local setOk, setResult = pcall(
            SetMapToQuestCondition,
            quest.questIndex,
            quest.stepIndex,
            quest.conditionIndex
        )
        if mapResultSucceeded(setOk, setResult) then
            objectiveMapId = getCurrentMapIdSafe()
            objectiveZoneId = getCurrentMapZoneIdSafe()
        end
    end

    local ok, taskId = pcall(
        RequestJournalQuestConditionAssistance,
        quest.questIndex,
        quest.stepIndex,
        quest.conditionIndex
    )

    -- Restore before any UI callback can observe the temporary objective map.
    if originalMapId > 0 and getCurrentMapIdSafe() ~= originalMapId
        and type(SetMapToMapId) == "function" then
        pcall(SetMapToMapId, originalMapId)
    end

    if ok and taskId ~= nil then
        self.questPositionRequests[taskId] = {
            purpose = "FOCUSED_QUEST",
            positionKey = quest.positionKey,
            quest = quest,
            -- Assistance coordinates belong to the objective map selected above,
            -- not the map that happens to be active when the async callback fires.
            mapId = objectiveMapId,
            zoneId = objectiveZoneId,
        }
        self.questPendingKeys[quest.positionKey] = taskId
    else
        -- Do not repeatedly request a condition that ESO says has no map position.
        self.questPositionCache[quest.positionKey] = { available = false }
    end
end

function T:FindNearestWayshrineOnCurrentMap(targetX, targetY)
    targetX, targetY = tonumber(targetX), tonumber(targetY)
    if not targetX or not targetY then return nil end

    local total = 0
    if type(GetNumFastTravelNodes) == "function" then
        local ok, count = pcall(GetNumFastTravelNodes)
        if ok then total = safeNumber(count, 0) end
    end

    local best, bestDistance = nil, nil
    for nodeIndex = 1, total do
        local entry = self:GetWayshrineNodeEntry(nodeIndex)
        if entry and entry.isShownInCurrentMap
            and entry.normalizedX ~= nil and entry.normalizedY ~= nil then
            local dx = entry.normalizedX - targetX
            local dy = entry.normalizedY - targetY
            local distance = (dx * dx) + (dy * dy)
            if bestDistance == nil or distance < bestDistance then
                best, bestDistance = entry, distance
            end
        end
    end

    if best then
        best.questDistance = bestDistance
        best.isQuestBest = true
    end
    return best
end

-- Convert a point on the active ESO map into universal normalized coordinates.
-- Unlike GetFastTravelNodeInfo's normalized coordinates, these remain comparable
-- after we zoom from an objective sub-map/interior out to the full overland zone.
function T:GetUniversalPointForMap(mapId, localX, localY)
    mapId = safeNumber(mapId, 0)
    localX, localY = tonumber(localX), tonumber(localY)
    if mapId <= 0 or localX == nil or localY == nil then return nil, nil end
    if type(GetUniversallyNormalizedMapInfo) ~= "function" then return nil, nil end

    local ok, offsetX, offsetY, width, height = pcall(GetUniversallyNormalizedMapInfo, mapId)
    offsetX, offsetY = tonumber(offsetX), tonumber(offsetY)
    width, height = tonumber(width), tonumber(height)
    if not ok or offsetX == nil or offsetY == nil or width == nil or height == nil
        or width <= 0 or height <= 0 then
        return nil, nil
    end

    return offsetX + (localX * width), offsetY + (localY * height)
end

function T:GetUniversalPointForCurrentMap(localX, localY)
    return self:GetUniversalPointForMap(getCurrentMapIdSafe(), localX, localY)
end

-- Quest condition maps are often a city, delve, interior, or other zoomed-in map.
-- On those maps ESO marks only the local wayshrine(s) as isShownInCurrentMap, which
-- made the addon look as if the rest of the zone's shrines did not exist. Keep the
-- objective in universal coordinates, walk outward through the map hierarchy, and
-- collect every discovered wayshrine that belongs to the same canonical overland
-- zone. The closest candidate is then chosen in one coordinate system.
function T:FindNearestWayshrineAcrossQuestZone(targetGlobalX, targetGlobalY, preferredZoneId, objectiveMapId)
    targetGlobalX, targetGlobalY = tonumber(targetGlobalX), tonumber(targetGlobalY)
    if targetGlobalX == nil or targetGlobalY == nil then return nil end

    -- Always begin the scan from the same map coordinate space that produced the
    -- objective point. The quest assistance callback is asynchronous and other UI
    -- code (especially the minimap) can switch the active map before it fires.
    local originalMapId = getCurrentMapIdSafe()
    objectiveMapId = safeNumber(objectiveMapId, 0)
    if objectiveMapId > 0 and objectiveMapId ~= originalMapId and type(SetMapToMapId) == "function" then
        local setOk, setResult = pcall(SetMapToMapId, objectiveMapId)
        -- Do not fire OnWorldMapChanged during a background route scan. The
        -- map is restored before the UI is notified, which prevents visible
        -- zoom/pan thrashing when the World Map happens to be open.
        mapResultSucceeded(setOk, setResult)
    end

    local targetCanonicalZoneId = getCanonicalZoneId(preferredZoneId)
    if targetCanonicalZoneId <= 0 and type(GetCurrentMapZoneIndex) == "function" then
        local zoneOk, currentZoneIndex = pcall(GetCurrentMapZoneIndex)
        if zoneOk then
            local currentZoneId = 0
            if type(GetZoneId) == "function" then
                local idOk, value = pcall(GetZoneId, safeNumber(currentZoneIndex, 0))
                if idOk then currentZoneId = safeNumber(value, 0) end
            end
            targetCanonicalZoneId = getCanonicalZoneId(currentZoneId)
        end
    end

    local best, bestDistance = nil, nil
    local seenNodes = {}

    local function inspectCurrentMap()
        local mapId = getCurrentMapIdSafe()
        if mapId <= 0 or type(GetUniversallyNormalizedMapInfo) ~= "function" then return 0 end

        local mapOk, offsetX, offsetY, width, height = pcall(GetUniversallyNormalizedMapInfo, mapId)
        offsetX, offsetY = tonumber(offsetX), tonumber(offsetY)
        width, height = tonumber(width), tonumber(height)
        if not mapOk or offsetX == nil or offsetY == nil or width == nil or height == nil
            or width <= 0 or height <= 0 then
            return 0
        end

        local total = 0
        if type(GetNumFastTravelNodes) == "function" then
            local ok, count = pcall(GetNumFastTravelNodes)
            if ok then total = safeNumber(count, 0) end
        end

        local foundOnThisMap = 0
        for nodeIndex = 1, total do
            local entry = self:GetWayshrineNodeEntry(nodeIndex)
            if entry and entry.isShownInCurrentMap
                and entry.normalizedX ~= nil and entry.normalizedY ~= nil then
                local entryCanonical = getCanonicalZoneId(safeNumber(entry.zoneId, 0))
                local sameDestinationZone = targetCanonicalZoneId <= 0
                    or (entryCanonical > 0 and entryCanonical == targetCanonicalZoneId)

                if sameDestinationZone then
                    foundOnThisMap = foundOnThisMap + 1
                    if not seenNodes[entry.nodeIndex] then
                        seenNodes[entry.nodeIndex] = true
                        local gx = offsetX + (entry.normalizedX * width)
                        local gy = offsetY + (entry.normalizedY * height)
                        local dx = gx - targetGlobalX
                        local dy = gy - targetGlobalY
                        local distance = (dx * dx) + (dy * dy)
                        if bestDistance == nil or distance < bestDistance then
                            best = entry
                            bestDistance = distance
                        end
                    end
                end
            end
        end
        return foundOnThisMap
    end

    -- Inspect the objective map, then each parent. Do not stop after finding one
    -- shrine: a city/sub-map may expose one while the full zone exposes many more.
    inspectCurrentMap()
    if type(MapZoomOut) == "function" then
        local previousMapId = getCurrentMapIdSafe()
        for _ = 1, 8 do
            local ok, result = pcall(MapZoomOut)
            if not mapResultSucceeded(ok, result) then break end

            local currentMapId = getCurrentMapIdSafe()
            if currentMapId > 0 and previousMapId > 0 and currentMapId == previousMapId then break end
            previousMapId = currentMapId
            inspectCurrentMap()
        end
    end

    if best then
        best.questDistance = bestDistance
        best.isQuestBest = true
    end

    -- Do not leave the player's world map changed after a background route lookup.
    if originalMapId > 0 and getCurrentMapIdSafe() ~= originalMapId and type(SetMapToMapId) == "function" then
        local restoreOk, restoreResult = pcall(SetMapToMapId, originalMapId)
        if mapResultSucceeded(restoreOk, restoreResult) then notifyMapChanged() end
    end
    return best
end

function T:OnQuestPositionRequestComplete(taskId, pinType, xLoc, yLoc, areaRadius, insideCurrentMapWorld, isBreadcrumb, teleportNPCId, waypointId, symbolicState, additionalSymbolicLocX, additionalSymbolicLocY)
    local request = self.questPositionRequests and self.questPositionRequests[taskId]
    if not request then return end

    self.questPositionRequests[taskId] = nil

    local positionKey = type(request) == "table" and request.positionKey or request
    if positionKey then self.questPendingKeys[positionKey] = nil end

    local x = tonumber(xLoc)
    local y = tonumber(yLoc)
    local additionalX = tonumber(additionalSymbolicLocX)
    local additionalY = tonumber(additionalSymbolicLocY)

    local function isNormalizedPoint(px, py)
        return px ~= nil and py ~= nil
            and px >= 0 and px <= 1
            and py >= 0 and py <= 1
    end

    -- ESO can return a useful breadcrumb/symbolic coordinate even when
    -- insideCurrentMapWorld is false. For travel routing that point is still
    -- preferable to collapsing immediately to a zone-only wayshrine choice.
    local exact = insideCurrentMapWorld == true and isNormalizedPoint(x, y)
    local routeX, routeY = nil, nil
    -- Prefer the actual quest-condition position whenever ESO says it belongs to
    -- the condition map. additionalSymbolicLoc is commonly a breadcrumb, door, or
    -- transition point and can be much farther from the real objective.
    if exact then
        routeX, routeY = x, y
    elseif isNormalizedPoint(additionalX, additionalY) then
        routeX, routeY = additionalX, additionalY
    elseif isNormalizedPoint(x, y) then
        routeX, routeY = x, y
    end

    local cachedPosition = nil
    if positionKey then
        local sourceMapId = type(request) == "table" and safeNumber(request.mapId, 0) or 0
        local globalX, globalY = nil, nil
        if routeX ~= nil and routeY ~= nil and sourceMapId > 0 then
            globalX, globalY = self:GetUniversalPointForMap(sourceMapId, routeX, routeY)
        end
        cachedPosition = {
            available = routeX ~= nil and routeY ~= nil,
            exact = exact,
            x = routeX or x,
            y = routeY or y,
            mapId = sourceMapId,
            globalX = globalX,
            globalY = globalY,
            insideCurrentMapWorld = insideCurrentMapWorld == true,
            isBreadcrumb = isBreadcrumb == true,
            symbolicState = symbolicState,
        }
        self.questPositionCache[positionKey] = cachedPosition
    end

    -- The Map/Travel page uses the same objective resolver, but it does not travel
    -- automatically. Resolve and cache the best shrine across the full objective
    -- zone so QUEST BEST reflects the Active/Main/Golden source selected in Suite.
    if type(request) == "table" and request.purpose == "FOCUSED_QUEST"
        and routeX ~= nil and routeY ~= nil then
        local objectiveMapId = safeNumber(request.mapId, 0)
        local globalX, globalY = self:GetUniversalPointForMap(objectiveMapId, routeX, routeY)
        if globalX == nil or globalY == nil then
            globalX, globalY = self:GetUniversalPointForCurrentMap(routeX, routeY)
            objectiveMapId = getCurrentMapIdSafe()
        end
        -- The visible map was already restored before this async callback fired.
        -- Use the zone captured from the quest objective map, never the player's
        -- current map, so cross-zone quests rank shrines in the destination zone.
        local objectiveZoneId = safeNumber(request.zoneId, 0)
        if objectiveZoneId <= 0 and type(request.quest) == "table" then
            objectiveZoneId = safeNumber(request.quest.zoneId, 0)
        end

        local nearest = nil
        if globalX ~= nil and globalY ~= nil then
            nearest = self:FindNearestWayshrineAcrossQuestZone(globalX, globalY, objectiveZoneId, objectiveMapId)
        end
        if nearest and cachedPosition then
            cachedPosition.globalX = globalX
            cachedPosition.globalY = globalY
            cachedPosition.objectiveZoneId = objectiveZoneId
            cachedPosition.bestNodeIndex = nearest.nodeIndex
            cachedPosition.bestDistance = nearest.questDistance
            cachedPosition.bestShrineName = nearest.name
        end
    end

    -- A travel-button request deliberately sets the world map to the active
    -- objective before asking ESO for assistance. The callback coordinates and
    -- every isShownInCurrentMap wayshrine are therefore in the same normalized
    -- coordinate space, allowing a true closest-node comparison inside the zone.
    if type(request) == "table" and request.purpose == "QUEST_TRAVEL" then
        self.pendingQuestTravelTaskId = nil
        if routeX ~= nil and routeY ~= nil then
            -- Convert with the exact condition map captured when the assistance request
            -- started. Using the current map here can project the same 0..1 coordinate
            -- onto a completely different Coldharbour sub-map and pick a distant shrine.
            local objectiveMapId = safeNumber(request.mapId, 0)
            local globalX, globalY = self:GetUniversalPointForMap(objectiveMapId, routeX, routeY)
            if globalX == nil or globalY == nil then
                globalX, globalY = self:GetUniversalPointForCurrentMap(routeX, routeY)
                objectiveMapId = getCurrentMapIdSafe()
            end
            -- QUEST_TRAVEL is asynchronous too. The current map may be the player's
            -- map again by now, so use the destination zone captured when the quest
            -- condition map was active.
            local preferredZoneId = safeNumber(request.zoneId, 0)
            if preferredZoneId <= 0 and type(request.quest) == "table" then
                preferredZoneId = safeNumber(request.quest.zoneId, 0)
                if preferredZoneId <= 0 and type(self.GetQuestRecordZone) == "function" then
                    local recordZoneId = self:GetQuestRecordZone(request.quest)
                    preferredZoneId = safeNumber(recordZoneId, 0)
                end
            end

            local nearest = nil
            if globalX ~= nil and globalY ~= nil then
                nearest = self:FindNearestWayshrineAcrossQuestZone(globalX, globalY, preferredZoneId, objectiveMapId)
            end
            if not nearest then
                -- Compatibility fallback for unusual maps that do not expose universal
                -- measurements: preserve the old same-map comparison.
                nearest = self:FindNearestWayshrineOnCurrentMap(routeX, routeY)
            end

            if nearest then
                EPC:Print(string.format(
                    "Closest discovered wayshrine across the quest's full destination zone: %s.",
                    nearest.name
                ))
                self:TravelToWayshrineNode(nearest.nodeIndex, nearest.name)
                return
            end
        end

        -- Some objectives are in interiors/private instances with no wayshrine on
        -- that exact map. Re-run the established parent-zone resolver, but do not
        -- request the same position a second time.
        local fallbackQuest = request.quest or {}
        fallbackQuest.skipPositionRequest = true
        local entry, reason = self:GetNearestWayshrineForQuestSelection(fallbackQuest)
        if entry then
            EPC:Print(string.format(
                "No wayshrine exists on the exact objective map; using the closest resolved destination wayshrine: %s.",
                entry.name
            ))
            self:TravelToWayshrineNode(entry.nodeIndex, entry.name)
        else
            EPC:Print(reason or "No discovered wayshrine could be resolved for that objective.")
        end
        return
    end

    if EPC.saved and (EPC.saved.activeTab == "MAP" or EPC.saved.activeTab == "QUESTS") then
        if EPC.saved.activeTab == "MAP" then
            EPC.saved.travelPage = 1
            EPC.saved.travelBookPage = 1
        end
        EPC:RequestRefresh("quest-position")
    end
end

function T:GetFocusedQuest(snapshot)
    -- The Suite's selected quest source is authoritative. In particular, ACTIVE_QUEST
    -- can intentionally differ from ESO's previously assisted quest for a frame or
    -- after a manual selection. Resolve that exact journal index first so the Travel
    -- page, direction data, and quest overlay all target the same quest.
    local questIndex = nil
    local source = EPC.saved and tostring(EPC.saved.questTrackingSource or "ACTIVE_QUEST") or "ACTIVE_QUEST"
    if source ~= "GOLDEN_PURSUITS" and source ~= "MAIN_QUEST" then source = "ACTIVE_QUEST" end

    if EPC.ActiveQuest and type(EPC.ActiveQuest.ResolveQuestSource2516) == "function" then
        local ok, resolved = pcall(EPC.ActiveQuest.ResolveQuestSource2516, EPC.ActiveQuest, source)
        if ok then questIndex = safeNumber(resolved, 0) end
    end

    -- Compatibility fallback for older saved data or if ActiveQuest has not finished
    -- initializing yet: use ESO's assisted quest exactly as the previous code did.
    if safeNumber(questIndex, 0) <= 0
        and type(GetNumTracked) == "function"
        and type(GetTrackedByIndex) == "function"
        and type(GetTrackedIsAssisted) == "function"
        and TRACK_TYPE_QUEST ~= nil then
        local countOk, numTracked = pcall(GetNumTracked)
        if countOk then
            numTracked = safeNumber(numTracked, 0)
            for trackedIndex = 1, numTracked do
                local trackedOk, trackType, param1, param2 = pcall(GetTrackedByIndex, trackedIndex)
                if trackedOk and trackType == TRACK_TYPE_QUEST then
                    local assistedOk, assisted = pcall(GetTrackedIsAssisted, trackType, param1, param2)
                    if assistedOk and assisted == true then
                        questIndex = safeNumber(param1, 0)
                        if questIndex > 0 then break end
                    end
                end
            end
        end
    end

    questIndex = safeNumber(questIndex, 0)
    if questIndex <= 0 then return nil end

    local questName = "Focused quest"
    if type(GetJournalQuestName) == "function" then
        local nameOk, returnedQuestName = pcall(GetJournalQuestName, questIndex)
        if nameOk then questName = clean(returnedQuestName, questName) end
    end

    local zoneName = "Unknown zone"
    local objectiveName = "Current objective"
    local zoneIndex = 0
    local poiIndex = 0
    if type(GetJournalQuestLocationInfo) == "function" then
        local locationOk, returnedZoneName, returnedObjectiveName, returnedZoneIndex, returnedPoiIndex = pcall(
            GetJournalQuestLocationInfo,
            questIndex
        )
        if locationOk then
            zoneName = clean(returnedZoneName, zoneName)
            objectiveName = clean(returnedObjectiveName, objectiveName)
            zoneIndex = safeNumber(returnedZoneIndex, 0)
            poiIndex = safeNumber(returnedPoiIndex, 0)
        end
    end

    local zoneId, parentZoneId = getZoneIdentity(zoneIndex)
    local stepIndex, conditionIndex = self:FindQuestCondition(questIndex)
    local identityKey = string.format(
        "%s:%d:%d:%d",
        source,
        questIndex,
        safeNumber(stepIndex, 0),
        safeNumber(conditionIndex, 0)
    )

    local quest = {
        questIndex = questIndex,
        source = source,
        name = questName,
        objectiveName = objectiveName,
        zoneName = zoneName,
        zoneIndex = zoneIndex,
        zoneId = zoneId,
        parentZoneId = parentZoneId,
        poiIndex = poiIndex,
        stepIndex = stepIndex,
        conditionIndex = conditionIndex,
        identityKey = identityKey,
    }

    if stepIndex and conditionIndex then
        -- Key by the authoritative source + quest + objective. Do not key by whatever
        -- map happened to be open before SetMapToQuestCondition runs.
        quest.positionKey = identityKey .. ":objective"
        quest.position = self.questPositionCache[quest.positionKey]
        if not quest.position then
            self:RequestFocusedQuestPosition(quest)
            quest.position = self.questPositionCache[quest.positionKey]
        end
    end

    return quest
end

function T:GetMode()
    local mode = EPC.saved and EPC.saved.travelMode or "SHRINES"
    if not self.modeLabels[mode] then
        mode = "SHRINES"
        if EPC.saved then EPC.saved.travelMode = mode end
    end
    return mode
end

function T:SetMode(mode)
    if not self.modeLabels[mode] then return end
    EPC.saved.travelMode = mode
    EPC.saved.travelPage = 1
    EPC.saved.travelBookPage = 1
    self.selectedKey = nil
    EPC:RefreshNow("travel-mode")
end

function T:GetPageSize(pageSize)
    pageSize = math.floor(safeNumber(pageSize, self.PAGE_SIZE or 4))
    return math.max(1, math.min(12, pageSize))
end

function T:GetPageKey(pageSize)
    pageSize = self:GetPageSize(pageSize)
    if pageSize == (self.BOOK_PAGE_SIZE or 8) then return "travelBookPage" end
    return "travelPage"
end

function T:ChangePage(delta, pageSize)
    pageSize = self:GetPageSize(pageSize)
    local pageKey = self:GetPageKey(pageSize)
    local page = safeNumber(EPC.saved[pageKey], 1) + safeNumber(delta, 0)
    EPC.saved[pageKey] = math.max(1, page)
    self.selectedKey = nil
    EPC:RefreshNow("travel-page")
end

function T:SelectVisibleRow(rowIndex, pageSize)
    local view
    if pageSize ~= nil then
        local snapshot = EPC.lastSnapshot or (EPC.Engine and EPC.Engine:BuildSnapshot()) or {}
        view = self:BuildView(snapshot, pageSize)
    else
        view = self.lastView
    end
    local row = view and view.rows and view.rows[rowIndex]
    if not row then return end
    if row.kind == "ZONE_HEADER" then
        self:ToggleTravelZone(row.zoneKey or row.zoneName)
        return
    end
    self.selectedKey = row.key
    EPC:RefreshNow("travel-selection")
end

function T:IsWayshrineTravelFreeNow()
    -- ESO charges a recall fee when teleporting from the world, but travel
    -- initiated from an active wayshrine is free. Prefer the map travel mode
    -- when the API exposes it; otherwise fall back to the normal recall fee.
    if type(GetMapMode) == "function" and MAP_MODE_FAST_TRAVEL ~= nil then
        local ok, mode = pcall(GetMapMode)
        if ok and mode == MAP_MODE_FAST_TRAVEL then
            return true
        end
    end

    if type(ZO_WorldMap_IsTravelingFromWayshrine) == "function" then
        local ok, fromWayshrine = pcall(ZO_WorldMap_IsTravelingFromWayshrine)
        if ok and fromWayshrine == true then
            return true
        end
    end

    return false
end

function T:GetLiveWayshrineTravelCost(nodeIndex)
    local currency = CURT_MONEY
    if type(GetRecallCurrency) == "function" then
        local currencyOk, returnedCurrency = pcall(GetRecallCurrency)
        if not currencyOk and nodeIndex ~= nil then
            currencyOk, returnedCurrency = pcall(GetRecallCurrency, nodeIndex)
        end
        if currencyOk and returnedCurrency ~= nil then
            currency = returnedCurrency
        end
    end

    if self:IsWayshrineTravelFreeNow() then
        return 0, currency
    end

    local cost = 0
    if type(GetRecallCost) == "function" then
        -- Current ESO UI uses the live recall fee. It is not destination-specific.
        local costOk, returnedCost = pcall(GetRecallCost)
        -- Compatibility fallback for API revisions that accepted a node index.
        if not costOk and nodeIndex ~= nil then
            costOk, returnedCost = pcall(GetRecallCost, nodeIndex)
        end
        if costOk then cost = safeNumber(returnedCost, 0) end
    end

    return cost, currency
end

function T:CanLeaveNow()
    if type(IsUnitInCombat) == "function" then
        local ok, inCombat = pcall(IsUnitInCombat, "player")
        if ok and inCombat then return false, "Unavailable in combat" end
    end

    if type(CanLeaveCurrentLocationViaTeleport) == "function" then
        local ok, canLeave = pcall(CanLeaveCurrentLocationViaTeleport)
        if ok and not canLeave then return false, "Travel blocked at this location" end
    end

    return true, "Ready"
end

-- Build a single discovered wayshrine entry using the same safety rules as the Travel page.
function T:GetWayshrineNodeEntry(nodeIndex)
    nodeIndex = safeNumber(nodeIndex, 0)
    if nodeIndex <= 0 or type(GetFastTravelNodeInfo) ~= "function" then return nil end

    local ok, known, name, normalizedX, normalizedY, _, _, poiType, isShownInCurrentMap, linkedCollectibleIsLocked = pcall(
        GetFastTravelNodeInfo,
        nodeIndex
    )
    local isWayshrine = POI_TYPE_WAYSHRINE == nil or poiType == POI_TYPE_WAYSHRINE
    if not ok or not known or not isWayshrine or linkedCollectibleIsLocked then return nil end

    if type(GetFastTravelNodeOutboundOnlyInfo) == "function" then
        local outboundOk, outbound = pcall(GetFastTravelNodeOutboundOnlyInfo, nodeIndex)
        if outboundOk and outbound == true then return nil end
    end

    local zoneIndex = 0
    local poiIndexFunction = GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices
    if type(poiIndexFunction) == "function" then
        local indicesOk, returnedZoneIndex = pcall(poiIndexFunction, nodeIndex)
        if indicesOk then zoneIndex = safeNumber(returnedZoneIndex, 0) end
    end

    local zoneName = "Unknown zone"
    if zoneIndex > 0 and type(GetZoneNameByIndex) == "function" then
        local zoneOk, returnedZoneName = pcall(GetZoneNameByIndex, zoneIndex)
        if zoneOk then zoneName = clean(returnedZoneName, zoneName) end
    end
    local zoneId, parentZoneId = getZoneIdentity(zoneIndex)

    local cost, currency = self:GetLiveWayshrineTravelCost(nodeIndex)

    local canAfford = true
    if cost > 0 and type(GetCurrencyAmount) == "function" and CURRENCY_LOCATION_CHARACTER ~= nil then
        local amountOk, amount = pcall(GetCurrencyAmount, currency, CURRENCY_LOCATION_CHARACTER)
        if amountOk then canAfford = safeNumber(amount, 0) >= cost end
    end

    local canLeave, leaveReason = self:CanLeaveNow()
    local costText
    if cost <= 0 then
        costText = "Free"
    elseif currency == CURT_MONEY or currency == nil then
        costText = formatNumber(cost) .. " gold"
    else
        costText = "Cost " .. formatNumber(cost)
    end

    local statusText = leaveReason
    if canLeave and not canAfford then statusText = "Not enough currency" end

    return {
        kind = "SHRINE",
        key = "S:" .. tostring(nodeIndex),
        nodeIndex = nodeIndex,
        name = clean(name, "Unnamed wayshrine"),
        zoneName = zoneName,
        zoneIndex = zoneIndex,
        zoneId = zoneId,
        parentZoneId = parentZoneId,
        normalizedX = tonumber(normalizedX),
        normalizedY = tonumber(normalizedY),
        isShownInCurrentMap = isShownInCurrentMap == true,
        cost = cost,
        costText = costText,
        statusText = statusText,
        canTravel = canLeave and canAfford,
    }
end

-- Find the nearest discovered wayshrine to a saved checkpoint. ESO exposes fast-travel
-- node coordinates relative to the current map, so this temporarily evaluates the
-- checkpoint's saved map, then restores the map that was active beforehand.
function T:GetNearestWayshrineToCheckpoint(checkpoint)
    if type(checkpoint) ~= "table" then return nil, false end
    local targetX, targetY = tonumber(checkpoint.x), tonumber(checkpoint.y)
    if not targetX or not targetY or targetX <= 0 or targetY <= 0 then return nil, false end

    local originalMapId = getCurrentMapIdSafe()
    local originalMapIndex = 0
    if type(GetCurrentMapIndex) == "function" then
        local ok, value = pcall(GetCurrentMapIndex)
        if ok then originalMapIndex = safeNumber(value, 0) end
    end

    local desiredMapId = safeNumber(checkpoint.mapId, 0)
    local desiredMapIndex = safeNumber(checkpoint.mapIndex, 0)
    local switched = false
    local comparableMapReady = true
    if desiredMapId > 0 and type(SetMapToMapId) == "function" and desiredMapId ~= originalMapId then
        pcall(SetMapToMapId, desiredMapId)
        comparableMapReady = getCurrentMapIdSafe() == desiredMapId
        switched = comparableMapReady
    elseif desiredMapIndex > 0 and type(SetMapToMapListIndex) == "function" and desiredMapIndex ~= originalMapIndex then
        pcall(SetMapToMapListIndex, desiredMapIndex)
        local currentMapIndex = 0
        if type(GetCurrentMapIndex) == "function" then
            local ok, value = pcall(GetCurrentMapIndex)
            if ok then currentMapIndex = safeNumber(value, 0) end
        end
        comparableMapReady = currentMapIndex == desiredMapIndex
        switched = comparableMapReady
    end

    local total = 0
    if type(GetNumFastTravelNodes) == "function" then
        local ok, count = pcall(GetNumFastTravelNodes)
        if ok then total = safeNumber(count, 0) end
    end

    local best, bestDistance = nil, nil
    local sameZoneFallback = nil
    local checkpointZoneId = safeNumber(checkpoint.zoneId, 0)
    local checkpointZoneName = lower(checkpoint.zone or checkpoint.mapName or "")

    for nodeIndex = 1, total do
        local entry = self:GetWayshrineNodeEntry(nodeIndex)
        if entry then
            local sameZone = false
            if checkpointZoneId > 0 then
                sameZone = entry.zoneId == checkpointZoneId or entry.parentZoneId == checkpointZoneId
            end
            if not sameZone and checkpointZoneName ~= "" then
                sameZone = lower(entry.zoneName) == checkpointZoneName
            end
            if sameZone and sameZoneFallback == nil then sameZoneFallback = entry end

            if comparableMapReady and entry.isShownInCurrentMap and entry.normalizedX and entry.normalizedY then
                local dx = entry.normalizedX - targetX
                local dy = entry.normalizedY - targetY
                local distance = (dx * dx) + (dy * dy)
                if bestDistance == nil or distance < bestDistance then
                    best = entry
                    bestDistance = distance
                end
            end
        end
    end

    if switched then
        if originalMapId > 0 and type(SetMapToMapId) == "function" then
            pcall(SetMapToMapId, originalMapId)
        elseif originalMapIndex > 0 and type(SetMapToMapListIndex) == "function" then
            pcall(SetMapToMapListIndex, originalMapIndex)
        end
    end

    if best then
        best.checkpointDistanceSquared = bestDistance
        best.exactCheckpointMapMatch = true
        return best, true
    end
    if sameZoneFallback then
        sameZoneFallback.exactCheckpointMapMatch = false
        return sameZoneFallback, false
    end
    return nil, false
end

function T:TravelToWayshrineNode(nodeIndex, displayName)
    local entry = self:GetWayshrineNodeEntry(nodeIndex)
    if not entry then
        EPC:Print("That wayshrine is no longer available or has not been discovered.")
        return false
    end
    if not entry.canTravel then
        EPC:Print(entry.statusText or "ESO currently blocks travel to that wayshrine.")
        return false
    end
    if type(FastTravelToNode) ~= "function" then
        EPC:Print("Fast-travel API is unavailable.")
        return false
    end
    EPC:Print("Traveling to " .. clean(displayName or entry.name, entry.name) .. ".")
    local ok = pcall(FastTravelToNode, entry.nodeIndex)
    if not ok then
        EPC:Print("ESO rejected the travel request. Try the normal World Map.")
        return false
    end
    return true
end


local function serviceTextMatches(kind, name, icon)
    local textValue = lower(tostring(name or "") .. " " .. tostring(icon or ""))
    if kind == "STABLE" then
        local stableNeedles = {"stablemaster", "stable master", "servicepin_stable", "servicetooltipicon_stablemaster", "stable"}
        for i = 1, #stableNeedles do
            if string.find(textValue, stableNeedles[i], 1, true) then return true end
        end
        return false
    end
    if kind == "GUILD_STORE" then
        local guildNeedles = {"guild trader", "guildtrader", "guild store", "guildstore", "trading house", "trader"}
        for i = 1, #guildNeedles do
            if string.find(textValue, guildNeedles[i], 1, true) then return true end
        end
        return false
    end

    -- Ordinary merchant routing intentionally excludes guild traders so the two
    -- buttons remain distinct destinations.
    if string.find(textValue, "guild trader", 1, true)
        or string.find(textValue, "guildtrader", 1, true)
        or string.find(textValue, "guild store", 1, true)
        or string.find(textValue, "guildstore", 1, true) then
        return false
    end
    local merchantNeedles = {
        "merchant", "vendor", "generalstore", "general_store", "general goods",
        "shop", "store", "armsman", "armorer", "clothier", "woodworker",
        "alchemist", "enchanter", "mystic", "chef", "brewer", "outfitter",
        "blacksmith", "weaponsmith", "grocer"
    }
    for i = 1, #merchantNeedles do
        if string.find(textValue, merchantNeedles[i], 1, true) then return true end
    end
    return false
end

function T:GetNearestCurrentZoneService(kind)
    if kind == "STABLE" then
        kind = "STABLE"
    elseif kind == "GUILD_STORE" then
        kind = "GUILD_STORE"
    else
        kind = "MERCHANT"
    end
    if type(SetMapToPlayerLocation) == "function" then pcall(SetMapToPlayerLocation) end

    local mapId = getCurrentMapIdSafe()
    local zoneIndex = 0
    if type(GetCurrentMapZoneIndex) == "function" then
        local ok, value = pcall(GetCurrentMapZoneIndex)
        if ok then zoneIndex = safeNumber(value, 0) end
    end
    if zoneIndex <= 0 and type(GetUnitZoneIndex) == "function" then
        local ok, value = pcall(GetUnitZoneIndex, "player")
        if ok then zoneIndex = safeNumber(value, 0) end
    end

    local playerX, playerY = 0.5, 0.5
    if type(GetMapPlayerPosition) == "function" then
        local ok, x, y, _, shown = pcall(GetMapPlayerPosition, "player")
        if ok and shown ~= false and tonumber(x) and tonumber(y) then
            playerX, playerY = tonumber(x), tonumber(y)
        end
    end

    local candidates = {}
    local function addCandidate(name, x, y, source)
        x, y = tonumber(x), tonumber(y)
        if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end
        local dx, dy = x - playerX, y - playerY
        candidates[#candidates + 1] = {
            name = clean(name, kind == "GUILD_STORE" and "Guild Trader" or (kind == "STABLE" and "Stablemaster" or "Merchant")),
            x = x, y = y, distance2 = dx * dx + dy * dy, mapId = mapId,
            zoneIndex = zoneIndex, source = source,
        }
    end

    if zoneIndex > 0 and type(GetNumPOIs) == "function" and type(GetPOIMapInfo) == "function" then
        local ok, count = pcall(GetNumPOIs, zoneIndex)
        count = ok and safeNumber(count, 0) or 0
        for poiIndex = 1, count do
            local infoOk, x, y, _, icon, shown, locked = pcall(GetPOIMapInfo, zoneIndex, poiIndex)
            if infoOk and shown == true and locked ~= true and tonumber(x) and tonumber(y) then
                local name = ""
                if type(GetPOIInfo) == "function" then
                    local nameOk, returnedName = pcall(GetPOIInfo, zoneIndex, poiIndex)
                    if nameOk then name = clean(returnedName, "") end
                end
                if serviceTextMatches(kind, name, icon) then
                    addCandidate(name, x, y, "poi")
                end
            end
        end
    end

    -- Native World Map town/service pins captured by the minimap provide the
    -- service locations ESO displays in cities even when GetPOIMapInfo does not.
    if EPC.saved and type(EPC.saved.miniMapNativeTownPins) == "table" and mapId > 0 then
        local nativeList = EPC.saved.miniMapNativeTownPins[tostring(mapId)]
        if type(nativeList) == "table" then
            for i=1,#nativeList do
                local row=nativeList[i]
                if type(row)=="table" and serviceTextMatches(kind,row.name,row.texture) then
                    addCandidate(row.name,row.x,row.y,"native-town-pin")
                end
            end
        end
    end

    -- The minimap learns merchant locations when the player opens a store. Use
    -- those remembered positions too, since ESO does not expose every vendor as
    -- a normal map POI.
    if kind == "MERCHANT" and EPC.saved and type(EPC.saved.miniMapKnownMerchants) == "table" and mapId > 0 then
        local list = EPC.saved.miniMapKnownMerchants[tostring(mapId)]
        if type(list) == "table" then
            for i = 1, #list do
                local row = list[i]
                if type(row) == "table" then addCandidate(row.name, row.x, row.y, "learned") end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if math.abs((a.distance2 or 0) - (b.distance2 or 0)) > 0.0000001 then
            return (a.distance2 or 0) < (b.distance2 or 0)
        end
        return lower(a.name) < lower(b.name)
    end)
    return candidates[1]
end


-- Return the player's position in the same universal normalized coordinate
-- system used by quest routing and cached native town/service pins.
function T:GetPlayerUniversalPosition()
    local mapId = getCurrentMapIdSafe()
    if mapId <= 0 or type(GetMapPlayerPosition) ~= "function" then return nil, nil, mapId end
    local ok, x, y, _, shown = pcall(GetMapPlayerPosition, "player")
    x, y = tonumber(x), tonumber(y)
    if not ok or shown == false or x == nil or y == nil then return nil, nil, mapId end
    local gx, gy = self:GetUniversalPointForMap(mapId, x, y)
    return gx, gy, mapId
end

function T:GetLocalPointForMap(mapId, globalX, globalY)
    mapId = safeNumber(mapId, 0)
    globalX, globalY = tonumber(globalX), tonumber(globalY)
    if mapId <= 0 or globalX == nil or globalY == nil or type(GetUniversallyNormalizedMapInfo) ~= "function" then
        return nil, nil
    end
    local ok, ox, oy, w, h = pcall(GetUniversallyNormalizedMapInfo, mapId)
    ox, oy, w, h = tonumber(ox), tonumber(oy), tonumber(w), tonumber(h)
    if not ok or ox == nil or oy == nil or w == nil or h == nil or w <= 0 or h <= 0 then return nil, nil end
    local x, y = (globalX - ox) / w, (globalY - oy) / h
    local epsilon = 0.003
    if x < -epsilon or x > 1 + epsilon or y < -epsilon or y > 1 + epsilon then return nil, nil end
    return math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
end

-- Search the native ESO service-pin cache across every map the Suite has seen.
-- This is the cross-map fallback used only when the current map/zone does not
-- expose the requested service. Universal coordinates let us compare different
-- town/zone maps without changing the visible World Map.
function T:GetNearestKnownServiceAcrossMaps(kind)
    if kind == "STABLE" then kind = "STABLE"
    elseif kind == "GUILD_STORE" then kind = "GUILD_STORE"
    else kind = "MERCHANT" end

    if not EPC.saved or type(EPC.saved.miniMapNativeTownPins) ~= "table" then return nil end
    local playerGX, playerGY, currentMapId = self:GetPlayerUniversalPosition()
    if playerGX == nil or playerGY == nil then return nil end

    local best, bestDistance = nil, nil
    local caches = EPC.saved.miniMapNativeTownPins
    for cacheKey, list in pairs(caches) do
        if type(list) == "table" then
            local cacheMapId = safeNumber(cacheKey, 0)
            for i = 1, #list do
                local row = list[i]
                if type(row) == "table" and serviceTextMatches(kind, row.name, row.texture) then
                    local mapId = safeNumber(row.sourceMapId, cacheMapId)
                    local gx, gy = tonumber(row.ux), tonumber(row.uy)
                    if (gx == nil or gy == nil) and mapId > 0 then
                        gx, gy = self:GetUniversalPointForMap(mapId, row.x, row.y)
                    end
                    if gx ~= nil and gy ~= nil then
                        local dx, dy = gx - playerGX, gy - playerGY
                        local distance2 = dx * dx + dy * dy
                        if bestDistance == nil or distance2 < bestDistance then
                            bestDistance = distance2
                            best = {
                                name = clean(row.name, kind == "GUILD_STORE" and "Guild Trader" or (kind == "STABLE" and "Stablemaster" or "Merchant")),
                                x = tonumber(row.x), y = tonumber(row.y),
                                ux = gx, uy = gy,
                                mapId = mapId,
                                sourceMapId = mapId,
                                zoneId = safeNumber(row.zoneId, 0),
                                zoneIndex = safeNumber(row.zoneIndex, 0),
                                zoneName = clean(row.zoneName, ""),
                                distance2 = distance2,
                                source = "native-town-pin-cross-map",
                                isCrossMap = mapId > 0 and currentMapId > 0 and mapId ~= currentMapId,
                            }
                        end
                    end
                end
            end
        end
    end
    return best
end

function T:TryPlacePendingServiceWaypoint()
    local target = self.pendingServiceWaypoint
    if type(target) ~= "table" then return false end
    local gx, gy = tonumber(target.ux), tonumber(target.uy)
    if gx == nil or gy == nil then self.pendingServiceWaypoint = nil; return false end

    local currentMapId = getCurrentMapIdSafe()
    local x, y = self:GetLocalPointForMap(currentMapId, gx, gy)
    if not x or not y then return false end
    if type(PingMap) == "function" and MAP_PIN_TYPE_PLAYER_WAYPOINT ~= nil and MAP_TYPE_LOCATION_CENTERED ~= nil then
        local ok = pcall(PingMap, MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, y)
        if ok then
            self.pendingServiceWaypoint = nil
            EPC:Print("Waypoint set on " .. clean(target.name, "service destination") .. ".")
            return true
        end
    end
    return false
end

function T:GetNearestWayshrineToCurrentMapPoint(targetX, targetY)
    targetX, targetY = tonumber(targetX), tonumber(targetY)
    if not targetX or not targetY then return nil end
    local total = 0
    if type(GetNumFastTravelNodes) == "function" then
        local ok, count = pcall(GetNumFastTravelNodes)
        if ok then total = safeNumber(count, 0) end
    end
    local best, bestDistance = nil, nil
    for nodeIndex = 1, total do
        local entry = self:GetWayshrineNodeEntry(nodeIndex)
        if entry and entry.canTravel and entry.isShownInCurrentMap and entry.normalizedX and entry.normalizedY then
            local dx, dy = entry.normalizedX - targetX, entry.normalizedY - targetY
            local dist2 = dx * dx + dy * dy
            if bestDistance == nil or dist2 < bestDistance then
                best, bestDistance = entry, dist2
            end
        end
    end
    return best
end

function T:TravelToNearestService(kind)
    if kind == "STABLE" then
        kind = "STABLE"
    elseif kind == "GUILD_STORE" then
        kind = "GUILD_STORE"
    else
        kind = "MERCHANT"
    end
    local label = kind == "GUILD_STORE" and "guild store" or (kind == "STABLE" and "Stablemaster" or "merchant")

    -- Prefer a service on the player's current map/zone. Only search other maps
    -- when the current destination has none, matching the requested "if needed"
    -- behavior rather than unexpectedly sending the player across Tamriel.
    local target = self:GetNearestCurrentZoneService(kind)
    local crossMap = false
    if not target then
        target = self:GetNearestKnownServiceAcrossMaps(kind)
        crossMap = target ~= nil
    end
    if not target then
        EPC:Print("No known " .. label .. " could be found. Open town/zone maps as you discover them so ESO can expose their service locations.")
        return false
    end

    local targetMapId = safeNumber(target.mapId or target.sourceMapId, 0)
    local targetGX, targetGY = tonumber(target.ux), tonumber(target.uy)
    if (targetGX == nil or targetGY == nil) and targetMapId > 0 then
        targetGX, targetGY = self:GetUniversalPointForMap(targetMapId, target.x, target.y)
        target.ux, target.uy = targetGX, targetGY
    end

    local currentMapId = getCurrentMapIdSafe()
    local sameMap = targetMapId <= 0 or currentMapId <= 0 or targetMapId == currentMapId

    -- Same-map services can get their waypoint immediately. Cross-map services
    -- receive a pending waypoint that is projected onto the arrival map after
    -- the wayshrine load completes.
    if sameMap and type(PingMap) == "function" and MAP_PIN_TYPE_PLAYER_WAYPOINT ~= nil and MAP_TYPE_LOCATION_CENTERED ~= nil
        and tonumber(target.x) and tonumber(target.y) then
        pcall(PingMap, MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, target.x, target.y)
    elseif targetGX ~= nil and targetGY ~= nil then
        self.pendingServiceWaypoint = target
    end

    local shrine = nil
    if targetGX ~= nil and targetGY ~= nil and targetMapId > 0 then
        shrine = self:FindNearestWayshrineAcrossQuestZone(targetGX, targetGY, safeNumber(target.zoneId, 0), targetMapId)
    end
    if not shrine and sameMap and tonumber(target.x) and tonumber(target.y) then
        shrine = self:GetNearestWayshrineToCurrentMapPoint(target.x, target.y)
    end
    if not shrine then
        self.pendingServiceWaypoint = nil
        EPC:Print("Found " .. target.name .. ", but no discovered wayshrine on its destination map can be used to reach it.")
        return false
    end

    local zoneText = clean(target.zoneName, "")
    if crossMap or not sameMap then
        EPC:Print(string.format("Nearest available %s outside this map: %s%s. Traveling via %s.", label, target.name, zoneText ~= "" and (" in " .. zoneText) or "", shrine.name))
    else
        EPC:Print(string.format("Nearest %s: %s. Traveling via %s and setting a waypoint on the destination.", label, target.name, shrine.name))
    end
    return self:TravelToWayshrineNode(shrine.nodeIndex, shrine.name)
end

-- Resolve the stable overland zone recorded by ESO for an accepted quest.
-- This is intentionally based on questId/GetQuestZoneId rather than
-- GetJournalQuestLocationInfo(), because the latter may be an instance or
-- objective label rather than a real travel zone.
-- Resolve stable overland metadata exposed specifically for an active journal quest.
-- This is intentionally separate from GetQuestZoneId(), which can identify an
-- interior instance (for example a Main Story mission) rather than the zone that
-- owns the wayshrines needed to reach it.
function T:GetMainStoryHarborageZone(journalQuestIndex)
    local qIndex = safeNumber(journalQuestIndex, 0)
    if qIndex <= 0 then return 0, "" end

    -- The Harborage itself is the reliable signal here. Do not require a
    -- QUEST_TYPE_MAIN_STORY match because ESO journal metadata can report an
    -- unexpected quest type for active Main Story steps.
    local alliance = 0
    if type(GetUnitAlliance) == "function" then
        local aOk, value = pcall(GetUnitAlliance, "player")
        if aOk then alliance = safeNumber(value, 0) end
    end

    local wanted = ""
    local dc = (ALLIANCE_DAGGERFALL_COVENANT ~= nil and alliance == ALLIANCE_DAGGERFALL_COVENANT) or alliance == 3
    local ad = (ALLIANCE_ALDMERI_DOMINION ~= nil and alliance == ALLIANCE_ALDMERI_DOMINION) or alliance == 1
    local ep = (ALLIANCE_EBONHEART_PACT ~= nil and alliance == ALLIANCE_EBONHEART_PACT) or alliance == 2
    if dc then
        wanted = "Glenumbra"
    elseif ad then
        wanted = "Auridon"
    elseif ep then
        wanted = "Stonefalls"
    end
    if wanted == "" then return 0, "" end

    if type(GetNumZones) == "function" and type(GetZoneNameByIndex) == "function" and type(GetZoneId) == "function" then
        local countOk, count = pcall(GetNumZones)
        count = countOk and safeNumber(count, 0) or 0
        for zoneIndex = 1, count do
            local nameOk, name = pcall(GetZoneNameByIndex, zoneIndex)
            if nameOk and lower(name or "") == lower(wanted) then
                local idOk, zoneId = pcall(GetZoneId, zoneIndex)
                zoneId = idOk and safeNumber(zoneId, 0) or 0
                return zoneId, wanted
            end
        end
    end
    return 0, wanted
end

local function isHarborageLocation(value)
    local text = lower(clean(value, ""))
    return text ~= "" and string.find(text, "harborage", 1, true) ~= nil
end

function T:GetJournalQuestOverlandFallbackZone(journalQuestIndex)
    local qIndex = safeNumber(journalQuestIndex, 0)
    if qIndex <= 0 then return 0, "", "" end

    -- ESO reports The Harborage as the location for many Main Story quests.
    -- Translate that one special hub to the alliance-specific overland zone that
    -- actually contains its entrance and wayshrines. Other quests remain dynamic.
    if type(GetJournalQuestLocationInfo) == "function" then
        local locOk, locationName, _, locationZoneIndex = pcall(GetJournalQuestLocationInfo, qIndex)
        if locOk then
            locationZoneIndex = safeNumber(locationZoneIndex, 0)

            -- First trust the location's numeric zone index, not its display label.
            if locationZoneIndex > 0 and type(GetZoneId) == "function" then
                local idOk, locationZoneId = pcall(GetZoneId, locationZoneIndex)
                locationZoneId = idOk and safeNumber(locationZoneId, 0) or 0
                if locationZoneId > 0 then
                    local canonical = getCanonicalZoneId(locationZoneId)
                    if canonical <= 0 then canonical = locationZoneId end
                    local zoneName = ""
                    if type(GetZoneNameById) == "function" then
                        local nameOk, value = pcall(GetZoneNameById, canonical)
                        if nameOk then zoneName = clean(value, "") end
                    end
                    if zoneName ~= "" and not isHarborageLocation(zoneName) then
                        return canonical, zoneName, "journal-location-zone-index"
                    end
                end
            end

            if isHarborageLocation(locationName) then
                local zoneId, zoneName = self:GetMainStoryHarborageZone(qIndex)
                if zoneName ~= "" then return zoneId, zoneName, "main-story-harborage" end
            end
        end
    end

    if type(GetJournalQuestZoneStoryZoneId) == "function" then
        local ok, zoneStoryId = pcall(GetJournalQuestZoneStoryZoneId, qIndex)
        zoneStoryId = ok and safeNumber(zoneStoryId, 0) or 0
        if zoneStoryId > 0 then
            local canonical = getCanonicalZoneId(zoneStoryId)
            if canonical <= 0 then canonical = zoneStoryId end
            local zoneName = ""
            if type(GetZoneNameById) == "function" then
                local nameOk, value = pcall(GetZoneNameById, canonical)
                if nameOk then zoneName = clean(value, "") end
            end
            if zoneName ~= "" then return canonical, zoneName, "zone-story" end
        end
    end

    if type(GetJournalQuestStartingZone) == "function" and type(GetZoneId) == "function" then
        local ok, startZoneIndex = pcall(GetJournalQuestStartingZone, qIndex)
        startZoneIndex = ok and safeNumber(startZoneIndex, 0) or 0
        if startZoneIndex > 0 then
            local idOk, startZoneId = pcall(GetZoneId, startZoneIndex)
            startZoneId = idOk and safeNumber(startZoneId, 0) or 0
            if startZoneId > 0 then
                local canonical = getCanonicalZoneId(startZoneId)
                if canonical <= 0 then canonical = startZoneId end
                local zoneName = ""
                if type(GetZoneNameById) == "function" then
                    local nameOk, value = pcall(GetZoneNameById, canonical)
                    if nameOk then zoneName = clean(value, "") end
                end
                if zoneName ~= "" then return canonical, zoneName, "starting-zone" end
            end
        end
    end

    return 0, "", ""
end

function T:GetQuestRecordZone(quest)
    if not quest then return 0, 0, "" end
    local questId = safeNumber(quest.questId, 0)
    if questId <= 0 and safeNumber(quest.questIndex, 0) > 0 and type(GetJournalQuestId) == "function" then
        local ok, value = pcall(GetJournalQuestId, safeNumber(quest.questIndex, 0))
        if ok then questId = safeNumber(value, 0) end
    end

    local zoneId = 0
    if questId > 0 and type(GetQuestZoneId) == "function" then
        local ok, value = pcall(GetQuestZoneId, questId)
        if ok then zoneId = safeNumber(value, 0) end
    end
    local canonicalZoneId = getCanonicalZoneId(zoneId)
    if canonicalZoneId <= 0 then canonicalZoneId = zoneId end

    local zoneName = ""
    local nameId = canonicalZoneId > 0 and canonicalZoneId or zoneId
    if nameId > 0 and type(GetZoneNameById) == "function" then
        local ok, value = pcall(GetZoneNameById, nameId)
        if ok then zoneName = clean(value, "") end
    end
    return zoneId, canonicalZoneId, zoneName
end

function T:RequestNearestQuestObjectiveTravel(quest, questIndex, stepIndex, conditionIndex)
    if type(RequestJournalQuestConditionAssistance) ~= "function" then return false end
    if self.pendingQuestTravelTaskId then return true end

    local ok, taskId = pcall(
        RequestJournalQuestConditionAssistance,
        questIndex,
        stepIndex,
        conditionIndex
    )
    if not ok or taskId == nil then return false end

    local positionKey = string.format(
        "travel:%d:%d:%d:%d",
        safeNumber(questIndex, 0),
        safeNumber(stepIndex, 0),
        safeNumber(conditionIndex, 0),
        getCurrentMapIdSafe()
    )
    self.questPositionRequests[taskId] = {
        positionKey = positionKey,
        purpose = "QUEST_TRAVEL",
        quest = quest,
        questIndex = questIndex,
        stepIndex = stepIndex,
        conditionIndex = conditionIndex,
        mapId = getCurrentMapIdSafe(),
        zoneId = getCurrentMapZoneIdSafe(),
    }
    self.questPendingKeys[positionKey] = taskId
    self.pendingQuestTravelTaskId = taskId
    return true
end

-- v0.25.27: resolve the best discovered wayshrine for a Quest Finder selection.
-- ESO does not expose world coordinates for an unaccepted quest giver, so
-- unstarted quests use the selected quest's zone as the authoritative route.
-- Accepted/assisted quests can still use the existing objective-distance ranking.
function T:GetNearestWayshrineForQuestSelection(quest)
    if not quest then
        return nil, "Select a quest first."
    end

    local snapshot = EPC.lastSnapshot or (EPC.Engine and EPC.Engine:BuildSnapshot()) or {}
    local entries = self:GetWayshrines(snapshot)
    local selectedQuestIndex = safeNumber(quest.questIndex, 0)
    local questRecordZoneId, questRecordCanonicalZoneId, questRecordZoneName = self:GetQuestRecordZone(quest)

    local function findShrineByCanonicalZone(targetZoneId, matchType)
        targetZoneId = safeNumber(targetZoneId, 0)
        if targetZoneId <= 0 then return nil end
        local canonical = getCanonicalZoneId(targetZoneId)
        if canonical <= 0 then canonical = targetZoneId end
        local exact, canonicalMatch = nil, nil
        for i = 1, #(entries or {}) do
            local entry = entries[i]
            local entryZoneId = safeNumber(entry and entry.zoneId, 0)
            if entryZoneId == targetZoneId and not exact then exact = entry end
            if not canonicalMatch and entryZoneId > 0 and getCanonicalZoneId(entryZoneId) == canonical then
                canonicalMatch = entry
            end
        end
        if exact then return exact, matchType end
        if canonicalMatch then return canonicalMatch, matchType end
        return nil
    end

    local function findShrineByZoneName(targetZoneName, matchType)
        local wanted = lower(clean(targetZoneName, ""))
        if wanted == "" then return nil end
        for i = 1, #(entries or {}) do
            local entry = entries[i]
            if lower(entry and entry.zoneName or "") == wanted then
                return entry, matchType
            end
        end
        return nil
    end

    -- The Harborage is an alliance-specific hub, not a standalone overland travel zone.
    -- Resolve it immediately before objective-map logic can strand us inside the private map.
    if selectedQuestIndex > 0 and type(GetJournalQuestLocationInfo) == "function" then
        local locOk, locationName, objectiveName, locationZoneIndex = pcall(GetJournalQuestLocationInfo, selectedQuestIndex)
        if locOk then
            locationName = clean(locationName, "")
            objectiveName = clean(objectiveName, "")
            locationZoneIndex = safeNumber(locationZoneIndex, 0)

            -- Main Story mission instances can report the quest title itself as the
            -- zone/objective. Resolve those to the alliance Harborage host BEFORE
            -- the numeric instance zone is considered, otherwise a valid Glenumbra/
            -- Auridon/Stonefalls wayshrine can never match.
            local journalQuestName = ""
            if type(GetJournalQuestName) == "function" then
                local nameOk, value = pcall(GetJournalQuestName, selectedQuestIndex)
                if nameOk then journalQuestName = clean(value, "") end
            end
            local selfReferential = journalQuestName ~= "" and (
                lower(locationName) == lower(journalQuestName) or lower(objectiveName) == lower(journalQuestName)
            )
            local isMainStory = false
            if type(GetJournalQuestType) == "function" then
                local typeOk, qt = pcall(GetJournalQuestType, selectedQuestIndex)
                qt = typeOk and safeNumber(qt, -1) or -1
                isMainStory = (QUEST_TYPE_MAIN_STORY ~= nil and qt == QUEST_TYPE_MAIN_STORY)
            end
            if isHarborageLocation(locationName) or (selfReferential and isMainStory) then
                local harborageZoneId, harborageZoneName = self:GetMainStoryHarborageZone(selectedQuestIndex)
                local shrine, matchType = nil, nil
                if harborageZoneId > 0 then
                    shrine, matchType = findShrineByCanonicalZone(harborageZoneId, "main-story-overland-entry")
                end
                if not shrine and harborageZoneName ~= "" then
                    shrine, matchType = findShrineByZoneName(harborageZoneName, "main-story-overland-entry-name")
                end
                if shrine then
                    shrine.resolvedQuestZoneId = harborageZoneId
                    shrine.resolvedQuestZoneName = harborageZoneName
                    return shrine, matchType
                end
            end

            -- Do NOT return a wayshrine from the journal's broad location zone here.
            -- Many quests expose only the zone at this stage, and choosing the first
            -- shrine in that zone prevents the active-condition position resolver below
            -- from ever comparing the real objective against all discovered shrines.
            -- The journal zone is kept as a last-resort fallback later in this function.

            if isHarborageLocation(locationName) then
                local harborageZoneId, harborageZoneName = self:GetMainStoryHarborageZone(selectedQuestIndex)
                local shrine, matchType = nil, nil
                if harborageZoneId > 0 then
                    shrine, matchType = findShrineByCanonicalZone(harborageZoneId, "harborage-alliance-zone")
                end
                if not shrine and harborageZoneName ~= "" then
                    shrine, matchType = findShrineByZoneName(harborageZoneName, "harborage-alliance-zone-name")
                end
                if shrine then
                    shrine.resolvedQuestZoneId = harborageZoneId
                    shrine.resolvedQuestZoneName = harborageZoneName
                    return shrine, matchType
                end
            end
        end
    end

    -- A completed Undaunted pledge belongs at this character's alliance enclave.
    if selectedQuestIndex > 0 and type(GetJournalQuestInfo) == "function" then
        local ok, _, _, _, _, _, completed, _, _, _, questType = pcall(GetJournalQuestInfo, selectedQuestIndex)
        local isPledge = ok and QUEST_TYPE_UNDAUNTED_PLEDGE ~= nil and questType == QUEST_TYPE_UNDAUNTED_PLEDGE
        if isPledge then
            if type(GetJournalQuestIsComplete) == "function" then
                local completeOk, completeValue = pcall(GetJournalQuestIsComplete, selectedQuestIndex)
                if completeOk then completed = completeValue == true end
            end
            if completed == true then
                local pledgeShrine, enclave = self:GetAlliancePledgeTurnInWayshrine(entries)
                if pledgeShrine then
                    pledgeShrine.pledgeTurnIn = true
                    pledgeShrine.pledgeEnclave = enclave
                    return pledgeShrine, "pledge-turnin"
                elseif enclave then
                    return nil, string.format(
                        "No discovered wayshrine was found for your %s Undaunted pledge turn-in in %s, %s.",
                        enclave.city, enclave.city, enclave.zone
                    )
                end
            end
        end
    end

    -- Resolve an instanced/objective map to the real overland map that physically
    -- contains it. ESO exposes universally-normalized map rectangles even when
    -- parent-map metadata is incomplete. We scan map records for the smallest
    -- containing zone that also owns one of the player's discovered wayshrines.
    local function getContainingOverlandWayshrine(matchType)
        if type(GetCurrentMapId) ~= "function"
            or type(GetUniversallyNormalizedMapInfo) ~= "function"
            or type(GetNumMaps) ~= "function"
            or type(GetMapIdByIndex) ~= "function"
            or type(GetMapInfoById) ~= "function" then
            return nil
        end

        local okMap, currentMapId = pcall(GetCurrentMapId)
        currentMapId = okMap and safeNumber(currentMapId, 0) or 0
        if currentMapId <= 0 then return nil end

        local okRect, ox, oz, w, h = pcall(GetUniversallyNormalizedMapInfo, currentMapId)
        if not okRect then return nil end
        ox, oz, w, h = tonumber(ox) or 0, tonumber(oz) or 0, tonumber(w) or 0, tonumber(h) or 0
        if w <= 0 or h <= 0 then return nil end
        local cx, cz = ox + (w * 0.5), oz + (h * 0.5)

        local mapEntries = self:GetWayshrines(snapshot)
        local bestEntry, bestArea, bestZoneId = nil, nil, 0
        local mapCountOk, mapCount = pcall(GetNumMaps)
        mapCount = mapCountOk and safeNumber(mapCount, 0) or 0

        for mapIndex = 1, mapCount do
            local idOk, mapId = pcall(GetMapIdByIndex, mapIndex)
            mapId = idOk and safeNumber(mapId, 0) or 0
            if mapId > 0 and mapId ~= currentMapId then
                local infoOk, _, _, _, zoneIndex = pcall(GetMapInfoById, mapId)
                zoneIndex = infoOk and safeNumber(zoneIndex, 0) or 0
                if zoneIndex > 0 then
                    local rectOk, mx, mz, mw, mh = pcall(GetUniversallyNormalizedMapInfo, mapId)
                    mx, mz, mw, mh = tonumber(mx) or 0, tonumber(mz) or 0, tonumber(mw) or 0, tonumber(mh) or 0
                    if rectOk and mw > 0 and mh > 0 then
                        local epsilon = 0.000001
                        local contains = cx >= (mx - epsilon) and cx <= (mx + mw + epsilon)
                            and cz >= (mz - epsilon) and cz <= (mz + mh + epsilon)
                        local area = mw * mh
                        if contains and area >= (w * h) then
                            local zoneId = 0
                            if type(GetZoneId) == "function" then
                                local zidOk, zid = pcall(GetZoneId, zoneIndex)
                                if zidOk then zoneId = safeNumber(zid, 0) end
                            end
                            if zoneId > 0 then
                                local canonical = getCanonicalZoneId(zoneId)
                                if canonical <= 0 then canonical = zoneId end
                                for i = 1, #(mapEntries or {}) do
                                    local entry = mapEntries[i]
                                    local entryZoneId = safeNumber(entry and entry.zoneId, 0)
                                    local entryCanonical = getCanonicalZoneId(entryZoneId)
                                    if entryZoneId == zoneId or (entryCanonical > 0 and entryCanonical == canonical) then
                                        if bestArea == nil or area < bestArea then
                                            bestEntry, bestArea, bestZoneId = entry, area, zoneId
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if bestEntry then
            bestEntry.resolvedQuestZoneId = bestZoneId
            if bestZoneId > 0 and type(GetZoneNameById) == "function" then
                local nameOk, zoneName = pcall(GetZoneNameById, bestZoneId)
                if nameOk then bestEntry.resolvedQuestZoneName = clean(zoneName, "") end
            end
            return bestEntry, matchType .. "-overland-container"
        end
        return nil
    end

    local function getShownWayshrineFromCurrentMap(matchType)
        local mapEntries = self:GetWayshrines(snapshot)

        -- Resolve the destination from ESO's map state itself. isShownInCurrentMap can
        -- be stale/false immediately after SetMapToQuestCondition(), especially when
        -- the quest objective is on an instance/sub-map. The current map zone index is
        -- authoritative and its parent zone gives us the overland destination.
        local mapZoneIndex = 0
        if type(GetCurrentMapZoneIndex) == "function" then
            local ok, value = pcall(GetCurrentMapZoneIndex)
            if ok then mapZoneIndex = safeNumber(value, 0) end
        end

        local mapZoneId, mapParentZoneId = getZoneIdentity(mapZoneIndex)
        local mapCanonicalZoneId = getCanonicalZoneId(mapZoneId)
        if mapCanonicalZoneId <= 0 then mapCanonicalZoneId = getCanonicalZoneId(mapParentZoneId) end

        local exactZone, canonicalZone = nil, nil
        for i = 1, #(mapEntries or {}) do
            local entry = mapEntries[i]
            if entry then
                local entryZoneIndex = safeNumber(entry.zoneIndex, 0)
                local entryZoneId = safeNumber(entry.zoneId, 0)
                if mapZoneIndex > 0 and entryZoneIndex == mapZoneIndex and not exactZone then
                    exactZone = entry
                elseif mapZoneId > 0 and entryZoneId == mapZoneId and not exactZone then
                    exactZone = entry
                end

                if mapCanonicalZoneId > 0 and not canonicalZone then
                    local entryCanonicalZoneId = getCanonicalZoneId(entryZoneId)
                    if entryCanonicalZoneId > 0 and entryCanonicalZoneId == mapCanonicalZoneId then
                        canonicalZone = entry
                    end
                end
            end
        end

        -- Prefer exact destination-zone identity, then its canonical/main overland zone.
        -- Do not fall back to an arbitrary shrine merely because it is shown on a map;
        -- that was the path that could keep a cross-zone quest in the player's current zone.
        if exactZone then return exactZone, matchType end
        if canonicalZone then return canonicalZone, matchType end
        return nil
    end

    -- Quest objectives can live on private instance maps (for example a main-story
    -- interior) whose zone identity has no fast-travel nodes. In that case, walk the
    -- WORLD MAP hierarchy outward. The first parent map that resolves to a discovered
    -- wayshrine is the real overland travel destination. This is intentionally dynamic:
    -- no quest names, cities, alliances, or zone names are hardcoded here.
    local function getWayshrineFromObjectiveParentMaps(matchType)
        local shrine, resolvedType = getShownWayshrineFromCurrentMap(matchType)
        if shrine then return shrine, resolvedType end

        -- Stronger fallback for instance maps: locate the smallest overland map
        -- whose universal rectangle contains the objective and that has a discovered
        -- wayshrine. This avoids relying on a missing/incorrect parent-zone chain.
        shrine, resolvedType = getContainingOverlandWayshrine(matchType)
        if shrine then return shrine, resolvedType end

        if type(MapZoomOut) ~= "function" then return nil end

        local previousMapId = getCurrentMapIdSafe()
        for _ = 1, 8 do
            local ok, result = pcall(MapZoomOut)
            if not mapResultSucceeded(ok, result) then break end
            notifyMapChanged()

            local currentMapId = getCurrentMapIdSafe()
            -- Stop if ESO did not actually move to a parent map.
            if currentMapId > 0 and previousMapId > 0 and currentMapId == previousMapId then break end
            previousMapId = currentMapId

            shrine, resolvedType = getShownWayshrineFromCurrentMap(matchType .. "-parent")
            if shrine then return shrine, resolvedType end

            -- Once we have zoomed all the way to a root/world map there is no useful
            -- zone identity left to match. Avoid ever choosing an arbitrary shrine.
            local zoneIndex = 0
            if type(GetCurrentMapZoneIndex) == "function" then
                local zoneOk, value = pcall(GetCurrentMapZoneIndex)
                if zoneOk then zoneIndex = safeNumber(value, 0) end
            end
            if zoneIndex <= 0 and currentMapId <= 0 then break end
        end
        return nil
    end

    -- If ESO exposes only journal POI metadata (zone + POI) rather than a live
    -- condition pin, use that POI's coordinates on the zone map and rank every
    -- discovered wayshrine by straight-line map distance. This is still much more
    -- accurate than returning the first/main wayshrine in the zone.
    local function getNearestJournalPOIWayshrine(matchType)
        if selectedQuestIndex <= 0
            or type(GetJournalQuestLocationInfo) ~= "function"
            or type(GetPOIMapInfo) ~= "function" then
            return nil
        end

        local locOk, _, _, zoneIndex, poiIndex = pcall(GetJournalQuestLocationInfo, selectedQuestIndex)
        zoneIndex = locOk and safeNumber(zoneIndex, 0) or 0
        poiIndex = locOk and safeNumber(poiIndex, 0) or 0
        if zoneIndex <= 0 or poiIndex <= 0 then return nil end

        local zoneId = 0
        if type(GetZoneId) == "function" then
            local zidOk, zid = pcall(GetZoneId, zoneIndex)
            if zidOk then zoneId = safeNumber(zid, 0) end
        end

        -- Put the world map on the POI's zone so both POI and fast-travel node
        -- coordinates share the same normalized coordinate space.
        if zoneId > 0 and type(GetMapIndexByZoneId) == "function" and type(SetMapToMapListIndex) == "function" then
            local indexOk, mapIndex = pcall(GetMapIndexByZoneId, zoneId)
            mapIndex = indexOk and safeNumber(mapIndex, 0) or 0
            if mapIndex > 0 then
                local setOk, setResult = pcall(SetMapToMapListIndex, mapIndex)
                if mapResultSucceeded(setOk, setResult) then notifyMapChanged() end
            end
        end

        local poiOk, px, py, _, _, shown = pcall(GetPOIMapInfo, zoneIndex, poiIndex)
        px, py = tonumber(px), tonumber(py)
        if not poiOk or px == nil or py == nil or px < 0 or px > 1 or py < 0 or py > 1 then
            return nil
        end
        -- Some valid quest POIs report shown=false until the map UI is open; the
        -- coordinates themselves are sufficient for distance ranking.
        local nearest = self:FindNearestWayshrineOnCurrentMap(px, py)
        if nearest then
            nearest.resolvedQuestZoneId = zoneId
            nearest.questPOIX = px
            nearest.questPOIY = py
            return nearest, matchType
        end
        return nil
    end

    -- IMPORTANT: for accepted quests, resolve the CURRENT OBJECTIVE MAP before any
    -- journal-zone matching. A quest can be journaled under Stormhaven while its next
    -- positional objective is actually in Glenumbra. Broad zone matching first caused
    -- the old code to return a Stormhaven shrine and never reach the real objective.
    if selectedQuestIndex > 0 then
        if type(GetJournalQuestNumSteps) == "function"
            and type(GetJournalQuestNumConditions) == "function"
            and type(GetJournalQuestConditionInfo) == "function"
            and type(DoesJournalQuestConditionHavePosition) == "function"
            and type(SetMapToQuestCondition) == "function" then

            local stepsOk, stepCount = pcall(GetJournalQuestNumSteps, selectedQuestIndex)
            stepCount = stepsOk and safeNumber(stepCount, 0) or 0

            for stepIndex = 1, stepCount do
                local countOk, conditionCount = pcall(GetJournalQuestNumConditions, selectedQuestIndex, stepIndex)
                conditionCount = countOk and safeNumber(conditionCount, 0) or 0
                for conditionIndex = 1, conditionCount do
                    local infoOk, _, _, _, isFailCondition, isComplete, _, isVisible = pcall(
                        GetJournalQuestConditionInfo,
                        selectedQuestIndex,
                        stepIndex,
                        conditionIndex,
                        false
                    )
                    local posOk, hasPosition = pcall(
                        DoesJournalQuestConditionHavePosition,
                        selectedQuestIndex,
                        stepIndex,
                        conditionIndex
                    )

                    if infoOk and posOk and hasPosition == true
                        and isFailCondition ~= true and isComplete ~= true and isVisible ~= false then
                        local setOk, setResult = pcall(SetMapToQuestCondition, selectedQuestIndex, stepIndex, conditionIndex)
                        if mapResultSucceeded(setOk, setResult) then
                            notifyMapChanged()
                            if quest.skipPositionRequest ~= true
                                and self:RequestNearestQuestObjectiveTravel(quest, selectedQuestIndex, stepIndex, conditionIndex) then
                                return nil, "__QUEST_POSITION_PENDING__"
                            end
                            local shrine, matchType = getWayshrineFromObjectiveParentMaps("quest-condition-map")
                            if shrine then return shrine, matchType end
                        end
                    end
                end
            end
        end

        -- Completed non-pledge quests may have a separate hand-in map.
        if type(GetJournalQuestIsComplete) == "function"
            and type(GetJournalQuestNumSteps) == "function"
            and type(SetMapToQuestStepEnding) == "function" then
            local completeOk, isComplete = pcall(GetJournalQuestIsComplete, selectedQuestIndex)
            if completeOk and isComplete == true then
                local stepsOk, stepCount = pcall(GetJournalQuestNumSteps, selectedQuestIndex)
                stepCount = stepsOk and safeNumber(stepCount, 0) or 0
                for stepIndex = stepCount, 1, -1 do
                    local setOk, setResult = pcall(SetMapToQuestStepEnding, selectedQuestIndex, stepIndex)
                    if mapResultSucceeded(setOk, setResult) then
                        notifyMapChanged()
                        local shrine, matchType = getWayshrineFromObjectiveParentMaps("quest-ending-map")
                        if shrine then return shrine, matchType end
                    end
                end
            end
        end

        -- If no condition/ending pin produced a directly comparable position, try
        -- the journal POI coordinates before any zone-only fallback.
        local poiShrine, poiMatchType = getNearestJournalPOIWayshrine("journal-poi-distance")
        if poiShrine then return poiShrine, poiMatchType end

        -- If positional map APIs leave us inside a private instance, use journal-level
        -- overland metadata before the generic quest record. For Main Story quests this
        -- can resolve the alliance-side overland zone even when GetQuestZoneId() names
        -- the mission instance itself. This remains dynamic for every active quest.
        local journalFallbackZoneId, journalFallbackZoneName, journalFallbackSource =
            self:GetJournalQuestOverlandFallbackZone(selectedQuestIndex)
        if journalFallbackZoneId > 0 or journalFallbackZoneName ~= "" then
            local shrine, matchType = nil, nil
            if journalFallbackZoneId > 0 then
                shrine, matchType = findShrineByCanonicalZone(
                    journalFallbackZoneId, "journal-" .. tostring(journalFallbackSource or "overland-zone")
                )
            end
            if not shrine and journalFallbackZoneName ~= "" then
                shrine, matchType = findShrineByZoneName(
                    journalFallbackZoneName, "journal-zone-name-" .. tostring(journalFallbackSource or "overland-zone")
                )
            end
            if shrine then
                shrine.resolvedQuestZoneId = journalFallbackZoneId
                shrine.resolvedQuestZoneName = journalFallbackZoneName
                return shrine, matchType
            end
        end

        -- Only then use ESO's generic quest record zone. It may identify an interior
        -- instance, so it is deliberately lower priority than journal overland data.
        if questRecordZoneId > 0 then
            local shrine, matchType = findShrineByCanonicalZone(questRecordZoneId, "quest-record-zone")
            if shrine then return shrine, matchType end
        end

        -- Only after objective/ending/quest-record resolution fails do we use ESO's broad quest-zone map.
        if type(SetMapToQuestZone) == "function" then
            local setOk, setResult = pcall(SetMapToQuestZone, selectedQuestIndex)
            if mapResultSucceeded(setOk, setResult) then
                notifyMapChanged()
                local shrine, matchType = getWayshrineFromObjectiveParentMaps("quest-map-zone")
                if shrine then return shrine, matchType end
            end
        end
    end

    -- Last-resort metadata match. This is useful for unaccepted quests and accepted
    -- quests whose conditions do not expose a position, but it is intentionally AFTER
    -- the active objective-map path above so it cannot trap cross-zone quests.
    local targetZoneId = questRecordZoneId > 0 and questRecordZoneId or safeNumber(quest.zoneId, 0)
    local targetZoneIndex = safeNumber(quest.zoneIndex, 0)
    local targetZoneName = questRecordZoneName ~= "" and lower(questRecordZoneName) or lower(quest.zone or quest.zoneName or "")

    if selectedQuestIndex > 0 and targetZoneId <= 0 and type(GetJournalQuestLocationInfo) == "function" then
        local ok, journalZoneName, _, journalZoneIndex = pcall(GetJournalQuestLocationInfo, selectedQuestIndex)
        if ok then
            if targetZoneName == "" or targetZoneName == "accepted quest" then
                targetZoneName = lower(journalZoneName or "")
            end
            journalZoneIndex = safeNumber(journalZoneIndex, 0)
            if targetZoneIndex <= 0 and journalZoneIndex > 0 then targetZoneIndex = journalZoneIndex end
            if targetZoneId <= 0 and journalZoneIndex > 0 and type(GetZoneId) == "function" then
                local idOk, journalZoneId = pcall(GetZoneId, journalZoneIndex)
                if idOk then targetZoneId = safeNumber(journalZoneId, 0) end
            end
        end
    end

    local targetCanonicalZoneId = getCanonicalZoneId(targetZoneId)
    local targetCanonicalZoneName = ""
    if targetCanonicalZoneId > 0 and type(GetZoneNameById) == "function" then
        local nameOk, canonicalName = pcall(GetZoneNameById, targetCanonicalZoneId)
        if nameOk then targetCanonicalZoneName = lower(canonicalName or "") end
    end

    local nameFallback, canonicalFallback, canonicalNameFallback = nil, nil, nil
    for i = 1, #(entries or {}) do
        local entry = entries[i]
        local entryZoneId = safeNumber(entry.zoneId, 0)
        local entryZoneIndex = safeNumber(entry.zoneIndex, 0)
        local entryZoneName = lower(entry.zoneName or "")

        if targetZoneIndex > 0 and entryZoneIndex == targetZoneIndex then return entry, "zone" end
        if targetZoneId > 0 and entryZoneId == targetZoneId then return entry, "zone" end
        if not nameFallback and targetZoneName ~= "" and entryZoneName == targetZoneName then nameFallback = entry end

        local entryCanonicalZoneId = getCanonicalZoneId(entryZoneId)
        if not canonicalFallback and targetCanonicalZoneId > 0
            and entryCanonicalZoneId > 0 and entryCanonicalZoneId == targetCanonicalZoneId then
            canonicalFallback = entry
        end

        if not canonicalNameFallback and targetCanonicalZoneName ~= ""
            and entryCanonicalZoneId > 0 and type(GetZoneNameById) == "function" then
            local okName, entryMainName = pcall(GetZoneNameById, entryCanonicalZoneId)
            if okName and lower(entryMainName or "") == targetCanonicalZoneName then
                canonicalNameFallback = entry
            end
        end
    end

    if nameFallback then return nameFallback, "zone" end
    if canonicalFallback then return canonicalFallback, "zone" end
    if canonicalNameFallback then return canonicalNameFallback, "zone" end

    return nil, string.format(
        "No discovered wayshrine could be resolved for the current objective of %s.",
        clean(quest.name or quest.zone or quest.zoneName, "that quest")
    )
end

function T:TravelToNearestQuestStarterWayshrine(quest)
    local entry, matchTypeOrReason = self:GetNearestWayshrineForQuestSelection(quest)
    if not entry then
        if matchTypeOrReason == "__QUEST_POSITION_PENDING__" then
            EPC:Print("Locating the closest discovered wayshrine to the current quest objective...")
            return true
        end
        EPC:Print(matchTypeOrReason or "No discovered wayshrine was found for that quest.")
        return false
    end

    if matchTypeOrReason == "pledge-turnin" then
        local enclave = entry.pledgeEnclave or self:GetUndauntedEnclaveForPlayer()
        EPC:Print(string.format(
            "Undaunted pledge turn-in: routing to your alliance enclave in %s, %s via %s.",
            enclave and enclave.city or "your alliance city",
            enclave and enclave.zone or "the alliance zone",
            entry.name
        ))
    elseif matchTypeOrReason == "objective" then
        EPC:Print(string.format("Nearest discovered wayshrine to the active quest objective: %s.", entry.name))
    elseif matchTypeOrReason == "quest-map-objective" then
        EPC:Print(string.format("Quest destination resolved from ESO's quest map; traveling to the nearest discovered wayshrine: %s.", entry.name))
    elseif matchTypeOrReason == "quest-condition-map" then
        EPC:Print(string.format("Quest objective resolved from ESO's active condition map; traveling to a discovered wayshrine in that destination zone: %s.", entry.name))
    elseif matchTypeOrReason == "quest-ending-map" then
        EPC:Print(string.format("Quest hand-in destination resolved from ESO's ending map; traveling to a discovered wayshrine in that destination zone: %s.", entry.name))
    elseif string.find(tostring(matchTypeOrReason or ""), "overland%-container") then
        EPC:Print(string.format("Quest objective resolved to the containing overland zone%s; traveling via %s.",
            entry.resolvedQuestZoneName and (" (" .. entry.resolvedQuestZoneName .. ")") or "", entry.name))
    elseif matchTypeOrReason == "quest-map-zone" then
        EPC:Print(string.format("Quest destination resolved from ESO's quest map; traveling to a discovered wayshrine in that zone: %s.", entry.name))
    elseif matchTypeOrReason == "map-fallback" then
        EPC:Print(string.format("Using a discovered wayshrine on the selected quest's zone map: %s.", entry.name))
    else
        EPC:Print(string.format(
            "Traveling toward %s via %s. ESO does not expose exact coordinates for unaccepted quest starters, so this route uses the quest zone.",
            clean(quest and quest.name, "the selected quest"),
            entry.name
        ))
    end

    return self:TravelToWayshrineNode(entry.nodeIndex, entry.name)
end

function T:GetWayshrines(snapshot)
    local entries = {}
    local currentZone = lower(snapshot and snapshot.zoneName or "")
    local focusedQuest = self:GetFocusedQuest(snapshot)
    local canLeave, leaveReason = self:CanLeaveNow()
    local total = 0

    if type(GetNumFastTravelNodes) == "function" then
        local ok, count = pcall(GetNumFastTravelNodes)
        if ok then total = safeNumber(count, 0) end
    end

    local poiIndexFunction = GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices

    for nodeIndex = 1, total do
        local ok, known, name, normalizedX, normalizedY, _, _, poiType, isShownInCurrentMap, linkedCollectibleIsLocked = pcall(
            GetFastTravelNodeInfo,
            nodeIndex
        )
        local isWayshrine = POI_TYPE_WAYSHRINE == nil or poiType == POI_TYPE_WAYSHRINE

        if ok and known and isWayshrine and not linkedCollectibleIsLocked then
            local isOutboundOnly = false
            if type(GetFastTravelNodeOutboundOnlyInfo) == "function" then
                local outboundOk, outbound = pcall(GetFastTravelNodeOutboundOnlyInfo, nodeIndex)
                if outboundOk then isOutboundOnly = outbound == true end
            end

            if not isOutboundOnly then
                local zoneIndex = 0
                if type(poiIndexFunction) == "function" then
                    local indicesOk, returnedZoneIndex = pcall(poiIndexFunction, nodeIndex)
                    if indicesOk then zoneIndex = safeNumber(returnedZoneIndex, 0) end
                end

                local zoneName = "Unknown zone"
                if zoneIndex > 0 and type(GetZoneNameByIndex) == "function" then
                    local zoneOk, returnedZoneName = pcall(GetZoneNameByIndex, zoneIndex)
                    if zoneOk then zoneName = clean(returnedZoneName, zoneName) end
                end

                local zoneId, parentZoneId = getZoneIdentity(zoneIndex)
                local cost, currency = self:GetLiveWayshrineTravelCost(nodeIndex)

                local canAfford = true
                if cost > 0 and type(GetCurrencyAmount) == "function" and CURRENCY_LOCATION_CHARACTER ~= nil then
                    local amountOk, amount = pcall(GetCurrencyAmount, currency, CURRENCY_LOCATION_CHARACTER)
                    if amountOk then canAfford = safeNumber(amount, 0) >= cost end
                end

                local costText
                if cost <= 0 then
                    costText = "Free"
                elseif currency == CURT_MONEY or currency == nil then
                    costText = formatNumber(cost) .. " gold"
                else
                    costText = "Cost " .. formatNumber(cost)
                end

                local statusText = leaveReason
                if canLeave and not canAfford then statusText = "Not enough currency" end

                local shrineName = clean(name, "Unnamed wayshrine")
                local entry = {
                    kind = "SHRINE",
                    key = "S:" .. tostring(nodeIndex),
                    nodeIndex = nodeIndex,
                    name = shrineName,
                    zoneName = zoneName,
                    zoneIndex = zoneIndex,
                    zoneId = zoneId,
                    parentZoneId = parentZoneId,
                    normalizedX = tonumber(normalizedX),
                    normalizedY = tonumber(normalizedY),
                    isShownInCurrentMap = isShownInCurrentMap == true,
                    displayText = shrineName .. " - " .. zoneName,
                    costText = costText,
                    statusText = statusText,
                    canTravel = canLeave and canAfford,
                    isCurrentZone = currentZone ~= "" and lower(zoneName) == currentZone,
                }

                entry.isQuestZone = zonesMatch(entry, focusedQuest)

                local questPosition = focusedQuest and focusedQuest.position or nil
                if questPosition and safeNumber(questPosition.bestNodeIndex, 0) == nodeIndex then
                    -- Full-zone objective resolver already compared every discovered
                    -- wayshrine after walking out of the sub-map hierarchy.
                    entry.questDistance = tonumber(questPosition.bestDistance) or 0
                    entry.isQuestZone = true
                elseif entry.isQuestZone
                    and questPosition and questPosition.available == true
                    and entry.isShownInCurrentMap
                    and entry.normalizedX ~= nil and entry.normalizedY ~= nil then
                    -- Compatibility path while an async full-zone result is pending.
                    local deltaX = entry.normalizedX - questPosition.x
                    local deltaY = entry.normalizedY - questPosition.y
                    entry.questDistance = (deltaX * deltaX) + (deltaY * deltaY)
                end

                entries[#entries + 1] = entry
            end
        end
    end

    if focusedQuest then
        table.sort(entries, questAwareWayshrineSort)
    else
        table.sort(entries, currentZoneFirstSort)
    end

    local bestQuestShrine = nil
    if focusedQuest then
        for i = 1, #entries do
            local entry = entries[i]
            if entry.questDistance ~= nil or entry.isQuestZone then
                bestQuestShrine = entry
                break
            end
        end
    end

    if bestQuestShrine then
        bestQuestShrine.isQuestBest = true
        bestQuestShrine.displayText = "QUEST BEST - " .. bestQuestShrine.name .. " - " .. bestQuestShrine.zoneName
    end

    return entries, focusedQuest, bestQuestShrine
end

function T:GetFriends(snapshot)
    local entries = {}
    local currentZone = lower(snapshot and snapshot.zoneName or "")
    local ownDisplayName = clean(type(GetDisplayName) == "function" and GetDisplayName() or "", "")
    local canLeave, leaveReason = self:CanLeaveNow()
    local count = 0

    if type(GetNumFriends) == "function" then
        local ok, returnedCount = pcall(GetNumFriends)
        if ok then count = safeNumber(returnedCount, 0) end
    end

    for friendIndex = 1, count do
        local infoOk, displayName, _, playerStatus, secsSinceLogoff = pcall(GetFriendInfo, friendIndex)
        displayName = clean(displayName, "")

        if infoOk and displayName ~= "" and displayName ~= ownDisplayName and isOnlineStatus(playerStatus, secsSinceLogoff) then
            local characterOk, hasCharacter, characterName, zoneName, _, _, _, _, zoneId = pcall(GetFriendCharacterInfo, friendIndex)
            if characterOk and hasCharacter then
                zoneName = clean(zoneName, "Unknown location")
                characterName = clean(characterName, displayName)
                local canJump, result = getJumpAvailability(zoneId)
                local ready = canLeave and canJump
                local statusText = not canLeave and leaveReason or (canJump and "Ready" or jumpResultText(result))

                entries[#entries + 1] = {
                    kind = "FRIEND",
                    key = "F:" .. lower(displayName),
                    name = displayName,
                    displayName = displayName,
                    characterName = characterName,
                    zoneName = zoneName,
                    zoneId = zoneId,
                    displayText = displayName .. " - " .. zoneName,
                    costText = "Free",
                    statusText = statusText,
                    canTravel = ready,
                    isCurrentZone = currentZone ~= "" and lower(zoneName) == currentZone,
                }
            end
        end
    end

    table.sort(entries, currentZoneFirstSort)
    return entries
end


-- Guild leader primary-home travel -------------------------------------------------
-- ESO exposes guild leaders through GetGuildInfo()/guild ranks and allows visiting
-- another player's primary residence with JumpToHouse(displayName). The game owns
-- house permissions/access checks; the Suite only issues the requested jump.
function T:GetGuildLeaderHomeOptions()
    local rows = {}
    local guildCount = 0
    if type(GetNumGuilds) == "function" then
        local ok, n = pcall(GetNumGuilds)
        if ok then guildCount = safeNumber(n, 0) end
    end

    for guildIndex = 1, guildCount do
        local guildId = nil
        if type(GetGuildId) == "function" then
            local ok, id = pcall(GetGuildId, guildIndex)
            if ok then guildId = id end
        end
        if guildId then
            local guildName = "Guild " .. tostring(guildIndex)
            if type(GetGuildName) == "function" then
                local ok, name = pcall(GetGuildName, guildId)
                if ok then guildName = clean(name, guildName) end
            end

            local leaderName = ""
            if type(GetGuildInfo) == "function" then
                local ok, _, _, returnedLeader = pcall(GetGuildInfo, guildId)
                if ok then leaderName = clean(returnedLeader, "") end
            end

            -- Fallback for clients/API revisions where GetGuildInfo does not provide
            -- a usable leader display name: find the roster member with guild-master rank.
            if leaderName == "" and type(GetNumGuildMembers) == "function"
                and type(GetGuildMemberInfo) == "function" then
                local okCount, count = pcall(GetNumGuildMembers, guildId)
                count = okCount and safeNumber(count, 0) or 0
                for memberIndex = 1, count do
                    local okInfo, displayName, _, rankIndex = pcall(GetGuildMemberInfo, guildId, memberIndex)
                    if okInfo and displayName and displayName ~= "" then
                        local isMaster = false
                        if type(IsGuildRankGuildMaster) == "function" and rankIndex ~= nil then
                            local okMaster, result = pcall(IsGuildRankGuildMaster, guildId, rankIndex)
                            isMaster = okMaster and result == true
                        end
                        if isMaster then
                            leaderName = clean(displayName, "")
                            break
                        end
                    end
                end
            end

            rows[#rows + 1] = {
                guildId = guildId,
                guildName = guildName,
                leaderName = leaderName,
                label = leaderName ~= "" and (guildName .. " - " .. leaderName) or (guildName .. " - Leader unavailable"),
            }
        end
    end

    table.sort(rows, function(a,b) return lower(a.guildName or "") < lower(b.guildName or "") end)
    return rows
end

function T:GetSelectedGuildLeaderHome()
    local options = self:GetGuildLeaderHomeOptions()
    if #options == 0 then
        self.selectedGuildLeaderGuildId = nil
        return nil, options
    end

    local wanted = tonumber(self.selectedGuildLeaderGuildId)
    if wanted then
        for _, row in ipairs(options) do
            if tonumber(row.guildId) == wanted then return row, options end
        end
    end

    self.selectedGuildLeaderGuildId = options[1].guildId
    return options[1], options
end

function T:SelectGuildLeaderGuild(guildId)
    self.selectedGuildLeaderGuildId = tonumber(guildId) or guildId
    if EPC.RefreshNow then EPC:RefreshNow("guild-leader-home-selection") end
end

function T:TravelToSelectedGuildLeaderHome()
    local selected = self:GetSelectedGuildLeaderHome()
    if not selected then
        EPC:Print("You are not currently in a guild.")
        return
    end
    if clean(selected.leaderName, "") == "" then
        EPC:Print("ESO did not expose the leader for " .. tostring(selected.guildName or "that guild") .. ".")
        return
    end

    local canLeave, reason = self:CanLeaveNow()
    if not canLeave then
        EPC:Print(tostring(reason or "Travel is currently unavailable") .. ".")
        return
    end

    local leader = clean(selected.leaderName, "")
    local own = clean(type(GetDisplayName) == "function" and GetDisplayName() or "", "")

    if leader == own then
        if type(GetHousingPrimaryHouse) == "function" and type(RequestJumpToHouse) == "function" then
            local okHouse, houseId = pcall(GetHousingPrimaryHouse)
            houseId = okHouse and safeNumber(houseId, 0) or 0
            if houseId > 0 then
                EPC:Print("Traveling to your primary residence for " .. tostring(selected.guildName or "guild") .. ".")
                local ok = pcall(RequestJumpToHouse, houseId, false)
                if not ok then EPC:Print("ESO rejected the house travel request.") end
                return
            end
        end
        EPC:Print("You are the guild leader, but ESO did not expose a primary residence to travel to.")
        return
    end

    if type(JumpToHouse) ~= "function" then
        EPC:Print("Guild leader home travel API is unavailable.")
        return
    end

    EPC:Print("Traveling to " .. leader .. "'s primary residence (" .. tostring(selected.guildName or "guild") .. ").")
    local ok = pcall(JumpToHouse, leader)
    if not ok then
        EPC:Print("ESO rejected the house travel request. The leader may not have an accessible primary residence.")
    end
end

local GetGuildMembersImplArch

function T:GetGuildMembers(...)

    return GetGuildMembersImplArch(self, ...)

end

GetGuildMembersImplArch = function(self, snapshot)
    local entries = {}
    local seen = {}
    local currentZone = lower(snapshot and snapshot.zoneName or "")
    local ownDisplayName = clean(type(GetDisplayName) == "function" and GetDisplayName() or "", "")
    local canLeave, leaveReason = self:CanLeaveNow()
    local guildCount = 0

    if type(GetNumGuilds) == "function" then
        local ok, returnedCount = pcall(GetNumGuilds)
        if ok then guildCount = safeNumber(returnedCount, 0) end
    end

    for guildIndex = 1, guildCount do
        local guildId = nil
        local guildOk, returnedGuildId = pcall(GetGuildId, guildIndex)
        if guildOk then guildId = returnedGuildId end

        if guildId then
            local guildName = "Guild"
            if type(GetGuildName) == "function" then
                local nameOk, returnedGuildName = pcall(GetGuildName, guildId)
                if nameOk then guildName = clean(returnedGuildName, guildName) end
            end

            local memberCount = 0
            local countOk, returnedMemberCount = pcall(GetNumGuildMembers, guildId)
            if countOk then memberCount = safeNumber(returnedMemberCount, 0) end

            for memberIndex = 1, memberCount do
                local infoOk, displayName, _, _, playerStatus, secsSinceLogoff = pcall(GetGuildMemberInfo, guildId, memberIndex)
                displayName = clean(displayName, "")
                local dedupeKey = lower(displayName)

                if infoOk and displayName ~= "" and displayName ~= ownDisplayName and not seen[dedupeKey] and isOnlineStatus(playerStatus, secsSinceLogoff) then
                    local characterOk, hasCharacter, characterName, zoneName, _, _, _, _, zoneId = pcall(GetGuildMemberCharacterInfo, guildId, memberIndex)
                    if characterOk and hasCharacter then
                        seen[dedupeKey] = true
                        zoneName = clean(zoneName, "Unknown location")
                        characterName = clean(characterName, displayName)
                        local canJump, result = getJumpAvailability(zoneId)
                        local ready = canLeave and canJump
                        local statusText = not canLeave and leaveReason or (canJump and "Ready" or jumpResultText(result))

                        entries[#entries + 1] = {
                            kind = "GUILD",
                            key = "G:" .. dedupeKey,
                            name = displayName,
                            displayName = displayName,
                            characterName = characterName,
                            guildName = guildName,
                            zoneName = zoneName,
                            zoneId = zoneId,
                            displayText = displayName .. " - " .. zoneName,
                            costText = "Free",
                            statusText = statusText,
                            canTravel = ready,
                            isCurrentZone = currentZone ~= "" and lower(zoneName) == currentZone,
                        }
                    end
                end
            end
        end
    end

    table.sort(entries, currentZoneFirstSort)
    return entries
end

function T:GetGroupMembers(snapshot)
    local entries = {}
    local currentZone = lower(snapshot and snapshot.zoneName or "")
    local canLeave, leaveReason = self:CanLeaveNow()
    local groupSize = 0

    if type(GetGroupSize) == "function" then
        local ok, returnedSize = pcall(GetGroupSize)
        if ok then groupSize = safeNumber(returnedSize, 0) end
    end

    for sortIndex = 1, groupSize do
        local tagOk, unitTag = pcall(GetGroupUnitTagByIndex, sortIndex)
        local isSelf = false
        if tagOk and unitTag and type(AreUnitsEqual) == "function" then
            local equalOk, equal = pcall(AreUnitsEqual, unitTag, "player")
            if equalOk then isSelf = equal == true end
        end

        if tagOk and unitTag and unitTag ~= "" and not isSelf then
            local online = true
            if type(IsUnitOnline) == "function" then
                local onlineOk, returnedOnline = pcall(IsUnitOnline, unitTag)
                if onlineOk then online = returnedOnline == true end
            end

            if online then
                local displayName = ""
                if type(GetUnitDisplayName) == "function" then
                    local displayOk, returnedDisplayName = pcall(GetUnitDisplayName, unitTag)
                    if displayOk then displayName = clean(returnedDisplayName, "") end
                end

                local characterName = displayName
                if type(GetUnitName) == "function" then
                    local characterOk, returnedCharacterName = pcall(GetUnitName, unitTag)
                    if characterOk then characterName = clean(returnedCharacterName, displayName) end
                end

                local zoneName = "Unknown location"
                if type(GetUnitZone) == "function" then
                    local zoneOk, returnedZoneName = pcall(GetUnitZone, unitTag)
                    if zoneOk then zoneName = clean(returnedZoneName, zoneName) end
                end

                local canJump, result = true, nil
                if type(CanJumpToGroupMember) == "function" then
                    local jumpOk, returnedCanJump, returnedResult = pcall(CanJumpToGroupMember, unitTag)
                    if jumpOk then canJump, result = returnedCanJump == true, returnedResult end
                end

                local ready = canLeave and canJump
                local statusText = not canLeave and leaveReason or (canJump and "Ready" or jumpResultText(result))
                local name = displayName ~= "" and displayName or characterName

                entries[#entries + 1] = {
                    kind = "GROUP",
                    key = "P:" .. lower(name) .. ":" .. tostring(sortIndex),
                    name = name,
                    displayName = displayName,
                    characterName = characterName,
                    unitTag = unitTag,
                    zoneName = zoneName,
                    displayText = name .. " - " .. zoneName,
                    costText = "Free",
                    statusText = statusText,
                    canTravel = ready,
                    isCurrentZone = currentZone ~= "" and lower(zoneName) == currentZone,
                }
            end
        end
    end

    table.sort(entries, currentZoneFirstSort)
    return entries
end

function T:GetEntries(mode, snapshot)
    if mode == "FRIENDS" then
        return self:GetFriends(snapshot), nil, nil
    elseif mode == "GUILD" then
        return self:GetGuildMembers(snapshot), nil, nil
    elseif mode == "GROUP" then
        return self:GetGroupMembers(snapshot), nil, nil
    end
    return self:GetWayshrines(snapshot)
end

-- v0.27.41: Build a hierarchical zone -> wayshrine list for the SHRINES view.
-- Zone headers are expandable and keep the Travel page readable even with many
-- discovered wayshrines.
function T:BuildZoneGroupedWayshrines(entries, snapshot, focusedQuest)
    self.expandedTravelZones = self.expandedTravelZones or {}
    local groups = {}
    local order = {}
    local currentZone = lower(snapshot and snapshot.zoneName or "")
    local questZone = lower(focusedQuest and focusedQuest.zoneName or "")

    for i = 1, #(entries or {}) do
        local entry = entries[i]
        local zoneName = clean(entry and entry.zoneName, "Unknown zone")
        local zoneKey = lower(zoneName)
        if zoneKey == "" then zoneKey = "unknown zone" end
        if not groups[zoneKey] then
            groups[zoneKey] = {name=zoneName, key=zoneKey, rows={}, hasQuestBest=false, isCurrentZone=false, isQuestZone=false}
            order[#order+1] = zoneKey
        end
        local g = groups[zoneKey]
        g.rows[#g.rows+1] = entry
        if entry.isQuestBest then g.hasQuestBest = true end
        if entry.isCurrentZone or zoneKey == currentZone then g.isCurrentZone = true end
        if entry.isQuestZone or (questZone ~= "" and zoneKey == questZone) then g.isQuestZone = true end
    end

    table.sort(order, function(a, b)
        local ga, gb = groups[a], groups[b]
        local pa = ga.hasQuestBest and 0 or (ga.isQuestZone and 1 or (ga.isCurrentZone and 2 or 3))
        local pb = gb.hasQuestBest and 0 or (gb.isQuestZone and 1 or (gb.isCurrentZone and 2 or 3))
        if pa ~= pb then return pa < pb end
        return lower(ga.name) < lower(gb.name)
    end)

    local display = {}
    for _,zoneKey in ipairs(order) do
        local g = groups[zoneKey]
        if self.expandedTravelZones[zoneKey] == nil then
            self.expandedTravelZones[zoneKey] = g.isCurrentZone or g.isQuestZone or g.hasQuestBest
        end
        local expanded = self.expandedTravelZones[zoneKey] == true
        display[#display+1] = {
            kind = "ZONE_HEADER",
            key = "Z:" .. zoneKey,
            zoneKey = zoneKey,
            name = g.name,
            zoneName = g.name,
            shrineCount = #g.rows,
            expanded = expanded,
            isCurrentZone = g.isCurrentZone,
            isQuestZone = g.isQuestZone,
            hasQuestBest = g.hasQuestBest,
            canTravel = false,
        }
        if expanded then
            for i=1,#g.rows do display[#display+1] = g.rows[i] end
        end
    end
    return display
end

function T:ToggleTravelZone(zoneKey)
    zoneKey = lower(zoneKey or "")
    if zoneKey == "" then return end
    self.expandedTravelZones = self.expandedTravelZones or {}
    self.expandedTravelZones[zoneKey] = not (self.expandedTravelZones[zoneKey] == true)
    EPC.saved.travelBookPage = 1
    EPC.saved.travelPage = 1
    if EPC.RefreshNow then EPC:RefreshNow("travel-zone-toggle") end
end

function T:BuildView(snapshot, pageSize)
    pageSize = self:GetPageSize(pageSize)
    local pageKey = self:GetPageKey(pageSize)
    local mode = self:GetMode()
    local entries, focusedQuest, bestQuestShrine = self:GetEntries(mode, snapshot)
    local displayEntries = entries
    if mode == "SHRINES" then
        displayEntries = self:BuildZoneGroupedWayshrines(entries, snapshot, focusedQuest)
    end

    local focusedQuestKey = focusedQuest and focusedQuest.identityKey or ""
    if mode == "SHRINES" and focusedQuestKey ~= (self.lastFocusedQuestKey or "") then
        EPC.saved.travelPage = 1
        EPC.saved.travelBookPage = 1
        self.selectedKey = nil
        self.lastFocusedQuestKey = focusedQuestKey
    elseif mode ~= "SHRINES" then
        self.lastFocusedQuestKey = focusedQuestKey
    end

    local pageCount = math.max(1, math.ceil(#displayEntries / pageSize))
    local page = EPC:Clamp(EPC.saved[pageKey] or 1, 1, pageCount)
    EPC.saved[pageKey] = page

    local selected = nil
    if self.selectedKey then
        for i = 1, #entries do
            if entries[i].key == self.selectedKey then
                selected = entries[i]
                break
            end
        end
    end
    if self.selectedKey and not selected then self.selectedKey = nil end

    local firstIndex = ((page - 1) * pageSize) + 1
    local rows = {}
    for i = 0, pageSize - 1 do
        local entry = displayEntries[firstIndex + i]
        if entry then rows[#rows + 1] = entry end
    end

    local emptyText
    local hint
    local header = "MAP AND TRAVEL"
    local title = "Travel from " .. clean(snapshot and snapshot.zoneName, "Unknown zone")
    local discoveryTarget = EPC.saved and EPC.saved.questDiscoveryTarget or nil
    local description = "Choose a destination, select it, then press TRAVEL. Travel never starts automatically."

    if mode == "SHRINES" then
        emptyText = "No discovered wayshrines are available."

        if focusedQuest then
            header = "QUEST-AWARE TRAVEL"
            title = "Focused quest: " .. focusedQuest.name

            if bestQuestShrine and bestQuestShrine.questDistance ~= nil then
                description = string.format(
                    "%s is the nearest discovered wayshrine to the current objective by straight-line map distance. Terrain and entrances may make another route faster.",
                    bestQuestShrine.name
                )
                hint = "QUEST BEST is listed first. Select it, then press TRAVEL."
            elseif bestQuestShrine then
                description = string.format(
                    "%s is prioritized because it is in %s. ESO did not expose comparable objective coordinates, so this is zone-first rather than exact-distance ranking.",
                    bestQuestShrine.name,
                    focusedQuest.zoneName
                )
                hint = "QUEST BEST is the first discovered wayshrine in the focused quest's zone."
            else
                description = string.format(
                    "No discovered wayshrine was found in %s. Try FRIENDS, GUILD, or GROUP to reach someone already in that zone.",
                    focusedQuest.zoneName
                )
                hint = "Direct wayshrine travel requires a discovered node. Social travel may still reach the quest zone."
            end
        else
            hint = "Focus a quest to rank its nearest available wayshrine, or select any discovered destination below."
        end
    elseif mode == "FRIENDS" then
        emptyText = "No online friends were found."
        hint = "Travel to Player goes to the nearest wayshrine and may reach zones you have not visited. ESO access rules still apply."
    elseif mode == "GUILD" then
        emptyText = "No online guild members were found."
        hint = "Guild travel goes to the member's nearest wayshrine and may reach undiscovered zones. ESO access rules still apply."
    else
        emptyText = "No online group members were found."
        hint = "Group travel uses ESO's Travel to Player system and normally arrives at the nearest wayshrine. Access rules still apply."
    end

    local selectedDetails = nil
    local selectedDisplay = "Choose below"
    if selected then
        local selectedZone = clean(selected.zoneName, "Unknown zone")
        local selectedName = clean(selected.name, "Unknown destination")
        selectedDisplay = selectedZone .. "\n" .. selectedName
        selectedDetails = string.format("Selected: %s - %s. %s; %s.", selectedZone, selectedName, selected.costText, selected.statusText)
    end

    local stats
    if mode == "SHRINES" and focusedQuest then
        stats = {
            { label = "FOCUSED QUEST", value = focusedQuest.name },
            { label = "BEST SHRINE", value = bestQuestShrine and bestQuestShrine.name or "None discovered" },
            { label = "SELECTED", value = selectedDisplay },
            { label = "STATUS", value = selected and (selected.costText .. " - " .. selected.statusText) or "Quest route ready" },
        }
    else
        stats = {
            { label = "TRAVEL MODE", value = self.modeLabels[mode] },
            { label = "AVAILABLE", value = tostring(#entries) },
            { label = "SELECTED", value = selectedDisplay },
            { label = "STATUS", value = selected and (selected.costText .. " - " .. selected.statusText) or "Select a destination" },
        }
    end

    local view = {
        mode = mode,
        modeLabel = self.modeLabels[mode],
        header = header,
        title = title,
        description = description,
        entries = entries,
        rows = rows,
        selected = selected,
        focusedQuest = focusedQuest,
        bestQuestShrine = bestQuestShrine,
        page = page,
        pageCount = pageCount,
        pageSize = pageSize,
        canPageBack = page > 1,
        canPageForward = page < pageCount,
        actionEnabled = selected ~= nil and selected.canTravel == true,
        actionText = "TRAVEL",
        emptyText = emptyText,
        hint = selectedDetails or hint,
        stats = stats,
    }

    self.lastView = view
    return view
end

function T:TravelSelected()
    local snapshot = EPC.lastSnapshot or (EPC.Engine and EPC.Engine:BuildSnapshot())
    local view = self:BuildView(snapshot)
    local entry = view.selected

    if not entry then
        EPC:Print("Select a destination first.")
        return
    end

    local canLeave, leaveReason = self:CanLeaveNow()
    if not canLeave then
        EPC:Print(leaveReason .. ".")
        return
    end

    if not entry.canTravel then
        EPC:Print(entry.statusText or "ESO currently blocks this destination.")
        return
    end

    local travelFunction
    local travelArgument
    local unavailableMessage

    if entry.kind == "SHRINE" then
        travelFunction = FastTravelToNode
        travelArgument = entry.nodeIndex
        unavailableMessage = "Fast-travel API is unavailable."
    elseif entry.kind == "FRIEND" then
        travelFunction = JumpToFriend
        travelArgument = entry.displayName
        unavailableMessage = "Friend travel API is unavailable."
    elseif entry.kind == "GUILD" then
        travelFunction = JumpToGuildMember
        travelArgument = entry.displayName
        unavailableMessage = "Guild travel API is unavailable."
    elseif entry.kind == "GROUP" then
        travelFunction = JumpToGroupMember
        travelArgument = entry.displayName ~= "" and entry.displayName or entry.characterName
        unavailableMessage = "Group travel API is unavailable."
    end

    if type(travelFunction) ~= "function" then
        EPC:Print(unavailableMessage or "Travel API is unavailable.")
        return
    end

    EPC:Print("Traveling to " .. entry.name .. ".")
    local ok = pcall(travelFunction, travelArgument)
    if not ok then
        EPC:Print("ESO rejected the travel request. Try the normal map or Social menu.")
    end
end

-- ==========================================================================
-- v0.27.64 - Direct Undaunted Pledge Master travel
-- Uses the same alliance-aware enclave lookup as pledge turn-in routing.
-- ==========================================================================
function T:TravelToPledgeMaster()
    local snapshot = EPC.lastSnapshot or {}
    local entries = self:GetWayshrines(snapshot)
    local shrine, enclave = self:GetAlliancePledgeTurnInWayshrine(entries)

    if not enclave then
        EPC:Print("Could not determine your alliance Undaunted Enclave.")
        return false
    end

    if not shrine then
        EPC:Print(string.format(
            "No discovered wayshrine was found for the Undaunted Pledge Masters in %s, %s.",
            tostring(enclave.city or "your alliance enclave"),
            tostring(enclave.zone or "")
        ))
        return false
    end

    EPC:Print(string.format(
        "Pledge Masters: traveling to %s, %s via %s.",
        tostring(enclave.city or "Undaunted Enclave"),
        tostring(enclave.zone or ""),
        tostring(shrine.name or enclave.wayshrine or "wayshrine")
    ))
    return self:TravelToWayshrineNode(shrine.nodeIndex, shrine.name or enclave.wayshrine)
end


-- ============================================================================
-- v0.29.63 - World Map Teleporter
-- Automatically appears beside ESO's keyboard World Map and exposes free
-- Travel-to-Player destinations from the player's Group, Friends, and Guilds.
-- ============================================================================
local MAP_TELEPORTER_ROWS = 15
local MAP_TELEPORTER_REFRESH = "ESOAdventurerSuite_MapTeleporterLive"

local function mtSetColor(control, r, g, b, a)
    if control and type(control.SetColor) == "function" then control:SetColor(r, g, b, a or 1) end
end

local function mtLabel(parent, text, font, r, g, b, align)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetText(text or "")
    label:SetColor(r or 1, g or 1, b or 1, 1)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    return label
end

local function mtBackdrop(parent, r, g, b, a)
    local bg = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    bg:SetCenterColor(r or 0.025, g or 0.035, b or 0.055, a or 0.94)
    bg:SetEdgeColor(0.55, 0.44, 0.17, 0.92)
    return bg
end

function T:IsMapTeleporterMapShowing()
    if type(ZO_WorldMap_IsWorldMapShowing) == "function" then
        local ok, showing = pcall(ZO_WorldMap_IsWorldMapShowing)
        if ok and showing == true then return true end
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.IsShowing) == "function" then
        local ok, showing = pcall(SCENE_MANAGER.IsShowing, SCENE_MANAGER, "worldMap")
        if ok and showing == true then return true end
    end
    if WORLD_MAP_SCENE and type(WORLD_MAP_SCENE.IsShowing) == "function" then
        local ok, showing = pcall(WORLD_MAP_SCENE.IsShowing, WORLD_MAP_SCENE)
        if ok and showing == true then return true end
    end
    return false
end

-- Resolve the keyboard World Map's actual map canvas.  Different ESO UI
-- revisions expose slightly different globals, so prefer the container/scroll
-- controls and gracefully fall back to the main World Map control.
function T:GetMapTeleporterMapControl()
    local names = {
        "ZO_WorldMapContainer",
        "ZO_WorldMapScroll",
        "ZO_WorldMap",
        "ZO_WorldMapMap",
        "ZO_WorldMapContent",
    }
    for _, name in ipairs(names) do
        local control = _G and _G[name] or nil
        if control and type(control.GetWidth) == "function" and type(control.GetHeight) == "function" then
            local okW, width = pcall(control.GetWidth, control)
            local okH, height = pcall(control.GetHeight, control)
            if okW and okH and safeNumber(width, 0) > 350 and safeNumber(height, 0) > 350 then
                return control
            end
        end
    end
    return nil
end

local LayoutMapTeleporterImplArch

function T:LayoutMapTeleporter(...)

    return LayoutMapTeleporterImplArch(self, ...)

end

LayoutMapTeleporterImplArch = function(self)
    local root = self.mapTeleporter
    if not root then return end

    -- The panel is intentionally the full height of the World Map.  Rows are
    -- packed into the available vertical space so taller maps show more of the
    -- destination list instead of leaving a large empty lower half.
    local startY = 180
    local footerReserve = 46
    local height = math.max(560, safeNumber(root:GetHeight(), 700))
    local available = math.max(300, height - startY - footerReserve)
    local rowH = math.max(30, math.min(44, math.floor(available / MAP_TELEPORTER_ROWS)))

    for i, row in ipairs(root.rows or {}) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, root, TOPLEFT, 12, startY + ((i - 1) * rowH))
        row:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, startY + ((i - 1) * rowH))
        row:SetHeight(math.max(28, rowH - 2))
    end
end

local DockMapTeleporterToWorldMapImplArch

function T:DockMapTeleporterToWorldMap(...)

    return DockMapTeleporterToWorldMapImplArch(self, ...)

end

DockMapTeleporterToWorldMapImplArch = function(self)
    local root = self.mapTeleporter
    if not root then return end

    local mapControl = self:GetMapTeleporterMapControl()
    root:ClearAnchors()
    root:SetWidth(430)
    if mapControl then
        -- Flush to the map's left edge and inherit its exact vertical span.
        root:SetAnchor(TOPRIGHT, mapControl, TOPLEFT, 0, 0)
        root:SetAnchor(BOTTOMRIGHT, mapControl, BOTTOMLEFT, 0, 0)
        root:SetClampedToScreen(false)
    else
        -- Safe fallback for unusual UI layouts/addons that replace the stock
        -- World Map container.
        local h = math.max(560, safeNumber(GuiRoot and GuiRoot:GetHeight(), 900) - 32)
        root:SetHeight(h)
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 8, 8)
        root:SetClampedToScreen(true)
    end
    self:LayoutMapTeleporter()
end

function T:GetMapTeleporterSnapshot()
    if EPC.lastSnapshot then return EPC.lastSnapshot end
    if EPC.Engine and type(EPC.Engine.BuildSnapshot) == "function" then
        local ok, snapshot = pcall(EPC.Engine.BuildSnapshot, EPC.Engine)
        if ok and snapshot then return snapshot end
    end
    local zoneName = ""
    if type(GetUnitZone) == "function" then
        local ok, z = pcall(GetUnitZone, "player")
        if ok then zoneName = clean(z, "") end
    end
    return { zoneName = zoneName }
end

local BuildMapTeleporterEntriesImplArch

function T:BuildMapTeleporterEntries(...)

    return BuildMapTeleporterEntriesImplArch(self, ...)

end

BuildMapTeleporterEntriesImplArch = function(self)
    local snapshot = self:GetMapTeleporterSnapshot()
    local mode = self.mapTeleporterMode or "ALL"
    local combined = {}
    local dedupe = {}
    local priority = { GROUP = 3, FRIEND = 2, GUILD = 1 }

    local function addRows(rows)
        for _, entry in ipairs(rows or {}) do
            local displayName = clean(entry.displayName or entry.name, "")
            local dedupeKey = lower(displayName ~= "" and displayName or entry.key)
            local previous = dedupe[dedupeKey]
            if not previous or (priority[entry.kind] or 0) > (priority[previous.kind] or 0) then
                dedupe[dedupeKey] = entry
            end
        end
    end

    if mode == "ALL" or mode == "GROUP" then addRows(self:GetGroupMembers(snapshot)) end
    if mode == "ALL" or mode == "FRIENDS" then addRows(self:GetFriends(snapshot)) end
    if mode == "ALL" or mode == "GUILD" then addRows(self:GetGuildMembers(snapshot)) end

    local playerNeedle = lower(self.mapTeleporterPlayerSearch or "")
    local zoneNeedle = lower(self.mapTeleporterZoneSearch or "")
    for _, entry in pairs(dedupe) do
        local playerHaystack = lower((entry.displayName or "") .. " " .. (entry.characterName or "") .. " " .. (entry.name or ""))
        local zoneHaystack = lower(entry.zoneName or "")
        if (playerNeedle == "" or string.find(playerHaystack, playerNeedle, 1, true))
            and (zoneNeedle == "" or string.find(zoneHaystack, zoneNeedle, 1, true)) then
            combined[#combined + 1] = entry
        end
    end

    table.sort(combined, function(a, b)
        if (a.isCurrentZone == true) ~= (b.isCurrentZone == true) then return a.isCurrentZone == true end
        local za, zb = lower(a.zoneName), lower(b.zoneName)
        if za ~= zb then return za < zb end
        local na, nb = lower(a.displayName or a.name), lower(b.displayName or b.name)
        if na ~= nb then return na < nb end
        return (priority[a.kind] or 0) > (priority[b.kind] or 0)
    end)
    return combined
end

local TravelMapTeleporterEntryImplArch

function T:TravelMapTeleporterEntry(...)

    return TravelMapTeleporterEntryImplArch(self, ...)

end

TravelMapTeleporterEntryImplArch = function(self, entry)
    if not entry then return end
    local canLeave, reason = self:CanLeaveNow()
    if not canLeave then EPC:Print(tostring(reason or "Travel is unavailable") .. ".") return end
    if entry.canTravel == false then EPC:Print(entry.statusText or "ESO currently blocks travel to that player.") return end

    local fn, arg
    if entry.kind == "GROUP" then
        fn = JumpToGroupMember
        arg = entry.displayName ~= "" and entry.displayName or entry.characterName
    elseif entry.kind == "FRIEND" then
        fn = JumpToFriend
        arg = entry.displayName
    elseif entry.kind == "GUILD" then
        fn = JumpToGuildMember
        arg = entry.displayName
    end
    if type(fn) ~= "function" then EPC:Print("ESO's Travel to Player API is unavailable for this destination.") return end

    EPC:Print("Traveling to " .. clean(entry.name, entry.displayName or "player") .. " in " .. clean(entry.zoneName, "their zone") .. ".")
    local ok = pcall(fn, arg)
    if not ok then EPC:Print("ESO rejected the travel request. The player's location or access state may have changed.") end
end

local SetMapTeleporterModeImplArch

function T:SetMapTeleporterMode(...)

    return SetMapTeleporterModeImplArch(self, ...)

end

SetMapTeleporterModeImplArch = function(self, mode)
    local valid = { ALL=true, GROUP=true, FRIENDS=true, GUILD=true }
    mode = valid[mode] and mode or "ALL"
    self.mapTeleporterMode = mode
    self.mapTeleporterPage = 1
    self:RefreshMapTeleporter()
end

function T:ChangeMapTeleporterPage(delta)
    self.mapTeleporterPage = math.max(1, safeNumber(self.mapTeleporterPage, 1) + safeNumber(delta, 0))
    self:RefreshMapTeleporter()
end

local CreateMapTeleporterImplArch

function T:CreateMapTeleporter(...)

    return CreateMapTeleporterImplArch(self, ...)

end

CreateMapTeleporterImplArch = function(self)
    if self.mapTeleporter then return self.mapTeleporter end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local wm = WINDOW_MANAGER
    local root = wm:CreateTopLevelWindow("EAS_WorldMapTeleporter02965")
    local rootHeight = safeNumber(GuiRoot:GetHeight(), 900)
    root:SetDimensions(430, math.max(560, rootHeight - 32))
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 8, 8)
    root:SetDrawTier(DT_HIGH)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawLevel(60)
    root:SetMouseEnabled(true)
    root:SetClampedToScreen(true)
    root:SetHidden(true)

    local bg = mtBackdrop(root, 0.018, 0.025, 0.043, 0.96)
    bg:SetAnchorFill(root)
    root.bg = bg

    local title = mtLabel(root, "MAP TELEPORTER", "ZoFontWinH2", 1.00, 0.78, 0.24, TEXT_ALIGN_CENTER)
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 8)
    title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 8)
    title:SetHeight(32)
    root.title = title

    local sub = mtLabel(root, "Free travel to online Group, Friends, and Guild members", "ZoFontGameSmall", 0.72, 0.76, 0.82, TEXT_ALIGN_CENTER)
    sub:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 40)
    sub:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 40)
    sub:SetHeight(20)

    local function createSearch(labelText, x, width, field)
        local lbl = mtLabel(root, labelText, "ZoFontGameSmall", 0.82, 0.83, 0.76)
        lbl:SetAnchor(TOPLEFT, root, TOPLEFT, x, 66)
        lbl:SetDimensions(width, 16)
        local boxBg = mtBackdrop(root, 0.035, 0.045, 0.065, 0.98)
        boxBg:SetAnchor(TOPLEFT, root, TOPLEFT, x, 84)
        boxBg:SetDimensions(width, 30)
        local edit = wm:CreateControl(nil, boxBg, CT_EDITBOX)
        edit:SetAnchor(TOPLEFT, boxBg, TOPLEFT, 8, 2)
        edit:SetAnchor(BOTTOMRIGHT, boxBg, BOTTOMRIGHT, -8, -2)
        edit:SetFont("ZoFontGame")
        edit:SetColor(0.95, 0.95, 0.92, 1)
        edit:SetMaxInputChars(40)
        edit:SetText(self[field] or "")
        edit:SetMouseEnabled(true)
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end
        if edit.SetEditEnabled then edit:SetEditEnabled(true) end
        if edit.SetCopyEnabled then edit:SetCopyEnabled(true) end
        if edit.SetPasteEnabled then edit:SetPasteEnabled(true) end
        if edit.SetTextType and TEXT_TYPE_ALL then edit:SetTextType(TEXT_TYPE_ALL) end

        -- The World Map scene owns a lot of mouse/keyboard input.  Explicitly
        -- take focus on both press and release so map shortcuts do not steal
        -- typing from these search fields.
        local function takeFocus(control)
            if control and control.TakeFocus then control:TakeFocus() end
        end
        edit:SetHandler("OnMouseDown", function(control) takeFocus(control) end)
        edit:SetHandler("OnMouseUp", function(control, button, upInside)
            if upInside ~= false then takeFocus(control) end
        end)
        edit:SetHandler("OnFocusGained", function() self.mapTeleporterSearchFocused = true end)
        edit:SetHandler("OnFocusLost", function() self.mapTeleporterSearchFocused = false end)
        edit:SetHandler("OnEnter", function(control)
            if control.LoseFocus then control:LoseFocus() end
        end)
        edit:SetHandler("OnEscape", function(control)
            if control.LoseFocus then control:LoseFocus() end
        end)
        edit:SetHandler("OnTextChanged", function(control)
            self[field] = control:GetText() or ""
            self.mapTeleporterPage = 1
            self:RefreshMapTeleporter()
        end)
        return edit
    end
    root.playerSearch = createSearch("PLAYER", 14, 192, "mapTeleporterPlayerSearch")
    root.zoneSearch = createSearch("ZONE", 222, 192, "mapTeleporterZoneSearch")

    root.tabs = {}
    local tabs = {
        {"ALL", "ALL"}, {"GROUP", "GROUP"}, {"FRIENDS", "FRIENDS"}, {"GUILD", "GUILD"},
    }
    local tabW = 95
    for i, spec in ipairs(tabs) do
        local button = wm:CreateControl(nil, root, CT_BUTTON)
        button:SetDimensions(tabW, 28)
        button:SetAnchor(TOPLEFT, root, TOPLEFT, 14 + ((i - 1) * (tabW + 6)), 124)
        button:SetFont("ZoFontGameBold")
        button:SetText(spec[2])
        button:SetNormalFontColor(0.82, 0.84, 0.86, 1)
        button:SetMouseOverFontColor(1.00, 0.88, 0.46, 1)
        button:SetHandler("OnClicked", function() self:SetMapTeleporterMode(spec[1]) end)
        root.tabs[spec[1]] = button
    end

    local stats = mtLabel(root, "", "ZoFontGameSmall", 0.72, 0.76, 0.82)
    stats:SetAnchor(TOPLEFT, root, TOPLEFT, 16, 157)
    stats:SetAnchor(TOPRIGHT, root, TOPRIGHT, -16, 157)
    stats:SetHeight(18)
    root.stats = stats

    root.rows = {}
    local startY = 180
    local rowH = 36
    for i = 1, MAP_TELEPORTER_ROWS do
        local row = wm:CreateControl(nil, root, CT_BUTTON)
        row:SetAnchor(TOPLEFT, root, TOPLEFT, 12, startY + ((i - 1) * rowH))
        row:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, startY + ((i - 1) * rowH))
        row:SetHeight(rowH - 2)
        row:SetMouseEnabled(true)
        local rowBg = mtBackdrop(row, 0.026, 0.034, 0.052, 0.78)
        rowBg:SetAnchorFill(row)
        row.bg = rowBg
        row.name = mtLabel(row, "", "ZoFontGameBold", 0.96, 0.96, 0.92)
        row.name:SetAnchor(TOPLEFT, row, TOPLEFT, 10, 3)
        row.name:SetAnchor(TOPRIGHT, row, TOPRIGHT, -92, 3)
        row.name:SetHeight(19)
        row.zone = mtLabel(row, "", "ZoFontGameSmall", 0.67, 0.74, 0.82)
        row.zone:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 10, -3)
        row.zone:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -92, -3)
        row.zone:SetHeight(17)
        row.source = mtLabel(row, "", "ZoFontGameSmall", 1.00, 0.78, 0.24, TEXT_ALIGN_RIGHT)
        row.source:SetAnchor(TOPRIGHT, row, TOPRIGHT, -8, 3)
        row.source:SetDimensions(78, 18)
        row.status = mtLabel(row, "", "ZoFontGameSmall", 0.50, 0.92, 0.62, TEXT_ALIGN_RIGHT)
        row.status:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -8, -3)
        row.status:SetDimensions(78, 17)
        row:SetHandler("OnMouseEnter", function(control)
            if control.entry then control.bg:SetCenterColor(0.08, 0.10, 0.14, 0.94) end
        end)
        row:SetHandler("OnMouseExit", function(control)
            if control.entry then control.bg:SetCenterColor(0.026, 0.034, 0.052, 0.78) end
        end)
        row:SetHandler("OnClicked", function(control)
            if control.entry then self:TravelMapTeleporterEntry(control.entry) end
        end)
        row:SetHidden(true)
        root.rows[i] = row
    end

    local prev = wm:CreateControl(nil, root, CT_BUTTON)
    prev:SetDimensions(72, 28)
    prev:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 14, -10)
    prev:SetFont("ZoFontGameBold")
    prev:SetText("PREVIOUS")
    prev:SetNormalFontColor(0.85, 0.86, 0.88, 1)
    prev:SetMouseOverFontColor(1.00, 0.78, 0.24, 1)
    prev:SetHandler("OnClicked", function() self:ChangeMapTeleporterPage(-1) end)
    root.prev = prev

    local page = mtLabel(root, "1 / 1", "ZoFontGame", 0.76, 0.79, 0.84, TEXT_ALIGN_CENTER)
    page:SetAnchor(BOTTOM, root, BOTTOM, 0, -11)
    page:SetDimensions(150, 26)
    root.page = page

    local nextButton = wm:CreateControl(nil, root, CT_BUTTON)
    nextButton:SetDimensions(72, 28)
    nextButton:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -14, -10)
    nextButton:SetFont("ZoFontGameBold")
    nextButton:SetText("NEXT")
    nextButton:SetNormalFontColor(0.85, 0.86, 0.88, 1)
    nextButton:SetMouseOverFontColor(1.00, 0.78, 0.24, 1)
    nextButton:SetHandler("OnClicked", function() self:ChangeMapTeleporterPage(1) end)
    root.next = nextButton

    root:SetHandler("OnMouseWheel", function(_, delta) self:ChangeMapTeleporterPage(delta < 0 and 1 or -1) end)
    self.mapTeleporter = root
    self:DockMapTeleporterToWorldMap()
    return root
end

local RefreshMapTeleporterImplArch

function T:RefreshMapTeleporter(...)

    return RefreshMapTeleporterImplArch(self, ...)

end

RefreshMapTeleporterImplArch = function(self)
    local root = self.mapTeleporter
    if not root or root:IsHidden() then return end
    self:DockMapTeleporterToWorldMap()
    local entries = self:BuildMapTeleporterEntries()
    self.mapTeleporterEntries = entries
    local pages = math.max(1, math.ceil(#entries / MAP_TELEPORTER_ROWS))
    local page = math.max(1, math.min(safeNumber(self.mapTeleporterPage, 1), pages))
    self.mapTeleporterPage = page
    local first = ((page - 1) * MAP_TELEPORTER_ROWS) + 1

    root.stats:SetText(string.format("%d ONLINE DESTINATION%s  |  click a player to travel", #entries, #entries == 1 and "" or "S"))
    root.page:SetText(string.format("PAGE %d / %d", page, pages))
    root.prev:SetEnabled(page > 1)
    root.next:SetEnabled(page < pages)

    for mode, button in pairs(root.tabs or {}) do
        local selected = mode == (self.mapTeleporterMode or "ALL")
        if selected then button:SetNormalFontColor(1.00, 0.78, 0.24, 1)
        else button:SetNormalFontColor(0.82, 0.84, 0.86, 1) end
    end

    for i, row in ipairs(root.rows or {}) do
        local entry = entries[first + i - 1]
        row.entry = entry
        if entry then
            row:SetHidden(false)
            row.name:SetText(clean(entry.displayName, entry.name or "Unknown Player"))
            local character = clean(entry.characterName, "")
            local zone = clean(entry.zoneName, "Unknown location")
            if character ~= "" and lower(character) ~= lower(entry.displayName or "") then
                row.zone:SetText(character .. "   " .. zone)
            else
                row.zone:SetText(zone)
            end
            local source = entry.kind == "FRIEND" and "FRIEND" or entry.kind
            row.source:SetText(source or "PLAYER")
            row.status:SetText(entry.canTravel == false and "BLOCKED" or "TRAVEL")
            if entry.canTravel == false then row.status:SetColor(0.94, 0.40, 0.36, 1)
            elseif entry.isCurrentZone then row.status:SetColor(0.45, 0.95, 1.00, 1)
            else row.status:SetColor(0.50, 0.92, 0.62, 1) end
        else
            row:SetHidden(true)
        end
    end
end

local SetMapTeleporterVisibleImplArch

function T:SetMapTeleporterVisible(...)

    return SetMapTeleporterVisibleImplArch(self, ...)

end

SetMapTeleporterVisibleImplArch = function(self, visible)
    local root = self:CreateMapTeleporter()
    if not root then return end
    visible = visible == true and EPC.saved and EPC.saved.mapTeleporterEnabled ~= false
    root:SetHidden(not visible)
    if visible then
        self.mapTeleporterPage = self.mapTeleporterPage or 1
        self.mapTeleporterMode = self.mapTeleporterMode or "ALL"
        self:DockMapTeleporterToWorldMap()
        self:RefreshMapTeleporter()
        zo_callLater(function() if EPC.Travel then EPC.Travel:DockMapTeleporterToWorldMap() end end, 60)
        zo_callLater(function() if EPC.Travel then EPC.Travel:DockMapTeleporterToWorldMap() end end, 220)
        if EVENT_MANAGER then
            EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
            EPC.Runtime:RegisterUpdate("Travel", "MapTeleporterRefresh", 4000, function()
                if EPC.Travel and EPC.Travel.mapTeleporter and not EPC.Travel.mapTeleporter:IsHidden() and EPC.Travel:IsMapTeleporterMapShowing() then
                    EPC.Travel:RefreshMapTeleporter()
                else
                    EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
                end
            end)
        end
    elseif EVENT_MANAGER then
        EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
    end
end

local RefreshMapTeleporterVisibilityImplArch

function T:RefreshMapTeleporterVisibility(...)

    return RefreshMapTeleporterVisibilityImplArch(self, ...)

end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local shouldShow = EPC.saved and EPC.saved.mapTeleporterEnabled ~= false and self:IsMapTeleporterMapShowing()
    self:SetMapTeleporterVisible(shouldShow)
end

function T:InitializeMapTeleporter()
    if self.mapTeleporterInitialized then
        self:RefreshMapTeleporterVisibility()
        return
    end
    self.mapTeleporterInitialized = true
    self.mapTeleporterMode = self.mapTeleporterMode or "ALL"
    self.mapTeleporterPage = self.mapTeleporterPage or 1
    self.mapTeleporterPlayerSearch = self.mapTeleporterPlayerSearch or ""
    self.mapTeleporterZoneSearch = self.mapTeleporterZoneSearch or ""
    self:CreateMapTeleporter()

    local function registerScene(scene)
        if scene and type(scene.RegisterCallback) == "function" then
            scene:RegisterCallback("StateChange", function()
                zo_callLater(function()
                    if EPC.Travel then EPC.Travel:RefreshMapTeleporterVisibility() end
                end, 60)
            end)
        end
    end
    registerScene(WORLD_MAP_SCENE)

    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.RegisterCallback) == "function" then
        CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
            if EPC.Travel and EPC.Travel.mapTeleporter and not EPC.Travel.mapTeleporter:IsHidden() then
                EPC.Travel:RefreshMapTeleporter()
            end
        end)
    end
    zo_callLater(function() if EPC.Travel then EPC.Travel:RefreshMapTeleporterVisibility() end end, 100)
end

-- ============================================================================
-- v0.29.66 - Expanded World Map Teleporter (BeamMeUp-style core feature set)
-- Standalone Suite implementation: zone aggregation, current-map routing,
-- quest routing, wayshrines, owned houses, favorites, instances, sorting,
-- blacklists, quick actions and row context actions.
-- ============================================================================
local MAP_TELEPORTER_MODES_02966 = {
    {"ALL", "ALL"}, {"ZONES", "ZONES"}, {"MAP", "MAP"}, {"QUESTS", "QUESTS"},
    {"GROUP", "GROUP"}, {"FRIENDS", "FRIENDS"}, {"GUILD", "GUILD"},
    {"SHRINES", "SHRINES"}, {"HOUSES", "HOUSES"}, {"FAVORITES", "FAVORITES"},
    {"INSTANCES", "INSTANCES"},
}

local function mtKey02966(entry)
    if not entry then return "" end
    if entry.favoriteKey and entry.favoriteKey ~= "" then return tostring(entry.favoriteKey) end
    if entry.kind == "ZONE" or entry.kind == "QUEST" then
        return "ZONE:" .. tostring(entry.zoneId or lower(entry.zoneName or ""))
    elseif entry.kind == "HOUSE" then
        return "HOUSE:" .. tostring(entry.houseId or 0)
    elseif entry.kind == "SHRINE" or entry.kind == "INSTANCE" then
        return tostring(entry.kind) .. ":" .. tostring(entry.nodeIndex or 0)
    end
    local who = clean(entry.displayName or entry.name, "")
    if who ~= "" then return "PLAYER:" .. lower(who) end
    return tostring(entry.kind or "ROW") .. ":" .. tostring(entry.key or lower(entry.name or entry.zoneName or ""))
end

local function mtZoneKey02966(entry)
    if not entry then return "" end
    local zid = safeNumber(entry.zoneId, 0)
    if zid > 0 then return tostring(zid) end
    return lower(entry.zoneName or "")
end

function T:IsMapTeleporterFavorite(entry)
    if not EPC.saved then return false end
    EPC.saved.mapTeleporterFavorites = EPC.saved.mapTeleporterFavorites or {}
    return EPC.saved.mapTeleporterFavorites[mtKey02966(entry)] == true
end

function T:ToggleMapTeleporterFavorite(entry)
    if not EPC.saved or not entry then return end
    EPC.saved.mapTeleporterFavorites = EPC.saved.mapTeleporterFavorites or {}
    local key = mtKey02966(entry)
    if key == "" then return end
    EPC.saved.mapTeleporterFavorites[key] = not (EPC.saved.mapTeleporterFavorites[key] == true)
    self:RefreshMapTeleporter()
end

function T:IsMapTeleporterBlacklisted(entry)
    if not EPC.saved or not entry then return false end
    EPC.saved.mapTeleporterBlacklistPlayers = EPC.saved.mapTeleporterBlacklistPlayers or {}
    EPC.saved.mapTeleporterBlacklistZones = EPC.saved.mapTeleporterBlacklistZones or {}
    local who = lower(entry.displayName or "")
    local zone = mtZoneKey02966(entry)
    return (who ~= "" and EPC.saved.mapTeleporterBlacklistPlayers[who] == true)
        or (zone ~= "" and EPC.saved.mapTeleporterBlacklistZones[zone] == true)
end

function T:ToggleMapTeleporterPlayerBlacklist(entry)
    if not EPC.saved or not entry then return end
    local who = lower(entry.displayName or "")
    if who == "" then return end
    EPC.saved.mapTeleporterBlacklistPlayers = EPC.saved.mapTeleporterBlacklistPlayers or {}
    EPC.saved.mapTeleporterBlacklistPlayers[who] = not (EPC.saved.mapTeleporterBlacklistPlayers[who] == true)
    self:RefreshMapTeleporter()
end

function T:ToggleMapTeleporterZoneBlacklist(entry)
    if not EPC.saved or not entry then return end
    local zone = mtZoneKey02966(entry)
    if zone == "" then return end
    EPC.saved.mapTeleporterBlacklistZones = EPC.saved.mapTeleporterBlacklistZones or {}
    EPC.saved.mapTeleporterBlacklistZones[zone] = not (EPC.saved.mapTeleporterBlacklistZones[zone] == true)
    self:RefreshMapTeleporter()
end

function T:GetMapTeleporterSocialEntries()
    local snapshot = self:GetMapTeleporterSnapshot()
    local combined, dedupe = {}, {}
    local priority = { GROUP = 3, FRIEND = 2, GUILD = 1 }
    local function add(rows)
        for _, e in ipairs(rows or {}) do
            local who = lower(e.displayName or e.name or e.key)
            if who ~= "" then
                local old = dedupe[who]
                if not old or (priority[e.kind] or 0) > (priority[old.kind] or 0) then dedupe[who] = e end
            end
        end
    end
    add(self:GetGroupMembers(snapshot)); add(self:GetFriends(snapshot)); add(self:GetGuildMembers(snapshot))
    for _, e in pairs(dedupe) do combined[#combined + 1] = e end
    return combined
end

function T:GetMapTeleporterDisplayedZone()
    local zoneIndex, zoneId, zoneName = 0, 0, ""
    if type(GetCurrentMapZoneIndex) == "function" then
        local ok, v = pcall(GetCurrentMapZoneIndex); if ok then zoneIndex = safeNumber(v, 0) end
    end
    if zoneIndex > 0 and type(GetZoneId) == "function" then
        local ok, v = pcall(GetZoneId, zoneIndex); if ok then zoneId = safeNumber(v, 0) end
    end
    if zoneId > 0 and type(GetZoneNameById) == "function" then
        local ok, v = pcall(GetZoneNameById, zoneId); if ok then zoneName = clean(v, "") end
    end
    if zoneName == "" and type(GetMapName) == "function" then
        local ok, v = pcall(GetMapName); if ok then zoneName = clean(v, "") end
    end
    return zoneId, zoneName
end

local GetMapTeleporterHouseEntriesImplArch

function T:GetMapTeleporterHouseEntries(...)

    return GetMapTeleporterHouseEntriesImplArch(self, ...)

end

GetMapTeleporterHouseEntriesImplArch = function(self)
    local rows, seen = {}, {}
    local owned = nil
    if COLLECTIONS_BOOK_SINGLETON and type(COLLECTIONS_BOOK_SINGLETON.GetOwnedHouses) == "function" then
        local ok, value = pcall(COLLECTIONS_BOOK_SINGLETON.GetOwnedHouses, COLLECTIONS_BOOK_SINGLETON)
        if ok and type(value) == "table" then owned = value end
    end
    if not owned and ZO_COLLECTIBLE_DATA_MANAGER and type(ZO_COLLECTIBLE_DATA_MANAGER.GetAllCollectibleDataObjects) == "function"
        and ZO_CollectibleCategoryData and ZO_CollectibleData then
        local ok, value = pcall(ZO_COLLECTIBLE_DATA_MANAGER.GetAllCollectibleDataObjects, ZO_COLLECTIBLE_DATA_MANAGER,
            { ZO_CollectibleCategoryData.IsHousingCategory }, { ZO_CollectibleData.IsUnlocked })
        if ok and type(value) == "table" then owned = value end
    end
    owned = owned or {}
    local primary = 0
    if type(GetHousingPrimaryHouse) == "function" then local ok,v=pcall(GetHousingPrimaryHouse); if ok then primary=safeNumber(v,0) end end
    for _, house in pairs(owned) do
        local houseId = safeNumber(house and house.houseId, 0)
        if houseId <= 0 and house and type(house.GetReferenceId) == "function" then
            local ok,v=pcall(house.GetReferenceId, house); if ok then houseId=safeNumber(v,0) end
        end
        if houseId > 0 and not seen[houseId] then
            seen[houseId] = true
            local collectibleId, houseZoneId, foundZoneId = 0, 0, 0
            if type(GetCollectibleIdForHouse) == "function" then local ok,v=pcall(GetCollectibleIdForHouse,houseId); if ok then collectibleId=safeNumber(v,0) end end
            if type(GetHouseZoneId) == "function" then local ok,v=pcall(GetHouseZoneId,houseId); if ok then houseZoneId=safeNumber(v,0) end end
            if type(GetHouseFoundInZoneId) == "function" then local ok,v=pcall(GetHouseFoundInZoneId,houseId); if ok then foundZoneId=safeNumber(v,0) end end
            if foundZoneId <= 0 then foundZoneId = houseZoneId end
            local name, nickname, zoneName = "House "..tostring(houseId), "", "Housing"
            if collectibleId > 0 and type(GetCollectibleName) == "function" then local ok,v=pcall(GetCollectibleName,collectibleId); if ok then name=clean(v,name) end end
            if collectibleId > 0 and type(GetCollectibleNickname) == "function" then local ok,v=pcall(GetCollectibleNickname,collectibleId); if ok then nickname=clean(v,"") end end
            if foundZoneId > 0 and type(GetZoneNameById) == "function" then local ok,v=pcall(GetZoneNameById,foundZoneId); if ok then zoneName=clean(v,zoneName) end end
            rows[#rows+1] = {
                kind="HOUSE", key="H:"..tostring(houseId), favoriteKey="HOUSE:"..tostring(houseId),
                houseId=houseId, collectibleId=collectibleId, zoneId=foundZoneId, zoneName=zoneName,
                name=name, displayName=name, characterName=nickname,
                canTravel=type(RequestJumpToHouse)=="function", statusText=houseId==primary and "PRIMARY" or "HOUSE",
                sourceText="HOUSE", isPrimary=houseId==primary,
            }
        end
    end
    table.sort(rows, function(a,b)
        if a.isPrimary ~= b.isPrimary then return a.isPrimary == true end
        local za,zb=lower(a.zoneName),lower(b.zoneName); if za~=zb then return za<zb end
        return lower(a.name)<lower(b.name)
    end)
    return rows
end

local GetMapTeleporterInstanceEntriesImplArch

function T:GetMapTeleporterInstanceEntries(...)

    return GetMapTeleporterInstanceEntriesImplArch(self, ...)

end

GetMapTeleporterInstanceEntriesImplArch = function(self)
    local rows, total = {}, 0
    if type(GetNumFastTravelNodes) == "function" then local ok,v=pcall(GetNumFastTravelNodes); if ok then total=safeNumber(v,0) end end
    for nodeIndex=1,total do
        local ok, known, name, normalizedX, normalizedY, _, _, poiType, _, locked = pcall(GetFastTravelNodeInfo, nodeIndex)
        if ok and known and not locked and (POI_TYPE_WAYSHRINE == nil or poiType ~= POI_TYPE_WAYSHRINE) then
            local houseId = 0
            if type(GetFastTravelNodeHouseId) == "function" then local hok,hid=pcall(GetFastTravelNodeHouseId,nodeIndex); if hok then houseId=safeNumber(hid,0) end end
            if houseId <= 0 then
                local zoneIndex = 0
                local fn = GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices
                if type(fn)=="function" then local zok,zidx=pcall(fn,nodeIndex); if zok then zoneIndex=safeNumber(zidx,0) end end
                local zoneName, zoneId = "Instance", 0
                if zoneIndex>0 and type(GetZoneNameByIndex)=="function" then local nok,n=pcall(GetZoneNameByIndex,zoneIndex); if nok then zoneName=clean(n,zoneName) end end
                if zoneIndex>0 and type(GetZoneId)=="function" then local iok,id=pcall(GetZoneId,zoneIndex); if iok then zoneId=safeNumber(id,0) end end
                local cost,currency=self:GetLiveWayshrineTravelCost(nodeIndex)
                rows[#rows+1]={kind="INSTANCE",key="I:"..tostring(nodeIndex),nodeIndex=nodeIndex,name=clean(name,"Instance"),displayName=clean(name,"Instance"),zoneName=zoneName,zoneId=zoneId,costText=cost<=0 and "Free" or (formatNumber(cost).." gold"),canTravel=true,statusText="TRAVEL",sourceText="INSTANCE"}
            end
        end
    end
    table.sort(rows,function(a,b) local za,zb=lower(a.zoneName),lower(b.zoneName); if za~=zb then return za<zb end return lower(a.name)<lower(b.name) end)
    return rows
end

function T:GetMapTeleporterBestRouteForZone(zoneId, zoneName, social, shrines, houses)
    local zid=safeNumber(zoneId,0); local zn=lower(zoneName)
    local best, bestScore=nil,-1
    local priority={GROUP=90,FRIEND=80,GUILD=70,HOUSE=50,SHRINE=40,INSTANCE=30}
    local function consider(e)
        local match=false
        if zid>0 and safeNumber(e.zoneId,0)>0 then match=safeNumber(e.zoneId,0)==zid end
        if not match and zn~="" then match=lower(e.zoneName)==zn end
        if match and e.canTravel~=false then
            local score=priority[e.kind] or 10
            if self:IsMapTeleporterFavorite(e) then score=score+20 end
            if score>bestScore then best,bestScore=e,score end
        end
    end
    for _,e in ipairs(social or {}) do consider(e) end
    for _,e in ipairs(houses or {}) do consider(e) end
    for _,e in ipairs(shrines or {}) do consider(e) end
    return best
end

function T:GetMapTeleporterZoneEntries()
    local snapshot=self:GetMapTeleporterSnapshot()
    local social=self:GetMapTeleporterSocialEntries()
    local shrines=self:GetWayshrines(snapshot)
    local houses=(EPC.saved and EPC.saved.mapTeleporterIncludeHouses==false) and {} or self:GetMapTeleporterHouseEntries()
    local groups={}
    local function touch(e,isPlayer)
        local zoneName=clean(e.zoneName,""); if zoneName=="" then return end
        local zoneId=safeNumber(e.zoneId,0); local key=zoneId>0 and tostring(zoneId) or lower(zoneName)
        local g=groups[key]; if not g then g={zoneId=zoneId,zoneName=zoneName,players=0,free=0,shrines=0,houses=0}; groups[key]=g end
        if isPlayer then g.players=g.players+1 end
        if e.kind=="SHRINE" then g.shrines=g.shrines+1 end
        if e.kind=="HOUSE" then g.houses=g.houses+1 end
        if e.canTravel~=false and (e.kind=="GROUP" or e.kind=="FRIEND" or e.kind=="GUILD" or e.kind=="HOUSE") then g.free=g.free+1 end
    end
    for _,e in ipairs(social) do touch(e,true) end
    for _,e in ipairs(houses) do touch(e,false) end
    if not EPC.saved or EPC.saved.mapTeleporterShowAllZones~=false then for _,e in ipairs(shrines) do touch(e,false) end end
    local rows={}
    local unknownByZone=self:GetMapTeleporterUnknownWayshrineZones()
    for _,g in pairs(groups) do
        local route=self:GetMapTeleporterBestRouteForZone(g.zoneId,g.zoneName,social,shrines,houses)
        rows[#rows+1]={kind="ZONE",key="Z:"..tostring(g.zoneId>0 and g.zoneId or lower(g.zoneName)),favoriteKey="ZONE:"..tostring(g.zoneId>0 and g.zoneId or lower(g.zoneName)),name=g.zoneName,displayName=g.zoneName,zoneName=g.zoneName,zoneId=g.zoneId,playerCount=g.players,knownWayshrines=g.shrines,unknownWayshrines=safeNumber(unknownByZone[lower(g.zoneName)],0),houseCount=g.houses,travelEntry=route,canTravel=route~=nil,statusText=route and ((route.kind=="GROUP" or route.kind=="FRIEND" or route.kind=="GUILD" or route.kind=="HOUSE") and "FREE" or (route.costText or "TRAVEL")) or "NO ROUTE",sourceText=route and route.kind or "ZONE"}
    end
    return rows
end

function T:GetMapTeleporterQuestEntries()
    local snapshot=self:GetMapTeleporterSnapshot(); local social=self:GetMapTeleporterSocialEntries(); local shrines=self:GetWayshrines(snapshot); local houses=self:GetMapTeleporterHouseEntries(); local rows={}
    local count=0; if type(GetNumJournalQuests)=="function" then local ok,v=pcall(GetNumJournalQuests); if ok then count=safeNumber(v,0) end end
    for q=1,count do
        local name="Quest"; local completed=false
        if type(GetJournalQuestInfo)=="function" then local ok,n,_,_,_,_,done=pcall(GetJournalQuestInfo,q); if ok then name=clean(n,name); completed=done==true end end
        if not completed then
            local zoneId,zoneName=self:GetJournalQuestOverlandFallbackZone(q)
            if zoneName~="" then
                local route=self:GetMapTeleporterBestRouteForZone(zoneId,zoneName,social,shrines,houses)
                rows[#rows+1]={kind="QUEST",key="Q:"..tostring(q),questIndex=q,name=name,displayName=name,zoneId=zoneId,zoneName=zoneName,travelEntry=route,canTravel=route~=nil,statusText=route and ((route.kind=="GROUP" or route.kind=="FRIEND" or route.kind=="GUILD" or route.kind=="HOUSE") and "FREE" or (route.costText or "TRAVEL")) or "NO ROUTE",sourceText="QUEST"}
            end
        end
    end
    table.sort(rows,function(a,b) local za,zb=lower(a.zoneName),lower(b.zoneName); if za~=zb then return za<zb end return lower(a.name)<lower(b.name) end)
    return rows
end

function T:GetMapTeleporterCurrentMapEntries()
    local zoneId,zoneName=self:GetMapTeleporterDisplayedZone(); local zn=lower(zoneName); local rows={}; local snapshot=self:GetMapTeleporterSnapshot()
    local function addIf(e)
        local match=false
        if zoneId>0 and safeNumber(e.zoneId,0)>0 then match=safeNumber(e.zoneId,0)==zoneId end
        if not match and zn~="" then match=lower(e.zoneName)==zn end
        if match then rows[#rows+1]=e end
    end
    for _,e in ipairs(self:GetMapTeleporterSocialEntries()) do addIf(e) end
    for _,e in ipairs(self:GetWayshrines(snapshot)) do if e.isShownInCurrentMap or zoneName=="" then addIf(e) end end
    if not EPC.saved or EPC.saved.mapTeleporterIncludeHouses~=false then for _,e in ipairs(self:GetMapTeleporterHouseEntries()) do addIf(e) end end
    for _,e in ipairs(self:GetMapTeleporterInstanceEntries()) do addIf(e) end
    return rows
end

local GetMapTeleporterFavoriteEntriesImplArch

function T:GetMapTeleporterFavoriteEntries(...)

    return GetMapTeleporterFavoriteEntriesImplArch(self, ...)

end

GetMapTeleporterFavoriteEntriesImplArch = function(self)
    local rows={}
    local sources={self:GetMapTeleporterSocialEntries(),self:GetMapTeleporterZoneEntries(),self:GetMapTeleporterHouseEntries(),self:GetWayshrines(self:GetMapTeleporterSnapshot()),self:GetMapTeleporterInstanceEntries()}
    local seen={}
    for _,src in ipairs(sources) do for _,e in ipairs(src or {}) do local k=mtKey02966(e); if k~="" and not seen[k] and self:IsMapTeleporterFavorite(e) then seen[k]=true; rows[#rows+1]=e end end end
    return rows
end

function T:SortMapTeleporterEntries(entries)
    local mode=(EPC.saved and EPC.saved.mapTeleporterSortMode) or "SMART"
    local ports=(EPC.saved and EPC.saved.mapTeleporterPortCount) or {}
    local last=(EPC.saved and EPC.saved.mapTeleporterLastUsed) or {}
    local pri={GROUP=1,FRIEND=2,GUILD=3,ZONE=4,HOUSE=5,PLAYER_HOME=6,SHRINE=7,QUEST=8,ITEM=9,LEAD=10,GUILD_HOME=11,GUILD_SUMMARY=12,INSTANCE=13}
    table.sort(entries,function(a,b)
        local af,bf=self:IsMapTeleporterFavorite(a),self:IsMapTeleporterFavorite(b)
        if mode=="SMART" and af~=bf then return af end
        if mode=="MOST_USED" then local ac,bc=safeNumber(ports[mtKey02966(a)],0),safeNumber(ports[mtKey02966(b)],0); if ac~=bc then return ac>bc end end
        if mode=="LAST_USED" then local ac,bc=safeNumber(last[mtKey02966(a)],0),safeNumber(last[mtKey02966(b)],0); if ac~=bc then return ac>bc end end
        if mode=="PLAYER_COUNT" then local ac,bc=safeNumber(a.playerCount,0),safeNumber(b.playerCount,0); if ac~=bc then return ac>bc end end
        if mode=="SOURCE" and (pri[a.kind] or 99)~=(pri[b.kind] or 99) then return (pri[a.kind] or 99)<(pri[b.kind] or 99) end
        local za,zb=lower(a.zoneName),lower(b.zoneName); if za~=zb then return za<zb end
        local na,nb=lower(a.displayName or a.name),lower(b.displayName or b.name); if na~=nb then return na<nb end
        return (pri[a.kind] or 99)<(pri[b.kind] or 99)
    end)
end

BuildMapTeleporterEntriesImplArch = function(self)
    local mode=self.mapTeleporterMode or "ALL"; local snapshot=self:GetMapTeleporterSnapshot(); local entries={}
    if mode=="GROUP" then entries=self:GetGroupMembers(snapshot)
    elseif mode=="FRIENDS" then entries=self:GetFriends(snapshot)
    elseif mode=="GUILD" then entries=self:GetGuildMembers(snapshot)
    elseif mode=="ZONES" then entries=self:GetMapTeleporterZoneEntries()
    elseif mode=="MAP" then entries=self:GetMapTeleporterCurrentMapEntries()
    elseif mode=="QUESTS" then entries=self:GetMapTeleporterQuestEntries()
    elseif mode=="SHRINES" then entries=self:GetWayshrines(snapshot)
    elseif mode=="HOUSES" then entries=self:GetMapTeleporterHouseEntries()
    elseif mode=="FAVORITES" then entries=self:GetMapTeleporterFavoriteEntries()
    elseif mode=="INSTANCES" then entries=self:GetMapTeleporterInstanceEntries()
    else
        entries=self:GetMapTeleporterSocialEntries()
        if not EPC.saved or EPC.saved.mapTeleporterIncludeHouses~=false then for _,e in ipairs(self:GetMapTeleporterHouseEntries()) do entries[#entries+1]=e end end
    end
    local playerNeedle=lower(self.mapTeleporterPlayerSearch or ""); local zoneNeedle=lower(self.mapTeleporterZoneSearch or ""); local filtered={}
    for _,e in ipairs(entries or {}) do
        local black=self:IsMapTeleporterBlacklisted(e)
        local showBlack=EPC.saved and EPC.saved.mapTeleporterShowBlacklisted==true
        local playerHay=lower((e.displayName or "").." "..(e.characterName or "").." "..(e.name or "")); local zoneHay=lower(e.zoneName or "")
        if (not black or showBlack) and (playerNeedle=="" or string.find(playerHay,playerNeedle,1,true)) and (zoneNeedle=="" or string.find(zoneHay,zoneNeedle,1,true)) then filtered[#filtered+1]=e end
    end
    self:SortMapTeleporterEntries(filtered)
    return filtered
end

function T:RecordMapTeleporterTravel(entry)
    if not EPC.saved or not entry then return end
    EPC.saved.mapTeleporterPortCount=EPC.saved.mapTeleporterPortCount or {}; EPC.saved.mapTeleporterLastUsed=EPC.saved.mapTeleporterLastUsed or {}
    local k=mtKey02966(entry); EPC.saved.mapTeleporterPortCount[k]=safeNumber(EPC.saved.mapTeleporterPortCount[k],0)+1
    EPC.saved.mapTeleporterLastUsed[k]=type(GetTimeStamp)=="function" and GetTimeStamp() or 0
end

TravelMapTeleporterEntryImplArch = function(self, entry)
    if not entry then return end
    if entry.travelEntry then return self:TravelMapTeleporterEntry(entry.travelEntry) end
    local canLeave,reason=self:CanLeaveNow(); if not canLeave then EPC:Print(tostring(reason or "Travel is unavailable")..".") return end
    if entry.canTravel==false then EPC:Print(entry.statusText or "ESO currently blocks this destination.") return end
    local fn,arg,arg2
    if entry.kind=="GROUP" then fn=JumpToGroupMember; arg=entry.displayName~="" and entry.displayName or entry.characterName
    elseif entry.kind=="FRIEND" then fn=JumpToFriend; arg=entry.displayName
    elseif entry.kind=="GUILD" then fn=JumpToGuildMember; arg=entry.displayName
    elseif entry.kind=="SHRINE" or entry.kind=="INSTANCE" then fn=FastTravelToNode; arg=entry.nodeIndex
    elseif entry.kind=="HOUSE" then fn=RequestJumpToHouse; arg=entry.houseId; arg2=false
    elseif entry.kind=="LEADS" then if EPC.AntiquityLeadFinder and EPC.AntiquityLeadFinder.Toggle then EPC.AntiquityLeadFinder:Toggle() end return
    end
    if type(fn)~="function" then EPC:Print("ESO's travel API is unavailable for this destination.") return end
    self:RecordMapTeleporterTravel(entry)
    EPC:Print("Traveling to "..clean(entry.name,entry.displayName or entry.zoneName or "destination")..".")
    local ok
    if arg2~=nil then ok=pcall(fn,arg,arg2) else ok=pcall(fn,arg) end
    if not ok then EPC:Print("ESO rejected the travel request. The destination or access state may have changed.") end
end

function T:MapTeleporterQuickHome(outside)
    if type(GetHousingPrimaryHouse)~="function" or type(RequestJumpToHouse)~="function" then EPC:Print("Primary-home travel API is unavailable.") return end
    local ok,id=pcall(GetHousingPrimaryHouse); id=ok and safeNumber(id,0) or 0; if id<=0 then EPC:Print("No primary residence is set.") return end
    pcall(RequestJumpToHouse,id,outside==true)
end

local MapTeleporterQuickLeaderImplArch

function T:MapTeleporterQuickLeader(...)

    return MapTeleporterQuickLeaderImplArch(self, ...)

end

MapTeleporterQuickLeaderImplArch = function(self)
    local rows=self:GetGroupMembers(self:GetMapTeleporterSnapshot()); local leader=nil
    for _,e in ipairs(rows or {}) do if e.isLeader then leader=e break end end
    if not leader and rows and rows[1] then leader=rows[1] end
    if leader then self:TravelMapTeleporterEntry(leader) else EPC:Print("No group leader is available to travel to.") end
end

function T:MapTeleporterQuickQuest()
    local rows=self:GetMapTeleporterQuestEntries(); if rows[1] and rows[1].travelEntry then self:TravelMapTeleporterEntry(rows[1]) else EPC:Print("No active quest has an available travel route.") end
end

local ShowMapTeleporterContextMenuImplArch

function T:ShowMapTeleporterContextMenu(...)

    return ShowMapTeleporterContextMenuImplArch(self, ...)

end

ShowMapTeleporterContextMenuImplArch = function(self, entry, owner)
    if not entry or type(ClearMenu)~="function" or type(AddMenuItem)~="function" or type(ShowMenu)~="function" then return false end
    ClearMenu()
    AddMenuItem(self:IsMapTeleporterFavorite(entry) and "Remove Favorite" or "Add Favorite", function() self:ToggleMapTeleporterFavorite(entry) end)
    if clean(entry.displayName,"")~="" and (entry.kind=="GROUP" or entry.kind=="FRIEND" or entry.kind=="GUILD") then
        AddMenuItem("Whisper", function() if type(StartChatInput)=="function" then StartChatInput("/w "..tostring(entry.displayName).." ") end end)
        AddMenuItem("Visit Primary Residence", function() if type(JumpToHouse)=="function" then pcall(JumpToHouse,entry.displayName) end end)
        AddMenuItem("Invite to Group", function()
            if type(TryGroupInviteByName)=="function" then pcall(TryGroupInviteByName,entry.displayName,false,true)
            elseif type(GroupInviteByName)=="function" then pcall(GroupInviteByName,entry.displayName) end
        end)
        AddMenuItem((EPC.saved and EPC.saved.mapTeleporterBlacklistPlayers and EPC.saved.mapTeleporterBlacklistPlayers[lower(entry.displayName)]) and "Unblacklist Player" or "Blacklist Player", function() self:ToggleMapTeleporterPlayerBlacklist(entry) end)
    end
    if clean(entry.zoneName,"")~="" then
        AddMenuItem((EPC.saved and EPC.saved.mapTeleporterBlacklistZones and EPC.saved.mapTeleporterBlacklistZones[mtZoneKey02966(entry)]) and "Unblacklist Zone" or "Blacklist Zone", function() self:ToggleMapTeleporterZoneBlacklist(entry) end)
    end
    if entry.kind=="HOUSE" and type(RequestJumpToHouse)=="function" then
        AddMenuItem("Travel Inside", function() pcall(RequestJumpToHouse,entry.houseId,false) end)
        AddMenuItem("Travel Outside", function() pcall(RequestJumpToHouse,entry.houseId,true) end)
    end
    if entry.canTravel~=false or entry.travelEntry then AddMenuItem("Travel Now",function() self:TravelMapTeleporterEntry(entry) end) end
    ShowMenu(owner)
    self:RaiseMapTeleporterPopupSurfacesDeferred02968()
    return true
end

SetMapTeleporterModeImplArch = function(self, mode)
    local valid={}; for _,m in ipairs(MAP_TELEPORTER_MODES_02966) do valid[m[1]]=true end
    self.mapTeleporterMode=valid[mode] and mode or "ALL"; self.mapTeleporterPage=1; self:RefreshMapTeleporter()
end

local HideMapCompletionForTeleporterImplArch

function T:HideMapCompletionForTeleporter(...)

    return HideMapCompletionForTeleporterImplArch(self, ...)

end

HideMapCompletionForTeleporterImplArch = function(self, hide)
    self.mapTeleporterHiddenCompletion=self.mapTeleporterHiddenCompletion or {}
    local candidates={"ZO_WorldMapZoneStoryTopLevel","ZO_WorldMapZoneStory","ZO_WorldMapZoneStoryKeyboard","ZO_WorldMapZoneStoryPane","ZO_WorldMapZoneGuide","ZO_WorldMapZoneGuideKeyboard"}
    for _,name in ipairs(candidates) do
        local c=_G and _G[name] or nil
        if c and type(c.SetHidden)=="function" then
            if hide then
                if self.mapTeleporterHiddenCompletion[name]==nil and type(c.IsHidden)=="function" then local ok,v=pcall(c.IsHidden,c); if ok then self.mapTeleporterHiddenCompletion[name]=v==true end end
                pcall(c.SetHidden,c,true)
            elseif self.mapTeleporterHiddenCompletion[name]~=nil then
                pcall(c.SetHidden,c,self.mapTeleporterHiddenCompletion[name]); self.mapTeleporterHiddenCompletion[name]=nil
            end
        end
    end
end

DockMapTeleporterToWorldMapImplArch = function(self)
    local root=self.mapTeleporter; if not root then return end
    local mapControl=self:GetMapTeleporterMapControl(); root:ClearAnchors()
    if mapControl then
        local top=safeNumber(mapControl:GetTop(),0); local left=safeNumber(mapControl:GetLeft(),0); local bottom=safeNumber(mapControl:GetBottom(),safeNumber(GuiRoot:GetHeight(),900))
        local width=math.max(500,left); local height=math.max(560,bottom-top)
        root:SetDimensions(width,height); root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,0,top); root:SetClampedToScreen(false)
    else
        local h=math.max(560,safeNumber(GuiRoot and GuiRoot:GetHeight(),900)-16); root:SetDimensions(500,h); root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,0,8); root:SetClampedToScreen(true)
    end
    self:LayoutMapTeleporter()
end

LayoutMapTeleporterImplArch = function(self)
    local root=self.mapTeleporter; if not root then return end
    local startY=236; local footerReserve=44; local height=math.max(560,safeNumber(root:GetHeight(),700)); local visibleRows=safeNumber(EPC.saved and EPC.saved.mapTeleporterVisibleRows,15); visibleRows=math.max(8,math.min(20,visibleRows)); root.visibleRows=visibleRows
    local available=math.max(260,height-startY-footerReserve); local rowH=math.max(28,math.min(42,math.floor(available/visibleRows)))
    for i,row in ipairs(root.rows or {}) do row:ClearAnchors(); row:SetAnchor(TOPLEFT,root,TOPLEFT,10,startY+((i-1)*rowH)); row:SetAnchor(TOPRIGHT,root,TOPRIGHT,-10,startY+((i-1)*rowH)); row:SetHeight(math.max(26,rowH-2)); row:SetHidden(i>visibleRows or row.entry==nil) end
end

CreateMapTeleporterImplArch = function(self)
    if self.mapTeleporter then return self.mapTeleporter end
    if not WINDOW_MANAGER or not GuiRoot then return nil end
    local wm=WINDOW_MANAGER; local root=wm:CreateTopLevelWindow("EAS_WorldMapTeleporter02966")
    root:SetDimensions(500,math.max(560,safeNumber(GuiRoot:GetHeight(),900)-16)); root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,0,8); root:SetDrawTier(DT_HIGH); root:SetDrawLayer(DL_OVERLAY); root:SetDrawLevel(90); root:SetMouseEnabled(true); root:SetClampedToScreen(false); root:SetHidden(true)
    local bg=mtBackdrop(root,0.012,0.018,0.032,0.995); bg:SetAnchorFill(root); root.bg=bg
    local title=mtLabel(root,"MAP TELEPORTER","ZoFontWinH2",1.00,0.78,0.24,TEXT_ALIGN_CENTER); title:SetAnchor(TOPLEFT,root,TOPLEFT,10,5); title:SetAnchor(TOPRIGHT,root,TOPRIGHT,-10,5); title:SetHeight(30); root.title=title
    local sub=mtLabel(root,"Zones | map | quests | players | wayshrines | houses | favorites","ZoFontGameSmall",0.72,0.76,0.82,TEXT_ALIGN_CENTER); sub:SetAnchor(TOPLEFT,root,TOPLEFT,10,34); sub:SetAnchor(TOPRIGHT,root,TOPRIGHT,-10,34); sub:SetHeight(18)
    local function quick(text,x,w,cb)
        local b=wm:CreateControl(nil,root,CT_BUTTON); b:SetDimensions(w,24); b:SetAnchor(TOPLEFT,root,TOPLEFT,x,56); b:SetFont("ZoFontGameSmall"); b:SetText(text); b:SetNormalFontColor(0.84,0.86,0.88,1); b:SetMouseOverFontColor(1,0.78,0.24,1); b:SetHandler("OnClicked",cb); return b
    end
    root.home=quick("HOME",12,72,function() self:MapTeleporterQuickHome(false) end)
    root.homeOut=quick("HOME OUT",88,82,function() self:MapTeleporterQuickHome(true) end)
    root.leader=quick("LEADER",174,72,function() self:MapTeleporterQuickLeader() end)
    root.questQuick=quick("QUEST",250,68,function() self:MapTeleporterQuickQuest() end)
    root.sort=quick("SORT",322,60,function()
        local order={"SMART","ZONE","SOURCE","PLAYER_COUNT","MOST_USED","LAST_USED"}; local cur=(EPC.saved and EPC.saved.mapTeleporterSortMode) or "SMART"; local idx=1; for i,v in ipairs(order) do if v==cur then idx=i break end end; idx=(idx%#order)+1; EPC.saved.mapTeleporterSortMode=order[idx]; self:RefreshMapTeleporter()
    end)
    local function createSearch(labelText,x,width,field)
        local lbl=mtLabel(root,labelText,"ZoFontGameSmall",0.82,0.83,0.76); lbl:SetAnchor(TOPLEFT,root,TOPLEFT,x,86); lbl:SetDimensions(width,16)
        local boxBg=mtBackdrop(root,0.028,0.038,0.057,0.99); boxBg:SetAnchor(TOPLEFT,root,TOPLEFT,x,103); boxBg:SetDimensions(width,28)
        local edit=wm:CreateControl(nil,boxBg,CT_EDITBOX); edit:SetAnchor(TOPLEFT,boxBg,TOPLEFT,7,1); edit:SetAnchor(BOTTOMRIGHT,boxBg,BOTTOMRIGHT,-7,-1); edit:SetFont("ZoFontGame"); edit:SetColor(.95,.95,.92,1); edit:SetMaxInputChars(40); edit:SetText(self[field] or ""); edit:SetMouseEnabled(true)
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end; if edit.SetEditEnabled then edit:SetEditEnabled(true) end
        local function focus(c) if c and c.TakeFocus then c:TakeFocus() end end; edit:SetHandler("OnMouseDown",focus); edit:SetHandler("OnMouseUp",function(c,_,inside) if inside~=false then focus(c) end end)
        edit:SetHandler("OnEnter",function(c) if c.LoseFocus then c:LoseFocus() end end); edit:SetHandler("OnEscape",function(c) if c.LoseFocus then c:LoseFocus() end end)
        edit:SetHandler("OnTextChanged",function(c) self[field]=c:GetText() or ""; self.mapTeleporterPage=1; self:RefreshMapTeleporter() end); return edit
    end
    local w=math.max(170,math.floor((safeNumber(root:GetWidth(),500)-34)/2)); root.playerSearch=createSearch("PLAYER OR DESTINATION",12,w,"mapTeleporterPlayerSearch"); root.zoneSearch=createSearch("ZONE",22+w,w,"mapTeleporterZoneSearch")
    root.tabs={}; local tabGap=4; local cols=6; local tabW=math.max(58,math.floor((safeNumber(root:GetWidth(),500)-20-(tabGap*(cols-1)))/cols))
    for i,spec in ipairs(MAP_TELEPORTER_MODES_02966) do local row=math.floor((i-1)/cols); local col=(i-1)%cols; local b=wm:CreateControl(nil,root,CT_BUTTON); b:SetDimensions(tabW,25); b:SetAnchor(TOPLEFT,root,TOPLEFT,10+col*(tabW+tabGap),139+row*28); b:SetFont("ZoFontGameSmall"); b:SetText(spec[2]); b:SetNormalFontColor(.82,.84,.86,1); b:SetMouseOverFontColor(1,.78,.24,1); b:SetHandler("OnClicked",function() self:SetMapTeleporterMode(spec[1]) end); root.tabs[spec[1]]=b end
    local stats=mtLabel(root,"","ZoFontGameSmall",.72,.76,.82); stats:SetAnchor(TOPLEFT,root,TOPLEFT,12,198); stats:SetAnchor(TOPRIGHT,root,TOPRIGHT,-12,198); stats:SetHeight(18); root.stats=stats
    local sortInfo=mtLabel(root,"","ZoFontGameSmall",.58,.63,.70,TEXT_ALIGN_RIGHT); sortInfo:SetAnchor(TOPRIGHT,root,TOPRIGHT,-12,216); sortInfo:SetDimensions(220,16); root.sortInfo=sortInfo
    root.rows={}; local maxRows=20
    for i=1,maxRows do
        local row=wm:CreateControl(nil,root,CT_BUTTON); row:SetMouseEnabled(true); local rbg=mtBackdrop(row,.022,.030,.047,.88); rbg:SetAnchorFill(row); row.bg=rbg
        row.star=wm:CreateControl(nil,row,CT_BUTTON); row.star:SetDimensions(28,24); row.star:SetAnchor(LEFT,row,LEFT,4,0); row.star:SetFont("ZoFontGameBold"); row.star:SetText("+"); row.star:SetNormalFontColor(.72,.72,.72,1); row.star:SetMouseOverFontColor(1,.78,.24,1); row.star:SetHandler("OnClicked",function(c) if row.entry then self:ToggleMapTeleporterFavorite(row.entry) end end)
        row.name=mtLabel(row,"","ZoFontGameBold",.96,.96,.92); row.name:SetAnchor(TOPLEFT,row,TOPLEFT,36,2); row.name:SetAnchor(TOPRIGHT,row,TOPRIGHT,-100,2); row.name:SetHeight(18)
        row.zone=mtLabel(row,"","ZoFontGameSmall",.67,.74,.82); row.zone:SetAnchor(BOTTOMLEFT,row,BOTTOMLEFT,36,-2); row.zone:SetAnchor(BOTTOMRIGHT,row,BOTTOMRIGHT,-100,-2); row.zone:SetHeight(16)
        row.source=mtLabel(row,"","ZoFontGameSmall",1,.78,.24,TEXT_ALIGN_RIGHT); row.source:SetAnchor(TOPRIGHT,row,TOPRIGHT,-7,2); row.source:SetDimensions(88,17)
        row.status=mtLabel(row,"","ZoFontGameSmall",.50,.92,.62,TEXT_ALIGN_RIGHT); row.status:SetAnchor(BOTTOMRIGHT,row,BOTTOMRIGHT,-7,-2); row.status:SetDimensions(88,16)
        row:SetHandler("OnMouseEnter",function(c) if c.entry then c.bg:SetCenterColor(.07,.09,.13,.98) end end); row:SetHandler("OnMouseExit",function(c) if c.entry then c.bg:SetCenterColor(.022,.030,.047,.88) end end)
        row:SetHandler("OnMouseUp",function(c,button,inside) if not inside or not c.entry then return end; if button==MOUSE_BUTTON_INDEX_RIGHT then self:ShowMapTeleporterContextMenu(c.entry,c) else self:TravelMapTeleporterEntry(c.entry) end end)
        row:SetHidden(true); root.rows[i]=row
    end
    local prev=wm:CreateControl(nil,root,CT_BUTTON); prev:SetDimensions(72,26); prev:SetAnchor(BOTTOMLEFT,root,BOTTOMLEFT,12,-8); prev:SetFont("ZoFontGameBold"); prev:SetText("PREVIOUS"); prev:SetNormalFontColor(.85,.86,.88,1); prev:SetMouseOverFontColor(1,.78,.24,1); prev:SetHandler("OnClicked",function() self:ChangeMapTeleporterPage(-1) end); root.prev=prev
    local page=mtLabel(root,"1 / 1","ZoFontGame",.76,.79,.84,TEXT_ALIGN_CENTER); page:SetAnchor(BOTTOM,root,BOTTOM,0,-9); page:SetDimensions(160,24); root.page=page
    local nextB=wm:CreateControl(nil,root,CT_BUTTON); nextB:SetDimensions(72,26); nextB:SetAnchor(BOTTOMRIGHT,root,BOTTOMRIGHT,-12,-8); nextB:SetFont("ZoFontGameBold"); nextB:SetText("NEXT"); nextB:SetNormalFontColor(.85,.86,.88,1); nextB:SetMouseOverFontColor(1,.78,.24,1); nextB:SetHandler("OnClicked",function() self:ChangeMapTeleporterPage(1) end); root.next=nextB
    root:SetHandler("OnMouseWheel",function(_,delta) self:ChangeMapTeleporterPage(delta<0 and 1 or -1) end); self.mapTeleporter=root; self:DockMapTeleporterToWorldMap(); return root
end

RefreshMapTeleporterImplArch = function(self)
    local root=self.mapTeleporter; if not root or root:IsHidden() then return end; self:DockMapTeleporterToWorldMap(); local entries=self:BuildMapTeleporterEntries(); self.mapTeleporterEntries=entries
    local perPage=safeNumber(root.visibleRows,15); local pages=math.max(1,math.ceil(#entries/perPage)); local page=math.max(1,math.min(safeNumber(self.mapTeleporterPage,1),pages)); self.mapTeleporterPage=page; local first=((page-1)*perPage)+1
    local mode=self.mapTeleporterMode or "ALL"; root.stats:SetText(string.format("%d DESTINATION%s  |  %s",#entries,#entries==1 and "" or "S",mode)); root.sortInfo:SetText("SORT: "..tostring((EPC.saved and EPC.saved.mapTeleporterSortMode) or "SMART")); root.page:SetText(string.format("PAGE %d / %d",page,pages)); root.prev:SetEnabled(page>1); root.next:SetEnabled(page<pages)
    for m,b in pairs(root.tabs or {}) do b:SetNormalFontColor(m==mode and 1.00 or .82,m==mode and .78 or .84,m==mode and .24 or .86,1) end
    for i,row in ipairs(root.rows or {}) do
        local e=i<=perPage and entries[first+i-1] or nil; row.entry=e
        if e then
            row:SetHidden(false); row.star:SetText(self:IsMapTeleporterFavorite(e) and "*" or "+"); row.star:SetNormalFontColor(self:IsMapTeleporterFavorite(e) and 1.00 or .72,self:IsMapTeleporterFavorite(e) and .78 or .72,self:IsMapTeleporterFavorite(e) and .24 or .72,1)
            local name=clean(e.displayName,e.name or e.zoneName or "Destination"); if e.kind=="ZONE" then name=e.zoneName elseif e.kind=="QUEST" then name=e.name end; row.name:SetText(name)
            local detail=clean(e.zoneName,"Unknown location"); if e.kind=="ZONE" then detail=string.format("%d online player%s%s",safeNumber(e.playerCount,0),safeNumber(e.playerCount,0)==1 and "" or "s",e.travelEntry and ("  |  via "..clean(e.travelEntry.name,e.travelEntry.kind)) or "") elseif e.kind=="HOUSE" and clean(e.characterName,"")~="" then detail=detail.."   "..e.characterName elseif e.kind=="QUEST" then detail=detail..(e.travelEntry and ("  |  via "..clean(e.travelEntry.name,e.travelEntry.kind)) or "") elseif clean(e.characterName,"")~="" and lower(e.characterName)~=lower(e.displayName or "") then detail=e.characterName.."   "..detail end; row.zone:SetText(detail)
            row.source:SetText(e.sourceText or (e.kind=="FRIEND" and "FRIEND" or e.kind or "TRAVEL")); row.status:SetText(e.canTravel==false and (e.statusText or "BLOCKED") or (e.statusText or e.costText or "TRAVEL")); if self:IsMapTeleporterBlacklisted(e) then row.status:SetColor(.95,.38,.34,1) elseif e.canTravel==false then row.status:SetColor(.95,.38,.34,1) elseif e.statusText=="FREE" or e.kind=="GROUP" or e.kind=="FRIEND" or e.kind=="GUILD" or e.kind=="HOUSE" then row.status:SetColor(.50,.92,.62,1) else row.status:SetColor(.45,.90,1,1) end
        else row:SetHidden(true) end
    end
    self:LayoutMapTeleporter()
end

SetMapTeleporterVisibleImplArch = function(self, visible)
    local root=self:CreateMapTeleporter(); if not root then return end; visible=visible==true and EPC.saved and EPC.saved.mapTeleporterEnabled~=false; root:SetHidden(not visible); self:HideMapCompletionForTeleporter(visible)
    if visible then self.mapTeleporterPage=self.mapTeleporterPage or 1; self.mapTeleporterMode=self.mapTeleporterMode or "ALL"; self:DockMapTeleporterToWorldMap(); self:RefreshMapTeleporter(); if EVENT_MANAGER then EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh"); EPC.Runtime:RegisterUpdate("Travel", "MapTeleporterRefresh",4000,function() if EPC.Travel and EPC.Travel.mapTeleporter and not EPC.Travel.mapTeleporter:IsHidden() and EPC.Travel:IsMapTeleporterMapShowing() then EPC.Travel:HideMapCompletionForTeleporter(true); EPC.Travel:RefreshMapTeleporter() else EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh") end end) end
    elseif EVENT_MANAGER then EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh") end
end

-- ============================================================================
-- v0.29.66 - BeamMeUp-style extended destination views and travel tools.
-- This is an independent Suite implementation using ESO's public APIs.
-- ============================================================================
MAP_TELEPORTER_MODES_02966 = {
    {"ALL", "ALL"}, {"ZONES", "ZONES"}, {"MAP", "MAP"}, {"ITEMS", "ITEMS"}, {"DELVES", "DELVES"}, {"QUESTS", "QUESTS"},
    {"GROUP", "GROUP"}, {"FRIENDS", "FRIENDS"}, {"GUILD", "GUILD"}, {"GUILDS", "GUILD HOMES"}, {"SHRINES", "SHRINES"}, {"HOUSES", "HOUSES"},
    {"PLAYER_HOMES", "PLAYER HOMES"}, {"DUNGEONS", "DUNGEONS"}, {"INSTANCES", "INSTANCES"}, {"LEADS", "LEADS"}, {"FAVORITES", "FAVORITES"}, {"BLOCKED", "BLOCKED"},
}

local function mtConstEquals02966(value, ...)
    for i = 1, select("#", ...) do
        local constantName = select(i, ...)
        local constantValue = _G and _G[constantName] or nil
        if constantValue ~= nil and value == constantValue then return true end
    end
    return false
end

function T:GetMapTeleporterZoneNameCache()
    if self.mapTeleporterZoneNameCache then return self.mapTeleporterZoneNameCache end
    local rows = {}
    local count = 0
    if type(GetNumZones) == "function" then
        local ok, v = pcall(GetNumZones)
        if ok then count = safeNumber(v, 0) end
    end
    for zoneIndex = 1, count do
        local zoneName = ""
        if type(GetZoneNameByIndex) == "function" then
            local ok, v = pcall(GetZoneNameByIndex, zoneIndex)
            if ok then zoneName = clean(v, "") end
        end
        if zoneName ~= "" then
            local zoneId = 0
            if type(GetZoneId) == "function" then
                local ok, v = pcall(GetZoneId, zoneIndex)
                if ok then zoneId = safeNumber(v, 0) end
            end
            rows[#rows + 1] = { zoneName = zoneName, zoneLower = lower(zoneName), zoneId = zoneId, zoneIndex = zoneIndex }
        end
    end
    table.sort(rows, function(a, b) return #a.zoneLower > #b.zoneLower end)
    self.mapTeleporterZoneNameCache = rows
    return rows
end

function T:InferMapTeleporterZoneFromText(text)
    local haystack = lower(clean(text, ""))
    if haystack == "" then return 0, "" end
    for _, zone in ipairs(self:GetMapTeleporterZoneNameCache()) do
        if zone.zoneLower ~= "" and string.find(haystack, zone.zoneLower, 1, true) then
            return safeNumber(zone.zoneId, 0), zone.zoneName
        end
    end
    return 0, ""
end

function T:GetMapTeleporterLeadEntries()
    local rows = {}
    local finder = EPC.AntiquityLeadFinder
    if not finder or type(finder.BuildEntries) ~= "function" then return rows end
    local ok, leads = pcall(finder.BuildEntries, finder)
    if not ok or type(leads) ~= "table" then return rows end
    local snapshot = self:GetMapTeleporterSnapshot()
    local social = self:GetMapTeleporterSocialEntries()
    local shrines = self:GetWayshrines(snapshot)
    local houses = self:GetMapTeleporterHouseEntries()
    for _, lead in ipairs(leads) do
        if lead.haveLead == true then
            local zoneId = safeNumber(lead.scryZoneId, 0)
            local zoneName = clean(lead.scryZone, "")
            local route = self:GetMapTeleporterBestRouteForZone(zoneId, zoneName, social, shrines, houses)
            rows[#rows + 1] = {
                kind = "LEAD", key = "L:" .. tostring(lead.antiquityId or 0), favoriteKey = "LEAD:" .. tostring(lead.antiquityId or 0),
                antiquityId = lead.antiquityId, name = clean(lead.name, "Antiquity Lead"), displayName = clean(lead.name, "Antiquity Lead"),
                zoneId = zoneId, zoneName = zoneName ~= "" and zoneName or "Unknown scry zone", travelEntry = route,
                canTravel = route ~= nil, statusText = route and ((route.kind == "GROUP" or route.kind == "FRIEND" or route.kind == "GUILD" or route.kind == "HOUSE") and "FREE" or (route.costText or "TRAVEL")) or "NO ROUTE",
                sourceText = "LEAD", sourceDetail = clean(lead.sourceShort, "Scryable lead"),
            }
        end
    end
    return rows
end

local GetMapTeleporterItemEntriesImplArch

function T:GetMapTeleporterItemEntries(...)

    return GetMapTeleporterItemEntriesImplArch(self, ...)

end

GetMapTeleporterItemEntriesImplArch = function(self)
    local rows, grouped = {}, {}
    local snapshot = self:GetMapTeleporterSnapshot()
    local social = self:GetMapTeleporterSocialEntries()
    local shrines = self:GetWayshrines(snapshot)
    local houses = self:GetMapTeleporterHouseEntries()
    local bags = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    local treasureType = _G and _G.SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP or nil
    local surveyType = _G and _G.SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT or nil

    for _, bagId in ipairs(bags) do
        if bagId ~= nil and type(GetBagSize) == "function" then
            local okSize, bagSize = pcall(GetBagSize, bagId)
            bagSize = okSize and safeNumber(bagSize, 0) or 0
            for slotIndex = 0, bagSize - 1 do
                local itemName = ""
                if type(GetItemName) == "function" then
                    local ok, v = pcall(GetItemName, bagId, slotIndex)
                    if ok then itemName = clean(v, "") end
                end
                if itemName ~= "" then
                    local itemType, specializedType = nil, nil
                    if type(GetItemType) == "function" then
                        local ok, a, b = pcall(GetItemType, bagId, slotIndex)
                        if ok then itemType, specializedType = a, b end
                    elseif type(GetItemLink) == "function" and type(GetItemLinkItemType) == "function" then
                        local okLink, link = pcall(GetItemLink, bagId, slotIndex, LINK_STYLE_DEFAULT or 0)
                        if okLink and link and link ~= "" then
                            local ok, a, b = pcall(GetItemLinkItemType, link)
                            if ok then itemType, specializedType = a, b end
                        end
                    end
                    local itemId = 0
                    if type(GetItemId) == "function" then local okId, vId = pcall(GetItemId, bagId, slotIndex); if okId then itemId = safeNumber(vId, 0) end end
                    local lname = lower(itemName)
                    local isTreasure = (treasureType ~= nil and specializedType == treasureType) or string.find(lname, "treasure map", 1, true) ~= nil
                    local isSurvey = (surveyType ~= nil and specializedType == surveyType) or string.find(lname, "survey", 1, true) ~= nil
                    local isClue = string.find(lname, "clue", 1, true) ~= nil and (ITEMTYPE_TROPHY == nil or itemType == ITEMTYPE_TROPHY)
                    if isTreasure or isSurvey or isClue then
                        local stack = 1
                        if type(GetSlotStackSize) == "function" then local ok, v = pcall(GetSlotStackSize, bagId, slotIndex); if ok then stack = math.max(1, safeNumber(v, 1)) end end
                        local key = lname
                        local existing = grouped[key]
                        if existing then existing.stack = existing.stack + stack
                        else
                            local zoneId, zoneName = self:InferMapTeleporterZoneFromText(itemName)
                            local route = zoneName ~= "" and self:GetMapTeleporterBestRouteForZone(zoneId, zoneName, social, shrines, houses) or nil
                            local kindText = isSurvey and "SURVEY" or (isTreasure and "TREASURE" or "CLUE")
                            grouped[key] = {
                                kind = "ITEM", key = "ITEM:" .. key, favoriteKey = "ITEM:" .. key,
                                name = itemName, displayName = itemName, itemId = itemId, zoneId = zoneId, zoneName = zoneName ~= "" and zoneName or "Zone not identified",
                                travelEntry = route, canTravel = route ~= nil, stack = stack, itemKind = kindText,
                                sourceText = kindText, statusText = route and ((route.kind == "GROUP" or route.kind == "FRIEND" or route.kind == "GUILD" or route.kind == "HOUSE") and "FREE" or (route.costText or "TRAVEL")) or "NO ROUTE",
                            }
                        end
                    end
                end
            end
        end
    end
    for _, row in pairs(grouped) do
        if safeNumber(row.stack, 1) > 1 then row.characterName = "Quantity: " .. tostring(row.stack) end
        rows[#rows + 1] = row
    end
    for _, lead in ipairs(self:GetMapTeleporterLeadEntries()) do rows[#rows + 1] = lead end
    return rows
end

local function mtClassifyFastTravelNode02966(name, poiType, zoneIndex)
    if mtConstEquals02966(poiType, "POI_TYPE_DELVE") then return "DELVE" end
    if mtConstEquals02966(poiType, "POI_TYPE_PUBLIC_DUNGEON") then return "PUBLIC DUNGEON" end
    if mtConstEquals02966(poiType, "POI_TYPE_GROUP_DUNGEON", "POI_TYPE_DUNGEON") then return "DUNGEON" end
    if mtConstEquals02966(poiType, "POI_TYPE_TRIAL") then return "TRIAL" end
    if mtConstEquals02966(poiType, "POI_TYPE_ARENA") then return "ARENA" end
    local zoneType = nil
    if zoneIndex and zoneIndex > 0 and type(GetZoneType) == "function" then local ok, v = pcall(GetZoneType, zoneIndex); if ok then zoneType = v end end
    if mtConstEquals02966(zoneType, "ZONE_TYPE_DUNGEON") then return "DUNGEON" end
    local n = lower(name or "")
    if string.find(n, "delve", 1, true) then return "DELVE" end
    if string.find(n, "public dungeon", 1, true) then return "PUBLIC DUNGEON" end
    if string.find(n, "trial", 1, true) then return "TRIAL" end
    if string.find(n, "arena", 1, true) then return "ARENA" end
    if string.find(n, "archive", 1, true) then return "ENDLESS" end
    return "INSTANCE"
end

GetMapTeleporterInstanceEntriesImplArch = function(self)
    local rows, total = {}, 0
    if type(GetNumFastTravelNodes) == "function" then local ok, v = pcall(GetNumFastTravelNodes); if ok then total = safeNumber(v, 0) end end
    local poiIndexFunction = GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices
    for nodeIndex = 1, total do
        local ok, known, name, normalizedX, normalizedY, _, _, poiType, _, locked = pcall(GetFastTravelNodeInfo, nodeIndex)
        if ok and known and not locked and (POI_TYPE_WAYSHRINE == nil or poiType ~= POI_TYPE_WAYSHRINE) then
            local houseId = 0
            if type(GetFastTravelNodeHouseId) == "function" then local hok, hid = pcall(GetFastTravelNodeHouseId, nodeIndex); if hok then houseId = safeNumber(hid, 0) end end
            if houseId <= 0 then
                local zoneIndex = 0
                if type(poiIndexFunction) == "function" then local zok, zidx = pcall(poiIndexFunction, nodeIndex); if zok then zoneIndex = safeNumber(zidx, 0) end end
                local zoneName, zoneId = "Instance", 0
                if zoneIndex > 0 and type(GetZoneNameByIndex) == "function" then local nok, n = pcall(GetZoneNameByIndex, zoneIndex); if nok then zoneName = clean(n, zoneName) end end
                if zoneIndex > 0 and type(GetZoneId) == "function" then local iok, id = pcall(GetZoneId, zoneIndex); if iok then zoneId = safeNumber(id, 0) end end
                local cost = self:GetLiveWayshrineTravelCost(nodeIndex)
                local category = mtClassifyFastTravelNode02966(name, poiType, zoneIndex)
                rows[#rows + 1] = {
                    kind = "INSTANCE", key = "I:" .. tostring(nodeIndex), nodeIndex = nodeIndex,
                    name = clean(name, "Instance"), displayName = clean(name, "Instance"), zoneName = zoneName, zoneId = zoneId, zoneIndex = zoneIndex,
                    normalizedX = tonumber(normalizedX), normalizedY = tonumber(normalizedY),
                    poiType = poiType, instanceCategory = category, costText = safeNumber(cost, 0) <= 0 and "Free" or (formatNumber(cost) .. " gold"),
                    canTravel = true, statusText = "TRAVEL", sourceText = category,
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.instanceCategory ~= b.instanceCategory then return tostring(a.instanceCategory) < tostring(b.instanceCategory) end
        return lower(a.name) < lower(b.name)
    end)
    return rows
end

function T:GetMapTeleporterDelveEntries()
    local rows = {}
    for _, e in ipairs(self:GetMapTeleporterInstanceEntries()) do
        if e.instanceCategory == "DELVE" or e.instanceCategory == "PUBLIC DUNGEON" then rows[#rows + 1] = e end
    end
    return rows
end

function T:GetMapTeleporterDungeonEntries()
    local rows = {}
    for _, e in ipairs(self:GetMapTeleporterInstanceEntries()) do
        local c = e.instanceCategory
        if c == "DUNGEON" or c == "TRIAL" or c == "ARENA" or c == "ENDLESS" then rows[#rows + 1] = e end
    end
    return rows
end

function T:GetMapTeleporterPlayerHomeEntries()
    local rows = {}
    if type(JumpToHouse) ~= "function" then return rows end
    for _, social in ipairs(self:GetMapTeleporterSocialEntries()) do
        local who = clean(social.displayName, "")
        if who ~= "" then
            rows[#rows + 1] = {
                kind = "PLAYER_HOME", key = "PH:" .. lower(who), favoriteKey = "PLAYER_HOME:" .. lower(who),
                name = who .. " - Primary Residence", displayName = who, characterName = social.characterName,
                zoneName = "Player primary residence", canTravel = true, statusText = "FREE", sourceText = "HOME",
            }
        end
    end
    return rows
end

function T:GetMapTeleporterGuildSummaryEntries()
    -- v0.29.330: Guild Homes view. One row per guild membership, traveling to
    -- the guild master's primary residence instead of an arbitrary online member.
    local rows = {}
    local options = self:GetGuildLeaderHomeOptions()
    local ownDisplayName = clean(type(GetDisplayName) == "function" and GetDisplayName() or "", "")

    for _, option in ipairs(options or {}) do
        local guildId = option.guildId
        local guildName = clean(option.guildName, "Guild")
        local leaderName = clean(option.leaderName, "")
        local canTravel = leaderName ~= ""
        local statusText = "VISIT HOME"
        local detail = leaderName ~= "" and ("Guild Master: " .. leaderName .. "  |  Primary Residence") or "Guild Master unavailable"

        if leaderName == "" then
            canTravel = false
            statusText = "LEADER UNKNOWN"
        elseif leaderName == ownDisplayName then
            local houseId = 0
            if type(GetHousingPrimaryHouse) == "function" then
                local ok, v = pcall(GetHousingPrimaryHouse)
                if ok then houseId = safeNumber(v, 0) end
            end
            canTravel = houseId > 0 and type(RequestJumpToHouse) == "function"
            statusText = canTravel and "VISIT HOME" or "NO PRIMARY HOME"
        elseif type(JumpToHouse) ~= "function" then
            canTravel = false
            statusText = "HOME API UNAVAILABLE"
        end

        rows[#rows + 1] = {
            kind = "GUILD_HOME",
            key = "GH:" .. tostring(guildId),
            favoriteKey = "GUILD_HOME:" .. tostring(guildId),
            guildId = guildId,
            guildName = guildName,
            leaderName = leaderName,
            name = guildName,
            displayName = guildName,
            characterName = leaderName,
            zoneName = "Guild leader primary residence",
            sourceDetail = detail,
            canTravel = canTravel,
            statusText = statusText,
            costText = "Free",
            sourceText = "GUILD HOME",
        }
    end

    table.sort(rows, function(a, b) return lower(a.guildName or a.name or "") < lower(b.guildName or b.name or "") end)
    return rows
end

function T:GetMapTeleporterBlockedEntries()
    local rows, seen = {}, {}
    local sources = {
        self:GetMapTeleporterSocialEntries(), self:GetMapTeleporterZoneEntries(), self:GetMapTeleporterHouseEntries(),
        self:GetWayshrines(self:GetMapTeleporterSnapshot()), self:GetMapTeleporterInstanceEntries(), self:GetMapTeleporterPlayerHomeEntries(),
    }
    for _, src in ipairs(sources) do
        for _, e in ipairs(src or {}) do
            local k = mtKey02966(e)
            if not seen[k] and self:IsMapTeleporterBlacklisted(e) then seen[k] = true; rows[#rows + 1] = e end
        end
    end
    return rows
end

function T:GetMapTeleporterUnknownWayshrineZones()
    local zones, total = {}, 0
    if type(GetNumFastTravelNodes) == "function" then local ok, v = pcall(GetNumFastTravelNodes); if ok then total = safeNumber(v, 0) end end
    local poiIndexFunction = GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices
    for nodeIndex = 1, total do
        local ok, known, _, _, _, _, _, poiType, _, locked = pcall(GetFastTravelNodeInfo, nodeIndex)
        local isWayshrine = POI_TYPE_WAYSHRINE == nil or poiType == POI_TYPE_WAYSHRINE
        if ok and not known and not locked and isWayshrine then
            local zoneIndex = 0
            if type(poiIndexFunction) == "function" then local zok, zidx = pcall(poiIndexFunction, nodeIndex); if zok then zoneIndex = safeNumber(zidx, 0) end end
            local zoneName = ""
            if zoneIndex > 0 and type(GetZoneNameByIndex) == "function" then local nok, n = pcall(GetZoneNameByIndex, zoneIndex); if nok then zoneName = clean(n, "") end end
            if zoneName ~= "" then local k = lower(zoneName); zones[k] = (zones[k] or 0) + 1 end
        end
    end
    return zones
end

function T:GetMapTeleporterDiscoveryRouteKey(entry)
    if type(entry) ~= "table" then return "" end
    local kind = lower(entry.kind or "SOCIAL")
    local who = lower(entry.displayName or entry.name or entry.characterName or entry.key or "")
    local zone = lower(entry.zoneName or "")
    if who == "" or zone == "" then return "" end
    return kind .. ":" .. who .. ":" .. zone
end

function T:GetMapTeleporterDiscoveryMemory()
    if not EPC.saved then return {} end
    if type(EPC.saved.mapTeleporterDiscoveryRoutes) ~= "table" then
        EPC.saved.mapTeleporterDiscoveryRoutes = {}
    end
    return EPC.saved.mapTeleporterDiscoveryRoutes
end

function T:IsMapTeleporterWayshrineNodeKnown(nodeIndex)
    nodeIndex = safeNumber(nodeIndex, 0)
    if nodeIndex <= 0 or type(GetFastTravelNodeInfo) ~= "function" then return false end
    local ok, known, _, _, _, _, _, poiType, _, locked = pcall(GetFastTravelNodeInfo, nodeIndex)
    if not ok or locked == true then return false end
    if POI_TYPE_WAYSHRINE ~= nil and poiType ~= POI_TYPE_WAYSHRINE then return false end
    return known == true
end

-- Travel-to-player normally drops the player at a wayshrine.  Learn that landing
-- node after the zone load so the discovery tool never sends the player back to
-- the same already-known shrine on a later discovery pass.
function T:GetMapTeleporterCurrentLandingWayshrine()
    if type(GetMapPlayerPosition) ~= "function" or type(GetFastTravelNodeInfo) ~= "function" then return nil end
    if type(SetMapToPlayerLocation) == "function" then pcall(SetMapToPlayerLocation) end

    local okPos, px, py = pcall(GetMapPlayerPosition, "player")
    px, py = tonumber(px), tonumber(py)
    if not okPos or px == nil or py == nil or (px == 0 and py == 0) then return nil end

    local total = 0
    if type(GetNumFastTravelNodes) == "function" then
        local ok, value = pcall(GetNumFastTravelNodes)
        if ok then total = safeNumber(value, 0) end
    end

    local best, bestDistance = nil, nil
    for nodeIndex = 1, total do
        local ok, known, name, nx, ny, _, _, poiType, shown, locked = pcall(GetFastTravelNodeInfo, nodeIndex)
        local isWayshrine = POI_TYPE_WAYSHRINE == nil or poiType == POI_TYPE_WAYSHRINE
        if ok and known == true and shown == true and locked ~= true and isWayshrine and tonumber(nx) and tonumber(ny) then
            local dx, dy = tonumber(nx) - px, tonumber(ny) - py
            local distance = (dx * dx) + (dy * dy)
            if bestDistance == nil or distance < bestDistance then
                bestDistance = distance
                best = { nodeIndex = nodeIndex, name = clean(name, "Wayshrine"), distance = distance }
            end
        end
    end
    return best
end

function T:IsMapTeleporterDiscoveryRouteExhausted(entry)
    local routeKey = self:GetMapTeleporterDiscoveryRouteKey(entry)
    if routeKey == "" then return false end
    local learned = self:GetMapTeleporterDiscoveryMemory()[routeKey]
    if type(learned) ~= "table" then return false end
    local nodeIndex = safeNumber(learned.nodeIndex, 0)
    -- A learned route is exhausted only while that exact landing wayshrine is
    -- still known.  If ESO ever invalidates the node, the route becomes eligible
    -- for discovery again instead of being permanently blacklisted.
    return nodeIndex > 0 and self:IsMapTeleporterWayshrineNodeKnown(nodeIndex)
end

function T:FinalizeMapTeleporterDiscoveryArrival()
    local pending = self.mapTeleporterDiscoveryPending
    if type(pending) ~= "table" then return end
    self.mapTeleporterDiscoveryPending = nil

    local routeKey = clean(pending.routeKey, "")
    if routeKey ~= "" and type(self.mapTeleporterDiscoveryRetryCounts) == "table" then
        self.mapTeleporterDiscoveryRetryCounts[routeKey] = nil
    end
    local zoneKey = lower(pending.zoneName or "")
    local beforeUnknown = safeNumber(pending.beforeUnknown, 0)
    local unknownNow = self:GetMapTeleporterUnknownWayshrineZones()
    local afterUnknown = safeNumber(unknownNow[zoneKey], 0)
    local landing = self:GetMapTeleporterCurrentLandingWayshrine()

    if routeKey ~= "" and landing and safeNumber(landing.nodeIndex, 0) > 0 then
        local memory = self:GetMapTeleporterDiscoveryMemory()
        memory[routeKey] = {
            nodeIndex = safeNumber(landing.nodeIndex, 0),
            nodeName = clean(landing.name, "Wayshrine"),
            zoneName = clean(pending.zoneName, ""),
            lastUnknownBefore = beforeUnknown,
            lastUnknownAfter = afterUnknown,
            discoveredNew = afterUnknown < beforeUnknown,
        }
    end

    if beforeUnknown > 0 and afterUnknown <= 0 then
        EPC:Print(clean(pending.zoneName, "That zone") .. " has no undiscovered wayshrines left. Skipping it from now on.")
    elseif beforeUnknown > 0 and afterUnknown < beforeUnknown then
        local amount = beforeUnknown - afterUnknown
        EPC:Print("Discovered " .. tostring(amount) .. " new wayshrine" .. (amount == 1 and "" or "s") .. " in " .. clean(pending.zoneName, "the zone") .. ".")
    elseif landing then
        EPC:Print("That route landed at already-discovered " .. clean(landing.name, "wayshrine") .. "; it will not be used again for discovery.")
    end
end

function T:GetMapTeleporterDiscoveryFailureMemory()
    if type(self.mapTeleporterDiscoveryFailedRoutes) ~= "table" then
        self.mapTeleporterDiscoveryFailedRoutes = {}
    end
    return self.mapTeleporterDiscoveryFailedRoutes
end

function T:GetMapTeleporterDiscoveryIdentity(entry)
    if type(entry) ~= "table" then return "" end
    return lower(entry.displayName or entry.name or entry.characterName or entry.key or "")
end

function T:MarkMapTeleporterDiscoveryRouteFailed(entry, reason)
    if type(entry) ~= "table" then return end
    local key = self:GetMapTeleporterDiscoveryRouteKey(entry)
    if key == "" then
        key = lower(entry.kind or "SOCIAL") .. ":" .. self:GetMapTeleporterDiscoveryIdentity(entry) .. ":" .. lower(entry.zoneName or "")
    end
    if key ~= "" then self:GetMapTeleporterDiscoveryFailureMemory()[key] = true end
    local who = clean(entry.displayName or entry.name or entry.characterName, "that player")
    EPC:Print("Skipping " .. who .. (reason and reason ~= "" and (": " .. tostring(reason)) or ".") .. " Trying the next wayshrine route.")
end

function T:IsMapTeleporterDiscoveryRouteFailed(entry)
    if type(entry) ~= "table" then return false end
    local key = self:GetMapTeleporterDiscoveryRouteKey(entry)
    if key == "" then return false end
    return self:GetMapTeleporterDiscoveryFailureMemory()[key] == true
end

-- Refresh a queued social route immediately before travel. Discovery queues can
-- outlive group/friend/guild roster changes, so never trust the original entry.
function T:GetLiveMapTeleporterDiscoveryEntry(entry)
    if type(entry) ~= "table" then return nil, "Destination is no longer available" end
    local wanted = self:GetMapTeleporterDiscoveryIdentity(entry)
    if wanted == "" then return nil, "Player could not be identified" end

    local best = nil
    for _, live in ipairs(self:GetMapTeleporterSocialEntries() or {}) do
        if self:GetMapTeleporterDiscoveryIdentity(live) == wanted then
            -- Prefer the exact queued source, but allow another live social path
            -- to the same player if the original group/friend/guild relation changed.
            if live.kind == entry.kind then
                best = live
                break
            elseif not best then
                best = live
            end
        end
    end

    if not best then return nil, "Player is offline, not found, or no longer available through Group, Friends, or Guild" end
    -- Do not reject best.canTravel here. That flag can be false for a few seconds
    -- after zoning even though the destination is valid. PrepareTravel performs a
    -- fresh jump-availability check and classifies permanent vs transient errors.

    local unknown = self:GetMapTeleporterUnknownWayshrineZones()
    local zoneKey = lower(best.zoneName or "")
    if zoneKey == "" or safeNumber(unknown[zoneKey], 0) <= 0 then
        return nil, "That destination no longer has an undiscovered wayshrine to pursue"
    end
    if self:IsMapTeleporterDiscoveryRouteExhausted(best) then
        return nil, "That landing route is already known"
    end
    if self:IsMapTeleporterDiscoveryRouteFailed(best) then
        return nil, "That route already failed during this discovery run"
    end
    return best, nil
end

function T:GetMapTeleporterDiscoveryRetryMemory()
    if type(self.mapTeleporterDiscoveryRetryCounts) ~= "table" then
        self.mapTeleporterDiscoveryRetryCounts = {}
    end
    return self.mapTeleporterDiscoveryRetryCounts
end

function T:GetMapTeleporterDiscoveryRetryKey(entry)
    local key = self:GetMapTeleporterDiscoveryRouteKey(entry)
    if key ~= "" then return key end
    return lower((entry and entry.kind) or "SOCIAL") .. ":" .. self:GetMapTeleporterDiscoveryIdentity(entry) .. ":" .. lower((entry and entry.zoneName) or "")
end

function T:ScheduleMapTeleporterDiscoveryTransientRetry(entry, reason)
    if type(entry) ~= "table" or not self.mapTeleporterDiscoveryActive then return false end
    local key = self:GetMapTeleporterDiscoveryRetryKey(entry)
    local retries = self:GetMapTeleporterDiscoveryRetryMemory()
    local attempt = safeNumber(retries[key], 0) + 1
    retries[key] = attempt

    -- Two retries are enough to ride out ESO's normal post-zone travel lock.
    -- If the destination remains bad, skip it and continue rather than stopping.
    if attempt > 2 then
        retries[key] = nil
        self:MarkMapTeleporterDiscoveryRouteFailed(entry, tostring(reason or "temporary travel failure") .. " after retries")
        zo_callLater(function()
            if EPC.Travel and EPC.Travel.mapTeleporterDiscoveryActive then
                EPC.Travel:ResumeMapTeleporterAutoDiscovery()
            end
        end, 600)
        return true
    end

    local delay = 2600 + ((attempt - 1) * 1600)
    EPC:Print("Wayshrine discovery: " .. tostring(reason or "destination is temporarily unavailable") .. ". Retrying this route in " .. tostring(math.floor(delay / 100) / 10) .. " seconds.")
    local queuedIndex = safeNumber(self.mapTeleporterDiscoveryIndex, 0)
    zo_callLater(function()
        local travel = EPC.Travel
        if not travel or not travel.mapTeleporterDiscoveryActive then return end
        local candidate = travel.mapTeleporterDiscoveryQueue and travel.mapTeleporterDiscoveryQueue[queuedIndex]
        if not candidate then
            travel:ResumeMapTeleporterAutoDiscovery()
            return
        end
        local started = travel:PrepareMapTeleporterDiscoveryTravel(candidate)
        if started == false then travel:ResumeMapTeleporterAutoDiscovery() end
    end, delay)
    return true
end

function T:ScheduleMapTeleporterDiscoveryFailureWatchdog(pendingToken)
    zo_callLater(function()
        local travel = EPC.Travel
        if not travel or not travel.mapTeleporterDiscoveryActive then return end
        local pending = travel.mapTeleporterDiscoveryPending
        if type(pending) ~= "table" or pending.token ~= pendingToken then return end
        if pending.prepared == true then return end

        local failedEntry = pending.entry
        travel.mapTeleporterDiscoveryPending = nil
        -- No PREPARE event often means ESO is still settling after the previous
        -- teleport. Retry the same route before considering it unusable.
        travel:ScheduleMapTeleporterDiscoveryTransientRetry(failedEntry, "ESO did not start the travel request yet")
    end, 4800)
end

function T:PrepareMapTeleporterDiscoveryTravel(entry)
    if type(entry) ~= "table" then return false end

    local liveEntry, unavailableReason = self:GetLiveMapTeleporterDiscoveryEntry(entry)
    if not liveEntry then
        self:MarkMapTeleporterDiscoveryRouteFailed(entry, unavailableReason)
        return false
    end

    local canLeave, leaveReason = self:CanLeaveNow()
    if not canLeave then
        -- Current-location restrictions immediately after zoning are global and
        -- temporary. Retry this route instead of stopping or burning the queue.
        self:ScheduleMapTeleporterDiscoveryTransientRetry(liveEntry, leaveReason or "travel is temporarily unavailable")
        return true
    end

    -- Re-check the jump result immediately before every discovery jump. The social
    -- list's canTravel value may be stale after a loading screen.
    local canJump, jumpResult = getJumpAvailability(safeNumber(liveEntry.zoneId, 0))
    if not canJump then
        local reason = jumpResultText(jumpResult)
        if isPermanentJumpFailure(jumpResult) then
            self:MarkMapTeleporterDiscoveryRouteFailed(liveEntry, reason)
            return false
        end
        self:ScheduleMapTeleporterDiscoveryTransientRetry(liveEntry, reason)
        return true
    end

    local zoneKey = lower(liveEntry.zoneName or "")
    local unknown = self:GetMapTeleporterUnknownWayshrineZones()
    local count = safeNumber(unknown[zoneKey], 0)
    if count <= 0 then return false end

    -- Keep the queue fresh if the player changed social source or zone.
    local index = safeNumber(self.mapTeleporterDiscoveryIndex, 0)
    if index > 0 and type(self.mapTeleporterDiscoveryQueue) == "table" then
        self.mapTeleporterDiscoveryQueue[index] = liveEntry
    end

    -- The fresh checks above won. Do not let a stale row flag block the request.
    liveEntry.canTravel = true
    liveEntry.statusText = "Ready"

    self.mapTeleporterDiscoveryAttemptSerial = safeNumber(self.mapTeleporterDiscoveryAttemptSerial, 0) + 1
    local token = self.mapTeleporterDiscoveryAttemptSerial
    self.mapTeleporterDiscoveryPending = {
        routeKey = self:GetMapTeleporterDiscoveryRouteKey(liveEntry),
        zoneName = clean(liveEntry.zoneName, ""),
        beforeUnknown = count,
        entry = liveEntry,
        token = token,
        prepared = false,
    }

    local started = self:TravelMapTeleporterEntry(liveEntry)
    if started == false then
        self.mapTeleporterDiscoveryPending = nil
        self:ScheduleMapTeleporterDiscoveryTransientRetry(liveEntry, "ESO rejected the travel request")
        return true
    end

    self:ScheduleMapTeleporterDiscoveryFailureWatchdog(token)
    return true
end

function T:GetNextUsefulMapTeleporterDiscoveryEntry(startIndex)
    if type(self.mapTeleporterDiscoveryQueue) ~= "table" then return nil, nil end
    local unknown = self:GetMapTeleporterUnknownWayshrineZones()
    local index = math.max(1, safeNumber(startIndex, 1))
    while index <= #self.mapTeleporterDiscoveryQueue do
        local entry = self.mapTeleporterDiscoveryQueue[index]
        local zoneKey = lower(entry and entry.zoneName or "")
        local remaining = safeNumber(unknown[zoneKey], 0)
        if entry and remaining > 0
            and not self:IsMapTeleporterDiscoveryRouteExhausted(entry)
            and not self:IsMapTeleporterDiscoveryRouteFailed(entry) then
            entry.discoveryUnknownCount = remaining
            return entry, index
        end
        index = index + 1
    end
    return nil, nil
end

function T:StartMapTeleporterAutoDiscovery()
    if self.mapTeleporterDiscoveryActive then
        self.mapTeleporterDiscoveryActive = false
        self.mapTeleporterDiscoveryQueue = nil
        self.mapTeleporterDiscoveryIndex = nil
        self.mapTeleporterDiscoveryPending = nil
        self.mapTeleporterDiscoveryFailedRoutes = nil
        self.mapTeleporterDiscoveryRetryCounts = nil
        EPC:Print("Wayshrine discovery stopped.")
        self:RefreshMapTeleporter()
        return
    end

    local unknown = self:GetMapTeleporterUnknownWayshrineZones()
    local queue, usedRoutes = {}, {}
    for _, e in ipairs(self:GetMapTeleporterSocialEntries()) do
        local z = lower(e.zoneName or "")
        local routeKey = self:GetMapTeleporterDiscoveryRouteKey(e)
        if z ~= "" and safeNumber(unknown[z], 0) > 0 and e.canTravel ~= false
            and routeKey ~= "" and not usedRoutes[routeKey]
            and not self:IsMapTeleporterDiscoveryRouteExhausted(e) then
            usedRoutes[routeKey] = true
            e.discoveryUnknownCount = safeNumber(unknown[z], 0)
            queue[#queue + 1] = e
        end
    end

    if #queue == 0 then
        EPC:Print("No new wayshrine discovery routes are available. Known or previously exhausted routes were skipped.")
        return
    end

    table.sort(queue, function(a, b)
        local ua, ub = safeNumber(a.discoveryUnknownCount, 0), safeNumber(b.discoveryUnknownCount, 0)
        if ua ~= ub then return ua > ub end
        local za, zb = lower(a.zoneName or ""), lower(b.zoneName or "")
        if za ~= zb then return za < zb end
        return lower(a.displayName or a.name or "") < lower(b.displayName or b.name or "")
    end)

    self.mapTeleporterDiscoveryActive = true
    self.mapTeleporterDiscoveryFailedRoutes = {}
    self.mapTeleporterDiscoveryRetryCounts = {}
    self.mapTeleporterDiscoveryQueue = queue
    self.mapTeleporterDiscoveryIndex = 0
    self.mapTeleporterDiscoveryPending = nil
    EPC:Print("Wayshrine discovery started: " .. tostring(#queue) .. " unused routes queued. Already-discovered landing routes are skipped.")

    local entry, index = self:GetNextUsefulMapTeleporterDiscoveryEntry(1)
    if not entry then
        self.mapTeleporterDiscoveryActive = false
        self.mapTeleporterDiscoveryQueue = nil
        self.mapTeleporterDiscoveryIndex = nil
        EPC:Print("No useful undiscovered wayshrine routes remain.")
        self:RefreshMapTeleporter()
        return
    end
    self.mapTeleporterDiscoveryIndex = index
    self:PrepareMapTeleporterDiscoveryTravel(entry)
    self:RefreshMapTeleporter()
end

function T:ResumeMapTeleporterAutoDiscovery()
    if not self.mapTeleporterDiscoveryActive or type(self.mapTeleporterDiscoveryQueue) ~= "table" then return end

    -- First learn what the previous jump actually did.  This is what prevents
    -- Discover Wayshrines from repeatedly sending the player to the same known
    -- landing shrine on later runs.
    self:FinalizeMapTeleporterDiscoveryArrival()

    local nextStart = safeNumber(self.mapTeleporterDiscoveryIndex, 0) + 1
    local entry, index = self:GetNextUsefulMapTeleporterDiscoveryEntry(nextStart)
    if not entry then
        self.mapTeleporterDiscoveryActive = false
        self.mapTeleporterDiscoveryQueue = nil
        self.mapTeleporterDiscoveryIndex = nil
        self.mapTeleporterDiscoveryPending = nil
        EPC:Print("Wayshrine discovery route finished. Already-known and completed destinations were skipped.")
        self:RefreshMapTeleporter()
        return
    end

    self.mapTeleporterDiscoveryIndex = index
    zo_callLater(function()
        if EPC.Travel and EPC.Travel.mapTeleporterDiscoveryActive then
            local candidate = EPC.Travel.mapTeleporterDiscoveryQueue and EPC.Travel.mapTeleporterDiscoveryQueue[index]
            if candidate and not EPC.Travel:PrepareMapTeleporterDiscoveryTravel(candidate) then
                EPC.Travel:ResumeMapTeleporterAutoDiscovery()
            end
        end
    end, 2800)
end

function T:IsMapTeleporterVeteranDifficulty()
    if type(ZO_GetPlayerDungeonDifficulty) == "function" and DUNGEON_DIFFICULTY_VETERAN ~= nil then
        local ok, difficulty = pcall(ZO_GetPlayerDungeonDifficulty)
        if ok and difficulty ~= nil then return difficulty == DUNGEON_DIFFICULTY_VETERAN end
    end
    if type(IsUnitUsingVeteranDifficulty) == "function" then
        local ok, value = pcall(IsUnitUsingVeteranDifficulty, "player")
        if ok then return value == true end
    end
    if type(IsGroupUsingVeteranDifficulty) == "function" then
        local ok, value = pcall(IsGroupUsingVeteranDifficulty)
        if ok then return value == true end
    end
    return false
end

function T:ToggleMapTeleporterDungeonDifficulty()
    if type(SetVeteranDifficulty) ~= "function" then EPC:Print("ESO's dungeon difficulty API is unavailable.") return end
    local isVeteran = self:IsMapTeleporterVeteranDifficulty()
    pcall(SetVeteranDifficulty, not isVeteran)
    EPC:Print("Dungeon difficulty requested: " .. (isVeteran and "Normal" or "Veteran") .. ".")
    zo_callLater(function() if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end, 250)
end

function T:GetMapTeleporterDungeonDifficultyText()
    return self:IsMapTeleporterVeteranDifficulty() and "VET" or "NORMAL"
end

BuildMapTeleporterEntriesImplArch = function(self)
    local mode = self.mapTeleporterMode or "ALL"
    local snapshot = self:GetMapTeleporterSnapshot()
    local entries = {}
    if mode == "GROUP" then entries = self:GetGroupMembers(snapshot)
    elseif mode == "FRIENDS" then entries = self:GetFriends(snapshot)
    elseif mode == "GUILD" then entries = self:GetGuildMembers(snapshot)
    elseif mode == "GUILDS" then entries = self:GetMapTeleporterGuildSummaryEntries()
    elseif mode == "ZONES" then entries = self:GetMapTeleporterZoneEntries()
    elseif mode == "MAP" then entries = self:GetMapTeleporterCurrentMapEntries()
    elseif mode == "ITEMS" then entries = self:GetMapTeleporterItemEntries()
    elseif mode == "DELVES" then entries = self:GetMapTeleporterDelveEntries()
    elseif mode == "QUESTS" then entries = self:GetMapTeleporterQuestEntries()
    elseif mode == "SHRINES" then entries = self:GetWayshrines(snapshot)
    elseif mode == "HOUSES" then entries = self:GetMapTeleporterHouseEntries()
    elseif mode == "PLAYER_HOMES" then entries = self:GetMapTeleporterPlayerHomeEntries()
    elseif mode == "DUNGEONS" then entries = self:GetMapTeleporterDungeonEntries()
    elseif mode == "FAVORITES" then entries = self:GetMapTeleporterFavoriteEntries()
    elseif mode == "INSTANCES" then entries = self:GetMapTeleporterInstanceEntries()
    elseif mode == "LEADS" then entries = self:GetMapTeleporterLeadEntries()
    elseif mode == "BLOCKED" then entries = self:GetMapTeleporterBlockedEntries()
    else
        entries = self:GetMapTeleporterSocialEntries()
        if not EPC.saved or EPC.saved.mapTeleporterIncludeHouses ~= false then
            for _, e in ipairs(self:GetMapTeleporterHouseEntries()) do entries[#entries + 1] = e end
        end
    end

    local playerNeedle = lower(self.mapTeleporterPlayerSearch or "")
    local zoneNeedle = lower(self.mapTeleporterZoneSearch or "")
    local filtered = {}
    for _, e in ipairs(entries or {}) do
        local black = self:IsMapTeleporterBlacklisted(e)
        local showBlack = mode == "BLOCKED" or (EPC.saved and EPC.saved.mapTeleporterShowBlacklisted == true)
        local playerHay = lower((e.displayName or "") .. " " .. (e.characterName or "") .. " " .. (e.name or "") .. " " .. (e.sourceDetail or ""))
        local zoneHay = lower((e.zoneName or "") .. " " .. (e.guildName or "") .. " " .. (e.sourceText or ""))
        if (not black or showBlack)
            and (playerNeedle == "" or string.find(playerHay, playerNeedle, 1, true))
            and (zoneNeedle == "" or string.find(zoneHay, zoneNeedle, 1, true)) then
            filtered[#filtered + 1] = e
        end
    end
    self:SortMapTeleporterEntries(filtered)
    return filtered
end

TravelMapTeleporterEntryImplArch = function(self, entry)
    if not entry then return false end
    if entry.travelEntry then return self:TravelMapTeleporterEntry(entry.travelEntry) end
    local canLeave, reason = self:CanLeaveNow()
    if not canLeave then EPC:Print(tostring(reason or "Travel is unavailable") .. ".") return false end
    if entry.canTravel == false then EPC:Print(entry.statusText or "ESO currently blocks this destination.") return false end
    local fn, arg, arg2
    if entry.kind == "GROUP" then fn = JumpToGroupMember; arg = entry.displayName ~= "" and entry.displayName or entry.characterName
    elseif entry.kind == "FRIEND" then fn = JumpToFriend; arg = entry.displayName
    elseif entry.kind == "GUILD" then fn = JumpToGuildMember; arg = entry.displayName
    elseif entry.kind == "SHRINE" or entry.kind == "INSTANCE" then fn = FastTravelToNode; arg = entry.nodeIndex
    elseif entry.kind == "HOUSE" then fn = RequestJumpToHouse; arg = entry.houseId; arg2 = false
    elseif entry.kind == "PLAYER_HOME" then fn = JumpToHouse; arg = entry.displayName
    elseif entry.kind == "GUILD_HOME" then
        local leader = clean(entry.leaderName, "")
        local own = clean(type(GetDisplayName) == "function" and GetDisplayName() or "", "")
        if leader == "" then EPC:Print("ESO did not expose the guild master's display name for " .. clean(entry.guildName, "that guild") .. ".") return false end
        if leader == own then
            local houseId = 0
            if type(GetHousingPrimaryHouse) == "function" then local ok, v = pcall(GetHousingPrimaryHouse); if ok then houseId = safeNumber(v, 0) end end
            if houseId <= 0 or type(RequestJumpToHouse) ~= "function" then EPC:Print("No primary residence is available for " .. clean(entry.guildName, "that guild") .. ".") return false end
            fn = RequestJumpToHouse; arg = houseId; arg2 = false
        else
            fn = JumpToHouse; arg = leader
        end
    elseif entry.kind == "LEAD" and EPC.AntiquityLeadFinder and EPC.AntiquityLeadFinder.Toggle then EPC.AntiquityLeadFinder:Toggle(); return true
    end
    if type(fn) ~= "function" then EPC:Print("ESO's travel API is unavailable for this destination.") return false end
    self:RecordMapTeleporterTravel(entry)
    EPC:Print("Traveling to " .. clean(entry.name, entry.displayName or entry.zoneName or "destination") .. ".")
    local ok
    if arg2 ~= nil then ok = pcall(fn, arg, arg2) else ok = pcall(fn, arg) end
    if not ok then EPC:Print("ESO rejected the travel request. The destination or access state may have changed.") return false end

    -- v0.29.156: Suite Teleporter can use social/house jump APIs that bypass
    -- the normal FastTravelToNode hook. Arm the arrival message only after ESO
    -- accepted the travel request so every Teleporter travel path is covered.
    if EPC.WayshrineAutoMessage and type(EPC.WayshrineAutoMessage.ArmSuiteTeleporterTravel) == "function" then
        pcall(EPC.WayshrineAutoMessage.ArmSuiteTeleporterTravel, EPC.WayshrineAutoMessage, entry)
    end
    return true
end

MapTeleporterQuickLeaderImplArch = function(self)
    local rows = self:GetGroupMembers(self:GetMapTeleporterSnapshot())
    local leader = nil
    for _, e in ipairs(rows or {}) do
        if e.unitTag and type(IsUnitGroupLeader) == "function" then local ok, v = pcall(IsUnitGroupLeader, e.unitTag); if ok and v == true then leader = e break end end
    end
    if not leader and rows and rows[1] then leader = rows[1] end
    if leader then self:TravelMapTeleporterEntry(leader) else EPC:Print("No group leader is available to travel to.") end
end

ShowMapTeleporterContextMenuImplArch = function(self, entry, owner)
    if not entry or type(ClearMenu) ~= "function" or type(AddMenuItem) ~= "function" or type(ShowMenu) ~= "function" then return false end
    ClearMenu()
    AddMenuItem(self:IsMapTeleporterFavorite(entry) and "Remove Favorite" or "Add Favorite", function() self:ToggleMapTeleporterFavorite(entry) end)
    local isPlayer = clean(entry.displayName, "") ~= "" and (entry.kind == "GROUP" or entry.kind == "FRIEND" or entry.kind == "GUILD" or entry.kind == "PLAYER_HOME")
    if isPlayer then
        AddMenuItem("Whisper", function() if type(StartChatInput) == "function" then StartChatInput("/w " .. tostring(entry.displayName) .. " ") end end)
        AddMenuItem("Visit Primary Residence", function() if type(JumpToHouse) == "function" then pcall(JumpToHouse, entry.displayName) end end)
        AddMenuItem("Invite to Group", function()
            if type(TryGroupInviteByName) == "function" then pcall(TryGroupInviteByName, entry.displayName, false, true)
            elseif type(GroupInviteByName) == "function" then pcall(GroupInviteByName, entry.displayName) end
        end)
        if entry.kind == "FRIEND" and type(RemoveFriend) == "function" then AddMenuItem("Remove Friend", function() pcall(RemoveFriend, entry.displayName) end)
        elseif entry.kind ~= "FRIEND" and type(RequestFriend) == "function" then AddMenuItem("Add Friend", function() pcall(RequestFriend, entry.displayName, "") end) end
        if entry.kind == "GROUP" and entry.unitTag then
            if type(IsUnitGroupLeader) == "function" then
                local ok, leader = pcall(IsUnitGroupLeader, entry.unitTag)
                if ok and not leader and type(GroupPromote) == "function" then AddMenuItem("Promote to Group Leader", function() pcall(GroupPromote, entry.unitTag) end) end
            end
            if type(GroupKickByName) == "function" then AddMenuItem("Kick from Group", function() pcall(GroupKickByName, entry.displayName) end) end
        end
        AddMenuItem((EPC.saved and EPC.saved.mapTeleporterBlacklistPlayers and EPC.saved.mapTeleporterBlacklistPlayers[lower(entry.displayName)]) and "Unblacklist Player" or "Blacklist Player", function() self:ToggleMapTeleporterPlayerBlacklist(entry) end)
    end
    if clean(entry.zoneName, "") ~= "" and entry.zoneName ~= "Player primary residence" then
        AddMenuItem((EPC.saved and EPC.saved.mapTeleporterBlacklistZones and EPC.saved.mapTeleporterBlacklistZones[mtZoneKey02966(entry)]) and "Unblacklist Zone" or "Blacklist Zone", function() self:ToggleMapTeleporterZoneBlacklist(entry) end)
    end
    if entry.kind == "GUILD_HOME" and entry.canTravel ~= false then
        AddMenuItem("Visit Guild Home", function() self:TravelMapTeleporterEntry(entry) end)
    end
    if entry.kind == "HOUSE" and type(RequestJumpToHouse) == "function" then
        AddMenuItem("Travel Inside", function() pcall(RequestJumpToHouse, entry.houseId, false) end)
        AddMenuItem("Travel Outside", function() pcall(RequestJumpToHouse, entry.houseId, true) end)
        if type(SetHousingPrimaryHouse) == "function" and not entry.isPrimary then AddMenuItem("Set as Primary Residence", function() pcall(SetHousingPrimaryHouse, entry.houseId); zo_callLater(function() if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end, 250) end) end
    end
    if entry.kind == "INSTANCE" and (entry.instanceCategory == "DUNGEON" or entry.instanceCategory == "TRIAL" or entry.instanceCategory == "ARENA") then
        AddMenuItem("Toggle Normal or Veteran", function() self:ToggleMapTeleporterDungeonDifficulty() end)
    end
    if entry.kind == "LEAD" and EPC.AntiquityLeadFinder and EPC.AntiquityLeadFinder.Toggle then AddMenuItem("Open Antiquity Lead Finder", function() EPC.AntiquityLeadFinder:Toggle() end) end
    if safeNumber(entry.zoneId, 0) > 0 or entry.questIndex then AddMenuItem("Show Destination on Map", function() self:ShowMapTeleporterEntryOnMap(entry, false) end) end
    if (entry.kind == "SHRINE" or entry.kind == "INSTANCE") and entry.normalizedX and entry.normalizedY then AddMenuItem("Show on Map and Set Waypoint", function() self:ShowMapTeleporterEntryOnMap(entry, true) end) end
    AddMenuItem("Share Destination in Chat", function() self:ShareMapTeleporterDestination(entry) end)
    if entry.canTravel ~= false or entry.travelEntry then AddMenuItem("Travel Now", function() self:TravelMapTeleporterEntry(entry) end) end
    ShowMenu(owner)
    self:RaiseMapTeleporterPopupSurfacesDeferred02968()
    return true
end

LayoutMapTeleporterImplArch = function(self)
    local root = self.mapTeleporter
    if not root then return end
    local tabCount = #MAP_TELEPORTER_MODES_02966
    local tabRows = math.max(1, math.ceil(tabCount / 6))
    local statsY = 139 + (tabRows * 28) + 3
    if root.stats then root.stats:ClearAnchors(); root.stats:SetAnchor(TOPLEFT, root, TOPLEFT, 12, statsY); root.stats:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, statsY) end
    if root.sortInfo then root.sortInfo:ClearAnchors(); root.sortInfo:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, statsY + 18) end
    local startY = statsY + 38
    local footerReserve = 44
    local height = math.max(560, safeNumber(root:GetHeight(), 700))
    local visibleRows = safeNumber(EPC.saved and EPC.saved.mapTeleporterVisibleRows, 15)
    visibleRows = math.max(8, math.min(20, visibleRows)); root.visibleRows = visibleRows
    local available = math.max(260, height - startY - footerReserve)
    local rowH = math.max(27, math.min(42, math.floor(available / visibleRows)))
    for i, row in ipairs(root.rows or {}) do
        row:ClearAnchors(); row:SetAnchor(TOPLEFT, root, TOPLEFT, 10, startY + ((i - 1) * rowH)); row:SetAnchor(TOPRIGHT, root, TOPRIGHT, -10, startY + ((i - 1) * rowH)); row:SetHeight(math.max(25, rowH - 2)); row:SetHidden(i > visibleRows or row.entry == nil)
    end
end


-- The Favorites view spans every native Suite destination source, not only social rows.
GetMapTeleporterFavoriteEntriesImplArch = function(self)
    local rows, seen = {}, {}
    local snapshot = self:GetMapTeleporterSnapshot()
    local sources = {
        self:GetMapTeleporterSocialEntries(), self:GetMapTeleporterZoneEntries(), self:GetMapTeleporterCurrentMapEntries(),
        self:GetMapTeleporterQuestEntries(), self:GetWayshrines(snapshot), self:GetMapTeleporterHouseEntries(),
        self:GetMapTeleporterPlayerHomeEntries(), self:GetMapTeleporterInstanceEntries(), self:GetMapTeleporterLeadEntries(),
        self:GetMapTeleporterItemEntries(), self:GetMapTeleporterGuildSummaryEntries(),
    }
    for _, source in ipairs(sources) do
        for _, entry in ipairs(source or {}) do
            local key = mtKey02966(entry)
            if key ~= "" and not seen[key] and self:IsMapTeleporterFavorite(entry) then
                seen[key] = true
                rows[#rows + 1] = entry
            end
        end
    end
    return rows
end

function T:ShowMapTeleporterEntryOnMap(entry, setWaypoint)
    if not entry then return false end
    local zoneId = safeNumber(entry.zoneId, 0)
    local mapIndex = 0
    if zoneId > 0 and type(GetMapIndexByZoneId) == "function" then
        local ok, value = pcall(GetMapIndexByZoneId, zoneId)
        if ok then mapIndex = safeNumber(value, 0) end
    end
    if mapIndex > 0 and type(SetMapToMapListIndex) == "function" then
        pcall(SetMapToMapListIndex, mapIndex)
    elseif entry.questIndex and type(SetMapToQuestZone) == "function" then
        pcall(SetMapToQuestZone, entry.questIndex)
    else
        EPC:Print("ESO does not expose a map destination for this row.")
        return false
    end
    if setWaypoint and entry.normalizedX and entry.normalizedY and type(PingMap) == "function"
        and MAP_PIN_TYPE_PLAYER_WAYPOINT ~= nil and MAP_TYPE_LOCATION_CENTERED ~= nil then
        zo_callLater(function()
            pcall(PingMap, MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, entry.normalizedX, entry.normalizedY)
        end, 120)
    end
    zo_callLater(function() if EPC.Travel then EPC.Travel:RefreshMapTeleporter() end end, 180)
    return true
end

function T:ShareMapTeleporterDestination(entry)
    if not entry or type(StartChatInput) ~= "function" then return end
    local name = clean(entry.name, entry.displayName or entry.zoneName or "Destination")
    local zone = clean(entry.zoneName, "")
    local text = "Travel: " .. name
    if zone ~= "" and lower(zone) ~= lower(name) then text = text .. " - " .. zone end
    StartChatInput(text)
end

-- Rebuild the teleporter once with all tabs. This override intentionally uses a
-- new control name so stale controls from older builds cannot collide after reload.
CreateMapTeleporterImplArch = function(self)
    if self.mapTeleporter then return self.mapTeleporter end
    if not WINDOW_MANAGER or not GuiRoot then return nil end
    local wm = WINDOW_MANAGER
    local root = wm:CreateTopLevelWindow("EAS_WorldMapTeleporter02966Full")
    root:SetDimensions(500, math.max(560, safeNumber(GuiRoot:GetHeight(), 900) - 16)); root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 8)
    root:SetDrawTier(DT_HIGH); root:SetDrawLayer(DL_OVERLAY); root:SetDrawLevel(100); root:SetMouseEnabled(true); root:SetClampedToScreen(false); root:SetHidden(true)
    local bg = mtBackdrop(root, 0.012, 0.018, 0.032, 1.0); bg:SetAnchorFill(root); root.bg = bg
    local title = mtLabel(root, "MAP TELEPORTER", "ZoFontWinH2", 1.00, 0.78, 0.24, TEXT_ALIGN_CENTER); title:SetAnchor(TOPLEFT, root, TOPLEFT, 10, 5); title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -10, 5); title:SetHeight(30); root.title = title
    local sub = mtLabel(root, "Players | zones | map | maps/surveys | delves | quests | shrines | homes | dungeons | leads", "ZoFontGameSmall", 0.72, 0.76, 0.82, TEXT_ALIGN_CENTER); sub:SetAnchor(TOPLEFT, root, TOPLEFT, 10, 34); sub:SetAnchor(TOPRIGHT, root, TOPRIGHT, -10, 34); sub:SetHeight(18)

    local quickSpecs = {
        {"HOME", 68, function() self:MapTeleporterQuickHome(false) end},
        {"OUTSIDE", 72, function() self:MapTeleporterQuickHome(true) end},
        {"LEADER", 68, function() self:MapTeleporterQuickLeader() end},
        {"QUEST", 62, function() self:MapTeleporterQuickQuest() end},
        {"DISCOVER", 78, function() self:StartMapTeleporterAutoDiscovery() end},
        {"N/V", 48, function() self:ToggleMapTeleporterDungeonDifficulty() end},
        {"SORT", 54, function()
            local order = {"SMART", "ZONE", "SOURCE", "PLAYER_COUNT", "MOST_USED", "LAST_USED"}
            local cur = (EPC.saved and EPC.saved.mapTeleporterSortMode) or "SMART"; local idx = 1
            for i, v in ipairs(order) do if v == cur then idx = i break end end
            idx = (idx % #order) + 1; EPC.saved.mapTeleporterSortMode = order[idx]; self:RefreshMapTeleporter()
        end},
    }
    root.quickButtons = {}
    local qx = 10
    for _, spec in ipairs(quickSpecs) do
        local b = wm:CreateControl(nil, root, CT_BUTTON); b:SetDimensions(spec[2], 24); b:SetAnchor(TOPLEFT, root, TOPLEFT, qx, 56); b:SetFont("ZoFontGameSmall"); b:SetText(spec[1]); b:SetNormalFontColor(0.84, 0.86, 0.88, 1); b:SetMouseOverFontColor(1, 0.78, 0.24, 1); b:SetHandler("OnClicked", spec[3]); root.quickButtons[#root.quickButtons + 1] = b; qx = qx + spec[2] + 4
    end

    local function createSearch(labelText, x, width, field)
        local lbl = mtLabel(root, labelText, "ZoFontGameSmall", 0.82, 0.83, 0.76); lbl:SetAnchor(TOPLEFT, root, TOPLEFT, x, 86); lbl:SetDimensions(width, 16)
        local boxBg = mtBackdrop(root, 0.028, 0.038, 0.057, 0.99); boxBg:SetAnchor(TOPLEFT, root, TOPLEFT, x, 103); boxBg:SetDimensions(width, 28)
        local edit = wm:CreateControl(nil, boxBg, CT_EDITBOX); edit:SetAnchor(TOPLEFT, boxBg, TOPLEFT, 7, 1); edit:SetAnchor(BOTTOMRIGHT, boxBg, BOTTOMRIGHT, -7, -1); edit:SetFont("ZoFontGame"); edit:SetColor(.95, .95, .92, 1); edit:SetMaxInputChars(50); edit:SetText(self[field] or ""); edit:SetMouseEnabled(true)
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end; if edit.SetEditEnabled then edit:SetEditEnabled(true) end
        local function focus(c) if c and c.TakeFocus then c:TakeFocus() end end
        edit:SetHandler("OnMouseDown", focus); edit:SetHandler("OnMouseUp", function(c, _, inside) if inside ~= false then focus(c) end end)
        edit:SetHandler("OnFocusGained", function() self.mapTeleporterSearchFocused = true end); edit:SetHandler("OnFocusLost", function() self.mapTeleporterSearchFocused = false end)
        edit:SetHandler("OnEnter", function(c) if c.LoseFocus then c:LoseFocus() end end); edit:SetHandler("OnEscape", function(c) if c.LoseFocus then c:LoseFocus() end end)
        edit:SetHandler("OnTextChanged", function(c) self[field] = c:GetText() or ""; self.mapTeleporterPage = 1; self:RefreshMapTeleporter() end)
        return edit
    end
    local initialW = safeNumber(root:GetWidth(), 500); local searchW = math.max(170, math.floor((initialW - 34) / 2))
    root.playerSearch = createSearch("PLAYER OR DESTINATION", 12, searchW, "mapTeleporterPlayerSearch"); root.zoneSearch = createSearch("ZONE", 22 + searchW, searchW, "mapTeleporterZoneSearch")

    root.tabs = {}; local tabGap, cols = 4, 6; local tabW = math.max(58, math.floor((initialW - 20 - (tabGap * (cols - 1))) / cols))
    for i, spec in ipairs(MAP_TELEPORTER_MODES_02966) do
        local tabRow = math.floor((i - 1) / cols); local col = (i - 1) % cols
        local b = wm:CreateControl(nil, root, CT_BUTTON); b:SetDimensions(tabW, 25); b:SetAnchor(TOPLEFT, root, TOPLEFT, 10 + col * (tabW + tabGap), 139 + tabRow * 28); b:SetFont("ZoFontGameSmall"); b:SetText(spec[2]); b:SetNormalFontColor(.82, .84, .86, 1); b:SetMouseOverFontColor(1, .78, .24, 1); b:SetHandler("OnClicked", function() self:SetMapTeleporterMode(spec[1]) end); root.tabs[spec[1]] = b
    end
    local statsY = 139 + math.ceil(#MAP_TELEPORTER_MODES_02966 / cols) * 28 + 3
    local stats = mtLabel(root, "", "ZoFontGameSmall", .72, .76, .82); stats:SetAnchor(TOPLEFT, root, TOPLEFT, 12, statsY); stats:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, statsY); stats:SetHeight(18); root.stats = stats
    local sortInfo = mtLabel(root, "", "ZoFontGameSmall", .58, .63, .70, TEXT_ALIGN_RIGHT); sortInfo:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, statsY + 18); sortInfo:SetDimensions(260, 16); root.sortInfo = sortInfo

    root.rows = {}; local maxRows = 20
    for i = 1, maxRows do
        local row = wm:CreateControl(nil, root, CT_BUTTON); row:SetMouseEnabled(true); local rbg = mtBackdrop(row, .022, .030, .047, .88); rbg:SetAnchorFill(row); row.bg = rbg
        row.star = wm:CreateControl(nil, row, CT_BUTTON); row.star:SetDimensions(28, 24); row.star:SetAnchor(LEFT, row, LEFT, 4, 0); row.star:SetFont("ZoFontGameBold"); row.star:SetText("+"); row.star:SetNormalFontColor(.72, .72, .72, 1); row.star:SetMouseOverFontColor(1, .78, .24, 1); row.star:SetHandler("OnClicked", function() if row.entry then self:ToggleMapTeleporterFavorite(row.entry) end end)
        row.name = mtLabel(row, "", "ZoFontGameBold", .96, .96, .92); row.name:SetAnchor(TOPLEFT, row, TOPLEFT, 36, 2); row.name:SetAnchor(TOPRIGHT, row, TOPRIGHT, -108, 2); row.name:SetHeight(18)
        row.zone = mtLabel(row, "", "ZoFontGameSmall", .67, .74, .82); row.zone:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 36, -2); row.zone:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -108, -2); row.zone:SetHeight(16)
        row.source = mtLabel(row, "", "ZoFontGameSmall", 1, .78, .24, TEXT_ALIGN_RIGHT); row.source:SetAnchor(TOPRIGHT, row, TOPRIGHT, -7, 2); row.source:SetDimensions(96, 17)
        row.status = mtLabel(row, "", "ZoFontGameSmall", .50, .92, .62, TEXT_ALIGN_RIGHT); row.status:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -7, -2); row.status:SetDimensions(96, 16)
        row:SetHandler("OnMouseEnter", function(c) if c.entry then c.bg:SetCenterColor(.07, .09, .13, .98) end end); row:SetHandler("OnMouseExit", function(c) if c.entry then c.bg:SetCenterColor(.022, .030, .047, .88) end end)
        row:SetHandler("OnMouseUp", function(c, button, inside) if not inside or not c.entry then return end; if button == (MOUSE_BUTTON_INDEX_RIGHT or 2) then self:ShowMapTeleporterContextMenu(c.entry, c) else self:TravelMapTeleporterEntry(c.entry) end end)
        row:SetHidden(true); root.rows[i] = row
    end
    local prev = wm:CreateControl(nil, root, CT_BUTTON); prev:SetDimensions(72, 26); prev:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 12, -8); prev:SetFont("ZoFontGameBold"); prev:SetText("PREVIOUS"); prev:SetNormalFontColor(.85, .86, .88, 1); prev:SetMouseOverFontColor(1, .78, .24, 1); prev:SetHandler("OnClicked", function() self:ChangeMapTeleporterPage(-1) end); root.prev = prev
    local page = mtLabel(root, "1 / 1", "ZoFontGame", .76, .79, .84, TEXT_ALIGN_CENTER); page:SetAnchor(BOTTOM, root, BOTTOM, 0, -9); page:SetDimensions(160, 24); root.page = page
    local nextB = wm:CreateControl(nil, root, CT_BUTTON); nextB:SetDimensions(72, 26); nextB:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -12, -8); nextB:SetFont("ZoFontGameBold"); nextB:SetText("NEXT"); nextB:SetNormalFontColor(.85, .86, .88, 1); nextB:SetMouseOverFontColor(1, .78, .24, 1); nextB:SetHandler("OnClicked", function() self:ChangeMapTeleporterPage(1) end); root.next = nextB
    root:SetHandler("OnMouseWheel", function(_, delta) self:ChangeMapTeleporterPage(delta < 0 and 1 or -1) end)
    self.mapTeleporter = root; self:DockMapTeleporterToWorldMap(); return root
end

RefreshMapTeleporterImplArch = function(self)
    local root = self.mapTeleporter
    if not root or root:IsHidden() then return end
    self:DockMapTeleporterToWorldMap()
    local entries = self:BuildMapTeleporterEntries(); self.mapTeleporterEntries = entries
    local perPage = safeNumber(root.visibleRows, 15); local pages = math.max(1, math.ceil(#entries / perPage)); local page = math.max(1, math.min(safeNumber(self.mapTeleporterPage, 1), pages)); self.mapTeleporterPage = page; local first = ((page - 1) * perPage) + 1
    local mode = self.mapTeleporterMode or "ALL"
    local extra = ""
    if self.mapTeleporterDiscoveryActive then extra = "  |  DISCOVERY " .. tostring(self.mapTeleporterDiscoveryIndex or 1) .. "/" .. tostring(#(self.mapTeleporterDiscoveryQueue or {})) end
    root.stats:SetText(string.format("%d DESTINATION%s  |  %s%s", #entries, #entries == 1 and "" or "S", mode, extra))
    root.sortInfo:SetText("SORT: " .. tostring((EPC.saved and EPC.saved.mapTeleporterSortMode) or "SMART") .. "  |  DUNGEON: " .. self:GetMapTeleporterDungeonDifficultyText())
    root.page:SetText(string.format("PAGE %d / %d", page, pages)); root.prev:SetEnabled(page > 1); root.next:SetEnabled(page < pages)
    for m, b in pairs(root.tabs or {}) do b:SetNormalFontColor(m == mode and 1.00 or .82, m == mode and .78 or .84, m == mode and .24 or .86, 1) end
    for i, row in ipairs(root.rows or {}) do
        local e = i <= perPage and entries[first + i - 1] or nil; row.entry = e
        if e then
            row:SetHidden(false); local fav = self:IsMapTeleporterFavorite(e); row.star:SetText(fav and "*" or "+"); row.star:SetNormalFontColor(fav and 1.00 or .72, fav and .78 or .72, fav and .24 or .72, 1)
            local name = clean(e.displayName, e.name or e.zoneName or "Destination")
            if e.kind == "ZONE" then name = e.zoneName elseif e.kind == "QUEST" or e.kind == "ITEM" or e.kind == "LEAD" or e.kind == "HOUSE" or e.kind == "INSTANCE" then name = clean(e.name, name) end
            row.name:SetText(name)
            local detail = clean(e.zoneName, "Unknown location")
            if e.kind == "ZONE" then
                local counts = string.format("%d online", safeNumber(e.playerCount, 0))
                if safeNumber(e.knownWayshrines, 0) > 0 then counts = counts .. "   " .. tostring(e.knownWayshrines) .. " shrine" .. (safeNumber(e.knownWayshrines, 0) == 1 and "" or "s") end
                if safeNumber(e.unknownWayshrines, 0) > 0 then counts = counts .. "   " .. tostring(e.unknownWayshrines) .. " undiscovered" end
                detail = counts .. (e.travelEntry and ("  |  via " .. clean(e.travelEntry.name, e.travelEntry.kind)) or "")
            elseif e.kind == "GUILD_SUMMARY" then detail = string.format("%d online travel target%s%s", safeNumber(e.playerCount, 0), safeNumber(e.playerCount, 0) == 1 and "" or "s", e.travelEntry and ("  |  via " .. clean(e.travelEntry.name, "member")) or "")
            elseif e.kind == "HOUSE" and clean(e.characterName, "") ~= "" then detail = detail .. "   " .. e.characterName
            elseif e.kind == "QUEST" then detail = detail .. (e.travelEntry and ("  |  via " .. clean(e.travelEntry.name, e.travelEntry.kind)) or "")
            elseif e.kind == "ITEM" and safeNumber(e.stack, 1) > 1 then detail = detail .. "  |  x" .. tostring(e.stack)
            elseif e.kind == "LEAD" and clean(e.sourceDetail, "") ~= "" then detail = detail .. "   " .. e.sourceDetail
            elseif clean(e.characterName, "") ~= "" and lower(e.characterName) ~= lower(e.displayName or "") then detail = e.characterName .. "   " .. detail end
            row.zone:SetText(detail)
            row.source:SetText(e.sourceText or (e.kind == "FRIEND" and "FRIEND" or e.kind or "TRAVEL"))
            row.status:SetText(e.canTravel == false and (e.statusText or "BLOCKED") or (e.statusText or e.costText or "TRAVEL"))
            if self:IsMapTeleporterBlacklisted(e) then row.status:SetColor(.95, .38, .34, 1)
            elseif e.canTravel == false then row.status:SetColor(.95, .38, .34, 1)
            elseif e.statusText == "FREE" or e.kind == "GROUP" or e.kind == "FRIEND" or e.kind == "GUILD" or e.kind == "HOUSE" or e.kind == "PLAYER_HOME" then row.status:SetColor(.50, .92, .62, 1)
            else row.status:SetColor(.45, .90, 1, 1) end
        else row:SetHidden(true) end
    end
    self:LayoutMapTeleporter()
end

-- ============================================================================
-- v0.29.68 - Teleporter popup layering / ESO-safe symbol recovery.
-- Keep the main panel below ESO's popup surfaces and explicitly raise the
-- standard keyboard menu/tooltip controls whenever a Teleporter popup opens.
-- ============================================================================
local RaiseMapTeleporterPopupSurfaces02968ImplArch
function T:RaiseMapTeleporterPopupSurfaces02968(...)
    return RaiseMapTeleporterPopupSurfaces02968ImplArch(self, ...)
end
RaiseMapTeleporterPopupSurfaces02968ImplArch = function(self)
    local names = {
        "ZO_Menu",
        "ZO_ComboBoxDropdown",
        "ZO_ComboBoxDropdown_Keyboard",
        "InformationTooltip",
        "ItemTooltip",
        "PopupTooltip",
        "ComparativeTooltip1",
        "ComparativeTooltip2",
        "ZO_MapLocationTooltip",
        "ZO_WorldMapTooltip",
    }
    for _, name in ipairs(names) do
        local control = _G and _G[name] or nil
        if control then
            if type(control.SetDrawTier) == "function" and DT_HIGH ~= nil then pcall(control.SetDrawTier, control, DT_HIGH) end
            if type(control.SetDrawLayer) == "function" and DL_OVERLAY ~= nil then pcall(control.SetDrawLayer, control, DL_OVERLAY) end
            if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, 2000) end
        end
    end
end

local RaiseMapTeleporterPopupSurfacesDeferred02968ImplArch

function T:RaiseMapTeleporterPopupSurfacesDeferred02968(...)

    return RaiseMapTeleporterPopupSurfacesDeferred02968ImplArch(self, ...)

end

RaiseMapTeleporterPopupSurfacesDeferred02968ImplArch = function(self)
    self:RaiseMapTeleporterPopupSurfaces02968()
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if EPC and EPC.Travel then EPC.Travel:RaiseMapTeleporterPopupSurfaces02968() end
        end, 1)
        zo_callLater(function()
            if EPC and EPC.Travel then EPC.Travel:RaiseMapTeleporterPopupSurfaces02968() end
        end, 35)
    end
end

-- ============================================================================
-- v0.29.67 - Clean World Map Teleporter presentation
-- Keeps the full destination/tool feature set from 0.29.66, but removes the
-- always-visible wall of filter buttons. All destination views live in one
-- compact VIEW menu and secondary actions live in TOOLS.
-- ============================================================================
local MAP_TELEPORTER_VIEW_MENU_02967 = {
    {"ALL", "All Destinations"},
    {"ZONES", "Zones"},
    {"MAP", "Current Map"},
    {"SHRINES", "Wayshrines"},
    {"GROUP", "Group"},
    {"FRIENDS", "Friends"},
    {"GUILD", "Guild Members"},
    {"GUILDS", "Guild Homes"},
    {"QUESTS", "Quests"},
    {"ITEMS", "Maps / Surveys / Items"},
    {"LEADS", "Antiquity Leads"},
    {"DELVES", "Delves"},
    {"DUNGEONS", "Dungeons / Trials"},
    {"INSTANCES", "All Instances"},
    {"HOUSES", "My Houses"},
    {"PLAYER_HOMES", "Player Homes"},
    {"FAVORITES", "Favorites"},
    {"BLOCKED", "Blocked"},
}

function T:GetMapTeleporterViewLabel02967(mode)
    mode = mode or self.mapTeleporterMode or "ALL"
    for _, spec in ipairs(MAP_TELEPORTER_VIEW_MENU_02967) do
        if spec[1] == mode then return spec[2] end
    end
    return "All Destinations"
end

local ShowMapTeleporterViewMenu02967ImplArch

function T:ShowMapTeleporterViewMenu02967(...)

    return ShowMapTeleporterViewMenu02967ImplArch(self, ...)

end

ShowMapTeleporterViewMenu02967ImplArch = function(self, owner)
    if type(ClearMenu) ~= "function" or type(AddMenuItem) ~= "function" or type(ShowMenu) ~= "function" then return end
    ClearMenu()
    local selected = self.mapTeleporterMode or "ALL"
    for _, spec in ipairs(MAP_TELEPORTER_VIEW_MENU_02967) do
        local mode, label = spec[1], spec[2]
        AddMenuItem((mode == selected and "SELECTED " or "") .. label, function()
            self:SetMapTeleporterMode(mode)
        end)
    end
    ShowMenu(owner)
    self:RaiseMapTeleporterPopupSurfacesDeferred02968()
end

function T:SetMapTeleporterSortMode02967(mode)
    if not EPC.saved then return end
    EPC.saved.mapTeleporterSortMode = mode or "SMART"
    self.mapTeleporterPage = 1
    self:RefreshMapTeleporter()
end

local ShowMapTeleporterToolsMenu02967ImplArch

function T:ShowMapTeleporterToolsMenu02967(...)

    return ShowMapTeleporterToolsMenu02967ImplArch(self, ...)

end

ShowMapTeleporterToolsMenu02967ImplArch = function(self, owner)
    if type(ClearMenu) ~= "function" or type(AddMenuItem) ~= "function" or type(ShowMenu) ~= "function" then return end
    ClearMenu()
    AddMenuItem("Travel Home", function() self:MapTeleporterQuickHome(false) end)
    AddMenuItem("Travel Outside Home", function() self:MapTeleporterQuickHome(true) end)
    AddMenuItem("Travel to Group Leader", function() self:MapTeleporterQuickLeader() end)
    AddMenuItem("Travel to Active Quest", function() self:MapTeleporterQuickQuest() end)
    AddMenuItem(self.mapTeleporterDiscoveryActive and "Stop Wayshrine Discovery" or "Discover Wayshrines", function() self:StartMapTeleporterAutoDiscovery() end)
    AddMenuItem("Dungeon Difficulty: " .. self:GetMapTeleporterDungeonDifficultyText(), function() self:ToggleMapTeleporterDungeonDifficulty() end)

    local currentSort = (EPC.saved and EPC.saved.mapTeleporterSortMode) or "SMART"
    local sorts = {
        {"SMART", "Smart"}, {"ZONE", "Zone"}, {"SOURCE", "Source"},
        {"PLAYER_COUNT", "Player Count"}, {"MOST_USED", "Most Used"}, {"LAST_USED", "Last Used"},
    }
    for _, spec in ipairs(sorts) do
        local sortMode, label = spec[1], spec[2]
        AddMenuItem((sortMode == currentSort and "SELECTED SORT " or "SORT ") .. label, function()
            self:SetMapTeleporterSortMode02967(sortMode)
        end)
    end
    ShowMenu(owner)
    self:RaiseMapTeleporterPopupSurfacesDeferred02968()
end

local function mtToolbarButton02967(wm, root, text, width)
    local button = wm:CreateControl(nil, root, CT_BUTTON)
    button:SetDimensions(width, 30)
    button:SetFont("ZoFontGameBold")
    button:SetText(text)
    button:SetNormalFontColor(0.86, 0.88, 0.90, 1)
    button:SetMouseOverFontColor(1.00, 0.88, 0.46, 1)
    local bg = wm:CreateControl(nil, button, CT_BACKDROP)
    bg:SetAnchorFill(button)
    bg:SetCenterColor(0.030, 0.040, 0.060, 0.96)
    bg:SetEdgeColor(0.18, 0.21, 0.27, 0.85)
    bg:SetDrawLayer(DL_BACKGROUND)
    button.bg02967 = bg
    return button
end

LayoutMapTeleporterImplArch = function(self)
    local root = self.mapTeleporter
    if not root then return end

    local width = math.max(420, safeNumber(root:GetWidth(), 500))
    local height = math.max(560, safeNumber(root:GetHeight(), 700))
    local margin = 12

    if root.viewButton then
        root.viewButton:ClearAnchors()
        root.viewButton:SetAnchor(TOPLEFT, root, TOPLEFT, margin, 46)
        root.viewButton:SetDimensions(math.max(170, math.floor(width * 0.43)), 30)
    end
    if root.favoriteButton then
        root.favoriteButton:ClearAnchors()
        root.favoriteButton:SetAnchor(TOPRIGHT, root.toolsButton or root, root.toolsButton and TOPLEFT or TOPRIGHT, root.toolsButton and -8 or -margin, root.toolsButton and 0 or 46)
    end
    if root.toolsButton then
        root.toolsButton:ClearAnchors()
        root.toolsButton:SetAnchor(TOPRIGHT, root, TOPRIGHT, -margin, 46)
    end

    local searchGap = 10
    local searchWidth = math.max(150, math.floor((width - (margin * 2) - searchGap) / 2))
    if root.playerSearchLabel then
        root.playerSearchLabel:ClearAnchors(); root.playerSearchLabel:SetAnchor(TOPLEFT, root, TOPLEFT, margin, 84); root.playerSearchLabel:SetWidth(searchWidth)
    end
    if root.zoneSearchLabel then
        root.zoneSearchLabel:ClearAnchors(); root.zoneSearchLabel:SetAnchor(TOPLEFT, root, TOPLEFT, margin + searchWidth + searchGap, 84); root.zoneSearchLabel:SetWidth(searchWidth)
    end
    if root.playerSearchBg then
        root.playerSearchBg:ClearAnchors(); root.playerSearchBg:SetAnchor(TOPLEFT, root, TOPLEFT, margin, 101); root.playerSearchBg:SetDimensions(searchWidth, 30)
    end
    if root.zoneSearchBg then
        root.zoneSearchBg:ClearAnchors(); root.zoneSearchBg:SetAnchor(TOPLEFT, root, TOPLEFT, margin + searchWidth + searchGap, 101); root.zoneSearchBg:SetDimensions(searchWidth, 30)
    end

    if root.stats then
        root.stats:ClearAnchors(); root.stats:SetAnchor(TOPLEFT, root, TOPLEFT, margin, 137); root.stats:SetAnchor(TOPRIGHT, root, TOPRIGHT, -margin, 137); root.stats:SetHeight(20)
    end

    local startY = 162
    local footerReserve = 42
    local visibleRows = safeNumber(EPC.saved and EPC.saved.mapTeleporterVisibleRows, 15)
    visibleRows = math.max(8, math.min(20, visibleRows))
    root.visibleRows = visibleRows
    local available = math.max(260, height - startY - footerReserve)
    local rowH = math.max(28, math.min(44, math.floor(available / visibleRows)))

    for i, row in ipairs(root.rows or {}) do
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, root, TOPLEFT, margin, startY + ((i - 1) * rowH))
        row:SetAnchor(TOPRIGHT, root, TOPRIGHT, -margin, startY + ((i - 1) * rowH))
        row:SetHeight(math.max(26, rowH - 2))
        row:SetHidden(i > visibleRows or row.entry == nil)
    end
end

CreateMapTeleporterImplArch = function(self)
    if self.mapTeleporter then return self.mapTeleporter end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local wm = WINDOW_MANAGER
    local root = wm:CreateTopLevelWindow("EAS_WorldMapTeleporter02967Clean")
    root:SetDimensions(500, math.max(560, safeNumber(GuiRoot:GetHeight(), 900) - 16))
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 8)
    root:SetDrawTier(DT_HIGH)
    root:SetDrawLayer(DL_CONTROLS)
    root:SetDrawLevel(40)
    root:SetMouseEnabled(true)
    root:SetClampedToScreen(false)
    root:SetHidden(true)

    local bg = wm:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.012, 0.018, 0.030, 0.995)
    bg:SetEdgeColor(0.16, 0.18, 0.23, 0.95)
    root.bg = bg

    local title = mtLabel(root, "MAP TELEPORTER", "ZoFontWinH2", 1.00, 0.78, 0.24, TEXT_ALIGN_LEFT)
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 7)
    title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 7)
    title:SetHeight(30)
    root.title = title

    local viewButton = mtToolbarButton02967(wm, root, "ALL DESTINATIONS", 210)
    viewButton:SetHandler("OnClicked", function(control) self:ShowMapTeleporterViewMenu02967(control) end)
    root.viewButton = viewButton

    local toolsButton = mtToolbarButton02967(wm, root, "TOOLS", 96)
    toolsButton:SetHandler("OnClicked", function(control) self:ShowMapTeleporterToolsMenu02967(control) end)
    root.toolsButton = toolsButton

    local favoriteButton = mtToolbarButton02967(wm, root, "FAVORITES", 112)
    favoriteButton:SetHandler("OnClicked", function() self:SetMapTeleporterMode("FAVORITES") end)
    root.favoriteButton = favoriteButton

    local function createSearch(labelText, field)
        local lbl = mtLabel(root, labelText, "ZoFontGameSmall", 0.66, 0.70, 0.77, TEXT_ALIGN_LEFT)
        lbl:SetHeight(16)
        local boxBg = wm:CreateControl(nil, root, CT_BACKDROP)
        boxBg:SetCenterColor(0.024, 0.032, 0.048, 0.99)
        boxBg:SetEdgeColor(0.15, 0.18, 0.23, 0.90)
        local edit = wm:CreateControl(nil, boxBg, CT_EDITBOX)
        edit:SetAnchor(TOPLEFT, boxBg, TOPLEFT, 8, 1)
        edit:SetAnchor(BOTTOMRIGHT, boxBg, BOTTOMRIGHT, -8, -1)
        edit:SetFont("ZoFontGame")
        edit:SetColor(0.95, 0.95, 0.92, 1)
        edit:SetMaxInputChars(50)
        edit:SetText(self[field] or "")
        edit:SetMouseEnabled(true)
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end
        if edit.SetEditEnabled then edit:SetEditEnabled(true) end
        local function focus(c) if c and c.TakeFocus then c:TakeFocus() end end
        edit:SetHandler("OnMouseDown", focus)
        edit:SetHandler("OnMouseUp", function(c, _, inside) if inside ~= false then focus(c) end end)
        edit:SetHandler("OnFocusGained", function() self.mapTeleporterSearchFocused = true end)
        edit:SetHandler("OnFocusLost", function() self.mapTeleporterSearchFocused = false end)
        edit:SetHandler("OnEnter", function(c) if c.LoseFocus then c:LoseFocus() end end)
        edit:SetHandler("OnEscape", function(c) if c.LoseFocus then c:LoseFocus() end end)
        edit:SetHandler("OnTextChanged", function(c)
            self[field] = c:GetText() or ""
            self.mapTeleporterPage = 1
            self:RefreshMapTeleporter()
        end)
        return lbl, boxBg, edit
    end

    root.playerSearchLabel, root.playerSearchBg, root.playerSearch = createSearch("PLAYER OR DESTINATION", "mapTeleporterPlayerSearch")
    root.zoneSearchLabel, root.zoneSearchBg, root.zoneSearch = createSearch("ZONE", "mapTeleporterZoneSearch")

    local stats = mtLabel(root, "", "ZoFontGameSmall", 0.67, 0.72, 0.79, TEXT_ALIGN_LEFT)
    root.stats = stats

    root.rows = {}
    for i = 1, 20 do
        local row = wm:CreateControl(nil, root, CT_BUTTON)
        row:SetMouseEnabled(true)
        local rbg = wm:CreateControl(nil, row, CT_BACKDROP)
        rbg:SetAnchorFill(row)
        rbg:SetCenterColor(0.020, 0.027, 0.041, 0.72)
        rbg:SetEdgeColor(0.09, 0.11, 0.15, 0.60)
        row.bg = rbg

        local star = wm:CreateControl(nil, row, CT_BUTTON)
        star:SetDimensions(24, 22)
        star:SetAnchor(LEFT, row, LEFT, 4, 0)
        star:SetFont("ZoFontGameBold")
        star:SetText("")
        star:SetNormalFontColor(1.00, 0.78, 0.24, 1)
        star:SetMouseOverFontColor(1.00, 0.90, 0.55, 1)
        row.star = star

        row.name = mtLabel(row, "", "ZoFontGameBold", 0.95, 0.96, 0.94, TEXT_ALIGN_LEFT)
        row.name:SetAnchor(TOPLEFT, row, TOPLEFT, 30, 2)
        row.name:SetAnchor(TOPRIGHT, row, TOPRIGHT, -98, 2)
        row.name:SetHeight(18)

        row.zone = mtLabel(row, "", "ZoFontGameSmall", 0.63, 0.69, 0.77, TEXT_ALIGN_LEFT)
        row.zone:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 30, -2)
        row.zone:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -98, -2)
        row.zone:SetHeight(16)

        row.source = mtLabel(row, "", "ZoFontGameSmall", 0.72, 0.74, 0.78, TEXT_ALIGN_RIGHT)
        row.source:SetAnchor(TOPRIGHT, row, TOPRIGHT, -7, 2)
        row.source:SetDimensions(86, 17)

        row.status = mtLabel(row, "", "ZoFontGameSmall", 0.50, 0.92, 0.62, TEXT_ALIGN_RIGHT)
        row.status:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -7, -2)
        row.status:SetDimensions(86, 16)

        local currentRow = row
        star:SetHandler("OnClicked", function()
            if currentRow.entry then self:ToggleMapTeleporterFavorite(currentRow.entry) end
        end)
        row:SetHandler("OnMouseEnter", function(c)
            if c.entry then c.bg:SetCenterColor(0.045, 0.058, 0.082, 0.94) end
        end)
        row:SetHandler("OnMouseExit", function(c)
            if c.entry then c.bg:SetCenterColor(0.020, 0.027, 0.041, 0.72) end
        end)
        row:SetHandler("OnMouseUp", function(c, button, inside)
            if not inside or not c.entry then return end
            if button == (MOUSE_BUTTON_INDEX_RIGHT or 2) then self:ShowMapTeleporterContextMenu(c.entry, c)
            else self:TravelMapTeleporterEntry(c.entry) end
        end)
        row:SetHidden(true)
        root.rows[i] = row
    end

    local prev = wm:CreateControl(nil, root, CT_BUTTON)
    prev:SetDimensions(78, 26)
    prev:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, 12, -8)
    prev:SetFont("ZoFontGameBold")
    prev:SetText("PREVIOUS")
    prev:SetNormalFontColor(0.78, 0.81, 0.85, 1)
    prev:SetMouseOverFontColor(1.00, 0.78, 0.24, 1)
    prev:SetHandler("OnClicked", function() self:ChangeMapTeleporterPage(-1) end)
    root.prev = prev

    local page = mtLabel(root, "1 / 1", "ZoFontGame", 0.70, 0.74, 0.80, TEXT_ALIGN_CENTER)
    page:SetAnchor(BOTTOM, root, BOTTOM, 0, -9)
    page:SetDimensions(160, 24)
    root.page = page

    local nextButton = wm:CreateControl(nil, root, CT_BUTTON)
    nextButton:SetDimensions(78, 26)
    nextButton:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -12, -8)
    nextButton:SetFont("ZoFontGameBold")
    nextButton:SetText("NEXT")
    nextButton:SetNormalFontColor(0.78, 0.81, 0.85, 1)
    nextButton:SetMouseOverFontColor(1.00, 0.78, 0.24, 1)
    nextButton:SetHandler("OnClicked", function() self:ChangeMapTeleporterPage(1) end)
    root.next = nextButton

    root:SetHandler("OnMouseWheel", function(_, delta) self:ChangeMapTeleporterPage(delta < 0 and 1 or -1) end)
    -- v0.29.341: remove the legacy per-frame popup-raise guard. Since v0.29.69
    -- Teleporter flyouts are internal controls and RaiseMapTeleporterPopupSurfaces02968
    -- is intentionally a no-op, this OnUpdate only burned a Lua callback every frame.
    root:SetHandler("OnUpdate", nil)

    self.mapTeleporter = root
    self:DockMapTeleporterToWorldMap()
    return root
end

RefreshMapTeleporterImplArch = function(self)
    local root = self.mapTeleporter
    if not root or root:IsHidden() then return end

    self:DockMapTeleporterToWorldMap()
    local entries = self:BuildMapTeleporterEntries()
    self.mapTeleporterEntries = entries

    local perPage = safeNumber(root.visibleRows, 15)
    local pages = math.max(1, math.ceil(#entries / perPage))
    local page = math.max(1, math.min(safeNumber(self.mapTeleporterPage, 1), pages))
    self.mapTeleporterPage = page
    local first = ((page - 1) * perPage) + 1
    local mode = self.mapTeleporterMode or "ALL"
    local viewLabel = self:GetMapTeleporterViewLabel02967(mode)

    if root.viewButton then root.viewButton:SetText(string.upper(viewLabel)) end
    if root.favoriteButton then
        if mode == "FAVORITES" then root.favoriteButton:SetNormalFontColor(1.00, 0.78, 0.24, 1)
        else root.favoriteButton:SetNormalFontColor(0.86, 0.88, 0.90, 1) end
    end

    local extra = ""
    if self.mapTeleporterDiscoveryActive then
        extra = "  |  DISCOVERY " .. tostring(self.mapTeleporterDiscoveryIndex or 1) .. "/" .. tostring(#(self.mapTeleporterDiscoveryQueue or {}))
    end
    if root.stats then
        root.stats:SetText(string.format("%d destination%s  |  %s%s", #entries, #entries == 1 and "" or "s", viewLabel, extra))
    end
    root.page:SetText(string.format("%d / %d", page, pages))
    root.prev:SetEnabled(page > 1)
    root.next:SetEnabled(page < pages)

    for i, row in ipairs(root.rows or {}) do
        local entry = i <= perPage and entries[first + i - 1] or nil
        row.entry = entry
        if entry then
            row:SetHidden(false)
            local favorite = self:IsMapTeleporterFavorite(entry)
            row.star:SetText(favorite and "*" or "+")

            local name = clean(entry.displayName, entry.name or entry.zoneName or "Destination")
            if entry.kind == "ZONE" then name = entry.zoneName
            elseif entry.kind == "QUEST" or entry.kind == "ITEM" or entry.kind == "LEAD" or entry.kind == "HOUSE" or entry.kind == "INSTANCE" then
                name = clean(entry.name, name)
            end
            row.name:SetText(name)

            local detail = clean(entry.zoneName, "Unknown location")
            if entry.kind == "ZONE" then
                local counts = string.format("%d online", safeNumber(entry.playerCount, 0))
                if safeNumber(entry.knownWayshrines, 0) > 0 then counts = counts .. "   " .. tostring(entry.knownWayshrines) .. " shrine" .. (safeNumber(entry.knownWayshrines, 0) == 1 and "" or "s") end
                if safeNumber(entry.unknownWayshrines, 0) > 0 then counts = counts .. "   " .. tostring(entry.unknownWayshrines) .. " undiscovered" end
                detail = counts
            elseif entry.kind == "GUILD_HOME" then
                detail = clean(entry.sourceDetail, clean(entry.leaderName, "") ~= "" and ("Guild Master: " .. clean(entry.leaderName, "") .. "  |  Primary Residence") or "Guild Master unavailable")
            elseif entry.kind == "GUILD_SUMMARY" then
                detail = string.format("%d online travel target%s", safeNumber(entry.playerCount, 0), safeNumber(entry.playerCount, 0) == 1 and "" or "s")
            elseif entry.kind == "HOUSE" and clean(entry.characterName, "") ~= "" then
                detail = detail .. "   " .. entry.characterName
            elseif entry.kind == "ITEM" and safeNumber(entry.stack, 1) > 1 then
                detail = detail .. "  |  x" .. tostring(entry.stack)
            elseif entry.kind == "LEAD" and clean(entry.sourceDetail, "") ~= "" then
                detail = detail .. "   " .. entry.sourceDetail
            elseif clean(entry.characterName, "") ~= "" and lower(entry.characterName) ~= lower(entry.displayName or "") then
                detail = entry.characterName .. "   " .. detail
            end
            row.zone:SetText(detail)

            row.source:SetText(entry.sourceText or (entry.kind == "FRIEND" and "FRIEND" or entry.kind or ""))
            row.status:SetText(entry.canTravel == false and (entry.statusText or "BLOCKED") or (entry.statusText or entry.costText or "TRAVEL"))
            if self:IsMapTeleporterBlacklisted(entry) or entry.canTravel == false then
                row.status:SetColor(0.95, 0.38, 0.34, 1)
            elseif entry.statusText == "FREE" or entry.statusText == "VISIT HOME" or entry.kind == "GROUP" or entry.kind == "FRIEND" or entry.kind == "GUILD" or entry.kind == "HOUSE" or entry.kind == "PLAYER_HOME" or entry.kind == "GUILD_HOME" then
                row.status:SetColor(0.50, 0.92, 0.62, 1)
            else
                row.status:SetColor(0.45, 0.90, 1.00, 1)
            end
        else
            row:SetHidden(true)
        end
    end

    self:LayoutMapTeleporter()
end


-- v0.29.76 - Teleporter flyout occlusion/readability fix.
-- Menus now use an opaque top-layer backdrop and 36px rows so destination
-- content can never bleed through View/Tools/Travel Options.

-- ============================================================================
-- v0.29.69 - Teleporter input-safe internal menus.
-- v0.29.70 - High-contrast, larger internal flyouts for readability.
-- ESO's global ZO_Menu can fight with the World Map scene and the Teleporter
-- top-level control for mouse ownership. Keep View, Tools and row actions inside
-- the Teleporter itself so there is only one interactive UI hierarchy.
-- ============================================================================
local MAP_TELEPORTER_REFRESH_BASE_02969 = RefreshMapTeleporterImplArch
local MAP_TELEPORTER_CREATE_BASE_02969 = CreateMapTeleporterImplArch

RaiseMapTeleporterPopupSurfaces02968ImplArch = function(self)
    -- Intentionally disabled in 0.29.69. Changing draw tiers on ESO's global
    -- menu/tooltip controls while they are open can break their mouse handling.
end

RaiseMapTeleporterPopupSurfacesDeferred02968ImplArch = function(self)
    -- Internal Teleporter flyouts no longer need global popup manipulation.
end

function T:IsMapTeleporterFlyoutOpen02969()
    local root = self.mapTeleporter
    return root and root.flyout02969 and not root.flyout02969:IsHidden()
end

function T:HideMapTeleporterFlyout02969()
    local root = self.mapTeleporter
    if root and root.flyout02969 then
        root.flyout02969:SetHidden(true)
        root.flyout02969.items02969 = nil
        for _, row in ipairs(root.flyout02969.rows02969 or {}) do
            if row.bg02969 then row.bg02969:SetHidden(true) end
            if row.label02982 then row.label02982:SetHidden(true) end
        end
    end
end

function T:EnsureMapTeleporterFlyout02969()
    local root = self.mapTeleporter
    if not root or not WINDOW_MANAGER then return nil end
    if root.flyout02969 then return root.flyout02969 end

    local wm = WINDOW_MANAGER
    -- Use the flyout itself as the opaque backdrop. In older builds the
    -- backdrop child was placed on DL_BACKGROUND, which allowed destination
    -- rows from the parent Teleporter to draw through it. Keeping the entire
    -- flyout on one overlay layer guarantees a solid menu above the list.
    local flyout = wm:CreateControl(nil, root, CT_BACKDROP)
    flyout:SetDimensions(390, 460)
    flyout:SetCenterColor(0.018, 0.022, 0.030, 1.000)
    flyout:SetEdgeColor(0.86, 0.66, 0.24, 1.000)
    flyout:SetDrawLayer(DL_OVERLAY)
    flyout:SetDrawLevel(940)
    flyout:SetMouseEnabled(true)
    flyout:SetHidden(true)
    flyout.bg02969 = flyout

    local title = wm:CreateControl(nil, flyout, CT_LABEL)
    title:SetAnchor(TOPLEFT, flyout, TOPLEFT, 12, 8)
    title:SetAnchor(TOPRIGHT, flyout, TOPRIGHT, -44, 8)
    title:SetHeight(24)
    title:SetFont("ZoFontGameBold")
    title:SetColor(1.00, 0.84, 0.38, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    flyout.title02969 = title

    local close = wm:CreateControl(nil, flyout, CT_BUTTON)
    close:SetDimensions(34, 26)
    close:SetAnchor(TOPRIGHT, flyout, TOPRIGHT, -6, 5)
    close:SetFont("ZoFontGameBold")
    close:SetText("X")
    close:SetNormalFontColor(0.82, 0.84, 0.88, 1)
    close:SetMouseOverFontColor(1.00, 0.78, 0.24, 1)
    close:SetHandler("OnClicked", function() self:HideMapTeleporterFlyout02969() end)
    flyout.close02969 = close

    local rule = wm:CreateControl(nil, flyout, CT_TEXTURE)
    rule:SetTexture("/esoui/art/miscellaneous/white.dds")
    rule:SetColor(0.72, 0.56, 0.20, 0.95)
    rule:SetAnchor(TOPLEFT, flyout, TOPLEFT, 8, 36)
    rule:SetAnchor(TOPRIGHT, flyout, TOPRIGHT, -8, 36)
    rule:SetHeight(1)
    flyout.rule02969 = rule

    flyout.rows02969 = {}
    for i = 1, 24 do
        local button = wm:CreateControl(nil, flyout, CT_BUTTON)
        button:SetAnchor(TOPLEFT, flyout, TOPLEFT, 8, 43 + ((i - 1) * 36))
        button:SetAnchor(TOPRIGHT, flyout, TOPRIGHT, -8, 43 + ((i - 1) * 36))
        button:SetHeight(34)
        -- v0.29.82: do not use CT_BUTTON's internal text renderer here.
        -- Depending on the World Map scene/draw stack ESO can place that internal
        -- text below sibling backdrops. The button is now mouse-input only and a
        -- dedicated CT_LABEL sibling is always drawn above every row surface.
        button:SetText("")
        button:SetDrawLayer(DL_OVERLAY)
        button:SetDrawLevel(946)

        local hover = wm:CreateControl(nil, flyout, CT_BACKDROP)
        hover:SetAnchor(TOPLEFT, button, TOPLEFT, 0, 0)
        hover:SetAnchor(BOTTOMRIGHT, button, BOTTOMRIGHT, 0, 0)
        hover:SetCenterColor(0.065, 0.075, 0.095, 1.00)
        hover:SetEdgeColor(0.18, 0.20, 0.24, 1.00)
        hover:SetDrawLayer(DL_OVERLAY)
        hover:SetDrawLevel(942)
        hover:SetMouseEnabled(false)
        button.bg02969 = hover

        local textLabel = wm:CreateControl(nil, flyout, CT_LABEL)
        textLabel:SetAnchor(LEFT, button, LEFT, 12, 0)
        textLabel:SetAnchor(RIGHT, button, RIGHT, -10, 0)
        textLabel:SetHeight(34)
        textLabel:SetFont("ZoFontGameBold")
        textLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        textLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        textLabel:SetColor(0.97, 0.98, 1.00, 1)
        textLabel:SetDrawLayer(DL_OVERLAY)
        textLabel:SetDrawLevel(950)
        textLabel:SetMouseEnabled(false)
        button.label02982 = textLabel

        button:SetHandler("OnMouseEnter", function(c)
            if c.bg02969 then c.bg02969:SetCenterColor(0.18, 0.15, 0.075, 1.00) end
            if c.label02982 and c.item02969 and c.item02969.enabled ~= false then
                c.label02982:SetColor(1.00, 0.88, 0.46, 1)
            end
        end)
        button:SetHandler("OnMouseExit", function(c)
            if c.bg02969 then
                local selected = c.item02969 and c.item02969.selected == true
                if selected then c.bg02969:SetCenterColor(0.15, 0.12, 0.050, 1.00)
                else c.bg02969:SetCenterColor(0.065, 0.075, 0.095, 1.00) end
            end
            if c.label02982 then
                if c.item02969 and c.item02969.enabled == false then
                    c.label02982:SetColor(0.50, 0.52, 0.56, 1)
                elseif c.item02969 and c.item02969.selected == true then
                    c.label02982:SetColor(1.00, 0.88, 0.46, 1)
                else
                    c.label02982:SetColor(0.97, 0.98, 1.00, 1)
                end
            end
        end)
        button:SetHandler("OnClicked", function(c)
            local item = c.item02969
            if not item or item.enabled == false then return end
            local action = item.action
            self:HideMapTeleporterFlyout02969()
            if type(action) == "function" then
                local ok, err = pcall(action)
                if not ok and EPC and EPC.Print then EPC:Print("Teleporter action failed: " .. tostring(err or "unknown error")) end
            end
        end)
        button:SetHidden(true)
        flyout.rows02969[i] = button
    end

    flyout:SetHandler("OnMouseWheel", function() end)
    root.flyout02969 = flyout
    return flyout
end

local ShowMapTeleporterFlyout02969ImplArch

function T:ShowMapTeleporterFlyout02969(...)

    return ShowMapTeleporterFlyout02969ImplArch(self, ...)

end

ShowMapTeleporterFlyout02969ImplArch = function(self, titleText, items, owner, contextMode)
    local root = self.mapTeleporter
    local flyout = self:EnsureMapTeleporterFlyout02969()
    if not root or not flyout then return false end

    items = items or {}
    local count = math.min(#items, #(flyout.rows02969 or {}))
    local rootW = math.max(420, safeNumber(root:GetWidth(), 500))
    local rootH = math.max(560, safeNumber(root:GetHeight(), 700))
    local flyoutW = contextMode and math.min(430, rootW - 24) or math.min(410, rootW - 24)
    local flyoutH = 50 + (count * 36) + 7
    flyoutH = math.min(flyoutH, rootH - 20)
    flyout:SetDimensions(flyoutW, flyoutH)
    flyout.title02969:SetText(titleText or "OPTIONS")
    flyout.items02969 = items

    for i, row in ipairs(flyout.rows02969 or {}) do
        local item = items[i]
        row.item02969 = item
        if item and i <= count then
            row:SetText("")
            row:SetEnabled(item.enabled ~= false)
            if row.label02982 then
                row.label02982:SetText(tostring(item.label or "Option"))
            end
            if item.enabled == false then
                if row.label02982 then row.label02982:SetColor(0.50, 0.52, 0.56, 1) end
                if row.bg02969 then row.bg02969:SetCenterColor(0.045, 0.050, 0.060, 1.00) end
            elseif item.selected == true then
                if row.label02982 then row.label02982:SetColor(1.00, 0.88, 0.46, 1) end
                if row.bg02969 then row.bg02969:SetCenterColor(0.15, 0.12, 0.050, 1.00) end
            else
                if row.label02982 then row.label02982:SetColor(0.97, 0.98, 1.00, 1) end
                if row.bg02969 then row.bg02969:SetCenterColor(0.065, 0.075, 0.095, 1.00) end
            end
            row:SetHidden(false)
            if row.bg02969 then row.bg02969:SetHidden(false) end
            if row.label02982 then row.label02982:SetHidden(false) end
        else
            row:SetHidden(true)
            if row.bg02969 then row.bg02969:SetHidden(true) end
            if row.label02982 then row.label02982:SetHidden(true) end
        end
    end

    local rootLeft = safeNumber(root:GetLeft(), 0)
    local rootTop = safeNumber(root:GetTop(), 0)
    local x, y = 12, 80
    if owner then
        if contextMode then
            x = rootW - flyoutW - 12
            y = safeNumber(owner:GetTop(), rootTop + 80) - rootTop
        else
            x = safeNumber(owner:GetLeft(), rootLeft + 12) - rootLeft
            y = safeNumber(owner:GetBottom(), rootTop + 78) - rootTop + 3
        end
    end
    x = math.max(8, math.min(x, rootW - flyoutW - 8))
    y = math.max(40, math.min(y, rootH - flyoutH - 8))

    flyout:ClearAnchors()
    flyout:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
    flyout:SetHidden(false)
    return true
end

ShowMapTeleporterViewMenu02967ImplArch = function(self, owner)
    local selected = self.mapTeleporterMode or "ALL"
    local items = {}
    for _, spec in ipairs(MAP_TELEPORTER_VIEW_MENU_02967 or {}) do
        local mode, label = spec[1], spec[2]
        items[#items + 1] = {
            label = label,
            selected = mode == selected,
            action = function() self:SetMapTeleporterMode(mode) end,
        }
    end
    return self:ShowMapTeleporterFlyout02969("DESTINATIONS", items, owner, false)
end

ShowMapTeleporterToolsMenu02967ImplArch = function(self, owner)
    local currentSort = (EPC.saved and EPC.saved.mapTeleporterSortMode) or "SMART"
    local items = {
        {label = "Travel Home", action = function() self:MapTeleporterQuickHome(false) end},
        {label = "Travel Outside Home", action = function() self:MapTeleporterQuickHome(true) end},
        {label = "Travel to Group Leader", action = function() self:MapTeleporterQuickLeader() end},
        {label = "Travel to Active Quest", action = function() self:MapTeleporterQuickQuest() end},
        {label = self.mapTeleporterDiscoveryActive and "Stop Wayshrine Discovery" or "Discover Wayshrines", action = function() self:StartMapTeleporterAutoDiscovery() end},
        {label = "Dungeon Difficulty: " .. self:GetMapTeleporterDungeonDifficultyText(), action = function() self:ToggleMapTeleporterDungeonDifficulty() end},
    }
    local sorts = {
        {"SMART", "Smart"}, {"ZONE", "Zone"}, {"SOURCE", "Source"},
        {"PLAYER_COUNT", "Player Count"}, {"MOST_USED", "Most Used"}, {"LAST_USED", "Last Used"},
    }
    for _, spec in ipairs(sorts) do
        local sortMode, label = spec[1], spec[2]
        items[#items + 1] = {
            label = "Sort: " .. label,
            selected = sortMode == currentSort,
            action = function() self:SetMapTeleporterSortMode02967(sortMode) end,
        }
    end
    return self:ShowMapTeleporterFlyout02969("TOOLS", items, owner, false)
end

function T:BuildMapTeleporterContextItems02969(entry)
    local items = {}
    if not entry then return items end

    local canTravel = entry.canTravel ~= false or entry.travelEntry
    if canTravel then
        items[#items + 1] = {label = "Travel Now", action = function() self:TravelMapTeleporterEntry(entry) end}
    end
    items[#items + 1] = {
        label = self:IsMapTeleporterFavorite(entry) and "Remove Favorite" or "Add Favorite",
        action = function() self:ToggleMapTeleporterFavorite(entry) end,
    }

    local isPlayer = clean(entry.displayName, "") ~= "" and
        (entry.kind == "GROUP" or entry.kind == "FRIEND" or entry.kind == "GUILD" or entry.kind == "PLAYER_HOME")
    if isPlayer then
        items[#items + 1] = {label = "Whisper", action = function()
            if type(StartChatInput) == "function" then StartChatInput("/w " .. tostring(entry.displayName) .. " ") end
        end}
        items[#items + 1] = {label = "Visit Primary Residence", action = function()
            if type(JumpToHouse) == "function" then pcall(JumpToHouse, entry.displayName) end
        end}
        items[#items + 1] = {label = "Invite to Group", action = function()
            if type(TryGroupInviteByName) == "function" then pcall(TryGroupInviteByName, entry.displayName, false, true)
            elseif type(GroupInviteByName) == "function" then pcall(GroupInviteByName, entry.displayName) end
        end}
        items[#items + 1] = {
            label = (EPC.saved and EPC.saved.mapTeleporterBlacklistPlayers and EPC.saved.mapTeleporterBlacklistPlayers[lower(entry.displayName)]) and "Unblacklist Player" or "Blacklist Player",
            action = function() self:ToggleMapTeleporterPlayerBlacklist(entry) end,
        }
    end

    if clean(entry.zoneName, "") ~= "" and entry.zoneName ~= "Player primary residence" then
        items[#items + 1] = {
            label = (EPC.saved and EPC.saved.mapTeleporterBlacklistZones and EPC.saved.mapTeleporterBlacklistZones[mtZoneKey02966(entry)]) and "Unblacklist Zone" or "Blacklist Zone",
            action = function() self:ToggleMapTeleporterZoneBlacklist(entry) end,
        }
    end

    if entry.kind == "HOUSE" and type(RequestJumpToHouse) == "function" then
        items[#items + 1] = {label = "Travel Inside", action = function() pcall(RequestJumpToHouse, entry.houseId, false) end}
        items[#items + 1] = {label = "Travel Outside", action = function() pcall(RequestJumpToHouse, entry.houseId, true) end}
        if type(SetHousingPrimaryHouse) == "function" and not entry.isPrimary then
            items[#items + 1] = {label = "Set as Primary Residence", action = function()
                pcall(SetHousingPrimaryHouse, entry.houseId)
                if type(zo_callLater) == "function" then zo_callLater(function() if EPC.Travel then EPC.Travel:RefreshMapTeleporter(true) end end, 250) end
            end}
        end
    end

    if entry.kind == "INSTANCE" and (entry.instanceCategory == "DUNGEON" or entry.instanceCategory == "TRIAL" or entry.instanceCategory == "ARENA") then
        items[#items + 1] = {label = "Toggle Normal or Veteran", action = function() self:ToggleMapTeleporterDungeonDifficulty() end}
    end
    if entry.kind == "LEAD" and EPC.AntiquityLeadFinder and EPC.AntiquityLeadFinder.Toggle then
        items[#items + 1] = {label = "Open Antiquity Lead Finder", action = function() EPC.AntiquityLeadFinder:Toggle() end}
    end
    if safeNumber(entry.zoneId, 0) > 0 or entry.questIndex then
        items[#items + 1] = {label = "Show Destination on Map", action = function() self:ShowMapTeleporterEntryOnMap(entry, false) end}
    end
    if (entry.kind == "SHRINE" or entry.kind == "INSTANCE") and entry.normalizedX and entry.normalizedY then
        items[#items + 1] = {label = "Show on Map and Set Waypoint", action = function() self:ShowMapTeleporterEntryOnMap(entry, true) end}
    end
    items[#items + 1] = {label = "Share Destination in Chat", action = function() self:ShareMapTeleporterDestination(entry) end}
    return items
end

ShowMapTeleporterContextMenuImplArch = function(self, entry, owner)
    if not entry then return false end
    return self:ShowMapTeleporterFlyout02969("TRAVEL OPTIONS", self:BuildMapTeleporterContextItems02969(entry), owner, true)
end

function T:InstallMapTeleporterInputFix02969(root)
    if not root or root.inputFix02969 then return end
    root.inputFix02969 = true

    if root.viewButton then
        root.viewButton:SetHandler("OnClicked", function(control)
            if self:IsMapTeleporterFlyoutOpen02969() and root.flyout02969 and root.flyout02969.owner02969 == control then
                self:HideMapTeleporterFlyout02969()
            else
                self:ShowMapTeleporterViewMenu02967(control)
                if root.flyout02969 then root.flyout02969.owner02969 = control end
            end
        end)
    end
    if root.toolsButton then
        root.toolsButton:SetHandler("OnClicked", function(control)
            if self:IsMapTeleporterFlyoutOpen02969() and root.flyout02969 and root.flyout02969.owner02969 == control then
                self:HideMapTeleporterFlyout02969()
            else
                self:ShowMapTeleporterToolsMenu02967(control)
                if root.flyout02969 then root.flyout02969.owner02969 = control end
            end
        end)
    end
    if root.favoriteButton then
        root.favoriteButton:SetHandler("OnClicked", function()
            self:HideMapTeleporterFlyout02969()
            self:SetMapTeleporterMode("FAVORITES")
        end)
    end

    for _, row in ipairs(root.rows or {}) do
        local currentRow = row
        if currentRow.star then
            currentRow.star:SetHandler("OnClicked", function()
                if self:IsMapTeleporterFlyoutOpen02969() then self:HideMapTeleporterFlyout02969(); return end
                if currentRow.entry then self:ToggleMapTeleporterFavorite(currentRow.entry) end
            end)
        end
        currentRow:SetHandler("OnMouseUp", function(c, button, inside)
            if not inside or not c.entry then return end
            if self:IsMapTeleporterFlyoutOpen02969() then
                self:HideMapTeleporterFlyout02969()
                return
            end
            if button == (MOUSE_BUTTON_INDEX_RIGHT or 2) then self:ShowMapTeleporterContextMenu(c.entry, c)
            else self:TravelMapTeleporterEntry(c.entry) end
        end)
    end
end

CreateMapTeleporterImplArch = function(self)
    local root = MAP_TELEPORTER_CREATE_BASE_02969(self)
    if root then self:InstallMapTeleporterInputFix02969(root) end
    return root
end

RefreshMapTeleporterImplArch = function(self, force02969)
    if force02969 ~= true and self:IsMapTeleporterFlyoutOpen02969() then
        -- Do not mutate the destination controls under the user's mouse while
        -- an action menu is open. The regular 1.6 second refresh resumes after
        -- the flyout closes.
        return
    end
    return MAP_TELEPORTER_REFRESH_BASE_02969(self)
end

local MAP_TELEPORTER_VISIBILITY_BASE_02969 = RefreshMapTeleporterVisibilityImplArch
RefreshMapTeleporterVisibilityImplArch = function(self, ...)
    local result = MAP_TELEPORTER_VISIBILITY_BASE_02969(self, ...)
    if self.mapTeleporter and self.mapTeleporter:IsHidden() then self:HideMapTeleporterFlyout02969() end
    return result
end

-- ============================================================================
-- v0.29.71 - Restore a visible World Map close keybind while Teleporter is open.
-- The Teleporter uses the player's existing TOGGLE_MAP binding (normally M)
-- rather than inventing a second close key. A small clickable title-bar hint is
-- also provided as a fallback if ESO's global keybind strip is unavailable.
-- ============================================================================
local GetMapToggleKeyText02971ImplArch
function T:GetMapToggleKeyText02971(...)
    return GetMapToggleKeyText02971ImplArch(self, ...)
end
GetMapToggleKeyText02971ImplArch = function(self)
    if type(GetActionBindingInfo) == "function" and type(GetKeyName) == "function" then
        local ok, keyCode = pcall(GetActionBindingInfo, "TOGGLE_MAP", 1)
        if ok and keyCode and (KEY_INVALID == nil or keyCode ~= KEY_INVALID) then
            local okName, keyName = pcall(GetKeyName, keyCode)
            keyName = okName and clean(keyName, "") or ""
            if keyName ~= "" then return keyName end
        end
    end
    return "M"
end

local CloseWorldMap02971ImplArch

function T:CloseWorldMap02971(...)

    return CloseWorldMap02971ImplArch(self, ...)

end

CloseWorldMap02971ImplArch = function(self)
    self:HideMapTeleporterFlyout02969()

    -- Use ESO's own main-menu map category first. This is the same system used
    -- by the TOGGLE_MAP binding, so it cleanly pops the map scene/scene stack.
    if SYSTEMS and type(SYSTEMS.GetObject) == "function" and MENU_CATEGORY_MAP ~= nil then
        local okObject, mainMenu = pcall(SYSTEMS.GetObject, SYSTEMS, "mainMenu")
        if okObject and mainMenu and type(mainMenu.ToggleCategory) == "function" then
            local okToggle = pcall(mainMenu.ToggleCategory, mainMenu, MENU_CATEGORY_MAP)
            if okToggle then return end
        end
    end

    -- Conservative fallback for unusual UI configurations.
    if SCENE_MANAGER and type(SCENE_MANAGER.Hide) == "function" then
        pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "worldMap")
    end
end

function T:EnsureMapTeleporterCloseKeybind02971()
    if self.mapTeleporterCloseKeybindGroup02971 then return self.mapTeleporterCloseKeybindGroup02971 end
    self.mapTeleporterCloseKeybindGroup02971 = {
        {
            name = "Close Map",
            keybind = "TOGGLE_MAP",
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            callback = function() self:CloseWorldMap02971() end,
            visible = function()
                return self.mapTeleporter and not self.mapTeleporter:IsHidden() and self:IsMapTeleporterMapShowing()
            end,
        },
    }
    return self.mapTeleporterCloseKeybindGroup02971
end

local SetMapTeleporterCloseKeybindVisible02971ImplArch

function T:SetMapTeleporterCloseKeybindVisible02971(...)

    return SetMapTeleporterCloseKeybindVisible02971ImplArch(self, ...)

end

SetMapTeleporterCloseKeybindVisible02971ImplArch = function(self, visible)
    local strip = KEYBIND_STRIP
    if not strip then return end
    local group = self:EnsureMapTeleporterCloseKeybind02971()
    if not group then return end

    if visible == true then
        if not self.mapTeleporterCloseKeybindAdded02971 and type(strip.AddKeybindButtonGroup) == "function" then
            local ok = pcall(strip.AddKeybindButtonGroup, strip, group)
            if ok then self.mapTeleporterCloseKeybindAdded02971 = true end
        elseif self.mapTeleporterCloseKeybindAdded02971 and type(strip.UpdateKeybindButtonGroup) == "function" then
            pcall(strip.UpdateKeybindButtonGroup, strip, group)
        end
    elseif self.mapTeleporterCloseKeybindAdded02971 and type(strip.RemoveKeybindButtonGroup) == "function" then
        pcall(strip.RemoveKeybindButtonGroup, strip, group)
        self.mapTeleporterCloseKeybindAdded02971 = false
    end
end

local MAP_TELEPORTER_CREATE_BASE_02971 = CreateMapTeleporterImplArch
CreateMapTeleporterImplArch = function(self)
    local root = MAP_TELEPORTER_CREATE_BASE_02971(self)
    if not root or not WINDOW_MANAGER then return root end

    if not root.closeMapButton02971 then
        local button = WINDOW_MANAGER:CreateControl(nil, root, CT_BUTTON)
        button:SetDimensions(138, 30)
        button:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 7)
        button:SetFont("ZoFontGameBold")
        button:SetNormalFontColor(0.90, 0.92, 0.95, 1)
        button:SetMouseOverFontColor(1.00, 0.84, 0.38, 1)
        button:SetPressedFontColor(1.00, 0.84, 0.38, 1)
        button:SetText(self:GetMapToggleKeyText02971() .. "  CLOSE MAP")
        button:SetHandler("OnClicked", function() self:CloseWorldMap02971() end)

        local bg = WINDOW_MANAGER:CreateControl(nil, button, CT_BACKDROP)
        bg:SetAnchorFill(button)
        bg:SetCenterColor(0.030, 0.040, 0.060, 0.98)
        bg:SetEdgeColor(0.34, 0.36, 0.40, 0.95)
        bg:SetDrawLayer(DL_BACKGROUND)
        button.bg02971 = bg
        root.closeMapButton02971 = button

        if root.title then
            root.title:ClearAnchors()
            root.title:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 7)
            root.title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -160, 7)
            root.title:SetHeight(30)
        end
    end

    return root
end

local MAP_TELEPORTER_REFRESH_BASE_02971 = RefreshMapTeleporterImplArch
RefreshMapTeleporterImplArch = function(self)
    local result = MAP_TELEPORTER_REFRESH_BASE_02971(self)
    local root = self.mapTeleporter
    if root and root.closeMapButton02971 then
        root.closeMapButton02971:SetText(self:GetMapToggleKeyText02971() .. "  CLOSE MAP")
    end
    return result
end

local MAP_TELEPORTER_VISIBLE_BASE_02971 = SetMapTeleporterVisibleImplArch
SetMapTeleporterVisibleImplArch = function(self, visible)
    local result = MAP_TELEPORTER_VISIBLE_BASE_02971(self, visible)
    local root = self.mapTeleporter
    local actuallyVisible = root and not root:IsHidden() and self:IsMapTeleporterMapShowing()
    self:SetMapTeleporterCloseKeybindVisible02971(actuallyVisible == true)
    if actuallyVisible and root.closeMapButton02971 then
        root.closeMapButton02971:SetText(self:GetMapToggleKeyText02971() .. "  CLOSE MAP")
    end
    return result
end

-- ============================================================================
-- v0.29.72 - Reliable World Map close control.
-- The previous implementation queried GetActionBindingInfo with an action name,
-- but current ESO expects layer/category/action indices for that API. Read the
-- player's real TOGGLE_MAP binding through GetHighestPriorityActionBindingInfoFromName
-- and keep a Suite-owned close control inside the Teleporter itself.
-- ============================================================================
local function EAS_MapBindingText02972()
    if type(GetHighestPriorityActionBindingInfoFromName) == "function" then
        local ok, keyCode, mod1, mod2, mod3, mod4 = pcall(GetHighestPriorityActionBindingInfoFromName, "TOGGLE_MAP", false)
        if ok and keyCode and (KEY_INVALID == nil or keyCode ~= KEY_INVALID) and type(GetKeyName) == "function" then
            local parts = {}
            local function addKeyName(code)
                if code and (KEY_INVALID == nil or code ~= KEY_INVALID) then
                    local okName, name = pcall(GetKeyName, code)
                    name = okName and clean(name, "") or ""
                    if name ~= "" then parts[#parts + 1] = name end
                end
            end
            addKeyName(mod1); addKeyName(mod2); addKeyName(mod3); addKeyName(mod4); addKeyName(keyCode)
            if #parts > 0 then return table.concat(parts, "+") end
        end
    end
    return "M"
end

GetMapToggleKeyText02971ImplArch = function(self)
    return EAS_MapBindingText02972()
end

function T:CloseWorldMap02972()
    self:HideMapTeleporterFlyout02969()
    local root = self.mapTeleporter
    if root then
        if root.playerSearch and root.playerSearch.LoseFocus then pcall(root.playerSearch.LoseFocus, root.playerSearch) end
        if root.zoneSearch and root.zoneSearch.LoseFocus then pcall(root.zoneSearch.LoseFocus, root.zoneSearch) end
    end
    self.mapTeleporterSearchFocused = false

    -- Hide the active map scene first. This is more reliable than treating a
    -- successful ToggleCategory pcall as proof that the scene actually closed.
    if SCENE_MANAGER and type(SCENE_MANAGER.HideCurrentScene) == "function" and self:IsMapTeleporterMapShowing() then
        pcall(SCENE_MANAGER.HideCurrentScene, SCENE_MANAGER)
    end

    local function verifyClosed()
        if not self:IsMapTeleporterMapShowing() then return end
        if SYSTEMS and type(SYSTEMS.GetObject) == "function" and MENU_CATEGORY_MAP ~= nil then
            local okObject, mainMenu = pcall(SYSTEMS.GetObject, SYSTEMS, "mainMenu")
            if okObject and mainMenu and type(mainMenu.ToggleCategory) == "function" then
                pcall(mainMenu.ToggleCategory, mainMenu, MENU_CATEGORY_MAP)
            end
        end
        if self:IsMapTeleporterMapShowing() and SCENE_MANAGER and type(SCENE_MANAGER.Hide) == "function" then
            pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "worldMap")
        end
    end
    if type(zo_callLater) == "function" then zo_callLater(verifyClosed, 60) else verifyClosed() end
end

CloseWorldMap02971ImplArch = function(self)
    return self:CloseWorldMap02972()
end

-- The old KEYBIND_STRIP entry used TOGGLE_MAP as a keybind-strip action. Keep
-- ESO's strip untouched; the dedicated Suite control below always shows the
-- actual Map binding and cannot become "Not Bound" because of UI_SHORTCUT_EXIT.
SetMapTeleporterCloseKeybindVisible02971ImplArch = function(self, visible)
    if self.mapTeleporterCloseKeybindAdded02971 and KEYBIND_STRIP and type(KEYBIND_STRIP.RemoveKeybindButtonGroup) == "function" then
        pcall(KEYBIND_STRIP.RemoveKeybindButtonGroup, KEYBIND_STRIP, self.mapTeleporterCloseKeybindGroup02971)
    end
    self.mapTeleporterCloseKeybindAdded02971 = false
end

local EAS_CreateMapTeleporterBase02972 = CreateMapTeleporterImplArch
CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase02972(self)
    if not root or not WINDOW_MANAGER then return root end

    -- Reuse the existing title button if present, but make it larger/clearer and
    -- add a second footer hint so the close binding is always visible.
    if root.closeMapButton02971 then
        root.closeMapButton02971:SetDimensions(168, 30)
        root.closeMapButton02971:SetHandler("OnClicked", function() self:CloseWorldMap02972() end)
    end

    if not root.mapCloseHint02972 then
        local hint = WINDOW_MANAGER:CreateControl(nil, root, CT_BUTTON)
        hint:SetDimensions(188, 28)
        hint:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -94, -7)
        hint:SetFont("ZoFontGameBold")
        hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        hint:SetNormalFontColor(1.00, 0.84, 0.38, 1)
        hint:SetMouseOverFontColor(1.00, 0.94, 0.70, 1)
        hint:SetPressedFontColor(1.00, 0.94, 0.70, 1)
        hint:SetHandler("OnClicked", function() self:CloseWorldMap02972() end)
        root.mapCloseHint02972 = hint

        local bg = WINDOW_MANAGER:CreateControl(nil, hint, CT_BACKDROP)
        bg:SetAnchorFill(hint)
        bg:SetCenterColor(0.025, 0.032, 0.046, 0.98)
        bg:SetEdgeColor(0.72, 0.56, 0.20, 0.95)
        bg:SetDrawLayer(DL_BACKGROUND)
        hint.bg02972 = bg

        -- Move page text slightly left so the explicit close control has its own
        -- readable footer space without covering PREV/NEXT.
        if root.page then
            root.page:ClearAnchors()
            root.page:SetAnchor(BOTTOM, root, BOTTOM, -120, -9)
        end
    end

    root.mapCloseHint02972:SetText(EAS_MapBindingText02972() .. "  -  CLOSE MAP")
    if root.closeMapButton02971 then root.closeMapButton02971:SetText(EAS_MapBindingText02972() .. "  CLOSE MAP") end
    return root
end

local EAS_RefreshMapTeleporterBase02972 = RefreshMapTeleporterImplArch
RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase02972(self, ...)
    local root = self.mapTeleporter
    if root then
        local keyText = EAS_MapBindingText02972()
        if root.mapCloseHint02972 then root.mapCloseHint02972:SetText(keyText .. "  -  CLOSE MAP") end
        if root.closeMapButton02971 then root.closeMapButton02971:SetText(keyText .. "  CLOSE MAP") end
    end
    return result
end

-- ============================================================================
-- v0.29.83 - Native map toggle + plain-text Teleporter UI.
-- Remove Suite-owned close-map buttons/hints and decorative arrow/caret glyphs.
-- The player's normal TOGGLE_MAP binding remains the map open/close control.
-- If a Teleporter search edit box owns keyboard focus, forward that same map
-- binding to ESO's native main-menu map toggle instead of inserting the key.
-- ============================================================================
local EAS_CreateMapTeleporterBase02983 = CreateMapTeleporterImplArch
local EAS_RefreshMapTeleporterBase02983 = RefreshMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase02983 = LayoutMapTeleporterImplArch

local function EAS_ToggleNativeWorldMap02983()
    if SYSTEMS and type(SYSTEMS.GetObject) == "function" and MENU_CATEGORY_MAP ~= nil then
        local okObject, mainMenu = pcall(SYSTEMS.GetObject, SYSTEMS, "mainMenu")
        if okObject and mainMenu and type(mainMenu.ToggleCategory) == "function" then
            local okToggle = pcall(mainMenu.ToggleCategory, mainMenu, MENU_CATEGORY_MAP)
            if okToggle then return true end
        end
    end
    return false
end

local function EAS_GetMapBindingKeyCode02983()
    if type(GetHighestPriorityActionBindingInfoFromName) == "function" then
        local ok, keyCode = pcall(GetHighestPriorityActionBindingInfoFromName, "TOGGLE_MAP", false)
        if ok and keyCode and (KEY_INVALID == nil or keyCode ~= KEY_INVALID) then
            return keyCode
        end
    end
    return nil
end

local function EAS_InstallSearchMapToggle02983(self, edit)
    if not edit or edit.easMapToggle02983 then return end
    edit.easMapToggle02983 = true
    edit:SetHandler("OnKeyDown", function(control, keyCode)
        local mapKey = EAS_GetMapBindingKeyCode02983()
        if mapKey and keyCode == mapKey then
            if control.LoseFocus then pcall(control.LoseFocus, control) end
            self.mapTeleporterSearchFocused = false
            self:HideMapTeleporterFlyout02969()
            EAS_ToggleNativeWorldMap02983()
        end
    end)
end

local function EAS_CleanTeleporterStaticText02983(self, root)
    if not root then return end

    -- No custom close-map controls. The World Map's normal binding owns close.
    if root.closeMapButton02971 then
        root.closeMapButton02971:SetHidden(true)
        root.closeMapButton02971:SetMouseEnabled(false)
    end
    if root.mapCloseHint02972 then
        root.mapCloseHint02972:SetHidden(true)
        root.mapCloseHint02972:SetMouseEnabled(false)
    end

    if root.title then
        root.title:ClearAnchors()
        root.title:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 7)
        root.title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 7)
        root.title:SetHeight(30)
    end

    local viewLabel = self:GetMapTeleporterViewLabel02967(self.mapTeleporterMode or "ALL")
    if root.viewButton then root.viewButton:SetText(string.upper(viewLabel)) end
    if root.toolsButton then root.toolsButton:SetText("TOOLS") end
    if root.favoriteButton then root.favoriteButton:SetText("FAVORITES") end
    if root.prev then root.prev:SetText("PREVIOUS") end
    if root.next then root.next:SetText("NEXT") end

    if root.playerSearchLabel then root.playerSearchLabel:SetText("PLAYER OR DESTINATION") end
    if root.zoneSearchLabel then root.zoneSearchLabel:SetText("ZONE") end

    if root.flyout02969 and root.flyout02969.close02969 then
        local close = root.flyout02969.close02969
        close:SetText("CLOSE")
        close:SetDimensions(62, 26)
        close:ClearAnchors()
        close:SetAnchor(TOPRIGHT, root.flyout02969, TOPRIGHT, -6, 5)
        if root.flyout02969.title02969 then
            root.flyout02969.title02969:ClearAnchors()
            root.flyout02969.title02969:SetAnchor(TOPLEFT, root.flyout02969, TOPLEFT, 12, 8)
            root.flyout02969.title02969:SetAnchor(TOPRIGHT, close, TOPLEFT, -8, 8)
            root.flyout02969.title02969:SetHeight(24)
        end
    end

    EAS_InstallSearchMapToggle02983(self, root.playerSearch)
    EAS_InstallSearchMapToggle02983(self, root.zoneSearch)

    -- Replace decorative favorite markers with short plain words.
    for _, row in ipairs(root.rows or {}) do
        if row.star then
            row.star:SetDimensions(36, 22)
            if row.entry then
                row.star:SetText(self:IsMapTeleporterFavorite(row.entry) and "FAV" or "ADD")
            else
                row.star:SetText("")
            end
        end
        if row.name then
            row.name:ClearAnchors()
            row.name:SetAnchor(TOPLEFT, row, TOPLEFT, 44, 2)
            row.name:SetAnchor(TOPRIGHT, row, TOPRIGHT, -98, 2)
            row.name:SetHeight(18)
        end
        if row.zone then
            row.zone:ClearAnchors()
            row.zone:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 44, -2)
            row.zone:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -98, -2)
            row.zone:SetHeight(16)
        end
    end

    if root.page then
        root.page:ClearAnchors()
        root.page:SetAnchor(BOTTOM, root, BOTTOM, 0, -9)
        root.page:SetDimensions(180, 24)
    end
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase02983(self)
    EAS_CleanTeleporterStaticText02983(self, root)
    return root
end

LayoutMapTeleporterImplArch = function(self)
    EAS_LayoutMapTeleporterBase02983(self)
    EAS_CleanTeleporterStaticText02983(self, self.mapTeleporter)
end

RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase02983(self, ...)
    local root = self.mapTeleporter
    if not root then return result end

    local entries = self.mapTeleporterEntries or {}
    local perPage = safeNumber(root.visibleRows, 15)
    local pages = math.max(1, math.ceil(#entries / math.max(1, perPage)))
    local page = math.max(1, math.min(safeNumber(self.mapTeleporterPage, 1), pages))
    local viewLabel = self:GetMapTeleporterViewLabel02967(self.mapTeleporterMode or "ALL")

    if root.stats then
        local text = string.format("%d destination%s   %s", #entries, #entries == 1 and "" or "s", viewLabel)
        if self.mapTeleporterDiscoveryActive then
            text = text .. "   DISCOVERY " .. tostring(self.mapTeleporterDiscoveryIndex or 1) .. " OF " .. tostring(#(self.mapTeleporterDiscoveryQueue or {}))
        end
        root.stats:SetText(text)
    end
    if root.page then root.page:SetText(string.format("PAGE %d OF %d", page, pages)) end

    for _, row in ipairs(root.rows or {}) do
        if row.entry and row.star then
            row.star:SetText(self:IsMapTeleporterFavorite(row.entry) and "FAV" or "ADD")
        end
    end

    EAS_CleanTeleporterStaticText02983(self, root)
    return result
end

-- Keep the internal flyout menus plain-text as well.
local EAS_ShowMapTeleporterFlyoutBase02983 = ShowMapTeleporterFlyout02969ImplArch
ShowMapTeleporterFlyout02969ImplArch = function(self, titleText, items, owner, contextMode)
    local result = EAS_ShowMapTeleporterFlyoutBase02983(self, titleText, items, owner, contextMode)
    local root = self.mapTeleporter
    if root and root.flyout02969 then
        local flyout = root.flyout02969
        if flyout.close02969 then
            flyout.close02969:SetText("CLOSE")
            flyout.close02969:SetDimensions(62, 26)
        end
        for _, row in ipairs(flyout.rows02969 or {}) do
            if row.label02982 and row.item02969 then
                local label = tostring(row.item02969.label or "Option")
                label = string.gsub(label, " / ", " OR ")
                label = string.gsub(label, " %+, ", " AND ")
                label = string.gsub(label, " %+ ", " AND ")
                row.label02982:SetText(label)
            end
        end
    end
    return result
end

-- ============================================================================
-- v0.29.84 - Search focus owns typing; native map binding owns map close.
-- While either Teleporter search edit box has keyboard focus, do not intercept
-- TOGGLE_MAP. This lets the player's map-key character be typed normally. Once
-- focus leaves the search boxes, ESO's native TOGGLE_MAP binding closes the map
-- exactly as it does without the Teleporter.
-- ============================================================================
local EAS_CreateMapTeleporterBase02984 = CreateMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase02984 = LayoutMapTeleporterImplArch

function T:ReleaseMapTeleporterSearchFocus02984()
    local root = self.mapTeleporter
    if not root then return end
    if root.playerSearch and root.playerSearch.LoseFocus then
        pcall(root.playerSearch.LoseFocus, root.playerSearch)
    end
    if root.zoneSearch and root.zoneSearch.LoseFocus then
        pcall(root.zoneSearch.LoseFocus, root.zoneSearch)
    end
    self.mapTeleporterSearchFocused = false
end

function T:ApplyMapTeleporterSearchFocus02984(root)
    if not root then return end

    local function restoreNativeTyping(edit)
        if not edit then return end
        -- v0.29.83 installed an OnKeyDown handler that explicitly toggled the
        -- World Map when the map binding was pressed. Remove it. CT_EDITBOX then
        -- keeps normal keyboard ownership while focused.
        if edit.SetHandler then edit:SetHandler("OnKeyDown", nil) end
    end
    restoreNativeTyping(root.playerSearch)
    restoreNativeTyping(root.zoneSearch)

    -- Clicking normal Teleporter controls means the user is no longer typing.
    -- Drop edit-box focus before those controls run so ESO's native map binding
    -- immediately resumes normal open/close behavior.
    local function releaseOnMouseDown(control)
        if not control or control.easReleaseSearchFocus02984 then return end
        control.easReleaseSearchFocus02984 = true
        control:SetHandler("OnMouseDown", function()
            self:ReleaseMapTeleporterSearchFocus02984()
        end)
    end

    releaseOnMouseDown(root.viewButton)
    releaseOnMouseDown(root.toolsButton)
    releaseOnMouseDown(root.favoriteButton)
    releaseOnMouseDown(root.prev)
    releaseOnMouseDown(root.next)
    for _, row in ipairs(root.rows or {}) do
        releaseOnMouseDown(row)
        releaseOnMouseDown(row.star)
    end
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase02984(self)
    self:ApplyMapTeleporterSearchFocus02984(root)
    return root
end

LayoutMapTeleporterImplArch = function(self, ...)
    local result = EAS_LayoutMapTeleporterBase02984(self, ...)
    self:ApplyMapTeleporterSearchFocus02984(self.mapTeleporter)
    return result
end


-- ============================================================================
-- v0.29.85 - Replace ESO's generic UI "Exit" hint with the real Map binding.
-- ESO's default world-map exit descriptor uses UI_SHORTCUT_EXIT, which inherits
-- from TOGGLE_GAME_CAMERA_UI_MODE and can display "Not Bound" independently of
-- the player's TOGGLE_MAP binding. While the Suite Teleporter is attached we
-- remove only that default Exit descriptor and add a native keybind-strip entry
-- tied directly to TOGGLE_MAP. Search edit boxes temporarily hide this entry so
-- typing keeps keyboard ownership; leaving search restores it immediately.
-- ============================================================================
function T:EnsureNativeMapToggleDescriptor02985()
    if self.nativeMapToggleDescriptor02985 then return self.nativeMapToggleDescriptor02985 end
    self.nativeMapToggleDescriptor02985 = {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        {
            name = "Close Map",
            keybind = "TOGGLE_MAP",
            callback = function()
                -- Mouse-clicking the keybind-strip entry should behave exactly
                -- like the player's normal Map action.
                if EAS_ToggleNativeWorldMap02983 then
                    EAS_ToggleNativeWorldMap02983()
                elseif SYSTEMS and type(SYSTEMS.GetObject) == "function" and MENU_CATEGORY_MAP ~= nil then
                    local okObject, mainMenu = pcall(SYSTEMS.GetObject, SYSTEMS, "mainMenu")
                    if okObject and mainMenu and type(mainMenu.ToggleCategory) == "function" then
                        pcall(mainMenu.ToggleCategory, mainMenu, MENU_CATEGORY_MAP)
                    end
                end
            end,
            visible = function()
                local root = self.mapTeleporter
                return root ~= nil
                    and not root:IsHidden()
                    and self:IsMapTeleporterMapShowing()
                    and self.mapTeleporterSearchFocused ~= true
            end,
        },
    }
    return self.nativeMapToggleDescriptor02985
end

local UpdateNativeMapToggleStrip02985ImplArch

function T:UpdateNativeMapToggleStrip02985(...)

    return UpdateNativeMapToggleStrip02985ImplArch(self, ...)

end

UpdateNativeMapToggleStrip02985ImplArch = function(self)
    local strip = KEYBIND_STRIP
    if not strip then return end
    local root = self.mapTeleporter
    local teleporterVisible = root ~= nil and not root:IsHidden() and self:IsMapTeleporterMapShowing()

    if teleporterVisible then
        -- Remove ESO's generic UI_SHORTCUT_EXIT item (the source of
        -- "Not Bound - Exit") while preserving the rest of the map strip.
        if not self.nativeDefaultExitRemoved02985 and type(strip.RemoveDefaultExit) == "function" then
            local ok = pcall(strip.RemoveDefaultExit, strip)
            if ok then self.nativeDefaultExitRemoved02985 = true end
        end

        local descriptor = self:EnsureNativeMapToggleDescriptor02985()
        if self.mapTeleporterSearchFocused == true then
            if self.nativeMapToggleAdded02985 and type(strip.RemoveKeybindButtonGroup) == "function" then
                pcall(strip.RemoveKeybindButtonGroup, strip, descriptor)
                self.nativeMapToggleAdded02985 = false
            end
        else
            if not self.nativeMapToggleAdded02985 and type(strip.AddKeybindButtonGroup) == "function" then
                local ok = pcall(strip.AddKeybindButtonGroup, strip, descriptor)
                if ok then self.nativeMapToggleAdded02985 = true end
            elseif self.nativeMapToggleAdded02985 and type(strip.UpdateKeybindButtonGroup) == "function" then
                pcall(strip.UpdateKeybindButtonGroup, strip, descriptor)
            end
        end
    else
        local descriptor = self.nativeMapToggleDescriptor02985
        if self.nativeMapToggleAdded02985 and descriptor and type(strip.RemoveKeybindButtonGroup) == "function" then
            pcall(strip.RemoveKeybindButtonGroup, strip, descriptor)
            self.nativeMapToggleAdded02985 = false
        end
        if self.nativeDefaultExitRemoved02985 and type(strip.RestoreDefaultExit) == "function" then
            pcall(strip.RestoreDefaultExit, strip)
            self.nativeDefaultExitRemoved02985 = false
        end
    end
end

function T:ApplyMapTeleporterSearchFocus02985(root)
    if not root then return end
    local function install(edit)
        if not edit then return end
        edit:SetHandler("OnFocusGained", function()
            self.mapTeleporterSearchFocused = true
            self:UpdateNativeMapToggleStrip02985()
        end)
        edit:SetHandler("OnFocusLost", function()
            -- Either edit may lose focus while the other gains it. Delay the
            -- check one frame so the new focus owner has already been applied.
            local function finish()
                local focused = false
                if root.playerSearch and type(root.playerSearch.HasFocus) == "function" then
                    local ok, value = pcall(root.playerSearch.HasFocus, root.playerSearch)
                    focused = focused or (ok and value == true)
                end
                if root.zoneSearch and type(root.zoneSearch.HasFocus) == "function" then
                    local ok, value = pcall(root.zoneSearch.HasFocus, root.zoneSearch)
                    focused = focused or (ok and value == true)
                end
                self.mapTeleporterSearchFocused = focused
                self:UpdateNativeMapToggleStrip02985()
            end
            if type(zo_callLater) == "function" then zo_callLater(finish, 0) else finish() end
        end)
    end
    install(root.playerSearch)
    install(root.zoneSearch)
end

local EAS_CreateMapTeleporterBase02985 = CreateMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase02985 = LayoutMapTeleporterImplArch
local EAS_SetMapTeleporterVisibleBase02985 = SetMapTeleporterVisibleImplArch
local EAS_RefreshMapTeleporterVisibilityBase02985 = RefreshMapTeleporterVisibilityImplArch

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase02985(self)
    self:ApplyMapTeleporterSearchFocus02985(root)
    return root
end

LayoutMapTeleporterImplArch = function(self, ...)
    local result = EAS_LayoutMapTeleporterBase02985(self, ...)
    self:ApplyMapTeleporterSearchFocus02985(self.mapTeleporter)
    self:UpdateNativeMapToggleStrip02985()
    return result
end

SetMapTeleporterVisibleImplArch = function(self, visible)
    local result = EAS_SetMapTeleporterVisibleBase02985(self, visible)
    self:ApplyMapTeleporterSearchFocus02985(self.mapTeleporter)
    self:UpdateNativeMapToggleStrip02985()
    return result
end

RefreshMapTeleporterVisibilityImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterVisibilityBase02985(self, ...)
    self:UpdateNativeMapToggleStrip02985()
    return result
end

-- ============================================================================
-- v0.29.86 - Make the displayed TOGGLE_MAP key actually close the World Map.
-- KEYBIND_STRIP can display arbitrary action bindings, but a descriptor using
-- TOGGLE_MAP does not reliably receive that action while the World Map owns its
-- action layer. Capture the raw keyboard event on the Teleporter window and
-- compare it against the player's real TOGGLE_MAP binding. Search edit boxes
-- remain exempt so typing is never treated as a map-close request.
-- ============================================================================
local RawKeyMatchesAction02986ImplArch
function T:RawKeyMatchesAction02986(...)
    return RawKeyMatchesAction02986ImplArch(self, ...)
end
RawKeyMatchesAction02986ImplArch = function(self, actionName, key, ctrl, alt, shift, command)
    if type(GetNumActionLayers) ~= "function" or type(GetActionLayerInfo) ~= "function"
        or type(GetActionLayerCategoryInfo) ~= "function" or type(GetActionInfo) ~= "function"
        or type(GetActionBindingInfo) ~= "function" then
        return false
    end

    local function modifierPresent(modifierKey, m1, m2, m3, m4)
        if modifierKey == nil then return false end
        if type(ZO_Keybindings_DoesKeyMatchAnyModifiers) == "function" then
            return ZO_Keybindings_DoesKeyMatchAnyModifiers(modifierKey, m1, m2, m3, m4) == true
        end
        return m1 == modifierKey or m2 == modifierKey or m3 == modifierKey or m4 == modifierKey
    end

    local numLayers = GetNumActionLayers() or 0
    for layerIndex = 1, numLayers do
        local _, numCategories = GetActionLayerInfo(layerIndex)
        for categoryIndex = 1, (numCategories or 0) do
            local _, numActions = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
            for actionIndex = 1, (numActions or 0) do
                local name = GetActionInfo(layerIndex, categoryIndex, actionIndex)
                if name == actionName then
                    for bindingIndex = 1, 4 do
                        local boundKey, m1, m2, m3, m4 = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindingIndex)
                        if boundKey and (KEY_INVALID == nil or boundKey ~= KEY_INVALID) and boundKey == key then
                            local wantCtrl = KEY_CTRL and modifierPresent(KEY_CTRL, m1, m2, m3, m4) or false
                            local wantAlt = KEY_ALT and modifierPresent(KEY_ALT, m1, m2, m3, m4) or false
                            local wantShift = KEY_SHIFT and modifierPresent(KEY_SHIFT, m1, m2, m3, m4) or false
                            local wantCommand = KEY_COMMAND and modifierPresent(KEY_COMMAND, m1, m2, m3, m4) or false
                            if (ctrl == true) == wantCtrl and (alt == true) == wantAlt
                                and (shift == true) == wantShift and (command == true) == wantCommand then
                                return true
                            end
                        end
                    end
                    return false
                end
            end
        end
    end
    return false
end

function T:IsMapTeleporterSearchActuallyFocused02986()
    local root = self.mapTeleporter
    if not root then return false end
    local function hasFocus(edit)
        if edit and type(edit.HasFocus) == "function" then
            local ok, value = pcall(edit.HasFocus, edit)
            return ok and value == true
        end
        return false
    end
    return self.mapTeleporterSearchFocused == true or hasFocus(root.playerSearch) or hasFocus(root.zoneSearch)
end

function T:ForceCloseWorldMap02986()
    if self:IsMapTeleporterSearchActuallyFocused02986() then return false end

    self:HideMapTeleporterFlyout02969()
    local root = self.mapTeleporter
    if root then
        if root.playerSearch and root.playerSearch.LoseFocus then pcall(root.playerSearch.LoseFocus, root.playerSearch) end
        if root.zoneSearch and root.zoneSearch.LoseFocus then pcall(root.zoneSearch.LoseFocus, root.zoneSearch) end
    end
    self.mapTeleporterSearchFocused = false

    local function hideMapNow()
        if not self:IsMapTeleporterMapShowing() then return true end

        -- First ask the actual world-map scene to hide. Do not depend on the
        -- keybind-strip action routing that failed in v0.29.85.
        if SCENE_MANAGER and type(SCENE_MANAGER.Hide) == "function" then
            pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "worldMap")
        end
        if not self:IsMapTeleporterMapShowing() then return true end

        -- Some map states are nested under the main menu rather than a plain
        -- worldMap scene. Toggle the native Map category only if it is still
        -- showing after the direct hide request.
        if SYSTEMS and type(SYSTEMS.GetObject) == "function" and MENU_CATEGORY_MAP ~= nil then
            local okObject, mainMenu = pcall(SYSTEMS.GetObject, SYSTEMS, "mainMenu")
            if okObject and mainMenu and type(mainMenu.ToggleCategory) == "function" then
                pcall(mainMenu.ToggleCategory, mainMenu, MENU_CATEGORY_MAP)
            end
        end

        if self:IsMapTeleporterMapShowing() and SCENE_MANAGER and type(SCENE_MANAGER.HideCurrentScene) == "function" then
            pcall(SCENE_MANAGER.HideCurrentScene, SCENE_MANAGER)
        end
        return not self:IsMapTeleporterMapShowing()
    end

    hideMapNow()
    -- Native action dispatch can run immediately after the raw OnKeyDown event.
    -- Re-check after it has finished so a second toggle cannot leave the map
    -- reopened.
    if type(zo_callLater) == "function" then
        zo_callLater(hideMapNow, 40)
        zo_callLater(hideMapNow, 140)
    end
    return true
end

local ApplyRawMapToggleHandler02986ImplArch

function T:ApplyRawMapToggleHandler02986(...)

    return ApplyRawMapToggleHandler02986ImplArch(self, ...)

end

ApplyRawMapToggleHandler02986ImplArch = function(self, root)
    if not root then return end
    if root.SetKeyboardEnabled then root:SetKeyboardEnabled(true) end
    root:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
        if not self:IsMapTeleporterMapShowing() or root:IsHidden() then return end
        if self:IsMapTeleporterSearchActuallyFocused02986() then return end
        if self:RawKeyMatchesAction02986("TOGGLE_MAP", key, ctrl, alt, shift, command) then
            self:ForceCloseWorldMap02986()
        end
    end)

    -- Keep the visible keybind-strip entry useful when clicked with the mouse.
    local descriptor = self:EnsureNativeMapToggleDescriptor02985()
    if descriptor and descriptor[1] then
        descriptor[1].callback = function() self:ForceCloseWorldMap02986() end
    end
end

local EAS_CreateMapTeleporterBase02986 = CreateMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase02986 = LayoutMapTeleporterImplArch
local EAS_SetMapTeleporterVisibleBase02986 = SetMapTeleporterVisibleImplArch

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase02986(self)
    self:ApplyRawMapToggleHandler02986(root)
    return root
end

LayoutMapTeleporterImplArch = function(self, ...)
    local result = EAS_LayoutMapTeleporterBase02986(self, ...)
    self:ApplyRawMapToggleHandler02986(self.mapTeleporter)
    return result
end

SetMapTeleporterVisibleImplArch = function(self, visible)
    local result = EAS_SetMapTeleporterVisibleBase02986(self, visible)
    self:ApplyRawMapToggleHandler02986(self.mapTeleporter)
    return result
end

-- ============================================================================
-- v0.29.114 - Smooth World Map Teleporter opening.
-- Large guild rosters previously scanned synchronously every time the World Map
-- opened (and again on the 1.6s live refresh).  Build guild destinations in
-- small frame-sized batches, reuse the completed cache, and coalesce duplicate
-- scene callbacks so opening/closing the map does not hitch the UI.
-- ============================================================================
local EAS_GetGuildMembersSyncBase029114 = GetGuildMembersImplArch
local EAS_RefreshMapTeleporterBase029114 = RefreshMapTeleporterImplArch
local EAS_SetMapTeleporterVisibleBase029114 = SetMapTeleporterVisibleImplArch

local function EAS_MapTeleporterNowMs029114()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return safeNumber(value, 0) end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return safeNumber(value, 0) end
    end
    return 0
end

function T:StartMapTeleporterGuildCacheBuild029114(snapshot)
    if self.mapTeleporterGuildBuild029114 then return end

    local guildCount = 0
    if type(GetNumGuilds) == "function" then
        local ok, value = pcall(GetNumGuilds)
        if ok then guildCount = safeNumber(value, 0) end
    end

    local state = {
        entries = {},
        seen = {},
        guildCount = guildCount,
        guildIndex = 1,
        memberIndex = 1,
        guildId = nil,
        guildName = "Guild",
        memberCount = 0,
        currentZone = lower(snapshot and snapshot.zoneName or ""),
        ownDisplayName = clean(type(GetDisplayName) == "function" and GetDisplayName() or "", ""),
    }
    local canLeave, leaveReason = self:CanLeaveNow()
    state.canLeave = canLeave
    state.leaveReason = leaveReason
    self.mapTeleporterGuildBuild029114 = state

    local function beginGuild()
        state.guildId = nil
        state.guildName = "Guild"
        state.memberCount = 0
        state.memberIndex = 1

        if state.guildIndex > state.guildCount then return false end
        if type(GetGuildId) == "function" then
            local ok, value = pcall(GetGuildId, state.guildIndex)
            if ok then state.guildId = value end
        end
        if state.guildId then
            if type(GetGuildName) == "function" then
                local ok, value = pcall(GetGuildName, state.guildId)
                if ok then state.guildName = clean(value, state.guildName) end
            end
            if type(GetNumGuildMembers) == "function" then
                local ok, value = pcall(GetNumGuildMembers, state.guildId)
                if ok then state.memberCount = safeNumber(value, 0) end
            end
        end
        return true
    end

    beginGuild()

    local function finish()
        table.sort(state.entries, currentZoneFirstSort)
        self.mapTeleporterGuildCache029114 = state.entries
        self.mapTeleporterGuildCacheExpires029114 = EAS_MapTeleporterNowMs029114() + 10000
        self.mapTeleporterGuildBuild029114 = nil

        local root = self.mapTeleporter
        if root and not root:IsHidden() and self:IsMapTeleporterMapShowing() then
            if type(zo_callLater) == "function" then
                zo_callLater(function()
                    if EPC and EPC.Travel and EPC.Travel.mapTeleporter and not EPC.Travel.mapTeleporter:IsHidden() then
                        EPC.Travel:RefreshMapTeleporter(true)
                    end
                end, 0)
            else
                self:RefreshMapTeleporter(true)
            end
        end
    end

    local function step()
        if self.mapTeleporterGuildBuild029114 ~= state then return end
        local processed = 0
        local budget = 70

        while processed < budget and state.guildIndex <= state.guildCount do
            if not state.guildId or state.memberIndex > state.memberCount then
                state.guildIndex = state.guildIndex + 1
                if state.guildIndex > state.guildCount then break end
                beginGuild()
            else
                local memberIndex = state.memberIndex
                state.memberIndex = state.memberIndex + 1
                processed = processed + 1

                if type(GetGuildMemberInfo) == "function" then
                    local infoOk, displayName, _, _, playerStatus, secsSinceLogoff = pcall(GetGuildMemberInfo, state.guildId, memberIndex)
                    displayName = clean(displayName, "")
                    local dedupeKey = lower(displayName)

                    if infoOk and displayName ~= "" and displayName ~= state.ownDisplayName
                        and not state.seen[dedupeKey] and isOnlineStatus(playerStatus, secsSinceLogoff)
                        and type(GetGuildMemberCharacterInfo) == "function" then
                        local characterOk, hasCharacter, characterName, zoneName, _, _, _, _, zoneId = pcall(GetGuildMemberCharacterInfo, state.guildId, memberIndex)
                        if characterOk and hasCharacter then
                            state.seen[dedupeKey] = true
                            zoneName = clean(zoneName, "Unknown location")
                            characterName = clean(characterName, displayName)
                            local canJump, result = getJumpAvailability(zoneId)
                            local ready = state.canLeave and canJump
                            local statusText = not state.canLeave and state.leaveReason or (canJump and "Ready" or jumpResultText(result))

                            state.entries[#state.entries + 1] = {
                                kind = "GUILD",
                                key = "G:" .. dedupeKey,
                                name = displayName,
                                displayName = displayName,
                                characterName = characterName,
                                guildName = state.guildName,
                                zoneName = zoneName,
                                zoneId = zoneId,
                                displayText = displayName .. " - " .. zoneName,
                                costText = "Free",
                                statusText = statusText,
                                canTravel = ready,
                                isCurrentZone = state.currentZone ~= "" and lower(zoneName) == state.currentZone,
                            }
                        end
                    end
                end
            end
        end

        if state.guildIndex > state.guildCount then
            finish()
            return
        end

        if type(zo_callLater) == "function" then
            zo_callLater(step, 0)
        else
            -- Extremely old/fallback UI path: preserve functionality even when
            -- the frame scheduler is unavailable.
            self.mapTeleporterGuildBuild029114 = nil
            self.mapTeleporterGuildCache029114 = EAS_GetGuildMembersSyncBase029114(self, snapshot) or {}
            self.mapTeleporterGuildCacheExpires029114 = EAS_MapTeleporterNowMs029114() + 10000
        end
    end

    if type(zo_callLater) == "function" then zo_callLater(step, 0) else step() end
end

GetGuildMembersImplArch = function(self, snapshot)
    local now = EAS_MapTeleporterNowMs029114()
    local cache = self.mapTeleporterGuildCache029114
    local expires = safeNumber(self.mapTeleporterGuildCacheExpires029114, 0)

    if type(cache) == "table" and (now == 0 or now < expires) then
        return cache
    end

    self:StartMapTeleporterGuildCacheBuild029114(snapshot or self:GetMapTeleporterSnapshot())
    -- Never block the World Map waiting for a large guild scan.  A stale cache
    -- is preferable to a frame hitch; on first use the list fills in as soon as
    -- the batched scan completes.
    return type(cache) == "table" and cache or {}
end

RefreshMapTeleporterImplArch = function(self, force029114)
    local root = self.mapTeleporter
    if not root or root:IsHidden() then return end

    if self.mapTeleporterOpening029114 == true and force029114 ~= true then
        self.mapTeleporterRefreshPending029114 = true
        return
    end

    local now = EAS_MapTeleporterNowMs029114()
    local last = safeNumber(self.mapTeleporterLastRefresh029114, 0)
    if force029114 ~= true and now > 0 and last > 0 and (now - last) < 180 then
        if not self.mapTeleporterRefreshPending029114 and type(zo_callLater) == "function" then
            self.mapTeleporterRefreshPending029114 = true
            local delay = math.max(1, 180 - (now - last))
            zo_callLater(function()
                local travel = EPC and EPC.Travel
                if not travel then return end
                travel.mapTeleporterRefreshPending029114 = false
                if travel.mapTeleporter and not travel.mapTeleporter:IsHidden() and travel:IsMapTeleporterMapShowing() then
                    travel:RefreshMapTeleporter(true)
                end
            end, delay)
        end
        return
    end

    self.mapTeleporterRefreshPending029114 = false
    self.mapTeleporterLastRefresh029114 = now
    return EAS_RefreshMapTeleporterBase029114(self)
end

SetMapTeleporterVisibleImplArch = function(self, visible)
    local wantVisible = visible == true and EPC.saved and EPC.saved.mapTeleporterEnabled ~= false
    local root = self.mapTeleporter
    local currentlyVisible = root and not root:IsHidden() or false

    -- SceneStateChanged can fire several times while the same map transition is
    -- settling.  Do not rebuild/re-register the Teleporter when visibility did
    -- not actually change.
    if wantVisible == currentlyVisible then
        if wantVisible and root then
            self:ApplyRawMapToggleHandler02986(root)
            self:ApplyMapTeleporterSearchFocus02985(root)
            self:UpdateNativeMapToggleStrip02985()
        elseif not wantVisible and self.mapTeleporterRefreshPending029114 then
            self.mapTeleporterRefreshPending029114 = false
        end
        return
    end

    if wantVisible then self.mapTeleporterOpening029114 = true end
    local result = EAS_SetMapTeleporterVisibleBase029114(self, wantVisible)
    self.mapTeleporterOpening029114 = false

    if wantVisible then
        -- Replace the old 1.6-second full refresh with a calmer live update.
        -- Group/friend rows still stay current, while guild data is maintained by
        -- the frame-sliced cache above.
        if EVENT_MANAGER then
            EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
            EPC.Runtime:RegisterUpdate("Travel", "MapTeleporterRefresh", 3500, function()
                local travel = EPC and EPC.Travel
                if travel and travel.mapTeleporter and not travel.mapTeleporter:IsHidden() and travel:IsMapTeleporterMapShowing() then
                    if travel.HideMapCompletionForTeleporter then travel:HideMapCompletionForTeleporter(true) end
                    travel:RefreshMapTeleporter()
                else
                    EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
                end
            end)
        end

        -- Let ESO finish the map scene/layout first, then populate destinations.
        -- This keeps the key press that opens the map on a light frame.
        if type(zo_callLater) == "function" then
            self.mapTeleporterRefreshPending029114 = true
            zo_callLater(function()
                local travel = EPC and EPC.Travel
                if not travel then return end
                travel.mapTeleporterRefreshPending029114 = false
                if travel.mapTeleporter and not travel.mapTeleporter:IsHidden() and travel:IsMapTeleporterMapShowing() then
                    travel:RefreshMapTeleporter(true)
                end
            end, 90)
        else
            self:RefreshMapTeleporter(true)
        end
    else
        self.mapTeleporterRefreshPending029114 = false
        if EVENT_MANAGER then EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh") end
    end

    return result
end

-- Fast TOGGLE_MAP key matching for the Teleporter close handler.  The direct
-- binding API avoids walking every action layer/category/action on each keydown.
local EAS_RawKeyMatchesActionBase029114 = RawKeyMatchesAction02986ImplArch
RawKeyMatchesAction02986ImplArch = function(self, actionName, key, ctrl, alt, shift, command)
    if type(GetHighestPriorityActionBindingInfoFromName) == "function" then
        local ok, boundKey, mod1, mod2, mod3, mod4 = pcall(GetHighestPriorityActionBindingInfoFromName, actionName, false)
        if ok and boundKey and (KEY_INVALID == nil or boundKey ~= KEY_INVALID) then
            if boundKey ~= key then return false end

            local function hasModifier(modifierKey)
                if modifierKey == nil then return false end
                return mod1 == modifierKey or mod2 == modifierKey or mod3 == modifierKey or mod4 == modifierKey
            end

            local wantCtrl = KEY_CTRL and hasModifier(KEY_CTRL) or false
            local wantAlt = KEY_ALT and hasModifier(KEY_ALT) or false
            local wantShift = KEY_SHIFT and hasModifier(KEY_SHIFT) or false
            local wantCommand = KEY_COMMAND and hasModifier(KEY_COMMAND) or false
            return (ctrl == true) == wantCtrl
                and (alt == true) == wantAlt
                and (shift == true) == wantShift
                and (command == true) == wantCommand
        end
    end
    return EAS_RawKeyMatchesActionBase029114(self, actionName, key, ctrl, alt, shift, command)
end

-- ============================================================================
-- v0.29.128 - Native World Map keyboard + collapsible Teleporter drawer.
-- The Teleporter must never own the World Map's keyboard layer.  ESO keeps
-- handling Escape, TOGGLE_MAP, player-location (R by default), zoom and every
-- other map action.  Only the two search edit boxes take keyboard focus when
-- the user explicitly clicks them.
-- ============================================================================
local EAS_CreateMapTeleporterBase029128 = CreateMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase029128 = LayoutMapTeleporterImplArch
local EAS_RefreshMapTeleporterBase029128 = RefreshMapTeleporterImplArch
local EAS_SetMapTeleporterVisibleBase029128 = SetMapTeleporterVisibleImplArch

local function EAS_SetControlHidden029128(control, hidden)
    if control and type(control.SetHidden) == "function" then
        pcall(control.SetHidden, control, hidden == true)
    end
end

local RestoreNativeWorldMapKeys029128ImplArch

function T:RestoreNativeWorldMapKeys029128(...)

    return RestoreNativeWorldMapKeys029128ImplArch(self, ...)

end

RestoreNativeWorldMapKeys029128ImplArch = function(self, root)
    if not root then return end

    -- A top-level keyboard-enabled Teleporter consumes keys before the native
    -- World Map can see them.  Remove the raw handler and keyboard ownership.
    if root.SetHandler then root:SetHandler("OnKeyDown", nil) end
    if root.SetKeyboardEnabled then root:SetKeyboardEnabled(false) end

    -- Search fields are the only controls allowed to own keyboard focus.
    local function fixSearch(edit)
        if not edit then return end
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end
        edit:SetHandler("OnEscape", function(c)
            if c and c.LoseFocus then pcall(c.LoseFocus, c) end
            self.mapTeleporterSearchFocused = false
            -- Escape from a focused search should still behave like Escape on
            -- the normal World Map instead of getting trapped in the edit box.
            if SCENE_MANAGER and type(SCENE_MANAGER.Hide) == "function" then
                pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "worldMap")
            elseif SCENE_MANAGER and type(SCENE_MANAGER.HideCurrentScene) == "function" then
                pcall(SCENE_MANAGER.HideCurrentScene, SCENE_MANAGER)
            end
        end)
    end
    fixSearch(root.playerSearch)
    fixSearch(root.zoneSearch)
end

-- Disable the old Teleporter-owned TOGGLE_MAP interception.  Calls from older
-- wrapper layers now simply restore native keyboard ownership.
ApplyRawMapToggleHandler02986ImplArch = function(self, root)
    self:RestoreNativeWorldMapKeys029128(root)
end

-- Do not replace ESO's standard Exit/map keybind strip.  Restore it if an older
-- Suite version removed it during this session.
UpdateNativeMapToggleStrip02985ImplArch = function(self)
    local strip = KEYBIND_STRIP
    if not strip then return end

    if self.nativeMapToggleAdded02985 and self.nativeMapToggleDescriptor02985
        and type(strip.RemoveKeybindButtonGroup) == "function" then
        pcall(strip.RemoveKeybindButtonGroup, strip, self.nativeMapToggleDescriptor02985)
    end
    self.nativeMapToggleAdded02985 = false

    if self.nativeDefaultExitRemoved02985 and type(strip.RestoreDefaultExit) == "function" then
        pcall(strip.RestoreDefaultExit, strip)
    end
    self.nativeDefaultExitRemoved02985 = false
end

local SetMapTeleporterExpanded029128ImplArch

function T:SetMapTeleporterExpanded029128(...)

    return SetMapTeleporterExpanded029128ImplArch(self, ...)

end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    local root = self.mapTeleporter
    if not root then return end
    expanded = expanded == true
    self.mapTeleporterExpanded029128 = expanded

    if saveState ~= false and EPC.saved then
        EPC.saved.mapTeleporterExpanded = expanded
    end

    if self.HideMapTeleporterFlyout02969 then self:HideMapTeleporterFlyout02969() end
    if not expanded and self.ReleaseMapTeleporterSearchFocus02984 then
        self:ReleaseMapTeleporterSearchFocus02984()
    end

    local normalControls = {
        root.title, root.viewButton, root.toolsButton, root.favoriteButton,
        root.playerSearchLabel, root.playerSearchBg, root.zoneSearchLabel, root.zoneSearchBg,
        root.stats, root.sortInfo, root.prev, root.page, root.next, root.closeMapButton02971,
    }
    for _, control in ipairs(normalControls) do EAS_SetControlHidden029128(control, not expanded) end
    for _, row in ipairs(root.rows or {}) do
        -- RefreshMapTeleporter will decide which rows are visible when expanded.
        EAS_SetControlHidden029128(row, not expanded or row.entry == nil)
    end

    if root.drawerButton029128 then
        root.drawerButton029128:SetText(expanded and "<  TELEPORTER" or "TELEPORTER  >")
        root.drawerButton029128:ClearAnchors()
        if expanded then
            root.drawerButton029128:SetAnchor(TOPRIGHT, root, TOPRIGHT, -5, 5)
        else
            root.drawerButton029128:SetAnchor(TOPLEFT, root, TOPLEFT, 5, 5)
        end
    end
    -- The legacy in-panel close-map button is intentionally retired; ESO's
    -- native Escape/Map bindings are the only map-close controls now.
    EAS_SetControlHidden029128(root.closeMapButton02971, true)

    root:ClearAnchors()
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 8)
    if expanded then
        root:SetDimensions(500, math.max(560, safeNumber(GuiRoot:GetHeight(), 900) - 16))
        if EAS_LayoutMapTeleporterBase029128 then EAS_LayoutMapTeleporterBase029128(self) end
        if not root:IsHidden() and self:IsMapTeleporterMapShowing() then
            EAS_RefreshMapTeleporterBase029128(self)
            if EVENT_MANAGER then
                EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
                EPC.Runtime:RegisterUpdate("Travel", "MapTeleporterRefresh", 3500, function()
                    local travel = EPC and EPC.Travel
                    if travel and travel.mapTeleporter and not travel.mapTeleporter:IsHidden()
                        and travel.mapTeleporterExpanded029128 == true and travel:IsMapTeleporterMapShowing() then
                        travel:RefreshMapTeleporter()
                    else
                        EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
                    end
                end)
            end
        end
    else
        -- Compact drawer tab: the map remains unobstructed until requested.
        root:SetDimensions(136, 42)
        if EVENT_MANAGER then EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh") end
    end

    self:RestoreNativeWorldMapKeys029128(root)
end

function T:ToggleMapTeleporterDrawer029128()
    self:SetMapTeleporterExpanded029128(not (self.mapTeleporterExpanded029128 == true), true)
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029128(self)
    if not root or not WINDOW_MANAGER then return root end

    if not root.drawerButton029128 then
        local button = WINDOW_MANAGER:CreateControl(nil, root, CT_BUTTON)
        button:SetDimensions(126, 32)
        button:SetAnchor(TOPLEFT, root, TOPLEFT, 5, 5)
        button:SetFont("ZoFontGameBold")
        button:SetNormalFontColor(0.94, 0.95, 0.96, 1)
        button:SetMouseOverFontColor(1.00, 0.78, 0.24, 1)
        button:SetPressedFontColor(1.00, 0.78, 0.24, 1)
        button:SetHandler("OnClicked", function() self:ToggleMapTeleporterDrawer029128() end)
        button:SetDrawLayer(DL_OVERLAY)
        button:SetDrawLevel(980)
        root.drawerButton029128 = button
    end

    -- The drawer starts folded whenever the map is first opened.  The saved
    -- value only tracks an explicit user toggle during the current map session;
    -- scene visibility below folds it again after closing the map.
    if self.mapTeleporterExpanded029128 == nil then
        self.mapTeleporterExpanded029128 = false
    end
    self:RestoreNativeWorldMapKeys029128(root)
    return root
end

LayoutMapTeleporterImplArch = function(self, ...)
    local root = self.mapTeleporter
    if root and self.mapTeleporterExpanded029128 ~= true then
        root:ClearAnchors()
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 8)
        root:SetDimensions(136, 42)
        self:RestoreNativeWorldMapKeys029128(root)
        return
    end
    local result = EAS_LayoutMapTeleporterBase029128(self, ...)
    self:RestoreNativeWorldMapKeys029128(self.mapTeleporter)
    return result
end

RefreshMapTeleporterImplArch = function(self, ...)
    local root = self.mapTeleporter
    if root and self.mapTeleporterExpanded029128 ~= true then
        -- No roster/guild destination rebuild while the drawer is folded.
        self:RestoreNativeWorldMapKeys029128(root)
        return
    end
    return EAS_RefreshMapTeleporterBase029128(self, ...)
end

SetMapTeleporterVisibleImplArch = function(self, visible)
    local result = EAS_SetMapTeleporterVisibleBase029128(self, visible)
    local root = self.mapTeleporter
    if not root then return result end

    if visible == true and EPC.saved and EPC.saved.mapTeleporterEnabled ~= false then
        -- Always open the World Map with a small folded tab so ESO's normal map
        -- remains fully usable.  The user expands the Teleporter on demand.
        self.mapTeleporterExpanded029128 = false
        self:SetMapTeleporterExpanded029128(false, false)
        root:SetHidden(false)
    else
        self.mapTeleporterExpanded029128 = false
        self:ReleaseMapTeleporterSearchFocus02984()
    end
    self:RestoreNativeWorldMapKeys029128(root)
    self:UpdateNativeMapToggleStrip02985()
    return result
end

-- ============================================================================
-- v0.29.129 - Keep the Map Teleporter independent from World Map zoom.
-- The destination drawer is UI chrome, not map content.  Never size/anchor it
-- from ZO_WorldMapContainer/scroll/map geometry because those controls change
-- while ESO zooms/pans/animates the map.  Keeping the drawer on GuiRoot also
-- prevents map zoom from visually scaling or shifting the Teleporter.
-- ============================================================================
DockMapTeleporterToWorldMapImplArch = function(self)
    local root = self.mapTeleporter
    if not root or not GuiRoot then return end

    root:ClearAnchors()
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 8)
    root:SetClampedToScreen(false)
    if root.SetScale then root:SetScale(1) end

    if self.mapTeleporterExpanded029128 == true then
        root:SetDimensions(500, math.max(560, safeNumber(GuiRoot:GetHeight(), 900) - 16))
    else
        root:SetDimensions(136, 42)
    end
end

-- Wrap creation once more so older creation layers cannot restore their
-- mouse-wheel pagination handler.  Wheel input over the actual map remains
-- native ESO zoom; wheel input over the Teleporter itself does nothing.
local EAS_CreateMapTeleporterBase029129 = CreateMapTeleporterImplArch
CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029129(self)
    if not root then return root end

    self:DockMapTeleporterToWorldMap()
    if root.SetHandler then
        root:SetHandler("OnMouseWheel", function() end)
    end
    self:RestoreNativeWorldMapKeys029128(root)
    return root
end


-- ============================================================================
-- v0.29.130 - Teleporter visibility modes + normal HUD overlay integration.
-- MAP: collapsible drawer exists only while ESO's World Map is showing.
-- ALWAYS: the same drawer is available during gameplay and uses ESO's native
-- HUD-fade fragment behavior, while remaining available on the World Map.
-- HUD Layout Mode temporarily expands/unlocks it and saves a screen position.
-- ============================================================================
local EAS_CreateMapTeleporterBase029130 = CreateMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase029130 = LayoutMapTeleporterImplArch
local EAS_RefreshMapTeleporterBase029130 = RefreshMapTeleporterImplArch
local EAS_SetMapTeleporterExpandedBase029130 = SetMapTeleporterExpanded029128ImplArch

local function EAS_MapTeleporterMode029130()
    if not EPC or not EPC.saved then return "MAP" end
    return EPC.saved.mapTeleporterDisplayMode == "ALWAYS" and "ALWAYS" or "MAP"
end

function T:GetMapTeleporterExpandedHeight029130()
    local rootH = math.max(600, safeNumber(GuiRoot and GuiRoot:GetHeight(), 900))
    return math.max(560, math.min(780, rootH - 40))
end

function T:AnchorMapTeleporter029130()
    local root = self.mapTeleporter
    if not root or not GuiRoot then return end
    local left = safeNumber(EPC.saved and EPC.saved.mapTeleporterLeft, -1)
    local top = safeNumber(EPC.saved and EPC.saved.mapTeleporterTop, -1)
    local rootW = safeNumber(GuiRoot:GetWidth(), 0)
    local rootH = safeNumber(GuiRoot:GetHeight(), 0)
    local width = self.mapTeleporterExpanded029128 == true and 500 or 136
    local height = self.mapTeleporterExpanded029128 == true and self:GetMapTeleporterExpandedHeight029130() or 42
    local valid = left >= 0 and top >= 0
        and (rootW <= 0 or left <= math.max(0, rootW - math.min(width, rootW)))
        and (rootH <= 0 or top <= math.max(0, rootH - math.min(height, rootH)))

    root:ClearAnchors()
    if valid then
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 12, 84)
    end
    root:SetClampedToScreen(true)
    if root.SetScale then root:SetScale(1) end
end

function T:SaveMapTeleporterPosition029130()
    local root = self.mapTeleporter
    if not root or not EPC.saved then return end
    EPC.saved.mapTeleporterLeft = math.max(0, safeNumber(root:GetLeft(), 0))
    EPC.saved.mapTeleporterTop = math.max(0, safeNumber(root:GetTop(), 0))
end

function T:ResetMapTeleporterPosition()
    if EPC.saved then
        EPC.saved.mapTeleporterLeft = -1
        EPC.saved.mapTeleporterTop = -1
    end
    self:AnchorMapTeleporter029130()
end

function T:EnsureMapTeleporterHudFragment029130()
    if self.mapTeleporterHudFragment029130 or not self.mapTeleporter then
        return self.mapTeleporterHudFragment029130
    end
    if EPC and EPC.CreateHudFadeFragment then
        self.mapTeleporterHudFragment029130 = EPC:CreateHudFadeFragment(self.mapTeleporter)
        self.mapTeleporterHudFragmentAttached029130 = self.mapTeleporterHudFragment029130 ~= nil
    end
    return self.mapTeleporterHudFragment029130
end

function T:SetMapTeleporterHudFragmentAttached029130(attached)
    local fragment = self:EnsureMapTeleporterHudFragment029130()
    if not fragment then return false end
    attached = attached == true
    if attached == (self.mapTeleporterHudFragmentAttached029130 == true) then return true end

    local function add(scene)
        if scene and type(scene.AddFragment) == "function" then pcall(scene.AddFragment, scene, fragment) end
    end
    local function remove(scene)
        if scene and type(scene.RemoveFragment) == "function" then pcall(scene.RemoveFragment, scene, fragment) end
    end
    if attached then
        add(HUD_SCENE)
        if HUD_UI_SCENE and HUD_UI_SCENE ~= HUD_SCENE then add(HUD_UI_SCENE) end
    else
        remove(HUD_SCENE)
        if HUD_UI_SCENE and HUD_UI_SCENE ~= HUD_SCENE then remove(HUD_UI_SCENE) end
    end
    self.mapTeleporterHudFragmentAttached029130 = attached
    return true
end

function T:SetMapTeleporterHudReason029130(showRequested)
    local fragment = self:EnsureMapTeleporterHudFragment029130()
    if fragment and type(fragment.SetHiddenForReason) == "function" then
        pcall(fragment.SetHiddenForReason, fragment, "EAS_TELEPORTER_DISABLED", showRequested ~= true)
    elseif self.mapTeleporter then
        self.mapTeleporter:SetHidden(showRequested ~= true)
    end
end

function T:UpdateMapTeleporterRefreshPulse029130()
    if not EVENT_MANAGER then return end
    EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
    local root = self.mapTeleporter
    if not root or root:IsHidden() or self.mapTeleporterExpanded029128 ~= true then return end
    if self.mapTeleporterLayoutMode029130 == true then return end
    local mapShowing = self:IsMapTeleporterMapShowing()
    if not mapShowing and EAS_MapTeleporterMode029130() ~= "ALWAYS" then return end

    EPC.Runtime:RegisterUpdate("Travel", "MapTeleporterRefresh", 4500, function()
        local travel = EPC and EPC.Travel
        if not travel or not travel.mapTeleporter or travel.mapTeleporter:IsHidden()
            or travel.mapTeleporterExpanded029128 ~= true then
            EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
            return
        end
        if not travel:IsMapTeleporterMapShowing() and EAS_MapTeleporterMode029130() ~= "ALWAYS" then
            EPC.Runtime:UnregisterUpdate("Travel", "MapTeleporterRefresh")
            return
        end
        travel:RefreshMapTeleporter(true)
    end)
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029130(self)
    if not root or not WINDOW_MANAGER then return root end

    root:SetClampedToScreen(true)
    root:SetMovable(self.mapTeleporterLayoutMode029130 == true)
    root:SetMouseEnabled(true)
    root:SetHandler("OnMoveStop", function(control)
        if control.StopMoving then pcall(control.StopMoving, control) end
        self:SaveMapTeleporterPosition029130()
    end)

    if not root.layoutDragHandle029130 then
        local handle = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
        handle:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
        handle:SetAnchor(TOPRIGHT, root, TOPRIGHT, 0, 0)
        handle:SetHeight(42)
        handle:SetMouseEnabled(false)
        if handle.SetDrawLayer and DL_OVERLAY then handle:SetDrawLayer(DL_OVERLAY) end
        if handle.SetDrawLevel then handle:SetDrawLevel(1500) end
        handle:SetHandler("OnMouseDown", function(_, button)
            if self.mapTeleporterLayoutMode029130 == true and button == MOUSE_BUTTON_INDEX_LEFT and root.StartMoving then
                root:StartMoving()
            end
        end)
        handle:SetHandler("OnMouseUp", function(_, button)
            if self.mapTeleporterLayoutMode029130 == true and button == MOUSE_BUTTON_INDEX_LEFT and root.StopMoving then
                root:StopMoving()
                self:SaveMapTeleporterPosition029130()
            end
        end)
        root.layoutDragHandle029130 = handle
    end

    self:AnchorMapTeleporter029130()
    self:RestoreNativeWorldMapKeys029128(root)
    return root
end

DockMapTeleporterToWorldMapImplArch = function(self)
    local root = self.mapTeleporter
    if not root then return end
    if self.mapTeleporterExpanded029128 == true then
        root:SetDimensions(500, self:GetMapTeleporterExpandedHeight029130())
    else
        root:SetDimensions(136, 42)
    end
    self:AnchorMapTeleporter029130()
end

LayoutMapTeleporterImplArch = function(self, ...)
    local root = self.mapTeleporter
    if root then
        if self.mapTeleporterExpanded029128 == true then
            root:SetDimensions(500, self:GetMapTeleporterExpandedHeight029130())
        else
            root:SetDimensions(136, 42)
        end
    end
    local result = EAS_LayoutMapTeleporterBase029130(self, ...)
    self:AnchorMapTeleporter029130()
    return result
end

RefreshMapTeleporterImplArch = function(self, force029130)
    local root = self.mapTeleporter
    if not root or root:IsHidden() or self.mapTeleporterExpanded029128 ~= true then return end
    -- The older anti-hitch wrapper only schedules delayed retries while the map
    -- is visible. Outside-map ALWAYS mode therefore requests a full refresh at
    -- its intentionally slow 4.5 second cadence or on direct user interaction.
    if not self:IsMapTeleporterMapShowing() and EAS_MapTeleporterMode029130() == "ALWAYS" then
        self.mapTeleporterLastRefresh029114 = 0
        force029130 = true
    end
    local result = EAS_RefreshMapTeleporterBase029130(self, force029130 == true)
    self:AnchorMapTeleporter029130()
    return result
end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    local result = EAS_SetMapTeleporterExpandedBase029130(self, expanded, saveState)
    local root = self.mapTeleporter
    if not root then return result end
    self:DockMapTeleporterToWorldMap()
    if expanded == true and not root:IsHidden() then self:RefreshMapTeleporter(true) end
    self:HideMapCompletionForTeleporter(self:IsMapTeleporterMapShowing() and expanded == true and not root:IsHidden())
    self:UpdateMapTeleporterRefreshPulse029130()
    return result
end

function T:RaiseForLayout()
    if self.mapTeleporterLayoutMode029130 ~= true then return end
    local root = self.mapTeleporter
    if not root or root:IsHidden() then return end
    if root.SetTopLevel then root:SetTopLevel(true) end
    if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
    if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
    if root.SetDrawLevel then root:SetDrawLevel(970) end
    if root.BringWindowToTop then root:BringWindowToTop() end
end

function T:SetLayoutMode(active)
    active = active == true
    local root = self:CreateMapTeleporter()
    if not root then return end

    if active and not self.mapTeleporterLayoutMode029130 then
        self.mapTeleporterLayoutRestoreExpanded029130 = self.mapTeleporterExpanded029128 == true
    end
    self.mapTeleporterLayoutMode029130 = active
    root:SetMovable(active)
    root:SetMouseEnabled(true)
    if root.layoutDragHandle029130 then root.layoutDragHandle029130:SetMouseEnabled(active) end
    if root.drawerButton029128 and root.drawerButton029128.SetMouseEnabled then root.drawerButton029128:SetMouseEnabled(not active) end

    if active then
        self:SetMapTeleporterHudFragmentAttached029130(false)
        self:SetMapTeleporterExpanded029128(true, false)
        if root.title then root.title:SetText("MAP TELEPORTER  |  DRAG TOP BAR TO MOVE") end
        root:SetHidden(false)
        self:RefreshMapTeleporter(true)
        if root.SetTopLevel then root:SetTopLevel(true) end
        if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
        if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
        if root.SetDrawLevel then root:SetDrawLevel(970) end
        if root.BringWindowToTop then root:BringWindowToTop() end
    else
        if root.title then root.title:SetText("MAP TELEPORTER") end
        local restore = self.mapTeleporterLayoutRestoreExpanded029130 == true
        self.mapTeleporterLayoutRestoreExpanded029130 = nil
        self:SetMapTeleporterExpanded029128(restore, false)
    end
    self:RefreshMapTeleporterVisibility()
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local root = self:CreateMapTeleporter()
    if not root or not EPC.saved then return end
    local enabled = EPC.saved.mapTeleporterEnabled ~= false
    local mode = EAS_MapTeleporterMode029130()
    local mapShowing = self:IsMapTeleporterMapShowing()
    local layout = self.mapTeleporterLayoutMode029130 == true or EPC.unitFramesMoveMode == true

    -- World Map and HUD Layout are explicit UI contexts, so detach the gameplay
    -- fade fragment and control visibility directly. Gameplay ALWAYS mode uses
    -- the same native HUD-fade fragment as the Suite FPS/Repair overlays.
    if layout then
        self:SetMapTeleporterHudFragmentAttached029130(false)
        root:SetHidden(not enabled)
    elseif mapShowing then
        self:SetMapTeleporterHudFragmentAttached029130(false)
        root:SetHidden(not enabled)
    elseif enabled and mode == "ALWAYS" then
        local fragmentAttached = self:SetMapTeleporterHudFragmentAttached029130(true)
        self:SetMapTeleporterHudReason029130(true)
        -- When the native HUD fragment exists it owns show/hide/fade state. Do
        -- not force SetHidden(false) here or the Teleporter could appear over an
        -- Inventory/Settings scene while the user changes this option.
        if not fragmentAttached then root:SetHidden(false) end
    else
        self:SetMapTeleporterHudFragmentAttached029130(false)
        root:SetHidden(true)
    end

    -- MAP mode folds again after leaving the map so every map opening starts as
    -- the compact drawer requested in 0.29.128. ALWAYS mode preserves the user's
    -- expanded/folded state while moving between gameplay and the map.
    if mapShowing and not self.mapTeleporterWasMapShowing029130 then
        if mode == "MAP" and not layout then self:SetMapTeleporterExpanded029128(false, false) end
    elseif not mapShowing and self.mapTeleporterWasMapShowing029130 then
        if mode == "MAP" and not layout then self:SetMapTeleporterExpanded029128(false, false) end
    end
    self.mapTeleporterWasMapShowing029130 = mapShowing

    local actuallyVisible = enabled and (layout or mapShowing or mode == "ALWAYS") and not root:IsHidden()
    self:HideMapCompletionForTeleporter(mapShowing and actuallyVisible and self.mapTeleporterExpanded029128 == true)
    self:RestoreNativeWorldMapKeys029128(root)
    self:UpdateNativeMapToggleStrip02985()
    self:DockMapTeleporterToWorldMap()
    self:UpdateMapTeleporterRefreshPulse029130()
end

-- Keep compatibility with older wrappers/callers that explicitly request a
-- visibility change; the final policy is now determined by Settings + context.
SetMapTeleporterVisibleImplArch = function(self, visible)
    if visible == false and EAS_MapTeleporterMode029130() == "MAP" and not self:IsMapTeleporterMapShowing() then
        local root = self.mapTeleporter
        if root then root:SetHidden(true) end
    end
    return self:RefreshMapTeleporterVisibility()
end

-- ============================================================================
-- v0.29.131 - Collapsed drawer hardening + reliable ALWAYS HUD visibility.
-- A folded Teleporter must render only its drawer tab; no destination rows or
-- expanded controls may be re-shown by legacy layout wrappers. ALWAYS mode is
-- also refreshed when ESO returns to HUD gameplay so the drawer is genuinely
-- usable outside the World Map while still following the native HUD fragment.
-- ============================================================================
local EAS_LayoutMapTeleporterBase029131 = LayoutMapTeleporterImplArch
local EAS_SetMapTeleporterExpandedBase029131 = SetMapTeleporterExpanded029128ImplArch
local EAS_RefreshMapTeleporterVisibilityBase029131 = RefreshMapTeleporterVisibilityImplArch
local EAS_CreateMapTeleporterBase029131 = CreateMapTeleporterImplArch

local function EAS_SetHiddenSafe029131(control, hidden)
    if control and type(control.SetHidden) == "function" then
        pcall(control.SetHidden, control, hidden == true)
    end
end

function T:ApplyMapTeleporterCollapsedPresentation029131(collapsed)
    local root = self.mapTeleporter
    if not root then return end
    collapsed = collapsed == true

    -- These are all expanded-only surfaces used by every Teleporter generation.
    -- Keeping legacy fields in the list makes the final layer safe even for a
    -- SavedVariables/session upgrade from an older in-memory UI build.
    local expandedFields = {
        "title",
        "viewButton", "toolsButton", "favoriteButton",
        "playerSearchLabel", "playerSearchBg",
        "zoneSearchLabel", "zoneSearchBg",
        "stats", "sortInfo",
        "prev", "page", "next",
        "closeMapButton02971",
        "home", "homeOut", "leader", "questQuick", "sort",
    }
    for i = 1, #expandedFields do
        EAS_SetHiddenSafe029131(root[expandedFields[i]], collapsed)
    end

    for _, button in pairs(root.tabs or {}) do
        EAS_SetHiddenSafe029131(button, collapsed)
    end

    for i, row in ipairs(root.rows or {}) do
        if collapsed then
            -- This is the important part: legacy LayoutMapTeleporter() code can
            -- otherwise re-show rows after the panel has already shrunk to 136x42.
            EAS_SetHiddenSafe029131(row, true)
        else
            local visibleRows = math.max(1, safeNumber(root.visibleRows, 15))
            EAS_SetHiddenSafe029131(row, i > visibleRows or row.entry == nil)
        end
    end

    if root.drawerButton029128 then
        EAS_SetHiddenSafe029131(root.drawerButton029128, false)
        root.drawerButton029128:SetText(collapsed and "TELEPORTER  >" or "<  TELEPORTER")
        root.drawerButton029128:ClearAnchors()
        if collapsed then
            root.drawerButton029128:SetAnchor(TOPLEFT, root, TOPLEFT, 5, 5)
        else
            root.drawerButton029128:SetAnchor(TOPRIGHT, root, TOPRIGHT, -5, 5)
        end
    end

    -- Never bring the retired close-map control back; native ESO ESC/Map owns it.
    EAS_SetHiddenSafe029131(root.closeMapButton02971, true)
end

LayoutMapTeleporterImplArch = function(self, ...)
    local root = self.mapTeleporter
    if root and self.mapTeleporterExpanded029128 ~= true then
        root:SetDimensions(136, 42)
        self:ApplyMapTeleporterCollapsedPresentation029131(true)
        if self.AnchorMapTeleporter029130 then self:AnchorMapTeleporter029130() end
        if self.RestoreNativeWorldMapKeys029128 then self:RestoreNativeWorldMapKeys029128(root) end
        return
    end

    local result = EAS_LayoutMapTeleporterBase029131(self, ...)
    self:ApplyMapTeleporterCollapsedPresentation029131(false)
    if self.AnchorMapTeleporter029130 then self:AnchorMapTeleporter029130() end
    return result
end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    expanded = expanded == true
    local result = EAS_SetMapTeleporterExpandedBase029131(self, expanded, saveState)
    local root = self.mapTeleporter
    if root then
        self:ApplyMapTeleporterCollapsedPresentation029131(not expanded)
        if not expanded then root:SetDimensions(136, 42) end
        if self.AnchorMapTeleporter029130 then self:AnchorMapTeleporter029130() end
    end
    return result
end

local function EAS_IsGameplayHudSceneShowing029131()
    local function showing(scene)
        if scene and type(scene.IsShowing) == "function" then
            local ok, value = pcall(scene.IsShowing, scene)
            return ok and value == true
        end
        return false
    end
    return showing(HUD_SCENE) or showing(HUD_UI_SCENE)
end

function T:RegisterMapTeleporterHudVisibility029131()
    if self.mapTeleporterHudVisibilityRegistered029131 then return end
    self.mapTeleporterHudVisibilityRegistered029131 = true
    local function register(scene)
        if scene and type(scene.RegisterCallback) == "function" then
            scene:RegisterCallback("StateChange", function()
                if type(zo_callLater) == "function" then
                    zo_callLater(function()
                        if EPC and EPC.Travel and EPC.Travel.RefreshMapTeleporterVisibility then
                            EPC.Travel:RefreshMapTeleporterVisibility()
                        end
                    end, 0)
                elseif EPC and EPC.Travel and EPC.Travel.RefreshMapTeleporterVisibility then
                    EPC.Travel:RefreshMapTeleporterVisibility()
                end
            end)
        end
    end
    register(HUD_SCENE)
    if HUD_UI_SCENE ~= HUD_SCENE then register(HUD_UI_SCENE) end
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029131(self)
    if not root then return root end
    self:RegisterMapTeleporterHudVisibility029131()
    self:ApplyMapTeleporterCollapsedPresentation029131(self.mapTeleporterExpanded029128 ~= true)
    return root
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local root = self:CreateMapTeleporter()
    if not root or not EPC.saved then return end

    local enabled = EPC.saved.mapTeleporterEnabled ~= false
    local mode = EPC.saved.mapTeleporterDisplayMode == "ALWAYS" and "ALWAYS" or "MAP"
    local mapShowing = self:IsMapTeleporterMapShowing()
    local layout = self.mapTeleporterLayoutMode029130 == true or EPC.unitFramesMoveMode == true

    if layout then
        if self.SetMapTeleporterHudFragmentAttached029130 then self:SetMapTeleporterHudFragmentAttached029130(false) end
        root:SetHidden(not enabled)
    elseif mapShowing then
        if self.SetMapTeleporterHudFragmentAttached029130 then self:SetMapTeleporterHudFragmentAttached029130(false) end
        root:SetHidden(not enabled)
    elseif enabled and mode == "ALWAYS" then
        -- Attach to the same native ESO HUD-fade system used by the Suite's FPS
        -- and compact Repair overlays, but explicitly reveal it when the HUD
        -- scene becomes active. This fixes the drawer remaining hidden after it
        -- was previously hidden by MAP mode or a menu scene.
        local fragmentAttached = self.SetMapTeleporterHudFragmentAttached029130
            and self:SetMapTeleporterHudFragmentAttached029130(true) or false
        if self.SetMapTeleporterHudReason029130 then self:SetMapTeleporterHudReason029130(true) end

        local suppressed = EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true
        if not suppressed then
            -- Explicitly reveal the top-level control when gameplay is active.
            -- The attached HUD fragment still owns subsequent idle/menu fading.
            root:SetHidden(false)
        elseif not fragmentAttached then
            root:SetHidden(true)
        end
    else
        if self.SetMapTeleporterHudFragmentAttached029130 then self:SetMapTeleporterHudFragmentAttached029130(false) end
        if self.SetMapTeleporterHudReason029130 then self:SetMapTeleporterHudReason029130(false) end
        root:SetHidden(true)
    end

    if mapShowing and not self.mapTeleporterWasMapShowing029130 then
        if mode == "MAP" and not layout then self:SetMapTeleporterExpanded029128(false, false) end
    elseif not mapShowing and self.mapTeleporterWasMapShowing029130 then
        if mode == "MAP" and not layout then self:SetMapTeleporterExpanded029128(false, false) end
    end
    self.mapTeleporterWasMapShowing029130 = mapShowing

    self:ApplyMapTeleporterCollapsedPresentation029131(self.mapTeleporterExpanded029128 ~= true)

    local actuallyVisible = enabled and (layout or mapShowing or mode == "ALWAYS") and not root:IsHidden()
    self:HideMapCompletionForTeleporter(mapShowing and actuallyVisible and self.mapTeleporterExpanded029128 == true)
    self:RestoreNativeWorldMapKeys029128(root)
    self:UpdateNativeMapToggleStrip02985()
    self:DockMapTeleporterToWorldMap()
    self:UpdateMapTeleporterRefreshPulse029130()
end

-- Compatibility callers still funnel through the final policy above.
SetMapTeleporterVisibleImplArch = function(self, visible)
    if visible == false and EPC.saved and EPC.saved.mapTeleporterDisplayMode ~= "ALWAYS"
        and not self:IsMapTeleporterMapShowing() then
        local root = self.mapTeleporter
        if root then root:SetHidden(true) end
    end
    return self:RefreshMapTeleporterVisibility()
end



-- ============================================================================
-- v0.29.132 - Hotkey-driven HUD Teleporter interaction.
-- In Always / HUD Overlay mode, the user can bind one key to open the
-- Teleporter while adventuring, enter UI mode to interact with it, and press
-- the same key again to fold it back down and return to gameplay.
-- ============================================================================
local SetMapTeleporterOverlayUIMode029132ImplArch
function T:SetMapTeleporterOverlayUIMode029132(...)
    return SetMapTeleporterOverlayUIMode029132ImplArch(self, ...)
end
SetMapTeleporterOverlayUIMode029132ImplArch = function(self, active)
    active = active == true
    local changed = false
    if type(SetGameCameraUIMode) == "function" then
        local ok, result = pcall(SetGameCameraUIMode, active)
        changed = (ok and result ~= false) or changed
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        local ok = pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, active)
        changed = ok or changed
    end
    return changed
end

function T:PushMapTeleporterActionLayer029132()
    if self.mapTeleporterActionLayerPushed029132 or type(PushActionLayerByName) ~= "function" then return end
    local ok = pcall(PushActionLayerByName, "ESOAdventurerSuiteMapTeleporterLayer")
    if ok then self.mapTeleporterActionLayerPushed029132 = true end
end

function T:PopMapTeleporterActionLayer029132()
    if not self.mapTeleporterActionLayerPushed029132 or type(RemoveActionLayerByName) ~= "function" then return end
    pcall(RemoveActionLayerByName, "ESOAdventurerSuiteMapTeleporterLayer")
    self.mapTeleporterActionLayerPushed029132 = false
end

local OpenMapTeleporterOverlay029132ImplArch

function T:OpenMapTeleporterOverlay029132(...)

    return OpenMapTeleporterOverlay029132ImplArch(self, ...)

end

OpenMapTeleporterOverlay029132ImplArch = function(self)
    if not EPC.saved or EPC.saved.mapTeleporterEnabled == false then
        if EPC.Print then EPC:Print("Map Teleporter is disabled. Enable it in Suite Settings > Map Teleporter.") end
        return false
    end

    local mode = (EPC.saved.mapTeleporterDisplayMode == "ALWAYS") and "ALWAYS" or "MAP"
    if not self:IsMapTeleporterMapShowing() and mode ~= "ALWAYS" then
        if EPC.Print then EPC:Print("Set Teleporter visibility to Always / HUD Overlay to open it outside the World Map.") end
        return false
    end

    local root = self:CreateMapTeleporter()
    if not root then return false end

    local alreadyInUIMode = false
    if type(IsGameCameraUIModeActive) == "function" then
        local ok, value = pcall(IsGameCameraUIModeActive)
        alreadyInUIMode = ok and value == true
    end

    self.mapTeleporterHotkeySession029132 = true
    self.mapTeleporterOwnsUIMode029132 = not alreadyInUIMode
    if self.mapTeleporterOwnsUIMode029132 then
        self:SetMapTeleporterOverlayUIMode029132(true)
    end

    root:SetHidden(false)
    root:SetMouseEnabled(true)
    self:SetMapTeleporterExpanded029128(true, true)
    self:RefreshMapTeleporter(true)
    self:PushMapTeleporterActionLayer029132()

    if root.SetTopLevel then root:SetTopLevel(true) end
    if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
    if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
    if root.SetDrawLevel then root:SetDrawLevel(980) end
    if root.BringWindowToTop then root:BringWindowToTop() end
    return true
end

local CloseMapTeleporterOverlay029132ImplArch

function T:CloseMapTeleporterOverlay029132(...)

    return CloseMapTeleporterOverlay029132ImplArch(self, ...)

end

CloseMapTeleporterOverlay029132ImplArch = function(self, skipRefresh)
    local root = self.mapTeleporter
    self.mapTeleporterHotkeySession029132 = false

    if self.HideMapTeleporterFlyout02969 then self:HideMapTeleporterFlyout02969() end
    if self.ReleaseMapTeleporterSearchFocus02984 then self:ReleaseMapTeleporterSearchFocus02984() end

    if not self:IsMapTeleporterMapShowing() and root and EPC.saved and EPC.saved.mapTeleporterDisplayMode == "ALWAYS" then
        self:SetMapTeleporterExpanded029128(false, true)
    end

    self:PopMapTeleporterActionLayer029132()
    if self.mapTeleporterOwnsUIMode029132 == true then
        self:SetMapTeleporterOverlayUIMode029132(false)
    end
    self.mapTeleporterOwnsUIMode029132 = false

    if skipRefresh ~= true then
        self:RefreshMapTeleporterVisibility()
    end
    return true
end

local ToggleMapTeleporterOverlay029132ImplArch

function T:ToggleMapTeleporterOverlay029132(...)

    return ToggleMapTeleporterOverlay029132ImplArch(self, ...)

end

ToggleMapTeleporterOverlay029132ImplArch = function(self)
    if not EPC.saved or EPC.saved.mapTeleporterEnabled == false then
        if EPC.Print then EPC:Print("Map Teleporter is disabled. Enable it in Suite Settings > Map Teleporter.") end
        return
    end

    if self:IsMapTeleporterMapShowing() then
        self:ToggleMapTeleporterDrawer029128()
        return
    end

    if (EPC.saved.mapTeleporterDisplayMode == "ALWAYS") ~= true then
        if EPC.Print then EPC:Print("Set Teleporter visibility to Always / HUD Overlay to use the Teleporter hotkey outside the World Map.") end
        return
    end

    local root = self:CreateMapTeleporter()
    local open = root and not root:IsHidden() and self.mapTeleporterExpanded029128 == true and self.mapTeleporterHotkeySession029132 == true
    if open then
        self:CloseMapTeleporterOverlay029132(false)
    else
        self:OpenMapTeleporterOverlay029132()
    end
end

local EAS_CreateMapTeleporterBase029132 = CreateMapTeleporterImplArch
local EAS_SetMapTeleporterExpandedBase029132 = SetMapTeleporterExpanded029128ImplArch
local EAS_RefreshMapTeleporterVisibilityBase029132 = RefreshMapTeleporterVisibilityImplArch

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029132(self)
    if not root then return root end

    if root.drawerButton029128 and not root.drawerButton029128.easHotkeySession029132 then
        root.drawerButton029128.easHotkeySession029132 = true
        root.drawerButton029128:SetHandler("OnClicked", function()
            local mode = EPC.saved and EPC.saved.mapTeleporterDisplayMode or "MAP"
            if self:IsMapTeleporterMapShowing() then
                self:ToggleMapTeleporterDrawer029128()
            elseif mode == "ALWAYS" and self.mapTeleporterHotkeySession029132 == true and self.mapTeleporterExpanded029128 == true then
                self:CloseMapTeleporterOverlay029132(false)
            else
                self:ToggleMapTeleporterDrawer029128()
            end
        end)
    end
    return root
end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    local result = EAS_SetMapTeleporterExpandedBase029132(self, expanded, saveState)
    if expanded ~= true and self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing() then
        self:CloseMapTeleporterOverlay029132(true)
    end
    return result
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local result = EAS_RefreshMapTeleporterVisibilityBase029132(self)
    local enabled = EPC.saved and EPC.saved.mapTeleporterEnabled ~= false
    local mode = EPC.saved and EPC.saved.mapTeleporterDisplayMode or "MAP"
    if self.mapTeleporterHotkeySession029132 == true and (not enabled or mode ~= "ALWAYS" or self:IsMapTeleporterMapShowing()) then
        self:CloseMapTeleporterOverlay029132(true)
    end
    return result
end

-- Public teleporter toggle is defined once after the final state machine.


-- ============================================================================
-- v0.29.133 - Native HUD fade ownership for Repair/Teleporter parity.
-- The collapsed ALWAYS drawer must fade exactly like the Suite's working FPS
-- overlay. During ordinary gameplay it is controlled only by the native HUD
-- fade fragment; direct SetHidden(false) and permanent top-level promotion are
-- reserved for explicit interaction contexts (map, layout, hotkey UI session).
-- ============================================================================
function T:SetMapTeleporterNormalGameplayLayer029133(root)
    if not root then return end
    pcall(function()
        if root.SetTopLevel then root:SetTopLevel(false) end
        if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
        if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
        if root.SetDrawLevel then root:SetDrawLevel(970) end
    end)
end

local SetMapTeleporterInteractiveLayer029133ImplArch

function T:SetMapTeleporterInteractiveLayer029133(...)

    return SetMapTeleporterInteractiveLayer029133ImplArch(self, ...)

end

SetMapTeleporterInteractiveLayer029133ImplArch = function(self, root)
    if not root then return end
    pcall(function()
        if root.SetTopLevel then root:SetTopLevel(true) end
        if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
        if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
        if root.SetDrawLevel then root:SetDrawLevel(980) end
        if root.BringWindowToTop then root:BringWindowToTop() end
    end)
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local root = self:CreateMapTeleporter()
    if not root or not EPC.saved then return end

    local enabled = EPC.saved.mapTeleporterEnabled ~= false
    local mode = EPC.saved.mapTeleporterDisplayMode == "ALWAYS" and "ALWAYS" or "MAP"
    local mapShowing = self:IsMapTeleporterMapShowing()
    local layout = self.mapTeleporterLayoutMode029130 == true or EPC.unitFramesMoveMode == true
    local hotkeySession = self.mapTeleporterHotkeySession029132 == true and not mapShowing

    -- If settings/context invalidate an active hotkey interaction, end it first
    -- so the mouse/UI mode is never stranded.
    if hotkeySession and (not enabled or mode ~= "ALWAYS") then
        self:CloseMapTeleporterOverlay029132(true)
        hotkeySession = false
    end

    if layout or mapShowing or hotkeySession then
        -- Explicit interaction contexts must remain fully visible and clickable.
        if self.SetMapTeleporterHudFragmentAttached029130 then
            self:SetMapTeleporterHudFragmentAttached029130(false)
        end
        if self.SetMapTeleporterHudReason029130 then
            self:SetMapTeleporterHudReason029130(enabled)
        end
        root:SetHidden(not enabled)
        if enabled then self:SetMapTeleporterInteractiveLayer029133(root) end
    elseif enabled and mode == "ALWAYS" then
        -- Ordinary gameplay: attach once and then leave visibility entirely to
        -- ESO's HUD-fade fragment. Do NOT call root:SetHidden(false) here.
        local fragmentAttached = self.SetMapTeleporterHudFragmentAttached029130
            and self:SetMapTeleporterHudFragmentAttached029130(true) or false
        if self.SetMapTeleporterHudReason029130 then
            self:SetMapTeleporterHudReason029130(true)
        end
        self:SetMapTeleporterNormalGameplayLayer029133(root)

        -- Fallback only for clients where the HUD fade fragment could not be
        -- created. Normal supported clients never enter this branch.
        if not fragmentAttached then
            local suppressed = EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true
            root:SetHidden(suppressed)
        end
    else
        if self.SetMapTeleporterHudReason029130 then
            self:SetMapTeleporterHudReason029130(false)
        end
        if self.SetMapTeleporterHudFragmentAttached029130 then
            self:SetMapTeleporterHudFragmentAttached029130(false)
        end
        root:SetHidden(true)
        self:SetMapTeleporterNormalGameplayLayer029133(root)
    end

    -- MAP mode still starts folded each time the World Map is entered/exited.
    if mapShowing and not self.mapTeleporterWasMapShowing029130 then
        if mode == "MAP" and not layout then self:SetMapTeleporterExpanded029128(false, false) end
    elseif not mapShowing and self.mapTeleporterWasMapShowing029130 then
        if mode == "MAP" and not layout then self:SetMapTeleporterExpanded029128(false, false) end
    end
    self.mapTeleporterWasMapShowing029130 = mapShowing

    self:ApplyMapTeleporterCollapsedPresentation029131(self.mapTeleporterExpanded029128 ~= true)
    local actuallyVisible = enabled and (layout or mapShowing or hotkeySession or mode == "ALWAYS") and not root:IsHidden()
    self:HideMapCompletionForTeleporter(mapShowing and actuallyVisible and self.mapTeleporterExpanded029128 == true)
    self:RestoreNativeWorldMapKeys029128(root)
    self:UpdateNativeMapToggleStrip02985()
    self:DockMapTeleporterToWorldMap()
    self:UpdateMapTeleporterRefreshPulse029130()
end


-- ============================================================================
-- v0.29.134 - Hotkey-only gameplay Teleporter + reliable close/click-away.
-- The permanent TELEPORTER > HUD drawer is retired outside the World Map.
-- In the outside-map mode the assigned key is the launcher: it opens the full
-- Teleporter in UI mode, the same key closes it, and clicking anywhere outside
-- the Teleporter closes it and returns to gameplay.
-- ============================================================================
local EAS_RefreshMapTeleporterVisibilityBase029134 = RefreshMapTeleporterVisibilityImplArch
local EAS_CreateMapTeleporterBase029134 = CreateMapTeleporterImplArch

function T:IsMapTeleporterToggleKey029134(key, ctrl, alt, shift, command)
    if type(self.RawKeyMatchesAction02986) == "function" then
        local ok, matches = pcall(self.RawKeyMatchesAction02986, self,
            "ESO_ADVENTURER_SUITE_MAP_TELEPORTER_TOGGLE", key, ctrl, alt, shift, command)
        if ok and matches == true then return true end
    end
    return false
end

function T:IsControlInsideMapTeleporter029134(control)
    local root = self.mapTeleporter
    if not root or not control then return false end
    local current = control
    for _ = 1, 32 do
        if current == root then return true end
        if not current or type(current.GetParent) ~= "function" then break end
        local ok, parent = pcall(current.GetParent, current)
        if not ok or not parent or parent == current then break end
        current = parent
    end
    return false
end

function T:UnregisterMapTeleporterClickAway029134()
    if EVENT_MANAGER and EVENT_GLOBAL_MOUSE_DOWN then
        EPC.Runtime:UnregisterEvent("Travel", "ClickAwayMouseDown")
    end
    self.mapTeleporterClickAwayRegistered029134 = false
end

function T:RegisterMapTeleporterClickAway029134()
    if self.mapTeleporterClickAwayRegistered029134 or not EVENT_MANAGER or not EVENT_GLOBAL_MOUSE_DOWN then return end
    self.mapTeleporterClickAwayRegistered029134 = true
    local eventName = (EPC.name or "ESOAdventurerSuite") .. "_TeleporterClickAway029134"
    EPC.Runtime:RegisterEvent("Travel", "ClickAwayMouseDown", EVENT_GLOBAL_MOUSE_DOWN, function()
        if not EPC or not EPC.Travel or EPC.Travel.mapTeleporterHotkeySession029132 ~= true then return end
        local travel = EPC.Travel
        local function checkClick()
            if travel.mapTeleporterHotkeySession029132 ~= true or travel:IsMapTeleporterMapShowing() then return end
            local control = nil
            if WINDOW_MANAGER then
                if type(WINDOW_MANAGER.GetMouseOverControl) == "function" then
                    local ok, value = pcall(WINDOW_MANAGER.GetMouseOverControl, WINDOW_MANAGER)
                    if ok then control = value end
                end
                if not control and type(WINDOW_MANAGER.GetMouseFocusControl) == "function" then
                    local ok, value = pcall(WINDOW_MANAGER.GetMouseFocusControl, WINDOW_MANAGER)
                    if ok then control = value end
                end
            end
            if not travel:IsControlInsideMapTeleporter029134(control) then
                travel:CloseMapTeleporterOverlay029134(false)
            end
        end
        if type(zo_callLater) == "function" then zo_callLater(checkClick, 0) else checkClick() end
    end)
end

function T:ApplyMapTeleporterHotkeyCapture029134(root)
    root = root or self.mapTeleporter
    if not root then return end
    local active = self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing()
    if not active then
        if self.RestoreNativeWorldMapKeys029128 then self:RestoreNativeWorldMapKeys029128(root) end
        return
    end

    if root.SetKeyboardEnabled then root:SetKeyboardEnabled(true) end
    root:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
        if self.mapTeleporterHotkeySession029132 ~= true then return end
        if (KEY_ESCAPE ~= nil and key == KEY_ESCAPE)
            or self:IsMapTeleporterToggleKey029134(key, ctrl, alt, shift, command) then
            self:CloseMapTeleporterOverlay029134(false)
        end
    end)

    local function wireEdit(edit)
        if not edit then return end
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end
        edit:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
            if self.mapTeleporterHotkeySession029132 == true
                and self:IsMapTeleporterToggleKey029134(key, ctrl, alt, shift, command) then
                self:CloseMapTeleporterOverlay029134(false)
            end
        end)
        edit:SetHandler("OnEscape", function(c)
            if c and c.LoseFocus then pcall(c.LoseFocus, c) end
            self.mapTeleporterSearchFocused = false
            if self.mapTeleporterHotkeySession029132 == true then
                self:CloseMapTeleporterOverlay029134(false)
            end
        end)
    end
    wireEdit(root.playerSearch)
    wireEdit(root.zoneSearch)
end

local function EAS_TeleporterNowMs029134()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok and tonumber(value) then return tonumber(value) end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return 0
end

local OpenMapTeleporterOverlay029134ImplArch

function T:OpenMapTeleporterOverlay029134(...)

    return OpenMapTeleporterOverlay029134ImplArch(self, ...)

end

OpenMapTeleporterOverlay029134ImplArch = function(self)
    if not EPC.saved or EPC.saved.mapTeleporterEnabled == false then
        if EPC.Print then EPC:Print("Map Teleporter is disabled. Enable it in Suite Settings > Map Teleporter.") end
        return false
    end
    if self:IsMapTeleporterMapShowing() then
        self:ToggleMapTeleporterDrawer029128()
        return true
    end
    if EPC.saved.mapTeleporterDisplayMode ~= "ALWAYS" then
        if EPC.Print then EPC:Print("Set Teleporter visibility to Hotkey / Outside Map to use it while adventuring.") end
        return false
    end

    local root = self:CreateMapTeleporter()
    if not root then return false end

    local alreadyInUIMode = false
    if type(IsGameCameraUIModeActive) == "function" then
        local ok, value = pcall(IsGameCameraUIModeActive)
        alreadyInUIMode = ok and value == true
    end

    self.mapTeleporterHotkeySession029132 = true
    self.mapTeleporterOwnsUIMode029132 = not alreadyInUIMode

    -- Push our inherited hotkey layer before entering UI mode. This keeps the
    -- same binding alive even when ESO suspends the normal General layer.
    self:PushMapTeleporterActionLayer029132()
    if self.mapTeleporterOwnsUIMode029132 then self:SetMapTeleporterOverlayUIMode029132(true) end

    if self.SetMapTeleporterHudFragmentAttached029130 then self:SetMapTeleporterHudFragmentAttached029130(false) end
    root:SetHidden(false)
    root:SetMouseEnabled(true)
    self:SetMapTeleporterExpanded029128(true, true)
    self:RefreshMapTeleporter(true)
    if self.SetMapTeleporterInteractiveLayer029133 then self:SetMapTeleporterInteractiveLayer029133(root) end
    self:ApplyMapTeleporterHotkeyCapture029134(root)
    self:RegisterMapTeleporterClickAway029134()
    return true
end

local CloseMapTeleporterOverlay029134ImplArch

function T:CloseMapTeleporterOverlay029134(...)

    return CloseMapTeleporterOverlay029134ImplArch(self, ...)

end

CloseMapTeleporterOverlay029134ImplArch = function(self, skipRefresh)
    if self.mapTeleporterClosing029134 then return true end
    self.mapTeleporterClosing029134 = true

    local root = self.mapTeleporter
    self:UnregisterMapTeleporterClickAway029134()
    self.mapTeleporterHotkeySession029132 = false
    self.mapTeleporterSuppressOpenUntil029134 = EAS_TeleporterNowMs029134() + 180

    if self.HideMapTeleporterFlyout02969 then self:HideMapTeleporterFlyout02969() end
    if self.ReleaseMapTeleporterSearchFocus02984 then self:ReleaseMapTeleporterSearchFocus02984() end

    if root and not self:IsMapTeleporterMapShowing() then
        self:SetMapTeleporterExpanded029128(false, true)
        root:SetHidden(true)
        if root.SetKeyboardEnabled then root:SetKeyboardEnabled(false) end
        if root.SetHandler then root:SetHandler("OnKeyDown", nil) end
    end

    self:PopMapTeleporterActionLayer029132()
    if self.mapTeleporterOwnsUIMode029132 == true then self:SetMapTeleporterOverlayUIMode029132(false) end
    self.mapTeleporterOwnsUIMode029132 = false
    self.mapTeleporterClosing029134 = false

    if skipRefresh ~= true then self:RefreshMapTeleporterVisibility() end
    return true
end

-- Redirect legacy 0.29.132 callers to the corrected implementation.
OpenMapTeleporterOverlay029132ImplArch = function(self) return self:OpenMapTeleporterOverlay029134() end
CloseMapTeleporterOverlay029132ImplArch = function(self, skipRefresh) return self:CloseMapTeleporterOverlay029134(skipRefresh) end

ToggleMapTeleporterOverlay029132ImplArch = function(self)
    if not EPC.saved or EPC.saved.mapTeleporterEnabled == false then
        if EPC.Print then EPC:Print("Map Teleporter is disabled. Enable it in Suite Settings > Map Teleporter.") end
        return
    end
    if self:IsMapTeleporterMapShowing() then
        self:ToggleMapTeleporterDrawer029128()
        return
    end
    if EPC.saved.mapTeleporterDisplayMode ~= "ALWAYS" then
        if EPC.Print then EPC:Print("Set Teleporter visibility to Hotkey / Outside Map to use it while adventuring.") end
        return
    end

    -- Session state is the source of truth. Do not rely on SetHidden/expanded,
    -- because ESO scene/UI-mode changes can alter those controls independently.
    if self.mapTeleporterHotkeySession029132 == true then
        self:CloseMapTeleporterOverlay029134(false)
    else
        if EAS_TeleporterNowMs029134() < (self.mapTeleporterSuppressOpenUntil029134 or 0) then return end
        self:OpenMapTeleporterOverlay029134()
    end
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029134(self)
    if not root then return root end
    if self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing() then
        self:ApplyMapTeleporterHotkeyCapture029134(root)
    end
    return root
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local result = EAS_RefreshMapTeleporterVisibilityBase029134(self)
    local root = self.mapTeleporter
    if not root or not EPC.saved then return result end

    local mapShowing = self:IsMapTeleporterMapShowing()
    local layout = self.mapTeleporterLayoutMode029130 == true or EPC.unitFramesMoveMode == true
    local hotkeySession = self.mapTeleporterHotkeySession029132 == true and not mapShowing

    -- Outside the World Map there is no permanent Teleporter drawer anymore.
    -- The only normal-gameplay visible state is an active hotkey interaction.
    if not mapShowing and not layout and not hotkeySession then
        if self.SetMapTeleporterHudFragmentAttached029130 then self:SetMapTeleporterHudFragmentAttached029130(false) end
        if self.SetMapTeleporterHudReason029130 then self:SetMapTeleporterHudReason029130(false) end
        root:SetHidden(true)
        if self.SetMapTeleporterNormalGameplayLayer029133 then self:SetMapTeleporterNormalGameplayLayer029133(root) end
    elseif hotkeySession then
        root:SetHidden(false)
        self:ApplyMapTeleporterHotkeyCapture029134(root)
        self:RegisterMapTeleporterClickAway029134()
    end
    return result
end


-- ============================================================================
-- v0.29.135 - Fully release gameplay input after Teleporter close.
-- Do not drive both ESO UI-mode APIs at once. The Suite's main interaction
-- system prefers SetGameCameraUIMode and uses SCENE_MANAGER only as a fallback;
-- the Teleporter now follows that same ownership model. Closing also disables
-- all Teleporter input before returning camera control, then verifies the owned
-- UI mode was actually released on the next frames.
-- ============================================================================
local SetMapTeleporterOverlayUIMode029135ImplArch
function T:SetMapTeleporterOverlayUIMode029135(...)
    return SetMapTeleporterOverlayUIMode029135ImplArch(self, ...)
end
SetMapTeleporterOverlayUIMode029135ImplArch = function(self, active)
    active = active == true
    if type(SetGameCameraUIMode) == "function" then
        local ok = pcall(SetGameCameraUIMode, active)
        if ok then return true end
    end
    if SCENE_MANAGER and type(SCENE_MANAGER.SetInUIMode) == "function" then
        local ok = pcall(SCENE_MANAGER.SetInUIMode, SCENE_MANAGER, active)
        return ok == true
    end
    return false
end

-- Redirect the older helper so every Teleporter path uses only one UI-mode API.
SetMapTeleporterOverlayUIMode029132ImplArch = function(self, active)
    return self:SetMapTeleporterOverlayUIMode029135(active)
end

function T:ForceReleaseMapTeleporterGameplayInput029135()
    -- Only release camera UI mode that the Teleporter itself acquired. Never
    -- tear down Inventory, Settings, a dialog, or another addon that already
    -- owned UI mode before the Teleporter opened.
    if self.mapTeleporterReleaseOwned029135 ~= true then return end
    if self:IsMapTeleporterMapShowing() then
        self.mapTeleporterReleaseOwned029135 = false
        return
    end

    local stillActive = false
    if type(IsGameCameraUIModeActive) == "function" then
        local ok, value = pcall(IsGameCameraUIModeActive)
        stillActive = ok and value == true
    end
    if stillActive then
        self:SetMapTeleporterOverlayUIMode029135(false)
    end

    -- Once camera UI mode reports clear, stop the release guard. If the API is
    -- unavailable, one fallback call is enough and we clear the flag here too.
    local verifyActive = false
    if type(IsGameCameraUIModeActive) == "function" then
        local ok, value = pcall(IsGameCameraUIModeActive)
        verifyActive = ok and value == true
    end
    if not verifyActive or type(IsGameCameraUIModeActive) ~= "function" then
        self.mapTeleporterReleaseOwned029135 = false
    end
end

local EAS_OpenMapTeleporterOverlayBase029135 = OpenMapTeleporterOverlay029134ImplArch
OpenMapTeleporterOverlay029134ImplArch = function(self)
    local result = EAS_OpenMapTeleporterOverlayBase029135(self)
    if result == true and self.mapTeleporterHotkeySession029132 == true then
        -- Snapshot the ownership decided by the existing open routine. This is
        -- what lets close distinguish Teleporter-owned UI mode from pre-existing UI.
        self.mapTeleporterReleaseOwned029135 = self.mapTeleporterOwnsUIMode029132 == true
    end
    return result
end

CloseMapTeleporterOverlay029134ImplArch = function(self, skipRefresh)
    if self.mapTeleporterClosing029135 then return true end
    self.mapTeleporterClosing029135 = true

    local root = self.mapTeleporter
    local ownedUIMode = self.mapTeleporterOwnsUIMode029132 == true
    self.mapTeleporterReleaseOwned029135 = ownedUIMode

    self:UnregisterMapTeleporterClickAway029134()
    self.mapTeleporterHotkeySession029132 = false
    self.mapTeleporterSuppressOpenUntil029134 = EAS_TeleporterNowMs029134() + 220

    -- Release every Teleporter input owner before changing camera UI mode.
    if self.HideMapTeleporterFlyout02969 then self:HideMapTeleporterFlyout02969() end
    if self.ReleaseMapTeleporterSearchFocus02984 then self:ReleaseMapTeleporterSearchFocus02984() end
    self.mapTeleporterSearchFocused = false

    if root and not self:IsMapTeleporterMapShowing() then
        self:SetMapTeleporterExpanded029128(false, true)
        root:SetHidden(true)
        root:SetMouseEnabled(false)
        if root.SetKeyboardEnabled then root:SetKeyboardEnabled(false) end
        if root.SetHandler then
            root:SetHandler("OnKeyDown", nil)
            root:SetHandler("OnMouseDown", nil)
            root:SetHandler("OnMouseUp", nil)
        end
        if root.playerSearch then
            if root.playerSearch.LoseFocus then pcall(root.playerSearch.LoseFocus, root.playerSearch) end
            if root.playerSearch.SetKeyboardEnabled then root.playerSearch:SetKeyboardEnabled(false) end
        end
        if root.zoneSearch then
            if root.zoneSearch.LoseFocus then pcall(root.zoneSearch.LoseFocus, root.zoneSearch) end
            if root.zoneSearch.SetKeyboardEnabled then root.zoneSearch:SetKeyboardEnabled(false) end
        end
    end

    self:PopMapTeleporterActionLayer029132()
    self.mapTeleporterActionLayerPushed029132 = false

    if ownedUIMode then
        self:SetMapTeleporterOverlayUIMode029135(false)
    end
    self.mapTeleporterOwnsUIMode029132 = false
    self.mapTeleporterClosing029135 = false

    -- ESO can finish the current mouse/key dispatch after our close callback.
    -- Re-check on the next frames so that dispatch cannot leave the cursor/camera
    -- in UI mode. These calls are gated by Teleporter ownership above.
    local function releaseAgain()
        if EPC and EPC.Travel then EPC.Travel:ForceReleaseMapTeleporterGameplayInput029135() end
    end
    if type(zo_callLater) == "function" and ownedUIMode then
        zo_callLater(releaseAgain, 0)
        zo_callLater(releaseAgain, 40)
        zo_callLater(releaseAgain, 120)
    elseif ownedUIMode then
        releaseAgain()
    end

    if skipRefresh ~= true then self:RefreshMapTeleporterVisibility() end
    return true
end

-- Keep the legacy aliases pointed at the final close/open implementation.
OpenMapTeleporterOverlay029132ImplArch = function(self) return self:OpenMapTeleporterOverlay029134() end
CloseMapTeleporterOverlay029132ImplArch = function(self, skipRefresh) return self:CloseMapTeleporterOverlay029134(skipRefresh) end

-- Re-enable mouse interaction whenever the Teleporter is deliberately promoted
-- again (World Map, HUD Layout, or a new hotkey session) after the hard close
-- above disabled its top-level mouse input.
local EAS_SetMapTeleporterInteractiveLayerBase029135 = SetMapTeleporterInteractiveLayer029133ImplArch
SetMapTeleporterInteractiveLayer029133ImplArch = function(self, root)
    root = root or self.mapTeleporter
    if root and root.SetMouseEnabled then root:SetMouseEnabled(true) end
    if EAS_SetMapTeleporterInteractiveLayerBase029135 then
        return EAS_SetMapTeleporterInteractiveLayerBase029135(self, root)
    end
end


-- ============================================================================
-- v0.29.136 - Native top-level interaction host + map-attached MAP mode.
-- Outside-map hotkey interaction now lets ESO's own SCENE_MANAGER own UI-mode
-- entry/exit through a tiny registered top-level host. The Teleporter window
-- itself is NOT registered, so native Escape on the World Map still closes the
-- map normally instead of consuming an extra Escape to hide the Teleporter.
-- MAP mode anchors to the stable ZO_WorldMap top-level (never the zoom canvas),
-- while hotkey/layout mode anchors to the saved HUD position on GuiRoot.
-- ============================================================================
local EAS_RefreshMapTeleporterVisibilityBase029136 = RefreshMapTeleporterVisibilityImplArch
local EAS_CreateMapTeleporterBase029136 = CreateMapTeleporterImplArch
local EAS_RestoreNativeWorldMapKeysBase029136 = RestoreNativeWorldMapKeys029128ImplArch
local EAS_RefreshMapTeleporterBase029136 = RefreshMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase029136 = LayoutMapTeleporterImplArch
local EAS_SetMapTeleporterExpandedBase029136 = SetMapTeleporterExpanded029128ImplArch

local EnsureMapTeleporterInteractionHost029136ImplArch

function T:EnsureMapTeleporterInteractionHost029136(...)

    return EnsureMapTeleporterInteractionHost029136ImplArch(self, ...)

end

EnsureMapTeleporterInteractionHost029136ImplArch = function(self)
    if self.mapTeleporterInteractionHost029136 then return self.mapTeleporterInteractionHost029136 end
    if not WINDOW_MANAGER or not SCENE_MANAGER or type(SCENE_MANAGER.RegisterTopLevel) ~= "function" then return nil end

    local host = WINDOW_MANAGER:CreateTopLevelWindow("EAS_MapTeleporterInteractionHost029136")
    host:SetDimensions(1, 1)
    host:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
    host:SetMouseEnabled(false)
    if host.SetKeyboardEnabled then host:SetKeyboardEnabled(false) end
    host:SetHidden(true)

    local locks = TOPLEVEL_LOCKS_UI_MODE
    if locks == nil then locks = true end
    SCENE_MANAGER:RegisterTopLevel(host, locks)
    self.mapTeleporterInteractionHost029136 = host

    host:SetHandler("OnHide", function()
        local travel = EPC and EPC.Travel
        if travel and travel.mapTeleporterHotkeySession029132 == true and travel.mapTeleporterClosing029136 ~= true then
            -- Escape/system UI close can hide the registered host directly.
            -- Finish Teleporter cleanup without asking SCENE_MANAGER to hide an
            -- already-hidden host again.
            travel:FinishMapTeleporterHotkeyClose029136(false, true)
        end
    end)
    return host
end

function T:IsMapTeleporterMouseInside029136()
    local root = self.mapTeleporter
    if not root or root:IsHidden() then return false end

    local control = nil
    if WINDOW_MANAGER then
        if type(WINDOW_MANAGER.GetMouseOverControl) == "function" then
            local ok, value = pcall(WINDOW_MANAGER.GetMouseOverControl, WINDOW_MANAGER)
            if ok then control = value end
        end
        if not control and type(WINDOW_MANAGER.GetMouseFocusControl) == "function" then
            local ok, value = pcall(WINDOW_MANAGER.GetMouseFocusControl, WINDOW_MANAGER)
            if ok then control = value end
        end
    end
    if control and self:IsControlInsideMapTeleporter029134(control) then return true end

    -- Coordinate fallback for blank/background areas that do not report a
    -- specific child control as the current mouse-over control.
    if type(GetUIMousePosition) == "function" and type(root.GetLeft) == "function" then
        local ok, x, y = pcall(GetUIMousePosition)
        if ok and x and y then
            local left = safeNumber(root:GetLeft(), 0)
            local top = safeNumber(root:GetTop(), 0)
            local right = safeNumber(root:GetRight(), left)
            local bottom = safeNumber(root:GetBottom(), top)
            if x >= left and x <= right and y >= top and y <= bottom then return true end
        end
    end
    return false
end

function T:UnregisterMapTeleporterClickAway029136()
    -- Remove the older mouse-down watcher too, in case it was registered by an
    -- earlier wrapper during the same UI session.
    if self.UnregisterMapTeleporterClickAway029134 then self:UnregisterMapTeleporterClickAway029134() end
    if EVENT_MANAGER and EVENT_GLOBAL_MOUSE_UP then
        EPC.Runtime:UnregisterEvent("Travel", "ClickAwayMouseUp")
    end
    self.mapTeleporterClickAwayRegistered029136 = false
end

local RegisterMapTeleporterClickAway029136ImplArch

function T:RegisterMapTeleporterClickAway029136(...)

    return RegisterMapTeleporterClickAway029136ImplArch(self, ...)

end

RegisterMapTeleporterClickAway029136ImplArch = function(self)
    self:UnregisterMapTeleporterClickAway029136()
    if not EVENT_MANAGER or not EVENT_GLOBAL_MOUSE_UP then return end
    self.mapTeleporterClickAwayRegistered029136 = true
    local eventName = (EPC.name or "ESOAdventurerSuite") .. "_TeleporterClickAway029136"
    EPC.Runtime:RegisterEvent("Travel", "ClickAwayMouseUp", EVENT_GLOBAL_MOUSE_UP, function()
        local travel = EPC and EPC.Travel
        if not travel or travel.mapTeleporterHotkeySession029132 ~= true or travel:IsMapTeleporterMapShowing() then return end
        -- Run after the completed mouse-up dispatch. This avoids tearing down UI
        -- mode in the middle of the click that asked to close the Teleporter.
        local function finishClick()
            if not EPC or not EPC.Travel then return end
            local activeTravel = EPC.Travel
            if activeTravel.mapTeleporterHotkeySession029132 ~= true or activeTravel:IsMapTeleporterMapShowing() then return end
            if not activeTravel:IsMapTeleporterMouseInside029136() then
                activeTravel:CloseMapTeleporterOverlay029136(false)
            end
        end
        if type(zo_callLater) == "function" then zo_callLater(finishClick, 0) else finishClick() end
    end)
end

function T:ApplyMapTeleporterHotkeySearchKeys029136(root)
    root = root or self.mapTeleporter
    if not root then return end
    local function wire(edit)
        if not edit then return end
        if edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end
        edit:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
            if self.mapTeleporterHotkeySession029132 == true
                and self:IsMapTeleporterToggleKey029134(key, ctrl, alt, shift, command) then
                self:CloseMapTeleporterOverlay029136(false)
            end
        end)
        edit:SetHandler("OnEscape", function(c)
            if c and c.LoseFocus then pcall(c.LoseFocus, c) end
            self.mapTeleporterSearchFocused = false
            if self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing() then
                self:CloseMapTeleporterOverlay029136(false)
            elseif SCENE_MANAGER and type(SCENE_MANAGER.Hide) == "function" then
                pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, "worldMap")
            end
        end)
    end
    wire(root.playerSearch)
    wire(root.zoneSearch)
end

RestoreNativeWorldMapKeys029128ImplArch = function(self, root)
    if EAS_RestoreNativeWorldMapKeysBase029136 then
        EAS_RestoreNativeWorldMapKeysBase029136(self, root)
    end
    if self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing() then
        self:ApplyMapTeleporterHotkeySearchKeys029136(root)
    end
end

DockMapTeleporterToWorldMapImplArch = function(self)
    local root = self.mapTeleporter
    if not root or not GuiRoot then return end

    if self.mapTeleporterExpanded029128 == true then
        root:SetDimensions(500, self:GetMapTeleporterExpandedHeight029130())
    else
        root:SetDimensions(136, 42)
    end
    root:SetClampedToScreen(true)
    if root.SetScale then root:SetScale(1) end

    local layout = self.mapTeleporterLayoutMode029130 == true or EPC.unitFramesMoveMode == true
    local mapShowing = self:IsMapTeleporterMapShowing()
    if mapShowing and not layout and ZO_WorldMap then
        -- Attach to the stable World Map top-level. ZO_WorldMapContainer is the
        -- zoom/pan canvas and is intentionally never used as an anchor.
        root:ClearAnchors()
        root:SetAnchor(TOPLEFT, ZO_WorldMap, TOPLEFT, 12, 84)
    else
        self:AnchorMapTeleporter029130()
    end
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029136(self)
    if not root then return root end
    self:EnsureMapTeleporterInteractionHost029136()
    -- The Teleporter top-level never owns raw keyboard input. Normal keybind
    -- layers stay in charge; search edit boxes are wired separately as needed.
    if root.SetHandler then root:SetHandler("OnKeyDown", nil) end
    if root.SetKeyboardEnabled then root:SetKeyboardEnabled(false) end
    self:DockMapTeleporterToWorldMap()
    return root
end

local FinishMapTeleporterHotkeyClose029136ImplArch

function T:FinishMapTeleporterHotkeyClose029136(...)

    return FinishMapTeleporterHotkeyClose029136ImplArch(self, ...)

end

FinishMapTeleporterHotkeyClose029136ImplArch = function(self, skipRefresh, hostAlreadyHidden)
    if self.mapTeleporterClosing029136 then return true end
    self.mapTeleporterClosing029136 = true

    local root = self.mapTeleporter
    self:UnregisterMapTeleporterClickAway029136()
    self.mapTeleporterHotkeySession029132 = false
    self.mapTeleporterOwnsUIMode029132 = false
    self.mapTeleporterReleaseOwned029135 = false
    self.mapTeleporterSuppressOpenUntil029134 = 0
    self.mapTeleporterSuppressOpenUntil029136 = EAS_TeleporterNowMs029134() + 140

    if self.HideMapTeleporterFlyout02969 then self:HideMapTeleporterFlyout02969() end
    if self.ReleaseMapTeleporterSearchFocus02984 then self:ReleaseMapTeleporterSearchFocus02984() end
    self.mapTeleporterSearchFocused = false

    if root and not self:IsMapTeleporterMapShowing() then
        self:SetMapTeleporterExpanded029128(false, true)
        root:SetHidden(true)
        root:SetMouseEnabled(true) -- keep it ready for the next hotkey open
        if root.SetHandler then root:SetHandler("OnKeyDown", nil) end
        if root.SetKeyboardEnabled then root:SetKeyboardEnabled(false) end
    end

    self:PopMapTeleporterActionLayer029132()
    self.mapTeleporterActionLayerPushed029132 = false

    local host = self.mapTeleporterInteractionHost029136
    if host and hostAlreadyHidden ~= true and SCENE_MANAGER and type(SCENE_MANAGER.HideTopLevel) == "function" then
        pcall(SCENE_MANAGER.HideTopLevel, SCENE_MANAGER, host)
    end

    self.mapTeleporterClosing029136 = false
    if skipRefresh ~= true then self:RefreshMapTeleporterVisibility() end
    return true
end

function T:CloseMapTeleporterOverlay029136(skipRefresh)
    return self:FinishMapTeleporterHotkeyClose029136(skipRefresh, false)
end

local OpenMapTeleporterOverlay029136ImplArch

function T:OpenMapTeleporterOverlay029136(...)

    return OpenMapTeleporterOverlay029136ImplArch(self, ...)

end

OpenMapTeleporterOverlay029136ImplArch = function(self)
    if not EPC.saved or EPC.saved.mapTeleporterEnabled == false then
        if EPC.Print then EPC:Print("Map Teleporter is disabled. Enable it in Suite Settings > Map Teleporter.") end
        return false
    end

    if self:IsMapTeleporterMapShowing() then
        self:ToggleMapTeleporterDrawer029128()
        return true
    end

    if EPC.saved.mapTeleporterDisplayMode ~= "ALWAYS" then
        if EPC.Print then EPC:Print("Set Teleporter visibility to Hotkey / Outside Map to use it while adventuring.") end
        return false
    end

    local root = self:CreateMapTeleporter()
    local host = self:EnsureMapTeleporterInteractionHost029136()
    if not root or not host or not SCENE_MANAGER or type(SCENE_MANAGER.ShowTopLevel) ~= "function" then
        if EPC.Print then EPC:Print("Map Teleporter could not enter ESO UI mode safely.") end
        return false
    end

    -- Clear any stale state left by a prior build/session before opening.
    self:UnregisterMapTeleporterClickAway029136()
    self.mapTeleporterClosing029136 = false
    self.mapTeleporterHotkeySession029132 = true
    self.mapTeleporterOwnsUIMode029132 = false
    self.mapTeleporterReleaseOwned029135 = false

    if self.SetMapTeleporterHudFragmentAttached029130 then self:SetMapTeleporterHudFragmentAttached029130(false) end
    if self.SetMapTeleporterHudReason029130 then self:SetMapTeleporterHudReason029130(false) end

    self:PushMapTeleporterActionLayer029132()

    -- SCENE_MANAGER owns UI-mode entry/exit through this registered host. This
    -- is the same native mechanism ESO uses for top-level UI windows.
    if not host:IsControlHidden() then
        pcall(SCENE_MANAGER.HideTopLevel, SCENE_MANAGER, host)
    end
    pcall(SCENE_MANAGER.ShowTopLevel, SCENE_MANAGER, host)

    root:SetMouseEnabled(true)
    root:SetHidden(false)
    self:SetMapTeleporterExpanded029128(true, true)
    self:DockMapTeleporterToWorldMap()
    self:RefreshMapTeleporter(true)
    self:ApplyMapTeleporterHotkeySearchKeys029136(root)
    self:RegisterMapTeleporterClickAway029136()

    if root.SetTopLevel then root:SetTopLevel(true) end
    if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
    if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
    if root.SetDrawLevel then root:SetDrawLevel(980) end
    if root.BringWindowToTop then root:BringWindowToTop() end
    return true
end

function T:ToggleMapTeleporterOverlay029136()
    if not EPC.saved or EPC.saved.mapTeleporterEnabled == false then
        if EPC.Print then EPC:Print("Map Teleporter is disabled. Enable it in Suite Settings > Map Teleporter.") end
        return
    end

    if self:IsMapTeleporterMapShowing() then
        self:ToggleMapTeleporterDrawer029128()
        return
    end

    if EPC.saved.mapTeleporterDisplayMode ~= "ALWAYS" then
        if EPC.Print then EPC:Print("Set Teleporter visibility to Hotkey / Outside Map to use it while adventuring.") end
        return
    end

    if self.mapTeleporterHotkeySession029132 == true then
        self:CloseMapTeleporterOverlay029136(false)
    else
        if EAS_TeleporterNowMs029134() < (self.mapTeleporterSuppressOpenUntil029136 or 0) then return end
        self:OpenMapTeleporterOverlay029136()
    end
end

RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase029136(self, ...)
    self:DockMapTeleporterToWorldMap()
    if self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing() then
        self:ApplyMapTeleporterHotkeySearchKeys029136(self.mapTeleporter)
    end
    return result
end

LayoutMapTeleporterImplArch = function(self, ...)
    local result = EAS_LayoutMapTeleporterBase029136(self, ...)
    self:DockMapTeleporterToWorldMap()
    return result
end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    local result = EAS_SetMapTeleporterExpandedBase029136(self, expanded, saveState)
    self:DockMapTeleporterToWorldMap()
    return result
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local mapShowing = self:IsMapTeleporterMapShowing()

    -- If the player opens the actual World Map while the outside-map Teleporter
    -- is active, end the hotkey UI session first, then let normal MAP behavior
    -- take over. This prevents the interaction host from locking map controls.
    if self.mapTeleporterHotkeySession029132 == true and mapShowing then
        self:FinishMapTeleporterHotkeyClose029136(true, false)
    end

    -- During a live hotkey session, never call legacy visibility wrappers that
    -- directly SetHidden() on the Teleporter. The native host must remain the
    -- sole UI-mode owner until Close/Click-Away hides it through SCENE_MANAGER.
    if self.mapTeleporterHotkeySession029132 == true and not mapShowing then
        local root = self:CreateMapTeleporter()
        if root then
            root:SetHidden(false)
            root:SetMouseEnabled(true)
            self:SetMapTeleporterExpanded029128(true, false)
            self:DockMapTeleporterToWorldMap()
            self:ApplyMapTeleporterHotkeySearchKeys029136(root)
        end
        return
    end

    local result = EAS_RefreshMapTeleporterVisibilityBase029136(self)
    local root = self.mapTeleporter
    if not root or not EPC.saved then return result end

    local enabled = EPC.saved.mapTeleporterEnabled ~= false
    local layout = self.mapTeleporterLayoutMode029130 == true or EPC.unitFramesMoveMode == true

    if mapShowing and enabled then
        -- Open-with-map is truly map-attached. It follows the map window itself,
        -- not the zoomable map canvas, and starts folded as before.
        root:SetHidden(false)
        root:SetMouseEnabled(true)
        self:DockMapTeleporterToWorldMap()
    elseif not layout then
        -- No persistent gameplay drawer in Hotkey / Outside Map mode.
        root:SetHidden(true)
        self:DockMapTeleporterToWorldMap()
    end
    return result
end

-- Keep every older public/legacy entry point pointed at the final state machine.
OpenMapTeleporterOverlay029134ImplArch = function(self) return self:OpenMapTeleporterOverlay029136() end
OpenMapTeleporterOverlay029132ImplArch = function(self) return self:OpenMapTeleporterOverlay029136() end
CloseMapTeleporterOverlay029134ImplArch = function(self, skipRefresh) return self:CloseMapTeleporterOverlay029136(skipRefresh) end
CloseMapTeleporterOverlay029132ImplArch = function(self, skipRefresh) return self:CloseMapTeleporterOverlay029136(skipRefresh) end
ToggleMapTeleporterOverlay029132ImplArch = function(self) return self:ToggleMapTeleporterOverlay029136() end

function ESOAdventurerSuite_ToggleMapTeleporterOverlay()
    if EPC and EPC.Travel and EPC.Travel.ToggleMapTeleporterOverlay029136 then
        EPC.Travel:ToggleMapTeleporterOverlay029136()
    end
end


-- ============================================================================
-- v0.29.138 - True map-side attachment + persistent completion-pane hiding.
-- In MAP mode, the Teleporter should look attached to the World Map itself,
-- not like a floating overlay. Anchor the expanded panel flush to the map's
-- left side with the map's full height, keep the compact drawer tucked into
-- the map's top-left corner, and hide ESO's generic map-completion/zone-guide
-- panes for the entire time the Teleporter feature is active on the map.
-- ============================================================================
local EAS_DockMapTeleporterBase029138 = DockMapTeleporterToWorldMapImplArch
local EAS_RefreshMapTeleporterVisibilityBase029138 = RefreshMapTeleporterVisibilityImplArch

local function EAS_GetMapTeleporterMapHost029138()
    if _G and _G["ZO_WorldMap"] then return _G["ZO_WorldMap"] end
    return nil
end

HideMapCompletionForTeleporterImplArch = function(self, hide)
    self.mapTeleporterHiddenCompletion = self.mapTeleporterHiddenCompletion or {}
    local candidates = {
        "ZO_WorldMapZoneStoryTopLevel", "ZO_WorldMapZoneStory", "ZO_WorldMapZoneStoryKeyboard",
        "ZO_WorldMapZoneStoryPane", "ZO_WorldMapZoneGuide", "ZO_WorldMapZoneGuideKeyboard",
        "ZO_WorldMapInfo", "ZO_WorldMapInfoContainer", "ZO_WorldMapInfoContent",
        "ZO_WorldMapFilters", "ZO_WorldMapKeyLegend",
    }
    for _, name in ipairs(candidates) do
        local c = _G and _G[name] or nil
        if c and type(c.SetHidden) == "function" then
            if hide then
                if self.mapTeleporterHiddenCompletion[name] == nil and type(c.IsHidden) == "function" then
                    local ok, v = pcall(c.IsHidden, c)
                    if ok then self.mapTeleporterHiddenCompletion[name] = (v == true) end
                end
                pcall(c.SetHidden, c, true)
            elseif self.mapTeleporterHiddenCompletion[name] ~= nil then
                pcall(c.SetHidden, c, self.mapTeleporterHiddenCompletion[name])
                self.mapTeleporterHiddenCompletion[name] = nil
            end
        end
    end
end

DockMapTeleporterToWorldMapImplArch = function(self)
    local root = self.mapTeleporter
    if not root or not GuiRoot then return end

    local layout = self.mapTeleporterLayoutMode029130 == true or (EPC and EPC.unitFramesMoveMode == true)
    local mapShowing = self:IsMapTeleporterMapShowing()
    local mapHost = EAS_GetMapTeleporterMapHost029138()

    root:SetClampedToScreen(true)
    if root.SetScale then root:SetScale(1) end

    if self.mapTeleporterExpanded029128 == true then
        root:SetWidth(430)
        if mapShowing and not layout and mapHost then
            root:ClearAnchors()
            root:SetAnchor(TOPLEFT, mapHost, TOPLEFT, 6, 6)
            root:SetAnchor(BOTTOMLEFT, mapHost, BOTTOMLEFT, 6, -6)
        else
            root:SetDimensions(430, self:GetMapTeleporterExpandedHeight029130())
            self:AnchorMapTeleporter029130()
        end
    else
        root:SetDimensions(136, 42)
        if mapShowing and not layout and mapHost then
            root:ClearAnchors()
            root:SetAnchor(TOPLEFT, mapHost, TOPLEFT, 10, 10)
        else
            self:AnchorMapTeleporter029130()
        end
    end
end


-- v0.29.139: Map completion stats are hidden only while the Teleporter is expanded.
-- Folding the Teleporter or closing the World Map restores ESO's completion UI.

RefreshMapTeleporterVisibilityImplArch = function(self)
    local result = EAS_RefreshMapTeleporterVisibilityBase029138(self)
    local enabled = EPC and EPC.saved and EPC.saved.mapTeleporterEnabled ~= false
    local mapShowing = self:IsMapTeleporterMapShowing()
    local root = self.mapTeleporter
    local teleporterOpen = enabled
        and mapShowing
        and root ~= nil
        and not root:IsHidden()
        and self.mapTeleporterExpanded029128 == true

    -- ESO's normal map-completion / zone-guide stats stay visible while the
    -- Teleporter is folded. Hide them only while the full Teleporter panel is
    -- actually open, then restore them immediately when it folds or the map closes.
    self:HideMapCompletionForTeleporter(teleporterOpen)

    if enabled and mapShowing then
        self:DockMapTeleporterToWorldMap()
    end
    return result
end


-- ============================================================================
-- v0.29.140 - Outside-left map docking + final search-field bounds.
-- The Teleporter must never sit on top of the parchment. Its RIGHT edge docks
-- to the World Map's LEFT edge. The final layout pass also recalculates the
-- PLAYER/ZONE search controls from the actual Teleporter width so the ZONE box
-- cannot extend past the panel after docking/resizing.
-- ============================================================================
local EAS_RefreshMapTeleporterVisibilityBase029140 = RefreshMapTeleporterVisibilityImplArch
local EAS_SetMapTeleporterExpandedBase029140 = SetMapTeleporterExpanded029128ImplArch
local EAS_LayoutMapTeleporterBase029140 = LayoutMapTeleporterImplArch

function T:ApplyMapTeleporterSearchBounds029140()
    local root = self.mapTeleporter
    if not root or self.mapTeleporterExpanded029128 ~= true then return end

    local width = math.max(320, safeNumber(root:GetWidth(), 430))
    local margin = 12
    local gap = 10
    local usable = math.max(280, width - (margin * 2) - gap)
    local searchWidth = math.floor(usable / 2)

    if root.playerSearchLabel then
        root.playerSearchLabel:ClearAnchors()
        root.playerSearchLabel:SetAnchor(TOPLEFT, root, TOPLEFT, margin, 84)
        root.playerSearchLabel:SetWidth(searchWidth)
    end
    if root.zoneSearchLabel then
        root.zoneSearchLabel:ClearAnchors()
        root.zoneSearchLabel:SetAnchor(TOPLEFT, root, TOPLEFT, margin + searchWidth + gap, 84)
        root.zoneSearchLabel:SetWidth(searchWidth)
    end
    if root.playerSearchBg then
        root.playerSearchBg:ClearAnchors()
        root.playerSearchBg:SetAnchor(TOPLEFT, root, TOPLEFT, margin, 101)
        root.playerSearchBg:SetDimensions(searchWidth, 30)
    end
    if root.zoneSearchBg then
        root.zoneSearchBg:ClearAnchors()
        root.zoneSearchBg:SetAnchor(TOPLEFT, root, TOPLEFT, margin + searchWidth + gap, 101)
        root.zoneSearchBg:SetDimensions(searchWidth, 30)
    end
end

DockMapTeleporterToWorldMapImplArch = function(self)
    local root = self.mapTeleporter
    if not root or not GuiRoot then return end

    local layout = self.mapTeleporterLayoutMode029130 == true or (EPC and EPC.unitFramesMoveMode == true)
    local mapShowing = self:IsMapTeleporterMapShowing()
    local mapHost = _G and _G["ZO_WorldMap"] or nil

    if root.SetScale then root:SetScale(1) end

    if mapShowing and not layout and mapHost then
        -- CRITICAL: do not clamp this window. Clamping can pull an outside-left
        -- anchor back over the map parchment when ESO thinks it is off-screen.
        root:SetClampedToScreen(false)
        root:ClearAnchors()

        if self.mapTeleporterExpanded029128 == true then
            root:SetWidth(430)
            -- Full-height sidebar OUTSIDE the parchment: root RIGHT -> map LEFT.
            root:SetAnchor(TOPRIGHT, mapHost, TOPLEFT, -4, 6)
            root:SetAnchor(BOTTOMRIGHT, mapHost, BOTTOMLEFT, -4, -6)
        else
            root:SetDimensions(136, 42)
            -- Folded drawer also remains outside, immediately left of the map.
            root:SetAnchor(TOPRIGHT, mapHost, TOPLEFT, -4, 10)
        end
    else
        root:SetClampedToScreen(true)
        if self.mapTeleporterExpanded029128 == true then
            root:SetDimensions(430, self:GetMapTeleporterExpandedHeight029130())
        else
            root:SetDimensions(136, 42)
        end
        self:AnchorMapTeleporter029130()
    end

    self:ApplyMapTeleporterSearchBounds029140()
end

local UpdateMapCompletionForTeleporter029140ImplArch

function T:UpdateMapCompletionForTeleporter029140(...)

    return UpdateMapCompletionForTeleporter029140ImplArch(self, ...)

end

UpdateMapCompletionForTeleporter029140ImplArch = function(self)
    local root = self.mapTeleporter
    local hide = EPC and EPC.saved and EPC.saved.mapTeleporterEnabled ~= false
        and self:IsMapTeleporterMapShowing()
        and root ~= nil
        and not root:IsHidden()
        and self.mapTeleporterExpanded029128 == true
    self:HideMapCompletionForTeleporter(hide)
end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    local result = EAS_SetMapTeleporterExpandedBase029140(self, expanded, saveState)
    self:DockMapTeleporterToWorldMap()
    self:UpdateMapCompletionForTeleporter029140()
    return result
end

LayoutMapTeleporterImplArch = function(self, ...)
    local result = EAS_LayoutMapTeleporterBase029140(self, ...)
    self:DockMapTeleporterToWorldMap()
    self:ApplyMapTeleporterSearchBounds029140()
    return result
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local result = EAS_RefreshMapTeleporterVisibilityBase029140(self)
    self:DockMapTeleporterToWorldMap()
    self:ApplyMapTeleporterSearchBounds029140()
    self:UpdateMapCompletionForTeleporter029140()
    return result
end


-- ============================================================================
-- v0.29.141 - Stop touching ESO map completion UI + organized toolbar.
-- The Teleporter no longer hides/restores any stock ESO map completion, zone
-- guide, info, filter, or legend controls. The three primary toolbar buttons
-- use one deterministic left-to-right layout with consistent sizing/gaps.
-- ============================================================================
local EAS_LayoutMapTeleporterBase029141 = LayoutMapTeleporterImplArch
local EAS_SetMapTeleporterExpandedBase029141 = SetMapTeleporterExpanded029128ImplArch
local EAS_RefreshMapTeleporterVisibilityBase029141 = RefreshMapTeleporterVisibilityImplArch

function T:RestoreMapCompletionState029141()
    local saved = self.mapTeleporterHiddenCompletion
    if type(saved) ~= "table" then return end
    for name, wasHidden in pairs(saved) do
        local control = _G and _G[name] or nil
        if control and type(control.SetHidden) == "function" then
            pcall(control.SetHidden, control, wasHidden == true)
        end
    end
    self.mapTeleporterHiddenCompletion = {}
end

-- Final policy: Map Teleporter never owns ESO's completion/zone-guide UI.
HideMapCompletionForTeleporterImplArch = function(self, hide)
    self:RestoreMapCompletionState029141()
end

UpdateMapCompletionForTeleporter029140ImplArch = function(self)
    self:RestoreMapCompletionState029141()
end

function T:ApplyMapTeleporterToolbar029141()
    local root = self.mapTeleporter
    if not root or self.mapTeleporterExpanded029128 ~= true then return end

    local width = math.max(360, safeNumber(root:GetWidth(), 430))
    local margin = 12
    local gap = 8
    local top = 46
    local height = 32
    local usable = math.max(300, width - (margin * 2) - (gap * 2))

    -- Destination mode gets the most room because labels such as
    -- MAPS / SURVEYS / ITEMS are longer than FAVORITES and TOOLS.
    local viewWidth = math.floor(usable * 0.55)
    local remaining = usable - viewWidth
    local favoriteWidth = math.floor(remaining * 0.56)
    local toolsWidth = remaining - favoriteWidth

    local x = margin
    if root.viewButton then
        root.viewButton:ClearAnchors()
        root.viewButton:SetAnchor(TOPLEFT, root, TOPLEFT, x, top)
        root.viewButton:SetDimensions(viewWidth, height)
        if root.viewButton.SetHorizontalAlignment then root.viewButton:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        x = x + viewWidth + gap
    end

    if root.favoriteButton then
        root.favoriteButton:ClearAnchors()
        root.favoriteButton:SetAnchor(TOPLEFT, root, TOPLEFT, x, top)
        root.favoriteButton:SetDimensions(favoriteWidth, height)
        if root.favoriteButton.SetHorizontalAlignment then root.favoriteButton:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        x = x + favoriteWidth + gap
    end

    if root.toolsButton then
        root.toolsButton:ClearAnchors()
        root.toolsButton:SetAnchor(TOPLEFT, root, TOPLEFT, x, top)
        root.toolsButton:SetDimensions(toolsWidth, height)
        if root.toolsButton.SetHorizontalAlignment then root.toolsButton:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    end

    -- Final active destination label: no VIEW prefix, and shrink only the
    -- longest labels so every mode stays inside the button box.
    if root.viewButton then
        local label = string.upper(self:GetMapTeleporterViewLabel02967(self.mapTeleporterMode or "ALL"))
        root.viewButton:SetText(label)
        local length = string.len(label)
        if length >= 20 then
            root.viewButton:SetFont("ZoFontGameSmall")
        elseif length >= 15 then
            root.viewButton:SetFont("ZoFontGame")
        else
            root.viewButton:SetFont("ZoFontGameBold")
        end
    end
    if root.favoriteButton then root.favoriteButton:SetFont("ZoFontGameBold") end
    if root.toolsButton then root.toolsButton:SetFont("ZoFontGameBold") end
end

LayoutMapTeleporterImplArch = function(self, ...)
    local result = EAS_LayoutMapTeleporterBase029141(self, ...)
    self:ApplyMapTeleporterToolbar029141()
    if self.ApplyMapTeleporterSearchBounds029140 then self:ApplyMapTeleporterSearchBounds029140() end
    return result
end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    local result = EAS_SetMapTeleporterExpandedBase029141(self, expanded, saveState)
    self:RestoreMapCompletionState029141()
    if expanded == true then self:ApplyMapTeleporterToolbar029141() end
    return result
end

RefreshMapTeleporterVisibilityImplArch = function(self)
    local result = EAS_RefreshMapTeleporterVisibilityBase029141(self)
    self:RestoreMapCompletionState029141()
    self:ApplyMapTeleporterToolbar029141()
    return result
end


-- ============================================================================
-- v0.29.142 - Destination labels without VIEW prefix + guaranteed text fit.
-- ============================================================================
local EAS_RefreshMapTeleporterBase029142 = RefreshMapTeleporterImplArch
local EAS_LayoutMapTeleporterBase029142 = LayoutMapTeleporterImplArch
local EAS_CreateMapTeleporterBase029142 = CreateMapTeleporterImplArch

function T:ApplyMapTeleporterDestinationLabel029142()
    local root = self.mapTeleporter
    if not root or not root.viewButton then return end
    local label = string.upper(self:GetMapTeleporterViewLabel02967(self.mapTeleporterMode or "ALL"))
    root.viewButton:SetText(label)
    local length = string.len(label)
    if length >= 20 then
        root.viewButton:SetFont("ZoFontGameSmall")
    elseif length >= 15 then
        root.viewButton:SetFont("ZoFontGame")
    else
        root.viewButton:SetFont("ZoFontGameBold")
    end
    if root.viewButton.SetHorizontalAlignment then root.viewButton:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029142(self)
    self:ApplyMapTeleporterDestinationLabel029142()
    return root
end

LayoutMapTeleporterImplArch = function(self, ...)
    local result = EAS_LayoutMapTeleporterBase029142(self, ...)
    if self.ApplyMapTeleporterToolbar029141 then self:ApplyMapTeleporterToolbar029141() end
    self:ApplyMapTeleporterDestinationLabel029142()
    return result
end

RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase029142(self, ...)
    if self.ApplyMapTeleporterToolbar029141 then self:ApplyMapTeleporterToolbar029141() end
    self:ApplyMapTeleporterDestinationLabel029142()
    return result
end


-- ============================================================================
-- v0.29.143 - Fast Teleporter open path.
-- Opening/expanding must be a UI-only operation. Reuse the last rendered
-- destination list immediately, then perform at most one deferred rebuild after
-- the panel is already visible. Static owned-house data is cached separately so
-- ESO's collection book is not rescanned on every open.
-- ============================================================================
local EAS_BuildMapTeleporterEntriesBase029143 = BuildMapTeleporterEntriesImplArch
local EAS_GetMapTeleporterHouseEntriesBase029143 = GetMapTeleporterHouseEntriesImplArch
local EAS_SetMapTeleporterExpandedBase029143 = SetMapTeleporterExpanded029128ImplArch
local EAS_InitializeTravelBase029143 = InitializeImplArch

local function EAS_TeleporterNowMs029143()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return safeNumber(value, 0) end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return safeNumber(value, 0) end
    end
    return 0
end

function T:GetMapTeleporterBuildCacheKey029143()
    local saved = EPC and EPC.saved or nil
    return table.concat({
        tostring(self.mapTeleporterMode or "ALL"),
        lower(self.mapTeleporterPlayerSearch or ""),
        lower(self.mapTeleporterZoneSearch or ""),
        tostring(saved and saved.mapTeleporterSortMode or "SMART"),
        tostring(saved and saved.mapTeleporterIncludeHouses ~= false),
        tostring(saved and saved.mapTeleporterShowAllZones ~= false),
        tostring(saved and saved.mapTeleporterShowBlacklisted == true),
    }, "|")
end

GetMapTeleporterHouseEntriesImplArch = function(self)
    local now = EAS_TeleporterNowMs029143()
    local cache = self.mapTeleporterHouseCache029143
    local expires = safeNumber(self.mapTeleporterHouseCacheExpires029143, 0)
    if type(cache) == "table" and (now == 0 or now < expires) then
        return cache
    end

    local rows = EAS_GetMapTeleporterHouseEntriesBase029143(self) or {}
    self.mapTeleporterHouseCache029143 = rows
    -- Housing ownership/nicknames change rarely. A one-minute cache removes a
    -- relatively expensive collection-book scan from normal Teleporter opens.
    self.mapTeleporterHouseCacheExpires029143 = now > 0 and (now + 60000) or 0
    return rows
end

BuildMapTeleporterEntriesImplArch = function(self)
    local key = self:GetMapTeleporterBuildCacheKey029143()
    self.mapTeleporterBuildCache029143 = self.mapTeleporterBuildCache029143 or {}
    local cached = self.mapTeleporterBuildCache029143[key]

    if self.mapTeleporterFastOpen029143 == true then
        if cached and type(cached.entries) == "table" then
            return cached.entries
        end
        -- If the exact filter/mode has never been rendered, opening should still
        -- be instant. The deferred pass below will populate it after the panel is
        -- visible instead of blocking the click/key press.
        return {}
    end

    local entries = EAS_BuildMapTeleporterEntriesBase029143(self) or {}
    self.mapTeleporterBuildCache029143[key] = {
        entries = entries,
        builtAt = EAS_TeleporterNowMs029143(),
    }
    return entries
end

function T:ScheduleMapTeleporterDeferredRefresh029143()
    self.mapTeleporterFastOpenGeneration029143 = safeNumber(self.mapTeleporterFastOpenGeneration029143, 0) + 1
    local generation = self.mapTeleporterFastOpenGeneration029143
    local key = self:GetMapTeleporterBuildCacheKey029143()
    local cached = self.mapTeleporterBuildCache029143 and self.mapTeleporterBuildCache029143[key] or nil
    local now = EAS_TeleporterNowMs029143()
    local age = cached and now > 0 and math.max(0, now - safeNumber(cached.builtAt, 0)) or 999999
    local needsRebuild = cached == nil or age > 5000

    local function finishOpen()
        if not EPC or not EPC.Travel then return end
        local travel = EPC.Travel
        if travel.mapTeleporterFastOpenGeneration029143 ~= generation then return end
        travel.mapTeleporterFastOpen029143 = false

        local root = travel.mapTeleporter
        if not root or root:IsHidden() or travel.mapTeleporterExpanded029128 ~= true then return end
        if needsRebuild then
            -- Bypass the older 180ms coalescer only for this single deferred
            -- post-open refresh. Guild enumeration itself remains frame-sliced.
            travel.mapTeleporterLastRefresh029114 = 0
            travel:RefreshMapTeleporter(true)
        end
    end

    if type(zo_callLater) == "function" then
        zo_callLater(finishOpen, 140)
    else
        finishOpen()
    end
end

SetMapTeleporterExpanded029128ImplArch = function(self, expanded, saveState)
    expanded = expanded == true
    local wasExpanded = self.mapTeleporterExpanded029128 == true

    if expanded and not wasExpanded then
        self.mapTeleporterFastOpen029143 = true
    elseif not expanded then
        self.mapTeleporterFastOpenGeneration029143 = safeNumber(self.mapTeleporterFastOpenGeneration029143, 0) + 1
        self.mapTeleporterFastOpen029143 = false
    end

    local result = EAS_SetMapTeleporterExpandedBase029143(self, expanded, saveState)

    if expanded and not wasExpanded then
        self:ScheduleMapTeleporterDeferredRefresh029143()
    end
    return result
end

function T:PrewarmMapTeleporterCaches029143()
    if self.mapTeleporterPrewarmStarted029143 then return end
    self.mapTeleporterPrewarmStarted029143 = true

    -- Houses are static enough to prepare once after login/zone activation.
    self:GetMapTeleporterHouseEntries()

    -- Start the existing frame-sliced guild cache in the background as well.
    -- This does not block the current frame.
    if self.StartMapTeleporterGuildCacheBuild029114 then
        self:StartMapTeleporterGuildCacheBuild029114(self:GetMapTeleporterSnapshot())
    end
end

InitializeImplArch = function(self)
    local result = EAS_InitializeTravelBase029143(self)
    local function schedulePrewarm()
        if type(zo_callLater) == "function" then
            zo_callLater(function()
                if EPC and EPC.Travel and EPC.Travel.PrewarmMapTeleporterCaches029143 then
                    EPC.Travel:PrewarmMapTeleporterCaches029143()
                end
            end, 1800)
        elseif EPC and EPC.Travel and EPC.Travel.PrewarmMapTeleporterCaches029143 then
            EPC.Travel:PrewarmMapTeleporterCaches029143()
        end
    end

    -- Wait until the player is actually activated so collection/social data is
    -- ready; otherwise an early empty housing result could be cached.
    if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED ~= nil then
        EPC.Runtime:RegisterEvent("Travel", "Prewarm", EVENT_PLAYER_ACTIVATED, function()
            EPC.Runtime:UnregisterEvent("Travel", "Prewarm")
            schedulePrewarm()
        end)
    else
        schedulePrewarm()
    end
    return result
end


-- ============================================================================
-- v0.29.144 - Teleporter camera isolation + 3D recovery hook.
-- The final Teleporter uses SCENE_MANAGER's registered top-level host. Retire
-- the older direct camera-UI helpers so no legacy handler can change camera mode
-- behind the native host, then refresh Suite 3D render spaces after close.
-- ============================================================================
SetMapTeleporterOverlayUIMode029135ImplArch = function(self, active)
    return false
end
SetMapTeleporterOverlayUIMode029132ImplArch = function(self, active)
    return false
end

local EAS_FinishMapTeleporterHotkeyCloseBase029144 = FinishMapTeleporterHotkeyClose029136ImplArch
FinishMapTeleporterHotkeyClose029136ImplArch = function(self, skipRefresh, hostAlreadyHidden)
    local result = EAS_FinishMapTeleporterHotkeyCloseBase029144(self, skipRefresh, hostAlreadyHidden)
    if EPC and EPC.ResourcePins and EPC.ResourcePins.ScheduleSuite3DRecovery029144 then
        EPC.ResourcePins:ScheduleSuite3DRecovery029144("Teleporter closed", 220)
    end
    return result
end

-- ============================================================================
-- v0.29.358 - Teleporter input, tab responsiveness, click-away and localization.
-- ============================================================================
local EAS_BuildMapTeleporterEntriesBase029358 = BuildMapTeleporterEntriesImplArch
local EAS_SetMapTeleporterModeBase029358 = SetMapTeleporterModeImplArch
local EAS_RefreshMapTeleporterBase029358 = RefreshMapTeleporterImplArch
local EAS_OpenMapTeleporterOverlayBase029358 = OpenMapTeleporterOverlay029136ImplArch
local EAS_FinishMapTeleporterHotkeyCloseBase029358 = FinishMapTeleporterHotkeyClose029136ImplArch
local EAS_RegisterMapTeleporterClickAwayBase029358 = RegisterMapTeleporterClickAway029136ImplArch

local function EAS_TeleporterNowMs029358()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok then return safeNumber(value, 0) end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok then return safeNumber(value, 0) end
    end
    return 0
end

local function EAS_LocalizedText029358(value, fallback)
    local text = tostring(value or "")
    if text == "" then text = tostring(fallback or "") end

    -- Let ESO consume its own grammar payload first. This is language-neutral
    -- and preserves Cyrillic/Latin/Asian UTF-8 text instead of trying to parse
    -- translated names ourselves.
    if text ~= "" and type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then
            text = formatted
        end
    end

    -- Safety fallback for unresolved ESO grammar suffixes. The Teleporter must
    -- never expose raw ^ control markers to the player on any language client.
    -- Strip the complete ASCII control token first, then remove any stray caret
    -- that survives malformed/third-party text. UTF-8 name bytes are untouched.
    text = text:gsub("%^+[%a][%a%d]*{[^}]*}", "")
    text = text:gsub("%^+[%a][%a%d]*", "")
    text = text:gsub("%^+[%w_:%-+,=|/\\{}%[%]%(%)%.]*", "")
    text = text:gsub("%^", "")
    text = text:gsub("{[%d]+}", "")
    text = text:gsub("[%c]+", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return tostring(fallback or "") end
    return text
end

local EAS_TELEPORTER_LOCALIZED_FIELDS_029358 = {
    "name", "displayName", "characterName", "zoneName", "guildName",
    "sourceText", "sourceDetail", "statusText", "costText", "leaderName",
    "displayText",
}

local function EAS_NormalizeTeleporterEntry029358(entry)
    if type(entry) ~= "table" then return entry end
    for _, field in ipairs(EAS_TELEPORTER_LOCALIZED_FIELDS_029358) do
        if entry[field] ~= nil then
            entry[field] = EAS_LocalizedText029358(entry[field], "")
        end
    end
    return entry
end

BuildMapTeleporterEntriesImplArch = function(self)
    local key = self.GetMapTeleporterBuildCacheKey029143 and self:GetMapTeleporterBuildCacheKey029143() or nil
    local now = EAS_TeleporterNowMs029358()
    local cache = key and self.mapTeleporterBuildCache029143 and self.mapTeleporterBuildCache029143[key] or nil

    -- Reuse a recent completed tab result. Older code rebuilt the provider every
    -- time a tab was selected, which is visible as a UI hitch on large social /
    -- housing / item collections.
    if self.mapTeleporterFastOpen029143 ~= true and cache and type(cache.entries) == "table" then
        local age = now > 0 and math.max(0, now - safeNumber(cache.builtAt, 0)) or 0
        if age <= 10000 then
            for _, entry in ipairs(cache.entries) do EAS_NormalizeTeleporterEntry029358(entry) end
            return cache.entries
        end
    end

    local entries = EAS_BuildMapTeleporterEntriesBase029358(self) or {}
    for _, entry in ipairs(entries) do EAS_NormalizeTeleporterEntry029358(entry) end
    return entries
end

SetMapTeleporterModeImplArch = function(self, mode)
    local previous = self.mapTeleporterMode or "ALL"
    if mode == previous then return end

    -- Switch the visible tab immediately using any cached result (or an empty
    -- placeholder) and do exactly one deferred provider rebuild. This prevents
    -- the click itself from blocking the current frame.
    self.mapTeleporterFastOpen029143 = true
    EAS_SetMapTeleporterModeBase029358(self, mode)
    self.mapTeleporterFastOpen029143 = false

    self.mapTeleporterTabGeneration029358 = safeNumber(self.mapTeleporterTabGeneration029358, 0) + 1
    local generation = self.mapTeleporterTabGeneration029358
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local travel = EPC and EPC.Travel
            if not travel or travel.mapTeleporterTabGeneration029358 ~= generation then return end
            local root = travel.mapTeleporter
            if not root or root:IsHidden() then return end
            travel.mapTeleporterLastRefresh029114 = 0
            travel:RefreshMapTeleporter(true)
        end, 40)
    else
        self:RefreshMapTeleporter(true)
    end
end

local function EAS_IsControlDescendant029358(control, ancestor)
    local node = control
    local guard = 0
    while node and guard < 32 do
        if node == ancestor then return true end
        guard = guard + 1
        if type(node.GetParent) ~= "function" then break end
        local ok, parent = pcall(node.GetParent, node)
        if not ok or parent == node then break end
        node = parent
    end
    return false
end

function T:IsMouseInsideMapTeleporterFlyout029358()
    local root = self.mapTeleporter
    local flyout = root and root.flyout02969 or nil
    if not flyout or flyout:IsHidden() then return false end

    local control = nil
    if WINDOW_MANAGER and type(WINDOW_MANAGER.GetMouseOverControl) == "function" then
        local ok, value = pcall(WINDOW_MANAGER.GetMouseOverControl, WINDOW_MANAGER)
        if ok then control = value end
    end
    if control and EAS_IsControlDescendant029358(control, flyout) then return true end

    if type(GetUIMousePosition) == "function" then
        local ok, x, y = pcall(GetUIMousePosition)
        if ok and x and y then
            local left, top = safeNumber(flyout:GetLeft(), 0), safeNumber(flyout:GetTop(), 0)
            local right, bottom = safeNumber(flyout:GetRight(), left), safeNumber(flyout:GetBottom(), top)
            return x >= left and x <= right and y >= top and y <= bottom
        end
    end
    return false
end

RegisterMapTeleporterClickAway029136ImplArch = function(self)
    if EAS_RegisterMapTeleporterClickAwayBase029358 then
        EAS_RegisterMapTeleporterClickAwayBase029358(self)
    end
    if not EVENT_MANAGER or not EVENT_GLOBAL_MOUSE_UP then return end

    local eventName = (EPC.name or "ESOAdventurerSuite") .. "_TeleporterFlyoutClickAway029358"
    EPC.Runtime:UnregisterEvent("Travel", "FlyoutClickAway")
    EPC.Runtime:RegisterEvent("Travel", "ClickAwayMouseUp", EVENT_GLOBAL_MOUSE_UP, function()
        local travel = EPC and EPC.Travel
        if not travel then return end
        local root = travel.mapTeleporter
        if not root or root:IsHidden() or not travel:IsMapTeleporterFlyoutOpen02969() then return end

        local function closeFlyoutIfOutside()
            local active = EPC and EPC.Travel
            if active and active:IsMapTeleporterFlyoutOpen02969() and not active:IsMouseInsideMapTeleporterFlyout029358() then
                active:HideMapTeleporterFlyout02969()
            end
        end
        if type(zo_callLater) == "function" then zo_callLater(closeFlyoutIfOutside, 0) else closeFlyoutIfOutside() end
    end)
end

local ApplyMapTeleporterOutsideInput029358ImplArch

function T:ApplyMapTeleporterOutsideInput029358(...)

    return ApplyMapTeleporterOutsideInput029358ImplArch(self, ...)

end

ApplyMapTeleporterOutsideInput029358ImplArch = function(self, root)
    root = root or self.mapTeleporter
    if not root or self:IsMapTeleporterMapShowing() or self.mapTeleporterHotkeySession029132 ~= true then return end

    if root.SetKeyboardEnabled then root:SetKeyboardEnabled(true) end
    root:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
        local isEscape = KEY_ESCAPE ~= nil and key == KEY_ESCAPE
        local isAltKey = KEY_ALT ~= nil and key == KEY_ALT
        local altOnly = alt == true and ctrl ~= true and shift ~= true and command ~= true
        if isEscape or isAltKey or altOnly then
            self:CloseMapTeleporterOverlay029136(false)
        elseif self:IsMapTeleporterToggleKey029134(key, ctrl, alt, shift, command) then
            self:CloseMapTeleporterOverlay029136(false)
        end
    end)
end

OpenMapTeleporterOverlay029136ImplArch = function(self)
    local result = EAS_OpenMapTeleporterOverlayBase029358(self)
    if result then self:ApplyMapTeleporterOutsideInput029358(self.mapTeleporter) end
    return result
end

FinishMapTeleporterHotkeyClose029136ImplArch = function(self, skipRefresh, hostAlreadyHidden)
    if EVENT_MANAGER and EVENT_GLOBAL_MOUSE_UP then
        EPC.Runtime:UnregisterEvent("Travel", "FlyoutClickAway")
    end
    local root = self.mapTeleporter
    if root and root.SetKeyboardEnabled then root:SetKeyboardEnabled(false) end
    if root and root.SetHandler then root:SetHandler("OnKeyDown", nil) end
    return EAS_FinishMapTeleporterHotkeyCloseBase029358(self, skipRefresh, hostAlreadyHidden)
end

RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase029358(self, ...)
    if self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing() then
        self:ApplyMapTeleporterOutsideInput029358(self.mapTeleporter)
    end
    return result
end

-- Keep old public aliases on the corrected outside-map state machine.
OpenMapTeleporterOverlay029134ImplArch = function(self) return self:OpenMapTeleporterOverlay029136() end
OpenMapTeleporterOverlay029132ImplArch = function(self) return self:OpenMapTeleporterOverlay029136() end
CloseMapTeleporterOverlay029134ImplArch = function(self, skipRefresh) return self:CloseMapTeleporterOverlay029136(skipRefresh) end
CloseMapTeleporterOverlay029132ImplArch = function(self, skipRefresh) return self:CloseMapTeleporterOverlay029136(skipRefresh) end

-- ============================================================================
-- v0.29.361 - Teleporter tab click restoration.
-- Do not attach OnMouseDown handlers to ESO buttons. ESO's button state machine
-- uses mouse-down internally; replacing that handler can prevent OnClicked from
-- firing at all. Flyout dismissal is performed inside the existing OnClicked
-- path instead, after the button has received the click normally.
-- ============================================================================
local ApplyMapTeleporterFlyoutPassThrough029361ImplArch
function T:ApplyMapTeleporterFlyoutPassThrough029361(...)
    return ApplyMapTeleporterFlyoutPassThrough029361ImplArch(self, ...)
end
ApplyMapTeleporterFlyoutPassThrough029361ImplArch = function(self, root)
    root = root or self.mapTeleporter
    if not root then return end

    local function clearBadMouseDown(control)
        if control and control.SetHandler then
            -- Remove the v0.29.360 handler that interfered with ESO button clicks.
            control:SetHandler("OnMouseDown", nil)
        end
    end

    clearBadMouseDown(root.viewButton)
    clearBadMouseDown(root.favoriteButton)
    clearBadMouseDown(root.toolsButton)
    clearBadMouseDown(root.prev)
    clearBadMouseDown(root.next)
    for _, control in pairs(root.tabs or {}) do clearBadMouseDown(control) end

    -- Rebind the visible Teleporter toolbar using normal OnClicked handlers.
    -- VIEW/TOOLS own their flyout toggle logic; FAVORITES is a real destination
    -- tab and explicitly dismisses any flyout before switching modes.
    if root.viewButton then
        root.viewButton:SetHandler("OnClicked", function(control)
            if self:IsMapTeleporterFlyoutOpen02969() and root.flyout02969 and root.flyout02969.owner02969 == control then
                self:HideMapTeleporterFlyout02969()
            else
                self:HideMapTeleporterFlyout02969()
                self:ShowMapTeleporterViewMenu02967(control)
                if root.flyout02969 then root.flyout02969.owner02969 = control end
            end
        end)
    end
    if root.toolsButton then
        root.toolsButton:SetHandler("OnClicked", function(control)
            if self:IsMapTeleporterFlyoutOpen02969() and root.flyout02969 and root.flyout02969.owner02969 == control then
                self:HideMapTeleporterFlyout02969()
            else
                self:HideMapTeleporterFlyout02969()
                self:ShowMapTeleporterToolsMenu02967(control)
                if root.flyout02969 then root.flyout02969.owner02969 = control end
            end
        end)
    end
    if root.favoriteButton then
        root.favoriteButton:SetHandler("OnClicked", function()
            self:HideMapTeleporterFlyout02969()
            self:SetMapTeleporterMode("FAVORITES")
        end)
    end

    -- Legacy/direct mode tabs, if present, switch normally and dismiss flyouts.
    for mode, control in pairs(root.tabs or {}) do
        if control then
            control:SetHandler("OnClicked", function()
                self:HideMapTeleporterFlyout02969()
                self:SetMapTeleporterMode(mode)
            end)
        end
    end

    if root.prev then
        root.prev:SetHandler("OnClicked", function()
            self:HideMapTeleporterFlyout02969()
            self:ChangeMapTeleporterPage(-1)
        end)
    end
    if root.next then
        root.next:SetHandler("OnClicked", function()
            self:HideMapTeleporterFlyout02969()
            self:ChangeMapTeleporterPage(1)
        end)
    end
end

local EAS_CreateMapTeleporterBase029361 = CreateMapTeleporterImplArch
CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029361(self)
    self:ApplyMapTeleporterFlyoutPassThrough029361(root)
    return root
end

local EAS_RefreshMapTeleporterBase029361 = RefreshMapTeleporterImplArch
RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase029361(self, ...)
    self:ApplyMapTeleporterFlyoutPassThrough029361(self.mapTeleporter)
    return result
end

-- ============================================================================
-- v0.29.362 - Teleporter flyout same-click flash guard.
-- EVENT_GLOBAL_MOUSE_UP is deferred by the click-away handler. When VIEW/TOOLS
-- opens a flyout on that same mouse-up, the deferred outside check sees the
-- pointer over the toolbar button (not the newly-opened flyout) and immediately
-- closes it, producing a visible one-frame flash. Mark toolbar-driven flyout
-- actions for a tiny same-click grace window so only a subsequent outside click
-- can dismiss the menu.
-- ============================================================================
local function EAS_MapTeleporterNowMs029362()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok and tonumber(value) then return tonumber(value) end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return 0
end

function T:SuppressMapTeleporterClickAway029362(durationMs)
    local now = EAS_MapTeleporterNowMs029362()
    self.mapTeleporterClickAwaySuppressUntil029362 = now + (tonumber(durationMs) or 120)
end

function T:IsMapTeleporterClickAwaySuppressed029362()
    local untilMs = tonumber(self.mapTeleporterClickAwaySuppressUntil029362) or 0
    return untilMs > EAS_MapTeleporterNowMs029362()
end

RegisterMapTeleporterClickAway029136ImplArch = function(self)
    if EAS_RegisterMapTeleporterClickAwayBase029358 then
        EAS_RegisterMapTeleporterClickAwayBase029358(self)
    end
    if not EVENT_MANAGER or not EVENT_GLOBAL_MOUSE_UP then return end

    local eventName = (EPC.name or "ESOAdventurerSuite") .. "_TeleporterFlyoutClickAway029358"
    EPC.Runtime:UnregisterEvent("Travel", "FlyoutClickAway")
    EPC.Runtime:RegisterEvent("Travel", "ClickAwayMouseUp", EVENT_GLOBAL_MOUSE_UP, function()
        local travel = EPC and EPC.Travel
        if not travel then return end
        local root = travel.mapTeleporter
        if not root or root:IsHidden() or not travel:IsMapTeleporterFlyoutOpen02969() then return end
        if travel:IsMapTeleporterClickAwaySuppressed029362() then return end

        local function closeFlyoutIfOutside()
            local active = EPC and EPC.Travel
            if not active or active:IsMapTeleporterClickAwaySuppressed029362() then return end
            if active:IsMapTeleporterFlyoutOpen02969() and not active:IsMouseInsideMapTeleporterFlyout029358() then
                active:HideMapTeleporterFlyout02969()
            end
        end
        if type(zo_callLater) == "function" then zo_callLater(closeFlyoutIfOutside, 0) else closeFlyoutIfOutside() end
    end)
end

ApplyMapTeleporterFlyoutPassThrough029361ImplArch = function(self, root)
    root = root or self.mapTeleporter
    if not root then return end

    local function clearBadMouseDown(control)
        if control and control.SetHandler then control:SetHandler("OnMouseDown", nil) end
    end

    clearBadMouseDown(root.viewButton)
    clearBadMouseDown(root.favoriteButton)
    clearBadMouseDown(root.toolsButton)
    clearBadMouseDown(root.prev)
    clearBadMouseDown(root.next)
    for _, control in pairs(root.tabs or {}) do clearBadMouseDown(control) end

    if root.viewButton then
        root.viewButton:SetHandler("OnClicked", function(control)
            self:SuppressMapTeleporterClickAway029362(140)
            if self:IsMapTeleporterFlyoutOpen02969() and root.flyout02969 and root.flyout02969.owner02969 == control then
                self:HideMapTeleporterFlyout02969()
            else
                self:HideMapTeleporterFlyout02969()
                self:ShowMapTeleporterViewMenu02967(control)
                if root.flyout02969 then root.flyout02969.owner02969 = control end
            end
        end)
    end
    if root.toolsButton then
        root.toolsButton:SetHandler("OnClicked", function(control)
            self:SuppressMapTeleporterClickAway029362(140)
            if self:IsMapTeleporterFlyoutOpen02969() and root.flyout02969 and root.flyout02969.owner02969 == control then
                self:HideMapTeleporterFlyout02969()
            else
                self:HideMapTeleporterFlyout02969()
                self:ShowMapTeleporterToolsMenu02967(control)
                if root.flyout02969 then root.flyout02969.owner02969 = control end
            end
        end)
    end
    if root.favoriteButton then
        root.favoriteButton:SetHandler("OnClicked", function()
            self:SuppressMapTeleporterClickAway029362(140)
            self:HideMapTeleporterFlyout02969()
            self:SetMapTeleporterMode("FAVORITES")
        end)
    end

    for mode, control in pairs(root.tabs or {}) do
        if control then
            local selectedMode = mode
            control:SetHandler("OnClicked", function()
                self:SuppressMapTeleporterClickAway029362(140)
                self:HideMapTeleporterFlyout02969()
                self:SetMapTeleporterMode(selectedMode)
            end)
        end
    end

    if root.prev then
        root.prev:SetHandler("OnClicked", function()
            self:SuppressMapTeleporterClickAway029362(140)
            self:HideMapTeleporterFlyout02969()
            self:ChangeMapTeleporterPage(-1)
        end)
    end
    if root.next then
        root.next:SetHandler("OnClicked", function()
            self:SuppressMapTeleporterClickAway029362(140)
            self:HideMapTeleporterFlyout02969()
            self:ChangeMapTeleporterPage(1)
        end)
    end
end


-- ============================================================================
-- v0.29.365 - survey/treasure destinations resolve by LibTreasure item ID.
-- ============================================================================
local EnsureMapTeleporterTreasureIndex029365ImplArch
function T:EnsureMapTeleporterTreasureIndex029365(...)
    return EnsureMapTeleporterTreasureIndex029365ImplArch(self, ...)
end
EnsureMapTeleporterTreasureIndex029365ImplArch = function(self)
    if self.mapTeleporterTreasureIndexReady029365 or self.mapTeleporterTreasureIndexBuilding029365 then return end
    if type(_G.LibTreasure_GetMapIdData)~="function" or type(GetNumMaps)~="function" or type(GetMapIdByIndex)~="function" then return end
    self.mapTeleporterTreasureIndexBuilding029365=true; self.mapTeleporterTreasureIndex029365=self.mapTeleporterTreasureIndex029365 or {}
    local ok,count=pcall(GetNumMaps); count=ok and safeNumber(count,0) or 0; local index=1
    local function step()
        local stop=math.min(count,index+29)
        for mapIndex=index,stop do
            local okId,mapId=pcall(GetMapIdByIndex,mapIndex); mapId=okId and safeNumber(mapId,0) or 0
            if mapId>0 then
                local okData,data=pcall(_G.LibTreasure_GetMapIdData,mapId)
                if okData and type(data)=="table" then
                    local zoneId,zoneName=0,""
                    if type(GetMapInfoById)=="function" then
                        local okInfo,_,_,_,zoneIndex=pcall(GetMapInfoById,mapId); zoneIndex=okInfo and safeNumber(zoneIndex,0) or 0
                        if zoneIndex>0 and type(GetZoneId)=="function" then local oz,z=pcall(GetZoneId,zoneIndex); if oz then zoneId=safeNumber(z,0) end end
                    end
                    if zoneId>0 and type(GetParentZoneId)=="function" then local op,p=pcall(GetParentZoneId,zoneId); if op and safeNumber(p,0)>0 then zoneId=safeNumber(p,zoneId) end end
                    if zoneId>0 and type(GetZoneNameById)=="function" then local on,n=pcall(GetZoneNameById,zoneId); if on then zoneName=EAS_LocalizedText029358(n,"") end end
                    for _,pin in ipairs(data) do
                        local iid=safeNumber(type(pin)=="table" and pin.itemId or 0,0)
                        if iid>0 and not self.mapTeleporterTreasureIndex029365[iid] then self.mapTeleporterTreasureIndex029365[iid]={mapId=mapId,zoneId=zoneId,zoneName=zoneName} end
                    end
                end
            end
        end
        index=stop+1
        if index<=count and type(zo_callLater)=="function" then zo_callLater(step,0) else
            self.mapTeleporterTreasureIndexBuilding029365=false; self.mapTeleporterTreasureIndexReady029365=true
            self.mapTeleporterBuildCache029143={}
            if self.mapTeleporterPanel and not self.mapTeleporterPanel:IsHidden() and type(zo_callLater)=="function" then zo_callLater(function() if T and T.RefreshMapTeleporter then T:RefreshMapTeleporter(true) end end,0) end
        end
    end
    step()
end
local EAS_GetMapTeleporterItemEntriesBase029365= GetMapTeleporterItemEntriesImplArch
GetMapTeleporterItemEntriesImplArch = function(self)
    self:EnsureMapTeleporterTreasureIndex029365()
    local rows=EAS_GetMapTeleporterItemEntriesBase029365(self)
    local idx=self.mapTeleporterTreasureIndex029365 or {}; local routing=nil
    for _,row in ipairs(rows or {}) do
        if row.kind=="ITEM" and safeNumber(row.itemId,0)>0 then
            local loc=idx[safeNumber(row.itemId,0)]
            if loc and safeNumber(loc.zoneId,0)>0 then
                if not routing then
                    local snap=self:GetMapTeleporterSnapshot(); routing={social=self:GetMapTeleporterSocialEntries(),shrines=self:GetWayshrines(snap),houses=self:GetMapTeleporterHouseEntries()}
                end
                row.zoneId=loc.zoneId; row.zoneName=EAS_LocalizedText029358(loc.zoneName,"")
                row.travelEntry=self:GetMapTeleporterBestRouteForZone(row.zoneId,row.zoneName,routing.social,routing.shrines,routing.houses)
                row.canTravel=row.travelEntry~=nil
                row.statusText=row.travelEntry and ((row.travelEntry.kind=="GROUP" or row.travelEntry.kind=="FRIEND" or row.travelEntry.kind=="GUILD" or row.travelEntry.kind=="HOUSE") and "FREE" or (row.travelEntry.costText or "TRAVEL")) or "NO ROUTE"
            elseif self.mapTeleporterTreasureIndexBuilding029365 then
                row.zoneName=EAS_LocalizedText029358("Locating survey destination...","")
            end
            EAS_NormalizeTeleporterEntry029358(row)
        end
    end
    return rows
end

-- ============================================================================
-- v0.29.376 - Teleporter input/localization/survey hardening.
-- ============================================================================
local EAS_EnsureTeleporterHostBase029376 = EnsureMapTeleporterInteractionHost029136ImplArch
local EAS_InitializeTravelBase029376 = InitializeImplArch

-- Use a full-screen, low-tier interaction host while the outside-map Teleporter
-- owns UI mode. The Teleporter itself remains DT_HIGH, so its buttons win mouse
-- hit-testing; blank screen clicks hit this host and close the overlay reliably.
EnsureMapTeleporterInteractionHost029136ImplArch = function(self)
    local host = EAS_EnsureTeleporterHostBase029376(self)
    if not host or not GuiRoot then return host end
    host:ClearAnchors(); host:SetAnchorFill(GuiRoot)
    host:SetMouseEnabled(true)
    if host.SetKeyboardEnabled then host:SetKeyboardEnabled(true) end
    if host.SetDrawTier and DT_LOW then host:SetDrawTier(DT_LOW) end
    if host.SetDrawLayer and DL_BACKGROUND then host:SetDrawLayer(DL_BACKGROUND) end
    if host.SetDrawLevel then host:SetDrawLevel(1) end
    host:SetHandler("OnMouseUp", function(_, button, inside)
        local travel=EPC and EPC.Travel
        if not travel or travel.mapTeleporterHotkeySession029132~=true or travel:IsMapTeleporterMapShowing() then return end
        if not travel:IsMapTeleporterMouseInside029136() and not travel:IsMouseInsideMapTeleporterFlyout029358() then
            travel:CloseMapTeleporterOverlay029136(false)
        end
    end)
    host:SetHandler("OnKeyDown", function(_, key, ctrl, alt, shift, command)
        local travel=EPC and EPC.Travel
        if not travel or travel.mapTeleporterHotkeySession029132~=true or travel:IsMapTeleporterMapShowing() then return end
        local escape = KEY_ESCAPE ~= nil and key == KEY_ESCAPE
        local altKey = KEY_ALT ~= nil and key == KEY_ALT
        local altOnly = alt == true and ctrl ~= true and shift ~= true and command ~= true
        if escape or altKey or altOnly or travel:IsMapTeleporterToggleKey029134(key,ctrl,alt,shift,command) then
            travel:CloseMapTeleporterOverlay029136(false)
        end
    end)
    return host
end

-- Rebind the localized-text sanitizer to strip only ESO's ASCII grammar tokens.
-- The older broad fallback could consume too much text after malformed carets on
-- Russian clients. Never pattern-match arbitrary UTF-8 bytes.
EAS_LocalizedText029358 = function(value, fallback)
    local text=tostring(value or "")
    if text=="" then text=tostring(fallback or "") end
    if text~="" and type(zo_strformat)=="function" then
        local ok,formatted=pcall(zo_strformat,"<<1>>",text)
        if ok and type(formatted)=="string" and formatted~="" then text=formatted end
    end
    text=text:gsub("%^+[A-Za-z][A-Za-z0-9]*%b{}","")
    text=text:gsub("%^+[A-Za-z][A-Za-z0-9]*","")
    text=text:gsub("%^","")
    text=text:gsub("[%c]+"," "):gsub("%s+"," ")
    text=text:gsub("^%s+",""):gsub("%s+$","")
    return text~="" and text or tostring(fallback or "")
end

local function EAS_MapZoneId029376(mapId, mapMeta)
    mapId=safeNumber(mapId,0); if mapId<=0 then return 0,"" end
    local zoneId=0
    if type(GetMapInfoById)=="function" then
        local ok,_,_,_,zoneIndex=pcall(GetMapInfoById,mapId)
        zoneIndex=ok and safeNumber(zoneIndex,0) or 0
        if zoneIndex>0 and type(GetZoneId)=="function" then local oz,z=pcall(GetZoneId,zoneIndex); if oz then zoneId=safeNumber(z,0) end end
    end
    -- Some survey source maps have no direct zoneIndex. Resolve their universal
    -- rectangle to the smallest containing map that does have a zone.
    if zoneId<=0 and mapMeta and type(GetUniversallyNormalizedMapInfo)=="function" then
        local current=mapMeta[mapId]
        if current and current.w and current.w>0 and current.h and current.h>0 then
            local cx,cy=current.x+current.w*0.5,current.y+current.h*0.5
            local bestArea=nil
            for candidateId,m in pairs(mapMeta) do
                if m.zoneId and m.zoneId>0 and m.w and m.w>0 and m.h and m.h>0 then
                    if cx>=m.x and cx<=m.x+m.w and cy>=m.y and cy<=m.y+m.h then
                        local area=m.w*m.h
                        if area>=current.w*current.h and (bestArea==nil or area<bestArea) then zoneId=m.zoneId; bestArea=area end
                    end
                end
            end
        end
    end
    if zoneId>0 and type(GetParentZoneId)=="function" then
        for _=1,4 do local ok,p=pcall(GetParentZoneId,zoneId); p=ok and safeNumber(p,0) or 0; if p<=0 or p==zoneId then break end; zoneId=p end
    end
    local zoneName=""
    if zoneId>0 and type(GetZoneNameById)=="function" then local ok,n=pcall(GetZoneNameById,zoneId); if ok then zoneName=EAS_LocalizedText029358(n,"") end end
    return zoneId,zoneName
end

EnsureMapTeleporterTreasureIndex029365ImplArch = function(self)
    if self.mapTeleporterTreasureIndexReady029376 or self.mapTeleporterTreasureIndexBuilding029376 then return end
    if type(_G.LibTreasure_GetMapIdData)~="function" or type(GetNumMaps)~="function" or type(GetMapIdByIndex)~="function" then return end
    self.mapTeleporterTreasureIndexBuilding029376=true
    self.mapTeleporterTreasureIndexBuilding029365=true
    self.mapTeleporterTreasureIndexReady029365=false
    self.mapTeleporterTreasureIndex029365={}
    local ok,count=pcall(GetNumMaps); count=ok and safeNumber(count,0) or 0
    local ids,meta={},{}; local i=1
    local function metaStep()
        local stop=math.min(count,i+39)
        for n=i,stop do
            local oi,mapId=pcall(GetMapIdByIndex,n); mapId=oi and safeNumber(mapId,0) or 0
            if mapId>0 then
                ids[#ids+1]=mapId
                local zoneId=0
                if type(GetMapInfoById)=="function" then local om,_,_,_,zi=pcall(GetMapInfoById,mapId); zi=om and safeNumber(zi,0) or 0; if zi>0 and type(GetZoneId)=="function" then local oz,z=pcall(GetZoneId,zi); if oz then zoneId=safeNumber(z,0) end end end
                local x,y,w,h=0,0,0,0
                if type(GetUniversallyNormalizedMapInfo)=="function" then local orc,a,b,c,d=pcall(GetUniversallyNormalizedMapInfo,mapId); if orc then x,y,w,h=tonumber(a) or 0,tonumber(b) or 0,tonumber(c) or 0,tonumber(d) or 0 end end
                meta[mapId]={zoneId=zoneId,x=x,y=y,w=w,h=h}
            end
        end
        i=stop+1
        if i<=count and type(zo_callLater)=="function" then zo_callLater(metaStep,0) else
            local pos=1
            local function dataStep()
                local finish=math.min(#ids,pos+24)
                for k=pos,finish do
                    local mapId=ids[k]
                    local od,data=pcall(_G.LibTreasure_GetMapIdData,mapId)
                    if od and type(data)=="table" then
                        local zoneId,zoneName=EAS_MapZoneId029376(mapId,meta)
                        for _,pin in ipairs(data) do
                            if type(pin)=="table" then
                                local iid=safeNumber(pin.itemId or pin.itemID or pin.itemid,0)
                                if iid>0 then
                                    local old=self.mapTeleporterTreasureIndex029365[iid]
                                    if not old or (safeNumber(old.zoneId,0)<=0 and zoneId>0) then self.mapTeleporterTreasureIndex029365[iid]={mapId=mapId,zoneId=zoneId,zoneName=zoneName} end
                                end
                            end
                        end
                    end
                end
                pos=finish+1
                if pos<=#ids and type(zo_callLater)=="function" then zo_callLater(dataStep,0) else
                    self.mapTeleporterTreasureIndexBuilding029376=false; self.mapTeleporterTreasureIndexBuilding029365=false
                    self.mapTeleporterTreasureIndexReady029376=true; self.mapTeleporterTreasureIndexReady029365=true
                    self.mapTeleporterBuildCache029143={}
                    if self.mapTeleporter and not self.mapTeleporter:IsHidden() and type(zo_callLater)=="function" then zo_callLater(function() if T and T.RefreshMapTeleporter then T:RefreshMapTeleporter(true) end end,0) end
                end
            end
            dataStep()
        end
    end
    metaStep()
end

InitializeImplArch = function(self)
    local result=EAS_InitializeTravelBase029376(self)
    local prefix=(EPC.name or "ESOAdventurerSuite").."_TeleporterInput029376"
    if EVENT_GAME_CAMERA_UI_MODE_CHANGED then
        EPC.Runtime:RegisterEvent("Travel", "CameraUiMode", EVENT_GAME_CAMERA_UI_MODE_CHANGED,function()
            local travel=EPC and EPC.Travel
            if not travel or travel.mapTeleporterHotkeySession029132~=true or travel:IsMapTeleporterMapShowing() then return end
            local inUi = true
            if type(IsGameCameraUIModeActive) == "function" then
                local ok, value = pcall(IsGameCameraUIModeActive)
                if ok then inUi = value == true end
            end
            if not inUi then travel:CloseMapTeleporterOverlay029136(false) end
        end)
    end
    return result
end


-- ============================================================================
-- v0.29.381 - Teleporter input ownership, click-away, and UTF-8-safe labels.
-- ============================================================================
local function EAS_TeleporterStripGrammar029381(value, fallback)
    local text = tostring(value or "")
    if text == "" then text = tostring(fallback or "") end
    local out, i, n = {}, 1, #text
    while i <= n do
        local b = text:byte(i)
        if b == 94 then -- ^ : ESO grammar payload begins here
            i = i + 1
            -- Consume chained ASCII grammar directives such as ^Fa{1}n{2}.
            while i <= n do
                local c = text:byte(i)
                if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) then
                    i = i + 1
                elseif c == 123 then -- {
                    local close = text:find("}", i + 1, true)
                    if close then i = close + 1 else i = i + 1; break end
                else
                    break
                end
            end
        else
            out[#out + 1] = text:sub(i, i)
            i = i + 1
        end
    end
    text = table.concat(out)
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or tostring(fallback or "")
end
EAS_LocalizedText029358 = EAS_TeleporterStripGrammar029381

ApplyMapTeleporterOutsideInput029358ImplArch = function(self, root)
    root = root or self.mapTeleporter
    if not root or self:IsMapTeleporterMapShowing() or self.mapTeleporterHotkeySession029132 ~= true then return end
    local function keyHandler(_, key, ctrl, alt, shift, command)
        local isEscape = KEY_ESCAPE ~= nil and key == KEY_ESCAPE
        local isAltKey = KEY_ALT ~= nil and key == KEY_ALT
        local altOnly = alt == true and ctrl ~= true and shift ~= true and command ~= true
        if isEscape or isAltKey or altOnly or self:IsMapTeleporterToggleKey029134(key, ctrl, alt, shift, command) then
            if root.playerSearch and root.playerSearch.LoseFocus then pcall(root.playerSearch.LoseFocus, root.playerSearch) end
            if root.zoneSearch and root.zoneSearch.LoseFocus then pcall(root.zoneSearch.LoseFocus, root.zoneSearch) end
            self:CloseMapTeleporterOverlay029136(false)
        end
    end
    if root.SetKeyboardEnabled then root:SetKeyboardEnabled(true) end
    root:SetHandler("OnKeyDown", keyHandler)
    -- Focused search boxes receive key events before their parent. Wire the same
    -- close keys there while preserving ordinary typing/search behavior.
    for _, edit in ipairs({root.playerSearch, root.zoneSearch}) do
        if edit and edit.SetKeyboardEnabled then edit:SetKeyboardEnabled(true) end
        if edit and edit.SetHandler then
            local old = edit.GetHandler and edit:GetHandler("OnKeyDown") or nil
            if not edit.easTeleporterKeyWrapped029381 then
                edit.easTeleporterKeyWrapped029381 = true
                edit:SetHandler("OnKeyDown", function(control, key, ctrl, alt, shift, command)
                    local closeKey = (KEY_ESCAPE ~= nil and key == KEY_ESCAPE) or (KEY_ALT ~= nil and key == KEY_ALT)
                        or (alt == true and ctrl ~= true and shift ~= true and command ~= true)
                    if closeKey then keyHandler(control, key, ctrl, alt, shift, command); return end
                    if type(old) == "function" then pcall(old, control, key, ctrl, alt, shift, command) end
                end)
            end
        end
    end
    -- A click on empty Teleporter chrome should dismiss only the flyout/dropdown.
    if root.SetMouseEnabled then root:SetMouseEnabled(true) end
    if root.SetHandler and not root.easFlyoutClickAway029381 then
        root.easFlyoutClickAway029381 = true
        local prior = root.GetHandler and root:GetHandler("OnMouseUp") or nil
        root:SetHandler("OnMouseUp", function(control, button, inside)
            if self:IsMapTeleporterFlyoutOpen02969() and not self:IsMouseInsideMapTeleporterFlyout029358() then
                self:HideMapTeleporterFlyout02969()
            end
            if type(prior) == "function" then pcall(prior, control, button, inside) end
        end)
    end
end

local EAS_RefreshMapTeleporterBase029381 = RefreshMapTeleporterImplArch
RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase029381(self, ...)
    local root = self.mapTeleporter
    if root then
        -- Re-sanitize visible labels after every data refresh. This catches cached
        -- entries created before the current language-safe normalization pass.
        local labels = {root.title, root.status, root.playerSearchLabel, root.zoneSearchLabel}
        for _, label in ipairs(labels) do
            if label and label.GetText and label.SetText then
                local ok, value = pcall(label.GetText, label)
                if ok then label:SetText(EAS_TeleporterStripGrammar029381(value, "")) end
            end
        end
    end
    if self.mapTeleporterHotkeySession029132 == true and not self:IsMapTeleporterMapShowing() then
        self:ApplyMapTeleporterOutsideInput029358(root)
    end
    return result
end


-- ============================================================================
-- v0.29.384 - World Map Teleporter ESC/click-away + Russian label hardening.
-- ============================================================================
local EAS_CreateMapTeleporterBase029384 = CreateMapTeleporterImplArch
local EAS_RefreshMapTeleporterBase029384 = RefreshMapTeleporterImplArch
local EAS_ShowMapTeleporterFlyoutBase029384 = ShowMapTeleporterFlyout02969ImplArch

local function EAS_TeleporterDisplayText029384(value, fallback)
    local text = tostring(value or "")
    if text == "" then text = tostring(fallback or "") end

    -- Let ESO resolve its own grammar markers first. This is safe for Cyrillic
    -- and avoids hand-editing multibyte letters.
    if text ~= "" and type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end

    -- Remove only ASCII ESO display markup.  None of these patterns consume
    -- Cyrillic/UTF-8 bytes.
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|t[^|]-|t", "")
    text = text:gsub("|u[^|]-|u", "")
    text = text:gsub("%^+[A-Za-z][A-Za-z0-9]*%b{}", "")
    text = text:gsub("%^+[A-Za-z][A-Za-z0-9]*", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or tostring(fallback or "")
end

CreateMapTeleporterImplArch = function(self)
    local root = EAS_CreateMapTeleporterBase029384(self)
    -- Click-away must also be registered for the docked World Map Teleporter,
    -- not only for the hotkey/outside-map session.
    if self.RegisterMapTeleporterClickAway029136 then self:RegisterMapTeleporterClickAway029136() end
    return root
end

ShowMapTeleporterFlyout02969ImplArch = function(self, titleText, items, owner, contextMode)
    local cleanItems = {}
    for i, item in ipairs(items or {}) do
        if type(item) == "table" then
            local copy = {}
            for k, v in pairs(item) do copy[k] = v end
            if copy.text ~= nil then copy.text = EAS_TeleporterDisplayText029384(copy.text, "") end
            if copy.label ~= nil then copy.label = EAS_TeleporterDisplayText029384(copy.label, "") end
            cleanItems[i] = copy
        else
            cleanItems[i] = item
        end
    end
    return EAS_ShowMapTeleporterFlyoutBase029384(self, EAS_TeleporterDisplayText029384(titleText, "OPTIONS"), cleanItems, owner, contextMode)
end

RefreshMapTeleporterImplArch = function(self, ...)
    local result = EAS_RefreshMapTeleporterBase029384(self, ...)
    local root = self.mapTeleporter
    if not root then return result end

    -- The docked Teleporter must not retain keyboard ownership from an earlier
    -- hotkey session. Otherwise Escape/Alt never reaches the World Map scene.
    if self:IsMapTeleporterMapShowing() then
        if root.SetKeyboardEnabled then root:SetKeyboardEnabled(false) end
        if root.SetHandler then root:SetHandler("OnKeyDown", nil) end
        for _, edit in ipairs({root.playerSearch, root.zoneSearch}) do
            if edit and edit.SetHandler then
                edit:SetHandler("OnEscape", function(c)
                    if c and c.LoseFocus then c:LoseFocus() end
                    if self:IsMapTeleporterFlyoutOpen02969() then self:HideMapTeleporterFlyout02969() end
                end)
            end
        end
    end

    if self.RegisterMapTeleporterClickAway029136 then self:RegisterMapTeleporterClickAway029136() end

    -- Normalize every currently visible string, including rows. This addresses
    -- Russian names cached before the latest sanitizer and strips stray ESO
    -- grammar/markup without byte-wise mutation of Cyrillic text.
    local labels = {root.title, root.status, root.stats, root.page, root.playerSearchLabel, root.zoneSearchLabel}
    for _, control in ipairs(labels) do
        if control and control.GetText and control.SetText then
            local ok, value = pcall(control.GetText, control)
            if ok then control:SetText(EAS_TeleporterDisplayText029384(value, "")) end
        end
    end
    for _, row in ipairs(root.rows or {}) do
        for _, control in ipairs({row.name, row.zone, row.source, row.status}) do
            if control and control.GetText and control.SetText then
                local ok, value = pcall(control.GetText, control)
                if ok then control:SetText(EAS_TeleporterDisplayText029384(value, "")) end
            end
        end
    end
    return result
end


-- BEGIN ABSORBED: TeleporterArenaDelveFix.lua
-- ESO Adventurer Suite
-- v0.29.643 - Teleporter arena + delve destination bridge.
-- Adds ESO POI/activity-backed Delves and Arenas to the same shared Teleporter
-- dataset used by the World Map panel and hotkey window. Direct instance nodes
-- are preferred; otherwise the entry routes through the nearest known wayshrine.
-- Static POI/activity discovery is cached for the session; route-node matching is
-- rebuilt only after player activation so repeated Teleporter refreshes stay cheap.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Travel then return end
local T = EPC.Travel

local function num(v, fallback)
    v = tonumber(v)
    if v == nil then return fallback or 0 end
    return v
end

local function clean(v, fallback)
    v = tostring(v or "")
    v = v:gsub("[%c]+", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if v == "" then return fallback or "" end
    return v
end

local function lower(v)
    return string.lower(clean(v, ""))
end

local function call1(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a
end

local function zoneIndexForId(zoneId)
    zoneId = num(zoneId, 0)
    if zoneId <= 0 or type(GetZoneIndex) ~= "function" then return 0 end
    return num(call1(GetZoneIndex, 0, zoneId), 0)
end

local function zoneIdForIndex(zoneIndex)
    zoneIndex = num(zoneIndex, 0)
    if zoneIndex <= 0 or type(GetZoneId) ~= "function" then return 0 end
    return num(call1(GetZoneId, 0, zoneIndex), 0)
end

local function parentZoneId(zoneId)
    zoneId = num(zoneId, 0)
    if zoneId <= 0 or type(GetParentZoneId) ~= "function" then return zoneId end
    local parent = num(call1(GetParentZoneId, 0, zoneId), 0)
    if parent <= 0 or parent == zoneId then return zoneId end
    return parent
end

local function poiTypeEquals(value, constantName)
    local constant = rawget(_G, constantName)
    return constant ~= nil and value == constant
end

local function getNodeZoneIndex(nodeIndex)
    local fn = rawget(_G, "GetFastTravelNodePOIIndicies") or rawget(_G, "GetFastTravelNodePOIIndices")
    if type(fn) ~= "function" then return 0 end
    local ok, zoneIndex = pcall(fn, nodeIndex)
    return ok and num(zoneIndex, 0) or 0
end

function T:InvalidateArenaDelveRouteCache029643()
    self._arenaDelveRouteNodes029643 = nil
    self._arenaDelveExtraEntries029643 = nil
end

function T:BuildArenaDelveStaticDestinations029643()
    if self._arenaDelveStaticDestinations029643 then
        return self._arenaDelveStaticDestinations029643
    end

    local rows, seen = {}, {}
    local function add(kind, name, zoneIndex, zoneId, x, y, poiIndex, activityId)
        name = clean(name, kind == "ARENA" and "Arena" or "Delve")
        zoneIndex = num(zoneIndex, 0)
        zoneId = num(zoneId, 0)
        if zoneId <= 0 and zoneIndex > 0 then zoneId = zoneIdForIndex(zoneIndex) end
        if zoneIndex <= 0 and zoneId > 0 then zoneIndex = zoneIndexForId(zoneId) end
        if zoneId <= 0 and zoneIndex <= 0 then return end

        local key = kind .. ":" .. tostring(zoneId) .. ":" .. lower(name)
        if seen[key] then
            -- Prefer a POI-backed record because it has real map coordinates.
            local existing = seen[key]
            if (not existing.x or not existing.y) and x and y then
                existing.x, existing.y = tonumber(x), tonumber(y)
                existing.poiIndex = poiIndex
            end
            if activityId and not existing.activityId then existing.activityId = activityId end
            return
        end

        local zoneName = ""
        if zoneIndex > 0 and type(GetZoneNameByIndex) == "function" then
            zoneName = clean(call1(GetZoneNameByIndex, "", zoneIndex), "")
        end
        if zoneName == "" and zoneId > 0 and type(GetZoneNameById) == "function" then
            zoneName = clean(call1(GetZoneNameById, "", zoneId), "")
        end

        local row = {
            instanceCategory = kind,
            name = name,
            zoneName = zoneName ~= "" and zoneName or "Tamriel",
            zoneIndex = zoneIndex,
            zoneId = zoneId,
            parentZoneId = parentZoneId(zoneId),
            x = tonumber(x), y = tonumber(y),
            poiIndex = poiIndex,
            activityId = activityId,
        }
        rows[#rows + 1] = row
        seen[key] = row
    end

    -- POIs are authoritative for Delves and useful for Arenas because they give
    -- us the exact map position needed to pick the nearest wayshrine.
    if type(GetNumZones) == "function" and type(GetNumPOIs) == "function" and type(GetPOIType) == "function" then
        local zoneCount = num(call1(GetNumZones, 0), 0)
        for zoneIndex = 1, zoneCount do
            local zoneId = zoneIdForIndex(zoneIndex)
            local poiCount = num(call1(GetNumPOIs, 0, zoneIndex), 0)
            for poiIndex = 1, poiCount do
                local poiType = call1(GetPOIType, nil, zoneIndex, poiIndex)
                local kind = nil
                if poiTypeEquals(poiType, "POI_TYPE_DELVE") then kind = "DELVE"
                elseif poiTypeEquals(poiType, "POI_TYPE_ARENA") then kind = "ARENA" end

                if kind then
                    local name = ""
                    if type(GetPOIInfo) == "function" then
                        name = clean(call1(GetPOIInfo, "", zoneIndex, poiIndex), "")
                    end
                    local x, y, shown, locked
                    if type(GetPOIMapInfo) == "function" then
                        local ok, px, py, _, _, isShown, collectibleLocked = pcall(GetPOIMapInfo, zoneIndex, poiIndex)
                        if ok then x, y, shown, locked = tonumber(px), tonumber(py), isShown, collectibleLocked end
                    end
                    -- Keep discovered/unlocked POIs and also named POIs that ESO
                    -- exposes even when their current-map visibility is false.
                    if name ~= "" and locked ~= true then
                        add(kind, name, zoneIndex, zoneId, x, y, poiIndex, nil)
                    end
                end
            end
        end
    end

    -- Activity Finder/Group Finder data fills Arena gaps that do not expose a
    -- normal map POI or fast-travel node. LFG_ACTIVITY_ARENA is the native type.
    local arenaType = rawget(_G, "LFG_ACTIVITY_ARENA")
    if arenaType ~= nil and type(GetNumActivitiesByType) == "function" and type(GetActivityIdByTypeAndIndex) == "function" then
        local count = num(call1(GetNumActivitiesByType, 0, arenaType), 0)
        for i = 1, count do
            local activityId = num(call1(GetActivityIdByTypeAndIndex, 0, arenaType, i), 0)
            if activityId > 0 then
                local name = ""
                if type(GetActivityInfo) == "function" then
                    name = clean(call1(GetActivityInfo, "", activityId), "")
                end
                local zoneId = 0
                if type(GetActivityZoneId) == "function" then
                    zoneId = num(call1(GetActivityZoneId, 0, activityId), 0)
                end
                if name ~= "" and zoneId > 0 then
                    add("ARENA", name, zoneIndexForId(zoneId), zoneId, nil, nil, nil, activityId)
                end
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.instanceCategory ~= b.instanceCategory then return a.instanceCategory < b.instanceCategory end
        if lower(a.zoneName) ~= lower(b.zoneName) then return lower(a.zoneName) < lower(b.zoneName) end
        return lower(a.name) < lower(b.name)
    end)

    self._arenaDelveStaticDestinations029643 = rows
    return rows
end

function T:BuildArenaDelveRouteNodes029643()
    if self._arenaDelveRouteNodes029643 then return self._arenaDelveRouteNodes029643 end

    local nodes = {}
    local count = type(GetNumFastTravelNodes) == "function" and num(call1(GetNumFastTravelNodes, 0), 0) or 0
    for nodeIndex = 1, count do
        local ok, known, name, x, y, _, _, poiType, _, locked = pcall(GetFastTravelNodeInfo, nodeIndex)
        if ok and known == true and locked ~= true then
            local zoneIndex = getNodeZoneIndex(nodeIndex)
            local zoneId = zoneIdForIndex(zoneIndex)
            local houseId = 0
            if type(GetFastTravelNodeHouseId) == "function" then
                houseId = num(call1(GetFastTravelNodeHouseId, 0, nodeIndex), 0)
            end
            if houseId <= 0 then
                nodes[#nodes + 1] = {
                    nodeIndex = nodeIndex,
                    name = clean(name, "Travel Node"),
                    x = tonumber(x), y = tonumber(y),
                    zoneIndex = zoneIndex,
                    zoneId = zoneId,
                    parentZoneId = parentZoneId(zoneId),
                    poiType = poiType,
                    isWayshrine = rawget(_G, "POI_TYPE_WAYSHRINE") ~= nil and poiType == POI_TYPE_WAYSHRINE,
                }
            end
        end
    end
    self._arenaDelveRouteNodes029643 = nodes
    return nodes
end

local function routeScore(destination, node)
    local exactZone = destination.zoneId > 0 and node.zoneId == destination.zoneId
    local parentMatch = destination.parentZoneId > 0
        and (node.zoneId == destination.parentZoneId or node.parentZoneId == destination.parentZoneId)
    if not exactZone and not parentMatch then return nil end

    local score = exactZone and 0 or 100
    if node.isWayshrine then score = score + 10 end
    if destination.x and destination.y and node.x and node.y then
        local dx, dy = destination.x - node.x, destination.y - node.y
        score = score + (dx * dx + dy * dy)
    else
        score = score + 1
    end
    return score
end

function T:FindArenaDelveRouteNode029643(destination)
    local nodes = self:BuildArenaDelveRouteNodes029643()
    local best, bestScore = nil, nil

    -- Prefer a direct Arena/Delve node for the same destination when ESO exposes
    -- one. Name matching is only used as a preference, never as the sole route.
    local wanted = lower(destination.name)
    for _, node in ipairs(nodes) do
        local score = routeScore(destination, node)
        if score then
            local nodeName = lower(node.name)
            local directType = (destination.instanceCategory == "ARENA" and poiTypeEquals(node.poiType, "POI_TYPE_ARENA"))
                or (destination.instanceCategory == "DELVE" and poiTypeEquals(node.poiType, "POI_TYPE_DELVE"))
            if directType then score = score - 50 end
            if wanted ~= "" and nodeName ~= "" and (nodeName == wanted or nodeName:find(wanted, 1, true) or wanted:find(nodeName, 1, true)) then
                score = score - 25
            end
            if bestScore == nil or score < bestScore then best, bestScore = node, score end
        end
    end
    return best
end

function T:GetArenaDelveExtraEntries029643()
    if self._arenaDelveExtraEntries029643 then return self._arenaDelveExtraEntries029643 end

    local out = {}
    for _, destination in ipairs(self:BuildArenaDelveStaticDestinations029643()) do
        local route = self:FindArenaDelveRouteNode029643(destination)
        local cost = 0
        if route and type(self.GetLiveWayshrineTravelCost) == "function" then
            local ok, value = pcall(self.GetLiveWayshrineTravelCost, self, route.nodeIndex)
            if ok then cost = num(value, 0) end
        end
        out[#out + 1] = {
            kind = "INSTANCE",
            key = "I:EAS643:" .. destination.instanceCategory .. ":" .. tostring(destination.zoneId) .. ":" .. lower(destination.name),
            nodeIndex = route and route.nodeIndex or nil,
            name = destination.name,
            displayName = destination.name,
            zoneName = destination.zoneName,
            zoneId = destination.zoneId,
            zoneIndex = destination.zoneIndex,
            parentZoneId = destination.parentZoneId,
            normalizedX = destination.x or (route and route.x),
            normalizedY = destination.y or (route and route.y),
            poiType = destination.instanceCategory == "DELVE" and rawget(_G, "POI_TYPE_DELVE") or rawget(_G, "POI_TYPE_ARENA"),
            instanceCategory = destination.instanceCategory,
            activityId = destination.activityId,
            routeViaWayshrine029643 = route and route.isWayshrine == true or false,
            routeNodeName029643 = route and route.name or "",
            canTravel = route ~= nil,
            statusText = route and nil or "No discovered travel node is currently available near this destination.",
            costText = cost <= 0 and "Free" or (tostring(math.floor(cost + 0.5)) .. " gold"),
        }
    end

    self._arenaDelveExtraEntries029643 = out
    return out
end

-- One shared source feeds ALL / DELVES / DUNGEONS / INSTANCES in both the big
-- World Map panel and hotkey Teleporter, so fixing the instance source fixes both.
if type(T.GetMapTeleporterInstanceEntries) == "function" and not T._easArenaDelveWrapped029643 then
    T._easArenaDelveWrapped029643 = true
    local baseInstances = GetMapTeleporterInstanceEntriesImplArch
    GetMapTeleporterInstanceEntriesImplArch = function(self, ...)
        local rows = baseInstances(self, ...) or {}
        local seen = {}
        for _, entry in ipairs(rows) do
            local key = lower(entry and entry.name or "") .. ":" .. tostring(num(entry and entry.zoneId, 0))
            seen[key] = true
        end
        for _, entry in ipairs(self:GetArenaDelveExtraEntries029643()) do
            local key = lower(entry.name) .. ":" .. tostring(num(entry.zoneId, 0))
            if not seen[key] then
                rows[#rows + 1] = entry
                seen[key] = true
            end
        end
        table.sort(rows, function(a, b)
            local ca, cb = tostring(a.instanceCategory or "INSTANCE"), tostring(b.instanceCategory or "INSTANCE")
            if ca ~= cb then return ca < cb end
            if lower(a.zoneName) ~= lower(b.zoneName) then return lower(a.zoneName) < lower(b.zoneName) end
            return lower(a.name) < lower(b.name)
        end)
        return rows
    end
end

-- Make routed entries explicit in chat so a Delve/Arena entry never pretends a
-- nearby wayshrine is the instance door itself.
if type(T.TravelMapTeleporterEntry) == "function" and not T._easArenaDelveTravelWrapped029643 then
    T._easArenaDelveTravelWrapped029643 = true
    local baseTravel = TravelMapTeleporterEntryImplArch
    TravelMapTeleporterEntryImplArch = function(self, entry, ...)
        if entry and entry.routeViaWayshrine029643 and entry.routeNodeName029643 ~= "" and EPC.Print then
            EPC:Print("Routing to " .. clean(entry.name, "destination") .. " via " .. entry.routeNodeName029643 .. ".")
        end
        return baseTravel(self, entry, ...)
    end
end

if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED then
    EPC.Runtime:RegisterEvent("Travel", "ArenaDelveRoutes", EVENT_PLAYER_ACTIVATED, function()
        if EPC.Travel and EPC.Travel.InvalidateArenaDelveRouteCache029643 then
            EPC.Travel:InvalidateArenaDelveRouteCache029643()
        end
    end)
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easdestinations"] = function()
    local static = T:BuildArenaDelveStaticDestinations029643()
    local delves, arenas = 0, 0
    for _, d in ipairs(static) do
        if d.instanceCategory == "DELVE" then delves = delves + 1
        elseif d.instanceCategory == "ARENA" then arenas = arenas + 1 end
    end
    local extras = T:GetArenaDelveExtraEntries029643()
    local routable = 0
    for _, e in ipairs(extras) do if e.canTravel ~= false then routable = routable + 1 end end
    local text = string.format("EAS Teleporter destinations | delves=%d arenas=%d routable=%d/%d", delves, arenas, routable, #extras)
    if type(d) == "function" then d(text) elseif EPC.Print then EPC:Print(text) end
end

-- END ABSORBED: TeleporterArenaDelveFix.lua
