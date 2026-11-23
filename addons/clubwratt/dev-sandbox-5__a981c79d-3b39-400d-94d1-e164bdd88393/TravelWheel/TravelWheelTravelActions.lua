-- TravelWheelTravelActions.lua: Makes the trip a destination names: a
-- wayshrine, a house, a campaign queue or a battleground queue.

local TravelWheelTravelActions = {}

local Log = TravelWheel.Log
local Alert = TravelWheel.Alert
local Utils = TravelWheel.TravelUtils
local Catalog = TravelWheel.CatalogActions

---@param id string
---@return TravelWheelDestination|nil
local function FindDestination(id)
    for _, destination in ipairs(TravelWheel.state.savedVars.destinations) do
        if destination.id == id then
            return destination
        end
    end
    return nil
end

-- ---------------------------------------------------------------- wayshrine

---Pay the recall fee and travel to the exact node.
---@param destination TravelWheelDestination
---@return boolean sent
local function GoNode(destination)
    local known = GetFastTravelNodeInfo(destination.nodeIndex)
    local cost = GetRecallCost(destination.nodeIndex)
    local blocked = Utils.NodeBlock({
        dead = IsUnitDead("player"),
        canLeave = CanLeaveCurrentLocationViaTeleport(),
        known = known,
        cost = cost,
        gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER),
    })
    Log(string.format("node %d known=%s cost=%d blocked=%s", destination.nodeIndex, tostring(known), cost, tostring(blocked)))
    if blocked then
        Alert(string.format("%s: %s", destination.name, blocked))
        return false
    end
    Alert(string.format("%s for %d gold", destination.name, cost))
    FastTravelToNode(destination.nodeIndex)
    return true
end

-- ---------------------------------------------------------------- house

---@param destination TravelWheelDestination
---@return boolean sent
local function GoHouse(destination)
    local houseId = destination.houseId
    if houseId == 0 then
        houseId = GetHousingPrimaryHouse()
        if houseId == 0 then
            Alert("no primary residence is set")
            return false
        end
    end
    if not CanJumpToHouseFromCurrentLocation() then
        Alert(string.format("%s: you cannot travel to a house from here", destination.name))
        return false
    end
    -- An unowned house is entered as a preview, which has no front door.
    local owned = IsCollectibleUnlocked(GetCollectibleIdForHouse(houseId))
    local outside = destination.outside == true and owned
    Log(string.format("house %d owned=%s outside=%s", houseId, tostring(owned), tostring(outside)))
    RequestJumpToHouse(houseId, outside)
    return true
end

-- ---------------------------------------------------------------- campaign

---Join a campaign's queue through the game's own flow, or enter when its
---queue has already popped.
---@param campaignId integer
---@return boolean sent
local function QueueCampaign(campaignId)
    local data = CAMPAIGN_BROWSER_MANAGER:GetDataByCampaignId(campaignId)
    if not data then
        QueryCampaignSelectionData()
        Alert("the campaign list has not loaded yet, try again in a moment")
        return false
    end
    if GetCurrentCampaignId() == campaignId then
        Alert(string.format("you are in %s", data.name))
        return false
    end

    for _, isGroup in ipairs({ false, true }) do
        if IsQueuedForCampaign(campaignId, isGroup) then
            local queueState = GetCampaignQueueState(campaignId, isGroup)
            Log(string.format("campaign %d already queued group=%s state=%s", campaignId, tostring(isGroup), tostring(queueState)))
            if queueState == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
                ConfirmCampaignEntry(campaignId, isGroup, true)
                return true
            end
            Alert(string.format("already in the queue for %s", data.name))
            return false
        end
    end

    if not CAMPAIGN_BROWSER_MANAGER:CanQueueForCampaign(data) then
        Alert(string.format("you cannot queue for %s from here", data.name))
        return false
    end
    Log(string.format("campaign %d queue", campaignId))
    -- The game's own flow: the Imperial City check, the alliance lock
    -- warning, and solo or group when grouped.
    CAMPAIGN_BROWSER_MANAGER:DoQueueForCampaign(data)
    return true
end

---@param destination TravelWheelDestination
---@return boolean sent
local function GoCampaign(destination)
    local campaignId = destination.campaignId
    if campaignId == 0 then
        campaignId = GetAssignedCampaignId()
        if campaignId == 0 then
            Alert("no home campaign is set")
            return false
        end
    end
    return QueueCampaign(campaignId)
end

-- ---------------------------------------------------------------- battleground

---@param destination TravelWheelDestination
---@return boolean sent
local function GoActivity(destination)
    local location = Catalog.FindActivityLocation(destination.activityType, destination.activityId, destination.isSet == true)
    if not location then
        Alert(string.format("%s is not offered to this character", destination.name))
        return false
    end
    if IsCurrentlySearchingForGroup() then
        Alert("already in a queue")
        return false
    end
    if location:IsLocked() then
        Alert(string.format("%s: %s", destination.name, tostring(location:GetLockReasonText() or "locked")))
        return false
    end
    Log(string.format("activity type=%d id=%d queue", destination.activityType, destination.activityId))
    -- The game's own finder: select this one entry and search, so its
    -- cooldown and group checks apply and its alerts say why a queue failed.
    local finder = ZO_ACTIVITY_FINDER_ROOT_MANAGER
    finder:ClearSelections()
    finder:SetLocationSelected(location, true)
    finder:StartSearch()
    if IsCurrentlySearchingForGroup() then
        Alert(string.format("in the queue for %s", location:GetNameGamepad()))
    end
    return true
end

-- ---------------------------------------------------------------- entry

local GO_BY_KIND = {
    node = GoNode,
    house = GoHouse,
    campaign = GoCampaign,
    activity = GoActivity,
}

---Make the trip of one saved destination: what a wheel entry does.
---@param id string
---@return boolean sent A travel or queue request went out; when none did, the player was told why
function TravelWheelTravelActions.Go(id)
    local destination = FindDestination(id)
    if not destination then
        Alert("that destination was removed")
        return false
    end
    Log(string.format("go %s kind=%s name=%s", id, destination.kind, destination.name))
    return GO_BY_KIND[destination.kind](destination)
end

---@param id string
---@return TravelWheelDestination|nil
function TravelWheelTravelActions.Find(id)
    return FindDestination(id)
end

---Join the queue of a campaign by its id: the requeue after an instance.
---@param campaignId integer
---@return boolean sent
function TravelWheelTravelActions.QueueCampaign(campaignId)
    Log(string.format("queue campaign %d", campaignId))
    return QueueCampaign(campaignId)
end

TravelWheel.TravelActions = TravelWheelTravelActions
