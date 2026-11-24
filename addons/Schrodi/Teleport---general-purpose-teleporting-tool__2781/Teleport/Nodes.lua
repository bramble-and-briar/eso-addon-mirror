local Teleport = Teleport
Teleport.Nodes = {}

local info  = Teleport.info
local color = Teleport.color
local C     = Teleport.COLORS

-- There seems to be no other way of telling if something is a 4-man dungeon
-- (POI_TYPE_GROUP_DUNGEON includes those and Blackrose Prison)
-- a trial or a solo/group arena (POI_TYPE seems to be almost random for those)
-- so I'm using texture names instead to tell them apart from other 
-- fast travel nodes. Better that than a hardcoded list of arenas, eh?
	
local DUNGEON_TEXTURE_NAMES = {
	['/esoui/art/icons/poi/poi_raiddungeon_glow.dds'   ] = true,
	['/esoui/art/icons/poi/poi_groupinstance_glow.dds' ] = true,
	['/esoui/art/icons/poi/poi_endlessdungeon_glow.dds'] = true,
	['/esoui/art/icons/poi/poi_solotrial_glow.dds'	   ] = true,
}

--------------------------------------------------------------------------------

Teleport.Nodes.wayshrinesByZoneIndexPoiIndex = {}
local dungeons, sortedDungeons, houses, sortedHouses, wayshrines, sortedWayshrines, wayshrinesByZoneIndexPoiIndex
local wayshrineNodeIndices, houseNodeIndices
function Teleport.Nodes:initialize()
    dungeons = {}
    houses = {}
    wayshrines = {}
    wayshrineNodeIndices = {}
    houseNodeIndices = {}
    wayshrinesByZoneIndexPoiIndex = {}
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local _, nodeName, _, _, _, textureName, poiType = GetFastTravelNodeInfo(nodeIndex)
        if not nodeName then 
            -- continue
        else
            if poiType == POI_TYPE_WAYSHRINE then
                wayshrines[nodeName] = nodeIndex
                table.insert(wayshrineNodeIndices, nodeIndex)
                local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(nodeIndex)
                if not wayshrinesByZoneIndexPoiIndex[zoneIndex] then
                    wayshrinesByZoneIndexPoiIndex[zoneIndex] = {}
                end
                wayshrinesByZoneIndexPoiIndex[zoneIndex][poiIndex] = nodeIndex
            elseif poiType == POI_TYPE_HOUSE then
                houses[nodeName] = nodeIndex
                table.insert(houseNodeIndices, nodeIndex)
            else
                if DUNGEON_TEXTURE_NAMES[textureName] then
                    if Teleport.Helpers:startsWith(nodeName, 'Dungeon: ') then
                        dungeons[string.sub(nodeName, 10)] = nodeIndex
                    elseif Teleport.Helpers:startsWith(nodeName, 'Trial: ') then
                        dungeons[string.sub(nodeName, 8)] = nodeIndex
                    else
                        dungeons[nodeName] = nodeIndex
                    end
                end
            end
        end
    end

    local keys = {}
    for key in pairs(dungeons) do
        table.insert(keys, key)
    end
    table.sort(keys)
    sortedDungeons = keys
    
    keys = {}
    for key in pairs(houses) do
        table.insert(keys, key)
    end
    table.sort(keys)
    sortedHouses = keys
    
    keys = {}
    for key in pairs(wayshrines) do
        table.insert(keys, key)
    end
    -- trim the ' Wayshrine' suffix when comparing
    table.sort(keys, function (a, b) return string.sub(a, 1, #a - 10) < string.sub(b, 1, #b - 10) end)
    sortedWayshrines = keys
	
	Teleport.Aliases:generateDungeonAliases(sortedDungeons)
end

-------------------------------------------------------------------------------

function Teleport.Nodes:isKnown(nodeIndex)
    return GetFastTravelNodeInfo(nodeIndex)
end

function Teleport.Nodes:getRecallCostString(nodeIndex)
    if Teleport.Helpers:isAtWayshrine() then
        return ""
    end

    return " (cost: " .. tostring(GetRecallCost(nodeIndex)) .. "g)";
end

-------------------------------------------------------------------------------

function Teleport.Nodes:getDungeonNodeIndex(exactName)
    return dungeons[exactName]
end

function Teleport.Nodes:findDungeonNode(namePrefix)
    for _, name in pairs(sortedDungeons) do
        if Teleport.Helpers:startsWithCaseInsensitive(name, namePrefix) then
            return name, dungeons[name]
        end
    end
    
    return nil
end

-------------------------------------------------------------------------------

function Teleport.Nodes:getWayshrineNodeIndex(exactName)
    return wayshrines[exactName]
end

function Teleport.Nodes:findWayshrineNode(namePrefix)
    for _, name in pairs(sortedWayshrines) do
        if Teleport.Helpers:startsWithCaseInsensitive(name, namePrefix) then
            return name, wayshrines[name]
        end
    end
    
    return nil
end

function Teleport.Nodes:getWayshrineByZoneByPoiIndices(zoneIndex, poiIndex)
    return wayshrinesByZoneIndexPoiIndex[zoneIndex] and wayshrinesByZoneIndexPoiIndex[zoneIndex][poiIndex]
end

-- Known wayshrines that are drawn on the currently set map, with their
-- coordinates on that map. Doesn't touch the map state itself.
function Teleport.Nodes:getKnownWayshrinesOnCurrentMap()
    local result = {}
    local mapZoneIndex = GetCurrentMapZoneIndex()

    for _, nodeIndex in ipairs(wayshrineNodeIndices) do
        local known, name, x, y, _, _, _, isShownInCurrentMap, isLocked = GetFastTravelNodeInfo(nodeIndex)
        if known and not isLocked and Teleport.Helpers:isOnMap(x, y) then
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            local isOutboundOnly = GetFastTravelNodeOutboundOnlyInfo(nodeIndex)
            if (isShownInCurrentMap or zoneIndex == mapZoneIndex) and not isOutboundOnly then
                table.insert(result, { index = nodeIndex, name = name, x = x, y = y })
            end
        end
    end

    return result
end

-- Houses you own that are drawn on the currently set map. Jumping outside
-- of them is free from anywhere, so they're as good as a wayshrine you're
-- standing at.
function Teleport.Nodes:getOwnedHousesOnCurrentMap()
    local result = {}
    local mapZoneIndex = GetCurrentMapZoneIndex()

    for _, nodeIndex in ipairs(houseNodeIndices) do
        local _, name, x, y, _, _, _, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if Teleport.Helpers:isOnMap(x, y) then
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            local houseId = GetFastTravelNodeHouseId(nodeIndex)
            local collectibleId = houseId and houseId ~= 0 and GetCollectibleIdForHouse(houseId)
            if (isShownInCurrentMap or zoneIndex == mapZoneIndex)
                and collectibleId and collectibleId ~= 0 and IsCollectibleUnlocked(collectibleId) then
                table.insert(result, { index = nodeIndex, name = name, x = x, y = y, houseId = houseId, isHouse = true })
            end
        end
    end

    return result
end

-------------------------------------------------------------------------------
-- Picking the cheapest way to reach one of several targets on a map.
--
-- A plan holds the best wayshrine (closest to any of the targets), the best
-- owned house (only with includeHouses) and, if the player is on that map,
-- the closest target to the player. All distances are in meters so plans
-- from different maps can be compared.

-- don't bother with a loading screen if it saves less than this much running
Teleport.Nodes.WALK_MARGIN_METERS = 150

-- targets: list of { x = , y = , radius = (optional, normalized), ... }
function Teleport.Nodes:planOnCurrentMap(targets, includeHouses)
    local plan = {}
    local nodes = self:getKnownWayshrinesOnCurrentMap()
    local houses = includeHouses and self:getOwnedHousesOnCurrentMap() or {}
    local px, py, _, isPlayerShown = GetMapPlayerPosition("player")
    plan.playerOnMap = isPlayerShown and Teleport.Helpers:isOnMap(px, py) or false

    for _, target in ipairs(targets) do
        local radius = 0
        if target.radius and target.radius > 0 then
            radius = Teleport.Helpers:mapDistance(0, 0, target.radius, 0)
        end

        for _, node in ipairs(nodes) do
            local distance = math.max(0, Teleport.Helpers:mapDistance(node.x, node.y, target.x, target.y) - radius)
            if not plan.nodeDistance or distance < plan.nodeDistance then
                plan.node, plan.nodeTarget, plan.nodeDistance = node, target, distance
            end
        end

        for _, house in ipairs(houses) do
            local distance = math.max(0, Teleport.Helpers:mapDistance(house.x, house.y, target.x, target.y) - radius)
            if not plan.houseDistance or distance < plan.houseDistance then
                plan.house, plan.houseTarget, plan.houseDistance = house, target, distance
            end
        end

        if plan.playerOnMap then
            local distance = math.max(0, Teleport.Helpers:mapDistance(px, py, target.x, target.y) - radius)
            if not plan.walkDistance or distance < plan.walkDistance then
                plan.walkTarget, plan.walkDistance = target, distance
            end
        end
    end

    return plan
end

function Teleport.Nodes:mergePlans(plans)
    local merged = {}
    for _, plan in ipairs(plans) do
        merged.playerOnMap = merged.playerOnMap or plan.playerOnMap
        if plan.nodeDistance and (not merged.nodeDistance or plan.nodeDistance < merged.nodeDistance) then
            merged.node, merged.nodeTarget, merged.nodeDistance = plan.node, plan.nodeTarget, plan.nodeDistance
        end
        if plan.houseDistance and (not merged.houseDistance or plan.houseDistance < merged.houseDistance) then
            merged.house, merged.houseTarget, merged.houseDistance = plan.house, plan.houseTarget, plan.houseDistance
        end
        if plan.walkDistance and (not merged.walkDistance or plan.walkDistance < merged.walkDistance) then
            merged.walkTarget, merged.walkDistance = plan.walkTarget, plan.walkDistance
        end
    end
    return merged
end

-- closest place to teleport to: wayshrine or owned house, or nil
-- returns spot, target, distance
function Teleport.Nodes:bestSpot(plan)
    if not plan then return nil end
    if plan.houseDistance and (not plan.nodeDistance or plan.houseDistance <= plan.nodeDistance) then
        return plan.house, plan.houseTarget, plan.houseDistance
    end
    if plan.nodeDistance then
        return plan.node, plan.nodeTarget, plan.nodeDistance
    end
    return nil
end

-- true when running there yourself is at least as good as any wayshrine / house
function Teleport.Nodes:shouldWalk(plan)
    if not plan or not plan.walkDistance then return false end
    local _, _, distance = self:bestSpot(plan)
    if not distance then return true end
    return plan.walkDistance <= distance + self.WALK_MARGIN_METERS
end

function Teleport.Nodes:travelOutsideHouse(house, suffix)
    info("Teleporting outside " .. color(house.name, C.HOUSE) .. (suffix or ""))
    RequestJumpToHouse(house.houseId, true)
    return true
end

-- wayshrine or house, whichever spot it is
function Teleport.Nodes:travelToSpot(spot, suffix)
    if spot.isHouse then
        return self:travelOutsideHouse(spot, suffix)
    end
    return self:travelTo(spot.index, suffix)
end

function Teleport.Nodes:travelTo(nodeIndex, suffix)
    local _, nodeName = GetFastTravelNodeInfo(nodeIndex)
    info("Teleporting to " .. color(nodeName, C.WAYSHRINE) .. (suffix or "") .. self:getRecallCostString(nodeIndex))
    FastTravelToNode(nodeIndex)
    return true
end

-------------------------------------------------------------------------------

function Teleport.Nodes:getHouseNodeIndex(exactName)
    return houses[exactName]
end

function Teleport.Nodes:findHouseNode(namePrefix)
    for _, name in pairs(sortedHouses) do
        if Teleport.Helpers:startsWithCaseInsensitive(name, namePrefix) then
            return name, houses[name]
        end
    end
    
    return nil
end
