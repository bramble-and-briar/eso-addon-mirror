DuelResults = {}
----------------------------------------------------------------------------------------------------------------------------------------------------------------
DuelResults.author = "Vixen Hunny"
DuelResults.name = "DuelResults"
DuelResults.version = "1.0.2"
DuelResults.player1 = nil
DuelResults.player2 = nil
LC = LibCombat2 or {}
DuelResults.player1Data = {}
DuelResults.player2Data = {}
DuelResults.player1Name = ""
DuelResults.player2RawName = ""
DuelResults.player1RawName = ""
DuelResults.player1Data.effects = {}
DuelResults.player2Data.effects = {}
DuelResults.player2Name = ""
DuelResults.combatMechs = {}
DuelResults.combatMechs[COMBAT_MECHANIC_FLAGS_HEALTH], _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
DuelResults.combatMechs[COMBAT_MECHANIC_FLAGS_STAMINA], _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_STAMINA)
DuelResults.combatMechs[COMBAT_MECHANIC_FLAGS_MAGICKA], _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MAGICKA)
DuelResults.combatTime = {}
DuelResults.combatTime[COMBAT_MECHANIC_FLAGS_HEALTH] = GetGameTimeMilliseconds()
DuelResults.combatTime[COMBAT_MECHANIC_FLAGS_STAMINA] = GetGameTimeMilliseconds()
DuelResults.combatTime[COMBAT_MECHANIC_FLAGS_MAGICKA] = GetGameTimeMilliseconds()
DuelResults.rps = {}
DuelResults.rps[COMBAT_MECHANIC_FLAGS_HEALTH], _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
DuelResults.rps[COMBAT_MECHANIC_FLAGS_STAMINA], _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_STAMINA)
DuelResults.rps[COMBAT_MECHANIC_FLAGS_MAGICKA], _, _ = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MAGICKA)
DuelResults.effects = {}
DuelResults.ran = false
DuelResults.ping = {
    avg = nil,
    miu = nil,
    max = nil,
    ping = nil,
}

local counts1 = {}

local counts1Faded = {}
local counts2Faded = {}
local counts2 = {}
local sorts1 = {}
local sorts2 = {}
local LAM2 = LibAddonMenu2
local function ResetDuelData()
    DuelResults.player1Data = {}
    DuelResults.player2Data = {}
    DuelResults.player1 = nil
    DuelResults.player1Name = ""
    DuelResults.player2Name = ""
    DuelResults.player2 = nil
    DuelResults.ran = false
    DuelResults.player1RawName = ""
    DuelResults.player1Data.effects = {}
    DuelResults.player2Data.effects = {}
    DuelResults.player2RawName = ""
    d("|cFF8800Duel data reset (Player 1 & Player 2).|r")
end
local function ShowPlayers()
    d(string.format("%s vs. %s ", GetUnitDisplayName(DuelResults.player1), GetUnitDisplayName(DuelResults.player2)))
end
local function calculateHPS()
    local durationSeconds = (GetFrameTimeMilliseconds() - DuelResults.player1Data.combatTime) / 1000
    local player1hps = DuelResults.player1Data.healingDone / durationSeconds
    local realp1hps = player1hps / 1000
    local durationSeconds = (GetFrameTimeMilliseconds() - DuelResults.player2Data.combatTime) / 1000
    local player2hps = DuelResults.player2Data.healingDone / durationSeconds
    local realp2hps = player2hps / 1000
    return realp1hps, realp2hps
end
local function calculateDPS()
    local durationSeconds = (GetFrameTimeMilliseconds() - DuelResults.player1Data.combatTime) / 1000
    local player1dps = DuelResults.player1Data.damageDone / durationSeconds
    local realp1dps = player1dps / 1000
    local durationSeconds = (GetFrameTimeMilliseconds() - DuelResults.player2Data.combatTime) / 1000
    local player2dps = DuelResults.player2Data.damageDone / durationSeconds
    local realp2dps = player2dps / 1000
    return realp1dps, realp2dps
end
local function calculateUptime(username)
    local now = GetFrameTimeMilliseconds()

    local pData
    if GetUnitDisplayName(DuelResults.player1) == username then
        pData = DuelResults.player1Data
    elseif GetUnitDisplayName(DuelResults.player2) == username then
        pData = DuelResults.player2Data
    else
        return
    end

    local combatStart = pData.combatTime
    if not combatStart then
        d("No combatTime set yet (t0).")
        return
    end

    for effectName, effect in pairs(pData.effects) do
        
        local uptime = effect.uptimepercent or 0.0
        local downtime = effect.downtimepercent or 0.0
        d(string.format(
            "Buff/Debuff Name: %s Uptime: %.2f%% Downtime: %.2f%%",
            effectName, uptime, downtime
        ))
    end
