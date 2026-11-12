if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Follow-up questions are rebuilt from evidence actually recorded for the current task.
-- No unrevealed step, unused reference or remote text generator feeds extraction.
local B=IHR_Runtime.Beta
local D=B.Dice
local E={};B.LearnedQuestions=E
local cache=setmetatable({}, {__mode="k"})
local function norm(s) return B.Normalize(type(s)=='string' and s or '') end
local function bare(s) return norm(s):gsub('^les ',''):gsub('^le ',''):gsub('^la ',''):gsub('^l ',''):gsub('^un ',''):gsub('^une ',''):gsub('^des ','') end
local function mentions(text,name) return (' '..norm(text)..' '):find(' '..bare(name)..' ',1,true)~=nil end
local function copy(t) local r={};for k,v in pairs(t or {}) do r[k]=v end;return r end
local function sentence(s) return (s:gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')) end
-- A route's departure point and comparison landmarks are not the destination
-- newly disclosed by the NPC. Inspect each occurrence, since another sentence
-- may independently name the same place as a genuine destination.
function E.ReferenceOnly(text,name)
    text=' '..norm(text)..' ';name=bare(name)
    if name=='' then return false end
    local start,found=1,false
    while true do
        local at,finish=text:find(' '..name..' ',start,true)
        if not at then break end
        found=true
        local before=text:sub(math.max(1,at-90),at)
        before=before:gsub(' du $',' de '):gsub(' des $',' de '):gsub(' de la $',' de '):gsub(' de l $',' de '):gsub(' d $',' de '):gsub(' le $',' '):gsub(' la $',' '):gsub(' les $',' '):gsub(' l $',' ')
        local reference=before:find(' depuis $') or before:find(' a partir de $')
        for _,direction in ipairs({'nord','sud','est','ouest','nord est','nord ouest','sud est','sud ouest'}) do
            if before:sub(-#direction-4)==direction..' de ' then reference=true end
        end
        if not reference then return false end
        start=finish
    end
    return found
end
local rooms={
 {name='la salle d’audience',aliases={"salle d'audience",'salle d’audience'},question='Où se trouve cette salle d’audience ?'},
 {name='la salle du trône',aliases={'salle du trône'},question='Où se trouve cette salle du trône ?'},
 {name='la salle du conseil',aliases={'salle du conseil'},question='Où se trouve cette salle du conseil ?'},
 {name='la salle des archives',aliases={'salle des archives'},question='Où se trouve cette salle des archives ?'},
}
local objects={cle=true,sceau=true,lettre=true,parchemin=true,journal=true,livre=true,amulette=true,medaillon=true,baton=true,
 coffre=true,relique=true,artefact=true,cristal=true,gemme=true,tome=true,anneau=true,coeur=true,manteau=true,sceptre=true}
local roles={capitaine=true,conservatrice=true,conservateur=true,roi=true,reine=true,thane=true,sylvestre=true,general=true,generale=true,
 maitre=true,maitresse=true,prince=true,princesse=true,pretre=true,pretresse=true,forgeron=true,alchimiste=true,marchand=true,marchande=true}
local connectors={le=true,la=true,les=true,un=true,une=true,du=true,de=true,des=true,d=true,l=true}
local function phrase(text,kind)
    local result,proper,head={},false,nil
    for token in text:gmatch('[^ \t\r\n]+') do
        local word=token:gsub('[.,;:!?].*$',''):gsub('[»].*$','')
        local key=norm(word)
        if #result==0 then key=key:gsub('^l ',''):gsub('^d ','') end
        if key=='' then break end
        if #result>0 and ({a=true,au=true,aux=true,dans=true,sur=true,pres=true,vers=true,chez=true,pour=true,qui=true,que=true,et=true})[key] then break end
        local capital=word~=zo_strlower(word)
        if not connectors[key] and not head then head=key end
        if capital then proper=true end
        if not capital and not connectors[key] and not roles[key] and not objects[key] then break end
        result[#result+1]=word
        if word~=token or #result>=9 then break end
    end
    while #result>0 and connectors[norm(result[#result])] do table.remove(result) end
    if #result==0 or (kind=='person' and not proper) or (kind=='object' and not objects[head] and not proper) then return end
    return table.concat(result,' '),head
end
function E.Relevant(entry,task)
    if entry.questKey~=task.questKey then return false end
    local J=B.Investigation
    if J.ForObjective(entry,task.stepText,task.text) then return true end
    if entry.taskText then return false end
    if entry.stepText and norm(entry.stepText)==norm(task.stepText) then return true end
    local target=D.TargetForTask(task)
    return target and mentions(entry.text,target.name) or false
end
function E.Extract(entry,task)
    local stamp=task.key..':'..norm(entry.text)
    local previous=cache[entry]
    if previous and previous.stamp==stamp then return previous.nodes end
    local nodes,seen={},{}
    local target=D.TargetForTask(task)
    local function add(kind,name,question,room)
        if type(name)~='string' or bare(name)=='' then return end
        if kind=='place' and E.ReferenceOnly(entry.text,name) then return end
        local key=kind..':'..bare(name)
        if seen[key] then
            if room then seen[key].room=true;seen[key].question=question end
            return
        end
        if (kind=='person' or kind=='object') and target and bare(target.name)==bare(name) then return end
        -- A place explicitly negated by the speaker is not a new destination.
        local text=' '..norm(entry.text)..' '
        for _,prefix in ipairs({'pas a ','pas dans ','pas au ','pas aux '}) do if text:find(' '..prefix..bare(name)..' ',1,true) then return end end
        local node={kind=kind,name=name,key=key,question=question,room=room};seen[key]=node;nodes[#nodes+1]=node
    end
    local scoped={name=task.quest.name,key=task.questKey,zoneIndex=task.quest.zoneIndex,sources={{text=entry.text,kind='Propos recueillis',objective=task.text,acquired=true,providedHint=true}}}
    for _,place in ipairs(B.MatchPlaces(scoped)) do
        if place.entityType~='alliance' and place.entityType~='person' then add('place',place.name) end
    end
    local lower=zo_strlower(entry.text or '')
    for _,room in ipairs(rooms) do
        for _,alias in ipairs(room.aliases) do if lower:find(alias,1,true) then add('place',room.name,room.question,true);break end end
    end
    local function scan(markers,kind)
        for _,marker in ipairs(markers) do
            local start=1
            while true do
                local _,finish=lower:find(marker,start,true)
                if not finish then break end
                local name,head=phrase(entry.text:sub(finish+1),kind)
                if name then
                    local typed=kind
                    if kind=='object' and not objects[head] then
                        local race=B.NpcRaces and B.NpcRaces.Find(name)
                        if race then typed='person' else typed=nil end
                    end
                    if typed then add(typed,name) end
                end
                start=finish+1
            end
        end
    end
    scan({'parler à ','parlez à ','demandez à ','rencontrez ','interrogez ','allez voir ','adressez-vous à '},'person')
    scan({'récupérez ','récupérer ','chercher ','cherchez ','trouvez ','trouver ','prenez ','prendre ','utilisez ','utiliser ','vous faudra ','besoin de ','apportez ','rapportez '},'object')
    -- If the response already locates a newly named person/object, ask about
    -- the named place instead of asking the already answered question again.
    for _,node in ipairs(nodes) do
        if node.kind~='place' then
            for clause in (entry.text or ''):gmatch('[^.!?;\n]+') do
                local text=' '..norm(clause)..' '
                local _,finish=text:find(' '..bare(node.name)..' ',1,true)
                if finish then
                    local tail=text:sub(finish+1)
                    local locative=tail:find('^est a ') or tail:find('^est dans ') or tail:find('^se trouve ') or tail:find('^a ') or tail:find('^au ') or tail:find('^aux ') or tail:find('^dans ')
                    if locative and not tail:find('^au sujet ') and not tail:find('^a propos ') then
                        for _,place in ipairs(nodes) do if place.kind=='place' and mentions(tail,place.name) then node.located=true end end
                    end
                end
            end
        end
    end
    cache[entry]={stamp=stamp,nodes=nodes}
    return nodes
end
local function entityId(task,node) return task.key..':learned:'..node.kind..':'..tostring(B.Hash(bare(node.name))) end
local function learned(task,node,phase,localOnly)
    local id=entityId(task,node)
    for _,hint in pairs(D.Saved().hints) do
        if hint.learnedEntity==id and hint.learnedPhase==phase and (not localOnly or D.SameOrigin(hint)) then return true end
    end
    for _,entry in ipairs(B.Investigation.Entries(task.questKey)) do
        if entry.learnedEntity==id and entry.learnedPhase==phase and (not localOnly or D.SameOrigin(entry)) then return true end
    end
    return false
end
local function scope(subject)
    if type(GetUnitWorldPosition)~='function' then return subject end
    local zone,x,_,z=GetUnitWorldPosition('player')
    if type(zone)~='number' or type(x)~='number' or type(z)~='number' then return subject end
    local saved=D.Saved();saved.inquiryOrigins=saved.inquiryOrigins or {}
    local list=saved.inquiryOrigins[subject.key] or {};saved.inquiryOrigins[subject.key]=list
    local found
    local radius=subject.kind=='spot' and 2500 or 10000
    for i,p in ipairs(list) do if D.SameOrigin(p) then found=i;break end end
    if not found then found=#list+1;list[found]={originZone=zone,originX=x,originZ=z,scopeRadius=radius} end
    subject.key=subject.key..':origin:'..found;subject.originZone=zone;subject.originX=x;subject.originZ=z;subject.scopeRadius=radius
    return subject
end
function E.SourceDepth(entry)
    if type(entry.inquiryDepth)=='number' then return math.max(0,math.floor(entry.inquiryDepth)) end
    return entry.kind=='renseignement' and 1 or 0
end
function E.Decorate(subject,depth)
    if not subject.task then return subject end
    subject.inquiryDepth=math.max(1,depth or 1)
    subject.inquiryBonus=(subject.inquiryDepth-1)*3
    subject.inquiryRoot=subject.task.key
    subject.inquiryNode=subject.learnedEntity or (subject.kind..':'..bare(subject.destination or subject.target or subject.question))
    subject.inquiryBaseKey=subject.inquiryBaseKey or subject.key
    subject.key=subject.inquiryBaseKey..(subject.inquiryDepth>1 and (':depth:'..subject.inquiryDepth) or '')
    return subject
end
function E.BaseDepth(subject)
    local task=subject.task
    if not task then return 1 end
    local node=subject.kind..':'..bare(subject.destination or subject.target or subject.question)
    local highest,same=0,nil
    for _,entry in ipairs(B.Investigation.Entries(task.questKey)) do
        if E.Relevant(entry,task) and entry.kind=='renseignement' then
            local depth=E.SourceDepth(entry)
            if entry.inquiryNode==node then same=not same and depth or math.min(same,depth) end
            highest=math.max(highest,depth)
        end
    end
    return same or highest+1
end
function D.InquiryLabel(subject,text)
    if not subject or (not subject.unresolved and (not subject.answer or subject.answer=='')) or not subject.task or not subject.inquiryBonus or subject.inquiryBonus<=0 then return text end
    if text:find('[DD +',1,true) then return text end
    return text..' |cC6AD76[DD +'..subject.inquiryBonus..']|r'
end
local function make(task,node,entry,phase,answer,dest,source)
    local question=node.question or D.GeographicQuestion(sentence(node.name),node.kind)
    return E.Decorate(scope({planner=2,task=task,title=task.quest.name,kind=phase=='link' and 'destination' or phase=='local' and 'spot' or phase,
        key=entityId(task,node)..':'..phase,question=question,answer=answer,unresolved=not answer,level=phase=='local' and 3 or phase=='route' and 2 or 1,
        destination=dest or node.name,target=node.name,targetKind=node.kind,learnedEntity=entityId(task,node),learnedPhase=phase,learnedNode=node.key,
        learnedSource=entry.id,source=source or ('Propos recueillis : '..tostring(entry.id)),relation='in'}),E.SourceDepth(entry)+1)
end
local function routeText(route)
    if not route then return end
    if route.near then return 'C’est tout près d’ici. Regardez autour de vous.' end
    local answer=route.bearing and ('D’ici, dirigez-vous '..route.bearing..'.') or nil
    if route.anchor and route.anchorBearing then
        local reference='C’est '..route.anchorBearing..' '..D.OfPlace(route.anchor)..'.'
        answer=answer and answer..' '..reference or reference
    end
    return answer
end
-- Match the provenance format emitted by RegionalQuestions.subject, as well as
-- the older quest/record notation. Exact numeric IDs prevent prefix collisions.
local function referenceMatches(source,hit)
    if type(source)~='string' then return false end
    local record,quest=source:match('^Référentiel régional : (%d+) ; quête (%d+)')
    if not record then quest,record=source:match('^Référentiel régional : (%d+)/(%d+)') end
    return tonumber(record)==tonumber(hit.record.id) and tonumber(quest)==tonumber(hit.quest.id)
end
local function roomContext(task,node,entry)
    local K=B.RegionalKnowledge
    local hit=K and K.Lookup(task)
    if not hit or not mentions(hit.record.hint,node.name) or not referenceMatches(entry.source,hit) then return end
    return K.Destination(task,hit,D.Metadata(task)),hit
end
-- Stable building geography is kept separately from quest objectives. These
-- facts disclose neither future actions nor people/items belonging to later stages.
local landmarks={
    {site='Cormont',name='la salle d’audience',
     text='La salle d’audience ? Elle se trouve dans l’arbre central de Cormont. Il faut monter.',
     source='Géographie locale : Cormont / salle d’audience ; référence FR validée, bâtiment de la thane'},
}
local function landmark(node,dest)
    for _,fact in ipairs(landmarks) do
        if bare(fact.site)==bare(dest.name) and bare(fact.name)==bare(node.name) then return fact end
    end
end
function E.Build(task,node,entry)
    if node.located then return end
    if node.kind=='place' and B.Here(node.name) then return end
    if node.kind=='person' and B.npc and B.RegionalKnowledge and B.RegionalKnowledge.SamePerson(node.name,B.npc.name) then return end
    if node.room then
        local dest,hit=roomContext(task,node,entry)
        -- Interior directions are local knowledge: a distant NPC cannot provide
        -- a room-level follow-up, regardless of trust or the eventual d20 result.
        if not dest or not D.NpcOnSite(task,dest) then
            local unknown=make(task,node,entry,'local',nil,node.name)
            unknown.localKnowledgeOnly=true;unknown.requiredSite=dest and dest.name
            return unknown
        end
        if learned(task,node,'local',true) then return end
        D.RequestPosition(task)
        local point=B.RegionalKnowledge.PointAnswer and B.RegionalKnowledge.PointAnswer(task)
        local fact=landmark(node,dest)
        if point or fact then
            local answer=point and fact and (point..' '..fact.text) or point or fact.text
            local source=point and 'Client FR : position actuelle de l’objectif dans le lieu indiqué' or fact.source
            if point and fact then source=source..' ; '..fact.source end
            return make(task,node,entry,'local',answer,node.name,source)
        end
        return make(task,node,entry,'local',nil,node.name)
    end
    if node.kind=='place' then
        local region=D.Region(task.quest.zoneIndex)
        local site=D.SiteForName(node.name,region and region.zoneIndex)
        local public=B.PublicPlace(node.name)
        if public and public.entityType=='alliance' then return end
        local dest={name=site and site.name or node.name,site=site,region=site and site.region or public and public.region}
        local known=D.InquiryKnowledge(task,dest)
        if B.Here(node.name) or known.route or learned(task,node,'route',true) then return end
        if public and public.entityType=='region' then
            if learned(task,node,'region',false) then return end
            local place=D.PlaceSubject({name=node.name},task)
            if place and place.answer then return make(task,node,entry,'region',place.answer,node.name,place.source) end
        end
        local route=D.ReadRoute(site)
        local answer=routeText(route)
        return make(task,node,entry,'route',answer,dest.name,route and route.source)
    end
    if learned(task,node,'link',false) then return end
    -- A newly named person/object is a legitimate question even when no safe location is available.
    -- Never use another, unrevealed objective's reference or the current target's marker for it.
    return make(task,node,entry,'link',nil,node.name)
end
function E.ForTask(task)
    local result,seen={},{}
    for _,entry in ipairs(B.Investigation.Entries(task.questKey)) do
        if E.Relevant(entry,task) then
            for _,node in ipairs(E.Extract(entry,task)) do
                if not seen[node.key] then
                    local subject=E.Build(task,node,entry)
                    if subject then result[#result+1]=subject;seen[node.key]=true end
                end
            end
        end
    end
    return result
end
local function signature(subject)
    return subject.kind..':'..bare(subject.destination or subject.target or '')
end
local oldSubjects,oldFollowups,oldReveal,oldRefresh=D.Subjects,D.Followups,D.Reveal,D.RefreshSubject
function D.Subjects(index)
    local result=oldSubjects(index)
    for _,subject in ipairs(result) do E.Decorate(subject,E.BaseDepth(subject)) end
    local seen={};for _,s in ipairs(result) do if not s.unresolved then seen[signature(s)]=true end end
    for _,task in ipairs(D.Tasks(index)) do
        for _,s in ipairs(E.ForTask(task)) do
            local key=signature(s)
            if not seen[key] then seen[key]=true;result[#result+1]=s end
        end
    end
    return result
end
function D.Followups(entry)
    local result=oldFollowups and oldFollowups(entry) or {}
    if not entry.task then return result end
    local task=D.Fresh(entry.task);if not task then return {} end
    local seen={};for _,f in ipairs(result) do E.Decorate(f.subject,E.BaseDepth(f.subject));f.text=D.InquiryLabel(f.subject,f.text);seen[signature(f.subject)]=true end
    for _,s in ipairs(E.ForTask(task)) do
        local key=signature(s)
        if s.key~=entry.key and not seen[key] then seen[key]=true;result[#result+1]={subject=s,text=D.InquiryLabel(s,s.question)} end
    end
    return result
end
function D.RefreshSubject(subject)
    if subject.learnedEntity then
        local task=D.Fresh(subject.task);if not task then return end
        for _,fresh in ipairs(E.ForTask(task)) do if fresh.key==subject.key then return fresh end end
        return
    end
    return oldRefresh(subject)
end
function D.Reveal(subject,result)
    if not oldReveal(subject,result) then return false end
    if subject.task and result and result.success then
        local depth=result.inquiryDepth or subject.inquiryDepth or 1
        local node=subject.inquiryNode or (subject.kind..':'..bare(subject.destination or subject.target or subject.question))
        local function annotate(record)
            if not record then return end
            record.inquiryDepth=depth;record.inquiryRoot=subject.task.key;record.inquiryNode=node
            if subject.learnedEntity then record.learnedEntity=subject.learnedEntity;record.learnedPhase=subject.learnedPhase end
        end
        annotate(D.Saved().hints[subject.key])
        for _,entry in ipairs(B.Investigation.Entries(subject.task.questKey)) do
            if entry.taskKey==subject.task.key and norm(entry.text)==norm(result.answer) and entry.source==result.source then annotate(entry) end
        end
    end
    return true
end
