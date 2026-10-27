local O=ObsidianHUD
local casts,effects,faded,completed={},{},{},{}
local nextScan=0
local function canonical(id) return O.timerAliases and O.timerAliases[id] or id end
local function timerSource(id)
    if O.GetTimerSource then return O.GetTimerSource(id) end
    return O.timerSources and O.timerSources[id]
end
local function disabled(id)
    local source=timerSource(id)
    return (O.timerDisabled and O.timerDisabled[id]) or
        (O.timerCounterOnly and O.timerCounterOnly[source or id]) or false
end
local function candidates(effectId,began,allowExisting)
    local result={}
    local mappedId,mappedTime
    for _,bar in ipairs({HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP}) do
        for slot=3,8 do
            local raw=GetSlotBoundId(slot,bar)
            local id=canonical(raw)
            if id and id>0 and not disabled(raw) then
                local mapped=timerSource(raw)
                local phase=O.timerPhases and O.timerPhases[effectId]
                if phase and phase.id==id then result[id]=true end
                if effectId==id or effectId==raw or effectId==mapped then
                    -- Shared mapped statuses require evidence of our cast.
                    if effectId==id or effectId==raw then
                        result[id]=true
                    elseif allowExisting and effects[id] and next(effects[id]) then
                        result[id]=true
                    elseif casts[id] and casts[id].used and type(began)=="number"
                        and began>=casts[id].began-0.1
                        and (not O.IsSharedTimerEffect or not O.IsSharedTimerEffect(effectId) or began<=casts[id].began+5)
                        and (not mappedTime or casts[id].began>mappedTime) then
                        mappedId,mappedTime=id,casts[id].began
                    elseif not casts[id] and O.IsSharedTimerEffect and not O.IsSharedTimerEffect(effectId) then
                        result[id]=true
                    end
                end
            end
        end
    end
    if mappedId then result[mappedId]=true end
    return result
end
function O.ResetSkillTimers()
    casts,effects,faded,completed={},{},{},{}
    nextScan=0
end
function O.OnTimerAbilityUsed(_,slot)
    if not slot or slot<3 or slot>8 then return end
    local bar=GetActiveHotbarCategory()
    if not O.OtherBar(bar) then return end
    local raw=GetSlotBoundId(slot,bar)
    if not raw or raw<=0 or disabled(raw) then return end
    local id=canonical(raw)
    if IsAbilityDurationToggled and IsAbilityDurationToggled(raw) then return end
    local now=GetFrameTimeSeconds()
    local duration=GetAbilityDuration and GetAbilityDuration(raw) or 0
    local channeled=GetAbilityCastInfo and GetAbilityCastInfo(raw) or false
    -- Like FAB, ordinary casts record activation, not a guessed tooltip timer.
    -- Only explicitly supported on-use cases can start a timer at activation.
    local onUse=O.timerOnUse and O.timerOnUse[raw]
    local estimate=not channeled and (onUse or (O.timerSummons and O.timerSummons[id]))
    if type(onUse)=="number" then
        local childDuration=GetAbilityDuration and GetAbilityDuration(timerSource(raw) or raw) or 0
        duration=type(childDuration)=="number" and childDuration>0 and childDuration or onUse*1000
    end
    local ending=estimate and type(duration)=="number" and duration>0 and now+duration/1000 or 0
    casts[id]={began=now,ending=ending,used=true}
    -- An ordinary recast does not erase the still-running old effect before
    -- the new projectile/effect arrives. Special placement starts a new phase.
    if estimate then effects[id]=nil end
    faded[id],completed[id]=nil,nil
    nextScan=0
end
local function record(id,key,began,ending,unitTag,snapshot)
    local now=GetFrameTimeSeconds()
    if type(began)~="number" or type(ending)~="number" or ending<=now or ending<=began then return end
    local cast=casts[id]
    if (completed[id] and began<=completed[id]) or (cast and began<cast.began-0.1)
        or (unitTag=="player" and faded[id] and began<=faded[id]) then return end
    local instances=effects[id] or {}
    effects[id]=instances
    local old=instances[key]
    if old and old.began>began then return end
    -- One observed status instance cannot be attributed to two different
    -- slotted skills just because both can grant that same buff.
    for other,otherInstances in pairs(effects) do
        if other~=id and otherInstances[key] and otherInstances[key].began<=began then
            otherInstances[key]=nil
        end
    end
    instances[key]={began=began,ending=ending,self=unitTag=="player",snapshot=snapshot}
    if cast then cast.ending=0; cast.nativeEnd=nil end
    return true