end

local function DumpLastDuel()
    local dps1, dps2 = calculateDPS()
    local hps1, hps2 = calculateHPS()
    d(string.format("%s vs %s:\r\n%s Data DPS: |cff00cc%.1fk|r HPS: |cff00cc%.1fk|r Crits: |cff00cc%d|r Blocked Attacks: |cff00cc%d|r", GetUnitDisplayName(DuelResults.player1), GetUnitDisplayName(DuelResults.player2), GetUnitDisplayName(DuelResults.player1), dps1, hps1, DuelResults.player1Data.crits or 0, DuelResults.player1Data.blocked or 0))
    d("Buff uptimes: ")
    calculateUptime(GetUnitDisplayName(DuelResults.player1))
    d(string.format("%s vs %s:\r\n%s Data DPS: |cff00cc%.1fk|r HPS: |cff00cc%.1fk|r Crits: |cff00cc%d|r Blocked Attacks: |cff00cc%d|r", GetUnitDisplayName(DuelResults.player1), GetUnitDisplayName(DuelResults.player2), GetUnitDisplayName(DuelResults.player2), dps2, hps2, DuelResults.player2Data.crits or 0, DuelResults.player2Data.blocked or 0))
    d("Buff Uptimes: ")
    calculateUptime(GetUnitDisplayName(DuelResults.player2))
    d("|cccccccDATA RESULTS END|r")
