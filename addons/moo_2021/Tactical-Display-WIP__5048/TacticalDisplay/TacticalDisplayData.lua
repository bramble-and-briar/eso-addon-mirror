TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Data = TacticalDisplay.Data or {}
local _Data = TacticalDisplay.Data
local _GetMeasurablePlayerDamage = TacticalDisplay.Base.GetMeasurablePlayerDamage
local _GetAbilityIconCached = TacticalDisplay.Utilities.GetAbilityIconCached
local _LogError = TacticalDisplay.Utilities.LogError
local _LogDebug = TacticalDisplay.Utilities.LogDebug

-- DB tables from base are assigned by Initialize
local _HIDDEN_ABILITIES       -- [ability id] = ability name
local _TRACKED_DOT_ABILITIES  -- [ability id] = ability name
local _SIGNATURE_ABILITIES    -- [ability id] = {"main" = main ability id, "name" = ability name}

local _debugLog               -- boolean
local _minDamage              -- skip tracking if lower than this
local _signatureFilterOff     -- true to mark all attacks as signature
local _signatureTTL           -- how long to keep signature; unit = num of received attacks
local _opponentTable          -- [source_or_target] = opponent data, see GetOrCreateOpponent()
local _onOpponentUpdated = {} -- [caller_id] = func callback(opponent)
_Data.OnOpponentUpdated = _onOpponentUpdated

local SHIELD_ACTION_RESULTS = {
    ACTION_RESULT_DAMAGE_SHIELDED,
}

local DAMAGE_ACTION_RESULTS = {
    ACTION_RESULT_DAMAGE,
    ACTION_RESULT_CRITICAL_DAMAGE,
    -- ACTION_RESULT_REFLECTED_DAMAGE, -- FIXME: how to handle this??
    ACTION_RESULT_BLOCKED_DAMAGE,
}

local DOT_ACTION_RESULTS = {
    ACTION_RESULT_DOT_TICK,
    ACTION_RESULT_DOT_TICK_CRITICAL,
}

local BLOCKED_ACTION_RESULTS = {
    [ACTION_RESULT_BLOCKED_DAMAGE] = true,
}

