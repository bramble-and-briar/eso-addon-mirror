local O=ObsidianHUD
local nextScan=0
local byId,byProgression,progressions={},{},{}
local eventCounts={}
local nativeCounts={}
local slotCounts,targetCounts,targetRevisions={},{},{}
local eventRevision=0
local trackedIds,nextTrackedScan={},0
local function ability(slot,bar)
    return O.GetSkillAbilityId and O.GetSkillAbilityId(slot,bar) or GetSlotBoundId(slot,bar)
end
local function counterSource(id)
    return (O.stackSources and O.stackSources[id]) or (O.GetTimerSource and O.GetTimerSource(id)) or id
end
local function tracked(id)
    if O.stackCounterIds and O.stackCounterIds[id] then return true end
    local now=GetFrameTimeSeconds()
    if now>=nextTrackedScan then
        trackedIds={}; nextTrackedScan=now+0.1
        for _,bar in ipairs({HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP}) do
            for slot=3,8 do
                local bound=ability(slot,bar)
                if bound and bound>0 then trackedIds[counterSource(bound)]=true end
            end
        end
    end
    return trackedIds[id] or false
end
local function targetStacks(id,now)
    local instances=targetCounts[id]
    local highest=0
    for key,entry in pairs(instances or {}) do
        if entry.ending and entry.ending<=now then instances[key]=nil
        else highest=math.max(highest,entry.count) end
    end
    if instances and not next(instances) then targetCounts[id]=nil end
    return highest
end
local function progression(id)
    if not GetAbilityProgressionXPInfoFromAbilityId then return nil end
    if progressions[id]~=nil then return progressions[id] or nil end
    local has,index=GetAbilityProgressionXPInfoFromAbilityId(id)
    local result=has and type(index)=="number" and index>0 and index or false
    progressions[id]=result
    return result or nil
end
function O.InvalidateStackEffects()
    nextScan=0; byId={}; byProgression={}
    nextTrackedScan=0
end
function O.ResetStackEffects()
    eventCounts={}; nativeCounts={}; eventRevision=0
    slotCounts,targetCounts,targetRevisions={},{},{}
    O.InvalidateStackEffects()
end

function O.OnSkillStackEffectChanged(_,change,effectSlot,_,unitTag,beginTime,endTime,count,_,_,_,_,_,_,unitId,id,sourceType)
    if not id or not tracked(id) then return end
    if unitTag~="player" then
        if not sourceType or (sourceType~=COMBAT_UNIT_TYPE_PLAYER
            and (not COMBAT_UNIT_TYPE_PLAYER_PET or sourceType~=COMBAT_UNIT_TYPE_PLAYER_PET)) then return end
        local key=tostring(unitId and unitId>0 and unitId or unitTag)..":"..tostring(effectSlot)
        local instances=targetCounts[id] or {}
        local old=instances[key]
        if old and beginTime and beginTime>0 and beginTime<old.began then return end
        if change==EFFECT_RESULT_FADED or type(count)~="number" or count<=0 then
            instances[key]=nil
        else
            instances[key]={count=count,began=beginTime or 0,
                ending=endTime and endTime>(beginTime or 0) and endTime or nil}
        end
        targetCounts[id]=next(instances) and instances or nil
        eventRevision=eventRevision+1; targetRevisions[id]=eventRevision
        if eventCounts[id] and eventCounts[id].count==0 then eventCounts[id]=nil end
        return
    end
    O.InvalidateStackEffects()
    eventRevision=eventRevision+1
    local current=eventCounts[id]
    local now=GetFrameTimeSeconds()
    -- A delayed old gain/fade cannot replace a newer counter, even when ESO
    -- reuses the same effect slot for the refreshed buff.
    if current and beginTime and beginTime>0 and beginTime<current.beginTime then return end
    if change==EFFECT_RESULT_FADED then
        -- Without identifying timestamps a fade remains authoritative.
        eventCounts[id]={count=0,slot=effectSlot,beginTime=beginTime or 0,updated=now,revision=eventRevision}
    elseif type(count)=="number" and count>=0 then
        local ending=endTime and endTime>(beginTime or 0) and endTime or nil
        eventCounts[id]={count=count,ending=ending,slot=effectSlot,beginTime=beginTime or 0,updated=now,revision=eventRevision}
    end
