if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Sourced geography and exact-current-task references. No guessed NPC positions.
local B=IHR_Runtime.Beta
local D=B.Dice
local E=B.LearnedQuestions
local G={};B.GeographicKnowledge=G
local catalogue=B.CompactCatalogue
local data=IHR_GeographicData
local places,people,objects,taskRefs,trie={},{},{},{},{}
local bound={}
local function norm(s) return B.Normalize(type(s)=='string' and s or '') end
local function bare(s) return norm(s):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ',''):gsub('^un ',''):gsub('^une ','') end
local function copy(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function at(name)
    name=D.PlaceName(name)
    local key=norm(name)
    if key:find('^le ') then return 'au '..name:sub(4) end
    if key:find('^les ') then return 'aux '..name:sub(5) end
    return 'à '..name
end
local function of(name) return D.OfPlace(name) end
local function index(map,key,row)
    if key=='' then return end
    catalogue.Add(map,key,row)
end
local function addTrie(name,kind,key)
    key=key or bare(name)
    if #key<5 then return end
    local node=trie
    for word in key:gmatch('[^ ]+') do node[word]=node[word] or {};node=node[word] end
    catalogue.Add(node,'entries',{name,kind})
end
for _,p in ipairs(data.places) do
    local seen={}
    for _,name in ipairs(p.names) do
        local key=bare(name)
        if not seen[key] then seen[key]=true;index(places,key,p);addTrie(name,'place',key) end
    end
end
for _,p in ipairs(data.people) do
    local seen={}
    for _,name in ipairs(p.names) do
        local key=B.NpcRaces and B.NpcRaces.NameKey(name) or norm(name)
        if not seen[key] then seen[key]=true;index(people,key,p);addTrie(name,'person') end
    end
end
for _,r in ipairs(IHR_GeographicObjectFacts or {}) do
    local seen={}
    for _,name in ipairs(r.names) do
        local key=norm(r.quest)..'\n'..bare(name)
        if not seen[key] then seen[key]=true;index(objects,key,r);addTrie(name,'object') end
    end
end
for _,r in ipairs(IHR_GeographicTaskData) do
    for _,text in ipairs(r.objectives) do index(taskRefs,norm(r.questName)..'\n'..B.RegionalKnowledge.ObjectiveKey(text),r) end
end
local function context(task)
    local meta=D.Metadata(task) or {}
    local region=D.Region(task.quest.zoneIndex)
    return bare(meta.region or region and region.name or task.quest.zoneName)
end
function G.Place(name,task)
    local candidates=places[bare(name)]
    local selected,signature,ambiguous,score=nil,nil,false,0
    local region=task and context(task) or ''
    for _,p in catalogue.Records(candidates) do
        local rank=region~='' and bare(p.zone)==region and 2 or 1
        local sign=table.concat({p.name,p.zone or '',p.parent or '',p.anchor or '',p.bearing or '',p.part or ''},'|')
        if rank>score then selected=p;signature=sign;score=rank;ambiguous=false
        elseif rank==score and sign~=signature then ambiguous=true end
    end
    if not ambiguous then return selected end
end
local function regionOf(p,task,seen)
    if not p then return end
    if p.zone then return p.zone end
    seen=seen or {};if seen[p] then return end;seen[p]=true
    return p.parent and regionOf(G.Place(p.parent,task),task,seen)
end
function G.Person(name,task)
    -- Only task context chooses a position. The informant's identity, race,
    -- location and trust never select a different destination for the same task.
    local nameKey=B.NpcRaces and B.NpcRaces.NameKey(name) or norm(name)
    local key=task.key..':person:'..nameKey
    if bound[key]~=nil then return bound[key] or nil end
    local region=context(task);local match,signature,ambiguous
    for _,p in catalogue.Records(people[nameKey]) do
        local ownRegion=p.zone or regionOf(G.Place(p.site,task),task)
        if region=='' or bare(ownRegion)==region then
            local sign=bare(p.site)..'|'..bare(ownRegion)
            if signature and signature~=sign then ambiguous=true end
            match=match or p;signature=signature or sign
        end
    end
    if ambiguous then match=nil end
    if match then bound[key]=match end
    return match
end
function G.Object(name,task)
    local match
    for _,row in catalogue.Records(objects[norm(task.quest.name)..'\n'..bare(name)]) do
        if match then return end
        match=row
    end
    return match
end
function G.TaskReference(task)
    local rows=taskRefs[norm(task.quest.name)..'\n'..B.RegionalKnowledge.ObjectiveKey(task.text)]
    local match,score,signature,ambiguous=nil,0,nil,false
    for _,r in catalogue.Records(rows) do
        local rank=#r.steps==0 and 1 or 0
        for _,s in ipairs(r.steps) do if norm(s)==norm(task.stepText) then rank=3;break end end
        if rank>0 then
            local sign=table.concat({r.place,r.relation,r.bearing or ''},'|')
            if rank>score then match=r;score=rank;signature=sign;ambiguous=false
            elseif rank==score and sign~=signature then ambiguous=true end
        end
    end
    if not ambiguous then return match end
end
-- Only complete atlas place names in a locative clause. Do not revive the
-- former capitalised-word extractor (which also treated races as places).
function G.AnswerPlaces(text,task)
    local words,found,seen={},{},{}
    for word in norm(text):gmatch('[^ ]+') do words[#words+1]=word end
    local i=1
    while i<=#words do
        local branch=trie;local best,finish
        for j=i,math.min(#words,i+14) do
            branch=branch[words[j]];if not branch then break end
            if branch.entries then best=branch.entries;finish=j end
        end
        if best then
            local before=' '..table.concat(words,' ',math.max(1,i-6),i-1)..' '
            local located=before:find(' dans ') or before:find(' chez ') or before:find(' a ') or before:find(' au ') or before:find(' aux ') or before:find(' en ') or before:find(' pres ') or before:find(' approcher de ') or before:find(' cote de ')
            local negated=before:find(' pas ') or before:find(' jamais ')
            for _,candidate in catalogue.Records(best) do
                local name,kind=candidate[1],candidate[2];local key=bare(name)
                if kind=='place' and located and not negated and #key>=4 and not seen[key]
                  and not ({interieur=true,exterieur=true,bosmer=true,rituel=true,domaine=true,est=true,ouest=true,nord=true,sud=true})[key]
                  and not E.ReferenceOnly(text,name) then
                    local p=G.Place(name,task)
                    if p then seen[key]=true;found[#found+1]=p end
                end
            end
            i=finish+1
        else i=i+1 end
    end
    return found
end
local function interior(p)
    return p and p.parent and bare(p.parent)~=bare(p.zone) and not p.city
end
local function localTo(task,name)
    return D.NpcOnSite(task,{name=name,site=D.SiteForName(name)})
end
local function primarySite(p,task)
    local seen={}
    while interior(p) and not seen[p] do
        seen[p]=true;local parent=G.Place(p.parent,task)
        if not parent then return p.parent end
        p=parent
    end
    return p and p.name
end
local function localEnough(task,p)
    return p and (localTo(task,p.name) or p.parent and localTo(task,p.parent))
end
function G.PlaceAnswer(name,task)
    local p=G.Place(name,task);if not p then return end
    local voice=B.RouteVoice
    -- Small interiors belong to local witnesses; public cities/regions can be
    -- situated broadly without pretending to know a particular room or object.
    if interior(p) and not localEnough(task,p) then
        local site=primarySite(p,task)
        if site and bare(site)~=bare(name) then
            local route=voice and voice.Format('destination',{destination=site,npc=B.npc,targetKey=task and task.key or name}) or ('Cherchez '..at(site)..'.')
            return route..' Les gens sur place pourront vous guider.',p.source,site,'destination'
        end
        return
    end
    local answer
    if voice then
        -- These coordinates describe a named anchor/parent, never the player's
        -- current origin. Keep the same facts without adding "d’ici".
        answer=voice.Format('relative',{bearing=p.bearing,anchor=p.anchor,part=p.part,parent=p.parent,
            relation=p.relation,region=p.zone and bare(p.name)~=bare(p.zone) and p.zone or nil,
            npc=B.npc,targetKey=task and task.key or name})
    end
    if answer then return answer,p.source,p.name,interior(p) and 'spot' or 'region' end
    if p.bearing and p.anchor then answer='C’est '..p.bearing..' '..of(p.anchor)..'.'
    elseif p.part and p.anchor then answer='C’est dans '..p.part..' '..of(p.anchor)..'.'
    elseif p.parent then
        local prefix=({inside='à l’intérieur '..of(p.parent),under='sous '..p.parent,near='près '..of(p.parent),outside='à l’extérieur '..of(p.parent)})[p.relation] or at(p.parent)
        answer='C’est '..prefix..'.'
    elseif p.zone and bare(p.name)~=bare(p.zone) then answer=p.name..' se trouve dans la région '..of(p.zone)..'.' end
    return answer,p.source,p.name,interior(p) and 'spot' or 'region'
end
local function origin(subject)
    if type(GetUnitWorldPosition)~='function' then return subject end
    local zone,x,_,z=GetUnitWorldPosition('player')
    if type(zone)~='number' or type(x)~='number' or type(z)~='number' then return subject end
    local saved=D.Saved();saved.inquiryOrigins=saved.inquiryOrigins or {}
    local list=saved.inquiryOrigins[subject.key] or {};saved.inquiryOrigins[subject.key]=list
    local radius=subject.kind=='spot' and 2500 or 10000
    local found
    for i,p in ipairs(list) do if D.SameOrigin(p) then found=i;break end end
    if not found then found=#list+1;list[found]={originZone=zone,originX=x,originZ=z,scopeRadius=radius} end
    subject.key=subject.key..':origin:'..found;subject.scopeRadius=radius
    subject.originZone=zone;subject.originX=x;subject.originZ=z
    return subject
end
local function heard(task,source,destination,localOnly)
    for _,entry in ipairs(B.Investigation.Entries(task.questKey)) do
        if E.Relevant(entry,task) and entry.source==source and bare(entry.destination)==bare(destination) and (not localOnly or D.SameOrigin(entry)) then return true end
    end
    return false
end
local function factAnswer(fact)
    local where
    if fact.relation=='bearing' then where=fact.bearing..' '..of(fact.place)
    elseif fact.relation=='part' then where='dans la partie '..fact.bearing:gsub('^au ',''):gsub('^à l’','')..' '..of(fact.place)
    else where=({inside='à l’intérieur '..of(fact.place),near='près '..of(fact.place),under='sous '..fact.place,on='sur '..fact.place})[fact.relation] or at(fact.place) end
    return 'Cherchez '..where..'.'
end
local function nearObjective(task)
    local p=D.positions[task.key]
    if not p or p.breadcrumb or type(p.radius)~='number' or p.radius>0 or p.mapId~=GetCurrentMapId() or GetTimeStamp()-p.time>20 or norm(p.taskText)~=norm(task.text) then return false end
    local x,y=GetMapPlayerPosition('player')
    return type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1 and (p.x-x)^2+(p.y-y)^2<=.000025
end
G.NearObjective=nearObjective
local function taskSubject(task,fact,target)
    local p=G.Place(fact.place,task)
    local isLocal=p and localEnough(task,p) or localTo(task,fact.place) or nearObjective(task)
    -- A faraway informant supplies the quest site, never indoor detail.
    local destination=not isLocal and p and primarySite(p,task) or fact.place
    if not destination then return end
    local source='Référence géographique : '..fact.questId..'/'..fact.order..' ; '..fact.source
    local detailed=fact.detail or fact.relation~='in' or interior(p)
    if isLocal and not detailed then return end
    local kind=isLocal and detailed and 'spot' or 'destination'
    if heard(task,source,destination,isLocal) then return end
    local answer=isLocal and (fact.detail or factAnswer(fact)) or ('Cherchez du côté de '..destination..'. Quelqu’un sur place pourra vous guider.')
    return origin({planner=2,task=task,title=task.quest.name,kind=kind,target=target.name,targetKind=target.kind,
        destination=destination,key=task.key..':geographic:'..fact.questId..':'..fact.order..':'..kind,
        question=D.QuestionForTask(task),answer=answer,source=source,level=isLocal and 3 or 1,relation='in'})
end
function G.Enrich(subject)
    if not subject or not subject.unresolved or not subject.task then return subject end
    -- A documented room can be asked about from afar; its detail cannot be disclosed there.
    if subject.localKnowledgeOnly and (not subject.requiredSite or not D.NpcOnSite(subject.task,{name=subject.requiredSite})) then return subject end
    local task=subject.task
    local name=subject.target or subject.destination
    local target=subject.targetKind
    local answer,source,dest,kind
    if target=='person' then
        local p=G.Person(name,task)
        if p then
            local place=G.Place(p.site,task)
            local near=p.city and localTo(task,p.city) or place and localEnough(task,place)
            local site=near and p.site or p.city or (place and primarySite(place)) or p.site
            if site then answer='Vous devriez chercher '..at(site)..'.';source=p.source;dest=site;kind=near and 'spot' or 'destination' end
        end
    elseif target=='object' then
        local fact=G.Object(name,task)
        if fact then
            local isLocal=localTo(task,fact.site)
            answer=isLocal and fact.detail or ('Cherchez du côté de '..fact.site..'.')
            source=fact.source;dest=fact.site;kind=isLocal and 'spot' or 'destination'
        end
    elseif target=='place' or subject.learnedEntity and subject.learnedNode and subject.learnedNode:find('^place:') then
        answer,source,dest,kind=G.PlaceAnswer(name,task)
    end
    if not answer then return subject end
    if heard(task,source,dest,kind=='spot') then return nil end
    local result=copy(subject);result.answer=answer;result.source=source;result.unresolved=false
    result.destination=dest;result.kind=kind;result.level=kind=='spot' and 3 or kind=='route' and 2 or 1
    result.key=result.key..':sourced';result=origin(result);result.inquiryBaseKey=result.key
    return result
end
-- Upgrade entity questions generated from actual acquired evidence.
local build=E.Build
function E.Build(task,node,entry)
    return G.Enrich(build(task,node,entry))
end
local extract=E.Extract
function E.Extract(entry,task)
    local nodes=extract(entry,task);local seen={}
    for _,node in ipairs(nodes) do seen[node.kind..':'..bare(node.name)]=true end
    local text=norm(entry.text);local words={};for word in text:gmatch('[^ ]+') do words[#words+1]=word end
    local target=D.TargetForTask(task)
    local i=1
    while i<=#words do
        local branch=trie;local best,finish
        for j=i,math.min(#words,i+14) do
            branch=branch[words[j]];if not branch then break end
            if branch.entries then best=branch.entries;finish=j end
        end
        if best then
            local picked
            for _,candidate in catalogue.Records(best) do
                local name,kind=candidate[1],candidate[2]
                local valid=kind=='place' and G.Place(name,task) or kind=='person' and G.Person(name,task) or kind=='object' and G.Object(name,task)
                if valid then
                    if picked and picked[2]~=kind then picked=nil;break end
                    picked=picked or candidate
                end
            end
            if picked then
                local name,kind=picked[1],picked[2]
                local key=kind..':'..bare(name)
                local before=' '..table.concat(words,' ',math.max(1,i-5),i-1)..' '
                local negated=before:find(' pas ') or before:find(' jamais ')
                local anchor=kind=='place' and (before:find(' nord ') or before:find(' sud ') or before:find(' ouest ') or before:find(' est '))
                local current=target and bare(target.name)==bare(name)
                local located=false
                if kind=='person' then
                    local tail=table.concat(words,' ',finish+1,#words)
                    local locative=tail:find('^est ') or tail:find('^se trouve ') or tail:find('^vous attend ') or tail:find('^a ') or tail:find('^au ') or tail:find('^aux ') or tail:find('^dans ')
                    if locative then
                        for start=finish+1,math.min(#words,finish+20) do
                            local branch=trie
                            for stop=start,math.min(#words,start+12) do
                                branch=branch[words[stop]];if not branch then break end
                                for _,item in catalogue.Records(branch.entries) do if item[2]=='place' and G.Place(item[1],task) then located=true end end
                            end
                        end
                    end
                end
                if not seen[key] and not current and not negated and not anchor and not located and not (kind=='place' and E.ReferenceOnly(entry.text,name)) then
                    seen[key]=true;nodes[#nodes+1]={kind=kind,name=name,key=key}
                end
            end
            i=finish+1
        else i=i+1 end
    end
    if target and target.kind=='person' then
        for i=#nodes,1,-1 do
            if nodes[i].kind=='person' and B.RegionalKnowledge.SamePerson(target.name,nodes[i].name) then table.remove(nodes,i) end
        end
    end
    return nodes
end
local plan=D.PlanTask
function D.PlanTask(task)
    local result=plan(task)
    -- Hand-reviewed regional logic keeps its speaker/method and stage rules.
    if B.RegionalKnowledge.HasQuest(task.quest.name) then
        local upgraded={}
        for _,subject in ipairs(result) do
            -- Keep reviewed methods intact, but do not ignore a sourced NPC
            -- location merely because its quest also has regional references.
            local next=subject.unresolved and G.Enrich(subject) or subject
            if next then upgraded[#upgraded+1]=next end
        end
        return upgraded
    end
    local fact=G.TaskReference(task)
    local target=D.TargetForTask(task)
    if fact and target and D.QuestionForTask(task) then
        local precise=taskSubject(task,fact,target)
        if precise then
            for _,s in ipairs(result) do if not s.unresolved and s.kind=='spot' then return result end end
            return {precise}
        end
        -- The reference was already disclosed; keep only a genuinely new native detail.
        local fresh={}
        for _,s in ipairs(result) do if not s.unresolved and s.kind=='spot' then fresh[#fresh+1]=s end end
        return fresh
    end
    local upgraded={}
    for _,s in ipairs(result) do local next=G.Enrich(s);if next then upgraded[#upgraded+1]=next end end
    return upgraded
end

-- Classification is independent of a quest destination. Ambiguous identities
-- remain unclassified; lack of documentation is never treated as "no E".
function G.NpcClassification(npc)
    if type(npc)=='string' then npc={name=npc} end
    npc=npc or {}
    local key=B.NpcRaces and B.NpcRaces.NameKey(npc.name) or norm(npc.name)
    local context=B.NpcRaces and B.NpcRaces.Context(npc) or {locality=bare(npc.locality)}
    local match,rank,role,speech,ambiguous=nil,-1,nil,nil,false
    for _,p in catalogue.Records(people[key]) do
        local own=0
        if bare(context.region)~='' and bare(p.zone)==bare(context.region) then own=own+2 end
        if bare(context.locality)~='' and (bare(p.site)==bare(context.locality) or bare(p.city)==bare(context.locality)) then own=own+3 end
        if own>rank then match=p;rank=own;role=p.role;speech=p.speech;ambiguous=false
        elseif own==rank and (role~=p.role or speech~=p.speech) then ambiguous=true end
    end
    if not match or ambiguous then return {role='indetermine',speech='indetermine'} end
    return {role=match.role or 'indetermine',speech=match.speech or 'indetermine',source=match.source,
        revision=match.roleRevision or match.revision,evidence=match.roleEvidence,speechEvidence=match.speechEvidence}
end
function G.OrdinaryPeople(speechStatus)
    local out={}
    for _,p in ipairs(data.people) do
        if p.role=='habitant_ordinaire' and (not speechStatus or p.speech==speechStatus) then out[#out+1]=p end
    end
    return out
end
