local O=ObsidianHUD
local nextScan=0
local byId,byProgression,progressions={},{},{}
local eventCounts={}
local nativeCounts={}
local eventRevision=0
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
end
function O.ResetStackEffects()
    eventCounts={}; nativeCounts={}; eventRevision=0
    O.InvalidateStackEffects()
end

function O.OnSkillStackEffectChanged(_,change,effectSlot,_,unitTag,beginTime,endTime,count,_,_,_,_,_,_,_,id)
    if unitTag~="player" then return end
    O.InvalidateStackEffects()
    if not O.stackCounterIds[id] then return end
    eventRevision=eventRevision+1
    local current=eventCounts[id]
    local now=GetFrameTimeSeconds()
    if change==EFFECT_RESULT_FADED then
        -- A same-slot fade (including missing timestamps) is authoritative.
        -- Ignore only an identifiable older, different-slot instance.
        if current and effectSlot and effectSlot>0 and current.slot~=effectSlot
            and beginTime and beginTime>0 and beginTime<current.beginTime then return end
        eventCounts[id]={count=0,slot=effectSlot,beginTime=beginTime or 0,updated=now,revision=eventRevision}
    elseif type(count)=="number" and count>=0 then
        local ending=endTime and endTime>(beginTime or 0) and endTime or nil
        eventCounts[id]={count=count,ending=ending,slot=effectSlot,beginTime=beginTime or 0,updated=now,revision=eventRevision}
    end
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
    local id=GetSlotBoundId(slot,bar)
    if not id or id==0 then nativeCounts[key]=nil; return 0 end
    local count=GetActionSlotEffectStackCount and GetActionSlotEffectStackCount(slot,bar) or 0
    local previous=nativeCounts[key]
    local source=O.stackSources and O.stackSources[id]
    local latest=eventCounts[source or id]
    local revision=latest and latest.revision or 0
    nativeCounts[key]={id=id,count=count,revision=revision}
    if previous and previous.id==id and previous.count>0 and count==0
        and revision<=(previous.revision or 0) then
        -- A real positive -> zero transition must not resurrect old fallback
        -- stacks. Do not treat an initially unavailable native counter as zero.
        eventRevision=eventRevision+1
        eventCounts[source or id]={count=0,beginTime=0,updated=GetFrameTimeSeconds(),revision=eventRevision}
        O.InvalidateStackEffects()
    end
    if count and count>0 then return count end
    local event=eventCounts[source or id]
    if event and event.count==0 then return 0 end
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

function O.PreviewSkillStacks()
    O.stackPreviewUntil=GetFrameTimeSeconds()+15
    O.Refresh()
    d("Obsidian HUD: Stack-Vorschau fuer 15 Sekunden: Testzahl 3. Menue schliessen, um die Position zu pruefen.")
end
