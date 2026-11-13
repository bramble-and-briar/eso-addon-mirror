-- KDStatTracker_Events.lua
-- Game event wiring. Kills come from our own killing blows, deaths from
-- EVENT_PLAYER_DEAD (reliable) joined with the most recent killing blow or hit
-- we took so we know who / what did it.

local KDST = KDStatTracker
local EM = EVENT_MANAGER
local NS = KDST.name

local recentKills = {}      -- [targetUnitId] = ms, for de-duping repeated killing blows
local lastKillingBlow       -- { abilityId, abilityName, killer, ms }
local lastHit               -- same shape, any damage taken from another unit

local function NowMs() return GetGameTimeMilliseconds() end

-------------------------------------------------------------------------------
-- Kills
-------------------------------------------------------------------------------
local function OnOutgoingKillingBlow(_, result, isError, abilityName, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, sourceUnitId, targetUnitId, abilityId)
    if isError or targetType == COMBAT_UNIT_TYPE_PLAYER then return end
    if not KDST.ShouldTrack() then return end
    if KDST.settings.playersOnly and not IsActiveWorldBattleground() and not KDST.LooksLikePlayer(targetName) then
        return
    end

    local now = NowMs()
    if targetUnitId and targetUnitId ~= 0 then
        local last = recentKills[targetUnitId]
        if last and now - last < KDST.KILL_DEDUPE_MS then return end
        recentKills[targetUnitId] = now
    end

    KDST.RecordKill(abilityId, KDST.AbilityName(abilityId, abilityName), KDST.CleanName(targetName))
end

-------------------------------------------------------------------------------
-- Deaths
-------------------------------------------------------------------------------
local function Snapshot(abilityId, abilityName, sourceName)
    return {
        abilityId   = abilityId or 0,
        abilityName = KDST.AbilityName(abilityId, abilityName),
        killer      = KDST.CleanName(sourceName),
        isPlayer    = KDST.LooksLikePlayer(sourceName),
        ms          = NowMs(),
    }
end

local function OnIncomingKillingBlow(_, _, isError, abilityName, _, _, sourceName, sourceType, _, _, _, _, _, _, _, _, abilityId)
    if isError then return end
    lastKillingBlow = Snapshot(abilityId, abilityName, sourceName)
end

local function OnIncomingDamage(_, _, isError, abilityName, _, _, sourceName, sourceType, _, _, hitValue, _, _, _, _, _, abilityId)
    if isError or sourceType == COMBAT_UNIT_TYPE_PLAYER or (hitValue or 0) <= 0 then return end
    if not sourceName or sourceName == "" then return end
    lastHit = Snapshot(abilityId, abilityName, sourceName)
end

local function ResolveDeathSource()
    local now = NowMs()
    if lastKillingBlow and now - lastKillingBlow.ms <= KDST.DEATH_LINK_MS then
        return lastKillingBlow
    end
    if lastHit and now - lastHit.ms <= KDST.DEATH_LINK_MS then
        return lastHit
    end
    return { abilityId = 0, abilityName = "Unknown", killer = "Unknown" }
end

local function OnPlayerDead()
    if not KDST.ShouldTrack() then return end
    -- The killing-blow combat event can arrive a frame after the death event.
    zo_callLater(function()
        local src = ResolveDeathSource()
        lastKillingBlow, lastHit = nil, nil
        -- Mirror the kill filter: an NPC (guard, monster) kill outside a battleground doesn't count.
        if KDST.settings.playersOnly and not IsActiveWorldBattleground() and src.ms and not src.isPlayer then
            return
        end
        KDST.RecordDeath(src.abilityId, src.abilityName, src.killer)
    end, 250)
end

-------------------------------------------------------------------------------
-- Duels
-------------------------------------------------------------------------------
local function OnDuelFinished(_, duelResult, wasLocalPlayersResult, _, opponentDisplayName)
    local won
    if duelResult == DUEL_RESULT_WON then
        won = wasLocalPlayersResult == true
    elseif duelResult == DUEL_RESULT_FORFEIT then
        -- wasLocalPlayersResult == true means *we* forfeited
        won = wasLocalPlayersResult ~= true
    else
        return
    end
    KDST.RecordDuel(won, opponentDisplayName)
end

-------------------------------------------------------------------------------
-- Battlegrounds
-------------------------------------------------------------------------------
local function OnBattlegroundStateChanged(_, previousState, currentState)
    currentState = currentState or previousState
    if currentState == BATTLEGROUND_STATE_RUNNING or currentState == BATTLEGROUND_STATE_STARTING then
        KDST.StartMatch()
    elseif currentState == BATTLEGROUND_STATE_POSTGAME or currentState == BATTLEGROUND_STATE_FINISHED then
        KDST.EndMatch(false)
    end
end

local function OnPlayerActivated()
    recentKills = {}
    if IsActiveWorldBattleground() then
        local state = GetCurrentBattlegroundState and GetCurrentBattlegroundState()
        if state == BATTLEGROUND_STATE_RUNNING or state == BATTLEGROUND_STATE_STARTING then
            KDST.StartMatch()
        end
    elseif KDST.match then
        KDST.EndMatch(true)   -- left before the match finished
    end
    KDST.callbacks:FireCallbacks("ZoneChanged")
end

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------
local function RegisterCombat(suffix, handler, ...)
    local name = NS .. suffix
    EM:RegisterForEvent(name, EVENT_COMBAT_EVENT, handler)
    EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT, ...)
end

function KDST.RegisterEvents()
    RegisterCombat("_KB_Player", OnOutgoingKillingBlow,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    RegisterCombat("_KB_Pet", OnOutgoingKillingBlow,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET)
    RegisterCombat("_KB_In", OnIncomingKillingBlow,
        REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    local damageResults = { ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL }
    for i, result in ipairs(damageResults) do
        RegisterCombat("_Hit" .. i, OnIncomingDamage,
            REGISTER_FILTER_COMBAT_RESULT, result,
            REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end

    EM:RegisterForEvent(NS .. "_Dead", EVENT_PLAYER_DEAD, OnPlayerDead)
    EM:RegisterForEvent(NS .. "_Duel", EVENT_DUEL_FINISHED, OnDuelFinished)
    EM:RegisterForEvent(NS .. "_BGState", EVENT_BATTLEGROUND_STATE_CHANGED, OnBattlegroundStateChanged)
    EM:RegisterForEvent(NS .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(NS .. "_GamepadMode", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        KDST.callbacks:FireCallbacks("PlatformChanged", KDST.IsGamepadUI())
    end)
end
