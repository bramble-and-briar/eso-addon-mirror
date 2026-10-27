-- Recuerda los últimos efectos y habilidades vistos (buffs ganados, debuffs que aplicas,
-- habilidades/procs que lanzas) para poder elegirlos en el editor sin conocer su ID.

local OA = OmniAura
local U = OA.Utils

local R = { list = {}, byId = {} }
OA.Recent = R

local MAX_ENTRIES = 60

local function Add(abilityId, name, icon)
    if not abilityId or abilityId == 0 then return end
    local now = GetFrameTimeSeconds()
    local entry = R.byId[abilityId]
    if entry then
        entry.time = now
        return
    end

    name = U.FormatName(name)
    if name == "" then name = U.AbilityName(abilityId) end
    entry = {
        id = abilityId,
        name = name,
        icon = U.NonEmpty(icon) or U.AbilityIcon(abilityId),
        time = now,
    }
    R.byId[abilityId] = entry
    R.list[#R.list + 1] = entry

    if #R.list > MAX_ENTRIES then
        -- Descarta el más antiguo.
        local oldest = 1
        for i, e in ipairs(R.list) do
            if e.time < R.list[oldest].time then oldest = i end
        end
        R.byId[R.list[oldest].id] = nil
        table.remove(R.list, oldest)
    end
end

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime,
                               stackCount, iconName, buffType, effectType, abilityType, statusEffectType,
                               unitName, unitId, abilityId)
    if changeType == EFFECT_RESULT_GAINED then
        Add(abilityId, effectName, iconName)
    end
end

local function OnCombatEvent(_, result, isError, abilityName, abilityGraphic, actionSlotType,
                             sourceName, sourceType, targetName, targetType, hitValue, powerType,
                             damageType, log, sourceUnitId, targetUnitId, abilityId)
    if not isError then Add(abilityId, abilityName) end
end

-- Lista ordenada de más reciente a más antiguo.
function R.Get()
    local out = {}
    for i, e in ipairs(R.list) do out[i] = e end
    table.sort(out, function(a, b) return a.time > b.time end)
    return out
end

function R.Init()
    local em = EVENT_MANAGER
    -- Efectos que recibes
    em:RegisterForEvent("OmniAura_RecentSelf", EVENT_EFFECT_CHANGED, OnEffectChanged)
    em:AddFilterForEvent("OmniAura_RecentSelf", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    -- Efectos que aplicas tú (debuffs en enemigos, etc.)
    em:RegisterForEvent("OmniAura_RecentMine", EVENT_EFFECT_CHANGED, OnEffectChanged)
    em:AddFilterForEvent("OmniAura_RecentMine", EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    -- Habilidades y procs que lanzas
    em:RegisterForEvent("OmniAura_RecentCombat", EVENT_COMBAT_EVENT, OnCombatEvent)
    em:AddFilterForEvent("OmniAura_RecentCombat", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
end
