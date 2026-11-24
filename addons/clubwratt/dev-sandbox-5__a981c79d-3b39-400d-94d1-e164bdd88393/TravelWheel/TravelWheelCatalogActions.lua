-- TravelWheelCatalogActions.lua: Reads what the game offers to travel to:
-- wayshrines by zone, houses, House Tours favorites, campaigns and
-- battleground queues.

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

---@return TravelWheelHouse[] houses The houses the player owns, by name
function TravelWheelCatalogActions.Houses()
    local houses = {}
    for index = 1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_HOUSE) do
        local collectibleId = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_HOUSE, index)
        local name = Utils.CleanName(GetCollectibleName(collectibleId))
        local houseId = GetCollectibleReferenceId(collectibleId)
        if name ~= "" and houseId ~= 0 and IsCollectibleUnlocked(collectibleId) then
            houses[#houses + 1] = {
                houseId = houseId,
                name = name,
                icon = GetCollectibleIcon(collectibleId),
            }
        end
    end
    return Utils.SortByName(houses)
end

-- ---------------------------------------------------------------- House Tours favorites
--
-- The favorites arrive from the server when a search is run. The game's
-- search manager runs it (filters, cooldown), and holds a state per list;
-- the listings themselves are read from the game, which keeps the last
-- answer whatever state the manager is left in.

---@type fun()[] Called when House Tours has answered or begun a favorites search
local favoriteListeners = {}

---@return "unavailable"|"asking"|"ready" status Whether the favorites can be read now
function TravelWheelCatalogActions.FavoritesStatus()
    if GetHouseToursStatus() ~= HOUSE_TOURS_STATUS_READY then
        return "unavailable"
    end
    local state = HOUSE_TOURS_SEARCH_MANAGER:GetSearchState(HOUSE_TOURS_LISTING_TYPE_FAVORITE)
    if state == ZO_HOUSE_TOURS_SEARCH_STATES.QUEUED or state == ZO_HOUSE_TOURS_SEARCH_STATES.WAITING then
        return "asking"
    end
    return "ready"
end

---@return TravelWheelHouse[] houses Other players' houses favorited in House Tours, by name; empty until the list has arrived
function TravelWheelCatalogActions.FavoriteHouses()
    local houses = {}
    for index = 1, GetNumHouseToursSearchListings(HOUSE_TOURS_LISTING_TYPE_FAVORITE) do
        local listing = ZO_HouseToursListingSearchData:New(HOUSE_TOURS_LISTING_TYPE_FAVORITE, index)
        local houseId = listing:GetHouseId()
        local owner = listing:GetOwnerDisplayName()
        local name = Utils.CleanName(listing:GetHouseName())
        if houseId ~= 0 and owner ~= "" and name ~= "" then
            local ownerName = ZO_FormatUserFacingDisplayName(owner)
            local tags = listing:GetTags()
            houses[#houses + 1] = {
                houseId = houseId,
                name = string.format("%s (%s)", name, ownerName),
                icon = listing:GetCollectibleIcon() or "",
                owner = owner,
                ownerName = ownerName,
                nickname = listing:GetNickname() or "",
                tags = #tags > 0 and listing:GetFormattedTagsText() or "",
                furnitureCount = listing:GetFurnitureCount(),
            }
        end
    end
    return Utils.SortByName(houses)
end