local CRITICAL_ACTION_RESULTS = {
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

-------------------------------------------------------------------------------
-- Shielded damage events: buffer absorbed damages for pairing later
-------------------------------------------------------------------------------

local UPDATE_CLEANUP_NAME = "TacticalDisplay_Data_ExpireShieldDamage"
local UPDATE_CLEANUP_INTERVAL_MS = 1000
-- use very short buffer to avoid matching excluded DoTs and excluded damage abilities that are absorbed by shields.
local SHIELD_BUFFER_DURATION_MS = 20

local _damageShieldBuffer = {} -- list of { timeMs, sourceUnitId, targetUnitId, hitValue }

local function PullShieldedDamage(timeMs, sourceUnitId, targetUnitId)
    local totalDamage = 0
    local numPulled = 0
    for i = #_damageShieldBuffer, 1, -1 do
        local shieldTimeMs, shieldSourceUnitId, shieldTargetUnitId, shieldDamage = unpack(_damageShieldBuffer[i])
        if shieldSourceUnitId == sourceUnitId
            and shieldTargetUnitId == targetUnitId
            and timeMs - shieldTimeMs <= SHIELD_BUFFER_DURATION_MS
        then
            table.remove(_damageShieldBuffer, i)
            totalDamage = totalDamage + shieldDamage
            numPulled = numPulled + 1
        end
    end
    if numPulled > 0 and _debugLog then
        _LogDebug(string.format("Pulled shield damage at %d: num %d, total %d; remain: %d",
            timeMs, numPulled, totalDamage, #_damageShieldBuffer))
    end
    return totalDamage
end

local function ExpireShieldedDamage()
    local numExpired = 0
    local clockTimeMs = GetGameTimeMilliseconds()
    for i = #_damageShieldBuffer, 1, -1 do
        local shieldTimeMs, _, _, _ = unpack(_damageShieldBuffer[i])
        if clockTimeMs - shieldTimeMs > SHIELD_BUFFER_DURATION_MS then
            table.remove(_damageShieldBuffer, i)
            numExpired = numExpired + 1
        end
    end
    if numExpired > 0 and _debugLog then
        _LogDebug(string.format("Expired shield damage: num %d; remain: %d",
            numExpired, #_damageShieldBuffer))
    end
end

local function OnShieldCombatEvent(
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
    if (targetType == COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER)
        or not targetName or targetName == "" then
        return
    end

    if hitValue == 0 then
        return
    end

    local timeMs = GetGameTimeMilliseconds()
    _damageShieldBuffer[#_damageShieldBuffer + 1] = { timeMs, sourceUnitId, targetUnitId, hitValue }

    if _debugLog then
        _LogDebug(string.format("Buffer shield damage at %d, from %d, to %d, damage %d; buffer %d",
            timeMs, sourceUnitId, targetUnitId, hitValue, #_damageShieldBuffer))
    end
end

-------------------------------------------------------------------------------
-- Combat damage events
-------------------------------------------------------------------------------

local function GetOrCreateOpponent(key)
    local opponent = _opponentTable[key]
    if not opponent then
        opponent = {
            name = key,
            lastSeen = 0,
            lastDealtAttack = nil,
            -- {
            --     abilityId = 123,
            --     abilityIcon = nil,
            --     abilityName = "Bash",
            --     damage = 100,
            --     isCritical = true,
            --     isBlocked = false,
            --     isShielded = false,
            -- },
            lastBaseDamage = 0,
            lastMitigation = 0,
            numAttacks = 0,
            signature = {},
        }
        _opponentTable[key] = opponent
    end
    return opponent
end

local MAX_BASE_DAMAGES = 20

local function UpdateOpponentBaseDamage(opponent, damage)
    local baseDamages = opponent.baseDamages or {}
    opponent.baseDamages = baseDamages

    if #baseDamages >= MAX_BASE_DAMAGES then
        table.remove(baseDamages, #baseDamages)
    end
    table.insert(baseDamages, 1, damage)

    local total = 0
    for _, d in ipairs(baseDamages) do
        total = total + d
    end
    opponent.lastBaseDamage = math.floor(total / #baseDamages + 0.5)
end

local function UpdateOpponentSignature(opponent)
    local lastDealtAttack = opponent.lastDealtAttack
    if not lastDealtAttack then
        return
    end

    local numAttacks = opponent.numAttacks or 0
    local signature = opponent.signature or {}
    opponent.signature = signature

    if _signatureFilterOff or lastDealtAttack.isSignature then
        local sigDef = _SIGNATURE_ABILITIES[lastDealtAttack.abilityId]
        local sigAbilityId = sigDef and sigDef.main or lastDealtAttack.abilityId
        local sitem = signature[sigAbilityId]
        if not sitem then
            sitem = {
                abilityName = lastDealtAttack.abilityName,
                abilityIcon = _GetAbilityIconCached(sigAbilityId) or lastDealtAttack.abilityIcon,
            }
            signature[sigAbilityId] = sitem
        end
        sitem.lastUsed = numAttacks
    end

    if numAttacks % 10 == 0 then
        local expiry = numAttacks - _signatureTTL
        for abilityId, sitem in pairs(signature) do
            if not sitem.lastUsed or sitem.lastUsed < expiry then
                signature[abilityId] = nil
                if _debugLog then
                    _LogDebug(string.format("Expire signature ability from [%s]: %d %s: %d < %d - %d",
                        opponent.name, abilityId, sitem.abilityName,
                        sitem.lastUsed or 0, numAttacks, _signatureTTL))
                end
            end
        end
    end
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
    if (targetType == COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER)
        or not targetName or targetName == ""
        or not abilityName or abilityName == ""
        or _HIDDEN_ABILITIES[abilityId] ~= nil then
        return
    end

    local sessionTimeMs = GetGameTimeMilliseconds()
    local shieldedDamage = PullShieldedDamage(sessionTimeMs, sourceUnitId, targetUnitId)
    local totalDamage = hitValue + overflow + shieldedDamage
    if totalDamage == 0 then
        if _debugLog then
            _LogDebug(string.format("Exclude zero incoming damage from [%s]: %d %s: %d %d %d",
                sourceName, abilityId, abilityName,
                result, sourceUnitId, targetUnitId))
        end
        return
    elseif totalDamage < _minDamage then
        return
    end

    local isBlocked = BLOCKED_ACTION_RESULTS[result]
    local isCritical = CRITICAL_ACTION_RESULTS[result]

    local opponentKey = zo_strformat(SI_UNIT_NAME, sourceName)
    local opponent = GetOrCreateOpponent(opponentKey)
    opponent.lastSeen = GetTimeStamp()

    local previousAttack = opponent.lastDealtAttack
    if previousAttack ~= nil
        and previousAttack.abilityName == abilityName
        and previousAttack.sessionTimeMs ~= nil
        and previousAttack.sessionTimeMs <= sessionTimeMs
        and previousAttack.sessionTimeMs >= sessionTimeMs - 100 then
        previousAttack.abilityId = abilityId
        previousAttack.abilityIcon = _GetAbilityIconCached(abilityId) or previousAttack.abilityIcon
        previousAttack.damage = previousAttack.damage + totalDamage
        previousAttack.isCritical = isCritical
        previousAttack.isBlocked = isBlocked
        previousAttack.isShielded = shieldedDamage > 0
        previousAttack.sessionTimeMs = sessionTimeMs
    else
        opponent.lastDealtAttack = {
            abilityId = abilityId,
            abilityName = abilityName,
            abilityIcon = _GetAbilityIconCached(abilityId) or nil,
            damage = totalDamage,
            isCritical = isCritical,
            isBlocked = isBlocked,
            isShielded = shieldedDamage > 0,
            isSignature = _SIGNATURE_ABILITIES[abilityId] ~= nil,
            sessionTimeMs = sessionTimeMs,
        }
        opponent.numAttacks = (opponent.numAttacks or 0) + 1
    end

    if not isBlocked
        and abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then
        UpdateOpponentBaseDamage(opponent, totalDamage)
    end

    UpdateOpponentSignature(opponent)

    if _debugLog then
        _LogDebug(string.format("Incoming from [%s]: %d %s, %d+%d+%d %s(base %d): %d %d %d",
            opponentKey, abilityId, abilityName,
            hitValue, overflow, shieldedDamage,
            (isCritical and "C" or "") .. (isBlocked and "B" or ""),
            opponent.lastBaseDamage,
            result, sourceUnitId, targetUnitId))
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
    if (targetType == COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER)
        or not targetName or targetName == ""
        or not abilityName or abilityName == ""
        or _HIDDEN_ABILITIES[abilityId] ~= nil then
        return
    end

    local shieldedDamage = PullShieldedDamage(GetGameTimeMilliseconds(), sourceUnitId, targetUnitId)
    local totalDamage = hitValue + overflow + shieldedDamage
    if totalDamage == 0 then
        if _debugLog then
            _LogDebug(string.format("Exclude zero outgoing damage from [%s]: %d %s: %d %d %d",
                sourceName, abilityId, abilityName,
                result, sourceUnitId, targetUnitId))
        end
        return
    elseif totalDamage < _minDamage then
        return
    end

    local isBlocked = BLOCKED_ACTION_RESULTS[result]
    local isCritical = CRITICAL_ACTION_RESULTS[result]

    local opponentKey = zo_strformat(SI_UNIT_NAME, targetName)
    local opponent = GetOrCreateOpponent(opponentKey)
    opponent.lastSeen = GetTimeStamp()

    if not isBlocked
        and not isCritical
        and shieldedDamage == 0
        and overflow == 0 then
        -- record opponent mitigation; inaccurate if damage lands right after bar-swapping or buf change
        local sourceDamage = _GetMeasurablePlayerDamage(abilityId, abilityName)
        if sourceDamage or 0 > 0 then
            local mitigation = math.floor((1 - totalDamage / sourceDamage) * 100 + 0.5)
            if mitigation >= 0 then
                opponent.lastMitigation = mitigation
                if _debugLog then
                    _LogDebug(string.format("Update mitigation %d %s %d => %s %d, mitigated %d%%",
                        abilityId, abilityName, sourceDamage,
                        opponentKey, totalDamage, mitigation))
                end
            end
        end
    end

    if _debugLog then
        _LogDebug(string.format("Outgoing to [%s]: %d %s, %d+%d+%d %s(%d%%): %d %d %d",
            opponentKey, abilityId, abilityName,
            hitValue, overflow, shieldedDamage,
            (isCritical and "C" or "") .. (isBlocked and "B" or ""),
            opponent.lastMitigation,
            result, sourceUnitId, targetUnitId))
    end

    InvokeOnOpponentUpdated(opponent)
end

-------------------------------------------------------------------------------
-- Combat event registrations
-------------------------------------------------------------------------------

local INCOMING_COMBAT_EVENT_PREFIX = "TacticalDisplay_Data_Combat_In_"
local OUTGOING_COMBAT_EVENT_PREFIX = "TacticalDisplay_Data_Combat_Out_"

local _combatEventRegistrations = {}

local function RegisterForCombatEvents()
    local handlers = {}
    for _, actionResult in ipairs(SHIELD_ACTION_RESULTS) do
        handlers[actionResult] = { OnShieldCombatEvent, OnShieldCombatEvent }
    end
    for _, actionResult in ipairs(DAMAGE_ACTION_RESULTS) do
        handlers[actionResult] = { OnIncomingCombatEvent, OnOutgoingCombatEvent }
    end

    for actionResult, callbackPair in pairs(handlers) do
        local onIncoming, onOutgoing = unpack(callbackPair)

        if onIncoming then
            local inReg = INCOMING_COMBAT_EVENT_PREFIX .. tostring(actionResult)
            EVENT_MANAGER:RegisterForEvent(inReg, EVENT_COMBAT_EVENT, onIncoming)
            if not EVENT_MANAGER:AddFilterForEvent(
                    inReg,
                    EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_IS_ERROR, false,
                    ---@diagnostic disable-next-line: redundant-parameter
                    REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                    ---@diagnostic disable-next-line: redundant-parameter
                    REGISTER_FILTER_COMBAT_RESULT, actionResult
                ) then
                _LogError(string.format("Failed to apply filter for %s", inReg))
            end
            _combatEventRegistrations[#_combatEventRegistrations + 1] = inReg
        end

        if onOutgoing then
            local outReg = OUTGOING_COMBAT_EVENT_PREFIX .. tostring(actionResult)
            EVENT_MANAGER:RegisterForEvent(outReg, EVENT_COMBAT_EVENT, onOutgoing)
            if not EVENT_MANAGER:AddFilterForEvent(
                    outReg,
                    EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_IS_ERROR, false,
                    ---@diagnostic disable-next-line: redundant-parameter
                    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                    ---@diagnostic disable-next-line: redundant-parameter
                    REGISTER_FILTER_COMBAT_RESULT, actionResult
                ) then
                _LogError(string.format("Failed to apply filter for %s", outReg))
            end
            _combatEventRegistrations[#_combatEventRegistrations + 1] = outReg
        end
    end

    -- Register for each of tracked DoT abilities as there are very few we need.
    -- Track incoming DoTs only. No reason to track outgoing DoTs yet.
    for _, actionResult in ipairs(DOT_ACTION_RESULTS) do
        for abilityId in pairs(_TRACKED_DOT_ABILITIES) do
            local dotReg = INCOMING_COMBAT_EVENT_PREFIX .. tostring(actionResult) .. "_" .. tostring(abilityId)
            EVENT_MANAGER:RegisterForEvent(dotReg, EVENT_COMBAT_EVENT, OnIncomingCombatEvent)
            if not EVENT_MANAGER:AddFilterForEvent(
                    dotReg,
                    EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_IS_ERROR, false,
                    ---@diagnostic disable-next-line: redundant-parameter
                    REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                    ---@diagnostic disable-next-line: redundant-parameter
                    REGISTER_FILTER_COMBAT_RESULT, actionResult,
                    ---@diagnostic disable-next-line: redundant-parameter
                    REGISTER_FILTER_ABILITY_ID, abilityId
                ) then
                _LogError(string.format("Failed to apply filter for %s", dotReg))
            end
            _combatEventRegistrations[#_combatEventRegistrations + 1] = dotReg
        end
    end

    if _debugLog then
        _LogDebug(string.format("Made %d combat event registrations", #_combatEventRegistrations))
    end
end

local function UnregisterForCombatEvents()
    if _debugLog then
        _LogDebug(string.format("Unregistering %d combat event registrations", #_combatEventRegistrations))
    end

    for i = #_combatEventRegistrations, 1, -1 do
        EVENT_MANAGER:UnregisterForEvent(_damageShieldBuffer[i], EVENT_COMBAT_EVENT)
        table.remove(_combatEventRegistrations, i)
    end
end

-------------------------------------------------------------------------------
-- Public functions
-------------------------------------------------------------------------------

function _Data.Initialize(savedVars)
    local serverName = GetWorldName()
    savedVars.data = savedVars.data or {}
    savedVars.data[serverName] = savedVars.data[serverName] or {}
    savedVars.data[serverName].opponentTable = savedVars.data[serverName].opponentTable or {}

    _opponentTable = savedVars.data[serverName].opponentTable

    _HIDDEN_ABILITIES = TacticalDisplay.Base.HIDDEN_ABILITIES
    _TRACKED_DOT_ABILITIES = TacticalDisplay.Base.TRACKED_DOT_ABILITIES
    _SIGNATURE_ABILITIES = TacticalDisplay.Base.SIGNATURE_ABILITIES
end

local _enabled = false

function _Data.Enable()
    if _enabled then
        return
    end
    RegisterForCombatEvents()
    EVENT_MANAGER:RegisterForUpdate(UPDATE_CLEANUP_NAME, UPDATE_CLEANUP_INTERVAL_MS, ExpireShieldedDamage)
    _enabled = true
end

function _Data.Disable()
    if not _enabled then
        return
    end
    UnregisterForCombatEvents()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_CLEANUP_NAME)
    _enabled = false
end

function _Data.UpdateParameters(debug, minDamage, signatureFilterOff, signatureTTL)
    _debugLog = debug
    _minDamage = minDamage
    _signatureFilterOff = signatureFilterOff
    _signatureTTL = signatureTTL
end
