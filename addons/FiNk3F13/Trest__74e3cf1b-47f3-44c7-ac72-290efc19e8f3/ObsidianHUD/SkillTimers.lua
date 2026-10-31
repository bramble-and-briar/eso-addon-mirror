local O=ObsidianHUD
local casts,effects,faded,completed={},{},{},{}
local slotTimes={}
local retired={}
local nextScan=0
local function ability(slot,bar)
    return O.GetSkillAbilityId and O.GetSkillAbilityId(slot,bar) or GetSlotBoundId(slot,bar)
end
local function canonical(id) return O.timerAliases and O.timerAliases[id] or id end
local function timerSource(id)
    local base=canonical(id)
    if O.GetTimerSource then return O.GetTimerSource(id) or O.GetTimerSource(base) end
    return O.timerSources and (O.timerSources[id] or O.timerSources[base])
end
local function disabled(id)
    local source=timerSource(id)
    return (O.timerDisabled and O.timerDisabled[id]) or
        (O.timerCounterOnly and O.timerCounterOnly[source or id]) or false
end
local function candidates(effectId,began,allowExisting)
    local result={}
    local effectBase=canonical(effectId)
    local mappedId,mappedTime
    for _,bar in ipairs({HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP}) do
        for slot=3,8 do
            local raw=ability(slot,bar)
            local id=canonical(raw)
            if id and id>0 and not disabled(raw) then
                local mapped=timerSource(raw)
                local phase=O.timerPhases and O.timerPhases[effectId]
                if phase and phase.id==id then result[id]=true end
                if effectBase==id or effectId==id or effectId==raw or effectId==mapped then
                    -- Shared mapped statuses require evidence of our cast.
                    if effectBase==id or effectId==id or effectId==raw then
                        result[id]=true
                    elseif allowExisting and effects[id] and next(effects[id]) then
                        result[id]=true
                    elseif casts[id] and casts[id].used and type(began)=="number"
                        and began>=casts[id].began-0.1
                        and (not O.IsSharedTimerEffect or not O.IsSharedTimerEffect(effectId) or began<=casts[id].began+5)
                        and (not mappedTime or casts[id].began>mappedTime) then
                        mappedId,mappedTime=id,casts[id].began
                    elseif not (casts[id] and casts[id].used) and O.IsSharedTimerEffect and not O.IsSharedTimerEffect(effectId) then
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
    if O.ResetSpecialSkillEffects then O.ResetSpecialSkillEffects() end
    casts,effects,faded,completed={},{},{},{}
    slotTimes={}
    retired={}
    nextScan=0
end
function O.OnTimerAbilityUsed(_,slot)
    if not slot or slot<3 or slot>8 then return end
    local bar=GetActiveHotbarCategory()
    if not O.OtherBar(bar) then return end
    local raw=ability(slot,bar)
    if not raw or raw<=0 or disabled(raw) then return end
    local id=canonical(raw)
    if O.OnSpecialSkillUsed then O.OnSpecialSkillUsed(id) end
    local onUse=O.timerOnUse and (O.timerOnUse[raw] or O.timerOnUse[id])
    if not onUse and IsAbilityDurationToggled and IsAbilityDurationToggled(raw) then return end
    local now=GetFrameTimeSeconds()
    local duration=GetAbilityDuration and GetAbilityDuration(raw) or 0
    if (type(duration)~="number" or duration<=0) and id~=raw and GetAbilityDuration then
        duration=GetAbilityDuration(id)
    end
    local channeled=GetAbilityCastInfo and GetAbilityCastInfo(raw) or false
    -- Like FAB, ordinary casts record activation, not a guessed tooltip timer.
    -- Only explicitly supported on-use cases can start a timer at activation.
    local child=O.timerUseChildDuration and O.timerUseChildDuration[id]
    if child then
        local actual=GetAbilityDuration and GetAbilityDuration(child) or 0
        if type(actual)=="number" and actual>0 then duration=actual end
    end
    -- Explicit activation rules also apply to tether skills whose metadata
    -- describes a channel/toggle even though their effect runs independently.
    local estimate=onUse or (not channeled and O.timerSummons and O.timerSummons[id])
    if type(onUse)=="number" then
        local childDuration=GetAbilityDuration and GetAbilityDuration(timerSource(raw) or raw) or 0
        duration=type(childDuration)=="number" and childDuration>0 and childDuration or onUse*1000
    end
    local ending=estimate and type(duration)=="number" and duration>0 and now+duration/1000 or 0
    local previous=casts[id]
    local replacing=previous and previous.ending>now or false
    local oldInstances={}
    for key,entry in pairs(effects[id] or {}) do
        if entry.ending>now then
            replacing=true
            oldInstances[key]={began=entry.began,ending=entry.ending,
                effectId=entry.effectId,snapshot=entry.snapshot,self=entry.self}
        end
    end
    retired[id]=next(oldInstances) and oldInstances or nil
    casts[id]={began=now,ending=ending,used=true,replacing=replacing}
    -- An ordinary recast does not erase the still-running old effect before
    -- the new projectile/effect arrives. Special placement starts a new phase.
    if estimate then effects[id]=nil end
    faded[id],completed[id]=nil,nil
    nextScan=0
    if O.RefreshSkillTimerText then O.RefreshSkillTimerText() end
