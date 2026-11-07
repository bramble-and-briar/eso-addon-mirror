local A = OneMap

function A:ZoneDestination(zoneId, name)
    if not zoneId or zoneId <= 0 then return nil end
    return { kind = "zone", zoneId = zoneId, name = name or GetZoneNameById(zoneId) }
end

function A:MapDestination(mapIndex)
    if not mapIndex then return nil end
    local name, _, _, zoneIndex = GetMapInfoByIndex(mapIndex)
    if not zoneIndex or zoneIndex <= 0 then return nil end
    return self:ZoneDestination(GetZoneId(zoneIndex), name)
end

function A:NodeDestination(nodeIndex)
    if not nodeIndex then return nil end
    local _, name, _, _, _, _, poiType = GetFastTravelNodeInfo(nodeIndex)
    local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(nodeIndex)
    if not zoneIndex or zoneIndex <= 0 then return nil end
    local zoneId = GetZoneId(zoneIndex)
    local houseId = GetFastTravelNodeHouseId(nodeIndex)
    local instanceType = GetPOIInstanceType(zoneIndex, poiIndex)
    local displayType = GetFastTravelNodeZoneDisplayType(nodeIndex)
    local filter = GetPOIMapFilterOverride(zoneIndex, poiIndex)
    local kind = "node"
    if houseId and houseId > 0 then
        kind = "house"
    elseif filter == MAP_FILTER_TRIALS or instanceType == INSTANCE_TYPE_RAID or displayType == ZONE_DISPLAY_TYPE_RAID then
        kind = "trial"
    elseif filter ~= MAP_FILTER_ARENAS and poiType == POI_TYPE_GROUP_DUNGEON
        and displayType ~= ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON then
        kind = "dungeon"
    end
    if kind == "dungeon" or kind == "trial" then
        -- Prefer the authoritative POI label. Some clients also prefix this
        -- label; interior-zone matching below handles that presentation.
        local poiName = GetPOIInfo(zoneIndex, poiIndex)
        if poiName and poiName ~= "" then name = poiName end
    end
    return { kind = kind, nodeIndex = nodeIndex, zoneId = zoneId,
        houseId = houseId, name = name, location = GetZoneNameById(zoneId) }
end

function A:QuestDestination(questIndex)
    if not IsValidQuestIndex(questIndex) then return nil end
    local _, _, zoneIndex = GetJournalQuestLocationInfo(questIndex)
    local zoneId = zoneIndex and zoneIndex > 0 and GetZoneId(zoneIndex) or nil
    if not zoneId or zoneId <= 0 then
        zoneId = GetQuestZoneId(GetJournalQuestId(questIndex))
    end
    local destination = self:ZoneDestination(zoneId, GetJournalQuestName(questIndex))
    if destination then destination.questIndex = questIndex end
    return destination
end

function A:AntiquityDestination(antiquity)
    local destination = self:ZoneDestination(antiquity:GetZoneId(), antiquity:GetName())
    if destination then destination.antiquityId = antiquity:GetId() end
    return destination
end

