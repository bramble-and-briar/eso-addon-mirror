if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Actual quest hand-ins and source-backed historical giver/recipient links.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local P=B.Personality
local pendingGivers,pendingRecipients={},{}
local offered
local byName={}
local giverNames={}
local function key(name) return B.NpcRaces.NameKey(B.Name(name or '')) end
local function link(name,id)
    if type(name)~='string' or name=='' then return end
    local record=B.NpcRaces.Find(name)
    if not record then return end -- Ambiguous/generic names are not identities.
    local k=key(name);byName[k]=byName[k] or {};byName[k][id]=true
end
local db=IHR_QuestRumorDB
for _,rows in pairs(db.maps) do for _,row in ipairs(rows) do
    local id=tonumber(row[3]);local giver=db.givers[tonumber(row[4])]
    if id and not db.objects[id] and db.meta[id] and db.meta[id][2]==0 then
        link(giver,id)
        if giver and B.NpcRaces.Find(giver) then local k=key(giver);giverNames[k]=giverNames[k] or {};giverNames[k][id]=true end
    end
end end
for id,q in pairs(IHR_RegionalKnowledgeData.quests) do
    local last=q.records[#q.records]
    if not q.repeatable and last and last.kind=='person' and (last.action=='talk' or last.action=='deliver') then
        link(last.target,id)
        if last.action=='deliver' then local recipient=B.Dice.DeliveryRecipient(last.objective);if recipient then link(recipient,id) end end
    end
end
-- Moramat's direct involvement is attested by her quest dialogue, not inferred
-- merely from being present in the same settlement as another quest giver.
for _,id in ipairs({4397,4398,4984}) do link('Moramat',id) end
local questIdsByName={}
for id,name in pairs(db.names) do
    if type(name)=='string' then
        local k=key(name)
        if questIdsByName[k]==nil then questIdsByName[k]=tonumber(id) else questIdsByName[k]=false end
    end
end
local function store()
    B.saved.personalDeeds112=B.saved.personalDeeds112 or {people={},offers={}}
    local data=B.saved.personalDeeds112;data.people=data.people or {};data.offers=data.offers or {};data.participants=data.participants or {}
    return data
end
local function saved() return store().people end
local function samePerson(a,b)
    local K=B.RegionalKnowledge
    return key(a)==key(b) or K and K.SamePerson(a,b) or false
end
local cooperationCache
function P.InvalidateQuestCooperation() cooperationCache=nil end
local function evidenceCache()
    local now=type(GetFrameTimeMilliseconds)=='function' and GetFrameTimeMilliseconds() or GetTimeStamp()*1000
    if not cooperationCache or cooperationCache.saved~=B.saved or now<cooperationCache.at or now-cooperationCache.at>=250 then
        cooperationCache={at=now,saved=B.saved,quests={}}
    end
    return cooperationCache
end
local function questIdentity(index)
    if type(index)~='number' or index<1 then return end
    local cache=evidenceCache()
    if cache.quests[index]~=nil then return cache.quests[index] or nil end
    cache.quests[index]=false
    if type(IsValidQuestIndex)~='function' or not IsValidQuestIndex(index) then return end
    local name,background,active=GetJournalQuestInfo(index)
    if not name or name=='' then return end
    local id=type(GetJournalQuestId)=='function' and GetJournalQuestId(index) or 0
    if not id or id<=0 then id=questIdsByName[key(name)] or 0 end
    local repeatType=type(GetJournalQuestRepeatType)=='function' and GetJournalQuestRepeatType(index) or 0
    if repeatType~=0 or db.meta[id] and db.meta[id][2]~=0 then return end
    local quest={index=index,id=id,name=name,background=background or '',active=active or '',relations={},
        key=id and id>0 and ('id:'..id) or ('name:'..key(name))}
    cache.quests[index]=quest
    return quest
end
local function unfinishedTasks(quest)
    if quest.tasks then return quest.tasks end
    local tasks={}
    quest.tasks=tasks
    if type(GetJournalQuestNumSteps)~='function' then return tasks end
    for step=1,GetJournalQuestNumSteps(quest.index) do
        local text,visibility,_,_,count=GetJournalQuestStepInfo(quest.index,step)
        if visibility~=QUEST_STEP_VISIBILITY_HIDDEN then
            for condition=1,count or 0 do
                local objective,current,maximum,fail,done,_,visible=GetJournalQuestConditionInfo(quest.index,step,condition,false)
                local fulfilled=done or type(current)=='number' and type(maximum)=='number' and maximum>0 and current>=maximum
                if visible and not fail and not fulfilled and objective and objective~='' then
                    tasks[#tasks+1]={index=quest.index,step=step,condition=condition,text=objective,stepText=text or '',quest={name=quest.name}}
                end
            end
        end
    end
    return tasks
end
local function journalRequester(quest,npc)
    -- Read native prose only. Notes and acquired testimony must never create
    -- a relationship merely because they mention another person's name.
    local name=key(npc.name):gsub('^le ',''):gsub('^la ',''):gsub('^l ','')
    if name=='' then return false end
    quest.journal=quest.journal or (' '..B.Normalize(quest.background..' '..quest.active)..' ')
    local text=quest.journal
    for _,verb in ipairs({' m a demande ',' m a charge ',' m a prie ',' m a confie ',
        ' a besoin de mon aide ',' compte sur moi ',' souhaite que je ',' veut que je '}) do
        if text:find(' '..name..verb,1,true) then return true end
    end
    return false
end
local function currentSpeaker(quest,npc,tasks)
    for _,task in ipairs(tasks or unfinishedTasks(quest)) do
        local plain=B.Normalize(task.text)
        if plain:find('^parlez ') or plain:find('^rencontrez ') or plain:find('^retrouvez ')
            or plain:find('^apportez ') or plain:find('^livrez ') then
            local target
            if plain:find('^apportez ') or plain:find('^livrez ') then target=B.Dice.DeliveryRecipient(task.text)
            else
                target=task.text:gsub('^%S+%s+',''):gsub('^avec%s+',''):gsub('^au%s+',''):gsub('^aux%s+',''):gsub('^à%s+','')
                -- A current contact can include a separately named place.
                for _,separator in ipairs({' à ',' au ',' aux ',' dans ',' près de '}) do
                    local at=target:find(separator,1,true);if at then target=target:sub(1,at-1);break end
                end
            end
            if target and samePerson(target,npc.name) then return true end
        end
        local K=B.RegionalKnowledge;local entry=K and K.Lookup(task)
        -- An escort/follower is a cooperating participant. A generic quest
        -- cast is deliberately excluded: it also lists enemies and suspects.
        if entry and entry.record.actor and (entry.record.action=='escort' or entry.record.action=='follow')
            and samePerson(entry.record.actor,npc.name) then return true end
    end
    return false
end
local function relationshipEvidence(quest,npc,tasks)
    local data=store();local nameKey=key(npc.name)
    if giverNames[nameKey] and giverNames[nameKey][quest.id] then return true,'donneur documenté' end
    for _,offer in pairs(data.offers) do
        if offer.npc and samePerson(offer.npc.name,npc.name) and
            (quest.id>0 and offer.id==quest.id or (not offer.id or offer.id==0) and offer.name==key(quest.name)) then
            return true,'mission confiée dans le dialogue'
        end
    end
    for identity,entry in pairs(data.participants[quest.key] or {}) do
        if identity==P.Profile(npc).id and entry.npc and samePerson(entry.npc.name,npc.name) then
            return true,'intermédiaire constaté dans le dialogue'
        end
    end
    if journalRequester(quest,npc) then return true,'demande d’aide écrite dans le journal' end
    if currentSpeaker(quest,npc,tasks) then return true,'interlocuteur de l’étape active' end
    return false
end
local function related(quest,npc,tasks)
    local identity=P.Profile(npc).id
    local proof=quest.relations[identity]
    if not proof then
        local yes,reason=relationshipEvidence(quest,npc,tasks)
        proof={yes=not not yes,reason=reason};quest.relations[identity]=proof
    end
    return proof.yes,proof.reason
end
-- A quest relationship is scoped to the exact active quest, not to every
-- question asked of anyone who happens to appear in another quest's cast.
-- This grants cooperation only; the geographic answer still needs a source.
function P.QuestCooperation(npc,subject)
    if not npc or not subject or not subject.task or subject.cooperation==false then return false end
    local quest=questIdentity(subject.task.index);if not quest then return false end
    if subject.task.quest and subject.task.quest.name and key(subject.task.quest.name)~=key(quest.name) then return false end
    local yes,reason=related(quest,npc)
    return yes,reason,quest.id
end
function P.ActiveQuestCooperation(npc)
    if not npc then return false end
    for index=1,MAX_JOURNAL_QUESTS or 25 do
        local quest=questIdentity(index)
        if quest then local yes,reason=related(quest,npc);if yes then return true,reason,quest.id end end
    end
    return false
end
function P.RecordPersonalDeed(npc,id,source,retro)
    if not npc or not id or id<=0 then return false end
    if db.meta[id] and db.meta[id][2]~=0 then return false end
    local identity=P.Profile(npc).id;local people=saved()
    people[identity]=people[identity] or {};local deeds=people[identity]
    if deeds[id] then return false end
    deeds[id]={name=npc.name,source=source,time=GetTimeStamp()}
    if R.Speechcraft and R.Speechcraft.InvalidateSocialReport then R.Speechcraft.InvalidateSocialReport() end
    local S=R.Speechcraft;local store=R.saved and R.saved.speechcraftV1
    local state=store and store.people and store.people[identity]
    if state and not retro and S then state.trust=math.min(S.Report(npc).cap,state.trust+5) end
    return true
end
-- A promise to help is a relationship, not a completed personal deed.
-- Givers and intermediaries use the same exact-quest evidence. Presence in
-- the same clan/region does not qualify.
function P.ActivePersonalHelp(npc)
    local data=store();data.help=data.help or {}
    local identity=P.Profile(npc).id
    local maximum,active,progressed=0,0,0
    if type(IsValidQuestIndex)~='function' then return 0,0,0 end
    for index=1,MAX_JOURNAL_QUESTS or 25 do
        if IsValidQuestIndex(index) then
            local quest=questIdentity(index)
            if quest then
                local name,id=quest.name,quest.id
                local signature={}
                local tasks=unfinishedTasks(quest)
                for _,task in ipairs(tasks) do signature[#signature+1]=task.text end
                if related(quest,npc,tasks) and not (saved()[identity] and saved()[identity][id]) then
                    local questKey=id and id>0 and ('id:'..id) or ('name:'..key(name))
                    data.help[identity]=data.help[identity] or {}
                    local record=data.help[identity][questKey]
                    local current=table.concat(signature,'|')
                    if not record then record={initial=current,progressed=false};data.help[identity][questKey]=record end
                    if current~='' and record.initial~='' and current~=record.initial then record.progressed=true end
                    local value=record.progressed and 8 or 5
                    maximum=math.max(maximum,value);active=active+1
                    if record.progressed then progressed=progressed+1 end
                end
            end
        end
    end
    return maximum,active,progressed
end
function P.PersonalBonus(npc)
    local p=P.Profile(npc);local all={}
    for _,id in ipairs(p.doc and p.doc.personalDeeds or {}) do all[id]=true end
    for id in pairs(byName[key(npc.name)] or {}) do
        -- Match the quest region when the native API supplies it.
        local region=type(GetQuestZoneId)=='function' and GetQuestZoneId(id) or 0
        local own=B.SocialZone(npc)
        local index=region>0 and type(GetZoneIndex)=='function' and GetZoneIndex(region) or nil
        if not index or index<=0 or B.SocialZone({zoneIndex=index})==own then all[id]=true end
    end
    for id in pairs(all) do
        if type(HasCompletedQuest)=='function' and HasCompletedQuest(id) then
            P.RecordPersonalDeed(npc,id,'Donneur / destinataire de quête documenté',true)
        end
    end
    local count=0;for _ in pairs(saved()[p.id] or {}) do count=count+1 end
    local help,active,progressed=P.ActivePersonalHelp(npc)
    return math.min(20,count*10+help),count,active,progressed,help
end
local function interlocutor()
    if type(DoesUnitExist)~='function' or not DoesUnitExist('interact') then return end
    if type(IsUnitPlayer)=='function' and IsUnitPlayer('interact') then return end
    local name=B.Name(GetUnitName('interact'));if name=='' then return end
    local npc={name=name,locality=type(GetPlayerLocationName)=='function' and GetPlayerLocationName() or '',zoneIndex=GetUnitZoneIndex('player')}
    npc.race=type(GetUnitRace)=='function' and GetUnitRace('interact') or ''
    return npc
end
local function capture(index)
    local npc=interlocutor();if not npc then return end
    local name=GetJournalQuestInfo(index)
    local id=type(GetJournalQuestId)=='function' and GetJournalQuestId(index) or nil
    local repeatType=type(GetJournalQuestRepeatType)=='function' and GetJournalQuestRepeatType(index) or 0
    if repeatType and repeatType~=0 then return end
    return {npc=npc,name=key(name),id=id,time=GetTimeStamp()}
end
EVENT_MANAGER:RegisterForEvent('RPMPersonalQuestOffered',EVENT_QUEST_OFFERED,function()
    P.InvalidateQuestCooperation()
    local npc=interlocutor();offered=npc and {npc=npc,time=GetTimeStamp()} or nil
end)
EVENT_MANAGER:RegisterForEvent('RPMPersonalQuestShared',EVENT_QUEST_SHARED,function() P.InvalidateQuestCooperation();offered=nil end)
EVENT_MANAGER:RegisterForEvent('RPMPersonalQuestGiven',EVENT_QUEST_ADDED,function(_,index)
    P.InvalidateQuestCooperation()
    local offer=offered;offered=nil
    if not offer or GetTimeStamp()-offer.time>3600 then return end
    local entry=capture(index)
    if entry and key(entry.npc.name)~=key(offer.npc.name) then entry=nil end
    pendingGivers[index]=entry
    if entry then
        local id=entry.id and entry.id>0 and ('id:'..entry.id) or ('journal:'..index..':'..entry.name)
        store().offers[id]=entry
        P.InvalidateQuestCooperation()
        P.ActivePersonalHelp(entry.npc)
    end
end)
EVENT_MANAGER:RegisterForEvent('RPMPersonalQuestReward',EVENT_QUEST_COMPLETE_DIALOG,function(_,index)
    P.InvalidateQuestCooperation();pendingRecipients[index]=capture(index)
end)
if EVENT_QUEST_ADVANCED then EVENT_MANAGER:RegisterForEvent('RPMPersonalQuestIntermediary',EVENT_QUEST_ADVANCED,function(_,index,_,_,_,mainStepChanged)
    P.InvalidateQuestCooperation()
    -- A native quest hand-off can happen halfway through a quest. Remember
    -- that speaker when the next objective no longer says to talk to them.
    if not mainStepChanged then return end
    local quest=questIdentity(index);local entry=quest and capture(index)
    if not entry then return end
    local data=store();data.participants[quest.key]=data.participants[quest.key] or {}
    data.participants[quest.key][P.Profile(entry.npc).id]=entry
    P.InvalidateQuestCooperation()
    P.ActivePersonalHelp(entry.npc)
    if R.Speechcraft and R.Speechcraft.InvalidateSocialReport then R.Speechcraft.InvalidateSocialReport() end
end) end
if EVENT_QUEST_CONDITION_COUNTER_CHANGED then
    EVENT_MANAGER:RegisterForEvent('RPMPersonalQuestCondition',EVENT_QUEST_CONDITION_COUNTER_CHANGED,P.InvalidateQuestCooperation)
end
EVENT_MANAGER:RegisterForEvent('RPMPersonalQuestRemoved',EVENT_QUEST_REMOVED,function(_,completed,index,name,zone,poi,id)
    P.InvalidateQuestCooperation()
    local giver,recipient=pendingGivers[index],pendingRecipients[index]
    local offers=store().offers;local offerKey='id:'..tostring(id)
    if not giver then giver=offers[offerKey] end
    if not giver then
        local found,ambiguous
        for k,entry in pairs(offers) do
            if entry.name==key(name) and (not entry.id or entry.id==0 or entry.id==id) then
                if found then ambiguous=true end;found=entry;offerKey=k
            end
        end
        if not ambiguous then giver=found end
    end
    if giver then for k,entry in pairs(offers) do if entry==giver then offers[k]=nil end end end
    pendingGivers[index]=nil;pendingRecipients[index]=nil
    local questKey=id and id>0 and ('id:'..id) or ('name:'..key(name))
    local participants=store().participants[questKey] or {};store().participants[questKey]=nil
    if not completed then return end
    for _,entry in pairs({giver=giver,recipient=recipient}) do
        if entry.name==key(name) and (not entry.id or entry.id==0 or entry.id==id) then
            P.RecordPersonalDeed(entry.npc,id,'Quête accomplie : interlocuteur constaté dans le dialogue natif')
        end
    end
    for _,entry in pairs(participants) do
        if entry.name==key(name) and (not entry.id or entry.id==0 or entry.id==id) then
            P.RecordPersonalDeed(entry.npc,id,'Quête accomplie : aide demandée par cet intermédiaire dans le dialogue natif')
        end
    end
    P.InvalidateReputation()
end)
