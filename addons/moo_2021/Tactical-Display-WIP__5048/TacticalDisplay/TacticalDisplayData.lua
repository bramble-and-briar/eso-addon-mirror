TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Data = TacticalDisplay.Data or {}
local _Data = TacticalDisplay.Data

local _opponentTable
local _onOpponentUpdated = {}
_Data.OnOpponentUpdated = _onOpponentUpdated

local DEBUG_COMBAT = false

local INCLUDED_ACTION_RESULTS = {
    ACTION_RESULT_DAMAGE,
    ACTION_RESULT_CRITICAL_DAMAGE,
    -- ACTION_RESULT_DOT_TICK,
    -- ACTION_RESULT_DOT_TICK_CRITICAL,
    -- ACTION_RESULT_REFLECTED_DAMAGE,
    ACTION_RESULT_BLOCKED_DAMAGE,
    ACTION_RESULT_DAMAGE_SHIELDED,
}

local CRITICAL_ACTION_RESULTS = {
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

local BLOCKED_ACTION_RESULTS = {
    [ACTION_RESULT_BLOCKED_DAMAGE] = true,
}

local EXCLUDED_ABILITY_NAMES = {
    -- Status effects
    ["Burning"] = true,
    ["Chilled"] = true,
    ["Concussed"] = true,
    ["Diseased"] = true,
    ["Hemorrhaging"] = true,
    ["Overcharged"] = true,
    ["Poisoned"] = true,
    ["Sundered"] = true,
    -- Weapon Enchants
    ["Befouled Weapon"] = true,
    ["Charged Weapon"] = true,
    ["Decrease Health"] = true,
    ["Fiery Weapon"] = true,
    ["Frozen Weapon"] = true,
    ["Poisoned Weapon"] = true,
}

local function GetOrCreateOpponent(key)
    local opponent = _opponentTable[key]
    if not opponent then
        opponent = {
            name = key,
            lastSeen = 0,
            lastDealtAttack = nil, -- { abilityName: "Bash", abilityIcon, damage = 100, critical = true, blocked = false }
            lastBaseDamage = 0,
            lastMitigation = 0,
        }
        _opponentTable[key] = opponent
    end
    return opponent
end

local function InvokeOnOpponentUpdated(opponent)
    for _, callback in pairs(_onOpponentUpdated) do
        if callback then
            callback(opponent)
        end
    end
end

local function OnIncomingCombatEvent(
    eventCode,
    result,
    isError,
    abilityName,
    abilityGraphic,
    abilityActionSlotType,
    sourceName,
    sourceType,
    targetName,
    targetType,
    hitValue,
    powerType,
    damageType,
    log,
    sourceUnitId,
    targetUnitId,
    abilityId,
    overflow
)
    if not hitValue or hitValue <= 0
        or not sourceName or sourceName == ""
        or not abilityName or abilityName == ""
        or EXCLUDED_ABILITY_NAMES[abilityName] == true then
        return
    end

    -- ignore environment damage
    if targetType == COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return
    end

    local blocked = BLOCKED_ACTION_RESULTS[result]
    local critical = CRITICAL_ACTION_RESULTS[result]

    local opponentKey = zo_strformat(SI_UNIT_NAME, sourceName)
    local opponent = GetOrCreateOpponent(opponentKey)
    opponent.lastSeen = GetTimeStamp()
    opponent.lastDealtAttack = {
        abilityName = abilityName,
        abilityIcon = abilityId and GetAbilityIcon(abilityId) or nil,
        damage = hitValue,
        critical = critical,
        blocked = blocked
    }
    if not blocked and not critical
        and abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then
        opponent.lastBaseDamage = hitValue
    end
    if DEBUG_COMBAT then
        d(string.format("Incoming from [%s]: %s, %d (base %d)", opponentKey, abilityName, hitValue,
            opponent.lastBaseDamage))
    end

    InvokeOnOpponentUpdated(opponent)
end

local function OnOutgoingCombatEvent(
    eventCode,
    result,
    isError,
    abilityName,
    abilityGraphic,
    abilityActionSlotType,
    sourceName,
    sourceType,
    targetName,
    targetType,
    hitValue,
    powerType,
    damageType,
    log,
    sourceUnitId,
    targetUnitId,
    abilityId,
    overflow
)
    if isError or not hitValue or hitValue <= 0
        or not targetName or targetName == ""
        or not abilityName or abilityName == ""
        or EXCLUDED_ABILITY_NAMES[abilityName] == true then
        return
    end

    -- ignore environment damage
    if targetType == COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return
    end

    local blocked = BLOCKED_ACTION_RESULTS[result]
    local critical = CRITICAL_ACTION_RESULTS[result]

    local opponentKey = zo_strformat(SI_UNIT_NAME, targetName)
    local opponent = GetOrCreateOpponent(opponentKey)
    opponent.lastSeen = GetTimeStamp()

    if not blocked and not critical
        and abilityActionSlotType == ACTION_SLOT_TYPE_BLOCK
        and abilityName == "Bash" then
        local _, playerBashDamage = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_BASH_DAMAGE)
        if playerBashDamage and playerBashDamage > 0 then
            local mitigation = math.floor((1 - hitValue / playerBashDamage) * 100 + 0.5)
            if mitigation >= 0 then
                opponent.lastMitigation = mitigation
                if DEBUG_COMBAT then
                    d(string.format(
                        "[TacticalDisplay] bash %d => %s %d, mitigated %d%%",
                        playerBashDamage,
                        opponentKey,
                        hitValue,
                        mitigation
                    ))
                end
            end
        end
    end
    if DEBUG_COMBAT then
        d(string.format("Outgoing to [%s]: %s, %d (%d%%)", opponentKey, abilityName, hitValue,
            opponent.lastMitigation))
    end

    InvokeOnOpponentUpdated(opponent)