end
function O.OnTimerEffectChanged(_,change,effectSlot,_,unitTag,began,ending,_,_,_,_,_,_,_,unitId,effectId,source)
    if source~=COMBAT_UNIT_TYPE_PLAYER or not effectId or effectId<=0 then return end
    local now=GetFrameTimeSeconds()
    if change~=EFFECT_RESULT_FADED and began==0 then began=now end
    local key=tostring(unitId or unitTag)..":"..tostring(effectSlot)..":"..effectId
    for id in pairs(candidates(effectId,began,change==EFFECT_RESULT_FADED)) do
        local instances=effects[id] or {}
        local rule=O.timerPhases and O.timerPhases[effectId]
        local cast=casts[id]
        local oldPhase=cast and cast.phase or 0
        if rule and (rule.phase<oldPhase or (cast and type(began)=="number" and began>0 and began<cast.began-0.1)) then
            -- Late fade/gain from phase one must not destroy phase two.
        elseif change==EFFECT_RESULT_FADED then
            local old=instances[key]
            if not (old and began and began>0 and began<old.began) then
                instances[key]=nil
                local cast=casts[id]
                if cast and (not began or began<=0 or began>=cast.began-0.05) then
                    cast.ending=0; cast.nativeEnd=nil
                end
                if unitTag=="player" then
                    faded[id]=began and began>0 and began or now
                    for k,effect in pairs(instances) do
                        if effect.self and effect.began<=faded[id] then instances[k]=nil end
                    end
                end
            end
        else
            if rule then
                if not cast then casts[id]={began=began,ending=0}; cast=casts[id] end
                if rule.phase>oldPhase then effects[id]=nil end
                cast.phase=rule.phase
                if rule.seconds then ending=now+rule.seconds end
            end
            record(id,key,began,ending,unitTag,false)
        end
    end
    nextScan=0
end
local function scan(now)
    if now<nextScan then return end
    nextScan=now+0.1
    for id,instances in pairs(effects) do
        for key,effect in pairs(instances) do
            if effect.ending<=now or effect.snapshot then instances[key]=nil end
        end
        if not next(instances) then effects[id]=nil end
    end
    if not GetNumBuffs or not GetUnitBuffInfo then return end
    local seenSelf={}
    for i=1,GetNumBuffs("player") do
        local _,began,ending,buffSlot,_,_,_,_,_,_,effectId,_,own=GetUnitBuffInfo("player",i)
        if own and effectId and effectId>0 then
            for id in pairs(candidates(effectId,began)) do
                local phase=O.timerPhases and O.timerPhases[effectId]
                local cast=casts[id]
                -- A snapshot of the parent's total duration must not replace
                -- the explicit current phase (e.g. the next Shalk explosion).
                if not (phase and cast and cast.phase) then
                    if record(id,"snapshot:"..tostring(buffSlot)..":"..effectId,began,ending,"player",true) then seenSelf[id]=true end
                end
            end
        end
    end
    for id,instances in pairs(effects) do
        for key,effect in pairs(instances) do
            if effect.self and not effect.snapshot then
                if effect.observed and not seenSelf[id] then instances[key]=nil
                elseif seenSelf[id] then effect.observed=true end
            end
        end
    end
end
function O.OnTimerSlotEffectUpdated(_,bar,slot)
    -- ESO announces effect changes separately from skill activation. Refresh
    -- the own-effect snapshot on that event; never manufacture a cast timer.
    if slot and slot>=3 and slot<=8 and O.OtherBar(bar) then nextScan=0 end
end
function O.OnTimerCombatEvent(_,result,isError,_,_,_,_,source,_,_,_,_,_,_,_,_,effectId)
    if isError or (source~=COMBAT_UNIT_TYPE_PLAYER and source~=COMBAT_UNIT_TYPE_PLAYER_PET) then return end
    local impact=result==ACTION_RESULT_DAMAGE or result==ACTION_RESULT_CRITICAL_DAMAGE
        or (ACTION_RESULT_BLOCKED_DAMAGE and result==ACTION_RESULT_BLOCKED_DAMAGE)
        or (ACTION_RESULT_DAMAGE_SHIELDED and result==ACTION_RESULT_DAMAGE_SHIELDED)
        or (ACTION_RESULT_IMMUNE and result==ACTION_RESULT_IMMUNE)
    if not impact then return end
    local id=O.timerExplosions and O.timerExplosions[effectId]
    if not id or not casts[id] then return end
    casts[id].ending=0; casts[id].nativeEnd=nil
    effects[id]=nil; completed[id]=GetFrameTimeSeconds()
end
function O.GetSkillTimerRemaining(slot,bar)
    if slot<3 or slot>8 or not O.OtherBar(bar) then return 0 end
    local raw=GetSlotBoundId(slot,bar)
    if not raw or raw<=0 or disabled(raw) then return 0 end
    local id=canonical(raw)
    local now=GetFrameTimeSeconds()
    -- Completed summons cannot restart from a late debuff/native cooldown.
    if completed[id] then return 0 end
    scan(now)
    local ending=0
    for _,effect in pairs(effects[id] or {}) do ending=math.max(ending,effect.ending) end
    -- Configured effect/phase timing takes priority over the parent button's
    -- duration, which may describe a different proc or placement phase.
    if ending>now then return (ending-now)*1000 end
    local cast=casts[id]
    local onUse=O.timerOnUse and O.timerOnUse[raw]
    if cast and cast.ending>now then return (cast.ending-now)*1000 end
    if (timerSource(raw) or onUse or (O.timerPhases and O.timerPhases[raw]))
        and not (O.timerSummons and O.timerSummons[id]) then return 0 end
    local native=GetActionSlotEffectTimeRemaining and GetActionSlotEffectTimeRemaining(slot,bar) or 0
    if native and native>0 then
        casts[id]=cast or {began=now,ending=0}
        casts[id].ending=0; casts[id].nativeEnd=now+native/1000
        return native
    end
    if cast and cast.nativeEnd then
        -- An authoritative positive -> zero ends the native effect. Neither
        -- old snapshots nor the earlier cast estimate may restart it.
        cast.nativeEnd=nil; cast.ending=0; effects[id]=nil
        faded[id]=now
    end
    return 0
end
