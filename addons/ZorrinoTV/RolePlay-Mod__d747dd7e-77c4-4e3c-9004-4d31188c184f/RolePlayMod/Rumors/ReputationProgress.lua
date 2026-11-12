if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Completed, non-repeatable quests determine local/region reputation points.
-- Catalogue scope is explicit: no invented city membership or unknown totals.
local B=IHR_Runtime.Beta
local P=B.Personality
local catalogue,cache,cacheTime
local function norm(s) return B.Normalize(s or ''):gsub('^le ',''):gsub('^la ',''):gsub('^les ','') end
local function standard(id)
    local db=IHR_QuestRumorDB;local meta=db.meta[id]
    return meta and tonumber(meta[2])==0 and not (db.removed or {})[id] and not (IHR_CharacterData.questGroups or {})[id]
end
local function insert(groups,group,id)
    if not group then return end
    groups[group]=groups[group] or {};groups[group][id]=true
end
local function build()
    local result={regions={},cities={}}
    if type(GetQuestZoneId)=='function' and type(GetZoneIndex)=='function' then
        for id in pairs(IHR_QuestRumorDB.meta) do if standard(id) then
            local zone=GetQuestZoneId(id)
            if zone and zone>0 then
                local index=GetZoneIndex(zone)
                if index and index>0 then insert(result.regions,B.SocialZone({zoneIndex=index}),id) end
            end
        end end
    end
    local locations=IHR_TavernRumorLocations or {};local byQuest={}
    for map,starts in pairs(locations.starts or {}) do
        local family=(locations.familyByMap or {})[map]
        if family and (locations.cityMaps or {})[map] then
            for entry in pairs(starts) do
                local id=tonumber(entry:match('^(%d+):'))
                if id and standard(id) then
                    if byQuest[id]==nil then byQuest[id]=family elseif byQuest[id]~=family then byQuest[id]=false end
                end
            end
        end
    end
    -- Starts recorded in several cities do not establish a unique city's story.
    for id,family in pairs(byQuest) do if family then insert(result.cities,family,id) end end
    return result
end
local function stages()
    B.saved.reputationStages114=B.saved.reputationStages114 or {}
    return B.saved.reputationStages114
end
local function observe(index)
    if not B.saved or type(GetJournalQuestId)~='function' or type(IsValidQuestIndex)~='function' or not IsValidQuestIndex(index) then return end
    local id=GetJournalQuestId(index);if not id or not standard(id) then return end
    local parts={}
    if type(GetJournalQuestNumSteps)~='function' then return end
    for step=1,GetJournalQuestNumSteps(index) do
        local _,visibility,_,_,count=GetJournalQuestStepInfo(index,step)
        if visibility~=QUEST_STEP_VISIBILITY_HIDDEN then
            for condition=1,count or 0 do
                local text,_,_,fail,done,_,visible=GetJournalQuestConditionInfo(index,step,condition,false)
                if visible and not fail and not done and text and text~='' then parts[#parts+1]=text end
            end
        end
    end
    local signature=table.concat(parts,'|');if signature=='' then return end
    local all=stages();local record=all[id]
    if not record then all[id]={initial=signature,advanced=false}
    elseif record.initial~=signature then record.advanced=true end
end
local function progress(ids,label)
    local total,completed,advanced=0,0,0
    for id in pairs(ids or {}) do
        total=total+1
        if type(HasCompletedQuest)=='function' and HasCompletedQuest(id) then completed=completed+1
        elseif B.saved and stages()[id] and stages()[id].advanced then advanced=advanced+1 end
    end
    return {total=total,completed=completed,advanced=advanced,points=total>0 and 20*(completed+advanced*.5)/total or 0,label=label}
end
function P.InvalidateReputationProgress(rebuild)
    local S=RolePlayMod.Speechcraft
    if S and S.InvalidateSocialReport then S.InvalidateSocialReport() end
    cache=nil;cacheTime=nil;if rebuild then catalogue=nil end
end
local invalidate=P.InvalidateReputation
function P.InvalidateReputation(...)
    P.InvalidateReputationProgress();return invalidate(...)
end
function P.ReputationProgress(npc)
    if not B.saved or B.saved.reputationEnabled==false then return {points=0,region=progress(nil,'désactivée')} end
    catalogue=catalogue or build()
    local now=GetTimeStamp()
    if not cache or not cacheTime or now-cacheTime>=60 then
        for index=1,MAX_JOURNAL_QUESTS or 25 do observe(index) end
        cache={regions={},cities={}}
        for region,ids in pairs(catalogue.regions) do cache.regions[region]=progress(ids,region) end
        for city,ids in pairs(catalogue.cities) do cache.cities[city]=progress(ids,city) end
        cacheTime=now
    end
    local zone,zoneName=B.SocialZone(npc)
    local region=cache.regions[zone] or progress(nil,zoneName)
    local city,cityKey;local locality=' '..norm(npc.locality)..' '
    for family,aliases in pairs((IHR_TavernRumorLocations or {}).towns or {}) do
        for _,alias in ipairs(aliases) do
            local name=norm(alias)
            if name~='' and locality:find(' '..name..' ',1,true) and (not cityKey or #family>#cityKey) then cityKey=family end
        end
    end
    if cityKey then city=cache.cities[cityKey] end
    local p=P.Profile(npc);local clan
    for _,rule in ipairs((RolePlayMod.Speechcraft or {}).CommunityRecognitionRules or {}) do
        if p.groups and p.groups[rule.group] then
            local ids={};for _,id in ipairs(rule.quests) do if standard(id) then ids[id]=true end end
            local value=progress(ids,rule.label)
            if not clan or value.points>clan.points then clan=value end
        end
    end
    return {region=region,city=city,clan=clan,points=math.max(region.points,city and city.points or 0,clan and clan.points or 0)}
end
function P.ReputationSensitivity(npc)
    local p=P.Profile(npc);local doc=p.doc;local custom=doc and doc.speechcraft or {}
    local value=custom.reputationSensitivity
    if P.Kind(p)=='radical' then return 0 end
    if value==nil then value=P.Kind(p)=='amical' and 1 or doc and doc.service and doc.service~='' and 1 or p.traditional and .25 or p.neutral and .75 or .5 end
    return math.max(0,math.min(1,tonumber(value) or .5))
end

for _,event in ipairs({EVENT_QUEST_ADDED or false,EVENT_QUEST_ADVANCED or false,EVENT_QUEST_CONDITION_COUNTER_CHANGED or false,EVENT_QUEST_REMOVED or false}) do
    if event then EVENT_MANAGER:RegisterForEvent('RPMReputationProgress114'..event,event,function(_,index)
        if type(index)=='number' then observe(index) end
        P.InvalidateReputationProgress()
    end) end
end
