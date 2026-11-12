-- A heard quest starter is a subject of inquiry before its quest is accepted.
-- The giver and position remain bound to the recorded quest/map/pin, never to
-- another NPC with the same name or another phase of the regional story.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local D=B.Dice
local T=B.TravelJournal
local W=B.WildernessRumors
local function entries() return B.saved and B.saved.travelJournalV1 and B.saved.travelJournalV1.entries or {} end
local function pin(entry)
    if not entry or not entry.anchor or not W.IsSecondary(tonumber(entry.quest)) then return end
    local db=IHR_QuestRumorDB
    for _,row in ipairs(db.maps[entry.mapKey] or {}) do
        local name=B.Name(db.givers[row[4]] or '')
        if row[3]==tonumber(entry.quest) and B.Normalize(name)==B.Normalize(entry.giver)
            and math.abs(row[1]-entry.anchor.x)<.0001 and math.abs(row[2]-entry.anchor.y)<.0001 then
            return {x=row[1],y=row[2]}
        end
    end
end
function T.PersonInquiry(id,snapshot,refreshed)
    if not R.Enabled('travelJournal') then return end
    if not refreshed then T.Refresh() end
    local entry=entries()[tostring(id)]
    if not entry or entry.started or entry.completed then return end
    local location=pin(entry);if not location then return end
    local giver=entry.giver:gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')
    local route,reference=entry.route,entry.reference
    local origin='other-region'
    if snapshot and snapshot.mapKey==entry.mapKey then
        local currentRoute,currentReference=W.Route({anchor=location},snapshot)
        route=currentRoute or route;reference=currentReference or reference
        if snapshot.player then
            local dx,dy=location.x-snapshot.player.x,location.y-snapshot.player.y
            origin=entry.mapKey..':'..math.floor(snapshot.player.x*20)..':'..math.floor(snapshot.player.y*20)
            -- Only a nearby witness gives an immediate direction to the person.
            -- Distant witnesses keep the documented public landmark as a lead.
            if dx*dx+dy*dy<.000025 then
                route='Vous devriez trouver '..giver..' tout près d’ici. Regardez autour de vous.'
            elseif dx*dx+dy*dy<.0025 then
                route=B.RouteVoice.Format('direction',{bearing=B.Bearing(dx,dy),npc=B.npc,targetKey='travel-person:'..entry.quest})
            end
        end
    end
    if not route or route=='' then return end
    local answer=route
    if not snapshot or snapshot.mapKey~=entry.mapKey then
        local region=(entry.region or ''):gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')
        answer='Sa piste mène vers '..region..'. '..route
    end
    return {kind='person',key='travel-person:'..entry.quest..':'..origin,level=1,
        title='À propos de '..giver,question='Où pourrais-je trouver '..giver..' ?',
        target=entry.giver,targetKind='person',rumorPersonId=entry.quest,reference=reference,
        answer=answer,source=entry.source or 'Départ de quête documenté : donneur et coordonnées LibQuestData',routeVoiced=true}
end
function T.Inquiries()
    if not R.Enabled('travelJournal') then return {} end
    T.Refresh()
    local pending=false
    for _,entry in pairs(entries()) do if not entry.started and not entry.completed then pending=true;break end end
    if not pending then return {} end
    local result,seen={},{};local snapshot=W.RegionSnapshot()
    for _,entry in pairs(entries()) do
        local subject=T.PersonInquiry(entry.quest,snapshot,true)
        local key=subject and (B.Normalize(entry.giver)..':'..entry.mapKey..':'..entry.anchor.x..':'..entry.anchor.y)
        if subject and not seen[key] then result[#result+1]=subject;seen[key]=true end
    end
    table.sort(result,function(a,b) return a.question<b.question or a.question==b.question and a.key<b.key end)
    return result
end
local refresh=D.RefreshSubject
function T.ShowInquiries()
    local choices={}
    for _,entry in ipairs(T.Inquiries()) do
        local subject=entry
        choices[#choices+1]={text=subject.question,callback=function() D.Ask(subject) end}
    end
    B.Show('Carnet de voyage',#choices>0 and B.DialogueLine('question') or 'Je n’ai pas d’autre personne à chercher dans mes notes pour le moment.',choices)
    B.ConversationUI.SetRoute({kind='travelQuestions'})
end
function D.RefreshSubject(subject)
    if subject and subject.rumorPersonId then return T.PersonInquiry(subject.rumorPersonId,W.RegionSnapshot()) end
    return refresh(subject)
end
local ask=D.Ask
function D.Ask(subject)
    if subject and subject.rumorPersonId then
        subject=D.RefreshSubject(subject)
        if not subject then return T.ShowInquiries() end
    end
    return ask(subject)
end
local roll=D.Roll
function D.Roll(subject,npc)
    local result,err,cached=roll(subject,npc)
    if result and result.success and subject and subject.rumorPersonId then
        local copy={};for k,v in pairs(result) do copy[k]=v end
        copy.answer=subject.answer;copy.source=subject.source;copy.factualAnswer=nil
        copy.knowledgeUnavailable=false;result=copy
    end
    return result,err,cached
end
local followups=D.Followups
function D.Followups(subject)
    if subject and subject.rumorPersonId then
        if subject.reference and not B.Here(subject.reference) then
            local next=D.PlaceSubject({name=subject.reference},nil)
            if next then return {{subject=next,text=next.question}} end
        end
        return {}
    end
    return followups(subject)
end
