-- Local reputation belongs to documented residents, not everyone passing through.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local P=B.Personality
local S=R.Speechcraft
local C={version=1,byId={},byName={},byRegion={},questSets={}}
B.Communities=C
local function norm(s)
    return B.Normalize(B.Name(type(s)=='string' and s or '')):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ','')
end
local function contains(text,word)
    return word~='' and (' '..text..' '):find(' '..word..' ',1,true)~=nil
end
local function add(index,key,value)
    if key=='' then return end
    index[key]=index[key] or {};index[key][#index[key]+1]=value
end
for _,row in ipairs(RPM_CommunityDataFR.communities) do
    row.regionKey=norm(row.region);row.aliasKeys={}
    for _,name in ipairs(row.aliases) do row.aliasKeys[#row.aliasKeys+1]=norm(name) end
    C.byId[row.id]=row;add(C.byRegion,row.regionKey,row)
    C.questSets[row.id]={};for id in pairs(row.quests) do C.questSets[row.id][id]=true end
    for name,sites in pairs(row.members) do
        local entry={community=row,sites={}}
        for _,site in ipairs(sites) do entry.sites[#entry.sites+1]=norm(site) end
        add(C.byName,norm(name),entry)
    end
end
local function regionName(npc)
    return norm(select(2,B.SocialZone(npc)))
end
local function localMatch(row,locality)
    for _,key in ipairs(row.aliasKeys) do if contains(locality,key) then return true end end
    return false
end
function C.Locality(npc)
    if not npc then return end
    local found;local locality=norm(npc.locality)
    for _,row in ipairs(C.byRegion[regionName(npc)] or {}) do
        if localMatch(row,locality) then if found and found~=row then return end;found=row end
    end
    return found
end
function C.Resolve(npc)
    if not npc then return end
    local entries=C.byName[norm(npc.name)]
    if not entries then return end
    local region,locality=regionName(npc),norm(npc.locality)
    if region=='' or locality=='' then return end
    local found
    for _,entry in ipairs(entries) do
        local row=entry.community
        if row.regionKey==region then
            local matches=localMatch(row,locality)
            for _,site in ipairs(entry.sites) do if locality==site then matches=true end end
            if matches then if found and found~=row then return end;found=row end
        end
    end
    return found
end
local function saved()
    if not B.saved then return end
    B.saved.communities122=B.saved.communities122 or {locations={}}
    local data=B.saved.communities122;data.locations=data.locations or {}
    return data
end
local function standard(id)
    local db=IHR_QuestRumorDB or {};local meta=(db.meta or {})[id]
    return meta and tonumber(meta[2])==0 and not (db.removed or {})[id]
        and not (IHR_CharacterData.questGroups or {})[id]
end
local invalidate=P.InvalidateReputationProgress
function P.InvalidateReputationProgress(...) return invalidate(...) end
local function changed()
    P.InvalidateReputationProgress()
end
function C.BindNative(id,zone,objective,zoneIndex,poiIndex)
    if not saved() or not standard(id) then return end
    local region=norm(zone)
    if not C.byRegion[region] and type(zoneIndex)=='number' and zoneIndex>0 then region=regionName({zoneIndex=zoneIndex}) end
    -- POI is the quest's native location metadata, not a target from its prose.
    if (not objective or objective=='') and type(GetPOIInfo)=='function' and
        type(zoneIndex)=='number' and zoneIndex>0 and type(poiIndex)=='number' and poiIndex>0 then
        objective=GetPOIInfo(zoneIndex,poiIndex)
    end
    local key=norm(objective);local found
    for _,row in ipairs(C.byRegion[region] or {}) do
        for _,alias in ipairs(row.aliasKeys) do if key==alias then
            if found and found~=row then return end;found=row
        end end
    end
    if not found or found.excludedQuests[id] then return end
    local data=saved();local old=data.locations[id]
    if old==false then return end
    if old and old~=found.id then
        -- Moving quest/ambiguous association: only explicit beneficiary bindings survive.
        if C.questSets[old] and not C.byId[old].quests[id] then C.questSets[old][id]=nil end
        data.locations[id]=false;changed();return
    end
    data.locations[id]=found.id
    if not C.questSets[found.id][id] then C.questSets[found.id][id]=true;changed() end
    return found
end
local function restoreLocations()
    local data=saved();if not data then return end
    if C.restored==data then return end
    C.restored=data
    -- A character change must not inherit another character's observed POIs.
    for id,row in pairs(C.byId) do
        C.questSets[id]={};for quest in pairs(row.quests) do C.questSets[id][quest]=true end
    end
    for id,community in pairs(data.locations) do
        local row=C.byId[community]
        if row and standard(id) and not row.excludedQuests[id] then C.questSets[community][id]=true end
    end
end
function C.ObserveActive()
    if not saved() or type(GetJournalQuestLocationInfo)~='function' or
        type(GetJournalQuestId)~='function' or type(IsValidQuestIndex)~='function' then return end
    for index=1,MAX_JOURNAL_QUESTS or 25 do if IsValidQuestIndex(index) then
        local id=GetJournalQuestId(index)
        if id and standard(id) then C.BindNative(id,GetJournalQuestLocationInfo(index)) end
    end end
end
function C.ObserveCompleted(id)
    if type(GetCompletedQuestLocationInfo)~='function' or not standard(id) then return end
    return C.BindNative(id,GetCompletedQuestLocationInfo(id))
end
-- Bounded background scan, never a full quest-history walk on wheel opening.
function C.ScanStep()
    if type(GetNextCompletedQuestId)~='function' or not saved() then C.scanning=false;return 0,true end
    local count=0
    while count<40 do
        local id=GetNextCompletedQuestId(C.cursor)
        if not id or id==0 or id==C.cursor then C.scanning=false;return count,true end
        C.cursor=id;count=count+1;C.ObserveCompleted(id)
    end
    return count,false
end
function C.Refresh()
    restoreLocations();C.ObserveActive()
    if S.InvalidateSocialReport then S.InvalidateSocialReport() end
end
function C.StartScan()
    C.Refresh();C.cursor=nil;C.scanning=true
    if not EVENT_MANAGER or type(EVENT_MANAGER.RegisterForUpdate)~='function' then return end
    EVENT_MANAGER:RegisterForUpdate('RPMCommunityHistory122',100,function()
        local _,done=C.ScanStep()
        if done then EVENT_MANAGER:UnregisterForUpdate('RPMCommunityHistory122') end
    end)
end
function C.Progress(row)
    local completed,advanced,total=0,0,0
    for id in pairs(C.questSets[row.id] or {}) do if standard(id) and not row.excludedQuests[id] then
        total=total+1
        if type(HasCompletedQuest)=='function' and HasCompletedQuest(id) then completed=completed+1
        elseif B.saved and B.saved.reputationStages114 and B.saved.reputationStages114[id]
            and B.saved.reputationStages114[id].advanced then advanced=advanced+1 end
    end end
    return {id=row.id,label=row.name,kind=row.kind,total=total,completed=completed,advanced=advanced,
        points=math.min(20,4*completed+2*advanced),basis='known-local-actions',exhaustive=false}
end
local progress=P.ReputationProgress
function P.ReputationProgress(npc)
    local previous=progress(npc)
    if not B.saved or B.saved.reputationEnabled==false then return previous end
    restoreLocations()
    local row=C.Resolve(npc);local localSite=C.Locality(npc)
    if not row and not localSite then return previous end -- Keep uncatalogued legacy cities.
    local result={};for key,value in pairs(previous) do result[key]=value end
    -- Proximity alone must not leak the legacy city's/clan's collective reward.
    result.city=nil;result.clan=nil
    if row then result.community=C.Progress(row) end
    result.points=math.max(result.region and result.region.points or 0,result.community and result.community.points or 0)
    return result
end
local profile=P.Profile
function P.Profile(npc)
    local p=profile(npc);local row=C.Resolve(npc or B.npc)
    p.community122=row and row.id;p.communityChecked122=true
    return p
end
local recognition=S.CommunityRecognition
function S.CommunityRecognition(p)
    if p.communityChecked122 then
        if P.Kind(p)=='radical' or type(HasCompletedQuest)~='function' then return end
        local row=C.byId[p.community122]
        if row then for id in pairs(row.acceptQuests) do if HasCompletedQuest(id) then
            return {id='community122:'..row.id,label='Votre aide a été reconnue à '..row.name}
        end end end
        -- Do not let an excluded antagonist inherit the old clan-only welcome.
        if p.groups and p.groups['barkbite clan'] then return end
    end
    return recognition(p)
end
local state=S.State
function S.State(npc)
    local own,details=state(npc)
    if B.CompanionTrust and B.CompanionTrust.Info(npc) then return own,details end
    local community=details.reputationProgress and details.reputationProgress.community
    if community then
        own.localDeeds122=own.localDeeds122 or {}
        local applied=math.floor(community.points*(details.reputationSensitivity or 0)+.5)
        local previous=own.localDeeds122[community.id] or 0
        if applied>previous then
            own.trust=math.min(details.cap,(own.trust or 0)+applied-previous)
            own.localDeeds122[community.id]=applied
        end
    end
    return own,details
end
local debug=S.Debug
function S.Debug(npc)
    local text=debug(npc);local row=C.Resolve(npc)
    if not row then return text end
    local value=C.Progress(row)
    return text..string.format('\n\nCommunauté : %s\nAide locale : %d quêtes achevées, %d avancées · %d / 20 points\nUne avancée vaut 2 points, une quête terminée 4 (elle remplace les 2). Les scores de communauté et de région ne se cumulent pas.\nLe nombre de quêtes locales connues ne représente pas un total exhaustif.',
        row.name,value.completed,value.advanced,value.points)
end
for _,event in ipairs({EVENT_QUEST_ADDED or false,EVENT_QUEST_ADVANCED or false,
    EVENT_QUEST_CONDITION_COUNTER_CHANGED or false,EVENT_QUEST_REMOVED or false,
    EVENT_QUEST_COMPLETE or false}) do
    if event then EVENT_MANAGER:RegisterForEvent('RPMCommunityQuest122'..event,event,function() C.Refresh();changed() end) end
end
if EVENT_PLAYER_ACTIVATED then EVENT_MANAGER:RegisterForEvent('RPMCommunities122',EVENT_PLAYER_ACTIVATED,C.StartScan) end
if EVENT_QUEST_REMOVED then EVENT_MANAGER:RegisterForEvent('RPMCommunityCompleted122',EVENT_QUEST_REMOVED,C.StartScan) end
