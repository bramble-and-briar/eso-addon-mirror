-- TravelWheelReturnActions.lua: Watches arrivals and battleground endings, and
-- makes the trip chosen for after an instance: back into the campaign or the
-- house the player left, or to a saved destination.

local TravelWheelReturnActions = {}

local Log = TravelWheel.Log
local Alert = TravelWheel.Alert
local Utils = TravelWheel.ReturnUtils

-- Travel to a house is the Recall cast (about 8 s). A request that is still
-- pending this long after it was sent had its cast broken, so it is sent again.
local CAST_WATCH_MS = 12000
-- Wait after the game refuses a request (still landing, in combat) before asking again.
local RETRY_MS = 2000
local MAX_WORLD_REQUESTS = 3
-- From the scoreboard there is one try: leaving the battleground is the fallback.
local MAX_SCOREBOARD_REQUESTS = 1
-- A finished match is left this long after it ends: time to see the result.
local LEAVE_DELAY_MS = 2000

---@return TravelWheelLocationFacts
local function ReadLocationFacts()
    return {
        inBattleground = IsActiveWorldBattleground(),
        inAvAWorld = IsPlayerInAvAWorld(),
        campaignId = GetCurrentCampaignId(),
        houseId = GetCurrentZoneHouseId(),
        houseOwner = GetCurrentHouseOwner(),
        -- The game's own test for "leaving the group removes you from here":
        -- dungeons, trials and arenas, but not delves or public dungeons.
        inGroupInstance = IsActiveWorldGroupOwnable(),
    }
end

---@return TravelWheelReturnTarget|nil
local function CurrentTarget()
    local state = TravelWheel.state
    local savedVars = state.savedVars
    local mode = savedVars.afterInstance
    return Utils.ResolveTarget(mode, savedVars.requeueCampaign, state.origin, TravelWheel.TravelActions.Find(mode))
end

---One travel request for the target.
---@param target TravelWheelReturnTarget
---@return "sent"|"wait"|"ended" outcome sent: a travel cast is running; wait: the game does not allow it yet; ended: nothing more to do (a queue was joined, or the player was told why not)
local function Attempt(target)
    if target.kind == "campaign" then
        if not CAMPAIGN_BROWSER_MANAGER:GetDataByCampaignId(target.campaignId) then
            QueryCampaignSelectionData()
            return "wait"
        end
        -- This queue is the way back: it is accepted the moment it is ready.
        local returnCampaigns = TravelWheel.state.returnCampaigns
        returnCampaigns[target.campaignId] = true
        if not TravelWheel.TravelActions.QueueCampaign(target.campaignId) then
            returnCampaigns[target.campaignId] = nil
        end
        return "ended"
    end

    if target.toHouse then
        if not CanJumpToHouseFromCurrentLocation() then
            return "wait"
        end
    elseif not CanLeaveCurrentLocationViaTeleport() then
        return "wait"
    end

    if target.kind == "house" then
        if target.owner == "" or target.owner == GetDisplayName() then
            RequestJumpToHouse(target.houseId, false)
        else
            JumpToSpecificHouse(target.owner, target.houseId, false)
        end
        return "sent"
    end
    return TravelWheel.TravelActions.Go(target.id) and "sent" or "ended"
end

---Leave a battleground whose match is over: what the scoreboard's own Leave
---button does. The game then puts the player back where he was.
---@param reason string
local function LeaveFinishedBattleground(reason)
    local finished = IsActiveWorldBattleground() and GetCurrentBattlegroundState() == BATTLEGROUND_STATE_FINISHED
    Log(string.format("leave battleground (%s) finished=%s", reason, tostring(finished)))
    if finished then
        LeaveBattleground()
    end
end

local RequestReturn

---Run RequestReturn after delayMs, unless the trip ended or another
---follow-up was scheduled in the meantime.
---@param pending TravelWheelPendingReturn
---@param delayMs integer
local function ScheduleRequest(pending, delayMs)
    pending.seq = pending.seq + 1
    local seq = pending.seq
    zo_callLater(function()
        if TravelWheel.state.pendingReturn == pending and pending.seq == seq then
            RequestReturn()
        end
    end, delayMs)
end

RequestReturn = function()
    local state = TravelWheel.state
    local pending = state.pendingReturn
    if not pending then
        return
    end

    if pending.requests >= pending.maxRequests then
        Log(string.format("return gave up after %d requests", pending.requests))
        state.pendingReturn = nil
        if pending.announce then
            Alert(string.format("could not travel to %s", pending.target.name))
        end
        if pending.fromScoreboard then
            LeaveFinishedBattleground("the scoreboard trip did not leave")
        end
        return
    end

    pending.requests = pending.requests + 1
    local outcome = Attempt(pending.target)
    Log(string.format("return request %d/%d target=%s outcome=%s combat=%s moving=%s",
        pending.requests, pending.maxRequests, pending.target.name, outcome,
        tostring(IsUnitInCombat("player")), tostring(IsPlayerMoving())))

    if outcome == "sent" then
        ScheduleRequest(pending, CAST_WATCH_MS)
    elseif outcome == "wait" then
        ScheduleRequest(pending, RETRY_MS)
    else
        state.pendingReturn = nil
    end