-- Only real, non-symbolic quest coordinates on the requested zone map qualify.
-- Breadcrumbs point to doors or transport NPCs and must not select a wayshrine.
function A:QuestPoints(questIndex)
    local points = {}
    local steps = WORLD_MAP_QUEST_BREADCRUMBS:GetSteps(questIndex)
    for _, conditions in pairs(steps or {}) do
        for _, position in pairs(conditions) do
            if position.insideCurrentMapWorld and not position.isBreadcrumb
                and position.symbolicState == QUEST_PIN_STATE_NONE
                and position.xLoc and position.yLoc then
                points[#points + 1] = { x = position.xLoc, y = position.yLoc }
            end
        end
    end
    return points
end

function A:AntiquityPoints(antiquityId)
    local points = {}
    for index = 1, GetNumInProgressAntiquities() do
        if GetInProgressAntiquityId(index) == antiquityId then
            for digIndex = 1, GetNumDigSitesForInProgressAntiquity(index) do
                local digId = GetInProgressAntiquityDigSiteId(index, digIndex)
                local x, y, shown = GetDigSiteNormalizedCenterPosition(digId)
                if shown then points[#points + 1] = { x = x, y = y } end
            end
        end
    end
    return points
end

function A:IsUsableNode(nodeIndex)
    local known, _, _, _, _, _, _, _, locked = GetFastTravelNodeInfo(nodeIndex)
    return known and not locked and not GetFastTravelNodeOutboundOnlyInfo(nodeIndex)
end

function A:SelectWayshrine(destination)
    local function Select()
        local points = {}
        if destination.antiquityId then points = self:AntiquityPoints(destination.antiquityId) end
        if destination.questIndex and self.questPointCache then
            local cached = self.questPointCache[destination.questIndex]
            if cached and cached.mapId == GetCurrentMapId() then points = cached.points end
        end
        local bestNode, bestDistance, bestPriority
        for nodeIndex = 1, GetNumFastTravelNodes() do
            local _, _, x, y, _, _, poiType, shown = GetFastTravelNodeInfo(nodeIndex)
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            if poiType == POI_TYPE_WAYSHRINE and zoneIndex and GetZoneId(zoneIndex) == destination.zoneId
                and self:IsUsableNode(nodeIndex) then
                local distance
                if shown and #points > 0 then
                    for _, point in ipairs(points) do
                        local squared = (x - point.x)^2 + (y - point.y)^2
                        distance = distance and math.min(distance, squared) or squared
                    end
                end
                local priority = GetFastTravelNodeMapPriority(nodeIndex)
                priority = (priority or -math.huge) + (IsFastTravelNodeAutoDiscovered(nodeIndex) and 0.5 or 0)
                local better
                if #points > 0 then
                    better = distance and (not bestDistance or distance < bestDistance)
                else
                    better = not bestNode or priority > bestPriority
                end
                if better then bestNode, bestDistance, bestPriority = nodeIndex, distance, priority end
            end
        end
        return bestNode
    end
    if not destination.antiquityId then return Select() end
    return self:OnZoneMap(destination.zoneId, Select)
end

function A:BuildInstanceZones()
    local byName = {}
    local function AddName(name, zoneId)
        if not name or name == "" then return end
        local key = zo_strformat(SI_LFG_ACTIVITY_NAME, name)
        if byName[key] == nil or byName[key] == zoneId then byName[key] = zoneId
        else byName[key] = false end
    end
    for _, activityType in ipairs({ LFG_ACTIVITY_DUNGEON, LFG_ACTIVITY_MASTER_DUNGEON, LFG_ACTIVITY_TRIAL }) do
        for index = 1, GetNumActivitiesByType(activityType) do
            local activityId = GetActivityIdByTypeAndIndex(activityType, index)
            local zoneId = GetActivityZoneId(activityId)
            if zoneId and zoneId > 0 then
                AddName(GetActivityName(activityId), zoneId)
                AddName(GetZoneNameById(zoneId), zoneId)
            end
        end
    end
    self.instanceZones = byName
end

function A:GetInstanceZone(destination)
    if not self.instanceZones then self:BuildInstanceZones() end
    local name = zo_strformat(SI_LFG_ACTIVITY_NAME, destination.name)
    if self.instanceZones[name] ~= nil then return self.instanceZones[name] or nil end
    local result, longest = nil, 0
    for activityName, zoneId in pairs(self.instanceZones) do
        if zoneId and #activityName > 0 and #activityName <= #name then
            local prefix = name:sub(1, #name - #activityName)
            if name:sub(-#activityName) == activityName
                and (prefix:match(":%s*$") or prefix:match("пјљ%s*$")) then
                if #activityName > longest then result, longest = zoneId, #activityName
                elseif #activityName == longest and result ~= zoneId then result = nil end
            end
        end
    end
    return result
end

function A:InstanceList(kind)
    local entries = {}
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local entry = self:NodeDestination(nodeIndex)
        if entry and (entry.kind == kind or (kind == "instances"
            and (entry.kind == "dungeon" or entry.kind == "trial"))) then
            entry.name = zo_strformat(SI_ZONE_NAME, entry.name)
            entry.name = entry.name:gsub("^Dungeon:%s*", ""):gsub("^Trial:%s*", "")
            entry.location = zo_strformat(SI_ZONE_NAME, entry.location)
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    return entries
end
