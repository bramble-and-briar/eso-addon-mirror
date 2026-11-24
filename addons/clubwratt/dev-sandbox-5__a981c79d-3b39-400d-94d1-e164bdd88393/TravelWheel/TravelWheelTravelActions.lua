-- TravelWheelTravelActions.lua: Makes the trip a destination names: a
-- wayshrine, a house, a campaign queue, a battleground queue or the game's
-- Get Me Unstuck.

local TravelWheelTravelActions = {}

local Log = TravelWheel.Log
local Alert = TravelWheel.Alert
local Utils = TravelWheel.TravelUtils
local CatalogUtils = TravelWheel.CatalogUtils
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
    if destination.owner and destination.owner ~= GetDisplayName() then
        -- Another player's house, favorited in House Tours: visited the way
        -- House Tours visits it, which is inside.
        local FROM_HOUSE_TOURS = true
        Log(string.format("house %d of %s", houseId, destination.owner))
        JumpToSpecificHouse(destination.owner, houseId, FROM_HOUSE_TOURS)
        return true
    end
    -- The player's own house. One not owned would open as a preview, which
    -- this addon does not travel to: an entry saved for one says so.
    local owned = IsCollectibleUnlocked(GetCollectibleIdForHouse(houseId))
    local outside = destination.outside == true
    Log(string.format("house %d owned=%s outside=%s", houseId, tostring(owned), tostring(outside)))
    if not owned then
        Alert(string.format("%s: you do not own this house", destination.name))
        return false
    end
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

---The Activity Finder queues the player is in now, by name, as the finder
---itself reads them: a queue by its set, a single activity by its own id.
---@return string names "A, B"; "" when the game names none
local function FinderQueueNames()
    local names = {}
    for index = 1, GetNumActivityRequests() do
        local activityId, setId = GetActivityRequestIds(index)
        local rawName = setId ~= 0 and GetActivitySetInfo(setId) or GetActivityName(activityId)
        local name = CatalogUtils.CleanName(rawName)
        if name ~= "" then
            names[#names + 1] = name
        end
    end
    return table.concat(names, ", ")
end

---Join the battleground queues ticked for the entry, the way the Activity
---Finder does when several are ticked there: one search holding each of them.
---The finder runs one search at a time, so a press during one says which
---queues it holds. Only this kind of entry is held back by it: a campaign
---queue and every trip are separate from the finder.
---@param destination TravelWheelDestination
---@return boolean sent
local function GoActivity(destination)
    if IsCurrentlySearchingForGroup() then
        local names = FinderQueueNames()
        Log(string.format("battleground queue: the finder is searching requests=%d for=[%s]", GetNumActivityRequests(), names))
        Alert(names ~= "" and ("already queued for " .. names) or "already in an Activity Finder queue")
        return false
    end
    local queues = Catalog.Battlegrounds()
    local join, reason = Utils.QueuesToJoin(queues, destination.queues or {})
    if #join == 0 then
        Log(string.format("battleground queue: nothing to join offered=%d reason=%s", #queues, tostring(reason)))
        for _, line in ipairs(Catalog.DescribeBattlegroundFinder()) do
            Log(line)
        end
        Alert(string.format("%s: %s", destination.name, reason))
        return false
    end
    -- The finder's own three steps (ZO_ACTIVITY_FINDER_ROOT_MANAGER:StartSearch),
    -- made here so the result is in hand for the log.
    ClearActivityFinderSearch()
    for _, queue in ipairs(join) do
        AddActivityFinderSetSearchEntry(queue.setId)
    end
    local result = StartActivityFinderSearch()
    Log(string.format("battleground queue: offered=%d join=[%s] result=%s", #queues, Utils.QueueNames(join), tostring(result)))
    if result ~= ACTIVITY_QUEUE_RESULT_SUCCESS then
        -- The game's own words for why, as its finder shows them.
        ZO_AlertEvent(EVENT_ACTIVITY_QUEUE_RESULT, result)
        return false
    end
    Alert("queueing for " .. Utils.QueueNames(join))
    return true
end

-- ---------------------------------------------------------------- get me unstuck

-- The Help menu's own prompts for Get Me Unstuck, under the names the game
-- registers them by (help_root_gamepad.lua).
local UNSTUCK_CONFIRM_DIALOG = "GAMEPAD_UNSTUCK_CONFIRM_DIALOG"
local UNSTUCK_COOLDOWN_DIALOG = "GAMEPAD_UNSTUCK_COOLDOWN_DIALOG"

---Open the game's own Get Me Unstuck prompt, the one the Help menu opens.
---The player confirms there and the game does the rest: an addon may not
---send the unstuck request itself (SendPlayerStuck is private).
---@param destination TravelWheelDestination
---@return boolean sent The prompt was opened
local function GoUnstuck(destination)
    if IsStuckFixPending() then
        Alert("the game is already getting you unstuck")
        return false
    end
    -- As the Help menu picks: the countdown while unstuck is on cooldown,
    -- which opens the confirm prompt itself when it runs out; else the
    -- confirm prompt.
    local cooldownMs = GetTimeUntilStuckAvailable()
    local dialogName = cooldownMs > 0 and UNSTUCK_COOLDOWN_DIALOG or UNSTUCK_CONFIRM_DIALOG
    Log(string.format("unstuck: opening %s cooldownMs=%d", dialogName, cooldownMs))
    TravelWheel.state.unstuckAsked = true
    ZO_Dialogs_ShowGamepadDialog(dialogName)
    return true
end

---The game raised a Lua error. After the prompt was opened from here, an
---error from the game's unstuck code means the game refused the request
---because an addon opened the prompt: close it and say so.
---@param errorText string
function TravelWheelTravelActions.OnLuaError(errorText)
    local state = TravelWheel.state
    if not state.unstuckAsked then
        return
    end
    local PLAIN = true
    if not (string.find(errorText, "SendPlayerStuck", 1, PLAIN) or string.find(errorText, "help_root_gamepad", 1, PLAIN)) then
        return
    end
    state.unstuckAsked = false
    ZO_Dialogs_ReleaseDialog(UNSTUCK_CONFIRM_DIALOG)
    Alert("the game refused Get Me Unstuck from the wheel: use Help, Get Me Unstuck")
end

-- ---------------------------------------------------------------- entry

local GO_BY_KIND = {
    node = GoNode,
    house = GoHouse,
    campaign = GoCampaign,
    activity = GoActivity,
    unstuck = GoUnstuck,
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

function TravelWheelTravelActions.Initialize()
    -- What the server answered to a queue request, whoever made it: the log
    -- shows why a battleground queue did not start.
    EVENT_MANAGER:RegisterForEvent(TravelWheel.name .. "_Travel", EVENT_ACTIVITY_QUEUE_RESULT, function(_, result)
        Log(string.format("activity queue result=%s %s", tostring(result), tostring(GetString("SI_ACTIVITYQUEUERESULT", result))))
    end)
    EVENT_MANAGER:RegisterForEvent(TravelWheel.name .. "_Travel", EVENT_STUCK_BEGIN, function()
        Log(string.format("unstuck: the game began it, asked from the wheel=%s", tostring(TravelWheel.state.unstuckAsked)))
        TravelWheel.state.unstuckAsked = false
    end)
end

TravelWheel.TravelActions = TravelWheelTravelActions
