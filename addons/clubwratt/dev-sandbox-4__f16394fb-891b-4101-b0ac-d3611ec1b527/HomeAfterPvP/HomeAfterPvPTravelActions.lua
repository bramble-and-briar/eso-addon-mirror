-- HomeAfterPvPTravelActions.lua: Watches arrivals and battleground endings, and
-- makes the trip to the primary residence.

local HomeAfterPvPTravelActions = {}

local Log = HomeAfterPvP.Log
local Utils = HomeAfterPvP.TravelUtils

local TRAVEL_INSIDE = false

-- Travel to a house is the Recall cast (about 8 s). A request that is still
-- pending this long after it was sent had its cast broken, so it is sent again.
local CAST_WATCH_MS = 12000
-- Wait after the game refuses a request (still landing, in combat) before asking again.
local RETRY_MS = 2000
local MAX_WORLD_REQUESTS = 3
-- From the scoreboard there is one try: landing in the main world is the fallback.
local MAX_SCOREBOARD_REQUESTS = 1

---@param message string
local function Alert(message)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Home After PvP: " .. message)
end

---@return HomeAfterPvPLocationFacts
local function ReadLocationFacts()
    return {
        inBattleground = IsActiveWorldBattleground(),
        inAvAWorld = IsPlayerInAvAWorld(),
        houseId = GetCurrentZoneHouseId(),
        inDungeon = IsUnitInDungeon("player"),
    }
end

local RequestTravel

---Run RequestTravel after delayMs, unless the trip ended or another follow-up
---was scheduled in the meantime.
---@param pending HomeAfterPvPPendingTrip
---@param delayMs integer
local function ScheduleRequest(pending, delayMs)
    pending.seq = pending.seq + 1
    local seq = pending.seq
    zo_callLater(function()
        if HomeAfterPvP.state.pending == pending and pending.seq == seq then
            RequestTravel()
        end
    end, delayMs)
end

RequestTravel = function()
    local state = HomeAfterPvP.state
    local pending = state.pending
    if not pending then
        return
    end

    if pending.requests >= pending.maxRequests then
        Log(string.format("gave up after %d requests", pending.requests))
        state.pending = nil
        if pending.announce then
            Alert("could not travel home")
        end
        return
    end

    pending.requests = pending.requests + 1
    local canJump = CanJumpToHouseFromCurrentLocation()
    Log(string.format("request %d/%d house=%d canJump=%s combat=%s moving=%s",
        pending.requests, pending.maxRequests, pending.houseId, tostring(canJump),
        tostring(IsUnitInCombat("player")), tostring(IsPlayerMoving())))

    if canJump then
        RequestJumpToHouse(pending.houseId, TRAVEL_INSIDE)
        ScheduleRequest(pending, CAST_WATCH_MS)
    else
        ScheduleRequest(pending, RETRY_MS)
    end
end

---Begin the trip to the primary residence.
---@param reason string
---@param maxRequests integer
---@param announce boolean
function HomeAfterPvPTravelActions.StartTrip(reason, maxRequests, announce)
    local houseId = GetHousingPrimaryHouse()
    Log(string.format("trip start (%s) primaryHouse=%d", reason, houseId))
    if houseId == 0 then
        if announce then
            Alert("no primary residence is set")
        end
        return
    end

    HomeAfterPvP.state.pending = {
        houseId = houseId,
        requests = 0,
        maxRequests = maxRequests,
        announce = announce,
        seq = 0,
    }
    if announce then
        Alert("travelling home")
    end
    RequestTravel()
end

function HomeAfterPvPTravelActions.TravelNow()
    HomeAfterPvPTravelActions.StartTrip("settings button", MAX_WORLD_REQUESTS, true)
end

---@param initial boolean
local function OnPlayerActivated(initial)
    local state = HomeAfterPvP.state
    state.pending = nil

    local facts = ReadLocationFacts()
    local location = Utils.ClassifyLocation(facts)
    local wasArmed = state.armed
    local armed, travelHome = Utils.DecideArrival(wasArmed, location)
    state.armed = armed

    Log(string.format(
        "arrived location=%s (bg=%s ava=%s house=%d dungeon=%s zone=%d) initial=%s armed %s->%s travelHome=%s enabled=%s",
        location, tostring(facts.inBattleground), tostring(facts.inAvAWorld), facts.houseId,
        tostring(facts.inDungeon), GetZoneId(GetUnitZoneIndex("player")), tostring(initial),
        tostring(wasArmed), tostring(armed), tostring(travelHome), tostring(state.savedVars.enabled)))

    if travelHome and state.savedVars.enabled then
        HomeAfterPvPTravelActions.StartTrip("returned from PvP", MAX_WORLD_REQUESTS, true)
    end
end

local function OnPlayerDeactivated()
    local state = HomeAfterPvP.state
    if state.pending then
        Log("leaving the zone with a trip pending")
        state.pending = nil
    end
end

---@param reason integer JumpResult
local function OnJumpFailed(reason)
    local pending = HomeAfterPvP.state.pending
    Log(string.format("jump failed reason=%s (%s) pending=%s",
        tostring(reason), GetString("SI_JUMPRESULT", reason), tostring(pending ~= nil)))
    if pending then
        ScheduleRequest(pending, RETRY_MS)
    end
end

---@param previousState integer BattlegroundState
---@param currentState integer BattlegroundState
local function OnBattlegroundStateChanged(previousState, currentState)
    local savedVars = HomeAfterPvP.state.savedVars
    local canJump = CanJumpToHouseFromCurrentLocation()
    Log(string.format("battleground state %s->%s canJump=%s",
        tostring(previousState), tostring(currentState), tostring(canJump)))

    if currentState == BATTLEGROUND_STATE_FINISHED and savedVars.enabled and savedVars.fromScoreboard and canJump then
        HomeAfterPvPTravelActions.StartTrip("battleground finished", MAX_SCOREBOARD_REQUESTS, false)
    end
end

---@param errorText string
local function OnLuaError(errorText)
    Log("lua error: " .. string.sub(tostring(errorText), 1, 900))
end

function HomeAfterPvPTravelActions.Initialize()
    local name = HomeAfterPvP.name
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function(_, initial) OnPlayerActivated(initial) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_DEACTIVATED, function() OnPlayerDeactivated() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_JUMP_FAILED, function(_, reason) OnJumpFailed(reason) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_BATTLEGROUND_STATE_CHANGED, function(_, previousState, currentState)
        OnBattlegroundStateChanged(previousState, currentState)
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_LUA_ERROR, function(_, errorText) OnLuaError(errorText) end)
end

HomeAfterPvP.TravelActions = HomeAfterPvPTravelActions