end
function O.OnSkillStackSlotUpdated(_,bar,slot)
    if not slot or slot<3 or slot>8 or not O.OtherBar(bar) then return end
    local key=tostring(bar)..":"..slot
    local id=ability(slot,bar)
    local count=GetActionSlotEffectStackCount and GetActionSlotEffectStackCount(slot,bar) or 0
    local remain=GetActionSlotEffectTimeRemaining and GetActionSlotEffectTimeRemaining(slot,bar) or 0
    if id and id>0 and count>0 and remain>0 then
        slotCounts[key]={id=id,count=count,ending=GetFrameTimeSeconds()+remain/1000}
    else slotCounts[key]=nil end
    O.InvalidateStackEffects()
end
local function refreshEffects()
    local now=GetFrameTimeSeconds()
    if now<nextScan then return end
    nextScan=now+0.1; byId={}; byProgression={}
    if not GetNumBuffs or not GetUnitBuffInfo then return end
    for i=1,GetNumBuffs("player") do
        local _,_,ending,_,count,_,_,_,_,_,id=GetUnitBuffInfo("player",i)
        if id and id>0 and count and count>=0 and (not ending or ending==0 or ending>now) then
            byId[id]=math.max(byId[id] or 0,count)
            local index=progression(id)
            if index then byProgression[index]=math.max(byProgression[index] or 0,count) end
        end
    end
end
function O.GetSkillStackCount(slot,bar)
    local key=tostring(bar)..":"..slot
    local id=ability(slot,bar)
    if not id or id==0 then nativeCounts[key]=nil; slotCounts[key]=nil; return 0 end
    if O.GetSpecialSkillState then
        local _,specialCount=O.GetSpecialSkillState(id)
        if specialCount~=nil then return specialCount end
    end
    local count=GetActionSlotEffectStackCount and GetActionSlotEffectStackCount(slot,bar) or 0
    local now=GetFrameTimeSeconds()
    local cached=slotCounts[key]
    if cached and (cached.id~=id or cached.ending<=now) then slotCounts[key]=nil; cached=nil end
    if count<=0 and cached and bar~=GetActiveHotbarCategory() then count=cached.count end
    local previous=nativeCounts[key]
    local resolved=counterSource(id)
    local source=resolved~=id and resolved or nil
    local latest=eventCounts[source or id]
    local revision=math.max(latest and latest.revision or 0,targetRevisions[source or id] or 0)
    nativeCounts[key]={id=id,count=count,revision=revision}
    if previous and previous.id==id and previous.count>0 and count==0
        and revision<=(previous.revision or 0) then
        -- A real positive -> zero transition must not resurrect old fallback
        -- stacks. Do not treat an initially unavailable native counter as zero.
        eventRevision=eventRevision+1
        eventCounts[source or id]={count=0,beginTime=0,updated=GetFrameTimeSeconds(),revision=eventRevision}
        targetCounts[source or id]=nil; slotCounts[key]=nil
        O.InvalidateStackEffects()
    end
    if count and count>0 then return count end
    local event=eventCounts[source or id]
    if event and event.count==0 then return 0 end
    local target=targetStacks(source or id,now)
    if target>0 then return target end
    refreshEffects()
    if event then
        if event.ending and event.ending<=GetFrameTimeSeconds() then return 0 end
        -- Allow one snapshot interval for ESO's buff list to catch up. Once
        -- this counter has appeared there, its removal must clear the cache
        -- even if no usable fade event followed. Hidden counters stay event based.
        local live=byId[source or id]
        if live~=nil then event.observed=true end
        if event.count>0 and event.observed and GetFrameTimeSeconds()-(event.updated or 0)>=0.1 then
            event.count=live or 0
            if event.count==0 then event.ending=nil end
        end
        return event.count
    end
    if source and byId[source] then return byId[source] end
    if byId[id] then return byId[id] end
    if source then return 0 end -- Do not borrow a different morph's counter.
    local index=progression(id)
    return index and byProgression[index] or 0
end