end

local INCOMING_COMBAT_EVENT_PREFIX = "TacticalDisplay_Combat_In_"
local OUTGOING_COMBAT_EVENT_PREFIX = "TacticalDisplay_Combat_Out_"

local function RegisterCombatEvent()
    for _, actionResult in ipairs(INCLUDED_ACTION_RESULTS) do
        local incomingCombatEvent = INCOMING_COMBAT_EVENT_PREFIX .. tostring(actionResult)
        EVENT_MANAGER:RegisterForEvent(incomingCombatEvent, EVENT_COMBAT_EVENT, OnIncomingCombatEvent)
        if not EVENT_MANAGER:AddFilterForEvent(
                incomingCombatEvent,
                EVENT_COMBAT_EVENT,
                REGISTER_FILTER_IS_ERROR, false,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_COMBAT_RESULT, actionResult
            ) then
            d(string.format("TacticalDisplay: failed to apply filter for %s", incomingCombatEvent))
        end

        local outgoingCombatEvent = OUTGOING_COMBAT_EVENT_PREFIX .. tostring(actionResult)
        EVENT_MANAGER:RegisterForEvent(outgoingCombatEvent, EVENT_COMBAT_EVENT, OnOutgoingCombatEvent)
        if not EVENT_MANAGER:AddFilterForEvent(
                outgoingCombatEvent,
                EVENT_COMBAT_EVENT,
                REGISTER_FILTER_IS_ERROR, false,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_COMBAT_RESULT, actionResult
            ) then
            d(string.format("TacticalDisplay: failed to apply filter for %s", outgoingCombatEvent))
        end
    end
end

local function UnregisterCombatEvent()
    for _, actionResult in ipairs(INCLUDED_ACTION_RESULTS) do
        EVENT_MANAGER:UnregisterForEvent(INCOMING_COMBAT_EVENT_PREFIX .. tostring(actionResult), EVENT_COMBAT_EVENT)
        EVENT_MANAGER:UnregisterForEvent(OUTGOING_COMBAT_EVENT_PREFIX .. tostring(actionResult), EVENT_COMBAT_EVENT)
    end
end

function _Data.Initialize(savedVars)
    local serverName = GetWorldName()
    savedVars.data = savedVars.data or {}
    savedVars.data[serverName] = savedVars.data[serverName] or {}
    savedVars.data[serverName].opponentTable = savedVars.data[serverName].opponentTable or {}

    _opponentTable = savedVars.data[serverName].opponentTable
end

function _Data.Enable()
    UnregisterCombatEvent()
    RegisterCombatEvent()
end

function _Data.Disable()
    UnregisterCombatEvent()
end