end
local function record(id,key,began,ending,unitTag,snapshot,effectId)
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
    instances[key]={began=began,ending=ending,self=unitTag=="player",snapshot=snapshot,effectId=effectId}
    for slotKey,saved in pairs(slotTimes) do
        if canonical(saved.id)==id then slotTimes[slotKey]=nil end
    end
    if cast then cast.ending=0; cast.nativeEnd=nil; cast.replacing=false end
    return true
end
function O.OnTimerEffectChanged(_,change,effectSlot,_,unitTag,began,ending,_,_,_,_,_,_,_,unitId,effectId,source)
    if (source~=COMBAT_UNIT_TYPE_PLAYER and (not COMBAT_UNIT_TYPE_PLAYER_PET or source~=COMBAT_UNIT_TYPE_PLAYER_PET))
        or not effectId or effectId<=0 then return end
    if O.OnSpecialSkillEffect and O.OnSpecialSkillEffect(change,effectSlot,unitTag,began,ending,unitId,effectId) then return end
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
            local prior=retired[id] and retired[id][key]
            if not prior and unitTag=="player" then
                for _,entry in pairs(retired[id] or {}) do
                    if entry.snapshot and entry.effectId==effectId then prior=entry; break end
                end
            end
            local hasBegin=type(began)=="number" and began>0
            local oldFade=prior and ((hasBegin and began<=prior.began)
                or (not hasBegin and (not ending or ending<=0 or math.abs(ending-prior.ending)<0.05)))
            if oldFade then
                for retiredKey,entry in pairs(retired[id]) do
                    if retiredKey==key or (entry.snapshot and entry.effectId==prior.effectId
                        and math.abs(entry.began-prior.began)<0.05
                        and math.abs(entry.ending-prior.ending)<0.05) then retired[id][retiredKey]=nil end
                end
                if old and old.began<=prior.began then instances[key]=nil end
            elseif not hasBegin and not old and cast and cast.replacing then
                -- Recasting can fade the previous effect with no timestamps
                -- before the replacement gain arrives. This is not evidence
                -- that the newly started activation has already ended.
            elseif not (old and hasBegin and began<old.began) then
                local fadedBegin=hasBegin and began or (old and old.began)
                instances[key]=nil
                for otherKey,entry in pairs(instances) do
                    if string.sub(otherKey,1,7)=="combat:" and entry.effectId==effectId
                        and (not fadedBegin or entry.began<=fadedBegin) then instances[otherKey]=nil end
                end
                for slotKey,saved in pairs(slotTimes) do
                    if canonical(saved.id)==id then slotTimes[slotKey]=nil end
                end
                local cast=casts[id]
                if cast and (not fadedBegin or fadedBegin>=cast.began-0.05) then
                    cast.ending=0; cast.nativeEnd=nil
                end
                if unitTag=="player" then
                    faded[id]=fadedBegin or now
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
            record(id,key,began,ending,unitTag,false,effectId)
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
                    if record(id,"snapshot:"..tostring(buffSlot)..":"..effectId,began,ending,"player",true,effectId) then seenSelf[id]=true end
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
    if slot and slot>=3 and slot<=8 and O.OtherBar(bar) then
        nextScan=0
        local id=ability(slot,bar)
        local remain=GetActionSlotEffectTimeRemaining and GetActionSlotEffectTimeRemaining(slot,bar) or 0
        local key=tostring(bar)..":"..slot
        if id and id>0 and remain>0 then
            slotTimes[key]={id=id,ending=GetFrameTimeSeconds()+remain/1000}
        else
            slotTimes[key]=nil
        end
    end
