if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Shared uncertain testimony; social delivery remains specific to each mode.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local S=R.Speechcraft
local P=B.Personality
local D=B.Dice
function S.Decision(npc,subject,current,report)
    if subject and subject.kind=='rumor' then return 'truth' end
    -- Practical cooperation is established by the active mission, including
    -- native intermediaries. It is never a random personality refusal or lie.
    if P.QuestCooperation and P.QuestCooperation(npc,subject) then return 'truth' end
    if subject.unresolved or not subject.answer then return 'truth' end
    if P.Kind(P.Profile(npc))=='amical' then return 'truth' end
    if current>=80 and not report.stubborn then return 'truth' end
    local p=P.Profile(npc)
    local modifier=({chaleureux=10,jovial=5,professionnel=5,impatient=-10,orgueilleux=-10})[p.temperament] or 0
    local band=math.floor(current/10)*10
    local honest=report.stubborn and math.max(35,math.min(90,band-5)) or math.max(10,math.min(95,band+20+modifier))
    -- Stable for this NPC, subject and day; repeated clicks never reroll.
    local roll=B.Hash(p.id..':speech-answer:'..tostring(subject.key)..':'..math.floor(GetTimeStamp()/86400))%100
    if roll<honest then return 'truth' end
    if report.stubborn or roll<honest+math.floor((100-honest)*.65) then return 'lie' end
    return 'refuse'
end
local function bare(text) return B.Normalize(text or ''):gsub('^le ',''):gsub('^la ',''):gsub('^les ','') end
function S.FalseLead(subject,npc)
    if not subject or subject.unresolved or not subject.answer or subject.kind=='rumor' then return end
    local region=D.Region(GetUnitZoneIndex('player'))
    if not region then return end
    local key=P.Profile(npc).id..':'..subject.key..':'..math.floor(GetTimeStamp()/86400)
    B.saved.falseLeads112=B.saved.falseLeads112 or {}
    local saved=B.saved.falseLeads112
    if saved[key] then return saved[key].text,saved[key].name end
    local destination=subject.task and D.Destination(subject.task)
    local candidates={}
    for i=1,GetNumPOIs(region.zoneIndex) do
        local name=GetPOIInfo(region.zoneIndex,i)
        if type(name)=='string' and name~='' and not B.Here(name) and bare(name)~=bare(subject.target)
            and bare(name)~=bare(subject.destination) and (not destination or bare(name)~=bare(destination.name))
            and not (' '..bare(subject.answer)..' '):find(' '..bare(name)..' ',1,true) then
            candidates[#candidates+1]={name=B.Name(name),zoneIndex=region.zoneIndex,poiIndex=i,region=region.name}
        end
    end
    if #candidates==0 then return end
    local start=B.Hash(key)%#candidates+1
    for offset=0,#candidates-1 do
        local place=candidates[(start+offset-1)%#candidates+1]
        local route=D.ReadRoute(place)
        if route and route.bearing and not route.near then
            local text='Cherchez du côté '..D.OfPlace(place.name)..'. D’ici, partez '..route.bearing..'.'
            saved[key]={text=text,name=place.name,zoneIndex=place.zoneIndex}
            return text,place.name
        end
    end
end
function P.RecordTestimony(subject,result)
    if not subject.task then return end
    local task=subject.task
    return B.Investigation.Record({kind='temoignage',unverified=true,text=result.answer,speaker=result.npc or B.npc.name,locality=result.locality or B.npc.locality,
        questKey=task.questKey,questName=task.quest.name,taskKey=task.key,taskText=task.text,stepText=task.stepText,
                inquiryDepth=result.inquiryDepth or subject.inquiryDepth or 1,source='Propos recueillis auprès de '..(result.npc or B.npc.name)})
end
function P.MaybeFalseAnswer(subject,result)
    if result.automatic or not result.success or result.knowledgeUnavailable or result.balanceDecision112 then return end
    if P.QuestCooperation and P.QuestCooperation(B.npc,subject) then return end
    result.balanceDecision112=true
    local report={stubborn=P.Kind(P.Profile(B.npc))=='radical'}
    if S.Decision(B.npc,subject,B.Confidence(B.npc),report)~='lie' then return end
    local wrong=S.FalseLead(subject,B.npc)
    if wrong then result.answer=wrong;result.factualAnswer=nil;result.unverified=true;result.source='Propos recueillis auprès de '..B.npc.name end
end
function S.SocialAnswer(subject,current,required,report)
    local decision=S.Decision(B.npc,subject,current,report)
    if decision=='truth' then return false end
    local result={speechcraft=true,automatic=true,refused=decision=='refuse',socialBehaviour=S.Behaviour(B.npc)}
    local text
    if decision=='lie' then
        local wrong=S.FalseLead(subject,B.npc)
        if wrong then
            wrong=D.CleanRouteText(wrong)
            text=B.SpokenAnswer(subject,wrong,B.npc,result)
            P.RecordTestimony(subject,{answer=wrong,npc=B.npc.name,locality=B.npc.locality})
        elseif report.stubborn then
            -- Once persuaded, an obstinate witness still gives an answer.
            -- Without a plausible wrong bearing, deliver the true fact reluctantly.
            return false
        else
            -- When no plausible geographic falsehood is available, feign ignorance.
            text=P.UnknownResponse(B.npc,subject,result)
        end
    else text=B.DialogueLine('refusal') end
    P.FinishAttempt(subject,result,B.npc)
    local choices={}
    if not S.Limited(B.npc) then
        choices[#choices+1]={text='J’aurais une autre question.',callback=function()
            if subject.task then B.ShowQuest(B.ReadQuest(subject.task.index)) else B.ShowHome() end
        end}
        if S.CanPersuade(B.npc) then choices[#choices+1]={text='Prenons un moment pour parler.',callback=S.Wheel.Show} end
    end
    choices[#choices+1]={text='Très bien. Je vous laisse.',callback=B.ShowHome}
    B.Show(subject.title,text,choices)
    return true
end