end

---@param target TravelWheelReturnTarget
---@param reason string
---@param maxRequests integer
---@param announce boolean Say so on screen when the trip is given up
---@param message string What the player is told as the trip starts
---@param fromScoreboard boolean Asked for inside a finished battleground: given up, the battleground is left instead
local function StartReturn(target, reason, maxRequests, announce, message, fromScoreboard)
    Log(string.format("return start (%s) target=%s", reason, target.name))
    TravelWheel.state.pendingReturn = {
        target = target,
        requests = 0,
        maxRequests = maxRequests,
        announce = announce,
        fromScoreboard = fromScoreboard,
        seq = 0,
    }
    Alert(message)
    RequestReturn()
end

---@param initial boolean
local function OnPlayerActivated(initial)
    local state = TravelWheel.state
    state.pendingReturn = nil

    local facts = ReadLocationFacts()
    local location = Utils.ClassifyLocation(facts)
    local wasArmed = state.armed
    local armed, makeTrip = Utils.DecideArrival(wasArmed, location)
    -- The target is read before the origin moves on to this landing.
    local target = makeTrip and CurrentTarget() or nil
    state.armed = armed
    state.origin = Utils.NextOrigin(location, facts, state.origin, state.lastPlace)
    state.lastPlace = { location = location, campaignId = facts.inAvAWorld and facts.campaignId or 0 }

    Log(string.format(
        "arrived location=%s (bg=%s ava=%s campaign=%d house=%d owner=%s groupInstance=%s dungeon=%s difficulty=%s zone=%d) initial=%s armed %s->%s mode=%s origin=%s target=%s",
        location, tostring(facts.inBattleground), tostring(facts.inAvAWorld), facts.campaignId, facts.houseId, tostring(facts.houseOwner),
        tostring(facts.inGroupInstance), tostring(IsUnitInDungeon("player")), tostring(GetCurrentZoneDungeonDifficulty()),
        GetZoneId(GetUnitZoneIndex("player")), tostring(initial), tostring(wasArmed), tostring(armed),
        tostring(state.savedVars.afterInstance), state.origin and state.origin.kind or "none", target and target.name or "none"))

    if target then
        StartReturn(target, "left an instance", MAX_WORLD_REQUESTS, true, string.format("back to %s", target.name), false)
    end
end

local function OnPlayerDeactivated()
    local state = TravelWheel.state
    if state.pendingReturn then
        Log("leaving the zone with a return pending")
        state.pendingReturn = nil
    end
end

---@param reason integer JumpResult
local function OnJumpFailed(reason)
    local pending = TravelWheel.state.pendingReturn
    if not pending then
        return
    end
    Log(string.format("return: jump failed reason=%s", tostring(reason)))
    -- A request sent while the last cast still runs: that cast goes on.
    if reason ~= JUMP_RESULT_JUMP_FAILED_ALREADY_JUMPING then
        ScheduleRequest(pending, RETRY_MS)
    end
end

---A finished match keeps the player on its scoreboard until he leaves. With
---the setting on, the addon leaves for him: straight to a house where the
---trip goes to one and the game allows travel from the battleground (the
---cast runs under the scoreboard), otherwise out of the battleground, where
---the main world landing makes the trip or the requeue.
---@param previousState integer BattlegroundState
---@param currentState integer BattlegroundState
local function OnBattlegroundStateChanged(previousState, currentState)
    local savedVars = TravelWheel.state.savedVars
    local canJump = CanJumpToHouseFromCurrentLocation()
    local target = CurrentTarget()
    Log(string.format("battleground state %s->%s leave=%s canJump=%s target=%s", tostring(previousState), tostring(currentState),
        tostring(savedVars.fromScoreboard), tostring(canJump), target and target.name or "none"))
    if currentState ~= BATTLEGROUND_STATE_FINISHED or not savedVars.fromScoreboard then
        return
    end
    if target and target.toHouse and canJump then
        StartReturn(target, "battleground finished", MAX_SCOREBOARD_REQUESTS, false,
            string.format("match over, travelling to %s", target.name), true)
        return
    end
    Alert("match over, leaving the battleground")
    zo_callLater(function()
        LeaveFinishedBattleground("match over")
    end, LEAVE_DELAY_MS)
end

function TravelWheelReturnActions.Initialize()
    local name = TravelWheel.name .. "_Return"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function(_, initial) OnPlayerActivated(initial) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_DEACTIVATED, function() OnPlayerDeactivated() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_JUMP_FAILED, function(_, reason) OnJumpFailed(reason) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_BATTLEGROUND_STATE_CHANGED, function(_, previousState, currentState)
        OnBattlegroundStateChanged(previousState, currentState)
    end)
end

TravelWheel.ReturnActions = TravelWheelReturnActions