end
function DuelResults:CreateSettingsMenu()
    local panelData = {
        type = "panel",
        name = "Duel Results",
        displayName = "|cff00ccDuel Results|r",
        author = DuelResults.author,
        version = DuelResults.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM2:RegisterAddonPanel("DuelResultsAddonPanel", panelData)
    local optionsData = {
    {
        type = "button",
        name = "Dump Last Fight",
        tooltip = "Prints all duel data gained in the most recent duel only",
        func = DumpLastDuel,
        width = "full",
    },
    {
        type = "button",
        name = "Reset Fight Data",
        tooltip = "Clears Player 1 and Player 2 duel data",
        func = ResetDuelData,
        width = "full",
        warning = "This will permanently clear current duel data",
    },
    {
        type = "button",
        name = "Show Player Name",
        tooltip = "Shows Player 1 and 2",
        func = ShowPlayers,
        width = "full"
    },
}
    LAM2:RegisterOptionControls("DuelResultsAddonPanel", optionsData)
end
function onFightHeal(_, result, isError, 
abilityName,
abilityGraphic,
actionSlotType,
sourceName,
sourceType,
targetName,
targetType,
hitValue,
powerType,
damageType,
log,
sID,
tID,
abilityId,
overflow
)
if DuelResults.player1 and DuelResults.player2 then
    if sourceName == DuelResults.player1RawName or sourceName == DuelResults.player1Name then
        if result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL then
            if result == ACTION_RESULT_HOT_TICK_CRITICAL or result ==ACTION_RESULT_CRITICAL_HEAL then
                DuelResults.player1Data.crits = (DuelResults.player1Data.crits or 0) + 1
                DuelResults.player2Data.crits = (DuelResults.player2Data.crits or 0)
            end
            DuelResults.player1Data.lastHealingTick = GetFrameTimeMilliseconds()
            DuelResults.player1Data.healingDone = (DuelResults.player1Data.healingDone or 0) + hitValue + overflow
            DuelResults.player2Data.healingDone = (DuelResults.player2Data.healingDone or 0)
        end
    elseif sourceName == DuelResults.player2RawName or sourceName == DuelResults.player2Name then
        if result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL then
            if result == ACTION_RESULT_HOT_TICK_CRITICAL or result == ACTION_RESULT_CRITICAL_HEAL then
                DuelResults.player2Data.crits = (DuelResults.player2Data.crits or 0) + 1
                DuelResults.player1Data.crits = (DuelResults.player1Data.crits or 0)
            end
            DuelResults.player2Data.lastHealingTick = GetFrameTimeMilliseconds()
            DuelResults.player2Data.healingDone = (DuelResults.player2Data.healingDone or 0) + hitValue + overflow
            DuelResults.player1Data.healingDone = (DuelResults.player1Data.healingDone or 0)
        end
    end
end
end
function onFightDamage(_, result, isError, 
abilityName,
abilityGraphic,
actionSlotType,
sourceName,
sourceType,
targetName,
targetType,
hitValue,
powerType,
damageType,
log,
sID,
tID,
abilityId,
overflow)
if DuelResults.player1 and DuelResults.player2 then
    if sourceName == DuelResults.player1RawName or sourceName == DuelResults.player1Name then
        if result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DAMAGE_SHIELDED then
            if result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_BLOCKED then
                DuelResults.player1Data.blocked = (DuelResults.player1Data.blocked or 0) + 1
                DuelResults.player2Data.blocked = (DuelResults.player2Data.blocked or 0)
            elseif result == ACTION_RESULT_CRITICAL_DAMAGE then
                DuelResults.player1Data.crits = (DuelResults.player1Data.crits or 0) + 1
                DuelResults.player2Data.crits = (DuelResults.player2Data.crits or 0)
            end
            DuelResults.player1Data.lastDamageTick = GetFrameTimeMilliseconds()
            DuelResults.player1Data.damageDone = (DuelResults.player1Data.damageDone or 0) + hitValue + overflow
            DuelResults.player2Data.damageDone = (DuelResults.player2Data.damageDone or 0)
        end

    elseif sourceName == DuelResults.player2RawName or sourceName == DuelResults.player2Name then
        if result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DAMAGE_SHIELDED then
            if result == ACTION_RESULT_BLOCKED_DAMAGE or result == ACTION_RESULT_BLOCKED then
                DuelResults.player2Data.blocked = (DuelResults.player2Data.blocked or 0) + 1
                DuelResults.player1Data.blocked = (DuelResults.player1Data.blocked or 0)
            elseif result == ACTION_RESULT_CRITICAL_DAMAGE then
                DuelResults.player2Data.crits = (DuelResults.player2Data.crits or 0) + 1
                DuelResults.player1Data.crits = (DuelResults.player1Data.crits or 0)
            end
            DuelResults.player2Data.lastDamageTick  = GetFrameTimeMilliseconds()
            DuelResults.player2Data.damageDone = (DuelResults.player2Data.damageDone or 0) + hitValue + overflow
            DuelResults.player1Data.damageDone = (DuelResults.player1Data.damageDone or 0)
        end


    end
end
end
local function EnsureEffectState(effect, combatStartMs)
    effect.UP = effect.UP or false
    effect.uptimeMs = effect.uptimeMs or 0
    effect.downtimeMs = effect.downtimeMs or 0
    effect.lastStateChangeMs = effect.lastStateChangeMs or combatStartMs
end

local function ApplyState(effect, newUp, nowMs)
    if newUp == effect.UP then
        -- no state change -> nothing to accumulate
        return
    end

    local dt = nowMs - (effect.lastStateChangeMs or nowMs)
    if dt < 0 then dt = 0 end

    -- close the previous interval
    if effect.UP then
        effect.uptimeMs = effect.uptimeMs + dt
    else
        effect.downtimeMs = effect.downtimeMs + dt
    end

    -- flip state
    effect.UP = newUp
    effect.lastStateChangeMs = nowMs
end

local function GetTotals(effect, combatStartMs, nowMs)
    local uptime = effect.uptimeMs or 0
    local downtime = effect.downtimeMs or 0

    -- include the currently running interval without mutating state
    local dt = nowMs - (effect.lastStateChangeMs or combatStartMs)
    if dt < 0 then dt = 0 end

    if effect.UP then
        uptime = uptime + dt
    else
        downtime = downtime + dt
    end

    local total = nowMs - combatStartMs
    if total <= 0 then
        return 0, 0, 0, 0
    end

    local uptimePct = (uptime / total) * 100
    local downtimePct = (downtime / total) * 100
    return uptime or 0.00, downtime or 0.00, uptimePct or 0.00, downtimePct or 0.00
end
function DuelResults:onEffectsUpdate(effectName, isUpNow, Name)
    local now = GetFrameTimeMilliseconds()

    local pData
    if Name == DuelResults.player1Name or Name == DuelResults.player1RawName then
        pData = DuelResults.player1Data
    elseif Name == DuelResults.player2Name or Name == DuelResults.player2RawName then
        pData = DuelResults.player2Data
    else
        return
    end

    -- combatTime is your t0 (start of measurement window)
    local combatStart = pData.combatTime
    if not combatStart then
        -- if you don’t have this set yet, set it now
        pData.combatTime = now
        combatStart = now
    end

    -- get effect table
    local effect = pData.effects[effectName]
    if not effect then
        pData.effects[effectName] = {}
        effect = pData.effects[effectName]
    end

    -- ensure fields exist
    EnsureEffectState(effect, combatStart)

    -- update accumulated time if state changed
    ApplyState(effect, isUpNow, now)

    -- compute totals + percentages
    local uptime, downtime, upPct, downPct = GetTotals(effect, combatStart, now)

    -- store results (optional)
    effect.uptime = uptime
    effect.downtime = downtime
    effect.uptimepercent = upPct
    effect.downtimepercent = downPct
end

local function OnEffectChanged(eventCode, changeType, effectSlot, effectName,
    unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType,
    abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
            
        if unitName == DuelResults.player1Name or unitName == DuelResults.player1RawName then
            if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
                DuelResults:onEffectsUpdate(effectName, true, unitName)
            elseif changeType == EFFECT_RESULT_FADED then
                DuelResults:onEffectsUpdate(effectName, false, unitName)
            end
        elseif unitName == DuelResults.player2Name or unitName == DuelResults.player2RawName then
            if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
                DuelResults:onEffectsUpdate(effectName, true, unitName)
            elseif changeType == EFFECT_RESULT_FADED then
                DuelResults:onEffectsUpdate(effectName, false, unitName)
            end
        end
    end

function DuelResults:OnDuelsUpdate()
    if IsPlayerInGroup(GetUnitDisplayName("player")) then
    for i = 1, GetGroupSize() do
        repeat
        local unitTag = GetGroupUnitTagByIndex(i)
        if IsUnitPvPFlagged(unitTag) then
            if DuelResults.player1 == nil then
                DuelResults.player1Data.combatTime = GetFrameTimeMilliseconds()
                DuelResults.player1RawName = GetRawUnitName(unitTag)
                DuelResults.player1 = unitTag
                DuelResults.player1Name = GetUnitName(unitTag)
                if DuelResults.player2 ~= nil and DuelResults.ran == false then
                    local name = GetUnitDisplayName(DuelResults.player2)
                    DuelResults.player2Data.combatTime = DuelResults.player1Data.combatTime
                    local name2 = GetUnitDisplayName(DuelResults.player1)
                    d(string.format("%s vs %s", name2, name))
                    DuelResults.ran = true
                    return true
                end
            elseif DuelResults.player2 == nil then
                if DuelResults.player1 == unitTag then
                    break
                end
                DuelResults.player2Data.combatTime = GetFrameTimeMilliseconds()
                DuelResults.player2 = unitTag
                DuelResults.player2RawName = GetRawUnitName(unitTag)
                DuelResults.player2Name = GetUnitName(unitTag)
                if DuelResults.player1 ~= nil and DuelResults.ran == false then
                    local name = GetUnitDisplayName(DuelResults.player1)
                    local name2 = GetUnitDisplayName(DuelResults.player2)
                    DuelResults.player1Data.combatTime = DuelResults.player2Data.combatTime
                    d(string.format("Duel Started: %s vs %s", name, name2))
                    DuelResults.ran = true
                    return true
                end
            else
                return true
            end
        end
    until true



    end
end
end
function DuelResults:Initialize()
    DuelResults:CreateSettingsMenu()
    EVENT_MANAGER:RegisterForEvent(DuelResults.name.."UpdateDamage", EVENT_COMBAT_EVENT, onFightDamage)
    EVENT_MANAGER:RegisterForEvent(DuelResults.name.."UpdateHeal", EVENT_COMBAT_EVENT, onFightHeal)
    EVENT_MANAGER:RegisterForEvent(DuelResults.name.."Effects", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:RegisterForUpdate(DuelResults.name.."UpdateDuelers", 2000, function() DuelResults:OnDuelsUpdate() end)
end 
function DuelResults:AddonLoaded(ec, addonName)
    if DuelResults.name ~= addonName then return end
    DuelResults:Initialize()
end
EVENT_MANAGER:RegisterForEvent(DuelResults.name.."_ADDONLOADED", EVENT_ADD_ON_LOADED, function(...) DuelResults:AddonLoaded(...) end)