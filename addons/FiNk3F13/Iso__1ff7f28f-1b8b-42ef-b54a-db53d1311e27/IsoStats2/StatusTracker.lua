-- Event-based collection inspired by CMX/LibCombat's actual-status approach.
-- No minor-buff proxies and no name-only matching between different enemies.
local S=IsoStats2
local units,criticalUnits,durations={},{},{}
local currentTargetId
local lastPrune=0
local debug={combat=0,effects=0,recent={}}
local function note(kind,unitId,id)
    if kind=='Kampf' then debug.combat=debug.combat+1 else debug.effects=debug.effects+1 end
    debug.recent[#debug.recent+1]={kind=kind,unitId=unitId,id=id,time=GetGameTimeMilliseconds()}
    if #debug.recent>6 then table.remove(debug.recent,1) end
end
function S.GetStatusTrackingDiagnostics()
    return {combat=debug.combat,effects=debug.effects,recent=debug.recent,targetId=currentTargetId}
end

local function validId(id) return id~=nil and id~=0 and id~='0' and id~='' end
local function targetExists()
    return DoesUnitExist('reticleover') and not IsUnitPlayer('reticleover')
        and IsUnitAttackable('reticleover') and not IsUnitDead('reticleover')
end
local function sameUnitName(a,b)
    if type(a)~='string' or type(b)~='string' then return false end
    if zo_strformat and SI_UNIT_NAME then
        return zo_strformat(SI_UNIT_NAME,a)==zo_strformat(SI_UNIT_NAME,b)
    end
    return a:gsub('%^%a+','')==b:gsub('%^%a+','')
end
local function put(unitId,abilityId,expires,origin)
    local critical=S.criticalEffectTypes[abilityId]
    local kind=S.statusEffectTypes[abilityId] or (critical and critical[1])
    if not kind or not validId(unitId) or expires<=GetGameTimeMilliseconds() then return end
    local map=critical and criticalUnits or units
    map[unitId]=map[unitId] or {}
    map[unitId][kind]={id=abilityId,expires=expires,origin=origin}
end
local function remove(unitId,abilityId)
    local critical=S.criticalEffectTypes[abilityId]
    local map=critical and criticalUnits or units
    local effects=map[unitId]
    if effects then
        effects[S.statusEffectTypes[abilityId] or critical[1]]=nil
        if not next(effects) then map[unitId]=nil end
        if not units[unitId] and not criticalUnits[unitId] then durations[unitId]=nil end
    end
end

function S.ResetStatusTracking()
    if S.ResetCriticalBuffDiagnostics then S.ResetCriticalBuffDiagnostics() end
    units,criticalUnits,durations={},{},{}
    currentTargetId=nil
    S.lastTargetSample=nil
    debug={combat=0,effects=0,recent={}}
end
function S.StatusTargetChanged()
    currentTargetId=nil
    S.lastTargetSample=nil
end

function S.OnTrackedEffectChanged(_,change,_,_,unitTag,_,endTime,_,_,_,_,_,_,unitName,unitId,abilityId)
    if unitTag=='reticleover' and change~=EFFECT_RESULT_FADED and validId(unitId) and targetExists()
        and sameUnitName(unitName,GetUnitName('reticleover')) then
        -- Only a game event explicitly assigning a unit ID to reticleover can
        -- establish the binding. Identical NPC names never establish it.
        currentTargetId=unitId
    end
    if not (S.statusEffectTypes[abilityId] or S.criticalEffectTypes[abilityId]) or not validId(unitId) then return end
    if S.statusEffectTypes[abilityId] then note('Effekt',unitId,abilityId) end
    if change==EFFECT_RESULT_FADED then remove(unitId,abilityId)
    elseif endTime and endTime>0 then put(unitId,abilityId,endTime*1000,'effect') end
end

function S.OnTrackedCombatEvent(_,result,isError,_,_,_,_,_,_,targetType,hitValue,_,_,_,_,unitId,abilityId)
    if isError or not (S.statusEffectTypes[abilityId] or S.criticalEffectTypes[abilityId]) or not validId(unitId)
        or targetType==COMBAT_UNIT_TYPE_PLAYER then return end
    if result~=ACTION_RESULT_EFFECT_FADED and result~=ACTION_RESULT_EFFECT_GAINED_DURATION
        and result~=ACTION_RESULT_EFFECT_GAINED then return end
    if S.statusEffectTypes[abilityId] then note('Kampf',unitId,abilityId) end
    if result==ACTION_RESULT_EFFECT_FADED then
        remove(unitId,abilityId)
    elseif result==ACTION_RESULT_EFFECT_GAINED_DURATION and type(hitValue)=='number' and hitValue>0 then
        durations[unitId]=durations[unitId] or {}
        durations[unitId][abilityId]=hitValue
        put(unitId,abilityId,GetGameTimeMilliseconds()+hitValue,'combat')
    elseif result==ACTION_RESULT_EFFECT_GAINED then
        -- A gained event can carry stacks rather than duration. Never interpret
        -- damage or stack values as a lifetime; reuse only a measured duration.
        local duration=durations[unitId] and durations[unitId][abilityId]
        if duration then put(unitId,abilityId,GetGameTimeMilliseconds()+duration,'combat') end
    end
end

function S.GetTargetStatusEffects()
    local now=GetGameTimeMilliseconds()
    if now-lastPrune>=5000 then
        for _,map in ipairs({units,criticalUnits}) do
            for unitId,effects in pairs(map) do
                for kind,entry in pairs(effects) do if entry.expires<=now then effects[kind]=nil end end
                if not next(effects) then map[unitId]=nil end
                if not units[unitId] and not criticalUnits[unitId] then durations[unitId]=nil end
            end
        end
        lastPrune=now
    end
    local result={}
    if not targetExists() or not currentTargetId then return result,nil end
    for kind,entry in pairs(units[currentTargetId] or {}) do
        if entry.expires>now then result[kind]=entry end
    end
    return result,currentTargetId
end

function S.GetTargetCriticalEffects()
    local result={}
    if not targetExists() or not currentTargetId then return result end
    local now=GetGameTimeMilliseconds()
    for kind,entry in pairs(criticalUnits[currentTargetId] or {}) do
        if entry.expires>now then result[kind]=entry end
    end
    return result
end

function S.InitializeStatusTracking()
    local em=EVENT_MANAGER
    S.ResetStatusTracking()
    em:RegisterForEvent(S.name..'StatusTarget',EVENT_RETICLE_TARGET_CHANGED,S.StatusTargetChanged)
    em:RegisterForEvent(S.name..'StatusEffects',EVENT_EFFECT_CHANGED,S.OnTrackedEffectChanged)
    em:RegisterForEvent(S.name..'StatusReset',EVENT_PLAYER_DEACTIVATED,S.ResetStatusTracking)
    local observed={}
    for id in pairs(S.statusEffectTypes) do observed[id]=true end
    for id in pairs(S.criticalEffectTypes) do observed[id]=true end
    for id in pairs(observed) do
        local name=S.name..'StatusCombat'..id
        em:RegisterForEvent(name,EVENT_COMBAT_EVENT,S.OnTrackedCombatEvent)
        em:AddFilterForEvent(name,EVENT_COMBAT_EVENT,REGISTER_FILTER_ABILITY_ID,id)
    end
end
