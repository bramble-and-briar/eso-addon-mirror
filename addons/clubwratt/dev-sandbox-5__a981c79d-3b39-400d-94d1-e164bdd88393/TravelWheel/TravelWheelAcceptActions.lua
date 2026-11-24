-- TravelWheelAcceptActions.lua: Accepts a queue that is ready, at once or after
-- a wait, by the rule set for its kind: a campaign queue (Cyrodiil, the
-- Imperial City), a battleground or a dungeon finder ready check. The game's
-- own prompt stays up meanwhile, so the player can still accept or decline.

local TravelWheelAcceptActions = {}

local Log = TravelWheel.Log
local Alert = TravelWheel.Alert
local Utils = TravelWheel.AcceptUtils

local READY_CHECK_KEY = "readycheck"
-- Marks a prompt that has been dealt with, until the game takes it away.
local DONE = {}

---Forget a prompt: the game took it away, so the next one starts fresh.
---@param key string
local function Forget(key)
    TravelWheel.state.pendingAccepts[key] = nil
end

---Accept a ready prompt after waitSeconds, once. A prompt already waiting or
---dealt with is left as it is.
---@param key string One per prompt
---@param waitSeconds integer
---@param label string The kind of queue, for the message
---@param stillReady fun(): boolean The prompt is still up and unanswered
---@param accept fun()
local function Schedule(key, waitSeconds, label, stillReady, accept)
    local pending = TravelWheel.state.pendingAccepts
    if pending[key] then
        return
    end
    local token = {}
    pending[key] = token

    local function Fire()
        if pending[key] ~= token then
            return
        end
        pending[key] = DONE
        local ready = stillReady()
        Log(string.format("accept %s after %d s ready=%s", key, waitSeconds, tostring(ready)))
        if ready then
            accept()
        end
    end

    if waitSeconds <= 0 then
        Fire()
    else
        Alert(string.format("%s queue ready, accepting in %d seconds", label, waitSeconds))
        zo_callLater(Fire, waitSeconds * 1000)
    end
end

-- ---------------------------------------------------------------- finder ready check

---@return boolean
local function ReadyCheckStillReady()
    return HasLFGReadyCheckNotification() and not HasAcceptedLFGReadyCheck()
end

local function OnReadyCheckUpdated()
    if not HasLFGReadyCheckNotification() then
        Forget(READY_CHECK_KEY)
        return
    end
    if HasAcceptedLFGReadyCheck() then
        return
    end
    local activityType, _, remainingSeconds = GetLFGReadyCheckNotificationInfo()
    local kind = Utils.ActivityKind(activityType)
    local waitSeconds = kind and Utils.WaitSeconds(TravelWheel.state.savedVars.accept[kind], remainingSeconds)
    Log(string.format("ready check activityType=%s kind=%s remaining=%s wait=%s",
        tostring(activityType), tostring(kind), tostring(remainingSeconds), tostring(waitSeconds)))
    if waitSeconds then
        Schedule(READY_CHECK_KEY, waitSeconds, kind, ReadyCheckStillReady, AcceptLFGReadyCheckNotification)
    end
end

-- ---------------------------------------------------------------- campaign queue

---@param campaignId integer
---@param isGroup boolean
---@param queueState integer CampaignQueueRequestStateType
local function OnCampaignQueueStateChanged(campaignId, isGroup, queueState)
    local key = string.format("campaign:%d:%s", campaignId, isGroup and "group" or "solo")

    if queueState ~= CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
        Forget(key)
        return
    end

    local remainingSeconds = GetCampaignQueueRemainingConfirmationSeconds(campaignId, isGroup)
    local waitSeconds = Utils.WaitSeconds(TravelWheel.state.savedVars.accept.campaign, remainingSeconds)
    Log(string.format("campaign %d group=%s ready remaining=%s wait=%s",
        campaignId, tostring(isGroup), tostring(remainingSeconds), tostring(waitSeconds)))
    if waitSeconds then
        Schedule(key, waitSeconds, "campaign", function()
            return GetCampaignQueueState(campaignId, isGroup) == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING
        end, function()
            ConfirmCampaignEntry(campaignId, isGroup, true)
        end)
    end
end

---Prompts that were already up when the interface loaded.
local function OnPlayerActivated()
    OnReadyCheckUpdated()
    for index = 1, GetNumCampaignQueueEntries() do
        local campaignId, isGroup = GetCampaignQueueEntry(index)
        OnCampaignQueueStateChanged(campaignId, isGroup, GetCampaignQueueState(campaignId, isGroup))
    end
end

function TravelWheelAcceptActions.Initialize()
    local name = TravelWheel.name .. "_Accept"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_GROUPING_TOOLS_READY_CHECK_UPDATED, function() OnReadyCheckUpdated() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_GROUPING_TOOLS_READY_CHECK_CANCELLED, function() Forget(READY_CHECK_KEY) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, function(_, campaignId, isGroup, queueState)
        OnCampaignQueueStateChanged(campaignId, isGroup, queueState)
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function() OnPlayerActivated() end)
end

TravelWheel.AcceptActions = TravelWheelAcceptActions
