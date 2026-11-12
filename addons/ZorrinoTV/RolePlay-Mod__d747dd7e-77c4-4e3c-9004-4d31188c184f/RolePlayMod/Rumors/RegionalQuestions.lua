if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Typed regional references. These facts are disclosed only through an actual answer.
local B=IHR_Runtime.Beta
local D=B.Dice
local K={};B.RegionalKnowledge=K
local byName,byObjective={},{ }
local function norm(s) return B.Normalize((s or ''):gsub('Wellkynd','Welkynd'):gsub('wellkynd','welkynd')) end
local articles={le=true,la=true,les=true,l=true,un=true,une=true,des=true,du=true}
local function words(s)
    local result={};for word in norm(s):gmatch('[^ ]+') do if not articles[word] then result[#result+1]=word end end
    return table.concat(result,' ')
end
function K.ObjectiveKey(s)
    s=(s or ''):gsub('\194\160',' '):gsub('\226\128\175',' ')
    local text=words(D.ObjectiveCanonical and D.ObjectiveCanonical(s) or s)
    text=text:gsub('^retirez ','recuperez '):gsub('^ramassez ','recuperez '):gsub('^recoltez ','recuperez '):gsub('^collectez ','recuperez ')
    text=text:gsub('^emmenez ','amenez '):gsub('^escortez ','amenez '):gsub('^accompagnez ','amenez ')
    return text
end
local function bare(s) return norm(s):gsub('^le ',''):gsub('^la ',''):gsub('^les ',''):gsub('^l ',''):gsub('^un ',''):gsub('^une ','') end
local function point(x,y) return type(x)=='number' and type(y)=='number' and x>0 and x<1 and y>0 and y<1 end
local function copy(t) local r={};for k,v in pairs(t or {}) do r[k]=v end;return r end
for _,quest in pairs(IHR_RegionalKnowledgeData.quests) do
    local name=norm(quest.name);byName[name]=byName[name] or {};byName[name][#byName[name]+1]=quest
    for _,record in ipairs(quest.records) do
        local seen={}
        for _,text in ipairs(record.objectives) do
            local key=name..'\n'..K.ObjectiveKey(text)
            if not seen[key] then
                byObjective[key]=byObjective[key] or {};byObjective[key][#byObjective[key]+1]={quest=quest,record=record};seen[key]=true
            end
        end
    end
end
function K.HasQuest(name) return byName[norm(name)]~=nil end
function K.Lookup(task)
    if not task or not task.quest then return end
    local entries=byObjective[norm(task.quest.name)..'\n'..K.ObjectiveKey(task.text)] or {}
    local best,score,signature,ambiguous=nil,0,nil,false
    for _,entry in ipairs(entries) do
        local r=entry.record;local rank=#r.steps==0 and 1 or 0
        local currentStep=task.stepText
        if not currentStep or currentStep=='' then currentStep=task.quest.stepText end
        for _,step in ipairs(r.steps) do if words(step)==words(currentStep) then rank=3;break end end
        if rank>0 then
            rank=rank*10+(norm(r.objective)==norm(task.text) and 3 or K.ObjectiveKey(r.objective)==K.ObjectiveKey(task.text) and 1 or 0)
            local sign=table.concat({r.action,r.kind,words(r.target),norm(r.hint),norm(r.site)},'\n')
            if rank>score then best=entry;score=rank;signature=sign;ambiguous=false
            elseif rank==score and signature~=sign then ambiguous=true end
        end
    end
    if not ambiguous then return best end
end
function K.SamePerson(a,b)
    a,b=bare(a),bare(b)
    if a=='' or b=='' then return false end
    if a==b then return true end
    -- A title may precede the name; a generic guard or 'the researcher' is not an identity.
    if #b>=4 and a:sub(-#b-1)==' '..b then return true end
    if #a>=4 and b:sub(-#a-1)==' '..a then return true end
    return false
end
local previousTarget,previousQuestion,previousDestination,previousPlan=D.TargetForTask,D.QuestionForTask,D.Destination,D.PlanTask
function K.Target(entry)
    local r=entry.record
    return {name=r.target,kind=r.kind,action=r.action,actor=r.actor,localAction=r.action=='interact',regional=true}
end
function K.Basic(task)
    local verb,rest=task.text:match('^([^ \t\r\n]+)[ \t\r\n]+(.+)$')
    if not verb or not ({amenez=true,emmenez=true,escortez=true,accompagnez=true})[norm(verb)] then return end
    local separators={" jusqu’aux "," jusqu'aux "," jusqu’au "," jusqu'au "," jusqu’à "," jusqu'à "," aux "," au "," à "," vers "," dans "}
    for _,separator in ipairs(separators) do
        local at=rest:find(separator,1,true)
        if at then
            local actor=rest:sub(1,at-1);local target=rest:sub(at+#separator)
            if separator:find('aux',1,true) then target='les '..target
            elseif separator:find('au ',1,true) then target='le '..target end
            if target~='' then
                local first=actor:match('^([^ ]+)') or ''
                if norm(verb)=='amenez' and first==zo_strlower(first) and not norm(actor):find('survivant',1,true) and not norm(actor):find('prisonnier',1,true) then
                    return {name=target,kind='person',action='deliver',item=actor,question='Savez-vous où je pourrais trouver '..target..' ?'}
                end
                return {name=target,kind='place',action='escort',actor=actor,question='Par où passe-t-on pour rejoindre '..target..' ?'}
            end
        end
    end
end
function D.TargetForTask(task)
    local entry=K.Lookup(task)
    if entry then
        local target=K.Target(entry)
        if target.action=='deliver' then
            local native=previousTarget(task)
            if native and native.kind=='person' then target.name=native.name end
        end
        return target
    end
    return K.Basic(task) or previousTarget(task)
end
function D.QuestionForTask(task)
    local entry=K.Lookup(task)
    if entry then
        local r=entry.record
        if r.action=='deliver' then local target=D.TargetForTask(task);if target and target.kind=='person' then return D.GeographicQuestion(target.name,'person') end end
        if B.npc and r.actor and K.SamePerson(r.actor,B.npc.name) and r.selfQuestion then return r.selfQuestion end
        return r.question
    end
    local basic=K.Basic(task)
    return basic and basic.question or previousQuestion(task)
end
function K.Destination(task,entry,meta)
    local r,q=entry.record,entry.quest
    local region=D.Region(task.quest.zoneIndex)
    local name=r.site or q.site
    -- The exact current objective map is evidence too; region names are not point locations.
    if meta and meta.mapName and meta.mapName~='' and bare(meta.mapName)~=bare(meta.region) and not ({tamriel=true,nirn=true,aurbis=true})[bare(meta.mapName)] then
        name=meta.mapName
    end
    if not name or name=='' then return end
    if r.kind=='place' and r.action=='locate' then
        local targetSite=D.SiteForName(r.target,meta and meta.regionIndex or region and region.zoneIndex or nil)
        if targetSite then name=targetSite.name end
    end
    local site=D.SiteForName(name,meta and meta.regionIndex or region and region.zoneIndex or nil)
    if meta and meta.region and meta.region~='' and bare(meta.mapName)==bare(meta.region) and bare(meta.region)~=bare(q.regionName) and q.regionName~='Quête principale' then
        -- A chain can leave its home province. Do not redirect a current objective to its old hub.
        if not site or site.region and bare(site.region)~=bare(meta.region) then return nil end
    end
    return {name=site and site.name or name,site=site,region=site and site.region or region and region.name or q.regionName,relation='in',source='Référentiel régional : '..q.id..'/'..r.id}
end
function D.Destination(task,meta)
    local entry=K.Lookup(task)
    if entry then return K.Destination(task,entry,meta) or previousDestination(task,meta) end
    return previousDestination(task,meta)
end
function K.Witness(entry)
    if not B.npc then return false end
    if entry.record.actor and K.SamePerson(entry.record.actor,B.npc.name) then return true end
    for _,person in ipairs(entry.quest.cast) do if K.SamePerson(person,B.npc.name) then return true end end
    return false
end
function K.Local(task,entry,dest)
    if not B.npc then return false end
    if K.Witness(entry) then return true end
    if dest and (B.Here(dest.name) or D.NpcOnSite(task,dest)) then return true end
    local p=D.positions[task.key]
    if p and type(p.radius)=='number' and p.radius<=0 and p.mapId==GetCurrentMapId() and GetTimeStamp()-p.time<20 and (not p.taskText or norm(p.taskText)==norm(task.text)) then
        local x,y=GetMapPlayerPosition('player')
        if point(x,y) and (p.x-x)^2+(p.y-y)^2<.0004 then return true end
    end
    return false
end
function K.KnowsReference(task,record)
    local source='Référentiel régional : '..tostring(record.id)
    local function validSource(text)
        return type(text)=='string' and text:find(source..' ;',1,true)==1 and (not record.coherenceRevision or text:find(record.coherenceRevision,1,true)) and (not record.methodVerified or text:find(' ; méthode vérifiée',1,true))
    end
    local journal=B.Investigation
    if journal then
        for _,e in ipairs(journal.Entries(task.questKey)) do
            if (e.factKind=='spot' or (e.level or 0)>=3) and validSource(e.source) and K.ObjectiveKey(e.taskText)==K.ObjectiveKey(task.text) and D.SameOrigin(e) then return true end
        end
    end
    for _,h in pairs(D.Saved().hints) do
        if h.taskKey==task.key and (h.level or 0)>=3 and validSource(h.source) and D.SameOrigin(h) then return true end
    end
    return false
end
local function scope(entries)
    if type(GetUnitWorldPosition)~='function' then return entries end
    local zone,x,_,z=GetUnitWorldPosition('player')
    if type(zone)~='number' or type(x)~='number' or type(z)~='number' then return entries end
    local saved=D.Saved();saved.inquiryOrigins=saved.inquiryOrigins or {}
    for _,entry in ipairs(entries) do
        local radius=entry.kind=='spot' and 2500 or 10000
        local points=saved.inquiryOrigins[entry.key] or {};saved.inquiryOrigins[entry.key]=points
        local found
        for i,p in ipairs(points) do if D.SameOrigin(p) then found=i;break end end
        if not found then found=#points+1;points[found]={originZone=zone,originX=x,originZ=z,scopeRadius=radius} end
        entry.key=entry.key..':origin:'..found;entry.originZone=zone;entry.originX=x;entry.originZ=z;entry.scopeRadius=radius
    end
    return entries
end
local function subject(task,entry,dest,kind,answer,question)
    local r=entry.record
    local target=D.TargetForTask(task) or {name=r.target,kind=r.kind}
    return {planner=4,kind=kind,task=task,title=task.quest.name,target=target.name,targetKind=target.kind,destination=dest and dest.name,
        regionalRecord=r.id,methodVerified=r.methodVerified and kind=='spot' and D.Coherence.MethodQuestion(question) or nil,key=task.key..':regional:'..r.id..':'..kind..(r.coherenceRevision and ':'..r.coherenceRevision or '')..(r.methodVerified and (D.Coherence.MethodQuestion(question) and ':method' or ':position') or ''),question=question,answer=answer,level=kind=='spot' and 3 or kind=='route' and 2 or 1,
        source='Référentiel régional : '..r.id..' ; quête '..entry.quest.id..' ; '..r.source..(r.coherenceRevision and ' ; '..r.coherenceRevision or '')..(r.methodVerified and D.Coherence.MethodQuestion(question) and ' ; méthode vérifiée' or ''),relation='in'}
end
function K.PointAnswer(task)
    local p=D.positions[task.key]
    if not p or p.radius>0 or p.mapId~=GetCurrentMapId() or GetTimeStamp()-p.time>20 or p.taskText and norm(p.taskText)~=norm(task.text) then return end
    local x,y=GetMapPlayerPosition('player');if not point(x,y) then return end
    local dx,dy=p.x-x,p.y-y
    if dx*dx+dy*dy<.000009 then return 'C’est juste ici. Regardez autour de vous.' end
    return 'Regardez '..B.Bearing(dx,dy)..' d’ici.'
end
local function routeAnswer(route)
    if not route then return end
    if route.near then return 'C’est tout près d’ici. Regardez autour de vous.' end
    local text
    if route.bearing then
        local origin=route.origin and route.origin~='' and ('Depuis '..route.origin..', ') or ''
        text=origin..'Dirigez-vous '..route.bearing..'.'
    end
    if route.anchor and route.anchorBearing then
        local reference='C’est '..route.anchorBearing..' '..D.OfPlace(route.anchor)..'.'
        text=text and text..' '..reference or reference
    end
    return text
end
local function onRecord(task,entry)
    local r=entry.record
    if r.silent or not r.question then return {} end
    if B.npc and r.kind=='person' and K.SamePerson(r.target,B.npc.name) then return {} end
    local meta=D.Metadata(task);D.RequestPosition(task)
    local dest=K.Destination(task,entry,meta)
    local localNpc=K.Local(task,entry,dest)
    local question=D.QuestionForTask(task)
    if localNpc then
        if K.KnowsReference(task,r) then return {} end
        question=(B.npc and r.actor and K.SamePerson(r.actor,B.npc.name) and r.selfQuestion) or r.localQuestion or question
        if r.kind=='place' and (task.text:find('^Fouillez ') or task.text:find('^Inspectez ') or task.text:find('^Explorez ')) then
            question='Par où me conseillez-vous de commencer les recherches ?'
        end
        local hint=r.hint
        if r.selfHint and B.npc and K.SamePerson(r.selfSpeaker or r.actor or '',B.npc.name) then hint=r.selfHint end
        local method=r.methodVerified and B.npc and K.SamePerson(r.methodSpeaker or '',B.npc.name) and K.Local(task,entry,dest)
        if r.method and not method then
            question=D.GeographicQuestion(r.target,r.kind)
        end
        local answer=not method and K.PointAnswer(task) or nil
        -- A native point and a visual description can complement each other.
        -- A static direction is not appended as if it started from the current player position.
        if answer and hint and not r.method and not D.GeographicDirections(hint) then answer=answer..' '..hint end
        if not answer and (not r.method or method) then answer=hint end
        if answer and answer~='' then
            -- Do not attribute another person's observations to a speaker in the first person.
            return scope({subject(task,entry,dest,'spot',answer,question)})
        end
    end
    if dest then
        -- A distant geographical answer never claims to explain an interaction.
        if r.method then question=D.GeographicQuestion(r.target,r.kind) end
        local known=D.InquiryKnowledge(task,dest)
        if not known.identity then
            return scope({subject(task,entry,dest,'destination','Cherchez du côté de '..dest.name..'. Les personnes sur place pourront vous en dire davantage.',question)})
        end
        local route=D.ReadRoute(dest.site)
        local answer=routeAnswer(route)
        if not known.route and answer then
            return scope({subject(task,entry,dest,'route',answer,'Comment rejoindre '..dest.name..' ?')})
        end
        if not known.identity then
            return scope({subject(task,entry,dest,'destination','Cherchez du côté de '..dest.name..'. Les personnes sur place pourront vous en dire davantage.',question)})
        end
    end
    -- Reaching the quest site does not locate its person/item. This producer
    -- replaces the native planner, so it must retain that unanswered objective
    -- even after an older beta recorded a route to the site.
    if r.kind=='person' or r.kind=='object' then
        local known=dest and D.InquiryKnowledge(task,dest)
        if not known or not known.exact then
            local pending=subject(task,entry,dest,'unresolved',nil,question)
            pending.unresolved=true;pending.localKnowledgeOnly=true
            pending.requiredSite=dest and dest.name
            return scope({pending})
        end
    end
    -- A precise reference without a reliable local witness is not given to a distant passer-by.
    return {}
end
function D.PlanTask(task)
    local entry=K.Lookup(task)
    if entry then return onRecord(task,entry) end
    -- Unmatched variants keep native geographic support, but do not borrow another stage's hint.
    local target=K.Basic(task) or previousTarget(task)
    if B.npc and target and target.kind=='person' and K.SamePerson(target.name,B.npc.name) then return {} end
    local result=previousPlan(task)
    local basic=K.Basic(task)
    if basic then for _,s in ipairs(result) do if s.kind~='route' and s.kind~='region' then s.question=basic.question;s.target=basic.name;s.targetKind='place' end end end
    if K.HasQuest(task.quest.name) then
        for _,s in ipairs(result) do
            if s.question and (s.question:find('jusqu',1,true) or s.question:find('pour fuir',1,true)) then return {} end
        end
    end
    return result
end
-- The existing Subjects/RefreshSubject/Reveal pipeline handles current unfinished tasks,
-- origin-scoped dice results, shared clues and journal recording for planner 4 as well.
if SLASH_COMMANDS then SLASH_COMMANDS['/ihrdiagnostic']=function()
    if type(d)~='function' then return end
    for _,q in ipairs(B.Quests()) do
        if K.HasQuest(q.name) then
            d(q.name)
            for _,task in ipairs(D.Tasks(q.index)) do local e=K.Lookup(task)
                d(' • '..task.text..' — '..(e and ('référence '..e.quest.id..'/'..e.record.order) or 'variante à vérifier'))
            end
        end
    end
end end
