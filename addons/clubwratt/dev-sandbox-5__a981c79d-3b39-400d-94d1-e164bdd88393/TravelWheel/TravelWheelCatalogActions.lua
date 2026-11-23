-- TravelWheelCatalogActions.lua: Reads what the game offers to travel to:
-- wayshrines by zone, houses, campaigns and battleground queues.

local TravelWheelCatalogActions = {}

local Utils = TravelWheel.CatalogUtils

-- The battleground finder lists its queues under one of these by level.
local function BattlegroundActivityTypes()
    return {
        LFG_ACTIVITY_BATTLE_GROUND_CHAMPION,
        LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION,
        LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL,
    }
end

---@type TravelWheelZone[]|nil
local zones = nil
---@type table<integer, TravelWheelNode[]>
local nodesByZone = {}

---Every discovered fast travel node except houses (houses are their own
---kind), grouped by zone. Built once and again after a discovery.
local function BuildNodes()
    zones = {}
    nodesByZone = {}
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local known, rawName, _, _, icon, _, poiType, _, collectibleLocked = GetFastTravelNodeInfo(nodeIndex)
        local name = Utils.CleanName(rawName)
        if known and not collectibleLocked and poiType ~= POI_TYPE_HOUSE and name ~= ""
            and not GetFastTravelNodeOutboundOnlyInfo(nodeIndex) then
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            local zoneId = type(zoneIndex) == "number" and GetZoneId(zoneIndex) or 0
            if zoneId ~= 0 then
                if not nodesByZone[zoneId] then
                    nodesByZone[zoneId] = {}
                    zones[#zones + 1] = { zoneId = zoneId, name = Utils.CleanName(GetZoneNameById(zoneId)) }
                end
                local nodes = nodesByZone[zoneId]
                nodes[#nodes + 1] = { nodeIndex = nodeIndex, name = name, icon = icon, zoneId = zoneId }
            end
        end
    end
    Utils.SortByName(zones)
    for _, nodes in pairs(nodesByZone) do
        Utils.SortByName(nodes)
    end
end

---@return TravelWheelZone[] zones Zones with a discovered node, by name
function TravelWheelCatalogActions.Zones()
    if not zones then
        BuildNodes()
    end
    return zones
end

---@param zoneId integer
---@return TravelWheelNode[] nodes Discovered nodes of the zone, by name
function TravelWheelCatalogActions.Nodes(zoneId)
    if not zones then
        BuildNodes()
    end
    return nodesByZone[zoneId] or {}
end

---@return integer zoneId The zone the map shows for where the player stands
function TravelWheelCatalogActions.PlayerZoneId()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    return Utils.OverlandZoneId(zoneId, GetParentZoneId(zoneId))
end

---@return TravelWheelHouse[] houses Every house in the game, owned first
function TravelWheelCatalogActions.Houses()
    local houses = {}
    for index = 1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_HOUSE) do
        local collectibleId = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_HOUSE, index)
        local name = Utils.CleanName(GetCollectibleName(collectibleId))
        local houseId = GetCollectibleReferenceId(collectibleId)
        if name ~= "" and houseId ~= 0 then
            houses[#houses + 1] = {
                houseId = houseId,
                name = name,
                icon = GetCollectibleIcon(collectibleId),
                owned = IsCollectibleUnlocked(collectibleId),
            }
        end
    end
    return Utils.SortHouses(houses)
end

---@return TravelWheelCampaign[] campaigns The campaigns the game lists, in its order
function TravelWheelCatalogActions.Campaigns()
    local campaigns = {}
    for _, data in ipairs(CAMPAIGN_BROWSER_MANAGER:GetCampaignDataList()) do
        campaigns[#campaigns + 1] = {
            campaignId = data.id,
            name = data.name,
            imperialCity = data.isImperialCityCampaign == true,
        }
    end
    return campaigns
end

---@return TravelWheelActivity[] activities The battleground queues open to this character's level
function TravelWheelCatalogActions.Battlegrounds()
    local activities = {}
    for _, activityType in ipairs(BattlegroundActivityTypes()) do
        for _, location in ipairs(ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetLocationsData(activityType) or {}) do
            if location:DoesPlayerMeetLevelRequirements() then
                activities[#activities + 1] = {
                    activityType = activityType,
                    activityId = location:GetId(),
                    isSet = location:IsSetEntryType(),
                    name = location:GetNameGamepad(),
                }
            end
        end
    end
    return activities
end

---The game's own finder entry for a saved queue, with its lock state.
---@param activityType integer
---@param activityId integer
---@param isSet boolean
---@return table|nil location
function TravelWheelCatalogActions.FindActivityLocation(activityType, activityId, isSet)
    for _, location in ipairs(ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetLocationsData(activityType) or {}) do
        if location:GetId() == activityId and location:IsSetEntryType() == isSet then
            return location
        end
    end
    return nil
end

function TravelWheelCatalogActions.Initialize()
    local name = TravelWheel.name .. "_Catalog"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_FAST_TRAVEL_NETWORK_UPDATED, function()
        zones = nil
    end)
    -- The campaign list arrives from the server on request; ask once per
    -- session (a queue press asks again when the list is still empty).
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_PLAYER_ACTIVATED)
        QueryCampaignSelectionData()
    end)
end

TravelWheel.CatalogActions = TravelWheelCatalogActions