end
function O.OnTimerCombatEvent(_,result,isError,_,_,_,_,source,_,target,_,_,_,_,_,_,effectId)
    if O.OnSpecialSkillCombat then O.OnSpecialSkillCombat(result,isError,target,effectId) end
    if isError or (source~=COMBAT_UNIT_TYPE_PLAYER and source~=COMBAT_UNIT_TYPE_PLAYER_PET) then return end
    local rule=O.timerCombatRules and O.timerCombatRules[effectId]
    if rule and (not rule.result or (_G[rule.result] and result==_G[rule.result]))
        and (not ACTION_RESULT_EFFECT_FADED or result~=ACTION_RESULT_EFFECT_FADED) then
        local now=GetFrameTimeSeconds()
        local id=rule.id or effectId
        local duration=rule.seconds and rule.seconds*1000 or (GetAbilityDuration and GetAbilityDuration(id) or 0)
        if duration>0 then
            for candidate in pairs(candidates(id,now)) do
                record(candidate,"combat:"..id,now,now+duration/1000,nil,false,effectId)
            end
        end
    end
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
    local raw=ability(slot,bar)
    if not raw or raw<=0 or disabled(raw) then return 0 end
    local id=canonical(raw)
    local now=GetFrameTimeSeconds()
    if O.GetSpecialSkillState then
        local remaining=O.GetSpecialSkillState(id)
        if remaining~=nil then return remaining end
    end
    -- Completed summons cannot restart from a late debuff/native cooldown.
    if completed[id] then return 0 end
    scan(now)
    local ending=0
    for _,effect in pairs(effects[id] or {}) do ending=math.max(ending,effect.ending) end
    -- Configured effect/phase timing takes priority over the parent button's
    -- duration, which may describe a different proc or placement phase.
    if ending>now then return (ending-now)*1000 end
    local cast=casts[id]
    local onUse=O.timerOnUse and (O.timerOnUse[raw] or O.timerOnUse[id])
    if cast and cast.ending>now then return (cast.ending-now)*1000 end
    -- A mapped effect ID does not invalidate ESO's own per-slot effect timer.
    -- Use that authoritative duration when no own event/snapshot was seen.
    -- Explicit placement/phase rules still must not borrow a parent timer.
    if (onUse or (O.timerPhases and O.timerPhases[raw]))
        and not (O.timerSummons and O.timerSummons[id])
        and not (O.wallStaffSkills and O.wallStaffSkills[raw]) then return 0 end
    local native=GetActionSlotEffectTimeRemaining and GetActionSlotEffectTimeRemaining(slot,bar) or 0
    local key=tostring(bar)..":"..slot
    local saved=slotTimes[key]
    if saved and (saved.id~=raw or saved.ending<=now) then slotTimes[key]=nil; saved=nil end
    if native and native>0 then
        slotTimes[key]={id=raw,ending=now+native/1000}
        casts[id]=cast or {began=now,ending=0}
        casts[id].ending=0; casts[id].nativeEnd=now+native/1000
        return native
    end
    -- Some clients return zero for an inactive slot between effect updates.
    -- Continue its last observed slot duration; an explicit zero event, expiry,
    -- ability replacement or a zero on the active bar clears that observation.
    if bar~=GetActiveHotbarCategory() and saved then return (saved.ending-now)*1000 end
    slotTimes[key]=nil
    if cast and cast.nativeEnd then
        -- An authoritative positive -> zero ends the native effect. Neither
        -- old snapshots nor the earlier cast estimate may restart it.
        cast.nativeEnd=nil; cast.ending=0; effects[id]=nil
        faded[id]=now
    end
    return 0
end