---@param what string
local function LogFavorites(what)
    TravelWheel.Log(string.format("house tours favorites: %s status=%s state=%s cooldown=%s listings=%d kept=%d", what,
        tostring(GetHouseToursStatus()), tostring(HOUSE_TOURS_SEARCH_MANAGER:GetSearchState(HOUSE_TOURS_LISTING_TYPE_FAVORITE)),
        tostring(IsHouseToursSearchOnCooldown()), GetNumHouseToursSearchListings(HOUSE_TOURS_LISTING_TYPE_FAVORITE),
        #TravelWheelCatalogActions.FavoriteHouses()))
end

---Ask the server for the player's House Tours favorites, through the game's
---search manager. Nothing is sent while House Tours is not up (its status
---event asks again) or while a search waits out the cooldown (the manager
---sends that one itself).
---@param reason string For the log
---@param evenWhileWaiting boolean|nil Ask although an earlier search has not been answered: the player is looking at an empty list, and that answer may never come
function TravelWheelCatalogActions.RequestFavoriteHouses(reason, evenWhileWaiting)
    local state = HOUSE_TOURS_SEARCH_MANAGER:GetSearchState(HOUSE_TOURS_LISTING_TYPE_FAVORITE)
    local send = GetHouseToursStatus() == HOUSE_TOURS_STATUS_READY
        and state ~= ZO_HOUSE_TOURS_SEARCH_STATES.QUEUED
        and (state ~= ZO_HOUSE_TOURS_SEARCH_STATES.WAITING or evenWhileWaiting == true)
    LogFavorites(string.format("request (%s) send=%s", reason, tostring(send)))
    if send then
        HOUSE_TOURS_SEARCH_MANAGER:ExecuteSearch(HOUSE_TOURS_LISTING_TYPE_FAVORITE)
    end
end

---@param listener fun() Called when House Tours has answered or begun a favorites search: the list may have changed
function TravelWheelCatalogActions.OnFavorites(listener)
    favoriteListeners[#favoriteListeners + 1] = listener
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

---The battleground queues the Activity Finder lists for this character, in
---the finder's order: its sets (a set is a queue, such as a solo or a group
---one; a single arena is not offered), the ones the game has switched on
---(`IsActive`), at this character's level. The lock on each is the game's
---own, kept current by the finder: a solo queue in a group, a cooldown.
---@return TravelWheelQueue[] queues
function TravelWheelCatalogActions.Battlegrounds()
    local queues = {}
    for _, activityType in ipairs(BattlegroundActivityTypes()) do
        for _, location in ipairs(ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetLocationsData(activityType) or {}) do
            if location:IsSetEntryType() and location:IsActive() and location:DoesPlayerMeetLevelRequirements() then
                queues[#queues + 1] = {
                    setId = location:GetId(),
                    name = Utils.CleanName(location:GetRawName()),
                    gameTypes = location:GetSetTypesListText() or "",
                    locked = location:IsLocked() == true,
                    lockReason = tostring(location:GetLockReasonText() or ""),
                }
            end
        end
    end
    return queues
end

---Everything the finder holds under battlegrounds, for the log: what it
---offers and what this addon left out, when the two lists disagree in game.
---@return string[] lines
function TravelWheelCatalogActions.DescribeBattlegroundFinder()
    local lines = {}
    for _, activityType in ipairs(BattlegroundActivityTypes()) do
        local sets, arenas = {}, 0
        for _, location in ipairs(ZO_ACTIVITY_FINDER_ROOT_MANAGER:GetLocationsData(activityType) or {}) do
            if location:IsSetEntryType() then
                sets[#sets + 1] = string.format("%d %s active=%s level=%s locked=%s", location:GetId(), tostring(location:GetRawName()),
                    tostring(location:IsActive()), tostring(location:DoesPlayerMeetLevelRequirements()), tostring(location:IsLocked()))
            else
                arenas = arenas + 1
            end
        end
        lines[#lines + 1] = string.format("battleground finder type=%d arenas=%d sets: %s", activityType, arenas, table.concat(sets, " | "))
    end
    return lines
end

function TravelWheelCatalogActions.Initialize()
    local name = TravelWheel.name .. "_Catalog"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_FAST_TRAVEL_NETWORK_UPDATED, function()
        zones = nil
    end)
    -- The campaign list arrives from the server on request; ask once per
    -- session (a queue press asks again when the list is still empty).
    -- So does the list of House Tours favorites, and again when it changes.
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_PLAYER_ACTIVATED)
        QueryCampaignSelectionData()
        TravelWheelCatalogActions.RequestFavoriteHouses("entered the world")
    end)
    HOUSE_TOURS_SEARCH_MANAGER:RegisterCallback("OnFavoritesChanged", function()
        TravelWheelCatalogActions.RequestFavoriteHouses("favorites changed")
    end)
    -- House Tours came up after the world loaded: nothing was sent before.
    EVENT_MANAGER:RegisterForEvent(name, EVENT_HOUSE_TOURS_STATUS_UPDATED, function()
        if #TravelWheelCatalogActions.FavoriteHouses() == 0 then
            TravelWheelCatalogActions.RequestFavoriteHouses("house tours status")
        end
    end)
    HOUSE_TOURS_SEARCH_MANAGER:RegisterCallback("OnSearchStateChanged", function(_, listingType)
        if listingType == HOUSE_TOURS_LISTING_TYPE_FAVORITE then
            LogFavorites("search state")
            for _, listener in ipairs(favoriteListeners) do
                listener()
            end
        end
    end)
end

TravelWheel.CatalogActions = TravelWheelCatalogActions
